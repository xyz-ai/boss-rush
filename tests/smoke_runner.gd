extends SceneTree

const RUN_STATE_SCRIPT := preload("res://scripts/core/RunState.gd")
const BATTLE_RESOLVER_SCRIPT := preload("res://scripts/core/BattleResolver.gd")
const PEEK_SYSTEM_SCRIPT := preload("res://scripts/systems/PeekSystem.gd")
const ADDON_SYSTEM_SCRIPT := preload("res://scripts/systems/AddonSystem.gd")
const BOSS_AI_SCRIPT := preload("res://scripts/core/BossAI.gd")
const MATCHUP_RULES_SCRIPT := preload("res://scripts/core/MatchupRules.gd")
const MVP_BOSS_AI_SCRIPT := preload("res://scripts/game/BossAI.gd")
const MVP_BATTLE_CARD_SCRIPT := preload("res://scripts/game/BattleCard.gd")
const MVP_COMBAT_ACTOR_STATE_SCRIPT := preload("res://scripts/game/CombatActorState.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var loader = get_root().get_node_or_null("DataLoader")
	if loader == null:
		failures.append("Autoload DataLoader is missing.")
	else:
		loader.reload_all()
		_test_logic(loader, failures)
		_test_ai(loader, failures)
		_test_mvp_boss_ai(failures)
	await _test_scene_instancing(loader, failures)
	await _test_main_mvp(failures)

	if failures.is_empty():
		print("SMOKE OK")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	print("SMOKE FAILED")
	quit(1)

func _test_logic(loader, failures: Array[String]) -> void:
	var challenge_rules: Dictionary = loader.get_balance("challenge_rules", {})
	var resolver = BATTLE_RESOLVER_SCRIPT.new(loader.get_balance("matchup_rules", {}))
	var addon_system = ADDON_SYSTEM_SCRIPT.new()
	var peek_system = PEEK_SYSTEM_SCRIPT.new()

	var state = _fresh_state(loader)
	_assert(state.bod == 3 and state.spr == 3 and state.rep == 3, "Player long-term states should start at 3.", failures)
	_assert(state.boss_bod == 3 and state.boss_spr == 3 and state.boss_rep == 3, "Boss long-term states should start at 3.", failures)
	_assert(state.current_set_state.remaining_player_battle_cards.size() == 5, "Player should start each set with 5 battle cards.", failures)
	_assert(state.current_set_state.remaining_boss_battle_cards.size() == 5, "Boss should start each set with 5 battle cards.", failures)
	_assert(state.current_set_state.boss_deck.size() == 5, "Boss deck view should track 5 boss cards.", failures)
	_assert(state.current_set_state.boss_used_cards.is_empty(), "Boss used cards should start empty.", failures)
	_assert(not state.current_set_state.boss_revealed, "Boss deck should start hidden.", failures)

	state.begin_round(state.current_set_state.remaining_boss_battle_cards)
	var result = resolver.resolve_round(state, "g_steady", "tl_procedure", {"addon_id": "", "cover": 0})
	_assert(result.get("margin", 0) == 2, "Growth vs defense should still produce +2 margin.", failures)
	_assert(state.current_set_state.next_bonus == 1, "G-Steady should still set Next +1.", failures)
	_assert(state.current_set_state.boss_hp == 4, "Boss HP should drop by 2 on the opening win.", failures)
	_assert(not "g_steady" in state.current_set_state.remaining_player_battle_cards, "Played player cards should leave the set hand.", failures)
	_assert(int(state.boss_spr) == 2, "G-Steady should apply a boss SPR penalty on hit.", failures)

	state = _fresh_state(loader)
	state.boss_spr = 1
	state.begin_round(state.current_set_state.remaining_boss_battle_cards)
	result = resolver.resolve_round(state, "c_audit", "tl_pressure", {"addon_id": "", "cover": 0})
	_assert(result.get("boss_total", 0) == 1, "Boss SPR <= 1 should reduce boss card power by 1 before multipliers.", failures)

	state = _fresh_state(loader)
	var baseline_state = _fresh_state(loader)
	baseline_state.begin_round(baseline_state.current_set_state.remaining_boss_battle_cards)
	var baseline_result = resolver.resolve_round(baseline_state, "g_burst", "tl_pressure", {"addon_id": "", "cover": 0})
	state.bod = 1
	state.begin_round(state.current_set_state.remaining_boss_battle_cards)
	result = resolver.resolve_round(state, "g_burst", "tl_pressure", {"addon_id": "", "cover": 0})
	_assert(
		int(result.get("player_damage", 0)) == int(baseline_result.get("player_damage", 0)) + 1,
		"Player BOD <= 1 should add 1 extra damage when hit.",
		failures
	)

	state = _fresh_state(loader)
	state.boss_bod = 1
	state.begin_round(state.current_set_state.remaining_boss_battle_cards)
	result = resolver.resolve_round(state, "g_steady", "tl_procedure", {"addon_id": "", "cover": 0})
	_assert(result.get("boss_damage", 0) == 3, "Boss BOD <= 1 should add 1 extra damage when boss is hit.", failures)

	state = _fresh_state(loader)
	state.begin_round(state.current_set_state.remaining_boss_battle_cards)
	result = resolver.resolve_round(state, "g_burst", "tl_pressure", {"addon_id": "stop_loss", "cover": 0})
	_assert(result.get("player_damage", 0) == 1, "StopLoss should still cap round damage to 1 HP.", failures)
	_assert(state.current_set_state.next_penalty == 1, "G-Burst should still set Next -1.", failures)

	state = _fresh_state(loader)
	state.begin_round(state.current_set_state.remaining_boss_battle_cards)
	var no_leverage_result = resolver.resolve_round(state, "g_steady", "tl_procedure", {"addon_id": "", "cover": 0})

	state = _fresh_state(loader)
	state.begin_round(state.current_set_state.remaining_boss_battle_cards)
	result = resolver.resolve_round(state, "g_steady", "tl_procedure", {"addon_id": "leverage", "cover": 0})
	_assert(
		int(result.get("boss_damage", 0)) == int(no_leverage_result.get("boss_damage", 0)) + 1,
		"Leverage should add 1 extra boss damage on a winning round.",
		failures
	)
	_assert(
		int(result.get("pos_after", 0)) == int(no_leverage_result.get("pos_after", 0)) + 1,
		"Leverage should also add +1 POS on top of the round margin.",
		failures
	)

	state = _fresh_state(loader)
	state.current_set_state.player_hp = 3
	state.current_set_state.boss_hp = 3
	state.current_set_state.round_index = 4
	state.current_set_state.remaining_player_battle_cards.clear()
	state.current_set_state.remaining_player_battle_cards.append("d_cover")
	state.current_set_state.remaining_boss_battle_cards.clear()
	state.current_set_state.remaining_boss_battle_cards.append("tl_procedure")
	state.begin_round(state.current_set_state.remaining_boss_battle_cards)
	result = resolver.resolve_round(state, "d_cover", "tl_procedure", {"addon_id": "", "cover": 0})
	_assert(result.get("set_finished", false), "Fifth round should finish the set.", failures)
	_assert(result.get("set_winner", "") == "boss", "Configured tie winner should favor the boss.", failures)

	state = _fresh_state(loader)
	state.begin_round(state.current_set_state.remaining_boss_battle_cards)
	var addon_result = addon_system.activate_addon(state, "intel")
	_assert(addon_result.get("ok", false), "Intel should be activatable inside a round.", failures)
	_assert(int(state.get_remaining_addons().get("intel", 0)) == 0, "Activated addons should be consumed for the whole challenge.", failures)
	state.start_set(challenge_rules)
	state.current_set_state.configure_boss_deck(loader.get_boss("team_lead").get("deck", []))
	_assert(int(state.get_remaining_addons().get("intel", 0)) == 0, "Addons should not refresh between sets.", failures)
	_assert(state.current_set_state.remaining_player_battle_cards.size() == 5, "A new set should restore the five-card hand.", failures)
	_assert(state.current_set_state.remaining_boss_battle_cards.size() == 5, "A new set should restore the five-card boss deck.", failures)

	state = _fresh_state(loader)
	state.challenge_state.player_set_wins = 1
	var finish_info = state.finish_set("player")
	_assert(finish_info.get("challenge_finished", false), "Second set win should end the challenge immediately.", failures)
	_assert(finish_info.get("challenge_winner", "") == "player", "Player should win the challenge after two set wins.", failures)

	state = _fresh_state(loader)
	state.spr = 1
	peek_system.peek_pool(state, state.current_set_state.boss_deck)
	_assert(state.current_set_state.boss_revealed, "Peeking should reveal the full boss deck for the set.", failures)
	_assert(state.is_failed(), "Run should enter a failed terminal state when a long-term status reaches zero.", failures)

	state = _fresh_state(loader)
	state.boss_rep = 1
	state.begin_round(state.current_set_state.remaining_boss_battle_cards)
	result = resolver.resolve_round(state, "a_tempo", "tl_alignment", {"addon_id": "", "cover": 0})
	_assert(result.get("challenge_finished", false), "Boss long-term collapse should immediately end the challenge.", failures)
	_assert(result.get("challenge_outcome", "") == "victory", "Boss long-term collapse should count as player victory.", failures)

	state = _fresh_state(loader)
	state.current_set_state.consume_boss_card("tl_pressure")
	state.current_set_state.mark_boss_card_used("tl_pressure")
	_assert(state.current_set_state.boss_used_cards.size() == 1, "Used boss cards should be tracked for deck visualization.", failures)
	_assert(not "tl_pressure" in state.current_set_state.remaining_boss_battle_cards, "Used boss cards should leave the remaining boss hand.", failures)
	state.start_set(challenge_rules)
	state.current_set_state.configure_boss_deck(loader.get_boss("team_lead").get("deck", []))
	_assert(state.current_set_state.boss_used_cards.is_empty(), "Boss used cards should reset on a new set.", failures)
	_assert(not state.current_set_state.boss_revealed, "Boss reveal state should reset on a new set.", failures)

func _test_ai(loader, failures: Array[String]) -> void:
	var state = _fresh_state(loader)
	var boss_def: Dictionary = loader.get_boss("team_lead")
	var ai = BOSS_AI_SCRIPT.new(loader.get_balance("matchup_rules", {}))
	ai.set_seed(1337)

	var pool = ai.prepare_pool(boss_def, state)
	_assert(pool.size() == 5, "Boss pool should expose all 5 remaining boss cards in MVP mode.", failures)
	for card_id in pool:
		_assert(card_id in boss_def.get("deck", []), "Boss pool should only contain deck cards.", failures)

	var counts = {"counter": 0, "neutral": 0, "wrong": 0}
	var rules = MATCHUP_RULES_SCRIPT.new(loader.get_balance("matchup_rules", {}))
	for _index in range(500):
		var pick = ai.pick_card(boss_def.get("deck", []), "growth", state)
		var category = rules.categorize(loader.get_boss_card(pick).get("family", ""), "growth")
		counts[category] += 1
	_assert(counts["counter"] > counts["neutral"], "Counter picks should outnumber neutral picks.", failures)
	_assert(counts["neutral"] > counts["wrong"], "Neutral picks should outnumber wrong picks.", failures)

func _test_mvp_boss_ai(failures: Array[String]) -> void:
	var ai: MvpBossAI = MVP_BOSS_AI_SCRIPT.new()
	var player_aggression: MvpBattleCard = MVP_BATTLE_CARD_SCRIPT.new(MVP_BATTLE_CARD_SCRIPT.TYPE_AGGRESSION)

	_assert(
		ai._categorize(MVP_BATTLE_CARD_SCRIPT.TYPE_DEFENSE, MVP_BATTLE_CARD_SCRIPT.TYPE_AGGRESSION) == MvpBossAI.CATEGORY_COUNTER,
		"Defense should categorize as counter versus aggression.",
		failures
	)
	_assert(
		ai._categorize(MVP_BATTLE_CARD_SCRIPT.TYPE_AGGRESSION, MVP_BATTLE_CARD_SCRIPT.TYPE_AGGRESSION) == MvpBossAI.CATEGORY_NEUTRAL,
		"Same-type matchup should be treated as neutral in the 3-type triangle.",
		failures
	)
	_assert(
		ai._categorize(MVP_BATTLE_CARD_SCRIPT.TYPE_PRESSURE, MVP_BATTLE_CARD_SCRIPT.TYPE_AGGRESSION) == MvpBossAI.CATEGORY_WRONG,
		"Pressure should categorize as wrong versus aggression.",
		failures
	)

	var distribution_state: MvpCombatActorState = MVP_COMBAT_ACTOR_STATE_SCRIPT.new("Boss", [
		MVP_BATTLE_CARD_SCRIPT.new(MVP_BATTLE_CARD_SCRIPT.TYPE_DEFENSE),
		MVP_BATTLE_CARD_SCRIPT.new(MVP_BATTLE_CARD_SCRIPT.TYPE_AGGRESSION),
		MVP_BATTLE_CARD_SCRIPT.new(MVP_BATTLE_CARD_SCRIPT.TYPE_PRESSURE),
	])
	var counts: Dictionary = {
		MvpBossAI.CATEGORY_COUNTER: 0,
		MvpBossAI.CATEGORY_NEUTRAL: 0,
		MvpBossAI.CATEGORY_WRONG: 0,
	}
	ai.set_seed(1337)
	for _index in range(600):
		var slot_index: int = ai.choose_slot(distribution_state, player_aggression)
		var chosen_card: MvpBattleCard = distribution_state.get_card_at(slot_index)
		var category: String = ai._categorize(chosen_card.type, player_aggression.type)
		counts[category] = int(counts.get(category, 0)) + 1
	_assert(int(counts.get(MvpBossAI.CATEGORY_COUNTER, 0)) > int(counts.get(MvpBossAI.CATEGORY_NEUTRAL, 0)), "MVP BossAI should favor counter picks over neutral picks.", failures)
	_assert(int(counts.get(MvpBossAI.CATEGORY_NEUTRAL, 0)) > int(counts.get(MvpBossAI.CATEGORY_WRONG, 0)), "MVP BossAI should favor neutral picks over wrong picks.", failures)

	var no_counter_state: MvpCombatActorState = MVP_COMBAT_ACTOR_STATE_SCRIPT.new("Boss", [
		MVP_BATTLE_CARD_SCRIPT.new(MVP_BATTLE_CARD_SCRIPT.TYPE_AGGRESSION),
		MVP_BATTLE_CARD_SCRIPT.new(MVP_BATTLE_CARD_SCRIPT.TYPE_PRESSURE),
	])
	var no_counter_buckets: Dictionary = ai._build_available_buckets(no_counter_state, player_aggression)
	_assert(
		ai._resolve_category_with_fallback(MvpBossAI.CATEGORY_COUNTER, no_counter_buckets) == MvpBossAI.CATEGORY_NEUTRAL,
		"When counter cards are exhausted, fallback should prefer neutral cards before wrong cards.",
		failures
	)

	var wrong_only_state: MvpCombatActorState = MVP_COMBAT_ACTOR_STATE_SCRIPT.new("Boss", [
		MVP_BATTLE_CARD_SCRIPT.new(MVP_BATTLE_CARD_SCRIPT.TYPE_PRESSURE),
		MVP_BATTLE_CARD_SCRIPT.new(MVP_BATTLE_CARD_SCRIPT.TYPE_PRESSURE),
	])
	var wrong_only_buckets: Dictionary = ai._build_available_buckets(wrong_only_state, player_aggression)
	_assert(
		ai._resolve_category_with_fallback(MvpBossAI.CATEGORY_COUNTER, wrong_only_buckets) == MvpBossAI.CATEGORY_WRONG,
		"When only wrong-category cards remain, fallback should still return a legal remaining category.",
		failures
	)

	var constrained_state: MvpCombatActorState = MVP_COMBAT_ACTOR_STATE_SCRIPT.new("Boss", MVP_BATTLE_CARD_SCRIPT.build_boss_template(MVP_BATTLE_CARD_SCRIPT.TEMPLATE_A_ID))
	constrained_state.mark_card_used(0)
	constrained_state.mark_card_used(4)
	ai.set_seed(2025)
	for _attempt in range(80):
		var chosen_slot: int = ai.choose_slot(constrained_state, player_aggression)
		_assert(chosen_slot != 0 and chosen_slot != 4, "MVP BossAI should never choose an already used slot.", failures)
		_assert(not constrained_state.is_slot_used(chosen_slot), "MVP BossAI should only choose currently unused slots.", failures)

	var exhausted_state: MvpCombatActorState = MVP_COMBAT_ACTOR_STATE_SCRIPT.new("Boss", [
		MVP_BATTLE_CARD_SCRIPT.new(MVP_BATTLE_CARD_SCRIPT.TYPE_PRESSURE),
	])
	exhausted_state.mark_card_used(0)
	_assert(ai.choose_slot(exhausted_state, player_aggression) == -1, "MVP BossAI should return -1 instead of crashing when no legal slots remain.", failures)

func _test_scene_instancing(loader, failures: Array[String]) -> void:
	for scene_path in [
		"res://scenes/main/Main.tscn",
		"res://scenes/battle/BattleScene.tscn",
		"res://scenes/shop/ShopScene.tscn",
	]:
		var packed: PackedScene = load(scene_path)
		if packed == null:
			failures.append("Could not load scene: %s" % scene_path)
			continue
		var instance = packed.instantiate()
		_assert(instance != null, "Could not instantiate scene: %s" % scene_path, failures)
		if instance != null:
			get_root().add_child(instance)
			await process_frame
			instance.queue_free()
			await process_frame

	var battle_scene: Control = load("res://scenes/battle/BattleScene.tscn").instantiate()
	var battle_state = _fresh_state(loader)
	var game_run = get_root().get_node_or_null("GameRun")
	if game_run != null:
		game_run.run_state = battle_state
	get_root().add_child(battle_scene)
	battle_scene.bind_context(battle_state, loader.get_boss("team_lead"))
	await process_frame
	battle_scene.call("_on_peek_requested")
	await process_frame
	_assert(battle_state.current_set_state.boss_revealed, "BattleScene should reveal the boss deck after peek.", failures)
	var first_card_id = str(battle_state.current_set_state.remaining_player_battle_cards[0])
	battle_scene.call("_on_player_card_selected", first_card_id)
	await process_frame
	_assert(battle_state.current_set_state.boss_used_cards.size() == 1, "BattleScene should record used boss cards after a round resolves.", failures)
	_assert(battle_state.current_set_state.remaining_boss_battle_cards.size() == 4, "BattleScene should consume one boss card after a round.", failures)
	var clash_area = battle_scene.get_node_or_null("SafeArea/StageRoot/TableCore/ClashArea")
	_assert(clash_area != null, "BattleScene should have a central ClashArea.", failures)
	if clash_area != null:
		var summary_label = clash_area.get_node_or_null("MarginContainer/VBoxContainer/SummaryLabel")
		_assert(summary_label != null and str(summary_label.text) != "本回合结算会显示在这里。", "ClashArea should update after a round resolves.", failures)
	battle_scene.queue_free()
	await process_frame

func _test_main_mvp(failures: Array[String]) -> void:
	for size in [Vector2i(1366, 768), Vector2i(1440, 900), Vector2i(1920, 1080)]:
		await _test_main_mvp_layout(size, failures)

	DisplayServer.window_set_size(Vector2i(1440, 900))
	await process_frame
	await process_frame
	var scene: Control = load("res://scenes/main/Main.tscn").instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame

	var controller = scene.call("get_mvp_controller")
	var round_label: Label = scene.get_node_or_null("ContentRoot/TableArea/CenterInfo/RoundLabel")
	var turn_label: Label = scene.get_node_or_null("ContentRoot/TableArea/CenterInfo/TurnLabel")
	var hand_anchor: HBoxContainer = scene.get_node_or_null("ContentRoot/TableArea/PlayerArea/HandAnchor")
	var boss_hand_count_label: Label = scene.get_node_or_null("ContentRoot/TableArea/BossDeckView/BossHandCountLabel")
	var boss_hand_row: HBoxContainer = scene.get_node_or_null("ContentRoot/TableArea/BossDeckView/DeckRow")
	var reveal_button: Button = scene.get_node_or_null("ContentRoot/TableArea/BossBattleDeckView/RevealBattleDeckButton")
	var battle_deck_row: HBoxContainer = scene.get_node_or_null("ContentRoot/TableArea/BossBattleDeckView/BattleDeckRow")
	var player_hp: Label = scene.get_node_or_null("ContentRoot/TableArea/PlayerHP")
	var boss_hp: Label = scene.get_node_or_null("ContentRoot/TableArea/BossHP")
	var player_slot: Control = scene.get_node_or_null("ContentRoot/TableArea/ClashArea/PlayerCardSlot")
	var boss_slot: Control = scene.get_node_or_null("ContentRoot/TableArea/ClashArea/BossCardSlot")
	var clash_result_label: Label = scene.get_node_or_null("ContentRoot/TableArea/ClashArea/ClashResultLabel")

	_assert(round_label != null and round_label.text == "Round 1 / 3", "Main MVP should start at Round 1 / 3.", failures)
	_assert(turn_label != null and turn_label.text == "Turn 1 / 5", "Main MVP should start at Turn 1 / 5.", failures)
	_assert(hand_anchor != null and hand_anchor.get_child_count() == 5, "Main MVP should spawn 5 player cards.", failures)
	_assert(boss_hand_row != null and boss_hand_row.get_child_count() == 5, "Boss hand view should start with 5 remaining cards.", failures)
	_assert(battle_deck_row != null and battle_deck_row.get_child_count() == 5, "Boss battle deck should always expose 5 slots.", failures)
	_assert(boss_hand_count_label != null and boss_hand_count_label.text == "Boss Hand x5", "Boss hand count should start at 5.", failures)
	_assert(controller != null, "Main scene should expose its MVP controller for smoke testing.", failures)

	if hand_anchor != null:
		var expected_player_hand := ["Aggression", "Aggression", "Defense", "Pressure", "Pressure"]
		var actual_player_hand: Array[String] = []
		for child in hand_anchor.get_children():
			if child.has_method("get_card_data"):
				actual_player_hand.append(str(child.get_card_data().get("display_name", "")))
		_assert(actual_player_hand == expected_player_hand, "Player hand should be the fixed 2-1-2 template.", failures)

	if controller != null:
		var snapshot: Dictionary = controller.get_state_snapshot()
		var expected_templates := {
			"template_a": ["Aggression", "Aggression", "Pressure", "Pressure", "Defense"],
			"template_b": ["Defense", "Defense", "Aggression", "Pressure", "Pressure"],
			"template_c": ["Aggression", "Defense", "Pressure", "Aggression", "Defense"],
		}
		var template_id := str(snapshot.get("current_boss_template_id", ""))
		_assert(expected_templates.has(template_id), "Boss should choose one of the three fixed templates.", failures)

	if battle_deck_row != null and battle_deck_row.get_child_count() > 0:
		var first_battle_deck_card = battle_deck_row.get_child(0)
		_assert(first_battle_deck_card.has_method("get_view_state"), "Boss battle deck cards should expose a view state for testing.", failures)
		if first_battle_deck_card.has_method("get_view_state"):
			_assert(first_battle_deck_card.get_view_state() == "hidden", "Boss battle deck should start hidden.", failures)

	if reveal_button != null:
		reveal_button.emit_signal("pressed")
		await process_frame

	if battle_deck_row != null:
		var revealed_names: Array[String] = []
		for child in battle_deck_row.get_children():
			if child.has_method("get_card_data"):
				revealed_names.append(str(child.get_card_data().get("display_name", "")))
		var expected_templates_after_reveal := {
			"template_a": ["Aggression", "Aggression", "Pressure", "Pressure", "Defense"],
			"template_b": ["Defense", "Defense", "Aggression", "Pressure", "Pressure"],
			"template_c": ["Aggression", "Defense", "Pressure", "Aggression", "Defense"],
		}
		var reveal_snapshot: Dictionary = controller.get_state_snapshot() if controller != null else {}
		var reveal_template_id := str(reveal_snapshot.get("current_boss_template_id", ""))
		_assert(revealed_names == expected_templates_after_reveal.get(reveal_template_id, []), "Reveal should expose exactly one of the fixed boss templates.", failures)
		for child in battle_deck_row.get_children():
			if child.has_method("get_view_state"):
				_assert(child.get_view_state() == "normal", "Reveal should switch every unused boss deck slot to normal.", failures)

	if hand_anchor != null and hand_anchor.get_child_count() > 0:
		var first_player_card = hand_anchor.get_child(0)
		first_player_card.emit_signal("pressed")
		await process_frame
		await process_frame

	_assert(hand_anchor != null and hand_anchor.get_child_count() == 4, "Playing one card should remove it from the visible hand.", failures)
	_assert(turn_label != null and turn_label.text == "Turn 2 / 5", "Resolving one turn should advance to Turn 2 / 5.", failures)
	_assert(player_slot != null and player_slot.get_child_count() == 1, "Clash area should show the player's current card.", failures)
	_assert(boss_slot != null and boss_slot.get_child_count() == 1, "Clash area should show the boss's current card.", failures)
	_assert(clash_result_label != null and not clash_result_label.text.is_empty(), "Clash result label should show a round summary.", failures)
	_assert(player_hp != null and "Player HP" in player_hp.text, "Player HP label should remain populated after a clash.", failures)
	_assert(boss_hp != null and "Boss HP" in boss_hp.text, "Boss HP label should remain populated after a clash.", failures)
	_assert(boss_hand_row != null and boss_hand_row.get_child_count() == 4, "Boss hand view should shrink to 4 remaining cards after one play.", failures)
	_assert(boss_hand_count_label != null and boss_hand_count_label.text == "Boss Hand x4", "Boss hand count should update after one play.", failures)
	_assert(battle_deck_row != null and battle_deck_row.get_child_count() == 5, "Boss battle deck should keep 5 visible slots after use.", failures)

	if battle_deck_row != null:
		var used_found := false
		for child in battle_deck_row.get_children():
			if child.has_method("get_view_state") and child.get_view_state() == "used":
				used_found = true
				break
		_assert(used_found, "A boss battle deck slot should turn used after the boss plays a card.", failures)

	scene.queue_free()
	await process_frame

func _test_main_mvp_layout(size: Vector2i, failures: Array[String]) -> void:
	DisplayServer.window_set_size(size)
	await process_frame
	await process_frame

	var scene: Control = load("res://scenes/main/Main.tscn").instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame

	var viewport_size := scene.get_viewport_rect().size
	var reveal_button: Control = scene.get_node_or_null("ContentRoot/TableArea/BossBattleDeckView/RevealBattleDeckButton")
	var battle_deck_row: HBoxContainer = scene.get_node_or_null("ContentRoot/TableArea/BossBattleDeckView/BattleDeckRow")
	var boss_hand_row: HBoxContainer = scene.get_node_or_null("ContentRoot/TableArea/BossDeckView/DeckRow")
	var hand_anchor: HBoxContainer = scene.get_node_or_null("ContentRoot/TableArea/PlayerArea/HandAnchor")
	var overlay_ui: Control = scene.get_node_or_null("ContentRoot/OverlayUI")
	var player_hp: Control = scene.get_node_or_null("ContentRoot/TableArea/PlayerHP")
	var boss_hp: Control = scene.get_node_or_null("ContentRoot/TableArea/BossHP")
	var boss_portrait: Control = scene.get_node_or_null("ContentRoot/BossArea/BossPortrait")
	var table_board: Control = scene.get_node_or_null("ContentRoot/TableArea/TableBoard")
	var player_status_panel: Control = scene.get_node_or_null("ContentRoot/TableArea/PlayerStatusPanel")
	var boss_status_panel: Control = scene.get_node_or_null("ContentRoot/TableArea/BossStatusPanel")

	_assert_control_within_viewport(reveal_button, viewport_size, "RevealBattleDeckButton should stay inside the viewport at %s." % size, failures)
	_assert_control_within_viewport(battle_deck_row, viewport_size, "BattleDeckRow should stay inside the viewport at %s." % size, failures)
	_assert_control_within_viewport(boss_hand_row, viewport_size, "Boss hand DeckRow should stay inside the viewport at %s." % size, failures)
	_assert_control_within_viewport(hand_anchor, viewport_size, "HandAnchor should stay inside the viewport at %s." % size, failures)
	_assert_control_within_viewport(overlay_ui, viewport_size, "OverlayUI should stay inside the viewport at %s." % size, failures)
	_assert_control_within_viewport(player_hp, viewport_size, "PlayerHP should stay inside the viewport at %s." % size, failures)
	_assert_control_within_viewport(boss_hp, viewport_size, "BossHP should stay inside the viewport at %s." % size, failures)
	_assert_control_within_viewport(boss_portrait, viewport_size, "BossPortrait should stay inside the viewport at %s." % size, failures)
	_assert_control_within_viewport(table_board, viewport_size, "TableBoard should stay inside the viewport at %s." % size, failures)
	_assert_control_within_viewport(player_status_panel, viewport_size, "PlayerStatusPanel should stay inside the viewport at %s." % size, failures)
	_assert_control_within_viewport(boss_status_panel, viewport_size, "BossStatusPanel should stay inside the viewport at %s." % size, failures)

	if hand_anchor != null:
		_assert(hand_anchor.get_child_count() == 5, "Main MVP should still show 5 player cards at %s." % size, failures)
		for child in hand_anchor.get_children():
			if child is Control:
				_assert_control_within_viewport(child, viewport_size, "Each player card should stay inside the viewport at %s." % size, failures)

	var reveal: Button = reveal_button as Button
	if reveal != null:
		reveal.emit_signal("pressed")
		await process_frame

	if battle_deck_row != null:
		for child in battle_deck_row.get_children():
			if child is Control:
				_assert_control_within_viewport(child, viewport_size, "Each boss battle deck card should stay inside the viewport after reveal at %s." % size, failures)

	if boss_hand_row != null:
		for child in boss_hand_row.get_children():
			if child is Control:
				_assert_control_within_viewport(child, viewport_size, "Each boss hand card should stay inside the viewport after reveal at %s." % size, failures)

	scene.queue_free()
	await process_frame

func _fresh_state(loader) -> Object:
	var defaults: Dictionary = loader.get_balance("starting_values", {})
	var challenge_rules: Dictionary = loader.get_balance("challenge_rules", {})
	var state = RUN_STATE_SCRIPT.new()
	state.configure(defaults)
	state.begin_challenge("team_lead", challenge_rules, loader.get_player_loadout("default_set_hand"))
	state.current_set_state.configure_boss_deck(loader.get_boss("team_lead").get("deck", []))
	return state

func _assert(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)

func _assert_control_within_viewport(control: Control, viewport_size: Vector2, message: String, failures: Array[String]) -> void:
	if control == null:
		failures.append(message)
		return
	var rect := Rect2(control.global_position, control.size)
	var viewport_rect := Rect2(Vector2.ZERO, viewport_size)
	_assert(viewport_rect.encloses(rect), message, failures)

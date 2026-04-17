extends SceneTree

const RUN_STATE_SCRIPT := preload("res://scripts/core/RunState.gd")
const BATTLE_RESOLVER_SCRIPT := preload("res://scripts/core/BattleResolver.gd")
const PEEK_SYSTEM_SCRIPT := preload("res://scripts/systems/PeekSystem.gd")
const ADDON_SYSTEM_SCRIPT := preload("res://scripts/systems/AddonSystem.gd")
const BOSS_AI_SCRIPT := preload("res://scripts/core/BossAI.gd")
const MATCHUP_RULES_SCRIPT := preload("res://scripts/core/MatchupRules.gd")
const MVP_BOSS_AI_SCRIPT := preload("res://scripts/game/BossAI.gd")
const MVP_BATTLE_CARD_SCRIPT := preload("res://scripts/game/BattleCard.gd")
const MVP_BET_CARD_SCRIPT := preload("res://scripts/game/BetCard.gd")
const MVP_COMBAT_ACTOR_STATE_SCRIPT := preload("res://scripts/game/CombatActorState.gd")
const ROUND_FEEDBACK_WAIT := 2.15
const PLAYER_SUMMARY_BUTTON_PATH := "ContentRoot/TableArea/PlayerArea/Optional" + "SummaryButton"
const BOSS_SUMMARY_BUTTON_PATH := "ContentRoot/TableArea/BossArea/Boss" + "SummaryToggleButton"

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
		_test_mvp_content_externalization(loader, failures)
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
		MVP_BATTLE_CARD_SCRIPT.archetype_for_template(MVP_BATTLE_CARD_SCRIPT.TEMPLATE_A_ID) == MVP_BATTLE_CARD_SCRIPT.ARCHETYPE_AGGRESSIVE,
		"template_a should map to the Aggressive boss archetype.",
		failures
	)
	_assert(
		MVP_BATTLE_CARD_SCRIPT.archetype_for_template(MVP_BATTLE_CARD_SCRIPT.TEMPLATE_B_ID) == MVP_BATTLE_CARD_SCRIPT.ARCHETYPE_DEFENSIVE,
		"template_b should map to the Defensive boss archetype.",
		failures
	)
	_assert(
		MVP_BATTLE_CARD_SCRIPT.archetype_for_template(MVP_BATTLE_CARD_SCRIPT.TEMPLATE_C_ID) == MVP_BATTLE_CARD_SCRIPT.ARCHETYPE_BALANCED,
		"template_c should map to the Balanced boss archetype.",
		failures
	)

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

	var archetype_state: MvpCombatActorState = MVP_COMBAT_ACTOR_STATE_SCRIPT.new("Boss", [
		MVP_BATTLE_CARD_SCRIPT.new(MVP_BATTLE_CARD_SCRIPT.TYPE_DEFENSE),
		MVP_BATTLE_CARD_SCRIPT.new(MVP_BATTLE_CARD_SCRIPT.TYPE_AGGRESSION),
		MVP_BATTLE_CARD_SCRIPT.new(MVP_BATTLE_CARD_SCRIPT.TYPE_PRESSURE),
	])
	var aggressive_counts := {
		MVP_BATTLE_CARD_SCRIPT.TYPE_AGGRESSION: 0,
		MVP_BATTLE_CARD_SCRIPT.TYPE_DEFENSE: 0,
	}
	ai.set_seed(7331)
	ai.set_archetype(MVP_BATTLE_CARD_SCRIPT.ARCHETYPE_AGGRESSIVE)
	for _index in range(600):
		var aggressive_slot: int = ai.choose_slot(archetype_state, player_aggression)
		var aggressive_card: MvpBattleCard = archetype_state.get_card_at(aggressive_slot)
		if aggressive_card != null and aggressive_counts.has(aggressive_card.type):
			aggressive_counts[aggressive_card.type] = int(aggressive_counts.get(aggressive_card.type, 0)) + 1
	_assert(
		int(aggressive_counts.get(MVP_BATTLE_CARD_SCRIPT.TYPE_AGGRESSION, 0)) > int(aggressive_counts.get(MVP_BATTLE_CARD_SCRIPT.TYPE_DEFENSE, 0)),
		"Aggressive MVP BossAI should choose Aggression more often than Defense when both remain legal.",
		failures
	)

	var defensive_counts := {
		MVP_BATTLE_CARD_SCRIPT.TYPE_AGGRESSION: 0,
		MVP_BATTLE_CARD_SCRIPT.TYPE_DEFENSE: 0,
	}
	ai.set_seed(7331)
	ai.set_archetype(MVP_BATTLE_CARD_SCRIPT.ARCHETYPE_DEFENSIVE)
	for _index in range(600):
		var defensive_slot: int = ai.choose_slot(archetype_state, player_aggression)
		var defensive_card: MvpBattleCard = archetype_state.get_card_at(defensive_slot)
		if defensive_card != null and defensive_counts.has(defensive_card.type):
			defensive_counts[defensive_card.type] = int(defensive_counts.get(defensive_card.type, 0)) + 1
	_assert(
		int(defensive_counts.get(MVP_BATTLE_CARD_SCRIPT.TYPE_DEFENSE, 0)) > int(defensive_counts.get(MVP_BATTLE_CARD_SCRIPT.TYPE_AGGRESSION, 0)),
		"Defensive MVP BossAI should choose Defense more often than Aggression when both remain legal.",
		failures
	)

	ai.set_archetype(MVP_BATTLE_CARD_SCRIPT.ARCHETYPE_BALANCED)

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

func _test_mvp_content_externalization(loader, failures: Array[String]) -> void:
	_assert(loader.has_method("get_mvp_boss_config"), "DataLoader should expose MVP boss content getters.", failures)
	_assert(loader.has_method("get_mvp_bet_card_def"), "DataLoader should expose MVP bet card content getters.", failures)
	_assert(loader.has_method("get_mvp_text"), "DataLoader should expose MVP text catalog getters.", failures)

	var boss_ids: Array[String] = loader.get_mvp_boss_ids()
	_assert(boss_ids.size() == 3, "MVP content repo should expose exactly 3 boss templates.", failures)
	_assert(boss_ids.has("template_a") and boss_ids.has("template_b") and boss_ids.has("template_c"), "MVP content repo should keep the three fixed boss ids.", failures)

	var template_a: Dictionary = loader.get_mvp_boss_config("template_a")
	var template_c: Dictionary = loader.get_mvp_boss_config("template_c")
	_assert(str(template_a.get("ui_label", "")) == "Aggressive Boss", "Boss ui_label should come from boss_templates.json.", failures)
	_assert((template_a.get("battle_deck", []) as Array).size() == 5, "Boss battle deck composition should come from boss_templates.json.", failures)
	_assert(str(template_c.get("flavor_text", "__missing__")) == "", "Missing optional boss flavor_text should fall back to an empty string.", failures)

	_assert(loader.get_mvp_text("result.you_win", "") == "YOU WIN", "Result headline text should come from text_catalog.json.", failures)
	_assert(loader.get_mvp_text("missing.key", "Fallback Text") == "Fallback Text", "Missing text_catalog keys should return the provided fallback text.", failures)

	var dirty_move := MVP_BET_CARD_SCRIPT.new(loader.get_mvp_bet_card_def("dirty_move"))
	var dirty_tooltip := dirty_move.tooltip_body_for_timing(MVP_BET_CARD_SCRIPT.TIMING_POST)
	_assert(dirty_tooltip.contains("Role:"), "Fallback bet tooltip generation should include a role line.", failures)
	_assert(dirty_tooltip.contains("Effect:"), "Fallback bet tooltip generation should include an effect line.", failures)
	_assert(dirty_tooltip.contains("Condition:"), "Fallback bet tooltip generation should include a condition line.", failures)
	_assert(dirty_tooltip.contains("Cost:"), "Fallback bet tooltip generation should include a cost line.", failures)

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

	await _test_main_mvp_without_bets(failures)
	await _test_main_mvp_boss_archetype(failures)
	await _test_main_mvp_player_summary_toggle(failures)
	await _test_main_mvp_boss_summary_toggle(failures)
	await _test_main_mvp_boss_bet_reveal_placeholder_interface(failures)
	await _test_main_mvp_bet_tooltip(failures)
	await _test_main_mvp_pre_bet_selection_still_allows_battle_card(failures)
	await _test_main_mvp_post_bet_end_turn(failures)
	await _test_main_mvp_post_bet_card_then_end_turn(failures)
	await _test_main_mvp_with_bets(failures)

func _test_main_mvp_without_bets(failures: Array[String]) -> void:
	DisplayServer.window_set_size(Vector2i(1440, 900))
	await process_frame
	await process_frame
	var loader = get_root().get_node_or_null("DataLoader")
	var scene: Control = load("res://scenes/main/Main.tscn").instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame

	var controller = scene.call("get_mvp_controller")
	_assert(controller != null, "Main scene should expose its MVP controller for smoke testing.", failures)
	if controller == null:
		scene.queue_free()
		await process_frame
		return

	controller.set_bet_mode_enabled(false)
	await process_frame
	await process_frame

	var snapshot: Dictionary = controller.get_state_snapshot()
	var battle_row: HBoxContainer = _find_scene_node(scene, "ContentRoot/TableArea/PlayerArea/CardViewport/BattleHandPanel/BattleCardRow") as HBoxContainer
	var battle_deck_row: HBoxContainer = _find_scene_node(scene, "ContentRoot/TableArea/BossArea/BossCardViewport/BossBattleDeckPanel/BossBattleCardRow") as HBoxContainer
	var turn_label: Label = scene.get_node_or_null("ContentRoot/TableArea/CenterInfo/TurnLabel")
	var clash_result_label: Label = scene.get_node_or_null("ContentRoot/TableArea/ClashArea/ClashResultLabel")
	var player_slot: Control = scene.get_node_or_null("ContentRoot/TableArea/ClashArea/PlayerCardSlot")
	var boss_slot: Control = scene.get_node_or_null("ContentRoot/TableArea/ClashArea/BossCardSlot")
	var turn_result_popup: Control = scene.get_node_or_null("ContentRoot/TableArea/TurnResultPopup")
	var battle_deck_title: Label = _find_scene_node(scene, "ContentRoot/TableArea/BossArea/BossModeTitleLabel") as Label
	var reveal_status_label: Label = scene.get_node_or_null("ContentRoot/TableArea/BossArea/BossModeBar/RevealStatusLabel")
	var player_bet_area: Control = _find_scene_node(scene, "ContentRoot/TableArea/PlayerArea/CardViewport/BetHandPanel") as Control
	var boss_bet_area: Control = _find_scene_node(scene, "ContentRoot/TableArea/BossArea/BossCardViewport/BossBetDeckPanel") as Control
	var bet_phase_hint: Label = scene.get_node_or_null("ContentRoot/TableArea/BetPhaseHint")
	var bet_result_hint: Label = scene.get_node_or_null("ContentRoot/TableArea/BetResultHint")

	_assert(not bool(snapshot.get("bet_mode_enabled", true)), "Smoke should be able to disable bet mode.", failures)
	_assert(player_bet_area != null and not player_bet_area.visible, "Player bet panel should hide when bet mode is disabled.", failures)
	_assert(boss_bet_area != null and not boss_bet_area.visible, "Boss bet panel should hide when bet mode is disabled.", failures)
	_assert(bet_phase_hint != null and not bet_phase_hint.visible, "BetPhaseHint should hide when bet mode is disabled.", failures)
	_assert(bet_result_hint != null and not bet_result_hint.visible, "BetResultHint should hide when bet mode is disabled.", failures)

	if battle_row != null and battle_row.get_child_count() > 0:
		(battle_row.get_child(0) as BaseButton).emit_signal("pressed")
		await process_frame
		await process_frame

	_assert_round_feedback_active(scene, controller, failures, "A non-bet turn")
	_assert(battle_row != null and battle_row.get_child_count() == 4, "Without bet mode, playing one card should resolve immediately and remove a visible card.", failures)
	_assert(turn_label != null and turn_label.text == "Turn 1 / 5", "Without bet mode, the turn should hold during the feedback pause before advancing.", failures)
	_assert(player_slot != null and player_slot.get_child_count() == 1, "Without bet mode, clash area should show the player's current card.", failures)
	_assert(boss_slot != null and boss_slot.get_child_count() == 1, "Without bet mode, clash area should show the boss's current card.", failures)
	_assert(battle_deck_row != null and battle_deck_row.get_child_count() == 5, "Boss battle deck should keep 5 visible slots after use.", failures)

	await _wait_seconds(ROUND_FEEDBACK_WAIT)

	snapshot = controller.get_state_snapshot()
	_assert(not bool(snapshot.get("round_feedback_active", true)), "Without bet mode, round feedback should clear after the fixed pause.", failures)
	_assert(turn_label != null and turn_label.text == "Turn 2 / 5", "Without bet mode, resolving one turn should advance to Turn 2 / 5 after feedback ends.", failures)
	_assert(turn_result_popup != null and not turn_result_popup.visible, "Without bet mode, the result popup should hide again after the feedback window.", failures)
	_assert(player_slot != null and player_slot.modulate.a >= 0.98, "Without bet mode, the player clash slot should return to full opacity after result mode.", failures)
	_assert(boss_slot != null and boss_slot.modulate.a >= 0.98, "Without bet mode, the boss clash slot should return to full opacity after result mode.", failures)
	_assert(battle_deck_title != null and battle_deck_title.modulate.a >= 0.98, "Without bet mode, the boss deck title should return to full opacity after result mode.", failures)
	if reveal_status_label != null:
		_assert(reveal_status_label.modulate.a >= 0.98, "Without bet mode, the reveal status label should return to full opacity after result mode.", failures)
	var default_turn_prompt := "Choose a card to start the turn."
	if loader != null and loader.has_method("get_mvp_text"):
		default_turn_prompt = str(loader.get_mvp_text("guidance.turn_start", default_turn_prompt))
	_assert(clash_result_label != null and clash_result_label.text == default_turn_prompt, "After popup feedback ends without bet mode, the center clash label should return to the default turn prompt.", failures)

	scene.queue_free()
	await process_frame

func _test_main_mvp_boss_archetype(failures: Array[String]) -> void:
	DisplayServer.window_set_size(Vector2i(1440, 900))
	await process_frame
	await process_frame
	var loader = get_root().get_node_or_null("DataLoader")
	var scene: Control = load("res://scenes/main/Main.tscn").instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame

	var controller = scene.call("get_mvp_controller")
	_assert(controller != null, "Main scene should expose its MVP controller for boss archetype smoke testing.", failures)
	if controller == null:
		scene.queue_free()
		await process_frame
		return

	var snapshot: Dictionary = controller.get_state_snapshot()
	var template_id := str(snapshot.get("current_boss_template_id", ""))
	var boss_config: Dictionary = {}
	if loader != null and loader.has_method("get_mvp_boss_config"):
		boss_config = loader.get_mvp_boss_config(template_id)
	var expected_archetype := str(boss_config.get("archetype", MVP_BATTLE_CARD_SCRIPT.archetype_for_template(template_id)))
	var expected_ui_label := str(boss_config.get("ui_label", boss_config.get("display_name", "%s Boss" % MVP_BATTLE_CARD_SCRIPT.archetype_display_name(expected_archetype))))
	var archetype_label: Label = scene.get_node_or_null("ContentRoot/TableArea/BossArea/BossModeBar/RuntimeBossArchetypeLabel")
	_assert(str(snapshot.get("boss_archetype", "")) == expected_archetype, "Main MVP should cache the boss archetype that matches the chosen template.", failures)
	_assert(archetype_label != null, "Boss mode bar should expose the runtime boss archetype label.", failures)
	_assert(
		archetype_label != null and archetype_label.text == expected_ui_label,
		"Boss archetype label should match the chosen boss template.",
		failures
	)

	scene.queue_free()
	await process_frame

func _test_main_mvp_player_summary_toggle(failures: Array[String]) -> void:
	DisplayServer.window_set_size(Vector2i(1440, 900))
	await process_frame
	await process_frame
	var loader = get_root().get_node_or_null("DataLoader")
	var scene: Control = load("res://scenes/main/Main.tscn").instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame

	var controller = scene.call("get_mvp_controller")
	_assert(controller != null, "Main scene should expose its MVP controller for player summary smoke testing.", failures)
	if controller == null:
		scene.queue_free()
		await process_frame
		return

	var summary_button: Button = scene.get_node_or_null(PLAYER_SUMMARY_BUTTON_PATH)
	var battle_tab_button: Button = scene.get_node_or_null("ContentRoot/TableArea/PlayerArea/ModeBar/BattleTabButton")
	var battle_panel: Control = scene.get_node_or_null("ContentRoot/TableArea/PlayerArea/CardViewport/BattleHandPanel")
	var bet_panel: Control = scene.get_node_or_null("ContentRoot/TableArea/PlayerArea/CardViewport/BetHandPanel")
	var summary_panel: Control = scene.get_node_or_null("ContentRoot/TableArea/PlayerArea/CardViewport/RuntimePlayerSummaryPanel")
	var summary_label: Label = scene.get_node_or_null("ContentRoot/TableArea/PlayerArea/CardViewport/RuntimePlayerSummaryPanel/MarginContainer/RuntimePlayerSummaryLabel")

	var snapshot: Dictionary = controller.get_state_snapshot()
	_assert(summary_button != null, "The player summary button should exist for smoke testing.", failures)
	_assert(not bool(snapshot.get("player_summary_visible", true)), "Player summary should start collapsed.", failures)
	_assert(str(snapshot.get("player_view_mode", "")) == "bet", "Player should still start in Bet mode when bet mode is enabled.", failures)
	_assert(bet_panel != null and bet_panel.visible, "Player bet panel should start visible before summary toggling.", failures)

	if summary_button != null:
		summary_button.emit_signal("pressed")
		await process_frame
		await process_frame

	snapshot = controller.get_state_snapshot()
	summary_panel = scene.get_node_or_null("ContentRoot/TableArea/PlayerArea/CardViewport/RuntimePlayerSummaryPanel")
	summary_label = scene.get_node_or_null("ContentRoot/TableArea/PlayerArea/CardViewport/RuntimePlayerSummaryPanel/MarginContainer/RuntimePlayerSummaryLabel")
	var cards_label := "Cards"
	var summary_label_text := "Summary"
	var player_bet_summary_title := "Player Bet Summary"
	var player_battle_summary_title := "Player Battle Summary"
	if loader != null and loader.has_method("get_mvp_text"):
		cards_label = str(loader.get_mvp_text("labels.cards", cards_label))
		summary_label_text = str(loader.get_mvp_text("labels.summary", summary_label_text))
		player_bet_summary_title = str(loader.get_mvp_text("summary.player_bet_title", player_bet_summary_title))
		player_battle_summary_title = str(loader.get_mvp_text("summary.player_battle_title", player_battle_summary_title))
	_assert(bool(snapshot.get("player_summary_visible", false)), "The player summary button should toggle player summary visibility on.", failures)
	_assert(str(snapshot.get("player_view_mode", "")) == "bet", "Opening player summary should not change the current player view mode.", failures)
	_assert(summary_panel != null and summary_panel.visible, "Player summary toggle should show the runtime summary panel.", failures)
	_assert(summary_label != null and summary_label.visible, "Player summary toggle should show the runtime summary label.", failures)
	_assert(summary_label != null and summary_label.text.contains(player_bet_summary_title), "Player summary should reflect the current Bet mode when opened from Bet view.", failures)
	_assert(bet_panel != null and bet_panel.visible, "Opening player summary should keep the current player viewport panel visible.", failures)
	_assert(summary_button != null and summary_button.text == cards_label, "Player summary button should switch to Cards while summary is open.", failures)

	if battle_tab_button != null:
		battle_tab_button.emit_signal("pressed")
		await process_frame
		await process_frame

	snapshot = controller.get_state_snapshot()
	summary_panel = scene.get_node_or_null("ContentRoot/TableArea/PlayerArea/CardViewport/RuntimePlayerSummaryPanel")
	summary_label = scene.get_node_or_null("ContentRoot/TableArea/PlayerArea/CardViewport/RuntimePlayerSummaryPanel/MarginContainer/RuntimePlayerSummaryLabel")
	_assert(str(snapshot.get("player_view_mode", "")) == "battle", "Switching player tabs should still work while summary is open.", failures)
	_assert(bool(snapshot.get("player_summary_visible", false)), "Changing player tabs should not close the summary.", failures)
	_assert(summary_panel != null and summary_panel.visible, "Player summary panel should remain visible while switching tabs.", failures)
	_assert(summary_label != null and summary_label.visible, "Player summary label should remain visible while switching tabs.", failures)
	_assert(summary_label != null and summary_label.text.contains(player_battle_summary_title), "Player summary should refresh to the Battle summary when the view mode changes.", failures)
	_assert(summary_label != null and summary_label.text.contains("Aggression x2"), "Player battle summary should expose Aggression count.", failures)
	_assert(summary_label != null and summary_label.text.contains("Defense x1"), "Player battle summary should expose Defense count.", failures)
	_assert(summary_label != null and summary_label.text.contains("Pressure x2"), "Player battle summary should expose Pressure count.", failures)
	_assert(battle_panel != null and battle_panel.visible, "Player battle panel should stay visible while summary is open.", failures)

	if summary_button != null:
		summary_button.emit_signal("pressed")
		await process_frame
		await process_frame

	snapshot = controller.get_state_snapshot()
	summary_panel = scene.get_node_or_null("ContentRoot/TableArea/PlayerArea/CardViewport/RuntimePlayerSummaryPanel")
	summary_label = scene.get_node_or_null("ContentRoot/TableArea/PlayerArea/CardViewport/RuntimePlayerSummaryPanel/MarginContainer/RuntimePlayerSummaryLabel")
	_assert(not bool(snapshot.get("player_summary_visible", true)), "The player summary button should toggle player summary visibility off.", failures)
	_assert(summary_panel != null and not summary_panel.visible, "Closing player summary should hide the runtime summary panel.", failures)
	_assert(summary_label != null and summary_label.visible, "Closing player summary should not destroy the runtime summary label node.", failures)
	_assert(battle_panel != null and battle_panel.visible, "Closing player summary should keep the current player viewport panel visible.", failures)
	_assert(summary_button != null and summary_button.text == summary_label_text, "Player summary button should return to Summary when collapsed.", failures)

	scene.queue_free()
	await process_frame

func _test_main_mvp_bet_tooltip(failures: Array[String]) -> void:
	DisplayServer.window_set_size(Vector2i(1440, 900))
	await process_frame
	await process_frame
	var loader = get_root().get_node_or_null("DataLoader")
	var scene: Control = load("res://scenes/main/Main.tscn").instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame

	var player_bet_row: HBoxContainer = _find_scene_node(scene, "ContentRoot/TableArea/PlayerArea/CardViewport/BetHandPanel/BetCardRow") as HBoxContainer
	var hold_button: Button = null
	if player_bet_row != null:
		hold_button = player_bet_row.get_node_or_null("BetButton_hold_steady") as Button
	var tooltip_panel: Control = scene.get_node_or_null("RuntimeTooltipPanel")
	var tooltip_title: Label = scene.get_node_or_null("RuntimeTooltipPanel/MarginContainer/VBoxContainer/TitleLabel")
	var tooltip_body: Label = scene.get_node_or_null("RuntimeTooltipPanel/MarginContainer/VBoxContainer/BodyLabel")

	_assert(player_bet_row != null, "Player bet row should exist for tooltip smoke testing.", failures)
	_assert(hold_button != null, "Hold Steady button should exist for tooltip smoke testing.", failures)
	_assert(tooltip_panel != null, "Main MVP should create a runtime tooltip panel.", failures)
	if hold_button != null:
		hold_button.emit_signal("mouse_entered")
		await process_frame
		await process_frame

	var expected_hold_name := "Hold Steady"
	if loader != null and loader.has_method("get_mvp_bet_card_def"):
		expected_hold_name = str(loader.get_mvp_bet_card_def("hold_steady").get("name", expected_hold_name))
	_assert(tooltip_panel != null and tooltip_panel.visible, "Hovering a player bet card should show the tooltip panel.", failures)
	_assert(tooltip_title != null and tooltip_title.text == expected_hold_name, "Bet tooltip title should show the hovered card name.", failures)
	_assert(tooltip_body != null and tooltip_body.text.contains("Role:"), "Bet tooltip body should include a role line.", failures)
	_assert(tooltip_body != null and tooltip_body.text.contains("Effect:"), "Bet tooltip body should include an effect line.", failures)
	_assert(tooltip_body != null and tooltip_body.text.contains("Condition:"), "Bet tooltip body should include a condition line.", failures)
	_assert(tooltip_body != null and tooltip_body.text.contains("Cost:"), "Bet tooltip body should include a cost line.", failures)

	if hold_button != null:
		hold_button.emit_signal("mouse_exited")
		await process_frame
		await process_frame

	_assert(tooltip_panel != null and not tooltip_panel.visible, "Moving off a player bet card should hide the tooltip panel.", failures)

	scene.queue_free()
	await process_frame

func _test_main_mvp_boss_summary_toggle(failures: Array[String]) -> void:
	DisplayServer.window_set_size(Vector2i(1440, 900))
	await process_frame
	await process_frame
	var loader = get_root().get_node_or_null("DataLoader")
	var scene: Control = load("res://scenes/main/Main.tscn").instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame

	var controller = scene.call("get_mvp_controller")
	_assert(controller != null, "Main scene should expose its MVP controller for boss summary smoke testing.", failures)
	if controller == null:
		scene.queue_free()
		await process_frame
		return

	var summary_button: Button = scene.get_node_or_null(BOSS_SUMMARY_BUTTON_PATH)
	var boss_battle_tab_button: Button = scene.get_node_or_null("ContentRoot/TableArea/BossArea/BossModeBar/BossBattleTabButton")
	var boss_bet_tab_button: Button = scene.get_node_or_null("ContentRoot/TableArea/BossArea/BossModeBar/BossBetTabButton")
	var battle_panel: Control = scene.get_node_or_null("ContentRoot/TableArea/BossArea/BossCardViewport/BossBattleDeckPanel")
	var bet_panel: Control = scene.get_node_or_null("ContentRoot/TableArea/BossArea/BossCardViewport/BossBetDeckPanel")
	var summary_panel: Control = scene.get_node_or_null("ContentRoot/TableArea/BossArea/BossCardViewport/RuntimeBossSummaryPanel")
	var summary_label: Label = scene.get_node_or_null("ContentRoot/TableArea/BossArea/BossCardViewport/RuntimeBossSummaryPanel/MarginContainer/RuntimeBossSummaryLabel")

	var snapshot: Dictionary = controller.get_state_snapshot()
	_assert(summary_button != null, "The boss summary button should exist for smoke testing.", failures)
	_assert(str(snapshot.get("boss_view_mode", "")) == "battle", "Boss should still start in Battle mode.", failures)
	_assert(not bool(snapshot.get("boss_summary_visible", true)), "Boss summary should start collapsed.", failures)
	_assert(not bool(snapshot.get("boss_battle_revealed", true)), "Boss battle reveal should start hidden before summary toggling.", failures)
	_assert(battle_panel != null and battle_panel.visible, "Boss battle panel should start visible before summary toggling.", failures)

	if summary_button != null:
		summary_button.emit_signal("pressed")
		await process_frame
		await process_frame

	snapshot = controller.get_state_snapshot()
	summary_panel = scene.get_node_or_null("ContentRoot/TableArea/BossArea/BossCardViewport/RuntimeBossSummaryPanel")
	summary_label = scene.get_node_or_null("ContentRoot/TableArea/BossArea/BossCardViewport/RuntimeBossSummaryPanel/MarginContainer/RuntimeBossSummaryLabel")
	var cards_label := "Cards"
	var summary_label_text := "Summary"
	var boss_battle_summary_title := "Boss Battle Summary"
	var boss_bet_summary_title := "Boss Bet Summary"
	if loader != null and loader.has_method("get_mvp_text"):
		cards_label = str(loader.get_mvp_text("labels.cards", cards_label))
		summary_label_text = str(loader.get_mvp_text("labels.summary", summary_label_text))
		boss_battle_summary_title = str(loader.get_mvp_text("summary.boss_battle_title", boss_battle_summary_title))
		boss_bet_summary_title = str(loader.get_mvp_text("summary.boss_bet_title", boss_bet_summary_title))
	_assert(bool(snapshot.get("boss_summary_visible", false)), "Boss summary toggle should open the boss summary.", failures)
	_assert(str(snapshot.get("boss_view_mode", "")) == "battle", "Opening boss summary should not change the current boss view mode.", failures)
	_assert(not bool(snapshot.get("boss_battle_revealed", true)), "Opening boss summary should not reveal the boss battle deck.", failures)
	_assert(summary_panel != null and summary_panel.visible, "Boss summary toggle should show the runtime boss summary panel.", failures)
	_assert(summary_label != null and summary_label.visible, "Boss summary toggle should show the runtime boss summary label.", failures)
	_assert(summary_label != null and summary_label.text.contains(boss_battle_summary_title), "Boss summary should show the battle summary while in Battle mode.", failures)
	_assert(summary_label != null and summary_label.text.contains("Aggression remaining:"), "Boss battle summary should expose remaining Aggression count.", failures)
	_assert(summary_label != null and summary_label.text.contains("Defense remaining:"), "Boss battle summary should expose remaining Defense count.", failures)
	_assert(summary_label != null and summary_label.text.contains("Pressure remaining:"), "Boss battle summary should expose remaining Pressure count.", failures)
	_assert(battle_panel != null and battle_panel.visible, "Opening boss summary should keep the current boss viewport panel visible.", failures)
	_assert(summary_button != null and summary_button.text == cards_label, "Boss summary button should switch to Cards while summary is open.", failures)

	if boss_bet_tab_button != null:
		boss_bet_tab_button.emit_signal("pressed")
		await process_frame
		await process_frame

	snapshot = controller.get_state_snapshot()
	summary_panel = scene.get_node_or_null("ContentRoot/TableArea/BossArea/BossCardViewport/RuntimeBossSummaryPanel")
	summary_label = scene.get_node_or_null("ContentRoot/TableArea/BossArea/BossCardViewport/RuntimeBossSummaryPanel/MarginContainer/RuntimeBossSummaryLabel")
	_assert(str(snapshot.get("boss_view_mode", "")) == "bet", "BossBetTabButton should still switch the boss view mode while summary is open.", failures)
	_assert(bool(snapshot.get("boss_summary_visible", false)), "Switching boss tabs should not close the summary.", failures)
	_assert(summary_panel != null and summary_panel.visible, "Boss summary panel should stay visible while switching tabs.", failures)
	_assert(summary_label != null and summary_label.visible, "Boss summary label should stay visible while switching tabs.", failures)
	_assert(summary_label != null and summary_label.text.contains(boss_bet_summary_title), "Boss summary should refresh to the Bet placeholder while in Bet mode.", failures)
	_assert(bet_panel != null and bet_panel.visible, "Boss bet panel should stay visible while summary is open.", failures)

	if boss_battle_tab_button != null:
		boss_battle_tab_button.emit_signal("pressed")
		await process_frame
		await process_frame
	if summary_button != null:
		summary_button.emit_signal("pressed")
		await process_frame
		await process_frame

	snapshot = controller.get_state_snapshot()
	summary_panel = scene.get_node_or_null("ContentRoot/TableArea/BossArea/BossCardViewport/RuntimeBossSummaryPanel")
	summary_label = scene.get_node_or_null("ContentRoot/TableArea/BossArea/BossCardViewport/RuntimeBossSummaryPanel/MarginContainer/RuntimeBossSummaryLabel")
	_assert(str(snapshot.get("boss_view_mode", "")) == "battle", "BossBattleTabButton should still restore Battle mode after summary testing.", failures)
	_assert(not bool(snapshot.get("boss_summary_visible", true)), "Boss summary toggle should close the summary.", failures)
	_assert(not bool(snapshot.get("boss_battle_revealed", true)), "Closing boss summary should still not affect reveal state.", failures)
	_assert(summary_panel != null and not summary_panel.visible, "Closing boss summary should hide the runtime summary panel.", failures)
	_assert(summary_label != null and summary_label.visible, "Closing boss summary should not destroy the runtime summary label node.", failures)
	_assert(battle_panel != null and battle_panel.visible, "Closing boss summary should keep the current boss viewport panel visible.", failures)
	_assert(summary_button != null and summary_button.text == summary_label_text, "Boss summary button should return to Summary when collapsed.", failures)

	scene.queue_free()
	await process_frame

func _test_main_mvp_boss_bet_reveal_placeholder_interface(failures: Array[String]) -> void:
	DisplayServer.window_set_size(Vector2i(1440, 900))
	await process_frame
	await process_frame
	var scene: Control = load("res://scenes/main/Main.tscn").instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame

	var controller = scene.call("get_mvp_controller")
	_assert(controller != null, "Main scene should expose its MVP controller for boss bet reveal placeholder smoke testing.", failures)
	if controller == null:
		scene.queue_free()
		await process_frame
		return

	var snapshot: Dictionary = controller.get_state_snapshot()
	_assert(not bool(snapshot.get("boss_bet_revealed", true)), "Boss bet reveal placeholder state should start hidden.", failures)
	_assert(controller.has_method("reveal_boss_bet_deck"), "Main MVP controller should expose reveal_boss_bet_deck placeholder interface.", failures)
	_assert(controller.has_method("refresh_boss_bet_deck"), "Main MVP controller should expose refresh_boss_bet_deck placeholder interface.", failures)

	if controller.has_method("reveal_boss_bet_deck"):
		controller.call("reveal_boss_bet_deck")
		await process_frame
		await process_frame
	if controller.has_method("refresh_boss_bet_deck"):
		controller.call("refresh_boss_bet_deck")
		await process_frame
		await process_frame

	snapshot = controller.get_state_snapshot()
	_assert(bool(snapshot.get("boss_bet_revealed", false)), "Boss bet reveal placeholder interface should update the cached reveal state.", failures)

	scene.queue_free()
	await process_frame

func _test_main_mvp_pre_bet_selection_still_allows_battle_card(failures: Array[String]) -> void:
	DisplayServer.window_set_size(Vector2i(1440, 900))
	await process_frame
	await process_frame
	var scene: Control = load("res://scenes/main/Main.tscn").instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame

	var controller = scene.call("get_mvp_controller")
	_assert(controller != null, "Main scene should expose its MVP controller for Pre-Bet optionality smoke testing.", failures)
	if controller == null:
		scene.queue_free()
		await process_frame
		return

	var battle_row: HBoxContainer = _find_scene_node(scene, "ContentRoot/TableArea/PlayerArea/CardViewport/BattleHandPanel/BattleCardRow") as HBoxContainer
	var player_bet_row: HBoxContainer = _find_scene_node(scene, "ContentRoot/TableArea/PlayerArea/CardViewport/BetHandPanel/BetCardRow") as HBoxContainer
	var turn_label: Label = scene.get_node_or_null("ContentRoot/TableArea/CenterInfo/TurnLabel")
	var player_slot: Control = scene.get_node_or_null("ContentRoot/TableArea/ClashArea/PlayerCardSlot")
	var boss_slot: Control = scene.get_node_or_null("ContentRoot/TableArea/ClashArea/BossCardSlot")
	var clash_result_label: Label = scene.get_node_or_null("ContentRoot/TableArea/ClashArea/ClashResultLabel")
	var turn_result_popup: Control = scene.get_node_or_null("ContentRoot/TableArea/TurnResultPopup")
	var end_turn_button: Button = scene.get_node_or_null("ContentRoot/TableArea/EndTurn")

	var snapshot: Dictionary = controller.get_state_snapshot()
	var player_snapshot: Dictionary = snapshot.get("player", {})
	var starting_spr := int(player_snapshot.get("spr", 0))
	var positive_shift_button := player_bet_row.get_node_or_null("BetButton_positive_shift") as Button
	_assert(positive_shift_button != null, "Pre-Bet row should expose Positive Shift before the player picks a battle card.", failures)
	if positive_shift_button != null:
		positive_shift_button.emit_signal("pressed")
		await process_frame
		await process_frame

	snapshot = controller.get_state_snapshot()
	player_snapshot = snapshot.get("player", {})
	_assert(str(snapshot.get("player_bet_id", "")) == "positive_shift", "Selecting a Pre-Bet card should record that choice before battle card play.", failures)
	_assert(str(snapshot.get("player_bet_timing", "")) == "pre", "A pre-turn bet selection should stay tagged as a Pre-Bet.", failures)
	_assert(int(player_snapshot.get("spr", 0)) == starting_spr - 1, "Positive Shift should cost half-price during Pre-Bet.", failures)

	if battle_row != null and battle_row.get_child_count() > 0:
		(battle_row.get_child(0) as BaseButton).emit_signal("pressed")
		await process_frame
		await process_frame

	snapshot = controller.get_state_snapshot()
	_assert(battle_row != null and battle_row.get_child_count() == 4, "After selecting a Pre-Bet card, the player should still be able to play a battle card immediately.", failures)
	_assert_round_feedback_active(scene, controller, failures, "A Pre-Bet-assisted turn")
	_assert(not bool(snapshot.get("post_bet_window_open", false)), "The Post-Bet window should wait until round feedback finishes.", failures)
	_assert(turn_label != null and turn_label.text == "Turn 1 / 5", "A battle card picked after a Pre-Bet card should resolve immediately but stay on the same turn until EndTurn.", failures)
	_assert(player_slot != null and player_slot.get_child_count() == 1, "The clash area should show the played player card after a Pre-Bet-assisted turn.", failures)
	_assert(boss_slot != null and boss_slot.get_child_count() == 1, "The clash area should show the boss card after a Pre-Bet-assisted turn.", failures)
	_assert(clash_result_label != null and clash_result_label.text == "", "The center clash label should stay clear while the popup owns round feedback.", failures)
	_assert(turn_result_popup != null and turn_result_popup.visible, "The main action popup should appear immediately after a Pre-Bet-assisted battle card play.", failures)
	_assert(end_turn_button != null and not end_turn_button.visible, "EndTurn should stay hidden during the feedback pause before Post-Bet opens.", failures)
	_assert(str(snapshot.get("player_pre_bet_id", "")) == "positive_shift", "The chosen Pre-Bet card should stay recorded until the turn is actually ended.", failures)

	await _wait_seconds(ROUND_FEEDBACK_WAIT)

	snapshot = controller.get_state_snapshot()
	_assert(str(snapshot.get("bet_phase", "")) == "post", "After the feedback pause, a Pre-Bet-assisted battle card play should enter Post-Bet.", failures)
	_assert(bool(snapshot.get("post_bet_window_open", false)), "A resolved main action should open the Post-Bet window once feedback ends.", failures)
	_assert(end_turn_button != null and end_turn_button.visible, "EndTurn should appear once the Pre-Bet-assisted main action enters Post-Bet.", failures)

	scene.queue_free()
	await process_frame

func _test_main_mvp_post_bet_end_turn(failures: Array[String]) -> void:
	DisplayServer.window_set_size(Vector2i(1440, 900))
	await process_frame
	await process_frame
	var loader = get_root().get_node_or_null("DataLoader")
	var scene: Control = load("res://scenes/main/Main.tscn").instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame

	var controller = scene.call("get_mvp_controller")
	_assert(controller != null, "Main scene should expose its MVP controller for EndTurn smoke testing.", failures)
	if controller == null:
		scene.queue_free()
		await process_frame
		return

	var battle_row: HBoxContainer = _find_scene_node(scene, "ContentRoot/TableArea/PlayerArea/CardViewport/BattleHandPanel/BattleCardRow") as HBoxContainer
	var battle_tab_button: Button = scene.get_node_or_null("ContentRoot/TableArea/PlayerArea/ModeBar/BattleTabButton")
	var turn_label: Label = scene.get_node_or_null("ContentRoot/TableArea/CenterInfo/TurnLabel")
	var player_slot: Control = scene.get_node_or_null("ContentRoot/TableArea/ClashArea/PlayerCardSlot")
	var boss_slot: Control = scene.get_node_or_null("ContentRoot/TableArea/ClashArea/BossCardSlot")
	var battle_deck_title: Label = _find_scene_node(scene, "ContentRoot/TableArea/BossArea/BossModeTitleLabel") as Label
	var reveal_status_label: Label = scene.get_node_or_null("ContentRoot/TableArea/BossArea/BossModeBar/RevealStatusLabel")
	var clash_result_label: Label = scene.get_node_or_null("ContentRoot/TableArea/ClashArea/ClashResultLabel")
	var turn_result_popup: Control = scene.get_node_or_null("ContentRoot/TableArea/TurnResultPopup")
	var end_turn_button: Button = scene.get_node_or_null("ContentRoot/TableArea/EndTurn")

	if battle_tab_button != null:
		battle_tab_button.emit_signal("pressed")
		await process_frame
	if battle_row != null and battle_row.get_child_count() > 0:
		(battle_row.get_child(0) as BaseButton).emit_signal("pressed")
		await process_frame
		await process_frame

	var snapshot: Dictionary = controller.get_state_snapshot()
	_assert_round_feedback_active(scene, controller, failures, "A bet-enabled turn")
	_assert(str(snapshot.get("bet_phase", "")) != "post" or not bool(snapshot.get("post_bet_window_open", false)), "Post-Bet should wait until the feedback pause ends.", failures)
	_assert(battle_row != null and battle_row.get_child_count() == 4, "The player hand should shrink immediately after a battle card is committed.", failures)
	_assert(turn_label != null and turn_label.text == "Turn 1 / 5", "EndTurn should be required to advance beyond the current turn.", failures)
	_assert(player_slot != null and player_slot.get_child_count() == 1, "The clash area should already show the player's committed card before EndTurn.", failures)
	_assert(boss_slot != null and boss_slot.get_child_count() == 1, "The clash area should already show the boss card before EndTurn.", failures)
	_assert(turn_result_popup != null and turn_result_popup.visible, "TurnResultPopup should appear as soon as the main action resolves.", failures)
	_assert(end_turn_button != null and not end_turn_button.visible, "EndTurn should stay hidden until the feedback pause finishes.", failures)

	await _wait_seconds(ROUND_FEEDBACK_WAIT)

	snapshot = controller.get_state_snapshot()
	_assert(str(snapshot.get("bet_phase", "")) == "post", "Clicking a battle card should enter Post-Bet after the feedback pause.", failures)
	_assert(bool(snapshot.get("post_bet_window_open", false)), "Post-Bet should open after the feedback pause ends.", failures)
	_assert(turn_result_popup != null and not turn_result_popup.visible, "Once result mode ends, the popup should hide before Post-Bet interaction resumes.", failures)
	_assert(player_slot != null and player_slot.modulate.a >= 0.98, "Once result mode ends, the player clash slot should return to full opacity.", failures)
	_assert(boss_slot != null and boss_slot.modulate.a >= 0.98, "Once result mode ends, the boss clash slot should return to full opacity.", failures)
	_assert(battle_deck_title != null and battle_deck_title.modulate.a >= 0.98, "Once result mode ends, the boss deck title should return to full opacity.", failures)
	if reveal_status_label != null:
		_assert(reveal_status_label.modulate.a >= 0.98, "Once result mode ends, the boss reveal status label should return to full opacity.", failures)
	_assert(end_turn_button != null and end_turn_button.visible, "EndTurn should become visible during Post-Bet.", failures)
	var post_bet_guidance := "Post-Bet: play one bet card or choose End Turn."
	if loader != null and loader.has_method("get_mvp_text"):
		post_bet_guidance = str(loader.get_mvp_text("guidance.post_bet_open", post_bet_guidance))
	_assert(clash_result_label != null and clash_result_label.text == post_bet_guidance, "After the popup clears, the center clash label should switch to a short Post-Bet guidance prompt.", failures)

	if end_turn_button != null:
		end_turn_button.emit_signal("pressed")
		await process_frame
		await process_frame

	snapshot = controller.get_state_snapshot()
	_assert(str(snapshot.get("bet_phase", "")) == "pre", "Clicking EndTurn should reopen Pre-Bet for the next turn.", failures)
	_assert(not bool(snapshot.get("post_bet_window_open", true)), "Clicking EndTurn should close the Post-Bet window.", failures)
	_assert(turn_label != null and turn_label.text == "Turn 2 / 5", "Clicking EndTurn should advance to the next turn.", failures)
	_assert(end_turn_button != null and not end_turn_button.visible, "EndTurn should hide again after advancing the turn.", failures)

	scene.queue_free()
	await process_frame

func _test_main_mvp_post_bet_card_then_end_turn(failures: Array[String]) -> void:
	DisplayServer.window_set_size(Vector2i(1440, 900))
	await process_frame
	await process_frame
	var scene: Control = load("res://scenes/main/Main.tscn").instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame

	var controller = scene.call("get_mvp_controller")
	_assert(controller != null, "Main scene should expose its MVP controller for Post-Bet effect smoke testing.", failures)
	if controller == null:
		scene.queue_free()
		await process_frame
		return

	var battle_row: HBoxContainer = _find_scene_node(scene, "ContentRoot/TableArea/PlayerArea/CardViewport/BattleHandPanel/BattleCardRow") as HBoxContainer
	var battle_tab_button: Button = scene.get_node_or_null("ContentRoot/TableArea/PlayerArea/ModeBar/BattleTabButton")
	var player_bet_row: HBoxContainer = _find_scene_node(scene, "ContentRoot/TableArea/PlayerArea/CardViewport/BetHandPanel/BetCardRow") as HBoxContainer
	var turn_label: Label = scene.get_node_or_null("ContentRoot/TableArea/CenterInfo/TurnLabel")
	var bet_result_hint: Label = scene.get_node_or_null("ContentRoot/TableArea/BetResultHint")
	var end_turn_button: Button = scene.get_node_or_null("ContentRoot/TableArea/EndTurn")

	if battle_tab_button != null:
		battle_tab_button.emit_signal("pressed")
		await process_frame
	if battle_row != null and battle_row.get_child_count() > 0:
		(battle_row.get_child(0) as BaseButton).emit_signal("pressed")
		await process_frame
		await process_frame

	_assert_round_feedback_active(scene, controller, failures, "A Post-Bet test turn")
	await _wait_seconds(ROUND_FEEDBACK_WAIT)

	var snapshot: Dictionary = controller.get_state_snapshot()
	_assert(str(snapshot.get("bet_phase", "")) == "post", "Post-Bet card testing should begin after the round feedback pause opens Post-Bet.", failures)
	_assert(bool(snapshot.get("post_bet_window_open", false)), "Post-Bet card testing should start with the Post-Bet window open.", failures)
	var winner := str(snapshot.get("current_round_winner", ""))
	var player_before: Dictionary = snapshot.get("player", {})
	var boss_before: Dictionary = snapshot.get("boss", {})
	var chosen_post_bet_id := "positive_shift"
	if winner == "boss":
		chosen_post_bet_id = "dirty_move"

	var post_bet_button := player_bet_row.get_node_or_null("BetButton_%s" % chosen_post_bet_id) as Button
	_assert(post_bet_button != null, "The requested Post-Bet button should be available during the Post-Bet window.", failures)
	if post_bet_button != null:
		post_bet_button.emit_signal("pressed")
		await process_frame
		await process_frame

	snapshot = controller.get_state_snapshot()
	var player_after_post: Dictionary = snapshot.get("player", {})
	var boss_after_post: Dictionary = snapshot.get("boss", {})
	_assert(bool(snapshot.get("post_bet_effects_applied", false)), "Selecting a Post-Bet card should apply Post-Bet effects immediately.", failures)
	_assert(str(snapshot.get("player_post_bet_id", "")) == chosen_post_bet_id, "The selected Post-Bet card should be recorded separately from Pre-Bet.", failures)
	_assert(str(snapshot.get("bet_phase", "")) == "post", "Selecting a Post-Bet card should not close the Post-Bet window by itself.", failures)
	_assert(turn_label != null and turn_label.text == "Turn 1 / 5", "Selecting a Post-Bet card should not advance the turn before EndTurn.", failures)
	_assert(end_turn_button != null and end_turn_button.visible, "EndTurn should remain visible after a Post-Bet card is used.", failures)
	_assert(int(player_after_post.get("spr", 0)) == int(player_before.get("spr", 0)) - 2, "A non-free Post-Bet card should use full cost immediately.", failures)
	if winner == "player":
		_assert(int(boss_after_post.get("hp", 0)) < int(boss_before.get("hp", 0)), "A winning Positive Shift Post-Bet should immediately reduce boss HP further.", failures)
	elif winner == "boss":
		_assert(int(player_after_post.get("hp", 0)) < int(player_before.get("hp", 0)), "A losing Dirty Move Post-Bet should immediately backfire on the player.", failures)
	if bet_result_hint != null and not str(bet_result_hint.text).is_empty():
		_assert(_is_valid_bet_result_text(str(bet_result_hint.text)), "Post-Bet effect text should stay in the expected compact format.", failures)

	if end_turn_button != null:
		end_turn_button.emit_signal("pressed")
		await process_frame
		await process_frame

	snapshot = controller.get_state_snapshot()
	_assert(str(snapshot.get("bet_phase", "")) == "pre", "After a Post-Bet card is applied, EndTurn should still be the action that advances the turn.", failures)
	_assert(turn_label != null and turn_label.text == "Turn 2 / 5", "EndTurn should advance the turn after Post-Bet effects have already been applied.", failures)
	_assert(end_turn_button != null and not end_turn_button.visible, "EndTurn should hide once the next turn begins.", failures)

	scene.queue_free()
	await process_frame

func _test_main_mvp_with_bets(failures: Array[String]) -> void:
	DisplayServer.window_set_size(Vector2i(1440, 900))
	await process_frame
	await process_frame
	var loader = get_root().get_node_or_null("DataLoader")
	var scene: Control = load("res://scenes/main/Main.tscn").instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame

	var controller = scene.call("get_mvp_controller")
	_assert(controller != null, "Main scene should expose its MVP controller for bet smoke testing.", failures)
	if controller == null:
		scene.queue_free()
		await process_frame
		return

	var round_label: Label = scene.get_node_or_null("ContentRoot/TableArea/CenterInfo/RoundLabel")
	var turn_label: Label = scene.get_node_or_null("ContentRoot/TableArea/CenterInfo/TurnLabel")
	var battle_row: HBoxContainer = _find_scene_node(scene, "ContentRoot/TableArea/PlayerArea/CardViewport/BattleHandPanel/BattleCardRow") as HBoxContainer
	var battle_tab_button: Button = scene.get_node_or_null("ContentRoot/TableArea/PlayerArea/ModeBar/BattleTabButton")
	var boss_battle_tab_button: Button = scene.get_node_or_null("ContentRoot/TableArea/BossArea/BossModeBar/BossBattleTabButton")
	var boss_bet_tab_button: Button = scene.get_node_or_null("ContentRoot/TableArea/BossArea/BossModeBar/BossBetTabButton")
	var reveal_button: Button = scene.get_node_or_null("ContentRoot/TableArea/BossArea/BossCardViewport/BossBattleDeckPanel/RevealBattleDeckButton")
	var battle_deck_row: HBoxContainer = _find_scene_node(scene, "ContentRoot/TableArea/BossArea/BossCardViewport/BossBattleDeckPanel/BossBattleCardRow") as HBoxContainer
	var player_slot: Control = scene.get_node_or_null("ContentRoot/TableArea/ClashArea/PlayerCardSlot")
	var boss_slot: Control = scene.get_node_or_null("ContentRoot/TableArea/ClashArea/BossCardSlot")
	var clash_result_label: Label = scene.get_node_or_null("ContentRoot/TableArea/ClashArea/ClashResultLabel")
	var player_bet_area: Control = _find_scene_node(scene, "ContentRoot/TableArea/PlayerArea/CardViewport/BetHandPanel") as Control
	var boss_bet_area: Control = _find_scene_node(scene, "ContentRoot/TableArea/BossArea/BossCardViewport/BossBetDeckPanel") as Control
	var player_bet_row: HBoxContainer = _find_scene_node(scene, "ContentRoot/TableArea/PlayerArea/CardViewport/BetHandPanel/BetCardRow") as HBoxContainer
	var boss_bet_row: HBoxContainer = _find_scene_node(scene, "ContentRoot/TableArea/BossArea/BossCardViewport/BossBetDeckPanel/BossBetCard") as HBoxContainer
	var bet_phase_hint: Label = scene.get_node_or_null("ContentRoot/TableArea/BetPhaseHint")
	var bet_result_hint: Label = scene.get_node_or_null("ContentRoot/TableArea/BetResultHint")
	var reveal_status_label: Label = scene.get_node_or_null("ContentRoot/TableArea/BossArea/BossModeBar/RevealStatusLabel")
	var boss_archetype_label: Label = scene.get_node_or_null("ContentRoot/TableArea/BossArea/BossModeBar/RuntimeBossArchetypeLabel")
	var turn_result_popup: Control = scene.get_node_or_null("ContentRoot/TableArea/TurnResultPopup")
	var end_turn_button: Button = scene.get_node_or_null("ContentRoot/TableArea/EndTurn")
	var pre_bet_phase_text := "Pre-Bet Phase"
	var battle_label := "Battle"
	var bet_label := "Bet"
	var revealed_label := "Revealed"
	if loader != null and loader.has_method("get_mvp_text"):
		pre_bet_phase_text = str(loader.get_mvp_text("phase.pre_bet", pre_bet_phase_text))
		battle_label = str(loader.get_mvp_text("labels.battle", battle_label))
		bet_label = str(loader.get_mvp_text("labels.bet", bet_label))
		revealed_label = str(loader.get_mvp_text("labels.revealed", revealed_label))

	_assert(round_label != null and round_label.text == "Round 1 / 3", "Main MVP should start at Round 1 / 3.", failures)
	_assert(turn_label != null and turn_label.text == "Turn 1 / 5", "Main MVP should start at Turn 1 / 5.", failures)
	_assert(player_bet_area != null and player_bet_area.visible, "Player bet panel should be visible when bet mode is enabled.", failures)
	_assert(boss_bet_area != null and not boss_bet_area.visible, "Boss bet panel should start hidden until the boss switches to bet mode.", failures)
	_assert(bet_phase_hint != null and bet_phase_hint.text == pre_bet_phase_text, "Bet mode should start in Pre-Bet phase.", failures)
	_assert(boss_battle_tab_button != null and boss_battle_tab_button.text == battle_label, "BossBattleTabButton should exist as the battle mode switch.", failures)
	_assert(boss_bet_tab_button != null and boss_bet_tab_button.text == bet_label, "BossBetTabButton should exist as the bet mode switch.", failures)
	_assert(player_bet_row != null and player_bet_row.get_child_count() == 3, "Player should see 3 minimal bet cards in bet mode.", failures)
	_assert(battle_row != null and battle_row.get_child_count() == 5, "Main MVP should spawn 5 player cards in the battle row.", failures)
	_assert(battle_deck_row != null and battle_deck_row.get_child_count() == 5, "Boss battle deck should always expose 5 slots.", failures)
	_assert(boss_bet_row != null, "Boss bet row should still exist in the revamped UI.", failures)

	if battle_row != null:
		var expected_player_hand := ["Aggression", "Aggression", "Defense", "Pressure", "Pressure"]
		var actual_player_hand: Array[String] = []
		for child in battle_row.get_children():
			if child.has_method("get_card_data"):
				actual_player_hand.append(str(child.get_card_data().get("display_name", "")))
		_assert(actual_player_hand == expected_player_hand, "Player hand should be the fixed 2-1-2 template.", failures)

	var snapshot: Dictionary = controller.get_state_snapshot()
	var template_id := str(snapshot.get("current_boss_template_id", ""))
	var boss_config: Dictionary = {}
	if loader != null and loader.has_method("get_mvp_boss_config"):
		boss_config = loader.get_mvp_boss_config(template_id)
	_assert(not boss_config.is_empty(), "Boss should choose one of the configured MVP templates.", failures)
	_assert(
		str(snapshot.get("boss_archetype", "")) == str(boss_config.get("archetype", MVP_BATTLE_CARD_SCRIPT.archetype_for_template(template_id))),
		"Boss archetype snapshot should align with the selected template.",
		failures
	)
	_assert(
		boss_archetype_label != null and boss_archetype_label.text == str(boss_config.get("ui_label", boss_config.get("display_name", ""))),
		"Runtime boss archetype label should expose the selected light personality.",
		failures
	)

	if player_bet_row != null:
		var pre_cost_labels := _collect_button_texts(player_bet_row)
		_assert(pre_cost_labels == [
			"Hold Steady (0 SPR)",
			"Positive Shift (1 SPR)",
			"Dirty Move (1 SPR)",
		], "Pre-Bet labels should show half-cost pricing.", failures)

	if battle_deck_row != null and battle_deck_row.get_child_count() > 0:
		var first_battle_deck_card = battle_deck_row.get_child(0)
		_assert(first_battle_deck_card.has_method("get_view_state"), "Boss battle deck cards should expose a view state for testing.", failures)
		if first_battle_deck_card.has_method("get_view_state"):
			_assert(first_battle_deck_card.get_view_state() == "hidden", "Boss battle deck should start hidden.", failures)

	if boss_bet_tab_button != null:
		boss_bet_tab_button.emit_signal("pressed")
		await process_frame
		await process_frame

	snapshot = controller.get_state_snapshot()
	_assert(str(snapshot.get("boss_view_mode", "")) == "bet", "BossBetTabButton should only switch the boss view mode to Bet.", failures)
	_assert(not bool(snapshot.get("boss_battle_revealed", true)), "Switching to Boss Bet view should not reveal the battle deck.", failures)
	_assert(boss_bet_area != null and boss_bet_area.visible, "Boss bet panel should become visible after switching to Bet mode.", failures)
	_assert(battle_deck_row != null and battle_deck_row.get_child_count() == 5, "Switching boss tabs should not disturb the battle deck row structure.", failures)

	if boss_battle_tab_button != null:
		boss_battle_tab_button.emit_signal("pressed")
		await process_frame
		await process_frame

	snapshot = controller.get_state_snapshot()
	_assert(str(snapshot.get("boss_view_mode", "")) == "battle", "BossBattleTabButton should only switch the boss view mode to Battle.", failures)
	_assert(not bool(snapshot.get("boss_battle_revealed", true)), "Switching back to Boss Battle view should still not reveal the deck.", failures)
	_assert(boss_bet_area != null and not boss_bet_area.visible, "Boss bet panel should hide again after returning to Battle mode.", failures)

	if reveal_button != null:
		reveal_button.emit_signal("pressed")
		await process_frame
		await process_frame

	if battle_deck_row != null:
		var revealed_names: Array[String] = []
		for child in battle_deck_row.get_children():
			if child.has_method("get_card_data"):
				revealed_names.append(str(child.get_card_data().get("display_name", "")))
		var reveal_snapshot: Dictionary = controller.get_state_snapshot()
		var reveal_template_id := str(reveal_snapshot.get("current_boss_template_id", ""))
		var reveal_config: Dictionary = {}
		var expected_revealed_names: Array[String] = []
		if loader != null and loader.has_method("get_mvp_boss_config"):
			reveal_config = loader.get_mvp_boss_config(reveal_template_id)
			for card_type in reveal_config.get("battle_deck", []):
				expected_revealed_names.append(MVP_BATTLE_CARD_SCRIPT.display_name_for_type(str(card_type)))
		_assert(bool(reveal_snapshot.get("boss_battle_revealed", false)), "RevealBattleDeckButton should only flip the boss battle reveal state.", failures)
		_assert(str(reveal_snapshot.get("boss_view_mode", "")) == "battle", "RevealBattleDeckButton should not switch away from battle mode.", failures)
		_assert(reveal_status_label != null and reveal_status_label.text == revealed_label, "RevealStatusLabel should track the battle deck reveal state.", failures)
		_assert(revealed_names == expected_revealed_names, "Reveal should expose exactly the configured boss template deck.", failures)
		for child in battle_deck_row.get_children():
			if child.has_method("get_view_state"):
				_assert(child.get_view_state() == "normal", "Reveal should switch every unused boss deck slot to normal.", failures)

	if battle_tab_button != null:
		battle_tab_button.emit_signal("pressed")
		await process_frame
	if battle_row != null and battle_row.get_child_count() > 0:
		(battle_row.get_child(0) as BaseButton).emit_signal("pressed")
		await process_frame
		await process_frame

	snapshot = controller.get_state_snapshot()
	_assert_round_feedback_active(scene, controller, failures, "A bet-enabled main action")
	_assert(not bool(snapshot.get("post_bet_window_open", false)), "The main action should pause in round feedback before Post-Bet opens.", failures)
	_assert(turn_label != null and turn_label.text == "Turn 1 / 5", "Turn should not advance until EndTurn resolves the Post-Bet window.", failures)
	_assert(battle_row != null and battle_row.get_child_count() == 4, "The hand should shrink immediately after the battle card is committed.", failures)
	_assert(player_slot != null and player_slot.get_child_count() == 1, "Clash area should show the player's card immediately after the main action resolves.", failures)
	_assert(boss_slot != null and boss_slot.get_child_count() == 1, "Boss clash slot should show the boss card immediately after the main action resolves.", failures)
	_assert(turn_result_popup != null and turn_result_popup.visible, "TurnResultPopup should appear immediately after the main action resolves.", failures)
	_assert(end_turn_button != null and not end_turn_button.visible, "EndTurn should stay hidden until the round feedback pause ends.", failures)

	await _wait_seconds(ROUND_FEEDBACK_WAIT)

	snapshot = controller.get_state_snapshot()
	_assert(str(snapshot.get("bet_phase", "")) == "post", "Playing a card without a pre-bet should open Post-Bet after the feedback pause.", failures)
	_assert(bool(snapshot.get("post_bet_window_open", false)), "The main action should resolve into an open Post-Bet window after feedback.", failures)
	_assert(end_turn_button != null and end_turn_button.visible, "EndTurn should appear during the Post-Bet window.", failures)
	if boss_bet_row != null and str(snapshot.get("boss_bet_id", "")).is_empty():
		_assert(boss_bet_row.get_child_count() == 0, "Boss bet row should stay empty when the boss did not lock a Post-Bet card.", failures)
	elif boss_bet_row != null:
		_assert(boss_bet_row.get_child_count() == 1, "Boss bet row should show exactly one locked Post-Bet card when the boss commits one.", failures)

	if player_bet_row != null:
		var post_cost_labels := _collect_button_texts(player_bet_row)
		_assert(post_cost_labels == [
			"Hold Steady (0 SPR)",
			"Positive Shift (2 SPR)",
			"Dirty Move (2 SPR)",
		], "Post-Bet labels should show full-cost pricing.", failures)
		var hold_button := player_bet_row.get_node_or_null("BetButton_hold_steady") as Button
		_assert(hold_button != null, "Player bet row should still include Hold Steady as a normal Post-Bet card.", failures)
		if hold_button != null:
			hold_button.emit_signal("pressed")
			await process_frame
			await process_frame

	snapshot = controller.get_state_snapshot()
	_assert(bool(snapshot.get("post_bet_effects_applied", false)), "Selecting a Post-Bet card should immediately apply the Post-Bet effects.", failures)
	_assert(str(snapshot.get("player_post_bet_id", "")) == "hold_steady", "Hold Steady should be tracked as a normal Post-Bet card selection.", failures)
	_assert(str(snapshot.get("bet_phase", "")) == "post", "Hold Steady should no longer end the turn by itself.", failures)
	_assert(turn_label != null and turn_label.text == "Turn 1 / 5", "Hold Steady should no longer advance the turn by itself.", failures)
	_assert(clash_result_label != null and clash_result_label.text == "Choose End Turn to continue.", "After a Post-Bet choice is locked, the center clash label should switch to a short EndTurn prompt.", failures)
	_assert(end_turn_button != null and end_turn_button.visible, "EndTurn should remain visible after Hold Steady because Hold Steady is not the turn-end control.", failures)

	if end_turn_button != null:
		end_turn_button.emit_signal("pressed")
		await process_frame
		await process_frame

	snapshot = controller.get_state_snapshot()
	_assert(str(snapshot.get("bet_phase", "")) == "pre", "After EndTurn, bet phase should reset to Pre-Bet for the next turn.", failures)
	_assert(battle_row != null and battle_row.get_child_count() == 4, "Ending the turn after Post-Bet should keep the already-consumed battle card removed.", failures)
	_assert(turn_label != null and turn_label.text == "Turn 2 / 5", "EndTurn should advance the turn once Post-Bet is done.", failures)
	_assert(player_slot != null and player_slot.get_child_count() == 1, "Clash area should still show the latest resolved player card after EndTurn.", failures)
	_assert(boss_slot != null and boss_slot.get_child_count() == 1, "Clash area should still show the latest resolved boss card after EndTurn.", failures)
	_assert(clash_result_label != null and clash_result_label.text == "Optional: place a bet first.", "After EndTurn starts the next turn, the center clash label should return to the new-turn guidance prompt.", failures)
	_assert(battle_deck_row != null and battle_deck_row.get_child_count() == 5, "Boss battle deck should keep 5 visible slots after use.", failures)
	_assert(end_turn_button != null and not end_turn_button.visible, "EndTurn should hide again once the next turn begins.", failures)
	_assert(
		bet_result_hint != null and _is_valid_bet_result_text(str(bet_result_hint.text)),
		"BetResultHint should report a compact turn bet result after Hold Steady no longer ends the turn.",
		failures
	)

	if battle_deck_row != null:
		var used_found := false
		for child in battle_deck_row.get_children():
			if child.has_method("get_view_state") and child.get_view_state() == "used":
				used_found = true
				break
		_assert(used_found, "A boss battle deck slot should turn used after the boss plays a card.", failures)

	controller.call("_reset_for_current_set")
	await process_frame
	await process_frame
	snapshot = controller.get_state_snapshot()
	_assert(not bool(snapshot.get("boss_battle_revealed", true)), "A new set should reset battle deck reveal state even when bet mode is on.", failures)
	_assert(str(snapshot.get("bet_phase", "")) == "pre", "A new set should reopen Pre-Bet when bet mode is enabled.", failures)
	_assert(str(snapshot.get("player_bet_id", "")) == "", "A new set should clear player bet selection.", failures)
	_assert(str(snapshot.get("boss_bet_id", "")) == "", "A new set should clear boss bet selection.", failures)
	scene.queue_free()
	await process_frame

func _collect_button_texts(row: HBoxContainer) -> Array[String]:
	var texts: Array[String] = []
	if row == null:
		return texts
	for child in row.get_children():
		if child is Button:
			texts.append((child as Button).text)
	return texts

func _is_valid_bet_result_text(text: String) -> bool:
	if text == "No Bet":
		return true
	var valid_segments := [
		"+1 Damage (Positive)",
		"+2 Damage (Dirty)",
		"Backfired: -1 HP",
		"Boss +1 Damage (Positive)",
		"Boss +2 Damage (Dirty)",
		"Boss Backfired: -1 HP",
	]
	for segment in text.split(" | "):
		if not valid_segments.has(segment):
			return false
	return not text.is_empty()

func _wait_seconds(seconds: float) -> void:
	await create_timer(seconds).timeout
	await process_frame
	await process_frame

func _assert_round_feedback_active(scene: Control, controller, failures: Array[String], context: String) -> void:
	var snapshot: Dictionary = controller.get_state_snapshot()
	var popup: Control = scene.get_node_or_null("ContentRoot/TableArea/TurnResultPopup")
	var popup_backdrop: ColorRect = scene.get_node_or_null("ContentRoot/TableArea/TurnResultPopup/RuntimeResultBackdrop")
	var headline_label: Label = scene.get_node_or_null("ContentRoot/TableArea/TurnResultPopup/RuntimeResultHeadlineLabel")
	var feedback_label: Label = scene.get_node_or_null("ContentRoot/TableArea/TurnResultPopup/FeedbackLabel")
	var center_info: Control = scene.get_node_or_null("ContentRoot/TableArea/CenterInfo")
	var clash_result_label: Label = scene.get_node_or_null("ContentRoot/TableArea/ClashArea/ClashResultLabel")
	var player_slot: Control = scene.get_node_or_null("ContentRoot/TableArea/ClashArea/PlayerCardSlot")
	var boss_slot: Control = scene.get_node_or_null("ContentRoot/TableArea/ClashArea/BossCardSlot")
	var bet_phase_hint: Label = scene.get_node_or_null("ContentRoot/TableArea/BetPhaseHint")
	var bet_result_hint: Label = scene.get_node_or_null("ContentRoot/TableArea/BetResultHint")
	var battle_deck_title: Label = _find_scene_node(scene, "ContentRoot/TableArea/BossArea/BossModeTitleLabel") as Label
	var reveal_status_label: Label = scene.get_node_or_null("ContentRoot/TableArea/BossArea/BossModeBar/RevealStatusLabel")
	var end_turn_button: Button = scene.get_node_or_null("ContentRoot/TableArea/EndTurn")
	_assert(bool(snapshot.get("round_feedback_active", false)), "%s should enter round feedback mode immediately after the clash resolves." % context, failures)
	_assert(popup != null and popup.visible, "%s should show TurnResultPopup during round feedback." % context, failures)
	_assert(popup != null and popup.z_index > 0, "%s should raise the result popup above the battle table during round feedback." % context, failures)
	_assert(popup_backdrop != null and popup_backdrop.visible, "%s should show the runtime popup backdrop during round feedback." % context, failures)
	_assert(headline_label != null and _feedback_has_headline(str(headline_label.text)), "%s should move the main result headline into the dedicated popup headline label." % context, failures)
	_assert(feedback_label != null and feedback_label.text.contains("You:"), "%s should show the compact matchup line in the popup body." % context, failures)
	_assert(feedback_label != null and feedback_label.text.contains("Boss:"), "%s should show the boss card in the compact popup body." % context, failures)
	_assert(feedback_label != null and _count_non_empty_lines(str(feedback_label.text)) <= 3, "%s should keep popup body text to at most three non-empty lines." % context, failures)
	_assert(feedback_label != null and not _feedback_has_headline(str(feedback_label.text)), "%s should keep the main result headline out of the popup body text." % context, failures)
	_assert(player_slot != null and player_slot.modulate.a >= 0.40 and player_slot.modulate.a <= 0.44, "%s should dim the player clash slot during result mode." % context, failures)
	_assert(boss_slot != null and boss_slot.modulate.a >= 0.40 and boss_slot.modulate.a <= 0.44, "%s should dim the boss clash slot during result mode." % context, failures)
	_assert(clash_result_label != null and not clash_result_label.visible, "%s should hide the center clash hint label during result mode." % context, failures)
	_assert(clash_result_label != null and not _label_contains_round_report(str(clash_result_label.text)), "%s should keep detailed round-report text out of the center clash label." % context, failures)
	_assert(center_info != null and not center_info.visible, "%s should hide CenterInfo during round feedback." % context, failures)
	_assert(bet_phase_hint != null and not bet_phase_hint.visible, "%s should hide BetPhaseHint during result mode." % context, failures)
	_assert(bet_result_hint != null and not bet_result_hint.visible, "%s should hide BetResultHint during result mode." % context, failures)
	_assert(battle_deck_title != null and battle_deck_title.modulate.a >= 0.33 and battle_deck_title.modulate.a <= 0.37, "%s should dim the boss deck title during result mode." % context, failures)
	if reveal_status_label != null:
		_assert(reveal_status_label.modulate.a >= 0.33 and reveal_status_label.modulate.a <= 0.37, "%s should dim the boss reveal status label during result mode." % context, failures)
	_assert(end_turn_button != null and not end_turn_button.visible, "%s should keep EndTurn hidden during the feedback pause." % context, failures)

func _feedback_has_headline(text: String) -> bool:
	return text.contains("YOU WIN") or text.contains("YOU LOSE") or text.contains("DRAW")

func _label_contains_round_report(text: String) -> bool:
	return (
		text.contains("YOU WIN")
		or text.contains("YOU LOSE")
		or text.contains("DRAW")
		or text.contains("You played")
		or text.contains("Boss played")
		or text.contains("Power:")
		or text.contains("remaining:")
	)

func _count_non_empty_lines(text: String) -> int:
	var count := 0
	for line in text.split("\n"):
		if not line.strip_edges().is_empty():
			count += 1
	return count

func _test_main_mvp_layout(size: Vector2i, failures: Array[String]) -> void:
	DisplayServer.window_set_size(size)
	await process_frame
	await process_frame

	var scene: Control = load("res://scenes/main/Main.tscn").instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame

	var viewport_size := scene.get_viewport_rect().size
	var reveal_button: Control = scene.get_node_or_null("ContentRoot/TableArea/BossArea/BossCardViewport/BossBattleDeckPanel/RevealBattleDeckButton")
	var battle_deck_row: HBoxContainer = _find_scene_node(scene, "ContentRoot/TableArea/BossArea/BossCardViewport/BossBattleDeckPanel/BossBattleCardRow") as HBoxContainer
	var battle_row: HBoxContainer = _find_scene_node(scene, "ContentRoot/TableArea/PlayerArea/CardViewport/BattleHandPanel/BattleCardRow") as HBoxContainer
	var overlay_ui: Control = scene.get_node_or_null("ContentRoot/OverlayUI")
	var player_hp: Control = scene.get_node_or_null("ContentRoot/TableArea/PlayerHP")
	var boss_hp: Control = scene.get_node_or_null("ContentRoot/TableArea/BossHP")
	var boss_portrait: Control = _find_scene_node(scene, "ContentRoot/TableArea/BossArea/BossPortrait") as Control
	var table_board: Control = scene.get_node_or_null("ContentRoot/TableArea/TableBoard")
	var player_status_panel: Control = scene.get_node_or_null("ContentRoot/TableArea/PlayerStatusPanel")
	var boss_status_panel: Control = scene.get_node_or_null("ContentRoot/TableArea/BossStatusPanel")

	_assert_control_within_viewport(reveal_button, viewport_size, "RevealBattleDeckButton should stay inside the viewport at %s." % size, failures)
	_assert_control_within_viewport(battle_deck_row, viewport_size, "BattleDeckRow should stay inside the viewport at %s." % size, failures)
	_assert_control_within_viewport(battle_row, viewport_size, "BattleCardRow should stay inside the viewport at %s." % size, failures)
	_assert_control_within_viewport(overlay_ui, viewport_size, "OverlayUI should stay inside the viewport at %s." % size, failures)
	_assert_control_within_viewport(player_hp, viewport_size, "PlayerHP should stay inside the viewport at %s." % size, failures)
	_assert_control_within_viewport(boss_hp, viewport_size, "BossHP should stay inside the viewport at %s." % size, failures)
	_assert_control_within_viewport(boss_portrait, viewport_size, "BossPortrait should stay inside the viewport at %s." % size, failures)
	_assert_control_within_viewport(table_board, viewport_size, "TableBoard should stay inside the viewport at %s." % size, failures)
	_assert_control_within_viewport(player_status_panel, viewport_size, "PlayerStatusPanel should stay inside the viewport at %s." % size, failures)
	_assert_control_within_viewport(boss_status_panel, viewport_size, "BossStatusPanel should stay inside the viewport at %s." % size, failures)

	if battle_row != null:
		_assert(battle_row.get_child_count() == 5, "Main MVP should still show 5 player cards at %s." % size, failures)
		for child in battle_row.get_children():
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

func _find_scene_node(scene: Node, path: String) -> Node:
	return scene.get_node_or_null(path)

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

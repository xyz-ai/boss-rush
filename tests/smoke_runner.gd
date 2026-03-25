extends SceneTree

const RUN_STATE_SCRIPT := preload("res://scripts/core/RunState.gd")
const BATTLE_RESOLVER_SCRIPT := preload("res://scripts/core/BattleResolver.gd")
const PEEK_SYSTEM_SCRIPT := preload("res://scripts/systems/PeekSystem.gd")
const ADDON_SYSTEM_SCRIPT := preload("res://scripts/systems/AddonSystem.gd")
const BOSS_AI_SCRIPT := preload("res://scripts/core/BossAI.gd")
const MATCHUP_RULES_SCRIPT := preload("res://scripts/core/MatchupRules.gd")

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
	await _test_scene_instancing(loader, failures)

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

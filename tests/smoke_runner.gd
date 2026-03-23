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
	await _test_scene_instancing(failures)

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
	state.begin_round(["tl_pressure", "tl_procedure", "tl_alignment"])
	var result = resolver.resolve_round(state, "g_steady", "tl_procedure", {"addon_id": "", "cover": 0})
	_assert(result.get("margin", 0) == 2, "Growth vs defense should create +2 margin.", failures)
	_assert(state.current_set_state.next_bonus == 1, "G-Steady should set Next +1.", failures)
	_assert(state.current_set_state.boss_hp == 4, "Boss HP should drop by 2 on the opening win.", failures)
	_assert(not "g_steady" in state.current_set_state.remaining_player_battle_cards, "Played battle cards should leave the current set hand.", failures)

	state = _fresh_state(loader)
	state.begin_round(["tl_pressure", "tl_procedure", "tl_alignment"])
	result = resolver.resolve_round(state, "c_audit", "tl_pressure", {"addon_id": "", "cover": 0})
	_assert(result.get("margin", 0) == 1, "C-Audit vs aggression should end with +1 margin.", failures)

	state = _fresh_state(loader)
	state.begin_round(["tl_pressure", "tl_procedure", "tl_alignment"])
	result = resolver.resolve_round(state, "g_burst", "tl_pressure", {"addon_id": "stop_loss", "cover": 0})
	_assert(result.get("player_damage", 0) == 1, "StopLoss should cap round damage to 1 HP.", failures)
	_assert(state.current_set_state.next_penalty == 1, "G-Burst should set Next -1.", failures)

	state = _fresh_state(loader)
	state.begin_round(["tl_pressure", "tl_procedure", "tl_alignment"])
	result = resolver.resolve_round(state, "g_steady", "tl_procedure", {"addon_id": "leverage", "cover": 0})
	_assert(result.get("boss_damage", 0) == 3, "Leverage should add 1 extra boss damage on a winning round.", failures)
	_assert(result.get("pos_after", 0) == 3, "Leverage should also add +1 POS on top of the round margin.", failures)

	state = _fresh_state(loader)
	state.current_set_state.player_hp = 3
	state.current_set_state.boss_hp = 3
	state.current_set_state.round_index = 4
	state.current_set_state.remaining_player_battle_cards.clear()
	state.current_set_state.remaining_player_battle_cards.append("d_cover")
	state.begin_round(["tl_procedure"])
	result = resolver.resolve_round(state, "d_cover", "tl_procedure", {"addon_id": "", "cover": 0})
	_assert(result.get("set_finished", false), "Fifth round should finish the set.", failures)
	_assert(result.get("set_winner", "") == "boss", "Configured tie winner should favor the boss.", failures)

	state = _fresh_state(loader)
	state.begin_round(["tl_pressure", "tl_procedure", "tl_alignment"])
	var addon_result = addon_system.activate_addon(state, "intel")
	_assert(addon_result.get("ok", false), "Intel should be activatable inside a round.", failures)
	_assert(int(state.get_remaining_addons().get("intel", 0)) == 0, "Activated addons should be consumed for the whole challenge.", failures)
	state.start_set(challenge_rules)
	_assert(int(state.get_remaining_addons().get("intel", 0)) == 0, "Addons should not refresh between sets.", failures)
	_assert(state.current_set_state.remaining_player_battle_cards.size() == 5, "A new set should restore the five-card hand.", failures)

	state = _fresh_state(loader)
	state.challenge_state.player_set_wins = 1
	var finish_info = state.finish_set("player")
	_assert(finish_info.get("challenge_finished", false), "Second set win should end the challenge immediately.", failures)
	_assert(finish_info.get("challenge_winner", "") == "player", "Player should win the challenge after two set wins.", failures)

	state = _fresh_state(loader)
	state.spr = 1
	state.begin_round(["tl_pressure", "tl_procedure", "tl_alignment"])
	peek_system.peek_pool(state, state.current_set_state.current_pool)
	_assert(state.is_failed(), "Run should fail immediately when SPR reaches zero.", failures)

func _test_ai(loader, failures: Array[String]) -> void:
	var state = _fresh_state(loader)
	var boss_def: Dictionary = loader.get_boss("team_lead")
	var ai = BOSS_AI_SCRIPT.new(loader.get_balance("matchup_rules", {}))
	ai.set_seed(1337)

	var pool = ai.prepare_pool(boss_def, state)
	_assert(pool.size() == 3, "Boss pool size should be 3.", failures)
	for card_id in pool:
		_assert(card_id in boss_def.get("deck", []), "Boss pool should only contain deck cards.", failures)

	var counts = {"counter": 0, "neutral": 0, "wrong": 0}
	var rules = MATCHUP_RULES_SCRIPT.new(loader.get_balance("matchup_rules", {}))
	for _index in range(300):
		var pick = ai.pick_card(["tl_pressure", "tl_alignment", "tl_procedure"], "growth", state)
		var category = rules.categorize(loader.get_boss_card(pick).get("family", ""), "growth")
		counts[category] += 1
	_assert(counts["counter"] > counts["neutral"], "Counter picks should outnumber neutral picks.", failures)
	_assert(counts["neutral"] > counts["wrong"], "Neutral picks should outnumber wrong picks.", failures)

func _test_scene_instancing(failures: Array[String]) -> void:
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

func _fresh_state(loader) -> Object:
	var defaults: Dictionary = loader.get_balance("starting_values", {})
	var challenge_rules: Dictionary = loader.get_balance("challenge_rules", {})
	var state = RUN_STATE_SCRIPT.new()
	state.configure(defaults)
	state.begin_challenge("team_lead", challenge_rules, loader.get_player_loadout("default_set_hand"))
	return state

func _assert(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)

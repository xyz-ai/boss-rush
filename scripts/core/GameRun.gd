extends Node

const RUN_STATE_SCRIPT := preload("res://scripts/core/RunState.gd")
const LOGGING_SYSTEM_SCRIPT := preload("res://scripts/systems/LoggingSystem.gd")
const SHOP_GENERATOR_SCRIPT := preload("res://scripts/core/ShopGenerator.gd")
const CONSTANTS := preload("res://scripts/util/Constants.gd")

var run_state
var logging_system = LOGGING_SYSTEM_SCRIPT.new()
var shop_generator = SHOP_GENERATOR_SCRIPT.new()

func _ready() -> void:
	if _data_loader() != null:
		_data_loader().reload_all()

func start_new_run() -> void:
	var defaults: Dictionary = _data_loader().get_balance("starting_values", {})
	run_state = RUN_STATE_SCRIPT.new()
	run_state.configure(defaults)
	logging_system = LOGGING_SYSTEM_SCRIPT.new()
	emit_log("新一轮挑战开始。")
	var boss_id = "team_lead"
	if not run_state.boss_order.is_empty():
		boss_id = run_state.boss_order[0]
	enter_boss(boss_id)

func enter_boss(boss_id: String) -> void:
	if run_state == null:
		start_new_run()
		return
	var boss_def = _data_loader().get_boss(boss_id)
	var challenge_rules = _data_loader().get_balance("challenge_rules", {})
	var loadout = _data_loader().get_player_loadout("default_set_hand")
	run_state.begin_challenge(boss_id, challenge_rules, loadout)
	emit_log("进入 Boss：%s / %s。" % [boss_def.get("title", boss_id), boss_def.get("name", boss_id)])
	emit_log("本次挑战采用三局两胜制，每局最多五回合。")
	SignalBus.emit_signal("screen_requested", CONSTANTS.SCREEN_BATTLE, {"boss": boss_def})
	broadcast_state()

func complete_boss(victory: bool, result: Dictionary = {}) -> void:
	if run_state == null:
		return
	if victory:
		if not run_state.current_boss_id in run_state.defeated_bosses:
			run_state.defeated_bosses.append(run_state.current_boss_id)
		open_shop()
		return
	end_run("defeat", _build_summary_payload(false, result))

func open_shop() -> void:
	if run_state == null:
		return
	run_state.pending_shop_items = shop_generator.generate_offers(
		run_state,
		_data_loader().get_shop_pool(),
		int(_data_loader().get_balance("shop_offer_count", 3))
	)
	SignalBus.emit_signal("screen_requested", CONSTANTS.SCREEN_SHOP, {"offers": run_state.pending_shop_items})
	broadcast_state()

func finish_shop() -> void:
	end_run("prototype_clear", _build_summary_payload(true, run_state.last_round_result))

func end_run(result_code: String, payload: Dictionary = {}) -> void:
	if run_state != null:
		run_state.run_result = result_code
	SignalBus.emit_signal("screen_requested", CONSTANTS.SCREEN_SUMMARY, payload)
	broadcast_state()

func emit_log(message: String) -> void:
	logging_system.push(message)

func get_recent_logs(limit: int = 8) -> Array[String]:
	return logging_system.get_recent(limit)

func get_recent_logs_text(limit: int = 8) -> String:
	return logging_system.get_recent_text(limit)

func broadcast_state() -> void:
	SignalBus.emit_signal("run_state_changed", run_state)

func _build_summary_payload(victory: bool, result: Dictionary) -> Dictionary:
	if run_state == null:
		return {"title": "总结", "summary": "当前没有进行中的挑战。"}

	var title = "挑战失败"
	var summary = "你没能扛过这一次对桌。"
	var challenge_snapshot = {}
	if run_state.challenge_state != null:
		challenge_snapshot = run_state.challenge_state.snapshot()

	if victory:
		title = "挑战胜利"
		summary = "你赢下了这一轮 Boss 挑战。下一个 Boss 入口已预留，但当前原型尚未开放。"
	elif run_state.bod <= 0:
		summary = "Body 归零，身体先撑不住了。"
	elif run_state.spr <= 0:
		summary = "Spirit 归零，你已经没有余裕再看清局面。"
	elif run_state.rep <= 0:
		summary = "Reputation 归零，场面已经不再站在你这边。"
	elif not challenge_snapshot.is_empty():
		summary = "你在三局两胜的挑战中败给了 %s。" % _data_loader().get_boss(run_state.current_boss_id).get("title", run_state.current_boss_id)

	return {
		"title": title,
		"summary": summary,
		"result": result,
		"challenge_snapshot": challenge_snapshot,
	}

func _data_loader():
	return get_node_or_null("/root/DataLoader")

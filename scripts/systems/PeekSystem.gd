extends RefCounted
class_name PeekSystem

func peek_pool(run_state, pool_ids: Array) -> Dictionary:
	var set_state = run_state.current_set_state
	if set_state == null:
		return {"ok": false, "message": "当前没有进行中的局。"}
	if pool_ids.is_empty():
		return {"ok": false, "message": "当前没有可查看的 Boss 卡池。"}
	if set_state.boss_revealed:
		return {"ok": true, "cost": 0, "pool": pool_ids, "message": "Boss 卡池已经展开。"}

	var cost = 0
	if not set_state.free_peek_this_round:
		cost = int(_data_loader().get_balance("peek_cost_spr", 1))
		run_state.spr -= cost
	set_state.boss_revealed = true

	var message = "Boss 卡池已展开。"
	if cost > 0:
		message = "消耗 %d 点 SPR，展开 Boss 卡池。" % cost
	elif set_state.free_peek_this_round:
		message = "Intel 生效，本回合免费展开 Boss 卡池。"
	return {"ok": true, "cost": cost, "pool": pool_ids.duplicate(), "message": message}

func _data_loader():
	var main_loop = Engine.get_main_loop()
	if main_loop is SceneTree:
		return main_loop.root.get_node_or_null("DataLoader")
	return null

extends RefCounted
class_name AddonSystem

func activate_addon(run_state, addon_id: String) -> Dictionary:
	var set_state = run_state.current_set_state
	var addon_inventory = run_state.get_remaining_addons()
	if set_state == null:
		return {"ok": false, "message": "当前没有进行中的局。"}
	if set_state.round_active_addon != "":
		return {"ok": false, "message": "本回合已经使用过一张加注牌。"}
	if int(addon_inventory.get(addon_id, 0)) <= 0:
		return {"ok": false, "message": "库存不足，无法使用。"}

	addon_inventory[addon_id] = int(addon_inventory.get(addon_id, 0)) - 1
	set_state.round_active_addon = addon_id
	if addon_id == "intel":
		set_state.free_peek_this_round = true

	var addon_def = _data_loader().get_addon(addon_id)
	return {"ok": true, "message": "已启用 %s。" % addon_def.get("name", addon_id)}

func build_round_context(run_state) -> Dictionary:
	var set_state = run_state.current_set_state
	return {
		"addon_id": "" if set_state == null else set_state.round_active_addon,
		"cover": 0 if set_state == null else set_state.cover,
	}

func clear_round(run_state) -> void:
	if run_state.current_set_state == null:
		return
	run_state.current_set_state.round_active_addon = ""
	run_state.current_set_state.free_peek_this_round = false

func _data_loader():
	var main_loop = Engine.get_main_loop()
	if main_loop is SceneTree:
		return main_loop.root.get_node_or_null("DataLoader")
	return null

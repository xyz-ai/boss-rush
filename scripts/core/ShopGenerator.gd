extends RefCounted
class_name ShopGenerator

var rng = RandomNumberGenerator.new()

func _init() -> void:
	rng.randomize()

func generate_offers(_run_state, shop_pool: Array, count: int = 3) -> Array[Dictionary]:
	var selected: Array[Dictionary] = []
	var source = shop_pool.duplicate(true)
	if source.is_empty():
		return selected

	for _index in range(min(count, source.size())):
		var pick_index = rng.randi_range(0, source.size() - 1)
		var offer: Dictionary = source[pick_index]
		offer["purchased"] = false
		selected.append(offer)
		source.remove_at(pick_index)

	while selected.size() < count:
		var fallback: Dictionary = shop_pool[rng.randi_range(0, shop_pool.size() - 1)].duplicate(true)
		fallback["purchased"] = false
		selected.append(fallback)
	return selected

func apply_offer(run_state, offer: Dictionary) -> Dictionary:
	if offer.get("purchased", false):
		return {"ok": false, "message": "该商品已售出。"}

	var cost = int(offer.get("cost_life", 0))
	if run_state.life < cost:
		return {"ok": false, "message": "LIFE 不足，无法支付。"}

	run_state.life -= cost
	var effects: Dictionary = offer.get("effects", {})
	var addon_inventory = run_state.get_remaining_addons()
	for addon_id in effects.get("addons", {}).keys():
		addon_inventory[addon_id] = int(addon_inventory.get(addon_id, 0)) + int(effects["addons"][addon_id])

	for key in effects.get("restore", {}).keys():
		var amount = int(effects["restore"][key])
		match str(key):
			"bod":
				run_state.bod += amount
			"spr":
				run_state.spr += amount
			"rep":
				run_state.rep += amount

	offer["purchased"] = true
	return {"ok": true, "message": "已购买：%s" % offer.get("title", offer.get("id", "未知商品"))}

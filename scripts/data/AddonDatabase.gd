extends RefCounted
class_name AddonDatabase

const CONSTANTS := preload("res://scripts/util/Constants.gd")

var _addons: Dictionary = {}

func configure(addons: Array) -> void:
	_addons.clear()
	for entry in addons:
		if entry is Dictionary and entry.has("id"):
			_addons[entry["id"]] = entry

func get_addon(addon_id: String) -> Dictionary:
	return _addons.get(addon_id, {}).duplicate(true)

func get_all_addons() -> Array[Dictionary]:
	var ordered: Array[Dictionary] = []
	for addon_id in CONSTANTS.ADDON_IDS:
		if _addons.has(addon_id):
			ordered.append(_addons[addon_id].duplicate(true))
	return ordered

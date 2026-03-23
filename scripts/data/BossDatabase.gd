extends RefCounted
class_name BossDatabase

var _bosses: Dictionary = {}

func configure(boss_defs: Array) -> void:
	_bosses.clear()
	for entry in boss_defs:
		if entry is Dictionary and entry.has("id"):
			_bosses[entry["id"]] = entry

func get_boss(boss_id: String) -> Dictionary:
	return _bosses.get(boss_id, {}).duplicate(true)

func get_boss_ids() -> Array[String]:
	var ids: Array[String] = []
	for key in _bosses.keys():
		ids.append(key)
	return ids

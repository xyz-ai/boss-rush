extends RefCounted
class_name LoggingSystem

var _entries: Array[String] = []

func push(message: String) -> void:
	if message.is_empty():
		return
	_entries.append(message)

func push_round_result(result: Dictionary) -> void:
	var lines: Array[String] = []
	var set_snapshot: Dictionary = result.get("set_snapshot", {})
	var challenge_snapshot: Dictionary = result.get("challenge_snapshot", {})
	lines.append("第 %d 局 第 %d 回合" % [
		int(set_snapshot.get("set_index", 0)),
		int(set_snapshot.get("round_index", 0)),
	])
	for line in result.get("logs", []):
		lines.append("- %s" % line)
	if result.get("set_finished", false):
		lines.append("本局结果：%s" % ("玩家胜" if result.get("set_winner", "") == "player" else "Boss 胜"))
	if not challenge_snapshot.is_empty():
		lines.append("挑战比分：%d : %d" % [
			int(challenge_snapshot.get("player_set_wins", 0)),
			int(challenge_snapshot.get("boss_set_wins", 0)),
		])
	push("\n".join(lines))

func get_recent(limit: int = 8) -> Array[String]:
	if _entries.size() <= limit:
		return _entries.duplicate()
	return _entries.slice(_entries.size() - limit, _entries.size())

func get_recent_text(limit: int = 8) -> String:
	return "\n\n".join(get_recent(limit))

extends RefCounted
class_name MatchupRules

var beats: Dictionary = {}
var multipliers: Dictionary = {
	"advantage": 2.0,
	"disadvantage": 0.5,
	"neutral": 1.0,
}

func _init(config: Dictionary = {}) -> void:
	configure(config)

func configure(config: Dictionary) -> void:
	beats = config.get("beats", {}).duplicate(true)
	multipliers = config.get("multipliers", multipliers).duplicate(true)

func get_multiplier(attacker_family: String, defender_family: String) -> float:
	if attacker_family == "control" or defender_family == "control":
		return float(multipliers.get("neutral", 1.0))
	if beats.get(attacker_family, "") == defender_family:
		return float(multipliers.get("advantage", 2.0))
	if beats.get(defender_family, "") == attacker_family:
		return float(multipliers.get("disadvantage", 0.5))
	return float(multipliers.get("neutral", 1.0))

func categorize(candidate_family: String, player_family: String) -> String:
	if candidate_family == "control" or player_family == "control":
		return "neutral"
	if beats.get(candidate_family, "") == player_family:
		return "counter"
	if beats.get(player_family, "") == candidate_family:
		return "wrong"
	return "neutral"

extends RefCounted
class_name ChallengeState

var boss_id: String = ""
var current_set_index: int = 1
var player_set_wins: int = 0
var boss_set_wins: int = 0
var max_sets: int = 3
var wins_to_clear: int = 2
var remaining_addons: Dictionary = {}
var equipped_battle_loadout: Array[String] = []
var special_wager_slots: Array = []

func configure(next_boss_id: String, challenge_rules: Dictionary, loadout_ids: Array[String], carried_addons: Dictionary) -> void:
	boss_id = next_boss_id
	current_set_index = 1
	player_set_wins = 0
	boss_set_wins = 0
	max_sets = int(challenge_rules.get("max_sets", 3))
	wins_to_clear = int(challenge_rules.get("wins_to_clear", 2))
	remaining_addons = carried_addons.duplicate(true)
	equipped_battle_loadout.clear()
	for card_id in loadout_ids:
		equipped_battle_loadout.append(str(card_id))
	# Reserved for future "body-part as wager" systems.
	special_wager_slots = []

func snapshot() -> Dictionary:
	return {
		"boss_id": boss_id,
		"current_set_index": current_set_index,
		"player_set_wins": player_set_wins,
		"boss_set_wins": boss_set_wins,
		"max_sets": max_sets,
		"wins_to_clear": wins_to_clear,
		"remaining_addons": remaining_addons.duplicate(true),
		"equipped_battle_loadout": equipped_battle_loadout.duplicate(),
	}

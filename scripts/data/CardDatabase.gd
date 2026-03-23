extends RefCounted
class_name CardDatabase

const CONSTANTS := preload("res://scripts/util/Constants.gd")

var _battle_cards: Dictionary = {}
var _boss_cards: Dictionary = {}

func configure(battle_cards: Array, boss_cards: Array) -> void:
	_battle_cards.clear()
	_boss_cards.clear()
	for entry in battle_cards:
		if entry is Dictionary and entry.has("id"):
			_battle_cards[entry["id"]] = entry
	for entry in boss_cards:
		if entry is Dictionary and entry.has("id"):
			_boss_cards[entry["id"]] = entry

func get_battle_card(card_id: String) -> Dictionary:
	return _battle_cards.get(card_id, {}).duplicate(true)

func get_boss_card(card_id: String) -> Dictionary:
	return _boss_cards.get(card_id, {}).duplicate(true)

func get_card(card_id: String) -> Dictionary:
	if _battle_cards.has(card_id):
		return get_battle_card(card_id)
	return get_boss_card(card_id)

func get_player_battle_cards(card_ids: Array = []) -> Array[Dictionary]:
	var ordered_cards: Array[Dictionary] = []
	var source_ids = card_ids
	if source_ids.is_empty():
		source_ids = CONSTANTS.PLAYER_BATTLE_CARD_IDS
	for card_id in source_ids:
		if _battle_cards.has(card_id):
			ordered_cards.append(_battle_cards[card_id].duplicate(true))
	return ordered_cards

extends RefCounted
class_name MvpCombatActorState

var actor_name: String = ""
var max_hp: int = 6
var hp: int = 6
var bod: int = 3
var spr: int = 3
var rep: int = 3

var cards: Array[MvpBattleCard] = []
var used_slots: Array[int] = []
var _deck_blueprint: Array[Dictionary] = []

func _init(name: String = "", starting_cards: Array[MvpBattleCard] = []) -> void:
	actor_name = name
	set_deck_blueprint(starting_cards)
	reset_for_new_set(max_hp)

func set_deck_blueprint(starting_cards: Array[MvpBattleCard]) -> void:
	_deck_blueprint.clear()
	for card in starting_cards:
		_deck_blueprint.append(card.to_dict())
	cards = _build_cards_from_blueprint()
	used_slots.clear()

func set_long_term_values(next_bod: int, next_spr: int, next_rep: int) -> void:
	bod = max(0, next_bod)
	spr = max(0, next_spr)
	rep = max(0, next_rep)

func reset_for_new_set(next_hp: int = 6) -> void:
	max_hp = max(1, next_hp)
	hp = max_hp
	cards = _build_cards_from_blueprint()
	used_slots.clear()

func get_available_slot_indices() -> Array[int]:
	var available: Array[int] = []
	for slot_index in range(cards.size()):
		if not used_slots.has(slot_index):
			available.append(slot_index)
	return available

func has_slot(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < cards.size()

func is_slot_used(slot_index: int) -> bool:
	return used_slots.has(slot_index)

func get_card_at(slot_index: int) -> MvpBattleCard:
	if not has_slot(slot_index):
		return null
	return cards[slot_index]

func mark_card_used(slot_index: int) -> bool:
	if not has_slot(slot_index) or used_slots.has(slot_index):
		return false
	used_slots.append(slot_index)
	return true

func all_cards_used() -> bool:
	return used_slots.size() >= cards.size()

func modify_hp(delta: int) -> void:
	hp = max(0, hp + delta)

func modify_status(stat_name: String, delta: int) -> void:
	match stat_name:
		"bod":
			bod = max(0, bod + delta)
		"spr":
			spr = max(0, spr + delta)
		"rep":
			rep = max(0, rep + delta)

func get_status(stat_name: String) -> int:
	match stat_name:
		"bod":
			return bod
		"spr":
			return spr
		"rep":
			return rep
		_:
			return 0

func is_collapsed() -> bool:
	return bod <= 0 or spr <= 0 or rep <= 0

func snapshot() -> Dictionary:
	return {
		"actor_name": actor_name,
		"hp": hp,
		"max_hp": max_hp,
		"bod": bod,
		"spr": spr,
		"rep": rep,
		"used_slots": used_slots.duplicate(),
	}

func _build_cards_from_blueprint() -> Array[MvpBattleCard]:
	var fresh_cards: Array[MvpBattleCard] = []
	for entry in _deck_blueprint:
		fresh_cards.append(MvpBattleCard.from_dict(entry))
	return fresh_cards

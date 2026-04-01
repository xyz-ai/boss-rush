extends RefCounted
class_name MvpBattleCard

const TYPE_AGGRESSION := "aggression"
const TYPE_DEFENSE := "defense"
const TYPE_PRESSURE := "pressure"
const VALID_TYPES := [TYPE_AGGRESSION, TYPE_DEFENSE, TYPE_PRESSURE]

const PLAYER_TEMPLATE := [
	TYPE_AGGRESSION,
	TYPE_AGGRESSION,
	TYPE_DEFENSE,
	TYPE_PRESSURE,
	TYPE_PRESSURE,
]

const BOSS_TEMPLATES := {
	"template_a": [
		TYPE_AGGRESSION,
		TYPE_AGGRESSION,
		TYPE_PRESSURE,
		TYPE_PRESSURE,
		TYPE_DEFENSE,
	],
	"template_b": [
		TYPE_DEFENSE,
		TYPE_DEFENSE,
		TYPE_AGGRESSION,
		TYPE_PRESSURE,
		TYPE_PRESSURE,
	],
	"template_c": [
		TYPE_AGGRESSION,
		TYPE_DEFENSE,
		TYPE_PRESSURE,
		TYPE_AGGRESSION,
		TYPE_DEFENSE,
	],
}

var type: String = TYPE_AGGRESSION

func _init(card_type: String = TYPE_AGGRESSION) -> void:
	type = card_type if card_type in VALID_TYPES else TYPE_AGGRESSION

static func from_dict(data: Dictionary) -> MvpBattleCard:
	return MvpBattleCard.new(str(data.get("type", TYPE_AGGRESSION)))

static func build_player_test_deck() -> Array[MvpBattleCard]:
	return _build_cards_from_types(PLAYER_TEMPLATE)

static func build_boss_template(template_id: String) -> Array[MvpBattleCard]:
	var template_types: Array = BOSS_TEMPLATES.get(template_id, BOSS_TEMPLATES["template_a"])
	return _build_cards_from_types(template_types)

static func pick_random_boss_template(rng: RandomNumberGenerator) -> Dictionary:
	var template_ids: Array = BOSS_TEMPLATES.keys()
	template_ids.sort()
	var chosen_index := rng.randi_range(0, template_ids.size() - 1)
	var template_id := str(template_ids[chosen_index])
	return {
		"id": template_id,
		"cards": build_boss_template(template_id),
	}

static func get_boss_template_types(template_id: String) -> Array[String]:
	var types: Array[String] = []
	for card_type in BOSS_TEMPLATES.get(template_id, BOSS_TEMPLATES["template_a"]):
		types.append(str(card_type))
	return types

static func get_all_boss_templates() -> Dictionary:
	var templates: Dictionary = {}
	for template_id in BOSS_TEMPLATES.keys():
		templates[template_id] = get_boss_template_types(str(template_id))
	return templates

static func display_name_for_type(card_type: String) -> String:
	match card_type:
		TYPE_AGGRESSION:
			return "Aggression"
		TYPE_DEFENSE:
			return "Defense"
		TYPE_PRESSURE:
			return "Pressure"
		_:
			return "Aggression"

static func _build_cards_from_types(source_types: Array) -> Array[MvpBattleCard]:
	var deck: Array[MvpBattleCard] = []
	for card_type in source_types:
		deck.append(MvpBattleCard.new(str(card_type)))
	return deck

func duplicate_card() -> MvpBattleCard:
	return MvpBattleCard.new(type)

func to_dict() -> Dictionary:
	return {
		"type": type,
		"display_name": display_name_for_type(type),
	}

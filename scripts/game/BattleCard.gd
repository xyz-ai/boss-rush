extends RefCounted
class_name MvpBattleCard

const TYPE_AGGRESSION := "aggression"
const TYPE_DEFENSE := "defense"
const TYPE_PRESSURE := "pressure"
const VALID_TYPES := [TYPE_AGGRESSION, TYPE_DEFENSE, TYPE_PRESSURE]
const TEMPLATE_A_ID := "template_a"
const TEMPLATE_B_ID := "template_b"
const TEMPLATE_C_ID := "template_c"
const DEFAULT_BOSS_TEMPLATE_ID := TEMPLATE_A_ID
const ARCHETYPE_AGGRESSIVE := "aggressive"
const ARCHETYPE_DEFENSIVE := "defensive"
const ARCHETYPE_BALANCED := "balanced"

const PLAYER_TEMPLATE := [
	TYPE_AGGRESSION,
	TYPE_AGGRESSION,
	TYPE_DEFENSE,
	TYPE_PRESSURE,
	TYPE_PRESSURE,
]

var type: String = TYPE_AGGRESSION

func _init(card_type: String = TYPE_AGGRESSION) -> void:
	type = normalized_type(card_type)

static func from_dict(data: Dictionary) -> MvpBattleCard:
	return MvpBattleCard.new(str(data.get("type", TYPE_AGGRESSION)))

static func build_player_test_deck() -> Array[MvpBattleCard]:
	return _build_cards_from_types(PLAYER_TEMPLATE)

static func build_boss_test_deck() -> Array[MvpBattleCard]:
	return build_boss_template(DEFAULT_BOSS_TEMPLATE_ID)

static func build_boss_template(template_id: String) -> Array[MvpBattleCard]:
	return _build_cards_from_types(get_boss_template_types(template_id))

static func pick_random_boss_template(rng: RandomNumberGenerator) -> Dictionary:
	var loader := _data_loader()
	if loader != null and loader.has_method("get_random_mvp_boss_config"):
		var config: Dictionary = loader.get_random_mvp_boss_config(rng)
		return {
			"id": str(config.get("boss_id", DEFAULT_BOSS_TEMPLATE_ID)),
			"cards": _build_cards_from_types(config.get("battle_deck", [])),
		}
	return {
		"id": DEFAULT_BOSS_TEMPLATE_ID,
		"cards": [],
	}

static func get_boss_template_types(template_id: String) -> Array[String]:
	var types: Array[String] = []
	var loader := _data_loader()
	if loader != null and loader.has_method("get_mvp_boss_config"):
		var config: Dictionary = loader.get_mvp_boss_config(template_id)
		for card_type in config.get("battle_deck", []):
			types.append(str(card_type))
	return types

static func get_all_boss_templates() -> Dictionary:
	var templates: Dictionary = {}
	var loader := _data_loader()
	var template_ids: Array[String] = [TEMPLATE_A_ID, TEMPLATE_B_ID, TEMPLATE_C_ID]
	if loader != null and loader.has_method("get_mvp_boss_ids"):
		template_ids = loader.get_mvp_boss_ids()
	for template_id in template_ids:
		templates[template_id] = get_boss_template_types(template_id)
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

static func archetype_for_template(template_id: String) -> String:
	var loader := _data_loader()
	if loader != null and loader.has_method("get_mvp_boss_config"):
		return str(loader.get_mvp_boss_config(template_id).get("archetype", ARCHETYPE_BALANCED))
	return ARCHETYPE_BALANCED

static func archetype_display_name(archetype: String) -> String:
	match archetype:
		ARCHETYPE_AGGRESSIVE:
			return "Aggressive"
		ARCHETYPE_DEFENSIVE:
			return "Defensive"
		ARCHETYPE_BALANCED:
			return "Balanced"
		_:
			return "Balanced"

static func normalized_type(card_type: String) -> String:
	return card_type if card_type in VALID_TYPES else TYPE_AGGRESSION

static func beats(attacker_type: String, defender_type: String) -> bool:
	match normalized_type(attacker_type):
		TYPE_AGGRESSION:
			return normalized_type(defender_type) == TYPE_PRESSURE
		TYPE_PRESSURE:
			return normalized_type(defender_type) == TYPE_DEFENSE
		TYPE_DEFENSE:
			return normalized_type(defender_type) == TYPE_AGGRESSION
		_:
			return false

static func status_for_type(card_type: String) -> String:
	match normalized_type(card_type):
		TYPE_AGGRESSION:
			return "bod"
		TYPE_PRESSURE:
			return "spr"
		TYPE_DEFENSE:
			return "rep"
		_:
			return "rep"

static func _build_cards_from_types(source_types: Array) -> Array[MvpBattleCard]:
	var deck: Array[MvpBattleCard] = []
	for card_type in source_types:
		deck.append(MvpBattleCard.new(str(card_type)))
	return deck

static func _data_loader() -> Node:
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree:
		return (main_loop as SceneTree).root.get_node_or_null("DataLoader")
	return null

func duplicate_card() -> MvpBattleCard:
	return MvpBattleCard.new(type)

func to_dict() -> Dictionary:
	return {
		"type": type,
		"display_name": display_name_for_type(type),
	}

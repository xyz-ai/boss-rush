extends RefCounted
class_name MvpBattleCard

const PLAYER_TEST_DATA: Array[Dictionary] = [
	{"id": "player_aggression", "display_name": "Aggression", "base_power": 2, "tag": "aggression"},
	{"id": "player_defense", "display_name": "Defense", "base_power": 2, "tag": "defense"},
	{"id": "player_pressure", "display_name": "Pressure", "base_power": 2, "tag": "pressure"},
	{"id": "player_aggression_ii", "display_name": "Aggression II", "base_power": 1, "tag": "aggression"},
	{"id": "player_defense_ii", "display_name": "Defense II", "base_power": 1, "tag": "defense"},
]

const BOSS_TEST_DATA: Array[Dictionary] = [
	{"id": "boss_aggression", "display_name": "Aggression", "base_power": 2, "tag": "aggression"},
	{"id": "boss_defense", "display_name": "Defense", "base_power": 2, "tag": "defense"},
	{"id": "boss_pressure", "display_name": "Pressure", "base_power": 2, "tag": "pressure"},
	{"id": "boss_aggression_ii", "display_name": "Aggression II", "base_power": 1, "tag": "aggression"},
	{"id": "boss_defense_ii", "display_name": "Defense II", "base_power": 1, "tag": "defense"},
]

const VALID_TAGS := ["aggression", "defense", "pressure"]

var id: String = ""
var display_name: String = ""
var base_power: int = 0
var tag: String = "aggression"

func _init(card_id: String = "", card_name: String = "", power: int = 0, card_tag: String = "aggression") -> void:
	id = card_id
	display_name = card_name
	base_power = power
	tag = card_tag if card_tag in VALID_TAGS else "aggression"

static func from_dict(data: Dictionary) -> MvpBattleCard:
	return MvpBattleCard.new(
		str(data.get("id", "")),
		str(data.get("display_name", "Card")),
		int(data.get("base_power", 0)),
		str(data.get("tag", "aggression"))
	)

static func build_player_test_deck() -> Array[MvpBattleCard]:
	return _build_deck(PLAYER_TEST_DATA)

static func build_boss_test_deck() -> Array[MvpBattleCard]:
	return _build_deck(BOSS_TEST_DATA)

static func _build_deck(source_data: Array[Dictionary]) -> Array[MvpBattleCard]:
	var deck: Array[MvpBattleCard] = []
	for entry in source_data:
		deck.append(MvpBattleCard.from_dict(entry))
	return deck

func duplicate_card() -> MvpBattleCard:
	return MvpBattleCard.new(id, display_name, base_power, tag)

func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"base_power": base_power,
		"tag": tag,
	}

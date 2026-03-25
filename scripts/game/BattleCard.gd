extends RefCounted
class_name MvpBattleCard

const PLAYER_TEST_DATA: Array[Dictionary] = [
	{"id": "player_aggression", "display_name": "Aggression", "base_power": 2, "tag": "attack"},
	{"id": "player_defense", "display_name": "Defense", "base_power": 2, "tag": "defend"},
	{"id": "player_pressure", "display_name": "Pressure", "base_power": 2, "tag": "pressure"},
	{"id": "player_tempo", "display_name": "Tempo", "base_power": 1, "tag": "attack"},
	{"id": "player_audit", "display_name": "Audit", "base_power": 1, "tag": "defend"},
]

const BOSS_TEST_DATA: Array[Dictionary] = [
	{"id": "boss_aggression", "display_name": "Aggression", "base_power": 2, "tag": "attack"},
	{"id": "boss_defense", "display_name": "Defense", "base_power": 2, "tag": "defend"},
	{"id": "boss_pressure", "display_name": "Pressure", "base_power": 2, "tag": "pressure"},
	{"id": "boss_tempo", "display_name": "Tempo", "base_power": 1, "tag": "attack"},
	{"id": "boss_audit", "display_name": "Audit", "base_power": 1, "tag": "defend"},
]

const VALID_TAGS := ["attack", "defend", "pressure"]

var id: String = ""
var display_name: String = ""
var base_power: int = 0
var tag: String = "attack"

func _init(card_id: String = "", card_name: String = "", power: int = 0, card_tag: String = "attack") -> void:
	id = card_id
	display_name = card_name
	base_power = power
	tag = card_tag if card_tag in VALID_TAGS else "attack"

static func from_dict(data: Dictionary) -> MvpBattleCard:
	return MvpBattleCard.new(
		str(data.get("id", "")),
		str(data.get("display_name", "Card")),
		int(data.get("base_power", 0)),
		str(data.get("tag", "attack"))
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

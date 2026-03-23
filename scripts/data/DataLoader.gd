extends Node

const CARD_DATABASE_SCRIPT := preload("res://scripts/data/CardDatabase.gd")
const BOSS_DATABASE_SCRIPT := preload("res://scripts/data/BossDatabase.gd")
const ADDON_DATABASE_SCRIPT := preload("res://scripts/data/AddonDatabase.gd")

var _card_db = CARD_DATABASE_SCRIPT.new()
var _boss_db = BOSS_DATABASE_SCRIPT.new()
var _addon_db = ADDON_DATABASE_SCRIPT.new()

var _matchup_rules: Dictionary = {}
var _ui_thresholds: Dictionary = {}
var _starting_values: Dictionary = {}
var _challenge_rules: Dictionary = {}
var _player_loadouts: Dictionary = {}
var _shop_pool: Array = []

func _ready() -> void:
	reload_all()

func reload_all() -> void:
	var battle_cards = _read_json("res://data/cards/battle_cards.json", [])
	var addon_cards = _read_json("res://data/cards/addon_cards.json", [])
	var boss_cards = _read_json("res://data/cards/boss_cards.json", [])
	var bosses = [
		_read_json("res://data/bosses/team_lead.json", {}),
		_read_json("res://data/bosses/manager.json", {}),
	]

	_card_db.configure(battle_cards, boss_cards)
	_addon_db.configure(addon_cards)
	_boss_db.configure(bosses)
	_matchup_rules = _read_json("res://data/balance/matchup_rules.json", {})
	_ui_thresholds = _read_json("res://data/balance/ui_thresholds.json", {})
	_starting_values = _read_json("res://data/balance/starting_values.json", {})
	_challenge_rules = _read_json("res://data/balance/challenge_rules.json", {})
	_player_loadouts = _read_json("res://data/cards/player_loadouts.json", {})
	_shop_pool = _read_json("res://data/shops/shop_pool.json", [])

func get_card(card_id: String) -> Dictionary:
	return _card_db.get_card(card_id)

func get_battle_card(card_id: String) -> Dictionary:
	return _card_db.get_battle_card(card_id)

func get_boss_card(card_id: String) -> Dictionary:
	return _card_db.get_boss_card(card_id)

func get_player_battle_cards(card_ids: Array = []) -> Array[Dictionary]:
	return _card_db.get_player_battle_cards(card_ids)

func get_player_loadout(loadout_key: String = "default_set_hand") -> Array[String]:
	var loadout: Array[String] = []
	for card_id in _player_loadouts.get(loadout_key, []):
		loadout.append(str(card_id))
	return loadout

func get_addon(addon_id: String) -> Dictionary:
	return _addon_db.get_addon(addon_id)

func get_all_addons() -> Array[Dictionary]:
	return _addon_db.get_all_addons()

func get_boss(boss_id: String) -> Dictionary:
	return _boss_db.get_boss(boss_id)

func get_shop_pool() -> Array:
	return _shop_pool.duplicate(true)

func get_balance(key: String, default_value = null):
	match key:
		"matchup_rules":
			return _matchup_rules.duplicate(true)
		"ui_thresholds":
			return _ui_thresholds.duplicate(true)
		"starting_values":
			return _starting_values.duplicate(true)
		"challenge_rules":
			return _challenge_rules.duplicate(true)
		_:
			return _starting_values.get(key, default_value)

func _read_json(path: String, fallback):
	if not FileAccess.file_exists(path):
		push_warning("Missing data file: %s" % path)
		return fallback
	var raw = FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(raw)
	if parsed == null:
		push_warning("Failed to parse JSON at %s" % path)
		return fallback
	return parsed

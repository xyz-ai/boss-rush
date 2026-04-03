extends RefCounted
class_name MvpBetCard

const TYPE_BET := "bet"
const COST_RESOURCE_SPR := "spr"

const TIMING_PRE := "pre"
const TIMING_POST := "post"

const HOLD_STEADY_ID := "hold_steady"
const POSITIVE_SHIFT_ID := "positive_shift"
const DIRTY_MOVE_ID := "dirty_move"

const PRE_BET_COST_MULTIPLIER := 0.5
const POST_BET_COST_MULTIPLIER := 1.0

var id: String = HOLD_STEADY_ID
var name: String = "Hold Steady"
var type: String = TYPE_BET
var base_cost: int = 0
var cost_resource: String = COST_RESOURCE_SPR
var timing_windows: Array[String] = [TIMING_PRE, TIMING_POST]
var effect_on_win: Dictionary = {}
var effect_on_lose: Dictionary = {}
var branch_enabled: bool = false
var branch_group_id: String = ""
var branch_options: Array = []
var branch_resolution_mode: String = ""

func _init(data: Dictionary = {}) -> void:
	id = str(data.get("id", HOLD_STEADY_ID))
	name = str(data.get("name", "Hold Steady"))
	type = str(data.get("type", TYPE_BET))
	base_cost = int(data.get("base_cost", 0))
	cost_resource = str(data.get("cost_resource", COST_RESOURCE_SPR))
	timing_windows = []
	for timing in data.get("timing_windows", [TIMING_PRE, TIMING_POST]):
		timing_windows.append(str(timing))
	effect_on_win = data.get("effect_on_win", {}).duplicate(true)
	effect_on_lose = data.get("effect_on_lose", {}).duplicate(true)
	branch_enabled = bool(data.get("branch_enabled", false))
	branch_group_id = str(data.get("branch_group_id", ""))
	branch_options = data.get("branch_options", []).duplicate(true)
	branch_resolution_mode = str(data.get("branch_resolution_mode", ""))

static func build_default_cards() -> Array:
	return [
		new(_blueprint_hold_steady()),
		new(_blueprint_positive_shift()),
		new(_blueprint_dirty_move()),
	]

static func from_id(bet_id: String):
	for card in build_default_cards():
		if card.id == bet_id:
			return card
	return null

static func cost_for_timing(card, timing: String) -> int:
	if card == null:
		return 0
	var multiplier := POST_BET_COST_MULTIPLIER
	if timing == TIMING_PRE:
		multiplier = PRE_BET_COST_MULTIPLIER
	return int(ceil(float(card.base_cost) * multiplier))

func is_available_in_timing(timing: String) -> bool:
	return timing_windows.has(timing)

func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"type": type,
		"base_cost": base_cost,
		"cost_resource": cost_resource,
		"timing_windows": timing_windows.duplicate(),
		"effect_on_win": effect_on_win.duplicate(true),
		"effect_on_lose": effect_on_lose.duplicate(true),
		"branch_enabled": branch_enabled,
		"branch_group_id": branch_group_id,
		"branch_options": branch_options.duplicate(true),
		"branch_resolution_mode": branch_resolution_mode,
	}

static func _blueprint_hold_steady() -> Dictionary:
	return {
		"id": HOLD_STEADY_ID,
		"name": "Hold Steady",
		"type": TYPE_BET,
		"base_cost": 0,
		"cost_resource": COST_RESOURCE_SPR,
		"timing_windows": [TIMING_PRE, TIMING_POST],
		"effect_on_win": {},
		"effect_on_lose": {},
		"branch_enabled": false,
		"branch_group_id": "",
		"branch_options": [],
		"branch_resolution_mode": "",
	}

static func _blueprint_positive_shift() -> Dictionary:
	return {
		"id": POSITIVE_SHIFT_ID,
		"name": "Positive Shift",
		"type": TYPE_BET,
		"base_cost": 2,
		"cost_resource": COST_RESOURCE_SPR,
		"timing_windows": [TIMING_PRE, TIMING_POST],
		"effect_on_win": {"bonus_damage": 1},
		"effect_on_lose": {},
		"branch_enabled": false,
		"branch_group_id": "",
		"branch_options": [],
		"branch_resolution_mode": "",
	}

static func _blueprint_dirty_move() -> Dictionary:
	return {
		"id": DIRTY_MOVE_ID,
		"name": "Dirty Move",
		"type": TYPE_BET,
		"base_cost": 2,
		"cost_resource": COST_RESOURCE_SPR,
		"timing_windows": [TIMING_PRE, TIMING_POST],
		"effect_on_win": {"bonus_damage": 2},
		"effect_on_lose": {"self_damage": 1},
		"branch_enabled": false,
		"branch_group_id": "",
		"branch_options": [],
		"branch_resolution_mode": "",
	}

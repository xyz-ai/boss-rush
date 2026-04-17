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
var role_text: String = ""
var effect_text: String = ""
var condition_text: String = ""
var cost_text: String = ""
var tooltip_body_template: String = ""

func _init(data: Dictionary = {}) -> void:
	id = str(data.get("id", HOLD_STEADY_ID))
	name = str(data.get("name", "Hold Steady"))
	type = str(data.get("type", TYPE_BET))
	base_cost = int(data.get("base_cost", data.get("cost", 0)))
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
	role_text = str(data.get("role", data.get("role_text", "No role text configured.")))
	effect_text = str(data.get("effect_summary", data.get("effect_text", "No effect summary configured.")))
	condition_text = str(data.get("condition_text", "No condition text configured."))
	cost_text = str(data.get("cost_text", "{cost} {resource}"))
	tooltip_body_template = str(data.get("tooltip_body", ""))

static func build_default_cards() -> Array:
	var loader := _data_loader()
	if loader != null and loader.has_method("get_mvp_bet_card_defs"):
		return build_cards_from_defs(loader.get_mvp_bet_card_defs())
	return []

static func from_id(bet_id: String):
	var loader := _data_loader()
	if loader != null and loader.has_method("get_mvp_bet_card_def"):
		var card_def: Dictionary = loader.get_mvp_bet_card_def(bet_id)
		if not card_def.is_empty():
			return new(card_def)
	return null

static func build_cards_from_defs(defs: Array) -> Array:
	var cards: Array = []
	for entry in defs:
		if entry is Dictionary:
			cards.append(new(entry))
	return cards

static func cost_for_timing(card, timing: String) -> int:
	if card == null:
		return 0
	var multiplier := POST_BET_COST_MULTIPLIER
	if timing == TIMING_PRE:
		multiplier = PRE_BET_COST_MULTIPLIER
	return int(ceil(float(card.base_cost) * multiplier))

func is_available_in_timing(timing: String) -> bool:
	return timing_windows.has(timing)

func tooltip_body_for_timing(timing: String) -> String:
	var resolved_cost_text := _resolve_cost_text(timing)
	if not tooltip_body_template.is_empty():
		return tooltip_body_template \
			.replace("{role}", role_text) \
			.replace("{effect_summary}", effect_text) \
			.replace("{condition_text}", condition_text) \
			.replace("{cost_text}", resolved_cost_text) \
			.replace("{cost}", str(cost_for_timing(self, timing))) \
			.replace("{resource}", cost_resource.to_upper())
	return "\n".join(PackedStringArray([
		"Role: %s" % role_text,
		"Effect: %s" % effect_text,
		"Condition: %s" % condition_text,
		"Cost: %s" % resolved_cost_text,
	]))

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
		"role": role_text,
		"effect_summary": effect_text,
		"condition_text": condition_text,
		"cost_text": cost_text,
		"tooltip_body": tooltip_body_template,
	}

func _resolve_cost_text(timing: String) -> String:
	var resolved_cost := cost_for_timing(self, timing)
	if cost_text.is_empty():
		return "%d %s" % [resolved_cost, cost_resource.to_upper()]
	return cost_text \
		.replace("{cost}", str(resolved_cost)) \
		.replace("{resource}", cost_resource.to_upper())

static func _data_loader() -> Node:
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree:
		return (main_loop as SceneTree).root.get_node_or_null("DataLoader")
	return null

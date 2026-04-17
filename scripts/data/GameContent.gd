extends RefCounted
class_name GameContent

const DEFAULT_BOSS_ID := "template_a"
const DEFAULT_ARCHETYPE := "balanced"
const DEFAULT_COUNTER_WEIGHT := 50
const DEFAULT_NEUTRAL_WEIGHT := 30
const DEFAULT_WRONG_WEIGHT := 20
const DEFAULT_TYPE_BONUS := 30
const DEFAULT_BET_TOOLTIP_TEMPLATE := "Role: {role}\nEffect: {effect_summary}\nCondition: {condition_text}\nCost: {cost_text}"

var _boss_configs: Dictionary = {}
var _boss_ids: Array[String] = []
var _bet_card_defs: Dictionary = {}
var _bet_card_ids: Array[String] = []
var _text_catalog: Dictionary = {}

func configure(boss_templates: Array, bet_card_defs: Array, text_catalog: Dictionary) -> void:
	_boss_configs.clear()
	_boss_ids.clear()
	for entry in boss_templates:
		if not entry is Dictionary:
			continue
		var boss_id := str(entry.get("boss_id", "")).strip_edges()
		if boss_id.is_empty():
			continue
		_boss_ids.append(boss_id)
		_boss_configs[boss_id] = _normalize_boss_config(entry)

	_bet_card_defs.clear()
	_bet_card_ids.clear()
	for entry in bet_card_defs:
		if not entry is Dictionary:
			continue
		var card_id := str(entry.get("id", "")).strip_edges()
		if card_id.is_empty():
			continue
		_bet_card_ids.append(card_id)
		_bet_card_defs[card_id] = _normalize_bet_card_def(entry)

	_text_catalog = text_catalog.duplicate(true) if text_catalog is Dictionary else {}

func get_boss_config(boss_id: String) -> Dictionary:
	if _boss_configs.has(boss_id):
		return _boss_configs[boss_id].duplicate(true)
	if _boss_configs.has(DEFAULT_BOSS_ID):
		return _boss_configs[DEFAULT_BOSS_ID].duplicate(true)
	return _normalize_boss_config({})

func get_random_boss_config(rng: RandomNumberGenerator) -> Dictionary:
	if _boss_ids.is_empty():
		return get_boss_config(DEFAULT_BOSS_ID)
	if rng == null:
		return get_boss_config(_boss_ids[0])
	return get_boss_config(_boss_ids[rng.randi_range(0, _boss_ids.size() - 1)])

func get_boss_ids() -> Array[String]:
	return _boss_ids.duplicate()

func get_bet_card_def(card_id: String) -> Dictionary:
	if _bet_card_defs.has(card_id):
		return _bet_card_defs[card_id].duplicate(true)
	return _normalize_bet_card_def({"id": card_id})

func get_bet_card_defs() -> Array[Dictionary]:
	var defs: Array[Dictionary] = []
	for card_id in _bet_card_ids:
		defs.append(get_bet_card_def(card_id))
	return defs

func get_text(key: String, fallback_text: String = "") -> String:
	if key.is_empty():
		return fallback_text
	var cursor = _text_catalog
	for segment in key.split("."):
		if not cursor is Dictionary or not cursor.has(segment):
			return fallback_text
		cursor = cursor[segment]
	return str(cursor) if cursor != null else fallback_text

func _normalize_boss_config(source: Dictionary) -> Dictionary:
	var boss_id := str(source.get("boss_id", DEFAULT_BOSS_ID)).strip_edges()
	var archetype := str(source.get("archetype", DEFAULT_ARCHETYPE)).strip_edges()
	var display_name := str(source.get("display_name", boss_id.capitalize())).strip_edges()
	var battle_deck: Array[String] = []
	for card_type in source.get("battle_deck", []):
		battle_deck.append(str(card_type))
	var ai_weights: Dictionary = {}
	var source_ai_weights = source.get("ai_weights", {})
	if source_ai_weights is Dictionary:
		ai_weights = (source_ai_weights as Dictionary).duplicate(true)
	return {
		"boss_id": boss_id,
		"display_name": display_name if not display_name.is_empty() else boss_id,
		"archetype": archetype if not archetype.is_empty() else DEFAULT_ARCHETYPE,
		"battle_deck": battle_deck,
		"ai_weights": {
			"counter": int(ai_weights.get("counter", DEFAULT_COUNTER_WEIGHT)),
			"neutral": int(ai_weights.get("neutral", DEFAULT_NEUTRAL_WEIGHT)),
			"wrong": int(ai_weights.get("wrong", DEFAULT_WRONG_WEIGHT)),
			"aggression_bonus": int(ai_weights.get("aggression_bonus", _default_type_bonus(archetype, "aggression"))),
			"defense_bonus": int(ai_weights.get("defense_bonus", _default_type_bonus(archetype, "defense"))),
			"pressure_bonus": int(ai_weights.get("pressure_bonus", _default_type_bonus(archetype, "pressure"))),
		},
		"ui_label": str(source.get("ui_label", display_name)).strip_edges() if not str(source.get("ui_label", "")).strip_edges().is_empty() else display_name,
		"flavor_text": str(source.get("flavor_text", "")),
	}

func _normalize_bet_card_def(source: Dictionary) -> Dictionary:
	var card_id := str(source.get("id", "unknown")).strip_edges()
	var card_name := str(source.get("name", card_id.capitalize())).strip_edges()
	var cost_resource := str(source.get("cost_resource", "spr")).strip_edges()
	var base_cost := int(source.get("base_cost", source.get("cost", 0)))
	var timing_windows: Array[String] = []
	for timing in source.get("timing_windows", ["pre", "post"]):
		timing_windows.append(str(timing))
	return {
		"id": card_id,
		"name": card_name if not card_name.is_empty() else card_id,
		"type": str(source.get("type", "bet")),
		"cost": int(source.get("cost", base_cost)),
		"base_cost": base_cost,
		"cost_resource": cost_resource if not cost_resource.is_empty() else "spr",
		"timing_windows": timing_windows,
		"effect_on_win": source.get("effect_on_win", {}).duplicate(true),
		"effect_on_lose": source.get("effect_on_lose", {}).duplicate(true),
		"role": str(source.get("role", "No role text configured.")),
		"effect_summary": str(source.get("effect_summary", "No effect summary configured.")),
		"condition_text": str(source.get("condition_text", "No condition text configured.")),
		"cost_text": str(source.get("cost_text", "{cost} {resource}")),
		"tooltip_body": str(source.get("tooltip_body", DEFAULT_BET_TOOLTIP_TEMPLATE)),
	}

func _default_type_bonus(archetype: String, card_type: String) -> int:
	match archetype:
		"aggressive":
			return DEFAULT_TYPE_BONUS if card_type == "aggression" else 0
		"defensive":
			return DEFAULT_TYPE_BONUS if card_type == "defense" else 0
		_:
			return 0

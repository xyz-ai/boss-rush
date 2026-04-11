extends RefCounted
class_name MvpBossAI

const CATEGORY_COUNTER := "counter"
const CATEGORY_NEUTRAL := "neutral"
const CATEGORY_WRONG := "wrong"
const COUNTER_WEIGHT := 50
const NEUTRAL_WEIGHT := 30
const WRONG_WEIGHT := 20
const ARCHETYPE_AGGRESSIVE := "aggressive"
const ARCHETYPE_DEFENSIVE := "defensive"
const ARCHETYPE_BALANCED := "balanced"
const ARCHETYPE_TYPE_BONUS := 30

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _archetype: String = ARCHETYPE_BALANCED

func _init() -> void:
	rng.randomize()

func set_seed(seed: int) -> void:
	rng.seed = seed

func set_archetype(archetype: String) -> void:
	_archetype = _normalize_archetype(archetype)

func choose_slot(boss_state: MvpCombatActorState, player_card: MvpBattleCard) -> int:
	if boss_state == null or player_card == null:
		return -1

	var weighted_slots := _build_weighted_slots(boss_state, player_card)
	if weighted_slots.is_empty():
		return -1
	var total_weight := 0
	for entry in weighted_slots:
		total_weight += int(entry.get("weight", 0))
	if total_weight <= 0:
		return -1
	var roll := rng.randi_range(1, total_weight)
	var running_total := 0
	for entry in weighted_slots:
		running_total += int(entry.get("weight", 0))
		if roll <= running_total:
			return int(entry.get("slot", -1))
	return int(weighted_slots.back().get("slot", -1))

func _categorize(boss_tag: String, player_tag: String) -> String:
	if MvpBattleCard.beats(boss_tag, player_tag):
		return CATEGORY_COUNTER
	if MvpBattleCard.beats(player_tag, boss_tag):
		return CATEGORY_WRONG
	return CATEGORY_NEUTRAL

func _build_available_buckets(boss_state: MvpCombatActorState, player_card: MvpBattleCard) -> Dictionary:
	var counter_slots: Array[int] = []
	var neutral_slots: Array[int] = []
	var wrong_slots: Array[int] = []

	for slot_index in boss_state.get_available_slot_indices():
		var boss_card: MvpBattleCard = boss_state.get_card_at(slot_index)
		if boss_card == null:
			continue
		var category: String = _categorize(boss_card.type, player_card.type)
		match category:
			CATEGORY_COUNTER:
				counter_slots.append(slot_index)
			CATEGORY_NEUTRAL:
				neutral_slots.append(slot_index)
			CATEGORY_WRONG:
				wrong_slots.append(slot_index)

	return {
		CATEGORY_COUNTER: counter_slots,
		CATEGORY_NEUTRAL: neutral_slots,
		CATEGORY_WRONG: wrong_slots,
	}

func _build_weighted_slots(boss_state: MvpCombatActorState, player_card: MvpBattleCard) -> Array[Dictionary]:
	var weighted_slots: Array[Dictionary] = []
	for slot_index in boss_state.get_available_slot_indices():
		var boss_card: MvpBattleCard = boss_state.get_card_at(slot_index)
		if boss_card == null:
			continue
		var category: String = _categorize(boss_card.type, player_card.type)
		var weight := _category_weight(category) + _archetype_bonus_for_type(boss_card.type)
		if weight <= 0:
			continue
		weighted_slots.append({
			"slot": slot_index,
			"weight": weight,
			"category": category,
			"type": boss_card.type,
		})
	return weighted_slots

func _roll_target_category() -> String:
	var roll: int = rng.randi_range(1, 100)
	if roll <= COUNTER_WEIGHT:
		return CATEGORY_COUNTER
	if roll <= COUNTER_WEIGHT + NEUTRAL_WEIGHT:
		return CATEGORY_NEUTRAL
	return CATEGORY_WRONG

func _resolve_category_with_fallback(target_category: String, buckets: Dictionary) -> String:
	for category in _fallback_order_for(target_category):
		var candidate_slots: Array = buckets.get(category, [])
		if not candidate_slots.is_empty():
			return category
	return ""

func _fallback_order_for(target_category: String) -> Array[String]:
	match target_category:
		CATEGORY_COUNTER:
			return [CATEGORY_COUNTER, CATEGORY_NEUTRAL, CATEGORY_WRONG]
		CATEGORY_NEUTRAL:
			return [CATEGORY_NEUTRAL, CATEGORY_COUNTER, CATEGORY_WRONG]
		CATEGORY_WRONG:
			return [CATEGORY_WRONG, CATEGORY_NEUTRAL, CATEGORY_COUNTER]
		_:
			return [CATEGORY_COUNTER, CATEGORY_NEUTRAL, CATEGORY_WRONG]

func _category_weight(category: String) -> int:
	match category:
		CATEGORY_COUNTER:
			return COUNTER_WEIGHT
		CATEGORY_NEUTRAL:
			return NEUTRAL_WEIGHT
		CATEGORY_WRONG:
			return WRONG_WEIGHT
		_:
			return 0

func _archetype_bonus_for_type(card_type: String) -> int:
	match _archetype:
		ARCHETYPE_AGGRESSIVE:
			return ARCHETYPE_TYPE_BONUS if card_type == MvpBattleCard.TYPE_AGGRESSION else 0
		ARCHETYPE_DEFENSIVE:
			return ARCHETYPE_TYPE_BONUS if card_type == MvpBattleCard.TYPE_DEFENSE else 0
		_:
			return 0

func _normalize_archetype(archetype: String) -> String:
	match archetype:
		ARCHETYPE_AGGRESSIVE, ARCHETYPE_DEFENSIVE:
			return archetype
		_:
			return ARCHETYPE_BALANCED

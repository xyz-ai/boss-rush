extends RefCounted
class_name MvpBossAI

const CATEGORY_COUNTER := "counter"
const CATEGORY_NEUTRAL := "neutral"
const CATEGORY_WRONG := "wrong"
const COUNTER_WEIGHT := 50
const NEUTRAL_WEIGHT := 30
const WRONG_WEIGHT := 20

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _init() -> void:
	rng.randomize()

func set_seed(seed: int) -> void:
	rng.seed = seed

func choose_slot(boss_state: MvpCombatActorState, player_card: MvpBattleCard) -> int:
	if boss_state == null or player_card == null:
		return -1

	var buckets: Dictionary = _build_available_buckets(boss_state, player_card)
	var target_category: String = _roll_target_category()
	var resolved_category: String = _resolve_category_with_fallback(target_category, buckets)
	if resolved_category.is_empty():
		return -1

	var chosen_slots: Array = buckets.get(resolved_category, [])
	if chosen_slots.is_empty():
		return -1
	return int(chosen_slots[rng.randi_range(0, chosen_slots.size() - 1)])

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

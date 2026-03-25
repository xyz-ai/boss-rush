extends RefCounted
class_name MvpBossAI

const CATEGORY_ORDER := ["counter", "neutral", "wrong"]

var rng := RandomNumberGenerator.new()

func _init() -> void:
	rng.randomize()

func set_seed(seed: int) -> void:
	rng.seed = seed

func choose_slot(boss_state: MvpCombatActorState, player_card: MvpBattleCard) -> int:
	if boss_state == null or player_card == null:
		return -1

	var buckets := {
		"counter": [],
		"neutral": [],
		"wrong": [],
	}

	for slot_index in boss_state.get_available_slot_indices():
		var boss_card := boss_state.get_card_at(slot_index)
		if boss_card == null:
			continue
		var category := _categorize(boss_card.tag, player_card.tag)
		buckets[category].append(slot_index)

	var weighted_categories: Array[Dictionary] = []
	for category in CATEGORY_ORDER:
		if buckets[category].is_empty():
			continue
		weighted_categories.append({
			"category": category,
			"weight": _weight_for_category(category),
		})

	if weighted_categories.is_empty():
		return -1

	var chosen_category := _pick_weighted_category(weighted_categories)
	var chosen_slots: Array = buckets[chosen_category]
	return int(chosen_slots[rng.randi_range(0, chosen_slots.size() - 1)])

func _categorize(boss_tag: String, player_tag: String) -> String:
	if _beats(boss_tag, player_tag):
		return "counter"
	if _beats(player_tag, boss_tag):
		return "wrong"
	return "neutral"

func _pick_weighted_category(weighted_categories: Array[Dictionary]) -> String:
	var total_weight := 0
	for entry in weighted_categories:
		total_weight += int(entry.get("weight", 0))

	if total_weight <= 0:
		return str(weighted_categories[0].get("category", "neutral"))

	var roll := rng.randi_range(1, total_weight)
	var cursor := 0
	for entry in weighted_categories:
		cursor += int(entry.get("weight", 0))
		if roll <= cursor:
			return str(entry.get("category", "neutral"))
	return str(weighted_categories[0].get("category", "neutral"))

func _weight_for_category(category: String) -> int:
	match category:
		"counter":
			return 50
		"neutral":
			return 30
		"wrong":
			return 20
		_:
			return 0

func _beats(attacker_tag: String, defender_tag: String) -> bool:
	match attacker_tag:
		"attack":
			return defender_tag == "pressure"
		"pressure":
			return defender_tag == "defend"
		"defend":
			return defender_tag == "attack"
		_:
			return false

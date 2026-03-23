extends RefCounted
class_name BossAI

const MATCHUP_RULES_SCRIPT := preload("res://scripts/core/MatchupRules.gd")

var matchup_rules
var rng = RandomNumberGenerator.new()

func _init(config: Dictionary = {}) -> void:
	matchup_rules = MATCHUP_RULES_SCRIPT.new(config)
	rng.randomize()

func set_seed(seed: int) -> void:
	rng.seed = seed

func prepare_pool(boss_def: Dictionary, _run_state) -> Array[String]:
	var deck: Array = boss_def.get("deck", []).duplicate()
	var pool_size = max(1, int(boss_def.get("pool_size", 3)))
	if deck.is_empty():
		return []
	var shuffled = _shuffle(deck)
	var pool: Array[String] = []
	for card_id in shuffled:
		pool.append(str(card_id))
		if pool.size() >= pool_size:
			break
	while pool.size() < pool_size:
		pool.append(str(deck[rng.randi_range(0, deck.size() - 1)]))
	return pool

func pick_card(pool_ids: Array, player_family: String, run_state) -> String:
	var boss_def = _data_loader().get_boss(run_state.current_boss_id)
	var weights: Dictionary = boss_def.get("ai_weights", {"counter": 50, "neutral": 35, "wrong": 15})
	var buckets = {
		"counter": [],
		"neutral": [],
		"wrong": [],
	}

	for card_id in pool_ids:
		var card_def = _data_loader().get_boss_card(str(card_id))
		var category = matchup_rules.categorize(card_def.get("family", ""), player_family)
		buckets[category].append(str(card_id))

	var weighted_available: Array[Dictionary] = []
	for category in ["counter", "neutral", "wrong"]:
		if not buckets[category].is_empty():
			weighted_available.append({
				"category": category,
				"weight": int(weights.get(category, 0)),
			})

	if weighted_available.is_empty():
		return str(pool_ids[0])

	var chosen_category = _pick_weighted_category(weighted_available)
	var chosen_bucket: Array = buckets[chosen_category]
	return str(chosen_bucket[rng.randi_range(0, chosen_bucket.size() - 1)])

func _pick_weighted_category(weighted_available: Array[Dictionary]) -> String:
	var total = 0
	for entry in weighted_available:
		total += int(entry.get("weight", 0))
	if total <= 0:
		return str(weighted_available[0].get("category", "neutral"))

	var roll = rng.randi_range(1, total)
	var cursor = 0
	for entry in weighted_available:
		cursor += int(entry.get("weight", 0))
		if roll <= cursor:
			return str(entry.get("category", "neutral"))
	return str(weighted_available[0].get("category", "neutral"))

func _shuffle(source: Array) -> Array:
	var result = source.duplicate()
	for index in range(result.size() - 1, 0, -1):
		var swap_index = rng.randi_range(0, index)
		var temp = result[index]
		result[index] = result[swap_index]
		result[swap_index] = temp
	return result

func _data_loader():
	var main_loop = Engine.get_main_loop()
	if main_loop is SceneTree:
		return main_loop.root.get_node_or_null("DataLoader")
	return null

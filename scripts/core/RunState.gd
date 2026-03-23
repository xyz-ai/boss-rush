extends RefCounted
class_name RunState

const CONSTANTS := preload("res://scripts/util/Constants.gd")
const CHALLENGE_STATE_SCRIPT := preload("res://scripts/core/ChallengeState.gd")
const SET_STATE_SCRIPT := preload("res://scripts/core/SetState.gd")

var pos: int = 0
var bod: int = 0
var spr: int = 0
var rep: int = 0
var life: int = 0

var pos_min: int = CONSTANTS.POS_MIN
var pos_max: int = CONSTANTS.POS_MAX

var boss_index: int = 0
var current_boss_id: String = ""

var boss_order: Array[String] = []
var defeated_bosses: Array[String] = []
var pending_shop_items: Array[Dictionary] = []
var last_round_result: Dictionary = {}
var run_result: String = ""
var challenge_rules: Dictionary = {}
var starting_addons_template: Dictionary = {}
var challenge_state
var current_set_state

func configure(defaults: Dictionary) -> void:
	pos = int(defaults.get("pos", 0))
	bod = int(defaults.get("bod", 8))
	spr = int(defaults.get("spr", 8))
	rep = int(defaults.get("rep", 8))
	life = int(defaults.get("life", 10))
	pos_min = int(defaults.get("pos_min", CONSTANTS.POS_MIN))
	pos_max = int(defaults.get("pos_max", CONSTANTS.POS_MAX))
	boss_index = 0
	current_boss_id = ""
	defeated_bosses.clear()
	pending_shop_items.clear()
	last_round_result.clear()
	run_result = ""
	challenge_rules.clear()
	challenge_state = null
	current_set_state = null
	starting_addons_template = defaults.get("starting_addons", {}).duplicate(true)
	boss_order.clear()
	for boss_id in defaults.get("boss_order", []):
		boss_order.append(str(boss_id))

func begin_challenge(boss_id: String, next_challenge_rules: Dictionary, loadout_ids: Array[String]) -> void:
	current_boss_id = boss_id
	boss_index = boss_order.find(boss_id)
	challenge_rules = next_challenge_rules.duplicate(true)
	last_round_result.clear()
	var carried_addons = starting_addons_template.duplicate(true)
	if challenge_state != null and not challenge_state.remaining_addons.is_empty():
		carried_addons = challenge_state.remaining_addons.duplicate(true)
	challenge_state = CHALLENGE_STATE_SCRIPT.new()
	challenge_state.configure(boss_id, challenge_rules, loadout_ids, carried_addons)
	if bool(challenge_rules.get("reset_pos_on_new_set", false)):
		pos = 0
	start_set(challenge_rules)

func start_set(set_rules: Dictionary) -> void:
	if challenge_state == null:
		return
	if bool(set_rules.get("reset_pos_on_new_set", false)):
		pos = 0
	last_round_result.clear()
	current_set_state = SET_STATE_SCRIPT.new()
	current_set_state.configure(
		challenge_state.current_set_index,
		set_rules,
		challenge_state.equipped_battle_loadout
	)

func begin_round(pool_ids: Array) -> void:
	if current_set_state != null:
		current_set_state.begin_round(pool_ids)

func clear_round_state() -> void:
	if current_set_state != null:
		current_set_state.clear_round_state()

func consume_battle_card(card_id: String) -> bool:
	if current_set_state == null:
		return false
	return current_set_state.consume_battle_card(card_id)

func finish_set(winner: String) -> Dictionary:
	if challenge_state == null:
		return {
			"set_winner": winner,
			"challenge_finished": true,
			"challenge_winner": "boss",
		}

	if winner == "player":
		challenge_state.player_set_wins += 1
	else:
		challenge_state.boss_set_wins += 1

	var challenge_finished := false
	if challenge_state.player_set_wins >= challenge_state.wins_to_clear:
		challenge_finished = true
	elif challenge_state.boss_set_wins >= challenge_state.wins_to_clear:
		challenge_finished = true
	elif challenge_state.current_set_index >= challenge_state.max_sets:
		challenge_finished = true

	var challenge_winner := "ongoing"
	if challenge_finished:
		if challenge_state.player_set_wins > challenge_state.boss_set_wins:
			challenge_winner = "player"
		else:
			challenge_winner = "boss"
	elif challenge_state.current_set_index < challenge_state.max_sets:
		challenge_state.current_set_index += 1

	return {
		"set_winner": winner,
		"challenge_finished": challenge_finished,
		"challenge_winner": challenge_winner,
		"challenge_snapshot": challenge_state.snapshot(),
	}

func clamp_pos() -> void:
	pos = clamp(pos, pos_min, pos_max)

func is_collapsed() -> bool:
	return bod <= 0 or spr <= 0 or rep <= 0

func is_failed() -> bool:
	return is_collapsed()

func is_victory() -> bool:
	return challenge_state != null and challenge_state.player_set_wins >= challenge_state.wins_to_clear

func get_remaining_addons() -> Dictionary:
	if challenge_state == null:
		return starting_addons_template
	return challenge_state.remaining_addons

func snapshot() -> Dictionary:
	return {
		"pos": pos,
		"bod": bod,
		"spr": spr,
		"rep": rep,
		"life": life,
		"current_boss_id": current_boss_id,
		"remaining_addons": get_remaining_addons().duplicate(true),
		"challenge": challenge_state.snapshot() if challenge_state != null else {},
		"set": current_set_state.snapshot() if current_set_state != null else {},
	}

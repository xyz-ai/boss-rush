extends RefCounted
class_name SetState

var set_index: int = 1
var round_index: int = 0
var max_rounds: int = 5
var player_hp: int = 6
var boss_hp: int = 6

var remaining_player_battle_cards: Array[String] = []
var played_player_battle_cards: Array[String] = []

var current_pool: Array[String] = []
var pool_revealed: bool = false
var free_peek_this_round: bool = false
var round_active_addon: String = ""

var next_bonus: int = 0
var next_penalty: int = 0
var cover: int = 0

var last_round_result: Dictionary = {}

func configure(next_set_index: int, set_rules: Dictionary, loadout_ids: Array[String]) -> void:
	set_index = next_set_index
	round_index = 0
	max_rounds = int(set_rules.get("max_rounds_per_set", 5))
	player_hp = int(set_rules.get("player_hp_per_set", 6))
	boss_hp = int(set_rules.get("boss_hp_per_set", 6))
	remaining_player_battle_cards.clear()
	for card_id in loadout_ids:
		remaining_player_battle_cards.append(str(card_id))
	played_player_battle_cards.clear()
	current_pool.clear()
	pool_revealed = false
	free_peek_this_round = false
	round_active_addon = ""
	next_bonus = 0
	next_penalty = 0
	cover = 0
	last_round_result.clear()

func begin_round(pool_ids: Array) -> void:
	current_pool.clear()
	for card_id in pool_ids:
		current_pool.append(str(card_id))
	pool_revealed = false
	free_peek_this_round = false
	round_active_addon = ""
	cover = 0

func consume_battle_card(card_id: String) -> bool:
	var card_index := remaining_player_battle_cards.find(card_id)
	if card_index == -1:
		return false
	remaining_player_battle_cards.remove_at(card_index)
	played_player_battle_cards.append(card_id)
	return true

func clear_round_state() -> void:
	current_pool.clear()
	pool_revealed = false
	free_peek_this_round = false
	round_active_addon = ""
	cover = 0

func has_rounds_remaining() -> bool:
	return round_index < max_rounds and not remaining_player_battle_cards.is_empty()

func snapshot() -> Dictionary:
	return {
		"set_index": set_index,
		"round_index": round_index,
		"max_rounds": max_rounds,
		"player_hp": player_hp,
		"boss_hp": boss_hp,
		"remaining_player_battle_cards": remaining_player_battle_cards.duplicate(),
		"played_player_battle_cards": played_player_battle_cards.duplicate(),
		"current_pool": current_pool.duplicate(),
		"pool_revealed": pool_revealed,
		"free_peek_this_round": free_peek_this_round,
		"round_active_addon": round_active_addon,
		"next_bonus": next_bonus,
		"next_penalty": next_penalty,
		"cover": cover,
	}

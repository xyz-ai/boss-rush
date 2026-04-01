extends RefCounted
class_name MvpBattleResolver

const BASE_SCORE := 1

func resolve_round(
	player_state: MvpCombatActorState,
	boss_state: MvpCombatActorState,
	player_slot: int,
	boss_slot: int
) -> Dictionary:
	var player_card: MvpBattleCard = player_state.get_card_at(player_slot)
	var boss_card: MvpBattleCard = boss_state.get_card_at(boss_slot)
	assert(player_card != null, "Player card slot is invalid for MVP battle resolution.")
	assert(boss_card != null, "Boss card slot is invalid for MVP battle resolution.")

	var player_modifier: int = _matchup_bonus(player_card.type, boss_card.type)
	var boss_modifier: int = _matchup_bonus(boss_card.type, player_card.type)
	var player_total: int = maxi(0, BASE_SCORE + player_modifier - _spr_penalty(player_state))
	var boss_total: int = maxi(0, BASE_SCORE + boss_modifier - _spr_penalty(boss_state))

	var player_damage: int = 0
	var boss_damage: int = 0
	var winner: String = "tie"
	var status_changes: Array[Dictionary] = []
	var logs: Array[String] = []
	var summary_text: String = "Tie round. No damage dealt."

	logs.append("Player played %s." % MvpBattleCard.display_name_for_type(player_card.type))
	logs.append("Boss played %s." % MvpBattleCard.display_name_for_type(boss_card.type))
	logs.append("Effective power -> Player %d / Boss %d." % [player_total, boss_total])

	if player_total > boss_total:
		winner = "player"
		boss_damage = player_total - boss_total
		if boss_damage > 0 and boss_state.bod <= 1:
			boss_damage += 1
			logs.append("Boss BOD <= 1, so incoming damage is increased by 1.")
		status_changes.append({
			"target": "boss",
			"stat": _status_for_type(player_card.type),
			"amount": -1,
		})
		summary_text = "Player wins the clash. Boss takes %d damage." % boss_damage
	elif boss_total > player_total:
		winner = "boss"
		player_damage = boss_total - player_total
		if player_damage > 0 and player_state.bod <= 1:
			player_damage += 1
			logs.append("Player BOD <= 1, so incoming damage is increased by 1.")
		status_changes.append({
			"target": "player",
			"stat": _status_for_type(boss_card.type),
			"amount": -1,
		})
		summary_text = "Boss wins the clash. Player takes %d damage." % player_damage
	else:
		logs.append("The clash is tied, so no HP or status changes are applied.")

	return {
		"player_slot": player_slot,
		"boss_slot": boss_slot,
		"player_card": player_card.to_dict(),
		"boss_card": boss_card.to_dict(),
		"player_total": player_total,
		"boss_total": boss_total,
		"player_damage": player_damage,
		"boss_damage": boss_damage,
		"winner": winner,
		"status_changes": status_changes,
		"summary_text": summary_text,
		"log_lines": logs,
	}

func _spr_penalty(actor_state: MvpCombatActorState) -> int:
	return 1 if actor_state.spr <= 1 else 0

func _matchup_bonus(attacker_tag: String, defender_tag: String) -> int:
	if MvpBattleCard.beats(attacker_tag, defender_tag):
		return 1
	if MvpBattleCard.beats(defender_tag, attacker_tag):
		return -1
	return 0

func _status_for_type(card_type: String) -> String:
	return MvpBattleCard.status_for_type(card_type)

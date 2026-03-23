extends RefCounted
class_name BattleResolver

const MATCHUP_RULES_SCRIPT := preload("res://scripts/core/MatchupRules.gd")

var matchup_rules

func _init(config: Dictionary = {}) -> void:
	matchup_rules = MATCHUP_RULES_SCRIPT.new(config)

func resolve_round(run_state, player_card_id: String, boss_card_id: String, round_ctx: Dictionary) -> Dictionary:
	var set_state = run_state.current_set_state
	assert(set_state != null, "BattleResolver.resolve_round() requires an active set.")

	var player_card = _data_loader().get_battle_card(player_card_id)
	var boss_card = _data_loader().get_boss_card(boss_card_id)
	var logs: Array[String] = []
	var used_addon = str(round_ctx.get("addon_id", ""))
	run_state.consume_battle_card(player_card_id)

	_apply_costs(run_state, player_card.get("self_costs", {}), logs, player_card.get("name", player_card_id))
	_apply_costs(run_state, boss_card.get("self_costs", {}), logs, boss_card.get("name", boss_card_id))

	var consumed_bonus = set_state.next_bonus
	var consumed_penalty = set_state.next_penalty
	set_state.next_bonus = 0
	set_state.next_penalty = 0

	var player_base = max(0, int(player_card.get("base", 0)) + consumed_bonus - consumed_penalty)
	var boss_base = max(0, int(boss_card.get("base", 0)))
	if consumed_bonus != 0 or consumed_penalty != 0:
		logs.append("延续状态生效：Next %+d / %+d。" % [consumed_bonus, -consumed_penalty])

	var current_cover = max(set_state.cover, int(round_ctx.get("cover", 0)))
	current_cover = max(current_cover, int(player_card.get("on_resolve", {}).get("cover_current", 0)))
	if current_cover > 0:
		logs.append("本回合获得 Cover %d。" % current_cover)

	if player_card.get("family", "") == "control":
		player_base += _resolve_control_bonus(player_card, boss_card, logs)

	var player_total = max(0, int(floor(float(player_base) * matchup_rules.get_multiplier(player_card.get("family", ""), boss_card.get("family", "")))))
	var boss_total = max(0, int(floor(float(boss_base) * matchup_rules.get_multiplier(boss_card.get("family", ""), player_card.get("family", "")))))

	logs.append("玩家打出 %s，Boss 打出 %s。" % [player_card.get("name", player_card_id), boss_card.get("name", boss_card_id)])
	logs.append("回合点数：玩家 %d vs Boss %d。" % [player_total, boss_total])

	var margin = player_total - boss_total
	var player_damage = 0
	var boss_damage = 0
	if margin > 0:
		boss_damage = margin
	elif margin < 0:
		player_damage = abs(margin)
		if current_cover > 0:
			var absorbed = min(player_damage, current_cover)
			player_damage -= absorbed
			logs.append("Cover 吸收了 %d 点伤害。" % absorbed)
		if used_addon == "stop_loss" and player_damage > 1:
			player_damage = 1
			logs.append("StopLoss 将本回合玩家 HP 损失锁定为 1。")

	if used_addon == "leverage" and boss_damage > 0:
		boss_damage += 1
		run_state.pos += 1
		logs.append("Leverage 放大优势：对 Boss 额外造成 1 点伤害，并获得 +1 POS。")

	set_state.player_hp -= player_damage
	set_state.boss_hp -= boss_damage

	if margin < 0:
		_apply_costs(run_state, boss_card.get("loss_penalty", {}), logs, "%s 压力" % boss_card.get("name", boss_card_id))

	run_state.pos += margin
	run_state.clamp_pos()
	set_state.round_index += 1
	set_state.cover = 0
	_apply_followup_states(set_state, player_card.get("on_resolve", {}), logs)

	var set_finished = false
	var set_winner = ""
	if set_state.boss_hp <= 0:
		set_finished = true
		set_winner = "player"
	elif set_state.player_hp <= 0:
		set_finished = true
		set_winner = "boss"
	elif not set_state.has_rounds_remaining() or set_state.remaining_player_battle_cards.is_empty():
		set_finished = true
		set_winner = _resolve_tiebreak_winner(set_state, str(run_state.challenge_rules.get("tie_winner", "boss")))

	var challenge_finished = false
	var challenge_outcome = "ongoing"
	var challenge_snapshot = run_state.challenge_state.snapshot() if run_state.challenge_state != null else {}
	if run_state.is_collapsed():
		challenge_finished = true
		challenge_outcome = "defeat"
	elif set_finished:
		var set_result = run_state.finish_set(set_winner)
		challenge_finished = bool(set_result.get("challenge_finished", false))
		challenge_outcome = "victory" if str(set_result.get("challenge_winner", "boss")) == "player" else "defeat"
		if not challenge_finished:
			challenge_outcome = "ongoing"
		challenge_snapshot = set_result.get("challenge_snapshot", challenge_snapshot)

	var battle_state = "ongoing"
	if challenge_finished:
		battle_state = "challenge_victory" if challenge_outcome == "victory" else "challenge_defeat"
	elif set_finished:
		battle_state = "set_victory" if set_winner == "player" else "set_defeat"

	var result = {
		"player_card_id": player_card_id,
		"boss_card_id": boss_card_id,
		"player_card": player_card,
		"boss_card": boss_card,
		"player_total": player_total,
		"boss_total": boss_total,
		"margin": margin,
		"player_damage": player_damage,
		"boss_damage": boss_damage,
		"pos_after": run_state.pos,
		"used_addon": used_addon,
		"battle_state": battle_state,
		"round_won": margin > 0,
		"set_finished": set_finished,
		"set_winner": set_winner,
		"challenge_finished": challenge_finished,
		"challenge_outcome": challenge_outcome,
		"player_hp_after": set_state.player_hp,
		"boss_hp_after": set_state.boss_hp,
		"challenge_snapshot": challenge_snapshot,
		"set_snapshot": set_state.snapshot(),
		"run_snapshot": run_state.snapshot(),
		"logs": logs,
	}
	set_state.last_round_result = result.duplicate(true)
	run_state.last_round_result = result.duplicate(true)
	return result

func _resolve_control_bonus(player_card: Dictionary, boss_card: Dictionary, logs: Array[String]) -> int:
	var control_data = player_card.get("on_resolve", {})
	var targets: Array = control_data.get("control_bonus_vs", [])
	if boss_card.get("family", "") in targets:
		var bonus = int(control_data.get("control_bonus", 0))
		logs.append("Audit 命中条件，额外 %+d。" % bonus)
		return bonus
	return 0

func _apply_followup_states(set_state, effects: Dictionary, logs: Array[String]) -> void:
	if effects.has("set_next_bonus"):
		set_state.next_bonus = int(effects.get("set_next_bonus", 0))
		logs.append("下回合获得 Next +%d。" % set_state.next_bonus)
	if effects.has("set_next_penalty"):
		set_state.next_penalty = int(effects.get("set_next_penalty", 0))
		logs.append("下回合承受 Next -%d。" % set_state.next_penalty)

func _resolve_tiebreak_winner(set_state, tie_winner: String) -> String:
	if set_state.player_hp > set_state.boss_hp:
		return "player"
	if set_state.boss_hp > set_state.player_hp:
		return "boss"
	return tie_winner

func _apply_costs(run_state, delta: Dictionary, logs: Array[String], source_label: String) -> void:
	for key in delta.keys():
		var amount = int(delta[key])
		if amount <= 0:
			continue
		match str(key):
			"bod":
				run_state.bod -= amount
			"spr":
				run_state.spr -= amount
			"rep":
				run_state.rep -= amount
			"life":
				run_state.life -= amount
		logs.append("%s 造成 %s -%d。" % [source_label, str(key).to_upper(), amount])

func _data_loader():
	var main_loop = Engine.get_main_loop()
	if main_loop is SceneTree:
		return main_loop.root.get_node_or_null("DataLoader")
	return null

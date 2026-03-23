extends PanelContainer
class_name StatusPanel

@onready var _challenge_label: Label = $MarginContainer/VBoxContainer/ChallengeLabel
@onready var _set_round_label: Label = $MarginContainer/VBoxContainer/SetRoundLabel
@onready var _score_label: Label = $MarginContainer/VBoxContainer/ScoreLabel
@onready var _pos_bar: ProgressBar = $MarginContainer/VBoxContainer/PosBar
@onready var _pos_label: Label = $MarginContainer/VBoxContainer/PosLabel
@onready var _resource_label: Label = $MarginContainer/VBoxContainer/ResourceLabel
@onready var _carry_label: Label = $MarginContainer/VBoxContainer/CarryLabel

func update_from_run_state(run_state) -> void:
	var challenge_state = run_state.challenge_state
	var set_state = run_state.current_set_state

	if challenge_state == null:
		_challenge_label.text = "挑战未开始"
		_set_round_label.text = "局 / 回合：-"
		_score_label.text = "比分：-"
		_pos_label.text = "POS +0"
		_resource_label.text = "BOD 0 / SPR 0 / REP 0 / LIFE 0"
		_carry_label.text = "临时效果：-"
		return

	_challenge_label.text = "三局两胜 / 本次挑战"
	var displayed_set = challenge_state.current_set_index
	var displayed_round = 1
	if set_state != null:
		displayed_set = set_state.set_index
		displayed_round = min(int(set_state.round_index) + 1, int(set_state.max_rounds))
	_set_round_label.text = "第 %d 局  第 %d 回合" % [
		displayed_set,
		displayed_round,
	]
	_score_label.text = "比分：玩家 %d : Boss %d" % [
		int(challenge_state.player_set_wins),
		int(challenge_state.boss_set_wins),
	]
	_pos_bar.min_value = run_state.pos_min
	_pos_bar.max_value = run_state.pos_max
	_pos_bar.value = run_state.pos
	_pos_label.text = "POS %s" % _signed(run_state.pos)
	_resource_label.text = "BOD %d / SPR %d / REP %d / LIFE %d" % [run_state.bod, run_state.spr, run_state.rep, run_state.life]
	if set_state == null:
		_carry_label.text = "临时效果：-"
	else:
		_carry_label.text = "临时效果：Next %+d / Penalty -%d / Cover %d / 加注 %s" % [
			int(set_state.next_bonus),
			int(set_state.next_penalty),
			int(set_state.cover),
			set_state.round_active_addon if set_state.round_active_addon != "" else "无",
		]

func apply_effect_profile(profile: Dictionary) -> void:
	var fatigue = float(profile.get("fatigue", 0.0))
	var coldness = float(profile.get("coldness", 0.0))
	self_modulate = Color(1.0 - coldness * 0.14, 1.0 - fatigue * 0.20, 1.0 - coldness * 0.06, 1.0)

func _signed(value: int) -> String:
	if value > 0:
		return "+%d" % value
	return str(value)

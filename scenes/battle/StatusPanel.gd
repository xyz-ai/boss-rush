extends PanelContainer
class_name StatusPanel

@onready var _title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var _challenge_label: Label = $MarginContainer/VBoxContainer/ChallengeLabel
@onready var _set_round_label: Label = $MarginContainer/VBoxContainer/SetRoundLabel
@onready var _score_label: Label = $MarginContainer/VBoxContainer/ScoreLabel
@onready var _pos_label: Label = $MarginContainer/VBoxContainer/PosLabel
@onready var _carry_label: Label = $MarginContainer/VBoxContainer/CarryLabel

func _ready() -> void:
	_apply_panel_style()
	_title_label.add_theme_color_override("font_color", Color(0.92, 0.88, 0.80, 0.92))
	_challenge_label.add_theme_color_override("font_color", Color(0.84, 0.80, 0.72, 0.94))
	_set_round_label.add_theme_color_override("font_color", Color(0.90, 0.88, 0.84, 1.0))
	_score_label.add_theme_color_override("font_color", Color(0.92, 0.90, 0.86, 1.0))
	_pos_label.add_theme_color_override("font_color", Color(0.70, 0.78, 0.84, 0.96))
	_carry_label.add_theme_color_override("font_color", Color(0.78, 0.76, 0.72, 0.88))

func update_from_run_state(run_state) -> void:
	var challenge_state = run_state.challenge_state
	var set_state = run_state.current_set_state

	_title_label.text = "挑战"
	if challenge_state == null:
		_challenge_label.text = "未进入挑战"
		_set_round_label.text = "局 / 回合 -"
		_score_label.text = "比分 -"
		_pos_label.text = "POS +0"
		_carry_label.text = "Next +0 / Pen 0 / Cover 0 / 加注 无"
		return

	_challenge_label.text = "三局两胜 / 本次挑战"
	if set_state == null:
		_set_round_label.text = "第 %d 局" % int(challenge_state.current_set_index)
		_score_label.text = "比分 %d : %d" % [
			int(challenge_state.player_set_wins),
			int(challenge_state.boss_set_wins),
		]
		_pos_label.text = "POS %s" % _signed(int(run_state.pos))
		_carry_label.text = "临时状态尚未建立"
		return

	_set_round_label.text = "第 %d 局 · 第 %d 回合" % [
		int(set_state.set_index),
		min(int(set_state.round_index) + 1, int(set_state.max_rounds)),
	]
	_score_label.text = "比分 %d : %d" % [
		int(challenge_state.player_set_wins),
		int(challenge_state.boss_set_wins),
	]
	_pos_label.text = "POS %s" % _signed(int(run_state.pos))
	_carry_label.text = "Next %+d / Pen %d / Cover %d / 加注 %s" % [
		int(set_state.next_bonus),
		int(set_state.next_penalty),
		int(set_state.cover),
		set_state.round_active_addon if set_state.round_active_addon != "" else "无",
	]

func apply_effect_profile(profile: Dictionary) -> void:
	var fatigue = float(profile.get("fatigue", 0.0))
	var coldness = float(profile.get("coldness", 0.0))
	self_modulate = Color(1.0 - coldness * 0.14, 1.0 - fatigue * 0.20, 1.0 - coldness * 0.06, 1.0)

func _apply_panel_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.045, 0.04, 0.58)
	style.border_color = Color(0.80, 0.74, 0.62, 0.12)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.shadow_color = Color(0, 0, 0, 0.16)
	style.shadow_size = 16
	add_theme_stylebox_override("panel", style)

func _signed(value: int) -> String:
	if value > 0:
		return "+%d" % value
	return str(value)

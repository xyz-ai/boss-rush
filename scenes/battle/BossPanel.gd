extends PanelContainer
class_name BossPanel

signal peek_requested()

var _boss_def: Dictionary = {}
var _accent: Color = Color(0.84, 0.78, 0.72)

@onready var _boss_name: Label = $MarginContainer/VBoxContainer/BossName
@onready var _boss_desc: Label = $MarginContainer/VBoxContainer/BossDesc
@onready var _pool_label: Label = $MarginContainer/VBoxContainer/PoolLabel
@onready var _state_label: Label = $MarginContainer/VBoxContainer/StateLabel
@onready var _score_label: Label = $MarginContainer/VBoxContainer/FooterRow/ScoreLabel
@onready var _hp_label: Label = $MarginContainer/VBoxContainer/FooterRow/HpLabel
@onready var _peek_button: Button = $MarginContainer/VBoxContainer/PeekButton

func _ready() -> void:
	_peek_button.pressed.connect(_on_peek_button_pressed)
	_apply_theme()

func set_boss(boss_def: Dictionary) -> void:
	_boss_def = boss_def.duplicate(true)
	_boss_name.text = "%s / %s" % [boss_def.get("title", "Boss"), boss_def.get("name", "")]
	_boss_desc.text = _compact_description(str(boss_def.get("description", "")))

func set_accent(accent: Color) -> void:
	_accent = accent
	if is_node_ready():
		_apply_theme()

func update_from_battle(run_state, boss_def: Dictionary = {}) -> void:
	if not boss_def.is_empty():
		set_boss(boss_def)
	var challenge_state = run_state.challenge_state
	var set_state = run_state.current_set_state
	if challenge_state == null or set_state == null:
		_score_label.text = "比分 -"
		_hp_label.text = "HP -"
		_pool_label.text = "未窥破 · 已出 0 / 0"
		_state_label.text = "BOD - / SPR - / REP -"
		return
	_score_label.text = "比分 %d : %d" % [
		int(challenge_state.player_set_wins),
		int(challenge_state.boss_set_wins),
	]
	_hp_label.text = "HP %d" % int(set_state.boss_hp)
	_state_label.text = "BOD %d / SPR %d / REP %d" % [
		int(run_state.boss_bod),
		int(run_state.boss_spr),
		int(run_state.boss_rep),
	]
	set_deck_status(set_state)

func set_deck_status(set_state) -> void:
	if set_state == null:
		_pool_label.text = "未窥破 · 已出 0 / 0"
		return
	var used_count = set_state.boss_used_cards.size()
	var total_count = set_state.boss_deck.size()
	var reveal_text = "未窥破"
	if set_state.boss_revealed:
		reveal_text = "已窥破"
	_pool_label.text = "%s · 已出 %d / %d" % [reveal_text, used_count, total_count]

func set_peek_state(cost: int, free_peek: bool, disabled: bool) -> void:
	_peek_button.disabled = disabled
	if disabled:
		_peek_button.text = "牌池已展开"
	elif free_peek:
		_peek_button.text = "免费查看牌池"
	else:
		_peek_button.text = "花 %d SPR 查看牌池" % cost

func apply_effect_profile(profile: Dictionary) -> void:
	var fatigue = float(profile.get("fatigue", 0.0))
	var coldness = float(profile.get("coldness", 0.0))
	self_modulate = Color(1.0 - coldness * 0.10, 1.0 - fatigue * 0.12, 1.0 - coldness * 0.04, 1.0)

func _apply_theme() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.045, 0.04, 0.50)
	style.border_color = Color(_accent.r, _accent.g, _accent.b, 0.18)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.shadow_color = Color(0, 0, 0, 0.18)
	style.shadow_size = 18
	add_theme_stylebox_override("panel", style)

	_boss_name.add_theme_color_override("font_color", Color(0.96, 0.92, 0.86, 0.98))
	_boss_desc.add_theme_color_override("font_color", Color(0.84, 0.82, 0.78, 0.88))
	_pool_label.add_theme_color_override("font_color", Color(_accent.r, _accent.g, _accent.b, 0.92))
	_state_label.add_theme_color_override("font_color", Color(0.84, 0.82, 0.78, 0.90))
	_peek_button.add_theme_stylebox_override("normal", _make_button_style(Color(0.12, 0.10, 0.09, 0.92), Color(_accent.r, _accent.g, _accent.b, 0.34)))
	_peek_button.add_theme_stylebox_override("hover", _make_button_style(Color(0.18, 0.14, 0.12, 0.96), Color(_accent.r, _accent.g, _accent.b, 0.54)))
	_peek_button.add_theme_stylebox_override("pressed", _make_button_style(Color(0.08, 0.07, 0.06, 0.96), Color(_accent.r, _accent.g, _accent.b, 0.42)))
	_peek_button.add_theme_stylebox_override("disabled", _make_button_style(Color(0.08, 0.07, 0.06, 0.56), Color(0.40, 0.38, 0.34, 0.18)))
	_peek_button.add_theme_color_override("font_color", Color(0.96, 0.92, 0.88))

func _make_button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style

func _on_peek_button_pressed() -> void:
	emit_signal("peek_requested")

func _compact_description(text: String) -> String:
	var clean := text.strip_edges()
	if clean.is_empty():
		return ""
	if clean.length() > 34:
		return "%s..." % clean.substr(0, 34)
	return clean

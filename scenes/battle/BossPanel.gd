extends PanelContainer
class_name BossPanel

signal peek_requested()

var _boss_def: Dictionary = {}

@onready var _boss_name: Label = $MarginContainer/VBoxContainer/BossName
@onready var _boss_desc: Label = $MarginContainer/VBoxContainer/InfoScroll/InfoVBox/BossDesc
@onready var _pool_label: Label = $MarginContainer/VBoxContainer/InfoScroll/InfoVBox/PoolLabel
@onready var _score_label: Label = $MarginContainer/VBoxContainer/FooterRow/ScoreLabel
@onready var _hp_label: Label = $MarginContainer/VBoxContainer/FooterRow/HpLabel
@onready var _peek_button: Button = $MarginContainer/VBoxContainer/PeekButton

func _ready() -> void:
	_peek_button.pressed.connect(_on_peek_button_pressed)

func set_boss(boss_def: Dictionary) -> void:
	_boss_def = boss_def.duplicate(true)
	_boss_name.text = "%s / %s" % [boss_def.get("title", "Boss"), boss_def.get("name", "")]
	_boss_desc.text = str(boss_def.get("description", ""))

func update_from_battle(run_state, boss_def: Dictionary = {}) -> void:
	if not boss_def.is_empty():
		set_boss(boss_def)
	var challenge_state = run_state.challenge_state
	var set_state = run_state.current_set_state
	if challenge_state == null or set_state == null:
		_score_label.text = "Boss 胜场：-"
		_hp_label.text = "Boss HP：-"
		_pool_label.text = "卡池状态：未开始"
		return
	_score_label.text = "Boss 胜场 %d / 玩家胜场 %d" % [
		int(challenge_state.boss_set_wins),
		int(challenge_state.player_set_wins),
	]
	_hp_label.text = "本局 Boss HP %d" % int(set_state.boss_hp)
	set_deck_status(set_state)

func set_deck_status(set_state) -> void:
	if set_state == null:
		_pool_label.text = "卡池状态：未开始"
		return
	var used_count = set_state.boss_used_cards.size()
	var total_count = set_state.boss_deck.size()
	var reveal_text = "未查看"
	if set_state.boss_revealed:
		reveal_text = "已展开"
	_pool_label.text = "卡池状态：%s，已出 %d / 总数 %d" % [reveal_text, used_count, total_count]

func set_peek_state(cost: int, free_peek: bool, disabled: bool) -> void:
	_peek_button.disabled = disabled
	if disabled:
		_peek_button.text = "卡池已展开"
	elif free_peek:
		_peek_button.text = "免费查看卡池"
	else:
		_peek_button.text = "支付 %d SPR 查看卡池" % cost

func apply_effect_profile(profile: Dictionary) -> void:
	var fatigue = float(profile.get("fatigue", 0.0))
	var coldness = float(profile.get("coldness", 0.0))
	self_modulate = Color(1.0 - coldness * 0.10, 1.0 - fatigue * 0.12, 1.0 - coldness * 0.04, 1.0)

func _on_peek_button_pressed() -> void:
	emit_signal("peek_requested")

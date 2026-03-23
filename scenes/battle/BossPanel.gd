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
		return
	_score_label.text = "Boss 胜场 %d / 玩家胜场 %d" % [
		int(challenge_state.boss_set_wins),
		int(challenge_state.player_set_wins),
	]
	_hp_label.text = "本局 Boss HP %d" % int(set_state.boss_hp)

func set_round_pool(pool_ids: Array, revealed: bool) -> void:
	if pool_ids.is_empty():
		_pool_label.text = "候选牌池：等待下一回合。"
		return
	if not revealed:
		_pool_label.text = "候选牌池：%d 张未揭示。" % pool_ids.size()
		return

	var names: Array[String] = []
	var data_loader = get_node_or_null("/root/DataLoader")
	for card_id in pool_ids:
		names.append(data_loader.get_boss_card(str(card_id)).get("name", str(card_id)))
	_pool_label.text = "候选牌池：%s" % " / ".join(names)

func set_peek_state(cost: int, free_peek: bool, disabled: bool) -> void:
	_peek_button.disabled = disabled
	if disabled:
		_peek_button.text = "牌池已查看"
	elif free_peek:
		_peek_button.text = "免费查看牌池"
	else:
		_peek_button.text = "支付 %d SPR 查看牌池" % cost

func apply_effect_profile(profile: Dictionary) -> void:
	var fatigue = float(profile.get("fatigue", 0.0))
	var coldness = float(profile.get("coldness", 0.0))
	self_modulate = Color(1.0 - coldness * 0.10, 1.0 - fatigue * 0.12, 1.0 - coldness * 0.04, 1.0)

func _on_peek_button_pressed() -> void:
	emit_signal("peek_requested")

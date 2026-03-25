extends PanelContainer
class_name ClashAreaView

@onready var _player_card_name: Label = $MarginContainer/VBoxContainer/CardRow/PlayerCard/MarginContainer/VBoxContainer/PlayerCardName
@onready var _player_card_meta: Label = $MarginContainer/VBoxContainer/CardRow/PlayerCard/MarginContainer/VBoxContainer/PlayerCardMeta
@onready var _boss_card_name: Label = $MarginContainer/VBoxContainer/CardRow/BossCard/MarginContainer/VBoxContainer/BossCardName
@onready var _boss_card_meta: Label = $MarginContainer/VBoxContainer/CardRow/BossCard/MarginContainer/VBoxContainer/BossCardMeta
@onready var _summary_label: Label = $MarginContainer/VBoxContainer/SummaryLabel

func _ready() -> void:
	assert(_player_card_name != null, "ClashAreaView is missing PlayerCardName.")
	assert(_player_card_meta != null, "ClashAreaView is missing PlayerCardMeta.")
	assert(_boss_card_name != null, "ClashAreaView is missing BossCardName.")
	assert(_boss_card_meta != null, "ClashAreaView is missing BossCardMeta.")
	assert(_summary_label != null, "ClashAreaView is missing SummaryLabel.")
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.035, 0.03, 0.60)
	style.border_color = Color(0.84, 0.76, 0.62, 0.12)
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
	clear_display()

func clear_display() -> void:
	_player_card_name.text = "玩家出牌"
	_player_card_meta.text = "等待出牌"
	_boss_card_name.text = "Boss 出牌"
	_boss_card_meta.text = "等待出牌"
	_summary_label.text = "本回合结算会显示在这里。"

func show_result(result: Dictionary) -> void:
	if result.is_empty():
		clear_display()
		return
	var player_card: Dictionary = result.get("player_card", {})
	var boss_card: Dictionary = result.get("boss_card", {})
	_player_card_name.text = str(player_card.get("name", result.get("player_card_id", "玩家出牌")))
	_player_card_meta.text = "%s / 点数 %d" % [str(player_card.get("family", "")).capitalize(), int(result.get("player_total", 0))]
	_boss_card_name.text = str(boss_card.get("name", result.get("boss_card_id", "Boss 出牌")))
	_boss_card_meta.text = "%s / 点数 %d" % [str(boss_card.get("family", "")).capitalize(), int(result.get("boss_total", 0))]
	_summary_label.text = "伤害：Boss -%d / 玩家 -%d    POS %+d" % [
		int(result.get("boss_damage", 0)),
		int(result.get("player_damage", 0)),
		int(result.get("margin", 0)),
	]

func apply_effect_profile(profile: Dictionary) -> void:
	var fatigue = float(profile.get("fatigue", 0.0))
	var coldness = float(profile.get("coldness", 0.0))
	self_modulate = Color(1.0 - coldness * 0.08, 1.0 - fatigue * 0.10, 1.0 - coldness * 0.02, 1.0)

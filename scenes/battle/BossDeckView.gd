extends PanelContainer
class_name BossDeckView

var _effect_profile: Dictionary = {}

@onready var _deck_title: Label = $MarginContainer/VBoxContainer/DeckTitle
@onready var _deck_row: HBoxContainer = $MarginContainer/VBoxContainer/DeckScroll/DeckRow

func refresh_from_state(set_state) -> void:
	for child in _deck_row.get_children():
		child.queue_free()

	if set_state == null:
		_deck_title.text = "对手牌列"
		return

	_deck_title.text = "对手牌列 %d 张 / 已出 %d" % [
		set_state.boss_deck.size(),
		set_state.boss_used_cards.size(),
	]

	var used_counts := _build_used_counts(set_state.boss_used_cards)
	for card_id in set_state.boss_deck:
		var card_state := "hidden"
		if set_state.boss_revealed:
			card_state = "ready"
			if int(used_counts.get(card_id, 0)) > 0:
				card_state = "used"
				used_counts[card_id] = int(used_counts.get(card_id, 0)) - 1
		_deck_row.add_child(_build_card_widget(str(card_id), card_state))

func apply_effect_profile(profile: Dictionary) -> void:
	_effect_profile = profile.duplicate(true)
	var fatigue = float(profile.get("fatigue", 0.0))
	var coldness = float(profile.get("coldness", 0.0))
	self_modulate = Color(1.0 - coldness * 0.08, 1.0 - fatigue * 0.08, 1.0 - coldness * 0.03, 1.0)

func _build_used_counts(used_cards: Array) -> Dictionary:
	var counts: Dictionary = {}
	for card_id in used_cards:
		var key = str(card_id)
		counts[key] = int(counts.get(key, 0)) + 1
	return counts

func _build_card_widget(card_id: String, card_state: String) -> Control:
	var card_def = _data_loader().get_boss_card(card_id)
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(126, 104)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var panel_box = StyleBoxFlat.new()
	panel_box.corner_radius_top_left = 10
	panel_box.corner_radius_top_right = 10
	panel_box.corner_radius_bottom_left = 10
	panel_box.corner_radius_bottom_right = 10
	panel_box.border_width_left = 1
	panel_box.border_width_top = 1
	panel_box.border_width_right = 1
	panel_box.border_width_bottom = 1
	panel_box.shadow_size = 10
	panel_box.shadow_color = Color(0, 0, 0, 0.18)
	panel_box.border_color = Color(0.64, 0.67, 0.73, 0.42)

	var title_text = "?"
	var body_text = "未查看"
	var badge_text = ""
	var title_color = Color(0.92, 0.94, 0.96)
	var alpha = 1.0
	match card_state:
		"hidden":
			panel_box.bg_color = Color(0.11, 0.11, 0.13, 0.88)
			title_text = "?"
			body_text = "未查看"
			alpha = 0.76
		"used":
			panel_box.bg_color = Color(0.20, 0.21, 0.24, 0.80)
			title_text = str(card_def.get("name", card_id))
			body_text = "已使用"
			badge_text = "已出"
			title_color = Color(0.72, 0.74, 0.77)
			alpha = 0.50
		_:
			panel_box.bg_color = Color(0.27, 0.30, 0.34, 0.95)
			title_text = str(card_def.get("name", card_id))
			body_text = str(card_def.get("family", "")).capitalize()
	panel.add_theme_stylebox_override("panel", panel_box)
	panel.modulate.a = alpha

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	var badge = Label.new()
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.text = badge_text
	badge.modulate = Color(0.90, 0.68, 0.52, 0.92)
	box.add_child(badge)

	var title = Label.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.text = title_text
	title.modulate = title_color
	box.add_child(title)

	var body = Label.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.text = body_text
	body.modulate = Color(0.78, 0.80, 0.84, 0.88)
	box.add_child(body)

	var tooltip_title = "Boss 未揭示卡"
	var tooltip_body = "当前还没有查看这一局的 Boss 卡池。"
	if card_state != "hidden":
		tooltip_title = str(card_def.get("name", card_id))
		tooltip_body = str(card_def.get("text", ""))
	panel.mouse_entered.connect(func():
		SignalBus.emit_signal("tooltip_requested", tooltip_title, tooltip_body, panel.global_position)
	)
	panel.mouse_exited.connect(func():
		SignalBus.emit_signal("tooltip_hidden")
	)
	return panel

func _data_loader():
	return get_node_or_null("/root/DataLoader")

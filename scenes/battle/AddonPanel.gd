extends PanelContainer
class_name AddonPanel

signal addon_selected(addon_id: String)

@onready var _addon_list: VBoxContainer = $MarginContainer/VBoxContainer/ListScroll/AddonList
@onready var _hint_label: Label = $MarginContainer/VBoxContainer/HintLabel

var _rows: Dictionary = {}

func set_inventory(inventory: Dictionary, addon_defs: Array[Dictionary], active_addon: String) -> void:
	if _rows.size() != addon_defs.size():
		_rebuild(addon_defs)

	for addon_def in addon_defs:
		var addon_id = str(addon_def.get("id", ""))
		var row_data: Dictionary = _rows.get(addon_id, {})
		if row_data.is_empty():
			continue

		var count = int(inventory.get(addon_id, 0))
		var title_label: Label = row_data["title"]
		var desc_label: Label = row_data["description"]
		var action_button: Button = row_data["button"]

		title_label.text = "%s x%d" % [addon_def.get("name", addon_id), count]
		desc_label.text = str(addon_def.get("text", ""))
		action_button.disabled = count <= 0 or (active_addon != "" and active_addon != addon_id)
		action_button.text = "使用"
		if active_addon == addon_id:
			action_button.text = "已启用"

	_hint_label.text = "加注牌属于本次挑战资源。每回合最多使用 1 张，用掉后直到商店补充前都不会恢复。"

func apply_effect_profile(profile: Dictionary) -> void:
	var fatigue = float(profile.get("fatigue", 0.0))
	self_modulate = Color(1.0 - fatigue * 0.08, 1.0 - fatigue * 0.14, 1.0, 1.0)

func _rebuild(addon_defs: Array[Dictionary]) -> void:
	for child in _addon_list.get_children():
		child.queue_free()
	_rows.clear()

	for addon_def in addon_defs:
		var addon_id = str(addon_def.get("id", ""))

		var row_panel = PanelContainer.new()
		row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_panel.custom_minimum_size = Vector2(0, 78)
		_addon_list.add_child(row_panel)

		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 12)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_right", 12)
		margin.add_theme_constant_override("margin_bottom", 10)
		row_panel.add_child(margin)

		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 12)
		margin.add_child(row)

		var info_box = VBoxContainer.new()
		info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
		info_box.add_theme_constant_override("separation", 4)
		row.add_child(info_box)

		var title_label = Label.new()
		title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info_box.add_child(title_label)

		var desc_label = Label.new()
		desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info_box.add_child(desc_label)

		var action_button = Button.new()
		action_button.custom_minimum_size = Vector2(84, 42)
		action_button.text = "使用"
		action_button.pressed.connect(_on_addon_button_pressed.bind(addon_id))
		row.add_child(action_button)

		_rows[addon_id] = {
			"title": title_label,
			"description": desc_label,
			"button": action_button,
		}

func _on_addon_button_pressed(addon_id: String) -> void:
	emit_signal("addon_selected", addon_id)

extends RefCounted
class_name MvpBetRowView

signal bet_selected(bet_id: String)

const UI_ASSET_PATHS := preload("res://scripts/ui/UiAssetPaths.gd")
const UI_TEXTURE_HELPER := preload("res://scripts/ui/UiTextureHelper.gd")

var _row: HBoxContainer
var _card_scene: PackedScene
var _buttons: Dictionary = {}

func _init(row: HBoxContainer, card_scene: PackedScene = null) -> void:
	_row = row
	_card_scene = card_scene
	_row.layout_mode = 1
	_row.anchor_left = 0.0
	_row.anchor_top = 0.0
	_row.anchor_right = 1.0
	_row.anchor_bottom = 1.0
	_row.offset_left = 0.0
	_row.offset_top = 0.0
	_row.offset_right = 0.0
	_row.offset_bottom = 0.0
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 12)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_entries(entries: Array[Dictionary], interactive: bool = true) -> void:
	_clear()
	for entry in entries:
		var control := _create_entry_control(entry, interactive)
		_row.add_child(control)
		_buttons[control.name] = control

func clear() -> void:
	_clear()

func _on_button_pressed(bet_id: String) -> void:
	bet_selected.emit(bet_id)

func _create_entry_control(entry: Dictionary, interactive: bool) -> Control:
	var disabled := bool(entry.get("disabled", false)) or not interactive
	if _card_scene != null:
		var card_view := _card_scene.instantiate() as MvpCardView
		if card_view != null:
			var bet_id := str(entry.get("id", "unknown"))
			card_view.name = "BetCard_%s" % bet_id
			card_view.set_card_size(Vector2(126, 176))
			card_view.mouse_filter = Control.MOUSE_FILTER_STOP
			card_view.configure(_entry_to_card_data(entry), _entry_view_state(entry, disabled), not disabled)
			if not disabled:
				card_view.pressed.connect(_on_button_pressed.bind(bet_id))
			_connect_tooltip(card_view, entry)
			return card_view

	var button := Button.new()
	button.name = "BetButton_%s" % str(entry.get("id", "unknown"))
	button.text = str(entry.get("label", "Bet"))
	button.custom_minimum_size = Vector2(124, 52)
	button.disabled = disabled
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	UI_TEXTURE_HELPER.apply_button_textures(
		button,
		UI_ASSET_PATHS.BUTTON_PRIMARY,
		UI_ASSET_PATHS.BUTTON_HOVER,
		UI_ASSET_PATHS.BUTTON_PRESSED,
		UI_ASSET_PATHS.BUTTON_DISABLED
	)
	if interactive and not button.disabled:
		button.pressed.connect(_on_button_pressed.bind(str(entry.get("id", ""))))
	_connect_tooltip(button, entry)
	return button

func _entry_to_card_data(entry: Dictionary) -> Dictionary:
	return {
		"id": str(entry.get("id", "unknown")),
		"type": "bet",
		"display_name": str(entry.get("label", entry.get("tooltip_title", "Bet"))),
	}

func _entry_view_state(entry: Dictionary, disabled: bool) -> String:
	if bool(entry.get("selected", false)):
		return "selected"
	if disabled:
		return "locked"
	return "normal"

func _connect_tooltip(control: Control, entry: Dictionary) -> void:
	var tooltip_title := str(entry.get("tooltip_title", ""))
	var tooltip_body := str(entry.get("tooltip_body", ""))
	if tooltip_title.is_empty() and tooltip_body.is_empty():
		return
	control.mouse_entered.connect(_on_button_mouse_entered.bind(control, tooltip_title, tooltip_body))
	control.mouse_exited.connect(_on_button_mouse_exited)

func _on_button_mouse_entered(control: Control, tooltip_title: String, tooltip_body: String) -> void:
	SignalBus.emit_signal("tooltip_requested", tooltip_title, tooltip_body, control.global_position)

func _on_button_mouse_exited() -> void:
	SignalBus.emit_signal("tooltip_hidden")

func _clear() -> void:
	SignalBus.emit_signal("tooltip_hidden")
	for child in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	_buttons.clear()

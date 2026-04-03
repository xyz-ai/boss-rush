extends RefCounted
class_name MvpBetRowView

signal bet_selected(bet_id: String)

var _row: HBoxContainer
var _buttons: Dictionary = {}

func _init(row: HBoxContainer) -> void:
	_row = row
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
		var button := Button.new()
		button.name = "BetButton_%s" % str(entry.get("id", "unknown"))
		button.text = str(entry.get("label", "Bet"))
		button.custom_minimum_size = Vector2(124, 52)
		button.disabled = bool(entry.get("disabled", false)) or not interactive
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		if interactive and not button.disabled:
			button.pressed.connect(_on_button_pressed.bind(str(entry.get("id", ""))))
		_row.add_child(button)
		_buttons[button.name] = button

func clear() -> void:
	_clear()

func _on_button_pressed(bet_id: String) -> void:
	bet_selected.emit(bet_id)

func _clear() -> void:
	for child in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	_buttons.clear()

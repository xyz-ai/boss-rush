extends PanelContainer
class_name TooltipPanel

@onready var _title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var _body_label: Label = $MarginContainer/VBoxContainer/BodyLabel

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	SignalBus.tooltip_requested.connect(_on_tooltip_requested)
	SignalBus.tooltip_hidden.connect(_on_tooltip_hidden)

func _process(_delta: float) -> void:
	if not visible:
		return
	var mouse_pos = get_viewport().get_mouse_position() + Vector2(18, 18)
	var size = get_combined_minimum_size()
	var viewport_size = get_viewport_rect().size
	mouse_pos.x = min(mouse_pos.x, viewport_size.x - size.x - 12.0)
	mouse_pos.y = min(mouse_pos.y, viewport_size.y - size.y - 12.0)
	global_position = mouse_pos

func _on_tooltip_requested(title: String, body: String, screen_position: Vector2) -> void:
	_title_label.text = title
	_body_label.text = body
	visible = true
	global_position = screen_position + Vector2(18, 18)

func _on_tooltip_hidden() -> void:
	visible = false

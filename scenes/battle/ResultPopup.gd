extends Control
class_name ResultPopup

signal continue_pressed()

@onready var _title_label: Label = $CenterContainer/PopupPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var _body_label: RichTextLabel = $CenterContainer/PopupPanel/MarginContainer/VBoxContainer/BodyScroll/BodyLabel
@onready var _body_scroll: ScrollContainer = $CenterContainer/PopupPanel/MarginContainer/VBoxContainer/BodyScroll
@onready var _continue_button: Button = $CenterContainer/PopupPanel/MarginContainer/VBoxContainer/ContinueButton

func _ready() -> void:
	visible = false
	_continue_button.pressed.connect(_on_continue_pressed)

func show_result(title: String, body: String, continue_text: String) -> void:
	_title_label.text = title
	_body_label.text = body
	_continue_button.text = continue_text
	_body_scroll.scroll_vertical = 0
	visible = true

func hide_popup() -> void:
	visible = false

func _on_continue_pressed() -> void:
	visible = false
	emit_signal("continue_pressed")

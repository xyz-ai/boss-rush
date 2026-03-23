extends Control
class_name CardView

signal card_selected(card_id: String)

@onready var _tilt_root: Control = $TiltRoot
@onready var _title_label: Label = $TiltRoot/CardPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var _meta_label: Label = $TiltRoot/CardPanel/MarginContainer/VBoxContainer/MetaLabel
@onready var _body_label: Label = $TiltRoot/CardPanel/MarginContainer/VBoxContainer/BodyLabel
@onready var _select_button: Button = $TiltRoot/CardPanel/MarginContainer/VBoxContainer/SelectButton

var card_id: String = ""
var card_def: Dictionary = {}
var hover_instability: float = 0.0
var _hovered: bool = false
var _rng = RandomNumberGenerator.new()
var _hover_tween: Tween

func _ready() -> void:
	_assert_ui_refs()
	_rng.randomize()
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	resized.connect(_update_pivot)
	_select_button.pressed.connect(_on_pressed)
	_update_pivot()
	if not card_def.is_empty():
		refresh()

func setup(definition: Dictionary) -> void:
	card_def = definition.duplicate(true)
	card_id = str(card_def.get("id", ""))
	if is_node_ready():
		refresh()

func refresh() -> void:
	assert(is_node_ready(), "CardView.refresh() called before the node was ready.")
	_assert_ui_refs()
	var tag_parts: Array[String] = []
	for tag in card_def.get("ui_tags", []):
		tag_parts.append(str(tag))

	var meta_lines: Array[String] = []
	if not tag_parts.is_empty():
		meta_lines.append("标签：%s" % " / ".join(tag_parts))
	meta_lines.append("类型：%s   Base %d" % [str(card_def.get("family", "")), int(card_def.get("base", 0))])

	_title_label.text = str(card_def.get("name", card_id))
	_meta_label.text = "\n".join(meta_lines)
	_body_label.text = str(card_def.get("text", ""))
	_select_button.text = "打出"
	_select_button.disabled = card_id.is_empty()

func set_hover_instability(amount: float) -> void:
	hover_instability = amount
	if not _hovered:
		_tilt_root.rotation_degrees = 0.0

func _process(_delta: float) -> void:
	if _hovered and hover_instability > 0.01:
		_tilt_root.rotation_degrees = -1.4 + _rng.randf_range(-hover_instability, hover_instability) * 0.12
		_tilt_root.position.x = _rng.randf_range(-1.0, 1.0) * hover_instability * 0.04
	elif not _hovered and abs(_tilt_root.rotation_degrees) > 0.01:
		_tilt_root.rotation_degrees = lerp(_tilt_root.rotation_degrees, 0.0, 0.24)
		_tilt_root.position.x = lerp(_tilt_root.position.x, 0.0, 0.24)

func _on_pressed() -> void:
	_play_press_feedback()
	emit_signal("card_selected", card_id)

func _on_mouse_entered() -> void:
	_hovered = true
	_play_hover_state(Vector2(0.0, -18.0), Vector2(1.04, 1.04), -1.4)
	SignalBus.emit_signal("tooltip_requested", card_def.get("name", card_id), card_def.get("text", ""), global_position)

func _on_mouse_exited() -> void:
	_hovered = false
	_play_hover_state(Vector2.ZERO, Vector2.ONE, 0.0)
	SignalBus.emit_signal("tooltip_hidden")

func _play_hover_state(offset: Vector2, scale_value: Vector2, rotation_value: float) -> void:
	if _hover_tween != null:
		_hover_tween.kill()
	_hover_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(_tilt_root, "position", offset, 0.14)
	_hover_tween.parallel().tween_property(_tilt_root, "scale", scale_value, 0.14)
	_hover_tween.parallel().tween_property(_tilt_root, "rotation_degrees", rotation_value, 0.14)

func _play_press_feedback() -> void:
	var press_target_scale = Vector2.ONE if not _hovered else Vector2(1.04, 1.04)
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_tilt_root, "scale", press_target_scale * 0.97, 0.05)
	tween.tween_property(_tilt_root, "scale", press_target_scale, 0.08)

func _update_pivot() -> void:
	_tilt_root.pivot_offset = _tilt_root.size * 0.5

func _assert_ui_refs() -> void:
	assert(_tilt_root != null, "CardView is missing node at path TiltRoot.")
	assert(_title_label != null, "CardView is missing node at path TiltRoot/CardPanel/MarginContainer/VBoxContainer/TitleLabel.")
	assert(_meta_label != null, "CardView is missing node at path TiltRoot/CardPanel/MarginContainer/VBoxContainer/MetaLabel.")
	assert(_body_label != null, "CardView is missing node at path TiltRoot/CardPanel/MarginContainer/VBoxContainer/BodyLabel.")
	assert(_select_button != null, "CardView is missing node at path TiltRoot/CardPanel/MarginContainer/VBoxContainer/SelectButton.")

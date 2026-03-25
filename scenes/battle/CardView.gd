extends Control
class_name CardView

signal card_selected(card_id: String)

const CARD_FRAME_PATH := "res://assets/battle/cards/frames/card_frame_main.png"
const CARD_SHADOW_PATH := "res://assets/battle/effects/shadow_card_soft.png"
const PORTRAIT_PATHS := {
	"growth": "res://assets/battle/cards/portraits/card_portrait_silhouette_01.png",
	"aggression": "res://assets/battle/cards/portraits/card_portrait_silhouette_02.png",
	"defense": "res://assets/battle/cards/portraits/card_portrait_silhouette_02.png",
	"control": "res://assets/battle/cards/portraits/card_portrait_silhouette_03.png",
}

@onready var _shadow: TextureRect = $Shadow
@onready var _tilt_root: Control = $TiltRoot
@onready var _backdrop: ColorRect = $TiltRoot/CardSurface/Backdrop
@onready var _portrait_glow: ColorRect = $TiltRoot/CardSurface/PortraitGlow
@onready var _portrait_texture: TextureRect = $TiltRoot/CardSurface/PortraitTexture
@onready var _frame_texture: TextureRect = $TiltRoot/CardSurface/FrameTexture
@onready var _title_label: Label = $TiltRoot/CardSurface/MarginContainer/VBoxContainer/TitleLabel
@onready var _meta_label: Label = $TiltRoot/CardSurface/MarginContainer/VBoxContainer/MetaLabel
@onready var _body_label: Label = $TiltRoot/CardSurface/MarginContainer/VBoxContainer/BodyLabel
@onready var _select_button: Button = $TiltRoot/CardSurface/MarginContainer/VBoxContainer/SelectButton

var card_id: String = ""
var card_def: Dictionary = {}
var hover_instability: float = 0.0
var _hovered: bool = false
var _base_tilt_rotation: float = 0.0
var _base_tilt_scale: Vector2 = Vector2.ONE
var _rng = RandomNumberGenerator.new()
var _hover_tween: Tween

func _ready() -> void:
	_assert_ui_refs()
	_rng.randomize()
	_apply_visual_theme()
	_body_label.max_lines_visible = 4
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
	_title_label.text = str(card_def.get("name", card_id))
	_meta_label.text = "%s  Base %d" % [str(card_def.get("family", "")).capitalize(), int(card_def.get("base", 0))]
	_body_label.text = _compact_body(str(card_def.get("text", "")))
	_select_button.text = "打出"
	_select_button.disabled = card_id.is_empty()
	_apply_family_theme()

func set_hover_instability(amount: float) -> void:
	hover_instability = amount
	if not _hovered:
		_tilt_root.rotation_degrees = _base_tilt_rotation
		_tilt_root.scale = _base_tilt_scale

func set_table_pose(angle_degrees: float, scale_factor: float) -> void:
	_base_tilt_rotation = angle_degrees
	_base_tilt_scale = Vector2.ONE * scale_factor
	if not _hovered and is_node_ready():
		_tilt_root.rotation_degrees = _base_tilt_rotation
		_tilt_root.scale = _base_tilt_scale

func _process(_delta: float) -> void:
	if _hovered and hover_instability > 0.01:
		_tilt_root.rotation_degrees = _base_tilt_rotation + _rng.randf_range(-hover_instability, hover_instability) * 0.12
		_tilt_root.position.x = _rng.randf_range(-1.0, 1.0) * hover_instability * 0.04
	elif not _hovered and abs(_tilt_root.rotation_degrees) > 0.01:
		_tilt_root.rotation_degrees = lerp(_tilt_root.rotation_degrees, _base_tilt_rotation, 0.24)
		_tilt_root.position.x = lerp(_tilt_root.position.x, 0.0, 0.24)
		_tilt_root.scale = _tilt_root.scale.lerp(_base_tilt_scale, 0.24)

func _on_pressed() -> void:
	_play_press_feedback()
	emit_signal("card_selected", card_id)

func _on_mouse_entered() -> void:
	_hovered = true
	_play_hover_state(Vector2(0.0, -18.0), _base_tilt_scale * 1.04, _base_tilt_rotation * 0.7)
	SignalBus.emit_signal("tooltip_requested", card_def.get("name", card_id), str(card_def.get("text", "")), global_position)

func _on_mouse_exited() -> void:
	_hovered = false
	_play_hover_state(Vector2.ZERO, _base_tilt_scale, _base_tilt_rotation)
	SignalBus.emit_signal("tooltip_hidden")

func _play_hover_state(offset: Vector2, scale_value: Vector2, rotation_value: float) -> void:
	if _hover_tween != null:
		_hover_tween.kill()
	_hover_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(_tilt_root, "position", offset, 0.14)
	_hover_tween.parallel().tween_property(_tilt_root, "scale", scale_value, 0.14)
	_hover_tween.parallel().tween_property(_tilt_root, "rotation_degrees", rotation_value, 0.14)

func _play_press_feedback() -> void:
	var press_target_scale = _base_tilt_scale if not _hovered else _base_tilt_scale * 1.04
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_tilt_root, "scale", press_target_scale * 0.97, 0.05)
	tween.tween_property(_tilt_root, "scale", press_target_scale, 0.08)

func _update_pivot() -> void:
	pivot_offset = size * 0.5
	_tilt_root.pivot_offset = _tilt_root.size * 0.5

func _apply_visual_theme() -> void:
	_shadow.texture = _load_texture(CARD_SHADOW_PATH)
	_shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_shadow.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED

	_frame_texture.texture = _load_texture(CARD_FRAME_PATH)
	_frame_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frame_texture.stretch_mode = TextureRect.STRETCH_SCALE
	_frame_texture.modulate = Color(0.92, 0.85, 0.74, 0.96)
	_frame_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait_texture.modulate = Color(0.88, 0.84, 0.78, 0.84)
	_portrait_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_select_button.add_theme_stylebox_override("normal", _make_button_style(Color(0.16, 0.12, 0.10, 0.90), Color(0.78, 0.66, 0.48, 0.34)))
	_select_button.add_theme_stylebox_override("hover", _make_button_style(Color(0.20, 0.15, 0.12, 0.96), Color(0.88, 0.76, 0.56, 0.52)))
	_select_button.add_theme_stylebox_override("pressed", _make_button_style(Color(0.12, 0.09, 0.08, 0.96), Color(0.88, 0.76, 0.56, 0.42)))
	_select_button.add_theme_stylebox_override("disabled", _make_button_style(Color(0.10, 0.09, 0.08, 0.66), Color(0.40, 0.38, 0.34, 0.26)))
	_select_button.add_theme_color_override("font_color", Color(0.96, 0.92, 0.88))

func _apply_family_theme() -> void:
	var family := str(card_def.get("family", ""))
	var base_color := Color(0.18, 0.16, 0.14, 0.98)
	var glow_color := Color(0.96, 0.84, 0.56, 0.08)
	match family:
		"aggression":
			base_color = Color(0.22, 0.13, 0.12, 0.98)
			glow_color = Color(0.92, 0.45, 0.34, 0.10)
		"defense":
			base_color = Color(0.13, 0.16, 0.18, 0.98)
			glow_color = Color(0.54, 0.72, 0.84, 0.10)
		"control":
			base_color = Color(0.18, 0.16, 0.19, 0.98)
			glow_color = Color(0.72, 0.66, 0.84, 0.10)
		_:
			base_color = Color(0.16, 0.17, 0.13, 0.98)
			glow_color = Color(0.80, 0.88, 0.62, 0.10)

	_backdrop.color = base_color
	_portrait_glow.color = glow_color
	_portrait_texture.texture = _pick_portrait_texture(family)
	_title_label.add_theme_color_override("font_color", Color(0.97, 0.95, 0.92))
	_meta_label.add_theme_color_override("font_color", Color(0.86, 0.80, 0.70, 0.94))
	_body_label.add_theme_color_override("font_color", Color(0.89, 0.87, 0.84, 0.94))

func _make_button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 10
	style.content_margin_top = 6
	style.content_margin_right = 10
	style.content_margin_bottom = 6
	return style

func _pick_portrait_texture(family: String) -> Texture2D:
	var path := str(PORTRAIT_PATHS.get(family, PORTRAIT_PATHS["growth"]))
	if not ResourceLoader.exists(path):
		path = PORTRAIT_PATHS["aggression"]
	return _load_texture(path)

func _compact_body(text: String) -> String:
	var clean := text.strip_edges()
	if clean.length() <= 64:
		return clean
	return "%s..." % clean.substr(0, 64)

func _load_texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

func _assert_ui_refs() -> void:
	assert(_shadow != null, "CardView is missing node at path Shadow.")
	assert(_tilt_root != null, "CardView is missing node at path TiltRoot.")
	assert(_backdrop != null, "CardView is missing node at path TiltRoot/CardSurface/Backdrop.")
	assert(_portrait_texture != null, "CardView is missing node at path TiltRoot/CardSurface/PortraitTexture.")
	assert(_frame_texture != null, "CardView is missing node at path TiltRoot/CardSurface/FrameTexture.")
	assert(_title_label != null, "CardView is missing node at path TiltRoot/CardSurface/MarginContainer/VBoxContainer/TitleLabel.")
	assert(_meta_label != null, "CardView is missing node at path TiltRoot/CardSurface/MarginContainer/VBoxContainer/MetaLabel.")
	assert(_body_label != null, "CardView is missing node at path TiltRoot/CardSurface/MarginContainer/VBoxContainer/BodyLabel.")
	assert(_select_button != null, "CardView is missing node at path TiltRoot/CardSurface/MarginContainer/VBoxContainer/SelectButton.")

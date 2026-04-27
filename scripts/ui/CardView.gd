extends Button
class_name MvpCardView

const UI_TEXTURE_HELPER := preload("res://scripts/ui/UiTextureHelper.gd")
const CARD_VISUAL_MAPPER := preload("res://scripts/ui/CardVisualMapper.gd")

@onready var _frame_texture: TextureRect = get_node_or_null("FrameTexture") as TextureRect
@onready var _card_art: TextureRect = $CardArt
@onready var _card_name: Label = $CardName
@onready var _state_overlay: ColorRect = $StateOverlay
@onready var _overlay_texture: TextureRect = get_node_or_null("OverlayTexture") as TextureRect

var _card_data: Dictionary = {}
var _view_state: String = "normal"
var _clickable: bool = false
var _hovering: bool = false

func _ready() -> void:
	text = ""
	focus_mode = Control.FOCUS_NONE
	flat = true
	_ensure_visual_layers()
	_frame_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame_texture.z_index = 1
	_card_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_art.z_index = 0
	_card_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_name.z_index = 4
	_card_name.add_theme_color_override("font_color", Color(0.97, 0.94, 0.86, 1.0))
	_card_name.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.86))
	_card_name.add_theme_constant_override("shadow_offset_x", 1)
	_card_name.add_theme_constant_override("shadow_offset_y", 1)
	_state_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_state_overlay.z_index = 2
	_overlay_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_texture.z_index = 3
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_refresh_visuals()

func configure(card_data: Dictionary, view_state: String = "normal", clickable: bool = false) -> void:
	_card_data = card_data.duplicate(true)
	_view_state = view_state
	_clickable = clickable
	if is_node_ready():
		_refresh_visuals()

func set_view_state(next_state: String) -> void:
	_view_state = next_state
	if is_node_ready():
		_refresh_visuals()

func get_view_state() -> String:
	return _view_state

func get_card_data() -> Dictionary:
	return _card_data.duplicate(true)

func set_clickable(is_clickable: bool) -> void:
	_clickable = is_clickable
	if is_node_ready():
		_refresh_visuals()

func set_card_size(card_size: Vector2) -> void:
	if card_size != Vector2.ZERO:
		custom_minimum_size = card_size

func _ensure_visual_layers() -> void:
	if _frame_texture == null:
		_frame_texture = TextureRect.new()
		_frame_texture.name = "FrameTexture"
		add_child(_frame_texture)
		move_child(_frame_texture, 0)
	if _overlay_texture == null:
		_overlay_texture = TextureRect.new()
		_overlay_texture.name = "OverlayTexture"
		add_child(_overlay_texture)
	for texture_rect in [_frame_texture, _overlay_texture]:
		texture_rect.layout_mode = 1
		texture_rect.anchor_left = 0.0
		texture_rect.anchor_top = 0.0
		texture_rect.anchor_right = 1.0
		texture_rect.anchor_bottom = 1.0
		texture_rect.offset_left = 0.0
		texture_rect.offset_top = 0.0
		texture_rect.offset_right = 0.0
		texture_rect.offset_bottom = 0.0
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.stretch_mode = TextureRect.STRETCH_SCALE

func _refresh_visuals() -> void:
	var card_name := str(_card_data.get("display_name", "Unknown"))
	var card_type := str(_card_data.get("type", MvpBattleCard.TYPE_AGGRESSION))
	var base_fill := _color_for_type(card_type)
	var border_color := base_fill.lightened(0.18)
	var label_text := card_name
	var frame_texture := UI_TEXTURE_HELPER.load_texture(CARD_VISUAL_MAPPER.frame_path_for_card(_card_data))
	var portrait_texture := UI_TEXTURE_HELPER.load_texture(CARD_VISUAL_MAPPER.portrait_path_for_card(_card_data))
	var overlay_path := CARD_VISUAL_MAPPER.overlay_path_for_state(_view_state)

	_frame_texture.texture = frame_texture
	_frame_texture.visible = frame_texture != null
	_overlay_texture.texture = null
	_overlay_texture.visible = false
	match _view_state:
		"hidden":
			base_fill = Color(0.10, 0.12, 0.16, 0.98)
			border_color = Color(0.46, 0.50, 0.58, 0.85)
			label_text = "Hidden"
			_card_art.texture = UI_TEXTURE_HELPER.load_texture(CARD_VISUAL_MAPPER.hidden_texture_path())
			_card_art.modulate = Color(0.74, 0.78, 0.84, 0.90)
			_state_overlay.visible = true
			_state_overlay.color = Color(0.02, 0.03, 0.05, 0.28)
		"used":
			base_fill = Color(0.18, 0.18, 0.18, 0.94)
			border_color = Color(0.48, 0.48, 0.48, 0.84)
			label_text = "%s\nUSED" % card_name
			_card_art.texture = portrait_texture
			_card_art.modulate = Color(0.62, 0.62, 0.62, 0.74)
			_state_overlay.visible = true
			_state_overlay.color = Color(0.04, 0.04, 0.04, 0.36)
			_apply_overlay_texture(overlay_path)
		"locked":
			base_fill = Color(0.13, 0.13, 0.14, 0.96)
			border_color = Color(0.38, 0.36, 0.32, 0.82)
			_card_art.texture = portrait_texture
			_card_art.modulate = Color(0.46, 0.46, 0.46, 0.72)
			_state_overlay.visible = true
			_state_overlay.color = Color(0.03, 0.03, 0.03, 0.42)
			_apply_overlay_texture(overlay_path)
		"selected":
			_card_art.texture = portrait_texture
			_card_art.modulate = Color(1.0, 0.96, 0.82, 0.96)
			_state_overlay.visible = false
			_apply_overlay_texture(overlay_path)
		_:
			_card_art.texture = portrait_texture
			_card_art.modulate = Color(1.0, 1.0, 1.0, 0.92)
			_state_overlay.visible = false
			if _hovering:
				_apply_overlay_texture(CARD_VISUAL_MAPPER.overlay_path_for_state("hover"))

	_card_name.text = label_text
	_apply_button_styles(base_fill, border_color)
	disabled = _view_state != "normal" or not _clickable

func _apply_overlay_texture(path: String) -> void:
	var texture := UI_TEXTURE_HELPER.load_texture(path)
	if texture == null:
		return
	_overlay_texture.texture = texture
	_overlay_texture.visible = true

func _apply_button_styles(fill: Color, border: Color) -> void:
	var normal_style := _make_style(fill, border)
	var hover_style := _make_style(fill.lightened(0.06), border.lightened(0.12))
	var pressed_style := _make_style(fill.darkened(0.08), border)
	var disabled_style := _make_style(fill, border)
	add_theme_stylebox_override("normal", normal_style)
	add_theme_stylebox_override("hover", hover_style)
	add_theme_stylebox_override("pressed", pressed_style)
	add_theme_stylebox_override("disabled", disabled_style)
	add_theme_color_override("font_color", Color(0.96, 0.96, 0.96, 1.0))
	add_theme_color_override("font_hover_color", Color(0.98, 0.98, 0.98, 1.0))
	add_theme_color_override("font_pressed_color", Color(0.94, 0.94, 0.94, 1.0))
	add_theme_color_override("font_disabled_color", Color(0.88, 0.88, 0.88, 0.92))

func _make_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 8
	style.content_margin_top = 8
	style.content_margin_right = 8
	style.content_margin_bottom = 8
	return style

func _color_for_type(card_type: String) -> Color:
	match card_type:
		"aggression":
			return Color(0.45, 0.18, 0.16, 0.98)
		"defense":
			return Color(0.16, 0.28, 0.42, 0.98)
		"pressure":
			return Color(0.46, 0.32, 0.14, 0.98)
		_:
			return Color(0.24, 0.24, 0.24, 0.98)

func _on_mouse_entered() -> void:
	_hovering = true
	if is_node_ready():
		_refresh_visuals()

func _on_mouse_exited() -> void:
	_hovering = false
	if is_node_ready():
		_refresh_visuals()

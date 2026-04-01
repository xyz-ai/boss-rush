extends Button
class_name MvpCardView

const HIDDEN_TEXTURE_PATH := "res://assets/battle/cards/backs/card_back_default.png"
const AGGRESSION_TEXTURE_PATH := "res://assets/battle/cards/portraits/card_portrait_silhouette_02.png"
const DEFENSE_TEXTURE_PATH := "res://assets/battle/cards/portraits/card_portrait_silhouette_01.png"
const PRESSURE_TEXTURE_PATH := "res://assets/battle/cards/portraits/card_portrait_silhouette_01.png"

@onready var _card_art: TextureRect = $CardArt
@onready var _card_name: Label = $CardName
@onready var _state_overlay: ColorRect = $StateOverlay

var _card_data: Dictionary = {}
var _view_state: String = "normal"
var _clickable: bool = false

func _ready() -> void:
	text = ""
	focus_mode = Control.FOCUS_NONE
	flat = true
	_card_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_name.z_index = 2
	_state_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_state_overlay.z_index = 1
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

func _refresh_visuals() -> void:
	var card_name := str(_card_data.get("display_name", "Unknown"))
	var card_type := str(_card_data.get("type", MvpBattleCard.TYPE_AGGRESSION))
	var base_fill := _color_for_type(card_type)
	var border_color := base_fill.lightened(0.18)
	var label_text := card_name

	match _view_state:
		"hidden":
			base_fill = Color(0.10, 0.12, 0.16, 0.98)
			border_color = Color(0.46, 0.50, 0.58, 0.85)
			label_text = "Hidden"
			_card_art.texture = _load_texture(HIDDEN_TEXTURE_PATH)
			_card_art.modulate = Color(0.74, 0.78, 0.84, 0.90)
			_state_overlay.visible = true
			_state_overlay.color = Color(0.02, 0.03, 0.05, 0.28)
		"used":
			base_fill = Color(0.18, 0.18, 0.18, 0.94)
			border_color = Color(0.48, 0.48, 0.48, 0.84)
			label_text = "%s\nUSED" % card_name
			_card_art.texture = _texture_for_type(card_type)
			_card_art.modulate = Color(0.62, 0.62, 0.62, 0.74)
			_state_overlay.visible = true
			_state_overlay.color = Color(0.04, 0.04, 0.04, 0.36)
		_:
			_card_art.texture = _texture_for_type(card_type)
			_card_art.modulate = Color(1.0, 1.0, 1.0, 0.92)
			_state_overlay.visible = false

	_card_name.text = label_text
	_apply_button_styles(base_fill, border_color)
	disabled = _view_state != "normal" or not _clickable

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

func _texture_for_type(card_type: String) -> Texture2D:
	match card_type:
		"aggression":
			return _load_texture(AGGRESSION_TEXTURE_PATH)
		"defense":
			return _load_texture(DEFENSE_TEXTURE_PATH)
		"pressure":
			return _load_texture(PRESSURE_TEXTURE_PATH)
		_:
			return _load_texture(HIDDEN_TEXTURE_PATH)

func _load_texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

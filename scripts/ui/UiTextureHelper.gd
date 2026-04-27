extends RefCounted
class_name UiTextureHelper

const DEFAULT_STYLE_MARGIN := 14.0

static func load_texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

static func apply_texture_rect(rect: TextureRect, path: String, stretch_mode: int = TextureRect.STRETCH_KEEP_ASPECT_COVERED) -> bool:
	if rect == null:
		return false
	var texture := load_texture(path)
	if texture == null:
		return false
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = stretch_mode
	return true

static func make_texture_style(path: String, margin: float = DEFAULT_STYLE_MARGIN) -> StyleBox:
	var texture := load_texture(path)
	if texture == null:
		return null
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = margin
	style.texture_margin_top = margin
	style.texture_margin_right = margin
	style.texture_margin_bottom = margin
	style.content_margin_left = margin
	style.content_margin_top = margin * 0.55
	style.content_margin_right = margin
	style.content_margin_bottom = margin * 0.55
	return style

static func apply_panel_texture(panel: Control, path: String, margin: float = DEFAULT_STYLE_MARGIN) -> bool:
	if panel == null:
		return false
	var style := make_texture_style(path, margin)
	if style == null:
		return false
	panel.add_theme_stylebox_override("panel", style)
	return true

static func apply_button_textures(button: Button, normal_path: String, hover_path: String, pressed_path: String, disabled_path: String, margin: float = DEFAULT_STYLE_MARGIN) -> bool:
	if button == null:
		return false
	var normal_style := make_texture_style(normal_path, margin)
	var hover_style := make_texture_style(hover_path, margin)
	var pressed_style := make_texture_style(pressed_path, margin)
	var disabled_style := make_texture_style(disabled_path, margin)
	if normal_style == null:
		return false
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("focus", normal_style)
	button.add_theme_stylebox_override("hover", hover_style if hover_style != null else normal_style)
	button.add_theme_stylebox_override("pressed", pressed_style if pressed_style != null else normal_style)
	button.add_theme_stylebox_override("disabled", disabled_style if disabled_style != null else normal_style)
	button.add_theme_color_override("font_color", Color(0.96, 0.93, 0.86, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.88, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.95, 0.86, 0.72, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.72, 0.70, 0.68, 0.78))
	return true

static func ensure_backdrop(parent: Control, node_name: String, path: String, stretch_mode: int = TextureRect.STRETCH_SCALE) -> TextureRect:
	if parent == null:
		return null
	var backdrop := parent.get_node_or_null(node_name) as TextureRect
	if backdrop == null:
		backdrop = TextureRect.new()
		backdrop.name = node_name
		parent.add_child(backdrop)
		parent.move_child(backdrop, 0)
	backdrop.layout_mode = 1
	backdrop.anchor_left = 0.0
	backdrop.anchor_top = 0.0
	backdrop.anchor_right = 1.0
	backdrop.anchor_bottom = 1.0
	backdrop.offset_left = 0.0
	backdrop.offset_top = 0.0
	backdrop.offset_right = 0.0
	backdrop.offset_bottom = 0.0
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = stretch_mode
	apply_texture_rect(backdrop, path, stretch_mode)
	return backdrop

static func ensure_label_backdrop(label: Label, node_name: String, path: String) -> TextureRect:
	if label == null:
		return null
	var backdrop := label.get_node_or_null(node_name) as TextureRect
	if backdrop == null:
		backdrop = TextureRect.new()
		backdrop.name = node_name
		label.add_child(backdrop)
	backdrop.show_behind_parent = true
	backdrop.layout_mode = 1
	backdrop.anchor_left = 0.0
	backdrop.anchor_top = 0.0
	backdrop.anchor_right = 1.0
	backdrop.anchor_bottom = 1.0
	backdrop.offset_left = 0.0
	backdrop.offset_top = 0.0
	backdrop.offset_right = 0.0
	backdrop.offset_bottom = 0.0
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	apply_texture_rect(backdrop, path, TextureRect.STRETCH_SCALE)
	return backdrop

extends Control
class_name BossDeckView

const CARD_FRAME_PATH := "res://assets/battle/cards/frames/card_frame_main.png"
const CARD_BACK_PATH := "res://assets/battle/cards/backs/card_back_default.png"
const CARD_USED_OVERLAY_PATH := "res://assets/battle/cards/overlays/card_overlay_used.png"
const CARD_SHADOW_PATH := "res://assets/battle/effects/shadow_card_soft.png"
const PORTRAIT_PATHS := [
	"res://assets/battle/cards/portraits/card_portrait_silhouette_01.png",
	"res://assets/battle/cards/portraits/card_portrait_silhouette_02.png",
	"res://assets/battle/cards/portraits/card_portrait_silhouette_03.png",
]

var _effect_profile: Dictionary = {}

@onready var _deck_title: Label = $MarginContainer/VBoxContainer/DeckTitle
@onready var _deck_row: HBoxContainer = $MarginContainer/VBoxContainer/DeckScroll/DeckRow

func _ready() -> void:
	_deck_title.add_theme_color_override("font_color", Color(0.86, 0.82, 0.76, 0.96))

func refresh_from_state(set_state) -> void:
	for child in _deck_row.get_children():
		child.queue_free()

	if set_state == null:
		_deck_title.text = "对手牌列"
		return

	_deck_title.text = "对手牌列 %d / 已出 %d" % [
		set_state.boss_deck.size(),
		set_state.boss_used_cards.size(),
	]

	var used_counts: Dictionary = _build_used_counts(set_state.boss_used_cards)
	for card_id in set_state.boss_deck:
		var card_state := "hidden"
		if set_state.boss_revealed:
			card_state = "ready"
			if int(used_counts.get(card_id, 0)) > 0:
				card_state = "used"
				used_counts[card_id] = int(used_counts.get(card_id, 0)) - 1
		_deck_row.add_child(_build_card_widget(str(card_id), card_state))

func apply_effect_profile(profile: Dictionary) -> void:
	_effect_profile = profile.duplicate(true)
	var fatigue = float(profile.get("fatigue", 0.0))
	var coldness = float(profile.get("coldness", 0.0))
	self_modulate = Color(1.0 - coldness * 0.08, 1.0 - fatigue * 0.06, 1.0 - coldness * 0.02, 1.0)

func _build_used_counts(used_cards: Array) -> Dictionary:
	var counts: Dictionary = {}
	for card_id in used_cards:
		var key = str(card_id)
		counts[key] = int(counts.get(key, 0)) + 1
	return counts

func _build_card_widget(card_id: String, card_state: String) -> Control:
	var card_def = _data_loader().get_boss_card(card_id)
	var root := Control.new()
	root.custom_minimum_size = Vector2(96, 132)
	root.mouse_filter = Control.MOUSE_FILTER_STOP

	var shadow := TextureRect.new()
	_fill_rect(shadow)
	shadow.texture = _load_texture(CARD_SHADOW_PATH)
	shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shadow.modulate = Color(0, 0, 0, 0.56)
	root.add_child(shadow)

	var body := Control.new()
	_fill_rect(body)
	root.add_child(body)

	var backdrop := ColorRect.new()
	_fill_rect_inset(backdrop, 0.04, 0.04, 0.96, 0.96)
	body.add_child(backdrop)

	var portrait := TextureRect.new()
	portrait.anchor_left = 0.10
	portrait.anchor_top = 0.09
	portrait.anchor_right = 0.90
	portrait.anchor_bottom = 0.70
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body.add_child(portrait)

	var back := TextureRect.new()
	_fill_rect_inset(back, 0.04, 0.04, 0.96, 0.96)
	back.texture = _load_texture(CARD_BACK_PATH)
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back.stretch_mode = TextureRect.STRETCH_SCALE
	back.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body.add_child(back)

	var frame := TextureRect.new()
	_fill_rect(frame)
	frame.texture = _load_texture(CARD_FRAME_PATH)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body.add_child(frame)

	var title_bg := ColorRect.new()
	title_bg.anchor_left = 0.10
	title_bg.anchor_top = 0.76
	title_bg.anchor_right = 0.90
	title_bg.anchor_bottom = 0.93
	title_bg.color = Color(0.04, 0.04, 0.04, 0.74)
	body.add_child(title_bg)

	var title := Label.new()
	title.anchor_left = 0.12
	title.anchor_top = 0.78
	title.anchor_right = 0.88
	title.anchor_bottom = 0.92
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_color_override("font_color", Color(0.94, 0.92, 0.88))
	body.add_child(title)

	var badge := Label.new()
	badge.anchor_left = 0.10
	badge.anchor_top = 0.04
	badge.anchor_right = 0.90
	badge.anchor_bottom = 0.18
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.add_theme_color_override("font_color", Color(0.94, 0.72, 0.42))
	body.add_child(badge)

	var used_overlay := TextureRect.new()
	_fill_rect(used_overlay)
	used_overlay.texture = _load_texture(CARD_USED_OVERLAY_PATH)
	used_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	used_overlay.stretch_mode = TextureRect.STRETCH_SCALE
	used_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	used_overlay.visible = false
	body.add_child(used_overlay)

	var tooltip_title := "Boss 未揭示牌"
	var tooltip_body := "当前还没有查看这一局的 Boss 卡池。"
	match card_state:
		"hidden":
			backdrop.color = Color(0.08, 0.08, 0.09, 0.88)
			back.visible = true
			portrait.visible = false
			title.text = "?"
			title.modulate = Color(0.78, 0.78, 0.80, 0.82)
			root.modulate.a = 0.82
		"used":
			backdrop.color = Color(0.14, 0.14, 0.15, 0.86)
			back.visible = false
			portrait.visible = true
			portrait.texture = _pick_portrait_texture(card_id)
			portrait.modulate = Color(0.62, 0.62, 0.64, 0.72)
			title.text = str(card_def.get("name", card_id))
			title.modulate = Color(0.72, 0.72, 0.74, 0.90)
			badge.text = "已出"
			used_overlay.visible = true
			root.modulate = Color(0.74, 0.74, 0.76, 0.56)
			tooltip_title = str(card_def.get("name", card_id))
			tooltip_body = "%s\n\n状态：本局已经出过。" % str(card_def.get("text", ""))
		_:
			backdrop.color = Color(0.16, 0.14, 0.12, 0.92)
			back.visible = false
			portrait.visible = true
			portrait.texture = _pick_portrait_texture(card_id)
			portrait.modulate = Color(0.92, 0.88, 0.80, 0.82)
			title.text = str(card_def.get("name", card_id))
			title.modulate = Color(0.95, 0.93, 0.89, 1.0)
			root.modulate = Color(1, 1, 1, 1)
			tooltip_title = str(card_def.get("name", card_id))
			tooltip_body = str(card_def.get("text", ""))

	root.mouse_entered.connect(func():
		SignalBus.emit_signal("tooltip_requested", tooltip_title, tooltip_body, root.global_position)
	)
	root.mouse_exited.connect(func():
		SignalBus.emit_signal("tooltip_hidden")
	)
	return root

func _pick_portrait_texture(card_id: String) -> Texture2D:
	var index: int = abs(card_id.hash()) % PORTRAIT_PATHS.size()
	var path: String = PORTRAIT_PATHS[index]
	if not ResourceLoader.exists(path):
		path = PORTRAIT_PATHS[1]
	return _load_texture(path)

func _fill_rect(control: Control) -> void:
	control.layout_mode = 1
	control.anchors_preset = Control.PRESET_FULL_RECT
	control.anchor_right = 1.0
	control.anchor_bottom = 1.0
	control.grow_horizontal = Control.GROW_DIRECTION_BOTH
	control.grow_vertical = Control.GROW_DIRECTION_BOTH
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _fill_rect_inset(control: Control, left: float, top: float, right: float, bottom: float) -> void:
	control.layout_mode = 1
	control.anchor_left = left
	control.anchor_top = top
	control.anchor_right = right
	control.anchor_bottom = bottom
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _load_texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

func _data_loader():
	return get_node_or_null("/root/DataLoader")

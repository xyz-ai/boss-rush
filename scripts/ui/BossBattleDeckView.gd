extends RefCounted
class_name MvpBossBattleDeckView

signal reveal_requested

var _root: Control
var _reveal_button: Button
var _deck_row: HBoxContainer
var _card_scene: PackedScene
var _cards: Array[MvpBattleCard] = []
var _revealed: bool = false
var _used_slots: Array[int] = []
var _reveal_enabled: bool = true
var _card_views: Array[MvpCardView] = []

func _init(root: Control, reveal_button: Button, deck_row: HBoxContainer, card_scene: PackedScene) -> void:
	_root = root
	_reveal_button = reveal_button
	_deck_row = deck_row
	_card_scene = card_scene
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_deck_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_deck_row.add_theme_constant_override("separation", 10)
	_deck_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reveal_button.text = _text("labels.reveal_battle_deck", "Reveal Battle Deck")
	_reveal_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	_deck_row.anchor_left = 0.0
	_deck_row.anchor_top = 0.0
	_deck_row.anchor_right = 0.0
	_deck_row.anchor_bottom = 0.0
	if not _reveal_button.pressed.is_connected(_on_reveal_pressed):
		_reveal_button.pressed.connect(_on_reveal_pressed)
	update_layout()

func set_deck(cards: Array[MvpBattleCard], revealed: bool, used_slots: Array[int]) -> void:
	_cards = cards
	_revealed = revealed
	_used_slots = used_slots.duplicate()
	_sync_card_views()
	_refresh_button_state()
	update_layout()

func set_reveal_enabled(enabled: bool) -> void:
	_reveal_enabled = enabled
	_refresh_button_state()
	update_layout()

func update_layout() -> void:
	if _root == null or _reveal_button == null or _deck_row == null:
		return
	var root_size := _root.size
	if root_size.x <= 0.0 or root_size.y <= 0.0:
		return

	var row_y: float = floorf(root_size.y * 0.48)
	_deck_row.position = Vector2(0.0, row_y)
	_deck_row.size = Vector2(root_size.x, maxf(root_size.y - row_y, 0.0))

func _on_reveal_pressed() -> void:
	if _reveal_button.disabled:
		return
	reveal_requested.emit()

func _refresh_button_state() -> void:
	if _revealed:
		_reveal_button.text = _text("labels.battle_deck_revealed", "Battle Deck Revealed")
	elif not _reveal_enabled:
		_reveal_button.text = _text("labels.reveal_locked", "Reveal Locked")
	else:
		_reveal_button.text = _text("labels.reveal_battle_deck", "Reveal Battle Deck")
	_reveal_button.disabled = _revealed or not _reveal_enabled

func _sync_card_views() -> void:
	while _card_views.size() > _cards.size():
		var trailing_view: MvpCardView = _card_views.pop_back()
		if is_instance_valid(trailing_view):
			_deck_row.remove_child(trailing_view)
			trailing_view.queue_free()

	while _card_views.size() < _cards.size():
		var next_slot_index: int = _card_views.size()
		var card_view: MvpCardView = _card_scene.instantiate()
		card_view.name = "BossBattleDeckCard%d" % next_slot_index
		card_view.set_card_size(Vector2(86, 118))
		_deck_row.add_child(card_view)
		_card_views.append(card_view)

	for slot_index in range(_cards.size()):
		var current_view: MvpCardView = _card_views[slot_index]
		current_view.name = "BossBattleDeckCard%d" % slot_index
		current_view.configure(_cards[slot_index].to_dict(), _state_for_slot(slot_index), false)

func _state_for_slot(slot_index: int) -> String:
	if _used_slots.has(slot_index):
		return "used"
	if _revealed:
		return "normal"
	return "hidden"

func _text(key: String, fallback_text: String) -> String:
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree:
		var loader := (main_loop as SceneTree).root.get_node_or_null("DataLoader")
		if loader != null and loader.has_method("get_mvp_text"):
			return str(loader.get_mvp_text(key, fallback_text))
	return fallback_text

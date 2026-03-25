extends RefCounted
class_name MvpBossDeckView

signal reveal_requested

var _root: Control
var _reveal_button: Button
var _deck_row: HBoxContainer
var _card_scene: PackedScene
var _cards: Array[MvpBattleCard] = []
var _revealed: bool = false
var _used_slots: Array[int] = []
var _reveal_enabled: bool = true

func _init(root: Control, reveal_button: Button, deck_row: HBoxContainer, card_scene: PackedScene) -> void:
	_root = root
	_reveal_button = reveal_button
	_deck_row = deck_row
	_card_scene = card_scene
	_deck_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_deck_row.add_theme_constant_override("separation", 10)
	_reveal_button.text = "Reveal Deck"
	_reveal_button.pressed.connect(_on_reveal_pressed)

func set_deck(cards: Array[MvpBattleCard], revealed: bool, used_slots: Array[int]) -> void:
	_cards = cards
	_revealed = revealed
	_used_slots = used_slots.duplicate()
	_rebuild_cards()
	_refresh_button_state()

func set_reveal_enabled(enabled: bool) -> void:
	_reveal_enabled = enabled
	_refresh_button_state()

func _on_reveal_pressed() -> void:
	if _reveal_button.disabled:
		return
	reveal_requested.emit()

func _refresh_button_state() -> void:
	if _revealed:
		_reveal_button.text = "Deck Revealed"
	elif not _reveal_enabled:
		_reveal_button.text = "Reveal Locked"
	else:
		_reveal_button.text = "Reveal Deck"
	_reveal_button.disabled = _revealed or not _reveal_enabled

func _rebuild_cards() -> void:
	for child in _deck_row.get_children():
		_deck_row.remove_child(child)
		child.queue_free()

	for slot_index in range(_cards.size()):
		var card_view: MvpCardView = _card_scene.instantiate()
		card_view.name = "BossDeckCard%d" % slot_index
		card_view.set_card_size(Vector2(84, 116))
		card_view.configure(_cards[slot_index].to_dict(), _state_for_slot(slot_index), false)
		_deck_row.add_child(card_view)

func _state_for_slot(slot_index: int) -> String:
	if _used_slots.has(slot_index):
		return "used"
	if _revealed:
		return "normal"
	return "hidden"

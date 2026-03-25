extends RefCounted
class_name MvpPlayerHandView

signal card_play_requested(slot_index: int)

var _hand_anchor: HBoxContainer
var _card_scene: PackedScene
var _card_views: Dictionary = {}

func _init(hand_anchor: HBoxContainer, card_scene: PackedScene) -> void:
	_hand_anchor = hand_anchor
	_card_scene = card_scene
	_hand_anchor.alignment = BoxContainer.ALIGNMENT_CENTER
	_hand_anchor.add_theme_constant_override("separation", 12)

func set_hand(cards: Array[MvpBattleCard], used_slots: Array[int], interactive: bool = true) -> void:
	_clear_cards()
	for slot_index in range(cards.size()):
		if used_slots.has(slot_index):
			continue
		var card_view: MvpCardView = _card_scene.instantiate()
		card_view.name = "PlayerCard%d" % slot_index
		card_view.set_card_size(Vector2(132, 188))
		card_view.configure(cards[slot_index].to_dict(), "normal", interactive)
		card_view.pressed.connect(_on_card_pressed.bind(slot_index))
		_hand_anchor.add_child(card_view)
		_card_views[slot_index] = card_view

func set_interactive(interactive: bool) -> void:
	for card_view in _card_views.values():
		if is_instance_valid(card_view):
			card_view.set_clickable(interactive)

func clear() -> void:
	_clear_cards()

func _on_card_pressed(slot_index: int) -> void:
	card_play_requested.emit(slot_index)

func _clear_cards() -> void:
	for child in _hand_anchor.get_children():
		_hand_anchor.remove_child(child)
		child.queue_free()
	_card_views.clear()

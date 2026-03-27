extends RefCounted
class_name MvpBossDeckView

var _root: Control
var _hand_count_label: Label
var _animation_anchor: Control
var _deck_row: HBoxContainer
var _card_scene: PackedScene
var _cards: Array[MvpBattleCard] = []
var _used_slots: Array[int] = []

func _init(
	root: Control,
	hand_count_label: Label,
	animation_anchor: Control,
	deck_row: HBoxContainer,
	card_scene: PackedScene
) -> void:
	_root = root
	_hand_count_label = hand_count_label
	_animation_anchor = animation_anchor
	_deck_row = deck_row
	_card_scene = card_scene
	_deck_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_deck_row.add_theme_constant_override("separation", 8)
	if _animation_anchor != null:
		_animation_anchor.visible = false

func set_hand(cards: Array[MvpBattleCard], used_slots: Array[int]) -> void:
	_cards = cards
	_used_slots = used_slots.duplicate()
	_refresh_count_label()
	_rebuild_cards()

func _refresh_count_label() -> void:
	var remaining_cards: int = maxi(_cards.size() - _used_slots.size(), 0)
	_hand_count_label.text = "Boss Hand x%d" % remaining_cards

func _rebuild_cards() -> void:
	for child in _deck_row.get_children():
		_deck_row.remove_child(child)
		child.queue_free()

	var remaining_cards: int = maxi(_cards.size() - _used_slots.size(), 0)
	for index in range(remaining_cards):
		var card_view: MvpCardView = _card_scene.instantiate()
		card_view.name = "BossHandCard%d" % index
		card_view.set_card_size(Vector2(68, 96))
		var fallback_data: Dictionary = {} if _cards.is_empty() else _cards[min(index, _cards.size() - 1)].to_dict()
		card_view.configure(fallback_data, "hidden", false)
		_deck_row.add_child(card_view)

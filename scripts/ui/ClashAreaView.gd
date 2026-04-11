extends RefCounted
class_name MvpClashAreaView

var _root: Control
var _player_card_slot: Control
var _boss_card_slot: Control
var _card_scene: PackedScene
var _result_label: Label

func _init(
	root: Control,
	player_card_slot: Control,
	boss_card_slot: Control,
	result_label: Label,
	card_scene: PackedScene
) -> void:
	_root = root
	_player_card_slot = player_card_slot
	_boss_card_slot = boss_card_slot
	_result_label = result_label
	_card_scene = card_scene
	assert(_result_label != null, "ClashAreaView requires an existing ClashResultLabel node.")
	clear_clash()

func show_clash(player_card: Dictionary, boss_card: Dictionary, summary_text: String) -> void:
	_place_card(_player_card_slot, player_card, "PlayerClashCard")
	_place_card(_boss_card_slot, boss_card, "BossClashCard")
	_result_label.text = summary_text

func set_result_text(text: String) -> void:
	_result_label.text = text

func get_result_text() -> String:
	return _result_label.text

func clear_clash() -> void:
	_clear_slot(_player_card_slot)
	_clear_slot(_boss_card_slot)
	_result_label.text = "Choose a card to start the turn."

func _place_card(slot: Control, card_data: Dictionary, node_name: String) -> void:
	_clear_slot(slot)
	var card_view: MvpCardView = _card_scene.instantiate()
	card_view.name = node_name
	card_view.set_card_size(Vector2(124, 176))
	card_view.configure(card_data, "normal", false)
	slot.add_child(card_view)
	card_view.layout_mode = 1
	card_view.anchor_left = 0.5
	card_view.anchor_top = 0.5
	card_view.anchor_right = 0.5
	card_view.anchor_bottom = 0.5
	card_view.offset_left = -card_view.custom_minimum_size.x * 0.5
	card_view.offset_top = -card_view.custom_minimum_size.y * 0.5
	card_view.offset_right = card_view.custom_minimum_size.x * 0.5
	card_view.offset_bottom = card_view.custom_minimum_size.y * 0.5

func _clear_slot(slot: Control) -> void:
	for child in slot.get_children():
		slot.remove_child(child)
		child.queue_free()

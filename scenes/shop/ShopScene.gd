extends Control

const ITEM_SCENE := preload("res://scenes/shop/ShopItemView.tscn")
const COLLAPSE_EFFECTS_SCRIPT := preload("res://scripts/systems/CollapseEffects.gd")

var run_state
var offers: Array[Dictionary] = []
var _collapse_effects
var _item_views: Dictionary = {}

@onready var _title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var _status_label: Label = $MarginContainer/VBoxContainer/StatusLabel
@onready var _item_row: HBoxContainer = $MarginContainer/VBoxContainer/ItemRow
@onready var _notice_label: Label = $MarginContainer/VBoxContainer/NoticeLabel
@onready var _continue_button: Button = $MarginContainer/VBoxContainer/ContinueButton

func _ready() -> void:
	_collapse_effects = COLLAPSE_EFFECTS_SCRIPT.new(_data_loader().get_balance("ui_thresholds", {}))
	_continue_button.pressed.connect(_on_continue_pressed)
	if run_state != null:
		_setup_scene()

func bind_context(next_run_state, next_offers: Array) -> void:
	run_state = next_run_state
	offers = next_offers.duplicate(true)
	if is_node_ready():
		_setup_scene()

func apply_effect_profile(profile: Dictionary) -> void:
	var fatigue = float(profile.get("fatigue", 0.0))
	var coldness = float(profile.get("coldness", 0.0))
	self_modulate = Color(1.0 - coldness * 0.08, 1.0 - fatigue * 0.10, 1.0 - coldness * 0.04, 1.0)

func _setup_scene() -> void:
	_title_label.text = "商店 / 挑战结束后"
	_notice_label.text = "商店只会在完整击败当前 Boss 后开启。"
	_rebuild_items()
	_refresh_ui()

func _rebuild_items() -> void:
	for child in _item_row.get_children():
		child.queue_free()
	_item_views.clear()
	for offer in offers:
		var item = ITEM_SCENE.instantiate()
		item.offer_pressed.connect(_on_offer_pressed)
		_item_row.add_child(item)
		_item_views[offer.get("id", "")] = item

func _refresh_ui() -> void:
	var addon_inventory = run_state.get_remaining_addons()
	_status_label.text = "LIFE %d   BOD %d   SPR %d   REP %d   Intel %d / Leverage %d / StopLoss %d" % [
		run_state.life,
		run_state.bod,
		run_state.spr,
		run_state.rep,
		int(addon_inventory.get("intel", 0)),
		int(addon_inventory.get("leverage", 0)),
		int(addon_inventory.get("stop_loss", 0)),
	]
	for offer in offers:
		var item = _item_views.get(offer.get("id", ""))
		if item != null:
			item.setup(offer, run_state.life >= int(offer.get("cost_life", 0)))
	apply_effect_profile(_collapse_effects.evaluate(run_state))

func _on_offer_pressed(offer_id: String) -> void:
	for offer in offers:
		if offer.get("id", "") != offer_id:
			continue
		var result = GameRun.shop_generator.apply_offer(run_state, offer)
		_notice_label.text = result.get("message", "")
		if result.get("ok", false):
			GameRun.emit_log(result.get("message", ""))
			GameRun.broadcast_state()
			_refresh_ui()
		return

func _on_continue_pressed() -> void:
	GameRun.finish_shop()

func _data_loader():
	return get_node_or_null("/root/DataLoader")

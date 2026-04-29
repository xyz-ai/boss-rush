extends Control

const CARD_VIEW_SCENE := preload("res://scenes/battle/CardView.tscn")
const BATTLE_RESOLVER_SCRIPT := preload("res://scripts/core/BattleResolver.gd")
const BOSS_AI_SCRIPT := preload("res://scripts/core/BossAI.gd")
const PEEK_SYSTEM_SCRIPT := preload("res://scripts/systems/PeekSystem.gd")
const ADDON_SYSTEM_SCRIPT := preload("res://scripts/systems/AddonSystem.gd")
const COLLAPSE_EFFECTS_SCRIPT := preload("res://scripts/systems/CollapseEffects.gd")
const UI_ASSET_PATHS := preload("res://scripts/ui/UiAssetPaths.gd")

const BG_OFFICE_PATH := "res://assets/battle/background/bg_office_dark.png"
const DESK_TABLE_PATH := "res://assets/battle/table/table_main.png"
const VIGNETTE_PATH := "res://assets/ui/common/vignette_main.png"

var run_state
var boss_def: Dictionary = {}

var _resolver
var _boss_ai
var _peek_system = PEEK_SYSTEM_SCRIPT.new()
var _addon_system = ADDON_SYSTEM_SCRIPT.new()
var _collapse_effects
var _desk_base_color: Color = Color(0.86, 0.76, 0.66, 0.94)
var _pending_hand_layout_passes: int = 0
var _right_drawer_tween: Tween
var _left_drawer_tween: Tween
var _right_hotzone_hovered := false
var _right_drawer_hovered := false
var _left_handle_hovered := false
var _left_drawer_hovered := false
var _left_drawer_pinned := true
var _right_drawer_open_pos := Vector2.ZERO
var _right_drawer_closed_pos := Vector2.ZERO
var _left_drawer_open_pos := Vector2.ZERO
var _left_drawer_closed_pos := Vector2.ZERO

var _card_views: Dictionary = {}
var _popup_mode := ""
var _pending_result: Dictionary = {}

@onready var _bg_office: TextureRect = $BackgroundLayer/BgOffice
@onready var _desk_surface: TextureRect = $BackgroundLayer/DeskTable
@onready var _vignette_overlay: TextureRect = $BackgroundLayer/VignetteOverlay
@onready var _dust_overlay: CanvasItem = $BackgroundLayer/DustOrCrackOverlay
@onready var _safe_area: Control = $SafeArea
@onready var _stage_root: Control = $SafeArea/StageRoot
@onready var _boss_stage: Control = $SafeArea/StageRoot/BossStage
@onready var _portrait_caption: Label = $SafeArea/StageRoot/BossStage/BossCaption
@onready var _boss_portrait: TextureRect = $SafeArea/StageRoot/BossStage/PortraitFrame/BossPortrait
@onready var _boss_portrait_fallback: Label = $SafeArea/StageRoot/BossStage/PortraitFrame/BossPortraitFallback
@onready var _portrait_frame: PanelContainer = $SafeArea/StageRoot/BossStage/PortraitFrame
@onready var _boss_panel = $SafeArea/StageRoot/BossStage/BossPanel
@onready var _table_core: Control = $SafeArea/StageRoot/TableCore
@onready var _top_round_info: PanelContainer = $SafeArea/StageRoot/TableCore/TopRoundInfo
@onready var _round_label: Label = $SafeArea/StageRoot/TableCore/TopRoundInfo/MarginContainer/VBoxContainer/RoundLabel
@onready var _hp_versus_label: Label = $SafeArea/StageRoot/TableCore/TopRoundInfo/MarginContainer/VBoxContainer/HpVersusLabel
@onready var _hint_label: Label = $SafeArea/StageRoot/TableCore/TopRoundInfo/MarginContainer/VBoxContainer/HintLabel
@onready var _intel_zone: Control = $SafeArea/StageRoot/TableCore/IntelZone
@onready var _intel_label: Label = $SafeArea/StageRoot/TableCore/IntelZone/IntelLabel
@onready var _boss_deck_view = $SafeArea/StageRoot/TableCore/IntelZone/BossDeckView
@onready var _clash_area = $SafeArea/StageRoot/TableCore/ClashArea
@onready var _boss_hp_plaque: PanelContainer = $SafeArea/StageRoot/TableCore/BossHpPlaque
@onready var _boss_hp_plaque_label: Label = $SafeArea/StageRoot/TableCore/BossHpPlaque/Label
@onready var _player_hp_plaque: PanelContainer = $SafeArea/StageRoot/TableCore/PlayerHpPlaque
@onready var _player_hp_plaque_label: Label = $SafeArea/StageRoot/TableCore/PlayerHpPlaque/Label
@onready var _boss_chip_stacks: Control = $SafeArea/StageRoot/TableCore/BossChipStacks
@onready var _player_chip_stacks: Control = $SafeArea/StageRoot/TableCore/PlayerChipStacks
@onready var _left_status_stage: Control = $SafeArea/StageRoot/LeftStatusStage
@onready var _left_status_handle: Button = $SafeArea/StageRoot/LeftStatusStage/LeftStatusHandle
@onready var _left_status_drawer: Control = $SafeArea/StageRoot/LeftStatusStage/LeftStatusDrawer
@onready var _status_panel = $SafeArea/StageRoot/LeftStatusStage/LeftStatusDrawer/MarginContainer/VBoxContainer/StatusPanel
@onready var _addon_panel = $SafeArea/StageRoot/LeftStatusStage/LeftStatusDrawer/MarginContainer/VBoxContainer/AddonPanel
@onready var _right_hotzone: Control = $SafeArea/StageRoot/RightDrawerHotzone
@onready var _right_drawer: Control = $SafeArea/StageRoot/RightDrawer
@onready var _right_drawer_panel: PanelContainer = $SafeArea/StageRoot/RightDrawer/DrawerPanel
@onready var _drawer_peek_button: Button = $SafeArea/StageRoot/RightDrawer/DrawerPanel/MarginContainer/VBoxContainer/ActionPanel/MarginContainer/VBoxContainer/PeekButton
@onready var _notice_label: Label = $SafeArea/StageRoot/RightDrawer/DrawerPanel/MarginContainer/VBoxContainer/ActionPanel/MarginContainer/VBoxContainer/NoticeLabel
@onready var _log_panel: PanelContainer = $SafeArea/StageRoot/RightDrawer/DrawerPanel/MarginContainer/VBoxContainer/LogPanel
@onready var _log_label: RichTextLabel = $SafeArea/StageRoot/RightDrawer/DrawerPanel/MarginContainer/VBoxContainer/LogPanel/MarginContainer/VBoxContainer/LogScroll/LogText
@onready var _log_scroll: ScrollContainer = $SafeArea/StageRoot/RightDrawer/DrawerPanel/MarginContainer/VBoxContainer/LogPanel/MarginContainer/VBoxContainer/LogScroll
@onready var _player_hand_stage: Control = $SafeArea/StageRoot/PlayerHandStage
@onready var _hand_title: Label = $SafeArea/StageRoot/PlayerHandStage/HandTitle
@onready var _hand_info_label: Label = $SafeArea/StageRoot/PlayerHandStage/HandInfoLabel
@onready var _card_row: Control = $SafeArea/StageRoot/PlayerHandStage/HandArea/CardRow
@onready var _result_popup = $ResultPopup

func _ready() -> void:
	_apply_visual_theme()
	_connect_stage_signals()
	_collapse_effects = COLLAPSE_EFFECTS_SCRIPT.new(_data_loader().get_balance("ui_thresholds", {}))
	_boss_panel.peek_requested.connect(_on_peek_requested)
	_drawer_peek_button.pressed.connect(_on_peek_requested)
	_addon_panel.addon_selected.connect(_on_addon_selected)
	_result_popup.continue_pressed.connect(_on_result_continue)
	_card_row.resized.connect(_queue_hand_layout)
	call_deferred("_apply_stage_layout")
	if run_state != null:
		_setup_scene()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_apply_stage_layout()
		_queue_hand_layout()

func _process(_delta: float) -> void:
	if _pending_hand_layout_passes > 0:
		_layout_player_cards()
		_pending_hand_layout_passes -= 1

func bind_context(next_run_state, next_boss_def: Dictionary) -> void:
	run_state = next_run_state
	boss_def = next_boss_def.duplicate(true)
	if is_node_ready():
		_setup_scene()

func apply_effect_profile(profile: Dictionary) -> void:
	_status_panel.apply_effect_profile(profile)
	_boss_panel.apply_effect_profile(profile)
	_boss_deck_view.apply_effect_profile(profile)
	if _clash_area.has_method("apply_effect_profile"):
		_clash_area.apply_effect_profile(profile)
	_addon_panel.apply_effect_profile(profile)
	_dust_overlay.modulate.a = float(profile.get("crack_alpha", 0.0))

	var fatigue = float(profile.get("fatigue", 0.0))
	var coldness = float(profile.get("coldness", 0.0))
	_desk_surface.modulate = Color(
		_desk_base_color.r - coldness * 0.03,
		_desk_base_color.g - fatigue * 0.05,
		_desk_base_color.b - coldness * 0.05,
		_desk_base_color.a
	)
	_boss_portrait.modulate = Color(1.0 - coldness * 0.05, 1.0 - fatigue * 0.05, 1.0 - coldness * 0.02, 0.90)
	_top_round_info.modulate = Color(1.0 - coldness * 0.04, 1.0 - fatigue * 0.05, 1.0, 1.0)
	_boss_hp_plaque.modulate = Color(1.0 - coldness * 0.05, 1.0 - fatigue * 0.02, 1.0, 1.0)
	_player_hp_plaque.modulate = Color(1.0 - coldness * 0.02, 1.0 - fatigue * 0.03, 1.0, 1.0)
	_right_drawer_panel.modulate = Color(1.0 - coldness * 0.04, 1.0 - fatigue * 0.03, 1.0, _right_drawer.modulate.a)
	for card_view in _card_views.values():
		card_view.set_hover_instability(float(profile.get("hover_instability", 0.0)))

func _setup_scene() -> void:
	_resolver = BATTLE_RESOLVER_SCRIPT.new(_data_loader().get_balance("matchup_rules", {}))
	_boss_ai = BOSS_AI_SCRIPT.new(_data_loader().get_balance("matchup_rules", {}))
	_boss_panel.set_boss(boss_def)
	_sync_presentation()
	if run_state.current_set_state == null:
		run_state.start_set(run_state.challenge_rules)
	_ensure_boss_deck_initialized()
	if run_state.current_set_state != null and run_state.current_set_state.current_pool.is_empty():
		_start_round()
	else:
		_refresh_ui()

func _sync_presentation() -> void:
	var presentation: Dictionary = boss_def.get("presentation", {})
	var accent = Color.from_string(str(presentation.get("accent_color", "#d4c8b5")), Color(0.84, 0.78, 0.72))
	_desk_base_color = Color.from_string(str(presentation.get("desk_tint", "#7b6655")), Color(0.86, 0.76, 0.66, 0.94))
	if not UI_ASSET_PATHS.USE_SEPARATE_BOSS_PORTRAIT:
		# Current background already includes the Boss; keep the separate portrait disabled.
		_boss_portrait.visible = false
		_boss_portrait_fallback.visible = false
		_portrait_caption.text = "%s / %s" % [boss_def.get("title", "瀵瑰腑"), boss_def.get("name", "Counterparty")]
		if _boss_panel.has_method("set_accent"):
			_boss_panel.set_accent(accent)
		return
	var portrait_path := _get_boss_portrait_path(presentation)
	var portrait_texture := _load_texture(portrait_path)
	_boss_portrait.texture = portrait_texture
	_boss_portrait.visible = portrait_texture != null
	_boss_portrait_fallback.visible = portrait_texture == null
	_boss_portrait_fallback.text = "%s\n%s" % [boss_def.get("title", "BOSS"), boss_def.get("name", "")]
	_boss_portrait_fallback.modulate = accent
	_portrait_caption.text = "%s / %s" % [boss_def.get("title", "对席"), boss_def.get("name", "Counterparty")]
	if _boss_panel.has_method("set_accent"):
		_boss_panel.set_accent(accent)

func _build_player_cards() -> void:
	for child in _card_row.get_children():
		child.queue_free()
	_card_views.clear()
	if run_state == null or run_state.current_set_state == null:
		return
	for card_def in _data_loader().get_player_battle_cards(run_state.current_set_state.remaining_player_battle_cards):
		var card_view = CARD_VIEW_SCENE.instantiate()
		card_view.setup(card_def)
		card_view.card_selected.connect(_on_player_card_selected)
		_card_row.add_child(card_view)
		_card_views[card_def.get("id", "")] = card_view
	_queue_hand_layout()

func _queue_hand_layout() -> void:
	_pending_hand_layout_passes = 3
	call_deferred("_layout_player_cards")

func _layout_player_cards() -> void:
	if not is_instance_valid(_card_row) or _card_row.size.x < 10.0:
		return
	var cards := _card_row.get_children()
	var count := cards.size()
	if count == 0:
		return

	var available_width: float = max(_card_row.size.x - 30.0, 620.0)
	var base_width: float = 176.0
	var base_step: float = 138.0
	var scale_factor: float = 1.0
	if count > 1:
		scale_factor = min(1.0, available_width / (base_width + base_step * float(count - 1)))
	scale_factor = clamp(scale_factor, 0.76, 1.0)

	var card_size := Vector2(176.0, 260.0)
	var step: float = 0.0
	if count > 1:
		step = min(base_step * scale_factor, (available_width - card_size.x * scale_factor) / float(count - 1))
	var span: float = card_size.x * scale_factor + step * float(max(count - 1, 0))
	var start_x: float = max((_card_row.size.x - span) * 0.5, 0.0)
	var center: float = (float(count) - 1.0) * 0.5

	for index in range(count):
		var card: Control = cards[index]
		var spread: float = float(index) - center
		var rise: float = abs(spread) * 11.0
		_pin_rect(card, Vector2(start_x + step * float(index), 10.0 + rise), card_size)
		card.z_index = int(300 - abs(spread) * 12.0)
		if card.has_method("set_table_pose"):
			card.set_table_pose(spread * 3.0, scale_factor)

func _ensure_boss_deck_initialized() -> void:
	if run_state == null or run_state.current_set_state == null:
		return
	if run_state.current_set_state.boss_deck.is_empty():
		run_state.current_set_state.configure_boss_deck(boss_def.get("deck", []))

func _start_round() -> void:
	if run_state == null or run_state.current_set_state == null:
		return
	var set_state = run_state.current_set_state
	_ensure_boss_deck_initialized()
	if not set_state.has_rounds_remaining():
		return
	run_state.begin_round(_boss_ai.prepare_pool(boss_def, run_state))
	GameRun.emit_log("第 %d 局 第 %d 回合开始。" % [set_state.set_index, set_state.round_index + 1])
	GameRun.broadcast_state()
	_notice_label.text = "从手牌中打出 1 张战斗牌。"
	_refresh_ui()

func _refresh_ui() -> void:
	if run_state == null:
		return

	var set_state = run_state.current_set_state
	var challenge_state = run_state.challenge_state
	_status_panel.update_from_run_state(run_state)
	_boss_panel.update_from_battle(run_state, boss_def)
	_boss_deck_view.refresh_from_state(set_state)
	if run_state.last_round_result.is_empty():
		_clash_area.clear_display()
	else:
		_clash_area.show_result(run_state.last_round_result)
	_build_player_cards()

	if set_state != null:
		var peek_cost := int(_data_loader().get_balance("peek_cost_spr", 1))
		var peek_disabled := bool(set_state.boss_revealed or set_state.boss_deck.is_empty())
		_boss_panel.set_deck_status(set_state)
		_boss_panel.set_peek_state(peek_cost, set_state.free_peek_this_round, peek_disabled)
		_drawer_peek_button.disabled = peek_disabled
		_drawer_peek_button.text = _build_peek_button_text(peek_cost, set_state.free_peek_this_round, peek_disabled)
		_addon_panel.set_inventory(run_state.get_remaining_addons(), _data_loader().get_all_addons(), set_state.round_active_addon)
		_round_label.text = "第 %d 局 / 第 %d 回合" % [set_state.set_index, min(set_state.round_index + 1, set_state.max_rounds)]
		_hp_versus_label.text = "玩家 %d HP   vs   Boss %d HP" % [set_state.player_hp, set_state.boss_hp]
		_hint_label.text = _build_table_caption(challenge_state, set_state)
		_intel_label.text = "已窥破的 Boss 牌列" if set_state.boss_revealed else "未窥破的 Boss 牌列"
		_hand_title.text = "玩家手牌"
		_hand_info_label.text = "剩余战斗牌 %d / 已打出 %d" % [
			set_state.remaining_player_battle_cards.size(),
			set_state.played_player_battle_cards.size(),
		]
		_refresh_hp_plaques(set_state, challenge_state)
	else:
		_drawer_peek_button.disabled = true
		_round_label.text = "等待挑战开始"
		_hp_versus_label.text = "玩家 HP   vs   Boss HP"
		_hint_label.text = "桌面尚未摆开。"
		_intel_label.text = "未窥破的 Boss 牌列"
		_boss_hp_plaque_label.text = "Boss HP -"
		_player_hp_plaque_label.text = "玩家 HP -"
		_clash_area.clear_display()

	_refresh_chip_stacks()
	_log_label.text = GameRun.get_recent_logs_text(8)
	call_deferred("_scroll_log_to_bottom")
	apply_effect_profile(_collapse_effects.evaluate(run_state))

func _refresh_hp_plaques(set_state, challenge_state) -> void:
	if set_state == null or challenge_state == null:
		_boss_hp_plaque_label.text = "Boss HP -"
		_player_hp_plaque_label.text = "玩家 HP -"
		return
	_boss_hp_plaque_label.text = "Boss HP %d\n局胜 %d" % [int(set_state.boss_hp), int(challenge_state.boss_set_wins)]
	_player_hp_plaque_label.text = "玩家 HP %d\n局胜 %d" % [int(set_state.player_hp), int(challenge_state.player_set_wins)]

func _refresh_chip_stacks() -> void:
	_clear_children(_player_chip_stacks)
	_clear_children(_boss_chip_stacks)
	if run_state == null:
		return

	var player_metrics := [
		{"label": "BOD", "value": int(run_state.bod), "max": 3},
		{"label": "SPR", "value": int(run_state.spr), "max": 3},
		{"label": "REP", "value": int(run_state.rep), "max": 3},
		{"label": "LIFE", "value": int(run_state.life), "max": 10},
	]
	for index in range(player_metrics.size()):
		var metric: Dictionary = player_metrics[index]
		var widget := _build_chip_metric("player", metric.label, int(metric.value), int(metric.max))
		_player_chip_stacks.add_child(widget)
		_pin_rect(widget, Vector2(index * 78.0, 0.0), Vector2(74.0, 108.0))

	var boss_metrics := [
		{"label": "BOD", "value": int(run_state.boss_bod), "max": 3},
		{"label": "SPR", "value": int(run_state.boss_spr), "max": 3},
		{"label": "REP", "value": int(run_state.boss_rep), "max": 3},
	]
	for index in range(boss_metrics.size()):
		var metric: Dictionary = boss_metrics[index]
		var widget := _build_chip_metric("boss", metric.label, int(metric.value), int(metric.max))
		_boss_chip_stacks.add_child(widget)
		_pin_rect(widget, Vector2(index * 82.0, 0.0), Vector2(78.0, 104.0))

func _build_chip_metric(side: String, label_text: String, value: int, max_value: int) -> Control:
	var widget := Control.new()
	widget.mouse_filter = Control.MOUSE_FILTER_IGNORE
	widget.custom_minimum_size = Vector2(74, 108)

	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.90, 0.86, 0.80, 0.94))
	_pin_rect(label, Vector2(0.0, 0.0), Vector2(74.0, 18.0))
	widget.add_child(label)

	var stack_count := 1
	if max_value > 0 and value > 0:
		stack_count = clampi(int(round((float(value) / float(max_value)) * 5.0)), 1, 5)
	for stack_index in range(stack_count):
		var chip_panel := PanelContainer.new()
		chip_panel.add_theme_stylebox_override("panel", _make_chip_style(side, stack_index == stack_count - 1))
		_pin_rect(chip_panel, Vector2(10.0, 52.0 - stack_index * 7.0), Vector2(54.0, 14.0))
		if value <= 0:
			chip_panel.modulate.a = 0.36
		widget.add_child(chip_panel)

	var value_label := Label.new()
	value_label.text = str(value)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_color_override("font_color", Color(0.96, 0.92, 0.88, 0.98))
	_pin_rect(value_label, Vector2(0.0, 74.0), Vector2(74.0, 24.0))
	widget.add_child(value_label)

	return widget

func _build_peek_button_text(cost: int, free_peek: bool, disabled: bool) -> String:
	if disabled:
		return "牌池已展开"
	if free_peek:
		return "免费查看牌池"
	return "花 %d SPR 查看牌池" % cost

func _build_table_caption(challenge_state, set_state) -> String:
	if challenge_state == null or set_state == null:
		return "等待挑战开始。"
	if run_state.last_round_result.is_empty():
		return "桌面已摆开。"
	var result = run_state.last_round_result
	if bool(result.get("challenge_finished", false)):
		return "挑战比分 %d : %d" % [challenge_state.player_set_wins, challenge_state.boss_set_wins]
	if bool(result.get("set_finished", false)):
		return "本局结束，准备进入下一局。"
	return "上一回合：Boss -%d / 玩家 -%d" % [int(result.get("boss_damage", 0)), int(result.get("player_damage", 0))]

func _on_peek_requested() -> void:
	if _result_popup.visible or run_state == null or run_state.current_set_state == null:
		return
	var set_state = run_state.current_set_state
	var result = _peek_system.peek_pool(run_state, set_state.boss_deck)
	_notice_label.text = result.get("message", "")
	if result.get("ok", false):
		GameRun.emit_log(result.get("message", ""))
		GameRun.broadcast_state()
	_refresh_ui()
	if run_state.is_failed():
		_present_failure_popup("为了看清对手的牌列，你先把自己逼到崩溃边缘。")

func _on_addon_selected(addon_id: String) -> void:
	if _result_popup.visible or run_state == null:
		return
	var result = _addon_system.activate_addon(run_state, addon_id)
	_notice_label.text = result.get("message", "")
	if result.get("ok", false):
		GameRun.emit_log(result.get("message", ""))
		GameRun.broadcast_state()
	_refresh_ui()

func _on_player_card_selected(card_id: String) -> void:
	if _result_popup.visible or run_state == null or run_state.current_set_state == null:
		return
	var set_state = run_state.current_set_state
	if set_state.current_pool.is_empty() or not card_id in set_state.remaining_player_battle_cards:
		return

	var player_card = _data_loader().get_battle_card(card_id)
	var boss_card_id = _boss_ai.pick_card(set_state.current_pool, player_card.get("family", ""), run_state)
	if not set_state.consume_boss_card(boss_card_id):
		return
	set_state.mark_boss_card_used(boss_card_id)

	var result = _resolver.resolve_round(run_state, card_id, boss_card_id, _addon_system.build_round_context(run_state))
	set_state.last_round_result = result.duplicate(true)
	run_state.clear_round_state()
	GameRun.logging_system.push_round_result(result)
	SignalBus.emit_signal("battle_resolved", result)
	GameRun.broadcast_state()
	_print_round_debug(result)
	_refresh_ui()
	_present_round_result(result)

func _present_round_result(result: Dictionary) -> void:
	_pending_result = result
	var body = _build_result_body(result)
	if bool(result.get("challenge_finished", false)):
		if result.get("challenge_outcome", "defeat") == "victory":
			_popup_mode = "shop"
			_result_popup.show_result("挑战胜利", body, "进入商店")
		else:
			_popup_mode = "summary"
			_result_popup.show_result("挑战失败", body, "进入总结")
		return
	if bool(result.get("set_finished", false)):
		_popup_mode = "next_set"
		var title = "本局胜利" if result.get("set_winner", "") == "player" else "本局失败"
		_result_popup.show_result(title, body, "进入下一局")
		return
	_popup_mode = "next_round"
	_result_popup.show_result("回合结算", body, "继续")

func _present_failure_popup(extra_text: String) -> void:
	_popup_mode = "summary"
	_pending_result = {"reason": extra_text}
	var body = "%s\n\n当前状态：POS %d / 玩家 BOD %d / SPR %d / REP %d / LIFE %d / Boss BOD %d / SPR %d / REP %d" % [
		extra_text,
		run_state.pos,
		run_state.bod,
		run_state.spr,
		run_state.rep,
		run_state.life,
		run_state.boss_bod,
		run_state.boss_spr,
		run_state.boss_rep,
	]
	_result_popup.show_result("挑战失败", body, "进入总结")

func _build_result_body(result: Dictionary) -> String:
	var lines: Array[String] = []
	var challenge_state = run_state.challenge_state
	var set_snapshot: Dictionary = result.get("set_snapshot", {})
	lines.append("玩家打出：%s" % result.get("player_card", {}).get("name", ""))
	lines.append("Boss 打出：%s" % result.get("boss_card", {}).get("name", ""))
	if result.get("used_addon", "") != "":
		lines.append("本回合加注：%s" % result.get("used_addon", ""))
	lines.append("伤害结算：Boss -%d / 玩家 -%d" % [int(result.get("boss_damage", 0)), int(result.get("player_damage", 0))])
	lines.append("局势压力：POS %+d，当前 POS %d" % [int(result.get("margin", 0)), int(result.get("pos_after", 0))])
	lines.append("本局 HP：玩家 %d / Boss %d" % [int(set_snapshot.get("player_hp", 0)), int(set_snapshot.get("boss_hp", 0))])
	if challenge_state != null:
		lines.append("挑战比分：玩家 %d / Boss %d" % [challenge_state.player_set_wins, challenge_state.boss_set_wins])
	lines.append("玩家状态：BOD %d / SPR %d / REP %d / LIFE %d" % [run_state.bod, run_state.spr, run_state.rep, run_state.life])
	lines.append("Boss 状态：BOD %d / SPR %d / REP %d" % [run_state.boss_bod, run_state.boss_spr, run_state.boss_rep])
	if result.has("logs"):
		lines.append("")
		for line in result.get("logs", []):
			lines.append("- %s" % line)
	return "\n".join(lines)

func _print_round_debug(result: Dictionary) -> void:
	var set_snapshot: Dictionary = result.get("set_snapshot", {})
	var challenge_snapshot: Dictionary = result.get("challenge_snapshot", {})
	print("[Battle] Player -> %s" % result.get("player_card", {}).get("name", result.get("player_card_id", "")))
	print("[Battle] Boss   -> %s" % result.get("boss_card", {}).get("name", result.get("boss_card_id", "")))
	print("[Battle] HP     -> Player %d / Boss %d" % [int(set_snapshot.get("player_hp", 0)), int(set_snapshot.get("boss_hp", 0))])
	print("[Battle] Set/Turn -> %d / %d" % [int(set_snapshot.get("set_index", 0)), int(set_snapshot.get("round_index", 0))])
	print("[Battle] Set finished=%s Challenge finished=%s" % [str(result.get("set_finished", false)), str(result.get("challenge_finished", false))])
	if not challenge_snapshot.is_empty():
		print("[Battle] Score -> %d:%d" % [int(challenge_snapshot.get("player_set_wins", 0)), int(challenge_snapshot.get("boss_set_wins", 0))])

func _on_result_continue() -> void:
	match _popup_mode:
		"shop":
			GameRun.complete_boss(true, _pending_result)
		"summary":
			GameRun.complete_boss(false, _pending_result)
		"next_set":
			run_state.start_set(run_state.challenge_rules)
			GameRun.emit_log("进入第 %d 局。" % run_state.current_set_state.set_index)
			GameRun.broadcast_state()
			_start_round()
		_:
			_start_round()

func _scroll_log_to_bottom() -> void:
	var bar = _log_scroll.get_v_scroll_bar()
	if bar != null:
		_log_scroll.scroll_vertical = int(bar.max_value)

func _apply_visual_theme() -> void:
	_apply_texture(_bg_office, BG_OFFICE_PATH, TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	_apply_texture(_desk_surface, DESK_TABLE_PATH, TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	_apply_texture(_vignette_overlay, VIGNETTE_PATH, TextureRect.STRETCH_SCALE)
	_bg_office.modulate = Color(0.74, 0.72, 0.68, 0.92)
	_desk_surface.modulate = _desk_base_color
	_vignette_overlay.modulate = Color(0, 0, 0, 0.78)

	_apply_panel_style(_portrait_frame, Color(0.04, 0.03, 0.025, 0.16), Color(0.88, 0.76, 0.60, 0.10), Color(0, 0, 0, 0.20), 18, 24)
	_apply_panel_style(_top_round_info, Color(0.04, 0.03, 0.025, 0.44), Color(0.86, 0.76, 0.62, 0.10), Color(0, 0, 0, 0.14), 14, 16)
	_apply_panel_style(_boss_hp_plaque, Color(0.06, 0.045, 0.035, 0.56), Color(0.86, 0.74, 0.58, 0.14), Color(0, 0, 0, 0.18), 12, 16)
	_apply_panel_style(_player_hp_plaque, Color(0.06, 0.045, 0.035, 0.56), Color(0.82, 0.80, 0.74, 0.12), Color(0, 0, 0, 0.18), 12, 16)
	_apply_panel_style(_right_drawer_panel, Color(0.03, 0.03, 0.035, 0.78), Color(0.84, 0.78, 0.64, 0.10), Color(0, 0, 0, 0.18), 16, 18)
	_apply_panel_style(_log_panel, Color(0.04, 0.04, 0.045, 0.62), Color(0.82, 0.76, 0.62, 0.12), Color(0, 0, 0, 0.16), 14, 12)

	_portrait_caption.add_theme_color_override("font_color", Color(0.95, 0.92, 0.86, 0.92))
	_round_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.86, 0.98))
	_hp_versus_label.add_theme_color_override("font_color", Color(0.90, 0.88, 0.84, 0.96))
	_hint_label.add_theme_color_override("font_color", Color(0.80, 0.78, 0.74, 0.84))
	_intel_label.add_theme_color_override("font_color", Color(0.86, 0.82, 0.76, 0.92))
	_hand_title.add_theme_color_override("font_color", Color(0.94, 0.91, 0.86, 0.96))
	_hand_info_label.add_theme_color_override("font_color", Color(0.82, 0.79, 0.74, 0.90))
	_boss_hp_plaque_label.add_theme_color_override("font_color", Color(0.96, 0.92, 0.88, 0.98))
	_player_hp_plaque_label.add_theme_color_override("font_color", Color(0.96, 0.92, 0.88, 0.98))
	_notice_label.add_theme_color_override("font_color", Color(0.90, 0.87, 0.82, 1.0))
	_style_button(_drawer_peek_button, Color(0.14, 0.11, 0.10, 0.94), Color(0.88, 0.76, 0.60, 0.28))
	_style_button(_left_status_handle, Color(0.08, 0.07, 0.06, 0.80), Color(0.82, 0.76, 0.62, 0.14))

func _apply_stage_layout() -> void:
	if not is_node_ready():
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var safe_rect := Rect2(20.0, 16.0, viewport_size.x - 40.0, viewport_size.y - 32.0)
	_pin_rect(_safe_area, safe_rect.position, safe_rect.size)
	_pin_rect(_stage_root, Vector2.ZERO, safe_rect.size)

	_pin_rect(_bg_office, Vector2.ZERO, viewport_size)
	_pin_rect(_vignette_overlay, Vector2.ZERO, viewport_size)
	_pin_rect(_desk_surface, Vector2(-viewport_size.x * 0.02, viewport_size.y * 0.15), Vector2(viewport_size.x * 1.04, viewport_size.y * 0.90))

	var stage_size := _stage_root.size
	var boss_width: float = clamp(stage_size.x * 0.52, 560.0, 760.0)
	var boss_height: float = clamp(stage_size.y * 0.28, 180.0, 250.0)
	_pin_rect(_boss_stage, Vector2((stage_size.x - boss_width) * 0.5, 0.0), Vector2(boss_width, boss_height))
	_pin_rect(_portrait_frame, Vector2((boss_width - boss_width * 0.42) * 0.5, 2.0), Vector2(boss_width * 0.42, boss_height * 0.86))
	_pin_rect(_boss_panel, Vector2((boss_width - boss_width * 0.30) * 0.5, boss_height * 0.30), Vector2(boss_width * 0.30, boss_height * 0.24))
	_pin_rect(_portrait_caption, Vector2(boss_width * 0.32, 0.0), Vector2(boss_width * 0.36, 26.0))

	var table_rect := Rect2(stage_size.x * 0.06, stage_size.y * 0.19, stage_size.x * 0.88, stage_size.y * 0.60)
	_pin_rect(_table_core, table_rect.position, table_rect.size)
	_pin_rect(
		_top_round_info,
		Vector2((table_rect.size.x - clamp(table_rect.size.x * 0.34, 320.0, 460.0)) * 0.5, table_rect.size.y * 0.08),
		Vector2(clamp(table_rect.size.x * 0.34, 320.0, 460.0), 82.0)
	)
	_pin_rect(_intel_zone, Vector2(table_rect.size.x * 0.18, table_rect.size.y * 0.30), Vector2(table_rect.size.x * 0.64, clamp(table_rect.size.y * 0.24, 144.0, 190.0)))
	_pin_rect(_clash_area, Vector2(table_rect.size.x * 0.31, table_rect.size.y * 0.56), Vector2(table_rect.size.x * 0.38, 116.0))
	_pin_rect(_boss_hp_plaque, Vector2(table_rect.size.x * 0.77, table_rect.size.y * 0.24), Vector2(136.0, 68.0))
	_pin_rect(_player_hp_plaque, Vector2(table_rect.size.x * 0.05, table_rect.size.y * 0.60), Vector2(136.0, 68.0))
	_pin_rect(_boss_chip_stacks, Vector2(table_rect.size.x * 0.03, table_rect.size.y * 0.24), Vector2(252.0, 110.0))
	_pin_rect(_player_chip_stacks, Vector2(table_rect.size.x * 0.58, table_rect.size.y * 0.58), Vector2(320.0, 112.0))

	var left_stage_width: float = clamp(stage_size.x * 0.16, 208.0, 232.0)
	var left_stage_height: float = clamp(stage_size.y * 0.34, 250.0, 320.0)
	_pin_rect(_left_status_stage, Vector2(0.0, stage_size.y * 0.62), Vector2(left_stage_width, left_stage_height))
	_pin_rect(_left_status_handle, Vector2(0.0, max((left_stage_height - 90.0) * 0.5, 0.0)), Vector2(22.0, 90.0))
	_pin_rect(_left_status_drawer, Vector2(18.0, 0.0), Vector2(left_stage_width - 18.0, left_stage_height))
	_left_drawer_open_pos = _left_status_drawer.position
	_left_drawer_closed_pos = Vector2(-_left_status_drawer.size.x + 16.0, 0.0)
	_set_left_drawer_open(_left_drawer_pinned or _left_handle_hovered or _left_drawer_hovered, true)

	var right_drawer_width: float = clamp(stage_size.x * 0.19, 256.0, 300.0)
	var right_drawer_height: float = clamp(stage_size.y * 0.40, 260.0, 360.0)
	var right_drawer_y: float = stage_size.y * 0.52
	_pin_rect(_right_drawer, Vector2(stage_size.x - right_drawer_width, right_drawer_y), Vector2(right_drawer_width, right_drawer_height))
	_right_drawer_open_pos = _right_drawer.position
	_right_drawer_closed_pos = Vector2(stage_size.x - 14.0, right_drawer_y)
	_set_right_drawer_open(_right_hotzone_hovered or _right_drawer_hovered, true)
	_pin_rect(_right_hotzone, Vector2(stage_size.x - 18.0, right_drawer_y + 8.0), Vector2(18.0, right_drawer_height - 16.0))

	var hand_width: float = clamp(stage_size.x * 0.70, 860.0, 1080.0)
	var hand_height: float = clamp(stage_size.y * 0.30, 220.0, 290.0)
	_pin_rect(_player_hand_stage, Vector2((stage_size.x - hand_width) * 0.5, stage_size.y - hand_height - 10.0), Vector2(hand_width, hand_height))
	_queue_hand_layout()

func _pin_rect(control: Control, position: Vector2, size: Vector2) -> void:
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 0.0
	control.anchor_bottom = 0.0
	control.position = position
	control.size = size

func _apply_panel_style(panel: PanelContainer, fill: Color, border: Color, shadow: Color, radius: int, shadow_size: int) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	style.shadow_color = shadow
	style.shadow_size = shadow_size
	panel.add_theme_stylebox_override("panel", style)

func _style_button(button: Button, fill: Color, border: Color) -> void:
	button.add_theme_stylebox_override("normal", _make_button_style(fill, border))
	button.add_theme_stylebox_override("hover", _make_button_style(fill.lightened(0.08), border.lightened(0.20)))
	button.add_theme_stylebox_override("pressed", _make_button_style(fill.darkened(0.12), border))
	button.add_theme_stylebox_override("disabled", _make_button_style(fill.darkened(0.08), Color(border.r, border.g, border.b, border.a * 0.45)))
	button.add_theme_color_override("font_color", Color(0.96, 0.92, 0.88))

func _make_button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style

func _make_chip_style(side: String, emphasis: bool) -> StyleBoxFlat:
	var fill := Color(0.30, 0.26, 0.20, 0.96)
	var border := Color(0.82, 0.74, 0.58, 0.52)
	if side == "boss":
		fill = Color(0.18, 0.18, 0.20, 0.96)
		border = Color(0.72, 0.72, 0.76, 0.46)
	if emphasis:
		fill = fill.lightened(0.08)
		border = border.lightened(0.12)

	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.shadow_color = Color(0, 0, 0, 0.14)
	style.shadow_size = 3
	return style

func _connect_stage_signals() -> void:
	_right_hotzone.mouse_entered.connect(_on_right_hotzone_entered)
	_right_hotzone.mouse_exited.connect(_on_right_hotzone_exited)
	_right_drawer.mouse_entered.connect(_on_right_drawer_entered)
	_right_drawer.mouse_exited.connect(_on_right_drawer_exited)
	_left_status_handle.mouse_entered.connect(_on_left_handle_entered)
	_left_status_handle.mouse_exited.connect(_on_left_handle_exited)
	_left_status_handle.pressed.connect(_on_left_handle_pressed)
	_left_status_drawer.mouse_entered.connect(_on_left_drawer_entered)
	_left_status_drawer.mouse_exited.connect(_on_left_drawer_exited)

func _on_right_hotzone_entered() -> void:
	_right_hotzone_hovered = true
	_set_right_drawer_open(true)

func _on_right_hotzone_exited() -> void:
	_right_hotzone_hovered = false
	_queue_right_drawer_close()

func _on_right_drawer_entered() -> void:
	_right_drawer_hovered = true
	_set_right_drawer_open(true)

func _on_right_drawer_exited() -> void:
	_right_drawer_hovered = false
	_queue_right_drawer_close()

func _queue_right_drawer_close() -> void:
	await get_tree().create_timer(0.08).timeout
	if not _right_hotzone_hovered and not _right_drawer_hovered:
		_set_right_drawer_open(false)

func _set_right_drawer_open(open: bool, immediate: bool = false) -> void:
	var target_position := _right_drawer_open_pos if open else _right_drawer_closed_pos
	var target_alpha := 1.0 if open else 0.0
	if immediate:
		_right_drawer.position = target_position
		_right_drawer.modulate.a = target_alpha
		return
	if _right_drawer_tween != null:
		_right_drawer_tween.kill()
	_right_drawer_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_right_drawer_tween.tween_property(_right_drawer, "position", target_position, 0.16)
	_right_drawer_tween.parallel().tween_property(_right_drawer, "modulate:a", target_alpha, 0.16)

func _on_left_handle_entered() -> void:
	_left_handle_hovered = true
	if not _left_drawer_pinned:
		_set_left_drawer_open(true)

func _on_left_handle_exited() -> void:
	_left_handle_hovered = false
	_queue_left_drawer_restore()

func _on_left_drawer_entered() -> void:
	_left_drawer_hovered = true
	_set_left_drawer_open(true)

func _on_left_drawer_exited() -> void:
	_left_drawer_hovered = false
	_queue_left_drawer_restore()

func _queue_left_drawer_restore() -> void:
	await get_tree().create_timer(0.08).timeout
	if _left_drawer_pinned:
		_set_left_drawer_open(true)
	elif not _left_handle_hovered and not _left_drawer_hovered:
		_set_left_drawer_open(false)

func _on_left_handle_pressed() -> void:
	_left_drawer_pinned = not _left_drawer_pinned
	_set_left_drawer_open(_left_drawer_pinned or _left_handle_hovered or _left_drawer_hovered)

func _set_left_drawer_open(open: bool, immediate: bool = false) -> void:
	_left_status_handle.text = "●" if open else "▶"
	var target_position := _left_drawer_open_pos if open else _left_drawer_closed_pos
	if immediate:
		_left_status_drawer.position = target_position
		return
	if _left_drawer_tween != null:
		_left_drawer_tween.kill()
	_left_drawer_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_left_drawer_tween.tween_property(_left_status_drawer, "position", target_position, 0.16)

func _apply_texture(texture_rect: TextureRect, path: String, stretch_mode: int) -> void:
	texture_rect.texture = _load_texture(path)
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = stretch_mode

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()

func _load_texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

func _get_boss_portrait_path(presentation: Dictionary) -> String:
	var presentation_path := str(presentation.get("portrait_path", ""))
	if not presentation_path.is_empty():
		return presentation_path
	match str(boss_def.get("id", "")):
		"team_lead":
			return UI_ASSET_PATHS.default_boss_portrait_path()
		_:
			return UI_ASSET_PATHS.default_boss_portrait_path()

func _data_loader():
	return get_node_or_null("/root/DataLoader")

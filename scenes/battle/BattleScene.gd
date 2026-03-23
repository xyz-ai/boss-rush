extends Control

const CARD_VIEW_SCENE := preload("res://scenes/battle/CardView.tscn")
const BATTLE_RESOLVER_SCRIPT := preload("res://scripts/core/BattleResolver.gd")
const BOSS_AI_SCRIPT := preload("res://scripts/core/BossAI.gd")
const PEEK_SYSTEM_SCRIPT := preload("res://scripts/systems/PeekSystem.gd")
const ADDON_SYSTEM_SCRIPT := preload("res://scripts/systems/AddonSystem.gd")
const COLLAPSE_EFFECTS_SCRIPT := preload("res://scripts/systems/CollapseEffects.gd")

var run_state
var boss_def: Dictionary = {}

var _resolver
var _boss_ai
var _peek_system = PEEK_SYSTEM_SCRIPT.new()
var _addon_system = ADDON_SYSTEM_SCRIPT.new()
var _collapse_effects
var _desk_base_color: Color = Color(0.18, 0.14, 0.12, 0.95)

var _card_views: Dictionary = {}
var _popup_mode: String = ""
var _pending_result: Dictionary = {}

@onready var _desk_surface: ColorRect = $BackgroundLayer/DeskSurface
@onready var _dust_overlay: Label = $BackgroundLayer/DustOrCrackOverlay
@onready var _boss_silhouette: Label = $SafeArea/RootHBox/MainStage/BossStage/MarginContainer/VBoxContainer/PortraitRow/PortraitFrame/BustMargin/BossSilhouette
@onready var _status_panel = $SafeArea/RootHBox/SideRail/StatusPanel
@onready var _boss_panel = $SafeArea/RootHBox/MainStage/BossStage/MarginContainer/VBoxContainer/PortraitRow/BossPanel
@onready var _addon_panel = $SafeArea/RootHBox/SideRail/AddonPanel
@onready var _card_row: HBoxContainer = $SafeArea/RootHBox/MainStage/PlayerHandStage/MarginContainer/VBoxContainer/HandScroll/CardRow
@onready var _hand_info_label: Label = $SafeArea/RootHBox/MainStage/PlayerHandStage/MarginContainer/VBoxContainer/HandInfoLabel
@onready var _log_label: RichTextLabel = $SafeArea/RootHBox/SideRail/LogPanel/MarginContainer/VBoxContainer/LogScroll/LogText
@onready var _log_scroll: ScrollContainer = $SafeArea/RootHBox/SideRail/LogPanel/MarginContainer/VBoxContainer/LogScroll
@onready var _notice_label: Label = $SafeArea/RootHBox/SideRail/ActionPanel/MarginContainer/VBoxContainer/NoticeLabel
@onready var _set_round_banner: Label = $SafeArea/RootHBox/MainStage/TableStage/MarginContainer/VBoxContainer/SetRoundBanner
@onready var _round_result_label: Label = $SafeArea/RootHBox/MainStage/TableStage/MarginContainer/VBoxContainer/ClashArea/CenterStack/RoundResultLabel
@onready var _player_hp_bar: ProgressBar = $SafeArea/RootHBox/MainStage/TableStage/MarginContainer/VBoxContainer/ClashArea/PlayerGauge/PlayerHpBar
@onready var _boss_hp_bar: ProgressBar = $SafeArea/RootHBox/MainStage/TableStage/MarginContainer/VBoxContainer/ClashArea/BossGauge/BossHpBar
@onready var _player_hp_value: Label = $SafeArea/RootHBox/MainStage/TableStage/MarginContainer/VBoxContainer/ClashArea/PlayerGauge/PlayerHpValue
@onready var _boss_hp_value: Label = $SafeArea/RootHBox/MainStage/TableStage/MarginContainer/VBoxContainer/ClashArea/BossGauge/BossHpValue
@onready var _result_popup = $ResultPopup

func _ready() -> void:
	_collapse_effects = COLLAPSE_EFFECTS_SCRIPT.new(_data_loader().get_balance("ui_thresholds", {}))
	_boss_panel.peek_requested.connect(_on_peek_requested)
	_addon_panel.addon_selected.connect(_on_addon_selected)
	_result_popup.continue_pressed.connect(_on_result_continue)
	if run_state != null:
		_setup_scene()

func bind_context(next_run_state, next_boss_def: Dictionary) -> void:
	run_state = next_run_state
	boss_def = next_boss_def.duplicate(true)
	if is_node_ready():
		_setup_scene()

func apply_effect_profile(profile: Dictionary) -> void:
	_status_panel.apply_effect_profile(profile)
	_boss_panel.apply_effect_profile(profile)
	_addon_panel.apply_effect_profile(profile)
	_dust_overlay.modulate.a = float(profile.get("crack_alpha", 0.0))
	_desk_surface.color = Color(
		_desk_base_color.r - float(profile.get("coldness", 0.0)) * 0.03,
		_desk_base_color.g - float(profile.get("fatigue", 0.0)) * 0.04,
		_desk_base_color.b - float(profile.get("coldness", 0.0)) * 0.03,
		_desk_base_color.a
	)
	for card_view in _card_views.values():
		card_view.set_hover_instability(float(profile.get("hover_instability", 0.0)))

func _setup_scene() -> void:
	_resolver = BATTLE_RESOLVER_SCRIPT.new(_data_loader().get_balance("matchup_rules", {}))
	_boss_ai = BOSS_AI_SCRIPT.new(_data_loader().get_balance("matchup_rules", {}))
	_boss_panel.set_boss(boss_def)
	_sync_presentation()
	if run_state.current_set_state == null:
		run_state.start_set(run_state.challenge_rules)
	if run_state.current_set_state != null and run_state.current_set_state.current_pool.is_empty():
		_start_round()
	else:
		_refresh_ui()

func _sync_presentation() -> void:
	var presentation: Dictionary = boss_def.get("presentation", {})
	var accent = Color.from_string(str(presentation.get("accent_color", "#cfd5db")), Color(0.82, 0.84, 0.87))
	_desk_base_color = Color.from_string(str(presentation.get("desk_tint", "#2f2624")), Color(0.18, 0.14, 0.12, 0.95))
	_boss_silhouette.text = "%s\n%s" % [boss_def.get("title", "BOSS"), boss_def.get("name", "")]
	_boss_silhouette.modulate = accent

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

func _start_round() -> void:
	if run_state == null or run_state.current_set_state == null:
		return
	var set_state = run_state.current_set_state
	if not set_state.has_rounds_remaining():
		return
	run_state.begin_round(_boss_ai.prepare_pool(boss_def, run_state))
	GameRun.emit_log("第 %d 局 第 %d 回合开始。" % [set_state.set_index, set_state.round_index + 1])
	GameRun.broadcast_state()
	_notice_label.text = "从下方手牌中打出 1 张战斗牌。你也可以先启用 1 张加注牌，再决定是否查看 Boss 牌池。"
	_refresh_ui()

func _refresh_ui() -> void:
	if run_state == null:
		return
	var set_state = run_state.current_set_state
	var challenge_state = run_state.challenge_state
	_status_panel.update_from_run_state(run_state)
	_boss_panel.update_from_battle(run_state, boss_def)
	_build_player_cards()

	if set_state != null:
		_boss_panel.set_round_pool(set_state.current_pool, set_state.pool_revealed)
		_boss_panel.set_peek_state(
			int(_data_loader().get_balance("peek_cost_spr", 1)),
			set_state.free_peek_this_round,
			set_state.pool_revealed or set_state.current_pool.is_empty()
		)
		_addon_panel.set_inventory(run_state.get_remaining_addons(), _data_loader().get_all_addons(), set_state.round_active_addon)
		_set_round_banner.text = "第 %d 局 / 第 %d 回合" % [set_state.set_index, min(set_state.round_index + 1, set_state.max_rounds)]
		_hand_info_label.text = "剩余战斗牌 %d / 已打出 %d" % [
			set_state.remaining_player_battle_cards.size(),
			set_state.played_player_battle_cards.size(),
		]
		_player_hp_bar.max_value = int(run_state.challenge_rules.get("player_hp_per_set", 6))
		_player_hp_bar.value = set_state.player_hp
		_player_hp_value.text = "玩家 HP %d" % set_state.player_hp
		_boss_hp_bar.max_value = int(run_state.challenge_rules.get("boss_hp_per_set", 6))
		_boss_hp_bar.value = set_state.boss_hp
		_boss_hp_value.text = "Boss HP %d" % set_state.boss_hp
		_round_result_label.text = _build_table_caption(challenge_state, set_state)

	_log_label.text = GameRun.get_recent_logs_text(8)
	call_deferred("_scroll_log_to_bottom")
	apply_effect_profile(_collapse_effects.evaluate(run_state))

func _build_table_caption(challenge_state, set_state) -> String:
	if challenge_state == null or set_state == null:
		return "等待挑战开始。"
	if run_state.last_round_result.is_empty():
		return "桌面已经摆开。你还有 %d 张牌可以决定这一局的走向。" % set_state.remaining_player_battle_cards.size()
	var result = run_state.last_round_result
	if bool(result.get("challenge_finished", false)):
		return "挑战比分 %d : %d" % [challenge_state.player_set_wins, challenge_state.boss_set_wins]
	if bool(result.get("set_finished", false)):
		return "本局结束，准备进入下一局。当前比分 %d : %d" % [challenge_state.player_set_wins, challenge_state.boss_set_wins]
	return "上一回合：玩家对 Boss 造成 %d / 承受 %d。" % [int(result.get("boss_damage", 0)), int(result.get("player_damage", 0))]

func _on_peek_requested() -> void:
	if _result_popup.visible or run_state == null or run_state.current_set_state == null:
		return
	var set_state = run_state.current_set_state
	var result = _peek_system.peek_pool(run_state, set_state.current_pool)
	_notice_label.text = result.get("message", "")
	if result.get("ok", false):
		GameRun.emit_log(result.get("message", ""))
		GameRun.broadcast_state()
	_refresh_ui()
	if run_state.is_failed():
		_present_failure_popup("为了看清候选牌池，你先把自己拖到了崩溃边缘。")

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
	var result = _resolver.resolve_round(run_state, card_id, boss_card_id, _addon_system.build_round_context(run_state))
	set_state.last_round_result = result.duplicate(true)
	run_state.clear_round_state()
	GameRun.logging_system.push_round_result(result)
	SignalBus.emit_signal("battle_resolved", result)
	GameRun.broadcast_state()
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
		var title = "本局胜利" if result.get("set_winner", "") == "player" else "本局失利"
		_result_popup.show_result(title, body, "进入下一局")
		return
	_popup_mode = "next_round"
	_result_popup.show_result("回合结算", body, "继续")

func _present_failure_popup(extra_text: String) -> void:
	_popup_mode = "summary"
	_pending_result = {"reason": extra_text}
	var body = "%s\n\n当前状态：POS %d / BOD %d / SPR %d / REP %d / LIFE %d" % [
		extra_text,
		run_state.pos,
		run_state.bod,
		run_state.spr,
		run_state.rep,
		run_state.life,
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
	lines.append("本局 HP：玩家 %d / Boss %d" % [
		int(set_snapshot.get("player_hp", 0)),
		int(set_snapshot.get("boss_hp", 0)),
	])
	if challenge_state != null:
		lines.append("挑战比分：玩家 %d / Boss %d" % [challenge_state.player_set_wins, challenge_state.boss_set_wins])
	lines.append("长期状态：BOD %d / SPR %d / REP %d / LIFE %d" % [
		run_state.bod,
		run_state.spr,
		run_state.rep,
		run_state.life,
	])
	if result.has("logs"):
		lines.append("")
		for line in result.get("logs", []):
			lines.append("- %s" % line)
	return "\n".join(lines)

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

func _data_loader():
	return get_node_or_null("/root/DataLoader")

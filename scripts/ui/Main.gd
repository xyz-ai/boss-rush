extends RefCounted
class_name MvpMainController

const CARD_VIEW_SCENE := preload("res://scenes/ui/CardView.tscn")
const BOSS_BATTLE_DECK_VIEW_SCRIPT := preload("res://scripts/ui/BossBattleDeckView.gd")
const BET_ROW_VIEW_SCRIPT := preload("res://scripts/ui/BetRowView.gd")
const BET_CARD_SCRIPT := preload("res://scripts/game/BetCard.gd")
const TOOLTIP_PANEL_SCENE := preload("res://scenes/ui/TooltipPanel.tscn")

const MAX_SETS := 3
const WINS_TO_CLEAR := 2
const MAX_TURNS := 5
const SET_HP := 6
const STARTING_BOD := 3
const STARTING_SPR := 3
const STARTING_REP := 3
const MAX_LOG_LINES := 5
const BET_PHASE_CLOSED := "closed"
const BET_MODE_DEFAULT_ENABLED := true
const TURN_RESULT_DISPLAY_DURATION := 1.6
const VIEW_MODE_BATTLE := "battle"
const VIEW_MODE_BET := "bet"
const ROUND_FOLLOWUP_NONE := ""
const ROUND_FOLLOWUP_OPEN_POST_BET := "open_post_bet"
const ROUND_FOLLOWUP_FINALIZE_TURN := "finalize_turn"

var _host: Control

var _background: TextureRect
var _content_root: Control
var _boss_area: Control
var _boss_portrait: TextureRect
var _table_area: Control
var _table_board: TextureRect
var _center_info: Control
var _round_label: Label
var _turn_label: Label
var _player_hp_label: Label
var _boss_hp_label: Label
var _overlay_ui: Control
var _overlay_log_label: RichTextLabel

var _hand_anchor: HBoxContainer
var _player_battle_panel: Control
var _player_mode_bar: HBoxContainer
var _player_battle_tab_button: Button
var _player_bet_tab_button: Button
var _player_mode_title_label: Label
var _player_card_viewport: Control
var _player_optional_summary_button: Button
var _player_summary_panel: PanelContainer
var _player_summary_label: Label
var _boss_deck_root: Control
var _boss_hand_count_label: Label
var _boss_hand_animation_anchor: Control
var _deck_row: HBoxContainer
var _boss_battle_deck_root: Control
var _boss_battle_panel: Control
var _boss_card_viewport: Control
var _battle_deck_title: Label
var _reveal_battle_deck_button: Button
var _battle_deck_row: HBoxContainer
var _boss_mode_bar: HBoxContainer
var _boss_battle_tab_button: Button
var _boss_bet_tab_button: Button
var _boss_reveal_status_label: Label
var _boss_summary_toggle_button: Button
var _boss_summary_panel: PanelContainer
var _boss_summary_label: Label
var _boss_archetype_label: Label
var _clash_root: Control
var _player_card_slot: Control
var _boss_card_slot: Control
var _clash_result_label: Label
var _player_area: Control
var _screen_effects: Control
var _player_bod_label: Label
var _player_spr_label: Label
var _player_rep_label: Label
var _boss_bod_label: Label
var _boss_spr_label: Label
var _boss_rep_label: Label
var _boss_bet_area: Control
var _boss_bet_row: HBoxContainer
var _peek_boss_bet_button: Button
var _player_bet_area: Control
var _player_bet_row: HBoxContainer
var _bet_phase_hint: Label
var _bet_result_hint: Label
var _turn_result_popup: Control
var _feedback_label: Label
var _end_turn_button: Button
var _tooltip_panel: Control

var _player_hand_view: MvpPlayerHandView
var _boss_deck_view: MvpBossDeckView
var _boss_battle_deck_view
var _clash_area_view: MvpClashAreaView
var _player_bet_view
var _boss_bet_view
var _boss_ai: MvpBossAI = MvpBossAI.new()
var _resolver: MvpBattleResolver = MvpBattleResolver.new()
var _boss_template_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _boss_bet_rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _player_state: MvpCombatActorState
var _boss_state: MvpCombatActorState
var _bet_cards: Array = []

var _current_set_index: int = 1
var _current_turn_index: int = 1
var _player_set_wins: int = 0
var _boss_set_wins: int = 0
var _boss_battle_revealed: bool = false
var _boss_bet_revealed: bool = false
var _current_boss_template_id: String = MvpBattleCard.DEFAULT_BOSS_TEMPLATE_ID
var _current_boss_archetype: String = MvpBattleCard.ARCHETYPE_BALANCED
var _challenge_over: bool = false
var _input_locked: bool = false
var _logs: Array[String] = []

var bet_mode_enabled: bool = BET_MODE_DEFAULT_ENABLED
var max_bets_per_turn: int = 1
var extra_bet_cost_scaling_enabled: bool = false
var extra_bet_cost_curve: Array = []
var boss_bet_peek_enabled: bool = true
var boss_bet_peek_cost_enabled: bool = false
var boss_bet_peek_snapshot_only: bool = true

var _bet_phase: String = BET_PHASE_CLOSED
var _player_pre_bet: MvpBetCard = null
var _player_post_bet: MvpBetCard = null
var _boss_post_bet: MvpBetCard = null
var _pending_player_slot: int = -1
var _pending_boss_slot: int = -1
var _post_bet_window_open: bool = false
var _post_bet_effects_applied: bool = false
var _current_round_result: Dictionary = {}
var _bet_result_text: String = ""
var _boss_bet_peek_snapshot_text: String = ""
var _player_view_mode: String = VIEW_MODE_BATTLE
var _boss_view_mode: String = VIEW_MODE_BATTLE
var _player_summary_visible: bool = false
var _boss_summary_visible: bool = false
var _round_feedback_active: bool = false
var _round_feedback_version: int = 0
var _pending_round_followup: String = ROUND_FOLLOWUP_NONE
var _pending_round_followup_result: Dictionary = {}

func _init(host: Control) -> void:
	_host = host
	_bet_cards = BET_CARD_SCRIPT.build_default_cards()

func ready() -> void:
	_bind_nodes()
	_hide_turn_result_popup(true)
	_configure_mouse_filters()
	_setup_views()
	_sync_reveal_battle_deck_layout()
	_ensure_overlay_log()
	if _screen_effects != null and _screen_effects.has_method("bind_target"):
		_screen_effects.bind_target(_content_root)
	_start_new_challenge()

func handle_notification(what: int) -> void:
	if what == Control.NOTIFICATION_RESIZED:
		_sync_reveal_battle_deck_layout()

func get_state_snapshot() -> Dictionary:
	var snapshot_player_bet = _current_snapshot_player_bet()
	return {
		"current_set_index": _current_set_index,
		"current_turn_index": _current_turn_index,
		"player_set_wins": _player_set_wins,
		"boss_set_wins": _boss_set_wins,
		"current_boss_template_id": _current_boss_template_id,
		"boss_battle_revealed": _boss_battle_revealed,
		"boss_bet_revealed": _boss_bet_revealed,
		"boss_archetype": _current_boss_archetype,
		"challenge_over": _challenge_over,
		"round_feedback_active": _round_feedback_active,
		"bet_mode_enabled": bet_mode_enabled,
		"bet_phase": _bet_phase,
		"player_view_mode": _player_view_mode,
		"boss_view_mode": _boss_view_mode,
		"player_summary_visible": _player_summary_visible,
		"boss_summary_visible": _boss_summary_visible,
		"post_bet_window_open": _post_bet_window_open,
		"post_bet_effects_applied": _post_bet_effects_applied,
		"current_round_winner": str(_current_round_result.get("winner", "")),
		"player_pre_bet_id": _player_pre_bet.id if _player_pre_bet != null else "",
		"player_post_bet_id": _player_post_bet.id if _player_post_bet != null else "",
		"boss_post_bet_id": _boss_post_bet.id if _boss_post_bet != null else "",
		"player_bet_id": snapshot_player_bet.id if snapshot_player_bet != null else "",
		"player_bet_timing": _current_snapshot_player_bet_timing(),
		"boss_bet_id": _boss_post_bet.id if _boss_post_bet != null else "",
		"boss_bet_timing": BET_CARD_SCRIPT.TIMING_POST if _boss_post_bet != null else "",
		"bet_result_text": _bet_result_text,
		"boss_bet_peek_snapshot_text": _boss_bet_peek_snapshot_text,
		"player": _player_state.snapshot() if _player_state != null else {},
		"boss": _boss_state.snapshot() if _boss_state != null else {},
	}

func _current_snapshot_player_bet() -> MvpBetCard:
	if _player_post_bet != null:
		return _player_post_bet
	if _player_pre_bet != null:
		return _player_pre_bet
	return null

func _current_snapshot_player_bet_timing() -> String:
	if _player_post_bet != null:
		return BET_CARD_SCRIPT.TIMING_POST
	if _player_pre_bet != null:
		return BET_CARD_SCRIPT.TIMING_PRE
	return ""

func set_bet_mode_enabled(enabled: bool, restart: bool = true) -> void:
	bet_mode_enabled = enabled
	if restart:
		_start_new_challenge()
		return
	_reset_turn_bet_state(false)
	_refresh_ui()

func push_log(message: String) -> void:
	_logs.append(message)
	while _logs.size() > MAX_LOG_LINES:
		_logs.remove_at(0)
	print("[MainMVP] %s" % message)
	_refresh_overlay_log()

func _find_node(paths: Array[String]) -> Node:
	for path in paths:
		var node := _host.get_node_or_null(path)
		if node != null:
			return node
	return null

func _find_control(paths: Array[String]) -> Control:
	return _find_node(paths) as Control

func _find_label(paths: Array[String]) -> Label:
	return _find_node(paths) as Label

func _find_button(paths: Array[String]) -> Button:
	return _find_node(paths) as Button

func _find_row(paths: Array[String]) -> HBoxContainer:
	return _find_node(paths) as HBoxContainer

func _assert_required(node: Node, message: String) -> void:
	assert(node != null, message)

func _bind_nodes() -> void:
	_background = _find_control(["Background"]) as TextureRect
	_content_root = _find_control(["ContentRoot"])
	_table_area = _find_control(["ContentRoot/TableArea"])
	_boss_area = _find_control([
		"ContentRoot/TableArea/BossArea",
		"ContentRoot/BossArea",
	])
	_boss_portrait = _find_control([
		"ContentRoot/TableArea/BossArea/BossPortrait",
		"ContentRoot/BossArea/BossPortrait",
	]) as TextureRect
	_table_board = _find_control(["ContentRoot/TableArea/TableBoard"]) as TextureRect
	_center_info = _find_control(["ContentRoot/TableArea/CenterInfo"])
	_round_label = _find_label(["ContentRoot/TableArea/CenterInfo/RoundLabel"])
	_turn_label = _find_label(["ContentRoot/TableArea/CenterInfo/TurnLabel"])
	_player_hp_label = _find_label(["ContentRoot/TableArea/PlayerHP"])
	_boss_hp_label = _find_label(["ContentRoot/TableArea/BossHP"])
	_overlay_ui = _find_control(["ContentRoot/OverlayUI"])

	_player_area = _find_control(["ContentRoot/TableArea/PlayerArea"])
	_player_mode_bar = _find_row(["ContentRoot/TableArea/PlayerArea/ModeBar"])
	_player_battle_tab_button = _find_button(["ContentRoot/TableArea/PlayerArea/ModeBar/BattleTabButton"])
	_player_bet_tab_button = _find_button(["ContentRoot/TableArea/PlayerArea/ModeBar/BetTabButton"])
	_player_mode_title_label = _find_label(["ContentRoot/TableArea/PlayerArea/ModeTitleLabel"])
	_player_card_viewport = _find_control(["ContentRoot/TableArea/PlayerArea/CardViewport"])
	_player_battle_panel = _find_control([
		"ContentRoot/TableArea/PlayerArea/CardViewport/BattleHandPanel",
		"ContentRoot/TableArea/PlayerArea/HandAnchor",
	])
	_hand_anchor = _find_row([
		"ContentRoot/TableArea/PlayerArea/CardViewport/BattleHandPanel/BattleCardRow",
		"ContentRoot/TableArea/PlayerArea/HandAnchor",
	])
	_player_bet_area = _find_control([
		"ContentRoot/TableArea/PlayerArea/CardViewport/BetHandPanel",
		"ContentRoot/TableArea/PlayerBetArea",
	])
	_player_bet_row = _find_row([
		"ContentRoot/TableArea/PlayerArea/CardViewport/BetHandPanel/BetCardRow",
		"ContentRoot/TableArea/PlayerBetArea/PlayerBetRow",
	])
	_player_optional_summary_button = _find_button([
		"ContentRoot/TableArea/PlayerArea/OptionalSummaryButton",
		"ContentRoot/TableArea/PlayerArea/OptionalSummary",
	])

	_boss_card_viewport = _find_control(["ContentRoot/TableArea/BossArea/BossCardViewport"])
	_boss_battle_panel = _find_control([
		"ContentRoot/TableArea/BossArea/BossCardViewport/BossBattleDeckPanel",
		"ContentRoot/TableArea/BossBattleDeckView",
	])
	_boss_battle_deck_root = _boss_battle_panel
	_battle_deck_title = _find_label([
		"ContentRoot/TableArea/BossArea/BossModeTitleLabel",
		"ContentRoot/TableArea/BossBattleDeckView/BattleDeckTitle",
	])
	_reveal_battle_deck_button = _find_button([
		"ContentRoot/TableArea/BossArea/BossCardViewport/BossBattleDeckPanel/RevealBattleDeckButton",
		"ContentRoot/TableArea/BossBattleDeckView/RevealBattleDeckButton",
	])
	_battle_deck_row = _find_row([
		"ContentRoot/TableArea/BossArea/BossCardViewport/BossBattleDeckPanel/BossBattleCardRow",
		"ContentRoot/TableArea/BossBattleDeckView/BattleDeckRow",
	])
	_boss_bet_area = _find_control([
		"ContentRoot/TableArea/BossArea/BossCardViewport/BossBetDeckPanel",
		"ContentRoot/TableArea/BossBetArea",
	])
	_boss_bet_row = _find_row([
		"ContentRoot/TableArea/BossArea/BossCardViewport/BossBetDeckPanel/BossBetCard",
		"ContentRoot/TableArea/BossBetArea/BetRow",
	])
	_boss_battle_tab_button = _find_button(["ContentRoot/TableArea/BossArea/BossModeBar/BossBattleTabButton"])
	_boss_bet_tab_button = _find_button(["ContentRoot/TableArea/BossArea/BossModeBar/BossBetTabButton"])
	_peek_boss_bet_button = _find_button([
		"ContentRoot/TableArea/BossBetArea/PeekBossBetButton",
	])
	_boss_mode_bar = _find_row(["ContentRoot/TableArea/BossArea/BossModeBar"])
	_boss_reveal_status_label = _find_label(["ContentRoot/TableArea/BossArea/BossModeBar/RevealStatusLabel"])
	_boss_summary_toggle_button = _find_button([
		"ContentRoot/TableArea/BossArea/BossSummaryToggleButton",
		"ContentRoot/TableArea/BossArea/BossSummaryToggle",
	])

	_boss_deck_root = _find_control(["ContentRoot/TableArea/BossDeckView"])
	_boss_hand_count_label = _find_label(["ContentRoot/TableArea/BossDeckView/BossHandCountLabel"])
	_boss_hand_animation_anchor = _find_control(["ContentRoot/TableArea/BossDeckView/BossHandAnimationAnchor"])
	_deck_row = _find_row(["ContentRoot/TableArea/BossDeckView/DeckRow"])

	_clash_root = _find_control(["ContentRoot/TableArea/ClashArea"])
	_player_card_slot = _find_control(["ContentRoot/TableArea/ClashArea/PlayerCardSlot"])
	_boss_card_slot = _find_control(["ContentRoot/TableArea/ClashArea/BossCardSlot"])
	_clash_result_label = _find_label(["ContentRoot/TableArea/ClashArea/ClashResultLabel"])
	_player_bod_label = _find_label(["ContentRoot/TableArea/PlayerStatusPanel/MarginContainer/VBoxContainer/PlayerBOD"])
	_player_spr_label = _find_label(["ContentRoot/TableArea/PlayerStatusPanel/MarginContainer/VBoxContainer/PlayerSPR"])
	_player_rep_label = _find_label(["ContentRoot/TableArea/PlayerStatusPanel/MarginContainer/VBoxContainer/PlayerREP"])
	_boss_bod_label = _find_label(["ContentRoot/TableArea/BossStatusPanel/MarginContainer/VBoxContainer/BossBOD"])
	_boss_spr_label = _find_label(["ContentRoot/TableArea/BossStatusPanel/MarginContainer/VBoxContainer/BossSPR"])
	_boss_rep_label = _find_label(["ContentRoot/TableArea/BossStatusPanel/MarginContainer/VBoxContainer/BossREP"])
	_bet_phase_hint = _find_label(["ContentRoot/TableArea/BetPhaseHint"])
	_bet_result_hint = _find_label(["ContentRoot/TableArea/BetResultHint"])
	_turn_result_popup = _find_control(["ContentRoot/TableArea/TurnResultPopup"])
	_feedback_label = _find_label(["ContentRoot/TableArea/TurnResultPopup/FeedbackLabel"])
	_end_turn_button = _find_button(["ContentRoot/TableArea/EndTurn"])
	_screen_effects = _host.get_node_or_null("ScreenEffects") as Control

	_assert_required(_background, "Main.tscn is missing Background.")
	_assert_required(_content_root, "Main.tscn is missing ContentRoot.")
	_assert_required(_table_area, "Main.tscn is missing TableArea.")
	_assert_required(_boss_area, "Main.tscn is missing BossArea.")
	_assert_required(_boss_portrait, "Main.tscn is missing BossPortrait.")
	_assert_required(_table_board, "Main.tscn is missing TableBoard.")
	_assert_required(_center_info, "Main.tscn is missing CenterInfo.")
	_assert_required(_round_label, "Main.tscn is missing RoundLabel.")
	_assert_required(_turn_label, "Main.tscn is missing TurnLabel.")
	_assert_required(_player_hp_label, "Main.tscn is missing PlayerHP.")
	_assert_required(_boss_hp_label, "Main.tscn is missing BossHP.")
	_assert_required(_player_area, "Main.tscn is missing PlayerArea.")
	_assert_required(_hand_anchor, "Main.tscn is missing a player battle card row.")
	_assert_required(_player_bet_area, "Main.tscn is missing a player bet panel.")
	_assert_required(_player_bet_row, "Main.tscn is missing a player bet row.")
	_assert_required(_player_optional_summary_button, "Main.tscn is missing OptionalSummaryButton.")
	_assert_required(_boss_battle_deck_root, "Main.tscn is missing a boss battle deck panel.")
	_assert_required(_battle_deck_title, "Main.tscn is missing BossModeTitleLabel/BattleDeckTitle.")
	_assert_required(_reveal_battle_deck_button, "Main.tscn is missing a boss reveal trigger.")
	_assert_required(_battle_deck_row, "Main.tscn is missing a boss battle deck row.")
	_assert_required(_boss_bet_area, "Main.tscn is missing a boss bet panel.")
	_assert_required(_boss_bet_row, "Main.tscn is missing a boss bet row.")
	_assert_required(_boss_battle_tab_button, "Main.tscn is missing BossBattleTabButton.")
	_assert_required(_boss_bet_tab_button, "Main.tscn is missing BossBetTabButton.")
	_assert_required(_boss_summary_toggle_button, "Main.tscn is missing BossSummaryToggleButton.")
	_assert_required(_clash_root, "Main.tscn is missing ClashArea.")
	_assert_required(_player_card_slot, "Main.tscn is missing PlayerCardSlot.")
	_assert_required(_boss_card_slot, "Main.tscn is missing BossCardSlot.")
	_assert_required(_clash_result_label, "Main.tscn is missing ClashResultLabel.")
	assert(_player_bod_label != null and _player_spr_label != null and _player_rep_label != null, "Main.tscn is missing PlayerStatusPanel labels.")
	assert(_boss_bod_label != null and _boss_spr_label != null and _boss_rep_label != null, "Main.tscn is missing BossStatusPanel labels.")
	_assert_required(_bet_phase_hint, "Main.tscn is missing BetPhaseHint.")
	_assert_required(_bet_result_hint, "Main.tscn is missing BetResultHint.")
	_assert_required(_turn_result_popup, "Main.tscn is missing TurnResultPopup.")
	_assert_required(_feedback_label, "Main.tscn is missing TurnResultPopup/FeedbackLabel.")
	_assert_required(_end_turn_button, "Main.tscn is missing EndTurn.")

func _set_mouse_filter(control: Control, filter_value: int) -> void:
	if control != null:
		control.mouse_filter = filter_value

func _normalize_view_mode(mode: String) -> String:
	if mode == VIEW_MODE_BET:
		return VIEW_MODE_BET
	return VIEW_MODE_BATTLE

func _set_player_view_mode(mode: String) -> void:
	_player_view_mode = _normalize_view_mode(mode)

func _set_boss_view_mode(mode: String) -> void:
	_boss_view_mode = _normalize_view_mode(mode)

func _toggle_player_summary() -> void:
	_player_summary_visible = not _player_summary_visible
	_refresh_ui()

func _toggle_boss_summary() -> void:
	_boss_summary_visible = not _boss_summary_visible
	_refresh_ui()

func _ensure_summary_labels() -> void:
	if _player_summary_panel == null and _player_card_viewport != null:
		_player_summary_panel = _create_summary_panel("RuntimePlayerSummaryPanel", "RuntimePlayerSummaryLabel")
		_player_card_viewport.add_child(_player_summary_panel)
		_player_summary_label = _player_summary_panel.get_node("MarginContainer/RuntimePlayerSummaryLabel") as Label
	elif _player_summary_panel != null and _player_summary_label == null:
		_player_summary_label = _player_summary_panel.get_node_or_null("MarginContainer/RuntimePlayerSummaryLabel") as Label
	if _boss_summary_panel == null and _boss_card_viewport != null:
		_boss_summary_panel = _create_summary_panel("RuntimeBossSummaryPanel", "RuntimeBossSummaryLabel")
		_boss_card_viewport.add_child(_boss_summary_panel)
		_boss_summary_label = _boss_summary_panel.get_node("MarginContainer/RuntimeBossSummaryLabel") as Label
	elif _boss_summary_panel != null and _boss_summary_label == null:
		_boss_summary_label = _boss_summary_panel.get_node_or_null("MarginContainer/RuntimeBossSummaryLabel") as Label
	_ensure_boss_archetype_label()
	_ensure_tooltip_panel()

func _create_summary_panel(panel_name: String, label_name: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = panel_name
	panel.layout_mode = 1
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 0.0
	panel.offset_left = 10.0
	panel.offset_top = 10.0
	panel.offset_right = -10.0
	panel.offset_bottom = 96.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = false
	panel.z_index = 5

	var margin := MarginContainer.new()
	margin.name = "MarginContainer"
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.offset_left = 10.0
	margin.offset_top = 8.0
	margin.offset_right = -10.0
	margin.offset_bottom = -8.0
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margin)

	var label := Label.new()
	label.name = label_name
	label.anchor_right = 1.0
	label.anchor_bottom = 1.0
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.95, 0.96, 0.97, 0.98))
	margin.add_child(label)

	return panel

func _ensure_boss_archetype_label() -> void:
	if _boss_archetype_label != null or _boss_mode_bar == null:
		return
	_boss_archetype_label = Label.new()
	_boss_archetype_label.name = "RuntimeBossArchetypeLabel"
	_boss_archetype_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_archetype_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_boss_archetype_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_boss_archetype_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_boss_archetype_label.add_theme_color_override("font_color", Color(0.88, 0.89, 0.92, 0.95))
	_boss_mode_bar.add_child(_boss_archetype_label)

func _ensure_tooltip_panel() -> void:
	if _tooltip_panel != null:
		return
	if TOOLTIP_PANEL_SCENE == null:
		return
	_tooltip_panel = TOOLTIP_PANEL_SCENE.instantiate() as Control
	if _tooltip_panel == null:
		return
	_tooltip_panel.name = "RuntimeTooltipPanel"
	_host.add_child(_tooltip_panel)

func _refresh_summary_texts() -> void:
	_ensure_summary_labels()
	if _player_optional_summary_button != null:
		_player_optional_summary_button.text = "Cards" if _player_summary_visible else "Summary"
	if _boss_summary_toggle_button != null:
		_boss_summary_toggle_button.text = "Cards" if _boss_summary_visible else "Summary"
	if _boss_battle_tab_button != null:
		_boss_battle_tab_button.text = "Battle"
	if _boss_bet_tab_button != null:
		_boss_bet_tab_button.text = "Bet"
	if _player_summary_label != null:
		_player_summary_label.text = _build_player_summary_text()
	if _boss_summary_label != null:
		_boss_summary_label.text = _build_boss_summary_text()
	if _boss_archetype_label != null:
		_boss_archetype_label.text = "%s Boss" % MvpBattleCard.archetype_display_name(_current_boss_archetype)

func _build_player_summary_text() -> String:
	if _player_view_mode == VIEW_MODE_BET and bet_mode_enabled:
		var timing := _current_player_bet_timing()
		var selected_bet: MvpBetCard = _selected_player_bet_for_timing(timing)
		var lines := PackedStringArray([
			"Player Bet Summary",
			"Phase: %s" % _phase_text(),
			"Selected: %s" % (selected_bet.name if selected_bet != null else "None"),
		])
		return "\n".join(lines)

	var counts: Dictionary = _build_remaining_type_counts(_player_state)
	return "\n".join(PackedStringArray([
		"Player Battle Summary",
		"Aggression x%d" % int(counts.get(MvpBattleCard.TYPE_AGGRESSION, 0)),
		"Defense x%d" % int(counts.get(MvpBattleCard.TYPE_DEFENSE, 0)),
		"Pressure x%d" % int(counts.get(MvpBattleCard.TYPE_PRESSURE, 0)),
	]))

func _build_boss_summary_text() -> String:
	if _boss_view_mode == VIEW_MODE_BET and bet_mode_enabled:
		return "Boss Bet Summary\nDetailed reveal not connected in this build."

	var counts: Dictionary = _build_remaining_type_counts(_boss_state)
	return "\n".join(PackedStringArray([
		"Boss Battle Summary",
		"Aggression remaining: %d" % int(counts.get(MvpBattleCard.TYPE_AGGRESSION, 0)),
		"Defense remaining: %d" % int(counts.get(MvpBattleCard.TYPE_DEFENSE, 0)),
		"Pressure remaining: %d" % int(counts.get(MvpBattleCard.TYPE_PRESSURE, 0)),
	]))

func _build_remaining_type_counts(actor_state: MvpCombatActorState) -> Dictionary:
	var counts := {
		MvpBattleCard.TYPE_AGGRESSION: 0,
		MvpBattleCard.TYPE_DEFENSE: 0,
		MvpBattleCard.TYPE_PRESSURE: 0,
	}
	if actor_state == null:
		return counts
	for slot_index in range(actor_state.cards.size()):
		if actor_state.used_slots.has(slot_index):
			continue
		var card: MvpBattleCard = actor_state.get_card_at(slot_index)
		if card != null:
			counts[card.type] = int(counts.get(card.type, 0)) + 1
	return counts

func _build_used_remaining_text(actor_state: MvpCombatActorState) -> String:
	if actor_state == null:
		return "Used: 0 / Remaining: 0"
	var used_count: int = actor_state.used_slots.size()
	var remaining_count: int = max(actor_state.cards.size() - used_count, 0)
	return "Used: %d / Remaining: %d" % [used_count, remaining_count]

func _refresh_viewport_modes() -> void:
	var player_battle_visible := true
	var player_bet_visible := false
	if bet_mode_enabled:
		player_battle_visible = _player_view_mode == VIEW_MODE_BATTLE
		player_bet_visible = _player_view_mode == VIEW_MODE_BET
	if _player_battle_panel != null:
		_player_battle_panel.visible = player_battle_visible
	if _player_bet_area != null:
		_player_bet_area.visible = bet_mode_enabled and player_bet_visible
	if _player_summary_panel != null:
		_player_summary_panel.visible = _player_summary_visible
	if _player_mode_bar != null:
		_player_mode_bar.visible = bet_mode_enabled
	if _player_mode_title_label != null:
		_player_mode_title_label.text = "Battle Cards" if player_battle_visible else "Bet Cards"

	var boss_battle_visible := true
	var boss_bet_visible := false
	if bet_mode_enabled:
		boss_battle_visible = _boss_view_mode == VIEW_MODE_BATTLE
		boss_bet_visible = _boss_view_mode == VIEW_MODE_BET
	if _boss_battle_panel != null:
		_boss_battle_panel.visible = boss_battle_visible
	if _boss_bet_area != null:
		_boss_bet_area.visible = bet_mode_enabled and boss_bet_visible
	if _boss_summary_panel != null:
		_boss_summary_panel.visible = _boss_summary_visible
	if _boss_mode_bar != null:
		_boss_mode_bar.visible = true
	if _battle_deck_title != null:
		_battle_deck_title.text = "Boss Battle Deck" if boss_battle_visible else "Boss Bet"
	if _boss_reveal_status_label != null:
		_boss_reveal_status_label.text = "Revealed" if _boss_battle_revealed else "Hidden"

func _configure_mouse_filters() -> void:
	_set_mouse_filter(_background, Control.MOUSE_FILTER_IGNORE)
	_set_mouse_filter(_table_board, Control.MOUSE_FILTER_IGNORE)
	_set_mouse_filter(_center_info, Control.MOUSE_FILTER_IGNORE)
	_set_mouse_filter(_round_label, Control.MOUSE_FILTER_IGNORE)
	_set_mouse_filter(_turn_label, Control.MOUSE_FILTER_IGNORE)
	_set_mouse_filter(_overlay_ui, Control.MOUSE_FILTER_IGNORE)
	_set_mouse_filter(_boss_battle_deck_root, Control.MOUSE_FILTER_IGNORE)
	_set_mouse_filter(_boss_deck_root, Control.MOUSE_FILTER_IGNORE)
	_set_mouse_filter(_boss_hand_count_label, Control.MOUSE_FILTER_IGNORE)
	_set_mouse_filter(_boss_hand_animation_anchor, Control.MOUSE_FILTER_IGNORE)
	_set_mouse_filter(_deck_row, Control.MOUSE_FILTER_IGNORE)
	_set_mouse_filter(_battle_deck_title, Control.MOUSE_FILTER_IGNORE)
	_set_mouse_filter(_battle_deck_row, Control.MOUSE_FILTER_IGNORE)
	_set_mouse_filter(_player_optional_summary_button, Control.MOUSE_FILTER_STOP)
	_set_mouse_filter(_boss_battle_tab_button, Control.MOUSE_FILTER_STOP)
	_set_mouse_filter(_boss_bet_tab_button, Control.MOUSE_FILTER_STOP)
	_set_mouse_filter(_boss_summary_toggle_button, Control.MOUSE_FILTER_STOP)
	_set_mouse_filter(_reveal_battle_deck_button, Control.MOUSE_FILTER_STOP)
	_set_mouse_filter(_peek_boss_bet_button, Control.MOUSE_FILTER_STOP)
	_set_mouse_filter(_end_turn_button, Control.MOUSE_FILTER_STOP)
	_set_mouse_filter(_bet_phase_hint, Control.MOUSE_FILTER_IGNORE)
	_set_mouse_filter(_bet_result_hint, Control.MOUSE_FILTER_IGNORE)
	_set_mouse_filter(_turn_result_popup, Control.MOUSE_FILTER_IGNORE)
	_set_mouse_filter(_feedback_label, Control.MOUSE_FILTER_IGNORE)

func _setup_views() -> void:
	_player_hand_view = MvpPlayerHandView.new(_hand_anchor, CARD_VIEW_SCENE)
	_player_hand_view.card_play_requested.connect(_on_card_play_requested)

	if _boss_deck_root != null and _boss_hand_count_label != null and _deck_row != null:
		_boss_deck_view = MvpBossDeckView.new(
			_boss_deck_root,
			_boss_hand_count_label,
			_boss_hand_animation_anchor,
			_deck_row,
			CARD_VIEW_SCENE
		)
	else:
		_boss_deck_view = null

	_boss_battle_deck_view = BOSS_BATTLE_DECK_VIEW_SCRIPT.new(
		_boss_battle_deck_root,
		_reveal_battle_deck_button,
		_battle_deck_row,
		CARD_VIEW_SCENE
	)
	if not _boss_battle_deck_view.reveal_requested.is_connected(_on_reveal_requested):
		_boss_battle_deck_view.reveal_requested.connect(_on_reveal_requested)

	_clash_area_view = MvpClashAreaView.new(
		_clash_root,
		_player_card_slot,
		_boss_card_slot,
		_clash_result_label,
		CARD_VIEW_SCENE
	)

	_player_bet_view = BET_ROW_VIEW_SCRIPT.new(_player_bet_row)
	if not _player_bet_view.bet_selected.is_connected(_on_player_bet_selected):
		_player_bet_view.bet_selected.connect(_on_player_bet_selected)
	_boss_bet_view = BET_ROW_VIEW_SCRIPT.new(_boss_bet_row)
	_ensure_summary_labels()
	if _player_battle_tab_button != null and not _player_battle_tab_button.pressed.is_connected(_on_player_battle_tab_pressed):
		_player_battle_tab_button.pressed.connect(_on_player_battle_tab_pressed)
	if _player_bet_tab_button != null and not _player_bet_tab_button.pressed.is_connected(_on_player_bet_tab_pressed):
		_player_bet_tab_button.pressed.connect(_on_player_bet_tab_pressed)
	if _player_optional_summary_button != null and not _player_optional_summary_button.pressed.is_connected(_toggle_player_summary):
		_player_optional_summary_button.pressed.connect(_toggle_player_summary)
	if _boss_battle_tab_button != null and not _boss_battle_tab_button.pressed.is_connected(_on_boss_battle_tab_pressed):
		_boss_battle_tab_button.pressed.connect(_on_boss_battle_tab_pressed)
	if _boss_bet_tab_button != null and not _boss_bet_tab_button.pressed.is_connected(_on_boss_bet_tab_pressed):
		_boss_bet_tab_button.pressed.connect(_on_boss_bet_tab_pressed)
	if _boss_summary_toggle_button != null and not _boss_summary_toggle_button.pressed.is_connected(_toggle_boss_summary):
		_boss_summary_toggle_button.pressed.connect(_toggle_boss_summary)
	if _peek_boss_bet_button != null and not _peek_boss_bet_button.pressed.is_connected(_on_peek_boss_bet_pressed):
		_peek_boss_bet_button.pressed.connect(_on_peek_boss_bet_pressed)
	if _boss_battle_tab_button != null:
		_boss_battle_tab_button.text = "Battle"
	if _boss_bet_tab_button != null:
		_boss_bet_tab_button.text = "Bet"
	if _player_optional_summary_button != null:
		_player_optional_summary_button.text = "Summary"
	if _boss_summary_toggle_button != null:
		_boss_summary_toggle_button.text = "Summary"
	_end_turn_button.text = "End Turn"
	_end_turn_button.hide()
	if not _end_turn_button.pressed.is_connected(_on_end_turn_pressed):
		_end_turn_button.pressed.connect(_on_end_turn_pressed)

func _ensure_overlay_log() -> void:
	if _overlay_ui == null:
		return
	_overlay_log_label = RichTextLabel.new()
	_overlay_log_label.name = "RuntimeLogLabel"
	_overlay_log_label.layout_mode = 1
	_overlay_log_label.anchor_left = 0.0
	_overlay_log_label.anchor_top = 0.0
	_overlay_log_label.anchor_right = 1.0
	_overlay_log_label.anchor_bottom = 1.0
	_overlay_log_label.offset_left = 0.0
	_overlay_log_label.offset_top = 0.0
	_overlay_log_label.offset_right = 0.0
	_overlay_log_label.offset_bottom = 0.0
	_overlay_log_label.bbcode_enabled = false
	_overlay_log_label.fit_content = false
	_overlay_log_label.scroll_active = false
	_overlay_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_overlay_log_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_log_label.add_theme_color_override("default_color", Color(0.95, 0.96, 0.97, 0.96))
	_overlay_ui.add_child(_overlay_log_label)
	_refresh_overlay_log()

func _refresh_overlay_log() -> void:
	if _overlay_log_label == null:
		return
	_overlay_log_label.text = "\n".join(_logs)

func _hide_turn_result_popup(invalidate_pending: bool = false) -> void:
	if invalidate_pending:
		_round_feedback_version += 1
		_round_feedback_active = false
		_pending_round_followup = ROUND_FOLLOWUP_NONE
		_pending_round_followup_result.clear()
	if is_instance_valid(_feedback_label):
		_feedback_label.text = ""
	if is_instance_valid(_turn_result_popup):
		_turn_result_popup.hide()

func show_turn_result_popup(payload: Dictionary) -> void:
	if not is_instance_valid(_turn_result_popup) or not is_instance_valid(_feedback_label):
		return
	var lines := PackedStringArray()
	for key in ["headline_text", "player_card_text", "boss_card_text", "explanation_text", "power_text", "remaining_text"]:
		var line := str(payload.get(key, "")).strip_edges()
		if not line.is_empty():
			lines.append(line)
	_feedback_label.text = "\n".join(lines)
	_turn_result_popup.show()

func _build_round_feedback_payload(result: Dictionary) -> Dictionary:
	if _boss_state == null or result.is_empty():
		return {}

	var player_card: Dictionary = result.get("player_card", {})
	var boss_card: Dictionary = result.get("boss_card", {})
	var player_type := str(player_card.get("type", ""))
	var boss_type := str(boss_card.get("type", ""))
	var player_name := str(player_card.get("display_name", MvpBattleCard.display_name_for_type(player_type)))
	var boss_name := str(boss_card.get("display_name", MvpBattleCard.display_name_for_type(boss_type)))
	var player_total := int(result.get("player_total", 0))
	var boss_total := int(result.get("boss_total", 0))
	var winner := str(result.get("winner", "tie"))
	var headline_text := "DRAW"
	match winner:
		"player":
			headline_text = "YOU WIN"
		"boss":
			headline_text = "YOU LOSE"
		_:
			headline_text = "DRAW"

	var remaining_count := 0
	for slot_index in range(_boss_state.cards.size()):
		if _boss_state.used_slots.has(slot_index):
			continue
		var remaining_card: MvpBattleCard = _boss_state.get_card_at(slot_index)
		if remaining_card != null and remaining_card.type == boss_type:
			remaining_count += 1

	return {
		"headline_text": headline_text,
		"player_card_text": "You played %s" % player_name,
		"boss_card_text": "Boss played %s" % boss_name,
		"explanation_text": _build_round_explanation(player_type, boss_type, winner, player_total, boss_total),
		"power_text": "Power: You %d vs Boss %d" % [player_total, boss_total],
		"remaining_text": "%s remaining: %d" % [boss_name, remaining_count],
	}

func _build_round_explanation(player_type: String, boss_type: String, winner: String, _player_total: int, _boss_total: int) -> String:
	var player_name := MvpBattleCard.display_name_for_type(player_type)
	var boss_name := MvpBattleCard.display_name_for_type(boss_type)
	if winner == "tie":
		if player_type == boss_type:
			return "Both played %s" % player_name
		return "Your %s and Boss %s trade evenly" % [player_name, boss_name]
	if winner == "player":
		if player_type == MvpBattleCard.TYPE_DEFENSE and boss_type == MvpBattleCard.TYPE_AGGRESSION:
			return "Your Defense blocks Aggression"
		return "Your %s beats %s" % [player_name, boss_name]
	if boss_type == MvpBattleCard.TYPE_DEFENSE and player_type == MvpBattleCard.TYPE_AGGRESSION:
		return "Boss Defense blocks your Aggression"
	return "Boss %s beats your %s" % [boss_name, player_name]

func _present_round_feedback(result: Dictionary, followup: String) -> void:
	if result.is_empty():
		_complete_round_feedback(result, followup)
		return
	_round_feedback_version += 1
	var feedback_version := _round_feedback_version
	_round_feedback_active = true
	_pending_round_followup = followup
	_pending_round_followup_result = result.duplicate(true)
	var payload := _build_round_feedback_payload(result)
	show_turn_result_popup(payload)
	if _clash_area_view != null:
		_clash_area_view.set_result_text(str(payload.get("headline_text", "")))
	_refresh_ui()
	var tree := _host.get_tree()
	if tree == null:
		_complete_round_feedback(result, followup)
		return
	await tree.create_timer(TURN_RESULT_DISPLAY_DURATION).timeout
	if feedback_version != _round_feedback_version:
		return
	_complete_round_feedback(result, followup)

func _complete_round_feedback(result: Dictionary, followup: String) -> void:
	_round_feedback_active = false
	_pending_round_followup = ROUND_FOLLOWUP_NONE
	_pending_round_followup_result.clear()
	_hide_turn_result_popup()
	if _clash_area_view != null:
		_clash_area_view.set_result_text(str(result.get("summary_text", "")))
	match followup:
		ROUND_FOLLOWUP_OPEN_POST_BET:
			_open_post_bet_window(result)
		ROUND_FOLLOWUP_FINALIZE_TURN:
			_finalize_current_turn()
		_:
			_refresh_ui()

func _start_new_challenge() -> void:
	_hide_turn_result_popup(true)
	_logs.clear()
	_player_set_wins = 0
	_boss_set_wins = 0
	_current_set_index = 1
	_current_turn_index = 1
	_boss_battle_revealed = false
	_boss_bet_revealed = false
	_current_boss_template_id = MvpBattleCard.DEFAULT_BOSS_TEMPLATE_ID
	_challenge_over = false
	_input_locked = false
	_bet_result_text = ""
	_boss_bet_peek_snapshot_text = ""
	_boss_template_rng.randomize()
	_boss_bet_rng.randomize()

	_player_state = MvpCombatActorState.new("Player", MvpBattleCard.build_player_test_deck())
	_boss_state = MvpCombatActorState.new("Boss", MvpBattleCard.build_boss_test_deck())
	_player_state.set_long_term_values(STARTING_BOD, STARTING_SPR, STARTING_REP)
	_boss_state.set_long_term_values(STARTING_BOD, STARTING_SPR, STARTING_REP)
	_reset_for_current_set()

	push_log("Challenge started. First to 2 set wins takes the match.")
	push_log("Set %d begins." % _current_set_index)
	push_log("Turn %d begins." % _current_turn_index)
	_refresh_ui()

func _reset_for_current_set() -> void:
	_hide_turn_result_popup(true)
	_player_state.set_deck_blueprint(MvpBattleCard.build_player_test_deck())
	var boss_template: Dictionary = MvpBattleCard.pick_random_boss_template(_boss_template_rng)
	_current_boss_template_id = str(boss_template.get("id", MvpBattleCard.DEFAULT_BOSS_TEMPLATE_ID))
	_current_boss_archetype = MvpBattleCard.archetype_for_template(_current_boss_template_id)
	_boss_ai.set_archetype(_current_boss_archetype)
	_boss_state.set_deck_blueprint(boss_template.get("cards", []))
	_player_state.reset_for_new_set(SET_HP)
	_boss_state.reset_for_new_set(SET_HP)
	_boss_battle_revealed = false
	_boss_bet_revealed = false
	_current_turn_index = 1
	_input_locked = false
	_bet_result_text = ""
	_boss_bet_peek_snapshot_text = ""
	_reset_turn_bet_state(true)
	_clash_area_view.clear_clash()

func _reset_turn_bet_state(clear_result: bool = false) -> void:
	_player_pre_bet = null
	_player_post_bet = null
	_boss_post_bet = null
	_pending_player_slot = -1
	_pending_boss_slot = -1
	_post_bet_window_open = false
	_post_bet_effects_applied = false
	_current_round_result.clear()
	_pending_round_followup = ROUND_FOLLOWUP_NONE
	_pending_round_followup_result.clear()
	_input_locked = false
	_boss_bet_peek_snapshot_text = ""
	if clear_result:
		_bet_result_text = ""
	_bet_phase = BET_CARD_SCRIPT.TIMING_PRE if bet_mode_enabled and not _challenge_over else BET_PHASE_CLOSED
	_set_player_view_mode(VIEW_MODE_BET if bet_mode_enabled and not _challenge_over else VIEW_MODE_BATTLE)
	_set_boss_view_mode(VIEW_MODE_BATTLE)
	if is_instance_valid(_end_turn_button):
		_end_turn_button.hide()

func _refresh_ui() -> void:
	_round_label.text = "Round %d / %d" % [_current_set_index, MAX_SETS]
	_turn_label.text = "Turn %d / %d" % [_current_turn_index, MAX_TURNS]
	_center_info.visible = not _round_feedback_active
	_player_hp_label.text = "Player HP %d" % _player_state.hp
	_boss_hp_label.text = "Boss HP %d" % _boss_state.hp
	_player_bod_label.text = "BOD %d" % _player_state.bod
	_player_spr_label.text = "SPR %d" % _player_state.spr
	_player_rep_label.text = "REP %d" % _player_state.rep
	_boss_bod_label.text = "BOD %d" % _boss_state.bod
	_boss_spr_label.text = "SPR %d" % _boss_state.spr
	_boss_rep_label.text = "REP %d" % _boss_state.rep
	_battle_deck_title.text = "Boss Battle Deck"

	_player_hand_view.set_hand(
		_player_state.cards,
		_player_state.used_slots,
		not _challenge_over and not _input_locked and not _post_bet_window_open
	)
	if _boss_deck_view != null:
		_boss_deck_view.set_hand(_boss_state.cards, _boss_state.used_slots)
	_boss_battle_deck_view.set_deck(_boss_state.cards, _boss_battle_revealed, _boss_state.used_slots)
	_boss_battle_deck_view.set_reveal_enabled(not _challenge_over)
	_refresh_bet_ui()
	_refresh_summary_texts()
	_refresh_viewport_modes()
	_sync_reveal_battle_deck_layout()
	_refresh_overlay_log()

func _refresh_bet_ui() -> void:
	_bet_phase_hint.visible = bet_mode_enabled and not _round_feedback_active
	if _peek_boss_bet_button != null:
		_peek_boss_bet_button.visible = bet_mode_enabled and boss_bet_peek_enabled
	var end_turn_visible := bet_mode_enabled and _post_bet_window_open and not _challenge_over and not _round_feedback_active
	_end_turn_button.visible = end_turn_visible
	_end_turn_button.disabled = not end_turn_visible
	if not bet_mode_enabled:
		_bet_phase_hint.text = ""
		_bet_result_hint.text = ""
		_bet_result_hint.visible = false
		_player_bet_view.clear()
		_boss_bet_view.clear()
		return

	_bet_phase_hint.text = _phase_text()
	var bet_result_display: String = _bet_result_text if not _bet_result_text.is_empty() else _boss_bet_peek_snapshot_text
	_bet_result_hint.text = bet_result_display
	_bet_result_hint.visible = not _round_feedback_active and not bet_result_display.is_empty()
	_player_bet_view.set_entries(_build_player_bet_entries(), _is_player_bet_interactive())
	_boss_bet_view.set_entries(_build_boss_bet_entries(), false)

func _on_player_battle_tab_pressed() -> void:
	_set_player_view_mode(VIEW_MODE_BATTLE)
	_refresh_ui()

func _on_player_bet_tab_pressed() -> void:
	if not bet_mode_enabled:
		return
	_set_player_view_mode(VIEW_MODE_BET)
	_refresh_ui()

func _on_boss_battle_tab_pressed() -> void:
	_set_boss_view_mode(VIEW_MODE_BATTLE)
	_refresh_ui()

func _on_boss_bet_tab_pressed() -> void:
	if not bet_mode_enabled:
		return
	_set_boss_view_mode(VIEW_MODE_BET)
	_refresh_ui()

func _build_player_bet_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var timing: String = _current_player_bet_timing()
	var selected_bet = _selected_player_bet_for_timing(timing)
	for bet_card in _bet_cards:
		var cost: int = BET_CARD_SCRIPT.cost_for_timing(bet_card, timing)
		var selected: bool = selected_bet != null and selected_bet.id == bet_card.id
		var label: String = "%s (%d SPR)" % [bet_card.name, cost]
		if selected:
			label = "[Selected] %s" % label
		var disabled: bool = true
		if not selected and _is_player_bet_interactive() and _can_actor_use_bet(_player_state, bet_card, timing):
			disabled = false
		entries.append({
			"id": bet_card.id,
			"label": label,
			"disabled": disabled,
			"tooltip_title": bet_card.name,
			"tooltip_body": bet_card.tooltip_body_for_timing(timing),
		})
	return entries

func _build_boss_bet_entries() -> Array[Dictionary]:
	if _boss_post_bet == null or not _post_bet_window_open:
		return []
	return [{
		"id": _boss_post_bet.id,
		"label": "Boss Bet Locked",
		"disabled": true,
	}]

func _selected_player_bet_for_timing(timing: String) -> MvpBetCard:
	if timing == BET_CARD_SCRIPT.TIMING_POST:
		return _player_post_bet
	return _player_pre_bet

func _current_player_bet_timing() -> String:
	if _bet_phase == BET_CARD_SCRIPT.TIMING_POST:
		return BET_CARD_SCRIPT.TIMING_POST
	return BET_CARD_SCRIPT.TIMING_PRE

func _phase_text() -> String:
	match _bet_phase:
		BET_CARD_SCRIPT.TIMING_PRE:
			return "Pre-Bet Phase"
		BET_CARD_SCRIPT.TIMING_POST:
			return "Post-Bet Phase"
		_:
			return "Bet Closed"

func _is_player_bet_interactive() -> bool:
	if not bet_mode_enabled or _challenge_over or _round_feedback_active:
		return false
	if _bet_phase == BET_CARD_SCRIPT.TIMING_PRE:
		return not _input_locked and not _post_bet_window_open and _player_pre_bet == null
	if _bet_phase == BET_CARD_SCRIPT.TIMING_POST:
		return _post_bet_window_open and not _post_bet_effects_applied and _player_post_bet == null
	return false

func _can_actor_use_bet(actor_state: MvpCombatActorState, bet_card, timing: String) -> bool:
	if actor_state == null or bet_card == null:
		return false
	if not bet_card.is_available_in_timing(timing):
		return false
	var cost: int = BET_CARD_SCRIPT.cost_for_timing(bet_card, timing)
	return actor_state.spr >= cost

func _sync_reveal_battle_deck_layout() -> void:
	if _boss_battle_deck_view != null and _boss_battle_deck_view.has_method("update_layout"):
		_boss_battle_deck_view.update_layout()

func reveal_boss_battle_deck() -> void:
	if _challenge_over or _boss_battle_revealed:
		return
	_boss_battle_revealed = true
	push_log("Boss battle deck revealed for the current set.")
	_refresh_ui()

func reveal_boss_bet_deck() -> void:
	_boss_bet_revealed = true
	refresh_boss_bet_deck()

func refresh_boss_bet_deck() -> void:
	_refresh_summary_texts()
	_refresh_viewport_modes()

func _on_reveal_requested() -> void:
	reveal_boss_battle_deck()

func _on_peek_boss_bet_pressed() -> void:
	if not bet_mode_enabled or not boss_bet_peek_enabled:
		return
	_set_boss_view_mode(VIEW_MODE_BET)
	_boss_bet_peek_snapshot_text = _build_boss_bet_snapshot_text()
	_refresh_ui()

func _build_boss_bet_snapshot_text() -> String:
	if _boss_post_bet == null:
		return "Boss: No Bet"
	return "Boss Bet: %s" % _boss_post_bet.name

func _on_player_bet_selected(bet_id: String) -> void:
	if not _is_player_bet_interactive():
		return
	var bet_card = BET_CARD_SCRIPT.from_id(bet_id)
	var timing: String = _current_player_bet_timing()
	if not _can_actor_use_bet(_player_state, bet_card, timing):
		return
	_consume_bet(_player_state, bet_card, timing, "Player")
	if timing == BET_CARD_SCRIPT.TIMING_PRE:
		_player_pre_bet = bet_card
		_bet_phase = BET_PHASE_CLOSED
		_set_player_view_mode(VIEW_MODE_BATTLE)
		_refresh_ui()
		return
	_player_post_bet = bet_card
	_set_player_view_mode(VIEW_MODE_BET)
	_apply_post_bet_effects_if_needed()
	_refresh_ui()

func _on_card_play_requested(slot_index: int) -> void:
	if _challenge_over or _input_locked or _post_bet_window_open or _player_state.is_slot_used(slot_index):
		return

	var player_card: MvpBattleCard = _player_state.get_card_at(slot_index)
	var boss_slot: int = _boss_ai.choose_slot(_boss_state, player_card)
	if player_card == null or boss_slot == -1:
		return

	if not bet_mode_enabled:
		_input_locked = true
		_player_hand_view.set_interactive(false)
		var no_bet_result: Dictionary = _resolver.resolve_round(_player_state, _boss_state, slot_index, boss_slot)
		_apply_round_result(no_bet_result)
		await _present_round_feedback(no_bet_result, ROUND_FOLLOWUP_FINALIZE_TURN)
		return

	_input_locked = true
	_player_hand_view.set_interactive(false)
	var result: Dictionary = _resolver.resolve_round(_player_state, _boss_state, slot_index, boss_slot)
	_bet_result_text = _apply_bet_modifiers(result, _player_pre_bet, null)
	_apply_round_result(result)
	var followup := ROUND_FOLLOWUP_OPEN_POST_BET
	if _is_round_terminal_state():
		followup = ROUND_FOLLOWUP_FINALIZE_TURN
	await _present_round_feedback(result, followup)

func _open_post_bet_window(result: Dictionary) -> void:
	_post_bet_window_open = true
	_post_bet_effects_applied = false
	_bet_phase = BET_CARD_SCRIPT.TIMING_POST
	_set_player_view_mode(VIEW_MODE_BET)
	_set_boss_view_mode(VIEW_MODE_BET)
	_lock_boss_post_bet(result)
	push_log("Post-Bet phase opened.")
	_refresh_ui()

func _lock_boss_post_bet(result: Dictionary) -> void:
	if not bet_mode_enabled or _boss_post_bet != null:
		return
	var player_card: MvpBattleCard = MvpBattleCard.from_dict(result.get("player_card", {}))
	var boss_card: MvpBattleCard = MvpBattleCard.from_dict(result.get("boss_card", {}))
	var chosen_bet = _choose_boss_bet(player_card, boss_card)
	if chosen_bet == null:
		return
	var timing: String = BET_CARD_SCRIPT.TIMING_POST
	if not _can_actor_use_bet(_boss_state, chosen_bet, timing):
		return
	_consume_bet(_boss_state, chosen_bet, timing, "Boss")
	_boss_post_bet = chosen_bet

func _choose_boss_bet(player_card: MvpBattleCard, boss_card: MvpBattleCard):
	if player_card == null or boss_card == null:
		return null

	var matchup := "neutral"
	if MvpBattleCard.beats(boss_card.type, player_card.type):
		matchup = "advantage"
	elif MvpBattleCard.beats(player_card.type, boss_card.type):
		matchup = "disadvantage"

	var hold = BET_CARD_SCRIPT.from_id(BET_CARD_SCRIPT.HOLD_STEADY_ID)
	var positive = BET_CARD_SCRIPT.from_id(BET_CARD_SCRIPT.POSITIVE_SHIFT_ID)
	var dirty = BET_CARD_SCRIPT.from_id(BET_CARD_SCRIPT.DIRTY_MOVE_ID)
	var timing: String = BET_CARD_SCRIPT.TIMING_POST
	var roll: int = _boss_bet_rng.randi_range(1, 100)

	match matchup:
		"advantage":
			if roll <= 45 and _can_actor_use_bet(_boss_state, positive, timing):
				return positive
			if roll <= 60 and _can_actor_use_bet(_boss_state, dirty, timing):
				return dirty
			if roll <= 85:
				return null
			return hold
		"disadvantage":
			if roll <= 12 and _can_actor_use_bet(_boss_state, positive, timing):
				return positive
			if roll <= 18 and _can_actor_use_bet(_boss_state, dirty, timing):
				return dirty
			if roll <= 82:
				return null
			return hold
		_:
			if roll <= 25 and _can_actor_use_bet(_boss_state, positive, timing):
				return positive
			if roll <= 33 and _can_actor_use_bet(_boss_state, dirty, timing):
				return dirty
			if roll <= 78:
				return null
			return hold

func _consume_bet(actor_state: MvpCombatActorState, bet_card, timing: String, actor_label: String) -> void:
	var cost: int = BET_CARD_SCRIPT.cost_for_timing(bet_card, timing)
	if cost > 0:
		actor_state.modify_status("spr", -cost)
	push_log("%s bet -> %s (%d SPR)." % [actor_label, bet_card.name, cost])

func _apply_bet_modifiers(result: Dictionary, player_bet = null, boss_bet = null) -> String:
	var log_lines: Array[String] = []
	for line in result.get("log_lines", []):
		log_lines.append(str(line))

	var messages: Array[String] = []
	var winner: String = str(result.get("winner", "tie"))
	if player_bet != null:
		_apply_single_bet_modifier(player_bet, "player", winner, result, messages, log_lines)
	if boss_bet != null:
		_apply_single_bet_modifier(boss_bet, "boss", winner, result, messages, log_lines)
	result["log_lines"] = log_lines
	return " | ".join(messages)

func _apply_single_bet_modifier(bet_card, owner: String, winner: String, result: Dictionary, messages: Array[String], log_lines: Array[String]) -> void:
	var owner_label: String = "Player" if owner == "player" else "Boss"
	match String(bet_card.id):
		BET_CARD_SCRIPT.HOLD_STEADY_ID:
			return
		BET_CARD_SCRIPT.POSITIVE_SHIFT_ID:
			if winner == owner:
				if owner == "player":
					result["boss_damage"] = int(result.get("boss_damage", 0)) + 1
				else:
					result["player_damage"] = int(result.get("player_damage", 0)) + 1
				var positive_text := "+1 Damage (Positive)"
				if owner == "boss":
					positive_text = "Boss %s" % positive_text
				messages.append(positive_text)
				log_lines.append("%s used Positive Shift for +1 damage." % owner_label)
		BET_CARD_SCRIPT.DIRTY_MOVE_ID:
			if winner == owner:
				if owner == "player":
					result["boss_damage"] = int(result.get("boss_damage", 0)) + 2
				else:
					result["player_damage"] = int(result.get("player_damage", 0)) + 2
				var dirty_text := "+2 Damage (Dirty)"
				if owner == "boss":
					dirty_text = "Boss %s" % dirty_text
				messages.append(dirty_text)
				log_lines.append("%s used Dirty Move for +2 damage." % owner_label)
			elif winner != "tie":
				if owner == "player":
					result["player_damage"] = int(result.get("player_damage", 0)) + 1
				else:
					result["boss_damage"] = int(result.get("boss_damage", 0)) + 1
				var backfire_text := "Backfired: -1 HP"
				if owner == "boss":
					backfire_text = "Boss %s" % backfire_text
				messages.append(backfire_text)
				log_lines.append("%s used Dirty Move and suffered 1 self damage." % owner_label)

func _apply_round_result(result: Dictionary) -> void:
	_current_round_result = result.duplicate(true)
	var player_slot: int = int(result.get("player_slot", -1))
	var boss_slot: int = int(result.get("boss_slot", -1))
	_player_state.mark_card_used(player_slot)
	_boss_state.mark_card_used(boss_slot)
	_player_state.modify_hp(-int(result.get("player_damage", 0)))
	_boss_state.modify_hp(-int(result.get("boss_damage", 0)))

	for line in result.get("log_lines", []):
		push_log(str(line))

	for change in result.get("status_changes", []):
		_apply_status_change(change)

	_clash_area_view.show_clash(
		result.get("player_card", {}),
		result.get("boss_card", {}),
		str(result.get("summary_text", ""))
	)
	_refresh_ui()

func _apply_post_bet_effects_if_needed() -> void:
	if not _post_bet_window_open or _post_bet_effects_applied or _current_round_result.is_empty():
		return

	var effect_result := {
		"winner": str(_current_round_result.get("winner", "tie")),
		"player_damage": 0,
		"boss_damage": 0,
		"log_lines": [],
	}
	var effect_text := _apply_bet_modifiers(effect_result, _player_post_bet, _boss_post_bet)
	_post_bet_effects_applied = true
	if not effect_text.is_empty():
		_bet_result_text = effect_text
	elif (_player_post_bet != null or _boss_post_bet != null) and _bet_result_text.is_empty():
		_bet_result_text = "No Bet"

	_player_state.modify_hp(-int(effect_result.get("player_damage", 0)))
	_boss_state.modify_hp(-int(effect_result.get("boss_damage", 0)))
	for line in effect_result.get("log_lines", []):
		push_log(str(line))
	_refresh_ui()

func _on_end_turn_pressed() -> void:
	if not _post_bet_window_open or _challenge_over:
		return
	_apply_post_bet_effects_if_needed()
	_finalize_current_turn()

func _finalize_current_turn() -> void:
	_post_bet_window_open = false
	_bet_phase = BET_PHASE_CLOSED
	push_log("Current HP -> Player %d / Boss %d." % [_player_state.hp, _boss_state.hp])
	push_log("Current score -> Player %d / Boss %d." % [_player_set_wins, _boss_set_wins])
	_print_round_debug(_current_round_result)

	if _player_state.is_collapsed():
		_finish_challenge("boss", "Player long-term state collapsed.")
		return
	if _boss_state.is_collapsed():
		_finish_challenge("player", "Boss long-term state collapsed.")
		return

	if _is_set_finished():
		_finish_set(_determine_set_winner())
		return

	_current_turn_index += 1
	_reset_turn_bet_state(false)
	push_log("Turn %d begins." % _current_turn_index)
	_refresh_ui()

func _is_round_terminal_state() -> bool:
	return _player_state.is_collapsed() or _boss_state.is_collapsed() or _is_set_finished()

func _apply_status_change(change: Dictionary) -> void:
	var target := str(change.get("target", ""))
	var stat_name := str(change.get("stat", ""))
	var amount := int(change.get("amount", 0))
	if amount == 0:
		return

	var target_state := _player_state if target == "player" else _boss_state
	target_state.modify_status(stat_name, amount)
	var target_label := "Player" if target == "player" else "Boss"
	push_log("%s %s %+d." % [target_label, stat_name.to_upper(), amount])

func _is_set_finished() -> bool:
	return (
		_player_state.hp <= 0
		or _boss_state.hp <= 0
		or _current_turn_index >= MAX_TURNS
		or _player_state.all_cards_used()
		or _boss_state.all_cards_used()
	)

func _determine_set_winner() -> String:
	if _boss_state.hp <= 0 and _player_state.hp > 0:
		return "player"
	if _player_state.hp <= 0 and _boss_state.hp > 0:
		return "boss"
	if _player_state.hp > _boss_state.hp:
		return "player"
	if _boss_state.hp > _player_state.hp:
		return "boss"
	if _player_state.rep > _boss_state.rep:
		return "player"
	if _boss_state.rep > _player_state.rep:
		return "boss"
	return "boss"

func _finish_set(set_winner: String) -> void:
	if set_winner == "player":
		_player_set_wins += 1
	else:
		_boss_set_wins += 1

	push_log("Set %d ended. %s won the set." % [_current_set_index, set_winner.capitalize()])
	print("[Battle] Set ended -> winner=%s score=%d:%d" % [set_winner, _player_set_wins, _boss_set_wins])

	if _player_set_wins >= WINS_TO_CLEAR or _boss_set_wins >= WINS_TO_CLEAR or _current_set_index >= MAX_SETS:
		var challenge_winner := "player" if _player_set_wins > _boss_set_wins else "boss"
		_finish_challenge(challenge_winner, "The challenge score reached its end condition.")
		return

	_current_set_index += 1
	_reset_for_current_set()
	push_log("Set %d begins." % _current_set_index)
	push_log("Turn %d begins." % _current_turn_index)
	_refresh_ui()

func _finish_challenge(challenge_winner: String, reason: String) -> void:
	_challenge_over = true
	_input_locked = false
	_bet_phase = BET_PHASE_CLOSED
	var result_text := "Player wins the challenge." if challenge_winner == "player" else "Boss wins the challenge."
	push_log("Challenge ended. %s" % result_text)
	push_log("Reason: %s" % reason)
	push_log("Final score -> Player %d / Boss %d." % [_player_set_wins, _boss_set_wins])
	print("[Battle] Challenge ended -> %s" % challenge_winner)
	_refresh_ui()

func _print_round_debug(result: Dictionary) -> void:
	var player_card: Dictionary = result.get("player_card", {})
	var boss_card: Dictionary = result.get("boss_card", {})
	print("[Battle] Player played -> %s" % player_card.get("display_name", ""))
	print("[Battle] Boss played   -> %s" % boss_card.get("display_name", ""))
	print("[Battle] HP            -> Player %d / Boss %d" % [_player_state.hp, _boss_state.hp])
	print("[Battle] Round/Turn    -> %d / %d" % [_current_set_index, _current_turn_index])

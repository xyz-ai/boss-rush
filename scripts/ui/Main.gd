extends RefCounted
class_name MvpMainController

const CARD_VIEW_SCENE := preload("res://scenes/ui/CardView.tscn")
const BOSS_BATTLE_DECK_VIEW_SCRIPT := preload("res://scripts/ui/BossBattleDeckView.gd")
const BET_ROW_VIEW_SCRIPT := preload("res://scripts/ui/BetRowView.gd")
const BET_CARD_SCRIPT := preload("res://scripts/game/BetCard.gd")

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
const TURN_RESULT_POPUP_DURATION := 2.2

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
var _boss_deck_root: Control
var _boss_hand_count_label: Label
var _boss_hand_animation_anchor: Control
var _deck_row: HBoxContainer
var _boss_battle_deck_root: Control
var _battle_deck_title: Label
var _reveal_battle_deck_button: Button
var _battle_deck_row: HBoxContainer
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
var _current_boss_template_id: String = MvpBattleCard.DEFAULT_BOSS_TEMPLATE_ID
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
var _player_pre_bet = null
var _player_post_bet = null
var _boss_post_bet = null
var _pending_player_slot: int = -1
var _pending_boss_slot: int = -1
var _post_bet_window_open: bool = false
var _post_bet_effects_applied: bool = false
var _current_round_result: Dictionary = {}
var _bet_result_text: String = ""
var _boss_bet_peek_snapshot_text: String = ""
var _turn_result_popup_version: int = 0

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
		"challenge_over": _challenge_over,
		"bet_mode_enabled": bet_mode_enabled,
		"bet_phase": _bet_phase,
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

func _current_snapshot_player_bet():
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

func _bind_nodes() -> void:
	_background = _host.get_node("Background") as TextureRect
	_content_root = _host.get_node("ContentRoot") as Control
	_boss_area = _host.get_node("ContentRoot/BossArea") as Control
	_boss_portrait = _host.get_node("ContentRoot/BossArea/BossPortrait") as TextureRect
	_table_area = _host.get_node("ContentRoot/TableArea") as Control
	_table_board = _host.get_node("ContentRoot/TableArea/TableBoard") as TextureRect
	_center_info = _host.get_node("ContentRoot/TableArea/CenterInfo") as Control
	_round_label = _host.get_node("ContentRoot/TableArea/CenterInfo/RoundLabel") as Label
	_turn_label = _host.get_node("ContentRoot/TableArea/CenterInfo/TurnLabel") as Label
	_player_hp_label = _host.get_node("ContentRoot/TableArea/PlayerHP") as Label
	_boss_hp_label = _host.get_node("ContentRoot/TableArea/BossHP") as Label
	_overlay_ui = _host.get_node("ContentRoot/OverlayUI") as Control
	_hand_anchor = _host.get_node("ContentRoot/TableArea/PlayerArea/HandAnchor") as HBoxContainer
	_boss_deck_root = _host.get_node("ContentRoot/TableArea/BossDeckView") as Control
	_boss_hand_count_label = _host.get_node("ContentRoot/TableArea/BossDeckView/BossHandCountLabel") as Label
	_boss_hand_animation_anchor = _host.get_node("ContentRoot/TableArea/BossDeckView/BossHandAnimationAnchor") as Control
	_deck_row = _host.get_node("ContentRoot/TableArea/BossDeckView/DeckRow") as HBoxContainer
	_boss_battle_deck_root = _host.get_node("ContentRoot/TableArea/BossBattleDeckView") as Control
	_battle_deck_title = _host.get_node("ContentRoot/TableArea/BossBattleDeckView/BattleDeckTitle") as Label
	_reveal_battle_deck_button = _host.get_node("ContentRoot/TableArea/BossBattleDeckView/RevealBattleDeckButton") as Button
	_battle_deck_row = _host.get_node("ContentRoot/TableArea/BossBattleDeckView/BattleDeckRow") as HBoxContainer
	_clash_root = _host.get_node("ContentRoot/TableArea/ClashArea") as Control
	_player_card_slot = _host.get_node("ContentRoot/TableArea/ClashArea/PlayerCardSlot") as Control
	_boss_card_slot = _host.get_node("ContentRoot/TableArea/ClashArea/BossCardSlot") as Control
	_clash_result_label = _host.get_node("ContentRoot/TableArea/ClashArea/ClashResultLabel") as Label
	_player_area = _host.get_node("ContentRoot/TableArea/PlayerArea") as Control
	_player_bod_label = _host.get_node("ContentRoot/TableArea/PlayerStatusPanel/MarginContainer/VBoxContainer/PlayerBOD") as Label
	_player_spr_label = _host.get_node("ContentRoot/TableArea/PlayerStatusPanel/MarginContainer/VBoxContainer/PlayerSPR") as Label
	_player_rep_label = _host.get_node("ContentRoot/TableArea/PlayerStatusPanel/MarginContainer/VBoxContainer/PlayerREP") as Label
	_boss_bod_label = _host.get_node("ContentRoot/TableArea/BossStatusPanel/MarginContainer/VBoxContainer/BossBOD") as Label
	_boss_spr_label = _host.get_node("ContentRoot/TableArea/BossStatusPanel/MarginContainer/VBoxContainer/BossSPR") as Label
	_boss_rep_label = _host.get_node("ContentRoot/TableArea/BossStatusPanel/MarginContainer/VBoxContainer/BossREP") as Label
	_boss_bet_area = _host.get_node("ContentRoot/TableArea/BossBetArea") as Control
	_boss_bet_row = _host.get_node("ContentRoot/TableArea/BossBetArea/BetRow") as HBoxContainer
	_peek_boss_bet_button = _host.get_node("ContentRoot/TableArea/BossBetArea/PeekBossBetButton") as Button
	_player_bet_area = _host.get_node("ContentRoot/TableArea/PlayerBetArea") as Control
	_player_bet_row = _host.get_node("ContentRoot/TableArea/PlayerBetArea/PlayerBetRow") as HBoxContainer
	_bet_phase_hint = _host.get_node("ContentRoot/TableArea/BetPhaseHint") as Label
	_bet_result_hint = _host.get_node("ContentRoot/TableArea/BetResultHint") as Label
	_turn_result_popup = _host.get_node("ContentRoot/TableArea/TurnResultPopup") as Control
	_feedback_label = _host.get_node("ContentRoot/TableArea/TurnResultPopup/FeedbackLabel") as Label
	_end_turn_button = _host.get_node("ContentRoot/TableArea/EndTurn") as Button
	_screen_effects = _host.get_node_or_null("ScreenEffects") as Control

	assert(_background != null, "Main.tscn is missing Background.")
	assert(_content_root != null, "Main.tscn is missing ContentRoot.")
	assert(_boss_area != null, "Main.tscn is missing BossArea.")
	assert(_boss_portrait != null, "Main.tscn is missing BossPortrait.")
	assert(_table_area != null, "Main.tscn is missing TableArea.")
	assert(_table_board != null, "Main.tscn is missing TableBoard.")
	assert(_center_info != null, "Main.tscn is missing CenterInfo.")
	assert(_round_label != null, "Main.tscn is missing RoundLabel.")
	assert(_turn_label != null, "Main.tscn is missing TurnLabel.")
	assert(_player_hp_label != null, "Main.tscn is missing PlayerHP.")
	assert(_boss_hp_label != null, "Main.tscn is missing BossHP.")
	assert(_hand_anchor != null, "Main.tscn is missing HandAnchor.")
	assert(_boss_deck_root != null, "Main.tscn is missing BossDeckView.")
	assert(_boss_hand_count_label != null, "Main.tscn is missing BossHandCountLabel.")
	assert(_boss_hand_animation_anchor != null, "Main.tscn is missing BossHandAnimationAnchor.")
	assert(_deck_row != null, "Main.tscn is missing DeckRow.")
	assert(_boss_battle_deck_root != null, "Main.tscn is missing BossBattleDeckView.")
	assert(_battle_deck_title != null, "Main.tscn is missing BattleDeckTitle.")
	assert(_reveal_battle_deck_button != null, "Main.tscn is missing RevealBattleDeckButton.")
	assert(_battle_deck_row != null, "Main.tscn is missing BattleDeckRow.")
	assert(_clash_root != null, "Main.tscn is missing ClashArea.")
	assert(_player_card_slot != null, "Main.tscn is missing PlayerCardSlot.")
	assert(_boss_card_slot != null, "Main.tscn is missing BossCardSlot.")
	assert(_clash_result_label != null, "Main.tscn is missing ClashResultLabel.")
	assert(_player_area != null, "Main.tscn is missing PlayerArea.")
	assert(_player_bod_label != null and _player_spr_label != null and _player_rep_label != null, "Main.tscn is missing PlayerStatusPanel labels.")
	assert(_boss_bod_label != null and _boss_spr_label != null and _boss_rep_label != null, "Main.tscn is missing BossStatusPanel labels.")
	assert(_boss_bet_area != null, "Main.tscn is missing BossBetArea.")
	assert(_boss_bet_row != null, "Main.tscn is missing BossBetArea/BetRow.")
	assert(_peek_boss_bet_button != null, "Main.tscn is missing BossBetArea/PeekBossBetButton.")
	assert(_player_bet_area != null, "Main.tscn is missing PlayerBetArea.")
	assert(_player_bet_row != null, "Main.tscn is missing PlayerBetArea/PlayerBetRow.")
	assert(_bet_phase_hint != null, "Main.tscn is missing BetPhaseHint.")
	assert(_bet_result_hint != null, "Main.tscn is missing BetResultHint.")
	assert(_turn_result_popup != null, "Main.tscn is missing TurnResultPopup.")
	assert(_feedback_label != null, "Main.tscn is missing TurnResultPopup/FeedbackLabel.")
	assert(_end_turn_button != null, "Main.tscn is missing EndTurn.")

func _configure_mouse_filters() -> void:
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_table_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_round_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_turn_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_battle_deck_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_deck_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_hand_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_hand_animation_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_deck_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_battle_deck_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_battle_deck_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reveal_battle_deck_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_peek_boss_bet_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_end_turn_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_bet_phase_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bet_result_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_turn_result_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feedback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _setup_views() -> void:
	_player_hand_view = MvpPlayerHandView.new(_hand_anchor, CARD_VIEW_SCENE)
	_player_hand_view.card_play_requested.connect(_on_card_play_requested)

	_boss_deck_view = MvpBossDeckView.new(
		_boss_deck_root,
		_boss_hand_count_label,
		_boss_hand_animation_anchor,
		_deck_row,
		CARD_VIEW_SCENE
	)

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
	if not _peek_boss_bet_button.pressed.is_connected(_on_peek_boss_bet_pressed):
		_peek_boss_bet_button.pressed.connect(_on_peek_boss_bet_pressed)
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
		_turn_result_popup_version += 1
	if is_instance_valid(_feedback_label):
		_feedback_label.text = ""
	if is_instance_valid(_turn_result_popup):
		_turn_result_popup.hide()

func show_turn_result_popup(lines: PackedStringArray) -> void:
	if not is_instance_valid(_turn_result_popup) or not is_instance_valid(_feedback_label):
		return
	_turn_result_popup_version += 1
	var popup_version := _turn_result_popup_version
	_feedback_label.text = "\n".join(lines)
	_turn_result_popup.show()
	var tree := _host.get_tree()
	if tree == null:
		return
	await tree.create_timer(TURN_RESULT_POPUP_DURATION).timeout
	if popup_version != _turn_result_popup_version:
		return
	_hide_turn_result_popup()

func _show_round_feedback(result: Dictionary) -> void:
	if _boss_state == null:
		return

	var player_card: Dictionary = result.get("player_card", {})
	var boss_card: Dictionary = result.get("boss_card", {})
	var player_type := str(player_card.get("type", ""))
	var boss_type := str(boss_card.get("type", ""))
	var player_display_name := str(player_card.get("display_name", MvpBattleCard.display_name_for_type(player_type)))
	var boss_display_name := str(boss_card.get("display_name", MvpBattleCard.display_name_for_type(boss_type)))
	var outcome := "ties"
	match str(result.get("winner", "tie")):
		"player":
			outcome = "wins"
		"boss":
			outcome = "loses"
		_:
			outcome = "ties"

	var remaining_count := 0
	for slot_index in range(_boss_state.cards.size()):
		if _boss_state.used_slots.has(slot_index):
			continue
		var remaining_card: MvpBattleCard = _boss_state.get_card_at(slot_index)
		if remaining_card != null and remaining_card.type == boss_type:
			remaining_count += 1

	show_turn_result_popup(PackedStringArray([
		"Boss used %s" % boss_display_name,
		"Your %s %s" % [player_display_name, outcome],
		"%s remaining: %d" % [boss_display_name, remaining_count],
	]))

func _start_new_challenge() -> void:
	_hide_turn_result_popup(true)
	_logs.clear()
	_player_set_wins = 0
	_boss_set_wins = 0
	_current_set_index = 1
	_current_turn_index = 1
	_boss_battle_revealed = false
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
	_player_state.set_deck_blueprint(MvpBattleCard.build_player_test_deck())
	var boss_template: Dictionary = MvpBattleCard.pick_random_boss_template(_boss_template_rng)
	_current_boss_template_id = str(boss_template.get("id", MvpBattleCard.DEFAULT_BOSS_TEMPLATE_ID))
	_boss_state.set_deck_blueprint(boss_template.get("cards", []))
	_player_state.reset_for_new_set(SET_HP)
	_boss_state.reset_for_new_set(SET_HP)
	_boss_battle_revealed = false
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
	_input_locked = false
	_boss_bet_peek_snapshot_text = ""
	if clear_result:
		_bet_result_text = ""
	_bet_phase = BET_CARD_SCRIPT.TIMING_PRE if bet_mode_enabled and not _challenge_over else BET_PHASE_CLOSED
	if is_instance_valid(_end_turn_button):
		_end_turn_button.hide()

func _refresh_ui() -> void:
	_round_label.text = "Round %d / %d" % [_current_set_index, MAX_SETS]
	_turn_label.text = "Turn %d / %d" % [_current_turn_index, MAX_TURNS]
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
	_boss_deck_view.set_hand(_boss_state.cards, _boss_state.used_slots)
	_boss_battle_deck_view.set_deck(_boss_state.cards, _boss_battle_revealed, _boss_state.used_slots)
	_boss_battle_deck_view.set_reveal_enabled(not _challenge_over)
	_refresh_bet_ui()
	_sync_reveal_battle_deck_layout()
	_refresh_overlay_log()

func _refresh_bet_ui() -> void:
	_player_bet_area.visible = bet_mode_enabled
	_boss_bet_area.visible = bet_mode_enabled
	_bet_phase_hint.visible = bet_mode_enabled
	_peek_boss_bet_button.visible = bet_mode_enabled and boss_bet_peek_enabled
	var end_turn_visible := bet_mode_enabled and _post_bet_window_open and not _challenge_over
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
	_bet_result_hint.visible = not bet_result_display.is_empty()
	_player_bet_view.set_entries(_build_player_bet_entries(), _is_player_bet_interactive())
	_boss_bet_view.set_entries(_build_boss_bet_entries(), false)

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

func _selected_player_bet_for_timing(timing: String):
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
	if not bet_mode_enabled or _challenge_over:
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

func _on_reveal_requested() -> void:
	if _challenge_over or _boss_battle_revealed:
		return
	_boss_battle_revealed = true
	push_log("Boss battle deck revealed for the current set.")
	_refresh_ui()

func _on_peek_boss_bet_pressed() -> void:
	if not bet_mode_enabled or not boss_bet_peek_enabled:
		return
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
		_refresh_ui()
		return
	_player_post_bet = bet_card
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
		_finalize_current_turn()
		return

	_input_locked = true
	_player_hand_view.set_interactive(false)
	var result: Dictionary = _resolver.resolve_round(_player_state, _boss_state, slot_index, boss_slot)
	_bet_result_text = _apply_bet_modifiers(result, _player_pre_bet, null)
	_apply_round_result(result)
	if _is_round_terminal_state():
		_finalize_current_turn()
		return
	_open_post_bet_window(result)

func _open_post_bet_window(result: Dictionary) -> void:
	_post_bet_window_open = true
	_post_bet_effects_applied = false
	_bet_phase = BET_CARD_SCRIPT.TIMING_POST
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
	_show_round_feedback(result)
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

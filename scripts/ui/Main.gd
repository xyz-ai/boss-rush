extends RefCounted
class_name MvpMainController

const CARD_VIEW_SCENE := preload("res://scenes/ui/CardView.tscn")

const MAX_SETS := 3
const WINS_TO_CLEAR := 2
const MAX_TURNS := 5
const SET_HP := 6
const STARTING_BOD := 3
const STARTING_SPR := 3
const STARTING_REP := 3
const MAX_LOG_LINES := 8

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
var _reveal_button: Button
var _deck_row: HBoxContainer
var _clash_root: Control
var _player_card_slot: Control
var _boss_card_slot: Control
var _player_area: Control
var _screen_effects: Control

var _player_hand_view: MvpPlayerHandView
var _boss_deck_view: MvpBossDeckView
var _clash_area_view: MvpClashAreaView
var _boss_ai: MvpBossAI = MvpBossAI.new()
var _resolver: MvpBattleResolver = MvpBattleResolver.new()

var _player_state: MvpCombatActorState
var _boss_state: MvpCombatActorState

var _current_set_index: int = 1
var _current_turn_index: int = 1
var _player_set_wins: int = 0
var _boss_set_wins: int = 0
var _boss_revealed: bool = false
var _challenge_over: bool = false
var _input_locked: bool = false
var _logs: Array[String] = []

func _init(host: Control) -> void:
	_host = host

func ready() -> void:
	_bind_nodes()
	_apply_stage_layout()
	_setup_views()
	_ensure_overlay_log()
	if _screen_effects != null and _screen_effects.has_method("bind_target"):
		_screen_effects.bind_target(_content_root)
	_start_new_challenge()

func handle_notification(what: int) -> void:
	if what == Control.NOTIFICATION_RESIZED:
		_apply_stage_layout()

func get_state_snapshot() -> Dictionary:
	return {
		"current_set_index": _current_set_index,
		"current_turn_index": _current_turn_index,
		"player_set_wins": _player_set_wins,
		"boss_set_wins": _boss_set_wins,
		"boss_revealed": _boss_revealed,
		"challenge_over": _challenge_over,
		"player": _player_state.snapshot() if _player_state != null else {},
		"boss": _boss_state.snapshot() if _boss_state != null else {},
	}

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
	_reveal_button = _host.get_node("ContentRoot/TableArea/BossDeckView/RevealDeckButton") as Button
	_deck_row = _host.get_node("ContentRoot/TableArea/BossDeckView/DeckRow") as HBoxContainer
	_clash_root = _host.get_node("ContentRoot/TableArea/ClashArea") as Control
	_player_card_slot = _host.get_node("ContentRoot/TableArea/ClashArea/PlayerCardSlot") as Control
	_boss_card_slot = _host.get_node("ContentRoot/TableArea/ClashArea/BossCardSlot") as Control
	_player_area = _host.get_node("ContentRoot/TableArea/PlayerArea") as Control
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
	assert(_reveal_button != null, "Main.tscn is missing RevealDeckButton.")
	assert(_deck_row != null, "Main.tscn is missing DeckRow.")
	assert(_clash_root != null, "Main.tscn is missing ClashArea.")
	assert(_player_card_slot != null, "Main.tscn is missing PlayerCardSlot.")
	assert(_boss_card_slot != null, "Main.tscn is missing BossCardSlot.")
	assert(_player_area != null, "Main.tscn is missing PlayerArea.")

func _setup_views() -> void:
	_player_hand_view = MvpPlayerHandView.new(_hand_anchor, CARD_VIEW_SCENE)
	_player_hand_view.card_play_requested.connect(_on_card_play_requested)

	_boss_deck_view = MvpBossDeckView.new(_boss_deck_root, _reveal_button, _deck_row, CARD_VIEW_SCENE)
	_boss_deck_view.reveal_requested.connect(_on_reveal_requested)

	_clash_area_view = MvpClashAreaView.new(_clash_root, _player_card_slot, _boss_card_slot, CARD_VIEW_SCENE)

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

func _start_new_challenge() -> void:
	_logs.clear()
	_player_set_wins = 0
	_boss_set_wins = 0
	_current_set_index = 1
	_current_turn_index = 1
	_boss_revealed = false
	_challenge_over = false
	_input_locked = false

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
	_player_state.reset_for_new_set(SET_HP)
	_boss_state.reset_for_new_set(SET_HP)
	_boss_revealed = false
	_current_turn_index = 1
	_input_locked = false
	_clash_area_view.clear_clash()

func _refresh_ui() -> void:
	_round_label.text = "Round %d / %d" % [_current_set_index, MAX_SETS]
	_turn_label.text = "Turn %d / %d" % [_current_turn_index, MAX_TURNS]
	_player_hp_label.text = "Player HP %d\nBOD %d  SPR %d  REP %d" % [
		_player_state.hp,
		_player_state.bod,
		_player_state.spr,
		_player_state.rep,
	]
	_boss_hp_label.text = "Boss HP %d\nBOD %d  SPR %d  REP %d" % [
		_boss_state.hp,
		_boss_state.bod,
		_boss_state.spr,
		_boss_state.rep,
	]

	_player_hand_view.set_hand(
		_player_state.cards,
		_player_state.used_slots,
		not _challenge_over and not _input_locked
	)
	_boss_deck_view.set_deck(_boss_state.cards, _boss_revealed, _boss_state.used_slots)
	_boss_deck_view.set_reveal_enabled(not _challenge_over)
	_refresh_overlay_log()
	_apply_stage_layout()

func _on_reveal_requested() -> void:
	if _challenge_over or _boss_revealed:
		return
	_boss_revealed = true
	push_log("Boss deck revealed for the current set.")
	_refresh_ui()

func _on_card_play_requested(slot_index: int) -> void:
	if _challenge_over or _input_locked or _player_state.is_slot_used(slot_index):
		return

	var player_card := _player_state.get_card_at(slot_index)
	var boss_slot := _boss_ai.choose_slot(_boss_state, player_card)
	if player_card == null or boss_slot == -1:
		return

	_input_locked = true
	_player_hand_view.set_interactive(false)

	var result := _resolver.resolve_round(_player_state, _boss_state, slot_index, boss_slot)
	_apply_round_result(result)

func _apply_round_result(result: Dictionary) -> void:
	var player_slot := int(result.get("player_slot", -1))
	var boss_slot := int(result.get("boss_slot", -1))
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
	push_log("Current HP -> Player %d / Boss %d." % [_player_state.hp, _boss_state.hp])
	push_log("Current score -> Player %d / Boss %d." % [_player_set_wins, _boss_set_wins])
	_print_round_debug(result)

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
	_input_locked = false
	push_log("Turn %d begins." % _current_turn_index)
	_refresh_ui()

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
	# MVP default: if HP and REP are both tied, the boss wins the set.
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

func _apply_stage_layout() -> void:
	if _host == null or not is_instance_valid(_host):
		return
	var viewport_size: Vector2 = _host.get_viewport_rect().size
	if viewport_size.x < 100.0 or viewport_size.y < 100.0:
		return

	_pin_rect(_host, Vector2.ZERO, viewport_size)
	_pin_rect(_background, Vector2.ZERO, viewport_size)
	if _screen_effects != null:
		_pin_rect(_screen_effects, Vector2.ZERO, viewport_size)

	var safe_margin_x: float = clampf(viewport_size.x * 0.03, 24.0, 52.0)
	var safe_margin_y: float = clampf(viewport_size.y * 0.03, 18.0, 42.0)
	var stage_rect := Rect2(
		Vector2(safe_margin_x, safe_margin_y),
		Vector2(viewport_size.x - safe_margin_x * 2.0, viewport_size.y - safe_margin_y * 2.0)
	)
	_pin_rect(_content_root, stage_rect.position, stage_rect.size)

	var stage_size := _content_root.size
	var boss_width: float = clampf(stage_size.x * 0.52, 520.0, 760.0)
	var boss_height: float = clampf(stage_size.y * 0.25, 180.0, 240.0)
	_pin_rect(_boss_area, Vector2((stage_size.x - boss_width) * 0.5, 0.0), Vector2(boss_width, boss_height))
	_boss_portrait.scale = Vector2.ONE
	_boss_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_boss_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_pin_rect(
		_boss_portrait,
		Vector2((boss_width - boss_width * 0.42) * 0.5, 0.0),
		Vector2(boss_width * 0.42, boss_height * 0.95)
	)

	var table_top: float = stage_size.y * 0.18
	var table_height: float = stage_size.y - table_top
	_pin_rect(_table_area, Vector2(0.0, table_top), Vector2(stage_size.x, table_height))

	var board_width: float = clampf(_table_area.size.x * 0.84, 900.0, 1320.0)
	var board_height: float = clampf(_table_area.size.y * 0.64, 430.0, 620.0)
	var board_position := Vector2(
		(_table_area.size.x - board_width) * 0.5,
		clampf(_table_area.size.y * 0.10, 36.0, 84.0)
	)
	_table_board.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_table_board.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_pin_rect(_table_board, board_position, Vector2(board_width, board_height))

	var center_info_size := Vector2(180.0, 52.0)
	_pin_rect(
		_center_info,
		Vector2((_table_area.size.x - center_info_size.x) * 0.5, board_position.y + 8.0),
		center_info_size
	)

	var player_hp_size := Vector2(188.0, 64.0)
	var boss_hp_size := Vector2(188.0, 64.0)
	_pin_rect(
		_player_hp_label,
		Vector2(board_position.x + 40.0, board_position.y + board_height * 0.57),
		player_hp_size
	)
	_pin_rect(
		_boss_hp_label,
		Vector2(board_position.x + board_width - boss_hp_size.x - 40.0, board_position.y + board_height * 0.19),
		boss_hp_size
	)

	var deck_width: float = clampf(board_width * 0.66, 580.0, 880.0)
	var deck_height: float = 170.0
	_pin_rect(
		_boss_deck_root,
		Vector2((_table_area.size.x - deck_width) * 0.5, board_position.y + 16.0),
		Vector2(deck_width, deck_height)
	)
	_pin_rect(_reveal_button, Vector2((deck_width - 136.0) * 0.5, 0.0), Vector2(136.0, 42.0))
	_pin_rect(_deck_row, Vector2(0.0, 54.0), Vector2(deck_width, 116.0))

	var clash_width: float = clampf(board_width * 0.46, 420.0, 620.0)
	var clash_height: float = 280.0
	_pin_rect(
		_clash_root,
		Vector2((_table_area.size.x - clash_width) * 0.5, board_position.y + board_height * 0.26),
		Vector2(clash_width, clash_height)
	)
	var clash_card_size := Vector2(140.0, 184.0)
	_pin_rect(
		_boss_card_slot,
		Vector2((clash_width - clash_card_size.x) * 0.5, 0.0),
		clash_card_size
	)
	_pin_rect(
		_player_card_slot,
		Vector2((clash_width - clash_card_size.x) * 0.5, clash_height - clash_card_size.y),
		clash_card_size
	)

	var hand_width: float = clampf(stage_size.x * 0.74, 860.0, 1120.0)
	var hand_height: float = clampf(stage_size.y * 0.23, 210.0, 250.0)
	_pin_rect(
		_player_area,
		Vector2((_table_area.size.x - hand_width) * 0.5, _table_area.size.y - hand_height - 8.0),
		Vector2(hand_width, hand_height)
	)
	_pin_rect(_hand_anchor, Vector2.ZERO, _player_area.size)

	var overlay_width: float = clampf(stage_size.x * 0.24, 280.0, 380.0)
	var overlay_height: float = 140.0
	_pin_rect(
		_overlay_ui,
		Vector2(0.0, table_top + board_position.y + board_height * 0.46),
		Vector2(overlay_width, overlay_height)
	)

func _pin_rect(control: Control, position: Vector2, size: Vector2) -> void:
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 0.0
	control.anchor_bottom = 0.0
	control.position = position
	control.size = size

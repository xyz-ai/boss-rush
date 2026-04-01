extends RefCounted
class_name MvpMainController

const CARD_VIEW_SCENE := preload("res://scenes/ui/CardView.tscn")
const BOSS_BATTLE_DECK_VIEW_SCRIPT := preload("res://scripts/ui/BossBattleDeckView.gd")

const MAX_SETS := 3
const WINS_TO_CLEAR := 2
const MAX_TURNS := 5
const SET_HP := 6
const STARTING_BOD := 3
const STARTING_SPR := 3
const STARTING_REP := 3
const MAX_LOG_LINES := 5

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

var _player_hand_view: MvpPlayerHandView
var _boss_deck_view: MvpBossDeckView
var _boss_battle_deck_view
var _clash_area_view: MvpClashAreaView
var _boss_ai: MvpBossAI = MvpBossAI.new()
var _resolver: MvpBattleResolver = MvpBattleResolver.new()
var _boss_template_rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _player_state: MvpCombatActorState
var _boss_state: MvpCombatActorState

var _current_set_index: int = 1
var _current_turn_index: int = 1
var _player_set_wins: int = 0
var _boss_set_wins: int = 0
var _boss_battle_revealed: bool = false
var _current_boss_template_id: String = MvpBattleCard.DEFAULT_BOSS_TEMPLATE_ID
var _challenge_over: bool = false
var _input_locked: bool = false
var _logs: Array[String] = []

func _init(host: Control) -> void:
	_host = host

func ready() -> void:
	_bind_nodes()
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
	return {
		"current_set_index": _current_set_index,
		"current_turn_index": _current_turn_index,
		"player_set_wins": _player_set_wins,
		"boss_set_wins": _boss_set_wins,
		"current_boss_template_id": _current_boss_template_id,
		"boss_battle_revealed": _boss_battle_revealed,
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

func _configure_mouse_filters() -> void:
	# Keep passive display layers from eating clicks meant for the reveal button.
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
	_boss_battle_revealed = false
	_current_boss_template_id = MvpBattleCard.DEFAULT_BOSS_TEMPLATE_ID
	_challenge_over = false
	_input_locked = false
	_boss_template_rng.randomize()

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
	_clash_area_view.clear_clash()

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
	_boss_bet_area.visible = false

	_player_hand_view.set_hand(
		_player_state.cards,
		_player_state.used_slots,
		not _challenge_over and not _input_locked
	)
	_boss_deck_view.set_hand(_boss_state.cards, _boss_state.used_slots)
	_boss_battle_deck_view.set_deck(_boss_state.cards, _boss_battle_revealed, _boss_state.used_slots)
	_boss_battle_deck_view.set_reveal_enabled(not _challenge_over)
	_sync_reveal_battle_deck_layout()
	_refresh_overlay_log()

func _sync_reveal_battle_deck_layout() -> void:
	if _boss_battle_deck_view != null and _boss_battle_deck_view.has_method("update_layout"):
		_boss_battle_deck_view.update_layout()

func _on_reveal_requested() -> void:
	if _challenge_over or _boss_battle_revealed:
		return
	_boss_battle_revealed = true
	push_log("Boss battle deck revealed for the current set.")
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

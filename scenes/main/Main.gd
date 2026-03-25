extends Control

const BATTLE_SCENE := preload("res://scenes/battle/BattleScene.tscn")
const SHOP_SCENE := preload("res://scenes/shop/ShopScene.tscn")
const COLLAPSE_EFFECTS_SCRIPT := preload("res://scripts/systems/CollapseEffects.gd")
const CONSTANTS := preload("res://scripts/util/Constants.gd")

@onready var _content_root: Control = $ContentRoot
@onready var _screen_effects = $ScreenEffects

var _collapse_effects

func _ready() -> void:
	_collapse_effects = COLLAPSE_EFFECTS_SCRIPT.new(_data_loader().get_balance("ui_thresholds", {}))
	_screen_effects.bind_target(_content_root)
	SignalBus.screen_requested.connect(_on_screen_requested)
	SignalBus.run_state_changed.connect(_on_run_state_changed)
	_show_main_menu()
	_on_run_state_changed(GameRun.run_state)

func _on_screen_requested(screen_name: String, payload: Dictionary) -> void:
	match screen_name:
		CONSTANTS.SCREEN_BATTLE:
			_show_battle(payload)
		CONSTANTS.SCREEN_SHOP:
			_show_shop(payload)
		CONSTANTS.SCREEN_SUMMARY:
			_show_summary(payload)
		_:
			_show_main_menu()

func _on_run_state_changed(run_state) -> void:
	var profile = {
		"desaturation": 0.0,
		"shake": 0.0,
		"panel_drop": 0.0,
		"crack_alpha": 0.0,
	}
	if run_state != null:
		profile = _collapse_effects.evaluate(run_state)
	_screen_effects.apply_profile(profile)
	var current_screen = _get_current_screen()
	if current_screen != null and current_screen.has_method("apply_effect_profile"):
		current_screen.apply_effect_profile(profile)

func _show_main_menu() -> void:
	_clear_content()
	var panel = _build_panel(
		"极简职场隐喻卡牌博弈",
		"单 Boss MVP 原型",
		[
			"主菜单 -> Team Lead 挑战 -> 商店 -> 阶段总结。",
			"战斗采用三局两胜制，每局最多五回合；玩家每局固定打完 5 张战斗牌。",
			"加注牌属于本次挑战资源，不会在局间自动恢复。",
			"BOD / SPR / REP 任意一项归零，会直接导致整场挑战崩溃失败。"
		],
		"开始 Run",
		_on_start_pressed
	)
	_content_root.add_child(panel)

func _show_battle(payload: Dictionary) -> void:
	_clear_content()
	var scene = BATTLE_SCENE.instantiate()
	_content_root.add_child(scene)
	scene.bind_context(GameRun.run_state, payload.get("boss", {}))

func _show_shop(payload: Dictionary) -> void:
	_clear_content()
	var scene = SHOP_SCENE.instantiate()
	_content_root.add_child(scene)
	scene.bind_context(GameRun.run_state, payload.get("offers", []))

func _show_summary(payload: Dictionary) -> void:
	_clear_content()
	var lines: Array[String] = [payload.get("summary", "这一轮已经结束。")]
	if GameRun.run_state != null:
		var challenge_snapshot: Dictionary = payload.get("challenge_snapshot", {})
		if challenge_snapshot.is_empty() and GameRun.run_state.challenge_state != null:
			challenge_snapshot = GameRun.run_state.challenge_state.snapshot()
		if not challenge_snapshot.is_empty():
			lines.append("挑战比分：玩家 %d / Boss %d" % [
				int(challenge_snapshot.get("player_set_wins", 0)),
				int(challenge_snapshot.get("boss_set_wins", 0)),
			])
		lines.append("最终状态：POS %d / BOD %d / SPR %d / REP %d / LIFE %d" % [
			GameRun.run_state.pos,
			GameRun.run_state.bod,
			GameRun.run_state.spr,
			GameRun.run_state.rep,
			GameRun.run_state.life,
		])
	var logs = GameRun.get_recent_logs_text(6)
	if not logs.is_empty():
		lines.append("最近记录：\n%s" % logs)
	var panel = _build_panel(
		payload.get("title", "总结"),
		"阶段回顾",
		lines,
		"返回主菜单",
		_on_back_to_menu_pressed
	)
	_content_root.add_child(panel)

func _build_panel(title: String, subtitle: String, body_lines: Array[String], button_text: String, button_callback: Callable) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(980, 600)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)

	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	margin.add_child(box)

	var title_label = Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 32)
	box.add_child(title_label)

	var subtitle_label = Label.new()
	subtitle_label.text = subtitle
	subtitle_label.modulate = Color(0.70, 0.76, 0.82)
	box.add_child(subtitle_label)

	var body_label = RichTextLabel.new()
	body_label.fit_content = true
	body_label.scroll_active = false
	body_label.bbcode_enabled = true
	body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_label.text = "[color=#cfd6de]%s[/color]" % "\n\n".join(body_lines)
	box.add_child(body_label)

	var button = Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(0, 54)
	button.pressed.connect(button_callback)
	box.add_child(button)

	return panel

func _clear_content() -> void:
	for child in _content_root.get_children():
		child.queue_free()

func _get_current_screen() -> Node:
	if _content_root.get_child_count() == 0:
		return null
	return _content_root.get_child(0)

func _on_start_pressed() -> void:
	GameRun.start_new_run()

func _on_back_to_menu_pressed() -> void:
	GameRun.run_state = null
	_show_main_menu()
	_on_run_state_changed(null)

func _data_loader():
	return get_node_or_null("/root/DataLoader")

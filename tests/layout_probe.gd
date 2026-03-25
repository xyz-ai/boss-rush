extends SceneTree

const RUN_STATE_SCRIPT := preload("res://scripts/core/RunState.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var loader = get_root().get_node_or_null("DataLoader")
	var game_run = get_root().get_node_or_null("GameRun")
	if loader == null:
		push_error("DataLoader missing.")
		quit(1)
		return
	loader.reload_all()

	for size in [Vector2i(1366, 768), Vector2i(1440, 900), Vector2i(1600, 900), Vector2i(1920, 1080)]:
		DisplayServer.window_set_size(size)
		await process_frame
		await process_frame
		var state = _fresh_state(loader)
		if game_run != null:
			game_run.run_state = state
		var scene: Control = load("res://scenes/battle/BattleScene.tscn").instantiate()
		get_root().add_child(scene)
		scene.bind_context(state, loader.get_boss("team_lead"))
		await process_frame
		await process_frame
		scene.call("_on_peek_requested")
		await process_frame
		_print_layout(scene, size)
		scene.queue_free()
		await process_frame

	quit(0)

func _print_layout(scene: Control, size: Vector2i) -> void:
	print("--- %dx%d ---" % [size.x, size.y])
	for path in [
		"SafeArea/StageRoot/BossStage",
		"SafeArea/StageRoot/BossStage/BossPanel",
		"SafeArea/StageRoot/TableCore",
		"SafeArea/StageRoot/TableCore/TopRoundInfo",
		"SafeArea/StageRoot/TableCore/IntelZone/BossDeckView",
		"SafeArea/StageRoot/LeftStatusStage",
		"SafeArea/StageRoot/RightDrawer",
		"SafeArea/StageRoot/PlayerHandStage",
		"SafeArea/StageRoot/PlayerHandStage/HandArea/CardRow",
	]:
		var node: Control = scene.get_node(path)
		var rect := Rect2(node.global_position, node.size)
		print("%s => pos=(%.1f, %.1f) size=(%.1f, %.1f)" % [path, rect.position.x, rect.position.y, rect.size.x, rect.size.y])

	var card_row: Control = scene.get_node("SafeArea/StageRoot/PlayerHandStage/HandArea/CardRow")
	for child in card_row.get_children():
		if child is Control:
			var card := child as Control
			var rect := Rect2(card.global_position, card.size * card.scale)
			print("card %s => local=(%.1f, %.1f) pos=(%.1f, %.1f) size=(%.1f, %.1f) rot=%.1f" % [card.name, card.position.x, card.position.y, rect.position.x, rect.position.y, rect.size.x, rect.size.y, card.rotation_degrees])

func _fresh_state(loader) -> Object:
	var defaults: Dictionary = loader.get_balance("starting_values", {})
	var challenge_rules: Dictionary = loader.get_balance("challenge_rules", {})
	var state = RUN_STATE_SCRIPT.new()
	state.configure(defaults)
	state.begin_challenge("team_lead", challenge_rules, loader.get_player_loadout("default_set_hand"))
	state.current_set_state.configure_boss_deck(loader.get_boss("team_lead").get("deck", []))
	return state

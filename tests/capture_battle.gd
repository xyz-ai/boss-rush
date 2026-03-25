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

	var output_dir := "res://tests/out"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))

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
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw

		var image: Image = get_root().get_viewport().get_texture().get_image()
		var output_path := "%s/battle_capture_%dx%d.png" % [output_dir, size.x, size.y]
		image.save_png(ProjectSettings.globalize_path(output_path))
		print(output_path)
		scene.queue_free()
		await process_frame

	quit(0)

func _fresh_state(loader) -> Object:
	var defaults: Dictionary = loader.get_balance("starting_values", {})
	var challenge_rules: Dictionary = loader.get_balance("challenge_rules", {})
	var state = RUN_STATE_SCRIPT.new()
	state.configure(defaults)
	state.begin_challenge("team_lead", challenge_rules, loader.get_player_loadout("default_set_hand"))
	state.current_set_state.configure_boss_deck(loader.get_boss("team_lead").get("deck", []))
	return state

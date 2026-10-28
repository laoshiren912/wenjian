extends SceneTree

# Diagnostic fixture only: compare OS/window/viewport coordinates without changing gameplay.
var game: SurvivorGame

func _initialize() -> void:
	_run.call_deferred()

func frames(count: int = 5) -> void:
	for frame in range(count):
		await physics_frame
	await process_frame

func sample(stage: String) -> void:
	print("INPUT PROBE: " + JSON.stringify({
		"stage": stage, "driver": DisplayServer.get_name(), "focused": root.has_focus(),
		"window_size": str(root.size), "viewport_rect": str(root.get_visible_rect()),
		"final_transform": str(root.get_final_transform()), "window_position": str(root.position),
		"os_mouse": str(DisplayServer.mouse_get_position()), "viewport_mouse": str(root.get_mouse_position()),
		"player_canvas": str(game.player.get_global_transform_with_canvas().origin),
		"world_mouse": str(game.player.get_global_mouse_position()), "aim": str(game.player.aim_direction)
	}))

func _run() -> void:
	root.size = Vector2i(1280, 720)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frames()
	game.start_run()
	for enemy in get_nodes_in_group("enemies"):
		enemy.free()
	game.spawn_timer = 9999.0
	game.player.camera.reset_smoothing()
	await frames()
	sample("before")
	var event := InputEventMouseMotion.new()
	event.position = game.player.get_global_transform_with_canvas().origin + Vector2(200, 0)
	event.global_position = event.position
	print("REQUESTED VIEWPORT POINT: ", event.position)
	Input.parse_input_event(event)
	sample("parse_immediate")
	await frames()
	sample("parse_after_physics")
	root.push_input(event, true)
	sample("push_local_immediate")
	await frames()
	sample("push_local_after_physics")
	root.grab_focus()
	root.warp_mouse(event.position)
	await frames()
	sample("viewport_warp_after_physics")
	paused = false
	quit()

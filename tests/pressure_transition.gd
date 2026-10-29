extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.select_profession(2)
	game.start_run()
	check(game.remaining == 8 and game.pending_wave.size() == 4, "remaining includes delayed enemies")
	var facing := Vector2.RIGHT
	var point: Vector2 = game.world.rear_spawn(game.player.global_position, facing)
	var offset: Vector2 = point - game.player.global_position
	check(offset.length() >= 350.0 and offset.normalized().dot(facing) <= -0.35, "rear spawn distance and direction")
	check(not game.world.path_between(point, game.player.global_position).is_empty(), "rear spawn reachable")
	game.player.visual.facing = facing
	game.player.aim_direction = facing
	game._spawn_rear_wave()
	check(game.pending_wave.is_empty() and get_nodes_in_group("enemies").size() == 8, "rear wave joins")
	var fast := 0
	for enemy in get_nodes_in_group("enemies"):
		if enemy.fast_chaser:
			fast += 1
			check(enemy.speed == 265.0, "fast chaser speed")
	check(fast == 2, "two fast chasers")
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	await process_frame
	game.remaining = 1
	game.player.position = SurvivorWorld.SPAWN
	Input.action_press("move_right")
	await physics_frame
	await physics_frame
	check(is_equal_approx(game.player.velocity.x, 240.0), "archer walking speed unchanged")
	game.player._attack_held = true
	Input.action_press("attack")
	await physics_frame
	await physics_frame
	check(is_equal_approx(game.player.velocity.x, 132.0), "fired bow shot reduces speed")
	Input.action_release("attack")
	Input.action_release("move_right")
	game.player._attack_held = false
	game.player.gain_experience(40)
	await process_frame
	await process_frame
	check(game.state == game.State.PLAYING and game.pending_levels == 1, "level gain does not interrupt battle")
	game._open_level_up()
	check(game.state == game.State.UPGRADE_PROMPT and game.hud.transition_button.disabled, "upgrade intro blocks immediate input")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	Input.parse_input_event(mouse)
	await process_frame
	game.hud._process(0.5)
	check(game.hud.transition_button.disabled, "held mouse keeps intro blocked")
	mouse = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = false
	Input.parse_input_event(mouse)
	await process_frame
	game.hud._process(0.5)
	check(not game.hud.transition_button.disabled, "intro enables after delay and release")
	game.hud.transition_button.pressed.emit()
	check(game.state == game.State.LEVEL_UP and not game.hud.level_ui.accepting, "card choice initially blocked")
	game.defer_upgrade()
	check(game.state == game.State.PLAYING and game.pending_levels == 1, "closing cards keeps earned choice")
	game._open_level_up()
	game.open_upgrade_choices()
	var previous_level: int = game.pending_levels
	game.hud.level_ui._choose(0)
	check(game.pending_levels == previous_level, "immediate card selection ignored")
	game.hud.level_ui._process(0.5)
	game.hud.level_ui._choose(0)
	check(game.state == game.State.PLAYING and game.pending_levels == 0, "card accepted after delay")
	paused = false
	game.queue_free()
	await process_frame
	print("PRESSURE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

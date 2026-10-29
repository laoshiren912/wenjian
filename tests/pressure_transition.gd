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
	check(game.state == game.State.PLAYING and not paused and game.player.skill_points == 1, "level gain grants a point without interrupting battle")
	check(game.hud.get_node_or_null("LevelUpUI") == null, "no card interface is created")
	paused = false
	game.queue_free()
	await process_frame
	print("PRESSURE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

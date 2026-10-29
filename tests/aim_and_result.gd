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
	for profession in range(3):
		var game = load("res://scenes/main.tscn").instantiate()
		root.add_child(game)
		current_scene = game
		await process_frame
		game.select_profession(profession)
		game.start_run()
		for enemy in get_nodes_in_group("enemies"):
			enemy.free()
		game.pending_wave.clear()
		game.remaining = 1
		var target = game._spawn_enemy(SurvivorEnemy.Kind.HOSTILE, game.player.global_position + Vector2(0, -[70, 135, 200][profession]))
		target.set_physics_process(false)
		var motion := InputEventMouseMotion.new()
		motion.position = game.player.get_global_transform_with_canvas() * game.player.to_local(target.global_position)
		motion.global_position = motion.position
		root.push_input(motion, true)
		await physics_frame
		await physics_frame
		check(game.player.aim_direction.dot(Vector2.UP) > 0.98, "mouse event aims upward for profession %d" % profession)
		game.player.weapon.attack(game.player.aim_direction)
		for i in range(50):
			await physics_frame
			if target.health < target.max_health:
				break
		check(target.health < target.max_health, "aimed attack hits profession %d" % profession)
		game._end_run(false)
		var key := InputEventKey.new()
		key.keycode = KEY_SPACE
		key.physical_keycode = KEY_SPACE
		key.pressed = true
		root.push_input(key, true)
		key = InputEventKey.new()
		key.keycode = KEY_SPACE
		key.physical_keycode = KEY_SPACE
		key.pressed = false
		root.push_input(key, true)
		await process_frame
		check(current_scene == game and game.state == game.State.DEAD, "space does not restart")
		paused = false
		game.queue_free()
		await process_frame
	print("AIM AND RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

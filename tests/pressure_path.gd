extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_run()
	for enemy in get_nodes_in_group("enemies"):
		enemy.free()
	game.pending_wave.clear()
	game.remaining = 1
	var chosen := Vector2i(-1, -1)
	for cell in game.world.blocked:
		if cell.x < 3 or cell.x >= 37 or cell.y < 3 or cell.y >= 27:
			continue
		var left: Vector2i = cell + Vector2i(-1, 0)
		var right: Vector2i = cell + Vector2i(1, 0)
		if not game.world.grid.is_point_solid(left) and not game.world.grid.is_point_solid(right):
			chosen = cell
			break
	if chosen.x < 0:
		printerr("FAIL: no suitable obstacle")
		quit(1)
		return
	var start: Vector2 = game.world.cell_center(chosen + Vector2i(-1, 0))
	var target: Vector2 = game.world.cell_center(chosen + Vector2i(1, 0))
	game.player.global_position = target
	var enemy = game._spawn_enemy(SurvivorEnemy.Kind.HOSTILE, start, true)
	var max_offset := 0.0
	var start_distance: float = start.distance_to(target)
	for tick in range(240):
		await physics_frame
		max_offset = maxf(max_offset, absf(enemy.global_position.y - start.y))
		if enemy.global_position.distance_to(target) < 65.0:
			break
	var end_distance: float = enemy.global_position.distance_to(target)
	var ok: bool = max_offset > 25.0 and end_distance < start_distance - 30.0
	print("PATH: around obstacle=%s deviation=%.1f distance=%.1f -> %.1f" % [ok, max_offset, start_distance, end_distance])
	paused = false
	game.queue_free()
	await process_frame
	quit(0 if ok else 1)

extends SceneTree

const CONFIG = preload("res://scripts/v41_config.gd")
var game
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
	await process_frame

func run() -> void:
	game = load("res://scenes/main_v41.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.debug_jump(CONFIG.FLOATING_RUINS_ROOM)
	game.debug_close()
	var player: SurvivorPlayer = game.player
	var world = game.world
	var outline: PackedVector2Array = world.walkable
	player.gm_invulnerable = true
	var enemies := get_nodes_in_group("enemies")
	for enemy in enemies:
		enemy.set_physics_process(false)
	await frames(2)
	check(Geometry2D.is_point_in_polygon(player.position, outline), "normal arrival remains inside")
	check(Geometry2D.is_point_in_polygon(world.exit_point, outline), "existing exit remains inside")
	var arrival_cell: Vector2i = world.nearest_cell(player.position)
	var exit_cell: Vector2i = world.nearest_cell(world.exit_point)
	check(not world.grid.get_id_path(arrival_cell, exit_cell).is_empty(), "navigation connects existing arrival and exit")
	for enemy in enemies:
		check(Geometry2D.is_point_in_polygon(enemy.position, outline), "wave-one spawn inside")
	var player_mask := player.collision_mask
	player.collision_mask = world.terrain_movement_mask
	enemies[0].collision_mask = world.terrain_movement_mask
	for i in range(outline.size()):
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		var edge := b - a
		var outward := Vector2(edge.y, -edge.x).normalized()
		var origin := a.lerp(b, 0.5) - outward * 42.0
		var pose := Transform2D(0.0, origin)
		var player_hit := KinematicCollision2D.new()
		var enemy_hit := KinematicCollision2D.new()
		check(player.test_move(pose, outward * 120.0, player_hit) and player_hit.get_collider() == world.floating_ruins_boundary,
			"player collider stops against edge %d" % i)
		check(enemies[0].test_move(pose, outward * 120.0, enemy_hit) and enemy_hit.get_collider() == world.floating_ruins_boundary,
			"enemy collider stops against edge %d" % i)
	for enemy in enemies:
		enemy.free()
	game.scheduler = null
	player.collision_mask = player_mask

	player.position = Vector2(640, 475)
	Input.action_press("move_down")
	await frames(30)
	Input.action_release("move_down")
	check(player.position.y > 500.0 and player.position.y < 550.0, "walking stops on the southern stone rim")
	check(not player.try_roll(), "legacy roll is disabled")
	player.position = Vector2(640, 475)
	game.player.cultivation = 2
	game.player.request_dash(Vector2.DOWN)
	await frames(26)
	check(game.player.dash_cooldown > 0.0 and player.position.y > 500.0 and player.position.y < 550.0, "high-speed dash truncates on the rim")

	player.position = Vector2(640, 523)
	player.aim_direction = Vector2.DOWN
	game.debug_spawn(2, 10)
	check(game.gm_spawned.size() == 10, "requested debug group spawned despite cursor aiming beyond the edge")
	for enemy in game.gm_spawned:
		check(Geometry2D.is_point_in_polygon(enemy.position, outline) and not world.grid.is_point_solid(world.cell_at(enemy.position)),
			"debug spawn snapped to a safe cell")
	player.position = Vector2(640, 390)
	await frames(90)
	check(game.gm_spawned.all(func(enemy): return Geometry2D.is_point_in_polygon(enemy.position, outline)),
		"live ranged enemies stay on platform while retreating")

	game.debug_jump(5)
	game.debug_close()
	await frames(2)
	check(game.world.floating_ruins_boundary.collision_layer == 0 and game.world.heaven_gate_boundary.collision_layer == 1,
		"platform collider is disabled when leaving room five")
	print("V41 ROOM 5 EDGE: %d/%d" % [checks - failures, checks])
	game.free()
	quit(1 if failures else 0)

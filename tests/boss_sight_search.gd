extends SceneTree
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	game.start_run()
	for enemy in get_nodes_in_group("enemies"):
		enemy.free()
	game.set_process(false)
	game.player.set_physics_process(false)
	var wall_cell := Vector2i(20, 15)
	game.world._add_wall(wall_cell)
	var center: Vector2 = game.world.cell_center(wall_cell)
	game.world.floor_cells.erase(wall_cell)
	var boss = game._spawn_enemy(3, center + Vector2(-150, 0))
	boss.boss_next_attack = 2
	boss.boss_timer = 100.0
	game.player.global_position = center + Vector2(-100, 130)
	await physics_frame
	await physics_frame
	check(boss._boss_has_sight(game.player.global_position), "initial sight")
	var last_seen: Vector2 = game.player.global_position
	game.player.global_position = center + Vector2(150, 0)
	await physics_frame
	await physics_frame
	check(not boss._boss_has_sight(game.player.global_position), "wall blocks sight")
	check(boss.boss_search_target == last_seen, "search last seen location")
	game.player.global_position = center + Vector2(180, -40)
	await physics_frame
	check(boss.boss_search_target == last_seen, "does not follow hidden player position")
	check(boss.boss_state == boss.BossState.APPROACH, "no charge from behind wall")
	var found := false
	for i in range(450):
		await physics_frame
		if boss._boss_has_sight(game.player.global_position):
			found = true
			break
	check(found, "boss moves around pillar and finds player")
	if found:
		boss.boss_timer = 0
		await physics_frame
		await physics_frame
		check(boss.boss_state == boss.BossState.CHARGE_WINDUP, "charge begins after sight returns")
		boss.global_position = center + Vector2(-150, 0)
		game.player.global_position = center + Vector2(150, 0)
		boss.boss_timer = 0.9
		await physics_frame
		await physics_frame
		check(boss.boss_state == boss.BossState.APPROACH, "early charge cancels after sight lost")
	print("BOSS SIGHT failures: ", failures)
	quit(1 if failures else 0)

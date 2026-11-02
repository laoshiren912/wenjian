extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	for seed_value in range(1, 13):
		var world := SurvivorWorld.new()
		root.add_child(world)
		world.build(seed_value)
		var groups := world.encounter_positions(4, SurvivorWorld.SPAWN)
		check(groups.size() == 4, "seed %d has four groups" % seed_value)
		var all: Array[Vector2] = []
		for group in groups:
			check(group.size() == 4, "seed %d four members" % seed_value)
			for point in group:
				check(not all.has(point) and not world.path_between(SurvivorWorld.SPAWN, point).is_empty(), "unique reachable point")
				all.append(point)
		world.free()
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	game.start_run()
	game.set_process(false)
	game.player.set_physics_process(false)
	for enemy in get_nodes_in_group("enemies"): enemy.free()
	var cell := Vector2i(20, 15)
	game.world._add_wall(cell)
	var center: Vector2 = game.world.cell_center(cell)
	var a = game._spawn_enemy(1, center + Vector2(-150, 0))
	var b = game._spawn_enemy(1, center + Vector2(-150, 80))
	for enemy in [a,b]:
		enemy.set_physics_process(false)
		enemy.encounter_id = 0
		enemy.home_position = enemy.global_position
	game.player.global_position = center + Vector2(150, 0)
	await physics_frame
	await physics_frame
	a._encounter_process(0.01)
	check(a.encounter_state == a.EncounterState.IDLE and b.encounter_state == b.EncounterState.IDLE, "wall prevents group alert")
	game.player.global_position = center + Vector2(-100, 100)
	await physics_frame
	a._encounter_process(0.01)
	check(a.encounter_state == a.EncounterState.CHASE and b.encounter_state == b.EncounterState.CHASE, "visible player alerts group")
	game.player.global_position = center + Vector2(150, 0)
	await physics_frame
	a._encounter_process(0.01)
	check(a.encounter_state == a.EncounterState.SEARCH and a.last_seen.distance_to(center + Vector2(-100, 100)) < 1, "wall causes last seen search")
	print("ENCOUNTER MAPS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

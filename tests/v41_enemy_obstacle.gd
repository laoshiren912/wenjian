extends SceneTree

var game
var failures := 0
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	run.call_deferred()

func tick() -> void:
	await physics_frame
	await process_frame

func run() -> void:
	game = load("res://scenes/main_v41.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	game.debug_opening(true)
	var probe = get_nodes_in_group("enemies")[0]
	var pillar_pos: Vector2 = game.world.lanterns[0].position
	probe.global_position = pillar_pos + Vector2(-60, 25)
	probe.path.clear()
	probe.repath = 0.0
	var avoid: Vector2 = probe._follow_path(pillar_pos + Vector2(60, 25))
	check(absf(avoid.y) > 0.1, "body-width near pillar uses navigation instead of centre-ray shortcut")
	var results := []
	for pillar_index in range(2):
		for side in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			for offset in [-30.0, -25.0, -15.0, 0.0, 15.0, 25.0, 30.0]:
				game.start_room()
				game.debug_opening(true)
				var p = game.player
				p.gm_invulnerable = true
				p.set_physics_process(false)
				var actors := get_nodes_in_group("enemies")
				var e = actors[0]
				for i in range(1, actors.size()):
					actors[i].free()
				e.pair_scheduler = null
				game.scheduler = null
				var pillar: Vector2 = game.world.lanterns[pillar_index].position
				var tangent: Vector2 = side.orthogonal()
				p.position = pillar + side * 75.0 + tangent * offset
				e.position = pillar - side * 55.0 + tangent * offset
				e.encounter_state = e.EncounterState.CHASE
				e.aggro = true
				e.last_seen = p.position
				e.home_position = e.position
				e.path.clear()
				e.repath = 0.0
				var start: Vector2 = e.position
				var turns := 0
				var last := Vector2.ZERO
				var traveled := 0.0
				for frame in range(180):
					var before: Vector2 = e.position
					await tick()
					var motion: Vector2 = e.position - before
					traveled += motion.length()
					if motion.length() > 0.2:
						if last.length() > 0.2 and motion.normalized().dot(last.normalized()) < -0.5:
							turns += 1
						last = motion
					if e.position.distance_to(p.position) < 60.0:
						break
				var progress: float = start.distance_to(p.position) - e.position.distance_to(p.position)
				results.append([pillar_index, side, offset, turns, snappedf(progress, 0.1), snappedf(traveled, 0.1)])
				check(progress > 65.0 and turns <= 3, "obstacle %s %s %s progress %.1f reversals %d" % [pillar_index, side, offset, progress, turns])
	print("ENEMY_OBSTACLE results=", results)
	print("ENEMY_OBSTACLE: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures else 0)

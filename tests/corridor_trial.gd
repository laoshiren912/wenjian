extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	printerr("FAIL: " + message) if not ok else print("PASS: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/corridor_trial.tscn", "F5 starts corridor")
	var room = load("res://scenes/corridor_trial.tscn").instantiate()
	root.add_child(room)
	await process_frame
	room.set_physics_process(false)
	room.player.set_physics_process(false)
	check(room.total == 6 and room.remaining == 6 and room.encounters.is_empty() and not room.world.portal_open, "six pending, no automatic spawn")
	check(room.world.RIGHT - room.world.LEFT + 1 == 16 and room.world.BOTTOM - room.world.TOP + 1 == 4, "fixed narrow corridor")
	var ranged := 0
	for i in range(6):
		var trigger_x: float = room.world.cell_center(Vector2i(room.world.TRIGGER_X[i], 14)).x
		room.player.global_position = Vector2(trigger_x, room.world.cell_center(Vector2i(13, 16)).y)
		room._physics_process(0.01)
		var encounter: Dictionary = room.encounters[i]
		var enemy: SurvivorEnemy = encounter.enemy
		if enemy.kind == SurvivorEnemy.Kind.RANGED: ranged += 1
		check(room.triggered_count == i + 1 and room.encounters.size() == i + 1 and enemy.emerging and enemy.collision_layer == 0, "trigger %d creates exactly one protected enemy from either side" % (i + 1))
		room._physics_process(0.61)
		room.player.global_position = enemy.global_position
		room._physics_process(0.61)
		check(encounter.state == "rising" and enemy.collision_layer == 0, "trigger %d waits for player to leave spawn" % (i + 1))
		room.player.global_position = room.world.cell_center(Vector2i(13, 14))
		room._physics_process(0.01)
		check(encounter.state == "active" and enemy.collision_layer == 4, "trigger %d activates after emergence" % (i + 1))
		enemy.set_physics_process(false)
		room._physics_process(0.01)
		check(room.encounters.size() == i + 1, "trigger %d does not repeat" % (i + 1))
		if i < 5:
			enemy.take_damage(10000, Vector2.ZERO)
			await process_frame
			check(not room.world.portal_open and room.phase == "combat", "portal remains locked after kill %d" % (i + 1))
	check(ranged == 2, "two ranged enemies among six")
	var last: SurvivorEnemy = room.encounters[5].enemy
	last.take_damage(10000, Vector2.ZERO)
	check(room.remaining == 0 and room.world.portal_open and room.phase == "combat", "last kill opens portal without ending run")
	room.player.global_position = room.world.cell_center(room.world.PORTAL_CELL)
	room._physics_process(0.01)
	check(room.phase == "cleared" and room.restart_button.visible, "reaching portal completes trial")
	room.start_room()
	check(room.remaining == 6 and room.triggered_count == 0 and not room.world.portal_open and room.encounters.is_empty(), "restart resets room")
	print("CORRIDOR: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

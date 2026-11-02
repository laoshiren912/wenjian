extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	printerr("FAIL: " + message) if not ok else print("PASS: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	check(ResourceLoader.exists("res://scenes/combat_room.tscn"), "original combat room remains available")
	var room = load("res://scenes/combat_room.tscn").instantiate()
	root.add_child(room)
	await process_frame
	room.set_physics_process(false)
	var seen := {}
	var safe := true
	for run_index in range(80):
		room.start_room()
		seen[room.total] = true
		if room.total not in [5, 6] or room.spawned.size() != room.total:
			safe = false
		for i in range(room.spawned.size()):
			var a: SurvivorEnemy = room.spawned[i]
			var cell: Vector2i = room.world.cell_at(a.global_position)
			if room.world.grid.is_point_solid(cell) or a.global_position.distance_to(room.player.global_position) < 160.0:
				safe = false
			for j in range(i):
				if a.global_position.distance_to(room.spawned[j].global_position) < 100.0:
					safe = false
	check(seen.has(5) and seen.has(6) and safe, "restarts produce 5 or 6 spaced safe spawns")
	check(room.phase == "warning" and get_nodes_in_group("enemies").is_empty() and not room.restart_button.visible, "warning hides enemies from combat and restart")
	var target: SurvivorEnemy = room.spawned[0]
	var health := target.health
	var location := target.global_position
	target.take_damage(999, Vector2.ZERO)
	check(target.health == health and target.collision_layer == 0 and not target.is_physics_processing(), "warning blocks damage, collision and enemy actions")
	room._physics_process(0.61)
	room._physics_process(0.30)
	target.take_damage(999, Vector2.ZERO)
	check(room.phase == "rising" and target.visible and target.visual.scale.y > 0.4 and target.visual.scale.y < 0.6, "enemy visibly rises")
	check(target.health == health and target.collision_layer == 0 and target.global_position == location, "rise remains protected and stationary")
	room._physics_process(0.31)
	check(room.phase == "combat" and get_nodes_in_group("enemies").size() == room.total and target.collision_layer == 4 and target.is_physics_processing(), "enemies activate after emergence")
	check(room.player.dual_attack_enabled and not room.player.weapon.locked and not room.spawned[0].dodge_enabled, "player has sword and bow; dodge off")
	var old_total: int = room.total
	for i in range(old_total - 1):
		room.spawned[i].take_damage(10000, Vector2.ZERO)
	check(room.remaining == 1 and room.phase == "combat" and not room.restart_button.visible, "no early clear")
	room.spawned[old_total - 1].take_damage(10000, Vector2.ZERO)
	check(room.remaining == 0 and room.phase == "cleared" and room.restart_button.visible and "清理完成" in room.status.text, "last kill clears room")
	room.start_room()
	check(room.phase == "warning" and room.remaining == room.total and get_nodes_in_group("enemies").is_empty(), "restart resets phase and pending enemies")
	check(room.restart_button.focus_mode == Control.FOCUS_NONE, "restart button does not capture Space")
	print("COMBAT ROOM: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var room = load("res://scenes/combat_room.tscn").instantiate()
	root.add_child(room)
	await process_frame
	var failures := 0
	for count in [5, 6]:
		while room.total != count:
			room.start_room()
		room.set_physics_process(false)
		room._physics_process(0.61)
		room._physics_process(0.61)
		room.player.set_physics_process(false)
		var enemies: Array = room.spawned.duplicate()
		var starts: Array[float] = []
		var closest: Array[float] = []
		for enemy in enemies:
			var distance: float = enemy.global_position.distance_to(room.player.global_position)
			starts.append(distance)
			closest.append(distance)
		var max_attackers := 0
		for tick in range(300):
			await physics_frame
			var attackers := 0
			for i in range(enemies.size()):
				var enemy = enemies[i]
				closest[i] = minf(closest[i], enemy.global_position.distance_to(room.player.global_position))
				if enemy.melee_action in ["windup", "attack"]: attackers += 1
			max_attackers = maxi(max_attackers, attackers)
		var ok := max_attackers <= 2
		for i in range(enemies.size()):
			if starts[i] - closest[i] < 100.0: ok = false
		if not ok: failures += 1
		print("ROOM CHASE %d: %s, max attackers %d, starts %s, closest %s" % [count, "PASS" if ok else "FAIL", max_attackers, starts, closest])
		room.start_room()
	print("ROOM CHASE RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)

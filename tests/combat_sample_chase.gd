extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var sample = load("res://scenes/combat_sample.tscn").instantiate()
	root.add_child(sample)
	await process_frame
	var failures := 0
	for count in [1, 4, 6]:
		sample.start_sample(count)
		sample.player.set_physics_process(false)
		var enemies := get_nodes_in_group("enemies")
		var initial: Array[float] = []
		for e in enemies: initial.append(e.global_position.distance_to(sample.player.global_position))
		var closest: Array[float] = initial.duplicate()
		var max_attackers := 0
		for tick in range(300):
			await physics_frame
			var attacking := 0
			for i in range(enemies.size()):
				var enemy = enemies[i]
				closest[i] = minf(closest[i], enemy.global_position.distance_to(sample.player.global_position))
				if enemy.melee_action in ["windup", "attack"]: attacking += 1
			max_attackers = maxi(max_attackers, attacking)
		var ok := max_attackers <= 2
		for i in range(enemies.size()):
			if initial[i] - closest[i] < 150.0: ok = false
		print("CHASE %d: %s, max attackers %d, start %s closest %s" % [count, "PASS" if ok else "FAIL", max_attackers, initial, closest])
		if not ok: failures += 1
	print("CHASE RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)

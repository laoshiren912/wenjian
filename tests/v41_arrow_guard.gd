extends SceneTree
var game
var failures := 0
func _initialize(): run.call_deferred()
func tick():
	await physics_frame
	await process_frame
func run():
	game = load("res://scenes/main_v41.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await tick()
	for mode in ["front21", "front30", "rear", "obstacle", "scaled", "thrust", "ranged", "boss"]:
		game.start_room()
		await tick()
		var p = game.player
		var enemies = get_nodes_in_group("enemies")
		var e = enemies[0]
		for i in range(1, enemies.size()): enemies[i].free()
		if mode == "boss":
			game.room_index = 6
			game._enter_room()
			p = game.player
			e = game.boss
		elif mode == "thrust":
			e.thrust_type = true
		elif mode == "ranged":
			e.kind = e.Kind.RANGED
		p.position = Vector2(600, 400)
		e.position = Vector2(690, 400)
		if mode == "obstacle":
			p.position = Vector2(360, 444)
			e.position = Vector2(480, 444)
		e.health = 21.0 if mode == "front21" else 100.0
		if mode == "front30": e.health = 30.0
		if mode == "scaled": p.damage_multiplier = 1.5
		e.encounter_state = e.EncounterState.CHASE
		e.guard_direction = Vector2.RIGHT if mode == "rear" else Vector2.LEFT
		if mode == "rear": e.guard_time = 0.16
		var before: float = e.health
		var hit := {"amount": 0.0, "blocked": true, "count": 0}
		e.damaged.connect(func(_pos, amount): hit.amount = amount; hit.blocked = e.last_hit_blocked; hit.count += 1)
		var started: bool = p.ranged_weapon.attack(Vector2.RIGHT)
		for frame in range(40): await tick()
		var expected: float = 0.0 if mode == "obstacle" else (31.5 if mode == "scaled" else 21.0)
		var ok: bool = started and is_equal_approx(hit.amount, expected) and hit.count == (0 if mode == "obstacle" else 1) and (mode == "obstacle" or not hit.blocked)
		if mode == "front21": ok = ok and (not is_instance_valid(e) or e.dead)
		if mode == "front30": ok = ok and is_instance_valid(e) and is_equal_approx(e.health, before - 21.0)
		if not ok: failures += 1
		print("ARROW ",mode," ok=",ok," result=",hit)
	print("ARROW RESULT failures=",failures)
	quit(1 if failures else 0)

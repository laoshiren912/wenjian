extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var room = load("res://scenes/corridor_trial.tscn").instantiate()
	root.add_child(room)
	await process_frame
	room.set_physics_process(false)
	room._spawn_at_trigger(1)
	room._physics_process(0.61)
	room._physics_process(0.61)
	var enemy: SurvivorEnemy = room.encounters[0].enemy
	room.player.global_position = enemy.global_position - Vector2(150, 0)
	room.player.set_physics_process(false)
	var before: float = room.player.health
	var saw_projectile := false
	for tick in range(90):
		await physics_frame
		for projectile in get_nodes_in_group("projectiles"):
			if projectile.hostile: saw_projectile = true
		if room.player.health < before: break
	var ok: bool = saw_projectile and room.player.health < before and enemy.kind == SurvivorEnemy.Kind.RANGED
	print("CORRIDOR RANGED: ", "PASS" if ok else "FAIL", " projectile=", saw_projectile, " health=", room.player.health)
	quit(0 if ok else 1)

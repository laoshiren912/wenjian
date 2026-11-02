extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_run()
	for enemy in get_nodes_in_group("enemies"):
		enemy.free()
	game.pending_wave.clear()
	var enemies: Array = []
	for i in range(3):
		enemies.append(game._spawn_enemy(SurvivorEnemy.Kind.HOSTILE, game.player.global_position + Vector2(42, 0).rotated(i * TAU / 3.0), false))
	for enemy in enemies:
		enemy.set_physics_process(false)
		enemy._update_melee(0.01, 42.0)
	var started := 0
	for enemy in enemies:
		if enemy.melee_action == "windup":
			started += 1
	var ok := started == 2
	var first = enemies[0]
	first.take_damage(1.0, Vector2.ZERO)
	ok = ok and first.melee_action == "recovery"
	var second = enemies[1]
	second._update_melee(1.0, 42.0)
	ok = ok and second.melee_action == "attack" and not second.melee_released
	second._update_melee(0.3, 42.0)
	ok = ok and second.melee_released
	second._update_melee(1.0, 42.0)
	ok = ok and second.melee_action == "recovery"
	var third = enemies[2]
	third.melee_action = "idle"
	game.player.weapon.swing_time = 0.2
	game.player.weapon.swing_direction = (third.global_position - game.player.global_position).normalized()
	var dodge: Vector2 = third._update_melee(0.01, 42.0)
	ok = ok and third.melee_action == "dodge" and absf(dodge.normalized().dot(game.player.weapon.swing_direction)) < 0.01
	third._update_melee(0.3, 42.0)
	ok = ok and third.melee_action == "recovery" and third.dodge_cooldown > 0.0
	print("MELEE: attack limit, interruption, delayed hit, recovery and dodge: ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)

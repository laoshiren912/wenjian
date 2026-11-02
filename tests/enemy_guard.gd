extends SceneTree
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scenes/main_v31.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	game.start_run()
	for enemy in get_nodes_in_group("enemies"):
		enemy.free()
	game.set_process(false)
	game.player.set_physics_process(false)
	var center: Vector2 = game.player.global_position
	var enemy = game._spawn_enemy(1, center + Vector2(100, 0))
	enemy.set_physics_process(false)
	enemy.guard_cooldown = 0.0
	enemy._physics_process(0.02)
	check(enemy.guard_time > 0.0 and enemy.guard_direction.x < -0.9, "guard faces player")
	var hp: float = enemy.health
	enemy.take_damage(100, Vector2.RIGHT * 155)
	check(is_equal_approx(hp - enemy.health, 35.0) and enemy.guard_time > 0, "front guard reduces damage")
	hp = enemy.health
	enemy.take_damage(30, Vector2.LEFT * 155)
	check(is_equal_approx(hp - enemy.health, 30.0), "rear attack deals full damage")
	enemy._physics_process(0.7)
	check(enemy.guard_time == 0 and enemy.guard_cooldown > 0, "guard ends and has cooldown")
	enemy.free()
	var a = game._spawn_enemy(1, center + Vector2(40, 0))
	var b = game._spawn_enemy(1, center + Vector2(-40, 0))
	var c = game._spawn_enemy(1, center + Vector2(0, 40))
	for e in [a, b, c]:
		e.set_physics_process(false)
		e.guard_cooldown = 5.0
		e.attack_cooldown = 0.0
		e._physics_process(0.01)
	check(a.windup > 0 and b.windup > 0 and c.windup == 0, "only two nearby melee attackers wind up")
	a.windup = 0.0
	c._physics_process(0.01)
	check(c.windup > 0, "waiting enemy can attack after opening")
	for e in [a,b,c]: e.free()
	var guard = game._spawn_enemy(1, center + Vector2(90, 0))
	guard.guard_time = 1.0
	guard.guard_direction = Vector2.LEFT
	game.remaining = 1
	game.pending_wave.clear()
	game.toggle_pause()
	game.set_gm_mode(true)
	game.gm_kill_floor()
	check(guard.dead and game.remaining == 0, "GM kill bypasses guard")
	print("ENEMY GUARD failures: ", failures)
	quit(1 if failures else 0)

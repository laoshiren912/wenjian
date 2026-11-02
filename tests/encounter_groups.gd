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
	var game = load("res://scenes/main_v31.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	game.set_gm_mode(true)
	game.start_run()
	game.set_process(false)
	game.player.set_physics_process(false)
	for floor_number in range(1, 4):
		game.toggle_pause()
		game.gm_select_floor(floor_number)
		var enemies = get_nodes_in_group("enemies")
		check(enemies.size() == floor_number * 4 + 4 and game.remaining == enemies.size(), "floor %d count" % floor_number)
		check(game.pending_wave.is_empty(), "no timed wave")
		var groups := {}
		for enemy in enemies:
			enemy.set_physics_process(false)
			groups[enemy.encounter_id] = groups.get(enemy.encounter_id, 0) + 1
			check(not game.world.path_between(game.player.global_position, enemy.home_position).is_empty(), "reachable home")
		check(groups.size() == floor_number + 1, "group count")
		for n in groups.values(): check(n == 4, "four per group")
	# Use a controlled wall-free area at the centre of a real map.
	for enemy in get_nodes_in_group("enemies"): enemy.free()
	var center: Vector2 = SurvivorWorld.SPAWN
	game.player.global_position = center
	var a = game._spawn_enemy(1, center + Vector2(100, 0))
	var b = game._spawn_enemy(1, center + Vector2(130, 40))
	var c = game._spawn_enemy(1, center + Vector2(-110, 0))
	for e in [a, b, c]:
		e.set_physics_process(false)
		e.home_position = e.global_position
	a.encounter_id = 0
	b.encounter_id = 0
	c.encounter_id = 1
	a._encounter_process(0.01)
	check(a.encounter_state == a.EncounterState.CHASE and b.encounter_state == b.EncounterState.CHASE, "whole group alerted")
	check(c.encounter_state == c.EncounterState.IDLE, "other group stays idle")
	game.player.global_position = center + Vector2(800, 0)
	a._encounter_process(0.01)
	check(a.encounter_state == a.EncounterState.SEARCH and a.last_seen == center, "search last seen")
	a.home_position = center + Vector2(-200, 100)
	a._encounter_process(3.1)
	check(a.encounter_state == a.EncounterState.RETURN, "search expires and return begins")
	game.player.global_position = center
	a._encounter_process(0.01)
	check(a.encounter_state == a.EncounterState.CHASE, "reacquires during return")
	# Aim follows during first half, then stays fixed.
	a.global_position = center + Vector2(50, 0)
	a.windup = 0.8
	a.attack_duration = 0.8
	a.attack_direction = Vector2.UP
	a._encounter_process(0.05)
	var early: Vector2 = a.attack_direction
	check(early != Vector2.UP, "early windup tracks")
	a.windup = 0.3
	game.player.global_position = center + Vector2(0, 40)
	a._encounter_process(0.02)
	check(a.attack_direction.is_equal_approx(early), "late windup locks")
	b.windup = 0.5
	c.encounter_id = 0
	c.windup = 0.5
	a.windup = 0.0
	check(a._encounter_attackers() == 2, "attack slots count group")
	var ranger = game._spawn_enemy(2, center + Vector2(100, 0))
	ranger.encounter_id = 2
	ranger.home_position = ranger.global_position
	ranger.set_physics_process(false)
	game.player.global_position = center
	ranger._encounter_process(0.01)
	check(ranger.velocity.x > 0.0, "ranged retreats when close")
	a.global_position = center + Vector2(100, 0)
	a.guard_direction = Vector2.LEFT
	a.encounter_state = a.EncounterState.CHASE
	a.guard_cooldown = 0.0
	a.windup = 0.0
	a.lunge_time = 0.0
	var health_before: float = a.health
	a.take_damage(40.0, Vector2.RIGHT * 100.0)
	check(is_equal_approx(health_before - a.health, 14.0) and a.guard_time > 0, "front hit triggers guard")
	a.guard_time = 0.0
	a.guard_cooldown = 0.0
	health_before = a.health
	a.take_damage(40.0, Vector2.LEFT * 100.0)
	check(is_equal_approx(health_before - a.health, 40.0), "rear hit avoids guard")
	game.player.gm_invulnerable = false
	game.player.invulnerability = 0.0
	game.player.global_position = center
	a.global_position = center + Vector2(55, 0)
	a.thrust_type = true
	a.knockback = Vector2.ZERO
	a.guard_time = 0.0
	a.windup = 0.01
	a.attack_duration = 0.65
	a.attack_direction = Vector2.LEFT
	var player_health: float = game.player.health
	a._encounter_process(0.02)
	a._encounter_process(0.1)
	check(a.velocity.x < 0.0 and a.lunge_time > 0.0, "melee lunge moves forward")
	a._encounter_process(0.07)
	check(a.attack_cooldown > 0.0 and game.player.health < player_health, "melee hit and recovery")
	ranger.global_position = center + Vector2(250, 0)
	ranger.windup = 0.01
	ranger.attack_duration = 0.85
	ranger.attack_direction = Vector2.LEFT
	var shots_before := get_nodes_in_group("projectiles").size()
	ranger._encounter_process(0.02)
	check(get_nodes_in_group("projectiles").size() == shots_before + 1 and ranger.attack_cooldown > 0, "ranged fires after windup")
	game.player.gm_invulnerable = true
	for e in [a, b, c, ranger]: e.free()
	game.toggle_pause()
	game.gm_select_floor(1)
	game.set_process(true)
	game.toggle_pause()
	game.gm_kill_floor()
	await process_frame
	await process_frame
	check(game.state == game.State.SHOP_PROMPT and game.remaining == 0, "GM clears all stationed enemies and shop opens")
	print("ENCOUNTERS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

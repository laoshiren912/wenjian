extends SceneTree
var failures := 0
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	game.start_run()
	var player = game.player
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	await physics_frame
	var center: Vector2 = player.global_position
	var a = game._spawn_enemy(1, center + Vector2(50, 0))
	var b = game._spawn_enemy(1, center + Vector2(0, 55))
	a.set_physics_process(false)
	b.set_physics_process(false)
	player.manuals.assign([0, 1])
	player.skill_points = 2
	check(player.upgrade_manual(0) and player.manual_levels[0] == 2 and player.skill_points == 1, "manual spends skill point")
	var ha: float = a.health
	var hb: float = b.health
	player.use_manual(0)
	check(is_equal_approx(ha - a.health, 60.0) and is_equal_approx(hb - b.health, 60.0), "upgraded area hits multiple targets")
	check(player.manual_cooldowns[0] > 5.5 and player.manual_cooldowns[0] < 5.7, "upgraded cooldown")
	check(player.try_roll(), "begin roll")
	player.use_manual(1)
	check(player.is_rolling() and player.manual_cooldowns[1] > 0.0, "skill fires while rolling")
	player.manual_cooldowns[0] = 0.0
	player.use_manual(0)
	check(player.manual_cooldowns[0] > 0.0 and player.is_rolling(), "immediate second skill")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	player._unhandled_input(click)
	player._physics_process(0.05)
	check(player._attack_pending, "attack pressed during roll is retained")
	player._finish_roll()
	player.weapon.cooldown = 0.0
	var attacks: int = player.weapon.attack_count
	player._physics_process(0.02)
	check(player.weapon.attack_count == attacks + 1, "queued attack starts after roll")
	var boss = game._spawn_enemy(3, center + Vector2(200, 0))
	boss.set_physics_process(false)
	boss.boss_state = boss.BossState.CIRCLE_WINDUP
	boss.boss_timer = 0.01
	player.gm_invulnerable = false
	player.invulnerability = 0.0
	var hp: float = player.health
	boss._boss_process(0.02)
	check(player.health < hp and boss.boss_state == boss.BossState.RECOVERY, "expanded circle and recovery")
	boss.global_position = center + Vector2(65, 0)
	boss.boss_charge_aim = Vector2.LEFT
	boss.boss_state = boss.BossState.COMBO_WINDUP
	boss.boss_timer = 0.01
	boss.boss_combo_hits = 0
	player.invulnerability = 0.0
	for i in range(3):
		boss._boss_process(0.6)
	check(boss.boss_combo_hits == 3 and boss.boss_state == boss.BossState.RECOVERY, "three attacks and recovery")
	boss.global_position = center + Vector2(200, 0)
	boss.boss_state = boss.BossState.CHARGE_WINDUP
	boss.boss_charge_aim = Vector2.LEFT
	boss.boss_timer = 0.01
	boss._boss_process(0.02)
	player.global_position = center + Vector2(0, 70)
	player.invulnerability = 0.0
	hp = player.health
	for i in range(45):
		boss._boss_process(0.02)
		if boss.boss_state == boss.BossState.RECOVERY:
			break
	check(boss.boss_charge_aim == Vector2.LEFT, "charge direction locked")
	check(player.health == hp, "sideways move dodges charge")
	check(boss.boss_state == boss.BossState.RECOVERY and boss.boss_timer > 0.0, "charge recovery")
	boss.global_position = center + Vector2(120, 0)
	player.global_position = center
	boss.boss_state = boss.BossState.CHARGING
	boss.boss_charge_aim = Vector2.LEFT
	boss.boss_charge_remaining = 240.0
	boss.boss_charge_hit = false
	player.invulnerability = 0.0
	hp = player.health
	for i in range(20):
		boss._boss_process(0.02)
	check(player.health < hp and boss.boss_charge_hit, "charge hits player in path")
	boss.boss_state = boss.BossState.APPROACH
	boss.boss_next_attack = 2
	boss.boss_timer = 0.0
	boss._boss_process(0.02)
	check(boss.boss_state == boss.BossState.CHARGE_WINDUP and boss.boss_charge_distance >= 0.0, "normal charge preparation calculates path")
	paused = false
	game.queue_free()
	await process_frame
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	game.start_run()
	game.remaining = 0
	game._floor_cleared()
	game.open_shop()
	game.claim_manual(0)
	check(game.player.manuals == [0], "floor one grants first manual")
	game.next_floor()
	game.player.gain_experience(90)
	game.show_stats()
	game.upgrade_manual(0)
	check(game.player.manual_levels[0] == 2 and game.player.skill_points == 1, "earned points spent through stats screen")
	game.resume_run()
	game.remaining = 0
	game._floor_cleared()
	game.open_shop()
	game.claim_manual(1)
	check(game.player.manuals == [0, 1], "floor two grants second manual")
	game.next_floor()
	check(game.floor_number == 3 and game.player.manuals.size() == 2, "both manuals available on floor three")
	game.remaining = 0
	game._floor_cleared()
	game.open_shop()
	game.next_floor()
	check(game.floor_number == 4 and game.player.manual_levels[0] == 2, "boss floor preserves build")
	print("V31 ROUND2: %d checks, %d failures" % [checks, failures])
	paused = false
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)

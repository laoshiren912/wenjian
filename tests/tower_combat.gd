extends SceneTree

var checks := 0
var failures := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for profession in range(3):
		var game = load("res://scenes/main.tscn").instantiate()
		root.add_child(game)
		await process_frame
		game.select_profession(profession)
		game.start_run()
		game.player.apply_upgrade(3)
		game.player.apply_upgrade(4)
		match profession:
			0: check(game.player.extra_targets == 1 and game.player.angle_bonus == 30.0, "sword cards")
			1: check(game.player.reach_bonus == 25.0 and game.player.angle_bonus == 20.0, "spear cards")
			2:
				check(game.player.extra_arrows == 1 and game.player.projectile_speed_bonus == 120.0, "bow cards")
				game.player.weapon.attack(Vector2.RIGHT)
				check(get_nodes_in_group("projectiles").size() == 2, "bow fires extra arrow")
		paused = false
		game.queue_free()
		await process_frame
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_run()
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	await process_frame
	var ranged = game._spawn_enemy(SurvivorEnemy.Kind.RANGED, game.player.global_position + Vector2(250, 0))
	ranged.attack_cooldown = 0
	await physics_frame
	await physics_frame
	var shots = get_nodes_in_group("projectiles")
	check(shots.size() > 0 and shots[0].hostile, "ranged fires hostile projectile")
	for shot in shots:
		shot.queue_free()
	ranged.queue_free()
	await process_frame
	var boss = game._spawn_enemy(SurvivorEnemy.Kind.BOSS, game.player.global_position + Vector2(100, 0))
	boss.special_cooldown = 0
	await physics_frame
	await physics_frame
	check(boss.special_windup > 0.0, "boss warning begins")
	var old_health: float = game.player.health
	boss.special_windup = 0.001
	await physics_frame
	await physics_frame
	check(game.player.health < old_health, "boss attack damages player")
	paused = false
	game.queue_free()
	await process_frame
	print("TOWER COMBAT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

extends SceneTree

var failures := 0
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	printerr("FAIL: " + message) if not ok else print("PASS: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var sample = load("res://scenes/combat_sample.tscn").instantiate()
	root.add_child(sample)
	await process_frame
	var enemy: SurvivorEnemy = get_first_node_in_group("enemies")
	enemy.set_physics_process(false)
	var player: SurvivorPlayer = sample.player
	player.set_physics_process(false)
	player.global_position = sample.world.cell_center(Vector2i(16, 12))
	enemy.global_position = sample.world.cell_center(Vector2i(20, 12))
	await physics_frame
	await physics_frame
	var bow: SurvivorWeapon = player.ranged_weapon
	var before := enemy.health
	check(bow.attack(Vector2.RIGHT), "arrow fired at wall")
	for i in range(60): await physics_frame
	check(is_equal_approx(enemy.health, before) and get_nodes_in_group("projectiles").is_empty(), "wall blocks arrow")
	enemy.global_position = sample.world.cell_center(Vector2i(17, 14))
	player.global_position = sample.world.cell_center(Vector2i(15, 14))
	await physics_frame
	check(bow.attack(Vector2.RIGHT), "arrow fired at enemy")
	for i in range(30): await physics_frame
	check(enemy.health < before, "arrow damages enemy")
	before = enemy.health
	player.global_position = sample.world.cell_center(Vector2i(16, 14))
	enemy.global_position = player.global_position + Vector2(65, 0)
	await physics_frame
	check(player.weapon.attack(Vector2.RIGHT), "sword starts near enemy")
	for i in range(25): await physics_frame
	check(enemy.health < before, "sword damages enemy during thrust")
	# Synthetic overlap with the wall is necessary to put both centers within the
	# 63 px attack radius while still placing solid geometry between them.
	enemy.global_position = Vector2(1145, 800)
	player.global_position = Vector2(1205, 800)
	enemy.melee_action = "attack"
	enemy.melee_duration = 0.6
	enemy.melee_timer = 0.6
	enemy.melee_released = false
	enemy.attack_direction = Vector2.RIGHT
	var health := player.health
	await physics_frame
	enemy._update_melee(0.3, 60.0)
	check(is_equal_approx(player.health, health), "enemy attack does not hit through wall")
	print("SAMPLE COLLISION: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

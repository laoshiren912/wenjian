extends SceneTree

# Runs the real scenes and physics with deterministic fixtures; never loaded by the game.
var game: SurvivorGame
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func frames(count: int) -> void:
	for index in range(count):
		await physics_frame
	await process_frame

func clear_enemies() -> void:
	for enemy in get_nodes_in_group("enemies"):
		enemy.free()
	for pickup in get_nodes_in_group("pickups"):
		pickup.free()

func enemy_at(offset: Vector2, kind: int = SurvivorEnemy.Kind.HOSTILE) -> SurvivorEnemy:
	var enemy := game._spawn_enemy(kind, game.player.position + offset)
	enemy.set_physics_process(false)
	return enemy

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func aim_right() -> void:
	game.player.camera.reset_smoothing()
	await frames(2)
	var event := InputEventMouseMotion.new()
	event.position = game.player.get_global_transform_with_canvas().origin + Vector2(200, 0)
	event.global_position = event.position
	Input.parse_input_event(event)
	await frames(2)

func fire_once() -> void:
	game.player.weapon.cooldown = 0.0
	game.player.stamina = 100.0
	Input.action_press("attack")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = root.get_mouse_position()
	root.push_input(press, true)
	await frames(2)
	Input.action_release("attack")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = press.position
	root.push_input(release, true)
	await frames(2)

func _run() -> void:
	# Headless Windows defaults to a 64x64 window; match the playable viewport.
	root.size = Vector2i(1280, 720)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	check(game.state == SurvivorGame.State.START and paused, "Start screen pauses the world")
	game.hud.start_requested.emit()
	await frames(3)
	check(game.state == SurvivorGame.State.PLAYING and not paused, "Start button enters playable state")
	clear_enemies()
	game.spawn_timer = 9999.0
	var start: Vector2 = game.player.position
	Input.action_press("move_right")
	await frames(20)
	Input.action_release("move_right")
	check(game.player.position.x > start.x + 55.0, "WASD movement updates the physical player")
	var straight_distance: float = game.player.position.distance_to(start)
	game.player.position = start
	Input.action_press("move_right")
	Input.action_press("move_down")
	await frames(20)
	Input.action_release("move_right")
	Input.action_release("move_down")
	check(absf(game.player.position.distance_to(start) - straight_distance) < 8.0, "Diagonal speed is normalized")
	game.player.position = Vector2(100, 640)
	Input.action_press("move_left")
	await frames(35)
	Input.action_release("move_left")
	check(game.player.position.x >= 77.0, "Boundary collision stops movement")
	game.player.position = SurvivorWorld.SPAWN
	await aim_right()
	check(game.player.aim_direction.dot(Vector2.RIGHT) > 0.99, "Mouse position drives aim")
	var sword_target := enemy_at(Vector2(70, 0))
	var sword_side := enemy_at(Vector2(55, 45))
	var behind := enemy_at(Vector2(-55, 0))
	await key(KEY_1)
	await fire_once()
	check(game.player.weapon.selected == 0 and is_equal_approx(sword_target.health, sword_target.max_health - 52.0), "Sword deals 52 damage to the nearest target")
	check(is_equal_approx(sword_side.health, sword_side.max_health), "Sword hits only one enemy, even with two in its cone")
	check(is_equal_approx(behind.health, behind.max_health), "Sword does not hit behind player")
	check(is_equal_approx(game.player.stamina, 84.0), "Sword spends 16 stamina")
	var count: int = game.player.weapon.attack_count
	check(not game.player.weapon.attack(Vector2.RIGHT) and count == game.player.weapon.attack_count, "Cooldown prevents extra attacks")
	clear_enemies()
	var spear_target := enemy_at(Vector2(135, 0))
	var spear_side := enemy_at(Vector2(105, 40))
	var spear_outside := enemy_at(Vector2(70, 80))
	await key(KEY_2)
	await fire_once()
	check(game.player.weapon.selected == 1 and is_equal_approx(spear_target.health, spear_target.max_health - 32.0), "Key 2 selects longer spear with lower 32 damage per target")
	check(is_equal_approx(spear_side.health, spear_side.max_health - 32.0), "Spear damages multiple enemies in its cone")
	check(is_equal_approx(spear_outside.health, spear_outside.max_health) and is_equal_approx(game.player.stamina, 77.0), "Spear respects cone edges and costs 23 stamina once per attack")
	await key(KEY_3)
	check(SurvivorWeapon.DATA.size() == 2 and game.player.weapon.selected == 1, "Staff is removed; key 3 does not select a weapon")
	game.player.weapon.cooldown = 0.0
	game.player.stamina = 0.0
	check(not game.player.weapon.attack(Vector2.RIGHT), "Insufficient stamina blocks attacks")
	await frames(90)
	check(game.player.stamina > 20.0, "Stamina recovers after the recovery delay")
	clear_enemies()
	# A solid pillar blocks spear attacks.
	var wall_cell := Vector2i.ZERO
	for cell in game.world.blocked:
		if cell.x > 2 and cell.x < 37 and cell.y > 2 and cell.y < 27:
			wall_cell = cell
			break
	var wall_center: Vector2 = game.world.cell_center(wall_cell)
	game.player.position = wall_center - Vector2(55, 0)
	await aim_right()
	var shielded := enemy_at(Vector2(110, 0))
	await key(KEY_2)
	await fire_once()
	check(is_equal_approx(shielded.health, shielded.max_health), "Melee cannot hit through a wall")
	clear_enemies()
	game.player.position = wall_center - Vector2(120, 0)
	game.player.invulnerability = 99.0
	var navigator := game._spawn_enemy(SurvivorEnemy.Kind.HOSTILE, wall_center + Vector2(120, 0))
	navigator.aggro = true
	await frames(360)
	check(navigator.position.distance_to(game.player.position) < 65.0, "Enemy physically navigates around an obstructing pillar")
	clear_enemies()
	game.player.position = SurvivorWorld.SPAWN
	game.player.invulnerability = 0.0
	var passive := game._spawn_enemy(SurvivorEnemy.Kind.PASSIVE, game.player.position + Vector2(100, 0))
	var hostile := game._spawn_enemy(SurvivorEnemy.Kind.HOSTILE, game.player.position + Vector2(210, 0))
	await frames(35)
	check(not passive.aggro and is_equal_approx(game.player.health, 100.0), "Passive enemy does not initiate combat")
	check(hostile.aggro and hostile.position.distance_to(game.player.position) < 205.0, "Hostile enemy detects and pursues player")
	passive.take_damage(1.0, Vector2.ZERO)
	check(passive.aggro, "Passive enemy retaliates after being hit")
	await frames(90)
	check(game.player.health < 100.0, "Enemy windup resolves into player damage")
	var health: float = game.player.health
	check(not game.player.take_damage(9.0, Vector2.RIGHT) and is_equal_approx(health, game.player.health), "Player invulnerability prevents repeated damage")
	clear_enemies()
	game.player.position = SurvivorWorld.SPAWN
	game.player.invulnerability = 0.0
	game.player.knockback = Vector2.ZERO
	game.player.health = 100.0
	# Actual kill signal -> deferred pickup -> attraction -> XP -> modal UI.
	for index in range(2):
		var victim := enemy_at(Vector2(25 + index * 5, 0))
		victim.take_damage(10000.0, Vector2.ZERO)
	await frames(15)
	check(game.kills >= 2 and game.player.total_experience == 20, "Enemy deaths drop pickups that grant experience")
	check(game.player.level == 2 and game.state == SurvivorGame.State.LEVEL_UP and paused, "XP threshold opens three-choice level UI and pauses combat")
	var elapsed_before: float = game.elapsed
	await frames(25)
	check(is_equal_approx(elapsed_before, game.elapsed), "Survival timer stops while choosing upgrades")
	game.hud.level_ui.choices[0].pressed.emit()
	await frames(2)
	check(is_equal_approx(game.player.damage_multiplier, 1.2) and not paused, "Damage choice applies and resumes combat")
	# Exercise the actual numeric-key path for the other two upgrade choices.
	game.player.gain_experience(game.player.next_level_xp)
	await frames(2)
	await key(KEY_2)
	check(is_equal_approx(game.player.attack_speed_multiplier, 1.15) and not paused, "Speed choice works through key 2")
	game.player.health = 60.0
	game.player.gain_experience(game.player.next_level_xp)
	await frames(2)
	await key(KEY_3)
	check(is_equal_approx(game.player.max_health, 125.0) and is_equal_approx(game.player.health, 100.0), "Health choice raises maximum and heals")
	clear_enemies()
	game.player.position = SurvivorWorld.SPAWN
	await aim_right()
	var upgraded := enemy_at(Vector2(65, 0))
	await key(KEY_1)
	await fire_once()
	check(is_equal_approx(upgraded.health, upgraded.max_health - 52.0 * 1.2), "Damage upgrade affects real sword hits")
	check(game.player.weapon.cooldown < 0.48 / 1.15, "Speed upgrade shortens real attack cooldown")
	clear_enemies()
	await key(KEY_TAB)
	check(game.state == SurvivorGame.State.PAUSED and paused and game.stats_open, "Tab opens attributes and pauses combat")
	await key(KEY_TAB)
	check(game.state == SurvivorGame.State.PLAYING and not paused, "Tab closes attributes and resumes combat")
	await key(KEY_ESCAPE)
	check(paused and game.state == SurvivorGame.State.PAUSED, "Escape opens pause menu")
	await key(KEY_ESCAPE)
	check(not paused, "Escape resumes combat")
	# Check every floor cell is connected to spawn, over several map seeds.
	for seed_value in [1, 17, 2026]:
		var test_world := SurvivorWorld.new()
		root.add_child(test_world)
		test_world.build(seed_value)
		var connected: bool = true
		for cell in test_world.floor_cells:
			if test_world.path_between(SurvivorWorld.SPAWN, test_world.cell_center(cell)).is_empty():
				connected = false
				break
		check(connected, "All walkable cells are reachable, map seed %d" % seed_value)
		test_world.free()
	# Complete an entire run through normal scene processing, at fixed timestep.
	game.elapsed = 0.0
	game.player.health = game.player.max_health
	game.player.invulnerability = 999.0
	game.spawn_timer = 0.0
	for second in range(182):
		if game.state == SurvivorGame.State.LEVEL_UP:
			game.hud.level_ui.choices[0].pressed.emit()
		await frames(60)
		if second % 30 == 0:
			print("SOAK: %d seconds, %d enemies" % [second, get_nodes_in_group("enemies").size()])
	check(game.state == SurvivorGame.State.WON and paused and is_equal_approx(game.elapsed, 180.0), "Full 180-second session reaches completion without blocking")
	check(get_nodes_in_group("enemies").size() <= 28, "Enemy population stays bounded during full session")
	game.hud.restart_requested.emit()
	await frames(4)
	game = current_scene
	check(game.state == SurvivorGame.State.START and game.kills == 0 and game.player.level == 1 and is_equal_approx(game.elapsed, 0.0), "Result restart reloads a clean new session")
	game.start_run()
	game.player.invulnerability = 0.0
	game.player.take_damage(999.0, Vector2.RIGHT)
	await frames(2)
	check(game.player.dead and game.state == SurvivorGame.State.DEAD and paused, "Zero health opens death result and freezes combat")
	await key(KEY_R)
	await frames(4)
	game = current_scene
	check(game.state == SurvivorGame.State.START and not game.player.dead and is_equal_approx(game.player.health, 100.0), "R after death restarts with restored player")
	print("RESULT: %d checks, %d failures" % [checks, failures])
	paused = false
	quit(0 if failures == 0 else 1)

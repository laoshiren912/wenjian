extends SceneTree

const CONFIG = preload("res://scripts/v41_config.gd")
const Trace = preload("res://scripts/v41_dash_trace.gd")
const ORIGIN := Vector2(460, 397)
var game
var player
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)

func frames(n: int) -> void:
	for i in range(n):
		await physics_frame
	await process_frame

func button(index: MouseButton, pressed: bool, point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = index
	event.pressed = pressed
	event.position = root.get_canvas_transform() * point
	event.global_position = event.position
	root.push_input(event, true)

func tap(index: MouseButton, point: Vector2) -> void:
	button(index, true, point)
	button(index, false, point)

func space(point: Vector2, held = null) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = root.get_canvas_transform() * point
	root.push_input(motion, true)
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	event.physical_keycode = KEY_SPACE
	event.pressed = true if held == null else held
	root.push_input(event, true)
	if held == null:
		event = event.duplicate()
		event.pressed = false
		root.push_input(event, true)

func traces() -> Array:
	return game.world.actors.get_children().filter(func(child): return child is Trace and not child.is_queued_for_deletion())

func fresh(rank: int = 0) -> Array[Node]:
	game.start_room()
	player = game.player
	player.position = ORIGIN
	player.cultivation = rank
	game.scheduler = null
	var enemies := get_nodes_in_group("enemies")
	for i in range(enemies.size()):
		var enemy: SurvivorEnemy = enemies[i]
		enemy.set_physics_process(false)
		enemy.position = Vector2(930, 410 + i * 45)
		enemy.health = 1000.0
		enemy.max_health = 1000.0
		enemy.guard_cooldown = 10.0
	return enemies

func run() -> void:
	game = load("res://scenes/main_v41.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frames(2)
	check(game.phase == "combat" and not paused and game.reward_options.is_empty(), "F5 opens directly in combat")
	check(get_nodes_in_group("enemies").size() == 4 and game.player.cultivation == 0, "first wave and base cultivation")
	await check_growth()
	await check_group_dashes()
	await check_terrain()
	await check_interrupts()
	await check_action_links()
	await check_combo()
	print("V41 MOVES: %d / %d passed" % [checks - failures, checks])
	game.free()
	await process_frame
	quit(1 if failures else 0)

func check_growth() -> void:
	var enemies := fresh()
	for i in range(3):
		enemies[i].take_damage(2000.0, Vector2.ZERO)
		check(player.cultivation == [0, 1, 2][i] and game.run_kills == i + 1, "natural cultivation kill %d" % (i + 1))
	game._debug_menu()
	game.debug_cultivation(0)
	check(player.cultivation == 0 and game.run_kills == 3, "GM changes rank without changing kills")
	game.debug_cultivation(-1)
	check(player.cultivation == 2, "GM restores earned rank")
	game.debug_close()
	enemies[3].take_damage(2000.0, Vector2.ZERO)
	check(game.phase == "reward_select" and game.reward_options.size() == 3 and game.reward_options.all(func(index): return index < 4), "regular reward after clearing room")
	game.reward_options.assign([0, 1, 2])
	game.select_reward(0)
	check(is_equal_approx(player.combo.stages[0].damage, 41.6) and player.cultivation == 2, "attribute cards apply independently of rank")
	game._apply_rewards()
	check(is_equal_approx(player.combo.stages[0].damage, 41.6), "reapplying rewards does not compound")
	await frames(2)

func check_group_dashes() -> void:
	for rank in range(3):
		var enemies := fresh(rank)
		var near: SurvivorEnemy = enemies[0]
		var middle: SurvivorEnemy = enemies[1]
		var far: SurvivorEnemy = enemies[2]
		var outside: SurvivorEnemy = enemies[3]
		var distance: float = CONFIG.DASH_DISTANCE[rank]
		near.position = ORIGIN + Vector2(distance * 0.23, 8)
		middle.position = ORIGIN + Vector2(distance / 3.0, -9)
		far.position = ORIGIN + Vector2(distance * 0.86, 5)
		outside.position = ORIGIN + Vector2(distance * 0.5, CONFIG.DASH_MARK_WIDTH[rank] + 45.0)
		await frames(2)
		var aim := ORIGIN + Vector2(390, 0)
		space(aim, true)
		await frames(2)
		check(player.dash_state == player.Dash.WINDUP and player.position.is_equal_approx(ORIGIN), "press starts stationary windup %d" % rank)
		check(is_equal_approx(player.stamina, 80.0) and player.invulnerability == 0.0, "one stamina cost and no invulnerability %d" % rank)
		await frames(18)
		var trace: Trace = traces()[0]
		check(absf(trace.tip.x - ORIGIN.x - distance) < 0.9 and absf(trace.tip.y - ORIGIN.y) < 0.8, "real shape travels declared distance and stays on line %d" % rank)
		check(trace.sealed and trace.marks.size() == [0, 1, 3][rank], "correct seal and mark count %d" % rank)
		for enemy in [near, middle, far]:
			check(is_equal_approx(1000.0 - enemy.health, CONFIG.DASH_DAMAGE[rank]), "along-path direct hit exactly once %d" % rank)
		var end: Vector2 = player.position
		space(aim)
		await frames(50)
		var total: float = CONFIG.DASH_DAMAGE[rank] + CONFIG.DASH_MARK_DAMAGE[rank]
		for enemy in [near, middle, far]:
			check(is_equal_approx(1000.0 - enemy.health, total), "separate mark hit dedupes overlaps %d" % rank)
		check(outside.health == 1000.0 and traces().is_empty(), "off-strip enemy safe and traces expire %d" % rank)
		check(player.position.distance_to(end) < 5.0 and player.stamina <= 86.0, "repeated press ignored during cooldown %d" % rank)
		space(aim, false)
		await frames(103)
		check(traces().is_empty() and player.dash_state == player.Dash.IDLE and not player.combo.charging, "holding then releasing never repeats or charges")

func check_terrain() -> void:
	var enemies := fresh(2)
	var obstacle: StaticBody2D = game.world.room1_obstacles[0]
	var axis := Vector2.RIGHT
	var start := obstacle.position - axis * 115.0
	player.position = start
	enemies[0].position = obstacle.position + axis * 98.0
	await frames(2)
	var probe := PhysicsRayQueryParameters2D.create(start, enemies[0].position, player.terrain_mask)
	var wall: Dictionary = player.get_world_2d().direct_space_state.intersect_ray(probe)
	check(not wall.is_empty(), "obstacle crosses the test line")
	space(obstacle.position + axis * 170.0)
	await frames(42)
	check(not wall.is_empty() and player.position.x <= float(wall.position.x) - 12.0 and player.position.x > start.x, "real obstacle truncates at hull edge")
	check(enemies[0].health == 1000.0, "obstacle protects enemy behind it")
	fresh(2)
	player.position = Vector2(650, 463)
	await frames(2)
	space(Vector2(650, 710))
	await frames(42)
	check(player.position.y < 700.0 and Geometry2D.is_point_in_polygon(player.position, game.world.walkable), "room perimeter keeps dash inside walkable boundary")

func check_interrupts() -> void:
	fresh(2)
	await frames(2)
	player.stamina = 19.0
	space(ORIGIN + Vector2.RIGHT * 200.0)
	await frames(3)
	check(traces().is_empty() and player.dash_cooldown == 0.0, "insufficient stamina does not consume cooldown")
	player.stamina = 100.0
	space(ORIGIN + Vector2.RIGHT * 200.0)
	await frames(10)
	check(player.dash_state == player.Dash.TRAVEL and not player.try_roll(), "space cannot cancel committed travel")
	check(player.take_damage(5.0, Vector2.UP), "real damage interrupts without invulnerability")
	check(player.dash_state == player.Dash.IDLE and player.dash_cooldown > 0.0, "damage interrupts while keeping the cost and cooldown")
	check(traces().is_empty() or traces()[0].marks.is_empty(), "interrupted travel creates no delayed hit")
	fresh(2)
	await frames(2)
	space(ORIGIN + Vector2.RIGHT * 320.0)
	await frames(21)
	check(traces().size() == 1 and traces()[0].marks.size() == 3, "lethal cleanup fixture has pending marks")
	player.take_damage(1000.0, Vector2.ZERO)
	check(paused and game.phase == "dead" and traces().is_empty(), "death clears pending sword marks")
	var key := InputEventKey.new()
	key.keycode = KEY_R
	key.pressed = true
	root.push_input(key, true)
	check(not paused and game.player.cultivation == 0 and game.run_kills == 0 and game.player.dash_cooldown == 0.0, "R opens fresh rank-zero combat")

func check_combo() -> void:
	var enemies := fresh(0)
	var enemy: SurvivorEnemy = enemies[0]
	enemy.position = ORIGIN + Vector2(70, 0)
	await frames(2)
	var aim := ORIGIN + Vector2(300, 0)
	tap(MOUSE_BUTTON_LEFT, aim)
	await frames(12)
	tap(MOUSE_BUTTON_LEFT, aim)
	await frames(22)
	tap(MOUSE_BUTTON_LEFT, aim)
	await frames(28)
	check(player.combo.attack_count == 3 and player.combo.stage == 2, "three left clicks buffer through active frames")
	check(is_equal_approx(1000.0 - enemy.health, 132.0), "32/40/60 base damage on real target")
	check(enemy.v41_heavy_stun > 0.0 and enemy.guard_visual_time == 0.0, "third hit interrupts and clears guard")
	for rank in range(3):
		for index in range(8):
			fresh(rank)
			var sword = player.combo
			var aim_direction := Vector2.from_angle(index * PI / 4.0)
			sword.swing_direction = aim_direction
			sword.swing_rank = rank
			for stage in range(3):
				sword.stage = stage
				var segment: PackedVector2Array = sword.blade_segment(1.0 if stage == 2 else 0.5)
				var display: PackedVector2Array = sword.display_segment(1.0 if stage == 2 else 0.5)
				var hand: Vector2 = player.visual.sword_hand(aim_direction, stage, 1.0 if stage == 2 else 0.5)
				var blade := display[0] - hand
				check(blade.length() >= 20.0 and blade.length() <= 32.0,
					"existing straight blade length rank=%d row=%d stage=%d" % [rank, index, stage])
				check(blade.normalized().dot(hand.direction_to(segment[1])) > 0.999 and segment[1].is_equal_approx(display[1]) and segment[1].dot(aim_direction) > 80.0,
					"eight-way hand anchor and shared reach rank=%d row=%d stage=%d" % [rank, index, stage])

func check_action_links() -> void:
	fresh(1)
	await frames(2)
	var aim := ORIGIN + Vector2.RIGHT * 380.0
	button(MOUSE_BUTTON_LEFT, true, aim)
	await frames(8)
	space(aim)
	await frames(3)
	check(player.combo.swing_time > 0.0 and not player.dash_request.is_zero_approx() and player.dash_state == player.Dash.IDLE,
		"Space queues without cancelling a committed primary")
	await frames(11)
	check(player.dash_state == player.Dash.WINDUP and player.combo.next_stage == 0, "buffered Space starts after primary recovery and clears chain")
	button(MOUSE_BUTTON_LEFT, false, aim)
	await frames(22)
	check(player.dash_state == player.Dash.RECOVERY, "dash has a terminal recovery")
	tap(MOUSE_BUTTON_LEFT, aim)
	await frames(7)
	check(player.dash_state == player.Dash.IDLE and player.combo.attack_count == 2 and player.combo.stage == 0, "late recovery buffers a new first swing")
	await frames(25)
	check(player.combo.attack_count == 2, "holding and the delayed release did not auto repeat")

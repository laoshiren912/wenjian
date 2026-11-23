extends SceneTree

const CONFIG = preload("res://scripts/v41_config.gd")
const Trace = preload("res://scripts/v41_dash_trace.gd")
const ORIGIN := Vector2(460, 397)
const CAPTURES := "res://artifacts/runtime/v41-aim-and-cooldown/"
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

func mouse_motion(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = root.get_canvas_transform() * point
	root.push_input(motion, true)

func space(point: Vector2, held = null) -> void:
	mouse_motion(point)
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
	await check_split_controls()
	print("V41 MOVES: %d / %d passed" % [checks - failures, checks])
	game.free()
	await process_frame
	quit(1 if failures else 0)

func check_growth() -> void:
	var enemies := fresh()
	# 第一关 3 击杀仍处于凡剑期。
	for i in range(3):
		enemies[i].take_damage(2000.0, Vector2.ZERO)
		check(player.cultivation == 0 and game.run_kills == i + 1, "natural cultivation kill %d stays rank 0" % (i + 1))
	# 验证达到对应击杀阈值后突破。
	game.room_index = 2
	game.run_kills = int(CONFIG.CULTIVATION_KILLS[1]) - 1
	player.cultivation = game._cultivation_rank()
	check(player.cultivation == 0, "just below rank 1 threshold stays rank 0")
	game.run_kills = int(CONFIG.CULTIVATION_KILLS[1])
	player.cultivation = game._cultivation_rank()
	check(player.cultivation == 1, "reaches rank 1 at threshold %d" % CONFIG.CULTIVATION_KILLS[1])
	game.room_index = 4
	game.run_kills = int(CONFIG.CULTIVATION_KILLS[2])
	player.cultivation = game._cultivation_rank()
	check(player.cultivation == 2, "reaches rank 2 at threshold %d" % CONFIG.CULTIVATION_KILLS[2])
	game._debug_menu()
	game.debug_cultivation(0)
	check(player.cultivation == 0 and game.run_kills == int(CONFIG.CULTIVATION_KILLS[2]), "GM changes rank without changing kills")
	game.debug_cultivation(-1)
	check(player.cultivation == 2, "GM restores earned rank")
	game.room_index = 0
	player.cultivation = game._cultivation_rank()
	game.debug_close()
	enemies[3].take_damage(2000.0, Vector2.ZERO)
	check(game.phase == "exit_ready" and not paused and game.world.portal_open, "room clear opens exit portal without forced modal")
	player.position = game.world.exit_point
	await frames(2)
	check(game.phase == "reward_select" and paused and game.reward_options.size() == 3 and game.reward_options.all(func(index): return index < 4), "stepping into exit portal opens regular reward")
	game.reward_options.assign([0, 1, 2])
	game.select_reward(0)
	await frames(2)
	player = game.player
	check(game.room_index == 1 and player.card_level(0) == 1 and player.cultivation == 0, "room two remains at basic rank and carries the chosen card")
	game._apply_rewards()
	check(player.card_level(0) == 1 and is_equal_approx(player.combo.stages[0].damage, 32.0), "reapplying cards leaves levels and base damage unchanged")
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
	check(not paused and game.phase == "defeat_transition" and traces().is_empty(), "death clears pending sword marks before the result")
	await frames(35)
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
	await frames(6)
	space(aim)
	await frames(2)
	check(player.combo.swing_time > 0.0 and not player.dash_request.is_zero_approx() and player.dash_state == player.Dash.IDLE,
		"Space queues without cancelling active primary frames")
	await frames(6)
	check(player.dash_state == player.Dash.WINDUP and player.combo.next_stage == 1,
		"buffered Space cancels primary recovery immediately and preserves next combo stage")
	button(MOUSE_BUTTON_LEFT, false, aim)
	await frames(18)
	check(player.dash_state == player.Dash.RECOVERY, "dash has a terminal recovery")
	tap(MOUSE_BUTTON_LEFT, aim)
	await frames(7)
	check(player.dash_state == player.Dash.IDLE and player.combo.attack_count == 2 and player.combo.stage == 1,
		"late recovery buffers the preserved second swing")
	await frames(25)
	check(player.combo.attack_count == 2, "holding and the delayed release did not auto repeat")
	# 路线1：左键1 -> 穿阵 -> 落地接左键2 -> 紧接着左键3重劈
	fresh(1)
	await frames(2)
	tap(MOUSE_BUTTON_LEFT, aim)
	await frames(12)
	space(aim)
	await frames(22)
	tap(MOUSE_BUTTON_LEFT, aim)
	await frames(7)
	check(player.combo.stage == 1, "route1: dash after first hit chains into second swing")
	await frames(14)
	tap(MOUSE_BUTTON_LEFT, aim)
	await frames(14)
	check(player.combo.stage == 2, "route1: second swing after dash continues into third finisher")
	# 路线2：左键1 -> 左键2 -> 瞬间穿阵 -> 落地直接接左键3重劈
	fresh(1)
	await frames(2)
	tap(MOUSE_BUTTON_LEFT, aim)
	await frames(16)
	tap(MOUSE_BUTTON_LEFT, aim)
	await frames(18) # 第二击刚过有效帧进入 recovery
	space(aim)
	await frames(2)
	check(player.dash_state == player.Dash.WINDUP and player.combo.next_stage == 2,
		"second hit recovery cancels into dash and preserves finisher")
	await frames(22)
	tap(MOUSE_BUTTON_LEFT, aim)
	await frames(7)
	check(player.combo.stage == 2, "dash after second hit chains into third finisher")
	# 落地超时未按左键后重置回第 1 段
	fresh(1)
	await frames(2)
	tap(MOUSE_BUTTON_LEFT, aim)
	await frames(12)
	space(aim)
	await frames(60) # 完整走完穿阵并超过 DASH_CHAIN_WINDOW (0.42s)
	tap(MOUSE_BUTTON_LEFT, aim)
	await frames(4)
	check(player.combo.stage == 0, "dash chain expires back to first swing after window")

func check_split_controls() -> void:
	var capture := "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	if capture:
		root.size = Vector2i(1280, 720)
		DirAccess.make_dir_recursive_absolute(CAPTURES)
	game.enter_title_screen()
	check(not game.player.aim_marker.visible, "aim marker hidden at the title")
	for rank in range(3):
		var enemies := fresh(rank)
		await frames(2)
		check(player.aim_marker.visible and player.aim_marker.can_process(), "aim marker in combat")
		var origin: Vector2 = player.global_position
		var click_point := origin + Vector2.RIGHT * 140.0
		enemies[0].position = origin + Vector2(88, 17)
		Input.action_press("move_left")
		tap(MOUSE_BUTTON_LEFT, click_point)
		check(player.visual.look_direction.is_equal_approx(Vector2.RIGHT), "left click immediately faces the cursor")
		await frames(9)
		check(player.combo.swing_direction.is_equal_approx(Vector2.RIGHT) and player.position.x < origin.x
			and is_equal_approx(player.position.y, origin.y), "retreat left while slashing right at rank %d" % rank)
		if capture and rank == 1:
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			check(image.save_png(CAPTURES + "01-retreating-slash.png") == OK, "native retreating slash capture")
		var second_point: Vector2 = player.global_position + Vector2.DOWN * 100.0
		tap(MOUSE_BUTTON_LEFT, second_point)
		mouse_motion(origin + Vector2.UP * 200.0)
		await frames(18)
		check(player.combo.stage == 1 and player.combo.swing_direction.is_equal_approx(Vector2.DOWN),
			"buffered second slash preserves the click direction at rank %d" % rank)
		Input.action_release("move_left")

		fresh(rank)
		await frames(2)
		origin = player.global_position
		Input.action_press("move_up")
		tap(MOUSE_BUTTON_RIGHT, origin + Vector2.RIGHT * 125.0)
		check(player.visual.look_direction.is_equal_approx(Vector2.RIGHT), "right click immediately faces the cursor")
		await frames(11)
		check(is_instance_valid(player.thrown_sword) and player.thrown_sword.aim.is_equal_approx(Vector2.RIGHT)
			and player.visual.look_direction.is_equal_approx(Vector2.RIGHT) and player.position.y < origin.y,
			"moving north leaves throw and pose locked east at rank %d" % rank)
		if capture and rank == 1:
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(CAPTURES + "02-moving-throw.png") == OK, "native moving throw capture")
		tap(MOUSE_BUTTON_LEFT, player.global_position + Vector2.LEFT * 100.0)
		mouse_motion(origin + Vector2.DOWN * 180.0)
		await frames(60)
		check(player.combo.attack_count == 1 and player.combo.swing_direction.is_equal_approx(Vector2.LEFT),
			"post-catch slash preserves the click direction at rank %d" % rank)
		Input.action_release("move_up")

		fresh(rank)
		await frames(2)
		origin = player.global_position
		Input.action_press("move_up")
		Input.action_press("move_right")
		space(origin + Vector2.LEFT * 150.0)
		Input.action_release("move_up")
		Input.action_release("move_right")
		await frames(8)
		check(player.dash_direction.is_equal_approx(Vector2(1, -1).normalized())
			and player.position.x > origin.x and player.position.y < origin.y,
			"dash records the pressed WASD diagonal at rank %d" % rank)

		fresh(rank)
		await frames(2)
		origin = player.global_position
		Input.action_press("move_up")
		Input.action_press("move_down")
		space(origin + Vector2.LEFT * 150.0)
		check(player.dash_request.is_zero_approx(), "opposing held keys do not fall back to mouse dash")
		Input.action_release("move_up")
		Input.action_release("move_down")
		space(origin + Vector2.LEFT * 150.0)
		await frames(8)
		check(player.dash_direction.is_equal_approx(Vector2.LEFT) and player.position.x < origin.x,
			"stationary dash aims at the cursor at rank %d" % rank)
	game.phase = "exit_ready"
	game._trigger_portal_reward()
	check(not player.aim_marker.visible, "aim marker hidden on reward selection")
	game.phase = "victory"
	game._update_status()
	check(not player.aim_marker.visible, "aim marker hidden on results")
	paused = false

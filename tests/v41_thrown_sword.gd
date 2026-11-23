extends SceneTree

const CONFIG = preload("res://scripts/v41_config.gd")
const Flight = preload("res://scripts/v41_thrown_sword.gd")
const ORIGIN := Vector2(456, 401)
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

func mouse(button: MouseButton, point: Vector2, pressed := true) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = root.get_canvas_transform() * point
	event.global_position = event.position
	event.pressed = pressed
	root.push_input(event, true)

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event, true)

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
		enemy.position = Vector2(960, 300 + i * 70)
		enemy.health = 1000.0
		enemy.max_health = 1000.0
		enemy.guard_cooldown = 100.0
	return enemies

func run() -> void:
	game = load("res://scenes/main_v41.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frames(2)
	await check_flight()
	await check_wall()
	await check_return_route()
	await check_inputs()
	await check_cleanup()
	print("V41 THROWN SWORD: %d/%d" % [checks - failures, checks])
	game.free()
	await process_frame
	quit(1 if failures else 0)

func check_flight() -> void:
	for rank in range(3):
		var enemies := fresh(rank)
		var distance: float = CONFIG.THROW_DISTANCE[rank]
		var spin_radius: float = CONFIG.THROW_RADIUS[rank]
		enemies[0].position = ORIGIN + Vector2(68, 0)
		enemies[1].position = ORIGIN + Vector2(distance - 6.0, 3.0)
		enemies[2].position = ORIGIN + Vector2(distance, spin_radius - 2.0)
		enemies[3].position = ORIGIN + Vector2(distance, spin_radius + 8.0)
		var contacts := [[], [], [], []]
		for i in range(enemies.size()):
			enemies[i].damaged.connect(func(_point: Vector2, amount: float):
				var flight: Flight = player.thrown_sword
				if is_instance_valid(flight):
					contacts[i].append({"age": flight.age, "phase": flight.flight, "amount": amount}))
		await frames(2)
		mouse(MOUSE_BUTTON_RIGHT, ORIGIN + Vector2.RIGHT * 350)
		await frames(3)
		var sword: Flight = player.thrown_sword
		check(is_instance_valid(sword) and sword.flight == Flight.Flight.OUTBOUND and sword.rank == rank, "right mouse launches rank %d" % rank)
		check(player.position.is_equal_approx(ORIGIN) and player.dash_state == player.Dash.IDLE, "throw leaves the character in place")
		check(is_equal_approx(player.stamina, 92.0) and player.throw_cooldown > 1.3 and player.dash_cooldown == 0.0, "throw spends only its own cost and cooldown")
		var spin_tick_count := 0
		var saw_catch := false
		var saw_return := false
		var spin_point := Vector2.INF
		var second_press := false
		for i in range(85):
			if not is_instance_valid(player.thrown_sword):
				break
			if sword.flight == Flight.Flight.SPIN:
				spin_tick_count += 1
				spin_point = sword.global_position
				if not second_press:
					mouse(MOUSE_BUTTON_RIGHT, ORIGIN + Vector2.LEFT * 100)
					second_press = true
			saw_return = saw_return or sword.flight == Flight.Flight.RETURN
			saw_catch = saw_catch or sword.flight == Flight.Flight.CATCH
			await frames(1)
		check(spin_point.distance_to(ORIGIN + Vector2.RIGHT * distance) < 1.0, "spin starts at configured range %d" % rank)
		check(absf(spin_tick_count / 60.0 - CONFIG.THROW_SPIN_TIME[rank]) < 0.04, "spin lasts the configured time %d" % rank)
		check(saw_return and saw_catch and not is_instance_valid(player.thrown_sword), "continuous return and catch phases")
		check(is_equal_approx(1000.0 - enemies[0].health, CONFIG.THROW_OUT_DAMAGE[rank] + CONFIG.THROW_RETURN_DAMAGE[rank]), "out and return each damage once")
		var mixed: Array = contacts[1]
		check(mixed.size() >= 3 and mixed[0].phase == Flight.Flight.OUTBOUND and mixed[1].phase == Flight.Flight.SPIN,
			"overlapping phases still allow the first hit and spaced spin damage")
		var spin_only: Array = contacts[2]
		check(spin_only.size() >= 3 and spin_only.size() <= CONFIG.THROW_SPIN_TICKS[rank]
			and spin_only.all(func(hit): return hit.phase == Flight.Flight.SPIN and is_equal_approx(hit.amount, CONFIG.THROW_SPIN_DAMAGE[rank]))
			and enemies[2].slow_time > 0.0, "spin-only target still takes spaced multi-hit damage and brief slow")
		for series in contacts:
			for i in range(1, series.size()):
				check(series[i].age - series[i - 1].age + 0.00001 >= CONFIG.THROW_TARGET_HIT_INTERVAL,
					"same throw and target leave at least 0.12s between accepted hits")
		check(enemies[3].health == 1000.0 and is_equal_approx(player.stamina, 92.0), "outside target and repeat-press cost")
		mouse(MOUSE_BUTTON_RIGHT, ORIGIN + Vector2.RIGHT * 350, false)
	# Verify short-range cursor-targeted spin stops right at clicked position
	fresh(2)
	await frames(2)
	mouse(MOUSE_BUTTON_RIGHT, ORIGIN + Vector2.RIGHT * 92.0)
	var short_spin := Vector2.INF
	for _i in range(60):
		await frames(1)
		if is_instance_valid(player.thrown_sword) and player.thrown_sword.flight == Flight.Flight.SPIN:
			short_spin = player.thrown_sword.global_position
			break
	check(short_spin.distance_to(ORIGIN + Vector2.RIGHT * 92.0) < 2.0, "short-range right-click spins right at cursor location")
	mouse(MOUSE_BUTTON_RIGHT, ORIGIN + Vector2.RIGHT * 92.0, false)

func check_wall() -> void:
	var enemies := fresh(2)
	var rock: Vector2 = game.world.room1_obstacles[0].position
	player.position = rock - Vector2(112, 0)
	enemies[0].position = rock + Vector2(98, 0)
	await frames(2)
	mouse(MOUSE_BUTTON_RIGHT, rock + Vector2(190, 0))
	await frames(2)
	var maximum: float = player.position.x
	var paused_at_wall := false
	for i in range(65):
		if not is_instance_valid(player.thrown_sword):
			break
		maximum = maxf(maximum, player.thrown_sword.global_position.x)
		paused_at_wall = paused_at_wall or player.thrown_sword.flight == Flight.Flight.SPIN
		await frames(1)
	check(maximum > rock.x - 105.0 and maximum < rock.x - 45.0 and not paused_at_wall, "outbound sweep hits rock and returns immediately")
	check(enemies[0].health == 1000.0 and not is_instance_valid(player.thrown_sword), "wall prevents damage and return succeeds")

func check_return_route() -> void:
	fresh(2)
	player.position = Vector2(676, 235)
	await frames(2)
	mouse(MOUSE_BUTTON_RIGHT, Vector2(380, 235))
	await frames(14)
	check(is_instance_valid(player.thrown_sword) and player.thrown_sword.flight == Flight.Flight.SPIN, "routing fixture launches south of the gate wall")
	# The direct return line now crosses the left wing of the new gate.
	player.position = Vector2(640, 162)
	var used_route := false
	var crossed_wall := false
	for i in range(125):
		if not is_instance_valid(player.thrown_sword):
			break
		var sword: Flight = player.thrown_sword
		var before := sword.global_position
		used_route = used_route or not sword.route.is_empty()
		await frames(1)
		if is_instance_valid(sword) and not before.is_equal_approx(sword.global_position):
			var ray := PhysicsRayQueryParameters2D.create(before, sword.global_position, player.terrain_mask)
			crossed_wall = crossed_wall or not player.get_world_2d().direct_space_state.intersect_ray(ray).is_empty()
	check(used_route and not crossed_wall and not is_instance_valid(player.thrown_sword), "return reroutes around terrain and catches")

func check_inputs() -> void:
	fresh(2)
	await frames(2)
	player.stamina = 7.0
	mouse(MOUSE_BUTTON_RIGHT, ORIGIN + Vector2.RIGHT * 300)
	await frames(3)
	check(not is_instance_valid(player.thrown_sword) and player.throw_cooldown == 0.0, "insufficient stamina starts no throw cooldown")
	player.stamina = 100.0
	mouse(MOUSE_BUTTON_RIGHT, ORIGIN + Vector2.RIGHT * 300)
	await frames(3)
	mouse(MOUSE_BUTTON_LEFT, ORIGIN + Vector2.RIGHT * 300)
	var start: Vector2 = player.position
	Input.action_press("move_down")
	await frames(12)
	check(player.position.y > start.y + 20.0 and player.combo.attack_count == 0, "can move with empty hands and buffered left does not swing")
	Input.action_release("move_down")
	await frames(48)
	check(not is_instance_valid(player.thrown_sword) and player.combo.attack_count == 1, "buffered left resumes after moving catch")
	var stamina: float = player.stamina
	mouse(MOUSE_BUTTON_RIGHT, ORIGIN + Vector2.RIGHT * 300)
	await frames(15)
	check(not is_instance_valid(player.thrown_sword) and player.throw_request.is_zero_approx() and player.stamina >= stamina,
		"throw cooldown rejects second shot even after catch")
	fresh(0)
	game.reward_counts[5] = 1
	game._apply_rewards()
	await frames(2)
	mouse(MOUSE_BUTTON_RIGHT, ORIGIN + Vector2.RIGHT * 300)
	await frames(4)
	key(KEY_SPACE)
	await frames(2)
	check(player.dash_state != player.Dash.IDLE and is_instance_valid(player.thrown_sword), "Space dash fires immediately without deadlocking while thrown sword is airborne")
	await frames(52)
	check(not is_instance_valid(player.thrown_sword) and player.dash_cooldown > 0.0 and is_equal_approx(player.stamina, 72.0), "airborne dash plus throw pays both costs once and finishes cleanly")
	check(player.combo.dash_armed and not player.is_rolling(), "same unique card arms after Space dash")

func check_cleanup() -> void:
	fresh(2)
	await frames(2)
	mouse(MOUSE_BUTTON_RIGHT, ORIGIN + Vector2.RIGHT * 300)
	await frames(3)
	var sword: Flight = player.thrown_sword
	player.take_damage(1000.0, Vector2.ZERO)
	check(not is_instance_valid(player.thrown_sword) and sword.is_queued_for_deletion(), "death removes sword and pending phases")
	await frames(35)
	key(KEY_R)
	await frames(2)
	check(game.player.throw_cooldown == 0.0 and not is_instance_valid(game.player.thrown_sword), "fresh run clears throw cooldown")
	fresh(2)
	await frames(2)
	mouse(MOUSE_BUTTON_RIGHT, ORIGIN + Vector2.RIGHT * 300)
	await frames(3)
	sword = player.thrown_sword
	game.debug_jump(1)
	game.debug_close()
	await frames(2)
	check(not is_instance_valid(sword) and not is_instance_valid(game.player.thrown_sword) and game.player.throw_cooldown == 0.0,
		"room change clears the previous flight and timing")

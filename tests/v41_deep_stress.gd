extends SceneTree

const CONFIG = preload("res://scripts/v41_config.gd")
const POOL = preload("res://scripts/v41_card_pool.gd")
const DOMAIN = preload("res://scripts/v41_boss_domain.gd")
var game
var checks := 0
var failures := 0
var spawns := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
	await process_frame

func audit_spawn(point: Vector2) -> void:
	var w = game.world
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 15.0
	query.shape = shape
	query.transform = Transform2D(0.0, point)
	query.collision_mask = w.terrain_movement_mask
	check(w.get_world_2d().direct_space_state.intersect_shape(query).is_empty(), "spawn circle clear room %d %s" % [game.room_index + 1, point])
	check(not w.path_between(point, game.player.position).is_empty(), "spawn reachable")
	spawns += 1

func test_geometry() -> void:
	for room in range(7):
		game.room_index = room
		game._enter_room()
		await frames(2)
		var w = game.world
		for cell in w.floor_cells:
			check(not w.grid.get_point_path(w.nearest_cell(game.player.position), cell).is_empty(), "connected navigation room %d" % room)
		if room == 6:
			audit_spawn(game.boss.position)
			continue
		for wave in range(CONFIG.WAVES[room].size()):
			game.wave_index = wave
			for sample in range(40):
				game.player.position = w.cell_center(w.floor_cells[sample * 17 % w.floor_cells.size()])
				for point in game._pick_wave_spawn_points():
					audit_spawn(point)

func test_cards() -> void:
	for seed_value in range(2000):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var counts: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
		for room in range(6):
			var rank := mini(2, room / 2)
			var cards := POOL.draw(counts, rng, rank)
			check(cards.size() == 3 and cards[0] != cards[1] and cards[1] != cards[2] and cards[0] != cards[2], "six draws remain full and distinct")
			for card in cards:
				check(POOL.eligible(card, counts, rank), "no exhausted unique card")
			counts[cards[rng.randi_range(0, 2)]] += 1

func test_retries() -> void:
	for pattern in range(3):
		for active in [false, true]:
			game.start_room()
			game.room_index = 6
			game._enter_room()
			await frames(2)
			game.player.gm_invulnerable = true
			game.boss.trigger_demon_domain(pattern)
			var old_domain: Node = game.boss.domain_node
			if active:
				await frames(90)
			game.feedback._spawn_crit_sparks(game.player.position)
			game.player.gm_invulnerable = false
			game.player.take_damage(99999.0, Vector2.ZERO)
			await frames(42)
			check(game.phase == "dead", "boss death reaches retry screen")
			game.retry_current_room()
			await frames(2)
			check(not is_instance_valid(old_domain), "old domain destroyed on retry")
			check(game.feedback.crit_sparks.is_empty(), "old particles cleared")
			check(game.player.health == game.player.max_health and game.player.sword_rain_cooldown == 0.0, "retry starts safe")
			check(game.world.actors.get_children().filter(func(n): return n.get_script() == DOMAIN).is_empty(), "no residual boss field")

func test_inputs_and_focus() -> void:
	game.start_room()
	game.player.gm_invulnerable = true
	game.player.gm_infinite_stamina = true
	for i in range(1200):
		var motion := InputEventMouseMotion.new()
		motion.position = Vector2(-500 if i % 2 else 1800, -200 if i % 3 else 1000)
		root.push_input(motion, true)
		if i % 7 == 0:
			for button in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
				var click := InputEventMouseButton.new()
				click.button_index = button
				click.position = motion.position
				click.pressed = true
				root.push_input(click, true)
				click = click.duplicate()
				click.pressed = false
				root.push_input(click, true)
			game.player.request_dash(Vector2.RIGHT if i % 2 else Vector2.LEFT)
			game.player.request_sword_rain()
		await frames(1)
		check(game.player.position.is_finite() and game.player.aim_direction.is_finite(), "spam keeps finite position and aim")
	await frames(200)
	check(not game.player.is_casting_sword_rain() and game.player.dash_state == game.player.Dash.IDLE and game.player.combo.swing_time <= 0.0, "spam state machines recover")
	game.start_room()
	game.player.request_sword_rain()
	var rain: Node = game.player.sword_rain_node
	game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(paused and game.menu_open, "application focus pauses arena")
	var age: float = rain.phase_age
	await frames(30)
	check(is_equal_approx(age, rain.phase_age), "skill clocks freeze while unfocused")
	game.resume_room()
	await frames(150)
	check(not game.player.is_casting_sword_rain(), "cast completes after explicit resume")

func test_full_runs() -> void:
	for seed_value in range(3):
		game.start_room()
		game.reward_rng.seed = seed_value
		for room in range(7):
			check(game.room_index == room, "sequential room entry")
			game.player.gm_invulnerable = true
			var timeout := 0
			while game.phase != "exit_ready" and game.phase != "victory" and timeout < 6000:
				if game.phase == "combat":
					await frames(90)
					for foe in get_nodes_in_group("enemies"):
						if not foe.dead:
							check(Geometry2D.is_point_in_polygon(foe.position, game.world.walkable), "AI remains inside perimeter")
							foe.knockback = Vector2(20000, -20000)
					await frames(2)
					for foe in get_nodes_in_group("enemies"):
						if not foe.dead:
							check(Geometry2D.is_point_in_polygon(foe.position, game.world.walkable), "large knockback cannot exit arena room %d at %s" % [room + 1, foe.position])
							foe.take_damage(999999.0, Vector2.ZERO, true)
				await frames(10)
				timeout += 10
			check(timeout < 6000 and game.remaining == 0, "all waves clear without soft lock")
			if room < 6:
				game.player.position = game.world.exit_point
				await frames(20)
				check(game.phase == "reward_select" and game.reward_options.size() == 3, "portal opens card selection")
				game.select_reward(game.reward_options[seed_value % 3])
				await frames(3)
		check(game.phase == "victory", "seven room victory")
		game.start_room()
		check(game.run_kills == 0 and game.run_elapsed == 0.0 and game.player.cultivation == 0 and game.reward_counts.all(func(n): return n == 0) and game.player.sword_rain_cooldown == 0.0, "fresh run resets all progress")

func test_cooldown_posture_and_ui() -> void:
	for rank in range(3):
		game.start_room()
		game.player.cultivation = rank
		game.reward_counts[POOL.Card.RAIN] = 1
		game._apply_rewards()
		game.player.request_sword_rain()
		var rain = game.player.sword_rain_node
		for enemy in get_nodes_in_group("enemies"):
			enemy.health = 1e9
		for hit in range(100):
			for enemy in get_nodes_in_group("enemies"):
				rain._resolve_sword_impact(enemy.position)
			check(game.player.sword_rain_cooldown >= 3.5 and rain.refunded_time <= CONFIG.SWORD_RAIN_COOLDOWNS[rank] - 3.5, "refund respects total cast floor")
	game.start_room()
	var elite = get_nodes_in_group("enemies")[0]
	elite.v41_guard_elite = true
	elite.set_physics_process(false)
	for i in range(100):
		elite.damage_posture(999999.0)
		check(elite.posture == 0.0 and elite.posture_broken_time > 0.0, "posture clamps at zero")
		elite._encounter_process(2.0)
		check(elite.posture == elite.posture_max and elite.posture_broken_time == 0.0, "elite exits break stun")
	game.start_room()
	for screen in ["title", "reward", "dead", "victory"]:
		if screen == "title":
			game.enter_title_screen()
		elif screen == "reward":
			game.phase = "reward_select"
			game._draw_rewards()
			game.hud.show_rewards()
		else:
			game.phase = screen
			game.hud.show_run_result(screen == "victory")
		for size in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(1280, 720)]:
			root.size = size
			await frames(8)
			var panel: Control = game.hud.title_start_btn if screen == "title" else game.hud.modal_panel
			check(Rect2(Vector2.ZERO, Vector2(size)).encloses(panel.get_global_rect()), "screen fits window/fullscreen round trip " + screen)

func test_obstructed_pursuit() -> void:
	for rock in [Vector2(490, 320), Vector2(730, 475), Vector2(900, 310)]:
		for kind in [SurvivorEnemy.Kind.HOSTILE, SurvivorEnemy.Kind.RANGED]:
			for side in [-1.0, 1.0]:
				game.start_room()
				game.room_index = 1
				game._enter_room()
				await frames(2)
				var foes := get_nodes_in_group("enemies")
				var foe = foes[0]
				for other in foes.slice(1):
					other.free()
				foe.kind = kind
				foe.pair_scheduler = null
				foe.v41_guard_elite = kind == SurvivorEnemy.Kind.HOSTILE
				foe.position = game.world.cell_center(game.world.nearest_cell(rock + Vector2(side * 110, 0)))
				game.player.position = game.world.cell_center(game.world.nearest_cell(rock - Vector2(side * 110, 0)))
				game.player.gm_invulnerable = true
				foe.alert_encounter(game.player.position)
				var start: Vector2 = foe.position
				await frames(300)
				check(foe._boss_has_sight(game.player.position) or foe.position.distance_to(start) > 24.0, "obstructed ranged/elite pursues instead of idling")

func run() -> void:
	root.size = Vector2i(1280, 720)
	game = load("res://scenes/main_v41.tscn").instantiate()
	root.add_child(game)
	await frames(2)
	await test_geometry()
	test_cards()
	await test_retries()
	await test_inputs_and_focus()
	await test_full_runs()
	await test_cooldown_posture_and_ui()
	await test_obstructed_pursuit()
	game.free()
	await frames(2)
	print("DEEP_STRESS checks=", checks, " spawns=", spawns, " FAILED=", failures)
	quit(1 if failures else 0)

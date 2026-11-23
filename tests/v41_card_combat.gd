extends "res://tests/v41_presentation.gd"

const CONFIG = preload("res://scripts/v41_config.gd")
const POOL = preload("res://scripts/v41_card_pool.gd")
const CARD = POOL.Card
const WAVE = preload("res://scripts/v41_sword_wave.gd")
const CAPTURES := "res://artifacts/runtime/v41-first-pass/"
const ORIGIN := Vector2(570, 420)

var foes: Array[SurvivorEnemy] = []

func shot(name: String) -> void:
	if capture:
		await RenderingServer.frame_post_draw
		var frame := root.get_texture().get_image()
		check(frame.save_png(CAPTURES + name + ".png") == OK, "native capture " + name)
		if name == "01-enemy-colors":
			var detail := frame.get_region(Rect2i(420, 340, 290, 220))
			detail.resize(580, 440, Image.INTERPOLATE_NEAREST)
			check(detail.save_png(CAPTURES + "01-enemy-detail.png") == OK, "native enemy detail")

func fresh(cards: Array[int], room := 0) -> void:
	game.start_room()
	game.room_index = room
	if room > 0:
		game._enter_room()
	for index in cards:
		game.reward_counts[index] = 1
	game._apply_rewards()
	game.player.gm_invulnerable = true
	game.player.position = ORIGIN
	foes.assign(get_nodes_in_group("enemies"))
	for i in range(foes.size()):
		var enemy := foes[i]
		enemy.set_physics_process(false)
		enemy.position = Vector2(1060, 480 + 36 * i)
		enemy.max_health = 1000
		enemy.health = 1000
		enemy.guard_cooldown = 99.0

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event, true)

func waves() -> Array:
	return game.world.actors.get_children().filter(func(node): return node is WAVE and not node.is_queued_for_deletion())

func test_wave_cards() -> void:
	for card in [CARD.LOTUS, CARD.WIDE, CARD.FAN]:
		fresh([card])
		foes[0].position = ORIGIN + Vector2(185, 0)
		if card == CARD.FAN:
			foes[0].guard_time = 1.0
			foes[0].guard_direction = Vector2.LEFT
		var sword = game.player.combo
		sword.next_stage = 2
		sword.chain_time = 0.2
		check(sword.attack(Vector2.RIGHT) and sword.stage == 2, "starts third swing")
		await frames(9)
		var blades := waves()
		check(blades.size() == (3 if card == CARD.FAN else 1), "third swing spawns expected wave count")
		if not blades.is_empty() and card == CARD.WIDE:
			check(blades[0].jade_trail and blades[0].hit_radius > 30.0 and blades[0].max_distance > 400.0, "wide wave has jade trail, wider and longer hurtbox")
		await frames(33)
		check(foes[0].health < 1000.0, "wave hits beyond melee range")
		if card == CARD.FAN:
			check(foes[0].guard_time == 0.0 and not foes[0].last_hit_blocked, "fan breaks a shield outside melee range")
	check(not game.hud.cast_focus.visible, "left combo does not start the cast focus")

func test_dash_cards() -> void:
	fresh([CARD.THUNDER, CARD.BLOOD, CARD.CHAIN, CARD.REFRESH])
	var player = game.player
	foes[0].position = ORIGIN + Vector2(0, 64)
	foes[0].guard_time = 1.0
	foes[1].position = ORIGIN + Vector2(60, 99)
	foes[2].position = ORIGIN + Vector2(128, 97)
	player.stamina = 82.0
	player.request_dash(Vector2.RIGHT)
	await frames(18)
	check(player.thunder_bombs.size() == 2 and foes[0].health == 1000.0, "real dash queues both ghosts and the start ghost has not exploded early")
	await frames(20)
	check(foes[0].health < 1000.0 and foes[0].guard_time == 0.0 and player.dash_cooldown == 0.0, "delayed explosion damages and breaks guard, refreshing dash")
	check(player.stamina >= 72.0, "shield break returns stamina")
	check(foes[1].health < 1000.0 and foes[2].health < 1000.0 and not game.feedback.card_arcs.is_empty(), "ghost also chains to nearby targets")

	fresh([CARD.REFRESH, CARD.BLOOD])
	player = game.player
	player.health = 80.0
	player.stamina = 64.0
	player.dash_cooldown = 1.0
	foes[0].position = ORIGIN + Vector2(65, 0)
	foes[0].health = 20.0
	foes[0].visual.update_pose(Vector2.ZERO, Vector2.RIGHT, Color.WHITE)
	player.combo.swing_direction = Vector2.RIGHT
	player.combo._deal_hit(foes[0], 32.0, Vector2.RIGHT)
	check(foes[0].dead and player.dash_cooldown == 0.0 and player.health == 85.0 and player.stamina == 78.0, "rear kill refreshes dash and grants blood card recovery")

func test_throw_cards() -> void:
	fresh([CARD.SPLIT, CARD.CHAIN])
	var player = game.player
	foes[0].position = ORIGIN + Vector2(65, 0)
	foes[1].position = ORIGIN + Vector2(100, 48)
	foes[2].position = ORIGIN + Vector2(125, -52)
	foes[3].position = ORIGIN + Vector2(156, 68)
	player._request_throw(Vector2.RIGHT, 155.0)
	await frames(6)
	check(is_instance_valid(player.thrown_sword) and player.thrown_sword.on_hit_cards_fired, "actual thrown sword contact triggers cards")
	check(waves().size() == 2 or foes.slice(1, 3).all(func(e): return e.health < 972.0), "throw spawns two moving homing blades")
	check(not game.feedback.card_arcs.is_empty() and game.feedback.card_arcs[0].points.size() == 4, "throw chain visits three distinct nearby targets")
	await frames(27)
	check(foes[1].health < 972.0 and foes[2].health < 976.0, "both tracking blades contribute damage after chain")
	check(not game.hud.cast_focus.visible, "throw does not start the cast focus")

func test_rain_card() -> void:
	fresh([CARD.RAIN])
	var player = game.player
	game.cultivation_override = 2
	player.cultivation = 2
	player.health = 80.0
	foes[0].position = Vector2(420, 450)
	foes[1].position = Vector2(690, 475)
	foes[2].position = Vector2(805, 385)
	foes[3].position = Vector2(910, 510)
	key(KEY_E)
	var rain = player.sword_rain_node
	check(is_instance_valid(rain) and rain.total_swords == 18, "E starts real skill with double base sword count")
	check(game.hitstop_active and game.hitstop_current_duration == 0.09 and game.hud.cast_focus.visible, "E starts the brief stop and edge focus")
	await frames(4)
	await shot("02-wanjian-cast")
	await frames(5)
	check(not game.hitstop_active and game.get_node("Camera2D").zoom.x > 1.0, "hitstop releases into a small zoom pulse")
	var limit := 100
	while is_instance_valid(rain) and rain.phase != rain.Phase.FALL and limit > 0:
		await frames(1)
		limit -= 1
	check(limit > 0 and not game.hud.cast_focus.visible, "focus is gone before sword fall")
	await frames(4)
	check(not game.hud.cast_focus.is_visible_in_tree(), "falling swords do not obscure the screen with an overlay")
	await shot("02-wanjian")
	await frames(70)
	check(player.health > 80.0 and game.get_node("Camera2D").zoom.is_equal_approx(Vector2.ONE), "rain heals and camera returns")

	fresh([CARD.RAIN])
	player = game.player
	player.request_sword_rain()
	rain = player.sword_rain_node
	player.health = 80.0
	foes[0].position = Vector2(685, 418)
	foes[1].position = Vector2(730, 418)
	rain._resolve_sword_impact(foes[0].position)
	check(player.sword_rain_cooldown == 6.5 and player.health == 82.0, "one target refunds exactly 1.5s and heals 2")
	rain._resolve_sword_impact(foes[0].position)
	check(player.sword_rain_cooldown == 6.5 and player.health == 84.0, "repeat hits heal without refunding the same target twice")
	rain._resolve_sword_impact(foes[1].position)
	check(player.sword_rain_cooldown == 5.0 and player.health == 86.0, "second distinct target refunds another 1.5s")

func test_native_enemies() -> void:
	fresh([], 1)
	var bandit := foes[0]
	var ranger := foes[2]
	bandit.position = Vector2(610, 425)
	bandit.windup = 0.17
	bandit.attack_direction = Vector2(-0.50, 0.86)
	bandit.visual.update_pose(Vector2.ZERO, bandit.attack_direction, Color.WHITE)
	bandit.queue_redraw()
	ranger.position = Vector2(483, 422)
	ranger.windup = 0.21
	ranger.attack_direction = Vector2(0.50, 0.86)
	ranger.visual.update_pose(Vector2.ZERO, ranger.attack_direction, Color.WHITE)
	ranger.queue_redraw()
	game.player.position = Vector2(542, 522)
	await frames(3)
	for enemy in [bandit, ranger]:
		check(enemy.visual.modulate == Color.WHITE and enemy.visual.self_modulate == Color.WHITE
			and enemy.visual.hit_flash_mat.get_shader_parameter("hurt_flash") == 0.0, "enemy windup uses neutral shader and modulate")
		enemy.visual.play_hurt()
	await frames(2)
	for enemy in [bandit, ranger]:
		var strength: float = enemy.visual.hit_flash_mat.get_shader_parameter("hurt_flash")
		check(strength > 0.0 and strength <= CONFIG.ENEMY_FLASH_STRENGTH, "enemy hit flash starts at restrained brightness")
	await frames(10)
	for enemy in [bandit, ranger]:
		check(enemy.visual.modulate == Color.WHITE and enemy.visual.hit_flash_mat.get_shader_parameter("hurt_flash") == 0.0, "enemy hit flash restores original colors")
	await shot("01-enemy-colors")

func test_reward_ui() -> void:
	for tier in [1, 2]:
		game.start_room()
		game.room_index = tier * 2
		game.run_kills = CONFIG.CULTIVATION_KILLS[tier]
		game.reward_counts[CARD.LOTUS] = 1
		game.reward_counts[CARD.BLOOD] = 1
		game._enter_room()
		game.phase = "exit_ready"
		game._trigger_portal_reward()
		check(game.reward_options.size() == 3 and game.reward_options.all(func(card): return POOL.tier(card) == tier), "real portal offers three unlocked cards of current tier")
		for resolution in [Vector2i(1280, 720), Vector2i(960, 540)]:
			root.size = resolution
			await frames(8)
			check_text_bounds(game.hud.modal_panel, Rect2(Vector2.ZERO, game.hud.root.size).grow(-12.0))
			if capture:
				check(root.size == resolution, "requested native resolution")
				await shot("03-tier-%d-%d" % [tier, resolution.x])

func test_spawns() -> void:
	for room in range(2, 6):
		game.start_room()
		game.room_index = room
		game._enter_room()
		var origin: Vector2 = game.player.position
		for batch in range(CONFIG.WAVES[room].size()):
			game.wave_index = batch
			var points: Array[Vector2] = game._pick_wave_spawn_points()
			check(points.size() == CONFIG.WAVES[room][batch].size() and points.all(func(point):
				return point.distance_to(origin) >= CONFIG.SPAWN_CLEARANCE and not game.world.path_between(origin, point).is_empty()),
				"room %d wave %d uses reachable spawn points" % [room + 1, batch + 1])
			for i in range(points.size()):
				check(points.slice(i + 1).all(func(point): return point.distance_to(points[i]) >= 40.0), "spawn spacing prevents stacked bodies")

func run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	if capture:
		DirAccess.make_dir_recursive_absolute(CAPTURES)
	game = load("res://scenes/main_v41.tscn").instantiate()
	game.skip_title_screen = true
	root.add_child(game)
	current_scene = game
	await frames()
	check(CONFIG.run_total() == 88, "seven-room run budgets 88 enemies")
	await test_native_enemies()
	await test_wave_cards()
	await test_dash_cards()
	await test_throw_cards()
	await test_rain_card()
	test_spawns()
	await test_reward_ui()
	paused = false
	game.free()
	await frames()
	print("CARD_COMBAT_RESULT checks=", checks, " failures=", failures)
	quit(1 if failures else 0)

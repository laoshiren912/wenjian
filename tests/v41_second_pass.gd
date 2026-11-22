extends "res://tests/v41_presentation.gd"

const CONFIG = preload("res://scripts/v41_config.gd")
const POOL = preload("res://scripts/v41_card_pool.gd")
const DOMAIN = preload("res://scripts/v41_boss_domain.gd")
const CAPTURES := "res://artifacts/runtime/v41-polish/"

func shot(name: String) -> void:
	if not capture:
		return
	await process_frame
	var frame := root.get_texture().get_image()
	check(frame.save_png(CAPTURES + name + ".png") == OK, "native capture " + name)
	if name == "02-defeat":
		var world := frame.get_pixel(121, 451)
		check(absf(world.r - world.g) < 0.008 and absf(world.r - world.b) < 0.008, "world screenshot pixels are grayscale")

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event, true)

func enter(room: int, kills: int, learned: Array[int] = []) -> void:
	game.start_room()
	game.room_index = room
	game.run_kills = kills
	for card in learned:
		game.reward_counts[card] = 1
	game._enter_room()

func test_ultimate() -> void:
	var kills := 0
	for room in range(CONFIG.RUN_ROOMS):
		enter(room, kills)
		var expected: float = [8.0, 8.0, 6.5, 6.5, 5.0, 5.0, 5.0][room]
		key(KEY_E)
		check(game.player.sword_rain_cooldown == expected, "E base cooldown in room %d is %.1fs" % [room + 1, expected])
		if room < CONFIG.BOSS_ROOM:
			kills += CONFIG.room_total(room)

	enter(2, 10, [POOL.Card.RAIN])
	var player = game.player
	var targets := get_nodes_in_group("enemies")
	player.gm_invulnerable = true
	player.position = Vector2(655, 440)
	for i in range(targets.size()):
		targets[i].set_physics_process(false)
		targets[i].position = Vector2(430 + i * 96, 450 + (i % 2) * 105)
		targets[i].health = 1000.0
	key(KEY_E)
	check(player.sword_rain_cooldown == 6.5 and game.hitstop_active, "stage two cooldown and cast impact initialize together")
	var rain = player.sword_rain_node
	check(game.hud.cast_focus.visible and game.hud.cast_focus.DURATION == 0.12, "cast begins with the 120ms edge focus")
	check(not game.hud.get_property_list().any(func(item): return item.name == "rain_title"), "E has no title widget")
	await frames(11)
	check(not game.hud.cast_focus.visible and rain.clock < 0.26, "cast focus clears while the initial shockwave still exists")
	await shot("04-e-shockwave")
	await frames(24)
	await frames(85)
	check(not is_instance_valid(player.sword_rain_node), "swords clean up after the cast")
	check(not player.request_sword_rain(), "cannot recast before the cooldown ends")

	enter(2, 10, [POOL.Card.RAIN])
	player = game.player
	check(player.request_sword_rain(), "new room fixture casts with clean state")
	rain = player.sword_rain_node
	targets = get_nodes_in_group("enemies")
	for i in range(targets.size()):
		targets[i].position = Vector2(420 + i * 90, 470)
		targets[i].health = 1000.0
	for enemy in targets:
		rain._resolve_sword_impact(enemy.position)
	check(targets.size() == 5 and rain.refunded_targets.size() == 5 and rain.refunded_time == 3.0
		and player.sword_rain_cooldown == 3.5, "stage two refunds stop at the 3.5-second floor")
	rain._resolve_sword_impact(targets[0].position)
	check(player.sword_rain_cooldown == 3.5, "repeat hit cannot bypass the cooldown floor")

	for room in [0, 4]:
		enter(room, 43 if room == 4 else 0, [POOL.Card.RAIN])
		player = game.player
		check(player.request_sword_rain(), "empowered rain starts in room %d" % (room + 1))
		rain = player.sword_rain_node
		targets = get_nodes_in_group("enemies")
		for i in range(targets.size()):
			targets[i].position = Vector2(320 + i * 80, 425)
			targets[i].health = 1000.0
		for enemy in targets:
			rain._resolve_sword_impact(enemy.position)
		check(player.sword_rain_cooldown == 3.5, "refund reaches the same floor in room %d" % (room + 1))

	enter(0, 0)
	player = game.player
	player.request_sword_rain()
	player.take_damage(5.0, Vector2.ZERO)
	check(player.sword_rain_cooldown == 3.5 and not is_instance_valid(player.sword_rain_node), "interrupt cancels the swords and shortens the cooldown to 3.5 seconds")

func wait_for_pattern(within: int = 18) -> Node2D:
	for i in range(within):
		if is_instance_valid(game.boss.domain_node):
			return game.boss.domain_node
		await frames(1)
	return null

func wait_burst(field: Node2D) -> bool:
	for i in range(100):
		if not is_instance_valid(field):
			return false
		if field.bursting:
			return true
		await frames(1)
	return false

func wait_clear_field() -> void:
	for i in range(300):
		if not is_instance_valid(game.boss.domain_node):
			return
		await frames(1)

func test_patterns() -> void:
	enter(CONFIG.BOSS_ROOM, 87)
	var player = game.player
	var boss = game.boss
	player.position = Vector2(640, 550)
	boss.health = boss.max_health * 0.74
	var field := await wait_for_pattern()
	check(is_instance_valid(field) and field.pattern == DOMAIN.Pattern.RAIN, "75 percent phase opens with the sword domain")
	if not is_instance_valid(field):
		return
	check(game.hud.boss_mechanic_name.text == "万魔剑域" and field.safe_zones.size() == 3, "domain announces itself and exposes three eyes")
	player.position = field.safe_zones[2]
	var before: float = player.health
	check(await wait_burst(field) and player.health == before, "rain starts after telegraph and the eye prevents damage")
	player.position = Vector2(598, 283)
	await frames(17)
	check(player.health == before - DOMAIN.TICK_DAMAGE, "rain reaches unsafe positions outside line art")
	player.position = field.safe_zones[2]
	await wait_clear_field()
	check(not boss.domain_active and boss.domain_cooldown > 0.0 and not game.hud.boss_mechanic.visible, "domain cleans up before cooldown")

	boss.health = boss.max_health * 0.52
	boss.boss_state = boss.BossState.APPROACH
	await frames(3)
	check(not boss.domain_active, "next phase still observes shared cooldown")
	boss.domain_cooldown = 0.0
	player.health = 100.0
	player.invulnerability = 0.0
	field = await wait_for_pattern()
	check(is_instance_valid(field) and field.pattern == DOMAIN.Pattern.WHEEL, "next ready phase rotates to the wheel")
	if not is_instance_valid(field):
		return
	check(game.hud.boss_mechanic_name.text == "八荒魔轮" and DOMAIN.TELEGRAPH[DOMAIN.Pattern.WHEEL] == 0.45
		and is_equal_approx(DOMAIN.WHEEL_RATE, 0.43 * 1.6), "wheel displays its new name and exact timing")
	var initial: Array = field._beam_segments()
	player.position = initial[0].a.lerp(initial[0].b, 0.50)
	await frames(18)
	check(not field.bursting and player.health == 100.0 and initial.size() == 4, "four wheel telegraphs do no damage")
	await shot("03-wheel-warning")
	check(await wait_burst(field) and player.health < 100.0, "warning resolves into a damaging beam")
	player.gm_invulnerable = true
	player.position = Vector2(589, 531)
	await frames(47)
	var turned: Array = field._beam_segments()
	var initial_dir: Vector2 = initial[0].b - field.arena_center
	var turned_dir: Vector2 = turned[0].b - field.arena_center
	check(initial_dir.angle_to(turned_dir) > 0.20 and field.bursting, "active wheel rotates clockwise and persists")
	await shot("03-wheel-active")
	await wait_clear_field()

	boss.health = boss.max_health * 0.34
	boss.boss_state = boss.BossState.APPROACH
	boss.domain_cooldown = 0.0
	player.gm_invulnerable = false
	player.health = 100.0
	player.invulnerability = 0.0
	field = await wait_for_pattern()
	check(is_instance_valid(field) and field.pattern == DOMAIN.Pattern.CROSS and boss.next_pattern == DOMAIN.Pattern.RAIN, "third spell rotates back to rain")
	if not is_instance_valid(field):
		return
	player.position = field.warn_lines[0].a.lerp(field.warn_lines[0].b, 0.45)
	await frames(38)
	check(field.warn_lines.size() == 3 and not field.bursting and player.health == 100.0, "three wide phantom strips warn before the simultaneous slash")
	var safe := Vector2(675, 456)
	check(not field.is_dangerous(safe), "there is a safe pocket between the strips")
	await shot("03-phantom-warning")
	player.dash_evade_grace = 0.40
	check(await wait_burst(field) and player.health == 100.0 and field.evade_flash_time > 0.0, "dash immunity protects against simultaneous slashes")
	player.dash_evade_grace = 0.0
	var on_strip: Vector2 = player.position
	player.position = safe
	field._apply_domain_damage()
	check(player.health == 100.0, "the open pocket prevents damage without immunity")
	player.position = on_strip
	field._apply_domain_damage()
	check(player.health == 72.0, "the same intersecting bands hurt without the dash window")
	await wait_clear_field()

func test_throw_feedback() -> void:
	enter(CONFIG.BOSS_ROOM, 87)
	var player = game.player
	var boss = game.boss
	player.gm_invulnerable = true
	boss.trigger_demon_domain(DOMAIN.Pattern.WHEEL)
	await wait_burst(boss.domain_node)
	player.position = boss.position + Vector2(-152, 0)
	game.feedback.shake_gate_left = 0.0
	var delivered: Array[float] = []
	boss.damaged.connect(func(_point: Vector2, _damage: float):
		if is_instance_valid(player.thrown_sword):
			delivered.append(player.thrown_sword.age))
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	click.position = root.get_canvas_transform() * boss.global_position
	root.push_input(click, true)
	for i in range(25):
		if not delivered.is_empty():
			break
		await frames(1)
	check(not delivered.is_empty() and boss.health < boss.max_health and boss.domain_active, "a real right-click hits the boss during the wheel")
	await shot("01-wheel-throw-impact")
	var lock_at_impact: float = boss.visual.hurt_flash_lock
	var flash_at_impact: float = boss.visual.hurt_time
	boss.visual.play_hurt()
	check(boss.visual.hurt_flash_lock == lock_at_impact and boss.visual.hurt_time == flash_at_impact, "a double contact cannot restart boss flash")
	var shake_before: float = game.feedback.shake_time
	game.feedback.request_camera_shake(3.0, 0.18)
	check(is_equal_approx(game.feedback.shake_time, shake_before), "a hit within the camera merge window does not restart the envelope")
	var peak: float = boss.visual.boss_material.get_shader_parameter("hurt_flash")
	check(peak <= CONFIG.BOSS_FLASH_STRENGTH, "rendered flash is bounded, including at the point of impact")
	await frames(35)
	var gaps_valid := delivered.size() >= 2
	for i in range(1, delivered.size()):
		gaps_valid = gaps_valid and delivered[i] - delivered[i - 1] + 0.00001 >= CONFIG.THROW_TARGET_HIT_INTERVAL
	check(gaps_valid, "accepted hits from one flight never fall below the per-target gap")
	await frames(25)
	boss.visual.play_hurt()
	await frames(5)
	boss.visual.play_hurt()
	check(boss.visual.hurt_time == 0.0 and boss.visual.hurt_flash_lock > 0.0, "flash has ended but repeat contacts are still gated")
	await frames(7)
	boss.visual.play_hurt()
	check(boss.visual.hurt_time > 0.0, "a hit after the gate can flash again")

func test_cover() -> void:
	game.enter_title_screen()
	root.size = Vector2i(1280, 720)
	await frames(8)
	var hud = game.hud
	check(game.phase == "title" and hud.title_start_btn.text == "踏入仙途" and hud.title_controls_label.visible
		and hud.title_main_label.get_child_count() == 1, "title uses the new composition and keeps start and controls")
	check(absf(hud.title_start_btn.get_global_rect().get_center().x - hud.root.size.x * 0.5) <= 1.0, "start button remains centered")
	await shot("03-wenjian-cover")
	root.size = Vector2i(960, 540)
	await frames(8)
	var viewport_bounds := Rect2(Vector2.ZERO, hud.root.size)
	check(viewport_bounds.encloses(hud.title_start_btn.get_global_rect()) and viewport_bounds.encloses(hud.title_controls_label.get_global_rect()),
		"start button and input legend fit at the smaller window size")
	await shot("03-wenjian-cover-960")

func test_defeat() -> void:
	enter(3, 25, [POOL.Card.LOTUS, POOL.Card.WIDE])
	game.cultivation_override = 1
	var player = game.player
	var foes := get_nodes_in_group("enemies")
	foes[0].take_damage(9000.0, Vector2.ZERO, true)
	player.stamina = 12.0
	player.dash_cooldown = 1.1
	player.sword_rain_cooldown = 9.0
	player.take_damage(9000.0, Vector2.ZERO)
	check(game.phase == "defeat_transition" and Engine.time_scale < 1.0 and not game.hud.minimal_layer.visible, "lethal damage enters slow motion and hides combat HUD")
	await frames(16)
	check(game.phase == "defeat_transition" and not paused and game.hud.defeat_ink.material.get_shader_parameter("amount") < 1.0, "defeat fades gradually")
	await frames(22)
	check(game.phase == "dead" and paused and Engine.time_scale == 1.0 and root.gui_get_focus_owner() == game.hud.defeat_retry, "defeat completes with retry focused and time restored")
	key(KEY_ENTER)
	player = game.player
	check(game.phase == "combat" and not paused and game.room_index == 3 and game.wave_index == 0
		and game.run_kills == 25 and player.health == player.max_health and player.stamina == player.max_stamina,
		"Enter retries the whole room without double-counting room kills")
	check(player.cultivation == 1 and player.card_level(POOL.Card.WIDE) == 1 and player.card_level(POOL.Card.LOTUS) == 1
		and player.dash_cooldown == 0.0 and player.sword_rain_cooldown == 0.0 and not game.hud.defeat_ink.visible,
		"retry keeps cultivation and cards while clearing combat presentation and cooldowns")

	enter(CONFIG.BOSS_ROOM, 87, [POOL.Card.RAIN])
	player = game.player
	player.position = Vector2(655, 491)
	game.boss.position = Vector2(816, 346)
	game.boss.trigger_demon_domain(DOMAIN.Pattern.WHEEL)
	player.take_damage(9000.0, Vector2.ZERO)
	check(not game.boss.domain_active and not game.hud.boss_mechanic.visible, "defeat cancels a live boss hazard and its warning")
	await frames(42)
	await shot("02-defeat")
	var restart: Button
	for button in game.hud.modal_panel.find_children("*", "Button", true, false):
		if button.text == "重入仙途":
			restart = button
	check(is_instance_valid(restart), "result exposes a fresh run action")
	if is_instance_valid(restart):
		restart.pressed.emit()
	check(game.room_index == 0 and game.run_kills == 0 and game.player.cultivation == 0
		and game.player.card_level(POOL.Card.RAIN) == 0 and not paused and not game.hud.defeat_ink.visible,
		"fresh run clears all progress and ink overlay")

func run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	if capture:
		DirAccess.make_dir_recursive_absolute(CAPTURES)
	game = load("res://scenes/main_v41.tscn").instantiate()
	game.skip_title_screen = true
	root.add_child(game)
	current_scene = game
	await frames()
	await test_ultimate()
	await test_patterns()
	await test_throw_feedback()
	await test_defeat()
	await test_cover()
	game.free()
	await frames()
	print("SECOND_PASS_RESULT checks=", checks, " failures=", failures)
	quit(1 if failures > 0 else 0)

extends SceneTree

var checks := 0
var failures := 0
var game
var player
var sword

func _initialize() -> void:
	Engine.physics_ticks_per_second = 100
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS: " if ok else "FAIL: ") + message)

func tick(count: int = 1, delta: float = 0.01) -> void:
	for i in range(count):
		player._physics_process(delta)
		sword._physics_process(delta)
		player.visual._physics_process(delta)

func bind_player() -> void:
	player = game.player
	sword = player.weapon
	player.set_physics_process(false)
	sword.set_physics_process(false)
	player.visual.set_physics_process(false)
	game.set_physics_process(false)
	player._has_aim_event = false
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	player.aim_direction = Vector2.RIGHT
	# Fix a viewport target for deterministic cursor-independent input tests.
	player._has_aim_event = true
	player._aim_viewport_position = root.get_canvas_transform() * (player.global_position + Vector2(400, 0))

func reset() -> void:
	game.start_room()
	bind_player()

func enemy_at(point: Vector2) -> SurvivorEnemy:
	var enemy: SurvivorEnemy = game.ENEMY.instantiate()
	enemy.world = game.world
	enemy.dodge_enabled = false
	enemy.position = point
	game.world.actors.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.collision_layer = 0
	return enemy

func mouse_press(pressed: bool) -> void:
	if pressed:
		Input.action_press("attack")
	else:
		Input.action_release("attack")
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = Vector2(640, 360)
	root.push_input(event, true)

func snapshot(name: String) -> void:
	await process_frame
	await process_frame
	var bounds := Rect2(Vector2.ZERO, game.hud.root.size).grow(1.0)
	for panel in game.hud.combat_panels:
		check(bounds.encloses(panel.get_global_rect()), name + " HUD fits")
	if game.hud.overlay.visible:
		check(bounds.encloses(game.hud.modal_panel.get_global_rect()), name + " modal fits")
	if OS.get_cmdline_user_args().has("--visual"):
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/runtime/v33_visual/" + name + ".png")

func run() -> void:
	game = load("res://scenes/main_v33.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	bind_player()
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/main_v33.tscn", "F5 starts V3.3")
	check(game.total == 4 and game.remaining == 4 and get_nodes_in_group("enemies").size() == 4, "four enemies appear immediately")
	for enemy in get_nodes_in_group("enemies"):
		check(enemy.kind == SurvivorEnemy.Kind.HOSTILE and not enemy.emerging and not enemy.dodge_enabled and enemy.encounter_id == -1, "existing ordinary melee AI without emergence")
		check(enemy.position.x >= game.world.cell_center(Vector2i(21, 14)).x and enemy.position.distance_to(player.position) > 100.0, "spawn on right away from hero")
	check(game.world.triggered.all(func(value): return value) and game.encounters.is_empty(), "old triggers inactive with no pending spawn")
	for i in range(6):
		player.position.x = game.world.cell_center(Vector2i(game.world.TRIGGER_X[i], 14)).x
		game._physics_process(1.0)
	check(get_nodes_in_group("enemies").size() == 4, "walking former triggers never adds enemies")
	reset()
	for stage in range(3):
		if stage == 0:
			sword.queue_click()
			tick()
		check(sword.stage == stage, "combo stage %d" % (stage + 1))
		var origin: Vector2 = player.position
		var target := enemy_at(player.position + Vector2(65, 0))
		var hp := target.health
		# Inspect just before each independent windup completes.
		var data: Dictionary = sword.current_data()
		while (sword.swing_duration - sword.swing_time) + 0.01001 < float(data.windup):
			tick()
		check(target.health == hp, "stage %d does no early windup damage" % stage)
		var direction: Vector2 = sword.swing_direction
		player._aim_viewport_position = root.get_canvas_transform() * (player.position + Vector2(0, 400))
		while sword.swing_time > 0.13:
			tick()
		check(sword.swing_direction.is_equal_approx(direction), "stage %d direction remains locked" % stage)
		check(is_equal_approx(hp - target.health, float(data.damage)), "stage %d has one timed damage hit" % stage)
		check(absf(player.position.distance_to(origin) - float(data.lunge)) < 0.01, "stage %d short lunge distance actual=%.3f" % [stage, player.position.distance_to(origin)])
		var hit_hp := target.health
		if stage < 2:
			sword.queue_click()
		player._aim_viewport_position = root.get_canvas_transform() * (player.position + Vector2(400, 0))
		while sword.swing_time > 0.0:
			tick()
		check(target.health == hit_hp, "stage %d recovery never hits again" % stage)
		target.free()
		if stage < 2:
			tick()
	check(sword.next_stage == 0, "third stage returns to first")
	tick(50)
	var still: Vector2 = player.position
	tick(20)
	check(player.position.is_equal_approx(still), "no lunge sliding after completion")
	reset()
	sword.attack(Vector2.RIGHT)
	var near := enemy_at(player.position + Vector2(55, -30))
	var far := enemy_at(player.position + Vector2(80, -43))
	tick(40)
	check(near.health == near.max_health - 32.0 and far.health == far.max_health, "simultaneous contacts choose nearest, one target maximum")
	reset()
	# Same target may take one hit on each of the three separate stages.
	var persistent := enemy_at(player.position + Vector2(60, 0))
	for i in range(3):
		persistent.position = player.position + Vector2(60, 0)
		sword.attack(Vector2.RIGHT)
		while sword.swing_time > 0.0:
			tick()
	check(is_equal_approx(persistent.max_health - persistent.health, 132.0), "same enemy can receive all three stages")
	reset()
	sword.attack(Vector2.RIGHT)
	tick(40)
	tick(40)
	sword.attack(Vector2.RIGHT)
	check(sword.stage == 0, "chain window expiry resets first stage")
	reset()
	mouse_press(true)
	tick(150)
	check(sword.attack_count == 1, "held left mouse never auto repeats")
	mouse_press(false)
	reset()
	sword.attack(Vector2.RIGHT)
	sword.queue_click()
	tick(45)
	check(sword.attack_count == 1, "expired early click is discarded")
	reset()
	sword.attack(Vector2.RIGHT)
	sword.queue_roll()
	tick(10)
	check(not player.is_rolling() and not sword.roll_queued and sword.swing_time > 0.0, "early Space cannot cancel windup")
	sword.queue_roll()
	tick(10)
	check(not player.is_rolling() and not sword.roll_queued, "Space cannot cancel active phase")
	while sword.swing_time > 0.11:
		tick()
	sword.queue_roll()
	sword.queue_click()
	check(sword.roll_queued and not player.is_rolling(), "last recovery window buffers without cancelling")
	while sword.swing_time > 0.0:
		tick()
	Input.action_press("move_up")
	tick()
	Input.action_release("move_up")
	check(player.is_rolling() and player._roll_direction == Vector2.UP and sword.attack_count == 1 and sword.click_time == 0.0, "roll wins over buffered sword and reads execution-time direction")
	check(player.stamina == 70.0 and player.invulnerability == 0.0, "roll cost preserved, no new invulnerability")
	for aim in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		reset()
		sword.next_stage = 2
		sword.chain_time = 1.0
		sword.attack(aim)
		var raised: PackedVector2Array = sword.blade_segment(0.0)
		var lowered: PackedVector2Array = sword.blade_segment(1.0)
		check(is_equal_approx(lowered[1].y - raised[1].y, 52.0) and is_equal_approx(lowered[0].y - raised[0].y, 20.0), "heavy blade drops downward for aim %s" % aim)
		var target := enemy_at(player.position + aim * 65.0)
		var hp := target.health
		tick(10)
		sword.queue_roll()
		check(not sword.roll_queued and not sword.can_roll(), "third windup remains noncancelable %s" % aim)
		while sword.time_until_roll() > 0.11:
			tick()
		sword.queue_roll()
		sword.queue_click()
		check(sword.roll_queued and not player.is_rolling(), "third downswing buffers roll without early cancellation %s" % aim)
		while not sword.can_roll():
			tick()
		check(sword.swing_time > 0.25 and hp - target.health == 60.0, "third hit completes while recovery remains %s" % aim)
		tick()
		check(player.is_rolling() and sword.swing_time == 0.0 and sword.click_time == 0.0, "roll immediately cancels third recovery and next click %s" % aim)
	reset()
	sword.next_stage = 2
	sword.chain_time = 1.0
	sword.attack(Vector2.RIGHT)
	while not sword.can_roll():
		tick()
	sword.queue_roll()
	tick()
	check(player.is_rolling(), "third miss can roll at downswing end, no hit-confirm requirement")
	for blocked_by in ["stamina", "cooldown"]:
		reset()
		sword.attack(Vector2.RIGHT)
		while sword.swing_time > 0.11:
			tick()
		sword.queue_roll()
		if blocked_by == "stamina":
			player.stamina = 0.0
		else:
			player._roll_cooldown = 1.0
		while sword.swing_time > 0.0:
			tick()
		tick()
		check(not player.is_rolling() and not sword.roll_queued, blocked_by + " prevents and discards buffered roll")
		tick(150)
		check(not player.is_rolling(), blocked_by + " never causes delayed roll")
	reset()
	sword.attack(Vector2.RIGHT)
	player._ranged_held = true
	Input.action_press("ranged_attack")
	tick(20)
	check(player.ranged_weapon.attack_count == 0, "bow cannot cancel sword")
	tick(20)
	check(player.ranged_weapon.attack_count > 0, "bow can fire after full sword recovery")
	check(is_equal_approx(player.visual.attack_duration, player.ranged_weapon.swing_duration), "bow pose keeps its own duration after combo")
	Input.action_release("ranged_attack")
	for notification in [Node.NOTIFICATION_PAUSED, Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		reset()
		sword.attack(Vector2.RIGHT)
		while sword.swing_time > 0.11:
			tick()
		sword.queue_roll()
		sword.queue_click()
		player.notification(notification)
		check(not sword.roll_queued and sword.click_time == 0.0, "pause/focus notification clears combo buffers")
	reset()
	sword.attack(Vector2.RIGHT)
	sword.queue_click()
	player.take_damage(10000, Vector2.ZERO)
	check(sword.swing_time == 0.0 and sword.click_time == 0.0 and not sword.roll_queued and paused, "death cancels action and inputs")
	reset()
	# Real wall collider blocks both sword hits and active lunge movement.
	player.position = game.world.cell_center(Vector2i(13, 13))
	player._aim_viewport_position = root.get_canvas_transform() * (player.position + Vector2(0, -400))
	var behind_wall := enemy_at(game.world.cell_center(Vector2i(13, 12)))
	await physics_frame
	sword.attack(Vector2.UP)
	tick(40)
	check(behind_wall.health == behind_wall.max_health, "wall blocks swept blade damage")
	reset()
	player.position = Vector2(game.world.cell_center(Vector2i(13, 13)).x, game.world.TOP * game.world.CELL + 14.1)
	player._aim_viewport_position = root.get_canvas_transform() * (player.position + Vector2(0, -400))
	await physics_frame
	sword.attack(Vector2.UP)
	tick(40)
	check(player.position.y >= game.world.TOP * game.world.CELL + 13.9, "lunge respects wall collision")
	reset()
	for enemy in get_nodes_in_group("enemies"):
		enemy.take_damage(10000, Vector2.ZERO)
		await process_frame
	check(game.remaining == 0 and game.world.portal_open and not paused, "four kills open exit without auto completion")
	player.position = game.world.cell_center(game.world.PORTAL_CELL)
	game._physics_process(0.01)
	check(game.phase == "cleared" and paused, "portal completes four-monster trial")
	for dimensions in [Vector2i(960, 540), Vector2i(1280, 720)]:
		root.size = dimensions
		reset()
		await snapshot("combat_%dx%d" % [dimensions.x, dimensions.y])
		game.toggle_stats()
		await snapshot("stats_%dx%d" % [dimensions.x, dimensions.y])
		game.resume_room()
		game.toggle_pause()
		await snapshot("pause_%dx%d" % [dimensions.x, dimensions.y])
		game.resume_room()
		for i in range(3):
			sword.attack(Vector2.RIGHT)
			tick(int((float(sword.current_data().windup) + float(sword.current_data().active) * 0.5) / 0.01))
			await snapshot("stage%d_%dx%d" % [i + 1, dimensions.x, dimensions.y])
			while sword.swing_time > 0.0:
				tick()
	if OS.get_cmdline_user_args().has("--visual"):
		root.size = Vector2i(1280, 720)
		var aims := [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]
		for i in range(aims.size()):
			reset()
			player.position = game.world.cell_center(Vector2i(19, 14))
			sword.next_stage = 2
			sword.chain_time = 1.0
			sword.attack(aims[i])
			tick(16)
			await snapshot("heavy_aim%d_raised" % i)
			tick(7)
			await snapshot("heavy_aim%d_middle" % i)
			tick(7)
			await snapshot("heavy_aim%d_lowered" % i)
	paused = false
	game.queue_free()
	await process_frame
	print("SWORD COMBO: %d checks, %d failures; controlled fixtures, not human playtest" % [checks, failures])
	quit(1 if failures else 0)

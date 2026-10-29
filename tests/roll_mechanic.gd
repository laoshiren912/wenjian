extends "res://tests/v21_animation.gd"

const ROLL_OUTPUT := "res://artifacts/roll_visual_2026-10-28/"

func fresh(index: int = 0) -> void:
	movement(Vector2.ZERO)
	Input.action_release("attack")
	Input.action_release("roll")
	game.restart_run()
	await frames(4)
	game = current_scene
	game.select_profession(index)
	game.start_run()
	game.spawn_timer = 9999
	clear_targets()

func roll_frames() -> int:
	return ceili(game.player.roll_duration * Engine.physics_ticks_per_second) + 2

func space(pressed: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	event.physical_keycode = KEY_SPACE
	event.pressed = pressed
	event.echo = echo
	root.push_input(event, true)

func mouse(pressed: bool) -> void:
	if pressed:
		Input.action_press("attack")
	else:
		Input.action_release("attack")
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = Vector2(840, 360)
	event.pressed = pressed
	root.push_input(event, true)

func capture_roll(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var frame: Image = root.get_texture().get_image()
	check(frame.save_png(ROLL_OUTPUT + name + ".png") == OK, "Native render " + name)
	if name.begins_with("01") or name.begins_with("02") or name.begins_with("03"):
		var center: Vector2 = game.player.get_global_transform_with_canvas().origin
		var crop := frame.get_region(Rect2i(int(center.x) - 48, int(center.y) - 48, 96, 96))
		crop.resize(576, 576, Image.INTERPOLATE_NEAREST)
		check(crop.save_png(ROLL_OUTPUT + name + "_detail.png") == OK, "Native roll detail " + name)
	else:
		var in_bounds: bool = true
		for control in game.hud.root.find_children("*", "Control", true, false):
			if control.is_visible_in_tree():
				in_bounds = in_bounds and root.get_visible_rect().grow(1).encloses(control.get_global_rect())
		check(in_bounds, "Visible help, attributes and pause controls remain within the viewport: " + name)

func visuals() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROLL_OUTPUT))
	await fresh()
	game.player.camera.position_smoothing_enabled = false
	game.player._movement_facing = Vector2.RIGHT
	game.player.try_roll()
	await frames(3)
	await capture_roll("01_roll_start")
	await frames(4)
	await capture_roll("02_roll_middle")
	await frames(14)
	await capture_roll("03_roll_finished")
	game.show_stats()
	await capture_roll("04_roll_attributes")
	game.resume_run()
	await fresh()
	game.toggle_pause()
	await capture_roll("05_pause")
	game.restart_run()
	await frames(4)
	game = current_scene
	await capture_roll("06_start_help")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.title = "Roll Mechanic Checks"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frames()
	if OS.get_cmdline_user_args().has("--render"):
		await visuals()
		print("ROLL VISUAL RESULT: %d checks, %d failures; controlled native renders, not input tests" % [checks, failures])
		paused = false
		quit(0 if failures == 0 else 1)
		return
	check(InputMap.has_action("roll"), "Space roll action is installed")
	space(true)
	space(false)
	await frames(3)
	check(game.state == SurvivorGame.State.PLAYING and not game.player.is_rolling() and game.player.stamina == 100, "Space can accept the start button without leaking into a roll")
	game.spawn_timer = 9999
	clear_targets()
	for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN, Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]:
		await fresh()
		var player: SurvivorPlayer = game.player
		movement(direction)
		var before: Vector2 = player.position
		check(player.try_roll() and player.stamina == 70 and is_equal_approx(player.stamina_delay, 0.42), "Roll %s charges 30 once and starts existing recovery delay" % direction)
		movement(Vector2.ZERO)
		check(not player.try_roll() and player.stamina == 70, "Active roll cannot restart or spend stamina twice")
		await frames(4)
		check(player.is_rolling() and player.visual.roll_time > 0 and not player.weapon.visible and player.rotation == 0 and player.get_node("CollisionShape2D").rotation == 0, "Only the body visual tumbles; the collider and actor never rotate")
		await frames(roll_frames())
		var displacement: Vector2 = player.position - before
		check(absf(displacement.length() - 150.0) < 0.5 and displacement.normalized().dot(direction.normalized()) > 0.999, "Roll %s travels 150 without diagonal acceleration" % direction)
		check(not player.is_rolling() and player.visual.rotation == 0 and player.visual.scale == Vector2.ONE and player.weapon.visible, "Roll ends in a clean standing pose")
		check(not player.try_roll(), "Cooldown still blocks a new roll after movement ends")
	await fresh()
	var player: SurvivorPlayer = game.player
	player._movement_facing = Vector2.LEFT
	await aim(Vector2.RIGHT)
	var before: Vector2 = player.position
	space(true)
	space(false)
	await frames(3)
	check(player.is_rolling() and player._roll_direction == Vector2.LEFT and player.stamina == 70, "A same-frame Space tap rolls toward last movement direction")
	movement(Vector2.RIGHT)
	await frames(3)
	check(player._roll_direction == Vector2.LEFT and player.visual.facing == Vector2.LEFT, "Changing WASD mid-roll cannot steer or turn the roll")
	movement(Vector2.ZERO)
	await frames(35)
	check(absf(player.position.x - before.x + 150) < 0.5, "Standing roll retains its full configured distance")
	space(true, true)
	space(false)
	await frames(3)
	check(not player.is_rolling(), "Keyboard auto-repeat does not trigger another roll after cooldown")
	await fresh()
	player = game.player
	player.roll_distance = 120
	player.roll_duration = 0.20
	player.roll_stamina_cost = 20
	player.roll_cooldown = 0.80
	before = player.position
	player.try_roll()
	check(player.stamina == 80 and is_equal_approx(player._roll_cooldown, 0.80), "Inspector parameters change cost and cooldown without code edits")
	await frames(16)
	check(absf(player.position.distance_to(before) - 120) < 0.5 and not player.is_rolling(), "Inspector distance and duration control actual physics movement")
	await fresh()
	player = game.player
	var wall := StaticBody2D.new()
	wall.position = player.position + Vector2(80, 0)
	wall.collision_layer = 1
	wall.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(16, 120)
	shape.shape = rectangle
	wall.add_child(shape)
	game.world.add_child(wall)
	await frames(2)
	movement(Vector2.RIGHT)
	before = player.position
	player.try_roll()
	movement(Vector2.ZERO)
	await frames(roll_frames())
	check(player.position.x <= wall.position.x - 8 - 13.9 and player.position.x > before.x, "A real physics wall stops the full roll without teleporting through")
	player._roll_cooldown = 0
	movement(Vector2.RIGHT)
	player.try_roll()
	movement(Vector2.ZERO)
	before = player.position
	await frames(roll_frames())
	check(player.position.distance_to(before) < 0.5 and not player.is_rolling(), "Rolling while pressed against the wall cannot cross it or become stuck in roll state")
	await fresh()
	player = game.player
	player.position = Vector2(79, 640)
	movement(Vector2.LEFT)
	player.try_roll()
	movement(Vector2.ZERO)
	await frames(20)
	check(player.position.x >= 77.9, "The existing outer map boundary also blocks a roll")
	await fresh()
	player = game.player
	check(is_equal_approx(player.roll_duration, 0.34) and is_equal_approx(player.roll_distance, 150), "Tuned default extends duration to 0.34 seconds while keeping 150 distance")
	check(is_equal_approx(player.roll_stamina_cost, 30) and is_equal_approx(player.roll_cooldown, 0.65), "Roll cost and start-based cooldown retain their original values")
	movement(Vector2.RIGHT)
	before = player.position
	player.try_roll()
	await frames(10)
	var elapsed: float = player.roll_duration - player._roll_remaining
	check(player.is_rolling() and elapsed > 0.14 and elapsed < 0.20 and absf(player.position.distance_to(before) - elapsed * 150.0 / 0.34) < 0.5, "Early displacement follows the slower configured speed instead of finishing abruptly")
	check(is_equal_approx(player.visual.roll_duration, player.roll_duration) and player.visual.roll_time > 0, "Body animation automatically uses the longer player roll duration")
	while player.is_rolling():
		await frames(1)
	var after_roll: Vector2 = player.position
	check(after_roll.x - before.x >= 149.5 and after_roll.x - before.x <= 154.0, "Holding movement through roll retains its distance with at most one normal walk tick")
	await frames(6)
	check(player.position.x > after_roll.x + 18 and absf(player.get_real_velocity().x - player.speed) < 0.5, "Held movement resumes at the original walk speed immediately after roll")
	movement(Vector2.ZERO)
	await frames(2)
	before = player.position
	await frames(4)
	check(player.position.distance_to(before) < 0.1 and player.visual.rotation == 0 and player.weapon.visible, "Releasing movement stops cleanly after the longer roll")
	for index in range(3):
		await fresh(index)
		player = game.player
		player.weapon.select_weapon((index + 2) % 3)
		player.try_roll()
		var event := InputEventKey.new()
		event.keycode = KEY_1 + (index + 1) % 3
		event.physical_keycode = event.keycode
		event.pressed = true
		root.push_input(event, true)
		event = event.duplicate()
		event.pressed = false
		root.push_input(event, true)
		mouse(true)
		await frames(10)
		check(player.is_rolling() and player.weapon.selected == index and player.weapon.attack_count == 0 and not player.weapon.visible, "Locked weapon %d rejects switching during roll without attacking or showing an old pose" % (index + 1))
		await frames(roll_frames())
		check(not player.is_rolling() and player.weapon.attack_count >= 1 and player.weapon.swing_weapon == index and player.weapon.visible, "Weapon %d held attack starts with the selected weapon after the longer roll" % (index + 1))
		mouse(false)
	await fresh()
	player = game.player
	player.stamina = 29
	player.stamina_delay = 5
	before = player.position
	check(not player.try_roll() and player.stamina == 29 and player._roll_cooldown == 0 and player.dry_attack_flash > 0, "Insufficient stamina rejects roll without charging or starting cooldown")
	await frames(2)
	check(player.position == before, "Rejected roll creates no displacement")
	for index in range(3):
		await fresh(index)
		player = game.player
		player.stamina = 29
		player.stamina_delay = 5
		player.weapon.cooldown = 0
		var stamina_before: float = player.stamina
		check(player.weapon.attack(Vector2.RIGHT) and player.stamina == stamina_before, "Weapon %d still attacks for free with insufficient roll stamina" % (index + 1))
	await fresh()
	player = game.player
	var successful: int = 0
	while successful < 8 and player.try_roll():
		successful += 1
		while player.is_rolling() or player._roll_cooldown > 0:
			await frames(1)
	check(successful >= 2 and successful < 8 and player.stamina < player.roll_stamina_cost, "Repeated rolls with real cooldown exhaust available stamina")
	var shortage: float = player.stamina
	await frames(15)
	check(player.stamina > shortage, "An exhausted resource resumes its original recovery")
	var recovery_frames: int = ceili((player.max_stamina - player.stamina) / player.stamina_regen * 60 + player.stamina_delay * 60) + 2
	print("ROLL RECOVERY: stamina=%.3f regen=%.1f waiting=%d frames" % [player.stamina, player.stamina_regen, recovery_frames])
	await frames(recovery_frames)
	check(player.stamina == 100 and player.try_roll(), "Recovery clamps at the original cap and allows rolling again")
	for index in range(3):
		await fresh(index)
		player = game.player
		var attack_frames: Array[int] = []
		var record_attack: Callable = func(_index: int, _direction: Vector2): attack_frames.append(Engine.get_physics_frames())
		player.weapon.attack_started.connect(record_attack)
		mouse(true)
		await frames(2)
		var attacks: int = player.weapon.attack_count
		var cooldown: float = player.weapon.cooldown
		check(attacks == 1 and player.try_roll() and player.weapon.cooldown == cooldown, "Weapon %d can transition from an attack to roll without resetting attack cooldown" % (index + 1))
		check(not player.weapon.attack(Vector2.RIGHT) and player.weapon.attack_count == attacks, "Weapon %d direct attack API also rejects rolling attacks" % (index + 1))
		await frames(10)
		check(player.is_rolling() and player.weapon.attack_count == attacks and player.stamina == 70, "Weapon %d held input cannot attack during roll" % (index + 1))
		await frames(45)
		check(player.weapon.attack_count > attacks and player.stamina > 70, "Weapon %d held attack resumes after roll without consuming or interrupting stamina recovery" % (index + 1))
		var intervals_valid: bool = true
		for tick in range(1, attack_frames.size()):
			intervals_valid = intervals_valid and (attack_frames[tick] - attack_frames[tick - 1]) / 60.0 + 0.0001 >= float(SurvivorWeapon.DATA[index].cooldown)
		check(attack_frames.size() >= 2 and intervals_valid, "Weapon %d attacks around a roll still respect the original attack interval" % (index + 1))
		player.weapon.attack_started.disconnect(record_attack)
		mouse(false)
	await fresh()
	player = game.player
	player.try_roll()
	mouse(true)
	mouse(false)
	await frames(40)
	check(player.weapon.attack_count == 0, "A short attack clicked only during roll is not buffered for later")
	await fresh(2)
	player = game.player
	var enemy := target_at(70)
	player.weapon.attack(Vector2.RIGHT)
	movement(Vector2.LEFT)
	player.try_roll()
	movement(Vector2.ZERO)
	await frames(7)
	check(player.is_rolling() and is_equal_approx(enemy.health, enemy.max_health - 21), "An already-fired arrow keeps moving and damaging during roll")
	await fresh()
	player = game.player
	player.try_roll()
	check(player.invulnerability == 0 and player.take_damage(12, Vector2.LEFT) and player.health == 88 and player.invulnerability == 0.7, "Roll adds no invulnerability and preserves normal damage and post-hit protection")
	check(not player.take_damage(12, Vector2.LEFT) and player.health == 88, "The original post-hit protection still rejects immediate repeated damage")
	await fresh()
	player = game.player
	player.try_roll()
	await frames(3)
	game.toggle_pause()
	var remaining: float = player._roll_remaining
	var cooldown: float = player._roll_cooldown
	var stamina: float = player.stamina
	before = player.position
	var visual_time: float = player.visual.roll_time
	await frames(20)
	check(player.position == before and player._roll_remaining == remaining and player._roll_cooldown == cooldown and player.stamina == stamina and player.visual.roll_time == visual_time, "Pause freezes roll displacement, animation, cooldown and resource recovery together")
	space(true)
	space(false)
	await frames(25)
	check(not paused and not player.is_rolling() and player.stamina < 100, "Space accepts Continue without queuing an extra roll")
	await fresh()
	player = game.player
	space(true)
	space(false)
	game.toggle_pause()
	game.resume_run()
	await frames(3)
	check(not player.is_rolling() and player.stamina == 100, "Pause clears an unprocessed roll press before resume")
	game.player.gain_experience(game.player.next_level_xp - game.player.experience)
	await frames(2)
	space(true)
	space(false)
	await frames(3)
	check(not paused and player.is_rolling() and player.skill_points == 1, "Space rolls normally immediately after gaining a skill point")
	await fresh()
	player = game.player
	player.try_roll()
	player.take_damage(10000, Vector2.ZERO)
	check(game.state == SurvivorGame.State.DEAD and not player.is_rolling() and player.visual.roll_time == 0 and player.visual.rotation == 0, "Death cancels active roll and restores the visual before settlement")
	await fresh()
	check(game.player.stamina == 100 and not game.player.is_rolling() and game.player._roll_cooldown == 0, "Restart resets roll timers, resource and animation state")
	print("ROLL RESULT: %d checks, %d failures" % [checks, failures])
	paused = false
	quit(0 if failures == 0 else 1)

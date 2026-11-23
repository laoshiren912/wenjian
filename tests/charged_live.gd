extends "res://tests/combo_live.gd"

func setup_room() -> void:
	game.start_room()
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)

func run() -> void:
	game = load("res://scenes/sword_motion_combat.tscn" if OS.get_cmdline_user_args().has("--motion") else "res://scenes/sword_motion_combat.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frames(2)
	setup_room()
	var player = game.player
	var sword = player.combo
	mouse(true)
	await frames(10)
	check(sword.attack_count == 0 and not sword.charging, "60 Hz press has no premature ordinary hit")
	mouse(false)
	await frames(1)
	check(sword.attack_count == 1 and sword.stage == 0, "60 Hz short release starts ordinary sword")
	setup_room()
	player = game.player
	sword = player.combo
	mouse(true)
	await frames(14)
	check(sword.charging and sword.attack_count == 0, "60 Hz GUI long hold enters charge only")
	var origin: Vector2 = player.position
	Input.action_press("move_right")
	await frames(6)
	Input.action_release("move_right")
	check(player.position.x > origin.x + 15.0 and sword.charging, "60 Hz charge remains mobile")
	await frames(36)
	check(sword.charge_fraction() == 1.0 and sword.attack_count == 0, "60 Hz full charge remains held")
	mouse(false)
	await frames(1)
	check(sword.attack_count == 1 and sword.charged_swing and not sword.charging, "60 Hz release fires charged sword without ordinary extra")
	await frames(45)
	check(sword.attack_count == 1 and sword.swing_time == 0.0, "60 Hz release does not repeat")
	setup_room()
	player = game.player
	sword = player.combo
	mouse(true)
	await frames(30)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = root.get_canvas_transform() * (player.global_position + Vector2(0, -200))
	Input.action_release("attack")
	root.push_input(release, true)
	var after_release := InputEventMouseMotion.new()
	after_release.position = root.get_canvas_transform() * (player.global_position + Vector2(200, 0))
	root.push_input(after_release, true)
	await frames(1)
	check(sword.swing_direction.is_equal_approx(Vector2.UP), "release locks event-time aim even if mouse moves before physics frame")
	# Same-frame roll and release should roll, not launch a locked heavy attack.
	setup_room()
	player = game.player
	sword = player.combo
	mouse(true)
	await frames(30)
	var space := InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	space.keycode = KEY_SPACE
	space.pressed = true
	root.push_input(space, true)
	mouse(false)
	await frames(1)
	check(player.is_rolling() and sword.attack_count == 0 and not sword.charging, "60 Hz roll wins over simultaneous charge release")
	await frames(30)
	check(sword.attack_count == 0, "60 Hz cancelled charge does not create delayed ordinary hit")
	setup_room()
	player = game.player
	sword = player.combo
	mouse(true)
	await frames(25)
	game.toggle_pause()
	check(not sword.gesture_held and not sword.charging, "60 Hz pause cancels held charge")
	mouse(false)
	game.resume_room()
	await frames(30)
	check(sword.attack_count == 0, "60 Hz release across pause cannot fire")
	# GUI-acquired gesture dragged out to world must never start a charge.
	var hud_button: Button
	for button in game.hud.root.find_children("*", "Button", true, false):
		if button.text.begins_with("角色属性"):
			hud_button = button
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.position = hud_button.get_global_rect().get_center()
	down.pressed = true
	root.push_input(down, true)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(600, 340)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion, true)
	await frames(55)
	mouse(false)
	await frames(2)
	check(not sword.gesture_held and not sword.charging and sword.attack_count == 0, "60 Hz GUI press dragged into world never charges or attacks")
	game.resume_room()
	setup_room()
	mouse(true)
	await frames(30)
	game.start_room()
	await frames(1)
	mouse(false)
	await frames(2)
	check(not game.player.combo.charging and game.player.combo.attack_count == 0, "60 Hz restart with held mouse cannot fire on release")
	paused = false
	game.queue_free()
	await process_frame
	print("CHARGED LIVE: %d checks, %d failures; engine-dispatched input, not human playtest" % [checks, failures])
	quit(1 if failures else 0)

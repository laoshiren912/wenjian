extends "res://tests/sword_combo.gd"

func prepare(kind: int, aim: Vector2) -> void:
	reset()
	player.aim_direction = aim
	player._aim_viewport_position = root.get_canvas_transform() * (player.global_position + aim * 300.0)
	if kind < 3:
		sword.next_stage = kind
		sword.chain_time = 1.0
		sword.attack(aim)
	else:
		sword.press_primary()
		tick(82)
		sword.release_primary()

func capture(label: String) -> void:
	await process_frame
	await process_frame
	if OS.get_cmdline_user_args().has("--visual"):
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/sword_motion_2026-11-03/" + label + ".png")

func click_control(text: String) -> void:
	for button in game.hud.root.find_children("*", "Button", true, false):
		if button.text == text:
			var press := InputEventMouseButton.new()
			press.button_index = MOUSE_BUTTON_LEFT
			press.position = button.get_global_rect().get_center()
			press.pressed = true
			root.push_input(press, true)
			press = press.duplicate()
			press.pressed = false
			root.push_input(press, true)
			return
	check(false, "missing control: " + text)

func run() -> void:
	game = load("res://scenes/sword_motion_trial.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	bind_player()
	check(get_nodes_in_group("enemies").is_empty() and game.remaining == 0, "motion trial opens empty, no combat pressure")
	check(game.get_node("Camera2D").zoom == Vector2.ONE * 1.8, "motion trial magnifies existing player")
	await capture("trial_idle")
	# Reach and motion rotate with aim in all eight directions, including diagonals.
	for kind in range(4):
		prepare(kind, Vector2.RIGHT)
		var reference: Array[PackedVector2Array] = []
		for progress in [0.0, 0.5, 1.0]:
			reference.append(sword.blade_segment(progress))
		for direction_index in range(8):
			var angle := direction_index * TAU / 8.0
			var aim := Vector2.RIGHT.rotated(angle)
			prepare(kind, aim)
			var equivariant := true
			for i in range(3):
				var segment: PackedVector2Array = sword.blade_segment(i / 2.0)
				for j in range(2):
					equivariant = equivariant and segment[j].distance_to(reference[i][j].rotated(angle)) < 0.001
			check(equivariant, "attack %d rotates full blade and hilt for aim %d" % [kind, direction_index])
			var target := enemy_at(player.position + aim * 65.0)
			target.max_health = 1000.0
			target.health = 1000.0
			var data: Dictionary = sword.current_data()
			tick(int(round((float(data.windup) + float(data.active) * 0.5) * 100.0)))
			var pose: Dictionary = sword.motion_pose()
			var blade: PackedVector2Array = sword.blade_segment(sword.active_progress(sword.swing_time))
			check((pose.grip as Vector2).distance_to(blade[0]) < 0.001 and (pose.tip as Vector2).distance_to(blade[1]) < 0.001 and (player.visual.sword_pose.grip as Vector2).distance_to(blade[0]) < 0.001, "hands, drawn blade and damage share pose %d/%d" % [kind, direction_index])
			check(sword.z_index == (0 if (pose.grip as Vector2).y < -3.0 else 2) and player.visual.z_index == 1, "front/back sword layering above floor %d/%d" % [kind, direction_index])
			# Remove fixture before visual snapshot so the action is easy to inspect.
			while sword.swing_time > 0.0:
				tick()
			check(target.health < 1000.0 and sword.sword_hit_targets.size() == 1, "arc hits once in aimed direction %d/%d" % [kind, direction_index])
			target.free()
			prepare(kind, aim)
			tick(int(round((float(sword.current_data().windup) + float(sword.current_data().active) * 0.5) * 100.0)))
			if OS.get_cmdline_user_args().has("--visual"):
				await capture("direction_%d_%d" % [kind, direction_index])
		# Seven key poses expose anticipation, blade orbit and actual recovery.
		for key in range(7):
			prepare(kind, Vector2.RIGHT)
			var data: Dictionary = sword.current_data()
			var time: float = [float(data.windup) * 0.45, float(data.windup), float(data.windup) + float(data.active) * 0.25, float(data.windup) + float(data.active) * 0.5, float(data.windup) + float(data.active) * 0.9, float(data.windup) + float(data.active) + float(data.recovery) * 0.25, float(data.windup) + float(data.active) + float(data.recovery) * 0.85][key]
			tick(maxi(1, int(round(time * 100.0))))
			if OS.get_cmdline_user_args().has("--visual"):
				await capture("sequence_%d_%d" % [kind, key])
	# Charge pose and all controls at the smaller supported viewport.
	for size in [Vector2i(960, 540), Vector2i(1280, 720)]:
		root.size = size
		reset()
		sword.press_primary()
		tick(82)
		await capture("trial_charge_%d" % size.x)
		var bounds := Rect2(Vector2.ZERO, game.hud.root.size).grow(1.0)
		for button in game.hud.root.find_children("*", "Button", true, false):
			if button.is_visible_in_tree():
				check(bounds.encloses(button.get_global_rect()), "trial button fits %s at %d" % [button.text, size.x])
	reset()
	await process_frame
	click_control("慢动作 ×0.45")
	await process_frame
	check(Engine.time_scale == 0.45 and sword.attack_count == 0 and not sword.gesture_held, "slow-motion GUI changes speed without sword input")
	click_control("正常速度")
	check(Engine.time_scale == 1.0, "normal-speed GUI restores speed")
	click_control("四怪实战 →")
	await process_frame
	await process_frame
	game = current_scene
	check(game.scene_file_path == "res://scenes/sword_motion_combat.tscn" and game.remaining == 4 and get_nodes_in_group("enemies").size() == 4 and Engine.time_scale == 1.0 and game.player.weapon.has_method("motion_pose"), "trial switches to four-enemy motion combat at normal speed")
	click_control("← 动作样板")
	await process_frame
	await process_frame
	game = current_scene
	check(game.scene_file_path == "res://scenes/sword_motion_trial.tscn" and get_nodes_in_group("enemies").is_empty(), "combat returns to empty motion trial")
	Engine.time_scale = 0.45
	game.queue_free()
	await process_frame
	check(Engine.time_scale == 1.0, "leaving trial restores normal simulation speed")
	print("SWORD MOTION: %d checks, %d failures; pose/controlled collision tests, not human feel" % [checks, failures])
	quit(1 if failures else 0)

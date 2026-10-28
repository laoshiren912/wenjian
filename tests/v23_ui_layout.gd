extends "res://tests/v21_animation.gd"

# Real scene/container layout. Fixtures remove enemies; they do not certify play balance.
const V23_OUTPUT := "res://artifacts/v23_layout_final_2026-10-28/"
var render: bool = false
var captures: int = 0
var sample_size: Vector2i

func fresh_ui() -> void:
	game.restart_run()
	await frames(5)
	game = current_scene
	game.spawn_timer = 9999
	clear_targets()

func inspect_layout(stage: String) -> void:
	await frames(5)
	var outside: Array[String] = []
	var clipped: Array[String] = []
	var bounds: Rect2 = game.hud.root.get_global_rect().grow(1)
	var controls: Array[Node] = game.hud.root.find_children("*", "Control", true, false)
	controls.append_array(game.hud.level_ui.find_children("*", "Control", true, false))
	for item in controls:
		var control := item as Control
		if not control.is_visible_in_tree():
			continue
		if not bounds.encloses(control.get_global_rect()):
			outside.append(str(control.get_path()) + " " + str(control.get_global_rect()))
		if control is Label or control is Button:
			if control.size.x + 1 < control.get_minimum_size().x or control.size.y + 1 < control.get_minimum_size().y:
				clipped.append(control.text)
	check(outside.is_empty(), "%s %s all visible controls within canvas: %s" % [sample_size, stage, outside])
	check(clipped.is_empty(), "%s %s labels/buttons fit their measured text: %s" % [sample_size, stage, clipped])
	if render:
		await RenderingServer.frame_post_draw
		var screenshot: Image = root.get_texture().get_image()
		check(screenshot.get_size() == sample_size, "Native screenshot uses requested physical window pixels " + str(sample_size))
		check(screenshot.save_png(V23_OUTPUT + "%dx%d_%s.png" % [sample_size.x, sample_size.y, stage]) == OK, "Saved native UI " + stage)
		captures += 1

func press(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await frames(3)

func _run() -> void:
	render = OS.get_cmdline_user_args().has("--render")
	if render:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(V23_OUTPUT))
	root.title = "V2.3 UI Layout Checks"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frames(4)
	for requested in [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(1024, 768), Vector2i(1920, 1080)]:
		sample_size = requested
		root.size = sample_size
		await frames(5)
		print("V23 SIZE: requested=%s actual=%s canvas=%s driver=%s" % [sample_size, root.size, game.hud.root.size, DisplayServer.get_name()])
		check(root.size == sample_size, "Actual window size matches requested " + str(sample_size))
		await fresh_ui()
		await inspect_layout("start")
		game.start_run()
		game.hud.notice.text = ""
		await inspect_layout("combat")
		var hud = game.hud
		var size: Vector2 = hud.root.size
		var center_battle := Rect2(size * Vector2(0.25, 0.25), size * 0.5)
		var clear_center: bool = true
		for panel in hud.combat_panels:
			clear_center = clear_center and not panel.get_global_rect().intersects(center_battle)
		check(clear_center and hud.combat_panels[0].size.y < 120 and hud.combat_panels[1].size.y < 120, "Compact top HUD and bottom equipment keep the central battle area clear")
		check(hud.xp_bar.get_global_rect().position.y > size.y * 0.8 and hud.xp_text.get_global_rect().position.y > size.y * 0.8, "Level and experience are at the bottom")
		check(hud.weapon_slots.size() == 3 and hud.combat_panels[2].get_global_rect().get_center().x == size.x * 0.5, "Three weapon slots remain centered at the bottom")
		var transparent: bool = hud.weapon_text.mouse_filter == Control.MOUSE_FILTER_IGNORE and hud.xp_bar.mouse_filter == Control.MOUSE_FILTER_IGNORE
		for slot in hud.weapon_slots:
			transparent = transparent and slot.mouse_filter == Control.MOUSE_FILTER_IGNORE and slot.find_children("*", "Button", true, false).is_empty()
		check(transparent, "Weapon display and bars neither consume input nor introduce clickable weapon switching")
		for index in range(3):
			await press(KEY_1 + index)
			var correct: bool = game.player.weapon.selected == index and hud.weapon_text.text == "%d  %s" % [index + 1, SurvivorWeapon.DATA[index].name]
			for other in range(3):
				var style := hud.weapon_slots[other].get_theme_stylebox("panel") as StyleBoxFlat
				correct = correct and style.border_width_left == (2 if other == index else 1)
			check(correct, "Keyboard weapon %d updates exactly one slot highlight and actual weapon" % (index + 1))
		# Feedback at the bottom must move above the relocated HUD instead of underneath it.
		var point := Vector2(size.x * 0.5, size.y - 2)
		var world_point: Vector2 = game.feedback.to_global(game.feedback.get_global_transform_with_canvas().affine_inverse() * point)
		game.feedback.show_damage(world_point, 21, false)
		await frames(2)
		var popup: Dictionary = game.feedback.popups[-1]
		var text_rect: Rect2 = popup.label.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, popup.label.size)
		check(not text_rect.intersects(hud.combat_panels[2].get_global_rect()) and bounds_safe(size).encloses(text_rect), "Bottom-edge damage avoids equipment and remains inside the viewport")
		await frames(60)
		game.show_stats()
		await inspect_layout("stats")
		game.resume_run()
		game.toggle_pause()
		await inspect_layout("pause")
		game.resume_run()
		game.player.gain_experience(game.player.next_level_xp)
		await inspect_layout("upgrade")
		var level_ui = hud.level_ui
		check(level_ui.choice_layout.vertical == (sample_size.x < 1100), "Upgrade orientation follows actual available window width, including canvas scaling")
		var separate: bool = true
		for index in range(3):
			for other in range(index + 1, 3):
				separate = separate and not level_ui.choices[index].get_global_rect().intersects(level_ui.choices[other].get_global_rect())
		check(separate and get_root().gui_get_focus_owner() == level_ui.choices[0], "Upgrade options do not overlap and the first option receives keyboard focus")
		root.size = Vector2i(1280, 720) if sample_size.x < 1100 else Vector2i(960, 540)
		await frames(5)
		check(level_ui.choice_layout.vertical == (root.size.x < 1100) and paused and game.pending_levels == 1 and root.gui_get_focus_owner() == level_ui.choices[0], "Resizing an open upgrade reflows cards without losing focus or choosing an upgrade")
		root.size = sample_size
		await frames(5)
		var damage: float = game.player.damage_multiplier
		await press(KEY_1)
		check(not paused and is_equal_approx(game.player.damage_multiplier, damage + 0.2) and game.player.weapon.selected == 2, "Numeric upgrade applies once without changing the selected weapon")
		game.player.gain_experience(game.player.next_level_xp)
		await frames(3)
		var attack_speed: float = game.player.attack_speed_multiplier
		level_ui.choices[1].pressed.emit()
		level_ui.choices[1].pressed.emit()
		await frames(3)
		check(not paused and is_equal_approx(game.player.attack_speed_multiplier, attack_speed + 0.15), "A stale second activation of a chosen card cannot apply twice")
		game.player.take_damage(10000, Vector2.ZERO)
		await inspect_layout("death")
		await fresh_ui()
		game.start_run()
		game.elapsed = SurvivorGame.RUN_DURATION
		game._end_run(true)
		await inspect_layout("success")
	print("V23 UI RESULT: %d checks, %d failures, %d native captures" % [checks, failures, captures])
	paused = false
	quit(0 if failures == 0 else 1)

func bounds_safe(size: Vector2) -> Rect2:
	return Rect2(Vector2(7.5, 7.5), size - Vector2(15, 15))

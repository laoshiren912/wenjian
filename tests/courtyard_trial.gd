extends SceneTree

var game
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS: " if ok else "FAIL: ") + label)

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
	await process_frame

func aim_at(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = root.get_canvas_transform() * point
	root.push_input(event, true)

func mouse(button: int, pressed: bool, point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = root.get_canvas_transform() * point
	root.push_input(event, true)

func capture(label: String) -> void:
	await frames(2)
	if OS.get_cmdline_user_args().has("--visual"):
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/courtyard_2026-11-03/" + label + ".png")
	# Window pixels can differ from the logical canvas under canvas_items stretch.
	var bounds := Rect2(Vector2.ZERO, game.get_viewport_rect().size).grow(1.0)
	for button in game.find_children("*", "Button", true, false):
		if button.is_visible_in_tree():
			check(bounds.encloses(button.get_global_rect()), label + " button fits: " + button.text)

func run() -> void:
	game = load("res://scenes/courtyard_trial.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frames(3)
	check(ResourceLoader.exists("res://scenes/courtyard_trial.tscn"), "approved art courtyard sample remains available")
	check(game.world.backdrop.texture.get_size().x > 1000, "approved painting imported as game asset")
	check(get_nodes_in_group("enemies").is_empty() and game.player.combo_enabled, "visual trial reuses existing hero without spawning enemies")
	check(game.world.lanterns.size() == 2 and game.world.walkable.size() == 8, "two depth props and painted floor boundary")
	var foreground_count := 0
	for node in game.world.get_children():
		if node is Polygon2D:
			foreground_count += 1
			check(node.polygon.size() >= 7 and node.uv.size() == node.polygon.size(), "foreground terrace has textured polygon")
	check(foreground_count == 2, "foreground art separated from backdrop")
	for actions in [["move_up"], ["move_down"], ["move_left"], ["move_right"], ["move_up", "move_left"], ["move_up", "move_right"], ["move_down", "move_left"], ["move_down", "move_right"]]:
		game.reset_position()
		await frames(2)
		var origin: Vector2 = game.player.position
		for action in actions:
			Input.action_press(action)
		await frames(180)
		for action in actions:
			Input.action_release(action)
		await frames(2)
		check(game.player.position.distance_to(origin) > 30.0, "movement works: " + str(actions))
		check(Geometry2D.is_point_in_polygon(game.player.position, game.world.walkable), "boundary blocks escape: " + str(actions))
	game.reset_position()
	var lantern = game.world.lanterns[0]
	game.player.position = lantern.position + Vector2(0, 50)
	Input.action_press("move_up")
	await frames(25)
	Input.action_release("move_up")
	check(game.player.position.distance_to(lantern.position) >= 30.5, "stone lantern foot collision blocks walking through")
	game.player.position = lantern.position + Vector2(0, -40)
	await frames(2)
	check(lantern.z_index == 5 and lantern.in_front, "lantern occludes hero standing behind")
	await capture("behind_lantern")
	game.player.position = lantern.position + Vector2(0, 45)
	await frames(2)
	check(lantern.z_index == -1 and not lantern.in_front, "hero draws in front when passing lantern")
	await capture("front_lantern")
	game.reset_position()
	# Real engine input dispatch still drives the existing weapons.
	aim_at(game.player.position + Vector2(200, 0))
	mouse(MOUSE_BUTTON_LEFT, true, game.player.position + Vector2(200, 0))
	mouse(MOUSE_BUTTON_LEFT, false, game.player.position + Vector2(200, 0))
	await frames(1)
	check(game.player.weapon.attack_count == 1, "short-release sword works in courtyard")
	await frames(30)
	mouse(MOUSE_BUTTON_RIGHT, true, game.player.position + Vector2(200, 0))
	mouse(MOUSE_BUTTON_RIGHT, false, game.player.position + Vector2(200, 0))
	await frames(1)
	check(game.player.ranged_weapon.attack_count == 1, "bow works in courtyard")
	game.reset_position()
	await frames(2)
	var before: Vector2 = game.player.position
	check(game.player.try_roll(), "existing roll can start")
	await frames(25)
	check(game.player.position.distance_to(before) > 100.0 and game.player.invulnerability == 0.0, "roll moves on floor without adding invulnerability")
	game.reset_position()
	game.player.combo.press_primary()
	await frames(20)
	check(game.player.combo.charging, "charge works in courtyard")
	game.toggle_pause()
	check(paused and not game.player.combo.charging, "pause cancels held charge")
	var still: Vector2 = game.player.position
	Input.action_press("move_left")
	await frames(5)
	Input.action_release("move_left")
	check(game.player.position == still, "pause freezes movement")
	game.toggle_pause()
	for dimensions in [Vector2i(1280, 720), Vector2i(960, 540)]:
		root.size = dimensions
		game.close_view = false
		game.reset_position()
		await capture("courtyard_%d" % dimensions.x)
		game.close_view = true
		game._update_camera()
		await capture("close_%d" % dimensions.x)
		var half: Vector2 = game.get_viewport_rect().size / game.camera.zoom * 0.5
		check(game.camera.position.x - half.x >= -0.1 and game.camera.position.y - half.y >= -0.1 and game.camera.position.x + half.x <= 1280.1 and game.camera.position.y + half.y <= 720.1, "close camera stays within painting")
		game.toggle_pause()
		await capture("pause_%d" % dimensions.x)
		game.toggle_pause()
	# A real GUI click on reset must not become a sword press.
	game.reset_position()
	var count: int = game.player.weapon.attack_count
	for button in game.find_children("*", "Button", true, false):
		if button.text == "重置位置":
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.position = button.get_global_rect().get_center()
			click.pressed = true
			root.push_input(click, true)
			click = click.duplicate()
			click.pressed = false
			root.push_input(click, true)
	await frames(2)
	check(game.player.weapon.attack_count == count and not game.player.combo.gesture_held, "GUI reset never triggers sword")
	game.queue_free()
	await process_frame
	print("COURTYARD: %d checks, %d failures; controlled input/collision/rendering, not human playtest" % [checks, failures])
	quit(1 if failures else 0)

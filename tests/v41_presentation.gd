extends SceneTree

const OUT := "res://artifacts/runtime/v41-presentation/"
var game
var failures := 0
var checks := 0
var capture := false

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print("PASS: " if condition else "FAIL: ", message)

func frames(count := 3) -> void:
	for i in range(count):
		await physics_frame
	await process_frame

func screenshot(name: String, subject: Node2D = null) -> void:
	if not capture:
		return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image.save_png(OUT + name + ".png") == OK, name + " screenshot")
	if subject != null:
		var point := Vector2i(subject.get_global_transform_with_canvas().origin.round())
		var detail := image.get_region(Rect2i(point - Vector2i(68, 75), Vector2i(136, 112)))
		var skin_pixels := 0
		for y in range(detail.get_height()):
			for x in range(detail.get_width()):
				if detail.get_pixel(x, y).to_rgba32() == Color("fcd491").to_rgba32():
					skin_pixels += 1
		check(skin_pixels >= 12, "rendered idle skin swatch " + name)
		detail.resize(544, 448, Image.INTERPOLATE_NEAREST)
		check(detail.save_png(OUT + name + "-detail.png") == OK, name + " detail")

func check_text_bounds(node: Node, bounds: Rect2) -> void:
	if node is Label or node is RichTextLabel:
		var rect: Rect2 = node.get_global_rect()
		var label: String = node.get_parsed_text() if node is RichTextLabel else node.text
		check(bounds.encloses(rect), "text inside safe area %s %s" % [label, rect])
		check(rect.position.is_equal_approx(rect.position.round()), "integer text origin " + label)
		check(node.get_theme_color("font_shadow_color").a == 0.0, "no offset text shadow " + label)
		if node is RichTextLabel:
			check(node.get_content_height() <= rect.size.y, "description fits " + label)
	for child in node.get_children():
		check_text_bounds(child, bounds)

func run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	if capture:
		DirAccess.make_dir_recursive_absolute(OUT)
	game = load("res://scenes/main_v41.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	if game.phase == "title":
		game.start_run_from_title()
	await frames()
	game.phase = "exit_ready"
	game._trigger_portal_reward()
	game.reward_options.assign([0, 1, 2])
	game.hud.show_rewards()
	for resolution in [Vector2i(1280, 720), Vector2i(960, 540)]:
		root.size = resolution
		await frames(8)
		if capture:
			check(root.size == resolution, "native window " + str(resolution))
		check_text_bounds(game.hud.modal_panel, Rect2(Vector2.ZERO, game.hud.root.size).grow(-12.0))
		await screenshot("reward-%dx%d" % [resolution.x, resolution.y])
	root.size = Vector2i(1280, 720)
	game.select_reward(0)
	await frames(12)
	game.cultivation_override = 2
	var player = game.player
	player.gm_invulnerable = true
	for enemy in get_nodes_in_group("enemies"):
		enemy.free()
	player.position = Vector2(410, 460)
	var aim := Vector2(680, 700)
	var motion := InputEventMouseMotion.new()
	motion.position = aim
	root.push_input(motion, true)
	await frames(5)
	await screenshot("player-stance", player)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = aim
	click.pressed = true
	root.push_input(click, true)
	await frames()
	click = click.duplicate()
	click.pressed = false
	root.push_input(click, true)
	await frames(5)
	check(player.combo.phase() == "active", "captured a live combo strike")
	check_neutral(player, "combo strike")
	await screenshot("player-strike", player)
	player.visual.play_hurt()
	check(player.visual.player_hit_flash_mat.get_shader_parameter("hurt_flash") == 1.0, "hit flash starts during combo")
	await frames(8)
	check(player.visual.hurt_time == 0.0, "hit flash timer finishes")
	check_neutral(player, "after hit flash")
	await frames(22)
	player.request_dash(Vector2(1, 1).normalized())
	for i in range(16):
		if player.dash_state == player.Dash.TRAVEL:
			break
		await frames(1)
	check(player.dash_state == player.Dash.TRAVEL, "captured live dash travel")
	check_neutral(player, "dash travel")
	await screenshot("player-dash", player)
	game.free()
	await frames()
	print("PRESENTATION_RESULT checks=", checks, " failures=", failures)
	quit(1 if failures > 0 else 0)

func check_neutral(player, phase: String) -> void:
	check(player.visual.modulate == Color.WHITE and player.visual.self_modulate == Color.WHITE
		and is_zero_approx(float(player.visual.player_hit_flash_mat.get_shader_parameter("hurt_flash"))),
		"neutral player color " + phase)

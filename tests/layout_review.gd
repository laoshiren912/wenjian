extends SceneTree

# Render the actual UI for review. These are controlled layout fixtures, not playthroughs.
const OUTPUT: String = "res://artifacts/stamina_layout_2026-10-28/"
var game: SurvivorGame
var failures: int = 0
var captures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func frames(count: int = 4) -> void:
	for frame in range(count):
		await physics_frame
	await process_frame

func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var bounds := Rect2(Vector2.ZERO, game.hud.root.size)
	var controls: Array[Node] = game.hud.root.find_children("*", "Control", true, false)
	controls.append_array(game.hud.level_ui.find_children("*", "Control", true, false))
	var outside: int = 0
	for item in controls:
		var control := item as Control
		if control.is_visible_in_tree() and not bounds.grow(1.0).encloses(control.get_global_rect()):
			outside += 1
			print("OUTSIDE: %s %s" % [control.name, control.get_global_rect()])
	failures += outside
	var frame: Image = root.get_texture().get_image()
	var result: Error = frame.save_png(OUTPUT + name + ".png")
	if result != OK:
		failures += 1
	captures += 1
	print("LAYOUT: %s, pixels=%s, out_of_bounds=%d, save=%s" % [name, frame.get_size(), outside, result])

func clear_enemies() -> void:
	for enemy in get_nodes_in_group("enemies"):
		enemy.free()
	game.spawn_timer = 9999.0

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	root.size = Vector2i(1280, 720)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frames()
	clear_enemies()
	await capture("01_start_1280")
	game.start_run()
	var left := game._spawn_enemy(SurvivorEnemy.Kind.HOSTILE, game.player.position + Vector2(-135, -40))
	var right := game._spawn_enemy(SurvivorEnemy.Kind.HOSTILE, game.player.position + Vector2(140, -40))
	left.set_physics_process(false)
	right.set_physics_process(false)
	await frames(8)
	left.take_damage(52.0, Vector2.ZERO)
	right.take_damage(32.0, Vector2.ZERO)
	game.player.take_damage(12.0, Vector2.ZERO)
	game.player.gain_experience(4)
	await frames(3)
	# Check the visible floating labels against each other in viewport coordinates.
	var rectangles: Array[Rect2] = []
	for popup in game.feedback.popups:
		var label: Label = popup.label
		var rectangle: Rect2 = label.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, label.size)
		rectangles.append(rectangle)
		if popup.kind == "enemy_damage":
			for enemy in get_nodes_in_group("enemies"):
				var health_bar: Rect2 = enemy.get_global_transform_with_canvas() * Rect2(-19, -38, 38, 4)
				if rectangle.grow(4.0).intersects(health_bar):
					failures += 1
					print("OVERLAP: damage number / enemy HP bar")
	for index in range(rectangles.size()):
		for other in range(index + 1, rectangles.size()):
			if rectangles[index].intersects(rectangles[other]):
				failures += 1
				print("OVERLAP: floating labels %d / %d" % [index, other])
	await capture("02_feedback_1280")
	clear_enemies()
	game.player.weapon.select_weapon(2)
	game.player.weapon.cooldown = 0.0
	game.player.stamina = 100.0
	game.player.weapon.attack(Vector2.RIGHT)
	await frames(3)
	await capture("02b_bow_arrow_1280")
	game.toggle_pause()
	await capture("03_pause_1280")
	game.resume_run()
	await frames(65)
	game.show_stats()
	await capture("04_stats_1280")
	game.resume_run()
	game.player.gain_experience(game.player.next_level_xp)
	await frames()
	await capture("05_upgrade_1280")
	game.hud.level_ui.choices[2].pressed.emit()
	await frames(65)
	game.player.take_damage(10000.0, Vector2.ZERO)
	await frames()
	await capture("06_death_1280")
	game.restart_run()
	await frames()
	while not is_instance_valid(current_scene) or not current_scene.is_node_ready():
		await process_frame
	game = current_scene
	clear_enemies()
	game.start_run()
	game.elapsed = SurvivorGame.RUN_DURATION
	game._end_run(true)
	await capture("07_success_1280")
	root.size = Vector2i(960, 540)
	await frames()
	await capture("08_result_960")
	# Review a fresh upgrade modal at a smaller window with the same canvas aspect.
	game.restart_run()
	await frames()
	while not is_instance_valid(current_scene) or not current_scene.is_node_ready():
		await process_frame
	game = current_scene
	clear_enemies()
	game.start_run()
	game.player.gain_experience(game.player.next_level_xp)
	await frames()
	await capture("09_upgrade_960")
	root.size = Vector2i(1024, 768)
	await frames()
	await capture("10_upgrade_4_3")
	print("LAYOUT RESULT: %d captures, %d failures" % [captures, failures])
	paused = false
	quit(0 if failures == 0 else 1)

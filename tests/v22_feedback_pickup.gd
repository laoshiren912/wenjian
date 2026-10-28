extends "res://tests/v21_animation.gd"

const V22_OUTPUT := "res://artifacts/v22_visual_final_2026-10-28/"

func fresh() -> void:
	game.restart_run()
	await frames(4)
	game = current_scene
	game.start_run()
	game.spawn_timer = 9999.0
	clear_targets()

func pickup(offset: Vector2, value: int = 1) -> Node2D:
	var node = SurvivorGame.PICKUP_SCENE.instantiate()
	node.position = game.player.position + offset
	node.value = value
	game.world.actors.add_child(node)
	node.set_physics_process(false)
	return node

func xp_popups() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for popup in game.feedback.popups:
		if popup.kind == "experience":
			result.append(popup)
	return result

func screen_point(point: Vector2) -> Vector2:
	return game.feedback.to_global(game.feedback.get_global_transform_with_canvas().affine_inverse() * point)

func popup_rect(popup: Dictionary) -> Rect2:
	return popup.label.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, popup.label.size)

func image_capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(V22_OUTPUT + name + ".png") == OK, "Native screenshot " + name)

func render_feedback() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(V22_OUTPUT))
	await fresh()
	for offset in [Vector2(-170, -60), Vector2(-65, -100), Vector2(65, -90), Vector2(170, -50)]:
		var enemy := game._spawn_enemy(SurvivorEnemy.Kind.HOSTILE, game.player.position + offset)
		enemy.set_physics_process(false)
		enemy.take_damage(11, Vector2.ZERO)
		enemy.take_damage(14, Vector2.ZERO)
	game.player.take_damage(12, Vector2.ZERO)
	for value in [3, 4, 5]:
		game.player.gain_experience(value)
	await frames(2)
	await image_capture("01_dense_damage_and_xp")
	game.toggle_pause()
	await image_capture("02_pause_freezes_feedback")
	game.resume_run()
	await frames(65)
	await image_capture("03_feedback_cleaned")
	await fresh()
	for point in [Vector2(2, 2), Vector2(1278, 2), Vector2(2, 718), Vector2(1278, 718)]:
		game.feedback.show_damage(screen_point(point), 52, false)
	await frames(2)
	await image_capture("04_edge_constraints")
	await fresh()
	game.player.gain_experience(84)
	await frames(2)
	await image_capture("05_queued_upgrades")
	for index in range(3):
		game.hud.level_ui.choices[index].pressed.emit()
	await frames(2)
	await image_capture("06_upgrades_applied")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.title = "V2.2 Feedback and Pickup Checks"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frames()
	game.start_run()
	game.spawn_timer = 9999.0
	clear_targets()
	for distance in [28.0, 29.0, 56.0, 160.0]:
		var orb := pickup(Vector2(distance, 0))
		var before: Vector2 = orb.position
		orb._physics_process(1.0 / 60.0)
		check(orb.position == before and not orb.collected, "XP at %.0f does not attract outside the strict one-body 28 radius" % distance)
		orb.free()
	var orb := pickup(Vector2(27, 0))
	orb._physics_process(1.0 / 420.0)
	check(is_equal_approx(orb.position.distance_to(game.player.position), 26.0), "XP just inside one body advances 1 unit in 1/420 second at the unchanged 420 speed")
	orb.free()
	orb = pickup(Vector2(23, 0))
	orb._physics_process(0.0)
	check(not orb.collected and game.player.total_experience == 0, "Collection distance stays strictly below 23")
	orb.position = game.player.position + Vector2(22.9, 0)
	orb._physics_process(0.0)
	check(orb.collected and game.player.total_experience == 1, "XP is credited immediately at collection")
	orb._physics_process(0.0)
	check(game.player.total_experience == 1, "The collected marker rejects a second collection before deletion")
	await frames(2)
	check(not is_instance_valid(orb), "Collected orb is removed")
	orb = pickup(Vector2(10, 0), 2)
	game.player.dead = true
	orb._physics_process(1.0 / 60.0)
	check(not orb.collected and game.player.total_experience == 1, "A dead player cannot collect nearby XP")
	game.player.dead = false
	orb.free()
	orb = pickup(Vector2(27, 0), 2)
	orb.set_physics_process(true)
	var start: Vector2 = orb.position
	game.toggle_pause()
	await frames(15)
	check(orb.position == start and game.player.total_experience == 1, "Real pause freezes attraction and accounting")
	game.resume_run()
	await frames(22)
	check(not is_instance_valid(orb) and game.player.total_experience == 3, "Actual physics resumes attraction and collects the exact value")
	var wall := StaticBody2D.new()
	wall.position = game.player.position + Vector2(24, 0)
	wall.collision_layer = 1
	wall.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(2, 10)
	shape.shape = rectangle
	wall.add_child(shape)
	game.world.add_child(wall)
	await frames(2)
	orb = pickup(Vector2(27, 0), 4)
	start = orb.position
	orb._physics_process(1.0 / 60.0)
	check(orb.position == start and not orb.collected, "An actual physics wall blocks attraction within one body")
	game.player.position = orb.position + Vector2(0, 27)
	var distance: float = orb.position.distance_to(game.player.position)
	orb._physics_process(1.0 / 60.0)
	check(is_equal_approx(orb.position.distance_to(game.player.position), distance - 7), "XP can attract after the player moves around the wall")
	orb.free()
	wall.free()
	await fresh()
	for value in [2, 3, 4]:
		orb = pickup(Vector2(10, 0), value)
		orb._physics_process(0.0)
	check(game.player.total_experience == 9 and game.player.experience == 9, "Batch collection immediately credits each orb's exact value")
	check(xp_popups().size() == 1 and int(xp_popups()[0].amount) == 9 and game.hud.notice.text == "+9 经验", "Batch XP shares one matching world and HUD total")
	await fresh()
	game.player.gain_experience(1)
	var first: Dictionary = xp_popups()[0]
	check(first.label.text == "+1 经验" and game.hud.notice.text == "+1 经验", "The first pickup is displayed immediately")
	await frames(4)
	var age: float = first.age
	game.player.gain_experience(2)
	check(xp_popups().size() == 1 and first.label.text == "+3 经验" and game.hud.notice.text == "+3 经验", "Pickups inside 0.12 seconds update the same popup")
	check(first.age == age, "Adding XP never restarts the first pickup's window or visual lifetime")
	await frames(4)
	game.player.gain_experience(4)
	check(xp_popups().size() == 2 and int(first.amount) == 3 and int(xp_popups()[1].amount) == 4 and game.hud.notice.text == "+4 经验", "A pickup beyond the first 0.12 seconds starts a fresh group")
	check(game.player.total_experience == 7, "Presentation grouping does not delay or alter actual XP")
	for modal in ["pause", "stats"]:
		await fresh()
		game.player.gain_experience(1)
		first = xp_popups()[0]
		if modal == "pause":
			game.toggle_pause()
		else:
			game.show_stats()
		age = first.age
		await frames(20)
		check(first.age == age and paused, modal + " freezes the current floating label")
		game.resume_run()
		game.player.gain_experience(1)
		check(xp_popups().size() == 2 and int(first.amount) == 1 and game.hud.notice.text == "+1 经验", modal + " closes the grouping window before combat resumes")
	await fresh()
	game.player.gain_experience(84)
	check(game.player.total_experience == 84 and game.player.level == 4, "Large XP immediately grants all three levels without waiting for display")
	await frames(2)
	check(paused and game.state == SurvivorGame.State.LEVEL_UP and game.pending_levels == 3, "Three earned levels open the existing paused choice queue")
	var elapsed: float = game.elapsed
	await frames(20)
	check(game.elapsed == elapsed, "Survival time is frozen for queued choices")
	game.hud.level_ui.choices[0].pressed.emit()
	check(game.pending_levels == 2 and paused and is_equal_approx(game.player.damage_multiplier, 1.2), "First choice applies damage exactly once and keeps the queue paused")
	game.hud.level_ui.choices[1].pressed.emit()
	check(game.pending_levels == 1 and paused and is_equal_approx(game.player.attack_speed_multiplier, 1.15), "Second choice applies speed exactly once")
	game.hud.level_ui.choices[2].pressed.emit()
	check(game.pending_levels == 0 and not paused and game.player.max_health == 125 and game.hud.notice.text == "强化已生效", "Final choice applies health once and restores combat with confirmation")
	game.choose_upgrade(2)
	check(game.player.max_health == 125, "A stale choice after the queue finishes cannot apply twice")
	game.player.gain_experience(1)
	check(xp_popups().size() == 2 and game.hud.notice.text == "+1 经验", "Upgrade pause closes the old XP group before new collection")
	for won in [false, true]:
		await fresh()
		game.player.gain_experience(1)
		first = xp_popups()[0]
		game._end_run(won)
		check(paused and game.feedback._experience_popup.is_empty() and int(first.amount) == 1, "Result closes XP batch, won=%s" % won)
		await fresh()
		check(game.feedback.popups.is_empty() and game.feedback.bursts.is_empty() and game.player.camera.offset.is_zero_approx(), "Restart clears all presentation state, won=%s" % won)
	var enemy := target_at(100)
	enemy.take_damage(10, Vector2.ZERO)
	enemy.take_damage(11, Vector2.ZERO)
	game.player.take_damage(12, Vector2.ZERO)
	game.player.gain_experience(3)
	check(enemy.health == enemy.max_health - 21 and game.player.health == 88, "Damage feedback remains tied to actual enemy and player health")
	var popups: Array = game.feedback.popups
	var no_overlap: bool = true
	var hp_bar: Rect2 = enemy.get_global_transform_with_canvas() * Rect2(-19, -38, 38, 4)
	for index in range(popups.size()):
		if popups[index].kind == "enemy_damage":
			check(not popup_rect(popups[index]).intersects(hp_bar), "Enemy damage stays above its health bar")
		for other in range(index + 1, popups.size()):
			no_overlap = no_overlap and not popup_rect(popups[index]).intersects(popup_rect(popups[other]))
	check(no_overlap, "Repeated hits, player damage, and XP occupy distinct text rectangles")
	check(popups[2].label.z_index > popups[1].label.z_index and popups[1].label.z_index > popups[3].label.z_index, "Player damage has priority above enemy damage and XP")
	check(popup_rect(popups[3]).position.y > (game.player.get_global_transform_with_canvas().origin.y), "Experience stays below the player")
	var count: int = popups.size()
	game.player.take_damage(12, Vector2.ZERO)
	check(popups.size() == count, "Invulnerable damage does not create a false number")
	await frames(65)
	check(game.feedback.popups.is_empty() and game.feedback.bursts.is_empty() and game.player.camera.offset.is_zero_approx(), "All numbers and bursts expire and shake returns to zero")
	await fresh()
	for point in [Vector2(2, 2), Vector2(1278, 2), Vector2(2, 718), Vector2(1278, 718)]:
		game.feedback.show_damage(screen_point(point), 52, false)
	await frames(2)
	var safe := Rect2(Vector2(8, 8), root.get_visible_rect().size - Vector2(16, 16)).grow(0.5)
	for popup in game.feedback.popups:
		check(safe.encloses(popup_rect(popup)), "Onscreen edge number keeps an 8 pixel margin during shake: %s" % popup_rect(popup))
		for panel in game.feedback.hud_obstacles:
			var panel_rect: Rect2 = panel.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, panel.size)
			check(not popup_rect(popup).intersects(panel_rect), "Edge number is not hidden behind an existing HUD panel")
	await fresh()
	game.feedback.show_damage(screen_point(Vector2(-250, 360)), 52, false)
	check(popup_rect(game.feedback.popups[0]).end.x < 0, "Offscreen enemy damage is not dragged into the viewport")
	await fresh()
	for index in range(24):
		game.feedback.show_damage(game.player.position, index + 1, false)
	check(game.feedback.popups.size() == 24, "Dense feedback preserves every damage event despite four placement attempts")
	var all_ignore: bool = true
	for popup in game.feedback.popups:
		all_ignore = all_ignore and popup.label.mouse_filter == Control.MOUSE_FILTER_IGNORE
	check(all_ignore, "Every floating label remains transparent to mouse input")
	await frames(65)
	check(game.feedback.popups.is_empty(), "Dense labels clean up without orphan controls")
	if OS.get_cmdline_user_args().has("--render"):
		await render_feedback()
	print("V22 RESULT: %d checks, %d failures" % [checks, failures])
	paused = false
	quit(0 if failures == 0 else 1)

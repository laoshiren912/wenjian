extends "res://tests/sword_combo.gd"

func start_charge(steps: int = 82) -> void:
	sword.press_primary()
	tick(steps)

func durable_target(offset: Vector2) -> SurvivorEnemy:
	var target := enemy_at(player.position + offset)
	target.health = 1000.0
	target.max_health = 1000.0
	return target

func run() -> void:
	game = load("res://scenes/sword_motion_combat.tscn" if OS.get_cmdline_user_args().has("--motion") else "res://scenes/sword_motion_combat.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	bind_player()
	# Use actual GUI-dispatched press/release for the click/hold boundary.
	mouse_press(true)
	tick(10)
	check(sword.attack_count == 0 and not sword.charging, "press and short hold do not attack")
	mouse_press(false)
	tick()
	check(sword.attack_count == 1 and sword.stage == 0 and not sword.charged_swing, "short release starts first ordinary stage")
	for next in [1, 2]:
		while sword.swing_time > 0.15:
			tick()
		mouse_press(true)
		tick(2)
		mouse_press(false)
		tick(20)
		check(sword.stage == next and sword.attack_count == next + 1, "release buffers ordinary stage %d" % next)
	reset()
	start_charge(21)
	check(not sword.charging and sword.attack_count == 0, "below hold threshold has no attack")
	tick()
	check(sword.charging and sword.next_stage == 0 and sword.click_time == 0.0, "threshold starts charge and clears combo")
	tick(30)
	check(absf(sword.charge_fraction() - 0.5) < 0.001, "half charge after threshold plus 0.30 seconds")
	tick(200)
	check(sword.charge_fraction() == 1.0 and sword.attack_count == 0, "full charge waits for release and clamps")
	var origin: Vector2 = player.position
	Input.action_press("move_right")
	tick(10)
	Input.action_release("move_right")
	check(absf(player.position.x - origin.x - player.speed * 0.1) < 0.02, "charge permits full-speed movement")
	player._aim_viewport_position = root.get_canvas_transform() * (player.position + Vector2(0, 400))
	tick()
	check(player.visual.charge_aim.is_equal_approx(Vector2.DOWN), "charge follows mouse aim and raises hands")
	player._ranged_held = true
	Input.action_press("ranged_attack")
	tick(5)
	check(player.ranged_weapon.attack_count == 0, "bow blocked during charge")
	Input.action_release("ranged_attack")
	player._ranged_held = false
	sword.release_primary()
	check(sword.charged_swing and sword.attack_count == 1 and sword.swing_direction == Vector2.DOWN, "release fires one directional charged attack")
	check(sword.released_power == 1.0 and is_equal_approx(sword.swing_duration, 0.68), "full power and independent timing")
	player._aim_viewport_position = root.get_canvas_transform() * (player.position + Vector2(400, 0))
	origin = player.position
	Input.action_press("move_right")
	tick(10)
	Input.action_release("move_right")
	check(sword.swing_direction == Vector2.DOWN, "charged direction remains locked after release")
	check(absf(player.position.x - origin.x - player.speed * 0.35 * 0.1) < 0.02, "release permits 35 percent movement without automatic lunge")
	check(not player.try_roll(), "charged windup cannot roll cancel")
	while sword.phase() != "active":
		tick()
	check(not player.try_roll(), "charged hit phase cannot roll cancel")
	while sword.phase() != "recovery":
		tick()
	check(player.try_roll() and sword.swing_time == 0.0 and not sword.gesture_held and player.invulnerability == 0.0, "charged recovery permits roll without extra invulnerability")
	# Multi-target blade sweep, including a target encountered later in the swing.
	reset()
	var low := durable_target(Vector2(80, -55))
	var high := durable_target(Vector2(80, 55))
	var outside := durable_target(Vector2(-80, 0))
	var too_far := durable_target(Vector2(180, 0))
	var side := durable_target(Vector2(30, 110))
	start_charge()
	sword.release_primary()
	tick(15)
	check(low.health == 1000.0 and high.health == 1000.0, "charge windup cannot damage")
	tick(55)
	check(low.health == 905.0 and high.health == 905.0, "sweep damages multiple enemies exactly once each")
	check(outside.health == 1000.0 and sword.sword_hit_targets.size() == 2, "directional sweep excludes rear targets")
	check(too_far.health == 1000.0 and side.health == 1000.0, "charged range and angle exclude distant and side targets")
	check(game.feedback.shake_strength >= 9.0 and game.feedback.shake_time > 0.0, "charged hit emits stronger active shake feedback")
	var still: Vector2 = player.position
	tick(20)
	check(player.position == still and sword.next_stage == 0, "charged attack has no drift and resets chain")
	sword.attack(Vector2.RIGHT)
	check(sword.stage == 0 and not sword.charged_swing, "ordinary combo restarts at stage one")
	reset()
	var partial := durable_target(Vector2(95, 0))
	start_charge(52)
	sword.release_primary()
	tick(70)
	check(absf(partial.health - 920.0) < 0.01, "half charge deals interpolated 80 damage")
	reset()
	var minimum := durable_target(Vector2(95, 0))
	start_charge(22)
	sword.release_primary()
	tick(70)
	check(absf(minimum.health - 935.0) < 0.01, "threshold release deals minimum 65 damage")
	reset()
	start_charge()
	sword.release_primary()
	player._ranged_held = true
	Input.action_press("ranged_attack")
	tick(50)
	check(sword.phase() == "recovery" and player.ranged_weapon.attack_count == 0, "bow cannot cancel charged recovery")
	tick(20)
	check(player.ranged_weapon.attack_count == 1, "bow can fire after complete charged recovery")
	Input.action_release("ranged_attack")
	# Holding during a previous action may not charge before it completes.
	reset()
	sword.attack(Vector2.RIGHT)
	sword.press_primary()
	while sword.swing_time > 0.0:
		tick()
	check(not sword.charging and sword.hold_time == 0.0, "ordinary action blocks long-hold timer")
	tick(21)
	check(not sword.charging, "hold threshold starts only after action ends")
	tick()
	check(sword.charging, "continued hold can charge after action")
	reset()
	player.ranged_weapon.attack(Vector2.RIGHT)
	sword.press_primary()
	tick(50)
	check(not sword.charging and sword.hold_time == 0.0, "active bow blocks charge timer")
	player.ranged_weapon.swing_time = 0.0
	tick(22)
	check(sword.charging, "charge starts after bow action ends")
	# Failed roll must not consume a charge or fire it later.
	for blocked in ["stamina", "cooldown"]:
		reset()
		start_charge()
		if blocked == "stamina":
			player.stamina = 0.0
		else:
			player._roll_cooldown = 2.0
		sword.queue_roll()
		tick()
		check(sword.charging and sword.gesture_held and not player.is_rolling(), blocked + " failure preserves charge")
		player.stamina = 100.0
		player._roll_cooldown = 0.0
		tick()
		check(not player.is_rolling(), blocked + " failed request does not roll later")
		sword.queue_roll()
		tick()
		check(player.is_rolling() and not sword.charging and not sword.gesture_held and sword.attack_count == 0, "successful roll cancels charge without attack")
		sword.release_primary()
		check(sword.click_time == 0.0, "release after charge cancel cannot queue ordinary sword")
	for notice in [Node.NOTIFICATION_PAUSED, Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		reset()
		start_charge()
		player.notification(notice)
		sword.release_primary()
		tick(50)
		check(not sword.charging and not sword.gesture_held and sword.attack_count == 0 and player.visual.charge_aim == Vector2.ZERO, "pause/focus clears charge and release cannot fire")
	reset()
	start_charge()
	player.take_damage(10000, Vector2.ZERO)
	check(not sword.charging and not sword.gesture_held and sword.swing_time == 0.0, "death clears charge")
	reset()
	start_charge()
	reset()
	check(not sword.charging and sword.attack_count == 0 and not sword.gesture_held, "restart clears charge")
	# Existing wall collider blocks charged damage.
	player.position = game.world.cell_center(Vector2i(13, 13))
	var wall_target := durable_target(Vector2(0, -64))
	await physics_frame
	player._aim_viewport_position = root.get_canvas_transform() * (player.position + Vector2(0, -400))
	start_charge()
	sword.release_primary()
	tick(70)
	check(wall_target.health == 1000.0, "wall blocks charged swept blade")
	for size in [Vector2i(960, 540), Vector2i(1280, 720)]:
		root.size = size
		reset()
		player.position = game.world.cell_center(Vector2i(19, 14))
		start_charge(52)
		await charge_snapshot("charge_half_%d" % size.x)
		tick(40)
		await charge_snapshot("charge_full_%d" % size.x)
		sword.release_primary()
		tick(23)
		await charge_snapshot("charge_swing_%d" % size.x)
		game.toggle_stats()
		await charge_snapshot("charge_stats_%d" % size.x)
		game.resume_room()
		game.toggle_pause()
		await charge_snapshot("charge_pause_%d" % size.x)
		game.resume_room()
	paused = false
	game.queue_free()
	await process_frame
	print("CHARGED SWORD: %d checks, %d failures; controlled fixtures, not human playtest" % [checks, failures])
	quit(1 if failures else 0)

func charge_snapshot(label: String) -> void:
	await process_frame
	await process_frame
	var bounds := Rect2(Vector2.ZERO, game.hud.root.size).grow(1.0)
	for panel in game.hud.combat_panels:
		check(bounds.encloses(panel.get_global_rect()), label + " HUD fits")
	if game.hud.overlay.visible:
		check(bounds.encloses(game.hud.modal_panel.get_global_rect()), label + " modal fits")
	if OS.get_cmdline_user_args().has("--visual"):
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/v34_review_2026-11-03/" + label + ".png")

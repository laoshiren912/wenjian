extends SceneTree

# Real F5 scene, spawned enemies and GUI events. Some fixtures stop AI or grant
# invulnerability to isolate rules; this is not a human difficulty acceptance.
const CONFIG = preload("res://scripts/v41_config.gd")
const OUT := "res://artifacts/v41_review_2026-11-05/"
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

func frames(count: int = 2) -> void:
	for i in range(count):
		await physics_frame
	await process_frame

func enemies() -> Array:
	return get_nodes_in_group("enemies").filter(func(e): return not e.dead and not e.is_queued_for_deletion())

func freeze() -> void:
	for enemy in enemies():
		enemy.set_physics_process(false)

func reset() -> void:
	Input.action_release("attack")
	Input.action_release("ranged_attack")
	game.start_room()
	game.player.gm_invulnerable = true
	freeze()

func click_mouse(down: bool, point := Vector2(670, 390), right := false) -> void:
	var action := "ranged_attack" if right else "attack"
	if down:
		Input.action_press(action)
	else:
		Input.action_release(action)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT if right else MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = point
	event.global_position = point
	root.push_input(event, true)

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)

func clear_wave() -> void:
	for enemy in enemies():
		enemy.take_damage(10000.0, Vector2.ZERO, true)
	await frames()
	freeze()

func clear_room() -> void:
	while game.phase == "combat":
		await clear_wave()

func reward(index: int) -> void:
	game.player.position = CONFIG.REWARD_POINT
	await frames()
	check(game.phase == "reward_select" and paused, "real reward point opens selection")
	# Seed-independent deterministic choice fixture after verifying actual draw.
	check(game.reward_options.size() == 3 and game.reward_options[0] != game.reward_options[1] and game.reward_options[1] != game.reward_options[2] and game.reward_options[0] != game.reward_options[2], "three random options are distinct")
	game.reward_options.assign([index, (index + 1) % 4, (index + 2) % 4])
	game.hud.show_rewards()
	game.select_reward(index)

func advance() -> void:
	game.player.position = CONFIG.EXIT_POINT
	await frames()
	freeze()

func target_at(point: Vector2) -> SurvivorEnemy:
	# Reposition a real room-spawned enemy, never substitute a mock enemy class.
	var enemy: SurvivorEnemy = enemies()[0]
	enemy.position = point
	enemy.health = 1000.0
	enemy.max_health = 1000.0
	enemy.guard_time = 0.0
	enemy.guard_cooldown = 10.0
	enemy.windup = 0.0
	enemy.lunge_time = 0.0
	enemy.knockback = Vector2.ZERO
	return enemy

func tick_sword(count: int) -> void:
	for i in range(count):
		game.player.weapon._physics_process(0.01)

func check_bow_cycle() -> void:
	reset()
	var player = game.player
	var bow = player.ranged_weapon
	var origin: Vector2 = player.position
	var target := Vector2(670, 390)
	click_mouse(true, target, true)
	await frames(12)
	check(bow.attack_count == 0 and player.bow_windup_remaining > 0.0 and is_equal_approx(player.movement_multiplier(), 0.45), "bow draws for a quarter second at reduced speed")
	await frames(6)
	check(bow.attack_count == 1 and player.bow_recovery_remaining > 0.0, "bow fires once after windup")
	check((player.position - origin).dot(bow.swing_direction) < -1.0 and game.feedback.shake_time > 0.0, "bow shot moves the body backward and shakes the camera")
	check(is_equal_approx(player.movement_multiplier(), 0.55), "bow recovery still allows movement")
	click_mouse(false, target, true)
	await frames(36)
	click_mouse(true, target, true)
	await frames(3)
	check(bow.attack_count == 1 and player.bow_windup_remaining == 0.0 and player.bow_recovery_remaining > 0.0, "press near end of recovery cannot queue another shot")
	await frames(75)
	check(bow.attack_count == 1 and player.bow_recovery_remaining == 0.0, "holding through the end of recovery never repeats")
	click_mouse(false, target, true)
	click_mouse(true, target, true)
	click_mouse(false, target, true)
	await frames(18)
	check(bow.attack_count == 2, "fresh tap after recovery fires even after button release")
	reset()
	click_mouse(true, target, true)
	await frames(5)
	key(KEY_SPACE)
	await frames(2)
	check(game.player.is_rolling() and game.player.bow_windup_remaining == 0.0, "successful roll cancels bow windup")
	click_mouse(false, target, true)
	await frames(35)
	check(game.player.ranged_weapon.attack_count == 0, "cancelled bow never fires after roll")

func snapshot(label: String) -> void:
	await frames(4)
	var bounds := Rect2(Vector2.ZERO, game.hud.root.size).grow(1)
	for panel in game.hud.combat_panels:
		check(bounds.encloses(panel.get_global_rect()), label + " HUD fits")
	if game.hud.overlay.visible:
		check(bounds.encloses(game.hud.modal_panel.get_global_rect()), label + " modal fits")
		for item in game.hud.modal_panel.find_children("*", "Control", true, false):
			if item.is_visible_in_tree():
				check(bounds.encloses(item.get_global_rect()), label + " text/button fits")
	if OS.get_cmdline_user_args().has("--visual"):
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(OUT + label + ".png") == OK, label + " screenshot saved")

func run() -> void:
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/main_v41.tscn", "F5 uses integrated V4.1")
	game = load("res://scenes/main_v41.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frames()
	reset()
	check(game.total == 4 and enemies().size() == 4 and game.scheduler.groups.size() == 2, "room1: four spawned melee, two real pairs")
	check(game.world.backdrop.texture != null and game.world.lanterns.size() == 2, "approved courtyard texture and two collidable lanterns")
	check(game.player.combo.get_script() == load("res://scripts/v41_sword.gd") and game.player.combo.has_method("motion_pose"), "F5 uses orbit sword with rewards")
	var draws := {}
	var offered := {}
	for seed_value in range(16):
		game.reward_rng.seed = seed_value
		game._draw_rewards()
		draws[str(game.reward_options)] = true
		for index in game.reward_options: offered[index] = true
	check(draws.size() > 1 and offered.size() == 4, "seeded draws vary and can offer all four rewards")
	for point in CONFIG.SPAWN_POINTS + [CONFIG.ENTRY_POINT, CONFIG.REWARD_POINT, CONFIG.EXIT_POINT]:
		check(Geometry2D.is_point_in_polygon(point, game.world.walkable) and not game.world.path_between(CONFIG.ENTRY_POINT, point).is_empty(), "configured point reachable: " + str(point))
	for e in enemies():
		check(e.encounter_id == 0 and e.max_simultaneous_attackers == 3 and e.health == 180.0 and e.damage == 12.0, "spawn enables encounter mechanics and configured stats")
	# Actual spawned defender: let real physics update its direction, then inspect hit.
	var defender: SurvivorEnemy = enemies()[0]
	game.player.set_physics_process(false)
	game.player.position = Vector2(570, 400)
	defender.position = Vector2(660, 400)
	defender.guard_cooldown = 0.0
	defender.set_physics_process(true)
	await frames(1)
	defender.set_physics_process(false)
	var hp := defender.health
	defender.take_damage(100.0, Vector2.RIGHT * 100.0)
	check(is_equal_approx(hp - defender.health, 35.0) and defender.guard_time > 0.0 and defender.guard_direction.x < -0.9, "REAL F5 defender: front 35 percent and active blue-arc state")
	hp = defender.health
	defender.take_damage(30.0, Vector2.LEFT * 100.0)
	check(is_equal_approx(hp - defender.health, 30.0), "REAL F5 defender: back full damage")
	await snapshot("guard")
	reset()
	# Pair scheduler with real AI running: track starts, recovery and alternation.
	game.player.set_physics_process(false)
	game.player.position = Vector2(620, 420)
	for i in range(enemies().size()):
		var e = enemies()[i]
		e.position = game.player.position + Vector2.RIGHT.rotated(i * TAU / 4.0) * 55.0
		e.home_position = e.position
		e.set_physics_process(true)
	var violation := false
	var waiting_moved := false
	var starts := 0
	var previous: Dictionary = {}
	for i in range(480):
		await frames(1)
		var active_groups := {}
		var active_count := 0
		for g in range(game.scheduler.groups.size()):
			for e in game.scheduler.groups[g]:
				if not game.scheduler.alive(e): continue
				var busy: bool = e.windup > 0.0 or e.lunge_time > 0.0
				if busy:
					active_groups[g] = true
					active_count += 1
				if busy and not previous.get(e.get_instance_id(), false): starts += 1
				previous[e.get_instance_id()] = busy
				if not game.scheduler.owns_turn(e) and e.get_real_velocity().length() > 1.0: waiting_moved = true
		violation = violation or active_groups.size() > 1 or active_count > CONFIG.PAIR_SIZE
	check(not violation and starts >= 4, "real physics: only selected pair attacks, multiple attack rounds occur")
	check(game.scheduler.history.size() >= 3 and game.scheduler.history[0] == 0 and game.scheduler.history[1] == 1 and game.scheduler.history[2] == 0, "real physics: pair 0 -> pair 1 -> pair 0, not a mere cap")
	check(waiting_moved, "real physics: non-active pair moves aside")
	freeze()
	# Adjustable queue and failure paths use the same actual spawned actors.
	game.scheduler.configure(enemies(), 1, 0.2)
	check(game.scheduler.groups.size() == 4 and game.scheduler.can_start(enemies()[0]) and not game.scheduler.can_start(enemies()[1]), "configurable pair size changes permission, not just number cap")
	game.scheduler.tick(0.21)
	check(game.scheduler.current == 1, "unreachable/unstarted turn times out instead of stalling queue")
	var previous_turn: int = game.scheduler.current
	var owner = game.scheduler.groups[previous_turn][0]
	owner.windup = 0.0
	owner.lunge_time = 0.0
	owner.attack_cooldown = 0.0
	game.scheduler.attack_started(owner)
	game.scheduler.tick(0.0)
	check(game.scheduler.current == previous_turn + 1, "finished recovery hands off immediately without artificial delay")
	owner = game.scheduler.groups[game.scheduler.current][0]
	owner.take_damage(10000.0, Vector2.ZERO, true)
	game.scheduler.tick(0.0)
	check(game.scheduler.current == 3, "dead active member immediately releases turn")
	# Room/wave totals, final-wave reward gate, stats and actual ranged retreat.
	reset()
	game.player.set_physics_process(false)
	await clear_room()
	check(game.phase == "reward_wait" and not game.world.portal_open, "full room clear required before reward")
	await reward(0)
	game.player.health = 63.0
	game.player.stamina = 47.0
	await advance()
	game.player.set_physics_process(false)
	check(game.room_index == 1 and game.total == 6 and game.remaining == 6 and enemies().size() == 3, "room2 starts only wave1 of six total")
	check(game.player.health == 63.0 and game.player.stamina >= 47.0 and game.player.stamina < 50.0 and game.reward_counts[0] == 1, "vitals preserved; only normal stamina regeneration after entry")
	var ranger: SurvivorEnemy
	for e in enemies():
		check(is_equal_approx(e.health, (120.0 if e.kind == e.Kind.RANGED else 180.0) * 1.2) and is_equal_approx(e.damage, (10.0 if e.kind == e.Kind.RANGED else 12.0) * 1.2), "room2 scales both health and damage")
		if e.kind == e.Kind.RANGED: ranger = e
	ranger.position = Vector2(680, 420)
	game.player.position = Vector2(580, 420)
	ranger.windup = 0.0
	ranger.attack_cooldown = 0.0
	var before: float = ranger.position.distance_to(game.player.position)
	ranger.set_physics_process(true)
	await frames(6)
	ranger.set_physics_process(false)
	check(ranger.position.distance_to(game.player.position) > before + 3.0 and ranger.velocity.x > 0, "REAL F5 spawned ranger physically retreats at close range")
	await snapshot("ranged_retreat")
	await clear_wave()
	check(game.wave_index == 1 and enemies().size() == 3 and game.remaining == 3 and not game.world.reward_visible, "second wave only after first clear, no early reward")
	await clear_wave()
	await reward(1)
	await advance()
	game.player.set_physics_process(false)
	check(game.total == 8 and enemies().size() == 4 and game.remaining == 8, "room3 starts first four of eight")
	await clear_wave()
	var thrusts := 0
	for e in enemies():
		if e.thrust_type and e.fast_chaser: thrusts += 1
		check(is_equal_approx(e.health, (120.0 if e.kind == e.Kind.RANGED else 180.0) * 1.4), "room3 health scale")
	check(thrusts == 1 and game.scheduler.groups.size() == 2 and game.scheduler.groups[1].size() == 1, "third room second wave includes one fast thrust and odd singleton turn")
	await clear_wave()
	await reward(2)
	await advance()
	check(game.phase == "cleared" and game.run_kills == 18 and enemies().is_empty(), "three rooms finish at terminal with eighteen kills")
	key(KEY_ENTER)
	freeze()
	check(game.room_index == 0 and game.reward_counts == [0, 0, 0, 0] and game.player.health == 100.0, "win restart clears full run")
	# Mixed real AI cannot exceed the configurable overall attack budget.
	game.room_index = 2
	game._enter_room()
	game.player.gm_invulnerable = true
	game.player.set_physics_process(false)
	game.player.position = Vector2(610, 420)
	var cap_violation := false
	var ranged_started := false
	for i in range(240):
		await frames(1)
		var active := 0
		for e in enemies():
			if e.windup > 0.0 or e.lunge_time > 0.0:
				active += 1
				if e.kind == e.Kind.RANGED: ranged_started = true
		cap_violation = cap_violation or active > CONFIG.ATTACK_LIMIT
	check(not cap_violation and ranged_started, "real mixed melee/ranged wave respects total configurable cap3")
	await check_bow_cycle()
	# Input boundaries use real GUI-dispatched press/release and 60Hz physics.
	reset()
	var sword = game.player.combo
	click_mouse(true)
	await frames(6)
	check(sword.attack_count == 0 and not sword.charging, "short hold does not attack on press")
	click_mouse(false)
	await frames(2)
	check(sword.attack_count == 1 and sword.stage == 0 and not sword.charged_swing, "short release attacks first stage")
	await frames(3)
	click_mouse(true)
	click_mouse(false)
	await frames(26)
	check(sword.attack_count == 2 and sword.stage == 1, "short release buffers second stage")
	click_mouse(true)
	click_mouse(false)
	await frames(28)
	check(sword.attack_count == 3 and sword.stage == 2, "short release buffers third stage")
	reset()
	sword = game.player.combo
	click_mouse(true)
	await frames(14)
	check(sword.charging and sword.attack_count == 0, "0.22 threshold starts charge without extra ordinary hit")
	await frames(40)
	check(sword.charge_fraction() == 1.0 and sword.attack_count == 0, "0.60 more seconds reaches full charge without auto release")
	click_mouse(false)
	await frames(1)
	check(sword.charged_swing and sword.attack_count == 1 and not sword.charging, "release starts exactly one charged attack")
	reset()
	sword = game.player.combo
	click_mouse(true)
	await frames(18)
	key(KEY_SPACE)
	await frames(2)
	check(game.player.is_rolling() and not sword.charging, "real Space cancels charging only on successful roll")
	click_mouse(false)
	await frames(30)
	check(sword.attack_count == 0, "release after cancelled charge never produces delayed attack")
	reset()
	game.reward_counts[1] = 1
	game._apply_rewards()
	sword = game.player.combo
	game.player.try_roll()
	await frames(24)
	check(sword.roll_armed, "successful roll arms reward while rolling does not consume it")
	click_mouse(true)
	click_mouse(false)
	await frames(2)
	check(sword.swing_bonus == 2.0 and not sword.roll_armed, "ordinary short-release attack consumes roll reward even on miss")
	await frames(24)
	click_mouse(true)
	click_mouse(false)
	await frames(2)
	check(sword.swing_bonus == 1.0, "roll multiplier is not reused for second ordinary attack")
	reset()
	sword = game.player.combo
	click_mouse(true)
	await frames(20)
	game.player._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	click_mouse(false)
	await frames(3)
	check(not sword.charging and sword.attack_count == 0, "focus loss clears hold and release cannot attack")
	# Actual contact tests use the current F5's spawned enemy and orbit blade.
	reset()
	game.player.set_physics_process(false)
	game.player.combo.set_physics_process(false)
	game.player.position = Vector2(580, 420)
	game.reward_counts.assign([1, 1, 0, 1])
	game._apply_rewards()
	sword = game.player.combo
	var target := target_at(game.player.position + Vector2(65, 0))
	check(is_equal_approx(sword.stages[0].damage, 41.6) and is_equal_approx(sword.charge_damage_max, 123.5), "+30 percent applies to ordinary and charged base, without shared bow multiplier")
	game.player.try_roll()
	game.player._finish_roll()
	check(sword.roll_armed, "roll arms one empowered sword")
	sword.gesture_held = true
	sword.charging = true
	sword.charge_time = sword.charge_duration
	sword._release_charge(Vector2.RIGHT)
	check(not sword.roll_armed and sword.swing_bonus == 2.0, "charge release consumes roll bonus once")
	tick_sword(40)
	check(is_equal_approx(1000.0 - target.health, 247.0), "actual charged orbit hit combines 95 x 1.3 x 2")
	check(target.knockback.length() <= 260.1, "third-stage reward never boosts charged knockback")
	# Fresh full charge hits multiple real spawned targets once each.
	reset()
	game.player.set_physics_process(false)
	game.player.combo.set_physics_process(false)
	game.player.position = Vector2(580, 420)
	sword = game.player.combo
	var targets := enemies()
	for i in range(targets.size()):
		targets[i].position = game.player.position + Vector2.RIGHT.rotated(-0.6 + i * 0.4) * 90.0
		targets[i].health = 1000.0
		targets[i].guard_cooldown = 10.0
	sword.charging = true
	sword.charge_time = sword.charge_duration
	sword._release_charge(Vector2.RIGHT)
	tick_sword(70)
	for e in targets:
		check(is_equal_approx(1000.0 - e.health, 95.0), "charged multi-target deals exactly one 95 hit per spawned enemy")
	# Heavy reward bypasses a real front guard only for ordinary third stage.
	for charged in [false, true]:
		reset()
		game.player.set_physics_process(false)
		game.player.combo.set_physics_process(false)
		game.player.position = Vector2(580, 420)
		game.reward_counts[3] = 1
		game._apply_rewards()
		sword = game.player.combo
		target = target_at(game.player.position + Vector2(65, 0))
		target.guard_cooldown = 0.0
		target.guard_direction = Vector2.LEFT
		target.encounter_state = target.EncounterState.CHASE
		if charged:
			sword.charging = true
			sword.charge_time = sword.charge_duration
			sword._release_charge(Vector2.RIGHT)
		else:
			sword.next_stage = 2
			sword.chain_time = 0.2
			sword.attack(Vector2.RIGHT)
		tick_sword(40)
		check(is_equal_approx(1000.0 - target.health, 33.25 if charged else 60.0), "guard interaction: charged block / ordinary third break = " + str(charged))
		check(is_equal_approx(target.knockback.length(), 65.0 if charged else CONFIG.HEAVY_PUSH), "correct charged vs third knockback")
	reset()
	game.reward_counts[2] = 2
	game.player.health = 91.0
	var killed = enemies()[0]
	killed.take_damage(10000.0, Vector2.ZERO, true)
	check(game.player.health == 100.0, "stacked kill heal capped at max health")
	game.player.gm_invulnerable = false
	game.player.invulnerability = 0.0
	game.player.take_damage(10000.0, Vector2.ZERO)
	check(game.phase == "dead" and paused, "real damage enters death result")
	key(KEY_R)
	freeze()
	check(game.reward_counts == [0, 0, 0, 0] and game.player.health == 100.0 and not paused, "death R resets run and rewards")
	await clear_room()
	game.player.position = CONFIG.REWARD_POINT
	await frames()
	game.reward_options.assign([0, 1, 3])
	game.reward_counts[1] = 1
	game.hud.show_rewards()
	await frames()
	var chosen: Button
	var disabled: Button
	for item in game.hud.modal_panel.find_children("*", "Button", true, false):
		if item.text.begins_with("剑伤害"): chosen = item
		if item.text.begins_with("翻滚后"): disabled = item
	check(disabled != null and disabled.disabled, "already unlocked unique reward is visibly disabled")
	game.select_reward(1)
	check(game.phase == "reward_select", "disabled unique reward cannot be selected through code")
	var count_before: int = game.player.weapon.attack_count
	var point := chosen.get_global_rect().get_center()
	click_mouse(true, point)
	await frames(1)
	click_mouse(false, point)
	await frames(2)
	check(game.phase == "exit_ready" and game.reward_counts[0] == 1 and game.player.weapon.attack_count == count_before, "real reward button applies once without ordinary or charged attack")
	game.player.combo.roll_armed = true
	click_mouse(true)
	await frames(18)
	# Change rooms through the real exit while holding a charge.
	await advance()
	click_mouse(false)
	await frames(2)
	check(game.room_index == 1 and game.reward_counts[1] == 1 and not game.player.combo.roll_armed and not game.player.combo.charging and game.player.combo.attack_count == 0, "room transition preserves unlock but clears armed multiplier and held charge")
	# All original imported samples must load with compatible charge-aware player.
	for path in ["courtyard_trial", "sword_motion_trial", "sword_motion_combat"]:
		var sample = load("res://scenes/" + path + ".tscn").instantiate()
		root.add_child(sample)
		await frames()
		check(sample.player.combo.has_method("press_primary"), "imported sample runs: " + path)
		sample.free()
	# Stable screenshots / viewport bounds at both sizes.
	for size in [Vector2i(960, 540), Vector2i(1280, 720)]:
		root.size = size
		root.content_scale_size = size
		reset()
		await snapshot("%d_courtyard" % size.x)
		game.toggle_view()
		await snapshot("%d_close" % size.x)
		game.toggle_view()
		click_mouse(true)
		await frames(55)
		await snapshot("%d_charge" % size.x)
		game.toggle_pause()
		await snapshot("%d_pause" % size.x)
		check(not game.player.combo.charging and not game.player.combo.gesture_held, "pause clears charge gesture")
		game.resume_room()
		click_mouse(false)
		game.toggle_stats()
		await snapshot("%d_stats" % size.x)
		game.resume_room()
		await clear_room()
		game.player.position = CONFIG.REWARD_POINT
		await frames()
		await snapshot("%d_rewards" % size.x)
		game.select_reward(game.reward_options.filter(game.can_select_reward)[0])
	paused = false
	game.queue_free()
	await process_frame
	print("V41 FLOW: %d checks, %d failures; real-scene controlled tests, not human play" % [checks, failures])
	quit(1 if failures else 0)

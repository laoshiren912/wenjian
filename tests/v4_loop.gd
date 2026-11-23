extends SceneTree

# Controlled real-scene fixtures and dispatched GUI events, not human combat.
var game
var checks := 0
var failures := 0
const CONFIG = preload("res://scripts/v4_config.gd")
const OUTPUT := "res://artifacts/v4_review_2026-11-05/"

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS: " if ok else "FAIL: ") + message)

func frames(count: int = 3) -> void:
	for i in range(count):
		await physics_frame
	await process_frame

func freeze() -> void:
	# Freeze mechanics only, retaining the run controller and real UI processing.
	game.player.set_physics_process(false)
	game.player.weapon.set_physics_process(false)
	game.player.ranged_weapon.set_physics_process(false)
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)

func reset() -> void:
	game.start_room()
	freeze()

func clear_room() -> void:
	for enemy in get_nodes_in_group("enemies"):
		if not enemy.dead:
			enemy.take_damage(10000.0, Vector2.ZERO, true)
	await frames()

func approach_reward() -> void:
	game.player.position = game.world.cell_center(CONFIG.REWARD_CELL)
	await frames()

func advance() -> void:
	game.player.position = game.world.cell_center(game.world.PORTAL_CELL)
	await frames(1)
	freeze()

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)

func mouse(down: bool, point: Vector2) -> void:
	if down:
		Input.action_press("attack")
	else:
		Input.action_release("attack")
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.global_position = point
	event.pressed = down
	root.push_input(event, true)

func button(prefix: String) -> Button:
	for item in game.hud.root.find_children("*", "Button", true, false):
		if item.is_visible_in_tree() and item.text.begins_with(prefix):
			return item
	return null

func click(prefix: String) -> void:
	var target := button(prefix)
	check(target != null, "button available: " + prefix)
	if target == null:
		return
	var point := target.get_global_rect().get_center()
	mouse(true, point)
	await frames(1)
	mouse(false, point)
	await frames()

func snapshot(name: String) -> void:
	await frames()
	var bounds := Rect2(Vector2.ZERO, game.hud.root.size).grow(1)
	for label in [game.hud.timer_text, game.hud.status_text]:
		check(bounds.encloses(label.get_global_rect()), name + " heading fits: " + str(label.get_global_rect()))
	for panel in game.hud.combat_panels:
		check(bounds.encloses(panel.get_global_rect()), name + " HUD fits")
	if game.hud.overlay.visible:
		check(bounds.encloses(game.hud.modal_panel.get_global_rect()), name + " modal fits")
		for item in game.hud.modal_panel.find_children("*", "Control", true, false):
			if item.is_visible_in_tree():
				check(bounds.encloses(item.get_global_rect()), name + " content fits: " + item.name)
	if OS.get_cmdline_user_args().has("--visual"):
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(OUTPUT + name + ".png") == OK, name + " screenshot saved")

func assert_fresh(label: String) -> void:
	check(game.room_index == 0 and game.remaining == 3 and game.phase == "combat" and not paused, label + " starts room 1")
	check(game.reward_counts == [0, 0, 0] and game.run_kills == 0, label + " clears run state")
	check(game.player.health == 100.0 and game.player.max_health == 100.0 and game.player.stamina == 100.0, label + " restores vitals")
	check(game.player.combo.stages[0].damage == 32.0 and game.player.roll_cooldown == 0.65, label + " restores combat baselines")

func run() -> void:
	check(ResourceLoader.exists("res://scenes/main_v4.tscn"), "V4 remains available via explicit scene")
	for name in ["main_v33", "main_v32", "main_v31", "main", "corridor_trial", "trigger_room", "combat_room", "combat_sample"]:
		check(load("res://scenes/" + name + ".tscn") != null, "old entry loadable: " + name)
	game = load("res://scenes/main_v4.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frames(1)
	reset()
	assert_fresh("entry")
	check(not game.world.reward_visible and not game.world.portal_open, "no early reward or exit")
	game.select_reward(0)
	check(game.reward_counts == [0, 0, 0], "cannot choose before reward")
	game.player.position = game.world.cell_center(game.world.PORTAL_CELL)
	await frames()
	check(game.room_index == 0, "combat blocks exit")
	await clear_room()
	check(game.remaining == 0 and game.phase == "reward_wait" and game.world.reward_visible, "clear spawns reward")
	check(not paused and not game.world.portal_open and game.room_index == 0, "distant reward does not auto-popup or allow exit")
	game.player.position = game.world.cell_center(CONFIG.REWARD_CELL) + Vector2(CONFIG.REWARD_RADIUS + 1.0, 0)
	await frames()
	check(game.phase == "reward_wait" and not paused, "outside 40-pixel reward radius does not open selection")
	game.toggle_pause()
	check(paused and game.phase == "reward_wait", "pause supported while waiting for reward")
	game.resume_room()
	await approach_reward()
	check(paused and game.phase == "reward_select", "proximity opens paused selection")
	key(KEY_ESCAPE)
	key(KEY_TAB)
	check(paused and game.phase == "reward_select" and game.hud.overlay.visible, "Esc/Tab cannot dismiss reward")
	game.select_reward(-1)
	game.select_reward(3)
	check(game.phase == "reward_select" and game.reward_counts == [0, 0, 0], "invalid choice cannot consume reward")
	await click("剑伤害")
	check(game.reward_counts == [1, 0, 0] and game.phase == "exit_ready" and not paused, "GUI choice applied once and resumes")
	check(game.player.weapon.attack_count == 0 and game.player.combo.click_time == 0.0, "reward click never queues attack")
	game.select_reward(0)
	check(game.reward_counts == [1, 0, 0] and not game.world.reward_visible and game.world.portal_open, "duplicate choice ignored, reward removed, exit open")
	check(is_equal_approx(game.player.combo.stages[0].damage, 36.8) and game.player.damage_multiplier == 1.0, "sword +15 percent without shared bow multiplier")
	# Actual sword hit, preserving the existing sweep rather than faking damage.
	var target: SurvivorEnemy = game.ENEMY.instantiate()
	target.world = game.world
	target.dodge_enabled = false
	target.position = game.player.position + Vector2(65, 0)
	game.world.actors.add_child(target)
	target.set_physics_process(false)
	target.collision_layer = 0
	game.player.weapon.attack(Vector2.RIGHT)
	for i in range(40):
		game.player.weapon._physics_process(0.01)
	check(is_equal_approx(target.max_health - target.health, 36.8), "real blade sweep deals boosted damage")
	target.free()
	game.player.ranged_weapon.attack(Vector2.RIGHT)
	var arrow
	for actor in game.world.actors.get_children():
		if actor.get_script() == load("res://scripts/projectile.gd"):
			arrow = actor
	check(arrow != null and arrow.damage == 21.0, "actual bow projectile retains 21 damage")
	var stale_arrow: WeakRef = weakref(arrow)
	game.player.health = 61.0
	game.player.stamina = 47.0
	game.player.combo.queue_click()
	game.player._roll_requested = true
	game.player._roll_cooldown = 0.6
	await advance()
	check(game.room_index == 1 and game.remaining == 4, "exit advances to second room")
	check(game.player.health == 61.0 and game.player.stamina == 47.0, "room transition preserves health and stamina")
	check(game.reward_counts == [1, 0, 0] and is_equal_approx(game.player.combo.stages[0].damage, 36.8), "bonus preserved without re-multiplication")
	check(stale_arrow.get_ref() == null and game.player.combo.click_time == 0.0 and not game.player._roll_requested and game.player._roll_cooldown == 0.0, "transition clears projectile, queued input and cooldown")
	var ranged := 0
	for enemy in get_nodes_in_group("enemies"):
		if enemy.kind == SurvivorEnemy.Kind.RANGED:
			ranged += 1
	check(ranged == 1, "second room has one ranged enemy")
	await clear_room()
	await approach_reward()
	game.select_reward(1)
	check(game.player.health == 81.0 and game.player.max_health == 120.0, "health reward adds 20 to both current and max")
	await advance()
	check(game.room_index == 2 and game.remaining == 5 and game.player.health == 81.0 and game.player.max_health == 120.0, "third room keeps vitals and rewards")
	ranged = 0
	for enemy in get_nodes_in_group("enemies"):
		if enemy.kind == SurvivorEnemy.Kind.RANGED:
			ranged += 1
	check(ranged == 1, "third room has four melee and one ranged")
	await clear_room()
	await approach_reward()
	game.select_reward(2)
	check(is_equal_approx(game.player.roll_cooldown, 0.65 * 0.85), "roll reward reduces cooldown only")
	game.player.try_roll()
	check(is_equal_approx(game.player._roll_cooldown, 0.65 * 0.85) and game.player.is_rolling(), "actual roll uses rewarded cooldown")
	await advance()
	check(game.room_index == 3 and game.phase == "cleared" and paused and game.total == 0, "terminal room wins without combat")
	check(game.run_kills == 12 and game.reward_counts == [1, 1, 1] and get_nodes_in_group("enemies").is_empty() and not game.world.reward_visible, "terminal has 12 kills, 3 rewards, no enemies/reward")
	key(KEY_ENTER)
	freeze()
	assert_fresh("win Enter restart")
	# Repeat each reward through all three real room transitions.
	for choice in range(3):
		reset()
		for room in range(3):
			await clear_room()
			await approach_reward()
			game.select_reward(choice)
			var count := room + 1
			check(game.reward_counts[choice] == count, "repeat reward count %d/%d" % [choice, count])
			if choice == 0:
				check(is_equal_approx(game.player.combo.stages[2].damage, 60.0 * (1.0 + count * 0.15)), "sword stacks additively")
			elif choice == 1:
				check(game.player.max_health == 100.0 + count * 20.0 and game.player.health == game.player.max_health, "health repeat stays capped")
			else:
				check(is_equal_approx(game.player.roll_cooldown, 0.65 * pow(0.85, count)), "roll stacks multiplicatively")
			await advance()
		check(game.phase == "cleared", "repeat reward route reaches terminal")
	# Death in each room, using real damage and actual restart key/button routes.
	for death_room in range(3):
		reset()
		for i in range(death_room):
			await clear_room()
			await approach_reward()
			game.select_reward(0)
			await advance()
		game.player.invulnerability = 0.0
		game.player.take_damage(10000.0, Vector2.ZERO)
		check(paused and game.phase == "dead" and game.room_index == death_room, "death result in room %d" % (death_room + 1))
		if death_room == 2:
			await click("重新开始")
		else:
			key(KEY_R if death_room == 0 else KEY_ENTER)
		freeze()
		assert_fresh("death restart %d" % death_room)
	await clear_room()
	await approach_reward()
	game.select_reward(1)
	game.toggle_pause()
	await click("重新开始")
	freeze()
	assert_fresh("pause restart")
	var old_player = load("res://scenes/player_combo.tscn").instantiate()
	root.add_child(old_player)
	check(old_player.combo.stages[0].damage == 32.0 and old_player.combo.stages[2].damage == 60.0, "V3.3 new instance untouched by V4 rewards")
	old_player.free()
	# Controlled visual fixtures at both supported review sizes.
	for size in [Vector2i(960, 540), Vector2i(1280, 720)]:
		root.size = size
		root.content_scale_size = size
		reset()
		await snapshot("%d_combat" % size.x)
		await clear_room()
		await snapshot("%d_reward_marker" % size.x)
		await approach_reward()
		await snapshot("%d_reward" % size.x)
		game.select_reward(0)
		game.toggle_stats()
		await snapshot("%d_stats" % size.x)
		game.resume_room()
		game.player.take_damage(10000.0, Vector2.ZERO)
		await snapshot("%d_death" % size.x)
		reset()
		for i in range(3):
			await clear_room()
			await approach_reward()
			game.select_reward(i)
			await advance()
		await snapshot("%d_win" % size.x)
	paused = false
	game.queue_free()
	await process_frame
	print("V4 LOOP: %d checks, %d failures; controlled fixtures, not human play" % [checks, failures])
	quit(1 if failures else 0)

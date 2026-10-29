extends SceneTree

# Real GUI + physics; send both pointer dispatch and global Input state in headless.
var game: SurvivorGame
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print(("PASS: " if condition else "FAIL: ") + description)

func frames(count: int = 3) -> void:
	for frame in range(count):
		await physics_frame
	await process_frame

func button(prefix: String) -> Button:
	for candidate in game.hud.root.find_children("*", "Button", true, false):
		if candidate.is_visible_in_tree() and candidate.text.begins_with(prefix):
			return candidate
	assert(false, "Missing visible button: " + prefix)
	return null

func mouse(pressed: bool, point: Vector2) -> void:
	if pressed:
		Input.action_press("attack")
	else:
		Input.action_release("attack")
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = point
	event.global_position = point
	root.push_input(event, true)

func click(control: Control) -> void:
	var point: Vector2 = control.get_global_rect().get_center()
	mouse(true, point)
	await frames()
	mouse(false, point)
	await frames()

func fixture() -> void:
	# Isolate UI from random combat, without immunity or stat changes.
	for enemy in get_nodes_in_group("enemies"):
		enemy.free()
	game.spawn_timer = 9999.0

func reloaded() -> void:
	await frames(4)
	game = current_scene
	fixture()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frames()
	fixture()
	mouse(true, Vector2(30, 400))
	await frames()
	mouse(false, Vector2(30, 400))
	await frames()
	check(paused and game.player.weapon.attack_count == 0, "Start backdrop blocks world input")
	await click(button("开始试炼"))
	check(not paused and game.player.weapon.attack_count == 0 and game.player.stamina == 100.0, "Start button resumes without attacking")
	for index in range(SurvivorWeapon.DATA.size()):
		game.restart_run()
		await reloaded()
		game.select_profession(index)
		await click(button("开始试炼"))
		check(game.player.weapon.selected == index and game.player.weapon.locked, "Fresh UI profession starts with its locked weapon")
		await click(button("暂停"))
		check(paused and game.player.weapon.attack_count == 0 and game.player.stamina == 100.0, "HUD pause does not attack or spend stamina, weapon %d" % (index + 1))
		await click(button("继续"))
		check(not paused and game.player.weapon.attack_count == 0 and game.player.stamina == 100.0, "Continue button does not attack, weapon %d" % (index + 1))
	await click(button("角色属性"))
	check(paused and game.stats_open and game.player.weapon.attack_count == 0, "Attributes button does not attack")
	await click(button("返回战斗"))
	check(not paused and game.player.weapon.attack_count == 0, "Attributes return does not attack")
	mouse(true, button("暂停").get_global_rect().get_center())
	await frames()
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(600, 450)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion, true)
	await frames(40)
	check(not paused and game.player.weapon.attack_count == 0 and game.player.stamina == 100.0, "Dragging a UI press into world cannot begin an attack")
	mouse(false, motion.position)
	await frames()
	game.restart_run()
	await reloaded()
	await click(button("开始试炼"))
	mouse(true, Vector2(600, 450))
	await frames(35)
	check(game.player.weapon.attack_count >= 2 and game.player.stamina == 100.0, "World press still supports hold-to-attack without stamina cost")
	var attacks: int = game.player.weapon.attack_count
	mouse(false, button("暂停").get_global_rect().get_center())
	await frames(40)
	check(game.player.weapon.attack_count == attacks, "Release over GUI ends a world attack gesture")
	mouse(true, Vector2(600, 450))
	await frames()
	game.toggle_pause()
	attacks = game.player.weapon.attack_count
	game.resume_run()
	await frames(40)
	check(game.player.weapon.attack_count == attacks, "Pause clears a held world attack; resume requires a new press")
	mouse(false, Vector2(600, 450))
	await frames(240)
	mouse(true, Vector2(600, 450))
	game.player.gain_experience(game.player.next_level_xp)
	await frames()
	check(not paused and game.player.skill_points == 1, "Earning a skill point does not interrupt held attack")
	mouse(false, Vector2(600, 450))
	await frames()
	attacks = game.player.weapon.attack_count
	await frames(40)
	check(game.player.weapon.attack_count == attacks, "Attack ends after release following a level gain")
	await click(button("暂停"))
	await click(button("重新开始"))
	await reloaded()
	check(game.state == SurvivorGame.State.START and game.player.weapon.attack_count == 0 and game.player.stamina == 100.0, "Pause-menu restart creates a clean player")
	await click(button("开始试炼"))
	game.player.take_damage(999.0, Vector2.RIGHT)
	await frames()
	check(game.state == SurvivorGame.State.DEAD, "Death result fixture opens")
	await click(button("重新开始"))
	await reloaded()
	check(game.state == SurvivorGame.State.START and game.player.weapon.attack_count == 0 and game.player.stamina == 100.0, "Death-result restart does not leak mouse attack into new scene")
	await click(button("开始试炼"))
	check(game.player.weapon.attack_count == 0 and game.player.stamina == 100.0, "Starting after death restart remains free of UI attacks")
	game._end_run(true)
	await frames()
	await click(button("重新开始"))
	await reloaded()
	check(game.state == SurvivorGame.State.START and game.player.weapon.attack_count == 0 and game.player.stamina == 100.0, "Victory-result restart does not leak mouse attack")
	print("UI REGRESSION RESULT: %d checks, %d failures" % [checks, failures])
	paused = false
	quit(0 if failures == 0 else 1)

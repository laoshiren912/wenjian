extends SceneTree

# Regress the confirmed same-tick click loss, including UI and cooldown boundaries.
# The original native click duration was not measured; its causal link stays unconfirmed.
var game: SurvivorGame
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func frames(count: int) -> void:
	for index in range(count):
		await physics_frame
	await process_frame

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS: " if ok else "FAIL: ") + description)

func mouse(pressed: bool, point: Vector2 = Vector2(840, 360)) -> void:
	if pressed:
		Input.action_press("attack")
	else:
		Input.action_release("attack")
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.global_position = point
	event.pressed = pressed
	root.push_input(event, true)

func ui_button(prefix: String) -> Button:
	for candidate in game.hud.root.find_children("*", "Button", true, false):
		if candidate.is_visible_in_tree() and candidate.text.begins_with(prefix):
			return candidate
	assert(false, "Missing button: " + prefix)
	return null

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frames(2)
	game.start_run()
	game.spawn_timer = 9999.0
	for enemy in get_nodes_in_group("enemies"):
		enemy.free()
	await frames(2)
	var player: SurvivorPlayer = game.player
	for index in range(3):
		game.restart_run()
		await frames(4)
		game = current_scene
		game.select_profession(index)
		game.start_run()
		game.spawn_timer = 9999.0
		for enemy in get_nodes_in_group("enemies"):
			enemy.free()
		player = game.player
		check(player.weapon.selected == index and player.weapon.locked, "Fresh profession supplies the intended locked weapon")
		player.weapon.cooldown = 0.0
		player.stamina = 0.0
		player.stamina_delay = 10.0
		var before: int = player.weapon.attack_count
		mouse(true)
		mouse(false)
		await frames(2)
		check(player.weapon.attack_count == before + 1, "Weapon %d accepts a released same-tick click exactly once" % (index + 1))
		check(player.stamina == 0.0, "Weapon %d short click stays free at zero stamina" % (index + 1))
		mouse(true)
		mouse(false)
		await frames(2)
		check(player.weapon.attack_count == before + 1, "Weapon %d short click cannot bypass cooldown" % (index + 1))
		await frames(60)
		check(player.weapon.attack_count == before + 1, "Weapon %d cooldown-rejected click is not replayed later" % (index + 1))
	player.weapon.cooldown = 0.0
	var before: int = player.weapon.attack_count
	mouse(true)
	mouse(false)
	game.toggle_pause()
	game.resume_run()
	await frames(2)
	check(player.weapon.attack_count == before, "Pause clears an unprocessed click before resuming")
	mouse(true)
	mouse(false)
	player._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	await frames(2)
	check(player.weapon.attack_count == before, "Focus-out notification clears an unprocessed click")
	var point: Vector2 = ui_button("暂停").get_global_rect().get_center()
	mouse(true, point)
	mouse(false, point)
	await frames(2)
	check(paused and player.weapon.attack_count == before and not player._attack_pending, "Short HUD pause click is consumed by GUI without arming an attack")
	point = ui_button("继续").get_global_rect().get_center()
	mouse(true, point)
	mouse(false, point)
	await frames(2)
	check(not paused and player.weapon.attack_count == before, "Short continue click resumes without attacking")
	for index in range(10):
		mouse(true)
		mouse(false)
	await frames(2)
	check(player.weapon.attack_count == before + 1, "Multiple clicks in one physics interval cannot multiply attacks")
	print("CLICK TIMING RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

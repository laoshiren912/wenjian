extends SceneTree

# Engine-driven 60 Hz frames, with enemy AI stopped to isolate player input.
var game
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS: " if ok else "FAIL: ") + message)

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
	await process_frame

func mouse(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = Vector2(600, 340)
	event.pressed = pressed
	if pressed:
		Input.action_press("attack")
	else:
		Input.action_release("attack")
	root.push_input(event, true)

func run() -> void:
	game = load("res://scenes/main_v33.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frames(2)
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	var player = game.player
	var sword = player.weapon
	var origin: Vector2 = player.position
	mouse(true)
	await frames(8)
	mouse(false)
	mouse(true)
	mouse(false)
	await frames(16)
	check(sword.stage == 1 and sword.attack_count == 2, "60 Hz GUI-dispatched click buffers second stage")
	await frames(9)
	mouse(true)
	mouse(false)
	await frames(15)
	check(sword.stage == 2 and sword.attack_count == 3, "60 Hz third stage follows distinct click")
	check(player.position.distance_to(origin) < 30.1, "60 Hz lunge remains bounded")
	while sword.time_until_roll() > 0.10:
		await frames(1)
	var space := InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	space.keycode = KEY_SPACE
	space.pressed = true
	root.push_input(space, true)
	check(sword.roll_queued and not player.is_rolling(), "60 Hz Space buffers only late in recovery")
	await frames(9)
	check(player.is_rolling() and sword.swing_time == 0.0, "60 Hz third downswing completes before roll cancels recovery")
	await frames(30)
	check(sword.attack_count == 3, "no extra sword from released mouse")
	game.toggle_pause()
	var position: Vector2 = player.position
	await frames(10)
	check(player.position == position and not sword.roll_queued and sword.click_time == 0.0, "60 Hz pause stops movement and clears queues")
	game.start_room()
	check(game.remaining == 4 and game.player.combo_enabled and game.player.weapon.attack_count == 0 and not paused, "restart resets four enemies and combo state")
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	var hud_button: Button
	for button in game.hud.root.find_children("*", "Button", true, false):
		if button.text.begins_with("暂停"):
			hud_button = button
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = hud_button.get_global_rect().get_center()
	click.pressed = true
	root.push_input(click, true)
	click = click.duplicate()
	click.pressed = false
	root.push_input(click, true)
	await frames(2)
	check(paused and game.player.weapon.attack_count == 0, "V3.3 HUD click never starts combo")
	paused = false
	game.queue_free()
	await process_frame
	print("COMBO LIVE: %d checks, %d failures; engine frames, not human input" % [checks, failures])
	quit(1 if failures else 0)

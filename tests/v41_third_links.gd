extends "res://tests/v41_third_probe.gd"
var failures := 0
func check(ok: bool, label: String):
	if not ok: failures += 1
	print("LINK ",label," ",ok)
func wait_frames(n: int):
	for i in range(n): await tick()
func tap():
	click(true, Vector2(900,420))
	await tick()
	click(false, Vector2(900,420))
	await tick()
func fresh():
	game.start_room()
	for e in get_nodes_in_group("enemies"): e.free()
	game.player.position = Vector2(620,420)
	await tick()
func finish():
	while game.player.combo.swing_time > 0: await tick()
func run():
	game = load("res://scenes/main_v41.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await tick()
	for pause in [16,20]:
		await fresh()
		await tap()
		await finish()
		await wait_frames(pause)
		await tap()
		check(game.player.combo.stage == (1 if pause == 16 else 0), "deadline " + str(pause))
	await fresh()
	for stage in range(3):
		await tap()
		check(game.player.combo.stage == stage, "stage " + str(stage))
		await finish()
	await tap()
	check(game.player.combo.stage == 0, "third resets")
	await fresh()
	await tap()
	await wait_frames(10)
	await tap()
	await wait_frames(12)
	check(game.player.combo.stage == 1, "in action buffer")
	for action in ["dash", "throw"]:
		await fresh()
		await tap()
		await finish()
		if action == "dash":
			dash()
			await wait_frames(32)
		else:
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_RIGHT
			ev.pressed = true
			ev.position = root.get_canvas_transform() * Vector2(900,420)
			root.push_input(ev,true)
			await tick()
			ev = ev.duplicate()
			ev.pressed = false
			root.push_input(ev,true)
			await wait_frames(42)
		await tap()
		var expected := 1 if action == "dash" else 0
		check(game.player.combo.stage == expected, action + (" preserves next" if action == "dash" else " next first"))
	print("LINK_RESULT failures=",failures)
	quit(1 if failures else 0)



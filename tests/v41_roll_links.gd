extends SceneTree

# V4.1's Space binding used to roll. Check that it now owns exactly one move.
var game
var failures := 0
var checks := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)

func press(action: String, down := true) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = down
	root.push_input(event, true)

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
	await process_frame

func run() -> void:
	game = load("res://scenes/main_v41.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var player = game.player
	player.position = Vector2(480, 410)
	for enemy in get_nodes_in_group("enemies"):
		enemy.free()
	game.scheduler = null
	await frames(2)
	var cursor := InputEventMouseMotion.new()
	cursor.position = root.get_canvas_transform() * Vector2(820, 410)
	root.push_input(cursor, true)
	press("ranged_attack")
	press("roll")
	await frames(3)
	check(player.dash_state == player.Dash.WINDUP and not player.is_rolling(), "Space wins simultaneous dash and throw requests")
	check(not is_instance_valid(player.thrown_sword) and player.throw_cooldown == 0.0 and is_equal_approx(player.stamina, 80.0),
		"no second skill or cost on a shared frame")
	await frames(18)
	check(player.position.x > 620.0 and absf(player.position.y - 410.0) < 1.0, "dash used the locked cursor direction")
	press("roll", false)
	press("ranged_attack", false)
	await frames(22)
	check(not player.is_rolling() and player.dash_state == player.Dash.IDLE, "releases do not activate either movement")
	await frames(123)
	check(player.dash_cooldown == 0.0 and not is_instance_valid(player.thrown_sword), "no queued repeat after cooldown")
	print("V41 SPACE LINKS: %d/%d" % [checks - failures, checks])
	game.free()
	quit(1 if failures else 0)

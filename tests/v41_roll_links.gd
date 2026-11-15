extends SceneTree

var game
var player
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)

func frames(n: int) -> void:
	for i in range(n):
		await physics_frame
	await process_frame

func action(name: String, pressed := true) -> void:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = pressed
	root.push_input(event)

func reset() -> void:
	game.start_room()
	game.debug_opening(true)
	player = game.player
	player.gm_invulnerable = true
	for enemy in get_nodes_in_group("enemies"):
		enemy.free()
	game.scheduler = null

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	game = load("res://scenes/main_v41.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	reset()
	check(player.try_roll(), "initial roll")
	action("attack")
	action("attack", false)
	await frames(5)
	check(player.is_rolling() and player.combo.attack_count == 0, "first half cannot cancel")
	await frames(8)
	check(not player.is_rolling() and player.combo.attack_count == 1, "buffered tap attacks after halfway")
	reset()
	player.try_roll()
	action("ranged_attack")
	await frames(13)
	check(not player.is_rolling() and player.combo.gesture_held, "held input begins at halfway")
	await frames(15)
	check(player.combo.charging, "held input enters normal charge")
	action("ranged_attack", false)
	reset()
	# The button is already held before the roll request reaches physics.
	action("ranged_attack")
	action("roll")
	await frames(6)
	check(player.is_rolling() and player.roll_action == "charge" and player.roll_charge_held, "right hold before roll survives roll reset")
	await frames(8)
	check(not player.is_rolling() and player.combo.gesture_held, "preserved right hold transfers when roll ends")
	await frames(15)
	check(player.combo.charging, "right held through roll enters charge")
	action("ranged_attack", false)
	reset()
	# Roll and held attack arrive before the same physics tick starts the roll.
	action("roll")
	action("ranged_attack")
	await frames(6)
	check(player.is_rolling() and player.roll_action == "charge" and player.roll_charge_held, "held attack survives pending roll start")
	await frames(8)
	check(not player.is_rolling() and player.combo.gesture_held, "pending-roll hold transfers at halfway")
	await frames(15)
	check(player.combo.charging, "pending-roll hold reaches normal charge threshold")
	action("ranged_attack", false)
	reset()
	action("roll")
	action("ranged_attack")
	action("ranged_attack", false)
	await frames(14)
	check(not player.is_rolling() and player.combo.attack_count == 0 and not player.combo.charging, "released pending-roll charge does not attack")
	reset()
	player.try_roll()
	action("attack")
	action("attack", false)
	action("roll")
	await frames(13)
	check(player.is_rolling() and is_equal_approx(player.stamina, 70.0) and player.combo.attack_count == 0, "last roll replaces tap and costs stamina")
	await frames(24)
	check(not player.is_rolling() and is_equal_approx(player.stamina, 70.0), "buffer does not cross next roll")
	reset()
	player.stamina = 20.0
	player.try_roll()
	action("roll")
	await frames(13)
	check(player.is_rolling() and is_equal_approx(player.stamina, 5.0), "insufficient stamina does not cancel roll")
	await frames(12)
	check(not player.is_rolling() and is_equal_approx(player.stamina, 5.0), "insufficient stamina blocks next roll")
	reset()
	player.try_roll()
	action("ranged_attack")
	await frames(13)
	check(not player.is_rolling() and player.combo.gesture_held, "right hold cancels roll at halfway")
	await frames(15)
	check(player.combo.charging, "right hold enters charge")
	action("ranged_attack", false)
	print("V41 ROLL LINKS: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures else 0)

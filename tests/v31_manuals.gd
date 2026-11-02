extends SceneTree
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scenes/main_v31.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	game.start_run()
	var player = game.player
	check(player.manuals.is_empty(), "no starting manual")
	game.state = game.State.SHOP
	paused = true
	game.claim_manual(0)
	game.claim_manual(1)
	check(player.manuals == [0], "one manual per floor")
	game.floor_number = 2
	game.claim_manual(0)
	check(player.manuals.size() == 1, "duplicate rejected")
	game.claim_manual(2)
	check(player.manuals == [0, 2], "second different manual")
	game.floor_number = 3
	game.claim_manual(1)
	check(player.manuals.size() == 2, "no third manual")
	paused = false
	game.state = game.State.PLAYING
	player.use_manual(1)
	check(player.momentum_armed > 0.0 and player.manual_cooldowns[1] > 0.0, "momentum activation")
	check(player.try_roll(), "roll after activation")
	check(player.momentum_ready > 0.0 and player.momentum_armed == 0.0, "roll arms thrust")
	check(is_equal_approx(player.consume_momentum(), 1.7) and is_equal_approx(player.consume_momentum(), 1.0), "one thrust boost")
	player._finish_roll()
	player.use_manual(0)
	check(player.manual_cooldowns[0] > 0.0, "area skill cooldown")
	player.manuals[0] = 1
	player.manual_cooldowns[0] = 0.0
	var before := get_nodes_in_group("projectiles").size()
	player.use_manual(0)
	check(get_nodes_in_group("projectiles").size() == before + 1 and player.manual_cooldowns[0] > 0.0, "sword energy projectile")
	player.manual_cooldowns[0] = 0.0
	player.weapon.swing_time = 0.2
	player.use_manual(0)
	check(player.manual_cooldowns[0] > 0.0 and player.weapon.swing_time == 0.0, "skill cancels unfinished sword action")
	print("MANUALS: failures ", failures)
	paused = false
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)

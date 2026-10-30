extends SceneTree
var failures := 0
func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", description)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	for profession in range(3):
		var game = load("res://scenes/main.tscn").instantiate()
		root.add_child(game)
		current_scene = game
		await process_frame
		game.select_profession(profession)
		game.set_gm_mode(true)
		check(game.gold == 300, "start toggle does not grant early")
		game.set_gm_mode(false)
		game.start_run()
		check(game.gold == 300 and game.player.take_damage(10.0, Vector2.RIGHT), "normal mode damage and gold")
		game.toggle_pause()
		game.set_gm_mode(true)
		check(game.gold == 5300 and game.player.health == game.player.max_health, "GM bonus and heal")
		game.player.invulnerability = 0.0
		check(not game.player.take_damage(10000.0, Vector2.RIGHT) and not game.player.dead, "GM prevents damage")
		game.add_gm_gold()
		check(game.gold == 6300, "GM add gold")
		game.set_gm_mode(false)
		game.set_gm_mode(true)
		check(game.gold == 6300, "bonus once per run")
		game.set_gm_mode(false)
		check(game.player.take_damage(10.0, Vector2.RIGHT), "damage restored")
		paused = false
		game.queue_free()
		await process_frame
	var fresh = load("res://scenes/main.tscn").instantiate()
	root.add_child(fresh)
	await process_frame
	fresh.set_gm_mode(true)
	fresh.start_run()
	check(fresh.gold == 5300 and fresh.player.gm_invulnerable, "start with GM")
	paused = false
	fresh.queue_free()
	await process_frame
	print("GM TEST failures: ", failures)
	quit(1 if failures else 0)

extends SceneTree

# Controlled checks for the temporary, unspendable skill-point placeholder.
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	for profession in range(3):
		var game = load("res://scenes/main.tscn").instantiate()
		root.add_child(game)
		current_scene = game
		await process_frame
		game.select_profession(profession)
		game.start_run()
		var player: SurvivorPlayer = game.player
		if OS.get_cmdline_user_args().has("--desktop"):
			for enemy in get_nodes_in_group("enemies"):
				enemy.free()
			game.pending_wave.clear()
			game.remaining = 1
			player.gain_experience(40)
			root.title = "Skill Point Review"
			print("SKILL POINT REVIEW: controlled XP fixture, no enemies")
			await create_timer(50.0, true).timeout
			quit()
			return
		var hp := player.health
		var max_hp := player.max_health
		var damage := player.damage_multiplier
		var speed := player.speed
		player.gain_experience(90)
		await process_frame
		check(player.level == 3 and player.skill_points == 2 and player.experience == 0, "multiple thresholds award exactly two points")
		check(not paused and game.state == game.State.PLAYING and not game.hud.overlay.visible, "level gains do not interrupt battle")
		check(player.health == hp and player.max_health == max_hp and player.damage_multiplier == damage and player.speed == speed, "no unapproved automatic stat bonuses")
		check("技能点 2" in game.hud.xp_text.text, "HUD displays accumulated points")
		check(game.hud.get_node_or_null("LevelUpUI") == null, "card UI is absent")
		player.gain_experience(1)
		check(player.skill_points == 2, "partial XP does not grant extra points")
		paused = false
		game.queue_free()
		await process_frame
	var fresh = load("res://scenes/main.tscn").instantiate()
	root.add_child(fresh)
	await process_frame
	check(fresh.player.skill_points == 0 and fresh.player.level == 1, "new run starts without carried points")
	paused = false
	fresh.queue_free()
	await process_frame
	print("SKILL POINTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

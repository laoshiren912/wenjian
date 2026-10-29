extends SceneTree

var checks := 0
var failures := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for profession in range(3):
		var game = load("res://scenes/main.tscn").instantiate()
		root.add_child(game)
		await process_frame
		game.select_profession(profession)
		game.start_run()
		check(game.player.profession_index == profession and game.player.weapon.locked, "profession and weapon")
		check(game.gold == 300 and game.player.next_level_xp == 40, "starting gold and XP threshold")
		check(game.remaining == 8, "first floor count")
		game.elapsed = 181.0
		await process_frame
		check(game.state == game.State.PLAYING, "180 seconds does not win")
		for floor_index in range(1, 5):
			check(game.floor_number == floor_index, "floor number")
			if floor_index < 4:
				check(get_nodes_in_group("enemies").size() == [4, 6, 8][floor_index - 1], "initial wave count")
				game._spawn_rear_wave()
			var enemies = get_nodes_in_group("enemies")
			check(enemies.size() == [8, 12, 16, 1][floor_index - 1], "enemy count")
			var ranged := 0
			for enemy in enemies:
				if enemy.kind == enemy.Kind.RANGED:
					ranged += 1
			check(ranged == [0, 2, 4, 0][floor_index - 1], "ranged count")
			var xp_before: int = game.player.total_experience
			var gold_before: int = game.gold
			for enemy in enemies:
				enemy.take_damage(100000.0, Vector2.ZERO)
			check(game.player.total_experience == xp_before + ([80, 120, 160, 0][floor_index - 1]), "kills grant XP immediately")
			check(game.gold == gold_before, "enemies do not award gold")
			check(get_nodes_in_group("pickups").is_empty(), "no XP pickups created")
			await process_frame
			await process_frame
			while game.state == game.State.UPGRADE_PROMPT and not game.floor_reward:
				game.open_upgrade_choices()
				check(game.hud.level_ui.offered.all(func(i): return i < 3), "normal card pool")
				game.hud.level_ui._process(1.0)
				game.hud.level_ui._choose(0)
				await process_frame
				await process_frame
			if floor_index == 4:
				check(game.state == game.State.WON, "boss victory")
				break
			check(game.state == game.State.UPGRADE_PROMPT and game.floor_reward, "floor reward")
			check(game.gold == gold_before + 250, "floor reward exactly once")
			game.open_upgrade_choices()
			check(game.hud.level_ui.offered.all(func(i): return i >= 3), "floor card pool")
			game.hud.level_ui._process(1.0)
			game.hud.level_ui._choose(0)
			check(game.state == game.State.SHOP_PROMPT, "shop transition")
			game.open_shop()
			check(game.state == game.State.SHOP, "shop after reward")
			check(not game.hud.level_ui.visible, "reward card closes before shop")
			var before: int = game.gold
			if floor_index == 1:
				game.buy_item(0)
				check(game.gold == before - 200 and game.purchased[0], "purchase")
				game.buy_item(0)
				check(game.gold == before - 200, "no repeat purchase")
				game.buy_item(2)
				check(not game.purchased[2], "insufficient gold")
			game.next_floor()
			check(game.state == game.State.PLAYING, "next floor")
		check(game.player.level == 6 and game.player.total_experience == 360, "360 XP gives five ordinary levels")
		check(game.gold == 850, "three clear rewards minus one purchase")
		paused = false
		game.queue_free()
		await process_frame
	print("TOWER: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

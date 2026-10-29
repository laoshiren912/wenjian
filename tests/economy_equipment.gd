extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
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
		game.state = game.State.SHOP
		paused = true
		game.gold = 10000
		for item in range(game.EQUIPMENT.size()):
			var before: int = game.gold
			game.buy_item(item)
			check(game.purchased[item] and game.gold == before - game.EQUIPMENT[item].price, "equipment purchase %d" % item)
			game.buy_item(item)
			check(game.gold == before - game.EQUIPMENT[item].price, "no duplicate purchase %d" % item)
		var player: SurvivorPlayer = game.player
		check(is_equal_approx(player.damage_multiplier, 1.25) and is_equal_approx(player.attack_speed_multiplier, 1.10), "AD base bonuses")
		check(player.stamina_on_kill == 5.0 and player.heal_on_kill == 3.0, "kill effects configured")
		check(is_equal_approx(player.damage_reduction, 0.15) and player.max_health == SurvivorPlayer.PROFESSIONS[profession].health + 75, "defense equipment")
		check(player.speed == SurvivorPlayer.PROFESSIONS[profession].speed + 31 and player.stamina_regen == 34, "mobility equipment")
		check(is_equal_approx(player.roll_cooldown, 0.55) and player.roll_distance == 180, "roll equipment")
		match profession:
			0: check(player.extra_targets == 1 and player.reach_bonus == 25, "sword equipment")
			1: check(player.reach_bonus == 50, "spear equipment")
			2: check(player.extra_arrows == 1 and player.reach_bonus == 25, "bow equipment")
		player.health = 50
		player.invulnerability = 0
		player.take_damage(20, Vector2.ZERO)
		check(is_equal_approx(player.health, 33), "actual damage reduction")
		player.stamina = 40
		game._on_enemy_killed(Vector2.ZERO, 10)
		check(is_equal_approx(player.health, 36) and is_equal_approx(player.stamina, 45), "actual kill recovery")
		game.select_shop_category(1)
		check(game.shop_category == 1, "AP category selectable")
		paused = false
		game.queue_free()
		await process_frame
	print("EQUIPMENT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

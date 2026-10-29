extends "res://tests/v21_animation.gd"

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frames(3)
	game.select_profession(0)
	game.start_run()
	clear_targets()
	await frames(2)
	var player := game.player
	movement(Vector2.LEFT)
	await frames(3)
	check(player.visual.facing == Vector2.LEFT and player.visual.leg_facing == Vector2.LEFT, "Whole body faces movement")
	check(player.weapon.display_direction() == Vector2.LEFT, "Weapon follows left movement despite mouse aim")
	movement(Vector2.UP)
	await frames(3)
	check(player.weapon.display_direction() == Vector2.UP, "Weapon follows up movement")
	movement(Vector2.ZERO)
	await frames(2)
	check(player.weapon.display_direction() == Vector2.UP, "Weapon retains direction while idle")
	var enemy := target_at(65)
	var health := enemy.health
	check(player.weapon.attack(Vector2.RIGHT), "Sword starts")
	await frames(2)
	check(player.visual.facing == Vector2.RIGHT and player.visual.leg_facing == Vector2.RIGHT, "Whole body faces attack")
	check(player.weapon.display_direction() == Vector2.RIGHT, "Weapon faces attack direction")
	check(is_equal_approx(player.weapon.swing_duration, 0.3) and player.weapon.cooldown > 0.7, "Base action 300 ms and interval 800 ms")
	movement(Vector2.LEFT)
	var attack_position := player.global_position
	await frames(2)
	check(player.global_position.distance_to(attack_position) < 0.1, "Movement remains locked during sword action")
	check(enemy.health == health, "No damage during windup")
	await frames(12)
	check(enemy.health < health, "Sword hits during sweep")
	var after_hit := enemy.health
	await frames(8)
	check(enemy.health == after_hit, "Sword hits target only once")
	check(player.weapon.swing_time == 0.0 and player.weapon.cooldown > 0.0 and player.movement_multiplier() == 1.0, "Movement resumes while attack remains on cooldown")
	check(player.global_position.x < attack_position.x - 1.0, "Player actually moves before cooldown ends")
	movement(Vector2.ZERO)
	check(not player.weapon.attack(Vector2.RIGHT), "Cannot attack again before cooldown ends")
	enemy.health = health
	player.weapon.cooldown = 0
	player.weapon.attack(Vector2.RIGHT)
	await frames(2)
	enemy.position = player.position + Vector2(300, 0)
	await frames(20)
	check(enemy.health == health, "Target leaving range avoids hit")
	await frames(15)
	enemy.position = player.position + Vector2(65, 0)
	player.weapon.cooldown = 0
	player.weapon.attack(Vector2.RIGHT)
	check(player.try_roll(), "Roll interrupts attack")
	await frames(25)
	check(enemy.health == health, "Interrupted windup causes no damage")
	player.attack_speed_multiplier = 2.0
	player.weapon.cooldown = 0
	await frames(5)
	check(player.weapon.attack(Vector2.RIGHT) and is_equal_approx(player.weapon.swing_duration, 0.15) and is_equal_approx(player.weapon.cooldown, 0.4), "Attack speed scales action and interval")
	print("SWORD RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

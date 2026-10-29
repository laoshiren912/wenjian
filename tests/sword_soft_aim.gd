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
	var weapon := player.weapon
	var first := target_at(65)
	first.position = player.position + Vector2.RIGHT.rotated(deg_to_rad(10.0)) * 65.0
	var assisted: Vector2 = weapon._sword_assist(Vector2.RIGHT)
	check(absf(rad_to_deg(assisted.angle()) - 10.0) < 0.1, "Nearby target within 15 degrees assists")
	first.position = player.position + Vector2.RIGHT.rotated(deg_to_rad(60.0)) * 65.0
	check(weapon._sword_assist(Vector2.RIGHT).is_equal_approx(Vector2.RIGHT), "Target at 60 degrees does not assist")
	first.position = player.position + Vector2.RIGHT * 180.0
	check(weapon._sword_assist(Vector2.RIGHT).is_equal_approx(Vector2.RIGHT), "Out of range target does not assist")
	first.position = player.position + Vector2.RIGHT.rotated(deg_to_rad(10.0)) * 65.0
	var second := target_at(70)
	second.position = player.position + Vector2.RIGHT.rotated(deg_to_rad(10.0)) * 80.0
	var first_health := first.health
	var second_health := second.health
	weapon.attack(Vector2.RIGHT)
	var locked_direction: Vector2 = weapon.swing_direction
	await frames(3)
	check(player._target_marker == null, "Sword assist has no persistent target marker")
	check(first.health == first_health and second.health == second_health, "No hits during windup")
	await frames(20)
	check(first.health < first_health and second.health == second_health, "Thrust hits only the first target")
	var first_after := first.health
	var second_after := second.health
	await frames(5)
	check(first.health == first_after and second.health == second_after, "No repeated or extra damage in one thrust")
	first.health = first_health
	second.health = second_health
	player.extra_targets = 1
	weapon.cooldown = 0
	first.position = player.position + Vector2.RIGHT * 65.0
	second.position = player.position + Vector2.RIGHT * 80.0
	weapon.attack(Vector2.RIGHT)
	await frames(22)
	check(first.health < first_health and second.health < second_health, "Extra target equipment enables a second thrust hit")
	player.extra_targets = 0
	first.health = first_health
	second.queue_free()
	weapon.cooldown = 0
	first.position = player.position + Vector2.RIGHT.rotated(deg_to_rad(10.0)) * 65.0
	weapon.attack(Vector2.RIGHT)
	locked_direction = weapon.swing_direction
	first.position = player.position + Vector2.UP * 250.0
	await frames(15)
	check(weapon.swing_direction.is_equal_approx(locked_direction), "Direction does not track moving target")
	check(first.health == first_health, "Moving out of sweep avoids hit")
	print("SWORD SOFT AIM RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

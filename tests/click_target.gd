extends "res://tests/v21_animation.gd"

func click_at(world_point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = root.get_canvas_transform() * world_point
	game.player._unhandled_input(event)

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
	var enemy := target_at(70)
	var health := enemy.health
	click_at(enemy.global_position + Vector2(0, 12))
	check(player._click_target == enemy, "Click selects enemy within hit area")
	await frames(2)
	check(player.weapon.swing_direction.dot(Vector2.RIGHT) > 0.999, "Attack aims at selected enemy center")
	check(player._target_marker == enemy and player._target_marker_remaining > 0.0, "Successful target attack shows marker")
	check(player._click_target == null, "Selection lasts only one attack attempt")
	enemy.global_position += Vector2(0, 200)
	await frames(20)
	check(enemy.health == health, "Moving away avoids selected attack")
	await frames(25)
	check(player._target_marker == null, "Marker expires without persistent lock")
	player.weapon.cooldown = 0
	var empty := player.global_position + Vector2(0, -120)
	click_at(empty)
	check(player._click_target == null, "Empty click selects no target")
	await frames(2)
	check(player.weapon.swing_direction.dot(Vector2.UP) > 0.999, "Empty click attacks toward click")
	check(player._target_marker == null, "Empty click displays no target marker")
	click_at(enemy.global_position)
	await frames(2)
	check(player._click_target == null and player.weapon.swing_direction.dot(Vector2.UP) > 0.999, "Click during cooldown does not queue target")
	player.weapon.cooldown = 0
	check(player.try_roll(), "Roll starts")
	click_at(enemy.global_position)
	await frames(2)
	check(player._click_target == null and not player._attack_pending, "Click during roll does not queue target")
	print("CLICK TARGET RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

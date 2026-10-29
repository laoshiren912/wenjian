extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)

func frames(count: int = 2) -> void:
	for index in range(count):
		await physics_frame
	await process_frame

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for profession in [0, 1, 2]:
		var game = load("res://scenes/main.tscn").instantiate()
		root.add_child(game)
		await process_frame
		game.select_profession(profession)
		game.start_run()
		for enemy in get_nodes_in_group("enemies"):
			enemy.free()
		game.pending_wave.clear()
		game.remaining = 1
		var player: SurvivorPlayer = game.player
		Input.action_press("move_left")
		await frames()
		check(is_equal_approx(player.velocity.x, -player.speed), "walking speed unchanged")
		var attack := InputEventMouseButton.new()
		attack.button_index = MOUSE_BUTTON_LEFT
		attack.pressed = true
		Input.action_press("attack")
		root.push_input(attack, true)
		await frames()
		var expected: float = player.speed * (0.55 if profession == 2 else 0.8)
		check(is_equal_approx(player.velocity.x, -expected), "attack movement for profession %d" % profession)
		attack = InputEventMouseButton.new()
		attack.button_index = MOUSE_BUTTON_LEFT
		attack.pressed = false
		Input.action_release("attack")
		root.push_input(attack, true)
		await frames()
		if profession == 2:
			check(player.is_bow_recovering() and is_equal_approx(player.velocity.x, -132), "tap release cannot cancel recovery")
			var before_rejected: float = player._bow_shot_remaining
			check(not player.weapon.attack(Vector2.RIGHT) and is_equal_approx(player._bow_shot_remaining, before_rejected), "rejected cooldown attack does not restart recovery")
			await frames(18)
			check(not player.is_bow_recovering() and is_equal_approx(player.velocity.x, -240), "stop firing restores full speed")
			player.position = SurvivorWorld.SPAWN
			player.weapon.cooldown = 0
			var start: Vector2 = player.position
			var before_attacks: int = player.weapon.attack_count
			attack = InputEventMouseButton.new()
			attack.button_index = MOUSE_BUTTON_LEFT
			attack.pressed = true
			Input.action_press("attack")
			root.push_input(attack, true)
			await frames(60)
			check(player.weapon.attack_count >= before_attacks + 3, "continuous attack still fires normally")
			var retreat: float = start.x - player.position.x
			check(retreat > 100.0 and retreat < 175.0, "one second of retreat firing is slower than ordinary melee pursuit")
			attack = InputEventMouseButton.new()
			attack.button_index = MOUSE_BUTTON_LEFT
			attack.pressed = false
			Input.action_release("attack")
			root.push_input(attack, true)
			Input.action_release("move_left")
			await frames(20)
			player.position = SurvivorWorld.SPAWN
			player.weapon.cooldown = 0
			player.weapon.attack(Vector2.RIGHT)
			paused = true
			var remaining: float = player._bow_shot_remaining
			await frames(4)
			check(is_equal_approx(player._bow_shot_remaining, remaining), "pause freezes recovery")
			paused = false
			Input.action_release("move_left")
			player.try_roll()
			await frames()
			check(player.is_rolling() and player.velocity.length() > 400, "roll bypasses shot movement penalty")
			check(player.stamina == 70, "roll cost unchanged")
		else:
			check(is_equal_approx(player.velocity.x, -player.speed), "melee release behavior unchanged")
		Input.action_release("move_left")
		Input.action_release("attack")
		paused = false
		game.queue_free()
		await process_frame
	print("BOW MOVEMENT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

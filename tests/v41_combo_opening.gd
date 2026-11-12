extends SceneTree

var game
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	printerr(("PASS: " if ok else "FAIL: ") + message)

func _initialize() -> void:
	run.call_deferred()

func tick() -> void:
	await physics_frame
	await process_frame

func tap(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = root.get_canvas_transform() * point
	event.global_position = event.position
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)

func run() -> void:
	game = load("res://scenes/main_v41.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.debug_opening(true)
	var player = game.player
	var enemies := get_nodes_in_group("enemies")
	var enemy = enemies[0]
	for i in range(1, enemies.size()):
		enemies[i].free()
	game.scheduler.configure([enemy], 2, 1.65)
	player.position = Vector2(600, 420)
	enemy.position = Vector2(660, 420)
	enemy.home_position = enemy.position
	enemy.alert_encounter(player.global_position)
	# Controlled setup: once direction is locked, place the player behind the
	# attacker as if they had dodged. The attack and subsequent AI stay live.
	for i in range(120):
		await tick()
		if enemy.windup > 0.0:
			player.position = enemy.position + Vector2(48, 0)
			break
	var seen_lunge := false
	for i in range(180):
		await tick()
		if enemy.lunge_time > 0.0:
			seen_lunge = true
		if seen_lunge and enemy.lunge_time <= 0.0:
			break
	check(seen_lunge and enemy.attack_cooldown > 0.0, "real enemy finishes first attack")
	var opening := Time.get_ticks_msec()
	var frame := 0
	var third_hit := -1
	var next_lunge := -1
	var hits: Array[int] = []
	enemy.damaged.connect(func(_point, _amount): hits.append(player.combo.stage))
	tap(enemy.global_position)
	Input.action_press("move_left")
	var second_sent := false
	var third_sent := false
	for i in range(100):
		await tick()
		frame += 1
		if not second_sent and player.combo.attack_count == 1 and player.combo.swing_time <= 0.08:
			tap(enemy.global_position)
			second_sent = true
		if second_sent and not third_sent and player.combo.attack_count == 2 and player.combo.swing_time <= 0.08:
			tap(enemy.global_position)
			third_sent = true
		if third_hit < 0 and 2 in hits:
			third_hit = frame
		if enemy.lunge_time > 0.0 and next_lunge < 0:
			next_lunge = frame
		if third_hit >= 0:
			break
	Input.action_release("move_left")
	check(hits.has(0) and hits.has(1) and hits.has(2), "three real hits in sequence " + str(hits))
	check(third_hit > 0, "third hit observed at %.3f seconds" % (float(third_hit) / 60.0))
	check(third_hit > 0 and (next_lunge < 0 or third_hit < next_lunge), "third hit before next attack damage")
	print("COMBO OPENING: %d/%d, third frame=%d next lunge=%d elapsed wall=%dms attacks=%d stage=%d distance=%.1f hp=%.1f" % [checks - failures, checks, third_hit, next_lunge, Time.get_ticks_msec() - opening, player.combo.attack_count, player.combo.stage, player.global_position.distance_to(enemy.global_position), player.health])
	quit(1 if failures else 0)

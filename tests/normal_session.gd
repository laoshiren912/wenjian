extends SceneTree

# Acceptance driver only: real main scene, normal stats, natural enemy spawns.
# Sends input and chooses earned upgrades. Never grants HP, XP, or invulnerability.
var game: SurvivorGame
var recovering: bool = false
var hits_received: int = 0
var upgrades: int = 0
var weapon_uses: Array[int] = [0, 0]
var previous_attack_count: int = 0
var last_report: int = -1
var mode: String = "combat"
var route: PackedVector2Array = PackedVector2Array()
var route_index: int = 0
var target_cell := Vector2i(-1, -1)
var decisions: int = 0
var patrol: Array[Vector2] = []
var patrol_index: int = 0

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument == "--idle":
			mode = "idle"
		elif argument == "--kite":
			mode = "kite"
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	game.player.hurt.connect(func(): hits_received += 1)
	for point in [Vector2(2080, 352), Vector2(2080, 1568), Vector2(352, 1568), Vector2(352, 352)]:
		var closest: Vector2 = SurvivorWorld.SPAWN
		for cell in game.world.floor_cells:
			var candidate: Vector2 = game.world.cell_center(cell)
			if candidate.distance_to(point) < closest.distance_to(point):
				closest = candidate
		patrol.append(closest)
	print("NORMAL SESSION: mode=%s, map_seed=%d, health=%.0f, invulnerability=%.2f, natural spawns, no stat overrides" % [mode, game.world.random.seed, game.player.health, game.player.invulnerability])
	game.hud.start_requested.emit()
	while game.state != SurvivorGame.State.DEAD and game.state != SurvivorGame.State.WON:
		await physics_frame
		if game.state == SurvivorGame.State.LEVEL_UP:
			_release()
			var choice: int = 2 if game.player.health < game.player.max_health * 0.65 else upgrades % 2
			game.hud.level_ui.choices[choice].pressed.emit()
			upgrades += 1
			print("EARNED UPGRADE: choice=%d level=%d HP=%.0f/%.0f" % [choice + 1, game.player.level, game.player.health, game.player.max_health])
		elif game.state == SurvivorGame.State.PLAYING and mode == "combat":
			_control()
		elif game.state == SurvivorGame.State.PLAYING and mode == "kite":
			if game.player.position.distance_to(patrol[patrol_index]) < 25.0:
				patrol_index = (patrol_index + 1) % patrol.size()
			var movement := _toward(patrol[patrol_index])
			_set_axis("move_left", maxf(0.0, -movement.x))
			_set_axis("move_right", maxf(0.0, movement.x))
			_set_axis("move_up", maxf(0.0, -movement.y))
			_set_axis("move_down", maxf(0.0, movement.y))
		var second: int = int(game.elapsed)
		if second % 10 == 0 and second != last_report:
			last_report = second
			print("NORMAL: t=%ds HP=%.0f/%.0f stamina=%.0f level=%d kills=%d hits=%d position=%s" % [second, game.player.health, game.player.max_health, game.player.stamina, game.player.level, game.kills, hits_received, game.player.position])
	_release()
	print("NORMAL RESULT: %s, seconds=%.2f, HP=%.0f/%.0f, kills=%d, level=%d, earned_upgrades=%d, hits_received=%d, weapon_attacks=%s" % ["WON" if game.state == SurvivorGame.State.WON else "DEAD", game.elapsed, game.player.health, game.player.max_health, game.kills, game.player.level, upgrades, hits_received, weapon_uses])
	paused = false
	quit()

func _release() -> void:
	_set_attack(false)
	for action in ["move_left", "move_right", "move_up", "move_down", "attack"]:
		Input.action_release(action)

func _control() -> void:
	decisions += 1
	var player: SurvivorPlayer = game.player
	if player.weapon.attack_count > previous_attack_count:
		weapon_uses[player.weapon.selected] += player.weapon.attack_count - previous_attack_count
		previous_attack_count = player.weapon.attack_count
	var nearest: SurvivorEnemy
	var nearest_distance: float = INF
	var danger := Vector2.ZERO
	var nearby: int = 0
	for enemy in get_nodes_in_group("enemies"):
		if enemy.dead:
			continue
		var offset: Vector2 = enemy.global_position - player.global_position
		var distance: float = offset.length()
		if distance < nearest_distance:
			nearest = enemy
			nearest_distance = distance
		if enemy.aggro and distance < 150.0:
			danger -= offset.normalized() * (150.0 - distance)
			nearby += 1
	var goal: Vector2 = player.position
	if is_instance_valid(nearest):
		goal = nearest.position
		# Aim via the real viewport transform, including camera smoothing.
		var event := InputEventMouseMotion.new()
		event.position = player.get_global_transform_with_canvas() * player.to_local(nearest.global_position)
		event.global_position = event.position
		root.push_input(event, true)
		var weapon: int = 1 if nearby >= 2 or nearest_distance > 102.0 else 0
		if player.weapon.selected != weapon:
			var key := InputEventKey.new()
			key.keycode = KEY_1 + weapon
			key.pressed = true
			Input.parse_input_event(key)
			var release := InputEventKey.new()
			release.keycode = KEY_1 + weapon
			Input.parse_input_event(release)
		if player.stamina < float(SurvivorWeapon.DATA[weapon].stamina):
			recovering = true
		if player.stamina >= 70.0:
			recovering = false
		var reach: float = float(SurvivorWeapon.DATA[weapon].reach)
		if not recovering and nearest_distance < reach:
			_set_attack(true)
		else:
			_set_attack(false)
	var pickup_distance: float = 250.0
	for pickup in get_nodes_in_group("pickups"):
		var distance: float = player.global_position.distance_to(pickup.global_position)
		if distance < pickup_distance:
			goal = pickup.global_position
			pickup_distance = distance
	var movement := Vector2.ZERO
	if danger.length() > 8.0 and nearest_distance < (115.0 if recovering else 65.0):
		movement = danger.normalized()
	elif pickup_distance < 250.0 or nearest_distance > (160.0 if recovering else 85.0):
		movement = _toward(goal)
	_set_axis("move_left", maxf(0.0, -movement.x))
	_set_axis("move_right", maxf(0.0, movement.x))
	_set_axis("move_up", maxf(0.0, -movement.y))
	_set_axis("move_down", maxf(0.0, movement.y))

func _toward(goal: Vector2) -> Vector2:
	var from_cell: Vector2i = game.world.cell_at(game.player.position)
	var to_cell: Vector2i = game.world.cell_at(goal)
	if from_cell == to_cell:
		return (goal - game.player.position).normalized()
	if route.is_empty() or target_cell != to_cell or route_index >= route.size():
		route = game.world.path_between(game.player.position, goal)
		route_index = 0
		target_cell = to_cell
	while route_index < route.size() and game.player.position.distance_to(route[route_index]) < 12.0:
		route_index += 1
	if route_index < route.size():
		return (route[route_index] - game.player.position).normalized()
	return Vector2.ZERO

func _set_axis(action: String, strength: float) -> void:
	if strength > 0.05:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)

func _set_attack(pressed: bool) -> void:
	if pressed == Input.is_action_pressed("attack"):
		return
	if pressed:
		Input.action_press("attack")
	else:
		Input.action_release("attack")
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = root.get_mouse_position()
	root.push_input(event, true)

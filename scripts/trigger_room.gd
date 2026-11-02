extends "res://scripts/combat_room.gd"

const TRIGGER_CELL := Vector2i(24, 15)
const INITIAL_CELLS: Array[Vector2i] = [Vector2i(18, 14), Vector2i(19, 16)]
const REINFORCEMENT_CELLS: Array[Vector2i] = [Vector2i(14, 12), Vector2i(20, 11), Vector2i(25, 12), Vector2i(13, 17), Vector2i(18, 16), Vector2i(24, 17), Vector2i(26, 14), Vector2i(16, 18), Vector2i(22, 14), Vector2i(22, 18)]
const REINFORCEMENTS := 4
const SAFE_DISTANCE := 100.0
const CLEARANCE := 36.0
var trigger_used := false
var initial_complete := false
var pending_trigger := false

func start_room() -> void:
	for child in world.actors.get_children():
		child.free()
	spawned.clear()
	world.spawn_points.clear()
	player = PLAYER.instantiate()
	player.position = world.cell_center(PLAYER_CELL)
	player.collision_mask = 1 | 4
	world.actors.add_child(player)
	player.enable_dual_attack()
	player.camera.enabled = false
	$Camera2D.make_current()
	feedback.camera = $Camera2D
	player.died.connect(_on_player_died)
	player.damage_received.connect(func(amount: float): feedback.show_damage(player.global_position, amount, true))
	total = 2 + REINFORCEMENTS
	remaining = total
	trigger_used = false
	initial_complete = false
	pending_trigger = false
	world.trigger_center = world.cell_center(TRIGGER_CELL)
	world.trigger_visible = true
	restart_button.hide()
	_spawn_wave(INITIAL_CELLS)

func _spawn_wave(cells: Array[Vector2i]) -> void:
	spawned.clear()
	world.spawn_points.clear()
	for cell in cells:
		var point: Vector2 = world.cell_center(cell)
		world.spawn_points.append(point)
		var enemy := ENEMY.instantiate() as SurvivorEnemy
		enemy.world = world
		enemy.kind = SurvivorEnemy.Kind.HOSTILE
		enemy.dodge_enabled = false
		enemy.collision_mask = 1 | 2 | 4
		enemy.collision_layer = 0
		enemy.emerging = true
		enemy.position = point
		enemy.killed.connect(_on_enemy_killed)
		enemy.damaged.connect(func(position: Vector2, amount: float): feedback.show_damage(position, amount, false))
		world.actors.add_child(enemy)
		enemy.remove_from_group("enemies")
		enemy.set_physics_process(false)
		enemy.visual.set_physics_process(false)
		enemy.hide()
		spawned.append(enemy)
	phase = "warning"
	phase_time = 0.0
	world.spawn_progress = 0.0
	world.queue_redraw()
	_update_status()

func _available_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in REINFORCEMENT_CELLS:
		if world.grid.is_point_solid(cell):
			continue
		var point: Vector2 = world.cell_center(cell)
		if point.distance_to(player.global_position) < SAFE_DISTANCE:
			continue
		var occupied := false
		for other in get_tree().get_nodes_in_group("enemies"):
			if not other.dead and other.global_position.distance_to(point) < SAFE_DISTANCE:
				occupied = true
				break
		for selected in result:
			if world.cell_center(selected).distance_to(point) < SAFE_DISTANCE:
				occupied = true
				break
		if not occupied:
			result.append(cell)
			if result.size() == REINFORCEMENTS:
				break
	return result

func _positions_clear() -> bool:
	for enemy in spawned:
		if enemy.global_position.distance_to(player.global_position) < CLEARANCE:
			return false
		for other in get_tree().get_nodes_in_group("enemies"):
			if not other.dead and enemy.global_position.distance_to(other.global_position) < CLEARANCE:
				return false
	return true

func _physics_process(delta: float) -> void:
	if phase not in ["dead", "cleared"] and not trigger_used and player.global_position.distance_to(world.trigger_center) <= world.TRIGGER_RADIUS:
		pending_trigger = true
	if phase == "rising" and phase_time + delta >= RISE_TIME and not _positions_clear():
		phase_time = RISE_TIME - 0.001
		status.text = "请离开出怪位置"
		return
	var previous_phase: String = phase
	super._physics_process(delta)
	if previous_phase == "rising" and phase == "combat" and not initial_complete:
		initial_complete = true
		_update_status()
	if phase != "combat" or trigger_used:
		return
	if pending_trigger:
		var cells := _available_cells()
		if cells.size() == REINFORCEMENTS:
			trigger_used = true
			pending_trigger = false
			world.trigger_visible = false
			_spawn_wave(cells)
		else:
			status.text = "正在寻找安全出怪位置，请移动"

func _update_status() -> void:
	if phase == "cleared":
		status.text = "房间清理完成"
	elif not trigger_used:
		status.text = "剩余 %d / %d（含待出现 4） ·  走进蓝圈引出敌人" % [remaining, total]
	else:
		status.text = "敌人 %d / %d" % [remaining, total]

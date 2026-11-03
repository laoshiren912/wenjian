extends "res://scripts/combat_room.gd"

const ENTRY_CELL := Vector2i(13, 14)
const ENEMY_KINDS: Array[int] = [SurvivorEnemy.Kind.HOSTILE, SurvivorEnemy.Kind.RANGED, SurvivorEnemy.Kind.HOSTILE, SurvivorEnemy.Kind.HOSTILE, SurvivorEnemy.Kind.RANGED, SurvivorEnemy.Kind.HOSTILE]
const SPAWN_CLEARANCE := 36.0
var encounters: Array[Dictionary] = []
var triggered_count := 0

func _ready() -> void:
	_setup_inputs()
	world.build_corridor()
	_build_ui()
	start_room()

func start_room() -> void:
	for child in world.actors.get_children():
		child.free()
	encounters.clear()
	world.warning_positions.clear()
	world.triggered.assign([false, false, false, false, false, false])
	world.portal_open = false
	triggered_count = 0
	total = ENEMY_KINDS.size()
	remaining = total
	phase = "combat"
	player = _create_player()
	player.position = world.cell_center(ENTRY_CELL)
	player.collision_mask = 1 | 4
	world.actors.add_child(player)
	player.enable_dual_attack()
	player.camera.enabled = false
	$Camera2D.make_current()
	feedback.camera = $Camera2D
	player.died.connect(_on_player_died)
	player.damage_received.connect(func(amount: float): feedback.show_damage(player.global_position, amount, true))
	_set_restart_visible(false)
	world.queue_redraw()
	_update_status()

func _create_player() -> SurvivorPlayer:
	return PLAYER.instantiate()

func _spawn_at_trigger(index: int) -> void:
	world.triggered[index] = true
	triggered_count += 1
	var cell := Vector2i(world.TRIGGER_X[index] + 1, 15 if index % 2 == 0 else 14)
	var point: Vector2 = world.cell_center(cell)
	var enemy := ENEMY.instantiate() as SurvivorEnemy
	enemy.world = world
	enemy.kind = ENEMY_KINDS[index]
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
	encounters.append({"enemy": enemy, "state": "warning", "time": 0.0, "point": point})
	world.warning_positions.append(point)
	world.queue_redraw()
	_update_status()

func _clear_spawn_position(enemy: SurvivorEnemy) -> bool:
	if enemy.global_position.distance_to(player.global_position) < SPAWN_CLEARANCE:
		return false
	for other in get_tree().get_nodes_in_group("enemies"):
		if not other.dead and enemy.global_position.distance_to(other.global_position) < SPAWN_CLEARANCE:
			return false
	return true

func _physics_process(delta: float) -> void:
	if phase != "combat":
		return
	for i in range(world.TRIGGER_X.size()):
		if not world.triggered[i]:
			var center_x: float = world.cell_center(Vector2i(world.TRIGGER_X[i], 14)).x
			if absf(player.global_position.x - center_x) <= 26.0:
				_spawn_at_trigger(i)
	for entry in encounters:
		if entry.state == "active":
			continue
		var enemy: SurvivorEnemy = entry.enemy
		if entry.state == "warning":
			entry.time += delta
			if entry.time >= WARNING_TIME:
				world.warning_positions.erase(entry.point)
				world.queue_redraw()
				entry.state = "rising"
				entry.time = 0.0
				enemy.show()
				enemy.visual.scale = Vector2(1.0, 0.01)
				enemy.visual.position.y = 10.0
		elif entry.state == "rising":
			entry.time = minf(RISE_TIME, float(entry.time) + delta)
			var progress := float(entry.time) / RISE_TIME
			enemy.visual.scale.y = maxf(0.01, progress)
			enemy.visual.position.y = 10.0 * (1.0 - progress)
			if progress >= 1.0 and _clear_spawn_position(enemy):
				enemy.emerging = false
				enemy.visual.set_physics_process(true)
				enemy.collision_layer = 4
				enemy.add_to_group("enemies")
				enemy.set_physics_process(true)
				entry.state = "active"
			elif progress >= 1.0:
				status.text = "请离开出怪位置"
	if world.portal_open and player.global_position.distance_to(world.cell_center(world.PORTAL_CELL)) < 34.0:
		phase = "cleared"
		status.text = "已抵达传送点 · 本次测试完成"
		_set_restart_visible(true)

func _set_restart_visible(visible: bool) -> void:
	restart_button.visible = visible

func _on_enemy_killed(_point: Vector2, _xp: int) -> void:
	remaining -= 1
	if phase == "dead":
		return
	if remaining == 0 and triggered_count == total:
		world.portal_open = true
		world.queue_redraw()
	_update_status()

func _update_status() -> void:
	if world.portal_open:
		status.text = "敌人已清除 · 走到右侧传送点"
	else:
		status.text = "剩余 %d / %d（沿路触发 %d / %d） · 前往右侧" % [remaining, total, triggered_count, total]

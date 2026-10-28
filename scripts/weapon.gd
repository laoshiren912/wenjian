class_name SurvivorWeapon
extends Node2D

const PROJECTILE_SCENE = preload("res://scenes/projectile.tscn")
const DATA: Array[Dictionary] = [
	{"name": "剑", "damage": 52.0, "reach": 90.0, "angle": 100.0, "cooldown": 0.48, "stamina": 0.0, "single_target": true, "role": "高伤单体"},
	{"name": "长矛", "damage": 32.0, "reach": 150.0, "angle": 56.0, "cooldown": 0.78, "stamina": 0.0, "single_target": false, "role": "群体穿刺"},
	{"name": "弓箭", "damage": 21.0, "reach": 640.0, "angle": 0.0, "cooldown": 0.32, "stamina": 0.0, "single_target": true, "role": "远程单体"},
]

var selected: int = 0
var cooldown: float = 0.0
var swing_time: float = 0.0
var swing_direction: Vector2 = Vector2.RIGHT
var swing_weapon: int = 0
var attack_count: int = 0

func _physics_process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	swing_time = maxf(0.0, swing_time - delta)
	queue_redraw()

func select_weapon(index: int) -> void:
	if index < 0 or index >= DATA.size():
		return
	selected = index
	queue_redraw()

func attack(direction: Vector2) -> bool:
	var player = get_parent()
	var data: Dictionary = DATA[selected]
	# Normal attacks use cooldown only; keep stamina and its recovery for future actions.
	if cooldown > 0.0:
		return false
	cooldown = float(data.cooldown) / player.attack_speed_multiplier
	swing_direction = direction.normalized()
	swing_weapon = selected
	swing_time = 0.18
	attack_count += 1
	var damage: float = float(data.damage) * player.damage_multiplier
	if selected == 2:
		var projectile = PROJECTILE_SCENE.instantiate()
		projectile.direction = swing_direction
		projectile.damage = damage
		projectile.max_distance = float(data.reach)
		player.get_parent().add_child(projectile)
		projectile.global_position = player.global_position + swing_direction * 23.0
		queue_redraw()
		return true
	var targets: Array[Node2D] = []
	var nearest: Node2D
	var nearest_distance: float = INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.dead:
			continue
		var offset: Vector2 = enemy.global_position - player.global_position
		if offset.length() > float(data.reach) + 12.0:
			continue
		if absf(direction.angle_to(offset)) > deg_to_rad(float(data.angle) * 0.5):
			continue
		var query := PhysicsRayQueryParameters2D.create(player.global_position, enemy.global_position, 1)
		if not get_world_2d().direct_space_state.intersect_ray(query).is_empty():
			continue
		if bool(data.single_target):
			if offset.length_squared() < nearest_distance:
				nearest = enemy
				nearest_distance = offset.length_squared()
		else:
			targets.append(enemy)
	if is_instance_valid(nearest):
		targets.append(nearest)
	for enemy in targets:
		enemy.take_damage(damage, direction * 155.0)
	queue_redraw()
	return true

func _draw() -> void:
	var player = get_parent()
	var aim: Vector2 = player.aim_direction
	var color := Color("e9cc83")
	if selected == 1:
		color = Color("b0d8ed")
	if selected == 2:
		var side: Vector2 = aim.orthogonal()
		var bow := PackedVector2Array([aim * 17.0 - side * 17.0, aim * 27.0 - side * 10.0, aim * 31.0, aim * 27.0 + side * 10.0, aim * 17.0 + side * 17.0])
		draw_polyline(bow, Color("d5ad70"), 3.0, true)
		draw_line(bow[0], bow[4], Color("eee4ca"), 1.0, true)
	else:
		draw_line(aim * 13.0, aim * (40.0 if selected == 1 else 28.0), color, 4.0, true)
	if swing_time <= 0.0 or swing_weapon == 2:
		return
	var data: Dictionary = DATA[swing_weapon]
	var fade: float = swing_time / 0.18
	var attack_color := Color(0.9, 0.82, 0.5, fade * 0.42)
	if swing_weapon == 1:
		attack_color = Color(0.6, 0.85, 1.0, fade * 0.35)
	var points := PackedVector2Array([Vector2.ZERO])
	var half: float = deg_to_rad(float(data.angle) * 0.5)
	for i in range(19):
		var angle: float = swing_direction.angle() - half + 2.0 * half * float(i) / 18.0
		points.append(Vector2.from_angle(angle) * float(data.reach))
	draw_colored_polygon(points, attack_color)
	draw_polyline(points, Color(1.0, 0.9, 0.65, fade), 2.0, true)

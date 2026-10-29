class_name SurvivorWeapon
extends Node2D

signal attack_started(index: int, direction: Vector2)
signal selection_changed(index: int)

const PROJECTILE_SCENE = preload("res://scenes/projectile.tscn")
const DATA: Array[Dictionary] = [
	{"name": "剑", "damage": 52.0, "reach": 90.0, "angle": 100.0, "cooldown": 0.48, "stamina": 0.0, "single_target": true, "role": "高伤单体"},
	{"name": "长矛", "damage": 32.0, "reach": 150.0, "angle": 56.0, "cooldown": 0.78, "stamina": 0.0, "single_target": false, "role": "群体穿刺"},
	{"name": "弓箭", "damage": 21.0, "reach": 640.0, "angle": 0.0, "cooldown": 0.32, "stamina": 0.0, "single_target": true, "role": "远程单体"},
]

var _selected: int = 0
var selected: int:
	get:
		return _selected
	set(value):
		select_weapon(value)
var _locked: bool = false
var locked: bool:
	get:
		return _locked
var cooldown: float = 0.0
var swing_time: float = 0.0
var swing_duration: float = 0.18
var swing_direction: Vector2 = Vector2.RIGHT
var swing_weapon: int = 0
var attack_count: int = 0

func _physics_process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	swing_time = maxf(0.0, swing_time - delta)
	queue_redraw()

func select_weapon(index: int) -> void:
	if _locked or index < 0 or index >= DATA.size():
		return
	if _selected != index:
		_selected = index
		swing_time = 0.0
		selection_changed.emit(index)
	queue_redraw()

func lock_to(index: int) -> bool:
	if _locked or index < 0 or index >= DATA.size():
		return false
	select_weapon(index)
	_locked = true
	return true

func attack(direction: Vector2) -> bool:
	var player = get_parent()
	if player.is_rolling():
		return false
	var data: Dictionary = DATA[selected]
	# Normal attacks use cooldown only; keep stamina and its recovery for future actions.
	if cooldown > 0.0:
		return false
	cooldown = float(data.cooldown) / player.attack_speed_multiplier
	swing_direction = direction.normalized()
	swing_weapon = selected
	swing_duration = minf(0.18, cooldown)
	swing_time = swing_duration
	attack_count += 1
	attack_started.emit(selected, swing_direction)
	var damage: float = float(data.damage) * player.damage_multiplier
	if selected == 2:
		for arrow in range(1 + player.extra_arrows):
			var projectile = PROJECTILE_SCENE.instantiate()
			projectile.direction = swing_direction.rotated((float(arrow) - player.extra_arrows * 0.5) * 0.15)
			projectile.damage = damage
			projectile.speed += player.projectile_speed_bonus
			projectile.max_distance = float(data.reach) + player.reach_bonus
			player.get_parent().add_child(projectile)
			projectile.global_position = player.global_position + projectile.direction * 23.0
		queue_redraw()
		return true
	var targets: Array[Node2D] = []
	var nearest: Node2D
	var nearest_distance: float = INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.dead:
			continue
		var offset: Vector2 = enemy.global_position - player.global_position
		if offset.length() > float(data.reach) + player.reach_bonus + 12.0:
			continue
		if absf(direction.angle_to(offset)) > deg_to_rad((float(data.angle) + player.angle_bonus) * 0.5):
			continue
		var query := PhysicsRayQueryParameters2D.create(player.global_position, enemy.global_position, 1)
		if not get_world_2d().direct_space_state.intersect_ray(query).is_empty():
			continue
		if bool(data.single_target) and player.extra_targets == 0:
			if offset.length_squared() < nearest_distance:
				nearest = enemy
				nearest_distance = offset.length_squared()
		else:
			targets.append(enemy)
	if is_instance_valid(nearest):
		targets.append(nearest)
	if bool(data.single_target) and player.extra_targets > 0:
		targets.sort_custom(func(a, b): return a.global_position.distance_squared_to(player.global_position) < b.global_position.distance_squared_to(player.global_position))
		targets.resize(mini(targets.size(), 1 + player.extra_targets))
	for enemy in targets:
		enemy.take_damage(damage, direction * 155.0)
	queue_redraw()
	return true

func _draw() -> void:
	var player = get_parent()
	var aim: Vector2 = player.aim_direction
	var active: bool = swing_time > 0.0 and swing_weapon == selected
	var progress: float = 1.0 - swing_time / swing_duration if active else 1.0
	if active:
		aim = swing_direction
	var color := Color("e9cc83")
	if selected == 1:
		color = Color("b0d8ed")
	if selected == 2:
		var side: Vector2 = aim.orthogonal()
		var recoil: Vector2 = -aim * (1.0 - progress) * 5.0
		var bow := PackedVector2Array([aim * 17.0 - side * 17.0 + recoil, aim * 27.0 - side * 10.0 + recoil, aim * 31.0 + recoil, aim * 27.0 + side * 10.0 + recoil, aim * 17.0 + side * 17.0 + recoil])
		draw_polyline(bow, Color("d5ad70"), 3.0, true)
		draw_line(bow[0], bow[4], Color("eee4ca"), 1.0, true)
	else:
		var reach: float = lerpf(float(DATA[selected].reach) + player.reach_bonus, 40.0 if selected == 1 else 28.0, progress)
		var blade: Vector2 = aim.rotated(progress * deg_to_rad(50.0)) if selected == 0 and active else aim
		draw_line(blade * 13.0, blade * reach, color, 4.0, true)
		if selected == 1:
			draw_colored_polygon(PackedVector2Array([blade * (reach + 4.0), blade * (reach - 6.0) + blade.orthogonal() * 4.0, blade * (reach - 6.0) - blade.orthogonal() * 4.0]), color)
	if not active or swing_weapon == 2:
		return
	var data: Dictionary = DATA[swing_weapon]
	var fade: float = swing_time / swing_duration
	var attack_color := Color(0.9, 0.82, 0.5, fade * 0.42)
	if swing_weapon == 1:
		attack_color = Color(0.6, 0.85, 1.0, fade * 0.35)
	var points := PackedVector2Array([Vector2.ZERO])
	var half: float = deg_to_rad((float(data.angle) + player.angle_bonus) * 0.5)
	for i in range(19):
		var angle: float = swing_direction.angle() - half + 2.0 * half * float(i) / 18.0
		points.append(Vector2.from_angle(angle) * (float(data.reach) + player.reach_bonus))
	draw_colored_polygon(points, attack_color)
	draw_polyline(points, Color(1.0, 0.9, 0.65, fade), 2.0, true)

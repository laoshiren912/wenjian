extends Node2D

const SPEED := 680.0
const CONFIG = preload("res://scripts/v41_config.gd")

var owner_actor: SurvivorPlayer
var direction := Vector2.RIGHT
var damage := 18.0
var rank := 0
var empowered := false
var max_distance := 310.0
var hit_radius := 20.0
var breaks_guard := false
var jade_trail := false
var homing := false
var target: SurvivorEnemy
var terrain_mask := 1
var traveled := 0.0
var hit_ids := {}
var trail: Array[Vector2] = []
var dying := false
var fade := 1.0

func _ready() -> void:
	z_index = 4
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	trail.append(global_position)

func _physics_process(delta: float) -> void:
	if dying:
		fade -= delta * 7.5
		if fade <= 0.0:
			queue_free()
		queue_redraw()
		return
	if not is_instance_valid(owner_actor) or owner_actor.dead:
		queue_free()
		return
	if homing:
		if not is_instance_valid(target) or target.dead:
			var candidates: Array[SurvivorEnemy] = owner_actor.card_targets(global_position, 240.0)
			target = candidates.front() if not candidates.is_empty() else null
		if is_instance_valid(target):
			var aim := global_position.direction_to(target.global_position)
			direction = direction.rotated(clampf(direction.angle_to(aim), -18.0 * delta, 18.0 * delta))
	var step := minf(SPEED * delta, max_distance - traveled)
	var from := global_position
	var to := from + direction * step
	var ray := PhysicsRayQueryParameters2D.create(from, to, terrain_mask)
	var wall := get_world_2d().direct_space_state.intersect_ray(ray)
	if not wall.is_empty():
		to = wall.position
		dying = true
	global_position = to
	traveled += from.distance_to(to)
	trail.append(global_position)
	if trail.size() > 7:
		trail.remove_at(0)
	_check_hits(from, to)
	if traveled >= max_distance - 0.5:
		dying = true
	queue_redraw()

func _check_hits(from: Vector2, to: Vector2) -> void:
	for candidate in get_tree().get_nodes_in_group("enemies"):
		var enemy := candidate as SurvivorEnemy
		if enemy == null or enemy.dead or enemy.emerging or enemy.is_queued_for_deletion():
			continue
		if hit_ids.has(enemy.get_instance_id()):
			continue
		var point := enemy.global_position
		var nearest := Geometry2D.get_closest_point_to_segment(point, from, to)
		if (homing and enemy != target) or point.distance_squared_to(nearest) > hit_radius * hit_radius or not owner_actor.clear_line(nearest, point):
			continue
		hit_ids[enemy.get_instance_id()] = true
		var rear: bool = owner_actor.is_rear_hit(enemy, direction)
		var broke := false
		if breaks_guard and enemy.is_guarding_stance():
			broke = enemy.break_guard_stance(CONFIG.HEAVY_BASE_BREAK, CONFIG.BREAK_STUN)
		enemy.take_damage(damage, direction * 65.0, breaks_guard, false)
		if broke:
			owner_actor.report_guard_break(enemy, 2)
		if rear and enemy.dead:
			owner_actor.refresh_dash_from_card()
		if homing:
			dying = true
			break

func _draw() -> void:
	var col_main := Color("8be6ff") if rank == 0 else (Color("56f0ea") if rank == 1 else Color("44d2ff"))
	if empowered:
		col_main = col_main.lerp(Color("ffe07d"), 0.28)
	if jade_trail:
		col_main = Color("52e6bb")
	var col_core := Color("f8ffff")
	var a := clampf(fade, 0.0, 1.0)
	# 青白像素流光拖尾
	for i in range(1, trail.size()):
		var t := float(i) / float(trail.size())
		var p0 := to_local(trail[i - 1]).round()
		var p1 := to_local(trail[i]).round()
		draw_line(p0, p1, Color(col_main, t * 0.68 * a), (10.0 if jade_trail else 5.5 if empowered else 4.2) * t, false)
		draw_line(p0, p1, Color(col_core, t * 0.72 * a), 1.8 * t, false)
	# 凌厉像素飞剑尖锋
	var side := direction.orthogonal()
	var blade_scale := 0.62 if homing else 1.45 if empowered or jade_trail else 1.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * blade_scale)
	var tip := direction * (18.0 if empowered else 15.0)
	var tail := -direction * (16.0 if empowered else 14.0)
	var wing_l := -direction * 4.0 + side * (7.5 if empowered else 6.0)
	var wing_r := -direction * 4.0 - side * (7.5 if empowered else 6.0)
	draw_colored_polygon(PackedVector2Array([tip, wing_l, tail, wing_r]), Color(col_main, 0.90 * a))
	draw_line((tail * 0.7).round(), tip.round(), Color(col_core, 0.96 * a), 2.5, false)
	draw_rect(Rect2((tip - Vector2(1.5, 1.5)).round(), Vector2(3, 3)), Color(col_core, a))

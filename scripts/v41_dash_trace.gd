extends Node2D

const CONFIG = preload("res://scripts/v41_config.gd")
const COLORS := [Color("e7f4ff"), Color("58dff8"), Color("a786ff")]
const BURST_LIFE := 0.20

var owner_actor: SurvivorPlayer
var rank := 0
var aim := Vector2.RIGHT
var start := Vector2.ZERO
var tip := Vector2.ZERO
var damage := 0.0
var mark_damage := 0.0
var terrain_mask := 1
var direct_hits := {}
var mark_hits := {}
var marks: Array[Dictionary] = []
var ghosts: Array[Dictionary] = []
var sealed := false
var age := 0.0
var next_mark := 0

func extend_to(point: Vector2, pose: Dictionary) -> void:
	if tip.distance_squared_to(point) < 0.01:
		return
	if rank > 0 and not pose.is_empty():
		if ghosts.is_empty() or tip.distance_to(ghosts.back().point) >= 26.0:
			ghosts.append({"point": tip, "pose": pose})
	var from := tip
	tip = point
	var first_contact := direct_hits.is_empty()
	var contact := _hit_strip(from, tip, CONFIG.DASH_WIDTH[rank], damage, direct_hits)
	if contact.is_finite() and first_contact:
		owner_actor.sword_cue.emit("dash_hit", contact)
	queue_redraw()

func seal() -> void:
	sealed = true
	var distance := start.distance_to(tip)
	if rank == 0 or distance < 8.0:
		return
	var count := mini(3 if rank == 2 else 1, maxi(1, int(distance / 32.0)))
	for i in range(count):
		marks.append({
			"from": start.lerp(tip, float(i) / count),
			"to": start.lerp(tip, float(i + 1) / count),
			"at": CONFIG.DASH_MARK_DELAY + i * CONFIG.DASH_MARK_INTERVAL,
		})

func _hit_strip(from: Vector2, to: Vector2, width: float, amount: float, hits: Dictionary) -> Vector2:
	var contact := Vector2.INF
	for candidate in get_tree().get_nodes_in_group("enemies"):
		var enemy := candidate as SurvivorEnemy
		if enemy == null or enemy.dead or enemy.emerging or enemy.is_queued_for_deletion() or hits.has(enemy.get_instance_id()):
			continue
		var point := enemy.global_position
		var nearest := Geometry2D.get_closest_point_to_segment(point, from, to)
		if point.distance_squared_to(nearest) > width * width:
			continue
		if not nearest.is_equal_approx(point):
			var ray := PhysicsRayQueryParameters2D.create(nearest, point, terrain_mask)
			if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
				continue
		hits[enemy.get_instance_id()] = true
		enemy.take_damage(amount, aim * 85.0, false, false)
		contact = point
	return contact

func _physics_process(delta: float) -> void:
	if not is_instance_valid(owner_actor) or owner_actor.dead:
		queue_free()
		return
	if not sealed:
		return
	age += delta
	while next_mark < marks.size() and age >= float(marks[next_mark].at):
		var mark := marks[next_mark]
		var contact := _hit_strip(mark.from, mark.to, CONFIG.DASH_MARK_WIDTH[rank], mark_damage, mark_hits)
		owner_actor.sword_cue.emit("mark_hit" if contact.is_finite() else "mark", contact if contact.is_finite() else mark.to)
		next_mark += 1
	var life := 0.19 if marks.is_empty() else float(marks.back().at) + BURST_LIFE
	if age >= life:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var color: Color = COLORS[rank]
	var fade := clampf(1.0 - age / 0.19, 0.0, 1.0)
	for ghost in ghosts:
		var pose: Dictionary = ghost.pose
		var destination: Rect2 = pose.destination
		destination.position += to_local(ghost.point)
		draw_texture_rect_region(pose.sheet, destination, pose.source, Color(color, fade * (0.24 if rank == 1 else 0.34)))
	if not start.is_equal_approx(tip) and fade > 0.0:
		var from := to_local(start)
		var to := to_local(tip)
		_lance(from, to, 4.0 + rank * 3.7, color, fade)
		_lance(from, to + Vector2.UP * (7.0 + rank * 3.0), 2.0 + rank * 2.0, color.lightened(0.35), fade * 0.8)
		if rank == 2:
			_lance(from + aim.orthogonal() * 13.0, to, 3.0, color, fade * 0.65)
			_lance(from - aim.orthogonal() * 13.0, to, 3.0, color, fade * 0.65)
	for mark in marks:
		var burst := age - float(mark.at)
		if burst >= BURST_LIFE:
			continue
		var from := to_local(mark.from)
		var to := to_local(mark.to)
		var width: float = CONFIG.DASH_MARK_WIDTH[rank]
		var hot := 1.0 - maxf(burst, 0.0) / BURST_LIFE
		if burst < 0.0:
			_lance(from + Vector2.UP * 3.0, to + Vector2.UP * 3.0, 1.0, color, 0.43)
			continue
		_lance(from, to, lerpf(3.0, width * 0.57, hot), color, hot)
		if rank == 2:
			var flank := aim.orthogonal() * width * 0.66
			_lance(from.lerp(to, 0.17) + flank, from.lerp(to, 0.86) - flank, 2.0 + 5.0 * hot, color, hot * 0.78)
			_lance(from.lerp(to, 0.11) - flank, from.lerp(to, 0.80) + flank, 2.0, color, hot * 0.73)
		_draw_breaking_mark(from, to, width, hot, color)
		for i in range(6):
			var side := -1.0 if i % 2 == 0 else 1.0
			var point := from.lerp(to, (i + 0.5) / 6.0) + aim.orthogonal() * side * width * (1.0 - hot)
			draw_line(point - aim * 5.0, point + aim * (4.0 + hot * 12.0), Color(color, hot), 2.0, true)

func _draw_breaking_mark(from: Vector2, to: Vector2, width: float, hot: float, color: Color) -> void:
	var side := aim.orthogonal()
	var spread := width * (0.34 + 0.38 * (1.0 - hot))
	# Lift the fractured blade edges above the ground band as the cut detonates.
	var lift := Vector2.UP * (7.0 + (16.0 if rank == 2 else 6.0) * sqrt(hot))
	for sign_value in [-1.0, 1.0]:
		var crest: Vector2 = from.lerp(to, 0.64) + side * sign_value * spread + lift
		var leading: Vector2 = from.lerp(to, 0.89) + side * sign_value * spread * 0.42
		var heel: Vector2 = from.lerp(to, 0.23) - side * sign_value * spread * 0.38
		var edges := PackedVector2Array([heel, crest, leading])
		if absf((crest - heel).cross(leading - heel)) > 0.1:
			draw_colored_polygon(edges, Color(color, 0.43 * hot))
		draw_polyline(edges, Color(color.lightened(0.68), hot * 0.9), 2.0 + hot * 2.0, true)

func _lance(from: Vector2, to: Vector2, width: float, color: Color, alpha: float) -> void:
	if from.is_equal_approx(to):
		return
	var side := (to - from).normalized().orthogonal() * width
	var center := from.lerp(to, 0.76)
	draw_colored_polygon(PackedVector2Array([from, center + side, to, center - side]), Color(color, alpha * 0.72))
	draw_line(from, to, Color(Color.WHITE.lerp(color, 0.24), alpha * 0.91), maxf(1.0, width * 0.32), true)

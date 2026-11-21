extends Node2D

const CONFIG = preload("res://scripts/v41_config.gd")
const STRIKE = preload("res://assets/characters/Swordsman/v41-strike-pose.png")
const BLADE_SOURCE := Rect2(156 + 84, 180 * 2 + 116, 52, 25)
const BLADE_PIVOT := Vector2(1, 2)
const BLADE_SCALE := 0.76
const BLADE_ANGLE := 0.3842 # Angle of the existing right-facing blade pixels.
const BLADE_CENTER_FROM_HILT := 11.0
const CATCH_TIME := 0.075
const COLORS := [Color("e9f3ff"), Color("67def3"), Color("b59bff")]
enum Flight { OUTBOUND, SPIN, RETURN, CATCH }

var actor: SurvivorPlayer
var rank := 0
var aim := Vector2.RIGHT
var power := 1.0
var opening_bonus := 1.0
var terrain_mask := 1
var flight := Flight.OUTBOUND
var angle := 0.0
var traveled := 0.0
var left := 0.0
var age := 0.0
var outbound_hits := {}
var spin_hits := {}
var return_hits := {}
var launch_point := Vector2.ZERO
var launch_grip := Vector2.ZERO
var catch_start := Vector2.ZERO
var catch_angle := 0.0
var route := PackedVector2Array()
var route_timer := 0.0
var probe := PhysicsShapeQueryParameters2D.new()
var blade_clearance := CircleShape2D.new()

func _ready() -> void:
	z_index = 4
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	global_position = actor.global_position
	launch_point = global_position
	launch_grip = actor.visual.throw_hand(aim)
	angle = aim.angle()
	blade_clearance.radius = 13.0
	probe.shape = blade_clearance
	probe.collision_mask = terrain_mask
	probe.margin = 0.1

func _physics_process(delta: float) -> void:
	if not is_instance_valid(actor) or actor.dead:
		queue_free()
		return
	age += delta
	if flight != Flight.CATCH:
		angle = wrapf(angle + delta * TAU * (5.2 + 0.6 * rank), -PI, PI)
	match flight:
		Flight.OUTBOUND:
			_outbound(delta)
		Flight.SPIN:
			_contact(global_position, global_position, CONFIG.THROW_RADIUS[rank], CONFIG.THROW_SPIN_DAMAGE[rank], spin_hits, aim)
			left -= delta
			if left <= 0.0:
				_return_now()
		Flight.RETURN:
			_recall(delta)
		Flight.CATCH:
			left -= delta
			if left <= 0.0:
				actor.finish_throw(self)
				queue_free()
	queue_redraw()

func _motion_fraction(from: Vector2, motion: Vector2) -> float:
	if motion.length_squared() < 0.001:
		return 1.0
	probe.transform = Transform2D(0.0, from)
	probe.motion = motion
	return get_world_2d().direct_space_state.cast_motion(probe)[0]

func _outbound(delta: float) -> void:
	var remaining: float = CONFIG.THROW_DISTANCE[rank] - traveled
	var length := minf(remaining, CONFIG.THROW_OUT_SPEED * delta)
	var from := global_position
	var fraction := _motion_fraction(from, aim * length)
	var distance := length * fraction
	if fraction < 1.0:
		distance = maxf(0.0, distance - 0.45)
	global_position += aim * distance
	traveled += distance
	if distance > 0.001:
		_contact(from, global_position, 18.0, CONFIG.THROW_OUT_DAMAGE[rank] * opening_bonus, outbound_hits, aim)
	if fraction < 1.0:
		_return_now()
	elif traveled >= CONFIG.THROW_DISTANCE[rank] - 0.01:
		flight = Flight.SPIN
		left = CONFIG.THROW_SPIN_TIME[rank]
		actor.sword_cue.emit("throw_spin", global_position)

func _return_now() -> void:
	flight = Flight.RETURN
	blade_clearance.radius = 7.0

func _return_target(delta: float) -> Vector2:
	var from := global_position
	if _motion_fraction(from, actor.global_position - from) >= 0.9999:
		return actor.global_position
	# The player can move behind a rock while the sword is airborne. Use the
	# room's existing walkable grid until a direct line to the player reopens.
	route_timer -= delta
	if route_timer <= 0.0:
		route = actor.get_parent().get_parent().path_between(from, actor.global_position)
		route_timer = 0.10
	for i in range(route.size() - 1, -1, -1):
		var offset := route[i] - from
		if offset.length_squared() > 4.0 and _motion_fraction(from, offset) >= 0.9999:
			return route[i]
	# The outbound corridor remains a safe retreat when a grid cell is unavailable.
	if _motion_fraction(from, launch_point - from) >= 0.9999:
		return launch_point
	return from

func _recall(delta: float) -> void:
	var from := global_position
	var offset := _return_target(delta) - from
	var step := offset.limit_length(CONFIG.THROW_RETURN_SPEED * delta)
	global_position += step * _motion_fraction(from, step)
	if from.distance_squared_to(global_position) > 0.001:
		_contact(from, global_position, 18.0, CONFIG.THROW_RETURN_DAMAGE[rank], return_hits, step.normalized())
	if global_position.distance_to(actor.global_position) <= 9.0:
		flight = Flight.CATCH
		left = CATCH_TIME
		catch_start = global_position
		catch_angle = angle
		actor.sword_cue.emit("throw_catch", global_position)

func _contact(from: Vector2, to: Vector2, radius: float, amount: float, hits: Dictionary, push: Vector2) -> void:
	var first := hits.is_empty()
	var contact := Vector2.INF
	for candidate in get_tree().get_nodes_in_group("enemies"):
		var enemy := candidate as SurvivorEnemy
		if enemy == null or enemy.dead or enemy.emerging or enemy.is_queued_for_deletion() or hits.has(enemy.get_instance_id()):
			continue
		var point := enemy.global_position
		var nearest := from if from.is_equal_approx(to) else Geometry2D.get_closest_point_to_segment(point, from, to)
		if point.distance_squared_to(nearest) > radius * radius:
			continue
		if not point.is_equal_approx(nearest):
			var ray := PhysicsRayQueryParameters2D.create(nearest, point, terrain_mask)
			if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
				continue
		hits[enemy.get_instance_id()] = true
		var direction := nearest.direction_to(point) if flight == Flight.SPIN and not nearest.is_equal_approx(point) else push
		enemy.take_damage(amount * power, direction * 56.0, false, false)
		contact = point
	if first and contact.is_finite():
		actor.sword_cue.emit("throw_hit", contact)

func _draw() -> void:
	if not is_instance_valid(actor):
		return
	var center := Vector2.ZERO
	var blade_angle := angle
	var strength := smoothstep(0.0, 0.075, age)
	var tint: Color = COLORS[rank]
	if flight == Flight.CATCH:
		var caught := smoothstep(0.0, 1.0, 1.0 - left / CATCH_TIME)
		var grip: Vector2 = actor.global_position + actor.visual.throw_hand(aim)
		var settled_angle: float = actor.visual.throw_blade_angle(aim)
		blade_angle = lerp_angle(catch_angle, settled_angle, caught)
		center = to_local(catch_start.lerp(grip + Vector2.from_angle(blade_angle) * BLADE_CENTER_FROM_HILT, caught))
		strength *= 1.0 - caught
	elif flight == Flight.OUTBOUND:
		center = (launch_grip + aim * BLADE_CENTER_FROM_HILT) * (1.0 - strength)
	var radius: float = CONFIG.THROW_RADIUS[rank] if flight == Flight.SPIN else 21.0 + rank * 3.0
	_draw_crescent(center, blade_angle, radius, tint, strength)
	if rank > 0 and flight == Flight.SPIN:
		_draw_crescent(center, blade_angle + PI, radius - 6.0, tint.lightened(0.3), strength * 0.64)
	var hilt := center - Vector2.from_angle(blade_angle) * BLADE_CENTER_FROM_HILT
	draw_set_transform(hilt, blade_angle)
	# A dark edge below the actual blade pixels keeps the steel readable over impact flashes.
	draw_line(Vector2(1.0, 0.0), Vector2(35.0, 0.0), Color("292438"), 4.8, true)
	draw_rect(Rect2(-8.0, -1.5, 8.0, 3.0), Color("483345"))
	draw_rect(Rect2(-8.5, -2.3, 2.2, 4.6), Color("deb467"))
	draw_rect(Rect2(-1.5, -4.9, 2.8, 9.8), Color("d89a45"))
	draw_line(Vector2(-1.1, -3.7), Vector2(-1.1, 1.8), Color("ffdc91"), 1.3)
	draw_set_transform(hilt, blade_angle - BLADE_ANGLE)
	draw_texture_rect_region(STRIKE, Rect2(-BLADE_PIVOT * BLADE_SCALE, BLADE_SOURCE.size * BLADE_SCALE), BLADE_SOURCE)
	draw_set_transform(Vector2.ZERO)

func _draw_crescent(center: Vector2, heading: float, radius: float, tint: Color, strength: float) -> void:
	if strength < 0.01:
		return
	for i in range(16):
		var t := i / 16.0
		var next := (i + 1) / 16.0
		var from := Vector2.from_angle(heading - lerpf(2.2, 0.0, t))
		var to := Vector2.from_angle(heading - lerpf(2.2, 0.0, next))
		var bulge := sin(t * PI)
		var next_bulge := sin(next * PI)
		var outer := radius * lerpf(0.57, 1.0, bulge)
		var outer_next := radius * lerpf(0.57, 1.0, next_bulge)
		var inner := outer - 1.0 - bulge * (6.0 + rank * 2.0)
		var inner_next := outer_next - 1.0 - next_bulge * (6.0 + rank * 2.0)
		draw_colored_polygon(PackedVector2Array([center + from * outer, center + to * outer_next,
			center + to * inner_next, center + from * inner]), Color(tint, strength * t * 0.67))
		draw_line(center + from * outer, center + to * outer_next, Color(tint.lightened(0.45), strength * t * 0.82), 1.7, true)

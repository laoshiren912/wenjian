extends Node2D

const CONFIG = preload("res://scripts/v41_config.gd")
const STRIKE = preload("res://assets/characters/Swordsman/v41-strike-pose.png")
const WHEEL_SHADER = preload("res://assets/shaders/v41_spin_wheel.gdshader")
const SEAL_SHADER = preload("res://assets/shaders/v41_bagua_seal.gdshader")
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
var target_distance := -1.0
var max_travel := 156.0
var power := 1.0
var opening_bonus := 1.0
var terrain_mask := 1
var flight := Flight.OUTBOUND
var angle := 0.0
var traveled := 0.0
var left := 0.0
var age := 0.0
var spin_tick_timer := 0.0
var spin_ticks_left := 0
var spin_tick_interval := 0.10
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
var flight_trail: Array[Vector2] = []
var wheel_sprite: Sprite2D
var wheel_material: ShaderMaterial
var seal_sprite: Sprite2D
var seal_material: ShaderMaterial
var _unit_tex: ImageTexture
var spin_seal_age := 0.0

func _ready() -> void:
	z_index = 4
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	global_position = actor.global_position
	launch_point = global_position
	launch_grip = actor.visual.throw_hand(aim)
	angle = aim.angle()
	var cap_dist: float = float(CONFIG.THROW_DISTANCE[clampi(rank, 0, 2)])
	max_travel = clampf(target_distance, CONFIG.THROW_MIN_DISTANCE, cap_dist) if target_distance > 0.0 else cap_dist
	blade_clearance.radius = 13.0
	probe.shape = blade_clearance
	probe.collision_mask = terrain_mask
	probe.margin = 0.1
	flight_trail.append(global_position)
	_setup_wheel_vfx()

func _setup_wheel_vfx() -> void:
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, Color.WHITE)
	_unit_tex = ImageTexture.create_from_image(img)

	wheel_material = ShaderMaterial.new()
	wheel_material.shader = WHEEL_SHADER
	wheel_sprite = Sprite2D.new()
	wheel_sprite.name = "SpinWheelVfx"
	wheel_sprite.texture = _unit_tex
	wheel_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	wheel_sprite.material = wheel_material
	wheel_sprite.z_index = -1
	add_child(wheel_sprite)

	seal_material = ShaderMaterial.new()
	seal_material.shader = SEAL_SHADER
	seal_material.set_shader_parameter("effect_mode", 0)
	seal_material.set_shader_parameter("pixel_grid", 56.0)
	seal_material.set_shader_parameter("primary_color", Color("48d6ff"))
	seal_material.set_shader_parameter("core_color", Color("f4fdff"))
	seal_sprite = Sprite2D.new()
	seal_sprite.name = "SpinGroundSeal"
	seal_sprite.texture = _unit_tex
	seal_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	seal_sprite.material = seal_material
	seal_sprite.z_as_relative = false
	seal_sprite.z_index = 0
	seal_sprite.visible = false
	add_child(seal_sprite)

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
			spin_seal_age += delta
			spin_tick_timer -= delta
			if spin_ticks_left > 0 and spin_tick_timer <= 0.0:
				spin_ticks_left -= 1
				spin_tick_timer += spin_tick_interval
				spin_hits.clear()
				_contact(global_position, global_position, CONFIG.THROW_RADIUS[rank], CONFIG.THROW_SPIN_DAMAGE[rank], spin_hits, aim, true)
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
	flight_trail.append(global_position)
	if flight_trail.size() > 11:
		flight_trail.remove_at(0)
	_update_wheel_vfx()
	queue_redraw()

func _update_wheel_vfx() -> void:
	if not is_instance_valid(wheel_sprite) or not is_instance_valid(actor):
		return
	var twin: bool = is_instance_valid(actor.combo) and actor.combo.heavy_reward
	var strength := smoothstep(0.0, 0.06, age)
	var center := Vector2.ZERO
	if flight == Flight.CATCH:
		var caught := smoothstep(0.0, 1.0, 1.0 - left / CATCH_TIME)
		strength *= 1.0 - caught
	elif flight == Flight.OUTBOUND:
		center = (launch_grip + aim * BLADE_CENTER_FROM_HILT) * (1.0 - strength)
	var base_radius: float = (CONFIG.THROW_RADIUS[rank] + 10.0) if flight == Flight.SPIN else (30.0 + rank * 4.5)
	if twin:
		base_radius *= 1.26
	var diameter := base_radius * 2.0
	wheel_sprite.visible = strength > 0.02
	wheel_sprite.position = center
	wheel_sprite.scale = Vector2(diameter, diameter)
	wheel_material.set_shader_parameter("rank_stage", rank)
	wheel_material.set_shader_parameter("twin_star", 1 if twin else 0)
	wheel_material.set_shader_parameter("spin_angle", angle)
	wheel_material.set_shader_parameter("strength", strength)
	wheel_material.set_shader_parameter("pixel_grid", clampf(roundf(diameter / 1.4), 68.0, 128.0))

	# 【双星旋刃】旋停期在地面映射微弱像素八卦/剑阵光纹
	if is_instance_valid(seal_sprite):
		var show_seal := twin and flight == Flight.SPIN
		seal_sprite.visible = show_seal
		if show_seal:
			var total_spin := maxf(0.01, float(CONFIG.THROW_SPIN_TIME[rank]))
			var seal_prog := clampf(spin_seal_age / total_spin, 0.0, 1.0)
			var seal_size: float = float(CONFIG.THROW_RADIUS[rank]) * 2.35
			seal_sprite.position = Vector2(0, 8)
			seal_sprite.scale = Vector2(seal_size, seal_size)
			seal_material.set_shader_parameter("progress", seal_prog)
			seal_material.set_shader_parameter("intensity", 0.72)

func _motion_fraction(from: Vector2, motion: Vector2) -> float:
	if motion.length_squared() < 0.001:
		return 1.0
	probe.transform = Transform2D(0.0, from)
	probe.motion = motion
	return get_world_2d().direct_space_state.cast_motion(probe)[0]

func _outbound(delta: float) -> void:
	var remaining: float = max_travel - traveled
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
	elif traveled >= max_travel - 0.01:
		flight = Flight.SPIN
		left = float(CONFIG.THROW_SPIN_TIME[rank])
		spin_ticks_left = int(CONFIG.THROW_SPIN_TICKS[rank])
		spin_tick_interval = left / float(maxi(1, spin_ticks_left))
		spin_tick_timer = 0.0
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

func _contact(from: Vector2, to: Vector2, radius: float, amount: float, hits: Dictionary, push: Vector2, pull_inward: bool = false) -> void:
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
		var impulse := push * 56.0
		if pull_inward:
			# 旋停期轻度向心牵引 + 短暂减速，方便聚怪衔接 E 或空格
			var to_center := global_position - point
			var pull_dist := to_center.length()
			impulse = to_center.normalized() * minf(CONFIG.THROW_PULL_STRENGTH, pull_dist * 3.2) if pull_dist > 6.0 else Vector2.ZERO
			enemy.slow_time = maxf(enemy.slow_time, CONFIG.THROW_SLOW_DURATION)
		enemy.take_damage(amount * power, impulse, false, false)
		contact = point
	if first and contact.is_finite():
		var twin: bool = is_instance_valid(actor.combo) and actor.combo.heavy_reward
		actor.sword_cue.emit("throw_hit_twin" if twin else "throw_hit", contact)

func _draw() -> void:
	if not is_instance_valid(actor):
		return
	var twin: bool = is_instance_valid(actor.combo) and actor.combo.heavy_reward
	var center := Vector2.ZERO
	var blade_angle := angle
	var strength := smoothstep(0.0, 0.06, age)
	var trail_col := Color("7be8ff") if rank < 2 else Color("4ad6ff")
	if twin:
		trail_col = trail_col.lerp(Color("ffe27a"), 0.28)
	# 飞行青白像素流光长拖尾（出剑/回剑一眼清晰可见）
	if flight != Flight.SPIN and flight_trail.size() >= 2:
		for i in range(1, flight_trail.size()):
			var t := float(i) / float(flight_trail.size())
			var p0 := to_local(flight_trail[i - 1]).round()
			var p1 := to_local(flight_trail[i]).round()
			draw_line(p0, p1, Color(trail_col, t * 0.62 * strength), (8.0 if twin else 5.5) * t, false)
			draw_line(p0, p1, Color(0.96, 1.0, 1.0, t * 0.85 * strength), (3.0 if twin else 2.0) * t, false)
	if flight == Flight.CATCH:
		var caught := smoothstep(0.0, 1.0, 1.0 - left / CATCH_TIME)
		var grip: Vector2 = actor.global_position + actor.visual.throw_hand(aim)
		var settled_angle: float = actor.visual.throw_blade_angle(aim)
		blade_angle = lerp_angle(catch_angle, settled_angle, caught)
		center = to_local(catch_start.lerp(grip + Vector2.from_angle(blade_angle) * BLADE_CENTER_FROM_HILT, caught))
		strength *= 1.0 - caught
	elif flight == Flight.OUTBOUND:
		center = (launch_grip + aim * BLADE_CENTER_FROM_HILT) * (1.0 - strength)
	if twin and flight != Flight.CATCH:
		# 对称青金副刃
		var sub_angle := blade_angle + PI
		var sub_hilt := center - Vector2.from_angle(sub_angle) * BLADE_CENTER_FROM_HILT
		draw_set_transform(sub_hilt, sub_angle - BLADE_ANGLE)
		draw_texture_rect_region(STRIKE, Rect2(-BLADE_PIVOT * BLADE_SCALE, BLADE_SOURCE.size * BLADE_SCALE), BLADE_SOURCE, Color(0.70, 0.97, 1.0, strength * 0.82))
		draw_set_transform(Vector2.ZERO)
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

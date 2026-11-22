extends Node2D

const CONFIG = preload("res://scripts/v41_config.gd")

enum Phase { CAST, ORBIT, ASCEND, FALL }

var actor: SurvivorPlayer
var rank := 0
var empowered := false
var refunded_targets := {}
var refunded_time := 0.0
var opening_bonus := 1.0
var power := 1.0
var terrain_mask := 1
var aim := Vector2.RIGHT
var fallback_center := Vector2.ZERO
var phase := Phase.CAST
var phase_age := 0.0
var clock := 0.0
var total_swords := 5
var swords: Array[Dictionary] = []
var impacts: Array[Dictionary] = []
var _fall_cue_sent := false

func _ready() -> void:
	z_index = 6
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	total_swords = int(CONFIG.SWORD_RAIN_COUNT[clampi(rank, 0, 2)]) * (2 if empowered else 1)
	if is_instance_valid(actor):
		global_position = actor.global_position
		aim = _current_aim()
		fallback_center = global_position + aim * 165.0
		actor.sword_cue.emit("sword_rain_cast", global_position)
	_build_sword_slots()

func is_casting() -> bool:
	return phase == Phase.CAST

func cast_progress() -> float:
	if phase != Phase.CAST:
		return 1.0
	return clampf(phase_age / maxf(0.01, CONFIG.SWORD_RAIN_CAST_TIME), 0.0, 1.0)

func _current_aim() -> Vector2:
	if not is_instance_valid(actor):
		return aim
	var dir: Vector2 = actor.aim_direction
	return dir.normalized() if not dir.is_zero_approx() else aim

func _live_enemies_sorted() -> Array[SurvivorEnemy]:
	var origin := actor.global_position if is_instance_valid(actor) else global_position
	var alive: Array[SurvivorEnemy] = []
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as SurvivorEnemy
		if enemy == null or enemy.dead or enemy.emerging or enemy.is_queued_for_deletion():
			continue
		alive.append(enemy)
	alive.sort_custom(func(a, b): return a.global_position.distance_squared_to(origin) < b.global_position.distance_squared_to(origin))
	return alive

func _fallback_drop(idx: int) -> Vector2:
	var spiral_a := float(idx) * 2.39996 + 0.35
	var spiral_r := 18.0 + float(idx % 3) * 18.0
	return fallback_center + Vector2(cos(spiral_a) * spiral_r, sin(spiral_a) * spiral_r * 0.65)

func _build_sword_slots() -> void:
	swords.clear()
	var alive := _live_enemies_sorted()
	for i in range(total_swords):
		var base_angle := (-aim).angle() + TAU * float(i) / float(maxi(1, total_swords))
		var locked_enemy: SurvivorEnemy = alive[i % alive.size()] if not alive.is_empty() else null
		var ring_a := TAU * float(i) / float(maxi(1, total_swords))
		var drop_pt := locked_enemy.global_position + Vector2(cos(ring_a) * 8.0, sin(ring_a) * 5.0) if locked_enemy != null else _fallback_drop(i)
		swords.append({
			"base_angle": base_angle,
			"target_enemy": locked_enemy,
			"drop_point": drop_pt,
			"ascend_start": Vector2.ZERO,
			"fall_delay": float(i) * CONFIG.SWORD_RAIN_FALL_STEP * (0.40 if empowered else 0.86),
			"skew_x": (float(i % 5) - 2.0) * (16.0 if empowered else 7.0),
			"landed": false,
			"land_age": 0.0,
		})

func _assign_live_targets() -> void:
	# 按距离由近到远均匀分配场上存活敌人（单精英/Boss 则全部飞剑集中错峰砸落）
	var alive := _live_enemies_sorted()
	if is_instance_valid(actor):
		fallback_center = actor.global_position + _current_aim() * 165.0
	for i in range(swords.size()):
		var s := swords[i]
		if s.landed:
			continue
		var ring_a := TAU * float(i) / float(maxi(1, total_swords))
		if alive.is_empty():
			s.target_enemy = null
			s.drop_point = _fallback_drop(i)
		else:
			var target: SurvivorEnemy = alive[i % alive.size()]
			s.target_enemy = target
			s.drop_point = target.global_position + Vector2(cos(ring_a) * 8.0, sin(ring_a) * 5.0)

func _track_live_targets() -> void:
	# 实时追踪锁定目标最新坐标；若目标中途阵亡则无缝重绑剩余存活敌人
	var alive_cache: Array[SurvivorEnemy] = []
	var cache_ready := false
	for i in range(swords.size()):
		var s := swords[i]
		if s.landed:
			continue
		var ring_a := TAU * float(i) / float(maxi(1, total_swords))
		var target: SurvivorEnemy = s.target_enemy if is_instance_valid(s.target_enemy) else null
		if target == null or target.dead or target.is_queued_for_deletion():
			if not cache_ready:
				alive_cache = _live_enemies_sorted()
				cache_ready = true
			if not alive_cache.is_empty():
				target = alive_cache[i % alive_cache.size()]
				s.target_enemy = target
			else:
				s.target_enemy = null
		if target != null and is_instance_valid(target) and not target.dead:
			s.drop_point = target.global_position + Vector2(cos(ring_a) * 8.0, sin(ring_a) * 5.0)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(actor) or actor.dead:
		queue_free()
		return
	global_position = actor.global_position
	phase_age += delta
	clock += delta

	match phase:
		Phase.CAST:
			if phase_age >= CONFIG.SWORD_RAIN_CAST_TIME:
				phase = Phase.ORBIT
				phase_age = 0.0
				actor.sword_cue.emit("sword_rain_gather", global_position)
		Phase.ORBIT:
			if phase_age >= CONFIG.SWORD_RAIN_ORBIT_TIME:
				for s in swords:
					var end_a: float = float(s.base_angle) + TAU
					s.ascend_start = global_position + Vector2(cos(end_a) * 54.0, sin(end_a) * 37.0 - 12.0)
				_assign_live_targets()
				phase = Phase.ASCEND
				phase_age = 0.0
				actor.sword_cue.emit("sword_rain_ascend", global_position)
		Phase.ASCEND:
			_track_live_targets()
			if phase_age >= CONFIG.SWORD_RAIN_ASCEND_TIME:
				phase = Phase.FALL
				phase_age = 0.0
				if not _fall_cue_sent:
					_fall_cue_sent = true
					actor.sword_cue.emit("sword_rain_fire", global_position)
		Phase.FALL:
			_track_live_targets()
			var all_done := true
			for s in swords:
				var local_t: float = phase_age - float(s.fall_delay)
				if not s.landed:
					all_done = false
					if local_t >= CONFIG.SWORD_RAIN_DROP_TIME:
						s.landed = true
						s.land_age = 0.0
						_resolve_sword_impact(s.drop_point)
				else:
					s.land_age += delta
					if float(s.land_age) < 0.14:
						all_done = false
			for i in range(impacts.size() - 1, -1, -1):
				impacts[i].age += delta
				if float(impacts[i].age) >= float(impacts[i].duration):
					impacts.remove_at(i)
			if all_done and impacts.is_empty():
				actor.finish_sword_rain(self)
				queue_free()
				return
	queue_redraw()

func _resolve_sword_impact(point: Vector2) -> void:
	var radius: float = CONFIG.SWORD_RAIN_IMPACT_RADIUS
	var dmg: float = float(CONFIG.SWORD_RAIN_DAMAGE[clampi(rank, 0, 2)]) * power
	var hit_any := false
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as SurvivorEnemy
		if enemy == null or enemy.dead or enemy.emerging or enemy.is_queued_for_deletion():
			continue
		if enemy.global_position.distance_squared_to(point) <= radius * radius:
			var push_dir := (enemy.global_position - point).normalized() if enemy.global_position.distance_squared_to(point) > 1.0 else aim
			var broke_guard := false
			if enemy.has_method("is_guarding_stance") and enemy.is_guarding_stance():
				if enemy.v41_guard_elite:
					broke_guard = enemy.damage_posture(55.0)
				else:
					broke_guard = enemy.break_guard_stance(CONFIG.HEAVY_BASE_BREAK, CONFIG.BREAK_STUN)
			var is_crit := broke_guard or opening_bonus > 1.0 or enemy.posture_broken_time > 0.0
			enemy.take_damage(dmg * opening_bonus, push_dir * 65.0, broke_guard, false, false, is_crit)
			if opening_bonus > 1.0:
				opening_bonus = 1.0
				actor.trigger_card_slash(enemy, aim)
			if broke_guard:
				actor.report_guard_break(enemy, 2)
			hit_any = true
			if empowered and not actor.dead:
				var target_id := enemy.get_instance_id()
				if not refunded_targets.has(target_id):
					refunded_targets[target_id] = true
					var budget: float = CONFIG.SWORD_RAIN_COOLDOWNS[rank] - CONFIG.SWORD_RAIN_MIN_COOLDOWN
					var refund := minf(CONFIG.SWORD_RAIN_REFUND, budget - refunded_time)
					refunded_time += refund
					actor.sword_rain_cooldown = maxf(0.0, actor.sword_rain_cooldown - refund)
				actor.health = minf(actor.max_health, actor.health + 2.0)
	impacts.append({
		"point": point,
		"age": 0.0,
		"duration": 0.19,
		"hit": hit_any,
	})
	if hit_any:
		actor.sword_cue.emit("sword_rain_hit", point)

func _draw_pixel_sword(pos: Vector2, heading: Vector2, length: float, col_main: Color, col_core: Color, col_accent: Color, alpha: float) -> void:
	length *= 1.34
	var dir := heading.normalized()
	var side := dir.orthogonal()
	var tip := (pos + dir * (length * 0.56)).round()
	var tail := (pos - dir * (length * 0.44)).round()
	var guard_l := (pos - dir * (length * 0.12) + side * 6.3).round()
	var guard_r := (pos - dir * (length * 0.12) - side * 6.3).round()
	draw_line(tail, tip, Color(col_main, 0.34 * alpha), 13.0, false)
	draw_colored_polygon(PackedVector2Array([tip, guard_l, tail, guard_r]), Color(col_main, 0.90 * alpha))
	draw_line(tail, tip, Color(col_core, 0.96 * alpha), 2.2, false)
	draw_line(guard_l, guard_r, Color(col_accent, 0.92 * alpha), 2.0, false)

func _draw_cast_shockwave() -> void:
	var progress := clampf(clock / 0.26, 0.0, 1.0)
	if progress >= 1.0:
		return
	var radius := lerpf(25.0, 120.0, 1.0 - pow(1.0 - progress, 2.3))
	var strength := 1.0 - smoothstep(0.02, 1.0, progress)
	draw_set_transform(Vector2(0, 12), 0.0, Vector2(1.0, 0.48))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 56, Color(0.22, 0.86, 0.69, 0.43 * strength), 14.0 * strength + 1.0, true)
	draw_arc(Vector2.ZERO, radius - 3.0, 0.0, TAU, 56, Color(0.88, 1.0, 0.91, 0.92 * strength), 3.4, true)
	draw_arc(Vector2.ZERO, radius * 0.74, 0.5, TAU, 46, Color(0.99, 0.80, 0.36, 0.77 * strength), 2.8, true)
	draw_set_transform(Vector2.ZERO)
	for i in range(24):
		var direction := Vector2.from_angle(TAU * float(i) / 24.0 + 0.09 * i)
		var point := direction * radius * (0.90 + 0.11 * (i % 3))
		point.y *= 0.48
		point.y -= progress * (14.0 + i % 5 * 6.0)
		var ink := Color("f5d982") if i % 3 == 0 else Color("a4f8dc")
		draw_line(point * 0.78, point, Color(ink, strength * 0.86), 2.0 + i % 2, true)

func _draw() -> void:
	_draw_cast_shockwave()
	var col_main := Color("8be6ff") if rank == 0 else (Color("52f0ea") if rank == 1 else Color("42d2ff"))
	var col_core := Color("f8ffff")
	var col_accent := Color("ffe17d") if (empowered or rank >= 1) else col_main

	if phase == Phase.CAST:
		var t := clampf(phase_age / maxf(0.01, CONFIG.SWORD_RAIN_CAST_TIME), 0.0, 1.0)
		var blade_t := smoothstep(0.45, 1.0, t)
		if blade_t > 0.01:
			for s in swords:
				var a: float = s.base_angle
				var p := Vector2(cos(a) * lerpf(30.0, 65.0, blade_t), sin(a) * lerpf(20.0, 45.0, blade_t) - 10.0)
				var tangent := Vector2(-sin(a), cos(a)).normalized()
				_draw_pixel_sword(p, tangent, lerpf(12.0, 26.0, blade_t), col_main, col_core, col_accent, blade_t * 0.92)

	elif phase == Phase.ORBIT:
		var t := clampf(phase_age / maxf(0.01, CONFIG.SWORD_RAIN_ORBIT_TIME), 0.0, 1.0)
		var eased := smoothstep(0.0, 1.0, t)
		var spin := eased * TAU
		var rx := lerpf(65.0, 54.0, t)
		var ry := lerpf(45.0, 37.0, t)
		draw_set_transform(Vector2(0, -10), 0.0, Vector2(1.0, ry / rx))
		draw_arc(Vector2.ZERO, rx, 0.0, TAU, 28, Color(col_main, 0.38 + 0.30 * t), 2.0, false)
		draw_set_transform(Vector2.ZERO)
		for s in swords:
			var cur_a: float = float(s.base_angle) + spin
			var pos := Vector2(cos(cur_a) * rx, sin(cur_a) * ry - 12.0)
			var prev_a := cur_a - 0.38
			var prev_pos := Vector2(cos(prev_a) * rx, sin(prev_a) * ry - 12.0)
			draw_line(prev_pos.round(), pos.round(), Color(col_main, 0.45), 9.0, false)
			draw_line(prev_pos.round(), pos.round(), Color(col_core, 0.84), 2.4, false)
			var tangent := Vector2(-sin(cur_a), cos(cur_a)).normalized()
			var heading := tangent.lerp(Vector2.UP, smoothstep(0.75, 1.0, t))
			_draw_pixel_sword(pos, heading, 28.0, col_main, col_core, col_accent, 0.95)

	elif phase == Phase.ASCEND:
		var t := clampf(phase_age / maxf(0.01, CONFIG.SWORD_RAIN_ASCEND_TIME), 0.0, 1.0)
		var lift := pow(t, 0.72) * 215.0
		# 为每个被锁定的存活敌人脚下闪现克制的淡青金索敌微环
		var marked := {}
		for s in swords:
			var tgt: SurvivorEnemy = s.target_enemy if is_instance_valid(s.target_enemy) else null
			if tgt != null and not tgt.dead and not marked.has(tgt.get_instance_id()):
				marked[tgt.get_instance_id()] = true
				var tp := to_local(tgt.global_position)
				draw_set_transform(tp + Vector2(0, 12), 0.0, Vector2(1.0, 0.44))
				draw_arc(Vector2.ZERO, lerpf(30.0, 18.0, t), 0.0, TAU, 22, Color(col_accent, 0.72 * t), 2.0, false)
				draw_set_transform(Vector2.ZERO)
		for s in swords:
			var start_local := to_local(s.ascend_start)
			var p := start_local + Vector2(0.0, -lift)
			var tail_p := p + Vector2(0.0, lerpf(16.0, 52.0, t))
			draw_line(tail_p.round(), p.round(), Color(col_main, 0.68 * (1.0 - t * 0.3)), 3.0, false)
			draw_line((p + Vector2(0, 20)).round(), p.round(), Color(col_core, 0.85 * (1.0 - t * 0.25)), 1.5, false)
			_draw_pixel_sword(p, Vector2.UP, 30.0, col_main, col_core, col_accent, 1.0 - t * 0.25)

	else:
		for s in swords:
			var local_t: float = phase_age - float(s.fall_delay)
			if local_t < 0.0:
				continue
			var dst := to_local(s.drop_point)
			if not s.landed:
				var f := clampf(local_t / maxf(0.01, CONFIG.SWORD_RAIN_DROP_TIME), 0.0, 1.0)
				var eased_f := f * f
				var start_p := dst + Vector2(float(s.skew_x), -250.0)
				var pos := start_p.lerp(dst, eased_f)
				var prev_p := start_p.lerp(dst, maxf(0.0, eased_f - 0.34))
				var heading := (dst - start_p).normalized()
				draw_line(prev_p.round(), pos.round(), Color(col_main, 0.56), 11.0, false)
				draw_line(prev_p.round(), pos.round(), Color(col_main, 0.92), 5.0, false)
				draw_line(prev_p.lerp(pos, 0.28).round(), pos.round(), Color(col_core, 0.95), 2.8, false)
				_draw_pixel_sword(pos, heading, 30.0, col_main, col_core, col_accent, 0.98)
			else:
				var st := clampf(float(s.land_age) / 0.14, 0.0, 1.0)
				var inv := 1.0 - st
				var heading := Vector2(-float(s.skew_x) * 0.006, 1.0).normalized()
				_draw_pixel_sword(dst - heading * 8.0, heading, 26.0, col_main, col_core, col_accent, inv * 0.92)

	for imp in impacts:
		var t := clampf(float(imp.age) / maxf(0.01, float(imp.duration)), 0.0, 1.0)
		var inv := 1.0 - t
		var pt := to_local(imp.point).round()
		var r_ring := lerpf(6.0, 32.0 if imp.hit else 24.0, pow(t, 0.55))
		draw_set_transform(pt + Vector2(0, 6), 0.0, Vector2(1.0, 0.44))
		draw_arc(Vector2.ZERO, r_ring, 0.0, TAU, 24, Color(col_main, inv * 0.85), 2.4 * inv + 1.0, false)
		if imp.hit:
			draw_arc(Vector2.ZERO, r_ring * 0.65, 0.0, TAU, 18, Color(col_accent, inv * 0.90), 2.0, false)
		draw_set_transform(Vector2.ZERO)
		for i in range(6):
			var a := TAU * float(i) / 6.0 + 0.3
			var sp := (pt + Vector2(cos(a) * r_ring * 0.9, sin(a) * r_ring * 0.4 - t * 14.0)).round()
			draw_rect(Rect2(sp - Vector2(1.5, 1.5), Vector2(3, 3)), Color(col_core if i % 2 == 0 else col_accent, inv * 0.92))

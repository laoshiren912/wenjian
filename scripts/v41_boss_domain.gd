extends Node2D

signal domain_burst_started
signal domain_finished

enum Pattern { RAIN, WHEEL, CROSS }
const NAMES := ["万魔剑域", "八荒魔轮", "心魔幻斩"]
const TELEGRAPH: Array[float] = [1.20, 0.45, 1.00]
const ACTIVE: Array[float] = [1.35, 3.50, 0.38]
const SHADOW := preload("res://assets/characters/Swordsman/Swordsman_Attack_Sheet_1404x1440.png")
const CHARGE_TIME := 1.20
const BURST_TIME := 1.35
const SAFE_RADIUS := 58.0
const LINE_HALF_WIDTH := 18.0
const TICK_INTERVAL := 0.22
const TICK_DAMAGE := 18.0
const WHEEL_HALF_WIDTH := 15.0
const CROSS_HALF_WIDTH := 31.0
const WHEEL_RATE := 0.688

var boss: Node2D
var player: Node2D
var pattern: int = Pattern.RAIN
var arena_center := Vector2(640, 380)
var arena_outline: PackedVector2Array
var elapsed := 0.0
var bursting := false
var tick_timer := 0.0
var safe_zones: Array[Vector2] = []
var warn_lines: Array[Dictionary] = []
var rain_blades: Array[Dictionary] = []
var shield_ripple_time := 0.0
var evade_flash_time := 0.0

func setup(owner_boss: Node2D, target_player: Node2D, center: Vector2, selected := Pattern.RAIN) -> void:
	boss = owner_boss
	player = target_player
	arena_center = center
	pattern = selected
	arena_outline = owner_boss.world.walkable
	z_index = 1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if pattern == Pattern.RAIN:
		_build_pattern()
	elif pattern == Pattern.CROSS:
		for pair in [[Vector2(215, 240), Vector2(1022, 505)],
				[Vector2(1060, 246), Vector2(301, 540)],
				[Vector2(260, 504), Vector2(1026, 504)]]:
			warn_lines.append({"a": pair[0], "b": pair[1]})

func _build_pattern() -> void:
	safe_zones.clear()
	warn_lines.clear()
	rain_blades.clear()
	# 3 个分布均匀且位于凌霄仙庭台面内的圆形青光安全阵眼
	safe_zones = [
		Vector2(410, 470),
		Vector2(870, 470),
		Vector2(640, 565),
	]
	# 纵横交错 + 对角十字暗红剑气预警线（避开安全阵眼中心视觉主焦，形成清晰走位空间）
	var y_rows := [260.0, 370.0, 495.0]
	for y in y_rows:
		warn_lines.append({"a": Vector2(180, y), "b": Vector2(1100, y), "kind": "h"})
	var x_cols := [320.0, 515.0, 765.0, 960.0]
	for x in x_cols:
		warn_lines.append({"a": Vector2(x, 165), "b": Vector2(x, 635), "kind": "v"})
	warn_lines.append({"a": Vector2(260, 195), "b": Vector2(1020, 595), "kind": "diag"})
	warn_lines.append({"a": Vector2(1020, 195), "b": Vector2(260, 595), "kind": "diag"})

	# 预生成沿预警线分布的黑红魔剑雨点位
	var rng := RandomNumberGenerator.new()
	rng.seed = int(Time.get_ticks_msec() % 100000) + 77
	for idx in range(warn_lines.size()):
		var ln: Dictionary = warn_lines[idx]
		var a: Vector2 = ln.a
		var b: Vector2 = ln.b
		for k in range(5):
			var frac := (float(k) + 0.5) / 5.0
			var pt := a.lerp(b, frac)
			if _in_any_safe_zone(pt):
				continue
			rain_blades.append({
				"point": pt,
				"delay": rng.randf_range(0.0, 0.72),
				"skew": rng.randf_range(-22.0, 22.0),
			})

func _in_any_safe_zone(pt: Vector2) -> bool:
	for sz in safe_zones:
		if pt.distance_squared_to(sz) <= SAFE_RADIUS * SAFE_RADIUS:
			return true
	return false

func _beam_segments() -> Array[Dictionary]:
	var segments: Array[Dictionary] = []
	var angle := -0.18 + maxf(0.0, elapsed - TELEGRAPH[Pattern.WHEEL]) * WHEEL_RATE
	for i in range(4):
		var ray := Vector2.from_angle(angle + i * PI * 0.5)
		var end := arena_center + ray * 1040.0
		for side in range(arena_outline.size()):
			var wall: Variant = Geometry2D.segment_intersects_segment(arena_center, end, arena_outline[side], arena_outline[(side + 1) % arena_outline.size()])
			if wall != null:
				end = wall
		segments.append({"a": arena_center + ray * 28.0, "b": end})
	return segments

func is_dangerous(pt: Vector2) -> bool:
	if pattern == Pattern.RAIN:
		return not _in_any_safe_zone(pt)
	var segments := _beam_segments() if pattern == Pattern.WHEEL else warn_lines
	var half_width := WHEEL_HALF_WIDTH if pattern == Pattern.WHEEL else CROSS_HALF_WIDTH
	for ln in segments:
		var nearest := Geometry2D.get_closest_point_to_segment(pt, ln.a, ln.b)
		if pt.distance_squared_to(nearest) <= half_width * half_width:
			return true
	return false

func _physics_process(delta: float) -> void:
	if not is_instance_valid(boss) or boss.dead or not is_instance_valid(player) or player.dead:
		queue_free()
		return
	elapsed += delta
	shield_ripple_time = maxf(0.0, shield_ripple_time - delta)
	evade_flash_time = maxf(0.0, evade_flash_time - delta)
	var just_burst := not bursting and elapsed >= TELEGRAPH[pattern]
	if just_burst:
		bursting = true
		tick_timer = 0.0
		domain_burst_started.emit()
	if bursting:
		tick_timer -= delta
		if pattern == Pattern.WHEEL or (pattern == Pattern.RAIN and tick_timer <= 0.0) or just_burst:
			tick_timer = TICK_INTERVAL
			_apply_domain_damage()
			if is_queued_for_deletion():
				return
		if elapsed >= TELEGRAPH[pattern] + ACTIVE[pattern]:
			domain_finished.emit()
			queue_free()
			return
	queue_redraw()

func _apply_domain_damage() -> void:
	if not is_instance_valid(player) or player.dead:
		return
	var p := player.global_position
	if pattern == Pattern.RAIN and _in_any_safe_zone(p):
		shield_ripple_time = 0.24
		return
	if player.has_method("is_dash_evading") and player.is_dash_evading():
		evade_flash_time = 0.26
		return
	if is_dangerous(p):
		var push := (p - arena_center).normalized()
		if push.is_zero_approx():
			push = Vector2.DOWN
		player.take_damage([TICK_DAMAGE, 16.0, 28.0][pattern], push)

func _draw() -> void:
	match pattern:
		Pattern.RAIN:
			_draw_rain()
		Pattern.WHEEL:
			_draw_wheel()
		Pattern.CROSS:
			_draw_cross()

func _draw_wheel() -> void:
	var wake := clampf(elapsed / TELEGRAPH[Pattern.WHEEL], 0.0, 1.0)
	var pulse := 0.75 + sin(elapsed * 17.0) * 0.25
	draw_circle(arena_center, 29.0, Color(0.43, 0.035, 0.08, wake * 0.42))
	draw_arc(arena_center, 31.0, elapsed * 2.0, elapsed * 2.0 + TAU, 48, Color(0.96, 0.32, 0.24, wake * 0.90), 2.6, true)
	for segment in _beam_segments():
		var a: Vector2 = segment.a
		var b: Vector2 = segment.b
		if not bursting:
			draw_line(a, b, Color(0.75, 0.04, 0.12, 0.26 + wake * 0.30), WHEEL_HALF_WIDTH * 2.0, true)
			draw_line(a, b, Color(1.0, 0.40, 0.33, 0.65 + pulse * 0.30), 2.6, true)
		else:
			draw_line(a, b, Color(0.24, 0.013, 0.052, 0.74), WHEEL_HALF_WIDTH * 2.0, true)
			draw_line(a, b, Color(0.90, 0.07, 0.17, 0.86), 20.0, true)
			draw_line(a, b, Color(1.0, 0.69, 0.52, 0.73 + pulse * 0.24), 4.5, true)
			for i in range(7):
				var point := a.lerp(b, fmod(elapsed * 2.1 + i * 0.149, 1.0))
				draw_line(point.lerp(a, 0.06), point, Color(1.0, 0.83, 0.61, 0.92), 2.0, true)

func _draw_cross() -> void:
	var wake := clampf(elapsed / TELEGRAPH[Pattern.CROSS], 0.0, 1.0)
	var release := clampf((elapsed - TELEGRAPH[Pattern.CROSS]) / ACTIVE[Pattern.CROSS], 0.0, 1.0)
	var flash := 1.0 - release
	for segment in warn_lines:
		var a: Vector2 = segment.a
		var b: Vector2 = segment.b
		var dir := a.direction_to(b)
		var side := dir.orthogonal() * CROSS_HALF_WIDTH
		draw_line(a, b, Color(0.63, 0.027, 0.07, (0.28 + wake * 0.30) * flash), CROSS_HALF_WIDTH * 2.0, true)
		for edge in [-1.0, 1.0]:
			draw_line(a + side * edge, b + side * edge, Color(1.0, 0.29, 0.25, flash * 0.85), 1.8, true)
		if bursting:
			draw_line(a, b, Color(0.16, 0.015, 0.035, flash), 42.0, true)
			draw_line(a, b, Color(0.98, 0.13, 0.18, flash), 15.0, true)
			draw_line(a, b, Color(1.0, 0.77, 0.62, flash), 4.0, true)
		var ghost := a.lerp(b, smoothstep(0.0, 0.34, release)) if bursting else a
		var row := posmod(roundi((dir.angle() + PI / 2.0) / (PI * 0.25)), 8)
		draw_texture_rect_region(SHADOW, Rect2(ghost + Vector2(-56, -91), Vector2(112, 130)),
			Rect2(Vector2((5 if bursting else 3) * 156, row * 180), Vector2(156, 180)), Color(0.94, 0.22, 0.24, flash * 0.90))

func _draw_rain() -> void:
	var charge_t := clampf(elapsed / CHARGE_TIME, 0.0, 1.0)
	var burst_t := clampf((elapsed - CHARGE_TIME) / BURST_TIME, 0.0, 1.0) if bursting else 0.0
	var fade_out := 1.0 - smoothstep(0.78, 1.0, burst_t) if bursting else 1.0

	# 1. 地面暗红魔域微压暗
	var pulse := 0.72 + 0.28 * sin(elapsed * 14.0)
	draw_circle(arena_center, 440.0, Color(0.22, 0.02, 0.05, (0.14 * charge_t if not bursting else 0.20) * fade_out))

	# 2. 纵横交错暗红剑气预警线 & 爆发期黑红十字剑气波
	for ln in warn_lines:
		var a: Vector2 = ln.a
		var b: Vector2 = ln.b
		if not bursting:
			var w := lerpf(6.0, LINE_HALF_WIDTH * 1.45, charge_t)
			draw_line(a, b, Color(0.78, 0.08, 0.14, (0.16 + 0.24 * charge_t) * pulse), w, false)
			draw_line(a, b, Color(1.0, 0.34, 0.28, (0.52 + 0.44 * charge_t) * pulse), 2.4, false)
			# 汇聚光点
			var mid := a.lerp(b, 0.5 + 0.35 * sin(elapsed * 5.0))
			draw_circle(mid, 3.5, Color(1.0, 0.78, 0.62, 0.75 * charge_t))
		else:
			var bw := LINE_HALF_WIDTH * 1.85 * fade_out
			draw_line(a, b, Color(0.16, 0.02, 0.05, 0.62 * fade_out), bw, false)
			draw_line(a, b, Color(0.95, 0.14, 0.20, 0.88 * fade_out), bw * 0.52, false)
			draw_line(a, b, Color(1.0, 0.78, 0.62, 0.92 * fade_out), maxf(2.0, bw * 0.16), false)
			# 沿线高速疾驰的十字剑气波光刃
			var wave_p := fmod(burst_t * 2.2, 1.0)
			var wpos := a.lerp(b, wave_p)
			var dir := (b - a).normalized()
			draw_line(wpos - dir * 48.0, wpos + dir * 48.0, Color(1.0, 0.92, 0.80, 0.95 * fade_out), 4.5, false)

	# 3. 圆形青光安全阵眼（像素八角阵纹 + 清晰青绿护盾光环）
	for idx in range(safe_zones.size()):
		var sz := safe_zones[idx]
		var safe_a := (0.65 + 0.35 * sin(elapsed * 6.0 + idx)) * fade_out
		draw_circle(sz, SAFE_RADIUS, Color(0.14, 0.74, 0.66, 0.22 * fade_out))
		draw_circle(sz, SAFE_RADIUS * 0.62, Color(0.45, 0.96, 0.88, 0.14 * safe_a))
		draw_arc(sz, SAFE_RADIUS, 0.0, TAU, 36, Color(0.56, 0.98, 0.90, 0.92 * fade_out), 3.0, false)
		draw_arc(sz, SAFE_RADIUS - 7.0, elapsed * 1.4, elapsed * 1.4 + TAU * 0.75, 24, Color(0.92, 0.86, 0.56, 0.78 * fade_out), 1.8, false)
		# 旋转八角阵纹
		var oct := PackedVector2Array()
		for k in range(8):
			var ang := elapsed * (1.2 if idx % 2 == 0 else -1.2) + k * TAU / 8.0
			oct.append(sz + Vector2(cos(ang), sin(ang)) * (SAFE_RADIUS * 0.78))
		oct.append(oct[0])
		draw_polyline(oct, Color(0.68, 0.98, 0.92, 0.62 * fade_out), 1.4, false)
		# 阵眼核心菱形符印
		draw_colored_polygon(PackedVector2Array([
			sz + Vector2(0, -10), sz + Vector2(10, 0), sz + Vector2(0, 10), sz + Vector2(-10, 0),
		]), Color(0.84, 1.0, 0.96, 0.85 * safe_a))

	# 4. 爆发期密集黑红魔剑雨坠落
	if bursting:
		var bt := elapsed - CHARGE_TIME
		for b in rain_blades:
			var local := bt - float(b.delay)
			if local < 0.0 or local > 0.42:
				continue
			var dst: Vector2 = b.point
			if local < 0.16:
				var f := local / 0.16
				var start_p := dst + Vector2(float(b.skew), -260.0)
				var pos := start_p.lerp(dst, f * f)
				var prev := start_p.lerp(dst, maxf(0.0, f * f - 0.25))
				draw_line(prev, pos, Color(0.14, 0.02, 0.04, 0.92), 6.0, false)
				draw_line(prev, pos, Color(0.98, 0.22, 0.24, 0.95), 3.0, false)
				draw_line(pos - Vector2(0, 8), pos, Color(1.0, 0.86, 0.72, 0.98), 1.8, false)
			else:
				var st := (local - 0.16) / 0.26
				var inv := 1.0 - st
				var r := lerpf(6.0, 32.0, st)
				draw_arc(dst, r, 0.0, TAU, 20, Color(0.95, 0.18, 0.22, inv * 0.88), 2.2, false)
				draw_line(dst + Vector2(-14, 0), dst + Vector2(14, 0), Color(1.0, 0.75, 0.62, inv * 0.82), 2.0, false)
				draw_line(dst + Vector2(0, -22), dst + Vector2(0, 6), Color(0.20, 0.02, 0.06, inv * 0.9), 4.0, false)
				draw_line(dst + Vector2(0, -20), dst + Vector2(0, 4), Color(0.98, 0.24, 0.26, inv * 0.9), 2.0, false)

	# 5. 玩家位于安全阵眼内护盾涟漪 / 穿阵闪避光环
	if is_instance_valid(player) and not player.dead:
		if shield_ripple_time > 0.0:
			var rt := shield_ripple_time / 0.24
			draw_arc(player.global_position, lerpf(36.0, 22.0, rt), 0.0, TAU, 24, Color(0.55, 0.98, 0.90, rt * 0.85), 2.5, false)
		if evade_flash_time > 0.0:
			var et := evade_flash_time / 0.26
			draw_arc(player.global_position, lerpf(42.0, 20.0, et), 0.0, TAU, 24, Color(0.98, 0.88, 0.56, et * 0.9), 3.0, false)

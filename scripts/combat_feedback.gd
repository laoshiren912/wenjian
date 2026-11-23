extends Node2D

# Presentation only: no damage, physics speed, or gameplay random state changes.
var camera: Camera2D
var popups: Array[Dictionary] = []
var bursts: Array[Dictionary] = []
var crit_sparks: Array[Dictionary] = []
var shake_time: float = 0.0
var shake_strength: float = 0.0
const EXPERIENCE_WINDOW: float = 0.12
const EDGE_MARGIN: float = 8.0
var _experience_popup: Dictionary = {}
var hud_obstacles: Array[Control] = []
var _popup_seq: int = 0
var _popup_rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	_popup_rng.seed = 20261122

func show_damage(point: Vector2, amount: float, is_player: bool, camera_shake: bool = true, blocked: bool = false, crit: bool = false) -> void:
	if amount <= 0.0:
		return
	var tier := "player" if is_player else "normal"
	var color := Color("ff7878") if is_player else Color("f6ecd4")
	var caption := "-%d" % roundi(amount)
	if crit and not is_player and not blocked:
		_spawn_crit_sparks(point)
	_popup(point, caption, color, "player_damage" if is_player else "enemy_damage", amount, tier)
	var burst_col := Color("a8b2ba") if blocked else (Color("ffba52") if crit else color)
	bursts.append({"point": point, "age": 0.0, "color": burst_col, "local_impact": not camera_shake})
	if camera_shake:
		request_camera_shake(8.0 if is_player else (4.6 if crit else 3.5), 0.18)

func _spawn_crit_sparks(point: Vector2) -> void:
	for i in range(8):
		var ang := TAU * float(i) / 8.0 + _popup_rng.randf_range(-0.22, 0.22)
		var spd := _popup_rng.randf_range(75.0, 155.0)
		crit_sparks.append({
			"pos": point + Vector2(0, -48.0),
			"vel": Vector2(cos(ang) * spd, sin(ang) * spd - 45.0),
			"age": 0.0,
			"duration": _popup_rng.randf_range(0.28, 0.44),
			"size": _popup_rng.randf_range(2.4, 4.2),
			"gold": i % 2 == 0,
		})

func request_camera_shake(strength: float, duration: float) -> void:
	shake_strength = maxf(shake_strength, strength)
	shake_time = duration

func show_experience(point: Vector2, amount: int) -> int:
	# Display immediately; age is measured from the FIRST pickup and never restarted.
	# This only combines presentation. Player already credited each individual pickup.
	if not _experience_popup.is_empty() and is_instance_valid(_experience_popup.label) and float(_experience_popup.age) < EXPERIENCE_WINDOW:
		_experience_popup.amount = int(_experience_popup.amount) + amount
		_experience_popup.label.text = "+%d 经验" % int(_experience_popup.amount)
		_place_popup(_experience_popup)
	else:
		_experience_popup = _popup(point, "+%d 经验" % amount, Color("91c7ff"), "experience", amount, "experience")
	return int(_experience_popup.amount)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		# All combat modals pause World. Keep existing labels, but close the XP batch.
		_experience_popup = {}

func _popup(point: Vector2, text: String, color: Color, kind: String, amount: float, tier: String = "normal") -> Dictionary:
	_popup_seq += 1
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font_size := 21
	var outline_size := 5
	var outline_col := Color("0d141a")
	if kind == "player_damage":
		font_size = 24
	elif kind == "guard_break":
		font_size = 24
		outline_size = 6
		outline_col = Color("261108")
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", outline_col)
	label.add_theme_constant_override("outline_size", outline_size)
	label.z_index = 3 if kind == "player_damage" else (2 if kind == "enemy_damage" else 1)
	add_child(label)

	# 独立物理抛物线初速度与重力（左右交替+微扰保证连击自然散开不重叠）
	var side := 1.0 if (_popup_seq % 2 == 0) else -1.0
	var vel := Vector2.ZERO
	var gravity := 0.0
	var duration := 0.82
	if kind == "experience":
		vel = Vector2(0.0, -12.0)
		gravity = 0.0
		duration = 0.90
	elif kind == "guard_break":
		vel = Vector2(0.0, -78.0)
		gravity = 120.0
		duration = 0.95
	elif kind == "player_damage":
		vel = Vector2(side * _popup_rng.randf_range(50.0, 90.0), _popup_rng.randf_range(-160.0, -128.0))
		gravity = 420.0
		duration = 0.84
	else:
		vel = Vector2(side * _popup_rng.randf_range(68.0, 120.0), _popup_rng.randf_range(-172.0, -134.0))
		gravity = 435.0
		duration = 0.82

	var source_visible: bool = get_viewport_rect().has_point(get_global_transform_with_canvas() * to_local(point))
	var popup := {
		"label": label,
		"age": 0.0,
		"duration": duration,
		"origin": Vector2.ZERO,
		"point": point,
		"kind": kind,
		"tier": tier,
		"vel": vel,
		"gravity": gravity,
		"amount": amount,
		"clamp_to_viewport": source_visible,
	}
	_place_popup(popup)
	label.pivot_offset = label.size * 0.5
	popups.append(popup)
	return popup

func _popup_drift(popup: Dictionary) -> Vector2:
	var t := float(popup.age)
	if popup.kind == "experience":
		return Vector2(0.0, -12.0 * t)
	var v: Vector2 = popup.vel
	var g: float = float(popup.gravity)
	return Vector2(v.x * t, v.y * t + 0.5 * g * t * t)

func _visible_position(popup: Dictionary, origin: Vector2) -> Vector2:
	var canvas: Transform2D = get_global_transform_with_canvas()
	var bounds: Rect2 = get_viewport_rect()
	# Do not pull an offscreen source's damage into the visible battle.
	if not bool(popup.clamp_to_viewport):
		return origin
	var rectangle: Rect2 = canvas * Rect2(origin, popup.label.size)
	var maximum: Vector2 = (bounds.end - Vector2.ONE * EDGE_MARGIN - rectangle.size).max(bounds.position + Vector2.ONE * EDGE_MARGIN)
	var clamped := Vector2(clampf(rectangle.position.x, bounds.position.x + EDGE_MARGIN, maximum.x), clampf(rectangle.position.y, bounds.position.y + EDGE_MARGIN, maximum.y))
	# Keep numbers clear of both the top HUD and the new bottom equipment panel.
	for control in hud_obstacles:
		if not is_instance_valid(control) or not control.is_visible_in_tree():
			continue
		var panel: Rect2 = control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)
		if Rect2(clamped, rectangle.size).intersects(panel.grow(4.0)):
			clamped.y = minf(maximum.y, panel.end.y + EDGE_MARGIN) if panel.get_center().y < bounds.get_center().y else maxf(bounds.position.y + EDGE_MARGIN, panel.position.y - rectangle.size.y - EDGE_MARGIN)
	return canvas.affine_inverse() * (canvas * origin + clamped - rectangle.position)

func _place_popup(popup: Dictionary) -> void:
	var label: Label = popup.label
	label.size = label.get_minimum_size()
	# Enemy HP bars sit 38 px above the body; keep their numbers above the bar.
	var height: float = 72.0 if popup.kind == "enemy_damage" else (62.0 if popup.kind == "player_damage" else (104.0 if popup.kind == "guard_break" else -36.0))
	var jitter_x := _popup_rng.randf_range(-14.0, 14.0) if popup.kind != "experience" and popup.kind != "guard_break" else 0.0
	var base: Vector2 = to_local(popup.point) - Vector2(label.size.x * 0.5 - jitter_x, height)
	var gap: Vector2 = label.size + Vector2(10, 8)
	var candidates := [Vector2.ZERO, Vector2(-gap.x * 0.85, -8), Vector2(gap.x * 0.85, -8), Vector2(0, gap.y if popup.kind == "experience" else -gap.y)]
	var canvas: Transform2D = get_global_transform_with_canvas()
	for offset in candidates:
		popup.origin = base + offset
		label.position = _visible_position(popup, popup.origin + _popup_drift(popup))
		var rectangle: Rect2 = canvas * Rect2(label.position, label.size)
		var overlaps: bool = false
		for other in popups:
			if other.label == label or not is_instance_valid(other.label):
				continue
			var other_rect: Rect2 = canvas * Rect2(other.label.position, other.label.size)
			if rectangle.grow(3.0).intersects(other_rect):
				overlaps = true
				break
		if not overlaps:
			break

func _update_camera_shake(delta: float) -> void:
	shake_time = maxf(0.0, shake_time - delta)
	if is_instance_valid(camera):
		var fade: float = shake_time / 0.18
		var phase: float = (0.18 - shake_time) * 90.0
		camera.offset = Vector2(sin(phase), cos(phase * 1.3)) * shake_strength * fade
		if shake_time <= 0.0:
			camera.offset = Vector2.ZERO
			shake_strength = 0.0
		# Clamp labels against this frame's camera, including its visual shake.
		camera.force_update_scroll()

func _process(delta: float) -> void:
	_update_camera_shake(delta)
	for index in range(popups.size() - 1, -1, -1):
		var popup: Dictionary = popups[index]
		popup.age += delta
		var t: float = float(popup.age)
		var dur: float = float(popup.get("duration", 0.9))
		var label: Label = popup.label
		label.position = _visible_position(popup, popup.origin + _popup_drift(popup))
		label.modulate.a = clampf((dur - t) / 0.28, 0.0, 1.0)
		if t >= dur:
			if label == _experience_popup.get("label"):
				_experience_popup = {}
			label.queue_free()
			popups.remove_at(index)
	for index in range(bursts.size() - 1, -1, -1):
		bursts[index].age += delta
		if float(bursts[index].age) >= 0.16:
			bursts.remove_at(index)
	for index in range(crit_sparks.size() - 1, -1, -1):
		var sp: Dictionary = crit_sparks[index]
		sp.age = float(sp.age) + delta
		sp.pos = Vector2(sp.pos) + Vector2(sp.vel) * delta
		sp.vel = Vector2(sp.vel) + Vector2(0.0, 260.0) * delta
		if float(sp.age) >= float(sp.duration):
			crit_sparks.remove_at(index)
	queue_redraw()

func _draw() -> void:
	for burst in bursts:
		var progress: float = float(burst.age) / 0.16
		var color: Color = burst.color
		color.a = 1.0 - progress
		var point: Vector2 = to_local(burst.point)
		if burst.get("local_impact", false):
			draw_arc(point, lerpf(6.0, 31.0, progress), 0.0, TAU, 24, color, 3.0, true)
			draw_circle(point, lerpf(10.0, 2.0, progress), Color(color, color.a * 0.7))
		for ray in range(6):
			var direction := Vector2.from_angle(TAU * float(ray) / 6.0)
			draw_line(point + direction * (12.0 + progress * 13.0), point + direction * (21.0 + progress * 18.0), color, 2.5, true)
	for sp in crit_sparks:
		var t := clampf(float(sp.age) / maxf(0.01, float(sp.duration)), 0.0, 1.0)
		var inv := 1.0 - t
		var pt := to_local(sp.pos)
		var r := float(sp.size) * (0.5 + 0.5 * inv)
		var col := Color(1.0, 0.86, 0.40, inv) if bool(sp.gold) else Color(1.0, 0.96, 0.84, inv)
		draw_line(pt + Vector2(-r, 0), pt + Vector2(r, 0), col, 1.6, true)
		draw_line(pt + Vector2(0, -r), pt + Vector2(0, r), col, 1.6, true)

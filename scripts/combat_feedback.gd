extends Node2D

# Presentation only: no damage, physics speed, or gameplay random state changes.
var camera: Camera2D
var popups: Array[Dictionary] = []
var bursts: Array[Dictionary] = []
var shake_time: float = 0.0
var shake_strength: float = 0.0
const EXPERIENCE_WINDOW: float = 0.12
const EDGE_MARGIN: float = 8.0
var _experience_popup: Dictionary = {}
var hud_obstacles: Array[Control] = []

func show_damage(point: Vector2, amount: float, is_player: bool) -> void:
	if amount <= 0.0:
		return
	var color := Color("ff8585") if is_player else Color("ffe3a0")
	_popup(point, "-%d" % roundi(amount), color, "player_damage" if is_player else "enemy_damage", amount)
	bursts.append({"point": point, "age": 0.0, "color": color})
	shake_strength = maxf(shake_strength, 8.0 if is_player else 3.5)
	shake_time = 0.18

func show_experience(point: Vector2, amount: int) -> int:
	# Display immediately; age is measured from the FIRST pickup and never restarted.
	# This only combines presentation. Player already credited each individual pickup.
	if not _experience_popup.is_empty() and is_instance_valid(_experience_popup.label) and float(_experience_popup.age) < EXPERIENCE_WINDOW:
		_experience_popup.amount = int(_experience_popup.amount) + amount
		_experience_popup.label.text = "+%d 经验" % int(_experience_popup.amount)
		_place_popup(_experience_popup)
	else:
		_experience_popup = _popup(point, "+%d 经验" % amount, Color("91c7ff"), "experience", amount)
	return int(_experience_popup.amount)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		# All combat modals pause World. Keep existing labels, but close the XP batch.
		_experience_popup = {}

func _popup(point: Vector2, text: String, color: Color, kind: String, amount: float) -> Dictionary:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 24 if kind == "player_damage" else 21)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("0b151c"))
	label.add_theme_constant_override("outline_size", 5)
	label.z_index = 3 if kind == "player_damage" else (2 if kind == "enemy_damage" else 1)
	add_child(label)
	var source_visible: bool = get_viewport_rect().has_point(get_global_transform_with_canvas() * to_local(point))
	var popup := {"label": label, "age": 0.0, "origin": Vector2.ZERO, "point": point, "kind": kind, "amount": amount, "clamp_to_viewport": source_visible}
	_place_popup(popup)
	popups.append(popup)
	return popup

func _popup_drift(popup: Dictionary) -> Vector2:
	# Keep XP below the character throughout its visible lifetime.
	return Vector2(0, -(12.0 if popup.kind == "experience" else 42.0) * float(popup.age))

func _visible_position(popup: Dictionary, origin: Vector2) -> Vector2:
	var canvas: Transform2D = get_global_transform_with_canvas()
	var bounds: Rect2 = get_viewport_rect()
	# Do not pull an offscreen source's damage into the visible battle.
	if not bool(popup.clamp_to_viewport):
		return origin
	var rectangle: Rect2 = canvas * Rect2(origin, popup.label.size)
	var maximum: Vector2 = (bounds.end - Vector2.ONE * EDGE_MARGIN - rectangle.size).max(bounds.position + Vector2.ONE * EDGE_MARGIN)
	var clamped := Vector2(clampf(rectangle.position.x, bounds.position.x + EDGE_MARGIN, maximum.x), clampf(rectangle.position.y, bounds.position.y + EDGE_MARGIN, maximum.y))
	# Preserve the current HUD layout; only move a covered floating number below it.
	for control in hud_obstacles:
		if not is_instance_valid(control) or not control.is_visible_in_tree():
			continue
		var panel: Rect2 = control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)
		if Rect2(clamped, rectangle.size).intersects(panel.grow(4.0)):
			clamped.y = minf(maximum.y, panel.end.y + EDGE_MARGIN)
	return canvas.affine_inverse() * (canvas * origin + clamped - rectangle.position)

func _place_popup(popup: Dictionary) -> void:
	var label: Label = popup.label
	label.size = label.get_minimum_size()
	# Enemy HP bars sit 38 px above the body; keep their numbers above the bar.
	var height: float = 76.0 if popup.kind == "enemy_damage" else (62.0 if popup.kind == "player_damage" else -36.0)
	var base: Vector2 = to_local(popup.point) - Vector2(label.size.x * 0.5, height)
	var gap: Vector2 = label.size + Vector2(8, 8)
	var candidates := [Vector2.ZERO, Vector2(-gap.x, 0), Vector2(gap.x, 0), Vector2(0, gap.y if popup.kind == "experience" else -gap.y)]
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
			if rectangle.grow(4.0).intersects(other_rect):
				overlaps = true
				break
		if not overlaps:
			break

func _process(delta: float) -> void:
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
	for index in range(popups.size() - 1, -1, -1):
		var popup: Dictionary = popups[index]
		popup.age += delta
		var label: Label = popup.label
		label.position = _visible_position(popup, popup.origin + _popup_drift(popup))
		label.modulate.a = clampf((0.9 - float(popup.age)) / 0.3, 0.0, 1.0)
		if float(popup.age) >= 0.9:
			if label == _experience_popup.get("label"):
				_experience_popup = {}
			label.queue_free()
			popups.remove_at(index)
	for index in range(bursts.size() - 1, -1, -1):
		bursts[index].age += delta
		if float(bursts[index].age) >= 0.16:
			bursts.remove_at(index)
	queue_redraw()

func _draw() -> void:
	for burst in bursts:
		var progress: float = float(burst.age) / 0.16
		var color: Color = burst.color
		color.a = 1.0 - progress
		for ray in range(6):
			var direction := Vector2.from_angle(TAU * float(ray) / 6.0)
			var point: Vector2 = to_local(burst.point)
			draw_line(point + direction * (12.0 + progress * 13.0), point + direction * (21.0 + progress * 18.0), color, 2.5, true)

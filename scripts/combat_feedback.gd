extends Node2D

# Presentation only: no damage, physics speed, or gameplay random state changes.
var camera: Camera2D
var popups: Array[Dictionary] = []
var bursts: Array[Dictionary] = []
var shake_time: float = 0.0
var shake_strength: float = 0.0

func show_damage(point: Vector2, amount: float, is_player: bool) -> void:
	if amount <= 0.0:
		return
	var color := Color("ff8585") if is_player else Color("ffe3a0")
	_popup(point, "-%d" % roundi(amount), color, "player_damage" if is_player else "enemy_damage", amount)
	bursts.append({"point": point, "age": 0.0, "color": color})
	shake_strength = maxf(shake_strength, 8.0 if is_player else 3.5)
	shake_time = 0.18

func show_experience(point: Vector2, amount: int) -> void:
	# XP rises from below the player, leaving damage numbers above the head clear.
	_popup(point + Vector2(0, 78), "+%d 经验" % amount, Color("91c7ff"), "experience", amount)

func _popup(point: Vector2, text: String, color: Color, kind: String, amount: float) -> void:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 24 if kind == "player_damage" else 21)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("0b151c"))
	label.add_theme_constant_override("outline_size", 5)
	add_child(label)
	# Slight stagger keeps several hits/XP drops from occupying the exact same spot.
	var stagger := Vector2((popups.size() % 3 - 1) * 15.0, -(popups.size() % 2) * 12.0)
	# Enemy HP bars sit 38 px above the body; keep numbers above the bar too.
	var height: float = 76.0 if kind == "enemy_damage" else (62.0 if kind == "player_damage" else 42.0)
	var origin := to_local(point) - Vector2(label.get_minimum_size().x * 0.5, height) + stagger
	label.position = origin
	popups.append({"label": label, "age": 0.0, "origin": origin, "kind": kind, "amount": amount})

func _process(delta: float) -> void:
	for index in range(popups.size() - 1, -1, -1):
		var popup: Dictionary = popups[index]
		popup.age += delta
		var label: Label = popup.label
		label.position = popup.origin + Vector2(0, -42.0 * float(popup.age))
		label.modulate.a = clampf((0.9 - float(popup.age)) / 0.3, 0.0, 1.0)
		if float(popup.age) >= 0.9:
			label.queue_free()
			popups.remove_at(index)
	for index in range(bursts.size() - 1, -1, -1):
		bursts[index].age += delta
		if float(bursts[index].age) >= 0.16:
			bursts.remove_at(index)
	shake_time = maxf(0.0, shake_time - delta)
	if is_instance_valid(camera):
		var fade: float = shake_time / 0.18
		var phase: float = (0.18 - shake_time) * 90.0
		camera.offset = Vector2(sin(phase), cos(phase * 1.3)) * shake_strength * fade
		if shake_time <= 0.0:
			camera.offset = Vector2.ZERO
			shake_strength = 0.0
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

extends StaticBody2D

var in_front := false
var shimmer := 0.0

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var collider := CollisionShape2D.new()
	var footprint := CircleShape2D.new()
	footprint.radius = 17.0
	collider.shape = footprint
	add_child(collider)
	queue_redraw()

func update_depth(foot: Vector2, time: float, delta: float) -> void:
	in_front = foot.y < position.y + 3.0
	# Local sword/hand passes use Z 0..2. The prop must occlude the entire actor.
	z_index = 5 if in_front else -1
	var hides_hero := in_front and absf(foot.x - position.x) < 26.0 and foot.y > position.y - 105.0
	modulate.a = move_toward(modulate.a, 0.52 if hides_hero else 1.0, delta * 3.0)
	shimmer = time
	queue_redraw()

func _draw() -> void:
	var dark := Color("26363d")
	var lit := Color("77858a")
	var warm := Color("f5c47d")
	# Cast shadow stays on the ground, below the upright object.
	draw_colored_polygon(PackedVector2Array([Vector2(-17, 2), Vector2(15, -3), Vector2(65, 22), Vector2(37, 31)]), Color(0.02, 0.07, 0.09, 0.25))
	draw_colored_polygon(PackedVector2Array([Vector2(-24, 0), Vector2(0, -12), Vector2(24, 0), Vector2(0, 13)]), lit.darkened(0.25))
	draw_colored_polygon(PackedVector2Array([Vector2(-24, 0), Vector2(0, 13), Vector2(0, 20), Vector2(-24, 7)]), dark.lightened(0.12))
	draw_colored_polygon(PackedVector2Array([Vector2(0, 13), Vector2(24, 0), Vector2(24, 7), Vector2(0, 20)]), dark)
	# Two differently lit faces establish volume rather than a screen-facing bar.
	draw_colored_polygon(PackedVector2Array([Vector2(-11, -63), Vector2(0, -57), Vector2(0, 7), Vector2(-11, 1)]), Color("61757a"))
	draw_colored_polygon(PackedVector2Array([Vector2(0, -57), Vector2(12, -63), Vector2(12, 1), Vector2(0, 7)]), Color("384e56"))
	draw_line(Vector2(-7, -47), Vector2(-7, -4), Color("8c9791"), 1.0, true)
	for y in [-48.0, -16.0]:
		draw_polyline(PackedVector2Array([Vector2(-12, y - 5), Vector2(0, y), Vector2(13, y - 5)]), Color("b0a48b"), 2.0, true)
	var glow := 0.65 + sin(shimmer * 2.2) * 0.08
	draw_circle(Vector2(0, -76), 28.0, Color(1.0, 0.59, 0.21, 0.035 * glow))
	draw_colored_polygon(PackedVector2Array([Vector2(-19, -94), Vector2(0, -84), Vector2(19, -94), Vector2(19, -65), Vector2(0, -55), Vector2(-19, -65)]), dark)
	draw_colored_polygon(PackedVector2Array([Vector2(-14, -88), Vector2(-3, -82), Vector2(-3, -64), Vector2(-14, -70)]), warm.darkened(0.18))
	draw_colored_polygon(PackedVector2Array([Vector2(3, -82), Vector2(14, -88), Vector2(14, -70), Vector2(3, -64)]), warm * glow)
	for x in [-10.0, 9.0]:
		draw_line(Vector2(x, -86), Vector2(x, -69), Color("574d3a"), 1.0, true)
	# Faceted pagoda cap, with a warm rim from the lantern below.
	draw_colored_polygon(PackedVector2Array([Vector2(-28, -94), Vector2(0, -113), Vector2(28, -94), Vector2(0, -80)]), Color("4d626b"))
	draw_colored_polygon(PackedVector2Array([Vector2(0, -110), Vector2(25, -94), Vector2(0, -83)]), Color("283e4b"))
	draw_polyline(PackedVector2Array([Vector2(-28, -94), Vector2(0, -80), Vector2(28, -94)]), Color("b2aa8c"), 2.0, true)
	draw_circle(Vector2(0, -114), 3.5, Color("a6a58d"))

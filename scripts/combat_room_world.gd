extends "res://scripts/combat_sample_world.gd"

var spawn_points: Array[Vector2] = []
var spawn_progress: float = -1.0

func _draw() -> void:
	super._draw()
	if spawn_progress < 0.0 or spawn_progress >= 1.0:
		return
	var strength := 0.35 + 0.4 * sin(spawn_progress * PI)
	for point in spawn_points:
		draw_circle(point, 23.0, Color(0.85, 0.26, 0.16, strength * 0.28))
		draw_arc(point, 25.0, 0.0, TAU, 32, Color(1.0, 0.55, 0.25, strength), 3.0, true)

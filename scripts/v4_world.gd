extends "res://scripts/corridor_world.gd"

const CONFIG = preload("res://scripts/v4_config.gd")
var reward_visible := false
var room_cleared := false

func _draw() -> void:
	super._draw()
	if room_cleared and not portal_open:
		draw_arc(cell_center(PORTAL_CELL), 31.0, 0.0, TAU, 40, Color("e1cc9c"), 2.0, true)
	if reward_visible:
		var point := cell_center(CONFIG.REWARD_CELL)
		draw_circle(point, CONFIG.REWARD_RADIUS, Color(1.0, 0.8, 0.3, 0.12))
		draw_colored_polygon(PackedVector2Array([point + Vector2(0, -15), point + Vector2(15, 0), point + Vector2(0, 15), point + Vector2(-15, 0)]), Color("f4d278"))

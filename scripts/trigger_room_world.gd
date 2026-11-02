extends "res://scripts/combat_room_world.gd"

var trigger_visible := true
var trigger_center := Vector2.ZERO
const TRIGGER_RADIUS := 72.0

func _draw() -> void:
	super._draw()
	if trigger_visible:
		draw_circle(trigger_center, TRIGGER_RADIUS, Color(0.25, 0.75, 0.85, 0.12))
		draw_arc(trigger_center, TRIGGER_RADIUS, 0.0, TAU, 48, Color(0.42, 0.89, 0.94, 0.75), 3.0, true)
		draw_line(trigger_center + Vector2(-12, 0), trigger_center + Vector2(12, 0), Color("a4f0ed"), 2.0, true)
		draw_line(trigger_center + Vector2(0, -12), trigger_center + Vector2(0, 12), Color("a4f0ed"), 2.0, true)

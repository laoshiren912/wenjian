extends "res://scripts/corridor_world.gd"

const PRACTICE_RECT := Rect2i(12, 10, 16, 10)

func build_corridor() -> void:
	grid.region = Rect2i(0, 0, COLUMNS, ROWS)
	grid.cell_size = Vector2.ONE * CELL
	grid.offset = Vector2.ONE * CELL * 0.5
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for x in range(COLUMNS):
		for y in range(ROWS):
			var cell := Vector2i(x, y)
			if not PRACTICE_RECT.has_point(cell):
				grid.set_point_solid(cell, true)
				if PRACTICE_RECT.grow(1).has_point(cell):
					_add_wall(cell)
	actors = Node2D.new()
	actors.name = "Actors"
	actors.y_sort_enabled = true
	add_child(actors)
	queue_redraw()

func _draw() -> void:
	for x in range(11, 29):
		for y in range(9, 21):
			var cell := Vector2i(x, y)
			var color := Color("203139") if (x + y) % 2 == 0 else Color("22353c")
			if blocked.has(cell):
				color = Color("41545b")
			draw_rect(Rect2(Vector2(cell) * CELL, Vector2.ONE * (CELL - 1)), color)
	var center := cell_center(Vector2i(19, 14))
	draw_arc(center, 170.0, 0.0, TAU, 96, Color(0.52, 0.68, 0.67, 0.22), 1.0, true)
	for i in range(8):
		var direction := Vector2.RIGHT.rotated(i * TAU / 8.0)
		draw_line(center + direction * 164.0, center + direction * 176.0, Color(0.52, 0.68, 0.67, 0.4), 2.0, true)

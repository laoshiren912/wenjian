extends "res://scripts/courtyard_world.gd"

const CONFIG = preload("res://scripts/v41_config.gd")
const NAV_CELL := 32.0
var reward_visible := false
var room_cleared := false
var portal_open := false

func build_battle() -> void:
	build_courtyard()
	actors.y_sort_enabled = true
	grid.region = Rect2i(0, 0, 40, 23)
	grid.cell_size = Vector2.ONE * NAV_CELL
	grid.offset = Vector2.ONE * NAV_CELL * 0.5
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for x in range(40):
		for y in range(23):
			var cell := Vector2i(x, y)
			var point := cell_center(cell)
			var safe := Geometry2D.is_point_in_polygon(point, walkable)
			for i in range(walkable.size()):
				if point.distance_to(Geometry2D.get_closest_point_to_segment(point, walkable[i], walkable[(i + 1) % walkable.size()])) < 20.0:
					safe = false
			for lantern in lanterns:
				if point.distance_to(lantern.position) < 42.0:
					safe = false
			grid.set_point_solid(cell, not safe)
			if safe:
				floor_cells.append(cell)
			else:
				blocked[cell] = true

func cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2.ONE * 0.5) * NAV_CELL

func cell_at(point: Vector2) -> Vector2i:
	return Vector2i((point / NAV_CELL).floor())

func nearest_cell(point: Vector2) -> Vector2i:
	var nearest: Vector2i = floor_cells[0]
	var best := INF
	for cell in floor_cells:
		var distance := point.distance_squared_to(cell_center(cell))
		if distance < best:
			nearest = cell
			best = distance
	return nearest

func path_between(start: Vector2, target: Vector2) -> PackedVector2Array:
	return grid.get_point_path(nearest_cell(start), nearest_cell(target))

func _draw() -> void:
	super._draw()
	var color := Color("86f5d3") if portal_open else (Color("e1cc9c") if room_cleared else Color("566b70"))
	draw_circle(CONFIG.EXIT_POINT, 27.0, Color(color, 0.15))
	draw_arc(CONFIG.EXIT_POINT, 27.0, 0.0, TAU, 40, color, 4.0, true)
	if reward_visible:
		var point := CONFIG.REWARD_POINT
		draw_circle(point, CONFIG.REWARD_RADIUS, Color(1, 0.8, 0.3, 0.12))
		draw_colored_polygon(PackedVector2Array([point + Vector2(0, -15), point + Vector2(15, 0), point + Vector2(0, 15), point + Vector2(-15, 0)]), Color("f4d278"))
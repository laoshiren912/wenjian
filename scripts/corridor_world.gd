extends SurvivorWorld

const LEFT := 12
const RIGHT := 27
const TOP := 13
const BOTTOM := 16
const TRIGGER_X: Array[int] = [15, 17, 19, 21, 23, 25]
const PORTAL_CELL := Vector2i(27, 15)
var triggered: Array[bool] = [false, false, false, false, false, false]
var warning_positions: Array[Vector2] = []
var portal_open := false

func build_corridor() -> void:
	random.randomize()
	grid.region = Rect2i(0, 0, COLUMNS, ROWS)
	grid.cell_size = Vector2.ONE * CELL
	grid.offset = Vector2.ONE * CELL * 0.5
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for x in range(COLUMNS):
		for y in range(ROWS):
			if x < LEFT or x > RIGHT or y < TOP or y > BOTTOM:
				grid.set_point_solid(Vector2i(x, y), true)
	for x in range(LEFT - 1, RIGHT + 2):
		_add_wall(Vector2i(x, TOP - 1))
		_add_wall(Vector2i(x, BOTTOM + 1))
	for y in range(TOP, BOTTOM + 1):
		_add_wall(Vector2i(LEFT - 1, y))
		_add_wall(Vector2i(RIGHT + 1, y))
	actors = Node2D.new()
	actors.name = "Actors"
	actors.y_sort_enabled = true
	add_child(actors)
	queue_redraw()

func _draw() -> void:
	var origin := Vector2(LEFT * CELL, TOP * CELL)
	var size := Vector2((RIGHT - LEFT + 1) * CELL, (BOTTOM - TOP + 1) * CELL)
	draw_rect(Rect2(origin, size), Color("172930"))
	for x in range(LEFT - 1, RIGHT + 2):
		for y in range(TOP - 1, BOTTOM + 2):
			var cell := Vector2i(x, y)
			var point := Vector2(x, y) * CELL
			if blocked.has(cell):
				draw_rect(Rect2(point + Vector2.ONE * 2, Vector2.ONE * (CELL - 4)), Color("3a5055"))
			elif (x + y) % 2 == 0:
				draw_rect(Rect2(point, Vector2.ONE * CELL), Color("192c32"))
	for i in range(TRIGGER_X.size()):
		if triggered[i]:
			continue
		var center := cell_center(Vector2i(TRIGGER_X[i], 14))
		draw_rect(Rect2(center.x - 20.0, TOP * CELL, 40.0, size.y), Color(0.2, 0.75, 0.85, 0.08))
		draw_circle(center, 24.0, Color(0.25, 0.75, 0.85, 0.16))
		draw_arc(center, 24.0, 0.0, TAU, 32, Color(0.42, 0.89, 0.94, 0.8), 2.5, true)
	for point in warning_positions:
		draw_circle(point, 23.0, Color(0.85, 0.26, 0.16, 0.18))
		draw_arc(point, 25.0, 0.0, TAU, 32, Color(1.0, 0.55, 0.25, 0.8), 3.0, true)
	var portal := cell_center(PORTAL_CELL)
	var color := Color("86f5d3") if portal_open else Color("566b70")
	draw_circle(portal, 27.0, Color(color.r, color.g, color.b, 0.15))
	draw_arc(portal, 27.0, 0.0, TAU, 40, color, 4.0, true)

extends SurvivorWorld

const LEFT := 12
const RIGHT := 27
const TOP := 10
const BOTTOM := 19

func build_sample() -> void:
	random.seed = 2026
	grid.region = Rect2i(0, 0, COLUMNS, ROWS)
	grid.cell_size = Vector2.ONE * CELL
	grid.offset = Vector2.ONE * CELL * 0.5
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for x in range(COLUMNS):
		for y in range(ROWS):
			var cell := Vector2i(x, y)
			if x < LEFT or x > RIGHT or y < TOP or y > BOTTOM:
				grid.set_point_solid(cell, true)
	for x in range(LEFT - 1, RIGHT + 2):
		_add_wall(Vector2i(x, TOP - 1))
		_add_wall(Vector2i(x, BOTTOM + 1))
	for y in range(TOP, BOTTOM + 1):
		_add_wall(Vector2i(LEFT - 1, y))
		_add_wall(Vector2i(RIGHT + 1, y))
	_add_wall(Vector2i(18, 12))
	_add_wall(Vector2i(21, 17))
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

class_name SurvivorWorld
extends Node2D

const CELL: int = 64
const COLUMNS: int = 40
const ROWS: int = 30
const SIZE := Vector2(COLUMNS * CELL, ROWS * CELL)
const SPAWN := SIZE * 0.5
var grid := AStarGrid2D.new()
var blocked: Dictionary = {}
var floor_cells: Array[Vector2i] = []
var random := RandomNumberGenerator.new()
var actors: Node2D

func build(seed_value: int = 0) -> void:
	if seed_value == 0:
		random.randomize()
	else:
		random.seed = seed_value
	grid.region = Rect2i(0, 0, COLUMNS, ROWS)
	grid.cell_size = Vector2(CELL, CELL)
	grid.offset = Vector2(CELL, CELL) * 0.5
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for x in range(COLUMNS):
		for y in range(ROWS):
			if x == 0 or y == 0 or x == COLUMNS - 1 or y == ROWS - 1:
				_add_wall(Vector2i(x, y))
	# Single-cell pillars, spaced apart: every passage is wider than an actor.
	for attempt in range(500):
		if blocked.size() >= 2 * COLUMNS + 2 * ROWS - 4 + 80:
			break
		var cell := Vector2i(random.randi_range(3, COLUMNS - 4), random.randi_range(3, ROWS - 4))
		if cell_center(cell).distance_to(SPAWN) < 270.0:
			continue
		var clear: bool = true
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				if blocked.has(cell + Vector2i(dx, dy)):
					clear = false
		if clear:
			_add_wall(cell)
	for x in range(1, COLUMNS - 1):
		for y in range(1, ROWS - 1):
			var cell := Vector2i(x, y)
			if not blocked.has(cell):
				floor_cells.append(cell)
	actors = Node2D.new()
	actors.name = "Actors"
	actors.y_sort_enabled = true
	add_child(actors)
	queue_redraw()

func rebuild_floor(player: Node2D) -> void:
	for child in actors.get_children():
		if child != player:
			child.free()
	actors.remove_child(player)
	actors.free()
	for child in get_children():
		if child is StaticBody2D:
			child.free()
	blocked.clear()
	floor_cells.clear()
	grid = AStarGrid2D.new()
	build()
	actors.add_child(player)
	player.global_position = SPAWN
	player.camera.reset_smoothing()

func _add_wall(cell: Vector2i) -> void:
	blocked[cell] = true
	grid.set_point_solid(cell, true)
	var wall := StaticBody2D.new()
	wall.position = cell_center(cell)
	wall.collision_layer = 1
	wall.collision_mask = 0
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(CELL, CELL)
	collider.shape = shape
	wall.add_child(collider)
	add_child(wall)

func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell) * CELL + Vector2.ONE * CELL * 0.5

func cell_at(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / CELL), floori(point.y / CELL))

func path_between(start: Vector2, target: Vector2) -> PackedVector2Array:
	var from_cell := cell_at(start)
	var to_cell := cell_at(target)
	if not grid.is_in_boundsv(from_cell) or not grid.is_in_boundsv(to_cell):
		return PackedVector2Array()
	if grid.is_point_solid(from_cell) or grid.is_point_solid(to_cell):
		return PackedVector2Array()
	return grid.get_point_path(from_cell, to_cell)

func random_spawn(away_from: Vector2, minimum_distance: float = 300.0) -> Vector2:
	for attempt in range(100):
		var cell: Vector2i = floor_cells[random.randi_range(0, floor_cells.size() - 1)]
		var point := cell_center(cell)
		if point.distance_to(away_from) >= minimum_distance and point.distance_to(away_from) < 850.0:
			var occupied: bool = false
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if enemy.global_position.distance_to(point) < 45.0:
					occupied = true
					break
			if not occupied:
				return point
	return Vector2.ZERO

func rear_spawn(origin: Vector2, facing: Vector2) -> Vector2:
	var candidates: Array[Vector2i] = floor_cells.duplicate()
	candidates.shuffle()
	for cell in candidates:
		var point := cell_center(cell)
		var offset := point - origin
		if offset.length() < 350.0 or offset.length() > 700.0 or offset.normalized().dot(facing) > -0.35:
			continue
		var occupied := false
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if enemy.global_position.distance_to(point) < 45.0:
				occupied = true
				break
		if not occupied and not path_between(point, origin).is_empty():
			return point
	# Keep the rear guarantee near walls: retry later rather than spawn in front.
	return Vector2.ZERO

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), Color("172930"))
	for x in range(COLUMNS):
		for y in range(ROWS):
			var cell := Vector2i(x, y)
			var origin := Vector2(x * CELL, y * CELL)
			if blocked.has(cell):
				draw_rect(Rect2(origin + Vector2(0, 5), Vector2(CELL, CELL)), Color("101f27"))
				draw_rect(Rect2(origin + Vector2.ONE * 2, Vector2.ONE * (CELL - 4)), Color("3a5055"))
				draw_line(origin + Vector2(4, 4), origin + Vector2(CELL - 4, 4), Color("5b7070"), 2.0)
			elif (x + y) % 2 == 0:
				draw_rect(Rect2(origin, Vector2(CELL, CELL)), Color("192c32"))
	for x in range(0, COLUMNS + 1):
		draw_line(Vector2(x * CELL, 0), Vector2(x * CELL, SIZE.y), Color(0.35, 0.5, 0.5, 0.06))
	for y in range(0, ROWS + 1):
		draw_line(Vector2(0, y * CELL), Vector2(SIZE.x, y * CELL), Color(0.35, 0.5, 0.5, 0.06))
	draw_arc(SPAWN, 96.0, 0.0, TAU, 64, Color(0.48, 0.85, 0.77, 0.13), 2.0, true)

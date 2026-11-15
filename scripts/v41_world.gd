extends "res://scripts/courtyard_world.gd"

const CONFIG = preload("res://scripts/v41_config.gd")
const NAV_CELL := 32.0
var reward_visible := false
var room_cleared := false
var portal_open := false
var pixel_courtyard: Node2D
var bamboo_room: Node2D
var mountain_steps_room: Node2D
var original_walkable: PackedVector2Array
var boundaries: Array[StaticBody2D] = []
var exit_point := CONFIG.EXIT_POINT
var room2_obstacles: Array[StaticBody2D] = []
var room1_obstacles: Array[StaticBody2D] = []

func build_battle() -> void:
	build_courtyard()
	pixel_courtyard = preload("res://scripts/v41_pixel_courtyard.gd").new()
	add_child(pixel_courtyard)
	bamboo_room = preload("res://scripts/v41_bamboo_room.gd").new()
	add_child(bamboo_room)
	mountain_steps_room = preload("res://scripts/v41_mountain_steps_room.gd").new()
	add_child(mountain_steps_room)
	actors.y_sort_enabled = true
	grid.region = Rect2i(0, 0, 40, 23)
	grid.cell_size = Vector2.ONE * NAV_CELL
	grid.offset = Vector2.ONE * NAV_CELL * 0.5
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	original_walkable = walkable.duplicate()
	boundaries.append(get_node("PaintedFloorBoundary"))
	_add_boundary(PackedVector2Array([Vector2(90, 110), Vector2(1190, 110), Vector2(1190, 610), Vector2(90, 610)]))
	_add_boundary(PackedVector2Array([Vector2(260, 220), Vector2(1050, 220), Vector2(1050, 550), Vector2(260, 550)]))
	for point in [Vector2(490, 320), Vector2(730, 475), Vector2(900, 310)]:
		var body := StaticBody2D.new()
		body.position = point
		body.collision_layer = 0
		body.collision_mask = 0
		var shape := CollisionPolygon2D.new()
		shape.polygon = PackedVector2Array([Vector2(-57, -18), Vector2(-37, -46), Vector2(24, -50), Vector2(57, -17), Vector2(52, 9), Vector2(-48, 9)])
		body.add_child(shape)
		var sprite := Sprite2D.new()
		sprite.texture = preload("res://assets/courtyard/guishan/mountain_rocks.png")
		sprite.scale = Vector2.ONE * 1.8
		sprite.position = Vector2(0, -65)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		body.add_child(sprite)
		add_child(body)
		room2_obstacles.append(body)
	_make_room1_obstacle(Vector2(400, 220), preload("res://assets/courtyard/guishan/mountain_rocks.png"), 1.8, -65.0)
	_make_room1_obstacle(Vector2(925, 590), preload("res://assets/courtyard/guishan/bamboo_grove.png"), 1.7, -60.0)

func _make_room1_obstacle(point: Vector2, texture: Texture2D, factor: float, offset: float) -> void:
	var body := StaticBody2D.new()
	body.position = point
	body.collision_layer = 0
	body.collision_mask = 0
	var shape := CollisionPolygon2D.new()
	shape.polygon = PackedVector2Array([Vector2(-52, -16), Vector2(-38, -42), Vector2(27, -42), Vector2(52, -16), Vector2(48, 8), Vector2(-48, 8)])
	body.add_child(shape)
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.scale = Vector2.ONE * factor
	sprite.position = Vector2(0, offset)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body.add_child(sprite)
	add_child(body)
	room1_obstacles.append(body)
func _add_boundary(polygon: PackedVector2Array) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 0
	body.collision_mask = 0
	body.set_meta("polygon", polygon)
	add_child(body)
	for i in range(polygon.size()):
		var segment := SegmentShape2D.new()
		segment.a = polygon[i]
		segment.b = polygon[(i + 1) % polygon.size()]
		var shape := CollisionShape2D.new()
		shape.shape = segment
		body.add_child(shape)
	boundaries.append(body)

func _rebuild_navigation() -> void:
	floor_cells.clear()
	blocked.clear()
	for x in range(40):
		for y in range(23):
			var cell := Vector2i(x, y)
			var point := cell_center(cell)
			var safe := Geometry2D.is_point_in_polygon(point, walkable)
			for i in range(walkable.size()):
				if point.distance_to(Geometry2D.get_closest_point_to_segment(point, walkable[i], walkable[(i + 1) % walkable.size()])) < 20.0:
					safe = false
			for lantern in lanterns:
				if lantern.collision_layer != 0 and point.distance_to(lantern.position) < 42.0:
					safe = false
			for obstacle in room2_obstacles + room1_obstacles:
				if obstacle.collision_layer != 0:
					var local := point - obstacle.position
					if absf(local.x) < 77.0 and local.y > -70.0 and local.y < 29.0:
						safe = false
			grid.set_point_solid(cell, not safe)
			if safe:
				floor_cells.append(cell)
			else:
				blocked[cell] = true

func set_room_style(room_index: int) -> void:
	var boundary_index := 1 if room_index == 0 else (2 if room_index == 1 else 0)
	for i in range(boundaries.size()):
		boundaries[i].collision_layer = 1 if i == boundary_index else 0
	walkable = original_walkable if boundary_index == 0 else boundaries[boundary_index].get_meta("polygon")
	lanterns[0].position = Vector2(500, 430) if room_index == 1 else Vector2(420, 444)
	lanterns[1].position = Vector2(1070, 485) if room_index == 1 else Vector2(864, 438)
	exit_point = Vector2(1130, 370) if room_index == 0 else (CONFIG.ROOM2_EXIT_POINT if room_index == 1 else CONFIG.EXIT_POINT)
	for lantern in lanterns:
		lantern.visible = room_index > 1
		lantern.collision_layer = 0 if room_index < 2 else 1
	for obstacle in room2_obstacles:
		obstacle.visible = room_index == 1
		obstacle.collision_layer = 1 if room_index == 1 else 0
	for obstacle in room1_obstacles:
		obstacle.visible = room_index == 0
		obstacle.collision_layer = 1 if room_index == 0 else 0
	_rebuild_navigation()
	var is_boss := room_index == CONFIG.BOSS_ROOM
	backdrop.visible = is_boss
	pixel_courtyard.visible = not is_boss and room_index > 1
	bamboo_room.visible = room_index == 0
	mountain_steps_room.visible = room_index == 1
	for lantern in lanterns:
		lantern.bamboo_rock = room_index == 0 or room_index == 1
		lantern.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if room_index == 0 or room_index == 1 else CanvasItem.TEXTURE_FILTER_PARENT_NODE
		lantern.queue_redraw()
	for child in get_children():
		if child is Polygon2D and child.texture == backdrop.texture:
			child.visible = is_boss

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
	draw_circle(exit_point, 27.0, Color(color, 0.15))
	draw_arc(exit_point, 27.0, 0.0, TAU, 40, color, 4.0, true)

extends "res://scripts/courtyard_world.gd"

const CONFIG = preload("res://scripts/v41_config.gd")
const ROOM_BACKGROUNDS := [
	preload("res://assets/courtyard/rooms2-7/room02_mountain_path.png"),
	preload("res://assets/courtyard/rooms2-7/room03_cliff_walkway.png"),
	preload("res://assets/courtyard/rooms2-7/room04_peak_temple.png"),
	preload("res://assets/courtyard/rooms2-7/room05_floating_ruins.png"),
	preload("res://assets/courtyard/rooms2-7/room06_heaven_gate.png"),
	preload("res://assets/courtyard/rooms2-7/room07_immortal_platform.png"),
]
const NAV_CELL := 32.0
const ROOM1_MOVEMENT_LAYER := 1 << 3
const ROOM1_NAV_CLEARANCE := 24.0
const ROOM1_EXIT_TRIGGER := Rect2(575, 216, 130, 50)
const ROOM_EXIT_RADIUS := 28.0
# The northern recess ends at the rear threshold. The walls flank the opening.
const ROOM1_FLOOR_OUTLINE := [
	Vector2(24, 321), Vector2(145, 321), Vector2(201, 292), Vector2(189, 253),
	Vector2(240, 227), Vector2(337, 204), Vector2(380, 195), Vector2(472, 193),
	Vector2(490, 205), Vector2(498, 126), Vector2(772, 126), Vector2(781, 204),
	Vector2(878, 211), Vector2(972, 224), Vector2(1075, 222), Vector2(1113, 237),
	Vector2(1097, 286), Vector2(1147, 320), Vector2(1256, 332),
	Vector2(1256, 395), Vector2(1172, 430), Vector2(1090, 476), Vector2(1084, 555),
	Vector2(1044, 582), Vector2(973, 617), Vector2(920, 660), Vector2(899, 699),
	Vector2(330, 699), Vector2(314, 668), Vector2(272, 633), Vector2(251, 589),
	Vector2(193, 582), Vector2(156, 537), Vector2(83, 524), Vector2(75, 468),
	Vector2(24, 432),
]
const ROOM1_GATE_WALLS := [Rect2(498, 120, 107, 80), Rect2(668, 120, 104, 80)]

# Room 5's stone floor, inward of the cliff faces and detached rubble.
const FLOATING_RUINS_OUTLINE := [
	Vector2(242, 222), Vector2(310, 203), Vector2(372, 175), Vector2(428, 155),
	Vector2(522, 162), Vector2(610, 156), Vector2(741, 148), Vector2(891, 163),
	Vector2(964, 192), Vector2(1034, 230), Vector2(1110, 268), Vector2(1148, 320),
	Vector2(1149, 372), Vector2(1121, 428), Vector2(1079, 462), Vector2(1010, 487),
	Vector2(918, 518), Vector2(797, 541), Vector2(683, 550), Vector2(549, 548),
	Vector2(471, 531), Vector2(401, 514), Vector2(310, 511), Vector2(246, 478),
	Vector2(193, 428), Vector2(171, 393), Vector2(138, 357), Vector2(144, 305),
	Vector2(181, 256),
]
# The outer masonry rim, with the lower staircase closed at the platform lip.
const BOSS_PLATFORM_OUTLINE := [
	Vector2(220, 220), Vector2(474, 108), Vector2(808, 108), Vector2(1061, 220),
	Vector2(1127, 435), Vector2(887, 606), Vector2(395, 606), Vector2(152, 435),
]
var reward_visible := false
var room_cleared := false
var portal_open := false
var bamboo_room: Node2D
var original_walkable: PackedVector2Array
var boundaries: Array[StaticBody2D] = []
var cliff_walkway_boundary: StaticBody2D
var floating_ruins_boundary: StaticBody2D
var heaven_gate_boundary: StaticBody2D
var boss_platform_boundary: StaticBody2D
var steles_by_room: Dictionary[int, Array] = {}
var depth_props: Array[StaticBody2D] = []
var has_exit := false
var exit_point := Vector2.ZERO
var room2_obstacles: Array[StaticBody2D] = []
var room1_obstacles: Array[StaticBody2D] = []
var terrain_movement_mask := 1

func build_battle() -> void:
	build_courtyard(false)
	# The old courtyard cutouts are specific to its painting, not the new single-layer maps.
	for child in get_children():
		if child is Polygon2D and child.texture == backdrop.texture:
			child.hide()
	backdrop.scale = Vector2.ONE
	backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bamboo_room = preload("res://scenes/v41_room1_visual.tscn").instantiate()
	add_child(bamboo_room)
	actors.y_sort_enabled = true
	grid.region = Rect2i(0, 0, 40, 23)
	grid.cell_size = Vector2.ONE * NAV_CELL
	grid.offset = Vector2.ONE * NAV_CELL * 0.5
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	original_walkable = walkable.duplicate()
	boundaries.append(get_node("PaintedFloorBoundary"))
	_add_boundary(PackedVector2Array(ROOM1_FLOOR_OUTLINE))
	_add_boundary(PackedVector2Array([Vector2(260, 220), Vector2(1050, 220), Vector2(1050, 550), Vector2(260, 550)]))
	cliff_walkway_boundary = _add_boundary(_cliff_walkway_outline())
	floating_ruins_boundary = _add_boundary(PackedVector2Array(FLOATING_RUINS_OUTLINE))
	heaven_gate_boundary = _add_boundary(_heaven_gate_outline())
	boss_platform_boundary = _add_boundary(PackedVector2Array(BOSS_PLATFORM_OUTLINE))
	_build_steles()
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
	for wall_rect: Rect2 in ROOM1_GATE_WALLS:
		var wall := StaticBody2D.new()
		wall.position = wall_rect.get_center()
		wall.collision_layer = 0
		wall.collision_mask = 0
		var collider := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = wall_rect.size
		collider.shape = shape
		wall.add_child(collider)
		add_child(wall)
		room1_obstacles.append(wall)

func _cliff_walkway_outline() -> PackedVector2Array:
	# Keep the old perimeter except for the stone apron below the northeast bridge.
	var outline := original_walkable.duplicate()
	var start := outline[2]
	var end := outline[3]
	var apron := PackedVector2Array([
		start.lerp(end, inverse_lerp(start.x, end.x, 880.0)),
		Vector2(936, 219), Vector2(982, 203), Vector2(1012, 209),
		Vector2(1067, 228), Vector2(1116, 256),
		start.lerp(end, inverse_lerp(start.x, end.x, 1160.0)),
	])
	for i in range(apron.size()):
		outline.insert(3 + i, apron[i])
	return outline

func _heaven_gate_outline() -> PackedVector2Array:
	# Keep the original northern edges where they reach the new side rails.
	var left_north := original_walkable[0].lerp(original_walkable[1],
		inverse_lerp(original_walkable[0].x, original_walkable[1].x, 200.0))
	var right_north := original_walkable[2].lerp(original_walkable[3],
		inverse_lerp(original_walkable[2].x, original_walkable[3].x, 1080.0))
	return PackedVector2Array([
		left_north, original_walkable[1], original_walkable[2], right_north,
		Vector2(1094, 361), Vector2(1077, 396), Vector2(1075, 474), Vector2(1122, 483),
		Vector2(1138, 538), Vector2(1040, 538), Vector2(1035, 576),
		Vector2(804, 593), Vector2(779, 604), Vector2(500, 604),
		Vector2(477, 593), Vector2(245, 576), Vector2(241, 538), Vector2(142, 538),
		Vector2(158, 483), Vector2(205, 474), Vector2(203, 396), Vector2(186, 361),
	])

func _build_steles() -> void:
	# Pixel silhouettes sampled from the room textures. Sort at ground level,
	# and use only the stone bases for collision and navigation.
	_add_stele(3, Vector2(401, 234), [
		Vector2(348, 217), Vector2(365, 198), Vector2(367, 137), Vector2(355, 128),
		Vector2(356, 109), Vector2(365, 95), Vector2(373, 91), Vector2(380, 73),
		Vector2(395, 65), Vector2(414, 66), Vector2(426, 75), Vector2(431, 91),
		Vector2(443, 100), Vector2(448, 114), Vector2(442, 132), Vector2(441, 200),
		Vector2(454, 219), Vector2(454, 248), Vector2(437, 257), Vector2(365, 260), Vector2(349, 249),
	], [Vector2(349, 218), Vector2(368, 207), Vector2(438, 208), Vector2(454, 220),
		Vector2(454, 248), Vector2(437, 257), Vector2(365, 260), Vector2(349, 249)])
	_add_stele(3, Vector2(871, 235), [
		Vector2(817, 220), Vector2(832, 204), Vector2(833, 135), Vector2(825, 126),
		Vector2(825, 108), Vector2(834, 95), Vector2(843, 89), Vector2(849, 74),
		Vector2(864, 64), Vector2(885, 64), Vector2(898, 74), Vector2(905, 90),
		Vector2(916, 99), Vector2(922, 115), Vector2(915, 132), Vector2(913, 204),
		Vector2(925, 220), Vector2(925, 246), Vector2(907, 258), Vector2(836, 256), Vector2(817, 245),
	], [Vector2(817, 220), Vector2(835, 208), Vector2(911, 208), Vector2(925, 220),
		Vector2(925, 246), Vector2(907, 258), Vector2(836, 256), Vector2(817, 245)])
	_add_stele(3, Vector2(154, 591), [
		Vector2(85, 592), Vector2(100, 574), Vector2(104, 488), Vector2(97, 478),
		Vector2(97, 461), Vector2(104, 445), Vector2(122, 429), Vector2(134, 414),
		Vector2(154, 407), Vector2(169, 409), Vector2(180, 421), Vector2(186, 438),
		Vector2(199, 450), Vector2(207, 469), Vector2(204, 485), Vector2(197, 494),
		Vector2(196, 552), Vector2(219, 572), Vector2(222, 606), Vector2(203, 632),
		Vector2(181, 642), Vector2(111, 642), Vector2(85, 626),
	], [Vector2(85, 592), Vector2(105, 567), Vector2(196, 552), Vector2(219, 572),
		Vector2(222, 606), Vector2(203, 632), Vector2(181, 642), Vector2(111, 642), Vector2(85, 626)])
	_add_stele(3, Vector2(1107, 590), [
		Vector2(1039, 588), Vector2(1056, 572), Vector2(1063, 551), Vector2(1065, 484),
		Vector2(1057, 472), Vector2(1058, 456), Vector2(1065, 445), Vector2(1075, 439),
		Vector2(1083, 422), Vector2(1096, 410), Vector2(1114, 406), Vector2(1129, 412),
		Vector2(1141, 424), Vector2(1146, 439), Vector2(1155, 451), Vector2(1159, 467),
		Vector2(1151, 486), Vector2(1145, 552), Vector2(1171, 577), Vector2(1176, 618),
		Vector2(1157, 635), Vector2(1131, 649), Vector2(1070, 635), Vector2(1040, 617),
	], [Vector2(1039, 588), Vector2(1063, 559), Vector2(1145, 552), Vector2(1171, 577),
		Vector2(1176, 618), Vector2(1157, 635), Vector2(1131, 649), Vector2(1070, 635), Vector2(1040, 617)])
	_add_stele(4, Vector2(383, 284), [
		Vector2(351, 278), Vector2(361, 263), Vector2(361, 251), Vector2(357, 243),
		Vector2(363, 232), Vector2(369, 227), Vector2(371, 219), Vector2(377, 214),
		Vector2(386, 211), Vector2(393, 215), Vector2(398, 227), Vector2(405, 233),
		Vector2(408, 245), Vector2(404, 257), Vector2(412, 270), Vector2(416, 284),
		Vector2(413, 296), Vector2(400, 304), Vector2(376, 307), Vector2(360, 302), Vector2(352, 293),
	], [Vector2(351, 278), Vector2(362, 268), Vector2(401, 266), Vector2(412, 273),
		Vector2(416, 284), Vector2(413, 296), Vector2(400, 304), Vector2(376, 307), Vector2(360, 302), Vector2(352, 293)])
	_add_stele(4, Vector2(883, 266), [
		Vector2(849, 265), Vector2(857, 251), Vector2(862, 244), Vector2(859, 231),
		Vector2(864, 218), Vector2(871, 214), Vector2(871, 204), Vector2(877, 197),
		Vector2(886, 195), Vector2(895, 198), Vector2(899, 208), Vector2(898, 215),
		Vector2(905, 223), Vector2(908, 236), Vector2(901, 249), Vector2(910, 255),
		Vector2(915, 267), Vector2(910, 280), Vector2(900, 286), Vector2(871, 286), Vector2(853, 279),
	], [Vector2(849, 265), Vector2(857, 251), Vector2(900, 248), Vector2(910, 255),
		Vector2(915, 267), Vector2(910, 280), Vector2(900, 286), Vector2(871, 286), Vector2(853, 279)])

func _add_stele(room_index: int, anchor: Vector2, silhouette: Array, footprint: Array) -> void:
	var body := StaticBody2D.new()
	body.position = anchor
	body.collision_layer = 0
	body.collision_mask = 0
	body.hide()
	var base := CollisionPolygon2D.new()
	base.position = -anchor
	base.polygon = PackedVector2Array(footprint)
	body.add_child(base)
	var mask := Polygon2D.new()
	mask.position = -anchor
	mask.polygon = PackedVector2Array(silhouette)
	mask.uv = mask.polygon
	mask.texture = ROOM_BACKGROUNDS[room_index - 1]
	mask.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body.add_child(mask)
	body.set_meta("footprint", base.polygon)
	add_child(body)
	if not steles_by_room.has(room_index):
		steles_by_room[room_index] = []
	steles_by_room[room_index].append(body)

func _add_boundary(polygon: PackedVector2Array) -> StaticBody2D:
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
	return body

func _near_outline(point: Vector2, outline: PackedVector2Array, clearance: float) -> bool:
	for i in range(outline.size()):
		var closest := Geometry2D.get_closest_point_to_segment(point, outline[i], outline[(i + 1) % outline.size()])
		if point.distance_to(closest) < clearance:
			return true
	return false

func _rebuild_navigation(room_index: int) -> void:
	var first_room := room_index == 0
	var steles: Array = steles_by_room.get(room_index, [])
	floor_cells.clear()
	blocked.clear()
	var clearance := ROOM1_NAV_CLEARANCE if first_room else 20.0
	for x in range(40):
		for y in range(23):
			var cell := Vector2i(x, y)
			var point := cell_center(cell)
			var safe := Geometry2D.is_point_in_polygon(point, walkable)
			safe = safe and not _near_outline(point, walkable, clearance)
			for lantern in lanterns:
				if lantern.collision_layer != 0 and point.distance_to(lantern.position) < 42.0:
					safe = false
			for obstacle in room2_obstacles:
				if obstacle.collision_layer != 0:
					var local := point - obstacle.position
					if absf(local.x) < 77.0 and local.y > -70.0 and local.y < 29.0:
						safe = false
			for stele: StaticBody2D in steles:
				var footprint: PackedVector2Array = stele.get_meta("footprint")
				if Geometry2D.is_point_in_polygon(point, footprint) or _near_outline(point, footprint, clearance):
					safe = false
			if first_room:
				for wall_rect: Rect2 in ROOM1_GATE_WALLS:
					if wall_rect.grow(clearance).has_point(point):
						safe = false
			grid.set_point_solid(cell, not safe)
			if safe:
				floor_cells.append(cell)
			else:
				blocked[cell] = true

func set_room_style(room_index: int) -> void:
	var first_room := room_index == 0
	var active_boundary := boundaries[1 if first_room else (2 if room_index == 1 else 0)]
	match room_index:
		2: active_boundary = cliff_walkway_boundary
		CONFIG.FLOATING_RUINS_ROOM: active_boundary = floating_ruins_boundary
		5: active_boundary = heaven_gate_boundary
		CONFIG.BOSS_ROOM: active_boundary = boss_platform_boundary
	for boundary in boundaries:
		boundary.collision_layer = 0
	var perimeter_layer := ROOM1_MOVEMENT_LAYER if first_room else 1
	active_boundary.collision_layer = perimeter_layer
	terrain_movement_mask = 1 | perimeter_layer
	walkable = original_walkable if active_boundary == boundaries[0] else active_boundary.get_meta("polygon")
	has_exit = room_index < CONFIG.BOSS_ROOM
	exit_point = CONFIG.ROOM_EXIT_POINTS[room_index] if has_exit else Vector2.ZERO
	if first_room:
		exit_point = ROOM1_EXIT_TRIGGER.get_center()
	for obstacle in room2_obstacles:
		obstacle.visible = room_index == 1
		obstacle.collision_layer = 1 if room_index == 1 else 0
	for obstacle in room1_obstacles:
		obstacle.visible = room_index == 0
		obstacle.collision_layer = 1 if room_index == 0 else 0
	for index: int in steles_by_room:
		for stele: StaticBody2D in steles_by_room[index]:
			stele.visible = room_index == index
			stele.collision_layer = 1 if room_index == index else 0
	for prop in depth_props:
		prop.z_index = 0
	depth_props.clear()
	if room_index == 1:
		depth_props.assign(room2_obstacles)
	else:
		depth_props.assign(steles_by_room.get(room_index, []))
	depth_props.sort_custom(func(a, b): return a.position.y < b.position.y)
	for i in range(depth_props.size()):
		depth_props[i].z_index = 4 * (i + 1)
	_rebuild_navigation(room_index)
	if not first_room:
		backdrop.texture = ROOM_BACKGROUNDS[room_index - 1]
	backdrop.visible = not first_room
	bamboo_room.visible = first_room
	bamboo_room.set_cloud_shadows_active(first_room)

func _process(delta: float) -> void:
	super._process(delta)
	if depth_props.is_empty():
		return
	# The sword uses relative Z 0..2. Reserve room for all of an actor's passes
	# between each prop, below the combat feedback at Z 20.
	for actor in actors.get_children():
		if actor is CharacterBody2D:
			var depth := 0
			for i in range(depth_props.size()):
				if actor.position.y <= depth_props[i].position.y:
					break
				depth = 4 * (i + 1) + 1
			actor.z_index = depth

func at_exit(point: Vector2) -> bool:
	if not has_exit:
		return false
	if bamboo_room.visible:
		return ROOM1_EXIT_TRIGGER.has_point(point)
	return point.distance_squared_to(exit_point) <= ROOM_EXIT_RADIUS * ROOM_EXIT_RADIUS

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
	if not has_exit:
		return
	var color := Color("86f5d3") if portal_open else (Color("e1cc9c") if room_cleared else Color("566b70"))
	var radius := 22.0 if bamboo_room.visible else ROOM_EXIT_RADIUS
	draw_circle(exit_point, radius, Color(color, 0.15))
	draw_arc(exit_point, radius, 0.0, TAU, 40, color, 4.0, true)

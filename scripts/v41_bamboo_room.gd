extends Node2D

const TERRAIN = preload("res://assets/courtyard/guishan/terrain.png")
const DENSE_BAMBOO = preload("res://assets/courtyard/guishan/dense_bamboo.png")
const BAMBOO = preload("res://assets/courtyard/guishan/bamboo_grove.png")
const FERNS = preload("res://assets/courtyard/guishan/ferns.png")
const ROCKS = preload("res://assets/courtyard/guishan/mountain_rocks.png")
const STELE = preload("res://assets/courtyard/guishan/wayfinding_stele.png")
const EARTH_TILES := {
	0: 1, 1: 2, 2: 3, 3: 4, 4: 5, 5: 6, 6: 7, 7: 8, 8: 9, 9: 10,
	10: 11, 11: 12, 12: 13, 13: 14, 14: 15, 15: 16, 19: 17, 23: 18,
	27: 19, 31: 20, 38: 21, 39: 22, 46: 23, 47: 24, 55: 25, 63: 26,
	76: 27, 77: 28, 78: 29, 79: 30, 95: 31, 110: 32, 111: 33, 127: 34,
	137: 35, 139: 36, 141: 37, 143: 38, 155: 39, 159: 40, 175: 41,
	191: 42, 205: 43, 207: 44, 223: 45, 239: 46, 255: 47,
}

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = -9

func _is_path(x: int, y: int) -> bool:
	x = clampi(x, 0, 39)
	var upper := 9 if x in range(14, 22) else (11 if x in range(28, 32) else 10)
	var lower := 11 if x in range(17, 24) else (13 if x in range(25, 34) else 12)
	return y >= upper and y <= lower

func _path_tile(x: int, y: int) -> int:
	if not _is_path(x, y):
		return 0
	var mask := 0
	var top := _is_path(x, y - 1)
	var right := _is_path(x + 1, y)
	var bottom := _is_path(x, y + 1)
	var left := _is_path(x - 1, y)
	if top: mask |= 1
	if right: mask |= 2
	if bottom: mask |= 4
	if left: mask |= 8
	if top and right and _is_path(x + 1, y - 1): mask |= 16
	if bottom and right and _is_path(x + 1, y + 1): mask |= 32
	if bottom and left and _is_path(x - 1, y + 1): mask |= 64
	if top and left and _is_path(x - 1, y - 1): mask |= 128
	return EARTH_TILES[mask]

func _draw() -> void:
	# Use the atlas transition masks to follow the gently bending path.
	for y in range(23):
		for x in range(40):
			var tile := _path_tile(x, y)
			var source := Rect2((tile % 16) * 32, int(tile / 16) * 32, 32, 32)
			draw_texture_rect_region(TERRAIN, Rect2(x * 32, y * 32, 32, 32), source)
	# Decorations are drawn behind the actors and carry no collision shapes.
	for item in [
		[DENSE_BAMBOO, Vector2(15, 20), 0.8], [DENSE_BAMBOO, Vector2(1030, 20), 0.8],
		[DENSE_BAMBOO, Vector2(0, 420), 0.7], [DENSE_BAMBOO, Vector2(1080, 420), 0.7],
		[FERNS, Vector2(218, 135), 0.75], [FERNS, Vector2(968, 135), 0.75],
		[FERNS, Vector2(180, 530), 0.75], [FERNS, Vector2(1000, 530), 0.75],
		[ROCKS, Vector2(75, 280), 0.75], [ROCKS, Vector2(1130, 280), 0.75],
		[STELE, Vector2(245, 225), 0.6]]:
		var texture: Texture2D = item[0]
		var point: Vector2 = item[1]
		draw_texture_rect(texture, Rect2(point, texture.get_size() * float(item[2])), false)
	# Exclude stray detached pixels at the left and right edges of this source.
	for point in [Vector2(330, 105), Vector2(870, 105), Vector2(255, 535), Vector2(945, 535)]:
		draw_texture_rect_region(BAMBOO, Rect2(point, Vector2(85, 96) * 0.85), Rect2(8, 0, 85, 96))
	for point in [Vector2(180, 240), Vector2(1065, 235), Vector2(360, 550), Vector2(860, 555)]:
		draw_texture_rect(FERNS, Rect2(point, Vector2(32, 24)), false)

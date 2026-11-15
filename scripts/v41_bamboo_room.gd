extends Node2D

const TERRAIN = preload("res://assets/courtyard/guishan/terrain.png")
const DENSE_BAMBOO = preload("res://assets/courtyard/guishan/dense_bamboo.png")
const BAMBOO = preload("res://assets/courtyard/guishan/bamboo_grove.png")
const FERNS = preload("res://assets/courtyard/guishan/ferns.png")
const ROCKS = preload("res://assets/courtyard/guishan/mountain_rocks.png")
const STELE = preload("res://assets/courtyard/guishan/wayfinding_stele.png")

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = -9

func _draw() -> void:
	# The path crosses the room from the existing entrance to the exit.
	# Atlas IDs 0, 32, 47, 39 are grass, upper edge, earth, lower edge.
	for y in range(23):
		var tile := 32 if y == 10 else (47 if y == 11 else (39 if y == 12 else 0))
		var source := Rect2((tile % 16) * 32, int(tile / 16) * 32, 32, 32)
		for x in range(40):
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

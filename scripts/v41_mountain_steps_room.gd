extends Node2D
const TERRAIN = preload("res://assets/courtyard/guishan/terrain.png")
const ROCKS = preload("res://assets/courtyard/guishan/mountain_rocks.png")
const BAMBOO = preload("res://assets/courtyard/guishan/bamboo_grove.png")
func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = -9
func _draw() -> void:
	for y in range(23):
		for x in range(40):
			draw_texture_rect_region(TERRAIN, Rect2(x * 32, y * 32, 32, 32), Rect2(0, 0, 32, 32))
	for x in range(190, 1100, 70):
		var texture = ROCKS if x % 3 == 0 else BAMBOO
		draw_texture_rect(texture, Rect2(x, 125, 96, 96), false)
		draw_texture_rect(ROCKS if x % 2 == 0 else BAMBOO, Rect2(x, 550, 96, 96), false)
	for y in [200, 265, 445, 510]:
		draw_texture_rect(ROCKS, Rect2(168, y, 92, 92), false)
		draw_texture_rect(BAMBOO if y == 265 else ROCKS, Rect2(1050, y, 92, 92), false)

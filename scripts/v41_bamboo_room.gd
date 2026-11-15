extends Node2D

const TERRAIN = preload("res://assets/courtyard/guishan/terrain.png")
const BAMBOO = preload("res://assets/courtyard/guishan/bamboo_grove.png")
const ROCKS = preload("res://assets/courtyard/guishan/mountain_rocks.png")
const STELE = preload("res://assets/courtyard/guishan/wayfinding_stele.png")

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = -9

func _draw() -> void:
	for y in range(23):
		for x in range(40):
			draw_texture_rect_region(TERRAIN, Rect2(x * 32, y * 32, 32, 32), Rect2(0, 0, 32, 32))
	# Pictures outside the walkable polygon are blocked by the room boundary.
	for x in range(190, 1100, 75):
		draw_texture_rect(BAMBOO if x % 2 == 0 else ROCKS, Rect2(x, 124, 96, 96), false)
		draw_texture_rect(ROCKS if x % 2 == 0 else BAMBOO, Rect2(x, 550, 96, 96), false)
	for y in [205, 270, 435, 500]:
		draw_texture_rect(ROCKS, Rect2(165, y, 95, 95), false)
		draw_texture_rect(BAMBOO, Rect2(1050, y, 95, 95), false)
	# Wayfinding markers sit outside the collision boundary at the entry and exit.
	draw_texture_rect(STELE, Rect2(170, 320, 88, 88), false)
	draw_texture_rect(STELE, Rect2(1052, 320, 88, 88), false)

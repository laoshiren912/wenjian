extends Node2D

const TERRAIN = preload("res://assets/courtyard/guishan/terrain.png")
const STEPS = preload("res://assets/courtyard/guishan/stone_steps.png")
const ROCKS = preload("res://assets/courtyard/guishan/mountain_rocks.png")
const STEPPING_ROCKS = preload("res://assets/courtyard/guishan/stepping_rocks.png")
const FERNS = preload("res://assets/courtyard/guishan/ferns.png")
const BAMBOO = preload("res://assets/courtyard/guishan/bamboo_grove.png")
const STELE = preload("res://assets/courtyard/guishan/wayfinding_stele.png")

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = -9

func _draw() -> void:
	# Atlas tile 94 is the original grey-green stone ground.
	var source := Rect2((94 % 16) * 32, int(94 / 16) * 32, 32, 32)
	for y in range(23):
		for x in range(40):
			draw_texture_rect_region(TERRAIN, Rect2(x * 32, y * 32, 32, 32), source)
	# Background-only props stay at the edges, away from the entrance and exit.
	for item in [
		[STEPS, Vector2(105, 85), 0.85], [STEPS, Vector2(1060, 85), 0.85],
		[STEPS, Vector2(105, 520), 0.85], [STEPS, Vector2(1060, 520), 0.85],
		[ROCKS, Vector2(25, 195), 0.8], [ROCKS, Vector2(1160, 195), 0.8],
		[ROCKS, Vector2(30, 470), 0.8], [ROCKS, Vector2(1160, 470), 0.8],
		[STEPPING_ROCKS, Vector2(220, 95), 0.65], [STEPPING_ROCKS, Vector2(950, 95), 0.65],
		[STEPPING_ROCKS, Vector2(225, 530), 0.65], [STEPPING_ROCKS, Vector2(950, 530), 0.65],
		[FERNS, Vector2(355, 110), 0.55], [FERNS, Vector2(860, 530), 0.55],
		[BAMBOO, Vector2(35, 70), 0.75], [BAMBOO, Vector2(1170, 530), 0.75],
		[STELE, Vector2(205, 205), 0.55]]:
		var texture: Texture2D = item[0]
		draw_texture_rect(texture, Rect2(item[1], texture.get_size() * float(item[2])), false)

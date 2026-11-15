extends Node2D

const TERRAIN = preload("res://assets/courtyard/guishan/terrain.png")
const STEPS = preload("res://assets/courtyard/guishan/stone_steps.png")
const ROCKS = preload("res://assets/courtyard/guishan/mountain_rocks.png")
const STEPPING_ROCKS = preload("res://assets/courtyard/guishan/stepping_rocks.png")
const FERNS = preload("res://assets/courtyard/guishan/ferns.png")

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = -9

func _draw() -> void:
	# Match the first room's three tile rows: top edge, path, bottom edge.
	# The stone atlas uses the same masks as the first room's earth tiles.
	for y in range(23):
		var tile := 79 if y == 10 else (94 if y == 11 else (86 if y == 12 else 0))
		var source := Rect2((tile % 16) * 32, int(tile / 16) * 32, 32, 32)
		for x in range(40):
			draw_texture_rect_region(TERRAIN, Rect2(x * 32, y * 32, 32, 32), source)
	# Overlapping background props make two bands, with no collision shapes.
	for item in [
		[ROCKS, Vector2(35, 105), 0.9], [STEPPING_ROCKS, Vector2(100, 105), 0.8],
		[STEPS, Vector2(190, 105), 0.9], [ROCKS, Vector2(255, 100), 0.9],
		[STEPPING_ROCKS, Vector2(325, 110), 0.8], [ROCKS, Vector2(410, 100), 0.9],
		[STEPS, Vector2(490, 110), 0.9], [STEPPING_ROCKS, Vector2(555, 100), 0.8],
		[ROCKS, Vector2(650, 105), 0.9], [STEPS, Vector2(730, 110), 0.9],
		[STEPPING_ROCKS, Vector2(800, 105), 0.8], [ROCKS, Vector2(890, 100), 0.9],
		[STEPS, Vector2(970, 110), 0.9], [STEPPING_ROCKS, Vector2(1035, 105), 0.8],
		[ROCKS, Vector2(1140, 105), 0.9],
		[ROCKS, Vector2(35, 520), 0.9], [STEPPING_ROCKS, Vector2(100, 520), 0.8],
		[STEPS, Vector2(190, 525), 0.9], [ROCKS, Vector2(255, 520), 0.9],
		[STEPPING_ROCKS, Vector2(325, 525), 0.8], [ROCKS, Vector2(410, 520), 0.9],
		[STEPS, Vector2(490, 525), 0.9], [STEPPING_ROCKS, Vector2(555, 520), 0.8],
		[ROCKS, Vector2(650, 520), 0.9], [STEPS, Vector2(730, 525), 0.9],
		[STEPPING_ROCKS, Vector2(800, 520), 0.8], [ROCKS, Vector2(890, 520), 0.9],
		[STEPS, Vector2(970, 525), 0.9], [STEPPING_ROCKS, Vector2(1035, 520), 0.8],
		[ROCKS, Vector2(1140, 520), 0.9],
		[FERNS, Vector2(355, 145), 0.45], [FERNS, Vector2(845, 140), 0.45],
		[FERNS, Vector2(355, 555), 0.45], [FERNS, Vector2(845, 555), 0.45]]:
		var texture: Texture2D = item[0]
		draw_texture_rect(texture, Rect2(item[1], texture.get_size() * float(item[2])), false)

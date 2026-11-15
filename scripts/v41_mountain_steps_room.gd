extends Node2D

const TERRAIN = preload("res://assets/courtyard/guishan/terrain.png")
const STEPS = preload("res://assets/courtyard/guishan/stone_steps.png")
const ROCKS = preload("res://assets/courtyard/guishan/mountain_rocks.png")
const STEPPING_ROCKS = preload("res://assets/courtyard/guishan/stepping_rocks.png")
const FERNS = preload("res://assets/courtyard/guishan/ferns.png")
const BAMBOO = preload("res://assets/courtyard/guishan/bamboo_grove.png")

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
	# Uneven clusters remain on the background layer, without collision.
	for item in [
		[ROCKS, Vector2(38, 112), 0.95], [FERNS, Vector2(93, 150), 0.48],
		[STEPPING_ROCKS, Vector2(126, 96), 0.72], [BAMBOO, Vector2(218, 97), 0.8],
		[ROCKS, Vector2(275, 124), 0.78], [STEPS, Vector2(340, 108), 0.85],
		[STEPPING_ROCKS, Vector2(405, 130), 0.68],
		[ROCKS, Vector2(565, 106), 0.9], [BAMBOO, Vector2(624, 95), 0.75],
		[FERNS, Vector2(679, 149), 0.42], [STEPPING_ROCKS, Vector2(739, 112), 0.82],
		[ROCKS, Vector2(842, 125), 0.84], [STEPS, Vector2(911, 98), 0.95],
		[FERNS, Vector2(978, 144), 0.48], [ROCKS, Vector2(1104, 106), 0.95],
		[STEPPING_ROCKS, Vector2(1167, 129), 0.62],
		[BAMBOO, Vector2(43, 511), 0.78], [ROCKS, Vector2(98, 542), 0.85],
		[STEPPING_ROCKS, Vector2(163, 516), 0.82], [FERNS, Vector2(255, 558), 0.47],
		[ROCKS, Vector2(291, 525), 0.95], [STEPS, Vector2(359, 540), 0.8],
		[STEPPING_ROCKS, Vector2(419, 516), 0.72],
		[BAMBOO, Vector2(554, 515), 0.85], [ROCKS, Vector2(613, 539), 0.82],
		[FERNS, Vector2(672, 558), 0.46], [STEPPING_ROCKS, Vector2(735, 530), 0.77],
		[STEPS, Vector2(824, 516), 0.9], [ROCKS, Vector2(893, 540), 0.96],
		[BAMBOO, Vector2(1004, 516), 0.72], [STEPPING_ROCKS, Vector2(1062, 535), 0.75],
		[ROCKS, Vector2(1152, 515), 0.86]]:
		var texture: Texture2D = item[0]
		draw_texture_rect(texture, Rect2(item[1], texture.get_size() * float(item[2])), false)
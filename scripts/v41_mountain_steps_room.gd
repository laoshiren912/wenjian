extends Node2D

const TERRAIN = preload("res://assets/courtyard/guishan/terrain.png")
const STEPS = preload("res://assets/courtyard/guishan/stone_steps.png")
const ROCKS = preload("res://assets/courtyard/guishan/mountain_rocks.png")
const STEPPING_ROCKS = preload("res://assets/courtyard/guishan/stepping_rocks.png")
const FERNS = preload("res://assets/courtyard/guishan/ferns.png")
const BAMBOO = preload("res://assets/courtyard/guishan/bamboo_grove.png")
const MASKS := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 19, 23, 27, 31, 38, 39, 46, 47, 55, 63, 76, 77, 78, 79, 95, 110, 111, 127, 137, 139, 141, 143, 155, 159, 175, 191, 205, 207, 223, 239, 255]

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = -9

func _road(x: int, y: int) -> bool:
	return (y >= 10 and y <= 12 and x <= 30) or (x >= 28 and x <= 30 and y >= 10)

func _draw() -> void:
	for y in range(23):
		for x in range(40):
			var tile := 0
			if _road(x, y):
				var n := _road(x, y - 1)
				var e := _road(x + 1, y)
				var s := _road(x, y + 1)
				var w := _road(x - 1, y)
				var mask := (1 if n else 0) + (2 if e else 0) + (4 if s else 0) + (8 if w else 0)
				if n and e and _road(x + 1, y - 1): mask += 16
				if e and s and _road(x + 1, y + 1): mask += 32
				if s and w and _road(x - 1, y + 1): mask += 64
				if w and n and _road(x - 1, y - 1): mask += 128
				tile = 48 + MASKS.find(mask)
			var source := Rect2((tile % 16) * 32, int(tile / 16) * 32, 32, 32)
			draw_texture_rect_region(TERRAIN, Rect2(x * 32, y * 32, 32, 32), source)
	# Three decoration areas remain outside the room boundary.
	for item in [
		[ROCKS, Vector2(65, 55), 1.0], [BAMBOO, Vector2(130, 55), 0.95], [FERNS, Vector2(205, 90), 0.5],
		[STEPS, Vector2(400, 65), 0.9], [ROCKS, Vector2(465, 55), 1.05], [BAMBOO, Vector2(540, 55), 0.9],
		[ROCKS, Vector2(825, 58), 1.0], [STEPPING_ROCKS, Vector2(895, 60), 0.8], [BAMBOO, Vector2(1010, 55), 0.95],
		[ROCKS, Vector2(1155, 215), 1.0], [BAMBOO, Vector2(1200, 205), 0.75],
		[STEPS, Vector2(1160, 390), 0.9], [ROCKS, Vector2(1200, 425), 0.8],
		[ROCKS, Vector2(1155, 585), 1.0], [BAMBOO, Vector2(1210, 580), 0.7],
		[BAMBOO, Vector2(25, 550), 1.15], [ROCKS, Vector2(90, 565), 1.15],
		[STEPPING_ROCKS, Vector2(160, 550), 0.9], [BAMBOO, Vector2(255, 555), 1.05],
		[ROCKS, Vector2(325, 558), 1.0], [FERNS, Vector2(235, 615), 0.55]]:
		var texture: Texture2D = item[0]
		draw_texture_rect(texture, Rect2(item[1], texture.get_size() * float(item[2])), false)
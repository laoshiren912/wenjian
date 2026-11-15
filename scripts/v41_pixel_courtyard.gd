extends Node2D

const TERRAIN = preload("res://assets/courtyard/guishan/terrain.png")
const TREE = preload("res://assets/courtyard/guishan/ginkgo_tree.png")
const BAMBOO = preload("res://assets/courtyard/guishan/bamboo_grove.png")
const LANTERN = preload("res://assets/courtyard/guishan/lantern_post.png")
const COTTAGE = preload("res://assets/courtyard/guishan/mountain_cottage.png")
const ROCKS = preload("res://assets/courtyard/guishan/mountain_rocks.png")
const FENCE = preload("res://assets/courtyard/guishan/wooden_fence.png")

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = -9

func _draw() -> void:
	# Guishan terrain atlas tile 94: fully paved stone, 32 x 32 pixels.
	var stone := Rect2(448, 160, 32, 32)
	for y in range(23):
		for x in range(40):
			draw_texture_rect_region(TERRAIN, Rect2(x * 32, y * 32, 32, 32), stone)
	# All props are pictures on the background layer, outside the fighting floor.
	for item in [
		[TREE, Vector2(65, 110), 0.9], [BAMBOO, Vector2(255, 130), 1.0],
		[COTTAGE, Vector2(576, 85), 1.1], [BAMBOO, Vector2(914, 130), 1.0],
		[TREE, Vector2(1040, 95), 0.9], [ROCKS, Vector2(35, 480), 0.9],
		[ROCKS, Vector2(1150, 485), 0.9], [LANTERN, Vector2(360, 155), 0.65],
		[LANTERN, Vector2(855, 155), 0.65], [FENCE, Vector2(470, 115), 0.8],
		[FENCE, Vector2(732, 115), 0.8]]:
		var texture: Texture2D = item[0]
		var point: Vector2 = item[1]
		var size: Vector2 = texture.get_size() * float(item[2])
		draw_texture_rect(texture, Rect2(point, size), false)

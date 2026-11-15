extends Node2D

const TERRAIN = preload("res://assets/courtyard/guishan/terrain.png")
const BAMBOO = preload("res://assets/courtyard/guishan/bamboo_grove.png")
const DENSE = preload("res://assets/courtyard/guishan/dense_bamboo.png")
const ROCKS = preload("res://assets/courtyard/guishan/mountain_rocks.png")
const FERNS = preload("res://assets/courtyard/guishan/ferns.png")
const STEPS = preload("res://assets/courtyard/guishan/stepping_rocks.png")
const STELE = preload("res://assets/courtyard/guishan/wayfinding_stele.png")

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = -9

func paint_room(second: bool) -> void:
	for y in range(23):
		for x in range(40):
			draw_texture_rect_region(TERRAIN, Rect2(x * 32, y * 32, 32, 32), Rect2(0, 0, 32, 32))
	# Floor decorations are painted beneath all actors and have no physics bodies.
	var spots = [[300,250,28,0],[365,310,24,1],[415,495,30,0],[565,245,22,1],[590,510,28,0],[675,300,20,0],[712,525,25,1],[835,255,29,0],[865,460,24,1],[970,270,28,0],[1010,505,23,1],[315,475,26,0],[950,365,21,0],[550,400,19,1],[760,370,19,0],[375,550,25,1],[1020,230,23,0],[630,555,27,0]]
	for i in range(spots.size()):
		var s = spots[i]
		var p = Vector2(s[0], s[1]) + (Vector2(12, -12) if second and i % 3 == 0 else Vector2.ZERO)
		var size = float(s[2])
		draw_texture_rect(FERNS if s[3] == 0 else STEPS, Rect2(p, Vector2(size * 1.25, size)), false, Color(0.48, 0.55, 0.43, 0.8))
	# Irregular silhouettes stay at the original boundary, separate from collision.
	var top = [[185,124,100,0],[258,137,85,2],[330,118,108,1],[425,130,91,0],[500,120,112,2],[595,138,85,1],[665,119,104,0],[755,133,91,2],[830,115,110,1],[925,132,94,0],[1002,121,100,2]]
	var bottom = [[180,550,104,2],[267,560,90,0],[340,545,110,1],[435,558,88,2],[510,548,105,0],[600,560,91,1],[675,545,110,2],[770,558,90,0],[845,547,106,1],[935,560,90,2],[1010,548,100,0]]
	for row in [top, bottom]:
		for i in range(row.size()):
			var e = row[i]
			var tex: Texture2D = [BAMBOO, DENSE, ROCKS][(e[3] + (1 if second else 0)) % 3]
			var pos = Vector2(e[0], e[1])
			var sz = Vector2(e[2], e[2])
			if i % 3 == 1:
				draw_set_transform(pos + Vector2(sz.x, 0), 0.0, Vector2(-1, 1))
				draw_texture_rect(tex, Rect2(Vector2.ZERO, sz), false)
				draw_set_transform(Vector2.ZERO)
			else:
				draw_texture_rect(tex, Rect2(pos, sz), false)
	for e in [[165,205,94,2],[170,275,87,1],[160,435,104,0],[170,510,90,2],[1050,205,97,0],[1050,275,88,2],[1045,435,105,1],[1050,510,92,0]]:
		draw_texture_rect([BAMBOO, DENSE, ROCKS][(e[3] + (1 if second else 0)) % 3], Rect2(e[0], e[1], e[2], e[2]), false)
	if not second:
		# Crop away the orange foliage on the right of the marker image.
		var source = STELE.get_size()
		for x in [170, 1052]:
			draw_texture_rect_region(STELE, Rect2(x, 320, 49.5, 88), Rect2(0, 0, source.x * 0.5625, source.y))
			draw_texture_rect(FERNS, Rect2(x + 35, 371, 26, 20), false, Color(0.45, 0.52, 0.39, 1))

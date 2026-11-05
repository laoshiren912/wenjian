extends SurvivorWorld

const ART_SIZE := Vector2(1280, 720)
const ART_PATH := "res://assets/courtyard/night_courtyard.png"
const FLOOR_UV := [Vector2(0.055, 0.49), Vector2(0.426, 0.295), Vector2(0.58, 0.295), Vector2(0.945, 0.49), Vector2(0.895, 0.63), Vector2(0.615, 0.874), Vector2(0.386, 0.874), Vector2(0.11, 0.64)]
var walkable := PackedVector2Array()
var lanterns: Array[StaticBody2D] = []
var backdrop: Sprite2D
var elapsed := 0.0
var visitor: SurvivorPlayer

func build_courtyard() -> void:
	var art := load(ART_PATH) as Texture2D
	backdrop = Sprite2D.new()
	backdrop.name = "ApprovedCourtyardArt"
	backdrop.texture = art
	backdrop.centered = false
	backdrop.scale = ART_SIZE / art.get_size()
	backdrop.z_index = -10
	add_child(backdrop)
	for point in FLOOR_UV:
		walkable.append(point * ART_SIZE)
	var boundary := StaticBody2D.new()
	boundary.name = "PaintedFloorBoundary"
	boundary.collision_layer = 1
	boundary.collision_mask = 0
	add_child(boundary)
	for i in range(walkable.size()):
		var segment := SegmentShape2D.new()
		segment.a = walkable[i]
		segment.b = walkable[(i + 1) % walkable.size()]
		var collider := CollisionShape2D.new()
		collider.shape = segment
		boundary.add_child(collider)
	actors = Node2D.new()
	actors.name = "Actors"
	add_child(actors)
	for point in [Vector2(420, 444), Vector2(864, 438)]:
		var lantern := preload("res://scripts/courtyard_lantern.gd").new()
		lantern.position = point
		add_child(lantern)
		lanterns.append(lantern)
	# Reuse the approved painting as exact foreground cutouts, not new artwork.
	# These cover the near terrace faces when a sword/actor overlaps their edge.
	_add_foreground(art, [Vector2(0, 0.62), Vector2(0.095, 0.68), Vector2(0.34, 0.87), Vector2(0.35, 0.84), Vector2(0.375, 0.85), Vector2(0.37, 1), Vector2(0, 1)])
	_add_foreground(art, [Vector2(0.625, 1), Vector2(0.62, 0.85), Vector2(0.65, 0.84), Vector2(0.66, 0.87), Vector2(0.91, 0.68), Vector2(1, 0.62), Vector2(1, 1)])
	queue_redraw()

func _add_foreground(texture: Texture2D, points: Array) -> void:
	var mask := Polygon2D.new()
	mask.name = "ForegroundTerrace"
	mask.texture = texture
	var polygon := PackedVector2Array()
	var uv := PackedVector2Array()
	for point: Vector2 in points:
		polygon.append(point * ART_SIZE)
		uv.append(point * texture.get_size())
	mask.polygon = polygon
	mask.uv = uv
	mask.z_index = 12
	add_child(mask)

func _process(delta: float) -> void:
	elapsed += delta
	if is_instance_valid(visitor):
		for lantern in lanterns:
			lantern.update_depth(visitor.position + Vector2(0, 12), elapsed, delta)
	queue_redraw()

func _draw() -> void:
	# Small drifting fireflies only; the painting supplies the main illumination.
	for i in range(12):
		var point := Vector2(200.0 + fmod(i * 97.0 + elapsed * 4.0, 880.0), 310.0 + fmod(i * 53.0, 220.0))
		point.y += sin(elapsed * 0.7 + i) * 9.0
		var alpha := (0.5 + sin(elapsed * 1.1 + i) * 0.5) * 0.5
		draw_circle(point, 1.3, Color(0.97, 0.83, 0.50, alpha))

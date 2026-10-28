extends Node2D

const ATTRACTION_RADIUS: float = 28.0
const ATTRACTION_SPEED: float = 420.0
const COLLECTION_DISTANCE: float = 23.0

var value: int = 8
var player: CharacterBody2D
var age: float = 0.0
var collected: bool = false

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	age += delta
	if collected or not is_instance_valid(player) or player.dead:
		return
	var distance: float = global_position.distance_to(player.global_position)
	if distance < ATTRACTION_RADIUS:
		# Obstacles also block attraction; pickups stay reachable where enemies die.
		var ray := PhysicsRayQueryParameters2D.create(global_position, player.global_position, 1)
		if get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
			global_position = global_position.move_toward(player.global_position, ATTRACTION_SPEED * delta)
	if global_position.distance_to(player.global_position) < COLLECTION_DISTANCE:
		collected = true
		player.gain_experience(value)
		queue_free()
	queue_redraw()

func _draw() -> void:
	var offset := Vector2(0.0, sin(age * 4.0) * 2.0)
	draw_circle(offset, 11.0, Color(0.45, 0.7, 1.0, 0.12))
	draw_colored_polygon(PackedVector2Array([Vector2(0, -7) + offset, Vector2(5, 0) + offset, Vector2(0, 7) + offset, Vector2(-5, 0) + offset]), Color("8bbaff"))

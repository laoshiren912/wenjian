extends CharacterBody2D

var direction: Vector2 = Vector2.RIGHT
var damage: float = 21.0
var speed: float = 540.0
var max_distance: float = 640.0
var traveled: float = 0.0
var spent: bool = false

func _physics_process(delta: float) -> void:
	if spent:
		return
	var motion: Vector2 = direction * speed * delta
	var collision := move_and_collide(motion)
	traveled += motion.length()
	if collision:
		var body = collision.get_collider()
		if is_instance_valid(body) and body.has_method("take_damage"):
			body.take_damage(damage, direction * 95.0)
		spent = true
		queue_free()
	elif traveled >= max_distance:
		spent = true
		queue_free()
	queue_redraw()

func _draw() -> void:
	draw_line(-direction * 20.0, Vector2.ZERO, Color("7967bf"), 5.0, true)
	draw_circle(Vector2.ZERO, 6.0, Color("c4b4ff"))
	draw_circle(direction * 2.0, 2.5, Color("ffffff"))

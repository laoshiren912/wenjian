extends CharacterBody2D

var direction: Vector2 = Vector2.RIGHT
var damage: float = 21.0
var speed: float = 540.0
var max_distance: float = 640.0
var traveled: float = 0.0
var spent: bool = false
var hostile: bool = false
var camera_shake := true
var sword_energy: bool = false

func _physics_process(delta: float) -> void:
	if spent:
		return
	var motion: Vector2 = direction * speed * delta
	var collision := move_and_collide(motion)
	traveled += motion.length()
	if collision:
		var body = collision.get_collider()
		if is_instance_valid(body) and body.has_method("take_damage"):
			if not hostile and body is SurvivorEnemy:
				body.take_damage(damage, direction * 95.0, false, camera_shake)
			else:
				body.take_damage(damage, direction if hostile else direction * 95.0)
		spent = true
		queue_free()
	elif traveled >= max_distance:
		spent = true
		queue_free()
	queue_redraw()

func _draw() -> void:
	if hostile:
		draw_circle(Vector2.ZERO, 7.0, Color("d695ff"))
		return
	if sword_energy:
		var side := direction.orthogonal()
		draw_line(-direction * 28.0, direction * 6.0, Color(0.5, 0.9, 1.0, 0.55), 5.0, true)
		draw_line(-side * 15.0, side * 15.0, Color("b5f7ff"), 5.0, true)
		return
	var side := direction.orthogonal()
	draw_line(-direction * 22.0, Vector2.ZERO, Color("d5ad70"), 3.0, true)
	draw_colored_polygon(PackedVector2Array([direction * 6.0, -direction * 4.0 + side * 5.0, -direction * 4.0 - side * 5.0]), Color("f3ead0"))
	draw_line(-direction * 22.0 + side * 4.0, -direction * 16.0, Color("d7e6dc"), 2.0, true)
	draw_line(-direction * 22.0 - side * 4.0, -direction * 16.0, Color("d7e6dc"), 2.0, true)

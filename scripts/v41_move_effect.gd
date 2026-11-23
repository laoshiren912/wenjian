extends Node2D

const CONFIG = preload("res://scripts/v41_config.gd")
var kind := "energy"
var direction := Vector2.RIGHT
var damage := 0.0
var distance := 0.0
var radius := 0.0
var elapsed := 0.0
var traveled := 0.0
var targets: Array[Node2D] = []

func _physics_process(delta: float) -> void:
	if kind == "echo":
		elapsed += delta
		if elapsed >= CONFIG.ECHO_DELAY and elapsed - delta < CONFIG.ECHO_DELAY:
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if not enemy.dead and global_position.distance_to(enemy.global_position) <= radius:
					var ray := PhysicsRayQueryParameters2D.create(global_position, enemy.global_position, 1)
					if get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
						enemy.take_damage(damage, Vector2.ZERO)
		if elapsed >= CONFIG.ECHO_DELAY + 0.2:
			queue_free()
	else:
		var step := minf(CONFIG.ENERGY_SPEED * delta, distance - traveled)
		var origin := global_position
		var end := origin + direction * step
		var ray := PhysicsRayQueryParameters2D.create(origin, end, 1)
		var wall := get_world_2d().direct_space_state.intersect_ray(ray)
		if not wall.is_empty():
			end = wall.position
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if enemy.dead or enemy in targets:
				continue
			var nearest := Geometry2D.get_closest_point_to_segment(enemy.global_position, origin, end)
			if nearest.distance_to(enemy.global_position) <= CONFIG.ENERGY_HALF_WIDTH + 15.0:
				var sight := PhysicsRayQueryParameters2D.create(origin, enemy.global_position, 1)
				if get_world_2d().direct_space_state.intersect_ray(sight).is_empty():
					targets.append(enemy)
					enemy.take_damage(damage, direction * 95.0)
		global_position = end
		traveled += step
		if not wall.is_empty() or traveled >= distance:
			queue_free()
	queue_redraw()

func _draw() -> void:
	if kind == "echo":
		var exploded := elapsed >= CONFIG.ECHO_DELAY
		draw_circle(Vector2.ZERO, radius, Color(1.0, 0.65, 0.2, 0.45 if exploded else 0.10))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(1.0, 0.8, 0.4, 0.95), 5.0 if exploded else 2.0)
		draw_circle(Vector2.ZERO, 12.0, Color(0.6, 0.9, 1.0, 0.45))
	else:
		draw_line(-direction.orthogonal() * CONFIG.ENERGY_HALF_WIDTH, direction.orthogonal() * CONFIG.ENERGY_HALF_WIDTH, Color("b5f7ff"), 7.0, true)

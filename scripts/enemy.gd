class_name SurvivorEnemy
extends CharacterBody2D

signal killed(location: Vector2, experience_value: int)
signal damaged(location: Vector2, amount: float)
enum Kind { PASSIVE, HOSTILE }
var kind: int = Kind.HOSTILE
var player: CharacterBody2D
var world: SurvivorWorld
var health_multiplier: float = 1.0
var max_health: float = 180.0
var health: float = 180.0
var speed: float = 105.0
var damage: float = 12.0
var experience_value: int = 10
var aggro: bool = false
var dead: bool = false
var flash: float = 0.0
var knockback: Vector2 = Vector2.ZERO
var attack_cooldown: float = 0.0
var windup: float = 0.0
var attack_direction: Vector2 = Vector2.RIGHT
var path: PackedVector2Array = PackedVector2Array()
var path_index: int = 0
var repath: float = 0.0
var wander_target: Vector2
var wander_timer: float = 2.0

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	if kind == Kind.PASSIVE:
		max_health = 120.0
		speed = 85.0
		damage = 9.0
		experience_value = 8
	max_health *= health_multiplier
	health = max_health
	wander_target = global_position
	wander_timer = world.random.randf_range(1.0, 3.0)
	repath = world.random.randf_range(0.0, 0.4)

func _physics_process(delta: float) -> void:
	if dead or not is_instance_valid(player) or player.dead:
		return
	flash = maxf(0.0, flash - delta)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	repath -= delta
	var distance: float = global_position.distance_to(player.global_position)
	if kind == Kind.HOSTILE and distance < 640.0:
		aggro = true
	var movement := Vector2.ZERO
	if windup > 0.0:
		windup -= delta
		if windup <= 0.0:
			var offset: Vector2 = player.global_position - global_position
			var ray := PhysicsRayQueryParameters2D.create(global_position, player.global_position, 1)
			if offset.length() < 63.0 and absf(attack_direction.angle_to(offset)) < 1.3 and get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
				player.take_damage(damage, offset.normalized())
			attack_cooldown = 0.95
	elif aggro:
		if distance < 45.0:
			if attack_cooldown <= 0.0:
				windup = 0.34
				attack_direction = (player.global_position - global_position).normalized()
		else:
			movement = _follow_path(player.global_position)
	else:
		wander_timer -= delta
		if wander_timer <= 0.0:
			wander_timer = world.random.randf_range(2.0, 4.0)
			var offset := Vector2i(world.random.randi_range(-2, 2), world.random.randi_range(-2, 2))
			var cell: Vector2i = world.cell_at(global_position) + offset
			if world.grid.is_in_boundsv(cell) and not world.grid.is_point_solid(cell):
				wander_target = world.cell_center(cell)
		if global_position.distance_to(wander_target) > 12.0:
			movement = _follow_path(wander_target) * 0.3
	# Soft separation avoids several enemies occupying the same visual position.
	var separation := Vector2.ZERO
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self or other.dead:
			continue
		var offset: Vector2 = global_position - other.global_position
		if offset.length_squared() > 0.01 and offset.length_squared() < 34.0 * 34.0:
			separation += offset.normalized() * 24.0
	velocity = movement * speed + knockback + separation.limit_length(45.0)
	knockback = knockback.move_toward(Vector2.ZERO, 520.0 * delta)
	move_and_slide()
	queue_redraw()

func _follow_path(target: Vector2) -> Vector2:
	var ray := PhysicsRayQueryParameters2D.create(global_position, target, 1)
	if global_position.distance_to(target) < 130.0 and get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
		# Short final approach; obstacle avoidance still uses physical collision.
		return (target - global_position).normalized()
	if path.is_empty() or (repath <= 0.0 and (path_index >= path.size() or global_position.distance_to(path[path_index]) < 18.0)):
		path = world.path_between(global_position, target)
		path_index = 0
		repath = 0.55
	while path_index < path.size() and global_position.distance_to(path[path_index]) < 10.0:
		path_index += 1
	if path_index < path.size():
		return (path[path_index] - global_position).normalized()
	return Vector2.ZERO

func take_damage(amount: float, push: Vector2) -> void:
	if dead:
		return
	aggro = true
	flash = 0.14
	var actual_damage: float = minf(health, amount)
	health -= amount
	damaged.emit(global_position, actual_damage)
	knockback = push
	# Damage interrupts a telegraphed attack.
	windup = 0.0
	attack_cooldown = maxf(attack_cooldown, 0.25)
	if health <= 0.0:
		dead = true
		set_deferred("collision_layer", 0)
		killed.emit(global_position, experience_value)
		queue_free()
	queue_redraw()

func _draw() -> void:
	var color := Color("e47c77") if kind == Kind.HOSTILE else Color("d4bb76")
	if flash > 0.0:
		color = Color.WHITE
	draw_circle(Vector2(0, 5), 17.0, Color(0.0, 0.0, 0.0, 0.22))
	if kind == Kind.HOSTILE:
		draw_colored_polygon(PackedVector2Array([Vector2(0, -18), Vector2(17, 0), Vector2(0, 18), Vector2(-17, 0)]), color)
	else:
		draw_circle(Vector2.ZERO, 15.0, color)
	draw_circle(Vector2(-5, -3), 2.0, Color("263038"))
	draw_circle(Vector2(5, -3), 2.0, Color("263038"))
	if aggro:
		draw_line(Vector2(0, -30), Vector2(0, -24), Color("ffab89"), 2.0)
		draw_circle(Vector2(0, -21), 1.5, Color("ffab89"))
	if health < max_health:
		draw_rect(Rect2(-19, -38, 38, 4), Color("182329"))
		draw_rect(Rect2(-19, -38, 38 * maxf(0.0, health / max_health), 4), color)
	if windup > 0.0:
		var center: float = attack_direction.angle()
		draw_arc(Vector2.ZERO, 48.0, center - 1.1, center + 1.1, 18, Color(1.0, 0.38, 0.25, 0.9), 3.0, true)

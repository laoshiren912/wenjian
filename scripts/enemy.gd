class_name SurvivorEnemy
extends CharacterBody2D

signal killed(location: Vector2, experience_value: int)
signal damaged(location: Vector2, amount: float)
enum Kind { PASSIVE, HOSTILE, RANGED, BOSS }
const PROJECTILE_SCENE = preload("res://scenes/projectile.tscn")
var kind: int = Kind.HOSTILE
var player: CharacterBody2D
var world: SurvivorWorld
var health_multiplier: float = 1.0
var max_health: float = 180.0
var health: float = 180.0
var speed: float = 175.0
var fast_chaser: bool = false
var damage: float = 12.0
var experience_value: int = SurvivorPlayer.XP_ENEMY
var aggro: bool = false
var dead: bool = false
var flash: float = 0.0
var knockback: Vector2 = Vector2.ZERO
var attack_cooldown: float = 0.0
var windup: float = 0.0
var attack_direction: Vector2 = Vector2.RIGHT
var melee_action: String = "idle"
var melee_timer: float = 0.0
var melee_duration: float = 0.0
var melee_released: bool = false
var dodge_cooldown: float = 0.0
var dodge_direction: Vector2 = Vector2.ZERO
var dodge_enabled: bool = true
var emerging: bool = false
var path: PackedVector2Array = PackedVector2Array()
var path_index: int = 0
var repath: float = 0.0
var wander_target: Vector2
var wander_timer: float = 2.0
var special_cooldown: float = 4.0
var special_windup: float = 0.0
@onready var visual: ActorVisual = $VisualRoot

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	if kind == Kind.PASSIVE:
		max_health = 120.0
		speed = 85.0
		damage = 9.0
		experience_value = SurvivorPlayer.XP_PASSIVE
	elif kind == Kind.RANGED:
		max_health = 120.0
		speed = 105.0
		damage = 10.0
	elif kind == Kind.BOSS:
		max_health = 1200.0
		speed = 115.0
		damage = 16.0
		experience_value = SurvivorPlayer.XP_BOSS
	if fast_chaser and kind == Kind.HOSTILE:
		speed = 265.0
	max_health *= health_multiplier
	health = max_health
	wander_target = global_position
	wander_timer = world.random.randf_range(1.0, 3.0)
	repath = world.random.randf_range(0.0, 0.4)
	visual.appearance = 1 if kind == Kind.HOSTILE else 2
	visual.update_pose(Vector2.ZERO, Vector2.DOWN, Color("e47c77") if kind == Kind.HOSTILE else Color("d4bb76"))

func _physics_process(delta: float) -> void:
	if dead or not is_instance_valid(player) or player.dead:
		return
	flash = maxf(0.0, flash - delta)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	repath -= delta
	var distance: float = global_position.distance_to(player.global_position)
	if kind != Kind.PASSIVE:
		aggro = true
	var movement := Vector2.ZERO
	var ranged_has_sight := true
	if kind == Kind.RANGED and distance < 420.0:
		var sight_ray := PhysicsRayQueryParameters2D.create(global_position, player.global_position, 1)
		ranged_has_sight = get_world_2d().direct_space_state.intersect_ray(sight_ray).is_empty()
	special_cooldown = maxf(0.0, special_cooldown - delta)
	if special_windup > 0.0:
		special_windup -= delta
		if special_windup <= 0.0:
			if distance < 125.0:
				var ray := PhysicsRayQueryParameters2D.create(global_position, player.global_position, 1)
				if get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
					player.take_damage(24.0, (player.global_position - global_position).normalized())
			special_cooldown = 5.0
	elif kind == Kind.BOSS and special_cooldown <= 0.0 and distance < 160.0:
		special_windup = 0.9
	elif kind == Kind.HOSTILE:
		movement = _update_melee(delta, distance)
	elif kind == Kind.RANGED and distance < 420.0 and ranged_has_sight:
		if attack_cooldown <= 0.0:
			var shot = PROJECTILE_SCENE.instantiate()
			shot.direction = (player.global_position - global_position).normalized()
			shot.damage = damage
			shot.speed = 300.0
			shot.max_distance = 500.0
			shot.collision_mask = 3
			shot.hostile = true
			get_parent().add_child(shot)
			shot.global_position = global_position + shot.direction * 23.0
			attack_cooldown = 1.7
	elif windup > 0.0:
		windup -= delta
		if windup <= 0.0:
			var offset: Vector2 = player.global_position - global_position
			var ray := PhysicsRayQueryParameters2D.create(global_position, player.global_position, 1)
			if offset.length() < 63.0 and absf(attack_direction.angle_to(offset)) < 1.3 and get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
				player.take_damage(damage, offset.normalized())
			attack_cooldown = 0.65
	elif aggro:
		if distance < 45.0:
			if attack_cooldown <= 0.0:
				windup = 0.25
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
	var look: Vector2 = attack_direction if windup > 0.0 or melee_action in ["windup", "attack"] else get_real_velocity()
	visual.update_pose(get_real_velocity(), look, Color("e47c77") if kind == Kind.HOSTILE else Color("d4bb76"))
	queue_redraw()

func _update_melee(delta: float, distance: float) -> Vector2:
	var offset: Vector2 = player.global_position - global_position
	dodge_cooldown = maxf(0.0, dodge_cooldown - delta)
	if melee_action == "dodge":
		melee_timer -= delta
		if melee_timer <= 0.0:
			melee_action = "recovery"
			melee_timer = 0.25
		return dodge_direction * 1.8
	if melee_action == "windup":
		melee_timer -= delta
		if melee_timer > melee_duration * 0.58 and offset.length() > 0.1:
			attack_direction = attack_direction.slerp(offset.normalized(), minf(1.0, delta * 5.5)).normalized()
		if melee_timer <= 0.0:
			melee_action = "attack"
			melee_duration = 0.5 if fast_chaser else 0.6
			melee_timer = melee_duration
			melee_released = false
		return Vector2.ZERO
	if melee_action == "attack":
		melee_timer -= delta
		var progress := 1.0 - melee_timer / melee_duration
		if not melee_released and progress >= (0.38 if fast_chaser else 0.44):
			melee_released = true
			var ray := PhysicsRayQueryParameters2D.create(global_position, player.global_position, 1)
			if offset.length() < 63.0 and attack_direction.dot(offset.normalized()) >= (0.82 if fast_chaser else 0.65) and get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
				player.take_damage(damage, offset.normalized())
		if melee_timer <= 0.0:
			melee_action = "recovery"
			melee_timer = 0.85 if fast_chaser else 1.25
		return attack_direction * (0.65 if fast_chaser else 0.4) if progress > 0.15 and progress < 0.52 else Vector2.ZERO
	if melee_action == "recovery":
		melee_timer -= delta
		if melee_timer <= 0.0:
			melee_action = "idle"
		return Vector2.ZERO
	if dodge_enabled and dodge_cooldown <= 0.0 and distance < 120.0 and player.weapon.swing_time > 0.0:
		var incoming: Vector2 = player.weapon.swing_direction
		var toward_enemy := -offset.normalized()
		if incoming.dot(toward_enemy) > 0.75:
			dodge_direction = incoming.rotated(PI * 0.5 if get_instance_id() % 2 == 0 else -PI * 0.5)
			melee_action = "dodge"
			melee_timer = 0.22
			dodge_cooldown = 2.5
			return dodge_direction * 1.8
	if distance >= 45.0:
		return _follow_path(player.global_position)
	var attackers := 0
	for other in get_tree().get_nodes_in_group("enemies"):
		if other != self and not other.dead and other.kind == Kind.HOSTILE and other.melee_action in ["windup", "attack"]:
			attackers += 1
	if attackers >= 2:
		return offset.normalized().rotated(PI * 0.5) * 0.4
	melee_action = "windup"
	melee_duration = 0.65 if fast_chaser else 0.85
	melee_timer = melee_duration
	attack_direction = offset.normalized()
	return Vector2.ZERO

func _follow_path(target: Vector2) -> Vector2:
	var ray := PhysicsRayQueryParameters2D.create(global_position, target, 1)
	if global_position.distance_to(target) < 130.0 and get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
		# Short final approach; obstacle avoidance still uses physical collision.
		return (target - global_position).normalized()
	if path.is_empty() or repath <= 0.0:
		path = world.path_between(global_position, target)
		path_index = 1 if path.size() > 1 else 0
		repath = 0.55
	while path_index < path.size() and global_position.distance_to(path[path_index]) < 10.0:
		path_index += 1
	if path_index < path.size():
		return (path[path_index] - global_position).normalized()
	return Vector2.ZERO

func take_damage(amount: float, push: Vector2) -> void:
	if dead or emerging:
		return
	aggro = true
	flash = 0.14
	visual.play_hurt()
	var actual_damage: float = minf(health, amount)
	health -= amount
	damaged.emit(global_position, actual_damage)
	knockback = push
	# Damage interrupts a telegraphed attack.
	windup = 0.0
	if melee_action == "windup":
		melee_action = "recovery"
		melee_timer = 0.25
	attack_cooldown = maxf(attack_cooldown, 0.25)
	if health <= 0.0:
		dead = true
		set_deferred("collision_layer", 0)
		visual.detach_and_die(get_parent())
		killed.emit(global_position, experience_value)
		queue_free()
	queue_redraw()

func _draw() -> void:
	var color := Color("e47c77") if kind == Kind.HOSTILE else Color("d4bb76")
	if flash > 0.0:
		color = Color.WHITE
	if aggro:
		draw_line(Vector2(0, -30), Vector2(0, -24), Color("ffab89"), 2.0)
		draw_circle(Vector2(0, -21), 1.5, Color("ffab89"))
	if health < max_health:
		draw_rect(Rect2(-19, -38, 38, 4), Color("182329"))
		draw_rect(Rect2(-19, -38, 38 * maxf(0.0, health / max_health), 4), color)
	if windup > 0.0:
		var center: float = attack_direction.angle()
		draw_arc(Vector2.ZERO, 48.0, center - 1.1, center + 1.1, 18, Color(1.0, 0.38, 0.25, 0.9), 3.0, true)
	if kind == Kind.HOSTILE and melee_action in ["windup", "attack"]:
		var progress := clampf(1.0 - melee_timer / melee_duration, 0.0, 1.0)
		var angle := attack_direction.angle()
		if not fast_chaser:
			angle += lerpf(-0.8, 0.65, progress) if melee_action == "attack" else -0.8
		var direction := Vector2.from_angle(angle)
		var length := 32.0 if melee_action == "windup" else (lerpf(30.0, 48.0, sin(progress * PI)) if fast_chaser else 42.0)
		draw_line(direction * 12.0, direction * length, Color("ffe2a0"), 4.0, true)
		if melee_action == "windup":
			var half_angle := acos(0.82 if fast_chaser else 0.65)
			draw_arc(Vector2.ZERO, 63.0, attack_direction.angle() - half_angle, attack_direction.angle() + half_angle, 24, Color(1.0, 0.38, 0.25, 0.8), 2.0, true)
	if special_windup > 0.0:
		draw_circle(Vector2.ZERO, 125.0, Color(1.0, 0.2, 0.1, 0.18))
		draw_arc(Vector2.ZERO, 125.0, 0.0, TAU, 48, Color("ff654f"), 3.0, true)
	if kind == Kind.RANGED:
		draw_circle(Vector2(0, -25), 5, Color("a77aff"))
	elif kind == Kind.BOSS:
		draw_arc(Vector2.ZERO, 24.0, 0.0, TAU, 32, Color("ffcc57"), 4.0, true)
	if fast_chaser:
		draw_arc(Vector2.ZERO, 21.0, 0.0, TAU, 24, Color("ffbd55"), 3.0, true)

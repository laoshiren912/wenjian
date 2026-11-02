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
var guard_time: float = 0.0
var guard_cooldown: float = 1.2
var guard_direction: Vector2 = Vector2.RIGHT
var encounter_id: int = -1
var home_position: Vector2 = Vector2.ZERO
var thrust_type: bool = false
enum EncounterState { IDLE, CHASE, SEARCH, RETURN }
var encounter_state: int = EncounterState.IDLE
var last_seen: Vector2 = Vector2.ZERO
var search_time: float = 0.0
var search_target: Vector2 = Vector2.ZERO
var search_checked: bool = false
var attack_duration: float = 0.0
var lunge_time: float = 0.0
var side_sign: float = 1.0
var path: PackedVector2Array = PackedVector2Array()
var path_index: int = 0
var repath: float = 0.0
var wander_target: Vector2
var wander_timer: float = 2.0
var special_cooldown: float = 4.0
var special_windup: float = 0.0
enum BossState { APPROACH, CIRCLE_WINDUP, COMBO_WINDUP, CHARGE_WINDUP, CHARGING, RECOVERY, STAGGER }
const BOSS_CIRCLE_RADIUS := 290.0
const BOSS_COMBO_RADIUS := 80.0
const BOSS_COMBO_HALF_ANGLE := 0.85
const BOSS_CHARGE_DISTANCE := 320.0
const BOSS_CHARGE_SPEED := 500.0
const BOSS_CHARGE_WIDTH := 29.0
var boss_state: int = BossState.APPROACH
var boss_timer: float = 1.0
var boss_next_attack: int = 0
var boss_combo_hits: int = 0
var boss_pressure: float = 0.0
var boss_pressure_grace: float = 0.0
var boss_last_seen: Vector2 = Vector2.ZERO
var boss_has_last_seen: bool = false
var boss_search_target: Vector2 = Vector2.ZERO
var boss_searching: bool = false
var boss_charge_remaining: float = 0.0
var boss_charge_aim: Vector2 = Vector2.RIGHT
var boss_charge_hit: bool = false
var boss_charge_distance: float = BOSS_CHARGE_DISTANCE
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
	if kind == Kind.BOSS:
		_boss_process(delta)
		return
	if encounter_id >= 0:
		_encounter_process(delta)
		return
	flash = maxf(0.0, flash - delta)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	guard_cooldown = maxf(0.0, guard_cooldown - delta)
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
	elif guard_time > 0.0:
		guard_time = maxf(0.0, guard_time - delta)
		if guard_time <= 0.0:
			attack_cooldown = maxf(attack_cooldown, 0.15)
	elif kind == Kind.HOSTILE and aggro and guard_cooldown <= 0.0 and distance < 140.0 and _boss_has_sight(player.global_position):
		guard_direction = (player.global_position - global_position).normalized()
		guard_time = 0.65
		guard_cooldown = 3.5
	elif aggro:
		if distance < 45.0:
			if attack_cooldown <= 0.0 and (kind != Kind.HOSTILE or _nearby_attackers() < 2):
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
	var look: Vector2 = guard_direction if guard_time > 0.0 else (attack_direction if windup > 0.0 else get_real_velocity())
	visual.update_pose(get_real_velocity(), look, Color("e47c77") if kind == Kind.HOSTILE else Color("d4bb76"))
	queue_redraw()

func _nearby_attackers() -> int:
	var count := 0
	for other in get_tree().get_nodes_in_group("enemies"):
		if other != self and not other.dead and other.kind == Kind.HOSTILE and other.windup > 0.0 and other.global_position.distance_to(player.global_position) < 160.0:
			count += 1
	return count

func alert_encounter(location: Vector2) -> void:
	for other in get_tree().get_nodes_in_group("enemies"):
		if other.encounter_id == encounter_id and encounter_id >= 0 and not other.dead:
			other.encounter_state = EncounterState.CHASE
			other.aggro = true
			other.last_seen = location
			other.search_time = 3.0

func _encounter_attackers() -> int:
	var count := 0
	for other in get_tree().get_nodes_in_group("enemies"):
		if other != self and not other.dead and other.encounter_id == encounter_id and (other.windup > 0.0 or other.lunge_time > 0.0):
			count += 1
	return count

func _encounter_process(delta: float) -> void:
	flash = maxf(0.0, flash - delta)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	guard_cooldown = maxf(0.0, guard_cooldown - delta)
	guard_time = maxf(0.0, guard_time - delta)
	repath -= delta
	var offset: Vector2 = player.global_position - global_position
	var distance := offset.length()
	var visible := distance < 340.0 and _boss_has_sight(player.global_position)
	if visible:
		alert_encounter(player.global_position)
	elif encounter_state == EncounterState.CHASE:
		encounter_state = EncounterState.SEARCH
		search_time = 3.0
		search_target = last_seen
		search_checked = false
		path.clear()
	var movement := Vector2.ZERO
	if encounter_state == EncounterState.SEARCH:
		search_time -= delta
		if search_time <= 0.0:
			encounter_state = EncounterState.RETURN
			path.clear()
	if windup > 0.0:
		windup -= delta
		if windup > attack_duration * 0.5 and visible and distance > 0.01:
			attack_direction = attack_direction.lerp(offset.normalized(), minf(1.0, delta * 5.0)).normalized()
		if windup <= 0.0:
			if kind == Kind.RANGED:
				_fire_encounter_shot()
				attack_cooldown = 1.7
			else:
				lunge_time = 0.16
	elif lunge_time > 0.0:
		lunge_time = maxf(0.0, lunge_time - delta)
		movement = attack_direction * (1.35 if thrust_type else 0.7)
		if lunge_time <= 0.0:
			var half_angle := 0.5 if thrust_type else 1.15
			if distance < (80.0 if thrust_type else 72.0) and absf(attack_direction.angle_to(offset)) < half_angle and _boss_has_sight(player.global_position):
				player.take_damage(damage, offset.normalized())
			attack_cooldown = 1.0 if thrust_type else 1.2
	elif guard_time > 0.0:
		pass
	elif encounter_state == EncounterState.CHASE and visible:
		if distance > 0.01:
			guard_direction = offset.normalized()
		var reach := 400.0 if kind == Kind.RANGED else (75.0 if thrust_type else 60.0)
		if kind == Kind.RANGED and distance < 180.0:
			movement = -offset.normalized() * 0.7
		elif distance > reach:
			movement = _follow_path(player.global_position)
		elif attack_cooldown <= 0.0:
			if _encounter_attackers() < 2:
				attack_direction = offset.normalized()
				attack_duration = 0.85 if kind == Kind.RANGED else (0.65 if thrust_type else 0.8)
				windup = attack_duration
			else:
				movement = offset.normalized().orthogonal() * side_sign * 0.35
	elif encounter_state == EncounterState.SEARCH:
		if global_position.distance_to(search_target) <= 25.0 and not search_checked:
			search_checked = true
			var nearby: Vector2i = world.cell_at(last_seen) + Vector2i(0, 2 if side_sign > 0 else -2)
			if world.grid.is_in_boundsv(nearby) and not world.grid.is_point_solid(nearby):
				search_target = world.cell_center(nearby)
				path.clear()
		if global_position.distance_to(search_target) > 20.0:
			movement = _follow_path(search_target)
	elif encounter_state == EncounterState.RETURN:
		if global_position.distance_to(home_position) > 16.0:
			movement = _follow_path(home_position)
		else:
			encounter_state = EncounterState.IDLE
			aggro = false
	var separation := Vector2.ZERO
	for other in get_tree().get_nodes_in_group("enemies"):
		if other != self and not other.dead and global_position.distance_squared_to(other.global_position) < 34.0 * 34.0:
			separation += (global_position - other.global_position).normalized() * 24.0
	velocity = movement * speed + knockback + separation.limit_length(45.0)
	knockback = knockback.move_toward(Vector2.ZERO, 520.0 * delta)
	move_and_slide()
	var look: Vector2 = attack_direction if windup > 0.0 or lunge_time > 0.0 else (guard_direction if guard_time > 0.0 or encounter_state == EncounterState.CHASE else get_real_velocity())
	visual.update_pose(get_real_velocity(), look, Color("e47c77") if kind == Kind.HOSTILE else Color("d4bb76"))
	queue_redraw()

func _fire_encounter_shot() -> void:
	var shot = PROJECTILE_SCENE.instantiate()
	shot.direction = attack_direction
	shot.damage = damage
	shot.speed = 300.0
	shot.max_distance = 500.0
	shot.collision_mask = 3
	shot.hostile = true
	get_parent().add_child(shot)
	shot.global_position = global_position + shot.direction * 23.0

func _boss_process(delta: float) -> void:
	flash = maxf(0.0, flash - delta)
	repath -= delta
	boss_timer -= delta
	boss_pressure_grace = maxf(0.0, boss_pressure_grace - delta)
	if boss_pressure_grace <= 0.0:
		boss_pressure = maxf(0.0, boss_pressure - 25.0 * delta)
	var offset: Vector2 = player.global_position - global_position
	var movement := Vector2.ZERO
	var can_see_player := _boss_has_sight(player.global_position)
	if can_see_player:
		boss_last_seen = player.global_position
		boss_has_last_seen = true
		boss_searching = false
	match boss_state:
		BossState.APPROACH:
			if not can_see_player:
				movement = _boss_search()
			elif boss_timer <= 0.0 and (offset.length() < 300.0 or boss_next_attack == 2):
				boss_charge_aim = offset.normalized() if offset.length_squared() > 0.01 else Vector2.RIGHT
				if boss_next_attack == 0:
					boss_state = BossState.CIRCLE_WINDUP
					boss_timer = 0.9
				elif boss_next_attack == 1:
					if offset.length() > BOSS_COMBO_RADIUS:
						movement = _follow_path(player.global_position)
					else:
						boss_state = BossState.COMBO_WINDUP
						boss_combo_hits = 0
						boss_timer = 0.4
				else:
					boss_state = BossState.CHARGE_WINDUP
					boss_timer = 1.0
					boss_charge_distance = _boss_open_charge_distance()
			else:
				movement = _follow_path(player.global_position)
		BossState.CIRCLE_WINDUP:
			if boss_timer <= 0.0:
				if offset.length() <= BOSS_CIRCLE_RADIUS:
					player.take_damage(24.0, offset.normalized())
				_boss_recover(1)
		BossState.COMBO_WINDUP:
			if boss_timer <= 0.0:
				if offset.length() <= BOSS_COMBO_RADIUS and absf(boss_charge_aim.angle_to(offset)) <= BOSS_COMBO_HALF_ANGLE:
					player.take_damage(damage, offset.normalized())
				boss_combo_hits += 1
				if boss_combo_hits >= 3:
					_boss_recover(2)
				else:
					boss_charge_aim = offset.normalized() if offset.length_squared() > 0.01 else boss_charge_aim
					boss_timer = 0.55
		BossState.CHARGE_WINDUP:
			if boss_timer > 0.55 and not can_see_player:
				boss_state = BossState.APPROACH
				boss_timer = 0.35
			elif boss_timer > 0.55 and offset.length_squared() > 0.01:
				boss_charge_aim = boss_charge_aim.lerp(offset.normalized(), minf(1.0, delta * 4.0)).normalized()
				boss_charge_distance = _boss_open_charge_distance()
			elif boss_timer <= 0.0:
				boss_state = BossState.CHARGING
				boss_charge_remaining = boss_charge_distance
				boss_charge_hit = false
		BossState.CHARGING:
			var start := global_position
			var distance := minf(boss_charge_remaining, BOSS_CHARGE_SPEED * delta)
			var collision := move_and_collide(boss_charge_aim * distance)
			var end := global_position
			var closest := Geometry2D.get_closest_point_to_segment(player.global_position, start, end)
			if not boss_charge_hit and closest.distance_to(player.global_position) <= BOSS_CHARGE_WIDTH and _boss_has_sight(player.global_position):
				boss_charge_hit = true
				player.take_damage(damage, boss_charge_aim)
			boss_charge_remaining -= distance
			if collision or boss_charge_remaining <= 0.0:
				_boss_recover(0)
		BossState.RECOVERY, BossState.STAGGER:
			if boss_timer <= 0.0:
				boss_state = BossState.APPROACH
				boss_timer = 0.35
	if boss_state == BossState.APPROACH:
		velocity = movement * speed
		move_and_slide()
	visual.update_pose(velocity if boss_state == BossState.APPROACH else Vector2.ZERO, boss_charge_aim, Color("d4bb76"))
	queue_redraw()

func _boss_has_sight(target: Vector2) -> bool:
	var ray := PhysicsRayQueryParameters2D.create(global_position, target, 1)
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func _boss_search() -> Vector2:
	# Pursue the last visible position, then search nearby without tracking
	# the player's current position through a wall.
	if boss_has_last_seen:
		boss_search_target = boss_last_seen
		boss_has_last_seen = false
		boss_searching = true
		path.clear()
	if not boss_searching or global_position.distance_to(boss_search_target) < 20.0:
		var origin: Vector2 = boss_last_seen if boss_last_seen != Vector2.ZERO else global_position
		var candidates: Array[Vector2i] = []
		for cell in world.floor_cells:
			var point: Vector2 = world.cell_center(cell)
			if point.distance_to(origin) < 400.0 and point.distance_to(global_position) > 80.0:
				candidates.append(cell)
		if candidates.is_empty():
			return Vector2.ZERO
		boss_search_target = world.cell_center(candidates[world.random.randi_range(0, candidates.size() - 1)])
		boss_searching = true
		path.clear()
	var direction := _follow_path(boss_search_target)
	if path.is_empty():
		boss_searching = false
	return direction

func _boss_open_charge_distance() -> float:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = $CollisionShape2D.shape
	query.transform = global_transform
	query.motion = boss_charge_aim * BOSS_CHARGE_DISTANCE
	query.collision_mask = 1
	var result := get_world_2d().direct_space_state.cast_motion(query)
	return BOSS_CHARGE_DISTANCE * result[0]

func _boss_recover(next_attack: int) -> void:
	boss_next_attack = next_attack
	boss_state = BossState.RECOVERY
	boss_timer = 0.7 if health <= max_health * 0.5 else 1.0
	velocity = Vector2.ZERO

func _follow_path(target: Vector2) -> Vector2:
	var ray := PhysicsRayQueryParameters2D.create(global_position, target, 1)
	if global_position.distance_to(target) < 130.0 and get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
		# Short final approach; obstacle avoidance still uses physical collision.
		return (target - global_position).normalized()
	if path.is_empty() or repath <= 0.0:
		path = world.path_between(global_position, target)
		path_index = 0
		repath = 0.55
	while path_index < path.size() and global_position.distance_to(path[path_index]) < 10.0:
		path_index += 1
	if path_index < path.size():
		return (path[path_index] - global_position).normalized()
	return Vector2.ZERO

func take_damage(amount: float, push: Vector2, ignore_guard: bool = false) -> void:
	if dead:
		return
	var can_block := guard_time > 0.0
	if encounter_id >= 0 and kind == Kind.HOSTILE and not thrust_type and encounter_state == EncounterState.CHASE and windup <= 0.0 and lunge_time <= 0.0 and guard_cooldown <= 0.0:
		can_block = true
	aggro = true
	var blocked_hit := not ignore_guard and kind == Kind.HOSTILE and can_block and not push.is_zero_approx() and guard_direction.dot(-push.normalized()) >= 0.5
	if blocked_hit:
		amount *= 0.35
		push *= 0.25
		if encounter_id >= 0:
			guard_time = 0.2
			guard_cooldown = 1.5
	if encounter_id >= 0 and not ignore_guard:
		alert_encounter(player.global_position)
	flash = 0.14
	visual.play_hurt()
	var actual_damage: float = minf(health, amount)
	health -= amount
	if kind == Kind.BOSS and boss_state != BossState.STAGGER and health > 0.0:
		boss_pressure += amount
		boss_pressure_grace = 2.0
		if boss_pressure >= 260.0:
			boss_pressure = 0.0
			boss_state = BossState.STAGGER
			boss_timer = 1.2
			velocity = Vector2.ZERO
	damaged.emit(global_position, actual_damage)
	knockback = push if kind != Kind.BOSS else Vector2.ZERO
	# Grouped enemies commit to a prepared strike; older standalone enemies retain their behavior.
	if encounter_id < 0:
		windup = 0.0
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
	if kind == Kind.BOSS:
		if boss_state == BossState.STAGGER:
			draw_arc(Vector2.ZERO, 32.0, 0.0, TAU, 32, Color("fff09a"), 5.0, true)
		if boss_state == BossState.CIRCLE_WINDUP:
			draw_circle(Vector2.ZERO, BOSS_CIRCLE_RADIUS, Color(1.0, 0.2, 0.1, 0.18))
			draw_arc(Vector2.ZERO, BOSS_CIRCLE_RADIUS, 0.0, TAU, 64, Color("ff654f"), 3.0, true)
		elif boss_state == BossState.COMBO_WINDUP:
			var angle := boss_charge_aim.angle()
			var points := PackedVector2Array([Vector2.ZERO])
			for i in range(25):
				points.append(Vector2.from_angle(angle - BOSS_COMBO_HALF_ANGLE + 2.0 * BOSS_COMBO_HALF_ANGLE * i / 24.0) * BOSS_COMBO_RADIUS)
			draw_colored_polygon(points, Color(1.0, 0.3, 0.1, 0.25))
			draw_arc(Vector2.ZERO, BOSS_COMBO_RADIUS, angle - BOSS_COMBO_HALF_ANGLE, angle + BOSS_COMBO_HALF_ANGLE, 24, Color("ff654f"), 3.0, true)
		elif boss_state == BossState.CHARGE_WINDUP:
			draw_line(Vector2.ZERO, boss_charge_aim * boss_charge_distance, Color(1.0, 0.3, 0.1, 0.28), BOSS_CHARGE_WIDTH * 2.0, true)
			draw_line(Vector2.ZERO, boss_charge_aim * boss_charge_distance, Color("ffd36b"), 3.0, true)
	if windup > 0.0:
		var center: float = attack_direction.angle()
		if encounter_id >= 0 and kind == Kind.RANGED:
			draw_line(Vector2.ZERO, attack_direction * 85.0, Color("c09bff"), 3.0, true)
		else:
			var spread := 0.5 if encounter_id >= 0 and thrust_type else 1.1
			draw_arc(Vector2.ZERO, 68.0 if thrust_type else 48.0, center - spread, center + spread, 18, Color(1.0, 0.38, 0.25, 0.9), 3.0, true)
	if special_windup > 0.0:
		draw_circle(Vector2.ZERO, 125.0, Color(1.0, 0.2, 0.1, 0.18))
		draw_arc(Vector2.ZERO, 125.0, 0.0, TAU, 48, Color("ff654f"), 3.0, true)
	if kind == Kind.RANGED:
		draw_circle(Vector2(0, -25), 5, Color("a77aff"))
	elif kind == Kind.BOSS:
		draw_arc(Vector2.ZERO, 24.0, 0.0, TAU, 32, Color("ffcc57"), 4.0, true)
	if fast_chaser:
		draw_arc(Vector2.ZERO, 21.0, 0.0, TAU, 24, Color("ffbd55"), 3.0, true)
	if guard_time > 0.0:
		var angle := guard_direction.angle()
		draw_arc(Vector2.ZERO, 25.0, angle - 0.8, angle + 0.8, 20, Color("8fe5ff"), 5.0, true)

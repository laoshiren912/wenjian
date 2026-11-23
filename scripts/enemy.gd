class_name SurvivorEnemy
extends CharacterBody2D

signal killed(location: Vector2, experience_value: int)
signal damaged(location: Vector2, amount: float)
enum Kind { PASSIVE, HOSTILE, RANGED, BOSS }
const V41 = preload("res://scripts/v41_config.gd")
const ENCOUNTER_LUNGE_TIME := 0.16
const MELEE_IMPACT_CUE_TIME := 0.08
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
var legacy_ai: bool = false
var guard_time: float = 0.0
var v41_guard_elite := false
var guard_cooldown: float = 1.2
var guard_direction: Vector2 = Vector2.RIGHT
var encounter_id: int = -1
var home_position: Vector2 = Vector2.ZERO
var thrust_type: bool = false
@export_range(1, 10, 1) var max_simultaneous_attackers: int = 2
var v41_pressure := false
var intro_room := false
var pair_scheduler: RefCounted
var waiting_radius := 125.0
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
		var previous_position := position
		_boss_process(delta)
		_recover_arena_position(previous_position)
		return
	if encounter_id >= 0:
		var previous_position := position
		_encounter_process(delta)
		_recover_arena_position(previous_position)
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
	elif kind == Kind.HOSTILE and not legacy_ai:
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
			if attack_cooldown <= 0.0 and (kind != Kind.HOSTILE or _nearby_attackers() < max_simultaneous_attackers):
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
	var move_scale := 0.15 if (hit_stun > 0.0 and windup <= 0.0 and lunge_time <= 0.0) else (0.62 if slow_time > 0.0 else 1.0)
	velocity = movement * speed * move_scale + knockback + separation.limit_length(45.0)
	knockback = knockback.lerp(Vector2.ZERO, minf(1.0, 14.0 * delta))
	if knockback.length_squared() < 4.0:
		knockback = Vector2.ZERO
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
	if attackers >= max_simultaneous_attackers:
		return offset.normalized().rotated(PI * 0.5) * 0.4
	melee_action = "windup"
	melee_duration = 0.65 if fast_chaser else 0.85
	melee_timer = melee_duration
	attack_direction = offset.normalized()
	return Vector2.ZERO
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
			if not v41_pressure or other.kind == kind or intro_room:
				count += 1
	return count

func _encounter_process(delta: float) -> void:
	flash = maxf(0.0, flash - delta)
	guard_anim_clock += delta
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	guard_cooldown = maxf(0.0, guard_cooldown - delta)
	guard_time = maxf(0.0, guard_time - delta)
	guard_visual_time = maxf(0.0, guard_visual_time - delta)
	repath -= delta
	var offset: Vector2 = player.global_position - global_position
	if v41_heavy_stun > 0.0:
		v41_heavy_stun = maxf(0.0, v41_heavy_stun - delta)
		if posture_broken_time > 0.0:
			posture_broken_time = maxf(0.0, posture_broken_time - delta)
			if posture_broken_time <= 0.0:
				posture = posture_max
		velocity = knockback
		knockback = knockback.lerp(Vector2.ZERO, minf(1.0, 11.0 * delta))
		move_and_slide()
		visual.update_pose(Vector2.ZERO, guard_direction, Color.WHITE)
		queue_redraw()
		return
	if posture_broken_time > 0.0:
		posture_broken_time = maxf(0.0, posture_broken_time - delta)
		if posture_broken_time <= 0.0:
			posture = posture_max
	if hit_stun > 0.0:
		hit_stun = maxf(0.0, hit_stun - delta)
	if slow_time > 0.0:
		slow_time = maxf(0.0, slow_time - delta)
	var distance := offset.length()
	var visible := distance < (V41.SIGHT_RANGE if v41_pressure else 340.0) and _boss_has_sight(player.global_position)
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
		if not _uses_melee_telegraph() and windup > attack_duration * 0.5 and visible and distance > 0.01:
			attack_direction = attack_direction.lerp(offset.normalized(), minf(1.0, delta * 5.0)).normalized()
		if windup <= 0.0:
			if kind == Kind.RANGED:
				_fire_encounter_shot()
				attack_cooldown = V41.RANGED_RECOVERY if v41_pressure else 1.7
			else:
				lunge_time = ENCOUNTER_LUNGE_TIME
	elif lunge_time > 0.0:
		lunge_time = maxf(0.0, lunge_time - delta)
		movement = attack_direction * _encounter_lunge_speed_factor()
		if lunge_time <= 0.0:
			if distance < _encounter_melee_hit_reach() and absf(attack_direction.angle_to(offset)) < _encounter_melee_half_angle() and _boss_has_sight(player.global_position):
				player.take_damage(damage, offset.normalized())
			attack_cooldown = V41.MELEE_RECOVERY if v41_pressure else (1.0 if thrust_type else 1.2)
	elif guard_time > 0.0:
		pass
	elif encounter_state == EncounterState.CHASE and visible:
		if distance > 0.01 and not _holding_encounter_melee_facing():
			guard_direction = offset.normalized()
		# 精英怪在追击靠近玩家且架势完好时主动展开真格挡架势（身前护体剑罡 + 黄色架势条）
		if v41_guard_elite and guard_cooldown <= 0.0 and posture_broken_time <= 0.0 and posture > 0.0 and distance < 175.0 and distance > 52.0:
			guard_time = 0.85
			guard_visual_time = 0.85
			guard_cooldown = 1.65
			velocity = Vector2.ZERO
			visual.update_pose(Vector2.ZERO, guard_direction, Color("e47c77"))
			queue_redraw()
			return
		var reach := 400.0 if kind == Kind.RANGED else (75.0 if thrust_type else 60.0)
		if kind == Kind.RANGED and v41_pressure:
			reach = V41.RANGED_REACH
		var retreat := distance < V41.RANGED_RETREAT and attack_cooldown > 0.0 if v41_pressure else distance < 180.0
		if kind == Kind.RANGED and retreat:
			movement = -offset.normalized() * 0.7
		elif kind == Kind.HOSTILE and is_instance_valid(pair_scheduler) and not pair_scheduler.can_start(self):
			var waiting_point := player.global_position - offset.normalized() * waiting_radius + offset.normalized().orthogonal() * side_sign * 35.0
			if v41_pressure and distance < waiting_radius - 18.0 and distance > 0.01:
				movement = -offset.normalized() * (0.95 if intro_room else 0.68) + offset.normalized().orthogonal() * side_sign * 0.35
			else:
				movement = _follow_path(waiting_point) * 0.65 if distance > waiting_radius + 25.0 else offset.normalized().orthogonal() * side_sign * 0.35
		elif distance > reach:
			movement = _follow_path(player.global_position)
		elif attack_cooldown <= 0.0:
			var attack_limit := max_simultaneous_attackers
			if v41_pressure:
				# Reserve both melee turns even with two ranged enemies alive.
				attack_limit = 1 if kind == Kind.RANGED else V41.PAIR_SIZE
			if _encounter_attackers() < attack_limit:
				attack_direction = offset.normalized()
				attack_duration = 0.85 if kind == Kind.RANGED else (0.65 if thrust_type else 0.8)
				if v41_pressure:
					attack_duration -= 0.20
				windup = attack_duration
				if kind == Kind.HOSTILE and is_instance_valid(pair_scheduler):
					pair_scheduler.attack_started(self)
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
	var move_scale := 0.15 if (hit_stun > 0.0 and windup <= 0.0 and lunge_time <= 0.0) else (0.62 if slow_time > 0.0 else 1.0)
	velocity = movement * speed * move_scale + knockback + separation.limit_length(45.0)
	knockback = knockback.lerp(Vector2.ZERO, minf(1.0, 14.0 * delta))
	if knockback.length_squared() < 4.0:
		knockback = Vector2.ZERO
	move_and_slide()
	var look: Vector2 = attack_direction if windup > 0.0 or lunge_time > 0.0 or _holding_encounter_melee_facing() else (guard_direction if guard_time > 0.0 or encounter_state == EncounterState.CHASE else get_real_velocity())
	var body_color := Color.WHITE if v41_pressure else (Color("e47c77") if kind == Kind.HOSTILE else Color("d4bb76"))
	visual.update_pose(get_real_velocity(), look, body_color)
	queue_redraw()

func _uses_melee_telegraph() -> bool:
	return v41_pressure and kind == Kind.HOSTILE

func _holding_encounter_melee_facing() -> bool:
	return _uses_melee_telegraph() and attack_cooldown > V41.MELEE_RECOVERY - V41.MELEE_FACING_RECOVERY

func _encounter_melee_hit_reach() -> float:
	return 80.0 if thrust_type else 72.0

func _encounter_melee_half_angle() -> float:
	return 0.5 if thrust_type else 1.15

func _encounter_lunge_speed_factor() -> float:
	return 1.35 if thrust_type else 0.7

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

func _boss_open_charge_distance(max_distance: float = BOSS_CHARGE_DISTANCE) -> float:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = $CollisionShape2D.shape
	query.transform = global_transform
	query.motion = boss_charge_aim * max_distance
	query.collision_mask = 1
	var result := get_world_2d().direct_space_state.cast_motion(query)
	return max_distance * result[0]

func _boss_recover(next_attack: int) -> void:
	boss_next_attack = next_attack
	boss_state = BossState.RECOVERY
	boss_timer = 0.7 if health <= max_health * 0.5 else 1.0
	velocity = Vector2.ZERO

func _recover_arena_position(previous_position: Vector2) -> void:
	# Segment walls remain the normal collision path. Recover exceptional displacement
	# beyond their corners so a living wave member can never become unreachable.
	if not v41_pressure or not is_instance_valid(world) or world.floor_cells.is_empty():
		return
	if global_position.is_finite() and Geometry2D.is_point_in_polygon(position, world.walkable):
		return
	var anchor: Vector2 = position if position.is_finite() else home_position
	position = previous_position if previous_position.is_finite() and Geometry2D.is_point_in_polygon(previous_position, world.walkable) else world.cell_center(world.nearest_cell(anchor))
	velocity = Vector2.ZERO
	knockback = Vector2.ZERO
	path.clear()
	repath = 0.0

func _follow_path(target: Vector2) -> Vector2:
	if v41_pressure:
		return _v41_follow_path(target)
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

func _v41_path_clear(target: Vector2) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = $CollisionShape2D.shape
	query.transform = global_transform
	query.motion = target - global_position
	query.collision_mask = world.terrain_movement_mask
	return get_world_2d().direct_space_state.cast_motion(query)[0] >= 1.0

func _v41_follow_path(target: Vector2) -> Vector2:
	# A centre ray can miss a pillar that clips the enemy's collision circle.
	if global_position.distance_to(target) < 130.0 and _v41_path_clear(target):
		return (target - global_position).normalized()
	if path.is_empty() or repath <= 0.0:
		path = world.path_between(global_position, target)
		path_index = 1 if path.size() > 1 and _v41_path_clear(path[1]) else 0
		repath = 0.55
	while path_index < path.size() and global_position.distance_to(path[path_index]) < 10.0:
		path_index += 1
	if path_index < path.size():
		return (path[path_index] - global_position).normalized()
	return Vector2.ZERO

const ELITE_POSTURE_MAX := 100.0
const ELITE_BREAK_STUN := 1.5

var damage_shakes_camera := true
var last_hit_blocked := false
var last_hit_crit := false
var v41_heavy_stun := 0.0
var hit_stun := 0.0
var slow_time := 0.0
var guard_visual_time := 0.0
var guard_anim_clock := 0.0
var posture_max: float = ELITE_POSTURE_MAX
var posture: float = ELITE_POSTURE_MAX
var posture_broken_time: float = 0.0

func is_guarding_stance() -> bool:
	return guard_time > 0.0 or (v41_pressure and guard_visual_time > 0.0)

func damage_posture(amount: float) -> bool:
	if not v41_guard_elite or posture_broken_time > 0.0 or amount <= 0.0:
		return false
	posture = maxf(0.0, posture - amount)
	if posture <= 0.0:
		break_guard_stance(ELITE_BREAK_STUN, ELITE_BREAK_STUN)
		posture_broken_time = ELITE_BREAK_STUN
		return true
	queue_redraw()
	return false

func break_guard_stance(opening_window: float = V41.HEAVY_BASE_BREAK, stun_duration: float = V41.BREAK_STUN) -> bool:
	var was_guarding := is_guarding_stance()
	guard_time = 0.0
	guard_visual_time = 0.0
	var actual_open := ELITE_BREAK_STUN if v41_guard_elite else opening_window
	var actual_stun := ELITE_BREAK_STUN if v41_guard_elite else stun_duration
	guard_cooldown = maxf(guard_cooldown, actual_open)
	if v41_guard_elite:
		posture = 0.0
		posture_broken_time = maxf(posture_broken_time, ELITE_BREAK_STUN)
	if v41_pressure and kind == Kind.HOSTILE and not thrust_type:
		v41_heavy_stun = maxf(v41_heavy_stun, actual_stun)
		windup = 0.0
		lunge_time = 0.0
		velocity = Vector2.ZERO
	elif kind == Kind.BOSS and was_guarding:
		boss_timer = maxf(boss_timer, 0.55)
		velocity = Vector2.ZERO
	queue_redraw()
	return was_guarding

func suppress_by_third_hit() -> void:
	if not v41_pressure or kind != Kind.HOSTILE or thrust_type:
		return
	v41_heavy_stun = maxf(v41_heavy_stun, V41.BREAK_STUN)
	windup = 0.0
	lunge_time = 0.0
	velocity = Vector2.ZERO

func take_damage(amount: float, push: Vector2, ignore_guard: bool = false, camera_shake: bool = true, v41_player_arrow: bool = false, force_crit: bool = false) -> void:
	damage_shakes_camera = camera_shake
	if dead or emerging:
		return
	var can_block := guard_time > 0.0 and posture_broken_time <= 0.0
	# 限定仅重装/精英怪自动进入格挡；普通小怪保持纯粹割草手感（手动设 guard_time 的单测仍兼容）
	if encounter_id >= 0 and kind == Kind.HOSTILE and v41_guard_elite and posture_broken_time <= 0.0 and encounter_state == EncounterState.CHASE and windup <= 0.0 and lunge_time <= 0.0 and guard_cooldown <= 0.0:
		can_block = true
	aggro = true
	var guard_arc := V41.GUARD_ARC_DOT if v41_pressure else 0.5
	var arrow_bypasses := v41_player_arrow and v41_pressure and kind == Kind.HOSTILE and not thrust_type
	var blocked_hit := not ignore_guard and not arrow_bypasses and kind == Kind.HOSTILE and can_block and not push.is_zero_approx() and guard_direction.dot(-push.normalized()) >= guard_arc
	last_hit_blocked = blocked_hit
	var vulnerable_crit := posture_broken_time > 0.0 and not blocked_hit
	last_hit_crit = (force_crit or vulnerable_crit) and not blocked_hit
	if vulnerable_crit and not force_crit:
		amount *= 1.5
	if blocked_hit:
		if v41_pressure:
			guard_visual_time = maxf(guard_visual_time, V41.GUARD_DISPLAY)
		amount *= V41.GUARD_DAMAGE_FACTOR if v41_pressure else 0.35
		push *= 0.25
		if encounter_id >= 0 and (not v41_pressure or guard_time <= 0.0):
			guard_time = (0.45 if v41_guard_elite else V41.GUARD_HOLD) if v41_pressure else 0.2
			guard_cooldown = (0.50 if v41_guard_elite else V41.GUARD_COOLDOWN) if v41_pressure else 1.5
	if encounter_id >= 0 and not ignore_guard:
		alert_encounter(player.global_position)
	if not v41_pressure or visual.hurt_flash_lock <= 0.00001:
		flash = V41.ENEMY_FLASH_DURATION if v41_pressure else 0.14
	visual.play_hurt()
	var actual_damage: float = minf(health, amount)
	health -= amount
	if kind == Kind.BOSS and not v41_pressure and boss_state != BossState.STAGGER and health > 0.0:
		boss_pressure += amount
		boss_pressure_grace = 2.0
		if boss_pressure >= 260.0:
			boss_pressure = 0.0
			boss_state = BossState.STAGGER
			boss_timer = 1.2
			velocity = Vector2.ZERO
	damaged.emit(global_position, actual_damage)
	if kind == Kind.BOSS:
		if boss_state != BossState.CHARGING and not push.is_zero_approx():
			knockback = push.limit_length(85.0) * 0.42
	else:
		knockback = push
		if v41_pressure and not blocked_hit and windup <= 0.0 and lunge_time <= 0.0:
			hit_stun = maxf(hit_stun, 0.065)
	if encounter_id < 0:
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
	if v41_guard_elite:
		draw_arc(Vector2(0, 13), 17.0, 0.20, PI - 0.20, 16, Color("80cfcb"), 2.0, true)
	if intro_room and kind == Kind.HOSTILE and is_instance_valid(pair_scheduler):
		if pair_scheduler.can_start(self) or windup > 0.0 or lunge_time > 0.0:
			draw_circle(Vector2(0, 23), 4.0, Color("ffad59"))
		else:
			draw_polyline(PackedVector2Array([Vector2(-7, 20), Vector2(0, 27), Vector2(7, 20)]), Color("a6b5bd"), 3.0, true)
	var color := Color("e47c77") if kind == Kind.HOSTILE else Color("d4bb76")
	if flash > 0.0:
		color = Color.WHITE
	if aggro:
		draw_line(Vector2(0, -30), Vector2(0, -24), Color("ffab89"), 2.0)
		draw_circle(Vector2(0, -21), 1.5, Color("ffab89"))
	if health < max_health or v41_guard_elite:
		var bar_w := 48.0 if v41_guard_elite else 38.0
		var bar_x := -bar_w * 0.5
		var bar_y := -52.0 if v41_guard_elite else -38.0
		draw_rect(Rect2(bar_x - 1.0, bar_y - 1.0, bar_w + 2.0, 6.0), Color("0a1014"))
		draw_rect(Rect2(bar_x, bar_y, bar_w, 4.0), Color("1b252c"))
		draw_rect(Rect2(bar_x, bar_y, bar_w * maxf(0.0, health / maxf(1.0, max_health)), 4.0), color)
		if v41_guard_elite:
			# 精英怪专属：生命条正下方醒目的明黄色「架势条（韧性条）」
			var py := bar_y + 6.0
			draw_rect(Rect2(bar_x - 1.0, py - 1.0, bar_w + 2.0, 6.5), Color("0a1014"))
			draw_rect(Rect2(bar_x, py, bar_w, 4.5), Color("242018"))
			if posture_broken_time > 0.0:
				var blink := 0.55 + 0.45 * sin(guard_anim_clock * 22.0)
				draw_rect(Rect2(bar_x, py, bar_w, 4.5), Color(0.95, 0.32, 0.18, 0.60 * blink))
				# 头顶破防眩晕标识（赤金碎盾菱标 + 旋转晕眩光弧）
				var warn_y := bar_y - 14.0
				draw_arc(Vector2(0, warn_y), 7.5, guard_anim_clock * 6.0, guard_anim_clock * 6.0 + PI * 1.35, 14, Color(1.0, 0.72, 0.25, 0.95), 2.0, true)
				draw_string_outline(preload("res://assets/fonts/msyh.ttc"), Vector2(-14, warn_y + 4.0), "破防", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 3, Color("200a06"))
				draw_string(preload("res://assets/fonts/msyh.ttc"), Vector2(-14, warn_y + 4.0), "破防", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("ffbe45"))
			else:
				var ratio := clampf(posture / maxf(1.0, posture_max), 0.0, 1.0)
				draw_rect(Rect2(bar_x, py, bar_w * ratio, 4.5), Color("f8d848"))
				draw_line(Vector2(bar_x, py + 0.5), Vector2(bar_x + bar_w * ratio, py + 0.5), Color("fff7cc"), 1.2)
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
	var impact_cue := clampf(1.0 - (V41.MELEE_RECOVERY - attack_cooldown) / MELEE_IMPACT_CUE_TIME, 0.0, 1.0)
	if _uses_melee_telegraph() and (windup > 0.0 or lunge_time > 0.0 or impact_cue > 0.0):
		_draw_encounter_melee_cue(impact_cue)
	elif windup > 0.0:
		var center: float = attack_direction.angle()
		if encounter_id >= 0 and kind == Kind.RANGED:
			draw_line(Vector2.ZERO, attack_direction * 85.0, Color("c09bff"), 3.0, true)
		else:
			var spread := 0.5 if encounter_id >= 0 and thrust_type else 1.1
			draw_arc(Vector2.ZERO, 68.0 if thrust_type else 48.0, center - spread, center + spread, 18, Color(1.0, 0.38, 0.25, 0.9), 3.0, true)
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
	if (guard_time > 0.0 or v41_pressure and guard_visual_time > 0.0) and posture_broken_time <= 0.0:
		var angle := guard_direction.angle()
		var half_arc := acos(V41.GUARD_ARC_DOT) if v41_pressure else 0.8
		var pulse := 0.74 + 0.26 * sin(guard_anim_clock * 14.0)
		var shield_r := 34.0 if kind == Kind.BOSS else (31.0 if v41_guard_elite else 27.0)
		# 半透明青金色扇形护体剑罡光弧（带流光纹理）
		var fan_poly := PackedVector2Array([Vector2.ZERO])
		var ring_poly := PackedVector2Array()
		var inner_r := shield_r - 11.0
		for i in range(21):
			var a := lerpf(angle - half_arc, angle + half_arc, float(i) / 20.0)
			var pt := Vector2.from_angle(a) * shield_r
			fan_poly.append(pt)
			ring_poly.append(pt)
		for i in range(20, -1, -1):
			var a := lerpf(angle - half_arc, angle + half_arc, float(i) / 20.0)
			ring_poly.append(Vector2.from_angle(a) * inner_r)
		draw_colored_polygon(fan_poly, Color(0.28, 0.84, 0.80, 0.14 + 0.06 * pulse))
		draw_colored_polygon(ring_poly, Color(0.45, 0.92, 0.88, 0.28 + 0.14 * pulse))
		# 扇形流光纹理波纹（沿弧面匀速扫过）
		var sweep_frac := fmod(guard_anim_clock * 1.25, 1.0)
		var sweep_a := lerpf(angle - half_arc * 0.85, angle + half_arc * 0.85, sweep_frac)
		draw_arc(Vector2.ZERO, shield_r - 4.5, maxf(angle - half_arc, sweep_a - 0.32), minf(angle + half_arc, sweep_a + 0.32), 12, Color(1.0, 0.96, 0.76, 0.85), 3.0, true)
		# 扇形侧边微光线
		draw_line(Vector2.from_angle(angle - half_arc) * 10.0, Vector2.from_angle(angle - half_arc) * shield_r, Color(0.86, 0.82, 0.50, 0.45), 1.4, true)
		draw_line(Vector2.from_angle(angle + half_arc) * 10.0, Vector2.from_angle(angle + half_arc) * shield_r, Color(0.86, 0.82, 0.50, 0.45), 1.4, true)
		# 外层鎏金剑罡边锋 + 内层霜青流光弧
		draw_arc(Vector2.ZERO, shield_r + 1.5, angle - half_arc, angle + half_arc, 26, Color(0.96, 0.84, 0.48, 0.92 * pulse), 3.0, true)
		draw_arc(Vector2.ZERO, shield_r - 2.0, angle - half_arc * 0.95, angle + half_arc * 0.95, 24, Color(0.56, 0.98, 0.94, 0.95), 3.6, true)
		draw_arc(Vector2.ZERO, inner_r + 1.5, angle - half_arc * 0.80, angle + half_arc * 0.80, 18, Color(1.0, 0.96, 0.80, 0.58 * pulse), 1.4, true)
		# 身前横举长剑光刃投影，凸显持剑横挡架势
		var fwd := Vector2.from_angle(angle)
		var side := fwd.orthogonal()
		var blade_mid := fwd * (shield_r - 8.0) + Vector2(0, -6.0)
		draw_line(blade_mid - side * 16.0, blade_mid + side * 16.0, Color(0.14, 0.20, 0.24, 0.85), 5.0, true)
		draw_line(blade_mid - side * 15.0, blade_mid + side * 15.0, Color(0.94, 0.98, 1.0, 0.95), 2.4, true)
		draw_circle(blade_mid - side * 11.0, 2.8, Color("f0cf7a"))

func _draw_encounter_melee_cue(impact_cue: float) -> void:
	var aiming := windup > 0.0
	var half_angle := _encounter_melee_half_angle()
	var angle := attack_direction.angle()
	if aiming:
		var progress := clampf(1.0 - windup / attack_duration, 0.0, 1.0)
		var reach := _encounter_melee_hit_reach() + speed * _encounter_lunge_speed_factor() * ENCOUNTER_LUNGE_TIME
		_draw_attack_fan(angle, half_angle, reach, progress)
		var hand := attack_direction * 10.0 + Vector2(0, -12)
		draw_line(hand, hand - Vector2(attack_direction.x * 11.0, 22), Color("412420"), 7.0, true)
		draw_line(hand, hand - Vector2(attack_direction.x * 11.0, 22), Color("ffe2a0"), 3.0, true)
	else:
		var progress := 1.0 - lunge_time / ENCOUNTER_LUNGE_TIME
		var blade_angle := angle + lerpf(-half_angle, half_angle, progress)
		draw_arc(Vector2.ZERO, _encounter_melee_hit_reach() * 0.8,
			maxf(angle - half_angle, blade_angle - 0.55), blade_angle + 0.001, 12, Color(1.0, 0.89, 0.63, 1.0 if lunge_time > 0.0 else impact_cue), 5.0, true)

func _draw_attack_fan(angle: float, half_angle: float, reach: float, progress: float) -> void:
	var points := PackedVector2Array([Vector2.ZERO])
	for i in range(17):
		points.append(Vector2.from_angle(angle + lerpf(-half_angle, half_angle, i / 16.0)) * reach)
	draw_colored_polygon(points, Color(1.0, 0.31, 0.12, lerpf(0.24, 0.49, progress)))
	draw_polyline(points + PackedVector2Array([Vector2.ZERO]), Color("ffad59"), 2.5, true)

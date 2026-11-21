extends SurvivorEnemy

const HEALTH := 3200.0
const APPROACH_SPEED := 205.0
const SWEEP_REACH := 102.0
const SWEEP_HALF_ANGLE := 1.32
const SWEEP_WINDUP := 0.78
const SWEEP_DAMAGE := 18.0
const CHARGE_REACH := 165.0
const CHARGE_WIDTH := 34.0
const CHARGE_WINDUP := 0.85
const CHARGE_SPEED := 450.0
const CHARGE_DAMAGE := 20.0
const RECOVERY := 1.05
const IMPACT_TIME := 0.16

func _ready() -> void:
	kind = Kind.BOSS
	v41_pressure = true
	super._ready()
	max_health = HEALTH
	health = max_health
	speed = APPROACH_SPEED
	visual.scale = Vector2.ONE * 1.5

func _boss_process(delta: float) -> void:
	flash = maxf(0.0, flash - delta)
	boss_timer -= delta
	repath -= delta
	var offset := player.global_position - global_position
	var visible := _boss_has_sight(player.global_position)
	if visible:
		boss_last_seen = player.global_position
		boss_has_last_seen = true
		boss_searching = false
	match boss_state:
		BossState.APPROACH:
			var reach := SWEEP_REACH - 14.0 if boss_next_attack == 0 else CHARGE_REACH
			if visible:
				if not offset.is_zero_approx():
					boss_charge_aim = offset.normalized()
				var can_reach := boss_next_attack == 0 or _boss_open_charge_distance(CHARGE_REACH) + CHARGE_WIDTH >= offset.length()
				if boss_timer <= 0.0 and offset.length() <= reach and can_reach:
					_begin_attack()
				elif offset.length() > reach or not can_reach:
					velocity = _follow_path(player.global_position) * speed
					move_and_slide()
			else:
				velocity = _boss_search() * speed
				move_and_slide()
		BossState.COMBO_WINDUP:
			if boss_timer <= 0.0:
				if visible and offset.length() <= SWEEP_REACH and absf(boss_charge_aim.angle_to(offset)) <= SWEEP_HALF_ANGLE:
					player.take_damage(SWEEP_DAMAGE, offset.normalized())
				_finish_attack(1)
		BossState.CHARGE_WINDUP:
			if boss_timer <= 0.0:
				boss_state = BossState.CHARGING
				boss_charge_remaining = boss_charge_distance
				boss_charge_hit = false
		BossState.CHARGING:
			var start := global_position
			var travel := minf(boss_charge_remaining, CHARGE_SPEED * delta)
			var collision := move_and_collide(boss_charge_aim * travel)
			var closest := Geometry2D.get_closest_point_to_segment(player.global_position, start, global_position)
			if not boss_charge_hit and closest.distance_to(player.global_position) <= CHARGE_WIDTH and _boss_has_sight(player.global_position):
				boss_charge_hit = true
				player.take_damage(CHARGE_DAMAGE, boss_charge_aim)
			boss_charge_remaining -= travel
			if collision or boss_charge_remaining <= 0.0:
				_finish_attack(0)
		BossState.RECOVERY:
			if boss_timer <= 0.0:
				boss_state = BossState.APPROACH
	visual.update_pose(get_real_velocity() if boss_state == BossState.APPROACH else Vector2.ZERO, boss_charge_aim, Color("e6a451"))
	queue_redraw()

func _follow_path(target: Vector2) -> Vector2:
	# A centre ray can clear a pillar while the body's radius still hits it.
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = $CollisionShape2D.shape
	query.transform = global_transform
	query.motion = target - global_position
	query.collision_mask = world.terrain_movement_mask
	var clearance := get_world_2d().direct_space_state.cast_motion(query)
	if global_position.distance_to(target) < 130.0 and clearance[0] >= 1.0:
		return (target - global_position).normalized()
	if path.is_empty() or repath <= 0.0:
		path = world.path_between(global_position, target)
		# Visit the first safe centre instead of cutting across its corner.
		path_index = 0
		repath = 0.55
	while path_index < path.size() and global_position.distance_to(path[path_index]) < 10.0:
		path_index += 1
	if path_index < path.size():
		return (path[path_index] - global_position).normalized()
	return Vector2.ZERO

func _begin_attack() -> void:
	if boss_next_attack == 0:
		boss_state = BossState.COMBO_WINDUP
		boss_timer = SWEEP_WINDUP
	else:
		boss_state = BossState.CHARGE_WINDUP
		boss_timer = CHARGE_WINDUP
		boss_charge_distance = _boss_open_charge_distance(CHARGE_REACH)

func _finish_attack(next_attack: int) -> void:
	boss_next_attack = next_attack
	boss_state = BossState.RECOVERY
	boss_timer = RECOVERY

func _draw() -> void:
	draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 36, Color("e6a451"), 3.0, true)
	match boss_state:
		BossState.COMBO_WINDUP:
			_draw_attack_fan(boss_charge_aim.angle(), SWEEP_HALF_ANGLE, SWEEP_REACH, 1.0 - boss_timer / SWEEP_WINDUP)
		BossState.CHARGE_WINDUP:
			var end := boss_charge_aim * (boss_charge_distance + CHARGE_WIDTH)
			var side := boss_charge_aim.orthogonal() * CHARGE_WIDTH
			var lane := PackedVector2Array([side, end + side, end - side, -side])
			draw_colored_polygon(lane, Color(1.0, 0.31, 0.12, lerpf(0.24, 0.49, 1.0 - boss_timer / CHARGE_WINDUP)))
			draw_polyline(lane + PackedVector2Array([side]), Color("ffad59"), 2.5, true)
		BossState.CHARGING:
			draw_line(Vector2.ZERO, -boss_charge_aim * 48.0, Color("ffe2a0"), 7.0, true)
		BossState.RECOVERY:
			var glow := clampf(1.0 - (RECOVERY - boss_timer) / IMPACT_TIME, 0.0, 1.0)
			if glow > 0.0 and boss_next_attack == 1:
				var angle := boss_charge_aim.angle()
				draw_arc(Vector2.ZERO, SWEEP_REACH, angle - SWEEP_HALF_ANGLE, angle + SWEEP_HALF_ANGLE, 24,
					Color(1.0, 0.89, 0.63, glow), 5.0, true)

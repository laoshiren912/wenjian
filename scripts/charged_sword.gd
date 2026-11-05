extends SurvivorWeapon

signal heavy_hit

@export var stages: Array[Dictionary] = [
	{"name": "横斩", "windup": 0.08, "active": 0.10, "recovery": 0.16, "damage": 32.0, "reach": 90.0, "angle": 100.0, "lunge": 8.0},
	{"name": "反向斜斩", "windup": 0.10, "active": 0.12, "recovery": 0.18, "damage": 40.0, "reach": 90.0, "angle": 110.0, "lunge": 10.0},
	{"name": "重劈", "windup": 0.16, "active": 0.14, "recovery": 0.30, "damage": 60.0, "reach": 100.0, "angle": 70.0, "lunge": 12.0},
]
@export var click_buffer: float = 0.30
@export var chain_window: float = 0.35
@export var roll_buffer: float = 0.12
@export_group("Charged sword")
@export_range(0.01, 1.0, 0.01) var hold_threshold: float = 0.22
@export_range(0.01, 3.0, 0.01) var charge_duration: float = 0.60
@export var charged_attack: Dictionary = {"name": "蓄力劈砍", "windup": 0.16, "active": 0.16, "recovery": 0.36, "reach": 140.0, "angle": 120.0, "lunge": 0.0}
@export var charge_damage_min: float = 65.0
@export var charge_damage_max: float = 95.0
@export var charge_knockback_min: float = 180.0
@export var charge_knockback_max: float = 260.0
@export_range(0.0, 1.0, 0.01) var charge_move_multiplier: float = 1.0
@export_range(0.0, 1.0, 0.01) var release_move_multiplier: float = 0.35
var gesture_held := false
var release_pending := false
var release_direction := Vector2.RIGHT
var hold_time := 0.0
var charging := false
var charge_time := 0.0
var charged_swing := false
var released_power := 0.0
var stage := -1
var next_stage := 0
var chain_time := 0.0
var click_time := 0.0
var roll_queued := false
var hit_done := false

func current_data() -> Dictionary:
	if charged_swing:
		return charged_attack
	return stages[maxi(stage, 0)]

func charge_fraction() -> float:
	return clampf(charge_time / maxf(0.001, charge_duration), 0.0, 1.0)

func press_primary() -> void:
	if not get_parent().dead and not get_parent().is_rolling() and not gesture_held:
		gesture_held = true
		hold_time = 0.0

func release_primary() -> void:
	var direction: Vector2 = release_direction if release_pending else get_parent().aim_direction
	release_pending = false
	if not gesture_held:
		return
	gesture_held = false
	if charging:
		_release_charge(direction)
	else:
		queue_click()
	hold_time = 0.0

func bow_blocked() -> bool:
	return charging or gesture_held

func clear_inputs() -> void:
	click_time = 0.0
	roll_queued = false
	gesture_held = false
	release_pending = false
	hold_time = 0.0
	charging = false
	charge_time = 0.0
	get_parent().visual.charge_aim = Vector2.ZERO
	queue_redraw()

func reset_chain() -> void:
	clear_inputs()
	next_stage = 0
	chain_time = 0.0

func queue_click() -> void:
	if not get_parent().dead and not get_parent().is_rolling():
		click_time = click_buffer

func queue_roll() -> void:
	if can_roll():
		get_parent()._roll_requested = true
	elif time_until_roll() <= roll_buffer + 0.00001:
		roll_queued = true

func can_roll() -> bool:
	return swing_time <= 0.0 or ((charged_swing or stage == 2) and phase() == "recovery")

func time_until_roll() -> float:
	if (charged_swing or stage == 2) and swing_time > 0.0:
		return maxf(0.0, swing_time - float(current_data().recovery) / get_parent().attack_speed_multiplier)
	return swing_time

func tick_inputs(delta: float) -> void:
	var player = get_parent()
	# A requested roll gets the first attempt; only success clears the gesture.
	if player._roll_requested and can_roll():
		return
	if release_pending:
		release_primary()
	if can_roll() and roll_queued:
		# Only a successful roll may cancel a held charge.
		roll_queued = false
		player._roll_requested = true
		return
	var available: bool = swing_time <= 0.0 and not player.is_rolling() and player.ranged_weapon.swing_time <= 0.0
	if gesture_held and available and not player._roll_requested:
		if not charging:
			hold_time += delta
			if hold_time + 0.000001 >= hold_threshold:
				charging = true
				charge_time = maxf(0.0, hold_time - hold_threshold)
				click_time = 0.0
				next_stage = 0
				chain_time = 0.0
		else:
			charge_time = minf(charge_duration, charge_time + delta)
		queue_redraw()
	elif gesture_held and not charging:
		hold_time = 0.0
	if available and not charging and not gesture_held and click_time > 0.0 and not player._roll_requested:
		attack(player.aim_direction)
	click_time = maxf(0.0, click_time - delta)

func _release_charge(direction: Vector2) -> void:
	released_power = charge_fraction()
	charging = false
	charge_time = 0.0
	charged_swing = true
	stage = -1
	next_stage = 0
	chain_time = 0.0
	click_time = 0.0
	swing_direction = direction.normalized()
	swing_duration = (float(charged_attack.windup) + float(charged_attack.active) + float(charged_attack.recovery)) / get_parent().attack_speed_multiplier
	swing_time = swing_duration
	swing_weapon = 0
	hit_done = false
	sword_hit_targets.clear()
	attack_count += 1
	attack_started.emit(0, swing_direction)
	show()
	queue_redraw()

func attack(direction: Vector2) -> bool:
	var player = get_parent()
	if charging or swing_time > 0.0 or player.dead or player.is_rolling() or player.ranged_weapon.swing_time > 0.0:
		return false
	charged_swing = false
	stage = next_stage if chain_time > 0.0 else 0
	var data := current_data()
	swing_direction = _sword_assist(direction.normalized())
	swing_duration = (float(data.windup) + float(data.active) + float(data.recovery)) / player.attack_speed_multiplier
	swing_time = swing_duration
	swing_weapon = 0
	hit_done = false
	sword_hit_targets.clear()
	click_time = 0.0
	chain_time = 0.0
	attack_count += 1
	attack_started.emit(0, swing_direction)
	show()
	return true

func phase() -> String:
	if swing_time <= 0.0:
		return "idle"
	var data := current_data()
	var elapsed: float = (swing_duration - swing_time) * get_parent().attack_speed_multiplier
	if elapsed < float(data.windup):
		return "windup"
	return "active" if elapsed < float(data.windup) + float(data.active) else "recovery"

func active_progress(time_left: float) -> float:
	var data := current_data()
	var elapsed: float = (swing_duration - time_left) * get_parent().attack_speed_multiplier
	return clampf((elapsed - float(data.windup)) / float(data.active), 0.0, 1.0)

func blade_angle(progress: float) -> float:
	var half := deg_to_rad(float(current_data().angle) * 0.5)
	if stage == 0:
		return lerpf(-half, half, progress)
	if stage == 1:
		return lerpf(half, -half, progress)
	return lerpf(-half, half, progress)

func blade_segment(progress: float) -> PackedVector2Array:
	var reach: float = float(current_data().reach) + get_parent().reach_bonus
	if stage == 2 and not charged_swing:
		# Height is projected along screen Y, never mirrored with aim direction.
		# The blade drops from overhead onto the aimed ground position.
		return PackedVector2Array([swing_direction * 13.0 + Vector2(0, lerpf(-20.0, 0.0, progress)), swing_direction * reach + Vector2(0, lerpf(-52.0, 0.0, progress))])
	var direction := swing_direction.rotated(blade_angle(progress))
	return PackedVector2Array([direction * 13.0, direction * reach])

func lunge_velocity(delta: float) -> Vector2:
	if swing_time <= 0.0 or delta <= 0.0:
		return Vector2.ZERO
	var fraction := active_progress(maxf(0.0, swing_time - delta)) - active_progress(swing_time)
	return swing_direction * float(current_data().lunge) * fraction / delta

func _physics_process(delta: float) -> void:
	if get_parent().dead:
		return
	if swing_time <= 0.0:
		chain_time = maxf(0.0, chain_time - delta)
		if chain_time <= 0.0:
			next_stage = 0
		return
	var previous := swing_time
	swing_time = maxf(0.0, swing_time - delta)
	_sweep(previous, swing_time)
	if swing_time <= 0.0:
		next_stage = 0 if charged_swing else (stage + 1) % stages.size()
		chain_time = chain_window if next_stage != 0 else 0.0
	queue_redraw()

func _sweep(previous: float, current: float) -> void:
	var data := current_data()
	var speed_scale: float = get_parent().attack_speed_multiplier
	var elapsed_before := (swing_duration - previous) * speed_scale
	var elapsed_after := (swing_duration - current) * speed_scale
	if (hit_done and not charged_swing) or elapsed_after < float(data.windup) or elapsed_before > float(data.windup) + float(data.active):
		return
	var from_angle := blade_angle(active_progress(previous))
	var to_angle := blade_angle(active_progress(current))
	var candidates: Array[Node2D] = []
	var player = get_parent()
	# Sweep a moving blade segment; do not hit the whole fan at windup completion.
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.dead or enemy.is_queued_for_deletion() or sword_hit_targets.has(enemy):
			continue
		var offset: Vector2 = enemy.global_position - player.global_position
		if stage == 2:
			var reach: float = float(data.reach) + player.reach_bonus
			if offset.length() > reach + 17.0 or absf(swing_direction.angle_to(offset)) > deg_to_rad(float(data.angle) * 0.5) + atan2(17.0, maxf(1.0, offset.length())):
				continue
		var contact := false
		var steps := maxi(1, ceili(absf(to_angle - from_angle) / deg_to_rad(3.0)))
		for sample in range(steps + 1):
			var progress := lerpf(active_progress(previous), active_progress(current), float(sample) / steps)
			var segment := blade_segment(progress)
			var nearest := Geometry2D.get_closest_point_to_segment(offset, segment[0], segment[1])
			if offset.distance_to(nearest) <= 17.0:
				contact = true
				break
		if not contact:
			continue
		var ray := PhysicsRayQueryParameters2D.create(player.global_position, enemy.global_position, 1)
		if get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
			candidates.append(enemy)
	if candidates.is_empty():
		return
	candidates.sort_custom(func(a, b): return a.global_position.distance_squared_to(player.global_position) < b.global_position.distance_squared_to(player.global_position))
	if charged_swing:
		for enemy in candidates:
			sword_hit_targets.append(enemy)
			_deal_hit(enemy, lerpf(charge_damage_min, charge_damage_max, released_power) * player.damage_multiplier, swing_direction * lerpf(charge_knockback_min, charge_knockback_max, released_power))
		if not hit_done:
			heavy_hit.emit()
		hit_done = true
		return
	hit_done = true
	sword_hit_targets.append(candidates[0])
	_deal_hit(candidates[0], float(data.damage) * player.damage_multiplier, swing_direction * (210.0 if stage == 2 else 115.0))
	if stage == 2:
		heavy_hit.emit()

func _deal_hit(target: Node2D, damage: float, push: Vector2) -> void:
	target.take_damage(damage, push)

func _draw() -> void:
	if charging:
		var aim: Vector2 = get_parent().aim_direction
		var half := deg_to_rad(float(charged_attack.angle) * 0.5)
		var reach: float = float(charged_attack.reach) + get_parent().reach_bonus
		var color := Color("ffd58c") if charge_fraction() < 1.0 else Color("b8f8ff")
		var fan := PackedVector2Array([Vector2.ZERO])
		for i in range(25):
			fan.append(aim.rotated(lerpf(-half, half, i / 24.0)) * reach)
		draw_colored_polygon(fan, Color(color, 0.08))
		draw_polyline(fan, Color(color, 0.35), 1.0, true)
		draw_arc(Vector2.ZERO, 30.0, -PI / 2.0, -PI / 2.0 + maxf(0.001, charge_fraction() * TAU), 48, color, 3.0, true)
		draw_line(aim * 13.0 + Vector2(0, -20), aim * 62.0 + Vector2(0, -48), color, 6.0, true)
		return
	if swing_time <= 0.0:
		super._draw()
		return
	var progress := active_progress(swing_time)
	var reach: float = float(current_data().reach) + get_parent().reach_bonus
	var segment := blade_segment(progress)
	var color := Color("aeefff") if charged_swing else (Color("ffe0a1") if stage != 2 else Color("ffbd76"))
	draw_line(segment[0], segment[1], color, 8.0 if charged_swing else (4.0 if stage != 2 else 6.0), true)
	if phase() == "active":
		var angle := swing_direction.angle()
		var start := blade_angle(maxf(0.0, progress - 0.25))
		var finish := blade_angle(progress)
		if stage != 2:
			draw_arc(Vector2.ZERO, reach, angle + minf(start, finish), angle + maxf(start, finish) + 0.001, 16, Color(color, 0.5), 6.0, true)
		else:
			var previous_segment := blade_segment(maxf(0.0, progress - 0.25))
			draw_colored_polygon(PackedVector2Array([previous_segment[0], previous_segment[1], segment[1], segment[0]]), Color(color, 0.25))

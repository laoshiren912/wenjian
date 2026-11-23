extends "res://scripts/charged_sword.gd"

# Optional motion prototype. Existing V3.4 combat keeps its original weapon.
var start_pose: Dictionary = {}

func clear_inputs() -> void:
	super.clear_inputs()
	if is_instance_valid(get_parent().ranged_weapon):
		sync_motion()

func attack(direction: Vector2) -> bool:
	var previous := motion_pose()
	var started := super.attack(direction)
	if started:
		start_pose = previous
		sync_motion()
	return started

func _release_charge(direction: Vector2) -> void:
	var previous := motion_pose()
	super._release_charge(direction)
	start_pose = previous
	sync_motion()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	sync_motion()

func blade_angle(progress: float) -> float:
	var half := deg_to_rad(float(current_data().angle) * 0.5)
	var eased := progress * progress * (3.0 - 2.0 * progress)
	return lerpf(-half, half, eased) * (-1.0 if stage == 1 else 1.0)

func _orbit_pose(angle: float, reach: float, torso: float, lean: Vector2, aim: Vector2) -> Dictionary:
	# The wrist orbits the shoulder more slowly than the blade. This produces a
	# real hilt pivot instead of a rigid radial line pinned to the actor centre.
	var grip := aim.rotated(angle * 0.55) * 18.0 + lean
	var blade := aim.rotated(angle)
	return {"grip": grip, "tip": grip + blade * (reach - 18.0), "torso": aim.rotated(torso), "lean": lean, "support": charged_swing or stage == 2}

func active_pose(progress: float) -> Dictionary:
	var angle := blade_angle(progress)
	var reach: float = float(current_data().reach) + get_parent().reach_bonus
	var lean := swing_direction * sin(progress * PI) * (5.0 if stage == 2 or charged_swing else 2.0)
	return _orbit_pose(angle, reach, angle * 0.6, lean, swing_direction)

func blade_segment(progress: float) -> PackedVector2Array:
	var pose := active_pose(progress)
	return PackedVector2Array([pose.grip, pose.tip])

func _blend_pose(from: Dictionary, to: Dictionary, amount: float) -> Dictionary:
	var t := smoothstep(0.0, 1.0, clampf(amount, 0.0, 1.0))
	var lean: Vector2 = (from.lean as Vector2).lerp(to.lean, t)
	var from_grip: Vector2 = from.grip - from.lean
	var to_grip: Vector2 = to.grip - to.lean
	var grip := Vector2.from_angle(lerp_angle(from_grip.angle(), to_grip.angle(), t)) * lerpf(from_grip.length(), to_grip.length(), t) + lean
	var from_blade: Vector2 = from.tip - from.grip
	var to_blade: Vector2 = to.tip - to.grip
	var blade := Vector2.from_angle(lerp_angle(from_blade.angle(), to_blade.angle(), t)) * lerpf(from_blade.length(), to_blade.length(), t)
	return {"grip": grip, "tip": grip + blade, "torso": Vector2.from_angle(lerp_angle((from.torso as Vector2).angle(), (to.torso as Vector2).angle(), t)), "lean": lean, "support": to.support}

func motion_pose() -> Dictionary:
	var aim: Vector2 = get_parent().aim_direction
	if charging:
		var pose := _orbit_pose(-2.25, float(stages[0].reach) + get_parent().reach_bonus, -0.7, -aim * 3.0, aim)
		pose.support = true
		return pose
	if swing_time <= 0.0:
		return _orbit_pose(0.95, float(stages[0].reach) + get_parent().reach_bonus, 0.0, Vector2.ZERO, aim)
	var data := current_data()
	var elapsed: float = (swing_duration - swing_time) * get_parent().attack_speed_multiplier
	if phase() == "windup":
		var t := elapsed / float(data.windup)
		var sign := -1.0 if stage == 1 else 1.0
		var cocked := _orbit_pose(-sign * (2.5 if stage == 2 or charged_swing else 2.1), float(data.reach) + get_parent().reach_bonus, -sign * 0.8, -swing_direction * 3.0, swing_direction)
		if t < 0.55:
			return _blend_pose(start_pose if not start_pose.is_empty() else active_pose(0.0), cocked, t / 0.55)
		return _blend_pose(cocked, active_pose(0.0), (t - 0.55) / 0.45)
	if phase() == "active":
		return active_pose(active_progress(swing_time))
	var recovery := (elapsed - float(data.windup) - float(data.active)) / float(data.recovery)
	var finish := active_pose(1.0)
	var follow := _orbit_pose(blade_angle(1.0) + (-0.5 if stage == 1 else 0.5), float(data.reach) + get_parent().reach_bonus, (-0.8 if stage == 1 else 0.8), swing_direction * 2.0, swing_direction)
	if recovery < 0.3:
		return _blend_pose(finish, follow, recovery / 0.3)
	var rest := _orbit_pose(0.95, float(stages[0].reach) + get_parent().reach_bonus, 0.0, Vector2.ZERO, swing_direction)
	return _blend_pose(follow, rest, (recovery - 0.3) / 0.7)

func display_pose(pose: Dictionary) -> Dictionary:
	return pose

func display_segment(progress: float) -> PackedVector2Array:
	var pose := display_pose(active_pose(progress))
	return PackedVector2Array([pose.grip, pose.tip])

func sync_motion() -> void:
	var actor = get_parent()
	actor.visual.z_index = 1
	if actor.is_rolling() or actor.dead or actor.ranged_weapon.swing_time > 0.0:
		actor.visual.sword_pose = {}
		z_index = 0
		return
	var pose := display_pose(motion_pose())
	actor.visual.sword_pose = pose
	# Keep both passes above the floor; a negative Z would put the rear sword
	# beneath the room background instead of just behind the actor.
	var rear: bool = pose.get("rear", (pose.grip as Vector2).y < -3.0)
	z_index = 0 if rear else 2
	queue_redraw()

func _draw() -> void:
	var actor = get_parent()
	if actor.is_rolling() or actor.dead or actor.ranged_weapon.swing_time > 0.0 or not actor.visual.bow_aim.is_zero_approx():
		return
	var pose := display_pose(motion_pose())
	var color := Color("aeefff") if charged_swing and swing_time > 0.0 else Color("eceddb")
	if charging:
		var aim: Vector2 = get_parent().aim_direction
		var half := deg_to_rad(float(charged_attack.angle) * 0.5)
		var reach: float = float(charged_attack.reach) + get_parent().reach_bonus
		color = Color("ffd58c") if charge_fraction() < 1.0 else Color("b8f8ff")
		var fan := PackedVector2Array([Vector2.ZERO])
		for i in range(25):
			fan.append(aim.rotated(lerpf(-half, half, i / 24.0)) * reach)
		draw_colored_polygon(fan, Color(color, 0.08))
		draw_polyline(fan, Color(color, 0.35), 1.0, true)
		draw_arc(Vector2.ZERO, 30.0, -PI / 2.0, -PI / 2.0 + maxf(0.001, charge_fraction() * TAU), 48, color, 3.0, true)
	if swing_time > 0.0 and phase() == "active":
		var progress := active_progress(swing_time)
		var previous := display_segment(maxf(0.0, progress - 0.4))
		for i in range(1, 9):
			var segment := display_segment(lerpf(maxf(0.0, progress - 0.4), progress, i / 8.0))
			draw_colored_polygon(PackedVector2Array([previous[0], previous[1], segment[1], segment[0]]), Color(color, i / 8.0 * 0.20))
			previous = segment
	_draw_blade(pose.grip, pose.tip, color)

func _draw_blade(grip: Vector2, tip: Vector2, color: Color) -> void:
	var direction := (tip - grip).normalized()
	var side := direction.orthogonal()
	var base := grip + direction * 6.0
	# Tapered steel, central ridge, crossguard and wrapped grip remain readable
	# without textures. All endpoints come from the collision/hand pose.
	var edge := PackedVector2Array([base - side * 3.5, tip - direction * 9.0 - side * 2.0, tip, tip - direction * 9.0 + side * 2.0, base + side * 3.5])
	draw_colored_polygon(edge, color.darkened(0.28))
	draw_colored_polygon(PackedVector2Array([base, tip, base + side * 3.5]), color)
	draw_line(base, tip - direction * 6.0, Color.WHITE, 1.0, true)
	draw_line(grip - side * 7.0, grip + side * 7.0, Color("d8b16b"), 3.0, true)
	draw_line(grip - direction * 10.0, grip, Color("394a53"), 4.5, true)
	draw_circle(grip - direction * 11.0, 2.5, Color("e1bf78"))

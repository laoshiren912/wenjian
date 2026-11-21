extends "res://scripts/sword_orbit.gd"

const CONFIG = preload("res://scripts/v41_config.gd")
const COLORS := [Color("ffeece"), Color("68e4f5"), Color("c4b2ff")]
# Toggle only this replacement for local A/B comparison.
const USE_MID_SLASH_V2 := true
const MID_SLASH_ATLAS = preload("res://assets/vfx/mid-horizontal-slash-v2/mid_horizontal_slash_v2_atlas_4x4.png")
const MID_SLASH_CELL := Vector2(256, 256)
const MID_SLASH_GRIP := Vector2(64, 154)
const MID_SLASH_SCALE := 0.55
const MID_SLASH_EDGE_GAP := 7.0
const MID_SLASH_PEAK_START := 0.50
const MID_SLASH_FADE := 0.10
# Bright leading edge near the moving tip, measured in source frame coordinates.
const MID_SLASH_LEADS := [
	Vector2(138, 205), Vector2(144, 192), Vector2(153, 178), Vector2(153, 157),
	Vector2(153, 140), Vector2(149, 122), Vector2(144, 102), Vector2(133, 90),
]
signal finisher_contact(point: Vector2)
signal guard_broken(point: Vector2)
var dash_reward := false
var heavy_reward := false
var dash_armed := false
var swing_bonus := 1.0
var card_multiplier := 1.0
var swing_rank := 0
var impact_sent := false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	chain_window = 0.30
	stages = stages.duplicate(true)
	for i in range(stages.size()):
		stages[i].windup = CONFIG.SWORD_TIMINGS[i].x
		stages[i].active = CONFIG.SWORD_TIMINGS[i].y
		stages[i].recovery = CONFIG.SWORD_TIMINGS[i].z

func blade_segment(progress: float) -> PackedVector2Array:
	var reach: float = float(current_data().reach) + get_parent().reach_bonus + CONFIG.SWORD_EXTENSION[swing_rank]
	if stage != 2:
		var direction := swing_direction.rotated(blade_angle(progress))
		return PackedVector2Array([direction * 13.0, direction * reach])
	# Project the heavy cut from overhead onto the aimed line early in the active window.
	var drop := smoothstep(0.0, 0.58, progress)
	return PackedVector2Array([
		swing_direction * 13.0 + Vector2.UP * CONFIG.THIRD_GRIP_LIFT * (1.0 - drop),
		swing_direction * reach * lerpf(0.79, 1.0, drop) + Vector2.UP * CONFIG.THIRD_TIP_LIFT * (1.0 - drop)])

func clear_chain_memory() -> void:
	next_stage = 0
	chain_time = 0.0

func _held_pose() -> Dictionary:
	# A relaxed side carry is independent of the cursor.
	return {"grip": Vector2(15, -3), "tip": Vector2(47, 27),
		"torso": Vector2.DOWN, "lean": Vector2.ZERO, "support": false}

func _swing_pose(progress: float, aim := Vector2.ZERO) -> Dictionary:
	if aim.is_zero_approx():
		aim = swing_direction
	var turn := -1.0 if stage == 1 else 1.0
	var angle := lerpf(-1.65, 1.65, progress) * turn
	var radial := aim.rotated(angle)
	# The wrist leads the blade. Its offset keeps the sword off the head axis.
	var wrist := aim.rotated(angle + turn * 0.8) * 19.0
	var lean := radial * 3.0
	var grip := Vector2(wrist.x, wrist.y * 0.65 - 8.0) + lean
	var blade := radial.rotated(-turn * 0.32) * (62.0 if charged_swing else 49.0)
	var lift := 9.0 + 10.0 * sin(progress * PI)
	if not charged_swing and stage == 2:
		var segment := blade_segment(progress)
		return {"grip": segment[0], "tip": segment[1], "torso": aim,
			"lean": aim * 3.0, "support": true, "rear": false}
	return {"grip": grip, "tip": grip + Vector2(blade.x, blade.y * 0.78 - lift),
		"torso": aim.rotated(angle * 0.65), "lean": lean,
		"support": charged_swing or stage == 2, "rear": wrist.y < -1.0}

func motion_pose() -> Dictionary:
	if charging:
		var pose := _swing_pose(0.0, get_parent().aim_direction)
		pose.support = true
		return pose
	if swing_time <= 0.0:
		return _held_pose()
	var data := current_data()
	var elapsed: float = (swing_duration - swing_time) * get_parent().attack_speed_multiplier
	if phase() == "windup":
		return _blend_pose(start_pose if not start_pose.is_empty() else _held_pose(),
			_swing_pose(0.0), elapsed / float(data.windup))
	if phase() == "active":
		return _swing_pose(active_progress(swing_time))
	var recovery: float = (elapsed - float(data.windup) - float(data.active)) / float(data.recovery)
	return _blend_pose(_swing_pose(1.0), _held_pose(), recovery)

func display_segment(progress: float) -> PackedVector2Array:
	var ground := blade_segment(progress)
	var tip: Vector2 = get_parent().visual.sword_tip(swing_direction, stage, progress, ground[1])
	return PackedVector2Array([tip, ground[1]])

func sync_motion() -> void:
	super.sync_motion()
	if _uses_mid_slash_v2() and swing_time > 0.0:
		z_index = 0
	if get_parent().dead:
		queue_redraw()

func _draw() -> void:
	if swing_time <= 0.0 or get_parent().dead or get_parent().is_rolling() or phase() == "windup":
		return
	var progress := active_progress(swing_time)
	if _uses_mid_slash_v2():
		_draw_mid_slash_v2(progress)
		return
	var recovery := 0.0
	if phase() == "recovery":
		recovery = 1.0 - swing_time * get_parent().attack_speed_multiplier / float(current_data().recovery)
	if recovery > (0.80 if stage == 2 else 0.42):
		return
	var opacity := (1.0 - smoothstep(0.0, 0.80 if stage == 2 else 0.42, recovery))
	var color: Color = COLORS[swing_rank]
	var start := maxf(0.0, progress - (0.55 if stage == 2 else 0.43))
	var previous := display_segment(start)
	for i in range(1, 11):
		var t := i / 10.0
		var sample := lerpf(start, progress, t)
		var edge := display_segment(sample)
		_draw_ribbon(previous, edge, color, opacity * t, swing_rank)
		previous = edge
	if progress > 0.03:
		var edge := display_segment(progress)
		var turn := -1.0 if stage == 1 else 1.0
		var tangent := (edge[1] - edge[0]).normalized().orthogonal() * turn
		var bend := edge[0].lerp(edge[1], 0.63) - tangent * (5.0 + swing_rank * 2.5)
		draw_polyline(PackedVector2Array([edge[0], bend, edge[1]]), Color(color.lightened(0.57), opacity * 0.82),
			2.0 + swing_rank + (1.5 if stage == 2 else 0.0), true)
	if stage == 2 and swing_rank > 0 and progress >= 0.38:
		_draw_heavy_wake(color, opacity, recovery)

func _uses_mid_slash_v2() -> bool:
	return USE_MID_SLASH_V2 and stage == 0 and swing_rank == 1 and not charged_swing

func _mid_slash_active_frame(progress: float) -> int:
	# Give the brightest cel half of the active swing. A single physics
	# sample near the end can disappear entirely between rendered frames.
	if progress >= MID_SLASH_PEAK_START:
		return 8
	return mini(1 + int(progress * 7.0 / MID_SLASH_PEAK_START), 7)

func _draw_mid_slash_v2(progress: float) -> void:
	var frame := _mid_slash_active_frame(progress)
	if phase() == "recovery":
		var fade_time: float = float(current_data().recovery) - swing_time * get_parent().attack_speed_multiplier
		if fade_time >= MID_SLASH_FADE:
			return
		frame = 9 + mini(int(maxf(0.0, fade_time) * 6.0 / MID_SLASH_FADE), 5)

	# The first endpoint from display_segment is the tip drawn by the character
	# renderer. Its other endpoint is the farther ground-plane hit projection.
	var hand: Vector2 = get_parent().visual.sword_hand(swing_direction, stage, progress)
	var tip := display_segment(progress)[0]
	var blade := tip - hand
	var axis := blade.normalized()
	var source_lead: Vector2 = MID_SLASH_LEADS[mini(frame, 8) - 1] - MID_SLASH_GRIP
	# The authored sweep runs upward when aimed right. Flip it to follow
	# this swing, then align that frame's leading edge with the blade.
	source_lead.y = -source_lead.y
	var rotation_to_blade := source_lead.angle_to(axis)
	var origin := tip + axis * (MID_SLASH_EDGE_GAP - source_lead.length() * MID_SLASH_SCALE)
	var cell := Vector2(frame % 4, frame >> 2)
	draw_set_transform(origin, rotation_to_blade, Vector2(MID_SLASH_SCALE, -MID_SLASH_SCALE))
	draw_texture_rect_region(MID_SLASH_ATLAS, Rect2(-MID_SLASH_GRIP, MID_SLASH_CELL),
		Rect2(cell * MID_SLASH_CELL, MID_SLASH_CELL))
	draw_set_transform(Vector2.ZERO)

func _draw_ribbon(previous: PackedVector2Array, edge: PackedVector2Array, color: Color, alpha: float, rank: int) -> void:
	if previous[1].distance_squared_to(edge[1]) < 0.01:
		return
	var inner := 0.10 if stage == 2 else lerpf(0.30, 0.07, maxf(0.0, alpha))
	var inner_start := previous[0].lerp(previous[1], inner)
	var inner_end := edge[0].lerp(edge[1], inner)
	var glow := Color(color, alpha * (0.19 + rank * 0.09 + (0.08 if stage == 2 else 0.0)))
	if absf((previous[1] - inner_start).cross(edge[1] - inner_start)) > 0.01:
		draw_colored_polygon(PackedVector2Array([inner_start, previous[1], edge[1]]), glow)
	if absf((edge[1] - inner_start).cross(inner_end - inner_start)) > 0.01:
		draw_colored_polygon(PackedVector2Array([inner_start, edge[1], inner_end]), glow)
	draw_line(previous[1], edge[1], Color(color, alpha * 0.87), 2.0 + rank * 1.6 + (2.0 if stage == 2 else 0.0), true)
	var core_start := previous[1].lerp(inner_start, 0.2)
	var core_end := edge[1].lerp(inner_end, 0.2)
	draw_line(core_start, core_end, Color(Color.WHITE, alpha * 0.80), 1.5, true)
	if rank == 2:
		draw_line(previous[0].lerp(previous[1], 0.43), edge[0].lerp(edge[1], 0.43), Color(color.lightened(0.3), alpha * 0.62), 2.0, true)

func _draw_heavy_wake(color: Color, alpha: float, recovery: float) -> void:
	var tip := blade_segment(1.0)[1]
	var tangent := swing_direction.orthogonal()
	var base := tip * 0.24
	for i in range(-1, 2):
		if i != 0 and swing_rank < 2:
			continue
		var spread := tangent * i * (13.0 + recovery * 19.0)
		var peak := base.lerp(tip, 0.67) + spread + Vector2.UP * (10.0 if i == 0 else 4.0)
		var wing := tangent * (10.0 if i == 0 else 5.0)
		draw_colored_polygon(PackedVector2Array([base, peak - wing, tip, peak + wing]), Color(color, alpha * 0.32))
		draw_polyline(PackedVector2Array([base, peak, tip]), Color(color.lightened(0.55), alpha * 0.85), 2.0 if i else 4.0, true)

func _draw_blade(_grip: Vector2, _tip: Vector2, _color: Color) -> void:
	# V4.1's character sprite already contains the weapon.
	pass

func attack(direction: Vector2) -> bool:
	if get_parent().dash_state != 0 or is_instance_valid(get_parent().thrown_sword) or swing_time > 0.0:
		return false
	swing_rank = get_parent().cultivation
	if not super.attack(direction):
		return false
	swing_bonus = consume_dash_bonus()
	impact_sent = false
	get_parent().sword_cue.emit("heavy_swing" if stage == 2 else "light_swing", global_position)
	return true

func consume_dash_bonus() -> float:
	var bonus := CONFIG.DASH_SWORD_FACTOR if dash_reward and dash_armed else 1.0
	dash_armed = false
	return bonus

func _sweep(previous: float, current: float) -> void:
	var player = get_parent()
	var limit := 1 + swing_rank if stage == 2 else 1
	if sword_hit_targets.size() >= limit:
		return
	var data := current_data()
	var elapsed_before: float = (swing_duration - previous) * player.attack_speed_multiplier
	var elapsed_after: float = (swing_duration - current) * player.attack_speed_multiplier
	if elapsed_after < float(data.windup) or elapsed_before > float(data.windup) + float(data.active):
		return
	var first := active_progress(previous)
	var last := active_progress(current)
	var reach: float = float(data.reach) + player.reach_bonus + CONFIG.SWORD_EXTENSION[swing_rank]
	var candidates: Array[Node2D] = []
	for target in get_tree().get_nodes_in_group("enemies"):
		if target.dead or target.emerging or target.is_queued_for_deletion() or sword_hit_targets.has(target):
			continue
		var offset: Vector2 = target.global_position - global_position
		if offset.length_squared() > (reach + 17.0) * (reach + 17.0):
			continue
		if stage == 2:
			var half := deg_to_rad(float(data.angle) * 0.5) + atan2(17.0, maxf(1.0, offset.length()))
			if last < CONFIG.THIRD_IMPACT_PROGRESS or absf(swing_direction.angle_to(offset)) > half:
				continue
		var contact := false
		for i in range(7):
			var sample := lerpf(first, last, i / 6.0)
			if stage == 2 and sample < CONFIG.THIRD_IMPACT_PROGRESS:
				continue
			var segment := blade_segment(sample)
			var nearest := Geometry2D.get_closest_point_to_segment(offset, segment[0], segment[1])
			if offset.distance_squared_to(nearest) <= 17.0 * 17.0:
				contact = true
				break
		if contact:
			var ray := PhysicsRayQueryParameters2D.create(global_position, target.global_position, player.terrain_mask)
			if get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
				candidates.append(target)
	candidates.sort_custom(func(a, b): return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position))
	for target in candidates:
		sword_hit_targets.append(target)
		_deal_hit(target, float(data.damage) * player.damage_multiplier, swing_direction * 115.0)
		if sword_hit_targets.size() >= limit:
			break

func _deal_hit(target: Node2D, damage: float, push: Vector2) -> void:
	var heavy_hit := stage == 2 and not charged_swing
	if target.dead or target.emerging:
		return
	var ordinary: bool = target is SurvivorEnemy and target.v41_pressure and target.kind == SurvivorEnemy.Kind.HOSTILE and not target.thrust_type
	var suppress: bool = heavy_hit and ordinary
	var break_guard: bool = heavy_hit and (heavy_reward or target is SurvivorEnemy and target.v41_pressure)
	if break_guard:
		target.guard_time = 0.0
		target.guard_visual_time = 0.0
		var opening := CONFIG.GUARD_BREAK_TIME if heavy_hit and heavy_reward else CONFIG.HEAVY_BASE_BREAK
		target.guard_cooldown = maxf(target.guard_cooldown, opening)
		if heavy_hit and heavy_reward:
			push = swing_direction * CONFIG.HEAVY_PUSH
	if heavy_hit and target is SurvivorEnemy and target.v41_pressure and target.kind != SurvivorEnemy.Kind.BOSS:
		push = swing_direction * CONFIG.THIRD_MOB_PUSH
	target.take_damage(damage * swing_bonus, push, false, false)
	if suppress and not target.dead:
		target.suppress_by_third_hit()
	if break_guard and ordinary:
		guard_broken.emit(target.global_position)
	if not impact_sent:
		impact_sent = true
		get_parent().sword_cue.emit("heavy_hit" if heavy_hit else "light_hit", target.global_position)
		if heavy_hit:
			finisher_contact.emit(target.global_position)
			self.heavy_hit.emit()

func queue_click() -> void:
	if not get_parent().dead:
		click_time = click_buffer

func tick_inputs(delta: float) -> void:
	var player = get_parent()
	if player.dash_state != 0 or is_instance_valid(player.thrown_sword) or (
			swing_time <= 0.0 and (not player.dash_request.is_zero_approx() or not player.throw_request.is_zero_approx())):
		click_time = maxf(0.0, click_time - delta)
		return
	super.tick_inputs(delta)

extends "res://scripts/sword_orbit.gd"

const CONFIG = preload("res://scripts/v41_config.gd")
const SlashVfx = preload("res://scripts/v41_slash_vfx.gd")
const SwordWave = preload("res://scripts/v41_sword_wave.gd")
const CARDS = preload("res://scripts/v41_card_pool.gd").Card
# Legacy mid-slash atlas disabled; procedural pixel shader vfx drives all three combo slots.
const USE_MID_SLASH_V2 := false
const MID_SLASH_ATLAS = preload("res://assets/vfx/mid-horizontal-slash-v2/mid_horizontal_slash_v2_atlas_4x4.png")
const SILVER_SLASH_ATLAS = preload("res://assets/vfx/combo-slash-v2/silver_atlas.png")
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
# One contact can emit a hit/blocked event plus break and kill events.
# Miss is emitted once after the active window, only if nothing was contacted.
signal combo_event(kind: String, slot: int, point: Vector2, target: Node2D)
var dash_armed := false
var swing_bonus := 1.0
var critical_slash_fired := false
var swing_rank := 0
var impact_sent := false
var miss_checked := false
var wave_fired := false
var slash_vfx: Node2D
var queued_direction := Vector2.ZERO

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	chain_window = CONFIG.COMBO_CHAIN_WINDOW
	click_buffer = CONFIG.COMBO_INPUT_BUFFER
	stages = stages.duplicate(true)
	for i in range(stages.size()):
		stages[i].windup = CONFIG.SWORD_TIMINGS[i].x
		stages[i].active = CONFIG.SWORD_TIMINGS[i].y
		stages[i].recovery = CONFIG.SWORD_TIMINGS[i].z
		stages[i].lunge = 0.0
	slash_vfx = SlashVfx.new()
	slash_vfx.name = "SlashVfx"
	add_child(slash_vfx)
	slash_vfx.bind_sword(self)

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

func preserve_chain_for_dash() -> void:
	clear_inputs()
	var preserved_next := next_stage if chain_time > 0.0 else 0
	if swing_time > 0.0:
		preserved_next = 0 if charged_swing else (stage + 1) % stages.size()
		swing_time = 0.0
	next_stage = preserved_next
	chain_time = CONFIG.DASH_CHAIN_WINDOW if next_stage != 0 else 0.0

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
	# Slot three has no replacement sprite yet. Keep its character animation,
	# but do not draw the obsolete geometric ribbon or wake.

func _uses_mid_slash_v2() -> bool:
	return USE_MID_SLASH_V2 and stage < 2 and not charged_swing

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
	# Reverse the authored sweep for the return stroke and realign its edge
	# to that stroke's actual sword tip.
	var flip_y := -1.0 if stage == 0 else 1.0
	source_lead.y *= flip_y
	var rotation_to_blade := source_lead.angle_to(axis)
	var scale_factor: float = [0.44, MID_SLASH_SCALE, 0.55][swing_rank]
	var origin := tip + axis * (MID_SLASH_EDGE_GAP - source_lead.length() * scale_factor)
	var cell := Vector2(frame % 4, frame >> 2)
	var atlas: Texture2D = SILVER_SLASH_ATLAS if swing_rank == 0 else MID_SLASH_ATLAS
	var tint := Color(0.78, 0.90, 1.0) if swing_rank == 2 else Color.WHITE
	draw_set_transform(origin, rotation_to_blade, Vector2(scale_factor, flip_y * scale_factor))
	draw_texture_rect_region(atlas, Rect2(-MID_SLASH_GRIP, MID_SLASH_CELL),
		Rect2(cell * MID_SLASH_CELL, MID_SLASH_CELL), tint)
	draw_set_transform(Vector2.ZERO)

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
	critical_slash_fired = false
	impact_sent = false
	miss_checked = false
	wave_fired = false
	get_parent().sword_cue.emit("heavy_swing" if stage == 2 else "light_swing", global_position)
	return true

func _sword_assist(direction: Vector2) -> Vector2:
	return direction if not direction.is_zero_approx() else Vector2.RIGHT

func _physics_process(delta: float) -> void:
	var player = get_parent()
	var freeze_chain: bool = not player.dead and player.dash_state != 0 and swing_time <= 0.0
	var saved_next := next_stage
	var saved_chain := chain_time
	var was_swinging: bool = swing_time > 0.0 and not charged_swing and not player.dead
	super._physics_process(delta)
	if freeze_chain:
		next_stage = saved_next
		chain_time = saved_chain
	if was_swinging and not miss_checked and active_progress(swing_time) >= 1.0:
		miss_checked = true
		if sword_hit_targets.is_empty():
			combo_event.emit("miss", stage, global_position, null)

func consume_dash_bonus() -> float:
	var bonus := CONFIG.DASH_SWORD_FACTOR if dash_armed else 1.0
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
	if stage == 2 and not charged_swing and not wave_fired and last >= CONFIG.THIRD_IMPACT_PROGRESS:
		wave_fired = true
		_fire_card_waves()
	var reach: float = float(data.reach) + player.reach_bonus + CONFIG.SWORD_EXTENSION[swing_rank]
	var candidates: Array[Node2D] = []
	for target in get_tree().get_nodes_in_group("enemies"):
		if target.dead or target.emerging or target.is_queued_for_deletion() or sword_hit_targets.has(target):
			continue
		var offset: Vector2 = target.global_position - global_position
		if offset.length_squared() > (reach + CONFIG.COMBO_TARGET_RADIUS) * (reach + CONFIG.COMBO_TARGET_RADIUS):
			continue
		if stage == 2:
			var half := deg_to_rad(float(data.angle) * 0.5) + atan2(CONFIG.COMBO_TARGET_RADIUS, maxf(1.0, offset.length()))
			if last < CONFIG.THIRD_IMPACT_PROGRESS or absf(swing_direction.angle_to(offset)) > half:
				continue
		var contact := false
		for i in range(7):
			var sample := lerpf(first, last, i / 6.0)
			if stage == 2 and sample < CONFIG.THIRD_IMPACT_PROGRESS:
				continue
			var segment := blade_segment(sample)
			var nearest := Geometry2D.get_closest_point_to_segment(offset, segment[0], segment[1])
			if offset.distance_squared_to(nearest) <= CONFIG.COMBO_TARGET_RADIUS * CONFIG.COMBO_TARGET_RADIUS:
				contact = true
				break
		if contact:
			var ray := PhysicsRayQueryParameters2D.create(global_position, target.global_position, player.terrain_mask)
			if get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
				candidates.append(target)
	candidates.sort_custom(func(a, b): return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position))
	for target in candidates:
		sword_hit_targets.append(target)
		_deal_hit(target, float(data.damage) * player.damage_multiplier, swing_direction * 155.0)
		if sword_hit_targets.size() >= limit:
			break

func _fire_card_waves() -> void:
	var player = get_parent()
	var lotus: int = player.card_level(CARDS.LOTUS)
	var wide: bool = player.card_level(CARDS.WIDE) > 0
	var fan: bool = player.card_level(CARDS.FAN) > 0
	if lotus == 0 and not wide and not fan:
		return
	var angles := [-0.28, 0.0, 0.28] if fan else [0.0]
	for angle in angles:
		var wave := SwordWave.new()
		wave.owner_actor = player
		wave.direction = swing_direction.rotated(angle)
		wave.position = player.get_parent().to_local(global_position)
		wave.damage = (36.0 + 12.0 * maxi(0, lotus - 1) if fan else 32.0 + 12.0 * maxi(0, lotus - 1)) * player.damage_multiplier
		wave.rank = swing_rank
		wave.terrain_mask = player.terrain_mask
		wave.empowered = fan
		wave.breaks_guard = fan
		wave.jade_trail = wide
		wave.hit_radius = 42.0 if wide else (30.0 if fan else 20.0)
		wave.max_distance = 490.0 if wide else (370.0 if fan else 290.0)
		player.get_parent().add_child(wave)

func _deal_hit(target: Node2D, damage: float, push: Vector2) -> void:
	var heavy_hit := stage == 2 and not charged_swing
	if target.dead or target.emerging:
		return
	var ordinary: bool = target is SurvivorEnemy and target.v41_pressure and target.kind == SurvivorEnemy.Kind.HOSTILE and not target.thrust_type
	var is_elite: bool = target is SurvivorEnemy and target.v41_guard_elite
	var suppress: bool = heavy_hit and ordinary
	var was_guarding: bool = target is SurvivorEnemy and target.has_method("is_guarding_stance") and target.is_guarding_stance()
	var backstab := false
	if target is SurvivorEnemy:
		backstab = get_parent().is_rear_hit(target, swing_direction)
	# 解法一（身法绕背）：绕至精英怪/格挡怪背后攻击，直接无视护盾触发 100% 赤金大暴击
	var backstab_break: bool = (was_guarding or is_elite) and (backstab or target.guard_direction.dot(swing_direction) > 0.25)
	var posture_shattered := false
	var break_guard := false
	if is_elite and was_guarding and not backstab_break:
		# 精英怪正面架势条博弈：前两段削减极少并弹刀，第三段重击大幅削减架势（打满 1-2-3 或配合飞剑震碎）
		var posture_dmg := 68.0 if heavy_hit else 18.0
		posture_shattered = target.damage_posture(posture_dmg)
		break_guard = posture_shattered
	elif backstab_break and was_guarding:
		target.break_guard_stance(CONFIG.HEAVY_BASE_BREAK, CONFIG.BREAK_STUN)
		break_guard = true
	elif heavy_hit and target is SurvivorEnemy and target.v41_pressure and not is_elite:
		target.break_guard_stance(CONFIG.HEAVY_BASE_BREAK, CONFIG.BREAK_STUN)
		break_guard = true
	if heavy_hit and target is SurvivorEnemy and target.v41_pressure and target.kind != SurvivorEnemy.Kind.BOSS:
		push = swing_direction * CONFIG.THIRD_MOB_PUSH
	var is_crit: bool = backstab_break or posture_shattered or swing_bonus > 1.0 or (heavy_hit and break_guard) or (target is SurvivorEnemy and target.posture_broken_time > 0.0)
	var crit_mult := 1.5 if (backstab_break or posture_shattered) else 1.0
	var dealt := damage * swing_bonus * crit_mult
	var ignore_guard := break_guard or backstab_break or (heavy_hit and not is_elite)
	target.take_damage(dealt, push, ignore_guard, false, false, is_crit)
	if swing_bonus > 1.0 and not critical_slash_fired and target is SurvivorEnemy:
		critical_slash_fired = true
		get_parent().trigger_card_slash(target, swing_direction)
	combo_event.emit("blocked" if target.last_hit_blocked else "hit", stage, target.global_position, target)
	if target.last_hit_blocked and not heavy_hit:
		# 正面轻击触发金属弹刀与轻微震退（不阻塞玩家立刻按空格穿阵绕背破防）
		var owner_p := get_parent()
		if owner_p is SurvivorPlayer and not owner_p.dead:
			owner_p.move_and_collide(-swing_direction * 7.5)
	if (suppress or backstab_break or posture_shattered) and not target.dead and not target.last_hit_blocked:
		target.suppress_by_third_hit()
	if break_guard and (ordinary or backstab_break or posture_shattered):
		if was_guarding or posture_shattered:
			get_parent().report_guard_break(target, stage)
		else:
			guard_broken.emit(target.global_position)
			combo_event.emit("guard_break", stage, target.global_position, target)
	if target.dead:
		if backstab:
			get_parent().refresh_dash_from_card()
		combo_event.emit("kill", stage, target.global_position, target)
	if not impact_sent:
		impact_sent = true
		if heavy_hit or backstab_break or posture_shattered or not target.last_hit_blocked:
			get_parent().sword_cue.emit("heavy_hit" if (heavy_hit or backstab_break or posture_shattered) else "light_hit", target.global_position)
		if heavy_hit:
			finisher_contact.emit(target.global_position)
			self.heavy_hit.emit()

func queue_click(direction := Vector2.ZERO) -> void:
	if not get_parent().dead:
		click_time = click_buffer
		queued_direction = direction

func tick_inputs(delta: float) -> void:
	var player = get_parent()
	if click_time > 0.0 and swing_time <= 0.0 and player.dash_state == 0 \
			and not is_instance_valid(player.thrown_sword) and player.dash_request.is_zero_approx() \
			and player.throw_request.is_zero_approx():
		attack(queued_direction if not queued_direction.is_zero_approx() else player.aim_direction)
	click_time = maxf(0.0, click_time - delta)

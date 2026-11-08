extends "res://scripts/sword_orbit.gd"

const CONFIG = preload("res://scripts/v41_config.gd")
var roll_reward := false
var heavy_reward := false
var roll_armed := false
var swing_bonus := 1.0

func _ready() -> void:
	chain_window = 0.30

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
	var pose := _swing_pose(progress)
	return PackedVector2Array([pose.grip, pose.tip])

func attack(direction: Vector2) -> bool:
	if not super.attack(direction):
		return false
	swing_bonus = CONFIG.ROLL_SWORD_FACTOR if roll_reward and roll_armed else 1.0
	roll_armed = false
	return true

func _release_charge(direction: Vector2) -> void:
	swing_bonus = CONFIG.ROLL_SWORD_FACTOR if roll_reward and roll_armed else 1.0
	roll_armed = false
	super._release_charge(direction)

func _deal_hit(target: Node2D, damage: float, push: Vector2) -> void:
	var heavy_hit := stage == 2 and not charged_swing
	var suppress: bool = heavy_hit and target is SurvivorEnemy and target.v41_pressure and target.kind == SurvivorEnemy.Kind.HOSTILE and not target.thrust_type
	var break_guard: bool = heavy_hit and (heavy_reward or target is SurvivorEnemy and target.v41_pressure)
	if break_guard:
		target.guard_time = 0.0
		var opening := CONFIG.GUARD_BREAK_TIME if heavy_reward else CONFIG.HEAVY_BASE_BREAK
		target.guard_cooldown = maxf(target.guard_cooldown, opening)
		if heavy_reward:
			push = swing_direction * CONFIG.HEAVY_PUSH
	if suppress:
		push = Vector2.ZERO
	target.take_damage(damage * swing_bonus, push)
	if suppress and not target.dead:
		target.suppress_by_third_hit()

func can_roll() -> bool:
	return swing_time <= 0.0 or phase() == "recovery" or (not charged_swing and phase() == "windup")

func time_until_roll() -> float:
	return maxf(0.0, swing_time - float(current_data().recovery) / get_parent().attack_speed_multiplier)

func press_primary() -> void:
	if not get_parent().dead and not gesture_held:
		gesture_held = true
		hold_time = 0.0

func queue_click() -> void:
	if not get_parent().dead:
		# A tap during the roll survives until the first actionable frame.
		click_time = get_parent()._roll_remaining + click_buffer

func queue_roll() -> void:
	if not charged_swing and phase() == "active":
		roll_queued = true
	else:
		super.queue_roll()

func tick_inputs(delta: float) -> void:
	var player = get_parent()
	if charged_swing or swing_time <= 0.0 or not gesture_held or release_pending or player._roll_requested or roll_queued:
		super.tick_inputs(delta)
		return
	# Recognize the gesture during the swing without accumulating charge power.
	var held := minf(hold_threshold, hold_time + delta)
	if held + 0.000001 >= hold_threshold and phase() == "recovery" and not player.is_rolling() and player.ranged_weapon.swing_time <= 0.0:
		swing_time = 0.0
		hold_time = maxf(0.0, hold_threshold - delta)
		super.tick_inputs(delta)
	else:
		super.tick_inputs(delta)
		hold_time = minf(held, maxf(0.0, hold_threshold - delta))

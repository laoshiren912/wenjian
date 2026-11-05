extends SurvivorPlayer

const BOW_WINDUP := 0.5
const BOW_RECOVERY := 0.6
const BOW_DRAW_SPEED := 0.45
const BOW_RECOVERY_SPEED := 0.55
const BOW_RECOIL := 150.0
const BOW_RECOIL_DECELERATION := 500.0

var bow_windup_remaining := 0.0
var bow_recovery_remaining := 0.0
var _bow_recoil_velocity := Vector2.ZERO

func _tick_ranged_attack(delta: float, rolling: bool) -> void:
	if bow_recovery_remaining > 0.0:
		_bow_recoil_velocity = _bow_recoil_velocity.move_toward(Vector2.ZERO, BOW_RECOIL_DECELERATION * delta)
		bow_recovery_remaining = maxf(0.0, bow_recovery_remaining - delta)
		return
	if not dual_attack_enabled or rolling or weapon.swing_time > 0.0 or combo.bow_blocked():
		bow_windup_remaining = 0.0
		return
	if bow_windup_remaining > 0.0:
		bow_windup_remaining = maxf(0.0, bow_windup_remaining - delta)
		if bow_windup_remaining <= 0.000001:
			bow_windup_remaining = 0.0
			if ranged_weapon.attack(aim_direction):
				bow_recovery_remaining = BOW_RECOVERY
				_bow_recoil_velocity = -ranged_weapon.swing_direction * BOW_RECOIL
	elif _ranged_pending:
		bow_windup_remaining = BOW_WINDUP

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	visual.bow_aim = Vector2.ZERO
	visual.bow_pull = 0.0
	visual.bow_release = 0.0
	visual.bow_step = 0.0
	if dead or is_rolling() or not dual_attack_enabled or weapon.swing_time > 0.0 or combo.charging:
		return
	if bow_windup_remaining > 0.0:
		visual.bow_aim = aim_direction
		visual.bow_pull = 1.0 - bow_windup_remaining / BOW_WINDUP
	elif not _bow_recoil_velocity.is_zero_approx():
		visual.bow_aim = ranged_weapon.swing_direction
		visual.bow_release = ranged_weapon.swing_time / ranged_weapon.swing_duration
		visual.bow_step = 1.0 - _bow_recoil_velocity.length() / BOW_RECOIL

func movement_multiplier() -> float:
	if weapon.swing_time > 0.0 or combo.charging:
		return super.movement_multiplier()
	if bow_windup_remaining > 0.0:
		return BOW_DRAW_SPEED
	if bow_recovery_remaining > 0.0:
		return 0.15 if not _bow_recoil_velocity.is_zero_approx() else BOW_RECOVERY_SPEED
	return super.movement_multiplier()

func _ranged_recoil_velocity() -> Vector2:
	return _bow_recoil_velocity

func _clear_ranged_input() -> void:
	super._clear_ranged_input()
	bow_windup_remaining = 0.0

func try_roll() -> bool:
	var succeeded := super.try_roll()
	if succeeded:
		bow_windup_remaining = 0.0
		_bow_recoil_velocity = Vector2.ZERO
		if combo.roll_reward:
			combo.roll_armed = true
	return succeeded

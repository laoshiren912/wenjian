extends SurvivorPlayer

const V41_CONFIG = preload("res://scripts/v41_config.gd")
const BOW_WINDUP := 0.5
const BOW_RECOVERY := 0.6
const BOW_DRAW_SPEED := 0.45
const BOW_RECOVERY_SPEED := 0.55
const BOW_RECOIL := 150.0
const BOW_RECOIL_DECELERATION := 500.0

var bow_windup_remaining := 0.0
var bow_recovery_remaining := 0.0
var _bow_recoil_velocity := Vector2.ZERO
var move_energy := false
var move_echo := false
var move_return := false
var upgrade_energy := false
var upgrade_echo := false
var upgrade_return := false
var return_window := 0.0
var return_buffered := false
var roll_action := ""
var roll_primary_held := false
var gm_infinite_stamina := false

func v41_arrow_factor() -> float:
	if combo.roll_reward and combo.roll_armed:
		combo.roll_armed = false
		return V41_CONFIG.ROLL_SWORD_FACTOR
	return 1.0

func _unhandled_input(event: InputEvent) -> void:
	if is_rolling():
		if event.is_action_pressed("attack"):
			roll_action = "primary"
			roll_primary_held = true
			if event is InputEventMouseButton:
				_aim_viewport_position = event.position
				_has_aim_event = true
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("roll"):
			roll_action = "roll"
			roll_primary_held = false
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ranged_attack"):
			if move_return:
				return_buffered = true
			else:
				roll_action = "bow"
				roll_primary_held = false
	super._unhandled_input(event)

func _input(event: InputEvent) -> void:
	super._input(event)
	if is_rolling() and event.is_action_released("attack"):
		roll_primary_held = false

func _execute_roll_action() -> void:
	var action := roll_action
	var held := roll_primary_held
	roll_action = ""
	roll_primary_held = false
	if action == "roll":
		try_roll()
	elif action == "primary":
		combo.press_primary()
		if not held:
			combo.release_primary()
		combo.tick_inputs(0.0)
	elif action == "bow":
		_ranged_pending = true

func _finish_roll() -> void:
	super._finish_roll()
	if move_return:
		return_window = V41_CONFIG.RETURN_UPGRADED_WINDOW if upgrade_return else V41_CONFIG.RETURN_WINDOW
		if return_buffered:
			_fire_return_arrow()
	return_buffered = false
	_execute_roll_action()

func _fire_return_arrow() -> void:
	if dead or not dual_attack_enabled or not move_return or return_window <= 0.0:
		return
	return_window = 0.0
	bow_windup_remaining = 0.0
	combo.clear_chain_memory()
	var arrow = preload("res://scenes/projectile.tscn").instantiate()
	arrow.direction = aim_direction.normalized()
	arrow.damage = float(ranged_weapon.DATA[2].damage) * damage_multiplier * V41_CONFIG.RETURN_DAMAGE_FACTOR * v41_arrow_factor()
	arrow.v41_player_arrow = true
	arrow.camera_shake = false
	arrow.speed += projectile_speed_bonus
	arrow.max_distance = float(ranged_weapon.DATA[2].reach) + reach_bonus
	get_parent().add_child(arrow)
	arrow.global_position = global_position + arrow.direction * 23.0
	ranged_weapon.swing_direction = arrow.direction
	ranged_weapon.attack_count += 1
	bow_recovery_remaining = BOW_RECOVERY
	_bow_recoil_velocity = -arrow.direction * BOW_RECOIL

func _tick_ranged_attack(delta: float, rolling: bool) -> void:
	if not rolling and move_return and return_window > 0.0 and _ranged_pending:
		_fire_return_arrow()
		return
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
		combo.clear_chain_memory()
		bow_windup_remaining = BOW_WINDUP

func _physics_process(delta: float) -> void:
	if is_rolling() and _roll_remaining <= roll_duration * 0.5 and roll_action in ["primary", "roll"] and not return_buffered:
		if roll_action != "roll" or stamina >= roll_stamina_cost:
			_finish_roll()
	if not is_rolling():
		return_window = maxf(0.0, return_window - delta)
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
	if weapon.swing_time > 0.0 and not combo.charged_swing and combo.stage in [0, 1]:
		return V41_CONFIG.COMBO_FIRST_TWO_MOVE_FACTOR
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

func spend_stamina(amount: float) -> bool:
	if OS.is_debug_build() and gm_infinite_stamina:
		return true
	if not super.spend_stamina(amount):
		return false
	stamina_delay = V41_CONFIG.STAMINA_REGEN_DELAY
	return true

func try_roll() -> bool:
	var origin := global_position
	var succeeded := super.try_roll()
	if succeeded:
		roll_action = ""
		roll_primary_held = false
		return_window = 0.0
		return_buffered = false
		if move_echo:
			var echo = preload("res://scripts/v41_move_effect.gd").new()
			echo.kind = "echo"
			echo.damage = V41_CONFIG.ECHO_DAMAGE
			echo.radius = V41_CONFIG.ECHO_UPGRADED_RADIUS if upgrade_echo else V41_CONFIG.ECHO_RADIUS
			get_parent().add_child(echo)
			echo.global_position = origin
		bow_windup_remaining = 0.0
		_bow_recoil_velocity = Vector2.ZERO
		if combo.roll_reward:
			combo.roll_armed = true
	return succeeded

extends SurvivorPlayer

const V41_CONFIG = preload("res://scripts/v41_config.gd")
var move_energy := false
var move_echo := false
var upgrade_energy := false
var upgrade_echo := false
var roll_action := ""
var roll_charge_held := false
var left_held := false
var gm_infinite_stamina := false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack"):
		left_held = true
		if event is InputEventMouseButton:
			_aim_viewport_position = event.position
			_has_aim_event = true
		if is_rolling() or _roll_requested:
			roll_action = "primary"
			roll_charge_held = false
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ranged_attack"):
		if event is InputEventMouseButton:
			_aim_viewport_position = event.position
			_has_aim_event = true
		if is_rolling() or _roll_requested:
			roll_action = "charge"
			roll_charge_held = true
		else:
			combo.press_primary()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("roll") and is_rolling():
		roll_action = "roll"
		roll_charge_held = false
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)

func _input(event: InputEvent) -> void:
	if event.is_action_released("attack"):
		if left_held:
			left_held = false
			if not is_rolling() and not _roll_requested:
				combo.queue_click()
		return
	if event.is_action_released("ranged_attack"):
		if is_rolling() or _roll_requested:
			roll_charge_held = false
		elif combo.gesture_held:
			if combo.charging:
				combo.release_direction = aim_direction
				combo.release_pending = true
			else:
				combo.clear_inputs()
		return
	super._input(event)

func _execute_roll_action() -> void:
	var action := roll_action
	var held := roll_charge_held
	roll_action = ""
	roll_charge_held = false
	if action == "roll":
		try_roll()
	elif action == "primary":
		if not left_held:
			combo.queue_click()
			combo.tick_inputs(0.0)
	elif action == "charge" and held:
		combo.press_primary()

func _finish_roll() -> void:
	super._finish_roll()
	_execute_roll_action()

func _tick_ranged_attack(_delta: float, _rolling: bool) -> void:
	pass

func _physics_process(delta: float) -> void:
	if is_rolling() and _roll_remaining <= roll_duration * 0.5 and roll_action in ["primary", "charge", "roll"]:
		if roll_action != "roll" or stamina >= roll_stamina_cost or (OS.is_debug_build() and gm_infinite_stamina):
			_finish_roll()
	super._physics_process(delta)

func movement_multiplier() -> float:
	if weapon.swing_time > 0.0 and not combo.charged_swing and combo.stage in [0, 1]:
		return V41_CONFIG.COMBO_FIRST_TWO_MOVE_FACTOR
	return super.movement_multiplier()

func spend_stamina(amount: float) -> bool:
	if OS.is_debug_build() and gm_infinite_stamina:
		return true
	if not super.spend_stamina(amount):
		return false
	stamina_delay = V41_CONFIG.STAMINA_REGEN_DELAY
	return true

func try_roll() -> bool:
	var origin := global_position
	var queued_action := roll_action
	var queued_held := roll_charge_held
	# A right-button press can arrive just before the roll request. Preserve a
	# pending hold across reset_chain, but keep an established charge cancellable.
	if queued_action == "" and combo.gesture_held and not combo.charging and not combo.release_pending:
		queued_action = "charge"
		queued_held = true
	var succeeded := super.try_roll()
	if succeeded:
		roll_action = queued_action if queued_action in ["primary", "charge"] else ""
		roll_charge_held = queued_held if roll_action == "charge" else false
		if move_echo:
			var echo = preload("res://scripts/v41_move_effect.gd").new()
			echo.kind = "echo"
			echo.damage = V41_CONFIG.ECHO_DAMAGE
			echo.radius = V41_CONFIG.ECHO_UPGRADED_RADIUS if upgrade_echo else V41_CONFIG.ECHO_RADIUS
			get_parent().add_child(echo)
			echo.global_position = origin
		if combo.roll_reward:
			combo.roll_armed = true
	return succeeded

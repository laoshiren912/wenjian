extends SurvivorPlayer

const V41_CONFIG = preload("res://scripts/v41_config.gd")
const DashTrace = preload("res://scripts/v41_dash_trace.gd")
const ThrownSword = preload("res://scripts/v41_thrown_sword.gd")
enum Dash { IDLE, WINDUP, TRAVEL, RECOVERY }
signal sword_cue(kind: String, point: Vector2)

var cultivation := 0
var gm_infinite_stamina := false
var terrain_mask := 1
var dash_state := Dash.IDLE
var dash_time := 0.0
var dash_cooldown := 0.0
var dash_direction := Vector2.RIGHT
var dash_rank := 0
var dash_buffer := 0.0
var dash_request := Vector2.ZERO
var dash_trace: DashTrace
var thrown_sword: ThrownSword
var throw_request := Vector2.ZERO
var throw_buffer := 0.0
var throw_cooldown := 0.0
var primary_after_throw := false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack") or event.is_action_pressed("ranged_attack"):
		if event is InputEventMouseButton:
			_aim_viewport_position = event.position
			_has_aim_event = true
		if event.is_action_pressed("ranged_attack"):
			_request_throw(_input_aim())
		elif is_instance_valid(thrown_sword):
			primary_after_throw = true
		elif dash_state == Dash.IDLE or (dash_state == Dash.RECOVERY and dash_time <= 0.10):
			combo.queue_click()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("roll"):
		request_dash(_input_aim())
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)

func _input_aim() -> Vector2:
	var point := get_global_mouse_position()
	if _has_aim_event:
		point = get_canvas_transform().affine_inverse() * _aim_viewport_position
	var offset := point - global_position
	return offset.normalized() if offset.length_squared() > 1.0 else aim_direction

func _notification(what: int) -> void:
	super._notification(what)
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_clear_dash_request()
		_clear_throw_request()
		primary_after_throw = false

func request_dash(direction: Vector2) -> void:
	if not dead and dash_state == Dash.IDLE and dash_cooldown <= 0.0 and dash_request.is_zero_approx():
		dash_request = direction.normalized()
		dash_buffer = 0.5

func _clear_dash_request() -> void:
	dash_request = Vector2.ZERO
	dash_buffer = 0.0

func _request_throw(direction: Vector2) -> void:
	if dead or dash_state != Dash.IDLE or is_instance_valid(thrown_sword) or throw_cooldown > 0.0 or not throw_request.is_zero_approx():
		return
	throw_request = direction.normalized()
	throw_buffer = 0.50

func _clear_throw_request() -> void:
	throw_request = Vector2.ZERO
	throw_buffer = 0.0

func _physics_process(delta: float) -> void:
	if dead:
		return
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	throw_cooldown = maxf(0.0, throw_cooldown - delta)
	throw_buffer = maxf(0.0, throw_buffer - delta)
	if throw_buffer <= 0.0:
		_clear_throw_request()
	if not is_instance_valid(thrown_sword):
		dash_buffer = maxf(0.0, dash_buffer - delta)
	if dash_buffer <= 0.0:
		_clear_dash_request()
	var normal_mask := collision_mask
	if dash_state == Dash.TRAVEL:
		collision_mask = terrain_mask
	super._physics_process(delta)
	collision_mask = normal_mask

func _tick_ranged_attack(delta: float, _rolling: bool) -> void:
	match dash_state:
		Dash.IDLE:
			if not is_instance_valid(thrown_sword) and combo.swing_time <= 0.0:
				if not dash_request.is_zero_approx() and knockback.is_zero_approx():
					_start_dash()
				elif not throw_request.is_zero_approx():
					_start_throw()
		Dash.WINDUP:
			dash_time -= delta
			if dash_time <= 0.00001:
				dash_state = Dash.TRAVEL
				dash_time = V41_CONFIG.DASH_TRAVEL
				dash_trace.start = global_position
				dash_trace.tip = global_position
				sword_cue.emit("dash", global_position)
		Dash.TRAVEL:
			_travel(delta)
		Dash.RECOVERY:
			dash_time -= delta
			if dash_time <= 0.00001:
				dash_state = Dash.IDLE
				dash_trace = null

func _start_dash() -> void:
	var direction := dash_request
	_clear_dash_request()
	if not spend_stamina(V41_CONFIG.DASH_COST):
		return
	dash_direction = direction
	dash_rank = cultivation
	dash_cooldown = V41_CONFIG.DASH_COOLDOWN
	dash_time = V41_CONFIG.DASH_WINDUP
	dash_state = Dash.WINDUP
	var bonus: float = combo.consume_dash_bonus() * combo.card_multiplier * damage_multiplier
	combo.dash_armed = combo.dash_reward
	_clear_throw_request()
	combo.reset_chain()
	visual.cancel_attack()
	dash_trace = DashTrace.new()
	dash_trace.owner_actor = self
	dash_trace.rank = dash_rank
	dash_trace.aim = direction
	dash_trace.start = global_position
	dash_trace.tip = global_position
	dash_trace.terrain_mask = terrain_mask
	dash_trace.damage = V41_CONFIG.DASH_DAMAGE[dash_rank] * bonus
	dash_trace.mark_damage = V41_CONFIG.DASH_MARK_DAMAGE[dash_rank] * combo.card_multiplier * damage_multiplier
	get_parent().add_child(dash_trace)

func _start_throw() -> void:
	var direction := throw_request
	_clear_throw_request()
	if not spend_stamina(V41_CONFIG.THROW_COST):
		return
	throw_cooldown = V41_CONFIG.THROW_COOLDOWN
	combo.reset_chain()
	visual.cancel_attack()
	thrown_sword = ThrownSword.new()
	thrown_sword.actor = self
	thrown_sword.rank = cultivation
	thrown_sword.aim = direction
	thrown_sword.terrain_mask = terrain_mask
	thrown_sword.power = combo.card_multiplier * damage_multiplier
	thrown_sword.opening_bonus = combo.consume_dash_bonus()
	primary_after_throw = false
	get_parent().add_child(thrown_sword)
	sword_cue.emit("throw_cast", global_position)

func finish_throw(flight: Node2D) -> void:
	if flight != thrown_sword:
		return
	thrown_sword = null
	if primary_after_throw and not dead:
		combo.queue_click()
	primary_after_throw = false

func clear_throw() -> void:
	_clear_throw_request()
	primary_after_throw = false
	if is_instance_valid(thrown_sword):
		thrown_sword.hide()
		thrown_sword.set_physics_process(false)
		thrown_sword.queue_free()
	thrown_sword = null

func _travel(delta: float) -> void:
	var step := minf(delta, dash_time)
	var motion: Vector2 = dash_direction * V41_CONFIG.DASH_DISTANCE[dash_rank] * step / V41_CONFIG.DASH_TRAVEL
	# Use the real player collision shape. Ignore enemy bodies for this move only.
	var wall := move_and_collide(motion)
	dash_trace.extend_to(global_position, visual.dash_ghost_pose(dash_direction))
	dash_time -= step
	if wall != null or dash_time <= 0.00001:
		dash_trace.seal()
		dash_time = V41_CONFIG.DASH_RECOVERY
		dash_state = Dash.RECOVERY

func clear_dash_effects() -> void:
	_clear_dash_request()
	dash_state = Dash.IDLE
	dash_time = 0.0
	dash_trace = null
	for child in get_parent().get_children():
		if child is DashTrace and child.owner_actor == self:
			child.hide()
			child.set_physics_process(false)
			child.queue_free()

func take_damage(amount: float, direction: Vector2) -> bool:
	if not super.take_damage(amount, direction):
		return false
	_clear_dash_request()
	if dead:
		clear_dash_effects()
		clear_throw()
	elif dash_state != Dash.IDLE:
		if is_instance_valid(dash_trace) and not dash_trace.sealed:
			dash_trace.seal()
			dash_trace.marks.clear()
		dash_trace = null
		dash_state = Dash.IDLE
		dash_time = 0.0
		combo.clear_inputs()
	return true

func movement_multiplier() -> float:
	if dash_state != Dash.IDLE:
		return 0.0
	if weapon.swing_time > 0.0 and combo.stage in [0, 1]:
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
	return false

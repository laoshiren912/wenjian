extends SurvivorPlayer

const V41_CONFIG = preload("res://scripts/v41_config.gd")
const DashTrace = preload("res://scripts/v41_dash_trace.gd")
const ThrownSword = preload("res://scripts/v41_thrown_sword.gd")
const SwordRain = preload("res://scripts/v41_sword_rain.gd")
const SwordWave = preload("res://scripts/v41_sword_wave.gd")
const CARDS = preload("res://scripts/v41_card_pool.gd").Card
enum Dash { IDLE, WINDUP, TRAVEL, RECOVERY }
signal sword_cue(kind: String, point: Vector2)
signal thunder_afterimage(point: Vector2, direction: Vector2, landing: bool)
signal card_lightning(points: PackedVector2Array)
signal card_slash(point: Vector2, direction: Vector2)

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
var throw_target_distance := -1.0
var throw_buffer := 0.0
var throw_cooldown := 0.0
var primary_after_throw := Vector2.ZERO
var sword_rain_node: Node2D
var sword_rain_cooldown := 0.0
var learned_cards: Array[int] = []
var dash_evade_grace := 0.0
var thunder_bombs: Array[Dictionary] = []
var input_locked := false
var aim_marker: Node2D

func _ready() -> void:
	super._ready()
	aim_marker = Node2D.new()
	aim_marker.z_index = 3
	aim_marker.hide()
	aim_marker.draw.connect(_draw_aim_marker)
	add_child(aim_marker)

func _process(_delta: float) -> void:
	aim_marker.queue_redraw()

func _draw_aim_marker() -> void:
	if dead or input_locked or not can_process():
		return
	var heading := _input_aim().angle()
	var crescent := PackedVector2Array()
	for i in range(13):
		var angle := lerpf(-0.43, 0.43, i / 12.0)
		crescent.append(Vector2.from_angle(heading + angle) * 30.0)
	for i in range(11, 0, -1):
		var angle := lerpf(-0.43, 0.43, i / 12.0)
		var radius := 30.0 - 4.0 * sin(PI * i / 12.0)
		crescent.append(Vector2.from_angle(heading + angle) * radius)
	var frost_gold := Color(0.89, 0.84, 0.62, 0.67)
	aim_marker.draw_colored_polygon(crescent, frost_gold)
	aim_marker.draw_polyline(crescent, Color(0.15, 0.19, 0.17, 0.46), 1.0, true)

func is_dash_evading() -> bool:
	return dash_state == Dash.TRAVEL or dash_evade_grace > 0.0

func card_level(card: int) -> int:
	return learned_cards[card] if card < learned_cards.size() else 0

func has_thunder_ghost() -> bool:
	return card_level(CARDS.THUNDER) > 0 or card_level(CARDS.CHAIN) > 0

func report_guard_break(enemy: SurvivorEnemy, slot: int) -> void:
	stamina = minf(max_stamina, stamina + 10.0 * card_level(CARDS.BLOOD))
	refresh_dash_from_card()
	combo.guard_broken.emit(enemy.global_position)
	combo.combo_event.emit("guard_break", slot, enemy.global_position, enemy)

func refresh_dash_from_card() -> void:
	if card_level(CARDS.REFRESH) > 0:
		dash_cooldown = 0.0

func is_rear_hit(enemy: SurvivorEnemy, direction: Vector2) -> bool:
	if card_level(CARDS.REFRESH) == 0:
		return false
	var facing: Vector2 = enemy.guard_direction if enemy.is_guarding_stance() else enemy.visual.look_direction
	return facing.dot(direction) > 0.55

func clear_line(from: Vector2, to: Vector2) -> bool:
	return from.is_equal_approx(to) or get_world_2d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters2D.create(from, to, terrain_mask)).is_empty()

func card_targets(point: Vector2, radius: float, exclude: Array = []) -> Array[SurvivorEnemy]:
	var targets: Array[SurvivorEnemy] = []
	for candidate in get_tree().get_nodes_in_group("enemies"):
		var enemy := candidate as SurvivorEnemy
		if enemy != null and not enemy.dead and not enemy.emerging and enemy not in exclude \
				and point.distance_squared_to(enemy.global_position) <= radius * radius and clear_line(point, enemy.global_position):
			targets.append(enemy)
	targets.sort_custom(func(a, b): return point.distance_squared_to(a.global_position) < point.distance_squared_to(b.global_position))
	return targets

func trigger_card_lightning(point: Vector2, source: SurvivorEnemy = null) -> void:
	if card_level(CARDS.CHAIN) == 0:
		return
	var points := PackedVector2Array([point])
	var struck: Array = [source]
	for i in range(3):
		var targets := card_targets(points[-1], 138.0, struck)
		if targets.is_empty():
			break
		var enemy := targets[0]
		struck.append(enemy)
		points.append(enemy.global_position)
		enemy.take_damage((28.0 - 4.0 * i) * damage_multiplier, Vector2.ZERO, false, false)
	if points.size() > 1:
		card_lightning.emit(points)

func trigger_card_slash(hit: SurvivorEnemy, direction: Vector2) -> void:
	var point := hit.global_position
	card_slash.emit(point, direction)
	for enemy in card_targets(point, 88.0, [hit]):
		enemy.take_damage(28.0 * damage_multiplier, direction * 45.0, false, false)

func split_thrown_sword(point: Vector2, direction: Vector2, source: SurvivorEnemy) -> void:
	var targets := card_targets(point, 230.0, [source])
	for i in range(2):
		var dart := SwordWave.new()
		dart.owner_actor = self
		dart.position = get_parent().to_local(point)
		dart.target = targets[i] if i < targets.size() else source
		var heading := point.direction_to(dart.target.global_position) if is_instance_valid(dart.target) and not dart.target.dead else direction
		if heading.is_zero_approx():
			heading = direction
		dart.direction = heading.rotated(-0.22 if i == 0 else 0.22)
		dart.damage = 22.0 * damage_multiplier
		dart.rank = cultivation
		dart.terrain_mask = terrain_mask
		dart.homing = true
		get_parent().add_child(dart)

func _unhandled_input(event: InputEvent) -> void:
	if dead or input_locked:
		return
	if event.is_action_pressed("attack") or event.is_action_pressed("ranged_attack"):
		if event is InputEventMouseButton:
			_aim_viewport_position = event.position
			_has_aim_event = true
		var offset := _input_mouse_world() - global_position
		aim_direction = offset.normalized() if offset.length_squared() > 1.0 else aim_direction
		if event.is_action_pressed("ranged_attack"):
			_request_throw(aim_direction, offset.length())
			if combo.swing_time <= 0.0 and not throw_request.is_zero_approx():
				_face_attack(throw_request)
		elif is_instance_valid(thrown_sword):
			primary_after_throw = aim_direction
		elif dash_state == Dash.IDLE or dash_state == Dash.RECOVERY or (dash_state == Dash.TRAVEL and dash_time <= 0.06):
			combo.queue_click(aim_direction)
			if combo.swing_time <= 0.0 and dash_state == Dash.IDLE:
				_face_attack(aim_direction)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("roll"):
		var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if not (Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right") \
				or Input.is_action_pressed("move_up") or Input.is_action_pressed("move_down")):
			direction = _input_aim()
		request_dash(direction)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var code: int = event.keycode if event.keycode != 0 else event.physical_keycode
		if code == KEY_E:
			request_sword_rain()
			get_viewport().set_input_as_handled()
			return
	super._unhandled_input(event)

func _face_attack(direction: Vector2) -> void:
	visual.update_pose(get_real_velocity(), direction, Color.WHITE, direction)

func _body_look(movement: Vector2, rolling_this_frame: bool) -> Vector2:
	if dash_state != Dash.IDLE:
		return dash_direction
	if is_instance_valid(thrown_sword):
		return thrown_sword.aim
	return super._body_look(movement, rolling_this_frame)

func _input_mouse_world() -> Vector2:
	if _has_aim_event:
		return get_canvas_transform().affine_inverse() * _aim_viewport_position
	return get_global_mouse_position()

func _input_aim() -> Vector2:
	var point := _input_mouse_world()
	var offset := point - global_position
	return offset.normalized() if offset.length_squared() > 1.0 else aim_direction

func _notification(what: int) -> void:
	super._notification(what)
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_clear_dash_request()
		_clear_throw_request()
		primary_after_throw = Vector2.ZERO
	if (what == NOTIFICATION_PAUSED or what == NOTIFICATION_UNPAUSED) and is_instance_valid(aim_marker):
		aim_marker.queue_redraw()

func request_dash(direction: Vector2) -> void:
	if dead or direction.is_zero_approx():
		return
	if dash_state in [Dash.IDLE, Dash.RECOVERY] and dash_cooldown <= V41_CONFIG.DASH_COOLDOWN_BUFFER:
		dash_request = direction.normalized()
		dash_buffer = maxf(0.50, dash_cooldown + 0.15)

func _clear_dash_request() -> void:
	dash_request = Vector2.ZERO
	dash_buffer = 0.0

func _request_throw(direction: Vector2, target_dist: float = -1.0) -> void:
	if dead or dash_state != Dash.IDLE or is_instance_valid(thrown_sword) or throw_cooldown > 0.0 or not throw_request.is_zero_approx():
		return
	throw_request = direction.normalized()
	throw_target_distance = target_dist
	throw_buffer = 0.50

func _clear_throw_request() -> void:
	throw_request = Vector2.ZERO
	throw_target_distance = -1.0
	throw_buffer = 0.0

func _physics_process(delta: float) -> void:
	if dead:
		return
	if input_locked:
		velocity = Vector2.ZERO
		if is_instance_valid(visual):
			visual.update_pose(Vector2.ZERO, Vector2.UP, Color.WHITE, Vector2.UP)
		return
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	throw_cooldown = maxf(0.0, throw_cooldown - delta)
	sword_rain_cooldown = maxf(0.0, sword_rain_cooldown - delta)
	dash_evade_grace = maxf(0.0, dash_evade_grace - delta)
	_tick_thunder_bombs(delta)
	throw_buffer = maxf(0.0, throw_buffer - delta)
	if throw_buffer <= 0.0:
		_clear_throw_request()
	dash_buffer = maxf(0.0, dash_buffer - delta)
	if dash_buffer <= 0.0:
		_clear_dash_request()
	var normal_mask := collision_mask
	if dash_state == Dash.TRAVEL:
		collision_mask = terrain_mask
	super._physics_process(delta)
	collision_mask = normal_mask

func _can_cancel_combo_for_dash() -> bool:
	if combo.swing_time <= 0.0:
		return true
	if combo.charged_swing:
		return false
	return combo.phase() == "recovery"

func _tick_ranged_attack(delta: float, _rolling: bool) -> void:
	match dash_state:
		Dash.IDLE:
			# 飞剑在途期间不再死锁玩家空格穿阵，提升连招流畅度
			if not dash_request.is_zero_approx() and dash_cooldown <= 0.0 and knockback.is_zero_approx() and _can_cancel_combo_for_dash():
				_start_dash()
			elif not is_instance_valid(thrown_sword) and combo.swing_time <= 0.0 and not throw_request.is_zero_approx():
				_start_throw()
		Dash.WINDUP:
			dash_time -= delta
			if dash_time <= 0.00001:
				dash_state = Dash.TRAVEL
				dash_time = V41_CONFIG.DASH_TRAVEL
				dash_trace.start = global_position
				dash_trace.tip = global_position
				sword_cue.emit("dash", global_position)
				if has_thunder_ghost():
					thunder_afterimage.emit(global_position, dash_direction, false)
					_queue_thunder_bomb(global_position)
		Dash.TRAVEL:
			_travel(delta)
		Dash.RECOVERY:
			dash_time -= delta
			var has_followup: bool = combo.click_time > 0.0 or not throw_request.is_zero_approx()
			if dash_time <= 0.00001 or (has_followup and dash_time <= V41_CONFIG.DASH_RECOVERY_CANCEL):
				dash_state = Dash.IDLE
				dash_time = 0.0
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
	combo.dash_armed = card_level(CARDS.CRITICAL) > 0
	_clear_throw_request()
	combo.preserve_chain_for_dash()
	visual.cancel_attack()
	dash_trace = DashTrace.new()
	dash_trace.owner_actor = self
	dash_trace.rank = dash_rank
	dash_trace.aim = direction
	dash_trace.start = global_position
	dash_trace.tip = global_position
	dash_trace.terrain_mask = terrain_mask
	dash_trace.damage = V41_CONFIG.DASH_DAMAGE[dash_rank] * damage_multiplier
	dash_trace.mark_damage = V41_CONFIG.DASH_MARK_DAMAGE[dash_rank] * damage_multiplier
	get_parent().add_child(dash_trace)

func _start_throw() -> void:
	var direction := throw_request
	var target_dist := throw_target_distance
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
	thrown_sword.target_distance = target_dist
	thrown_sword.terrain_mask = terrain_mask
	thrown_sword.power = damage_multiplier
	thrown_sword.opening_bonus = combo.consume_dash_bonus()
	primary_after_throw = Vector2.ZERO
	get_parent().add_child(thrown_sword)
	sword_cue.emit("throw_cast", global_position)

func finish_throw(flight: Node2D) -> void:
	if flight != thrown_sword:
		return
	thrown_sword = null
	if not primary_after_throw.is_zero_approx() and not dead:
		combo.queue_click(primary_after_throw)
	primary_after_throw = Vector2.ZERO

func clear_throw() -> void:
	_clear_throw_request()
	primary_after_throw = Vector2.ZERO
	if is_instance_valid(thrown_sword):
		thrown_sword.hide()
		thrown_sword.set_physics_process(false)
		thrown_sword.queue_free()
	thrown_sword = null

func sword_rain_base_cooldown() -> float:
	return V41_CONFIG.SWORD_RAIN_COOLDOWNS[cultivation]

func request_sword_rain() -> bool:
	if dead or sword_rain_cooldown > 0.0 or is_instance_valid(sword_rain_node):
		return false
	if not spend_stamina(V41_CONFIG.SWORD_RAIN_COST):
		return false
	sword_rain_cooldown = sword_rain_base_cooldown()
	var rain := SwordRain.new()
	rain.actor = self
	rain.rank = cultivation
	rain.empowered = card_level(CARDS.RAIN) > 0
	rain.opening_bonus = combo.consume_dash_bonus()
	rain.power = damage_multiplier
	rain.terrain_mask = terrain_mask
	sword_rain_node = rain
	get_parent().add_child(rain)
	return true

func finish_sword_rain(node: Node2D) -> void:
	if node == sword_rain_node:
		sword_rain_node = null

func clear_sword_rain() -> void:
	if is_instance_valid(sword_rain_node):
		sword_rain_node.hide()
		sword_rain_node.set_physics_process(false)
		sword_rain_node.queue_free()
	sword_rain_node = null

func is_casting_sword_rain() -> bool:
	return is_instance_valid(sword_rain_node) and sword_rain_node.is_casting()

func _travel(delta: float) -> void:
	var step := minf(delta, dash_time)
	var motion: Vector2 = dash_direction * V41_CONFIG.DASH_DISTANCE[dash_rank] * step / V41_CONFIG.DASH_TRAVEL
	# Use the real player collision shape. Ignore enemy bodies for this move only.
	var wall := move_and_collide(motion)
	dash_trace.extend_to(global_position, visual.dash_ghost_pose(dash_direction))
	dash_time -= step
	if wall != null or dash_time <= 0.00001:
		dash_trace.seal()
		dash_evade_grace = 0.07
		if has_thunder_ghost():
			thunder_afterimage.emit(global_position, dash_direction, true)
			_queue_thunder_bomb(global_position)
		dash_time = V41_CONFIG.DASH_RECOVERY
		dash_state = Dash.RECOVERY

func _queue_thunder_bomb(point: Vector2) -> void:
	thunder_bombs.append({
		"point": point,
		"left": V41_CONFIG.THUNDER_GHOST_DELAY,
		"damage": (26.0 + float(cultivation) * 8.0 + 12.0 * maxi(0, card_level(CARDS.THUNDER) - 1)) * damage_multiplier,
	})

func _tick_thunder_bombs(delta: float) -> void:
	for i in range(thunder_bombs.size() - 1, -1, -1):
		var bomb: Dictionary = thunder_bombs[i]
		bomb.left = float(bomb.left) - delta
		if float(bomb.left) <= 0.0:
			var center: Vector2 = bomb.point
			var dmg: float = float(bomb.damage)
			for enemy in card_targets(center, 92.0):
				var push := center.direction_to(enemy.global_position)
				var broke := enemy.break_guard_stance(V41_CONFIG.HEAVY_BASE_BREAK, V41_CONFIG.BREAK_STUN) if enemy.is_guarding_stance() else false
				enemy.take_damage(dmg, push * 110.0, true, false)
				if broke:
					report_guard_break(enemy, 2)
			sword_cue.emit("thunder_burst", center)
			trigger_card_lightning(center)
			thunder_bombs.remove_at(i)

func clear_dash_effects() -> void:
	_clear_dash_request()
	dash_state = Dash.IDLE
	dash_time = 0.0
	dash_trace = null
	thunder_bombs.clear()
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
		clear_sword_rain()
	else:
		if is_casting_sword_rain():
			clear_sword_rain()
			sword_rain_cooldown = minf(sword_rain_cooldown, V41_CONFIG.SWORD_RAIN_MIN_COOLDOWN)
		if dash_state != Dash.IDLE:
			var prev_state := dash_state
			if prev_state == Dash.WINDUP:
				stamina = minf(max_stamina, stamina + V41_CONFIG.DASH_COST * 0.5)
				dash_cooldown = minf(dash_cooldown, 0.40)
			elif prev_state == Dash.TRAVEL:
				dash_cooldown = minf(dash_cooldown, V41_CONFIG.DASH_INTERRUPT_COOLDOWN)
			if is_instance_valid(dash_trace) and not dash_trace.sealed:
				dash_trace.seal()
				dash_trace.marks.clear()
			dash_trace = null
			dash_state = Dash.IDLE
			dash_time = 0.0
			if prev_state != Dash.RECOVERY:
				combo.clear_inputs()
	return true

func movement_multiplier() -> float:
	if dash_state == Dash.WINDUP or dash_state == Dash.TRAVEL:
		return 0.0
	if dash_state == Dash.RECOVERY:
		return V41_CONFIG.DASH_RECOVERY_MOVE_FACTOR
	if is_casting_sword_rain():
		return V41_CONFIG.SWORD_RAIN_CAST_MOVE_FACTOR
	if weapon.swing_time > 0.0 and combo.stage in [0, 1]:
		return V41_CONFIG.COMBO_FIRST_TWO_MOVE_FACTOR
	return super.movement_multiplier()

func spend_stamina(amount: float) -> bool:
	if preload("res://scripts/test_runtime.gd").enabled() and gm_infinite_stamina:
		return true
	if not super.spend_stamina(amount):
		return false
	stamina_delay = V41_CONFIG.STAMINA_REGEN_DELAY
	return true

func try_roll() -> bool:
	return false

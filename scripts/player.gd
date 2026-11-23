class_name SurvivorPlayer
extends CharacterBody2D

signal died
signal level_gained
signal hurt
signal damage_received(amount: float)
signal experience_received(amount: int)

const PROFESSIONS: Array[Dictionary] = [
	{"name": "剑士", "weapon": 0, "health": 100.0, "speed": 225.0},
	{"name": "枪兵", "weapon": 1, "health": 150.0, "speed": 180.0},
	{"name": "弓箭手", "weapon": 2, "health": 80.0, "speed": 240.0},
]
const MANUAL_NAMES = ["旋风斩", "剑气", "乘势"]
const XP_BASE: int = 40
const XP_STEP: int = 10
const XP_ENEMY: int = 10
const XP_PASSIVE: int = 8
const XP_BOSS: int = 0
var _profession_index: int = 0
var profession_index: int:
	get:
		return _profession_index

@export_group("Roll")
@export_range(1.0, 500.0, 1.0) var roll_distance: float = 150.0
@export_range(0.05, 1.0, 0.01) var roll_duration: float = 0.34
@export_range(0.0, 200.0, 1.0) var roll_stamina_cost: float = 30.0
@export_range(0.0, 5.0, 0.01) var roll_cooldown: float = 0.65

@export_group("Bow movement")
@export_range(0.1, 1.0, 0.01) var bow_shot_move_multiplier: float = 0.55
@export_range(0.0, 1.0, 0.01) var bow_shot_move_duration: float = 0.24

var max_health: float = 100.0
var health: float = 100.0
var max_stamina: float = 100.0
var stamina: float = 100.0
var stamina_regen: float = 26.0
var stamina_delay: float = 0.0
var speed: float = 225.0
var damage_multiplier: float = 1.0
var attack_speed_multiplier: float = 1.0
var reach_bonus: float = 0.0
var angle_bonus: float = 0.0
var extra_targets: int = 0
var extra_arrows: int = 0
var projectile_speed_bonus: float = 0.0
var equipment_names: Array[String] = []
var skill_points: int = 0
var manuals: Array[int] = []
var manual_cooldowns: Array[float] = [0.0, 0.0]
var manual_levels: Array[int] = [1, 1]
const MANUAL_MAX_LEVEL: int = 4
var momentum_armed: float = 0.0
var momentum_ready: float = 0.0
var momentum_bonus: float = 1.7
var manual_flash: float = 0.0
var manual_effect: int = -1
var manual_direction: Vector2 = Vector2.RIGHT
var manual_origin: Vector2 = Vector2.ZERO
var damage_reduction: float = 0.0
var heal_on_kill: float = 0.0
var stamina_on_kill: float = 0.0
var level: int = 1
var experience: int = 0
var next_level_xp: int = XP_BASE
var total_experience: int = 0
var invulnerability: float = 0.0
var knockback: Vector2 = Vector2.ZERO
var aim_direction: Vector2 = Vector2.RIGHT
var _movement_facing: Vector2 = Vector2.DOWN
var _aim_viewport_position: Vector2 = Vector2.ZERO
var _has_aim_event: bool = false
var dead: bool = false
var gm_invulnerable: bool = false
var dry_attack_flash: float = 0.0
var _attack_held: bool = false
var _attack_pending: bool = false
var _click_target: Node2D = null
var _target_marker: Node2D = null
var _target_marker_remaining: float = 0.0
var _roll_requested: bool = false
var _roll_remaining: float = 0.0
var _roll_cooldown: float = 0.0
var _roll_direction: Vector2 = Vector2.DOWN
var _bow_shot_remaining: float = 0.0
var dual_attack_enabled: bool = false
@export var combo_enabled: bool = false
var combo
var ranged_weapon: SurvivorWeapon
var _ranged_held: bool = false
var _ranged_pending: bool = false
@onready var weapon: SurvivorWeapon = $Weapon
@onready var camera: Camera2D = $Camera2D
@onready var visual: ActorVisual = $VisualRoot

func _uses_charge() -> bool:
	return combo_enabled and is_instance_valid(combo) and combo.has_method("press_primary")

func _ready() -> void:
	if combo_enabled:
		combo = weapon
	weapon.attack_started.connect(_on_attack_started)
	weapon.selection_changed.connect(_on_weapon_selected)

func enable_dual_attack() -> void:
	if is_instance_valid(ranged_weapon):
		return
	dual_attack_enabled = true
	ranged_weapon = SurvivorWeapon.new()
	ranged_weapon.name = "RangedWeapon"
	add_child(ranged_weapon)
	ranged_weapon.select_weapon(2)
	ranged_weapon.hide()
	ranged_weapon.attack_started.connect(_on_attack_started)

func initialize_profession(index: int) -> bool:
	# The manager calls this once, while the start screen still pauses the world.
	if weapon.locked or not get_tree().paused or index < 0 or index >= PROFESSIONS.size():
		return false
	var data: Dictionary = PROFESSIONS[index]
	if not weapon.lock_to(int(data.weapon)):
		return false
	_profession_index = index
	max_health = float(data.health)
	health = max_health
	speed = float(data.speed)
	_attack_held = false
	_attack_pending = false
	_roll_requested = false
	return true

func _on_attack_started(index: int, direction: Vector2) -> void:
	if index == 2:
		_bow_shot_remaining = bow_shot_move_duration
		if combo_enabled:
			visual.play_attack(index, direction, ranged_weapon.swing_duration)
			return
	visual.play_attack(index, direction, weapon.swing_duration)
	if combo_enabled and index == 0:
		visual.set_combo_pose(0 if _uses_charge() and combo.charged_swing else combo.stage, combo.current_data())

func consume_momentum() -> float:
	if momentum_ready > 0.0:
		momentum_ready = 0.0
		return momentum_bonus
	return 1.0

func use_manual(slot: int) -> void:
	if dead or get_tree().paused or profession_index != 0 or slot < 0 or slot >= manuals.size() or manual_cooldowns[slot] > 0.0:
		return
	# A skill cancels an unfinished sword action, but never resets its cooldown.
	weapon.swing_time = 0.0
	if is_instance_valid(ranged_weapon):
		ranged_weapon.swing_time = 0.0
	manual_direction = aim_direction
	manual_origin = global_position
	manual_effect = manuals[slot]
	manual_flash = 0.25
	if not is_rolling():
		visual.play_attack(0, aim_direction, 0.25)
	var rank: int = manual_levels[slot]
	match manuals[slot]:
		0:
			manual_cooldowns[slot] = 6.0 - 0.4 * (rank - 1)
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if enemy.dead or global_position.distance_to(enemy.global_position) > 120.0:
					continue
				var ray := PhysicsRayQueryParameters2D.create(global_position, enemy.global_position, 1)
				if get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
					enemy.take_damage((45.0 + 15.0 * (rank - 1)) * damage_multiplier, (enemy.global_position - global_position).normalized() * 155.0)
		1:
			manual_cooldowns[slot] = 4.0
			var shot = SurvivorWeapon.PROJECTILE_SCENE.instantiate()
			shot.direction = aim_direction
			shot.damage = (65.0 + 20.0 * (rank - 1)) * damage_multiplier
			shot.sword_energy = true
			shot.speed = 500.0
			shot.max_distance = 340.0
			get_parent().add_child(shot)
			shot.global_position = global_position + aim_direction * 23.0
		2:
			manual_cooldowns[slot] = 6.0
			momentum_bonus = 1.7 + 0.25 * (rank - 1)
			if is_rolling():
				momentum_ready = 3.0
			else:
				momentum_armed = 4.0

func upgrade_manual(slot: int) -> bool:
	if slot < 0 or slot >= manuals.size() or skill_points <= 0 or manual_levels[slot] >= MANUAL_MAX_LEVEL:
		return false
	skill_points -= 1
	manual_levels[slot] += 1
	return true

func is_bow_recovering() -> bool:
	return weapon.selected == 2 and _bow_shot_remaining > 0.0 and not is_rolling()

func movement_multiplier() -> float:
	if _uses_charge():
		if combo.charging:
			return combo.charge_move_multiplier
		if combo.charged_swing and weapon.swing_time > 0.0:
			return combo.release_move_multiplier
	return 0.0 if weapon.swing_time > 0.0 or (is_instance_valid(ranged_weapon) and ranged_weapon.swing_time > 0.0) else 1.0

func _on_weapon_selected(_index: int) -> void:
	visual.cancel_attack()

func is_rolling() -> bool:
	return _roll_remaining > 0.0

func try_roll() -> bool:
	if combo_enabled and not combo.can_roll():
		return false
	if dead or get_tree().paused or is_rolling() or _roll_cooldown > 0.0:
		return false
	if not spend_stamina(roll_stamina_cost):
		return false
	var movement := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_roll_direction = movement.normalized() if not movement.is_zero_approx() else _movement_facing
	_roll_remaining = maxf(0.001, roll_duration)
	if momentum_armed > 0.0:
		momentum_armed = 0.0
		momentum_ready = 3.0
	_roll_cooldown = roll_cooldown
	if combo_enabled:
		combo.reset_chain()
	_attack_pending = false
	_click_target = null
	_target_marker = null
	_target_marker_remaining = 0.0
	# Existing hits/arrows and shared cooldown survive; only the recovery drawing ends.
	weapon.swing_time = 0.0
	if is_instance_valid(ranged_weapon):
		ranged_weapon.swing_time = 0.0
	_ranged_pending = false
	_bow_shot_remaining = 0.0
	weapon.hide()
	visual.play_roll(_roll_direction, _roll_remaining)
	return true

func _finish_roll() -> void:
	_roll_remaining = 0.0
	weapon.show()
	visual.stop_roll()

func _tick_ranged_attack(_delta: float, rolling: bool) -> void:
	if dual_attack_enabled and not rolling and weapon.swing_time <= 0.0 and (not _uses_charge() or not combo.bow_blocked()) and (_ranged_pending or (_ranged_held and Input.is_action_pressed("ranged_attack"))):
		ranged_weapon.attack(aim_direction)

func _ranged_recoil_velocity() -> Vector2:
	return Vector2.ZERO

func _physics_process(delta: float) -> void:
	if dead:
		return
	invulnerability = maxf(0.0, invulnerability - delta)
	for i in range(manual_cooldowns.size()):
		manual_cooldowns[i] = maxf(0.0, manual_cooldowns[i] - delta)
	momentum_armed = maxf(0.0, momentum_armed - delta)
	momentum_ready = maxf(0.0, momentum_ready - delta)
	manual_flash = maxf(0.0, manual_flash - delta)
	stamina_delay = maxf(0.0, stamina_delay - delta)
	dry_attack_flash = maxf(0.0, dry_attack_flash - delta)
	_target_marker_remaining = maxf(0.0, _target_marker_remaining - delta)
	if _target_marker_remaining <= 0.0 or not is_instance_valid(_target_marker):
		_target_marker = null
	_bow_shot_remaining = maxf(0.0, _bow_shot_remaining - delta)
	if stamina_delay <= 0.0:
		stamina = minf(max_stamina, stamina + stamina_regen * delta)
	_roll_cooldown = maxf(0.0, _roll_cooldown - delta)
	if _roll_requested and not combo_enabled:
		_roll_requested = false
		try_roll()
	var movement := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var rolling_this_frame: bool = is_rolling()
	var world_aim: Vector2 = get_global_mouse_position()
	if _has_aim_event:
		world_aim = get_viewport().get_canvas_transform().affine_inverse() * _aim_viewport_position
	var aim: Vector2 = world_aim - global_position
	if aim.length_squared() > 1.0:
		aim_direction = aim.normalized()
	if combo_enabled:
		combo.tick_inputs(delta)
		if _roll_requested:
			_roll_requested = false
			try_roll()
		rolling_this_frame = is_rolling()
	if not combo_enabled and not rolling_this_frame and (not is_instance_valid(ranged_weapon) or ranged_weapon.swing_time <= 0.0) and (_attack_pending or (_attack_held and Input.is_action_pressed("attack"))):
		var attack_direction := aim_direction
		if weapon.selected != 0 and _attack_pending and is_instance_valid(_click_target) and not _click_target.dead:
			var target_offset: Vector2 = _click_target.global_position - global_position
			if target_offset.length_squared() > 1.0:
				attack_direction = target_offset.normalized()
		if weapon.attack(attack_direction):
			_target_marker = _click_target if weapon.selected != 0 and _attack_pending and is_instance_valid(_click_target) and not _click_target.dead else null
			_target_marker_remaining = 0.65 if is_instance_valid(_target_marker) else 0.0
	_tick_ranged_attack(delta, rolling_this_frame)
	_ranged_pending = false
	if not rolling_this_frame:
		_attack_pending = false
		_click_target = null
	if rolling_this_frame:
		# Scale the final partial tick so unobstructed rolls cover the configured distance.
		var step: float = minf(delta, _roll_remaining)
		velocity = _roll_direction * (roll_distance / maxf(0.001, roll_duration)) * (step / delta) + knockback
	else:
		velocity = movement * speed * movement_multiplier() + knockback + _ranged_recoil_velocity()
		if combo_enabled:
			velocity += combo.lunge_velocity(delta)
	knockback = knockback.move_toward(Vector2.ZERO, 650.0 * delta)
	move_and_slide()
	var color := Color("79e2d0")
	if invulnerability > 0.0:
		color = Color("ffffff") if fmod(invulnerability, 0.16) > 0.08 else Color("e88385")
	if not rolling_this_frame and not movement.is_zero_approx():
		_movement_facing = Vector2(signf(movement.x), 0) if absf(movement.x) > absf(movement.y) else Vector2(0, signf(movement.y))
	var body_look := _body_look(movement, rolling_this_frame)
	if _uses_charge():
		visual.charge_aim = aim_direction if combo.charging else Vector2.ZERO
	visual.update_pose(get_real_velocity(), body_look, color, body_look)
	if rolling_this_frame:
		_roll_remaining = maxf(0.0, _roll_remaining - delta)
		if not is_rolling():
			_finish_roll()
	queue_redraw()

func _body_look(movement: Vector2, rolling_this_frame: bool) -> Vector2:
	var body_look: Vector2 = visual.facing
	if weapon.swing_time > 0.0:
		body_look = weapon.swing_direction
	elif is_instance_valid(ranged_weapon) and ranged_weapon.swing_time > 0.0:
		body_look = ranged_weapon.swing_direction
	elif _uses_charge() and combo.charging:
		body_look = aim_direction
	elif not movement.is_zero_approx():
		body_look = movement
	if rolling_this_frame:
		body_look = _roll_direction
	return body_look

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_aim_viewport_position = event.position
		_has_aim_event = true
	# Releases must clear the gesture even when a GUI control consumes them later.
	if event.is_action_released("attack"):
		_attack_held = false
		if _uses_charge():
			if event is InputEventMouseButton:
				_aim_viewport_position = event.position
				_has_aim_event = true
				var release_world: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * event.position
				var release_aim := release_world - global_position
				combo.release_direction = release_aim.normalized() if release_aim.length_squared() > 1.0 else aim_direction
			else:
				combo.release_direction = aim_direction
			combo.release_pending = combo.gesture_held
	if dual_attack_enabled and event.is_action_released("ranged_attack"):
		_ranged_held = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if combo_enabled and is_instance_valid(combo):
			combo.clear_inputs()
		# A modal may swallow the release while the player is paused.
		_attack_held = false
		_attack_pending = false
		_click_target = null
		_roll_requested = false
		_clear_ranged_input()

func _clear_ranged_input() -> void:
	_ranged_held = false
	_ranged_pending = false

func _target_at_click(world_position: Vector2) -> Node2D:
	var best: Node2D = null
	var best_distance := INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.dead or enemy.is_queued_for_deletion():
			continue
		var distance: float = enemy.global_position.distance_squared_to(world_position)
		# The enemy collision circle is 15 pixels; a small margin makes it clickable.
		if distance <= 19.0 * 19.0 and distance < best_distance:
			best = enemy
			best_distance = distance
	return best

func _unhandled_input(event: InputEvent) -> void:
	if combo_enabled and event.is_action_pressed("attack"):
		if event is InputEventMouseButton:
			_aim_viewport_position = event.position
			_has_aim_event = true
		if _uses_charge():
			if combo.release_pending:
				combo.release_primary()
			combo.press_primary()
		else:
			combo.queue_click()
		get_viewport().set_input_as_handled()
		return
	if combo_enabled and event.is_action_pressed("roll"):
		combo.queue_roll()
		get_viewport().set_input_as_handled()
		return
	# Only presses that survive GUI handling may start a world attack gesture.
	if dual_attack_enabled and event.is_action_pressed("ranged_attack"):
		_ranged_held = true
		_ranged_pending = not is_rolling()
		if event is InputEventMouseButton:
			_aim_viewport_position = event.position
			_has_aim_event = true
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("attack"):
		_attack_held = true
		_attack_pending = not is_rolling() or (not dual_attack_enabled and profession_index == 0)
		_click_target = null
		if event is InputEventMouseButton:
			_aim_viewport_position = event.position
			_has_aim_event = true
			if _attack_pending and weapon.selected != 0:
				var point: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * event.position
				_click_target = _target_at_click(point)
		get_viewport().set_input_as_handled()
	if InputMap.has_action("skill_1") and event.is_action_pressed("skill_1") and not event.is_echo():
		use_manual(0)
		get_viewport().set_input_as_handled()
	if InputMap.has_action("skill_2") and event.is_action_pressed("skill_2") and not event.is_echo():
		use_manual(1)
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("roll"):
		_roll_requested = true
		get_viewport().set_input_as_handled()

func spend_stamina(amount: float) -> bool:
	if stamina < amount:
		dry_attack_flash = 0.15
		return false
	stamina -= amount
	stamina_delay = 0.42
	return true

func take_damage(amount: float, direction: Vector2) -> bool:
	if dead or (gm_invulnerable and preload("res://scripts/test_runtime.gd").enabled()) or invulnerability > 0.0:
		return false
	var actual_damage: float = minf(health, amount * (1.0 - damage_reduction))
	health = maxf(0.0, health - actual_damage)
	invulnerability = 0.7
	knockback = direction * 180.0
	visual.play_hurt()
	hurt.emit()
	damage_received.emit(actual_damage)
	if health <= 0.0:
		dead = true
		if combo_enabled:
			combo.reset_chain()
			weapon.swing_time = 0.0
			visual.cancel_attack()
		_target_marker = null
		_target_marker_remaining = 0.0
		_roll_requested = false
		_finish_roll()
		died.emit()
	queue_redraw()
	return true

func gain_experience(amount: int) -> void:
	if dead:
		return
	experience += amount
	total_experience += amount
	experience_received.emit(amount)
	while experience >= next_level_xp:
		experience -= next_level_xp
		level += 1
		skill_points += 1
		next_level_xp = XP_BASE + (level - 1) * XP_STEP
		level_gained.emit()

func _draw() -> void:
	if manual_flash > 0.0:
		var fade := manual_flash / 0.25
		var origin := to_local(manual_origin)
		if manual_effect == 0:
			draw_arc(origin, 120.0, 0.0, TAU, 48, Color(0.55, 1.0, 0.85, fade * 0.5), 2.0, true)
			for i in range(3):
				var a := manual_direction.angle() + float(i) * TAU / 3.0 + (1.0 - fade) * PI
				draw_arc(origin, 95.0 - i * 15.0, a, a + 1.1, 18, Color(0.55, 1.0, 0.85, fade), 7.0 - i * 2.0, true)
		elif manual_effect == 1:
			draw_line(origin + manual_direction * 16.0, origin + manual_direction * 65.0, Color(0.65, 0.9, 1.0, fade), 5.0, true)
		else:
			draw_line(origin - manual_direction * 20.0, origin + manual_direction * 36.0, Color(1.0, 0.85, 0.35, fade), 5.0, true)
	if momentum_armed > 0.0 or momentum_ready > 0.0:
		draw_arc(Vector2.ZERO, 30.0, 0.0, TAU, 32, Color("ffd96a") if momentum_ready > 0.0 else Color("96e5cf"), 3.0, true)
	if is_instance_valid(_target_marker) and not _target_marker.dead and _target_marker_remaining > 0.0:
		var center: Vector2 = to_local(_target_marker.global_position)
		var color := Color("f9dd7a")
		draw_arc(center, 27.0, PI - 0.62, PI + 0.62, 20, color, 3.5, true)
		draw_arc(center, 27.0, -0.62, 0.62, 20, color, 3.5, true)
	if dry_attack_flash > 0.0:
		draw_arc(Vector2.ZERO, 24.0, 0, TAU, 24, Color("efb362"), 2.5, true)

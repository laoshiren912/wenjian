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
var ranged_weapon: SurvivorWeapon
var _ranged_held: bool = false
var _ranged_pending: bool = false
@onready var weapon: SurvivorWeapon = $Weapon
@onready var camera: Camera2D = $Camera2D
@onready var visual: ActorVisual = $VisualRoot

func _ready() -> void:
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
	visual.play_attack(index, direction, weapon.swing_duration)

func is_bow_recovering() -> bool:
	return weapon.selected == 2 and _bow_shot_remaining > 0.0 and not is_rolling()

func movement_multiplier() -> float:
	return 0.0 if weapon.swing_time > 0.0 or (is_instance_valid(ranged_weapon) and ranged_weapon.swing_time > 0.0) else 1.0

func _on_weapon_selected(_index: int) -> void:
	visual.cancel_attack()

func is_rolling() -> bool:
	return _roll_remaining > 0.0

func try_roll() -> bool:
	if dead or get_tree().paused or is_rolling() or _roll_cooldown > 0.0:
		return false
	if not spend_stamina(roll_stamina_cost):
		return false
	var movement := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_roll_direction = movement.normalized() if not movement.is_zero_approx() else _movement_facing
	_roll_remaining = maxf(0.001, roll_duration)
	_roll_cooldown = roll_cooldown
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

func _physics_process(delta: float) -> void:
	if dead:
		return
	invulnerability = maxf(0.0, invulnerability - delta)
	stamina_delay = maxf(0.0, stamina_delay - delta)
	dry_attack_flash = maxf(0.0, dry_attack_flash - delta)
	_target_marker_remaining = maxf(0.0, _target_marker_remaining - delta)
	if _target_marker_remaining <= 0.0 or not is_instance_valid(_target_marker):
		_target_marker = null
	_bow_shot_remaining = maxf(0.0, _bow_shot_remaining - delta)
	if stamina_delay <= 0.0:
		stamina = minf(max_stamina, stamina + stamina_regen * delta)
	_roll_cooldown = maxf(0.0, _roll_cooldown - delta)
	if _roll_requested:
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
	if not rolling_this_frame and (not is_instance_valid(ranged_weapon) or ranged_weapon.swing_time <= 0.0) and (_attack_pending or (_attack_held and Input.is_action_pressed("attack"))):
		var attack_direction := aim_direction
		if weapon.selected != 0 and _attack_pending and is_instance_valid(_click_target) and not _click_target.dead:
			var target_offset: Vector2 = _click_target.global_position - global_position
			if target_offset.length_squared() > 1.0:
				attack_direction = target_offset.normalized()
		if weapon.attack(attack_direction):
			_target_marker = _click_target if weapon.selected != 0 and _attack_pending and is_instance_valid(_click_target) and not _click_target.dead else null
			_target_marker_remaining = 0.65 if is_instance_valid(_target_marker) else 0.0
	if dual_attack_enabled and not rolling_this_frame and weapon.swing_time <= 0.0 and (_ranged_pending or (_ranged_held and Input.is_action_pressed("ranged_attack"))):
		ranged_weapon.attack(aim_direction)
	_ranged_pending = false
	_attack_pending = false
	_click_target = null
	if rolling_this_frame:
		# Scale the final partial tick so unobstructed rolls cover the configured distance.
		var step: float = minf(delta, _roll_remaining)
		velocity = _roll_direction * (roll_distance / maxf(0.001, roll_duration)) * (step / delta) + knockback
	else:
		velocity = movement * speed * movement_multiplier() + knockback
	knockback = knockback.move_toward(Vector2.ZERO, 650.0 * delta)
	move_and_slide()
	var color := Color("79e2d0")
	if invulnerability > 0.0:
		color = Color("ffffff") if fmod(invulnerability, 0.16) > 0.08 else Color("e88385")
	if not rolling_this_frame and not movement.is_zero_approx():
		_movement_facing = Vector2(signf(movement.x), 0) if absf(movement.x) > absf(movement.y) else Vector2(0, signf(movement.y))
	var body_look: Vector2 = visual.facing
	if weapon.swing_time > 0.0:
		body_look = weapon.swing_direction
	elif is_instance_valid(ranged_weapon) and ranged_weapon.swing_time > 0.0:
		body_look = ranged_weapon.swing_direction
	elif not movement.is_zero_approx():
		body_look = movement
	if rolling_this_frame:
		body_look = _roll_direction
	visual.update_pose(get_real_velocity(), body_look, color, body_look)
	if rolling_this_frame:
		_roll_remaining = maxf(0.0, _roll_remaining - delta)
		if not is_rolling():
			_finish_roll()
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_aim_viewport_position = event.position
		_has_aim_event = true
	# Releases must clear the gesture even when a GUI control consumes them later.
	if event.is_action_released("attack"):
		_attack_held = false
	if dual_attack_enabled and event.is_action_released("ranged_attack"):
		_ranged_held = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		# A modal may swallow the release while the player is paused.
		_attack_held = false
		_attack_pending = false
		_click_target = null
		_roll_requested = false
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
		_attack_pending = not is_rolling()
		_click_target = null
		if event is InputEventMouseButton:
			_aim_viewport_position = event.position
			_has_aim_event = true
			if _attack_pending and weapon.selected != 0:
				var point: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * event.position
				_click_target = _target_at_click(point)
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
	if dead or invulnerability > 0.0:
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
	if is_instance_valid(_target_marker) and not _target_marker.dead and _target_marker_remaining > 0.0:
		var center: Vector2 = to_local(_target_marker.global_position)
		var color := Color("f9dd7a")
		draw_arc(center, 27.0, PI - 0.62, PI + 0.62, 20, color, 3.5, true)
		draw_arc(center, 27.0, -0.62, 0.62, 20, color, 3.5, true)
	if dry_attack_flash > 0.0:
		draw_arc(Vector2.ZERO, 24.0, 0, TAU, 24, Color("efb362"), 2.5, true)

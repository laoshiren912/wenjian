class_name SurvivorPlayer
extends CharacterBody2D

signal died
signal level_gained
signal hurt
signal damage_received(amount: float)
signal experience_received(amount: int)

var max_health: float = 100.0
var health: float = 100.0
var max_stamina: float = 100.0
var stamina: float = 100.0
var stamina_regen: float = 26.0
var stamina_delay: float = 0.0
var speed: float = 225.0
var damage_multiplier: float = 1.0
var attack_speed_multiplier: float = 1.0
var level: int = 1
var experience: int = 0
var next_level_xp: int = 18
var total_experience: int = 0
var invulnerability: float = 0.0
var knockback: Vector2 = Vector2.ZERO
var aim_direction: Vector2 = Vector2.RIGHT
var dead: bool = false
var dry_attack_flash: float = 0.0
var _attack_held: bool = false
@onready var weapon: SurvivorWeapon = $Weapon
@onready var camera: Camera2D = $Camera2D

func _physics_process(delta: float) -> void:
	if dead:
		return
	invulnerability = maxf(0.0, invulnerability - delta)
	stamina_delay = maxf(0.0, stamina_delay - delta)
	dry_attack_flash = maxf(0.0, dry_attack_flash - delta)
	if stamina_delay <= 0.0:
		stamina = minf(max_stamina, stamina + stamina_regen * delta)
	var movement := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = movement * speed + knockback
	knockback = knockback.move_toward(Vector2.ZERO, 650.0 * delta)
	move_and_slide()
	var aim: Vector2 = get_global_mouse_position() - global_position
	if aim.length_squared() > 1.0:
		aim_direction = aim.normalized()
	if _attack_held and Input.is_action_pressed("attack"):
		weapon.attack(aim_direction)
	queue_redraw()

func _input(event: InputEvent) -> void:
	# Releases must clear the gesture even when a GUI control consumes them later.
	if event.is_action_released("attack"):
		_attack_held = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		# A modal may swallow the release while the player is paused.
		_attack_held = false

func _unhandled_input(event: InputEvent) -> void:
	# Only presses that survive GUI handling may start a world attack gesture.
	if event.is_action_pressed("attack"):
		_attack_held = true
		get_viewport().set_input_as_handled()
	for index in range(SurvivorWeapon.DATA.size()):
		if event.is_action_pressed("weapon_%d" % (index + 1)):
			weapon.select_weapon(index)

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
	var actual_damage: float = minf(health, amount)
	health = maxf(0.0, health - amount)
	invulnerability = 0.7
	knockback = direction * 180.0
	hurt.emit()
	damage_received.emit(actual_damage)
	if health <= 0.0:
		dead = true
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
		next_level_xp = 18 + (level - 1) * 10
		level_gained.emit()

func apply_upgrade(index: int) -> void:
	match index:
		0:
			damage_multiplier += 0.2
		1:
			attack_speed_multiplier += 0.15
		2:
			max_health += 25.0
			health = minf(max_health, health + 40.0)

func _draw() -> void:
	draw_circle(Vector2(0, 5), 17.0, Color(0.0, 0.0, 0.0, 0.25))
	var color := Color("79e2d0")
	if invulnerability > 0.0:
		color = Color("ffffff") if fmod(invulnerability, 0.16) > 0.08 else Color("e88385")
	draw_circle(Vector2.ZERO, 14.0, color)
	draw_arc(Vector2.ZERO, 18.0, 0, TAU, 32, Color("2a706e"), 2.0, true)
	var tip: Vector2 = aim_direction * 21.0
	var side: Vector2 = aim_direction.orthogonal() * 5.0
	draw_colored_polygon(PackedVector2Array([tip, aim_direction * 12.0 + side, aim_direction * 12.0 - side]), Color("f2faf2"))
	if dry_attack_flash > 0.0:
		draw_arc(Vector2.ZERO, 24.0, 0, TAU, 24, Color("efb362"), 2.5, true)

class_name ActorVisual
extends Node2D

# Presentation only. Never move an actor, change a collider, or resolve an attack here.
@export_enum("Player", "Hostile", "Passive") var appearance: int = 0
var facing: Vector2 = Vector2.DOWN
var motion: Vector2 = Vector2.ZERO
var tint := Color("79e2d0")
var walk_phase: float = 0.0
var hurt_time: float = 0.0
var attack_time: float = 0.0
var attack_duration: float = 0.18
var attack_weapon: int = 0
var attack_direction: Vector2 = Vector2.RIGHT
var dying: bool = false
var death_age: float = 0.0
const DEATH_DURATION: float = 0.22

func update_pose(actual_motion: Vector2, look: Vector2, color: Color) -> void:
	if dying:
		return
	motion = actual_motion
	tint = color
	if look.length_squared() > 0.01:
		facing = Vector2(signf(look.x), 0) if absf(look.x) > absf(look.y) else Vector2(0, signf(look.y))
	if motion.length_squared() < 1.0:
		walk_phase = 0.0
	queue_redraw()

func play_attack(index: int, direction: Vector2, duration: float) -> void:
	attack_weapon = index
	attack_direction = direction.normalized()
	attack_duration = maxf(0.001, duration)
	attack_time = attack_duration
	queue_redraw()

func cancel_attack() -> void:
	attack_time = 0.0
	queue_redraw()

func play_hurt() -> void:
	hurt_time = 0.14
	queue_redraw()

func detach_and_die(world_parent: Node) -> void:
	# The enemy is still freed immediately; only this non-physical child survives briefly.
	reparent(world_parent, true)
	add_to_group("death_visuals")
	dying = true
	motion = Vector2.ZERO
	walk_phase = 0.0
	hurt_time = 0.0
	attack_time = 0.0
	queue_redraw()

func _physics_process(delta: float) -> void:
	if dying:
		death_age += delta
		var progress: float = clampf(death_age / DEATH_DURATION, 0.0, 1.0)
		modulate.a = 1.0 - progress
		scale = Vector2.ONE * lerpf(1.0, 0.72, progress)
		rotation = progress * 0.25
		if death_age >= DEATH_DURATION:
			queue_free()
	else:
		if motion.length_squared() >= 1.0:
			var stride: float = 72.0 if appearance == 0 else 44.0
			walk_phase = fmod(walk_phase + motion.length() * delta / stride * TAU, TAU)
		hurt_time = maxf(0.0, hurt_time - delta)
		attack_time = maxf(0.0, attack_time - delta)
	queue_redraw()

func _draw() -> void:
	var moving: bool = motion.length_squared() >= 1.0 and not dying
	var step: float = sin(walk_phase) * 4.0 if moving else 0.0
	var bob: float = absf(sin(walk_phase)) * 1.5 if moving else 0.0
	var recoil: float = attack_time / attack_duration if attack_time > 0.0 else 0.0
	var lean := attack_direction * recoil * (1.5 if attack_weapon == 2 else 2.5)
	var offset := Vector2(0, -bob) + lean
	var color: Color = Color.WHITE if hurt_time > 0.0 else tint
	var outline := Color("203c43")
	var boots := Color("294c56") if appearance == 0 else Color("56423b")
	# Ground shadow stays fixed while limbs and torso animate above it.
	draw_set_transform(Vector2(0, 10), 0.0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, 16.0, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO)
	var side_view: bool = facing.x != 0.0
	var left_foot := Vector2(-5, 15 + step * facing.y)
	var right_foot := Vector2(5, 15 - step * facing.y)
	if side_view:
		left_foot = Vector2(-2 + facing.x * step, 15)
		right_foot = Vector2(2 - facing.x * step, 15)
	draw_line(Vector2(-4, 5) + offset, left_foot, boots, 5.0, true)
	draw_line(Vector2(4, 5) + offset, right_foot, boots, 5.0, true)
	draw_circle(left_foot, 3.0, boots)
	draw_circle(right_foot, 3.0, boots)
	var left_hand := Vector2(-12, 5 - step * 0.5) + offset
	var right_hand := Vector2(12, 5 + step * 0.5) + offset
	if attack_time > 0.0:
		right_hand = attack_direction * (18.0 + recoil * 5.0) + Vector2(0, 2)
	draw_line(Vector2(-7, -1) + offset, left_hand, outline, 5.0, true)
	draw_line(Vector2(7, -1) + offset, right_hand, outline, 5.0, true)
	draw_circle(left_hand, 2.5, color.lightened(0.2))
	draw_circle(right_hand, 2.5, color.lightened(0.2))
	if appearance == 1:
		draw_colored_polygon(PackedVector2Array([Vector2(0, -7) + offset, Vector2(10, 1) + offset, Vector2(0, 10) + offset, Vector2(-10, 1) + offset]), outline)
		draw_colored_polygon(PackedVector2Array([Vector2(0, -5) + offset, Vector2(8, 1) + offset, Vector2(0, 8) + offset, Vector2(-8, 1) + offset]), color)
	else:
		# A narrower profile and back seam distinguish turning from walking backwards.
		draw_set_transform(offset, 0.0, Vector2(0.72 if side_view else 1.0, 1.0))
		draw_circle(Vector2(0, 1), 10.0, outline)
		draw_circle(Vector2(0, 1), 8.5, color)
		if facing == Vector2.UP:
			draw_line(Vector2(0, -5), Vector2(0, 7), boots, 2.0, true)
		else:
			draw_line(Vector2(-6, 6), Vector2(6, 6), boots, 2.0, true)
		draw_set_transform(Vector2.ZERO)
	var head := Vector2(0, -11) + offset
	draw_circle(head, 7.5, outline)
	draw_circle(head, 6.0, color.lightened(0.18))
	if facing == Vector2.UP:
		draw_line(head + Vector2(-4, -1), head + Vector2(4, -1), boots, 3.0, true)
	elif facing == Vector2.DOWN:
		draw_circle(head + Vector2(-2.5, 1), 1.0, outline)
		draw_circle(head + Vector2(2.5, 1), 1.0, outline)
	else:
		draw_circle(head + Vector2(facing.x * 3, 0), 1.2, outline)
		draw_line(head + Vector2(facing.x * 4, 2), head + Vector2(facing.x * 7, 2), color.lightened(0.3), 2.0, true)

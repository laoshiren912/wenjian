class_name ActorVisual
extends Node2D

# Presentation only. Never move an actor, change a collider, or resolve an attack here.
@export_enum("Player", "Hostile", "Passive") var appearance: int = 0
var facing: Vector2 = Vector2.DOWN
var leg_facing: Vector2 = Vector2.DOWN
var motion: Vector2 = Vector2.ZERO
var tint := Color("79e2d0")
var walk_phase: float = 0.0
var hurt_time: float = 0.0
var attack_time: float = 0.0
var attack_duration: float = 0.18
var attack_weapon: int = 0
var attack_direction: Vector2 = Vector2.RIGHT
var combo_stage := -1
var combo_data: Dictionary = {}
var dying: bool = false
var death_age: float = 0.0
var roll_time: float = 0.0
var roll_duration: float = 0.24
var roll_direction: Vector2 = Vector2.DOWN
const DEATH_DURATION: float = 0.22

func update_pose(actual_motion: Vector2, look: Vector2, color: Color, leg_look: Vector2 = Vector2.ZERO) -> void:
	if dying:
		return
	motion = actual_motion
	tint = color
	if look.length_squared() > 0.01:
		facing = Vector2(signf(look.x), 0) if absf(look.x) > absf(look.y) else Vector2(0, signf(look.y))
	var legs := leg_look if leg_look.length_squared() > 0.01 else look
	if legs.length_squared() > 0.01:
		leg_facing = Vector2(signf(legs.x), 0) if absf(legs.x) > absf(legs.y) else Vector2(0, signf(legs.y))
	if motion.length_squared() < 1.0:
		walk_phase = 0.0
	queue_redraw()

func play_attack(index: int, direction: Vector2, duration: float) -> void:
	combo_stage = -1
	attack_weapon = index
	attack_direction = direction.normalized()
	attack_duration = maxf(0.001, duration)
	attack_time = attack_duration
	queue_redraw()

func cancel_attack() -> void:
	attack_time = 0.0
	combo_stage = -1
	queue_redraw()

func set_combo_pose(stage: int, data: Dictionary) -> void:
	combo_stage = stage
	combo_data = data

func play_roll(direction: Vector2, duration: float) -> void:
	cancel_attack()
	roll_direction = direction
	roll_duration = maxf(0.001, duration)
	roll_time = roll_duration
	queue_redraw()

func stop_roll() -> void:
	roll_time = 0.0
	rotation = 0.0
	scale = Vector2.ONE
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
		if roll_time > 0.0:
			roll_time = maxf(0.0, roll_time - delta)
			var spin: float = signf(roll_direction.x) if roll_direction.x != 0.0 else signf(roll_direction.y)
			rotation = (1.0 - roll_time / roll_duration) * TAU * spin
			scale = Vector2(1.0, 0.75)
		else:
			rotation = 0.0
			scale = Vector2.ONE
		if motion.length_squared() >= 1.0:
			var stride: float = 72.0 if appearance == 0 else 44.0
			walk_phase = fmod(walk_phase + motion.length() * delta / stride * TAU, TAU)
		hurt_time = maxf(0.0, hurt_time - delta)
		attack_time = maxf(0.0, attack_time - delta)
	queue_redraw()

func _draw() -> void:
	var moving: bool = motion.length_squared() >= 1.0 and not dying and roll_time <= 0.0
	if roll_time > 0.0:
		draw_arc(Vector2.ZERO, 24.0, -1.8, 1.8, 24, Color(0.55, 0.92, 0.86, 0.5), 2.0, true)
	var step: float = sin(walk_phase) * 4.0 if moving else 0.0
	var bob: float = absf(sin(walk_phase)) * 1.5 if moving else 0.0
	var recoil: float = attack_time / attack_duration if attack_time > 0.0 else 0.0
	var lean := attack_direction * recoil * (1.5 if attack_weapon == 2 else 2.5)
	if combo_stage >= 0 and attack_time > 0.0:
		var progress := 1.0 - recoil
		lean = attack_direction * sin(progress * PI) * (7.0 if combo_stage == 2 else 3.0)
		lean += attack_direction.orthogonal() * sin(progress * TAU) * (2.0 if combo_stage == 0 else -2.0)
	var offset := Vector2(0, -bob) + lean
	var color: Color = Color.WHITE if hurt_time > 0.0 else tint
	var outline := Color("203c43")
	var boots := Color("294c56") if appearance == 0 else Color("56423b")
	# Ground shadow stays fixed while limbs and torso animate above it.
	draw_set_transform(Vector2(0, 10), 0.0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, 16.0, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO)
	var side_view: bool = facing.x != 0.0
	var left_foot := Vector2(-5, 15 + step * leg_facing.y)
	var right_foot := Vector2(5, 15 - step * leg_facing.y)
	if leg_facing.x != 0.0:
		left_foot = Vector2(-2 + leg_facing.x * step, 15)
		right_foot = Vector2(2 - leg_facing.x * step, 15)
	draw_line(Vector2(-4, 5) + offset, left_foot, boots, 5.0, true)
	draw_line(Vector2(4, 5) + offset, right_foot, boots, 5.0, true)
	draw_circle(left_foot, 3.0, boots)
	draw_circle(right_foot, 3.0, boots)
	var left_hand := Vector2(-12, 5 - step * 0.5) + offset
	var right_hand := Vector2(12, 5 + step * 0.5) + offset
	if attack_time > 0.0:
		right_hand = attack_direction * (18.0 + recoil * 5.0) + Vector2(0, 2)
		if combo_stage >= 0:
			var progress := clampf(((1.0 - recoil) * (float(combo_data.windup) + float(combo_data.active) + float(combo_data.recovery)) - float(combo_data.windup)) / float(combo_data.active), 0.0, 1.0)
			var half := deg_to_rad(float(combo_data.angle) * 0.5)
			var angle := lerpf(-half, half, progress) if combo_stage != 1 else lerpf(half, -half, progress)
			right_hand = attack_direction.rotated(angle) * 22.0 + Vector2(0, -8.0 if combo_stage == 2 else 2.0)
			if combo_stage == 2:
				right_hand = attack_direction * 18.0 + Vector2(0, lerpf(-28.0, 5.0, progress))
				left_hand = right_hand - attack_direction * 6.0
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

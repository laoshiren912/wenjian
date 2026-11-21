extends ActorVisual

const CONFIG = preload("res://scripts/v41_config.gd")

const S_IDLE = preload("res://assets/characters/Swordsman/Swordsman_Idle_Sheet_780x1440.png")
const S_WALK = preload("res://assets/characters/Swordsman/Swordsman_Walk_Sheet_1404x1440.png")
const S_ATTACK = preload("res://assets/characters/Swordsman/Swordsman_Attack_Sheet_1404x1440.png")
const S_STRIKE_POSE = preload("res://assets/characters/Swordsman/v41-strike-pose.png")
const S_DEATH = preload("res://assets/characters/Swordsman/Swordsman_Death_Sheet_1404x540.png")
const B_IDLE = preload("res://assets/characters/Bandit/Bandit_Idle_Sheet_780x1312.png")
const B_WALK = preload("res://assets/characters/Bandit/Bandit_Walk_Sheet_1404x1312.png")
const B_ATTACK = preload("res://assets/characters/Bandit/Bandit_Attack_Sheet_1404x656.png")
const B_DEATH = preload("res://assets/characters/Bandit/Bandit_Death_Sheet_1404x328.png")
const H_WALK = preload("res://assets/characters/Herbalist/Herbalist_Walk_Sheet_972x928.png")
const H_DEATH = preload("res://assets/characters/Herbalist/Herbalist_Death_Sheet_972x348.png")
const ART_SCALE := 0.55
const S_CELL := Vector2(156, 180)
const S_ORIGIN := -Vector2(79, 135) * ART_SCALE + Vector2(0, 15)
const DOWNCUT_HAND := [Vector2(103, 117), Vector2(92, 124), Vector2(85, 118), Vector2(68, 119),
	Vector2(70, 119), Vector2(89, 119), Vector2(73, 120), Vector2(63, 123)]
const DOWNCUT_TIP := [Vector2(135, 144), Vector2(125, 156), Vector2(132, 137), Vector2(79, 157),
	Vector2(108, 146), Vector2(78, 157), Vector2(25, 137), Vector2(32, 156)]
const RAISED_HAND := [Vector2(100, 112), Vector2(74, 51), Vector2(101, 84), Vector2(68, 65),
	Vector2(109, 78), Vector2(77, 65), Vector2(58, 84), Vector2(64, 51)]
const DASH_TINTS := [Color("f3f8ff"), Color("86eafa"), Color("c4b8ff")]
static var empty_hand_sheet: ImageTexture

var look_direction := Vector2.DOWN
var animation_clock := 0.0
var player_death := false
var player_death_age := 0.0
var herbalist_visual := false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	herbalist_visual = get_parent() is SurvivorEnemy and get_parent().kind == SurvivorEnemy.Kind.RANGED
	if get_parent() is SurvivorPlayer:
		process_mode = Node.PROCESS_MODE_ALWAYS
		get_parent().died.connect(_player_died)
		if empty_hand_sheet == null:
			_prepare_empty_hand_pose()

func _player_died() -> void:
	player_death = true
	player_death_age = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	if player_death:
		player_death_age += delta
		queue_redraw()

func update_pose(actual_motion: Vector2, look: Vector2, color: Color, leg_look: Vector2 = Vector2.ZERO) -> void:
	if look.length_squared() > 0.01:
		look_direction = look.normalized()
	super.update_pose(actual_motion, look, color, leg_look)

func _physics_process(delta: float) -> void:
	if not get_tree().paused:
		animation_clock += delta
		super._physics_process(delta)

func _direction_index(direction: Vector2) -> int:
	return posmod(roundi((direction.angle() + PI / 2.0) / (PI / 4.0)), 8)

func _prepare_empty_hand_pose() -> void:
	# Reuse the existing split attack body. Mask the small gold guard at the
	# wrist only in the temporary throw pose; the source atlases stay untouched.
	var body := S_STRIKE_POSE.get_image().get_region(Rect2i(0, 0, 156, 1440))
	for row in range(8):
		var grip := Vector2i(DOWNCUT_HAND[row]) + Vector2i(0, 180 * row)
		for y in range(grip.y - 11, grip.y + 8):
			for x in range(grip.x - 10, grip.x + 11):
				var pixel := body.get_pixel(x, y)
				if pixel.r > 0.75 and pixel.g > 0.47 and pixel.b < 0.30:
					body.set_pixel(x, y, Color("9a663e"))
	empty_hand_sheet = ImageTexture.create_from_image(body)

func _throw_pose_offset() -> Vector2:
	return Vector2(0.0, -1.2 * absf(sin(animation_clock * 27.0))) if motion.length_squared() > 4.0 else Vector2.ZERO

func throw_hand(direction: Vector2) -> Vector2:
	return S_ORIGIN + DOWNCUT_HAND[_direction_index(direction)] * ART_SCALE + _throw_pose_offset()

func throw_blade_angle(direction: Vector2) -> float:
	var row := _direction_index(direction)
	return (DOWNCUT_TIP[row] - DOWNCUT_HAND[row]).angle()

func _draw_throw_pose(direction: Vector2) -> void:
	var row := _direction_index(direction)
	var tint := Color(2.0, 2.0, 2.0) if hurt_time > 0.0 else Color.WHITE
	draw_texture_rect_region(empty_hand_sheet, Rect2(S_ORIGIN + _throw_pose_offset(), S_CELL * ART_SCALE),
		Rect2(Vector2(0, row * S_CELL.y), S_CELL), tint)

func _strike_row(direction: Vector2, chain_stage: int) -> int:
	var index := _direction_index(direction)
	return posmod(-index, 8) if chain_stage == 1 else index

func _strike_offset(direction: Vector2, chain_stage: int, progress: float) -> Vector2:
	if chain_stage == 2:
		return _heavy_lean(direction, progress)
	return direction * sin(progress * PI) * 3.0

func sword_hand(direction: Vector2, chain_stage: int, progress: float) -> Vector2:
	var row := _strike_row(direction, chain_stage)
	var hand: Vector2 = DOWNCUT_HAND[row]
	if chain_stage == 2 and progress < CONFIG.THIRD_IMPACT_PROGRESS:
		hand = (RAISED_HAND[row] as Vector2).lerp(hand, smoothstep(0.0, CONFIG.THIRD_IMPACT_PROGRESS, progress))
	var offset := S_ORIGIN + hand * ART_SCALE
	if chain_stage == 1:
		offset.x = -offset.x
	return offset + _strike_offset(direction, chain_stage, progress)

func sword_tip(direction: Vector2, chain_stage: int, progress: float, projected_edge: Vector2) -> Vector2:
	var row := _strike_row(direction, chain_stage)
	var hand := sword_hand(direction, chain_stage, progress)
	var blade_length: float = DOWNCUT_HAND[row].distance_to(DOWNCUT_TIP[row]) * ART_SCALE
	return hand + hand.direction_to(projected_edge) * blade_length

func _heavy_lean(direction: Vector2, progress: float) -> Vector2:
	return direction * lerpf(-4.0, 5.0, smoothstep(0.17, 0.34, progress))

func dash_ghost_pose(direction: Vector2) -> Dictionary:
	return {"sheet": S_ATTACK, "destination": Rect2(S_ORIGIN + direction * 3.0, S_CELL * ART_SCALE),
		"source": Rect2(Vector2(5 * S_CELL.x, _direction_index(direction) * S_CELL.y), S_CELL)}

func _draw_dash(player) -> void:
	var direction: Vector2 = player.dash_direction
	var index := _direction_index(direction)
	var rank: int = player.dash_rank
	var pose := dash_ghost_pose(direction)
	var color: Color = DASH_TINTS[rank]
	var frame := 5
	var destination: Rect2 = pose.destination
	var tint := Color.WHITE
	match int(player.dash_state):
		1:
			frame = 1
			destination.position -= direction * 5.0
			draw_line(-direction * 20.0, direction * 33.0, Color(color, 0.48), 2.0, true)
		2:
			tint = Color(color.lightened(0.38), 0.38 if rank == 2 else 0.93)
			if rank == 2:
				var front := direction * 34.0
				var side := direction.orthogonal() * 12.0
				var back := -direction * 52.0
				draw_colored_polygon(PackedVector2Array([back, -direction * 6.0 + side, front, -direction * 6.0 - side]), Color(color, 0.69))
				draw_line(back, front, Color("f8f4ff"), 4.0, true)
		3:
			frame = 6 if player.dash_time > 0.065 else 8
			destination.position += direction * 3.0
	var source := Rect2(Vector2(frame * S_CELL.x, index * S_CELL.y), S_CELL)
	draw_texture_rect_region(S_ATTACK, destination, source, tint)

func _draw_player_attack(player) -> void:
	var sword = player.combo
	var direction: Vector2 = sword.swing_direction
	var stage: int = sword.stage
	var row := _strike_row(direction, stage)
	var frame := 0
	var progress: float = sword.active_progress(sword.swing_time)
	var elapsed: float = (sword.swing_duration - sword.swing_time) * player.attack_speed_multiplier
	var wound: bool = sword.phase() == "windup"
	var recover: bool = sword.phase() == "recovery"
	var color := Color(2.0, 2.0, 2.0) if hurt_time > 0.0 else Color.WHITE
	var lift := stage == 2 and progress < CONFIG.THIRD_IMPACT_PROGRESS
	var settling: bool = recover and sword.swing_time < (0.055 if stage == 2 else 0.078)
	if not wound and not lift and not settling:
		var edge: Vector2 = sword.blade_segment(progress)[1]
		_draw_strike_pose(direction, stage, progress, edge, color)
		return
	var offset := S_ORIGIN
	if stage == 2:
		if wound or lift:
			frame = 3 if wound and elapsed < 0.036 else 4
			offset += _heavy_lean(direction, 0.0) - Vector2(0, 2)
		else:
			frame = 8
	else:
		if stage == 1:
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1, 1))
		frame = (1 if stage == 0 else 2) if wound else 8
	draw_texture_rect_region(S_ATTACK, Rect2(offset, S_CELL * ART_SCALE),
		Rect2(Vector2(frame * S_CELL.x, row * S_CELL.y), S_CELL), color)
	draw_set_transform(Vector2.ZERO)

func _draw_strike_pose(direction: Vector2, stage: int, progress: float, edge: Vector2, color: Color) -> void:
	var row := _strike_row(direction, stage)
	var mirror := Vector2(-1, 1) if stage == 1 else Vector2.ONE
	var hand := sword_hand(direction, stage, progress)
	var hand_cell: Vector2 = DOWNCUT_HAND[row]
	var source_blade: Vector2 = (DOWNCUT_TIP[row] - hand_cell) * mirror
	var blade_direction := hand.direction_to(edge)
	var angle := source_blade.angle_to(blade_direction)
	var offset := _strike_offset(direction, stage, progress)
	var behind := direction.y < -0.55 and blade_direction.y < -0.4
	if behind:
		_draw_strike_blade(row, hand_cell, hand, angle, mirror, color)
	draw_set_transform(offset, 0.0, mirror)
	draw_texture_rect_region(S_STRIKE_POSE, Rect2(S_ORIGIN, S_CELL * ART_SCALE),
		Rect2(Vector2(0, row * S_CELL.y), S_CELL), color)
	if not behind:
		_draw_strike_blade(row, hand_cell, hand, angle, mirror, color)
	draw_set_transform(Vector2.ZERO)

func _draw_strike_blade(row: int, hand_cell: Vector2, hand: Vector2, angle: float, mirror: Vector2, color: Color) -> void:
	draw_set_transform(hand, angle, mirror)
	draw_texture_rect_region(S_STRIKE_POSE, Rect2(-hand_cell * ART_SCALE, S_CELL * ART_SCALE),
		Rect2(Vector2(S_CELL.x, row * S_CELL.y), S_CELL), color)

func _draw() -> void:
	if herbalist_visual:
		_draw_herbalist()
		return
	var is_player := get_parent() is SurvivorPlayer or player_death
	var player = get_parent() if is_player and not player_death else null
	if player != null and is_instance_valid(player.thrown_sword):
		_draw_throw_pose(player.thrown_sword.aim)
		return
	if player != null and player.dash_state != 0:
		_draw_dash(player)
		return
	if player != null and is_instance_valid(player.combo) and player.combo.swing_time > 0.0:
		_draw_player_attack(player)
		return
	var direction := look_direction
	var index := _direction_index(direction)
	var size := Vector2(156, 180 if is_player else 164)
	var pivot := Vector2(79, 135) if is_player else Vector2(78, 126)
	var sheet: Texture2D = S_IDLE if is_player else B_IDLE
	var frame := int(animation_clock * 6.0) % 5
	var row := index
	var flip := false
	var enemy = get_parent() if not is_player and not dying else null
	var enemy_attacking: bool = enemy != null and (enemy.windup > 0.0 or enemy.lunge_time > 0.0)
	if dying or player_death:
		sheet = S_DEATH if is_player else B_DEATH
		var age: float = player_death_age if player_death else death_age
		frame = mini(8, int(age / (0.9 if player_death else DEATH_DURATION) * 9.0))
		if is_player:
			row = 0 if index in [0, 1, 2, 7] else (2 if index in [5, 6] else 1)
		else:
			row = 1 if index in [5, 6, 7] else 0
	elif enemy_attacking:
		sheet = B_ATTACK
		var progress: float = 1.0 - enemy.windup / maxf(enemy.attack_duration, 0.001) if enemy.windup > 0.0 else 0.8
		frame = clampi(int(progress * 9.0), 0, 8)
		var rows := [0, 0, 1, 1, 2, 3, 3, 0]
		row = rows[index]
		flip = index in [6, 7]
	elif motion.length_squared() >= 1.0 and roll_time <= 0.0:
		sheet = S_WALK if is_player else B_WALK
		frame = int(animation_clock * 8.0) % 9
	var destination := Rect2(-pivot * ART_SCALE + Vector2(0, 15), size * ART_SCALE)
	var source := Rect2(Vector2(frame * size.x, row * size.y), size)
	var color := Color(2.0, 2.0, 2.0, 1.0) if hurt_time > 0.0 else Color.WHITE
	if flip:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1, 1))
	draw_texture_rect_region(sheet, destination, source, color)
	if flip:
		draw_set_transform(Vector2.ZERO)

func _draw_herbalist() -> void:
	var index := _direction_index(look_direction)
	var sheet: Texture2D = H_WALK
	var row := index
	var frame := int(animation_clock * 8.0) % 9 if motion.length_squared() >= 1.0 else 0
	var flip := false
	if dying:
		sheet = H_DEATH
		frame = mini(8, int(death_age / DEATH_DURATION * 9.0))
		row = 0 if index in [0, 1, 7] else (1 if index == 4 else 2)
		flip = index in [2, 3]
	elif get_parent() is SurvivorEnemy and get_parent().windup > 0.0:
		frame = 0
	var destination := Rect2(-Vector2(54, 103) * ART_SCALE + Vector2(0, 15), Vector2(108, 116) * ART_SCALE)
	var source := Rect2(Vector2(frame * 108, row * 116), Vector2(108, 116))
	var color := Color(2.0, 2.0, 2.0, 1.0) if hurt_time > 0.0 else Color.WHITE
	if flip:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1, 1))
	draw_texture_rect_region(sheet, destination, source, color)
	if flip:
		draw_set_transform(Vector2.ZERO)

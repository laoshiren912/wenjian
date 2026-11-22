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
const HIT_FLASH_SHADER = preload("res://assets/shaders/v41_hit_flash.gdshader")
const PLAYER_HIT_FLASH_SHADER = preload("res://assets/shaders/v41_player_hit_flash.gdshader")
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
const FACE_PALETTE := {
	Color("eb983c"): Color("fcd491"),
	Color("c87728"): Color("fdba5d"),
	Color("a6581c"): Color("d4965a"),
	Color("ddb920"): Color("fed075"),
	Color("de9616"): Color("fdba5d"),
}
static var player_attack_sheet: ImageTexture
static var player_strike_sheet: ImageTexture
static var empty_hand_sheet: ImageTexture

var look_direction := Vector2.DOWN
var animation_clock := 0.0
var player_death := false
var player_death_age := 0.0
var herbalist_visual := false
var spawn_pop_time := 0.0
var hit_flash_mat: ShaderMaterial
var player_hit_flash_mat: ShaderMaterial

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	herbalist_visual = get_parent() is SurvivorEnemy and get_parent().kind == SurvivorEnemy.Kind.RANGED
	if get_parent() is SurvivorEnemy:
		hit_flash_mat = ShaderMaterial.new()
		hit_flash_mat.shader = HIT_FLASH_SHADER
		material = hit_flash_mat
	if get_parent() is SurvivorPlayer:
		player_hit_flash_mat = ShaderMaterial.new()
		player_hit_flash_mat.shader = PLAYER_HIT_FLASH_SHADER
		player_hit_flash_mat.set_shader_parameter("hurt_flash", 0.0)
		material = player_hit_flash_mat
		process_mode = Node.PROCESS_MODE_ALWAYS
		get_parent().died.connect(_player_died)
		if empty_hand_sheet == null:
			_prepare_player_poses()

func play_hurt() -> void:
	if hit_flash_mat != null:
		start_limited_hurt_flash(CONFIG.ENEMY_FLASH_INTERVAL, CONFIG.ENEMY_FLASH_DURATION)
		return
	hurt_time = 0.07
	if player_hit_flash_mat != null:
		player_hit_flash_mat.set_shader_parameter("hurt_flash", 1.0)
	queue_redraw()

func play_spawn_pop() -> void:
	spawn_pop_time = 0.24
	modulate.a = 0.0
	scale = Vector2(0.76, 1.24)
	queue_redraw()

func _player_died() -> void:
	player_death = true
	player_death_age = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	if spawn_pop_time > 0.0:
		spawn_pop_time = maxf(0.0, spawn_pop_time - delta)
		var t := 1.0 - spawn_pop_time / 0.24
		modulate.a = clampf(t * 1.35, 0.0, 1.0)
		var s := lerpf(0.76, 1.0, smoothstep(0.0, 1.0, t))
		scale = Vector2(s, lerpf(1.24, 1.0, smoothstep(0.0, 1.0, t)))
		if spawn_pop_time <= 0.0:
			modulate.a = 1.0
			scale = Vector2.ONE
		queue_redraw()
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
	var was_hurt := hurt_time > 0.0
	super._physics_process(delta)
	if hit_flash_mat != null and was_hurt and hurt_time == 0.0 and not dying:
		modulate = Color.WHITE
		self_modulate = Color.WHITE
	if player_hit_flash_mat != null and was_hurt and hurt_time == 0.0:
		player_hit_flash_mat.set_shader_parameter("hurt_flash", 0.0)
		modulate = Color.WHITE
		self_modulate = Color.WHITE

func _direction_index(direction: Vector2) -> int:
	return posmod(roundi((direction.angle() + PI / 2.0) / (PI / 4.0)), 8)

func _prepare_player_poses() -> void:
	# The diagonal downcut cels have an orange face baked into the source art.
	# Match only their face swatches to the idle atlas. Keep weapons, clothes
	# and the original atlas used by the boss intact.
	var attack := S_ATTACK.get_image()
	var strike := S_STRIKE_POSE.get_image()
	for row in [3, 5]:
		var face := Rect2i(49 if row == 3 else 81, row * 180 + 70, 28, 20)
		_restore_face_palette(strike, face)
		for frame in [5, 6]:
			_restore_face_palette(attack, Rect2i(face.position + Vector2i(frame * 156, 0), face.size))
	player_attack_sheet = ImageTexture.create_from_image(attack)
	player_strike_sheet = ImageTexture.create_from_image(strike)

	# Reuse the existing split attack body. Mask the small gold guard at the
	# wrist only in the temporary throw pose; the source atlases stay untouched.
	var body := strike.get_region(Rect2i(0, 0, 156, 1440))
	for row in range(8):
		var grip := Vector2i(DOWNCUT_HAND[row]) + Vector2i(0, 180 * row)
		for y in range(grip.y - 11, grip.y + 8):
			for x in range(grip.x - 10, grip.x + 11):
				var pixel := body.get_pixel(x, y)
				if pixel.r > 0.75 and pixel.g > 0.47 and pixel.b < 0.30:
					body.set_pixel(x, y, Color("9a663e"))
	empty_hand_sheet = ImageTexture.create_from_image(body)

func _restore_face_palette(sheet: Image, rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var pixel := sheet.get_pixel(x, y)
			if FACE_PALETTE.has(pixel):
				sheet.set_pixel(x, y, FACE_PALETTE[pixel])

func _throw_pose_offset() -> Vector2:
	return Vector2(0.0, -1.2 * absf(sin(animation_clock * 27.0))) if motion.length_squared() > 4.0 else Vector2.ZERO

func throw_hand(direction: Vector2) -> Vector2:
	return S_ORIGIN + DOWNCUT_HAND[_direction_index(direction)] * ART_SCALE + _throw_pose_offset()

func throw_blade_angle(direction: Vector2) -> float:
	var row := _direction_index(direction)
	return (DOWNCUT_TIP[row] - DOWNCUT_HAND[row]).angle()

func _draw_throw_pose(direction: Vector2) -> void:
	var row := _direction_index(direction)
	draw_texture_rect_region(empty_hand_sheet, Rect2(S_ORIGIN + _throw_pose_offset(), S_CELL * ART_SCALE),
		Rect2(Vector2(0, row * S_CELL.y), S_CELL))

func _strike_row(direction: Vector2, chain_stage: int) -> int:
	var index := _direction_index(direction)
	return posmod(-index, 8) if chain_stage == 1 else index

func _strike_offset(direction: Vector2, chain_stage: int, progress: float) -> Vector2:
	if chain_stage == 2:
		return _heavy_lean(direction, progress)
	if chain_stage == 1:
		return direction * sin(progress * PI) * 3.8 + Vector2(0.0, -2.5 * sin(progress * PI))
	return direction * sin(progress * PI) * 4.5

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
	var thrust := lerpf(-5.5, 7.5, smoothstep(0.18, 0.36, progress))
	var crouch := lerpf(2.2, 3.2, smoothstep(0.20, 0.42, progress))
	return direction * thrust + Vector2(0.0, crouch)

func dash_ghost_pose(direction: Vector2) -> Dictionary:
	return {"sheet": player_attack_sheet, "destination": Rect2(S_ORIGIN + direction * 3.0, S_CELL * ART_SCALE),
		"source": Rect2(Vector2(5 * S_CELL.x, _direction_index(direction) * S_CELL.y), S_CELL)}

func _draw_dash(player) -> void:
	var direction: Vector2 = player.dash_direction
	var index := _direction_index(direction)
	var rank: int = player.dash_rank
	var pose := dash_ghost_pose(direction)
	var color: Color = DASH_TINTS[rank]
	var frame := 5
	var destination: Rect2 = pose.destination
	match int(player.dash_state):
		1:
			frame = 1
			destination.position -= direction * 5.0
			draw_line(-direction * 20.0, direction * 33.0, Color(color, 0.48), 2.0, true)
		2:
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
	draw_texture_rect_region(player_attack_sheet, destination, source)

func _draw_player_attack(player) -> void:
	var sword = player.combo
	var direction: Vector2 = sword.swing_direction
	var stage: int = sword.stage
	var row := _strike_row(direction, stage)
	var frame := 0
	var progress: float = sword.active_progress(sword.swing_time)
	var data: Dictionary = sword.current_data()
	var elapsed: float = (sword.swing_duration - sword.swing_time) * player.attack_speed_multiplier
	var wound: bool = sword.phase() == "windup"
	var recover: bool = sword.phase() == "recovery"
	var lift := stage == 2 and progress < CONFIG.THIRD_IMPACT_PROGRESS
	var rec_ratio := clampf((elapsed - float(data.windup) - float(data.active)) / maxf(0.001, float(data.recovery)), 0.0, 1.0) if recover else 0.0
	var settling: bool = recover and (rec_ratio >= 0.42 if stage == 2 else rec_ratio >= 0.34)
	if not wound and not lift and not settling:
		var edge: Vector2 = sword.blade_segment(progress)[1]
		_draw_strike_pose(direction, stage, progress, edge, rec_ratio)
		return
	var body_offset := Vector2.ZERO
	var body_scale := Vector2.ONE
	var body_tilt := 0.0
	var mirror_x := 1.0
	if stage == 2:
		if wound or lift:
			var windup_ratio := clampf(elapsed / maxf(0.001, float(data.windup)), 0.0, 1.0)
			frame = 3 if wound and windup_ratio < 0.45 else 4
			# 第三击蓄力压低重心 + 后撤高举，肉眼可辨蓄势重斩
			var crouch_t := smoothstep(0.0, 1.0, windup_ratio if wound else 1.0)
			body_scale = Vector2(lerpf(1.0, 1.09, crouch_t), lerpf(1.0, 0.87, crouch_t))
			body_offset = _heavy_lean(direction, 0.0)
			body_tilt = -0.06 * signf(direction.x if absf(direction.x) > 0.15 else 1.0) * crouch_t
		else:
			# 重斩收招前半滞重压低，后半平稳起身收刀
			frame = 5 if rec_ratio < 0.68 else 8
			var rise_t := smoothstep(0.42, 1.0, rec_ratio)
			body_scale = Vector2(lerpf(1.07, 1.0, rise_t), lerpf(0.92, 1.0, rise_t))
			body_offset = _heavy_lean(direction, 1.0) * (1.0 - rise_t)
	elif stage == 1:
		mirror_x = -1.0
		if wound:
			var windup_ratio := clampf(elapsed / maxf(0.001, float(data.windup)), 0.0, 1.0)
			frame = 2 if windup_ratio < 0.52 else 3
			body_scale = Vector2(1.03, 0.96)
			body_offset = -direction * 2.2 * windup_ratio + Vector2(0.0, 1.2)
		else:
			frame = 7 if rec_ratio < 0.65 else 8
			body_scale = Vector2(0.98, 1.02)
	else:
		if wound:
			var windup_ratio := clampf(elapsed / maxf(0.001, float(data.windup)), 0.0, 1.0)
			frame = 0 if windup_ratio < 0.45 else 1
			body_scale = Vector2(1.02, 0.98)
			body_offset = -direction * 2.5 * windup_ratio
		else:
			frame = 6 if rec_ratio < 0.62 else 7
	var foot_comp := Vector2(0.0, 15.0 * (1.0 - body_scale.y))
	draw_set_transform(body_offset + foot_comp, body_tilt, Vector2(mirror_x * body_scale.x, body_scale.y))
	draw_texture_rect_region(player_attack_sheet, Rect2(S_ORIGIN, S_CELL * ART_SCALE),
		Rect2(Vector2(frame * S_CELL.x, row * S_CELL.y), S_CELL))
	draw_set_transform(Vector2.ZERO)

func _draw_strike_pose(direction: Vector2, stage: int, progress: float, edge: Vector2, rec_ratio: float) -> void:
	var row := _strike_row(direction, stage)
	var mirror := Vector2(-1, 1) if stage == 1 else Vector2.ONE
	var hand := sword_hand(direction, stage, progress)
	var hand_cell: Vector2 = DOWNCUT_HAND[row]
	var source_blade: Vector2 = (DOWNCUT_TIP[row] - hand_cell) * mirror
	var blade_direction := hand.direction_to(edge)
	var angle := source_blade.angle_to(blade_direction)
	var offset := _strike_offset(direction, stage, progress)
	var body_scale := Vector2.ONE
	var body_tilt := 0.0
	if stage == 0:
		# 第一击横斩：利落前冲、轻微横向速度拉伸
		var pulse := sin(progress * PI) * (1.0 - rec_ratio)
		body_scale = Vector2(1.0 + 0.05 * pulse, 1.0 - 0.04 * pulse)
	elif stage == 1:
		# 第二击反向斜挑：微上提拉长 + 反向斜倾
		var lift_pulse := sin(progress * PI) * (1.0 - rec_ratio * 0.8)
		body_scale = Vector2(1.0 - 0.04 * lift_pulse, 1.0 + 0.06 * lift_pulse)
		body_tilt = -0.055 * lift_pulse * signf(direction.x if absf(direction.x) > 0.15 else 1.0)
	else:
		# 第三击重劈：下压蓄劲爆发压低重心，收招前段保持厚重定势
		var slam := smoothstep(CONFIG.THIRD_IMPACT_PROGRESS, 0.45, progress) * (1.0 - rec_ratio * 0.4)
		body_scale = Vector2(1.0 + 0.09 * slam, 1.0 - 0.09 * slam)
		body_tilt = 0.065 * slam * signf(direction.x if absf(direction.x) > 0.15 else 1.0)
	var behind := direction.y < -0.55 and blade_direction.y < -0.4
	if behind:
		_draw_strike_blade(row, hand_cell, hand, angle, mirror)
	var foot_comp := Vector2(0.0, 15.0 * (1.0 - body_scale.y))
	draw_set_transform(offset + foot_comp, body_tilt, Vector2(mirror.x * body_scale.x, mirror.y * body_scale.y))
	draw_texture_rect_region(player_strike_sheet, Rect2(S_ORIGIN, S_CELL * ART_SCALE),
		Rect2(Vector2(0, row * S_CELL.y), S_CELL))
	if not behind:
		_draw_strike_blade(row, hand_cell, hand, angle, mirror)
	draw_set_transform(Vector2.ZERO)

func _draw_strike_blade(row: int, hand_cell: Vector2, hand: Vector2, angle: float, mirror: Vector2) -> void:
	draw_set_transform(hand, angle, mirror)
	draw_texture_rect_region(S_STRIKE_POSE, Rect2(-hand_cell * ART_SCALE, S_CELL * ART_SCALE),
		Rect2(Vector2(S_CELL.x, row * S_CELL.y), S_CELL))

func _draw() -> void:
	if herbalist_visual:
		_draw_herbalist()
		return
	var is_player := get_parent() is SurvivorPlayer or player_death
	var player = get_parent() if is_player and not player_death else null
	if player != null and is_instance_valid(player.combo) and player.combo.dash_armed:
		_draw_thunder_armed_aura()
	if player != null and player.dash_state != 0:
		_draw_dash(player)
		return
	if player != null and is_instance_valid(player.thrown_sword):
		_draw_throw_pose(player.thrown_sword.aim)
		return
	if player != null and is_instance_valid(player.combo) and player.combo.swing_time > 0.0:
		_draw_player_attack(player)
		return
	if player != null and player.is_casting_sword_rain():
		_draw_sword_rain_cast(player)
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
	var enemy_guarding: bool = enemy != null and not enemy_attacking and enemy.has_method("is_guarding_stance") and enemy.is_guarding_stance()
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
	elif enemy_guarding:
		# 持剑横挡架势：定格在横刃起手帧并略微沉肩稳姿
		sheet = B_ATTACK
		frame = 2
		var guard_idx := _direction_index(enemy.guard_direction)
		var rows := [0, 0, 1, 1, 2, 3, 3, 0]
		row = rows[guard_idx]
		flip = guard_idx in [6, 7]
	elif motion.length_squared() >= 1.0 and roll_time <= 0.0:
		sheet = S_WALK if is_player else B_WALK
		frame = int(animation_clock * 8.0) % 9
	var destination := Rect2(-pivot * ART_SCALE + Vector2(0, 15), size * ART_SCALE)
	var source := Rect2(Vector2(frame * size.x, row * size.y), size)
	if is_instance_valid(hit_flash_mat):
		hit_flash_mat.set_shader_parameter("hurt_flash", CONFIG.ENEMY_FLASH_STRENGTH * clampf(hurt_time / CONFIG.ENEMY_FLASH_DURATION, 0.0, 1.0))
	var recoil_sx := 1.035 if (not is_player and hurt_time > 0.0) else (1.05 if enemy_guarding else 1.0)
	var recoil_sy := 0.965 if (not is_player and hurt_time > 0.0) else (0.95 if enemy_guarding else 1.0)
	var sx := -recoil_sx if flip else recoil_sx
	if flip or not is_equal_approx(recoil_sx, 1.0):
		draw_set_transform(Vector2(0.0, 15.0 * (1.0 - recoil_sy)), 0.0, Vector2(sx, recoil_sy))
	draw_texture_rect_region(sheet, destination, source)
	if flip or not is_equal_approx(recoil_sx, 1.0):
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
	if is_instance_valid(hit_flash_mat):
		hit_flash_mat.set_shader_parameter("hurt_flash", CONFIG.ENEMY_FLASH_STRENGTH * clampf(hurt_time / CONFIG.ENEMY_FLASH_DURATION, 0.0, 1.0))
	var recoil_sx := 1.035 if hurt_time > 0.0 else 1.0
	var recoil_sy := 0.965 if hurt_time > 0.0 else 1.0
	var sx := -recoil_sx if flip else recoil_sx
	if flip or not is_equal_approx(recoil_sx, 1.0):
		draw_set_transform(Vector2(0.0, 15.0 * (1.0 - recoil_sy)), 0.0, Vector2(sx, recoil_sy))
	draw_texture_rect_region(sheet, destination, source)
	if flip or not is_equal_approx(recoil_sx, 1.0):
		draw_set_transform(Vector2.ZERO)

func _draw_thunder_armed_aura() -> void:
	# 【雷霆残影】下一剑伤害翻倍蓄力就绪时的青金电弧微光提示
	var pulse := 0.55 + 0.45 * sin(animation_clock * 16.0)
	draw_set_transform(Vector2(0, 14), 0.0, Vector2(1.0, 0.38))
	draw_arc(Vector2.ZERO, 20.0 + pulse * 3.0, 0.0, TAU, 24, Color(0.55, 0.96, 1.0, 0.42 + pulse * 0.25), 2.0, false)
	draw_set_transform(Vector2.ZERO)
	for i in range(4):
		var a := animation_clock * 5.2 + i * PI * 0.5
		var p := Vector2(cos(a) * 18.0, sin(a) * 11.0 - 4.0).round()
		var q := (p + Vector2(cos(a + 0.9) * 6.0, -5.0)).round()
		draw_line(p, q, Color(1.0, 0.92, 0.52, 0.85), 1.5, false)
		draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color(0.68, 1.0, 0.98, 0.92))

func _draw_sword_rain_cast(player) -> void:
	# 【万剑归宗】念咒/结印前摇姿态：沉身起诀、双层聚灵法环与旋升法诀微光
	var rain = player.sword_rain_node
	var t: float = rain.cast_progress() if is_instance_valid(rain) else 0.5
	var aim: Vector2 = rain.aim if is_instance_valid(rain) else look_direction
	var row := _direction_index(aim)
	var rank: int = clampi(player.cultivation, 0, 2)
	var ring_col := Color("8be6ff") if rank == 0 else (Color("56eee8") if rank == 1 else Color("44d2ff"))
	var core_col := Color("ffe17d") if rain.empowered else Color("f6ffff")

	# 脚下双层聚灵法环
	draw_set_transform(Vector2(0, 14), 0.0, Vector2(1.0, 0.38))
	draw_arc(Vector2.ZERO, lerpf(16.0, 34.0, t), 0.0, TAU, 24, Color(ring_col, 0.55 + 0.30 * t), 2.2, false)
	draw_arc(Vector2.ZERO, lerpf(10.0, 24.0, t), t * TAU, t * TAU + TAU * 0.72, 20, Color(core_col, 0.72), 1.6, false)
	draw_set_transform(Vector2.ZERO)

	# 沉身起诀姿态（脚底锚定微压蓄势 + 末段轻提）
	var frame := 3 if t < 0.55 else 4
	var sy := lerpf(1.0, 0.92, sin(t * PI))
	var sx := lerpf(1.0, 1.06, sin(t * PI))
	var foot_comp := Vector2(0.0, 15.0 * (1.0 - sy))
	draw_set_transform(foot_comp, 0.0, Vector2(sx, sy))
	draw_texture_rect_region(player_attack_sheet, Rect2(S_ORIGIN, S_CELL * ART_SCALE),
		Rect2(Vector2(frame * S_CELL.x, row * S_CELL.y), S_CELL))
	draw_set_transform(Vector2.ZERO)

	# 胸前结印微芒 + 周身旋升 4 枚法诀灵点
	var seal_pos := (aim * 11.0 + Vector2(0, -12.0 - t * 4.0)).round()
	draw_line(seal_pos + Vector2(-5, 0), seal_pos + Vector2(5, 0), Color(core_col, 0.85 * t), 1.5, false)
	draw_line(seal_pos + Vector2(0, -5), seal_pos + Vector2(0, 5), Color(core_col, 0.85 * t), 1.5, false)
	for i in range(4):
		var a := t * TAU * 1.4 + i * PI * 0.5
		var rad := lerpf(26.0, 16.0, t)
		var p := Vector2(cos(a) * rad, sin(a) * rad * 0.45 + lerpf(8.0, -24.0, t)).round()
		draw_rect(Rect2(p - Vector2(1.5, 1.5), Vector2(3, 3)), Color(ring_col if i % 2 == 0 else core_col, 0.88))

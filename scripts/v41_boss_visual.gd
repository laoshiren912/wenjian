extends ActorVisual

const S_IDLE = preload("res://assets/characters/Swordsman/Swordsman_Idle_Sheet_780x1440.png")
const S_WALK = preload("res://assets/characters/Swordsman/Swordsman_Walk_Sheet_1404x1440.png")
const S_ATTACK = preload("res://assets/characters/Swordsman/Swordsman_Attack_Sheet_1404x1440.png")
const S_DEATH = preload("res://assets/characters/Swordsman/Swordsman_Death_Sheet_1404x540.png")
const TINT_SHADER = preload("res://assets/shaders/v41_boss_tint.gdshader")
const CONFIG = preload("res://scripts/v41_config.gd")

const CELL := Vector2(156, 180)
const BOSS_SCALE := 0.80
const ORIGIN := -Vector2(79, 135) * BOSS_SCALE + Vector2(0, 18)

var look_direction := Vector2.DOWN
var animation_clock := 0.0
var boss_material: ShaderMaterial
var charge_ghosts: Array[Dictionary] = []
var _ghost_timer := 0.0
var melee_flash := false

func _ready() -> void:
	ensure_material()

func play_melee_hurt() -> void:
	melee_flash = true
	hurt_time = CONFIG.MELEE_FLASH_DURATION
	hurt_flash_lock = maxf(hurt_flash_lock, CONFIG.ENEMY_FLASH_INTERVAL)
	queue_redraw()

func play_hurt() -> void:
	if hurt_flash_lock <= 0.00001:
		melee_flash = false
	start_limited_hurt_flash(CONFIG.ENEMY_FLASH_INTERVAL, CONFIG.ENEMY_FLASH_DURATION)

func ensure_material() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if not is_instance_valid(boss_material):
		boss_material = ShaderMaterial.new()
		boss_material.shader = TINT_SHADER
	if material != boss_material:
		material = boss_material

func update_pose(actual_motion: Vector2, look: Vector2, color: Color, leg_look: Vector2 = Vector2.ZERO) -> void:
	if look.length_squared() > 0.01:
		look_direction = look.normalized()
	super.update_pose(actual_motion, look, color, leg_look)

func _physics_process(delta: float) -> void:
	if not get_tree().paused:
		animation_clock += delta
		super._physics_process(delta)
		for i in range(charge_ghosts.size() - 1, -1, -1):
			charge_ghosts[i].age += delta
			if float(charge_ghosts[i].age) >= 0.16:
				charge_ghosts.remove_at(i)
		var boss = get_parent()
		if not dying and boss != null and boss is SurvivorEnemy and boss.boss_state == SurvivorEnemy.BossState.CHARGING:
			_ghost_timer -= delta
			if _ghost_timer <= 0.0:
				_ghost_timer = 0.035
				charge_ghosts.append({
					"pos": boss.global_position,
					"row": _direction_index(boss.boss_charge_aim),
					"age": 0.0,
				})
		else:
			_ghost_timer = 0.0

func _direction_index(direction: Vector2) -> int:
	return posmod(roundi((direction.angle() + PI / 2.0) / (PI / 4.0)), 8)

func _draw() -> void:
	ensure_material()
	var boss = get_parent() if not dying and get_parent() is SurvivorEnemy else null
	var aim: Vector2 = boss.boss_charge_aim if boss != null and not boss.boss_charge_aim.is_zero_approx() else look_direction
	var row := _direction_index(aim)
	var sheet: Texture2D = S_IDLE
	var frame := int(animation_clock * 5.0) % 5
	var body_offset := Vector2.ZERO
	var body_scale := Vector2.ONE
	var aura := 0.0

	if dying:
		sheet = S_DEATH
		frame = mini(8, int(death_age / DEATH_DURATION * 9.0))
		row = 0 if row in [0, 1, 2, 7] else (2 if row in [5, 6] else 1)
	elif boss != null:
		match boss.boss_state:
			SurvivorEnemy.BossState.APPROACH:
				if motion.length_squared() >= 4.0:
					sheet = S_WALK
					frame = int(animation_clock * 7.0) % 9
				else:
					sheet = S_IDLE
					frame = int(animation_clock * 5.0) % 5
			SurvivorEnemy.BossState.COMBO_WINDUP:
				sheet = S_ATTACK
				var t := clampf(1.0 - boss.boss_timer / maxf(0.01, boss.SWEEP_WINDUP), 0.0, 1.0)
				frame = 2 if t < 0.35 else (3 if t < 0.72 else 4)
				aura = lerpf(0.25, 1.0, t)
				body_scale = Vector2(lerpf(1.0, 1.08, t), lerpf(1.0, 0.90, t))
				body_offset = -aim * (6.0 * t) + Vector2(sin(animation_clock * 48.0) * 1.4 * t, 0.0)
			SurvivorEnemy.BossState.CHARGE_WINDUP:
				sheet = S_ATTACK
				var t := clampf(1.0 - boss.boss_timer / maxf(0.01, boss.CHARGE_WINDUP), 0.0, 1.0)
				frame = 1 if t < 0.45 else 3
				aura = lerpf(0.30, 1.0, t)
				body_scale = Vector2(lerpf(1.0, 1.10, t), lerpf(1.0, 0.88, t))
				body_offset = -aim * (9.0 * t)
			SurvivorEnemy.BossState.CHARGING:
				sheet = S_ATTACK
				frame = 5
				aura = 1.0
				body_scale = Vector2(1.08, 0.94)
				body_offset = aim * 4.0
			SurvivorEnemy.BossState.RECOVERY:
				sheet = S_ATTACK
				var elapsed: float = boss.RECOVERY - boss.boss_timer
				if elapsed < 0.18:
					frame = 6
					body_offset = aim * 5.0
					aura = (1.0 - elapsed / 0.18) * 0.65
				elif elapsed < 0.42:
					frame = 7
					body_offset = aim * 2.0
				else:
					frame = 8

	if is_instance_valid(boss_material):
		boss_material.set_shader_parameter("hurt_flash", (1.0 if melee_flash and hurt_time > 0.0 else CONFIG.BOSS_FLASH_STRENGTH * clampf(hurt_time / CONFIG.ENEMY_FLASH_DURATION, 0.0, 1.0)))
	if hurt_time > 0.0:
		body_scale *= Vector2(1.022, 0.978)

	# 冲锋赤金像素残像
	if boss != null:
		for g in charge_ghosts:
			var g_alpha := (1.0 - float(g.age) / 0.16) * 0.42
			var g_local: Vector2 = to_local(g.pos)
			draw_texture_rect_region(
				S_ATTACK,
				Rect2(g_local + ORIGIN, CELL * BOSS_SCALE),
				Rect2(Vector2(5 * CELL.x, int(g.row) * CELL.y), CELL),
				Color(1.0, 0.56, 0.24, g_alpha)
			)

	# 脚底柔和阴影与微弱玄金威压地环（非粗几何占位）
	if not dying:
		draw_set_transform(Vector2(0, 17), 0.0, Vector2(1.0, 0.36))
		draw_circle(Vector2.ZERO, 24.0, Color(0.05, 0.03, 0.06, 0.34))
		draw_arc(Vector2.ZERO, 26.0, 0.0, TAU, 32, Color(0.95, 0.68, 0.28, 0.28 + aura * 0.35), 1.8, false)
		draw_set_transform(Vector2.ZERO)

	var foot_comp := Vector2(0.0, 18.0 * (1.0 - body_scale.y))
	draw_set_transform(body_offset + foot_comp, 0.0, body_scale)
	draw_texture_rect_region(
		sheet,
		Rect2(ORIGIN, CELL * BOSS_SCALE),
		Rect2(Vector2(frame * CELL.x, row * CELL.y), CELL),
		Color.WHITE
	)
	draw_set_transform(Vector2.ZERO)

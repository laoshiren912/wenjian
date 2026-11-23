extends Node2D

const CONFIG = preload("res://scripts/v41_config.gd")
const SLASH_SHADER = preload("res://assets/shaders/v41_combo_slash.gdshader")
const SEAL_SHADER = preload("res://assets/shaders/v41_bagua_seal.gdshader")

const FADE_DURATIONS := [0.085, 0.095, 0.12]
const ARC_HALF_RAD := [1.12, 1.24, 0.92]
const SEAL_DURATION := 0.15

var sword
var slash_sprite: Sprite2D
var slash_material: ShaderMaterial
var _unit_texture: ImageTexture
var block_recoil := 0.0
var _last_attack_id := -1
var _seal_spawned := false

func _get_unit_texture() -> ImageTexture:
	if _unit_texture == null:
		var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		image.set_pixel(0, 0, Color.WHITE)
		_unit_texture = ImageTexture.create_from_image(image)
	return _unit_texture

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_as_relative = false
	slash_material = ShaderMaterial.new()
	slash_material.shader = SLASH_SHADER
	slash_sprite = Sprite2D.new()
	slash_sprite.texture = _get_unit_texture()
	slash_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	slash_sprite.material = slash_material
	slash_sprite.visible = false
	add_child(slash_sprite)

func bind_sword(target_sword) -> void:
	sword = target_sword

func trigger_block_recoil() -> void:
	block_recoil = 1.0

func notify_third_impact(world_point: Vector2, rank: int, boosted: bool) -> void:
	if rank == 2 and not _seal_spawned:
		_seal_spawned = true
		spawn_ground_effect(world_point, 0, rank, 1.0 if boosted else 0.88)

func spawn_ground_effect(world_point: Vector2, effect_mode: int, rank: int, intensity: float = 1.0) -> void:
	var host := _effect_host()
	if host == null:
		return
	var fx := Node2D.new()
	fx.global_position = world_point
	fx.z_index = 1 if effect_mode == 0 else 2
	fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var mat := ShaderMaterial.new()
	mat.shader = SEAL_SHADER
	mat.set_shader_parameter("effect_mode", effect_mode)
	mat.set_shader_parameter("progress", 0.0)
	mat.set_shader_parameter("intensity", intensity)
	mat.set_shader_parameter("pixel_grid", 52.0 if effect_mode == 0 else 60.0)

	var primary := Color("d6e6f5")
	var core := Color("ffffff")
	if rank == 1:
		primary = Color("55e8e3")
		core = Color("ecffff")
	elif rank == 2:
		primary = Color("44cfff")
		core = Color("f6fdff")
	if effect_mode == 1 and intensity > 1.05:
		# 破防气浪略带金青锋锐
		primary = primary.lerp(Color("ffd98a"), 0.45)
	if effect_mode == 1:
		primary = Color("075acc")
		core = Color("16c8ff")
	mat.set_shader_parameter("primary_color", primary)
	mat.set_shader_parameter("core_color", core)

	var sprite := Sprite2D.new()
	sprite.texture = _get_unit_texture()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.material = mat
	var size_px := 92.0 if effect_mode == 0 else (98.0 + float(rank) * 12.0)
	sprite.scale = Vector2(size_px, size_px)
	if effect_mode == 1:
		sprite.scale.y *= 0.48
	fx.add_child(sprite)
	host.add_child(fx)

	var duration := SEAL_DURATION if effect_mode == 0 else (0.19 if intensity <= 1.05 else 0.23)
	var tween := fx.create_tween()
	tween.tween_method(func(val: float):
		if is_instance_valid(mat):
			mat.set_shader_parameter("progress", val), 0.0, 1.0, duration)
	tween.tween_callback(fx.queue_free)

func _effect_host() -> Node:
	if not is_instance_valid(sword):
		return null
	var player: Node = sword.get_parent()
	if not is_instance_valid(player):
		return null
	return player.get_parent()

func _process(delta: float) -> void:
	if block_recoil > 0.0:
		block_recoil = maxf(0.0, block_recoil - delta * 9.5)
	if not is_instance_valid(sword):
		slash_sprite.visible = false
		return
	var player = sword.get_parent()
	if not is_instance_valid(player) or player.dead or player.is_rolling() or sword.charged_swing or sword.swing_time <= 0.0:
		slash_sprite.visible = false
		return

	var current_attack_id: int = sword.attack_count
	if current_attack_id != _last_attack_id:
		_last_attack_id = current_attack_id
		_seal_spawned = false
		block_recoil = 0.0

	var phase_name: String = sword.phase()
	var slot: int = clampi(sword.stage, 0, 2)
	var rank: int = clampi(sword.swing_rank, 0, 2)
	var data: Dictionary = sword.current_data()
	var speed_mult: float = maxf(0.01, player.attack_speed_multiplier)
	var progress: float = sword.active_progress(sword.swing_time)
	var fade_progress := 0.0

	if phase_name == "windup":
		# 一、二击前摇干脆利落不提前亮刀光；第三击仅在蓄势末段显极克制剑意微线
		if slot != 2:
			slash_sprite.visible = false
			return
		var elapsed: float = (sword.swing_duration - sword.swing_time) * speed_mult
		var windup_ratio := clampf(elapsed / maxf(0.001, float(data.windup)), 0.0, 1.0)
		if windup_ratio < 0.45:
			slash_sprite.visible = false
			return
		progress = lerpf(0.02, 0.16, (windup_ratio - 0.45) / 0.55)
	elif phase_name == "recovery":
		var fade_limit: float = FADE_DURATIONS[slot]
		var elapsed: float = (sword.swing_duration - sword.swing_time) * speed_mult
		var rec_elapsed: float = elapsed - float(data.windup) - float(data.active)
		if rec_elapsed >= fade_limit:
			slash_sprite.visible = false
			return
		progress = 1.0
		fade_progress = clampf(rec_elapsed / fade_limit, 0.0, 1.0)

	# 阶段3第三击劈落至落点：一瞬即逝（0.15s）的仙纹/八卦微光印记（空挥不触发砸地气浪）
	if slot == 2 and rank == 2 and not _seal_spawned and phase_name != "windup" and progress >= CONFIG.THIRD_IMPACT_PROGRESS + 0.06:
		_seal_spawned = true
		var seal_reach: float = (float(data.reach) + player.reach_bonus + CONFIG.SWORD_EXTENSION[rank]) * 0.72
		var seal_pos: Vector2 = player.global_position + sword.swing_direction * seal_reach
		spawn_ground_effect(seal_pos, 0, rank, 0.78)

	# 严格贴剑挥砍半径与锁定朝向（凡剑紧咬直剑剑尖，御气外放，仙术双层外扩）
	var reach: float = float(data.reach) + player.reach_bonus + CONFIG.SWORD_EXTENSION[rank]
	var aim: Vector2 = sword.swing_direction.normalized() if not sword.swing_direction.is_zero_approx() else Vector2.RIGHT

	var empowered: bool = sword.swing_bonus > 1.01
	var radius_ratio: float = [0.68, 0.78, 0.88][rank]
	if slot == 2:
		radius_ratio = [0.74, 0.84, 0.94][rank]
	if empowered:
		radius_ratio *= 1.10
	var visual_radius := reach * radius_ratio
	var quad_size := visual_radius * 2.0
	var center_offset := aim * (4.0 if slot < 2 else 7.0) + Vector2(0.0, -4.0 if slot < 2 else -2.0)

	# 朝上挥砍时将刀光稍微让位于角色轮廓，保持清晰可读（保持非负 Z 避免落到场景背景之下）
	var aiming_up := aim.y < -0.45
	z_index = 0 if aiming_up else 2

	slash_sprite.visible = true
	slash_sprite.position = center_offset
	slash_sprite.rotation = aim.angle()
	slash_sprite.scale = Vector2(quad_size, quad_size)
	slash_sprite.modulate = Color(1.0, 0.96, 0.70, 1.0) if empowered else Color.WHITE

	# 虚拟像素网格与主角像素密度严格对齐（约 1.6px 一个像素点）
	var pixel_grid := clampf(roundf(quad_size / 1.6), 76.0, 156.0)
	slash_material.set_shader_parameter("rank_stage", rank)
	slash_material.set_shader_parameter("combo_slot", slot)
	slash_material.set_shader_parameter("slash_progress", progress)
	slash_material.set_shader_parameter("fade_progress", fade_progress)
	slash_material.set_shader_parameter("half_arc", ARC_HALF_RAD[slot])
	slash_material.set_shader_parameter("pixel_grid", pixel_grid)
	slash_material.set_shader_parameter("block_recoil", block_recoil)
	slash_material.set_shader_parameter("behind_soften", 1.0 if aiming_up else 0.0)

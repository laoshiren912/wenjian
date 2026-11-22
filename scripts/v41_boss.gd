extends SurvivorEnemy

const BOSS_VISUAL = preload("res://scripts/v41_boss_visual.gd")
const BOSS_VFX_SHADER = preload("res://assets/shaders/v41_boss_vfx.gdshader")
const HEALTH := 4400.0
const APPROACH_SPEED := 228.0
const SWEEP_REACH := 102.0
const SWEEP_HALF_ANGLE := 1.32
const SWEEP_WINDUP := 0.68
const SWEEP_DAMAGE := 22.0
const CHARGE_REACH := 165.0
const CHARGE_WIDTH := 34.0
const CHARGE_WINDUP := 0.74
const CHARGE_SPEED := 495.0
const CHARGE_DAMAGE := 25.0
const RECOVERY := 0.86
const IMPACT_TIME := 0.22

var vfx_sprite: Sprite2D
var vfx_material: ShaderMaterial
var _unit_tex: ImageTexture

func _ready() -> void:
	name = "心魔"
	kind = Kind.BOSS
	v41_pressure = true
	var vr := get_node_or_null("VisualRoot")
	if vr != null and vr.get_script() != BOSS_VISUAL:
		vr.set_script(BOSS_VISUAL)
	super._ready()
	max_health = HEALTH
	health = max_health
	speed = APPROACH_SPEED
	visual.scale = Vector2.ONE
	visual.z_index = 1
	_setup_vfx()

func _setup_vfx() -> void:
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, Color.WHITE)
	_unit_tex = ImageTexture.create_from_image(img)
	vfx_material = ShaderMaterial.new()
	vfx_material.shader = BOSS_VFX_SHADER
	vfx_sprite = Sprite2D.new()
	vfx_sprite.name = "BossAttackVfx"
	vfx_sprite.texture = _unit_tex
	vfx_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	vfx_sprite.material = vfx_material
	vfx_sprite.visible = false
	add_child(vfx_sprite)

func _boss_process(delta: float) -> void:
	flash = maxf(0.0, flash - delta)
	boss_timer -= delta
	repath -= delta
	var offset := player.global_position - global_position
	var visible := _boss_has_sight(player.global_position)
	if visible:
		boss_last_seen = player.global_position
		boss_has_last_seen = true
		boss_searching = false
	match boss_state:
		BossState.APPROACH:
			var reach := SWEEP_REACH - 14.0 if boss_next_attack == 0 else CHARGE_REACH
			if visible:
				if not offset.is_zero_approx():
					boss_charge_aim = offset.normalized()
				var can_reach := boss_next_attack == 0 or _boss_open_charge_distance(CHARGE_REACH) + CHARGE_WIDTH >= offset.length()
				if boss_timer <= 0.0 and offset.length() <= reach and can_reach:
					_begin_attack()
				elif offset.length() > reach or not can_reach:
					velocity = _follow_path(player.global_position) * speed
					move_and_slide()
			else:
				velocity = _boss_search() * speed
				move_and_slide()
		BossState.COMBO_WINDUP:
			if boss_timer <= 0.0:
				if visible and offset.length() <= SWEEP_REACH and absf(boss_charge_aim.angle_to(offset)) <= SWEEP_HALF_ANGLE:
					player.take_damage(SWEEP_DAMAGE, offset.normalized())
				_finish_attack(1)
		BossState.CHARGE_WINDUP:
			if boss_timer <= 0.0:
				boss_state = BossState.CHARGING
				boss_charge_remaining = boss_charge_distance
				boss_charge_hit = false
		BossState.CHARGING:
			var start := global_position
			var travel := minf(boss_charge_remaining, CHARGE_SPEED * delta)
			var collision := move_and_collide(boss_charge_aim * travel)
			var closest := Geometry2D.get_closest_point_to_segment(player.global_position, start, global_position)
			if not boss_charge_hit and closest.distance_to(player.global_position) <= CHARGE_WIDTH and _boss_has_sight(player.global_position):
				boss_charge_hit = true
				player.take_damage(CHARGE_DAMAGE, boss_charge_aim)
			boss_charge_remaining -= travel
			if collision or boss_charge_remaining <= 0.0:
				_finish_attack(0)
		BossState.RECOVERY:
			if boss_timer <= 0.0:
				boss_state = BossState.APPROACH
	if boss_state == BossState.CHARGING:
		knockback = Vector2.ZERO
	elif knockback.length_squared() > 1.0:
		move_and_collide(knockback * delta)
		knockback = knockback.lerp(Vector2.ZERO, minf(1.0, 18.0 * delta))
		if knockback.length_squared() < 2.0:
			knockback = Vector2.ZERO
	visual.update_pose(get_real_velocity() if boss_state == BossState.APPROACH else Vector2.ZERO, boss_charge_aim, Color("e6a451"))
	_update_vfx()
	queue_redraw()

func _update_vfx() -> void:
	if not is_instance_valid(vfx_sprite) or dead:
		return
	var aim := boss_charge_aim.normalized() if not boss_charge_aim.is_zero_approx() else Vector2.RIGHT
	match boss_state:
		BossState.COMBO_WINDUP:
			var t := clampf(1.0 - boss_timer / SWEEP_WINDUP, 0.0, 1.0)
			vfx_sprite.visible = true
			vfx_sprite.z_index = 0
			vfx_sprite.centered = true
			vfx_sprite.position = Vector2.ZERO
			vfx_sprite.rotation = aim.angle()
			var d := SWEEP_REACH * 2.04
			vfx_sprite.scale = Vector2(d, d)
			vfx_material.set_shader_parameter("mode", 0)
			vfx_material.set_shader_parameter("progress", t)
			vfx_material.set_shader_parameter("half_arc", SWEEP_HALF_ANGLE)
			vfx_material.set_shader_parameter("pixel_grid", 104.0)
		BossState.CHARGE_WINDUP:
			var t := clampf(1.0 - boss_timer / CHARGE_WINDUP, 0.0, 1.0)
			var length := boss_charge_distance + CHARGE_WIDTH
			vfx_sprite.visible = true
			vfx_sprite.z_index = 0
			vfx_sprite.centered = true
			vfx_sprite.position = aim * (length * 0.5)
			vfx_sprite.rotation = aim.angle()
			vfx_sprite.scale = Vector2(length, CHARGE_WIDTH * 2.0)
			vfx_material.set_shader_parameter("mode", 2)
			vfx_material.set_shader_parameter("progress", t)
			vfx_material.set_shader_parameter("pixel_grid", 88.0)
		BossState.CHARGING:
			var prog := clampf(1.0 - boss_charge_remaining / maxf(1.0, boss_charge_distance), 0.0, 1.0)
			vfx_sprite.visible = true
			vfx_sprite.z_index = 2
			vfx_sprite.centered = true
			vfx_sprite.position = -aim * 22.0
			vfx_sprite.rotation = aim.angle()
			vfx_sprite.scale = Vector2(96.0, CHARGE_WIDTH * 2.1)
			vfx_material.set_shader_parameter("mode", 3)
			vfx_material.set_shader_parameter("progress", prog)
			vfx_material.set_shader_parameter("pixel_grid", 72.0)
		BossState.RECOVERY:
			var elapsed := RECOVERY - boss_timer
			if elapsed < IMPACT_TIME and boss_next_attack == 1:
				var t := clampf(elapsed / IMPACT_TIME, 0.0, 1.0)
				vfx_sprite.visible = true
				vfx_sprite.z_index = 2
				vfx_sprite.centered = true
				vfx_sprite.position = Vector2.ZERO
				vfx_sprite.rotation = aim.angle()
				var d := SWEEP_REACH * 2.16
				vfx_sprite.scale = Vector2(d, d)
				vfx_material.set_shader_parameter("mode", 1)
				vfx_material.set_shader_parameter("progress", t)
				vfx_material.set_shader_parameter("half_arc", SWEEP_HALF_ANGLE)
				vfx_material.set_shader_parameter("pixel_grid", 112.0)
			else:
				vfx_sprite.visible = false
		_:
			vfx_sprite.visible = false

func _follow_path(target: Vector2) -> Vector2:
	# A centre ray can clear a pillar while the body's radius still hits it.
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = $CollisionShape2D.shape
	query.transform = global_transform
	query.motion = target - global_position
	query.collision_mask = world.terrain_movement_mask
	var clearance := get_world_2d().direct_space_state.cast_motion(query)
	if global_position.distance_to(target) < 130.0 and clearance[0] >= 1.0:
		return (target - global_position).normalized()
	if path.is_empty() or repath <= 0.0:
		path = world.path_between(global_position, target)
		# Visit the first safe centre instead of cutting across its corner.
		path_index = 0
		repath = 0.55
	while path_index < path.size() and global_position.distance_to(path[path_index]) < 10.0:
		path_index += 1
	if path_index < path.size():
		return (path[path_index] - global_position).normalized()
	return Vector2.ZERO

func _begin_attack() -> void:
	if boss_next_attack == 0:
		boss_state = BossState.COMBO_WINDUP
		boss_timer = SWEEP_WINDUP
	else:
		boss_state = BossState.CHARGE_WINDUP
		boss_timer = CHARGE_WINDUP
		boss_charge_distance = _boss_open_charge_distance(CHARGE_REACH)

func _finish_attack(next_attack: int) -> void:
	boss_next_attack = next_attack
	boss_state = BossState.RECOVERY
	boss_timer = RECOVERY

func _draw() -> void:
	# Boss body, ground aura, telegraphs and slashes are rendered by pixel visual & shader nodes.
	pass

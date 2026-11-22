extends Node2D

const PORTAL_SHADER = preload("res://assets/shaders/v41_portal_array.gdshader")

var active := false
var active_ratio := 0.0
var burst_flash := 0.0
var wave_age := -1.0
var clock := 0.0
var portal_radius := 28.0

var base_sprite: Sprite2D
var base_mat: ShaderMaterial
var _unit_tex: ImageTexture
var overlay_fx: Node2D
var motes: Array[Dictionary] = []

class PortalOverlayFX extends Node2D:
	var owner_fx: Node2D
	func _draw() -> void:
		if not is_instance_valid(owner_fx):
			return
		owner_fx._draw_overlay(self)

func _ready() -> void:
	z_index = -2
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, Color.WHITE)
	_unit_tex = ImageTexture.create_from_image(img)

	base_mat = ShaderMaterial.new()
	base_mat.shader = PORTAL_SHADER
	base_sprite = Sprite2D.new()
	base_sprite.texture = _unit_tex
	base_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	base_sprite.material = base_mat
	base_sprite.centered = true
	add_child(base_sprite)

	overlay_fx = PortalOverlayFX.new()
	overlay_fx.owner_fx = self
	overlay_fx.z_index = 18
	overlay_fx.z_as_relative = false
	add_child(overlay_fx)

	for i in range(14):
		motes.append({
			"angle": TAU * float(i) / 14.0,
			"dist": 0.25 + float(i % 5) * 0.16,
			"phase": float(i) / 14.0,
			"speed": 0.46 + float(i % 4) * 0.11,
			"gold": i % 2 == 0,
		})

func configure(pos: Vector2, enabled: bool, radius: float) -> void:
	position = pos
	visible = enabled
	portal_radius = radius
	var diameter := radius * 3.25
	if is_instance_valid(base_sprite):
		base_sprite.scale = Vector2(diameter, diameter)
	active = false
	active_ratio = 0.0
	burst_flash = 0.0
	wave_age = -1.0
	_sync_shader()
	if is_instance_valid(overlay_fx):
		overlay_fx.queue_redraw()

func set_portal_active(is_open: bool, play_wave: bool = false) -> void:
	var was_active := active
	active = is_open
	if is_open and (play_wave or not was_active):
		wave_age = 0.0
		burst_flash = maxf(burst_flash, 0.55)
	if not is_open:
		active_ratio = 0.0
		burst_flash = 0.0
		wave_age = -1.0
	_sync_shader()
	if is_instance_valid(overlay_fx):
		overlay_fx.queue_redraw()

func trigger_step_in_burst() -> void:
	burst_flash = 1.0
	wave_age = 0.0
	_sync_shader()
	if is_instance_valid(overlay_fx):
		overlay_fx.queue_redraw()

func _process(delta: float) -> void:
	if not visible:
		return
	clock += delta
	var target := 1.0 if active else 0.0
	active_ratio = move_toward(active_ratio, target, delta * 3.8)
	if burst_flash > 0.0:
		burst_flash = maxf(0.0, burst_flash - delta * 2.2)
	if wave_age >= 0.0:
		wave_age += delta
		if wave_age >= 0.85:
			wave_age = -1.0
	_sync_shader()
	if is_instance_valid(overlay_fx):
		overlay_fx.queue_redraw()

func _sync_shader() -> void:
	if not is_instance_valid(base_mat):
		return
	base_mat.set_shader_parameter("time_sec", clock)
	base_mat.set_shader_parameter("active_ratio", active_ratio)
	base_mat.set_shader_parameter("burst_flash", burst_flash)

func _draw_overlay(canvas: Node2D) -> void:
	if active_ratio <= 0.02:
		return
	var a := active_ratio
	var breath := 0.78 + 0.22 * sin(clock * 3.8)

	# 1. 极克制通透竖向呼吸光晕（绝不遮挡角色与建筑）
	var col_w := portal_radius * 0.92
	var col_h := 56.0 + burst_flash * 24.0
	canvas.draw_rect(Rect2(-col_w, -col_h, col_w * 2.0, col_h), Color(0.38, 0.94, 0.88, (0.075 * breath + burst_flash * 0.14) * a))
	canvas.draw_rect(Rect2(-col_w * 0.48, -col_h * 1.15, col_w * 0.96, col_h * 1.15), Color(0.96, 0.86, 0.56, (0.08 * breath + burst_flash * 0.18) * a))

	# 2. 激活/踏入瞬间向外扩散的亮青金双层激活波纹
	if wave_age >= 0.0:
		var wt := clampf(wave_age / 0.85, 0.0, 1.0)
		var winv := 1.0 - wt
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.84))
		canvas.draw_arc(Vector2.ZERO, lerpf(portal_radius * 0.5, portal_radius * 2.6, pow(wt, 0.55)), 0.0, TAU, 36, Color(0.42, 0.96, 0.90, winv * 0.88), 3.0 * winv + 1.0, false)
		canvas.draw_arc(Vector2.ZERO, lerpf(portal_radius * 0.3, portal_radius * 1.9, pow(wt, 0.68)), 0.0, TAU, 28, Color(0.96, 0.84, 0.48, winv * 0.78), 2.0, false)
		canvas.draw_set_transform(Vector2.ZERO)

	# 3. 持续缓缓上升的青金色细碎像素灵气光点
	for m in motes:
		var mt := fposmod(float(m.phase) + clock * float(m.speed), 1.0)
		var fade := sin(mt * PI) * a
		if fade < 0.05:
			continue
		var ang := float(m.angle) + clock * 0.65
		var rad := portal_radius * float(m.dist) * 1.12
		var pos := Vector2(cos(ang) * rad, sin(ang) * rad * 0.65 - mt * 52.0).round()
		var col := Color(0.98, 0.86, 0.48, fade * 0.92) if m.gold else Color(0.45, 0.96, 0.92, fade * 0.90)
		canvas.draw_rect(Rect2(pos - Vector2(1.5, 1.5), Vector2(3.0, 3.0)), col)
		canvas.draw_rect(Rect2(pos - Vector2(0.5, 0.5), Vector2(1.0, 1.0)), Color(1.0, 1.0, 0.96, fade * 0.9))

	# 4. 防迷路轻导引：阵眼上方克制浮动青金菱形光箭
	var bob := sin(clock * 4.4) * 4.0
	var tip := Vector2(0.0, -34.0 + bob).round()
	var guide_a := (0.68 + 0.26 * breath) * a
	var arrow_pts := PackedVector2Array([
		tip + Vector2(0.0, 8.0),
		tip + Vector2(-7.0, 0.0),
		tip + Vector2(-2.5, 0.0),
		tip + Vector2(0.0, 3.0),
		tip + Vector2(2.5, 0.0),
		tip + Vector2(7.0, 0.0),
	])
	canvas.draw_colored_polygon(arrow_pts, Color(0.04, 0.07, 0.10, 0.75 * guide_a))
	canvas.draw_polyline(arrow_pts + PackedVector2Array([arrow_pts[0]]), Color(0.98, 0.88, 0.54, guide_a), 1.6, false)
	var diamond := PackedVector2Array([
		tip + Vector2(0.0, -9.0),
		tip + Vector2(4.5, -4.5),
		tip + Vector2(0.0, 0.0),
		tip + Vector2(-4.5, -4.5),
	])
	canvas.draw_colored_polygon(diamond, Color(0.44, 0.96, 0.90, guide_a * 0.92))
	canvas.draw_rect(Rect2(tip + Vector2(-1.0, -5.5), Vector2(2.0, 2.0)), Color(1.0, 1.0, 0.96, guide_a))

extends Node2D

const SHADOW_LARGE = preload("res://assets/vfx/torr-penn-cloud-shadows/shadow-mask-0.png")
const SHADOW_MEDIUM = preload("res://assets/vfx/torr-penn-cloud-shadows/shadow-mask-3.png")
const SHADOW_SMALL = preload("res://assets/vfx/torr-penn-cloud-shadows/shadow-mask-5.png")
const CLOUD_LARGE = preload("res://assets/vfx/torr-penn-cloud-shadows/original_cloud_0.png")
const CLOUD_MEDIUM = preload("res://assets/vfx/torr-penn-cloud-shadows/original_cloud_3.png")
const BOUNDS := Vector2(1280.0, 720.0)
const WRAP_PADDING := 28.0

var room_index := 0
var clock := 0.0
var motes: Array[Dictionary] = []
var ground_cloud_layer: Node2D
var edge_cloud_layer: Node2D
var cloud_entries: Array[Dictionary] = []

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 14
	ground_cloud_layer = Node2D.new()
	ground_cloud_layer.name = "GroundCloudLayer"
	ground_cloud_layer.z_as_relative = false
	ground_cloud_layer.z_index = -5
	add_child(ground_cloud_layer)

	edge_cloud_layer = Node2D.new()
	edge_cloud_layer.name = "EdgeCloudLayer"
	edge_cloud_layer.z_as_relative = false
	edge_cloud_layer.z_index = 22
	add_child(edge_cloud_layer)
	_seed_motes()

func set_room(index: int) -> void:
	room_index = index
	visible = room_index >= 1
	_seed_motes()
	_rebuild_clouds()
	queue_redraw()

func _clear_clouds() -> void:
	cloud_entries.clear()
	if is_instance_valid(ground_cloud_layer):
		for c in ground_cloud_layer.get_children():
			c.queue_free()
	if is_instance_valid(edge_cloud_layer):
		for c in edge_cloud_layer.get_children():
			c.queue_free()

func _add_cloud(tex: Texture2D, pos: Vector2, mag: float, alpha: float, speed: float, foreground: bool) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.position = pos
	sprite.scale = Vector2.ONE * mag
	sprite.self_modulate.a = alpha
	var host := edge_cloud_layer if foreground else ground_cloud_layer
	host.add_child(sprite)
	cloud_entries.append({"sprite": sprite, "speed": speed})

func _rebuild_clouds() -> void:
	_clear_clouds()
	if not visible:
		return
	# 第 2、3、4 关（山道石阶 -> 峭壁栈道 -> 山顶殿前）：复刻第 1 关云影与边缘前景云，密度/流速逐关递进
	if room_index == 1:
		_add_cloud(SHADOW_LARGE, Vector2(240, 220), 2.35, 0.28, 15.0, false)
		_add_cloud(SHADOW_MEDIUM, Vector2(780, 415), 2.05, 0.34, 15.0, false)
		_add_cloud(SHADOW_SMALL, Vector2(1110, 540), 1.85, 0.28, 15.0, false)
		# 前景飘云严格限定在屏幕上下边缘，绝不遮挡中央战斗区
		_add_cloud(CLOUD_LARGE, Vector2(260, 56), 2.15, 0.28, 26.0, true)
		_add_cloud(CLOUD_MEDIUM, Vector2(920, 672), 1.90, 0.28, 26.0, true)
	elif room_index == 2:
		_add_cloud(SHADOW_LARGE, Vector2(190, 195), 2.50, 0.34, 21.0, false)
		_add_cloud(SHADOW_MEDIUM, Vector2(610, 360), 2.15, 0.39, 21.0, false)
		_add_cloud(SHADOW_LARGE, Vector2(980, 470), 2.25, 0.33, 21.0, false)
		_add_cloud(SHADOW_SMALL, Vector2(1180, 260), 1.95, 0.34, 21.0, false)
		_add_cloud(CLOUD_LARGE, Vector2(220, 60), 2.25, 0.35, 34.0, true)
		_add_cloud(CLOUD_MEDIUM, Vector2(880, 82), 1.95, 0.32, 34.0, true)
		_add_cloud(CLOUD_LARGE, Vector2(540, 668), 2.15, 0.36, 34.0, true)
	elif room_index == 3:
		_add_cloud(SHADOW_LARGE, Vector2(160, 180), 2.65, 0.38, 27.0, false)
		_add_cloud(SHADOW_MEDIUM, Vector2(490, 340), 2.25, 0.44, 27.0, false)
		_add_cloud(SHADOW_LARGE, Vector2(840, 460), 2.45, 0.40, 27.0, false)
		_add_cloud(SHADOW_SMALL, Vector2(1120, 240), 2.05, 0.38, 27.0, false)
		_add_cloud(SHADOW_MEDIUM, Vector2(300, 540), 2.10, 0.36, 27.0, false)
		_add_cloud(CLOUD_LARGE, Vector2(180, 52), 2.35, 0.42, 42.0, true)
		_add_cloud(CLOUD_MEDIUM, Vector2(760, 74), 2.10, 0.38, 42.0, true)
		_add_cloud(CLOUD_LARGE, Vector2(420, 672), 2.30, 0.42, 42.0, true)
		_add_cloud(CLOUD_MEDIUM, Vector2(1040, 650), 2.00, 0.40, 42.0, true)
	else:
		# 第 5、6、7 关：保留柔和克制的地面高空云影，突出仙庭与悬空遗迹的清透感
		var alpha := 0.22 if room_index < 6 else 0.16
		_add_cloud(SHADOW_LARGE, Vector2(300, 230), 2.40, alpha, 16.0, false)
		_add_cloud(SHADOW_MEDIUM, Vector2(890, 470), 2.15, alpha, 16.0, false)

func _seed_motes() -> void:
	motes.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4100 + room_index * 137
	var count := 32 if room_index >= 5 else 28
	for i in range(count):
		motes.append({
			"pos": Vector2(rng.randf_range(30.0, BOUNDS.x - 30.0), rng.randf_range(30.0, BOUNDS.y - 30.0)),
			"speed": rng.randf_range(16.0, 34.0),
			"phase": rng.randf_range(0.0, TAU),
			"size": 3.0 if i % 3 != 0 else 4.0,
			"variant": i % 2,
		})

func _process(delta: float) -> void:
	if not visible or get_tree().paused:
		return
	clock += delta
	for entry in cloud_entries:
		var sprite: Sprite2D = entry.sprite
		if not is_instance_valid(sprite):
			continue
		var margin := sprite.texture.get_width() * sprite.scale.x * 0.5 + WRAP_PADDING
		var span := BOUNDS.x + 2.0 * margin
		var travel := sprite.position.x + margin + float(entry.speed) * delta
		sprite.position.x = fposmod(travel, span) - margin

	var drift_x := 22.0 if room_index <= 2 else (12.0 if room_index <= 4 else 8.0)
	var drift_y := 16.0 if room_index <= 2 else -14.0
	for m in motes:
		var p: Vector2 = m.pos
		var spd: float = m.speed
		var ph: float = m.phase
		p.x += (drift_x + sin(clock * 1.4 + ph) * 9.0) * delta * (spd / 20.0)
		p.y += (drift_y + cos(clock * 1.1 + ph) * 6.0) * delta * (spd / 20.0)
		if p.x > BOUNDS.x + 20.0:
			p.x = -20.0
		elif p.x < -20.0:
			p.x = BOUNDS.x + 20.0
		if p.y > BOUNDS.y + 20.0:
			p.y = -20.0
		elif p.y < -20.0:
			p.y = BOUNDS.y + 20.0
		m.pos = p
	queue_redraw()

func _draw() -> void:
	if not visible:
		return
	# 分房间主题像素微粒：2-3关翻转飘零竹叶/山风微尘，4-5关青白灵尘，6-7关淡金/霜青仙庭流尘
	var col_a: Color
	var col_b: Color
	var is_leaf := room_index <= 2
	if room_index <= 2:
		col_a = Color("76b858")
		col_b = Color("d8c27a")
	elif room_index <= 4:
		col_a = Color("7bf0ec")
		col_b = Color("e0fbff")
	else:
		col_a = Color("ffd97d")
		col_b = Color("7ad8ff")

	for m in motes:
		var pos: Vector2 = (m.pos as Vector2).round()
		var sz: float = m.size
		var pulse := 0.45 + 0.40 * sin(clock * 2.4 + float(m.phase))
		var col := col_a if int(m.variant) == 0 else col_b
		col.a = pulse * (0.82 if is_leaf else 0.72)
		if is_leaf:
			var flip_w := maxf(2.0, absf(cos(clock * 2.8 + float(m.phase))) * (sz + 3.0))
			draw_rect(Rect2(pos, Vector2(flip_w, sz)), col)
			draw_rect(Rect2(pos + Vector2(1.0, 1.0), Vector2(maxf(1.0, flip_w * 0.5), 1.0)), Color(col.lightened(0.3), col.a))
		else:
			draw_rect(Rect2(pos, Vector2(sz, sz)), col)
			if sz >= 4.0:
				draw_rect(Rect2(pos + Vector2(1.0, 1.0), Vector2(2.0, 2.0)), Color(1.0, 1.0, 1.0, col.a * 0.85))

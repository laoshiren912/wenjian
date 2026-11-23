extends Control

# 4 枚无框悬浮 16-bit 像素技能图标（0=左键单剑, 1=右键旋剑, 2=空格穿阵, 3=E四剑阵）
var icon_kind := 0
var key_caption := ""
var rank_stage := 0
var cooldown_left := 0.0
var cooldown_total := 1.0
var insufficient := false
var active_state := false
var casting_caption := ""
var twin_empowered := false
var pulse_age := 1.0
var clock := 0.0

func setup(kind: int, key_label: String) -> void:
	icon_kind = kind
	key_caption = key_label
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(78, 102)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func trigger_pulse() -> void:
	pulse_age = 0.0
	queue_redraw()

func set_state(rank: int, cd_left: float, cd_total: float, no_stamina: bool, is_active: bool, cast_text: String = "", twin: bool = false) -> void:
	rank_stage = clampi(rank, 0, 2)
	cooldown_left = maxf(0.0, cd_left)
	cooldown_total = maxf(0.01, cd_total)
	insufficient = no_stamina
	active_state = is_active
	casting_caption = cast_text
	twin_empowered = twin
	queue_redraw()

func _process(delta: float) -> void:
	clock += delta
	if pulse_age < 1.0:
		pulse_age = minf(1.0, pulse_age + delta * 4.5)
		queue_redraw()
	elif active_state or not casting_caption.is_empty():
		queue_redraw()

func _px(origin: Vector2, gx: int, gy: int, gw: int, gh: int, col: Color) -> void:
	var s := 2.5
	draw_rect(Rect2(origin + Vector2(roundf(gx * s), roundf(gy * s)), Vector2(roundf(gw * s), roundf(gh * s))), col)

func _draw() -> void:
	var font := preload("res://assets/fonts/msyh.ttc")
	var center_x := size.x * 0.5
	var icon_size := 55.0
	var bounce := sin(clampf(pulse_age, 0.0, 1.0) * PI) * 5.0 if pulse_age < 1.0 else 0.0
	var icon_top := 20.0 - bounce
	var origin := Vector2(roundf(center_x - icon_size * 0.5), roundf(icon_top))

	# 顶部轻提示（如 E 键“施法中”）
	if not casting_caption.is_empty():
		var pulse_a := 0.78 + 0.22 * sin(clock * 12.0)
		var c_pos := Vector2(center_x, 15.0)
		var c_size := font.get_string_size(casting_caption, HORIZONTAL_ALIGNMENT_CENTER, -1, 15)
		var draw_p := Vector2(roundf(c_pos.x - c_size.x * 0.5), c_pos.y)
		draw_string_outline(font, draw_p, casting_caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color(0.04, 0.07, 0.10, 0.92 * pulse_a))
		draw_string(font, draw_p, casting_caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.98, 0.92, 0.62, pulse_a))

	# 极淡墨晕托底（无方框边框，仅防浅色玉台融背景）
	var bg_center := origin + Vector2(icon_size * 0.5, icon_size * 0.5)
	draw_circle(bg_center, 27.5, Color(0.05, 0.08, 0.11, 0.30))
	draw_circle(bg_center, 20.0, Color(0.06, 0.10, 0.14, 0.22))

	# 施法/激活/释放瞬间柔光环
	if active_state or pulse_age < 1.0:
		var glow_a := 0.55 * (1.0 - pulse_age) if pulse_age < 1.0 else (0.35 + 0.18 * sin(clock * 10.0))
		var glow_col := Color("6ef2ee") if rank_stage == 1 else (Color("5ad6ff") if rank_stage == 2 else Color("eaf4ff"))
		if twin_empowered or icon_kind == 3:
			glow_col = glow_col.lerp(Color("ffe07d"), 0.35)
		draw_arc(bg_center, 26.5 + bounce * 0.5, 0.0, TAU, 28, Color(glow_col, glow_a), 2.4, false)

	# 主色与高光色随三阶段修为轻度呼应
	var col_main := Color("dce9f5") if rank_stage == 0 else (Color("66f0e8") if rank_stage == 1 else Color("58d6ff"))
	var col_core := Color("ffffff")
	var col_gold := Color("f0cb72")
	var col_outline := Color("111b24")

	var dimmed := (cooldown_left > 0.05) or insufficient
	var alpha := 0.42 if dimmed else 0.98
	if insufficient and cooldown_left <= 0.05:
		col_main = col_main.lerp(Color("8a96a0"), 0.55)
		col_core = col_core.lerp(Color("a8b2ba"), 0.45)

	var c_main := Color(col_main, alpha)
	var c_core := Color(col_core, alpha)
	var c_gold := Color(col_gold, alpha)
	var c_out := Color(col_outline, alpha * 0.92)

	# 绘制 22x22 逻辑网格 16-bit 像素图标
	match icon_kind:
		0:
			# 左键：斜向锐利单剑
			for i in range(12):
				_px(origin, 16 - i, 4 + i, 2, 2, c_out)
				_px(origin, 17 - i, 4 + i, 1, 1, c_core)
				_px(origin, 16 - i, 5 + i, 1, 1, c_main)
			_px(origin, 17, 3, 2, 2, c_core)
			# 鎏金护手与剑柄
			_px(origin, 4, 13, 5, 1, c_gold)
			_px(origin, 7, 14, 1, 4, c_gold)
			_px(origin, 3, 17, 2, 2, c_gold)
			_px(origin, 4, 16, 2, 2, c_out)
			# 锐利斜锋弧点
			_px(origin, 11, 3, 4, 1, c_main)
			_px(origin, 18, 8, 1, 4, c_main)
		1:
			# 右键：旋剑剑轮
			var ring_col := c_gold if twin_empowered else c_main
			draw_arc(bg_center, 19.0, -2.5, -0.3, 16, ring_col, 3.0, false)
			draw_arc(bg_center, 19.0, 0.6, 2.8, 16, c_main, 3.0, false)
			draw_arc(bg_center, 14.0, -2.2, -0.6, 12, c_core, 2.0, false)
			draw_arc(bg_center, 14.0, 0.9, 2.5, 12, c_core, 2.0, false)
			# 中心斜刃
			for i in range(8):
				_px(origin, 14 - i, 7 + i, 2, 1, c_core)
			_px(origin, 9, 12, 3, 1, c_gold)
			_px(origin, 10, 11, 1, 3, c_gold)
		2:
			# 空格：穿阵疾风残影
			# 左侧三道疾风残影条
			_px(origin, 2, 7, 7, 1, Color(c_main, alpha * 0.72))
			_px(origin, 1, 11, 9, 2, c_main)
			_px(origin, 3, 15, 6, 1, Color(c_main, alpha * 0.72))
			# 右侧前冲像素箭锋/人影剪影
			_px(origin, 12, 5, 3, 2, c_core)
			_px(origin, 11, 8, 5, 3, c_main)
			_px(origin, 13, 11, 6, 2, c_core)
			_px(origin, 11, 14, 4, 3, c_main)
			_px(origin, 18, 10, 2, 2, c_core)
			_px(origin, 19, 11, 1, 1, c_gold)
		3:
			# E：四剑阵（万剑归宗）
			var xs := [4, 8, 12, 16]
			var ys := [6, 3, 4, 7]
			for idx in range(4):
				var gx: int = xs[idx]
				var gy: int = ys[idx]
				_px(origin, gx, gy, 2, 9, c_out)
				_px(origin, gx, gy + 1, 1, 8, c_main)
				_px(origin, gx + 1, gy, 1, 7, c_core)
				_px(origin, gx - 1, gy + 8, 4, 1, c_gold)
				_px(origin, gx, gy + 9, 2, 2, c_gold)
			# 下方微弧法诀线
			draw_arc(bg_center + Vector2(0, 12.5), 17.5, 0.35, PI - 0.35, 16, Color(c_gold, alpha * 0.75), 1.8, false)

	# 冷却暗色圆晕扇形遮罩与剩余秒数（保持无方框剪影）
	if cooldown_left > 0.05:
		var frac := clampf(cooldown_left / cooldown_total, 0.0, 1.0)
		draw_circle(bg_center, 25.5, Color(0.03, 0.05, 0.08, 0.42))
		var steps := maxi(4, int(ceilf(28.0 * frac)))
		var sweep_pts := PackedVector2Array([bg_center])
		var start_a := -PI * 0.5
		for s in range(steps + 1):
			var a := start_a + TAU * frac * (float(s) / float(steps))
			sweep_pts.append(bg_center + Vector2(cos(a), sin(a)) * 25.5)
		if sweep_pts.size() >= 3:
			draw_colored_polygon(sweep_pts, Color(0.02, 0.04, 0.07, 0.46))
		draw_arc(bg_center, 25.5, start_a, start_a + TAU * frac, steps + 2, Color(0.62, 0.78, 0.84, 0.58), 1.8, false)
		var cd_str := "%.1f" % cooldown_left
		var t_sz := font.get_string_size(cd_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 20)
		var tp := Vector2(roundf(bg_center.x - t_sz.x * 0.5), roundf(bg_center.y + 7.5))
		draw_string_outline(font, tp, cd_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 5, Color(0.03, 0.05, 0.08, 0.95))
		draw_string(font, tp, cd_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("f6f9fb"))

	# 底部中文键位标注（绝不使用英文缩写）
	var key_col := Color("d29c9c") if (insufficient and cooldown_left <= 0.05) else (Color("9aa9b2") if cooldown_left > 0.05 else Color("eef4f2"))
	var k_sz := font.get_string_size(key_caption, HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
	var kp := Vector2(roundf(center_x - k_sz.x * 0.5), 95.0)
	draw_string_outline(font, kp, key_caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color(0.04, 0.07, 0.10, 0.95))
	draw_string(font, kp, key_caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, key_col)

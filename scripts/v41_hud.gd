extends "res://scripts/combo_hud.gd"

signal reward_selected(index: int)
signal title_start_requested
signal title_mute_requested
const CONFIG = preload("res://scripts/v41_config.gd")
const SkillSlot = preload("res://scripts/v41_skill_slot.gd")
const TITLE_FADE_DURATION := 0.35

var run
var gm_scroll: ScrollContainer

# 无框水墨暗金开局标题画面节点
var title_layer: Control
var title_art: Control
var title_center_box: VBoxContainer
var title_main_label: Label
var title_divider: Control
var title_btn_spacer: Control
var title_start_btn: Button
var title_mute_btn: Button
var title_controls_label: Label
var _title_active := false
var _title_fading_out := false
var _title_fade_elapsed := 0.0

# 无框极简仙侠 HUD 节点
var minimal_layer: Control
var vitals_box: VBoxContainer
var top_center_box: VBoxContainer
var top_right_box: HBoxContainer
var bottom_skills_box: HBoxContainer
var hp_bar_slim: ProgressBar
var hp_val_label: Label
var hp_title_label: Label
var sp_bar_slim: ProgressBar
var sp_val_label: Label
var cult_title_label: Label
var cult_bar_slim: ProgressBar
var cult_label: Label
var room_title_label: Label
var divider_line: Control
var room_sub_label: Label
var boss_bar_row: HBoxContainer
var boss_name_label: Label
var boss_hp_bar: ProgressBar
var boss_hp_val: Label
var boss_break_label: Label
var minimal_notice: Label
var banner_fx: Control
var skill_slots: Array[Control] = []

var _hud_clock := 0.0
var _last_cultivation := -1
var _cult_flash := 0.0
var _last_attack_count := 0
var _was_dashing := false
var _was_throwing := false
var _was_raining := false
var _boss_break_flash := 0.0
var _last_boss_hp := -1.0

class InkBackdrop extends Control:
	var mode := 0 # 0 = 顶部轻墨晕与云纹线, 1 = 细云纹分割线
	func _draw() -> void:
		if mode == 1:
			var y := size.y * 0.5
			var cx := size.x * 0.5
			var half := minf(size.x * 0.46, 106.0)
			# 深墨底层描边 + 淡金宣纸细线 + 中央菱形云纹点缀
			draw_line(Vector2(cx - half, y), Vector2(cx - 12.0, y), Color(0.05, 0.08, 0.11, 0.76), 3.4, false)
			draw_line(Vector2(cx + 12.0, y), Vector2(cx + half, y), Color(0.05, 0.08, 0.11, 0.76), 3.4, false)
			draw_line(Vector2(cx - half + 2.0, y), Vector2(cx - 12.0, y), Color(0.86, 0.80, 0.62, 0.88), 1.2, false)
			draw_line(Vector2(cx + 12.0, y), Vector2(cx + half - 2.0, y), Color(0.86, 0.80, 0.62, 0.88), 1.2, false)
			var pts := PackedVector2Array([
				Vector2(cx, y - 4.2), Vector2(cx + 6.0, y),
				Vector2(cx, y + 4.2), Vector2(cx - 6.0, y),
			])
			draw_colored_polygon(pts, Color(0.05, 0.08, 0.11, 0.84))
			draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.92, 0.84, 0.62, 0.92), 1.4, false)
			draw_rect(Rect2(Vector2(cx - 1.5, y - 1.5), Vector2(3.0, 3.0)), Color("f6eed4"))
		elif mode == 2:
			# 标题专用：加宽古风细云纹暗金分割线（主线 + 两侧细回纹 + 中心玉金菱印）
			var y := size.y * 0.5
			var cx := size.x * 0.5
			var half := minf(size.x * 0.48, 142.0)
			draw_line(Vector2(cx - half, y), Vector2(cx - 15.0, y), Color(0.03, 0.05, 0.08, 0.84), 4.0, false)
			draw_line(Vector2(cx + 15.0, y), Vector2(cx + half, y), Color(0.03, 0.05, 0.08, 0.84), 4.0, false)
			draw_line(Vector2(cx - half + 2.0, y), Vector2(cx - 15.0, y), Color(0.92, 0.80, 0.48, 0.94), 1.5, false)
			draw_line(Vector2(cx + 15.0, y), Vector2(cx + half - 2.0, y), Color(0.92, 0.80, 0.48, 0.94), 1.5, false)
			for side in [-1.0, 1.0]:
				var s: float = float(side)
				var tip_x: float = cx + s * (half + 4.0)
				var curl := PackedVector2Array([
					Vector2(tip_x - s * 4.0, y),
					Vector2(tip_x, y - 3.0),
					Vector2(tip_x + s * 4.0, y),
					Vector2(tip_x, y + 3.0),
				])
				draw_colored_polygon(curl, Color(0.94, 0.82, 0.50, 0.90))
			var pts := PackedVector2Array([
				Vector2(cx, y - 5.5), Vector2(cx + 8.0, y),
				Vector2(cx, y + 5.5), Vector2(cx - 8.0, y),
			])
			draw_colored_polygon(pts, Color(0.04, 0.06, 0.10, 0.90))
			draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.96, 0.86, 0.54, 0.96), 1.6, false)
			draw_rect(Rect2(Vector2(cx - 2.0, y - 2.0), Vector2(4.0, 4.0)), Color("fff4cf"))

class TitleArtOverlay extends Control:
	var clock := 0.0
	var title_ref: Control
	var controls_ref: Control

	func _process(delta: float) -> void:
		if not visible:
			return
		clock += delta
		queue_redraw()

	func _draw() -> void:
		if not visible or size.x < 10.0 or size.y < 10.0:
			return
		var cx := size.x * 0.5
		var compact := size.x < 1100.0 or size.y < 620.0

		# 1. 极轻上下边缘水墨暗角（保持竹林与山门中景完全通透）
		var edge_h := 54.0 if compact else 72.0
		var steps := 6
		for i in range(steps):
			var frac := float(i) / float(steps)
			var next_frac := float(i + 1) / float(steps)
			var band_h := edge_h * (next_frac - frac)
			var a := pow(1.0 - frac, 1.8) * 0.24
			draw_rect(Rect2(0.0, edge_h * frac, size.x, band_h + 1.0), Color(0.02, 0.04, 0.07, a))
			draw_rect(Rect2(0.0, size.y - edge_h * next_frac, size.x, band_h + 1.0), Color(0.02, 0.04, 0.07, a * 1.15))

		# 2. 主标题背后柔滑椭圆水墨晕染（彻底无矩形边缘，仅柔和托出暗金字迹对比度）
		var title_cy := (84.0 if compact else 118.0)
		var title_w := (170.0 if compact else 220.0)
		if is_instance_valid(title_ref) and title_ref.size.x > 10.0:
			var r := title_ref.get_global_rect()
			var local_center := r.get_center() - global_position
			title_cy = local_center.y
			title_w = maxf(title_w, r.size.x * 0.90)
		var pulse := 0.82 + 0.18 * sin(clock * 1.9)
		draw_set_transform(Vector2(cx, title_cy), 0.0, Vector2(1.0, 0.34))
		for seg in range(7):
			var frac := float(seg) / 7.0
			var rad := title_w * lerpf(1.38, 0.42, frac)
			var sa := lerpf(0.022, 0.068, frac)
			draw_circle(Vector2.ZERO, rad, Color(0.02, 0.04, 0.07, sa))
		# 主标题后极淡暖金灵气微晕
		draw_circle(Vector2.ZERO, title_w * 0.86, Color(0.95, 0.82, 0.48, 0.055 * pulse))
		draw_circle(Vector2.ZERO, title_w * 0.48, Color(1.0, 0.90, 0.58, 0.050 * pulse))
		draw_set_transform(Vector2.ZERO)

		# 3. 题字右侧一枚精致朱砂小印（「剑」印，凸显国风仙侠气息）
		if is_instance_valid(title_ref) and title_ref.size.x > 10.0:
			var tr := title_ref.get_global_rect()
			var seal_sz := 16.0 if compact else 20.0
			var sx := (tr.position.x + tr.size.x - global_position.x) + (8.0 if compact else 12.0)
			var sy := (tr.position.y + tr.size.y - global_position.y) - seal_sz - (8.0 if compact else 12.0)
			var seal_rect := Rect2(sx, sy, seal_sz, seal_sz)
			draw_rect(seal_rect.grow(1.5), Color(0.03, 0.04, 0.06, 0.78))
			draw_rect(seal_rect, Color(0.72, 0.18, 0.15, 0.92))
			draw_rect(seal_rect, Color(0.96, 0.78, 0.64, 0.55), false, 1.0)
			var font := ThemeDB.fallback_font
			var fsz := 10 if compact else 12
			var gdim := font.get_string_size("剑", HORIZONTAL_ALIGNMENT_CENTER, -1, fsz)
			var gp := Vector2(roundf(sx + (seal_sz - gdim.x) * 0.5), roundf(sy + seal_sz * 0.76))
			draw_string(font, gp, "剑", HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, Color("f8eee2"))

		# 4. 漂浮在标题四周的细碎金色灵尘
		for i in range(10):
			var phase := float(i) * 1.17 + clock * (0.45 + float(i % 3) * 0.14)
			var px := cx + sin(phase * 0.78 + float(i)) * (title_w * 1.15)
			var py := title_cy + cos(phase * 0.95 + float(i) * 0.7) * (36.0 if compact else 48.0) - 6.0
			var pa := (0.28 + 0.36 * (0.5 + 0.5 * sin(phase * 1.8))) * pulse
			var dot_sz := 2.5 if i % 3 == 0 else 2.0
			draw_rect(Rect2(roundf(px), roundf(py), dot_sz, dot_sz), Color(0.98, 0.88, 0.56, pa))

		# 5. 底部操作指南背后的极淡椭圆墨晕（无硬框边缘，确保浅色地面可读）
		if is_instance_valid(controls_ref) and controls_ref.size.x > 10.0:
			var cr := controls_ref.get_global_rect()
			var cc := cr.get_center() - global_position
			var cw := cr.size.x * 0.58 + 26.0
			draw_set_transform(cc, 0.0, Vector2(1.0, 0.11))
			for seg in range(4):
				var rad := cw * lerpf(1.18, 0.62, float(seg) / 4.0)
				draw_circle(Vector2.ZERO, rad, Color(0.02, 0.04, 0.07, 0.065 + float(seg) * 0.032))
			draw_set_transform(Vector2.ZERO)

class ScreenBannerFX extends Control:
	var active := false
	var age := 0.0
	var duration := 1.15
	var title := ""
	var subtitle := ""
	var primary := Color("6ef4ec")
	var secondary := Color("ffe278")
	var edge_alpha := 0.22

	func trigger(t_text: String, s_text: String, col_a: Color, col_b: Color, dur: float, e_alpha: float) -> void:
		title = t_text
		subtitle = s_text
		primary = col_a
		secondary = col_b
		duration = maxf(0.2, dur)
		edge_alpha = e_alpha
		age = 0.0
		active = true
		visible = true
		queue_redraw()

	func clear() -> void:
		active = false
		age = 0.0
		visible = false
		queue_redraw()

	func _process(delta: float) -> void:
		if not active:
			return
		age += delta
		if age >= duration:
			clear()
		else:
			queue_redraw()

	func _draw() -> void:
		if not active or size.x < 10.0 or size.y < 10.0:
			return
		var t := clampf(age / duration, 0.0, 1.0)
		var fade_in := clampf(t / 0.14, 0.0, 1.0)
		var fade_out := clampf((1.0 - t) / 0.28, 0.0, 1.0)
		var alpha := fade_in * fade_out
		var pulse := 0.78 + 0.22 * sin(age * 9.5)

		# 1. 屏幕四周克制呼吸流光（分层渐隐边缘晕带，绝不糊中间画面）
		var e_a := edge_alpha * alpha * pulse
		var layers := 4
		var max_band := 22.0
		for i in range(layers):
			var frac := float(i) / float(layers)
			var next_frac := float(i + 1) / float(layers)
			var thick := max_band * (next_frac - frac)
			var inset := max_band * frac
			var la := e_a * pow(1.0 - frac, 1.65)
			var col := primary.lerp(secondary, frac * 0.55)
			var c := Color(col, la)
			draw_rect(Rect2(inset, inset, size.x - inset * 2.0, thick), c)
			draw_rect(Rect2(inset, size.y - inset - thick, size.x - inset * 2.0, thick), c)
			draw_rect(Rect2(inset, inset + thick, thick, size.y - (inset + thick) * 2.0), c)
			draw_rect(Rect2(size.x - inset - thick, inset + thick, thick, size.y - (inset + thick) * 2.0), c)

		# 2. 屏幕中上方仙侠浮字横幅（避开顶部关名与中央角色区）
		var cx := size.x * 0.5
		var cy := size.y * 0.255 + lerpf(8.0, 0.0, fade_in)
		var half_w := minf(size.x * 0.26, 228.0) * lerpf(0.86, 1.0, fade_in)
		var band_h := 66.0

		# 轻薄渐隐墨带托底（确保第 7 关浅色云海清晰可读，又无厚重黑框）
		for seg in range(5):
			var sw := half_w * (1.0 - float(seg) * 0.14)
			var sa := alpha * (0.10 + 0.07 * float(seg))
			draw_rect(Rect2(cx - sw, cy - band_h * 0.5, sw * 2.0, band_h), Color(0.03, 0.06, 0.10, sa))

		# 上下细金云纹线与菱形微缀
		var top_y := cy - band_h * 0.5 + 3.0
		var bot_y := cy + band_h * 0.5 - 3.0
		draw_line(Vector2(cx - half_w, top_y), Vector2(cx + half_w, top_y), Color(0.03, 0.06, 0.10, 0.72 * alpha), 3.0, false)
		draw_line(Vector2(cx - half_w * 0.92, top_y), Vector2(cx + half_w * 0.92, top_y), Color(primary, 0.88 * alpha), 1.4, false)
		draw_line(Vector2(cx - half_w * 0.78, bot_y), Vector2(cx + half_w * 0.78, bot_y), Color(0.03, 0.06, 0.10, 0.65 * alpha), 2.5, false)
		draw_line(Vector2(cx - half_w * 0.72, bot_y), Vector2(cx + half_w * 0.72, bot_y), Color(secondary, 0.76 * alpha), 1.2, false)
		for side in [-1.0, 1.0]:
			var dx: float = cx + float(side) * (half_w * 0.92 + 5.0)
			var pts := PackedVector2Array([
				Vector2(dx, top_y - 3.5), Vector2(dx + 4.5, top_y),
				Vector2(dx, top_y + 3.5), Vector2(dx - 4.5, top_y),
			])
			draw_colored_polygon(pts, Color(secondary, 0.92 * alpha))

		# 短促横向光扫动画（0.10..0.54 期间横掠横幅）
		if t >= 0.10 and t <= 0.56:
			var st := (t - 0.10) / 0.46
			var sx := lerpf(cx - half_w * 0.95, cx + half_w * 0.95, st)
			var sa := sin(st * PI) * 0.52 * alpha
			var sweep_poly := PackedVector2Array([
				Vector2(sx - 26.0, bot_y - 2.0), Vector2(sx + 6.0, bot_y - 2.0),
				Vector2(sx + 26.0, top_y + 2.0), Vector2(sx - 6.0, top_y + 2.0),
			])
			draw_colored_polygon(sweep_poly, Color(1.0, 0.98, 0.88, sa))

		# 大号主标题 + 副行仙侠小字（深墨厚描边）
		var font := ThemeDB.fallback_font
		var title_sz := 32 if size.x >= 1100.0 else 27
		var t_dim := font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, title_sz)
		var tp := Vector2(roundf(cx - t_dim.x * 0.5), roundf(cy + 4.0))
		draw_string_outline(font, tp, title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_sz, 6, Color(0.03, 0.05, 0.09, 0.95 * alpha))
		draw_string(font, tp, title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_sz, Color(primary.lerp(Color("ffffff"), 0.35), alpha))

		if not subtitle.is_empty():
			var sub_sz := 16 if size.x >= 1100.0 else 14
			var s_dim := font.get_string_size(subtitle, HORIZONTAL_ALIGNMENT_CENTER, -1, sub_sz)
			var sp := Vector2(roundf(cx - s_dim.x * 0.5), roundf(cy + 24.0))
			draw_string_outline(font, sp, subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_sz, 4, Color(0.03, 0.05, 0.09, 0.92 * alpha))
			draw_string(font, sp, subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_sz, Color(secondary.lerp(Color("f4f8f6"), 0.45), alpha * 0.95))

func _resize_modal() -> void:
	super._resize_modal()
	if is_instance_valid(gm_scroll) and is_instance_valid(modal_panel) and gm_scroll.get_parent().get_parent() == modal_panel:
		gm_scroll.custom_minimum_size.y = maxf(0.0, minf(440.0, root.size.y - 180.0))
	_layout_title_screen()

func _ink_label(text: String, font_size: int, color: Color = Color("f2f6f4"), outline_px: int = 4) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.07, 0.10, 0.94))
	lbl.add_theme_constant_override("outline_size", outline_px)
	lbl.add_theme_color_override("font_shadow_color", Color(0.02, 0.04, 0.06, 0.55))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	return lbl

func _slim_bar(fill_color: Color, width: float, height: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(width, height)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.08, 0.11, 0.66)
	bg.border_color = Color(0.03, 0.05, 0.08, 0.94)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(1)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.border_color = Color(0.03, 0.05, 0.08, 0.0)
	fill.set_border_width_all(1)
	fill.set_corner_radius_all(1)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	return bar

func _ghost_button(text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(70, 34)
	btn.add_theme_font_size_override("font_size", 17)
	btn.add_theme_color_override("font_color", Color("ecf3f1"))
	btn.add_theme_color_override("font_hover_color", Color("ffffff"))
	btn.add_theme_color_override("font_outline_color", Color(0.04, 0.07, 0.10, 0.94))
	btn.add_theme_constant_override("outline_size", 4)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.06, 0.10, 0.14, 0.36)
	normal.border_color = Color(0.74, 0.84, 0.86, 0.26)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(3)
	normal.content_margin_left = 12.0
	normal.content_margin_right = 12.0
	normal.content_margin_top = 4.0
	normal.content_margin_bottom = 4.0
	var hover := normal.duplicate()
	hover.bg_color = Color(0.12, 0.20, 0.25, 0.62)
	hover.border_color = Color(0.45, 0.88, 0.92, 0.78)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.16, 0.28, 0.32, 0.78)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.pressed.connect(callback)
	return btn

func _ready() -> void:
	super._ready()
	# 隐藏旧版厚框 HUD 容器，但保留 hurt_flash / overlay / 弹窗机制兼容
	if root.get_child_count() > 0:
		root.get_child(0).hide()
	combat_panels.clear()

	minimal_layer = Control.new()
	minimal_layer.name = "MinimalXianxiaHUD"
	PrototypeUI.fill(minimal_layer)
	minimal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(minimal_layer)
	root.move_child(minimal_layer, 1)

	# === 顶部独立三栏锚点布局（彻底解耦，确保中轴严格 50% 对齐、右侧绝不裁切）===
	# 1. 左上角：独立锚定 PRESET_TOP_LEFT
	vitals_box = PrototypeUI.column(5)
	vitals_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitals_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	vitals_box.offset_left = 20.0
	vitals_box.offset_top = 14.0
	minimal_layer.add_child(vitals_box)
	combat_panels.append(vitals_box)

	var hp_row := HBoxContainer.new()
	hp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_row.add_theme_constant_override("separation", 8)
	vitals_box.add_child(hp_row)
	hp_title_label = _ink_label("生命", 16, Color("f2d8d8"), 4)
	hp_row.add_child(hp_title_label)
	hp_bar_slim = _slim_bar(Color("d95353"), 168.0, 10.0)
	hp_row.add_child(hp_bar_slim)
	hp_val_label = _ink_label("100/100", 16, Color("f4f6f5"), 4)
	hp_row.add_child(hp_val_label)

	var sp_row := HBoxContainer.new()
	sp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sp_row.add_theme_constant_override("separation", 8)
	vitals_box.add_child(sp_row)
	sp_row.add_child(_ink_label("体力", 16, Color("d4f2f0"), 4))
	sp_bar_slim = _slim_bar(Color("5fd8d4"), 168.0, 9.0)
	sp_row.add_child(sp_bar_slim)
	sp_val_label = _ink_label("100/100", 16, Color("dff4f2"), 4)
	sp_row.add_child(sp_val_label)

	var cult_row := HBoxContainer.new()
	cult_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cult_row.add_theme_constant_override("separation", 8)
	vitals_box.add_child(cult_row)
	cult_title_label = _ink_label("修为", 16, Color("f4e4b4"), 4)
	cult_row.add_child(cult_title_label)
	cult_bar_slim = _slim_bar(Color("e6c15a"), 168.0, 9.0)
	cult_row.add_child(cult_bar_slim)
	cult_label = _ink_label("凡剑期 0/8", 15, Color("f0e2b6"), 4)
	cult_row.add_child(cult_label)

	# 2. 顶部居中：独立锚定 PRESET_CENTER_TOP（水平绝对居中于视口 50%）
	top_center_box = PrototypeUI.column(3)
	top_center_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_center_box.anchor_left = 0.5
	top_center_box.anchor_right = 0.5
	top_center_box.anchor_top = 0.0
	top_center_box.anchor_bottom = 0.0
	top_center_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top_center_box.grow_vertical = Control.GROW_DIRECTION_END
	top_center_box.offset_top = 12.0
	minimal_layer.add_child(top_center_box)
	combat_panels.append(top_center_box)

	room_title_label = _ink_label("山门竹林", 26, Color("f6f8f5"), 5)
	room_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_center_box.add_child(room_title_label)

	var div := InkBackdrop.new()
	div.mode = 1
	div.mouse_filter = Control.MOUSE_FILTER_IGNORE
	div.custom_minimum_size = Vector2(220, 10)
	div.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	divider_line = div
	top_center_box.add_child(divider_line)

	room_sub_label = _ink_label("第 1 关 / 共七关  ·  剩余敌人 4", 17, Color("e6efe9"), 4)
	room_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_center_box.add_child(room_sub_label)

	boss_bar_row = HBoxContainer.new()
	boss_bar_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_bar_row.alignment = BoxContainer.ALIGNMENT_CENTER
	boss_bar_row.add_theme_constant_override("separation", 9)
	boss_bar_row.visible = false
	top_center_box.add_child(boss_bar_row)
	boss_name_label = _ink_label(CONFIG.BOSS_NAME, 19, Color("ffe2a8"), 5)
	boss_bar_row.add_child(boss_name_label)
	boss_hp_bar = _slim_bar(Color("d64c3e"), 280.0, 12.0)
	boss_bar_row.add_child(boss_hp_bar)
	boss_hp_val = _ink_label("3200/3200", 16, Color("f8eee2"), 4)
	boss_bar_row.add_child(boss_hp_val)
	boss_break_label = _ink_label("破防", 17, Color("ffd966"), 4)
	boss_break_label.visible = false
	boss_bar_row.add_child(boss_break_label)

	# 3. 右上角：独立锚定 PRESET_TOP_RIGHT（距离右边缘严格保持 22px 安全边距）
	top_right_box = HBoxContainer.new()
	top_right_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_right_box.alignment = BoxContainer.ALIGNMENT_END
	top_right_box.add_theme_constant_override("separation", 10)
	top_right_box.anchor_left = 1.0
	top_right_box.anchor_right = 1.0
	top_right_box.anchor_top = 0.0
	top_right_box.anchor_bottom = 0.0
	top_right_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	top_right_box.grow_vertical = Control.GROW_DIRECTION_END
	top_right_box.offset_right = -22.0
	top_right_box.offset_top = 14.0
	minimal_layer.add_child(top_right_box)
	combat_panels.append(top_right_box)

	top_right_box.add_child(_ghost_button("属性", func(): stats_requested.emit()))
	top_right_box.add_child(_ghost_button("暂停", func(): pause_requested.emit()))

	# === 底部居中：独立锚定 PRESET_CENTER_BOTTOM ===
	var bottom_col := PrototypeUI.column(4)
	bottom_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_col.anchor_left = 0.5
	bottom_col.anchor_right = 0.5
	bottom_col.anchor_top = 1.0
	bottom_col.anchor_bottom = 1.0
	bottom_col.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom_col.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom_col.offset_bottom = -10.0
	minimal_layer.add_child(bottom_col)

	minimal_notice = _ink_label("", 19, Color("ffe8a3"), 4)
	minimal_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	minimal_notice.custom_minimum_size.y = 26.0
	bottom_col.add_child(minimal_notice)

	bottom_skills_box = HBoxContainer.new()
	bottom_skills_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_skills_box.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_skills_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bottom_skills_box.add_theme_constant_override("separation", 26)
	bottom_col.add_child(bottom_skills_box)
	combat_panels.append(bottom_skills_box)

	var slot_keys := ["左键", "右键", "空格", "E"]
	for i in range(slot_keys.size()):
		var slot: Control = SkillSlot.new()
		slot.setup(i, slot_keys[i])
		bottom_skills_box.add_child(slot)
		skill_slots.append(slot)

	# 屏幕级破境/清场仪式演出覆层（非交互、不加入 combat_panels）
	banner_fx = ScreenBannerFX.new()
	banner_fx.name = "ScreenBannerFX"
	banner_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_fx.visible = false
	PrototypeUI.fill(banner_fx)
	root.add_child(banner_fx)

	# 无框水墨暗金开局标题画面（不加入 combat_panels，默认隐藏，由 run.phase == "title" 激活）
	_build_title_screen()

	# 确保全屏红闪与遮罩弹窗始终位于最顶层
	root.move_child(title_layer, root.get_child_count() - 4)
	root.move_child(banner_fx, root.get_child_count() - 3)
	root.move_child(hurt_flash, root.get_child_count() - 2)
	root.move_child(overlay, root.get_child_count() - 1)

func _build_title_screen() -> void:
	title_layer = Control.new()
	title_layer.name = "TitleScreenLayer"
	PrototypeUI.fill(title_layer)
	title_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_layer.visible = false
	root.add_child(title_layer)

	var art := TitleArtOverlay.new()
	art.name = "TitleArtOverlay"
	PrototypeUI.fill(art)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_layer.add_child(art)
	title_art = art

	# 1. 屏幕中上方偏中：大号主标题 + 细云纹线 + 副标题 + 古风暗金细边按钮
	title_center_box = PrototypeUI.column(6)
	title_center_box.name = "TitleCenterBox"
	title_center_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_center_box.anchor_left = 0.5
	title_center_box.anchor_right = 0.5
	title_center_box.anchor_top = 0.0
	title_center_box.anchor_bottom = 0.0
	title_center_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title_center_box.grow_vertical = Control.GROW_DIRECTION_END
	title_center_box.offset_top = 64.0
	title_layer.add_child(title_center_box)

	title_main_label = Label.new()
	title_main_label.text = "问 剑"
	title_main_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_main_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	title_main_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_main_label.add_theme_font_size_override("font_size", 76)
	title_main_label.add_theme_color_override("font_color", Color("f6dfa2"))
	title_main_label.add_theme_color_override("font_outline_color", Color(0.03, 0.05, 0.09, 0.96))
	title_main_label.add_theme_constant_override("outline_size", 10)
	title_main_label.add_theme_color_override("font_shadow_color", Color(0.01, 0.03, 0.06, 0.82))
	title_main_label.add_theme_constant_override("shadow_offset_x", 2)
	title_main_label.add_theme_constant_override("shadow_offset_y", 4)
	title_center_box.add_child(title_main_label)
	art.title_ref = title_main_label

	var tdiv := InkBackdrop.new()
	tdiv.mode = 2
	tdiv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tdiv.custom_minimum_size = Vector2(300, 18)
	tdiv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	title_divider = tdiv
	title_center_box.add_child(title_divider)

	title_btn_spacer = Control.new()
	title_btn_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_btn_spacer.custom_minimum_size = Vector2(0, 26)
	title_center_box.add_child(title_btn_spacer)

	title_start_btn = Button.new()
	title_start_btn.name = "TitleStartButton"
	title_start_btn.text = "踏入仙途"
	title_start_btn.focus_mode = Control.FOCUS_NONE
	title_start_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	title_start_btn.custom_minimum_size = Vector2(214, 48)
	title_start_btn.add_theme_font_size_override("font_size", 22)
	title_start_btn.add_theme_color_override("font_color", Color("f7e6b8"))
	title_start_btn.add_theme_color_override("font_hover_color", Color("fff9e2"))
	title_start_btn.add_theme_color_override("font_pressed_color", Color("ffffff"))
	title_start_btn.add_theme_color_override("font_outline_color", Color(0.03, 0.05, 0.09, 0.96))
	title_start_btn.add_theme_constant_override("outline_size", 4)
	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.05, 0.08, 0.11, 0.62)
	btn_normal.border_color = Color(0.84, 0.71, 0.40, 0.88)
	btn_normal.set_border_width_all(1)
	btn_normal.set_corner_radius_all(2)
	btn_normal.shadow_color = Color(0.01, 0.03, 0.06, 0.45)
	btn_normal.shadow_size = 4
	btn_normal.content_margin_left = 26.0
	btn_normal.content_margin_right = 26.0
	btn_normal.content_margin_top = 8.0
	btn_normal.content_margin_bottom = 8.0
	var btn_hover := btn_normal.duplicate()
	btn_hover.bg_color = Color(0.11, 0.14, 0.16, 0.78)
	btn_hover.border_color = Color(1.0, 0.90, 0.56, 1.0)
	btn_hover.set_border_width_all(2)
	btn_hover.shadow_color = Color(0.96, 0.82, 0.40, 0.42)
	btn_hover.shadow_size = 8
	var btn_pressed := btn_hover.duplicate()
	btn_pressed.bg_color = Color(0.16, 0.20, 0.21, 0.88)
	btn_pressed.shadow_size = 4
	title_start_btn.add_theme_stylebox_override("normal", btn_normal)
	title_start_btn.add_theme_stylebox_override("hover", btn_hover)
	title_start_btn.add_theme_stylebox_override("pressed", btn_pressed)
	title_start_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	title_start_btn.pressed.connect(func(): title_start_requested.emit())
	title_center_box.add_child(title_start_btn)

	# 2. 右上角：极低调静音开关（与 M 键双向同步）
	title_mute_btn = _ghost_button("声音：开 [M]", func(): title_mute_requested.emit())
	title_mute_btn.name = "TitleMuteButton"
	title_mute_btn.custom_minimum_size = Vector2(106, 32)
	title_mute_btn.add_theme_font_size_override("font_size", 14)
	title_mute_btn.add_theme_color_override("font_color", Color("dfe7e2"))
	title_mute_btn.anchor_left = 1.0
	title_mute_btn.anchor_right = 1.0
	title_mute_btn.anchor_top = 0.0
	title_mute_btn.anchor_bottom = 0.0
	title_mute_btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	title_mute_btn.grow_vertical = Control.GROW_DIRECTION_END
	title_mute_btn.offset_right = -22.0
	title_mute_btn.offset_top = 18.0
	title_layer.add_child(title_mute_btn)

	# 3. 屏幕底部居中：一行带深墨描边的清晰操作指南
	title_controls_label = _ink_label("左键三连 · 右键旋斩 · 空格穿阵 · E万剑归宗", 17, Color("eef2ec"), 5)
	title_controls_label.name = "TitleControlsLabel"
	title_controls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_controls_label.anchor_left = 0.5
	title_controls_label.anchor_right = 0.5
	title_controls_label.anchor_top = 1.0
	title_controls_label.anchor_bottom = 1.0
	title_controls_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title_controls_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	title_controls_label.offset_bottom = -20.0
	title_layer.add_child(title_controls_label)
	art.controls_ref = title_controls_label

	_layout_title_screen()

func _layout_title_screen() -> void:
	if not is_instance_valid(title_layer) or not is_instance_valid(root):
		return
	var compact := root.size.x < 1100.0 or root.size.y < 620.0
	title_center_box.offset_top = 48.0 if compact else 76.0
	title_main_label.add_theme_font_size_override("font_size", 60 if compact else 78)
	title_main_label.add_theme_constant_override("outline_size", 8 if compact else 10)
	title_divider.custom_minimum_size = Vector2(236, 14) if compact else Vector2(300, 18)
	title_btn_spacer.custom_minimum_size = Vector2(0, 18) if compact else Vector2(0, 26)
	title_start_btn.custom_minimum_size = Vector2(184, 42) if compact else Vector2(214, 48)
	title_start_btn.add_theme_font_size_override("font_size", 19 if compact else 22)
	title_mute_btn.offset_top = 14.0 if compact else 18.0
	title_mute_btn.offset_right = -20.0 if compact else -22.0
	title_controls_label.add_theme_font_size_override("font_size", 15 if compact else 17)
	title_controls_label.offset_bottom = -14.0 if compact else -20.0
	if is_instance_valid(title_art):
		title_art.queue_redraw()

func show_title_screen(muted: bool = false) -> void:
	_title_active = true
	_title_fading_out = false
	_title_fade_elapsed = 0.0
	if is_instance_valid(minimal_layer):
		minimal_layer.visible = false
		minimal_layer.modulate.a = 0.0
	if is_instance_valid(title_layer):
		title_layer.visible = true
		title_layer.modulate.a = 1.0
	if is_instance_valid(title_start_btn):
		title_start_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		title_start_btn.disabled = false
	if is_instance_valid(title_mute_btn):
		title_mute_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	sync_title_mute(muted)
	_layout_title_screen()

func hide_title_screen(instant: bool = false) -> void:
	if instant:
		_title_active = false
		_title_fading_out = false
		_title_fade_elapsed = 0.0
		if is_instance_valid(title_layer):
			title_layer.visible = false
			title_layer.modulate.a = 0.0
		if is_instance_valid(minimal_layer):
			minimal_layer.visible = true
			minimal_layer.modulate.a = 1.0
		return
	if not _title_active and not _title_fading_out:
		if is_instance_valid(minimal_layer):
			minimal_layer.visible = true
			minimal_layer.modulate.a = 1.0
		return
	_title_active = false
	_title_fading_out = true
	_title_fade_elapsed = 0.0
	if is_instance_valid(title_start_btn):
		title_start_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_start_btn.disabled = true
	if is_instance_valid(title_mute_btn):
		title_mute_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(minimal_layer):
		minimal_layer.visible = true
		minimal_layer.modulate.a = 0.0

func sync_title_mute(muted: bool) -> void:
	if is_instance_valid(title_mute_btn):
		title_mute_btn.text = "声音：静音 [M]" if muted else "声音：开 [M]"

func play_breakthrough_banner(rank: int) -> void:
	if not is_instance_valid(banner_fx):
		return
	if rank == 1:
		banner_fx.trigger("破境 · 御气期", "剑气外放 · 招式进阶", Color("6ef4ec"), Color("f5dc82"), 1.15, 0.22)
	elif rank >= 2:
		banner_fx.trigger("破境 · 仙术期", "仙术成型 · 剑威大成", Color("ffe278"), Color("72e6ff"), 1.20, 0.26)

func play_clear_banner(is_boss: bool = false) -> void:
	if not is_instance_valid(banner_fx):
		return
	if is_boss:
		banner_fx.trigger("心魔已破 · 凌霄圆满", "七关尽克 · 剑道大成", Color("ffe484"), Color("8cf2ee"), 1.80, 0.24)
	else:
		banner_fx.trigger("清场 · 破阵成功", "步入传送阵眼 · 领悟功法", Color("f4dc86"), Color("7ef2d4"), 1.55, 0.16)

func clear_screen_banner() -> void:
	if is_instance_valid(banner_fx):
		banner_fx.clear()

func show_notice(text: String) -> void:
	super.show_notice(text)
	if is_instance_valid(minimal_notice):
		minimal_notice.text = text

func _process(delta: float) -> void:
	super._process(delta)
	_hud_clock += delta
	if _title_fading_out:
		_title_fade_elapsed += delta
		var t := clampf(_title_fade_elapsed / TITLE_FADE_DURATION, 0.0, 1.0)
		var smooth := t * t * (3.0 - 2.0 * t)
		if is_instance_valid(title_layer):
			title_layer.modulate.a = 1.0 - smooth
		if is_instance_valid(minimal_layer):
			minimal_layer.visible = true
			minimal_layer.modulate.a = smooth
		if t >= 1.0:
			_title_fading_out = false
			if is_instance_valid(title_layer):
				title_layer.visible = false
				title_layer.modulate.a = 0.0
			if is_instance_valid(minimal_layer):
				minimal_layer.modulate.a = 1.0
	if _cult_flash > 0.0:
		_cult_flash = maxf(0.0, _cult_flash - delta)
	if _boss_break_flash > 0.0:
		_boss_break_flash = maxf(0.0, _boss_break_flash - delta)
	if is_instance_valid(minimal_notice):
		if notice_time <= 0.0:
			minimal_notice.text = ""
		else:
			minimal_notice.modulate.a = clampf(notice_time / 0.4, 0.0, 1.0)

func reward_summary() -> String:
	if run == null:
		return ""
	return "剑伤 +%.0f%% · 击杀回血 %.0f · 冲刺翻倍 %s · 破防延长 %s" % [
		run.reward_counts[0] * CONFIG.SWORD_BONUS * 100.0,
		run.reward_counts[2] * CONFIG.KILL_HEAL,
		("就绪" if player.combo.dash_armed else "已解锁") if run.reward_counts[1] > 0 else "未解锁",
		"已解锁" if run.reward_counts[3] > 0 else "未解锁",
	]

func update_room(remaining: int, total: int, triggered: int) -> void:
	super.update_room(remaining, total, triggered)
	if run == null or not is_instance_valid(player):
		return

	# 1. 更新左上角气血、体力与修为境界
	hp_bar_slim.max_value = player.max_health
	hp_bar_slim.value = player.health
	hp_val_label.text = "%.0f/%.0f" % [player.health, player.max_health]
	var low_hp := player.max_health > 0.0 and (player.health / player.max_health) < 0.25
	if low_hp:
		var pulse := 0.55 + 0.45 * sin(_hud_clock * 9.5)
		var warn_col := Color("d95353").lerp(Color("ff2e2e"), pulse)
		(hp_bar_slim.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = warn_col
		hp_val_label.add_theme_color_override("font_color", Color("ffd0d0").lerp(Color("ff5a5a"), pulse))
		hp_title_label.add_theme_color_override("font_color", Color("ffd0d0").lerp(Color("ff5a5a"), pulse))
	else:
		(hp_bar_slim.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = Color("d95353")
		hp_val_label.add_theme_color_override("font_color", Color("f4f6f5"))
		hp_title_label.add_theme_color_override("font_color", Color("f2d8d8"))

	sp_bar_slim.max_value = player.max_stamina
	sp_bar_slim.value = player.stamina
	sp_val_label.text = "%.0f/%.0f" % [player.stamina, player.max_stamina]

	var rank: int = clampi(player.cultivation, 0, CONFIG.CULTIVATION_NAMES.size() - 1)
	if _last_cultivation >= 0 and _last_cultivation != rank:
		_cult_flash = 0.85
	_last_cultivation = rank

	var cult_fill := cult_bar_slim.get_theme_stylebox("fill") as StyleBoxFlat
	cult_bar_slim.max_value = 1.0
	if run.cultivation_override >= 0:
		cult_bar_slim.value = 1.0
		cult_label.text = "%s·切换" % CONFIG.CULTIVATION_NAMES[rank]
	elif rank == 2:
		cult_bar_slim.value = 1.0
		cult_label.text = "%s·圆满" % CONFIG.CULTIVATION_NAMES[rank]
	else:
		var floor_kills: int = int(CONFIG.CULTIVATION_KILLS[rank])
		var next_kills: int = int(CONFIG.CULTIVATION_KILLS[rank + 1])
		var span: float = maxf(1.0, float(next_kills - floor_kills))
		cult_bar_slim.value = clampf(float(run.run_kills - floor_kills) / span, 0.0, 1.0)
		cult_label.text = "%s %d/%d" % [CONFIG.CULTIVATION_NAMES[rank], run.run_kills, next_kills]

	if _cult_flash > 0.0:
		var glow := clampf(_cult_flash / 0.85, 0.0, 1.0)
		cult_fill.bg_color = Color("e6c15a").lerp(Color("fff0a6"), glow)
		cult_label.add_theme_color_override("font_color", Color("f0e2b6").lerp(Color("fff2a8"), glow))
		cult_title_label.add_theme_color_override("font_color", Color("f4e4b4").lerp(Color("fff2a8"), glow))
	elif rank == 2:
		var shimmer := 0.5 + 0.5 * sin(_hud_clock * 4.5)
		cult_fill.bg_color = Color("e6c15a").lerp(Color("9beed8"), 0.25 + 0.22 * shimmer)
		cult_label.add_theme_color_override("font_color", Color("b8f4e8").lerp(Color("ffe999"), 0.45))
		cult_title_label.add_theme_color_override("font_color", Color("f4e4b4"))
	else:
		var jade_mix := 0.22 if rank == 1 else 0.0
		cult_fill.bg_color = Color("e6c15a").lerp(Color("94e4c8"), jade_mix)
		var base_c := Color("f0e2b6") if rank == 0 else Color("a8f2e0")
		cult_label.add_theme_color_override("font_color", base_c)
		cult_title_label.add_theme_color_override("font_color", Color("f4e4b4"))

	# 2. 更新顶部居中关名、进度/剩敌 或 第7关 Boss 气血长条
	var room_idx := clampi(run.room_index, 0, CONFIG.ROOM_NAMES.size() - 1)
	var room_name: String = CONFIG.ROOM_NAMES[room_idx]
	room_title_label.text = room_name
	var in_boss := room_idx == CONFIG.BOSS_ROOM and is_instance_valid(run.boss)
	boss_bar_row.visible = in_boss
	room_sub_label.visible = not in_boss
	if in_boss:
		var b: SurvivorEnemy = run.boss
		boss_hp_bar.max_value = b.max_health
		boss_hp_bar.value = maxf(0.0, b.health)
		boss_hp_val.text = "%.0f/%.0f" % [maxf(0.0, b.health), b.max_health]
		if _last_boss_hp > 0.0 and _last_boss_hp - b.health >= 50.0:
			_boss_break_flash = 0.75
		_last_boss_hp = b.health
		var broken_now: bool = _boss_break_flash > 0.0 or b.v41_heavy_stun > 0.0 or b.boss_state == SurvivorEnemy.BossState.STAGGER
		boss_break_label.visible = broken_now
		timer_text.text = "%s · %s %.0f / %.0f" % [room_name, CONFIG.BOSS_NAME, maxf(0.0, b.health), b.max_health]
	else:
		_last_boss_hp = -1.0
		if run.phase == "cleared":
			room_sub_label.text = "%s 已破  ·  本局通关" % CONFIG.BOSS_NAME
		elif run.phase == "clear_celebration":
			room_sub_label.text = "%s 已破" % CONFIG.BOSS_NAME if room_idx == CONFIG.BOSS_ROOM else "第 %d 关 / 共七关  ·  破阵成功" % (room_idx + 1)
		elif run.phase == "exit_ready":
			room_sub_label.text = "步入%s阵眼  ·  领悟功法" % CONFIG.ROOM_EXIT_LABELS[room_idx]
		elif run.phase == "reward_select":
			room_sub_label.text = "第 %d 关 / 共七关  ·  阵眼领悟" % (room_idx + 1)
		else:
			room_sub_label.text = "第 %d 关 / 共七关  ·  剩余敌人 %d" % [room_idx + 1, remaining]
		timer_text.text = room_sub_label.text

	# 3. 更新底部四枚无框像素技能图标与释放弹跳闪光
	var combo = player.combo
	if combo.attack_count != _last_attack_count:
		if _last_attack_count > 0:
			skill_slots[0].trigger_pulse()
		_last_attack_count = combo.attack_count

	var throwing_now: bool = is_instance_valid(player.thrown_sword)
	if throwing_now and not _was_throwing:
		skill_slots[1].trigger_pulse()
	_was_throwing = throwing_now

	var dashing_now: bool = player.dash_state != 0
	if dashing_now and not _was_dashing:
		skill_slots[2].trigger_pulse()
	_was_dashing = dashing_now

	var raining_now: bool = is_instance_valid(player.sword_rain_node)
	if raining_now and not _was_raining:
		skill_slots[3].trigger_pulse()
	_was_raining = raining_now

	skill_slots[0].set_state(rank, 0.0, 1.0, false, combo.swing_time > 0.0, "", combo.dash_armed and combo.dash_reward)
	skill_slots[1].set_state(rank, player.throw_cooldown, CONFIG.THROW_COOLDOWN, (not throwing_now and player.stamina < CONFIG.THROW_COST), throwing_now, "", combo.heavy_reward)
	skill_slots[2].set_state(rank, player.dash_cooldown, CONFIG.DASH_COOLDOWN, (not dashing_now and player.stamina < CONFIG.DASH_COST), dashing_now, "", combo.dash_reward)
	var cast_tip := "施法中" if raining_now else ""
	skill_slots[3].set_state(rank, player.sword_rain_cooldown, CONFIG.SWORD_RAIN_COOLDOWN, (not raining_now and player.stamina < CONFIG.SWORD_RAIN_COST), raining_now, cast_tip, player.sword_rain_card_level > 0)

	# 保持旧文本字段同步更新，供既有接口或测试读取
	var rain_status := "就绪" if player.stamina >= CONFIG.SWORD_RAIN_COST else "体力不足"
	if player.is_casting_sword_rain():
		rain_status = "念咒中"
	elif raining_now:
		rain_status = "施法中"
	elif player.sword_rain_cooldown > 0.0:
		rain_status = "%.1f 秒" % player.sword_rain_cooldown
	weapon_text.text = "左键 · 右键 · 空格 · E"
	weapon_detail.text = "%s · 万剑 %s" % [CONFIG.CULTIVATION_NAMES[rank], rain_status]

func show_rewards() -> void:
	var box := _screen("清房奖励", "选择一项属性奖励")
	box.add_child(_modal_label(reward_summary(), 17))
	var names: Array[String] = CONFIG.reward_names()
	for index in run.reward_options:
		var label: String = names[index]
		var enabled: bool = run.can_select_reward(index)
		_add_button(box, label if enabled else label + "（已解锁）", func(): reward_selected.emit(index))
		(box.get_child(box.get_child_count() - 1) as Button).disabled = not enabled
	box.add_child(_modal_label("冲刺翻倍作用于下一次出剑的直击。第三段自带破防。", 16))

func show_card_debug() -> void:
	var panel := _screen("GM 调试 · `", "仅调试运行有效；滚动查看全部功能")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(680, 0)
	panel.add_child(scroll)
	gm_scroll = scroll
	_resize_modal()
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	var gm_row := HBoxContainer.new()
	box.add_child(gm_row)
	gm_row.add_child(PrototypeUI.button("无敌：" + ("开" if run.gm_invincible else "关"), func(): run.debug_toggle_invincible(), 38))
	gm_row.add_child(PrototypeUI.button("无限体力：" + ("开" if run.gm_infinite_stamina else "关"), func(): run.debug_toggle_stamina(), 38))
	gm_row.add_child(PrototypeUI.button("体力回满", func(): run.debug_fill_stamina(), 38))
	var cultivation_row := HBoxContainer.new()
	box.add_child(cultivation_row)
	for rank in range(CONFIG.CULTIVATION_NAMES.size()):
		var button := PrototypeUI.button(CONFIG.CULTIVATION_NAMES[rank], func(): run.debug_cultivation(rank), 38)
		button.disabled = run.cultivation_override == rank
		cultivation_row.add_child(button)
	cultivation_row.add_child(PrototypeUI.button("恢复自然修为", func(): run.debug_cultivation(-1), 38))
	box.add_child(_modal_label("跳关", 17))
	var rooms := HBoxContainer.new()
	box.add_child(rooms)
	for i in range(CONFIG.RUN_ROOMS):
		rooms.add_child(PrototypeUI.button("Boss" if i == CONFIG.BOSS_ROOM else str(i + 1), func(): run.debug_jump(i), 38))
	var spawn_row := HBoxContainer.new()
	box.add_child(spawn_row)
	var types := OptionButton.new()
	for label in ["普通近战", "举防近战", "远程", "Boss"]: types.add_item(label)
	spawn_row.add_child(types)
	var count := SpinBox.new()
	count.min_value = 1
	count.max_value = 20
	count.value = 1
	spawn_row.add_child(count)
	spawn_row.add_child(PrototypeUI.button("玩家前方刷怪", func(): run.debug_spawn(types.selected, int(count.value)), 38))
	spawn_row.add_child(PrototypeUI.button("清除当前敌人", func(): run.debug_clear_enemies(), 38))
	box.add_child(_modal_label("调试得卡", 17))
	var grid := GridContainer.new()
	grid.columns = 2
	box.add_child(grid)
	var names := CONFIG.reward_names()
	for index in range(names.size()):
		var button := PrototypeUI.button(names[index], func(): run.debug_grant(index), 38)
		button.disabled = not run.CARD_POOL.eligible(index, run.reward_counts)
		grid.add_child(button)
	box.add_child(PrototypeUI.button("返回", func(): run.debug_close(), 38))

func show_pause(_gold: int = -1) -> void:
	var box := _screen("已暂停", "共七关 · 凌霄仙庭迎战" + CONFIG.BOSS_NAME)
	box.add_child(_modal_label("左键三连，右键掷剑，空格穿阵，E 万剑归宗，M 静音。\n清场后步入传送阵眼领悟功法，选完直接进入下一关。", 16))
	_add_button(box, "继续  [Esc]", func(): resume_requested.emit())
	var tools_row := HBoxContainer.new()
	tools_row.add_theme_constant_override("separation", 8)
	var cam_btn := PrototypeUI.button("镜头：" + ("近景" if run != null and run.close_view else "远景"), func():
		if run != null:
			run.toggle_view()
		show_pause(), 38)
	cam_btn.focus_mode = Control.FOCUS_NONE
	cam_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cam_btn.add_theme_font_size_override("font_size", 16)
	tools_row.add_child(cam_btn)
	if run != null and is_instance_valid(run.audio_mgr):
		var bgm_btn := PrototypeUI.button("背景音乐：" + ("关" if run.audio_mgr.bgm_muted else "开"), func():
			run.audio_mgr.toggle_bgm_mute()
			show_pause(), 38)
		bgm_btn.focus_mode = Control.FOCUS_NONE
		bgm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bgm_btn.add_theme_font_size_override("font_size", 16)
		var mute_btn := PrototypeUI.button("音频：" + ("静音" if run.audio_mgr.master_muted else "开启"), func():
			run.audio_mgr.toggle_master_mute()
			show_pause(), 38)
		mute_btn.focus_mode = Control.FOCUS_NONE
		mute_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mute_btn.add_theme_font_size_override("font_size", 16)
		tools_row.add_child(bgm_btn)
		tools_row.add_child(mute_btn)
	box.add_child(tools_row)
	_add_button(box, "重新开始", func(): restart_requested.emit())
	_add_button(box, "庭院 / 镜头独立样板（结束本局）", func(): _open_sample("courtyard_trial"))
	_add_button(box, "挥剑慢动作样板（结束本局）", func(): _open_sample("sword_motion_trial"))

func _open_sample(scene: String) -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/" + scene + ".tscn")

func show_stats() -> void:
	var rank: int = clampi(player.cultivation, 0, CONFIG.CULTIVATION_NAMES.size() - 1)
	var box := _screen("角色属性", CONFIG.CULTIVATION_NAMES[rank])
	box.add_theme_constant_override("separation", 8)
	box.add_child(_modal_label("生命 %.0f / %.0f · 体力 %.0f / %.0f\n%s" % [player.health, player.max_health, player.stamina, player.max_stamina, reward_summary()], 15))
	for i in range(player.combo.stages.size()):
		var data: Dictionary = player.combo.stages[i]
		box.add_child(_modal_label("左键 %d %s · 伤害 %.1f · 距离 %.0f" % [i + 1, data.name, float(data.damage) * player.damage_multiplier, float(data.reach) + CONFIG.SWORD_EXTENSION[rank]], 15, Color("e1cc9c")))
	var mult: float = player.combo.card_multiplier * player.damage_multiplier
	box.add_child(_modal_label("空格 穿阵一线 · 距离 %.0f · 体力 %.0f · 冷却 %.2f 秒 · 直击 %.1f / 剑痕 %.1f" % [
		CONFIG.DASH_DISTANCE[rank], CONFIG.DASH_COST, CONFIG.DASH_COOLDOWN,
		CONFIG.DASH_DAMAGE[rank] * mult, CONFIG.DASH_MARK_DAMAGE[rank] * mult,
	], 15))
	box.add_child(_modal_label("右键 掷剑旋斩 · 距离 %.0f · 体力 %.0f · 冷却 %.1f 秒 · 飞出 %.1f / 旋斩 %.1f×%d / 回程 %.1f" % [
		CONFIG.THROW_DISTANCE[rank], CONFIG.THROW_COST, CONFIG.THROW_COOLDOWN,
		CONFIG.THROW_OUT_DAMAGE[rank] * mult, CONFIG.THROW_SPIN_DAMAGE[rank] * mult, int(CONFIG.THROW_SPIN_TICKS[rank]), CONFIG.THROW_RETURN_DAMAGE[rank] * mult,
	], 15))
	var sword_count: int = int(CONFIG.SWORD_RAIN_COUNT[rank]) + (CONFIG.SWORD_RAIN_CARD_EXTRA if player.sword_rain_card_level > 0 else 0)
	var rain_radius: float = CONFIG.SWORD_RAIN_IMPACT_RADIUS + (8.0 if player.sword_rain_card_level > 0 else 0.0)
	box.add_child(_modal_label("E 万剑归宗 · %d 柄天降飞剑 · 单剑伤害 %.1f · 落点半径 %.0f · 体力 %.0f · 冷却 %.1f 秒" % [
		sword_count, float(CONFIG.SWORD_RAIN_DAMAGE[rank]) * mult, rain_radius,
		CONFIG.SWORD_RAIN_COST, CONFIG.SWORD_RAIN_COOLDOWN,
	], 15, Color("9de8ef")))
	_add_button(box, "返回战斗  [Tab / Esc]", func(): resume_requested.emit())

func show_run_result(won: bool) -> void:
	var box := _screen("本局通关" if won else "角色倒下", "已击败" + CONFIG.BOSS_NAME if won else "倒在第 %d / %d 关" % [run.room_index + 1, CONFIG.RUN_ROOMS])
	box.add_child(_modal_label("本局击败 %d / %d\n%s" % [run.run_kills, CONFIG.run_total(), reward_summary()], 19))
	box.add_child(_modal_label("重新开始：第 1 关、满生命与体力、清空奖励。", 17))
	_add_button(box, "重新开始  [Enter / R]", func(): restart_requested.emit())

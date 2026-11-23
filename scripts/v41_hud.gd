extends "res://scripts/combo_hud.gd"

signal reward_selected(index: int)
signal title_start_requested
signal title_mute_requested
signal return_to_title_requested
const CONFIG = preload("res://scripts/v41_config.gd")
const SkillSlot = preload("res://scripts/v41_skill_slot.gd")
const REWARD_UI = preload("res://scripts/v41_reward_ui.gd")
const DEFEAT_SHADER = preload("res://assets/shaders/v41_defeat_ink.gdshader")
const BOSS_DOMAIN = preload("res://scripts/v41_boss_domain.gd")
signal retry_room_requested
const CARDS = preload("res://scripts/v41_card_pool.gd").Card
const POOL = preload("res://scripts/v41_card_pool.gd")
const TITLE_FADE_DURATION := 0.35

var run
var gm_scroll: ScrollContainer
var domain_alert_fx: Control
var _reward_mode := false
var _victory_mode := false
var _pause_mode := false
var _stats_mode := false
var _rebuilding_ink_modal := false
var _reward_backdrop: Control
var _reward_cards: Array[Control] = []
var _reward_title_label: Label
var _victory_title_label: Label
var _reward_sfx_player: AudioStreamPlayer
var _reward_hover_sfx: AudioStreamWAV
var _reward_select_sfx: AudioStreamWAV

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
var cast_focus: REWARD_UI.CastFocus
var defeat_ink: ColorRect
var defeat_retry: Button
var boss_mechanic: VBoxContainer
var boss_mechanic_name: Label
var boss_mechanic_hint: Label
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

		# 题字控件绘制自身墨迹。此处仅定位周围灵尘。
		var title_cy := (84.0 if compact else 118.0)
		var title_w := (170.0 if compact else 220.0)
		if is_instance_valid(title_ref) and title_ref.size.x > 10.0:
			var r := title_ref.get_global_rect()
			title_cy = (r.get_center() - global_position).y
			title_w = maxf(title_w, r.size.x * 0.90)
		var pulse := 0.82 + 0.18 * sin(clock * 1.9)

		# 4. 漂浮在标题四周的细碎金色灵尘
		for i in range(10):
			var phase := float(i) * 1.17 + clock * (0.45 + float(i % 3) * 0.14)
			var px := cx + sin(phase * 0.78 + float(i)) * (title_w * 1.15)
			var py := title_cy + cos(phase * 0.95 + float(i) * 0.7) * (36.0 if compact else 48.0) - 6.0
			var pa := (0.28 + 0.36 * (0.5 + 0.5 * sin(phase * 1.8))) * pulse
			var dot_sz := 2.5 if i % 3 == 0 else 2.0
			draw_rect(Rect2(roundf(px), roundf(py), dot_sz, dot_sz), Color(0.98, 0.88, 0.56, pa))

		# 5. 底部操作指南下方柔光暗带（移除旧同心圆晕）
		if is_instance_valid(controls_ref) and controls_ref.size.x > 10.0:
			var cr := controls_ref.get_global_rect()
			var c_top := cr.position.y - global_position.y - 10.0
			var c_bot := size.y
			draw_polygon(
				PackedVector2Array([Vector2(0, c_top), Vector2(size.x, c_top), Vector2(size.x, c_bot), Vector2(0, c_bot)]),
				PackedColorArray([Color(0.02, 0.03, 0.05, 0.0), Color(0.02, 0.03, 0.05, 0.0), Color(0.02, 0.03, 0.05, 0.42), Color(0.02, 0.03, 0.05, 0.42)])
			)

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
		var font := preload("res://assets/fonts/msyh.ttc")
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
	if _reward_mode and is_instance_valid(modal_panel):
		_layout_reward_screen()
		_layout_title_screen()
		return
	if _victory_mode and is_instance_valid(modal_panel):
		_layout_victory_screen()
		_layout_title_screen()
		return
	if _pause_mode and is_instance_valid(modal_panel) and not _rebuilding_ink_modal:
		_rebuilding_ink_modal = true
		show_pause()
		_rebuilding_ink_modal = false
		_layout_title_screen()
		return
	if _stats_mode and is_instance_valid(modal_panel) and not _rebuilding_ink_modal:
		_rebuilding_ink_modal = true
		show_stats()
		_rebuilding_ink_modal = false
		_layout_title_screen()
		return
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
	cast_focus = REWARD_UI.CastFocus.new()
	cast_focus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PrototypeUI.fill(cast_focus)
	root.add_child(cast_focus)
	cast_focus.hide()
	defeat_ink = ColorRect.new()
	defeat_ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ink_material := ShaderMaterial.new()
	ink_material.shader = DEFEAT_SHADER
	defeat_ink.material = ink_material
	PrototypeUI.fill(defeat_ink)
	root.add_child(defeat_ink)
	root.move_child(defeat_ink, 0)
	defeat_ink.hide()

	# 无框水墨暗金开局标题画面（不加入 combat_panels，默认隐藏，由 run.phase == "title" 激活）
	_build_title_screen()

	# Boss【心魔】「万魔剑域」全屏边缘暗红魔气预警覆层
	domain_alert_fx = REWARD_UI.DomainAlertOverlay.new()
	domain_alert_fx.name = "DomainAlertOverlay"
	root.add_child(domain_alert_fx)
	boss_mechanic = PrototypeUI.column(1)
	boss_mechanic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(boss_mechanic)
	boss_mechanic.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	boss_mechanic.offset_left = -300
	boss_mechanic.offset_right = 300
	boss_mechanic.offset_top = 89
	boss_mechanic_name = Label.new()
	boss_mechanic_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_mechanic.add_child(REWARD_UI.style_ink_label(boss_mechanic_name, 30, Color("ffb580"), 5))
	boss_mechanic_hint = Label.new()
	boss_mechanic_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_mechanic.add_child(REWARD_UI.style_ink_label(boss_mechanic_hint, 14, Color("f6ddd0"), 2))
	boss_mechanic.hide()

	# 确保全屏红闪与遮罩弹窗始终位于最顶层
	root.move_child(domain_alert_fx, root.get_child_count() - 5)
	root.move_child(title_layer, root.get_child_count() - 4)
	root.move_child(banner_fx, root.get_child_count() - 3)
	root.move_child(hurt_flash, root.get_child_count() - 2)
	root.move_child(overlay, root.get_child_count() - 1)

	_reward_hover_sfx = REWARD_UI.make_hover_sound()
	_reward_select_sfx = REWARD_UI.make_select_sound()
	_reward_sfx_player = AudioStreamPlayer.new()
	_reward_sfx_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_reward_sfx_player.volume_db = -10.0
	add_child(_reward_sfx_player)

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
	title_main_label.self_modulate = Color.TRANSPARENT
	var title_ink := REWARD_UI.CoverTitle.new()
	title_ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PrototypeUI.fill(title_ink)
	title_main_label.add_child(title_ink)
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
	title_controls_label = _ink_label("WASD 移动 · 鼠标瞄准 · 左键三连 · 右键旋斩 · 空格穿阵 · E 万剑归宗", 17, Color("eef2ec"), 5)
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
	if is_instance_valid(cast_focus):
		cast_focus.clear()

func play_cast_focus() -> void:
	banner_fx.clear()
	cast_focus.play()

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
	var names: Array[String] = []
	for index in range(POOL.TITLES.size()):
		var count: int = run.reward_counts[index]
		if count > 0:
			names.append(POOL.TITLES[index] + (" ×%d" % count if count > 1 else ""))
	if names.is_empty():
		return "已习得功法 · 尚未领悟"
	return "已习得功法 · " + "、".join(names.slice(0, 3)) + ("\n" + "、".join(names.slice(3)) if names.size() > 3 else "")

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
		if run.phase in ["cleared", "victory"]:
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

	skill_slots[0].set_state(rank, 0.0, 1.0, false, combo.swing_time > 0.0, "", combo.dash_armed)
	skill_slots[1].set_state(rank, player.throw_cooldown, CONFIG.THROW_COOLDOWN, (not throwing_now and player.stamina < CONFIG.THROW_COST), throwing_now, "", player.card_level(CARDS.SPLIT) > 0 or player.card_level(CARDS.CHAIN) > 0)
	skill_slots[2].set_state(rank, player.dash_cooldown, CONFIG.DASH_COOLDOWN, (not dashing_now and player.stamina < CONFIG.DASH_COST), dashing_now, "", player.has_thunder_ghost())
	var cast_tip := "施法中" if raining_now else ""
	skill_slots[3].set_state(rank, player.sword_rain_cooldown, player.sword_rain_base_cooldown(), (not raining_now and player.stamina < CONFIG.SWORD_RAIN_COST), raining_now, cast_tip, player.card_level(CARDS.RAIN) > 0)

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

func set_domain_alert(active: bool) -> void:
	if is_instance_valid(domain_alert_fx):
		domain_alert_fx.set_alert(active)

func _clear_ink_modal() -> void:
	_reward_mode = false
	_victory_mode = false
	_pause_mode = false
	_stats_mode = false
	_reward_cards.clear()
	_reward_title_label = null
	_victory_title_label = null
	if is_instance_valid(_reward_backdrop):
		_reward_backdrop.queue_free()
		_reward_backdrop = null
	overlay.color = Color(0.02, 0.035, 0.05, 0.93)

func hide_screen() -> void:
	_clear_ink_modal()
	if is_instance_valid(minimal_layer) and not _title_active:
		minimal_layer.visible = true
	super.hide_screen()

func _screen(title: String, subtitle: String) -> VBoxContainer:
	_clear_ink_modal()
	return super._screen(title, subtitle)

func _play_reward_sfx(stream: AudioStreamWAV) -> void:
	if DisplayServer.get_name() == "headless" or not is_instance_valid(_reward_sfx_player):
		return
	_reward_sfx_player.stream = stream
	_reward_sfx_player.play()

func show_rewards() -> void:
	_clear_ink_modal()
	transition_button = null
	profession_buttons.clear()
	profession_layout = null
	start_button = null
	for child in overlay_center.get_children():
		overlay_center.remove_child(child)
		child.queue_free()

	overlay.color = Color(0, 0, 0, 0)
	overlay.show()
	overlay_center.visible = true

	var vignette := REWARD_UI.VignetteBackdrop.new()
	vignette.darkness = 0.64
	vignette.edge_alpha = 0.72
	vignette.rebuild()
	overlay.add_child(vignette)
	overlay.move_child(vignette, 0)
	_reward_backdrop = vignette

	_reward_mode = true
	modal_panel = PanelContainer.new()
	modal_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	overlay_center.add_child(modal_panel)

	var main_box := VBoxContainer.new()
	main_box.alignment = BoxContainer.ALIGNMENT_CENTER
	main_box.add_theme_constant_override("separation", 8)
	modal_panel.add_child(main_box)

	var header_row := HBoxContainer.new()
	header_row.alignment = BoxContainer.ALIGNMENT_CENTER
	header_row.add_theme_constant_override("separation", 14)
	main_box.add_child(header_row)

	header_row.add_child(REWARD_UI.CloudDivider.new(108.0, Color("c8a45c")))
	_reward_title_label = Label.new()
	_reward_title_label.text = "领 悟 功 法"
	REWARD_UI.style_ink_label(_reward_title_label, 40, Color("f0d79e"), 2)
	header_row.add_child(_reward_title_label)
	header_row.add_child(REWARD_UI.VermilionSeal.new("悟", 28.0))
	header_row.add_child(REWARD_UI.CloudDivider.new(108.0, Color("c8a45c")))

	var subtitle := Label.new()
	subtitle.text = "当前领悟 · %s · 择一修习" % CONFIG.CULTIVATION_NAMES[run.reward_rank()]
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	REWARD_UI.style_ink_label(subtitle, 16, Color("c2d1cf"), 1)
	main_box.add_child(subtitle)

	var summary := Label.new()
	summary.text = reward_summary()
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	REWARD_UI.style_ink_label(summary, 15, Color("adbfbd"), 1)
	main_box.add_child(summary)

	var cards_row := HBoxContainer.new()
	cards_row.name = "CardsRow"
	cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_row.add_theme_constant_override("separation", 22)
	main_box.add_child(cards_row)

	for index in run.reward_options:
		var enabled: bool = run.can_select_reward(index)
		var slot := _build_reward_card(index, enabled)
		cards_row.add_child(slot)
		_reward_cards.append(slot)

	var foot := Label.new()
	foot.text = "悬停品鉴功法 · 点击择一修习步入下一重山门"
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	REWARD_UI.style_ink_label(foot, 15, Color("adbfbd"), 1)
	main_box.add_child(foot)

	_layout_reward_screen()

func _build_reward_card(index: int, enabled: bool) -> Control:
	var tier := POOL.tier(index)
	var border_col: Color = REWARD_UI.TIER_EDGES[tier]
	var accent := Color("8ee7d3") if REWARD_UI.CARD_TAGS[index] == "剑气御剑流" else Color("e4c185")
	var glow_col := border_col.lightened(0.32)

	var slot := Control.new()
	slot.custom_minimum_size = Vector2(236, 326)
	slot.mouse_filter = Control.MOUSE_FILTER_PASS

	var holder := Control.new()
	holder.name = "VisualHolder"
	PrototypeUI.fill(holder)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(holder)

	var visual := REWARD_UI.JadeCardVisual.new()
	visual.accent = accent
	visual.border_col = border_col
	visual.glow_col = glow_col
	visual.disabled_state = not enabled
	holder.add_child(visual)

	var pad := MarginContainer.new()
	PrototypeUI.fill(pad)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_theme_constant_override("margin_left", 16)
	pad.add_theme_constant_override("margin_right", 16)
	pad.add_theme_constant_override("margin_top", 16)
	pad.add_theme_constant_override("margin_bottom", 16)
	holder.add_child(pad)

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_BEGIN
	col.add_theme_constant_override("separation", 7)
	pad.add_child(col)

	var emblem_center := CenterContainer.new()
	emblem_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var emblem := REWARD_UI.CardEmblem.new(REWARD_UI.CARD_ICONS[index], accent, not enabled)
	emblem.name = "Emblem"
	emblem_center.add_child(emblem)
	col.add_child(emblem_center)

	var name_label := Label.new()
	name_label.name = "CardTitle"
	name_label.text = POOL.TITLES[index]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	REWARD_UI.style_ink_label(name_label, 25, Color("8a9196") if not enabled else Color("f3e2bb"), 2)
	col.add_child(name_label)

	var tag_center := CenterContainer.new()
	tag_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tag_panel := PanelContainer.new()
	tag_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tag_style := StyleBoxFlat.new()
	tag_style.bg_color = Color(0.08, 0.11, 0.14, 0.85)
	tag_style.border_color = Color("555d63") if not enabled else Color(accent.r, accent.g, accent.b, 0.78)
	tag_style.set_border_width_all(1)
	tag_style.set_corner_radius_all(2)
	tag_style.content_margin_left = 10.0
	tag_style.content_margin_right = 10.0
	tag_style.content_margin_top = 2.0
	tag_style.content_margin_bottom = 2.0
	tag_panel.add_theme_stylebox_override("panel", tag_style)
	var tag_label := Label.new()
	tag_label.text = "%s · %s" % [REWARD_UI.TIER_NAMES[tier], REWARD_UI.CARD_TAGS[index]]
	REWARD_UI.style_ink_label(tag_label, 14, Color("80888e") if not enabled else accent, 1)
	tag_panel.add_child(tag_label)
	tag_center.add_child(tag_panel)
	col.add_child(tag_center)

	var div := ColorRect.new()
	div.custom_minimum_size = Vector2(0, 1)
	div.color = Color(accent.r, accent.g, accent.b, 0.18 if not enabled else 0.36)
	div.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(div)

	var desc := RichTextLabel.new()
	desc.name = "CardDesc"
	desc.bbcode_enabled = true
	desc.fit_content = true
	desc.scroll_active = false
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc.add_theme_font_size_override("normal_font_size", 15)
	desc.add_theme_color_override("default_color", Color("7a8389") if not enabled else Color("dce6e5"))
	desc.add_theme_color_override("font_outline_color", Color("090d11"))
	desc.add_theme_constant_override("outline_size", 1)
	desc.text = "[center]%s[/center]" % POOL.DESCRIPTIONS[index]
	col.add_child(desc)

	if not enabled:
		var done_label := Label.new()
		done_label.text = "已 修 成"
		done_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		REWARD_UI.style_ink_label(done_label, 14, Color("c46458"), 1)
		col.add_child(done_label)

	var btn := Button.new()
	btn.accessibility_name = POOL.TITLES[index] if enabled else POOL.TITLES[index] + "（已修成）"
	btn.disabled = not enabled
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if enabled else Control.CURSOR_ARROW
	PrototypeUI.fill(btn)
	for st_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		btn.add_theme_stylebox_override(st_name, StyleBoxEmpty.new())

	var float_tween_ref := [null]
	btn.mouse_entered.connect(func():
		if btn.disabled:
			return
		visual.hovered = true
		visual.queue_redraw()
		_play_reward_sfx(_reward_hover_sfx)
		if float_tween_ref[0] != null and is_instance_valid(float_tween_ref[0]):
			float_tween_ref[0].kill()
		var tw := holder.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_method(func(y: float): holder.position.y = roundf(y), holder.position.y, -8.0, 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		float_tween_ref[0] = tw)
	btn.mouse_exited.connect(func():
		visual.hovered = false
		visual.queue_redraw()
		if float_tween_ref[0] != null and is_instance_valid(float_tween_ref[0]):
			float_tween_ref[0].kill()
		var tw := holder.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_method(func(y: float): holder.position.y = roundf(y), holder.position.y, 0.0, 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		float_tween_ref[0] = tw)
	btn.pressed.connect(func():
		if btn.disabled:
			return
		_play_reward_sfx(_reward_select_sfx)
		var fx := REWARD_UI.SelectFlashFX.new(slot.get_global_rect(), glow_col)
		root.add_child(fx)
		reward_selected.emit(index))
	slot.add_child(btn)
	return slot

func _layout_reward_screen() -> void:
	if not is_instance_valid(modal_panel):
		return
	var sz := root.size if is_instance_valid(root) and root.size.x > 0.0 and root.size.y > 0.0 else Vector2(1280, 720)
	var compact := minf(sz.y, get_window().size.y) < 600.0 or minf(sz.x, get_window().size.x) < 1050.0
	var card_w := roundf(clampf((sz.x - 140.0) / 3.0, 196.0, 236.0))
	var card_h := 284.0 if compact else 304.0
	var sep := 16 if compact else 22
	if is_instance_valid(_reward_title_label):
		_reward_title_label.add_theme_font_size_override("font_size", 36 if compact else 40)
	var cards_row := modal_panel.find_child("CardsRow", true, false) as HBoxContainer
	if cards_row != null:
		cards_row.add_theme_constant_override("separation", sep)
	for slot in _reward_cards:
		if not is_instance_valid(slot):
			continue
		slot.custom_minimum_size = Vector2(card_w, card_h)
		var emblem := slot.find_child("Emblem", true, false) as Control
		if emblem != null:
			emblem.custom_minimum_size = Vector2(72, 60) if compact else Vector2(88, 76)
		var card_title := slot.find_child("CardTitle", true, false) as Label
		if card_title != null:
			card_title.add_theme_font_size_override("font_size", 24 if compact else 25)
	modal_panel.custom_minimum_size.x = minf(card_w * 3.0 + sep * 2.0 + 32.0, sz.x - 32.0)

func show_card_debug() -> void:
	if not preload("res://scripts/test_runtime.gd").enabled():
		return
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
	var names := POOL.TITLES
	for index in range(names.size()):
		var button := PrototypeUI.button(names[index], func(): run.debug_grant(index), 38)
		button.disabled = not POOL.eligible(index, run.reward_counts, 2)
		grid.add_child(button)
	box.add_child(PrototypeUI.button("返回", func(): run.debug_close(), 38))

func _fmt_stat_num(value: float) -> String:
	var rounded := roundf(value)
	if absf(value - rounded) < 0.05:
		return "%.0f" % rounded
	return "%.1f" % value

func _open_ink_gold_modal(panel_width: float, compact: bool) -> VBoxContainer:
	_clear_ink_modal()
	transition_button = null
	profession_buttons.clear()
	profession_layout = null
	start_button = null
	for child in overlay_center.get_children():
		overlay_center.remove_child(child)
		child.queue_free()

	overlay.color = Color(0, 0, 0, 0)
	overlay.show()
	overlay_center.visible = true

	var vignette := REWARD_UI.VignetteBackdrop.new()
	vignette.darkness = 0.68
	vignette.edge_alpha = 0.80
	vignette.tint = Color(0.018, 0.022, 0.028, 1.0)
	vignette.rebuild()
	overlay.add_child(vignette)
	overlay.move_child(vignette, 0)
	_reward_backdrop = vignette

	modal_panel = PanelContainer.new()
	modal_panel.name = "InkGoldModal"
	modal_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var sz := root.size if is_instance_valid(root) and root.size.x > 0.0 and root.size.y > 0.0 else Vector2(1280, 720)
	modal_panel.custom_minimum_size = Vector2(minf(panel_width, sz.x - 36.0), 0.0)
	overlay_center.add_child(modal_panel)

	var frame_vis := REWARD_UI.InkGoldPanelVisual.new()
	frame_vis.name = "InkGoldFrame"
	modal_panel.add_child(frame_vis)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pad_x := 20 if compact else 28
	var pad_y := 14 if compact else 20
	margin.add_theme_constant_override("margin_left", pad_x)
	margin.add_theme_constant_override("margin_right", pad_x)
	margin.add_theme_constant_override("margin_top", pad_y)
	margin.add_theme_constant_override("margin_bottom", pad_y)
	modal_panel.add_child(margin)

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 8 if compact else 11)
	margin.add_child(col)
	return col

func show_pause(_gold: int = -1) -> void:
	var sz := root.size if is_instance_valid(root) and root.size.x > 0.0 and root.size.y > 0.0 else Vector2(1280, 720)
	var compact := sz.x < 1100.0 or sz.y < 620.0
	var col := _open_ink_gold_modal(470.0 if compact else 540.0, compact)
	_pause_mode = true

	# 1. 书法大字「已暂停」+ 右侧朱砂小印
	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_theme_constant_override("separation", 10 if compact else 14)
	col.add_child(title_row)

	var title_lbl := Label.new()
	title_lbl.text = "已 暂 停"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	REWARD_UI.style_calligraphy_title(title_lbl, 36 if compact else 44, Color("f3dda2"), 4 if compact else 5)
	title_row.add_child(title_lbl)

	var seal := REWARD_UI.VermilionSeal.new("息", 24.0 if compact else 28.0)
	seal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(seal)

	# 暗金云纹分割线
	var div_wrap := CenterContainer.new()
	div_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	div_wrap.add_child(REWARD_UI.CloudDivider.new(250.0 if compact else 320.0, Color("c8a86b")))
	col.add_child(div_wrap)

	# 当前关卡进度铭牌徽章（如：第七关 · 凌霄仙庭）
	var room_idx := clampi(run.room_index, 0, CONFIG.ROOM_NAMES.size() - 1) if run != null else 0
	var room_ordinals := ["第一关", "第二关", "第三关", "第四关", "第五关", "第六关", "第七关"]
	var stage_badge_wrap := CenterContainer.new()
	stage_badge_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stage_badge := PanelContainer.new()
	stage_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_badge.add_theme_stylebox_override("panel", REWARD_UI.make_sub_panel_style(Color(0.784, 0.659, 0.420, 0.72), Color("1b1d23"), 14.0, 3.0 if compact else 4.0))
	var stage_lbl := Label.new()
	stage_lbl.text = "%s · %s" % [room_ordinals[room_idx], CONFIG.ROOM_NAMES[room_idx]]
	stage_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	REWARD_UI.style_kai_label(stage_lbl, 15 if compact else 17, Color("efd9a4"), 2)
	stage_badge.add_child(stage_lbl)
	stage_badge_wrap.add_child(stage_badge)
	col.add_child(stage_badge_wrap)

	# 2. 双列暗金键帽微标操作指南
	var guide_panel := PanelContainer.new()
	guide_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	guide_panel.add_theme_stylebox_override("panel", REWARD_UI.make_sub_panel_style(Color(0.784, 0.659, 0.420, 0.34), Color("101115"), 14.0 if compact else 18.0, 9.0 if compact else 12.0))
	col.add_child(guide_panel)

	var key_grid := GridContainer.new()
	key_grid.columns = 2
	key_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key_grid.add_theme_constant_override("h_separation", 18 if compact else 26)
	key_grid.add_theme_constant_override("v_separation", 6 if compact else 9)
	guide_panel.add_child(key_grid)

	var key_bindings := [
		["WASD", "步法走位"],
		["鼠标", "剑指方向"],
		["左键", "三连剑式"],
		["右键", "掷剑旋斩"],
		["空格", "穿阵身法"],
		["E", "万剑归宗"],
		["M", "静音开关"],
		["Tab", "本命属性"],
	]
	for pair in key_bindings:
		key_grid.add_child(REWARD_UI.make_keycap_badge(str(pair[0]), str(pair[1]), compact))

	# 3. 主按钮：「继续问剑 [Esc]」
	var resume_btn := Button.new()
	resume_btn.name = "PauseResumeButton"
	resume_btn.text = "继续问剑  [Esc]"
	REWARD_UI.style_ink_button(resume_btn, 18 if compact else 20, Vector2(0, 38 if compact else 44))
	resume_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resume_btn.mouse_entered.connect(func(): _play_reward_sfx(_reward_hover_sfx))
	resume_btn.pressed.connect(func():
		_play_reward_sfx(_reward_select_sfx)
		resume_requested.emit())
	col.add_child(resume_btn)

	# 4. 中间三枚深墨金边铭牌开关（镜头 / 背景音乐 / 音频）
	var tools_row := HBoxContainer.new()
	tools_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tools_row.add_theme_constant_override("separation", 8 if compact else 10)
	col.add_child(tools_row)

	var toggle_h := 34 if compact else 38
	var toggle_fs := 13 if compact else 15
	var cam_btn := Button.new()
	cam_btn.text = "镜头：" + ("近景" if run != null and run.close_view else "远景")
	REWARD_UI.style_plaque_toggle_button(cam_btn, toggle_fs, Vector2(0, toggle_h))
	cam_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cam_btn.mouse_entered.connect(func(): _play_reward_sfx(_reward_hover_sfx))
	cam_btn.pressed.connect(func():
		_play_reward_sfx(_reward_select_sfx)
		if run != null:
			run.toggle_view()
		show_pause())
	tools_row.add_child(cam_btn)

	if run != null and is_instance_valid(run.audio_mgr):
		var bgm_btn := Button.new()
		bgm_btn.text = "背景音乐：" + ("关" if run.audio_mgr.bgm_muted else "开")
		REWARD_UI.style_plaque_toggle_button(bgm_btn, toggle_fs, Vector2(0, toggle_h))
		bgm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bgm_btn.mouse_entered.connect(func(): _play_reward_sfx(_reward_hover_sfx))
		bgm_btn.pressed.connect(func():
			_play_reward_sfx(_reward_select_sfx)
			run.audio_mgr.toggle_bgm_mute()
			show_pause())
		tools_row.add_child(bgm_btn)

		var mute_btn := Button.new()
		mute_btn.text = "音频：" + ("静音" if run.audio_mgr.master_muted else "开启")
		REWARD_UI.style_plaque_toggle_button(mute_btn, toggle_fs, Vector2(0, toggle_h))
		mute_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mute_btn.mouse_entered.connect(func(): _play_reward_sfx(_reward_hover_sfx))
		mute_btn.pressed.connect(func():
			_play_reward_sfx(_reward_select_sfx)
			run.audio_mgr.toggle_master_mute()
			show_pause())
		tools_row.add_child(mute_btn)

	# 5. 底部克制暗朱砂红微光边框「重新开始」
	var restart_btn := Button.new()
	restart_btn.name = "PauseRestartButton"
	restart_btn.text = "重新开始"
	REWARD_UI.style_crimson_button(restart_btn, 16 if compact else 17, Vector2(0, 34 if compact else 38))
	restart_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	restart_btn.mouse_entered.connect(func(): _play_reward_sfx(_reward_hover_sfx))
	restart_btn.pressed.connect(func():
		_play_reward_sfx(_reward_select_sfx)
		restart_requested.emit())
	col.add_child(restart_btn)


func _open_sample(scene: String) -> void:
	if not preload("res://scripts/test_runtime.gd").enabled():
		return
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/" + scene + ".tscn")

func _build_stats_skill_plaque(key_text: String, title_text: String, accent: Color, compact: bool) -> VBoxContainer:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", REWARD_UI.make_sub_panel_style(Color(accent.r, accent.g, accent.b, 0.50), Color("191b21"), 11.0 if compact else 14.0, 8.0 if compact else 10.0))

	var inner := VBoxContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_constant_override("separation", 5 if compact else 7)
	card.add_child(inner)

	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override("separation", 7 if compact else 9)
	inner.add_child(head)

	var cap := PanelContainer.new()
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var cap_st := StyleBoxFlat.new()
	cap_st.bg_color = Color("21232b")
	cap_st.border_color = accent
	cap_st.set_border_width_all(1)
	cap_st.set_corner_radius_all(2)
	cap_st.content_margin_left = 6.0
	cap_st.content_margin_right = 6.0
	cap_st.content_margin_top = 1.0
	cap_st.content_margin_bottom = 1.0
	cap.add_theme_stylebox_override("panel", cap_st)
	var k_lbl := Label.new()
	k_lbl.text = key_text
	k_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	REWARD_UI.style_ink_label(k_lbl, 11 if compact else 12, Color("f6e3b0"), 1)
	cap.add_child(k_lbl)
	head.add_child(cap)

	var t_lbl := Label.new()
	t_lbl.text = title_text
	t_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	REWARD_UI.style_ink_label(t_lbl, 15 if compact else 17, accent.lerp(Color("fff6df"), 0.35), 2)
	head.add_child(t_lbl)

	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 1)
	sep.color = Color(accent.r, accent.g, accent.b, 0.24)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(sep)

	return inner

func _make_stat_chip(label_text: String, val_text: String, val_col: Color, compact: bool) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.add_theme_stylebox_override("panel", REWARD_UI.make_sub_panel_style(Color(0.784, 0.659, 0.420, 0.26), Color("111216"), 6.0 if compact else 8.0, 3.0 if compact else 4.0))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 5)
	chip.add_child(row)
	var kl := Label.new()
	kl.text = label_text
	kl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	REWARD_UI.style_ink_label(kl, 12 if compact else 13, Color("bcb4a3"), 1)
	row.add_child(kl)
	var vl := Label.new()
	vl.text = val_text
	vl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	REWARD_UI.style_ink_label(vl, 13 if compact else 15, val_col, 1)
	row.add_child(vl)
	return chip

func show_stats() -> void:
	var sz := root.size if is_instance_valid(root) and root.size.x > 0.0 and root.size.y > 0.0 else Vector2(1280, 720)
	var compact := sz.x < 1100.0 or sz.y < 620.0
	var col := _open_ink_gold_modal(660.0 if compact else 780.0, compact)
	_stats_mode = true

	var rank: int = clampi(player.cultivation, 0, CONFIG.CULTIVATION_NAMES.size() - 1) if is_instance_valid(player) else 0
	var rank_accent := Color("f0cf78") if rank == 2 else (Color("7be6d8") if rank == 1 else Color("d9be83"))

	# 1. 顶部修为与气血概览栏
	var header_row := HBoxContainer.new()
	header_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_row.add_theme_constant_override("separation", 12 if compact else 18)
	col.add_child(header_row)

	var left_title := HBoxContainer.new()
	left_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	left_title.add_theme_constant_override("separation", 8 if compact else 12)
	header_row.add_child(left_title)

	var title_lbl := Label.new()
	title_lbl.text = "本 命 属 性"
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	REWARD_UI.style_calligraphy_title(title_lbl, 32 if compact else 40, Color("f3dda2"), 4 if compact else 5)
	left_title.add_child(title_lbl)

	var seal := REWARD_UI.VermilionSeal.new("道", 22.0 if compact else 26.0)
	seal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	left_title.add_child(seal)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_row.add_child(spacer)

	# 右侧：当前修为境界暗金徽章 + 生命/体力条
	var right_overview := HBoxContainer.new()
	right_overview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_overview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right_overview.add_theme_constant_override("separation", 10 if compact else 14)
	header_row.add_child(right_overview)

	var rank_badge := PanelContainer.new()
	rank_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rank_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rank_badge.add_theme_stylebox_override("panel", REWARD_UI.make_sub_panel_style(rank_accent, Color("1c1e24"), 10.0 if compact else 12.0, 4.0 if compact else 6.0))
	var rank_col := VBoxContainer.new()
	rank_col.alignment = BoxContainer.ALIGNMENT_CENTER
	rank_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rank_col.add_theme_constant_override("separation", 1)
	rank_badge.add_child(rank_col)
	var rk_k := Label.new()
	rk_k.text = "当前境界"
	rk_k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rk_k.mouse_filter = Control.MOUSE_FILTER_IGNORE
	REWARD_UI.style_ink_label(rk_k, 10 if compact else 11, Color("b4aa96"), 1)
	rank_col.add_child(rk_k)
	var rk_v := Label.new()
	rk_v.text = CONFIG.CULTIVATION_NAMES[rank]
	rk_v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rk_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	REWARD_UI.style_kai_label(rk_v, 16 if compact else 19, rank_accent, 2)
	rank_col.add_child(rk_v)
	right_overview.add_child(rank_badge)

	var bars_col := VBoxContainer.new()
	bars_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bars_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bars_col.add_theme_constant_override("separation", 5 if compact else 7)
	right_overview.add_child(bars_col)

	var bar_w := 108.0 if compact else 136.0
	var bar_h := 8.0 if compact else 10.0
	for pair in [
		["生命", player.health, player.max_health, Color("d95353"), Color("f4d8d8")],
		["体力", player.stamina, player.max_stamina, Color("5fd8d4"), Color("d2f2f0")],
	]:
		var b_row := HBoxContainer.new()
		b_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b_row.add_theme_constant_override("separation", 6 if compact else 8)
		var lbl := Label.new()
		lbl.text = str(pair[0])
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		REWARD_UI.style_ink_label(lbl, 12 if compact else 13, pair[4], 1)
		b_row.add_child(lbl)
		var pb := _slim_bar(pair[3], bar_w, bar_h)
		pb.max_value = float(pair[2])
		pb.value = float(pair[1])
		b_row.add_child(pb)
		var val := Label.new()
		val.text = "%.0f/%.0f" % [float(pair[1]), float(pair[2])]
		val.custom_minimum_size = Vector2(54 if compact else 62, 0)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val.mouse_filter = Control.MOUSE_FILTER_IGNORE
		REWARD_UI.style_ink_label(val, 12 if compact else 13, Color("eee9dd"), 1)
		b_row.add_child(val)
		bars_col.add_child(b_row)

	var div_wrap := CenterContainer.new()
	div_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	div_wrap.add_child(REWARD_UI.CloudDivider.new(440.0 if compact else 560.0, Color("c8a86b")))
	col.add_child(div_wrap)

	# 2. 已悟功法展示栏
	var arts_panel := PanelContainer.new()
	arts_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arts_panel.add_theme_stylebox_override("panel", REWARD_UI.make_sub_panel_style(Color(0.784, 0.659, 0.420, 0.36), Color("101115"), 12.0 if compact else 15.0, 7.0 if compact else 10.0))
	col.add_child(arts_panel)

	var arts_col := VBoxContainer.new()
	arts_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arts_col.add_theme_constant_override("separation", 5 if compact else 7)
	arts_panel.add_child(arts_col)

	var arts_head := Label.new()
	arts_head.text = "已悟功法"
	arts_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	REWARD_UI.style_ink_label(arts_head, 13 if compact else 14, Color("d8be85"), 1)
	arts_col.add_child(arts_head)

	var learned: Array[int] = []
	if run != null:
		for index in range(POOL.TITLES.size()):
			if int(run.reward_counts[index]) > 0:
				learned.append(index)

	if learned.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "道心初启 · 尚未领悟功法"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		REWARD_UI.style_kai_label(empty_lbl, 15 if compact else 17, Color("a99874"), 1)
		arts_col.add_child(empty_lbl)
	else:
		var arts_grid := GridContainer.new()
		arts_grid.columns = mini(3, learned.size())
		arts_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		arts_grid.add_theme_constant_override("h_separation", 7 if compact else 10)
		arts_grid.add_theme_constant_override("v_separation", 5 if compact else 7)
		arts_col.add_child(arts_grid)
		for index in learned:
			var count: int = int(run.reward_counts[index])
			var tier: int = POOL.tier(index)
			var edge_col: Color = REWARD_UI.TIER_EDGES[tier]
			var plaque := PanelContainer.new()
			plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
			plaque.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			plaque.add_theme_stylebox_override("panel", REWARD_UI.make_sub_panel_style(Color(edge_col.r, edge_col.g, edge_col.b, 0.72), Color("1a1c22"), 8.0 if compact else 10.0, 4.0 if compact else 5.0))
			var p_col := VBoxContainer.new()
			p_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
			p_col.add_theme_constant_override("separation", 1)
			plaque.add_child(p_col)
			var nm := Label.new()
			nm.text = POOL.TITLES[index] + (" ×%d" % count if count > 1 else "")
			nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
			REWARD_UI.style_ink_label(nm, 12 if compact else 14, Color("f3dfb0"), 1)
			p_col.add_child(nm)
			var ef := Label.new()
			ef.text = REWARD_UI.CARD_SHORT_EFFECTS[index]
			ef.mouse_filter = Control.MOUSE_FILTER_IGNORE
			REWARD_UI.style_ink_label(ef, 11 if compact else 12, Color("b8c2c0"), 1)
			p_col.add_child(ef)
			arts_grid.add_child(plaque)

	# 3. 招式数值卡片化（四栏暗金剑式铭牌，隐藏距离/落点半径/剑痕0.0等内部调试参数）
	var skills_grid := GridContainer.new()
	skills_grid.columns = 2
	skills_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skills_grid.add_theme_constant_override("h_separation", 10 if compact else 14)
	skills_grid.add_theme_constant_override("v_separation", 8 if compact else 12)
	col.add_child(skills_grid)

	var mult: float = player.damage_multiplier if is_instance_valid(player) else 1.0

	# 铭牌 1：[左键] 普攻三连
	var combo_inner := _build_stats_skill_plaque("左键", "普攻三连", Color("d8b770"), compact)
	skills_grid.add_child(combo_inner.get_parent())
	var combo_row := HBoxContainer.new()
	combo_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combo_row.add_theme_constant_override("separation", 5 if compact else 7)
	combo_inner.add_child(combo_row)
	var combo_names := ["一式横斩", "二式斜斩", "三式重劈"]
	for i in range(mini(3, player.combo.stages.size())):
		var data: Dictionary = player.combo.stages[i]
		var dmg_val: float = float(data.damage) * mult
		combo_row.add_child(_make_stat_chip(combo_names[i], _fmt_stat_num(dmg_val), Color("f5dc99"), compact))

	# 铭牌 2：[空格] 穿阵身法
	var dash_inner := _build_stats_skill_plaque("空格", "穿阵身法", Color("7edfd5"), compact)
	skills_grid.add_child(dash_inner.get_parent())
	var dash_row := HBoxContainer.new()
	dash_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dash_row.add_theme_constant_override("separation", 6 if compact else 8)
	dash_inner.add_child(dash_row)
	dash_row.add_child(_make_stat_chip("直击伤害", _fmt_stat_num(CONFIG.DASH_DAMAGE[rank] * mult), Color("9ef2e8"), compact))
	dash_row.add_child(_make_stat_chip("冷却", "%.2f 秒" % CONFIG.DASH_COOLDOWN, Color("e8dec6"), compact))

	# 铭牌 3：[右键] 掷剑旋斩
	var throw_inner := _build_stats_skill_plaque("右键", "掷剑旋斩", Color("d8b770"), compact)
	skills_grid.add_child(throw_inner.get_parent())
	var throw_row := HBoxContainer.new()
	throw_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	throw_row.add_theme_constant_override("separation", 5 if compact else 7)
	throw_inner.add_child(throw_row)
	throw_row.add_child(_make_stat_chip("飞出", _fmt_stat_num(CONFIG.THROW_OUT_DAMAGE[rank] * mult), Color("f5dc99"), compact))
	throw_row.add_child(_make_stat_chip("旋斩", "%s×%d" % [_fmt_stat_num(CONFIG.THROW_SPIN_DAMAGE[rank] * mult), int(CONFIG.THROW_SPIN_TICKS[rank])], Color("f5dc99"), compact))
	throw_row.add_child(_make_stat_chip("回程", _fmt_stat_num(CONFIG.THROW_RETURN_DAMAGE[rank] * mult), Color("f5dc99"), compact))
	var throw_cd := Label.new()
	throw_cd.text = "冷却 %.1f 秒" % CONFIG.THROW_COOLDOWN
	throw_cd.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	throw_cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	REWARD_UI.style_ink_label(throw_cd, 11 if compact else 12, Color("b4ad9c"), 1)
	throw_inner.add_child(throw_cd)

	# 铭牌 4：[E] 万剑归宗
	var rain_inner := _build_stats_skill_plaque("E", "万剑归宗", Color("86e4f2"), compact)
	skills_grid.add_child(rain_inner.get_parent())
	var sword_count: int = int(CONFIG.SWORD_RAIN_COUNT[rank]) * (2 if player.card_level(CARDS.RAIN) > 0 else 1)
	var rain_row := HBoxContainer.new()
	rain_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rain_row.add_theme_constant_override("separation", 6 if compact else 8)
	rain_inner.add_child(rain_row)
	rain_row.add_child(_make_stat_chip("飞剑", "%d 柄" % sword_count, Color("9feef9"), compact))
	rain_row.add_child(_make_stat_chip("单剑伤害", _fmt_stat_num(float(CONFIG.SWORD_RAIN_DAMAGE[rank]) * mult), Color("f5dc99"), compact))
	var rain_cd := Label.new()
	rain_cd.text = "当前境界冷却 %.1f 秒" % player.sword_rain_base_cooldown()
	rain_cd.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rain_cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	REWARD_UI.style_ink_label(rain_cd, 11 if compact else 12, Color("a9cfd4"), 1)
	rain_inner.add_child(rain_cd)

	# 4. 底部暗金按钮：「返回战斗 [Tab / Esc]」
	var back_wrap := CenterContainer.new()
	back_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(back_wrap)
	var back_btn := Button.new()
	back_btn.name = "StatsReturnButton"
	back_btn.text = "返回战斗  [Tab / Esc]"
	REWARD_UI.style_ink_button(back_btn, 17 if compact else 19, Vector2(236 if compact else 276, 36 if compact else 42))
	back_btn.mouse_entered.connect(func(): _play_reward_sfx(_reward_hover_sfx))
	back_btn.pressed.connect(func():
		_play_reward_sfx(_reward_select_sfx)
		resume_requested.emit())
	back_wrap.add_child(back_btn)

func show_run_result(won: bool) -> void:
	if won:
		_show_victory_screen()
		return
	_show_defeat_screen()

func set_defeat_ink(amount: float) -> void:
	defeat_ink.material.set_shader_parameter("amount", amount)
	defeat_ink.visible = amount > 0.0
	if amount > 0.0:
		minimal_layer.hide()

func show_boss_mechanic(pattern: int) -> void:
	boss_mechanic.visible = pattern >= 0
	if pattern >= 0:
		banner_fx.clear()
		boss_mechanic_name.text = BOSS_DOMAIN.NAMES[pattern]
		boss_mechanic_hint.text = ["进青光阵眼，或穿阵躲剑雨", "跟随空隙绕圈，或穿阵过线", "离开猩红斩带，或穿阵闪避"][pattern]

func _show_defeat_screen() -> void:
	_clear_ink_modal()
	set_defeat_ink(1.0)
	for child in overlay_center.get_children():
		overlay_center.remove_child(child)
		child.queue_free()
	overlay.color = Color.TRANSPARENT
	overlay.show()
	overlay_center.show()
	modal_panel = PanelContainer.new()
	modal_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	overlay_center.add_child(modal_panel)
	var column := PrototypeUI.column(12)
	modal_panel.add_child(column)

	var header := REWARD_UI.DefeatTitle.new()
	header.accessibility_name = "败北"
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.custom_minimum_size = Vector2(510, 146)
	column.add_child(header)
	var room_names := ["第一关", "第二关", "第三关", "第四关", "第五关", "第六关", "第七关"]
	var room_title := "剑台心魔" if run.room_index == CONFIG.BOSS_ROOM else CONFIG.ROOM_NAMES[run.room_index]
	var subtitle := Label.new()
	subtitle.text = "止步于 %s · %s" % [room_names[run.room_index], room_title]
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(REWARD_UI.style_ink_label(subtitle, 21, Color("e6e0d5"), 2))
	var kills := Label.new()
	kills.text = "本局斩敌 %d 名" % run.run_kills
	kills.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(REWARD_UI.style_ink_label(kills, 16, Color("c9c6bf"), 2))

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 18)
	column.add_child(actions)
	defeat_retry = REWARD_UI.style_ink_button(Button.new(), 23, Vector2(208, 50))
	defeat_retry.text = "重战本关"
	defeat_retry.focus_mode = Control.FOCUS_ALL
	var focus_ring := StyleBoxFlat.new()
	focus_ring.bg_color = Color.TRANSPARENT
	focus_ring.border_color = Color("d6c9a9")
	focus_ring.set_border_width_all(2)
	focus_ring.set_corner_radius_all(3)
	defeat_retry.add_theme_stylebox_override("focus", focus_ring)
	defeat_retry.pressed.connect(func(): retry_room_requested.emit())
	actions.add_child(defeat_retry)
	var restart := REWARD_UI.style_ink_button(Button.new(), 20, Vector2(184, 50))
	restart.text = "重入仙途"
	restart.focus_mode = Control.FOCUS_ALL
	restart.pressed.connect(func(): restart_requested.emit())
	actions.add_child(restart)
	var home := REWARD_UI.style_ink_button(Button.new(), 15, Vector2(125, 36))
	home.text = "重归山门"
	home.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	home.focus_mode = Control.FOCUS_ALL
	home.pressed.connect(func(): return_to_title_requested.emit())
	column.add_child(home)
	defeat_retry.grab_focus()

func _format_duration(seconds: float) -> String:
	var sec := maxi(0, int(round(seconds)))
	return "%02d:%02d" % [sec / 60, sec % 60]

func _show_victory_screen() -> void:
	_clear_ink_modal()
	set_domain_alert(false)
	clear_screen_banner()
	if is_instance_valid(minimal_layer):
		minimal_layer.visible = false
	for child in overlay_center.get_children():
		overlay_center.remove_child(child)
		child.queue_free()

	overlay.color = Color(0, 0, 0, 0)
	overlay.show()
	overlay_center.visible = true

	var vignette := REWARD_UI.VignetteBackdrop.new()
	vignette.darkness = 0.54
	vignette.edge_alpha = 0.78
	vignette.rebuild()
	overlay.add_child(vignette)
	overlay.move_child(vignette, 0)
	_reward_backdrop = vignette

	_victory_mode = true
	modal_panel = PanelContainer.new()
	modal_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	overlay_center.add_child(modal_panel)

	var main_box := VBoxContainer.new()
	main_box.alignment = BoxContainer.ALIGNMENT_CENTER
	main_box.add_theme_constant_override("separation", 18)
	modal_panel.add_child(main_box)

	# 顶部暗金水墨主标题 + 朱砂「成」印
	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 14)
	main_box.add_child(title_row)

	_victory_title_label = Label.new()
	_victory_title_label.text = "心魔已斩 · 问剑大成"
	REWARD_UI.style_victory_label(_victory_title_label, 48, Color("f2d99f"), 7, Color("090d11"))
	title_row.add_child(_victory_title_label)
	title_row.add_child(REWARD_UI.VermilionSeal.new("成", 34.0))

	var div_center := CenterContainer.new()
	div_center.add_child(REWARD_UI.CloudDivider.new(360.0, Color("d4ae60")))
	main_box.add_child(div_center)

	# 居中战绩墨韵铭牌
	var plaque_wrap := Control.new()
	plaque_wrap.name = "VictoryPlaqueWrap"
	plaque_wrap.custom_minimum_size = Vector2(560, 148)
	plaque_wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	main_box.add_child(plaque_wrap)

	plaque_wrap.add_child(REWARD_UI.VictoryPlaque.new())
	var plaque_margin := MarginContainer.new()
	PrototypeUI.fill(plaque_margin)
	plaque_margin.add_theme_constant_override("margin_left", 28)
	plaque_margin.add_theme_constant_override("margin_right", 28)
	plaque_margin.add_theme_constant_override("margin_top", 20)
	plaque_margin.add_theme_constant_override("margin_bottom", 18)
	plaque_wrap.add_child(plaque_margin)

	var plaque_col := VBoxContainer.new()
	plaque_col.alignment = BoxContainer.ALIGNMENT_CENTER
	plaque_col.add_theme_constant_override("separation", 14)
	plaque_margin.add_child(plaque_col)

	var stats_row := HBoxContainer.new()
	stats_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_row.add_theme_constant_override("separation", 36)
	plaque_col.add_child(stats_row)

	var rank_idx: int = clampi(player.cultivation, 0, CONFIG.CULTIVATION_NAMES.size() - 1) if is_instance_valid(player) else 0
	var stat_items := [
		["通关耗时", _format_duration(run.run_elapsed), Color("f5d27a")],
		["斩敌总数", "%d / %d" % [run.run_kills, CONFIG.run_total()], Color("8ae8de")],
		["当前修为", CONFIG.CULTIVATION_NAMES[rank_idx], Color("f2dfb0")],
	]
	for item in stat_items:
		var cell := VBoxContainer.new()
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.add_theme_constant_override("separation", 4)
		var k_lbl := Label.new()
		k_lbl.text = item[0]
		k_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		REWARD_UI.style_victory_label(k_lbl, 14, Color("9eb4b6"), 2, Color("090d11"))
		var v_lbl := Label.new()
		v_lbl.text = item[1]
		v_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		REWARD_UI.style_victory_label(v_lbl, 24, item[2], 4, Color("090d11"))
		cell.add_child(k_lbl)
		cell.add_child(v_lbl)
		stats_row.add_child(cell)

	var summary_lbl := Label.new()
	summary_lbl.text = reward_summary()
	summary_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	REWARD_UI.style_victory_label(summary_lbl, 13, Color("b4c7c9"), 2, Color("090d11"))
	plaque_col.add_child(summary_lbl)

	# 底部双枚古风暗金按钮
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 26)
	main_box.add_child(btn_row)

	var back_btn := Button.new()
	back_btn.name = "ReturnTitleButton"
	back_btn.text = "重 归 山 门"
	REWARD_UI.style_ink_button(back_btn, 21, Vector2(204, 48))
	back_btn.mouse_entered.connect(func(): _play_reward_sfx(_reward_hover_sfx))
	back_btn.pressed.connect(func():
		_play_reward_sfx(_reward_select_sfx)
		return_to_title_requested.emit())
	btn_row.add_child(back_btn)

	var retry_btn := Button.new()
	retry_btn.name = "RestartJourneyButton"
	retry_btn.text = "再 入 仙 途"
	REWARD_UI.style_ink_button(retry_btn, 21, Vector2(204, 48))
	retry_btn.mouse_entered.connect(func(): _play_reward_sfx(_reward_hover_sfx))
	retry_btn.pressed.connect(func():
		_play_reward_sfx(_reward_select_sfx)
		restart_requested.emit())
	btn_row.add_child(retry_btn)

	var hint_lbl := Label.new()
	hint_lbl.text = "按 Enter / R 再入仙途 · 点击重归山门返回封面"
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	REWARD_UI.style_victory_label(hint_lbl, 13, Color("93a8aa"), 2, Color("090d11"))
	main_box.add_child(hint_lbl)

	_layout_victory_screen()

func _layout_victory_screen() -> void:
	if not is_instance_valid(modal_panel):
		return
	var sz := root.size if is_instance_valid(root) and root.size.x > 0.0 and root.size.y > 0.0 else Vector2(1280, 720)
	var compact := sz.y < 600.0 or sz.x < 1050.0
	if is_instance_valid(_victory_title_label):
		_victory_title_label.add_theme_font_size_override("font_size", 38 if compact else 48)
	var wrap := modal_panel.find_child("VictoryPlaqueWrap", true, false) as Control
	if wrap != null:
		wrap.custom_minimum_size = Vector2(490, 134) if compact else Vector2(560, 148)
	modal_panel.custom_minimum_size.x = minf(680.0, sz.x - 40.0)

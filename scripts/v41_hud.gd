extends "res://scripts/combo_hud.gd"

signal reward_selected(index: int)
const CONFIG = preload("res://scripts/v41_config.gd")
const SkillSlot = preload("res://scripts/v41_skill_slot.gd")

var run
var gm_scroll: ScrollContainer

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

	# 确保全屏红闪与遮罩弹窗始终位于最顶层
	root.move_child(banner_fx, root.get_child_count() - 3)
	root.move_child(hurt_flash, root.get_child_count() - 2)
	root.move_child(overlay, root.get_child_count() - 1)

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

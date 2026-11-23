class_name V41RewardUI
extends RefCounted

const POOL = preload("res://scripts/v41_card_pool.gd")
const INK_BRUSH_SHADER = preload("res://assets/shaders/v41_ink_brush.gdshader")
const TIER_EDGES := [Color("8c8d80"), Color("5db9aa"), Color("d3aa57")]
const TIER_NAMES := ["凡品", "进阶", "仙品"]
const CARD_TAGS := ["剑气", "身法", "破阵", "剑气御剑流", "剑气御剑流", "身法破阵流", "身法破阵流", "剑气御剑流", "剑气御剑流", "身法破阵流"]
const CARD_ICONS := ["sword_aura", "wind_array", "spirit_pill", "flying_sword", "sword_aura", "sword_aura", "wind_array", "flying_sword", "sword_aura", "wind_array"]
const CARD_SHORT_EFFECTS: Array[String] = [
	"三击出穿透剑气",
	"穿阵留影延爆破盾",
	"斩敌回血回体",
	"首击分裂双小剑",
	"三击剑气加宽加远",
	"穿阵后下击必暴击",
	"破盾背斩刷穿阵",
	"飞剑翻倍吸血减冷",
	"三击齐射三道剑气",
	"飞剑残影引雷链",
]

static func calligraphy_face() -> FontFile:
	return preload("res://assets/fonts/STXINGKA.ttf")

static func serif_face() -> FontFile:
	return preload("res://assets/fonts/simkai.ttf")

static func ui_face() -> FontFile:
	return preload("res://assets/fonts/msyh.ttc")

class CastFocus extends Control:
	const DURATION := 0.12
	var fade := 0.0
	var release: Tween

	func play() -> void:
		clear()
		show()
		_set_fade(1.0)
		release = create_tween().set_ignore_time_scale(true)
		release.tween_method(_set_fade, 1.0, 0.0, DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		release.tween_callback(hide)

	func clear() -> void:
		if release != null and release.is_valid():
			release.kill()
		fade = 0.0
		hide()

	func _set_fade(value: float) -> void:
		fade = value
		queue_redraw()

	func _draw() -> void:
		var edge := Color(0.015, 0.025, 0.031, 0.40 * fade)
		for x in [0.0, size.x]:
			var inner: float = x + (115.0 if x == 0.0 else -115.0)
			draw_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x, size.y), Vector2(inner, size.y), Vector2(inner, 0)]),
				PackedColorArray([edge, edge, Color.TRANSPARENT, Color.TRANSPARENT]))
		for y in [0.0, size.y]:
			var inner: float = y + (80.0 if y == 0.0 else -80.0)
			draw_polygon(PackedVector2Array([Vector2(0, y), Vector2(size.x, y), Vector2(size.x, inner), Vector2(0, inner)]),
				PackedColorArray([edge, edge, Color.TRANSPARENT, Color.TRANSPARENT]))

class DefeatTitle extends Control:
	var brush_font := V41RewardUI.calligraphy_face()
	var seal_font := V41RewardUI.serif_face()
	var ink_rect: ColorRect

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		ink_rect = ColorRect.new()
		ink_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ink_rect.show_behind_parent = true
		ink_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ink_rect.offset_left = -80.0
		ink_rect.offset_right = 80.0
		ink_rect.offset_top = -18.0
		ink_rect.offset_bottom = 18.0
		var mat := ShaderMaterial.new()
		mat.shader = INK_BRUSH_SHADER
		mat.set_shader_parameter("mode", 1)
		mat.set_shader_parameter("ink_color", Color(0.02, 0.024, 0.030, 0.90))
		ink_rect.material = mat
		add_child(ink_rect)

	func _draw() -> void:
		var mid := size * 0.5
		var font: Font = brush_font if brush_font.has_char(0x8d25) and brush_font.has_char(0x5317) else preload("res://assets/fonts/msyh.ttc")
		var sfont: Font = seal_font if seal_font.has_char(0x6b8b) else preload("res://assets/fonts/msyh.ttc")
		# 端正稳重、凌厉微错落布局（不做歪斜旋转）
		var sz_a := 106
		var sz_b := 96
		var w_a := font.get_string_size("败", HORIZONTAL_ALIGNMENT_LEFT, -1, sz_a).x
		var w_b := font.get_string_size("北", HORIZONTAL_ALIGNMENT_LEFT, -1, sz_b).x
		var gap := 24.0
		var total_w := w_a + gap + w_b
		var base_x := mid.x - total_w * 0.5 - 12.0
		var base_y := mid.y + 34.0
		_draw_glyph(font, "败", Vector2(base_x, base_y - 3.0), sz_a)
		_draw_glyph(font, "北", Vector2(base_x + w_a + gap, base_y + 4.0), sz_b)
		# 右侧精致裂纹朱砂小印（端正不歪斜）
		var seal_pos := Vector2(base_x + total_w + 18.0, base_y - 36.0).round()
		var stamp := Rect2(seal_pos, Vector2(30.0, 32.0))
		draw_rect(stamp.grow(1.5), Color(0.04, 0.03, 0.03, 0.85))
		draw_rect(stamp, Color("8f2621"))
		draw_rect(stamp.grow(-2.5), Color(0.86, 0.56, 0.48, 0.62), false, 1.0)
		var g_sz := sfont.get_string_size("残", HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
		var gp := Vector2(stamp.position.x + (stamp.size.x - g_sz.x) * 0.5, stamp.position.y + 22.0).round()
		draw_string(sfont, gp, "残", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("f0ddd2"))
		# 细腻裂纹贯穿印角
		draw_polyline(PackedVector2Array([
			stamp.position + Vector2(18, 0),
			stamp.position + Vector2(15, 11),
			stamp.position + Vector2(21, 17),
			stamp.position + Vector2(17, 25),
			stamp.position + Vector2(23, 32),
		]), Color(0.07, 0.05, 0.05, 0.88), 1.6, true)

	func _draw_glyph(font: Font, glyph: String, origin: Vector2, font_size: int) -> void:
		var p := origin.round()
		# 柔和外墨晕 + 浓墨厚描边 + 素白霜灰字心
		draw_string_outline(font, p + Vector2(0, 3), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 14, Color(0.02, 0.025, 0.032, 0.52))
		draw_string_outline(font, p, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 8, Color("0d0f12"))
		draw_string(font, p, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("f0ece2"))

class CoverTitle extends Control:
	var brush_font := V41RewardUI.calligraphy_face()
	var seal_font := V41RewardUI.serif_face()
	var ink_cloud: ColorRect
	var ink_mat: ShaderMaterial
	var clock := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		ink_cloud = ColorRect.new()
		ink_cloud.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ink_cloud.show_behind_parent = true
		ink_cloud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ink_cloud.offset_left = -120.0
		ink_cloud.offset_right = 120.0
		ink_cloud.offset_top = -34.0
		ink_cloud.offset_bottom = 34.0
		ink_mat = ShaderMaterial.new()
		ink_mat.shader = INK_BRUSH_SHADER
		ink_mat.set_shader_parameter("mode", 0)
		ink_mat.set_shader_parameter("ink_color", Color(0.025, 0.038, 0.052, 0.82))
		ink_mat.set_shader_parameter("accent_color", Color(0.92, 0.78, 0.44, 0.18))
		ink_cloud.material = ink_mat
		add_child(ink_cloud)

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		clock += delta
		if is_instance_valid(ink_mat):
			ink_mat.set_shader_parameter("time_sec", clock)

	func _draw() -> void:
		var label := get_parent() as Label
		var scale_factor := (float(label.get_theme_font_size("font_size")) / 76.0) if label != null else 1.0
		var center := size * 0.5
		var font: Font = brush_font if brush_font.has_char(0x95ee) and brush_font.has_char(0x5251) else preload("res://assets/fonts/msyh.ttc")
		var sfont: Font = seal_font if seal_font.has_char(0x5251) else preload("res://assets/fonts/msyh.ttc")
		# 克制、高级的水平微错落书法排版（端正重心，0 角度不歪斜，问略大于剑）
		var sz_wen := roundi(98.0 * scale_factor)
		var sz_jian := roundi(86.0 * scale_factor)
		var w_wen := font.get_string_size("问", HORIZONTAL_ALIGNMENT_LEFT, -1, sz_wen).x
		var w_jian := font.get_string_size("剑", HORIZONTAL_ALIGNMENT_LEFT, -1, sz_jian).x
		var gap := 26.0 * scale_factor
		var total_w := w_wen + gap + w_jian
		var start_x := center.x - total_w * 0.5 - 6.0 * scale_factor
		var base_y := center.y + 32.0 * scale_factor

		_draw_cover_glyph(font, "问", Vector2(start_x, base_y - 4.0 * scale_factor), sz_wen, scale_factor)
		_draw_cover_glyph(font, "剑", Vector2(start_x + w_wen + gap, base_y + 4.0 * scale_factor), sz_jian, scale_factor)

		# 右侧精致暗红朱砂「剑」印（端正印章，带微做旧内细框）
		var seal_w := roundf(24.0 * scale_factor)
		var seal_h := roundf(26.0 * scale_factor)
		var seal_origin := Vector2(start_x + total_w + 14.0 * scale_factor, base_y - seal_h - 4.0 * scale_factor).round()
		var stamp := Rect2(seal_origin, Vector2(seal_w, seal_h))
		draw_rect(stamp.grow(1.5), Color(0.04, 0.03, 0.03, 0.84))
		draw_rect(stamp, Color("992822"))
		draw_rect(stamp.grow(-2.2), Color(0.92, 0.68, 0.56, 0.56), false, 1.0)
		var sf_sz := roundi(14.5 * scale_factor)
		var gs := sfont.get_string_size("剑", HORIZONTAL_ALIGNMENT_LEFT, -1, sf_sz)
		var gp := Vector2(stamp.position.x + (stamp.size.x - gs.x) * 0.5, stamp.position.y + stamp.size.y * 0.74).round()
		draw_string(sfont, gp, "剑", HORIZONTAL_ALIGNMENT_LEFT, -1, sf_sz, Color("f6e4d2"))

	func _draw_cover_glyph(font: Font, glyph: String, origin: Vector2, font_size: int, sf: float) -> void:
		var p := origin.round()
		# 微弱暖金外发光 + 深墨细腻描边 + 素金字心
		draw_string_outline(font, p, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, maxi(10, roundi(14.0 * sf)), Color(0.95, 0.78, 0.38, 0.22))
		draw_string_outline(font, p + Vector2(0, roundf(3.0 * sf)), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, maxi(7, roundi(10.0 * sf)), Color(0.02, 0.03, 0.05, 0.65))
		draw_string_outline(font, p, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, maxi(5, roundi(7.0 * sf)), Color("0d1216"))
		draw_string(font, p, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("f4dfa4"))

static func make_hover_sound() -> AudioStreamWAV:
	return _synth_chime(980.0, 1480.0, 0.075, 0.16)

static func make_select_sound() -> AudioStreamWAV:
	return _synth_chord([587.33, 880.0, 1174.66], 0.24, 0.20)

static func _synth_chime(freq_a: float, freq_b: float, duration: float, gain: float) -> AudioStreamWAV:
	var rate := 22050
	var frames := int(rate * duration)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var phase := 0.0
	for i in range(frames):
		var t := float(i) / float(frames)
		var env := sin(minf(1.0, t * 10.0) * PI * 0.5) * pow(1.0 - t, 2.2)
		var freq := lerpf(freq_a, freq_b, t * 0.5)
		phase += TAU * freq / float(rate)
		var sample := (sin(phase) * 0.72 + sin(phase * 2.02) * 0.28) * env * gain
		var val := clampi(int(sample * 32767.0), -32768, 32767)
		data[i * 2] = val & 0xFF
		data[i * 2 + 1] = (val >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	return stream

static func _synth_chord(freqs: Array, duration: float, gain: float) -> AudioStreamWAV:
	var rate := 22050
	var frames := int(rate * duration)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var t := float(i) / float(frames)
		var env := sin(minf(1.0, t * 14.0) * PI * 0.5) * pow(1.0 - t, 1.8)
		var acc := 0.0
		for k in range(freqs.size()):
			var f := float(freqs[k])
			acc += sin(TAU * f * float(i) / float(rate)) * (0.55 if k == 0 else 0.32)
		var sample := acc * env * gain / float(freqs.size()) * 1.9
		var val := clampi(int(sample * 32767.0), -32768, 32767)
		data[i * 2] = val & 0xFF
		data[i * 2 + 1] = (val >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	return stream

static func style_ink_label(label: Label, size: int, color: Color, outline_size: int = 4, outline_color: Color = Color("0a0e12")) -> Label:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", outline_color)
	label.add_theme_constant_override("outline_size", outline_size)
	return label

static func style_victory_label(label: Label, size: int, color: Color, outline_size: int, outline_color: Color) -> void:
	style_ink_label(label, size, color, outline_size, outline_color)
	label.add_theme_color_override("font_shadow_color", Color(0.02, 0.03, 0.05, 0.72))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 2)

static func style_calligraphy_title(label: Label, font_size: int, color: Color = Color("f2dca4"), outline_size: int = 5) -> Label:
	label.add_theme_font_override("font", calligraphy_face())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("090a0d"))
	label.add_theme_constant_override("outline_size", outline_size)
	label.add_theme_color_override("font_shadow_color", Color(0.01, 0.015, 0.02, 0.78))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label

static func style_kai_label(label: Label, font_size: int, color: Color = Color("d8c495"), outline_size: int = 2) -> Label:
	label.add_theme_font_override("font", serif_face())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("0a0b0e"))
	label.add_theme_constant_override("outline_size", outline_size)
	return label

static func style_plaque_toggle_button(btn: Button, font_size: int = 15, min_size: Vector2 = Vector2(118, 36)) -> Button:
	btn.custom_minimum_size = min_size
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", Color("e8dcc0"))
	btn.add_theme_color_override("font_hover_color", Color("fff6db"))
	btn.add_theme_color_override("font_pressed_color", Color("ffe7a3"))
	btn.add_theme_color_override("font_outline_color", Color("090a0d"))
	btn.add_theme_constant_override("outline_size", 2)
	for pair in [
		["normal", Color("181a1f"), Color("9d824f"), 1, 0],
		["hover", Color("22252c"), Color("e8c982"), 1, 5],
		["pressed", Color("2a2d35"), Color("f6dc96"), 2, 3],
	]:
		var st := StyleBoxFlat.new()
		st.bg_color = pair[1]
		st.border_color = pair[2]
		st.set_border_width_all(int(pair[3]))
		st.set_corner_radius_all(2)
		if int(pair[4]) > 0:
			st.shadow_color = Color(0.84, 0.68, 0.34, 0.24)
			st.shadow_size = int(pair[4])
		st.content_margin_left = 10.0
		st.content_margin_right = 10.0
		st.content_margin_top = 6.0
		st.content_margin_bottom = 6.0
		btn.add_theme_stylebox_override(str(pair[0]), st)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return btn

static func style_crimson_button(btn: Button, font_size: int = 17, min_size: Vector2 = Vector2(200, 38)) -> Button:
	btn.custom_minimum_size = min_size
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", Color("e6b8ae"))
	btn.add_theme_color_override("font_hover_color", Color("ffe6e0"))
	btn.add_theme_color_override("font_pressed_color", Color("ffd0c4"))
	btn.add_theme_color_override("font_outline_color", Color("0c0707"))
	btn.add_theme_constant_override("outline_size", 3)
	for pair in [
		["normal", Color("1b1315"), Color("9c433a"), 1, 3],
		["hover", Color("28171a"), Color("d96858"), 2, 7],
		["pressed", Color("331c20"), Color("ee7d6d"), 2, 4],
	]:
		var st := StyleBoxFlat.new()
		st.bg_color = pair[1]
		st.border_color = pair[2]
		st.set_border_width_all(int(pair[3]))
		st.set_corner_radius_all(3)
		st.shadow_color = Color(0.76, 0.24, 0.19, 0.24 if int(pair[4]) > 4 else 0.12)
		st.shadow_size = int(pair[4])
		st.content_margin_left = 18.0
		st.content_margin_right = 18.0
		st.content_margin_top = 6.0
		st.content_margin_bottom = 6.0
		btn.add_theme_stylebox_override(str(pair[0]), st)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return btn

static func make_sub_panel_style(border_col: Color = Color("c8a86b"), bg_col: Color = Color("181a1f"), pad_x: float = 12.0, pad_y: float = 8.0) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = bg_col
	st.border_color = border_col
	st.set_border_width_all(1)
	st.set_corner_radius_all(2)
	st.content_margin_left = pad_x
	st.content_margin_right = pad_x
	st.content_margin_top = pad_y
	st.content_margin_bottom = pad_y
	return st

static func make_keycap_badge(key_text: String, desc_text: String, compact: bool = false) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 7 if compact else 9)

	var cap := PanelContainer.new()
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var cap_style := StyleBoxFlat.new()
	cap_style.bg_color = Color("1d1f26")
	cap_style.border_color = Color("c8a86b")
	cap_style.set_border_width_all(1)
	cap_style.set_corner_radius_all(2)
	cap_style.content_margin_left = 6.0 if compact else 8.0
	cap_style.content_margin_right = 6.0 if compact else 8.0
	cap_style.content_margin_top = 1.0 if compact else 2.0
	cap_style.content_margin_bottom = 1.0 if compact else 2.0
	cap.add_theme_stylebox_override("panel", cap_style)
	cap.custom_minimum_size = Vector2(56 if compact else 64, 0)

	var k_lbl := Label.new()
	k_lbl.text = key_text
	k_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	k_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	style_ink_label(k_lbl, 12 if compact else 13, Color("f3dda2"), 1)
	cap.add_child(k_lbl)
	row.add_child(cap)

	var d_lbl := Label.new()
	d_lbl.text = desc_text
	d_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	d_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	style_ink_label(d_lbl, 13 if compact else 14, Color("dcd6c7"), 1)
	row.add_child(d_lbl)
	return row

static func style_ink_button(btn: Button, font_size: int = 21, min_size: Vector2 = Vector2(204, 48)) -> Button:
	btn.custom_minimum_size = min_size
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", Color("f2dfb0"))
	btn.add_theme_color_override("font_hover_color", Color("fff6db"))
	btn.add_theme_color_override("font_pressed_color", Color("ffe7a3"))
	btn.add_theme_color_override("font_outline_color", Color("0a0e12"))
	btn.add_theme_constant_override("outline_size", 4)
	for pair in [
		["normal", Color(0.07, 0.10, 0.13, 0.86), Color("b8924d"), 1],
		["hover", Color(0.13, 0.17, 0.21, 0.94), Color("f4d382"), 2],
		["pressed", Color(0.18, 0.22, 0.25, 0.96), Color("ffe49e"), 2],
	]:
		var st := StyleBoxFlat.new()
		st.bg_color = pair[1]
		st.border_color = pair[2]
		st.set_border_width_all(pair[3])
		st.set_corner_radius_all(3)
		st.content_margin_left = 22.0
		st.content_margin_right = 22.0
		st.content_margin_top = 8.0
		st.content_margin_bottom = 8.0
		btn.add_theme_stylebox_override(pair[0], st)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return btn

class VignetteBackdrop extends TextureRect:
	var darkness := 0.64
	var edge_alpha := 0.72
	var tint := Color(0.02, 0.032, 0.045, 1.0)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		stretch_mode = TextureRect.STRETCH_SCALE

	func rebuild() -> void:
		var grad := Gradient.new()
		grad.offsets = PackedFloat32Array([0.0, 0.56, 1.0])
		grad.colors = PackedColorArray([
			Color(tint.r * 1.15, tint.g * 1.15, tint.b * 1.15, darkness * 0.82),
			Color(tint.r, tint.g, tint.b, darkness),
			Color(tint.r * 0.5, tint.g * 0.5, tint.b * 0.5, clampf(darkness + edge_alpha * 0.42, 0.0, 0.94)),
		])
		var tex := GradientTexture2D.new()
		tex.gradient = grad
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.48)
		tex.fill_to = Vector2(0.5, 0.0)
		tex.width = 256
		tex.height = 144
		texture = tex

class VermilionSeal extends Control:
	var glyph := "悟"
	var seal_size := 28.0

	func _init(text := "悟", sz := 28.0) -> void:
		glyph = text
		seal_size = sz
		custom_minimum_size = Vector2(sz, sz)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var outer := Rect2(Vector2.ZERO, size).grow(-1.5)
		draw_rect(outer, Color("9e2722"), true)
		draw_rect(outer, Color("d85a4a"), false, 1.5)
		draw_rect(outer.grow(-3.0), Color(0.95, 0.82, 0.72, 0.45), false, 1.0)
		var kai := V41RewardUI.serif_face()
		var font: Font = kai if (glyph.length() > 0 and kai.has_char(glyph.unicode_at(0))) else V41RewardUI.ui_face()
		var fsize := int(round(seal_size * 0.58))
		var tsize := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_CENTER, -1, fsize)
		var pos := Vector2((size.x - tsize.x) * 0.5, (size.y + font.get_ascent(fsize) - font.get_descent(fsize)) * 0.5 - 1.0)
		draw_string(font, pos.round(), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color("f6e7d4"))

class CloudDivider extends Control:
	var line_color := Color("c8a45c")

	func _init(min_w := 108.0, col := Color("c8a45c")) -> void:
		line_color = col
		custom_minimum_size = Vector2(min_w, 16)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var y := size.y * 0.5
		var cx := size.x * 0.5
		var half := size.x * 0.46
		draw_line(Vector2(cx - half, y), Vector2(cx - 14.0, y), Color(line_color.r, line_color.g, line_color.b, 0.72), 1.4, true)
		draw_line(Vector2(cx + 14.0, y), Vector2(cx + half, y), Color(line_color.r, line_color.g, line_color.b, 0.72), 1.4, true)
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx, y - 5.0), Vector2(cx + 7.0, y), Vector2(cx, y + 5.0), Vector2(cx - 7.0, y),
		]), Color(line_color.r, line_color.g, line_color.b, 0.88))
		draw_arc(Vector2(cx - half + 8.0, y - 3.0), 4.0, PI * 0.15, PI * 1.15, 8, Color(line_color.r, line_color.g, line_color.b, 0.65), 1.2, true)
		draw_arc(Vector2(cx + half - 8.0, y - 3.0), 4.0, -PI * 0.15, PI * 0.85, 8, Color(line_color.r, line_color.g, line_color.b, 0.65), 1.2, true)

class CardEmblem extends Control:
	var kind := "sword_aura"
	var accent := Color("e2b35c")
	var muted := false

	func _init(icon_kind := "sword_aura", col := Color("e2b35c"), is_muted := false) -> void:
		kind = icon_kind
		accent = col
		muted = is_muted
		custom_minimum_size = Vector2(88, 76)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.42
		var gold := Color("767a7d") if muted else accent
		var frost := Color("5b6569") if muted else Color("8ce8de")
		draw_circle(c, r, Color(gold.r, gold.g, gold.b, 0.14))
		draw_arc(c, r, 0.0, TAU, 36, Color(gold.r, gold.g, gold.b, 0.48), 1.5, true)
		draw_arc(c, r - 4.5, 0.0, TAU, 32, Color(frost.r, frost.g, frost.b, 0.28), 1.0, true)
		match kind:
			"sword_aura":
				draw_arc(c + Vector2(2, 2), r * 0.78, -PI * 0.82, PI * 0.18, 22, Color(frost.r, frost.g, frost.b, 0.85), 3.0, true)
				draw_arc(c, r * 0.62, -PI * 0.75, PI * 0.12, 18, Color(gold.r, gold.g, gold.b, 0.92), 2.0, true)
				draw_colored_polygon(PackedVector2Array([
					c + Vector2(-18, 18), c + Vector2(12, -16), c + Vector2(18, -18), c + Vector2(15, -10), c + Vector2(-13, 21),
				]), gold)
				draw_line(c + Vector2(-14, 14), c + Vector2(-4, 24), Color("f5e5bd") if not muted else gold, 2.5, true)
				draw_line(c + Vector2(-18, 22), c + Vector2(-11, 15), gold, 3.0, true)
			"wind_array":
				var pts := PackedVector2Array()
				for i in range(8):
					var ang := i * TAU / 8.0 + PI / 8.0
					pts.append(c + Vector2(cos(ang), sin(ang)) * r * 0.74)
				pts.append(pts[0])
				draw_polyline(pts, Color(gold.r, gold.g, gold.b, 0.78), 1.4, true)
				draw_arc(c, r * 0.52, -PI * 0.9, PI * 0.35, 20, frost, 2.8, true)
				draw_arc(c, r * 0.34, PI * 0.15, PI * 1.35, 16, gold, 2.2, true)
				draw_colored_polygon(PackedVector2Array([
					c + Vector2(r * 0.58, -6), c + Vector2(r * 0.78, 0), c + Vector2(r * 0.56, 7),
				]), frost)
			"spirit_pill":
				for sign_x in [-1.0, 1.0]:
					draw_colored_polygon(PackedVector2Array([
						c + Vector2(0, 16), c + Vector2(sign_x * 20, 12), c + Vector2(sign_x * 13, 3), c + Vector2(0, 9),
					]), Color(frost.r, frost.g, frost.b, 0.72))
				draw_circle(c + Vector2(0, -3), r * 0.36, Color(gold.r, gold.g, gold.b, 0.32))
				draw_circle(c + Vector2(0, -3), r * 0.26, gold)
				draw_circle(c + Vector2(-3.5, -6.5), r * 0.09, Color("fff6dc") if not muted else Color("b4bcbf"))
				draw_arc(c + Vector2(0, -3), r * 0.44, -PI * 0.85, -PI * 0.15, 14, Color(frost.r, frost.g, frost.b, 0.82), 1.6, true)
			"flying_sword":
				draw_arc(c + Vector2(0, 8), r * 0.62, PI * 0.12, PI * 0.88, 16, Color(frost.r, frost.g, frost.b, 0.78), 2.4, true)
				draw_line(c + Vector2(-12, 12), c + Vector2(-4, 20), frost, 1.8, true)
				draw_line(c + Vector2(12, 12), c + Vector2(5, 19), frost, 1.8, true)
				draw_colored_polygon(PackedVector2Array([
					c + Vector2(0, -24), c + Vector2(5, -14), c + Vector2(4, 10), c + Vector2(-4, 10), c + Vector2(-5, -14),
				]), gold)
				draw_line(c + Vector2(0, -21), c + Vector2(0, 8), Color("fff0c8") if not muted else gold, 1.4, true)
				draw_line(c + Vector2(-11, 10), c + Vector2(11, 10), gold, 3.0, true)
				draw_line(c + Vector2(0, 10), c + Vector2(0, 21), gold, 3.2, true)

class JadeCardVisual extends Control:
	var accent := Color("e2b35c")
	var border_col := Color("b8893c")
	var glow_col := Color("f6d487")
	var hovered := false
	var disabled_state := false
	var shimmer := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _process(delta: float) -> void:
		if hovered and not disabled_state:
			shimmer = fmod(shimmer + delta * 1.45, 1.0)
			queue_redraw()
		elif shimmer > 0.0:
			shimmer = 0.0
			queue_redraw()

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		var bg := Color("12171c") if disabled_state else (Color("18222a") if hovered else Color("111920"))
		var outer := Color("495259") if disabled_state else (glow_col if hovered else border_col)
		var inner := Color("333a40") if disabled_state else Color(accent.r, accent.g, accent.b, 0.85 if hovered else 0.42)
		draw_rect(Rect2(Vector2(0, 5), size), Color(0.01, 0.015, 0.02, 0.42), true)
		draw_rect(rect, bg, true)
		draw_rect(Rect2(0, 0, size.x, size.y * 0.36), Color(accent.r, accent.g, accent.b, 0.04 if disabled_state else (0.12 if hovered else 0.06)), true)
		draw_rect(Rect2(0, size.y * 0.68, size.x, size.y * 0.32), Color(0.02, 0.03, 0.04, 0.34), true)
		draw_rect(rect.grow(-1.0), outer, false, 2.0 if hovered and not disabled_state else 1.4)
		var inner_rect := rect.grow(-6.0)
		draw_rect(inner_rect, inner, false, 1.0)
		var k := 9.0
		for corner in [
			[inner_rect.position, Vector2(1, 0), Vector2(0, 1)],
			[Vector2(inner_rect.end.x, inner_rect.position.y), Vector2(-1, 0), Vector2(0, 1)],
			[Vector2(inner_rect.position.x, inner_rect.end.y), Vector2(1, 0), Vector2(0, -1)],
			[inner_rect.end, Vector2(-1, 0), Vector2(0, -1)],
		]:
			var p: Vector2 = corner[0]
			draw_line(p, p + corner[1] * k, outer, 1.8, true)
			draw_line(p, p + corner[2] * k, outer, 1.8, true)
		if hovered and not disabled_state:
			var sweep_x := lerpf(-size.x * 0.2, size.x * 1.2, shimmer)
			draw_line(Vector2(clampf(sweep_x - 36.0, 2.0, size.x - 2.0), 1.5), Vector2(clampf(sweep_x + 36.0, 2.0, size.x - 2.0), 1.5), Color(1.0, 0.96, 0.82, 0.92), 2.5, true)
			draw_line(Vector2(clampf(size.x - sweep_x - 36.0, 2.0, size.x - 2.0), size.y - 1.5), Vector2(clampf(size.x - sweep_x + 36.0, 2.0, size.x - 2.0), size.y - 1.5), Color(1.0, 0.96, 0.82, 0.85), 2.5, true)
			draw_rect(rect.grow(-1.0), Color(glow_col.r, glow_col.g, glow_col.b, 0.14), false, 4.0)

class SelectFlashFX extends Control:
	var origin := Vector2.ZERO
	var card_size := Vector2(220, 320)
	var accent := Color("f5d27a")
	var progress := 0.0

	func _init(rect: Rect2, col: Color) -> void:
		origin = rect.get_center()
		card_size = rect.size
		accent = col
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _process(delta: float) -> void:
		progress += delta / 0.28
		if progress >= 1.0:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var t := clampf(progress, 0.0, 1.0)
		var inv := 1.0 - t
		var cur := card_size * lerpf(1.0, 0.18, t * t)
		var r := Rect2(origin - cur * 0.5, cur)
		draw_rect(r, Color(accent.r, accent.g, accent.b, 0.34 * inv), true)
		draw_rect(r, Color(1.0, 0.96, 0.84, 0.92 * inv), false, 2.5)
		draw_arc(origin, lerpf(28.0, maxf(card_size.x, card_size.y) * 0.62, 1.0 - inv * inv), 0.0, TAU, 36, Color(accent.r, accent.g, accent.b, 0.65 * inv), 2.0, true)

class VictoryPlaque extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.055, 0.075, 0.095, 0.84), true)
		draw_rect(Rect2(0, 0, size.x, size.y * 0.35), Color(0.88, 0.72, 0.38, 0.07), true)
		draw_rect(r.grow(-1.0), Color("c59e54"), false, 1.6)
		var inner := r.grow(-6.0)
		draw_rect(inner, Color(0.82, 0.68, 0.38, 0.42), false, 1.0)
		var k := 11.0
		for c in [
			[inner.position, Vector2(1, 0), Vector2(0, 1)],
			[Vector2(inner.end.x, inner.position.y), Vector2(-1, 0), Vector2(0, 1)],
			[Vector2(inner.position.x, inner.end.y), Vector2(1, 0), Vector2(0, -1)],
			[inner.end, Vector2(-1, 0), Vector2(0, -1)],
		]:
			var p: Vector2 = c[0]
			draw_line(p, p + c[1] * k, Color("f0cf80"), 1.8, true)
			draw_line(p, p + c[2] * k, Color("f0cf80"), 1.8, true)

class InkGoldPanelVisual extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		if size.x < 16.0 or size.y < 16.0:
			return
		var r := Rect2(Vector2.ZERO, size)
		# 深玄墨主底色 #141518 + 顶部极淡暖金气晕 + 底部沉墨微压
		draw_rect(r, Color(0.078, 0.082, 0.094, 0.96), true)
		draw_rect(Rect2(1.0, 1.0, size.x - 2.0, minf(size.y * 0.30, 118.0)), Color(0.78, 0.66, 0.42, 0.055), true)
		draw_rect(Rect2(1.0, size.y * 0.78, size.x - 2.0, size.y * 0.22 - 1.0), Color(0.02, 0.022, 0.03, 0.36), true)

		# 暗金双线描边 #C8A86B
		var outer_gold := Color("c8a86b")
		var inner_gold := Color(0.784, 0.659, 0.420, 0.46)
		var bright_gold := Color("ead092")
		draw_rect(r.grow(-1.0), outer_gold, false, 1.8)
		var inner := r.grow(-7.0)
		draw_rect(inner, inner_gold, false, 1.0)

		# 四角精致国风回纹装饰（严格位于面板内框，绝不越出外缘）
		var arm := 16.0
		var step := 6.0
		var hook := 4.0
		for c in [
			[inner.position, Vector2(1, 0), Vector2(0, 1)],
			[Vector2(inner.end.x, inner.position.y), Vector2(-1, 0), Vector2(0, 1)],
			[Vector2(inner.position.x, inner.end.y), Vector2(1, 0), Vector2(0, -1)],
			[inner.end, Vector2(-1, 0), Vector2(0, -1)],
		]:
			var p: Vector2 = c[0]
			var dx: Vector2 = c[1]
			var dy: Vector2 = c[2]
			# 外折角亮金托线
			draw_line(p, p + dx * arm, bright_gold, 1.8, false)
			draw_line(p, p + dy * arm, bright_gold, 1.8, false)
			# 内回纹小折钩
			var q: Vector2 = p + dx * step + dy * step
			draw_polyline(PackedVector2Array([
				p + dx * (step + hook) + dy * 0.0,
				p + dx * (step + hook) + dy * step,
				q,
				p + dx * step + dy * (step + hook),
				p + dx * 0.0 + dy * (step + hook),
			]), Color(0.88, 0.75, 0.48, 0.78), 1.2, false)
			draw_rect(Rect2((p + dx * 2.5 + dy * 2.5) - Vector2(1.2, 1.2), Vector2(2.4, 2.4)), bright_gold, true)

class DomainAlertOverlay extends Control:
	var intensity := 0.0
	var clock := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		visible = false

	func set_alert(active: bool) -> void:
		if active:
			visible = true
			intensity = maxf(intensity, 0.85)
		else:
			intensity = 0.0
			visible = false
		queue_redraw()

	func _process(delta: float) -> void:
		if not visible:
			return
		clock += delta
		queue_redraw()

	func _draw() -> void:
		if intensity <= 0.01:
			return
		var pulse := 0.65 + 0.35 * sin(clock * 8.5)
		var a := intensity * pulse
		var w := size.x
		var h := size.y
		for i in range(6):
			var t := float(6 - i) / 6.0
			var edge := 16.0 + float(i) * 14.0
			var c := Color(0.68, 0.07, 0.11, 0.14 * t * a)
			draw_rect(Rect2(0, 0, w, edge), c, true)
			draw_rect(Rect2(0, h - edge, w, edge), c, true)
			draw_rect(Rect2(0, 0, edge * 1.2, h), c, true)
			draw_rect(Rect2(w - edge * 1.2, 0, edge * 1.2, h), c, true)
		draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), Color(0.95, 0.24, 0.22, 0.65 * a), false, 2.5)

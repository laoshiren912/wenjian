class_name PrototypeUI
extends RefCounted

static func label(text: String, size: int = 18, color: Color = Color("dce8e8")) -> Label:
	var item := Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size", size)
	item.add_theme_color_override("font_color", color)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return item

static func style(color: Color, border: Color = Color("38525b")) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(6)
	box.content_margin_left = 18.0
	box.content_margin_right = 18.0
	box.content_margin_top = 14.0
	box.content_margin_bottom = 14.0
	return box

static func button(text: String, callback: Callable, height: float = 48.0) -> Button:
	var item := Button.new()
	item.text = text
	item.custom_minimum_size.y = height
	item.add_theme_font_size_override("font_size", 19)
	item.add_theme_color_override("font_color", Color("e5efeb"))
	item.add_theme_stylebox_override("normal", style(Color("243b43")))
	item.add_theme_stylebox_override("hover", style(Color("355864"), Color("7dddc9")))
	item.add_theme_stylebox_override("focus", style(Color(0, 0, 0, 0), Color("9cebd7")))
	item.add_theme_stylebox_override("pressed", style(Color("46746c")))
	for state in ["normal", "hover", "focus", "pressed"]:
		var box := item.get_theme_stylebox(state) as StyleBoxFlat
		box.content_margin_top = 8.0
		box.content_margin_bottom = 8.0
	item.pressed.connect(callback)
	return item

static func panel() -> PanelContainer:
	var item := PanelContainer.new()
	item.add_theme_stylebox_override("panel", style(Color("152831")))
	return item

static func column(separation: int = 12) -> VBoxContainer:
	var item := VBoxContainer.new()
	item.add_theme_constant_override("separation", separation)
	return item

static func fill(control: Control) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

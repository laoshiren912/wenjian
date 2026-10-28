extends Control

signal chosen(index: int)
var title_label: Label
var choices: Array[Button] = []
var accepting: bool = false
var panel: PanelContainer
var choice_layout: BoxContainer

func _ready() -> void:
	PrototypeUI.fill(self)
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.045, 0.065, 0.93)
	PrototypeUI.fill(shade)
	add_child(shade)
	var center := CenterContainer.new()
	PrototypeUI.fill(center)
	add_child(center)
	panel = PrototypeUI.panel()
	center.add_child(panel)
	var box := PrototypeUI.column(12)
	panel.add_child(box)
	title_label = PrototypeUI.label("升级", 32, Color("91e6cb"))
	box.add_child(title_label)
	box.add_child(PrototypeUI.label("战斗已暂停 · 选择一项强化后继续", 18))
	choice_layout = BoxContainer.new()
	choice_layout.add_theme_constant_override("separation", 10)
	box.add_child(choice_layout)
	for index in range(3):
		var button := PrototypeUI.button("", _choose.bind(index), 174)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 18)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choice_layout.add_child(button)
		choices.append(button)
	var help := PrototypeUI.label("鼠标点击或按 1 / 2 / 3 选择 · 选择后继续战斗", 16, Color("9eb7bc"))
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(help)
	resized.connect(_update_layout)
	get_window().size_changed.connect(_update_layout)
	_update_layout()
	hide()

func _update_layout() -> void:
	# canvas_items may keep a 1280-wide canvas in a 960-wide physical window.
	var narrow: bool = minf(size.x, get_window().size.x) < 1100
	choice_layout.vertical = narrow
	panel.custom_minimum_size.x = minf(700 if narrow else 1000, size.x - 48)
	for button in choices:
		button.custom_minimum_size = Vector2(0, 100 if narrow else 174)

func show_choices(player: SurvivorPlayer) -> void:
	title_label.text = "等级 %d  /  选择强化" % player.level
	choices[0].text = "1   力量\n伤害倍率 +20 个百分点\n%.0f%% → %.0f%%" % [player.damage_multiplier * 100, (player.damage_multiplier + 0.2) * 100]
	choices[1].text = "2   迅捷\n攻速倍率 +15 个百分点\n%.0f%% → %.0f%%" % [player.attack_speed_multiplier * 100, (player.attack_speed_multiplier + 0.15) * 100]
	choices[2].text = "3   活力\n最大生命 +25 · 恢复 40 生命\n上限 %.0f → %.0f" % [player.max_health, player.max_health + 25]
	accepting = true
	show()
	_update_layout()
	choices[0].grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not accepting:
		return
	for index in range(3):
		if event.is_action_pressed("upgrade_%d" % (index + 1)):
			get_viewport().set_input_as_handled()
			_choose(index)
			return

func _choose(index: int) -> void:
	if not accepting:
		return
	accepting = false
	hide()
	chosen.emit(index)

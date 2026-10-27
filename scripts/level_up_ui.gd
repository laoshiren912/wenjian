extends Control

signal chosen(index: int)
var title_label: Label
var choices: Array[Button] = []
var accepting: bool = false

func _ready() -> void:
	PrototypeUI.fill(self)
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.045, 0.065, 0.93)
	PrototypeUI.fill(shade)
	add_child(shade)
	var center := CenterContainer.new()
	PrototypeUI.fill(center)
	add_child(center)
	var panel := PrototypeUI.panel()
	panel.custom_minimum_size = Vector2(940, 0)
	center.add_child(panel)
	var box := PrototypeUI.column(22)
	panel.add_child(box)
	title_label = PrototypeUI.label("升级", 32, Color("91e6cb"))
	box.add_child(title_label)
	box.add_child(PrototypeUI.label("战斗已暂停 · 选择一项强化后继续", 18))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	for index in range(3):
		var button := PrototypeUI.button("", _choose.bind(index), 205)
		button.custom_minimum_size.x = 285.0
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(button)
		choices.append(button)
	box.add_child(PrototypeUI.label("也可按数字键 1 / 2 / 3 选择。升级期间不消耗存活时间。", 16, Color("9eb7bc")))
	hide()

func show_choices(player: SurvivorPlayer) -> void:
	title_label.text = "等级 %d  /  选择强化" % player.level
	choices[0].text = "1   力量\n\n伤害倍率 +20 个百分点\n%.0f%% → %.0f%%" % [player.damage_multiplier * 100, (player.damage_multiplier + 0.2) * 100]
	choices[1].text = "2   迅捷\n\n攻速倍率 +15 个百分点\n%.0f%% → %.0f%%" % [player.attack_speed_multiplier * 100, (player.attack_speed_multiplier + 0.15) * 100]
	choices[2].text = "3   活力\n\n最大生命 +25 · 恢复 40 生命\n上限 %.0f → %.0f" % [player.max_health, player.max_health + 25]
	accepting = true
	show()
	choices[0].grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not accepting:
		return
	for index in range(3):
		if event.is_action_pressed("weapon_%d" % (index + 1)):
			get_viewport().set_input_as_handled()
			_choose(index)
			return

func _choose(index: int) -> void:
	if not accepting:
		return
	accepting = false
	hide()
	chosen.emit(index)

extends Control

signal chosen(index: int)
signal deferred
var allow_defer: bool = true
var close_button: Button
var help_label: Label
var title_label: Label
var choices: Array[Button] = []
var accepting: bool = false
var panel: PanelContainer
var choice_layout: BoxContainer
var offered: Array[int] = []
var reward_title: String = ""
var input_delay: float = 0.0

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
	close_button = PrototypeUI.button("× 暂不选择", func(): deferred.emit(), 30)
	close_button.add_theme_font_size_override("font_size", 16)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	box.add_child(close_button)
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
	help_label = help
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
	close_button.visible = allow_defer
	help_label.text = "鼠标点击或按 1 / 2 / 3 选择" + (" · 可暂存稍后选择" if allow_defer else " · 清层后进入奖励和商店流程")
	title_label.text = reward_title if not reward_title.is_empty() else "等级 %d  /  选择强化" % player.level
	var descriptions := ["力量\n伤害倍率 +20 个百分点", "迅捷\n攻速倍率 +15 个百分点", "活力\n最大生命 +25，恢复 40", "", "", "远行\n翻滚距离 +35"]
	match player.profession_index:
		0:
			descriptions[3] = "横扫\n剑可额外击中 1 个目标"
			descriptions[4] = "宽刃\n剑攻击角度 +30°"
		1:
			descriptions[3] = "长锋\n长矛攻击距离 +25"
			descriptions[4] = "扩刺\n长矛攻击角度 +20°"
		2:
			descriptions[3] = "齐射\n每次额外射出 1 支箭"
			descriptions[4] = "疾矢\n箭矢速度 +120"
	var pool: Array[int] = [0, 1, 2]
	if not reward_title.is_empty():
		pool.assign([3, 4, 5])
	pool.shuffle()
	offered = pool.slice(0, 3)
	for index in range(3):
		choices[index].text = "%d   %s\n可重复叠加" % [index + 1, descriptions[offered[index]]]
	accepting = false
	input_delay = 0.35
	for button in choices:
		button.disabled = true
	show()
	_update_layout()

func _process(delta: float) -> void:
	if visible and not accepting:
		input_delay = maxf(0.0, input_delay - delta)
		if input_delay <= 0.0 and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			accepting = true
			for button in choices:
				button.disabled = false
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
	chosen.emit(offered[index])

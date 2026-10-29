extends CanvasLayer

signal start_requested
signal profession_requested(index: int)
signal restart_requested
signal stats_requested
signal pause_requested
signal resume_requested
signal purchase_requested(index: int)
signal shop_category_requested(index: int)
signal upgrade_continue_requested
signal shop_continue_requested
signal next_floor_requested
signal upgrades_requested

var player: SurvivorPlayer
var root: Control
var overlay: ColorRect
var overlay_center: CenterContainer
var health_bar: ProgressBar
var stamina_bar: ProgressBar
var xp_bar: ProgressBar
var health_text: Label
var stamina_text: Label
var xp_text: Label
var weapon_text: Label
var weapon_detail: Label
var timer_text: Label
var status_text: Label
var hurt_flash: ColorRect
var notice: Label
var notice_time: float = 0.0
var combat_panels: Array[Control] = []
var profession_buttons: Array[Button] = []
var profession_layout: BoxContainer
var start_button: Button
var modal_panel: PanelContainer
var tower_floor: int = 1
var tower_gold: int = 0
var transition_button: Button
var transition_delay: float = 0.0
var upgrades_button: Button
@onready var level_ui = $LevelUpUI

func _ready() -> void:
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PrototypeUI.fill(root)
	add_child(root)
	var margin := MarginContainer.new()
	PrototypeUI.fill(margin)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 15)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(margin)
	var layout := PrototypeUI.column(8)
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(layout)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(top)
	var vitals := _combat_panel()
	vitals.custom_minimum_size.x = 230.0
	vitals.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(vitals)
	combat_panels.append(vitals)
	var bars := PrototypeUI.column(3)
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitals.add_child(bars)
	health_text = PrototypeUI.label("生命", 15)
	bars.add_child(health_text)
	health_bar = _bar(Color("e68080"))
	bars.add_child(health_bar)
	stamina_text = PrototypeUI.label("体力", 15)
	bars.add_child(stamina_text)
	stamina_bar = _bar(Color("81d9ba"))
	bars.add_child(stamina_bar)
	var center := PrototypeUI.column(3)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(center)
	timer_text = PrototypeUI.label("00:00 / 03:00", 26)
	timer_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(timer_text)
	status_text = PrototypeUI.label("生存至 03:00 完成试炼", 14, Color("a6c0c1"))
	status_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(status_text)
	var actions := _combat_panel()
	actions.custom_minimum_size.x = 230
	actions.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(actions)
	combat_panels.append(actions)
	var action_box := PrototypeUI.column(5)
	action_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actions.add_child(action_box)
	for button in [PrototypeUI.button("角色属性  [Tab]", func(): stats_requested.emit(), 32), PrototypeUI.button("暂停  [Esc]", func(): pause_requested.emit(), 32)]:
		button.add_theme_font_size_override("font_size", 16)
		action_box.add_child(button)
	upgrades_button = PrototypeUI.button("待选强化", func(): upgrades_requested.emit(), 32)
	upgrades_button.add_theme_font_size_override("font_size", 16)
	action_box.add_child(upgrades_button)
	upgrades_button.hide()
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(spacer)
	notice = PrototypeUI.label("", 19, Color("9ae7d5"))
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.custom_minimum_size.y = 26
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(notice)
	var equipment := _combat_panel()
	equipment.custom_minimum_size.x = 600
	equipment.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	layout.add_child(equipment)
	combat_panels.append(equipment)
	var equipment_box := PrototypeUI.column(4)
	equipment_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	equipment.add_child(equipment_box)
	var detail_row := HBoxContainer.new()
	detail_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_row.add_theme_constant_override("separation", 12)
	equipment_box.add_child(detail_row)
	weapon_text = PrototypeUI.label("剑士 · 剑", 18, Color("e5cd95"))
	detail_row.add_child(weapon_text)
	weapon_detail = PrototypeUI.label("", 15, Color("b4d1d4"))
	detail_row.add_child(weapon_detail)
	var experience := HBoxContainer.new()
	experience.mouse_filter = Control.MOUSE_FILTER_IGNORE
	experience.add_theme_constant_override("separation", 12)
	equipment_box.add_child(experience)
	xp_text = PrototypeUI.label("经验", 14)
	experience.add_child(xp_text)
	xp_bar = _bar(Color("92b9f5"))
	xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	experience.add_child(xp_bar)
	hurt_flash = ColorRect.new()
	PrototypeUI.fill(hurt_flash)
	hurt_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hurt_flash.color = Color(0.9, 0.15, 0.15, 0.0)
	root.add_child(hurt_flash)
	overlay = ColorRect.new()
	PrototypeUI.fill(overlay)
	overlay.color = Color(0.02, 0.035, 0.05, 0.93)
	root.add_child(overlay)
	overlay_center = CenterContainer.new()
	PrototypeUI.fill(overlay_center)
	overlay.add_child(overlay_center)
	move_child(level_ui, get_child_count() - 1)
	root.resized.connect(_resize_modal)
	get_window().size_changed.connect(_resize_modal)

func _combat_panel() -> PanelContainer:
	var panel := PrototypeUI.panel()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := PrototypeUI.style(Color("152831"))
	background.content_margin_left = 10
	background.content_margin_right = 10
	background.content_margin_top = 7
	background.content_margin_bottom = 7
	panel.add_theme_stylebox_override("panel", background)
	return panel

func _resize_modal() -> void:
	if is_instance_valid(modal_panel):
		var choosing: bool = is_instance_valid(profession_layout)
		var narrow: bool = minf(root.size.x, get_window().size.x) < 1100
		modal_panel.custom_minimum_size.x = minf(1000 if choosing and not narrow else 760, root.size.x - 48)
		if choosing:
			profession_layout.vertical = narrow
			for button in profession_buttons:
				button.custom_minimum_size = Vector2(0, 90 if narrow else 150)

func _modal_label(text: String, size: int = 18, color: Color = Color("dce8e8")) -> Label:
	var label := PrototypeUI.label(text, size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 8)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := PrototypeUI.style(Color("0c1921"), Color("0c1921"))
	var fill := PrototypeUI.style(color, color)
	for box in [background, fill]:
		box.content_margin_top = 0.0
		box.content_margin_bottom = 0.0
		box.content_margin_left = 0.0
		box.content_margin_right = 0.0
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	return bar

func update_game(elapsed: float, kills: int, duration: float) -> void:
	if not is_instance_valid(player):
		return
	health_text.text = "生命  %.0f / %.0f" % [player.health, player.max_health]
	health_bar.max_value = player.max_health
	health_bar.value = player.health
	stamina_text.text = "体力（翻滚）  %.0f / %.0f" % [player.stamina, player.max_stamina]
	stamina_bar.max_value = player.max_stamina
	stamina_bar.value = player.stamina
	xp_text.text = "Lv.%d    经验  %d / %d" % [player.level, player.experience, player.next_level_xp]
	xp_bar.max_value = player.next_level_xp
	xp_bar.value = player.experience
	weapon_text.text = "%s · %s" % [SurvivorPlayer.PROFESSIONS[player.profession_index].name, SurvivorWeapon.DATA[player.weapon.selected].name]
	var weapon_data: Dictionary = SurvivorWeapon.DATA[player.weapon.selected]
	weapon_detail.text = "%s · 每目标伤害 %.0f" % [weapon_data.role, float(weapon_data.damage) * player.damage_multiplier]
	if player.weapon.selected == 2:
		weapon_detail.text += " · 射后慢移" if player.is_bow_recovering() else " · 停火可全速移动"

func update_tower(floor_number: int, remaining: int, gold: int, direction: Vector2, pending: int = 0) -> void:
	tower_floor = floor_number
	tower_gold = gold
	var arrow := ""
	if not direction.is_zero_approx():
		var arrows := ["→", "↘", "↓", "↙", "←", "↖", "↑", "↗"]
		arrow = arrows[posmod(roundi(direction.angle() / (PI / 4.0)), 8)]
	timer_text.text = "第 %d 层  ·  剩余 %d" % [floor_number, remaining]
	status_text.text = "金币 %d  ·  最近敌人 %s%s" % [gold, arrow, "  ·  待出现 %d" % pending if pending > 0 else ""]

func _process(delta: float) -> void:
	if is_instance_valid(transition_button) and transition_button.disabled:
		transition_delay = maxf(0.0, transition_delay - delta)
		if transition_delay <= 0.0 and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			transition_button.disabled = false
			transition_button.grab_focus()
	hurt_flash.color.a = maxf(0.0, hurt_flash.color.a - delta * 0.8)
	if notice_time > 0.0:
		notice_time -= delta
		if notice_time <= 0.0:
			notice.text = ""

func show_notice(text: String) -> void:
	notice.text = text
	notice_time = 2.5

func update_pending_upgrades(count: int) -> void:
	upgrades_button.visible = count > 0
	upgrades_button.text = "待选强化 ×%d" % count

func flash_damage() -> void:
	hurt_flash.color.a = 0.18

func _screen(title: String, subtitle: String) -> VBoxContainer:
	transition_button = null
	profession_buttons.clear()
	profession_layout = null
	start_button = null
	for child in overlay_center.get_children():
		overlay_center.remove_child(child)
		child.queue_free()
	modal_panel = PrototypeUI.panel()
	overlay_center.add_child(modal_panel)
	_resize_modal()
	var box := PrototypeUI.column(12)
	modal_panel.add_child(box)
	box.add_child(_modal_label(title, 32, Color("96e5cf")))
	box.add_child(_modal_label(subtitle, 17, Color("aec4c7")))
	overlay.show()
	return box

func show_start() -> void:
	var box := _screen("通天塔 · 选择职业", "清理每层敌人，获得强化与装备，挑战第 4 层 Boss · 本局武器固定")
	profession_layout = BoxContainer.new()
	profession_layout.add_theme_constant_override("separation", 10)
	box.add_child(profession_layout)
	for index in range(SurvivorPlayer.PROFESSIONS.size()):
		var data: Dictionary = SurvivorPlayer.PROFESSIONS[index]
		var weapon: Dictionary = SurvivorWeapon.DATA[int(data.weapon)]
		var text := "%d  %s · %s\n%s\n生命 %.0f · 移速 %.0f" % [index + 1, data.name, weapon.name, weapon.role, data.health, data.speed]
		var button := PrototypeUI.button(text, func(): profession_requested.emit(index), 150)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 18)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		profession_layout.add_child(button)
		profession_buttons.append(button)
	box.add_child(_modal_label("WASD 移动 · 鼠标瞄准 · 左键攻击 · Space 翻滚\n剑/矛按住攻击减速 20%%；弓每次射击后 %.2f 秒移速为 %.0f%%\n翻滚耗 %.0f 体力且无额外无敌帧；击败敌人直接获得经验。" % [player.bow_shot_move_duration, player.bow_shot_move_multiplier * 100.0, player.roll_stamina_cost], 16))
	start_button = PrototypeUI.button("开始试炼  [Enter]", func(): start_requested.emit(), 48)
	box.add_child(start_button)
	select_profession(0)
	_resize_modal()
	start_button.grab_focus()

func select_profession(index: int) -> void:
	for other in range(profession_buttons.size()):
		var button := profession_buttons[other]
		var selected: bool = other == index
		var style := button.get_theme_stylebox("normal") as StyleBoxFlat
		style.bg_color = Color("2b5149") if selected else Color("243b43")
		style.border_color = Color("9cebd7") if selected else Color("38525b")
		button.add_theme_color_override("font_color", Color("fff0bd") if selected else Color("e5efeb"))

func hide_screen() -> void:
	overlay.hide()

func show_upgrade_prompt(title: String, subtitle: String) -> void:
	var box := _screen(title, subtitle)
	box.add_child(_modal_label("松开攻击键，准备好后继续。", 18))
	transition_button = PrototypeUI.button("继续选择强化", func(): upgrade_continue_requested.emit())
	transition_button.disabled = true
	transition_delay = 0.4
	box.add_child(transition_button)

func show_shop_prompt(floor_number: int, gold: int) -> void:
	var box := _screen("第 %d 层结算" % floor_number, "清层强化已选择 · 当前金币 %d" % gold)
	box.add_child(_modal_label("准备好后进入商店，选择装备或保留金币。", 18))
	transition_button = PrototypeUI.button("进入商店", func(): shop_continue_requested.emit())
	transition_button.disabled = true
	transition_delay = 0.4
	box.add_child(transition_button)

func show_pause() -> void:
	var box := _screen("已暂停", "战斗已暂停。")
	box.add_child(_modal_label("WASD 移动 · 鼠标瞄准 · 按住左键攻击 · Space 翻滚\nTab 查看属性 · Esc 继续战斗 · 本局武器固定\n\n红弧与红圈是攻击预警；紫色标记是远程怪。\n击败敌人直接获得经验，升级时点击或按 1 / 2 / 3 选择强化。", 18))
	var button := PrototypeUI.button("继续  [Esc]", func(): resume_requested.emit())
	box.add_child(button)
	box.add_child(PrototypeUI.button("重新开始", func(): restart_requested.emit()))
	button.grab_focus()

func show_stats() -> void:
	var box := _screen("%s · 角色属性 / Lv.%d" % [SurvivorPlayer.PROFESSIONS[player.profession_index].name, player.level], "查看期间暂停战斗 · 数值包含当前升级效果 · 本局武器固定")
	box.add_child(_modal_label("生命 %.0f / %.0f       体力 %.0f / %.0f\n移动速度 %.0f       体力恢复 %.0f / 秒（消耗后延迟 0.42 秒）\n伤害倍率 %.0f%%       攻速倍率 %.0f%%" % [player.health, player.max_health, player.stamina, player.max_stamina, player.speed, player.stamina_regen, player.damage_multiplier * 100, player.attack_speed_multiplier * 100], 18))
	var data: Dictionary = SurvivorWeapon.DATA[player.weapon.selected]
	box.add_child(_modal_label("%s（%s）伤害 %.1f · 距离 %.0f · 间隔 %.2f 秒 · 体力 %.0f" % [data.name, data.role, float(data.damage) * player.damage_multiplier, data.reach, float(data.cooldown) / player.attack_speed_multiplier, data.stamina], 18, Color("e1cc9c")))
	box.add_child(_modal_label("翻滚：距离 %.0f · 持续 %.2f 秒 · 体力 %.0f · 冷却 %.2f 秒\n翻滚期间不能攻击，无额外无敌帧。" % [player.roll_distance, player.roll_duration, player.roll_stamina_cost, player.roll_cooldown], 18))
	if player.weapon.selected == 2:
		box.add_child(_modal_label("射箭后 %.2f 秒，移动速度为 %.0f%%；松开左键也需完成恢复。" % [player.bow_shot_move_duration, player.bow_shot_move_multiplier * 100.0], 16))
	box.add_child(_modal_label("楼层 %d · 金币 %d\n装备：%s\n卡牌次数（力量 / 迅捷 / 活力 / 职业1 / 职业2 / 远行）：%s" % [tower_floor, tower_gold, "、".join(player.equipment_names) if not player.equipment_names.is_empty() else "无", str(player.card_counts)], 16))
	var button := PrototypeUI.button("返回战斗  [Tab / Esc]", func(): resume_requested.emit())
	box.add_child(button)
	button.grab_focus()

func show_result(won: bool, elapsed: float, kills: int) -> void:
	var box := _screen("通天塔完成" if won else "挑战结束", "击败了塔顶 Boss！" if won else "生命耗尽，再试一次。")
	box.add_child(_modal_label("本局职业  %s\n抵达第 %d 层 · 金币 %d\n击败敌人  %d · 等级 %d\n累计经验  %d" % [SurvivorPlayer.PROFESSIONS[player.profession_index].name, tower_floor, tower_gold, kills, player.level, player.total_experience], 24))
	var button := PrototypeUI.button("重新开始  [Enter / R]", func(): restart_requested.emit(), 54)
	box.add_child(button)
	button.grab_focus()

func show_shop(gold: int, purchased: Array[bool], category: int, message: String = "") -> void:
	var box := _screen("层间商店", "金币 %d · 每件装备本局限购一次 · AP 暂未开放" % gold)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 5)
	box.add_child(tabs)
	for tab in range(4):
		var label: String = ["AD", "AP（未开放）", "防御", "机动"][tab]
		var tab_button := PrototypeUI.button(("● " if tab == category else "") + label, func(): shop_category_requested.emit(tab), 38)
		tab_button.add_theme_font_size_override("font_size", 16)
		tab_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(tab_button)
	for index in range(SurvivorGame.EQUIPMENT.size()):
		var item: Dictionary = SurvivorGame.EQUIPMENT[index]
		if int(item.category) != category:
			continue
		var text := "%s · %d 金币%s\n%s" % [item.name, item.price, " · 已购买" if purchased[index] else "", item.effect]
		var button := PrototypeUI.button(text, func(): purchase_requested.emit(index), 55)
		button.add_theme_font_size_override("font_size", 15)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.disabled = purchased[index]
		box.add_child(button)
	if category == 1:
		box.add_child(_modal_label("暂未开放：技能系统尚未实现。", 17))
	box.add_child(_modal_label(message if not message.is_empty() else "金币不足的商品可以点击查看提示。", 15, Color("e1cd9b")))
	var next := PrototypeUI.button("进入下一层", func(): next_floor_requested.emit(), 42)
	box.add_child(next)
	next.grab_focus()

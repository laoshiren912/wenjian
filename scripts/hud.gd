extends CanvasLayer

signal start_requested
signal restart_requested
signal stats_requested
signal pause_requested
signal resume_requested

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
var weapon_slots: Array[PanelContainer] = []
var weapon_labels: Array[Label] = []
var modal_panel: PanelContainer
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
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 6)
	slots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	equipment_box.add_child(slots)
	for index in range(SurvivorWeapon.DATA.size()):
		var slot := _combat_panel()
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slots.add_child(slot)
		weapon_slots.append(slot)
		var label := PrototypeUI.label("%d  %s" % [index + 1, SurvivorWeapon.DATA[index].name], 18)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.add_child(label)
		weapon_labels.append(label)
	var detail_row := HBoxContainer.new()
	detail_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_row.add_theme_constant_override("separation", 12)
	equipment_box.add_child(detail_row)
	weapon_text = PrototypeUI.label("1  剑", 15, Color("e5cd95"))
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
		modal_panel.custom_minimum_size.x = minf(760, root.size.x - 48)

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
	weapon_text.text = "%d  %s" % [player.weapon.selected + 1, SurvivorWeapon.DATA[player.weapon.selected].name]
	for index in range(weapon_slots.size()):
		var selected: bool = index == player.weapon.selected
		# Reuse the existing slot style; updating selection never changes input or focus.
		var style := weapon_slots[index].get_theme_stylebox("panel") as StyleBoxFlat
		style.bg_color = Color("2b5149") if selected else Color("101f28")
		style.border_color = Color("9cebd7") if selected else Color("38525b")
		style.set_border_width_all(2 if selected else 1)
		weapon_labels[index].modulate = Color("fff0bd") if selected else Color("b4c6ca")
	var weapon_data: Dictionary = SurvivorWeapon.DATA[player.weapon.selected]
	weapon_detail.text = "%s · 每目标伤害 %.0f" % [weapon_data.role, float(weapon_data.damage) * player.damage_multiplier]
	timer_text.text = "%02d:%02d / %02d:%02d" % [int(elapsed) / 60, int(elapsed) % 60, int(duration) / 60, int(duration) % 60]
	status_text.text = "击败 %d 个敌人 · 生存至 03:00" % kills

func _process(delta: float) -> void:
	hurt_flash.color.a = maxf(0.0, hurt_flash.color.a - delta * 0.8)
	if notice_time > 0.0:
		notice_time -= delta
		if notice_time <= 0.0:
			notice.text = ""

func show_notice(text: String) -> void:
	notice.text = text
	notice_time = 2.5

func flash_damage() -> void:
	hurt_flash.color.a = 0.18

func _screen(title: String, subtitle: String) -> VBoxContainer:
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
	var box := _screen("边境试炼", "2D 俯视角动作 RPG · 核心可玩性原型")
	box.add_child(_modal_label("在有限的遗迹地图中生存 3 分钟。击败敌人、贴近拾取晶体并升级。\n\nWASD 移动 · 鼠标瞄准 · 按住左键攻击 · Space 翻滚\n数字键 1 / 2 / 3 切换剑、长矛、弓箭 · Tab 属性 · Esc 暂停\n\n剑：高伤单体，只命中面前最近的一只怪物。\n长矛：较低单体伤害，可穿刺范围内多只怪物。\n弓箭：远程单体，箭矢碰到怪物或墙体后消失。\n普攻免费；翻滚耗 %.0f 体力，不能攻击、无额外无敌帧。\n红弧：攻击预警；金色圆形：受击后反击；红色菱形：主动追击。\n蓝色晶体：一个身位内吸附；新刷出的怪物逐渐增血。" % player.roll_stamina_cost, 18))
	var button := PrototypeUI.button("开始试炼  [Enter]", func(): start_requested.emit(), 54)
	box.add_child(button)
	button.grab_focus()

func hide_screen() -> void:
	overlay.hide()

func show_pause() -> void:
	var box := _screen("已暂停", "战斗与存活计时已暂停。")
	box.add_child(_modal_label("WASD 移动 · 鼠标瞄准 · 按住左键攻击\n1 / 2 / 3 切换剑、长矛、弓箭 · Space 翻滚\nTab 查看属性 · Esc 继续战斗\n\n红弧是攻击预警；金色圆形受击后反击，红色菱形主动追击。\n贴近蓝色晶体拾取经验，升级时选择一项强化。", 18))
	var button := PrototypeUI.button("继续  [Esc]", func(): resume_requested.emit())
	box.add_child(button)
	box.add_child(PrototypeUI.button("重新开始", func(): restart_requested.emit()))
	button.grab_focus()

func show_stats() -> void:
	var box := _screen("角色属性  /  Lv.%d" % player.level, "查看期间暂停战斗 · 数值包含当前升级效果")
	box.add_child(_modal_label("生命 %.0f / %.0f       体力 %.0f / %.0f\n移动速度 %.0f       体力恢复 %.0f / 秒（消耗后延迟 0.42 秒）\n伤害倍率 %.0f%%       攻速倍率 %.0f%%" % [player.health, player.max_health, player.stamina, player.max_stamina, player.speed, player.stamina_regen, player.damage_multiplier * 100, player.attack_speed_multiplier * 100], 18))
	for data in SurvivorWeapon.DATA:
		box.add_child(_modal_label("%s（%s）伤害 %.1f · 距离 %.0f · 间隔 %.2f 秒 · 体力 %.0f" % [data.name, data.role, float(data.damage) * player.damage_multiplier, data.reach, float(data.cooldown) / player.attack_speed_multiplier, data.stamina], 18, Color("e1cc9c")))
	box.add_child(_modal_label("翻滚：距离 %.0f · 持续 %.2f 秒 · 体力 %.0f · 冷却 %.2f 秒\n翻滚期间不能攻击，无额外无敌帧。" % [player.roll_distance, player.roll_duration, player.roll_stamina_cost, player.roll_cooldown], 18))
	var button := PrototypeUI.button("返回战斗  [Tab / Esc]", func(): resume_requested.emit())
	box.add_child(button)
	button.grab_focus()

func show_result(won: bool, elapsed: float, kills: int) -> void:
	var box := _screen("试炼完成" if won else "试炼结束", "已生存 3 分钟！" if won else "生命耗尽。调整距离，留意攻击预警，再试一次。")
	box.add_child(_modal_label("存活时间  %02d:%02d\n击败敌人  %d\n最终等级  %d\n累计经验  %d" % [int(elapsed) / 60, int(elapsed) % 60, kills, player.level, player.total_experience], 24))
	var button := PrototypeUI.button("重新开始  [Enter / R]", func(): restart_requested.emit(), 54)
	box.add_child(button)
	button.grab_focus()

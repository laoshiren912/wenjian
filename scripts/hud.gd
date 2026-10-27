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
var timer_text: Label
var status_text: Label
var hurt_flash: ColorRect
var notice: Label
var notice_time: float = 0.0
@onready var level_ui = $LevelUpUI

func _ready() -> void:
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PrototypeUI.fill(root)
	add_child(root)
	var margin := MarginContainer.new()
	PrototypeUI.fill(margin)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 15)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(margin)
	var layout := PrototypeUI.column(8)
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(layout)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 20)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(top)
	var vitals := PrototypeUI.panel()
	vitals.custom_minimum_size.x = 285.0
	top.add_child(vitals)
	var bars := PrototypeUI.column(5)
	vitals.add_child(bars)
	bars.add_child(PrototypeUI.label("边境试炼  /  第一轮原型", 17, Color("8ce2cc")))
	health_text = PrototypeUI.label("生命", 15)
	bars.add_child(health_text)
	health_bar = _bar(Color("e68080"))
	bars.add_child(health_bar)
	stamina_text = PrototypeUI.label("体力", 15)
	bars.add_child(stamina_text)
	stamina_bar = _bar(Color("81d9ba"))
	bars.add_child(stamina_bar)
	xp_text = PrototypeUI.label("经验", 15)
	bars.add_child(xp_text)
	xp_bar = _bar(Color("92b9f5"))
	bars.add_child(xp_bar)
	var center := PrototypeUI.column(3)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(center)
	timer_text = PrototypeUI.label("00:00 / 03:00", 30)
	timer_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(timer_text)
	status_text = PrototypeUI.label("生存至 03:00 完成试炼", 16, Color("a6c0c1"))
	status_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(status_text)
	var equipment := PrototypeUI.panel()
	equipment.custom_minimum_size.x = 275.0
	top.add_child(equipment)
	var equipment_box := PrototypeUI.column(8)
	equipment.add_child(equipment_box)
	weapon_text = PrototypeUI.label("1  剑", 23, Color("e5cd95"))
	equipment_box.add_child(weapon_text)
	equipment_box.add_child(PrototypeUI.label("1 剑    2 长矛    3 法杖", 16))
	equipment_box.add_child(PrototypeUI.button("角色属性  [Tab]", func(): stats_requested.emit(), 36))
	equipment_box.add_child(PrototypeUI.button("暂停  [Esc]", func(): pause_requested.emit(), 36))
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(spacer)
	notice = PrototypeUI.label("", 22, Color("9ae7d5"))
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(notice)
	var footer := PrototypeUI.label("WASD 移动   ·   鼠标瞄准 / 按住左键攻击   ·   Tab 属性   ·   Esc 暂停\n金色圆形：受击后反击    /    红色菱形：主动追击    /    蓝色晶体：靠近拾取经验", 16, Color("bad0ce"))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(footer)
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

func _bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(250, 8)
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
	stamina_text.text = "体力  %.0f / %.0f" % [player.stamina, player.max_stamina]
	stamina_bar.max_value = player.max_stamina
	stamina_bar.value = player.stamina
	xp_text.text = "Lv.%d    经验  %d / %d" % [player.level, player.experience, player.next_level_xp]
	xp_bar.max_value = player.next_level_xp
	xp_bar.value = player.experience
	weapon_text.text = "%d  %s" % [player.weapon.selected + 1, SurvivorWeapon.DATA[player.weapon.selected].name]
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
	var panel := PrototypeUI.panel()
	panel.custom_minimum_size.x = 740.0
	overlay_center.add_child(panel)
	var box := PrototypeUI.column(16)
	panel.add_child(box)
	box.add_child(PrototypeUI.label(title, 34, Color("96e5cf")))
	box.add_child(PrototypeUI.label(subtitle, 18, Color("aec4c7")))
	overlay.show()
	return box

func show_start() -> void:
	var box := _screen("边境试炼", "2D 俯视角动作 RPG · 核心可玩性原型")
	box.add_child(PrototypeUI.label("在有限的遗迹地图中生存 3 分钟。击败敌人、拾取晶体并升级。\n\nWASD 移动 · 鼠标瞄准 · 按住左键攻击\n数字键 1 / 2 / 3 切换剑、长矛、法杖\nTab 查看属性 · Esc 暂停\n\n剑适合群攻，长矛适合拉开距离，法杖发射远程弹。\n体力耗尽时先停止攻击，等待恢复。敌人红色弧线是攻击预警。\n金色圆形平时中立，受到攻击后会持续反击。", 19))
	var button := PrototypeUI.button("开始试炼  [Enter]", func(): start_requested.emit(), 54)
	box.add_child(button)
	button.grab_focus()

func hide_screen() -> void:
	overlay.hide()

func show_pause() -> void:
	var box := _screen("已暂停", "战斗与存活计时已暂停。")
	var button := PrototypeUI.button("继续  [Esc]", func(): resume_requested.emit())
	box.add_child(button)
	box.add_child(PrototypeUI.button("重新开始", func(): restart_requested.emit()))
	button.grab_focus()

func show_stats() -> void:
	var box := _screen("角色属性  /  Lv.%d" % player.level, "查看期间暂停战斗 · 数值包含当前升级效果")
	box.add_child(PrototypeUI.label("生命 %.0f / %.0f       体力 %.0f / %.0f\n移动速度 %.0f       体力恢复 %.0f / 秒（停手 0.42 秒后）\n伤害倍率 %.0f%%       攻速倍率 %.0f%%" % [player.health, player.max_health, player.stamina, player.max_stamina, player.speed, player.stamina_regen, player.damage_multiplier * 100, player.attack_speed_multiplier * 100], 19))
	for data in SurvivorWeapon.DATA:
		box.add_child(PrototypeUI.label("%s   伤害 %.1f  ·  距离 %.0f  ·  间隔 %.2f 秒  ·  体力 %.0f" % [data.name, float(data.damage) * player.damage_multiplier, data.reach, float(data.cooldown) / player.attack_speed_multiplier, data.stamina], 18, Color("e1cc9c")))
	var button := PrototypeUI.button("返回战斗  [Tab / Esc]", func(): resume_requested.emit())
	box.add_child(button)
	button.grab_focus()

func show_result(won: bool, elapsed: float, kills: int) -> void:
	var box := _screen("试炼完成" if won else "试炼结束", "已生存 3 分钟！" if won else "生命耗尽。调整距离，留意体力，再试一次。")
	box.add_child(PrototypeUI.label("存活时间  %02d:%02d\n击败敌人  %d\n最终等级  %d\n累计经验  %d" % [int(elapsed) / 60, int(elapsed) % 60, kills, player.level, player.total_experience], 24))
	var button := PrototypeUI.button("重新开始  [Enter / R]", func(): restart_requested.emit(), 54)
	box.add_child(button)
	button.grab_focus()

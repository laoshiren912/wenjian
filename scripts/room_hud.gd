extends "res://scripts/hud.gd"

# Reuse the V3.1 layout; the room prototype exposes only its active systems.
func _ready() -> void:
	super._ready()
	xp_text.get_parent().hide()
	manual_text.hide()
	for button in root.find_children("*", "Button", true, false):
		button.focus_mode = Control.FOCUS_NONE

func update_room(remaining: int, total: int, triggered: int) -> void:
	update_game(0.0, total - remaining, 0.0)
	timer_text.text = "剩余 %d / %d  ·  已触发 %d / %d" % [remaining, total, triggered, total]
	weapon_detail.text = "刺击 %.0f  ·  箭矢 %.0f" % [float(SurvivorWeapon.DATA[0].damage) * player.damage_multiplier, float(SurvivorWeapon.DATA[2].damage) * player.damage_multiplier]

func show_pause(_gold: int = -1) -> void:
	var box := _screen("已暂停", "V3.2 · 关卡式基础整合")
	box.add_child(_modal_label("WASD 移动 · 鼠标瞄准\n左键刺击 · 右键射箭 · 按住连续攻击\nSpace 翻滚 · Tab 查看属性 · Esc 继续\n\n沿路触发敌人，清除全部敌人后前往右侧传送点。", 18))
	_add_button(box, "继续  [Esc]", func(): resume_requested.emit())
	_add_button(box, "重新开始", func(): restart_requested.emit())

func show_stats() -> void:
	var box := _screen("角色属性", "查看期间暂停战斗 · 左键剑 / 右键弓")
	box.add_child(_modal_label("生命 %.0f / %.0f · 体力 %.0f / %.0f\n移动速度 %.0f · 体力恢复 %.0f / 秒" % [player.health, player.max_health, player.stamina, player.max_stamina, player.speed, player.stamina_regen], 18))
	for index in [0, 2]:
		var data: Dictionary = SurvivorWeapon.DATA[index]
		box.add_child(_modal_label("%s：伤害 %.0f · 距离 %.0f · 间隔 %.2f 秒" % [data.name, float(data.damage) * player.damage_multiplier, float(data.reach) + player.reach_bonus, float(data.cooldown) / player.attack_speed_multiplier], 18, Color("e1cc9c")))
	box.add_child(_modal_label("翻滚：距离 %.0f · 持续 %.2f 秒\n消耗 %.0f 体力 · 冷却 %.2f 秒 · 无额外无敌帧" % [player.roll_distance, player.roll_duration, player.roll_stamina_cost, player.roll_cooldown], 18))
	box.add_child(_modal_label("攻击动作期间停步；翻滚可取消动作。\n射箭后恢复阶段移动规则沿用当前版本。", 16))
	_add_button(box, "返回战斗  [Tab / Esc]", func(): resume_requested.emit())

func show_room_result(completed: bool, kills: int, total: int) -> void:
	var box := _screen("本次测试完成" if completed else "角色倒下", "已抵达传送点；下一张地图尚未接入。" if completed else "生命耗尽，可以重新挑战。")
	box.add_child(_modal_label("击败敌人 %d / %d" % [kills, total], 24))
	_add_button(box, "重新开始  [Enter / R]", func(): restart_requested.emit())

func _add_button(box: VBoxContainer, text: String, callback: Callable) -> void:
	var button := PrototypeUI.button(text, callback)
	# Space belongs to rolling; it must never activate a menu button.
	button.focus_mode = Control.FOCUS_NONE
	box.add_child(button)

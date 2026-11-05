extends "res://scripts/room_hud.gd"

func _ready() -> void:
	super._ready()
	var return_button := PrototypeUI.button("返回V4.1（新局）", func():
		Engine.time_scale = 1.0
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/main_v41.tscn"), 32)
	root.add_child(return_button)
	return_button.position = Vector2(16, 157)
	return_button.focus_mode = Control.FOCUS_NONE
	if get_parent().scene_file_path in ["res://scenes/main_v33.tscn", "res://scenes/sword_motion_combat.tscn"]:
		var back := PrototypeUI.button("← 动作样板", func():
			get_tree().paused = false
			get_tree().change_scene_to_file("res://scenes/sword_motion_trial.tscn"), 34)
		root.add_child(back)
		back.position = Vector2(16, 115)
		back.focus_mode = Control.FOCUS_NONE
	root.move_child(overlay, root.get_child_count() - 1)

func update_room(remaining: int, total: int, _triggered: int) -> void:
	update_game(0.0, total - remaining, 0.0)
	timer_text.text = "剩余 %d / %d" % [remaining, total]
	var combo = player.combo
	weapon_text.text = "左键 剑击 / 蓄力 · 右键 弓"
	weapon_detail.text = "短按松手连击 · 长按松手重击"
	if combo.charging:
		weapon_detail.text = "蓄力 %d%% · 松手劈砍 / Space 取消" % roundi(combo.charge_fraction() * 100.0)
	elif combo.charged_swing and combo.swing_time > 0.0:
		weapon_detail.text = "蓄力劈砍 · " + {"windup": "前摇", "active": "命中", "recovery": "收招"}[combo.phase()]
	elif combo.swing_time > 0.0:
		weapon_detail.text = "第 %d 段 %s · %s" % [combo.stage + 1, combo.current_data().name, {"windup": "前摇", "active": "命中", "recovery": "收招"}[combo.phase()]]

func show_pause(_gold: int = -1) -> void:
	var box := _screen("已暂停", "V3.4 · 独立蓄力重击与四怪试玩")
	box.add_child(_modal_label("WASD 移动 · 鼠标瞄准\n短按左键松手：横斩 → 斜斩 → 重劈\n长按左键：蓄力，松手范围劈砍\n蓄力可移动；Space 成功翻滚取消蓄力\n右键射箭 · Space 翻滚 · Tab 属性\n第三段/蓄力劈砍命中阶段结束后可翻滚。\n翻滚开放前 %.2f 秒可预输入。" % player.combo.roll_buffer, 18))
	_add_button(box, "继续  [Esc]", func(): resume_requested.emit())
	_add_button(box, "重新开始", func(): restart_requested.emit())

func show_stats() -> void:
	var box := _screen("角色属性", "V3.4 · 普攻单目标 / 蓄力多目标 · 查看期间暂停")
	box.add_child(_modal_label("生命 %.0f / %.0f · 体力 %.0f / %.0f\n移动 %.0f · 体力恢复 %.0f / 秒" % [player.health, player.max_health, player.stamina, player.max_stamina, player.speed, player.stamina_regen], 17))
	var combo = player.combo
	for i in range(combo.stages.size()):
		var data: Dictionary = combo.stages[i]
		var scale: float = player.attack_speed_multiplier
		box.add_child(_modal_label("%d %s：伤害 %.0f · 距离 %.0f · 前移 %.0f\n前摇 %.2f / 命中 %.2f / 收招 %.2f 秒" % [i + 1, data.name, float(data.damage) * player.damage_multiplier, float(data.reach) + player.reach_bonus, data.lunge, float(data.windup) / scale, float(data.active) / scale, float(data.recovery) / scale], 16, Color("e1cc9c")))
	box.add_child(_modal_label("弓：伤害 %.0f · 距离 %.0f · 间隔 %.2f 秒\n翻滚：距离 %.0f · %.2f 秒 · 体力 %.0f · 冷却 %.2f 秒" % [21.0 * player.damage_multiplier, 640.0 + player.reach_bonus, 0.32 / player.attack_speed_multiplier, player.roll_distance, player.roll_duration, player.roll_stamina_cost, player.roll_cooldown], 16))
	box.add_child(_modal_label("蓄力：识别 %.2f + 满蓄 %.2f 秒 · 伤害 %.0f–%.0f\n范围 %.0f / %.0f° · 前摇 %.2f / 命中 %.2f / 收招 %.2f\n蓄力移速 %.0f%% / 释放 %.0f%%；无额外无敌帧。" % [combo.hold_threshold, combo.charge_duration, combo.charge_damage_min * player.damage_multiplier, combo.charge_damage_max * player.damage_multiplier, combo.charged_attack.reach + player.reach_bonus, combo.charged_attack.angle, combo.charged_attack.windup / player.attack_speed_multiplier, combo.charged_attack.active / player.attack_speed_multiplier, combo.charged_attack.recovery / player.attack_speed_multiplier, combo.charge_move_multiplier * 100.0, combo.release_move_multiplier * 100.0], 15))
	_add_button(box, "返回战斗  [Tab / Esc]", func(): resume_requested.emit())

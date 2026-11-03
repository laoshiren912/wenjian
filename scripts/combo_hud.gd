extends "res://scripts/room_hud.gd"

func update_room(remaining: int, total: int, _triggered: int) -> void:
	update_game(0.0, total - remaining, 0.0)
	timer_text.text = "剩余 %d / %d" % [remaining, total]
	var combo = player.combo
	weapon_text.text = "左键 三段剑击 · 右键 弓"
	weapon_detail.text = "点击逐段 · 重劈落刀后可翻滚"
	if combo.swing_time > 0.0:
		weapon_detail.text = "第 %d 段 %s · %s" % [combo.stage + 1, combo.current_data().name, {"windup": "前摇", "active": "命中", "recovery": "收招"}[combo.phase()]]

func show_pause(_gold: int = -1) -> void:
	var box := _screen("已暂停", "V3.3 · 三段剑击与四怪试玩")
	box.add_child(_modal_label("WASD 移动 · 鼠标瞄准\n连续点击左键：横斩 → 反向斜斩 → 向下重劈\n右键射箭 · Space 翻滚 · Tab 属性\n\n前两段收招后翻滚；第三段落刀后即可翻滚。\n开放前 %.2f 秒可提前按 Space。" % player.combo.roll_buffer, 18))
	_add_button(box, "继续  [Esc]", func(): resume_requested.emit())
	_add_button(box, "重新开始", func(): restart_requested.emit())

func show_stats() -> void:
	var box := _screen("角色属性", "V3.3 · 每段单目标 · 查看期间暂停")
	box.add_child(_modal_label("生命 %.0f / %.0f · 体力 %.0f / %.0f\n移动 %.0f · 体力恢复 %.0f / 秒" % [player.health, player.max_health, player.stamina, player.max_stamina, player.speed, player.stamina_regen], 17))
	var combo = player.combo
	for i in range(combo.stages.size()):
		var data: Dictionary = combo.stages[i]
		var scale: float = player.attack_speed_multiplier
		box.add_child(_modal_label("%d %s：伤害 %.0f · 距离 %.0f · 前移 %.0f\n前摇 %.2f / 命中 %.2f / 收招 %.2f 秒" % [i + 1, data.name, float(data.damage) * player.damage_multiplier, float(data.reach) + player.reach_bonus, data.lunge, float(data.windup) / scale, float(data.active) / scale, float(data.recovery) / scale], 16, Color("e1cc9c")))
	box.add_child(_modal_label("弓：伤害 %.0f · 距离 %.0f · 间隔 %.2f 秒\n翻滚：距离 %.0f · %.2f 秒 · 体力 %.0f · 冷却 %.2f 秒" % [21.0 * player.damage_multiplier, 640.0 + player.reach_bonus, 0.32 / player.attack_speed_multiplier, player.roll_distance, player.roll_duration, player.roll_stamina_cost, player.roll_cooldown], 16))
	box.add_child(_modal_label("第三段落刀后可翻滚取消收招；无额外无敌帧。", 16))
	_add_button(box, "返回战斗  [Tab / Esc]", func(): resume_requested.emit())

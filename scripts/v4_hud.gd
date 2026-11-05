extends "res://scripts/combo_hud.gd"

signal reward_selected(index: int)
const CONFIG = preload("res://scripts/v4_config.gd")
var run

func reward_summary() -> String:
	if run == null:
		return ""
	return "剑伤 +%.0f%% · 生命上限 +%.0f · 翻滚冷却 ×%.3f" % [run.reward_counts[0] * CONFIG.SWORD_BONUS * 100.0, run.reward_counts[1] * CONFIG.HEALTH_BONUS, pow(CONFIG.ROLL_FACTOR, run.reward_counts[2])]

func update_room(remaining: int, total: int, triggered: int) -> void:
	super.update_room(remaining, total, triggered)
	if run == null:
		return
	timer_text.text = "终点 · 通关" if run.room_index == 3 else "房间 %d / 3 · 剩余 %d / %d" % [run.room_index + 1, remaining, total]
	weapon_detail.text += "\n" + reward_summary()

func show_rewards() -> void:
	var box := _screen("清房奖励 · 三选一", "每房领取一次 · 可重复选择 · 选择后开放出口")
	box.add_child(_modal_label(reward_summary(), 17))
	var names: Array[String] = CONFIG.reward_names()
	for i in range(names.size()):
		_add_button(box, names[i], func(): reward_selected.emit(i))
	box.add_child(_modal_label("剑伤按基础值加算，仅影响剑；生命同时恢复%.0f点。\n翻滚冷却每次乘%.2f。请选一项继续。" % [CONFIG.HEALTH_BONUS, CONFIG.ROLL_FACTOR], 16))

func show_pause(_gold: int = -1) -> void:
	var box := _screen("已暂停", "V4 · 三个战斗房间 → 终点")
	box.add_child(_modal_label("WASD 移动 · 鼠标瞄准 · 左键逐次三段剑击\n右键弓 · Space 翻滚 · Tab 属性\n清房后靠近金色奖励，选一项，再走入右侧出口。\n重新开始将返回第1间，清空本局奖励。", 17))
	_add_button(box, "继续  [Esc]", func(): resume_requested.emit())
	_add_button(box, "重新开始", func(): restart_requested.emit())

func show_stats() -> void:
	var box := _screen("角色属性", "V4 · 本局奖励跨房间保留")
	box.add_child(_modal_label("生命 %.0f / %.0f · 体力 %.0f / %.0f\n%s" % [player.health, player.max_health, player.stamina, player.max_stamina, reward_summary()], 17))
	for i in range(player.combo.stages.size()):
		var data: Dictionary = player.combo.stages[i]
		box.add_child(_modal_label("%d %s：伤害 %.1f · 距离 %.0f · 前移 %.0f\n前摇 %.2f / 命中 %.2f / 收招 %.2f 秒" % [i + 1, data.name, float(data.damage) * player.damage_multiplier, data.reach, data.lunge, data.windup, data.active, data.recovery], 16, Color("e1cc9c")))
	box.add_child(_modal_label("弓伤害 %.1f · 翻滚冷却 %.3f 秒\n翻滚距离 %.0f · 持续 %.2f 秒 · 消耗体力 %.0f" % [21.0 * player.damage_multiplier, player.roll_cooldown, player.roll_distance, player.roll_duration, player.roll_stamina_cost], 16))
	_add_button(box, "返回战斗  [Tab / Esc]", func(): resume_requested.emit())

func show_run_result(won: bool) -> void:
	var box := _screen("本局通关" if won else "角色倒下", "已抵达终点房间" if won else "倒在第 %d / 3 间" % (run.room_index + 1))
	box.add_child(_modal_label("本局击败 %d / 12\n%s" % [run.run_kills, reward_summary()], 19))
	box.add_child(_modal_label("重新开始：第1间、满生命与体力、清空奖励。", 17))
	_add_button(box, "重新开始  [Enter / R]", func(): restart_requested.emit())

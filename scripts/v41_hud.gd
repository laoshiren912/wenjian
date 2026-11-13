extends "res://scripts/combo_hud.gd"

signal reward_selected(index: int)
const CONFIG = preload("res://scripts/v41_config.gd")
var run

func _ready() -> void:
	super._ready()
	var zoom := PrototypeUI.button("远近镜头切换", func(): run.toggle_view(), 32)
	root.add_child(zoom)
	zoom.position = Vector2(16, 115)
	zoom.focus_mode = Control.FOCUS_NONE
	root.move_child(overlay, root.get_child_count() - 1)

func reward_summary() -> String:
	if run == null:
		return ""
	return "剑伤 +%.0f%% · 击杀回血 %.0f · 翻滚翻倍 %s · 第三段破防延长 %s\n蓄力槽 %s · 翻滚槽 %s · 弓槽 %s" % [run.reward_counts[0] * CONFIG.SWORD_BONUS * 100.0, run.reward_counts[2] * CONFIG.KILL_HEAL, ("就绪" if player.combo.roll_armed else "已解锁") if run.reward_counts[1] > 0 else "未解锁", "已解锁" if run.reward_counts[3] > 0 else "未解锁", "剑气斩+" if run.reward_counts[7] else ("剑气斩" if run.reward_counts[4] else "空"), "残影步+" if run.reward_counts[8] else ("残影步" if run.reward_counts[5] else "空"), "回身箭+" if run.reward_counts[9] else ("回身箭" if run.reward_counts[6] else "空")]

func update_room(remaining: int, total: int, triggered: int) -> void:
	super.update_room(remaining, total, triggered)
	if run == null:
		return
	if run.phase == "cleared":
		timer_text.text = "守庭者已击败 · 通关"
	elif is_instance_valid(run.boss):
		timer_text.text = "第 %d / %d 间 · 守庭者 %.0f / %.0f" % [run.room_index + 1, CONFIG.RUN_ROOMS, run.boss.health, run.boss.max_health]
	else:
		timer_text.text = "房间 %d / %d · 剩余 %d / %d" % [run.room_index + 1, CONFIG.RUN_ROOMS, remaining, total]
	weapon_text.text = "左键 剑击 / 蓄力 · 右键 弓"
	var action := "短按松手连击 · 长按松手重击"
	if player.combo.charging:
		action = "蓄力 %d%% · Space取消" % roundi(player.combo.charge_fraction() * 100.0)
	elif player.combo.swing_time > 0.0:
		action = "蓄力劈砍" if player.combo.charged_swing else "第%d段 %s" % [player.combo.stage + 1, player.combo.current_data().name]
	elif player.bow_windup_remaining > 0.0:
		action = "弓 · 拉弦"
	elif player.bow_recovery_remaining > 0.0:
		action = "弓 · 收招 %.1f 秒" % player.bow_recovery_remaining
	weapon_detail.text = action + "\n" + reward_summary()

func show_rewards() -> void:
	var box := _screen("开战前选择招式 · 三选一" if run.opening_choice else "清房奖励 · 三选一", "选择一张卡；招式装入对应槽位，强化需要先获得招式")
	box.add_child(_modal_label(reward_summary(), 17))
	var names: Array[String] = CONFIG.reward_names()
	for index in run.reward_options:
		var label: String = names[index]
		var enabled: bool = run.can_select_reward(index)
		_add_button(box, label if enabled else label + "（已解锁）", func(): reward_selected.emit(index))
		(box.get_child(box.get_child_count() - 1) as Button).disabled = not enabled
	box.add_child(_modal_label("剑气斩：满蓄释放远程穿透剑气。残影步：翻滚起点延时范围爆炸。\n回身箭：每次翻滚最多一箭；滚中按下也会缓存。\n翻滚翻倍作用下一次剑击、蓄力或箭，挥空消耗；第三段自带破防，蓄力正面会被格挡、不破防。", 16))

func show_card_debug() -> void:
	var box := _screen("调试得卡 · F8", "仅调试运行有效；强化须先获得对应招式")
	var grid := GridContainer.new()
	grid.columns = 2
	box.add_child(grid)
	var names := CONFIG.reward_names()
	for index in range(names.size()):
		var button := PrototypeUI.button(names[index], func(): run.debug_grant(index), 38)
		button.disabled = not run.CARD_POOL.eligible(index, run.reward_counts)
		grid.add_child(button)
	var row := HBoxContainer.new()
	box.add_child(row)
	var skip := PrototypeUI.button("跳过开局选卡", func(): run.debug_opening(true), 38)
	var redo := PrototypeUI.button("重做开局选卡", func(): run.debug_opening(false), 38)
	skip.disabled = run.room_index != 0 or run.triggered_count != 0
	redo.disabled = skip.disabled
	row.add_child(skip)
	row.add_child(redo)
	box.add_child(PrototypeUI.button("返回", func(): run.debug_close(), 38))

func show_pause(_gold: int = -1) -> void:
	var box := _screen("已暂停", "V4.1 · 六间战斗房与守庭者")
	box.add_child(_modal_label("前六间清场领奖，第七间挑战守庭者。\n近战配对轮换，当前一组出手，其余侧移等待。\n左键短按松手连击，长按蓄力松手释放；右键弓。\n清完全部波次，靠近金色奖励按 E 领奖，再走右侧出口。\n进入独立样板会结束本局，返回时重新开始。", 17))
	_add_button(box, "继续  [Esc]", func(): resume_requested.emit())
	_add_button(box, "重新开始", func(): restart_requested.emit())
	_add_button(box, "庭院 / 镜头独立样板（结束本局）", func(): _open_sample("courtyard_trial"))
	_add_button(box, "挥剑慢动作样板（结束本局）", func(): _open_sample("sword_motion_trial"))

func _open_sample(scene: String) -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/" + scene + ".tscn")

func show_stats() -> void:
	var box := _screen("角色属性", "V4.1 · 绕身挥剑、蓄力与庭院战斗")
	box.add_child(_modal_label("生命 %.0f / %.0f · 体力 %.0f / %.0f\n%s" % [player.health, player.max_health, player.stamina, player.max_stamina, reward_summary()], 17))
	for i in range(player.combo.stages.size()):
		var data: Dictionary = player.combo.stages[i]
		box.add_child(_modal_label("%d %s：伤害 %.1f · 距离 %.0f · 前移 %.0f" % [i + 1, data.name, float(data.damage) * player.damage_multiplier, data.reach, data.lunge], 17, Color("e1cc9c")))
	box.add_child(_modal_label("蓄力 %.2f+%.2f秒 · 伤害 %.1f～%.1f · 范围 %.0f/%.0f°\n弓伤害 %.1f · 翻滚冷却 %.3f秒\n翻滚后普通剑/蓄力或箭×%.0f；破防延长奖励只作用第三段。" % [CONFIG.HOLD_THRESHOLD, CONFIG.CHARGE_DURATION, player.combo.charge_damage_min, player.combo.charge_damage_max, CONFIG.CHARGE_REACH, CONFIG.CHARGE_ANGLE, 21.0 * player.damage_multiplier, player.roll_cooldown, CONFIG.ROLL_SWORD_FACTOR], 16))
	_add_button(box, "返回战斗  [Tab / Esc]", func(): resume_requested.emit())

func show_run_result(won: bool) -> void:
	var box := _screen("本局通关" if won else "角色倒下", "已击败守庭者" if won else "倒在第 %d / %d 间" % [run.room_index + 1, CONFIG.RUN_ROOMS])
	box.add_child(_modal_label("本局击败 %d / %d\n%s" % [run.run_kills, CONFIG.run_total(), reward_summary()], 19))
	box.add_child(_modal_label("重新开始：第1间、满生命与体力、清空奖励。", 17))
	_add_button(box, "重新开始  [Enter / R]", func(): restart_requested.emit())

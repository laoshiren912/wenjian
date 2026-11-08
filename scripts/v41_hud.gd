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
	return "剑伤 +%.0f%% · 击杀回血 %.0f\n翻滚翻倍 %s · 重劈破防 %s" % [run.reward_counts[0] * CONFIG.SWORD_BONUS * 100.0, run.reward_counts[2] * CONFIG.KILL_HEAL, ("已就绪" if player.combo.roll_armed else "已解锁") if run.reward_counts[1] > 0 else "未解锁", "已解锁" if run.reward_counts[3] > 0 else "未解锁"]

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
	var box := _screen("清房奖励 · 随机三选一", "已解锁项禁用；剑伤、击杀回血可重复叠加")
	box.add_child(_modal_label(reward_summary(), 17))
	var names: Array[String] = CONFIG.reward_names()
	for index in run.reward_options:
		var label: String = names[index]
		var enabled: bool = run.can_select_reward(index)
		_add_button(box, label if enabled else label + "（已解锁）", func(): reward_selected.emit(index))
		(box.get_child(box.get_child_count() - 1) as Button).disabled = not enabled
	box.add_child(_modal_label("翻滚翻倍作用下一次普通剑击或蓄力释放，挥空也消耗。\n第三段破防只作用普通第三段，不作用蓄力。", 16))

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
	box.add_child(_modal_label("蓄力 %.2f+%.2f秒 · 伤害 %.1f～%.1f · 范围 %.0f/%.0f°\n弓伤害 %.1f · 翻滚冷却 %.3f秒\n翻滚后普通剑/蓄力×%.0f；第三段破防不影响蓄力。" % [CONFIG.HOLD_THRESHOLD, CONFIG.CHARGE_DURATION, player.combo.charge_damage_min, player.combo.charge_damage_max, CONFIG.CHARGE_REACH, CONFIG.CHARGE_ANGLE, 21.0 * player.damage_multiplier, player.roll_cooldown, CONFIG.ROLL_SWORD_FACTOR], 16))
	_add_button(box, "返回战斗  [Tab / Esc]", func(): resume_requested.emit())

func show_run_result(won: bool) -> void:
	var box := _screen("本局通关" if won else "角色倒下", "已击败守庭者" if won else "倒在第 %d / %d 间" % [run.room_index + 1, CONFIG.RUN_ROOMS])
	box.add_child(_modal_label("本局击败 %d / %d\n%s" % [run.run_kills, CONFIG.run_total(), reward_summary()], 19))
	box.add_child(_modal_label("重新开始：第1间、满生命与体力、清空奖励。", 17))
	_add_button(box, "重新开始  [Enter / R]", func(): restart_requested.emit())

extends "res://scripts/combo_hud.gd"

signal reward_selected(index: int)
const CONFIG = preload("res://scripts/v41_config.gd")
var run
var gm_scroll: ScrollContainer

func _resize_modal() -> void:
	super._resize_modal()
	if is_instance_valid(gm_scroll) and is_instance_valid(modal_panel) and gm_scroll.get_parent().get_parent() == modal_panel:
		gm_scroll.custom_minimum_size.y = maxf(0.0, minf(460.0, root.size.y - 180.0))

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
	return "剑伤 +%.0f%% · 击杀回血 %.0f · 冲刺翻倍 %s · 破防延长 %s" % [run.reward_counts[0] * CONFIG.SWORD_BONUS * 100.0, run.reward_counts[2] * CONFIG.KILL_HEAL, ("就绪" if player.combo.dash_armed else "已解锁") if run.reward_counts[1] > 0 else "未解锁", "已解锁" if run.reward_counts[3] > 0 else "未解锁"]

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
	weapon_text.text = "左键 三连 · Space 穿阵 · 右键 掷剑"
	stamina_text.text = "体力  %.0f / %.0f" % [player.stamina, player.max_stamina]
	var rank: int = player.cultivation
	var progress := "修为已成" if rank == 2 else "击杀 %d/%d" % [run.run_kills, CONFIG.CULTIVATION_KILLS[rank + 1]]
	if run.cultivation_override >= 0:
		progress = "GM"
	var cooldown := "就绪" if player.stamina >= CONFIG.DASH_COST else "体力不足"
	if player.dash_cooldown > 0.0:
		cooldown = "%.1f 秒" % player.dash_cooldown
	var throw_status := "就绪" if player.stamina >= CONFIG.THROW_COST else "体力不足"
	if is_instance_valid(player.thrown_sword):
		throw_status = "飞行中"
	elif player.throw_cooldown > 0.0:
		throw_status = "%.1f 秒" % player.throw_cooldown
	weapon_detail.text = "%s · %s\n穿阵 %s  掷剑 %s" % [CONFIG.CULTIVATION_NAMES[rank], progress, cooldown, throw_status]

func show_rewards() -> void:
	var box := _screen("清房奖励", "选择一项属性奖励")
	box.add_child(_modal_label(reward_summary(), 17))
	var names: Array[String] = CONFIG.reward_names()
	for index in run.reward_options:
		var label: String = names[index]
		var enabled: bool = run.can_select_reward(index)
		_add_button(box, label if enabled else label + "（已解锁）", func(): reward_selected.emit(index))
		(box.get_child(box.get_child_count() - 1) as Button).disabled = not enabled
	box.add_child(_modal_label("冲刺翻倍作用于下一次出剑的直击。第三段自带破防。", 16))

func show_card_debug() -> void:
	var panel := _screen("GM 调试 · `", "仅调试运行有效；滚动查看全部功能")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(680, 0)
	panel.add_child(scroll)
	gm_scroll = scroll
	_resize_modal()
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	var gm_row := HBoxContainer.new()
	box.add_child(gm_row)
	gm_row.add_child(PrototypeUI.button("无敌：" + ("开" if run.gm_invincible else "关"), func(): run.debug_toggle_invincible(), 38))
	gm_row.add_child(PrototypeUI.button("无限体力：" + ("开" if run.gm_infinite_stamina else "关"), func(): run.debug_toggle_stamina(), 38))
	gm_row.add_child(PrototypeUI.button("体力回满", func(): run.debug_fill_stamina(), 38))
	var cultivation_row := HBoxContainer.new()
	box.add_child(cultivation_row)
	for rank in range(CONFIG.CULTIVATION_NAMES.size()):
		var button := PrototypeUI.button(CONFIG.CULTIVATION_NAMES[rank], func(): run.debug_cultivation(rank), 38)
		button.disabled = run.cultivation_override == rank
		cultivation_row.add_child(button)
	cultivation_row.add_child(PrototypeUI.button("恢复自然修为", func(): run.debug_cultivation(-1), 38))
	box.add_child(_modal_label("跳关", 17))
	var rooms := HBoxContainer.new()
	box.add_child(rooms)
	for i in range(CONFIG.RUN_ROOMS):
		rooms.add_child(PrototypeUI.button("Boss" if i == CONFIG.BOSS_ROOM else str(i + 1), func(): run.debug_jump(i), 38))
	var spawn_row := HBoxContainer.new()
	box.add_child(spawn_row)
	var types := OptionButton.new()
	for label in ["普通近战", "举防近战", "远程", "Boss"]: types.add_item(label)
	spawn_row.add_child(types)
	var count := SpinBox.new()
	count.min_value = 1
	count.max_value = 20
	count.value = 1
	spawn_row.add_child(count)
	spawn_row.add_child(PrototypeUI.button("玩家前方刷怪", func(): run.debug_spawn(types.selected, int(count.value)), 38))
	spawn_row.add_child(PrototypeUI.button("清除当前敌人", func(): run.debug_clear_enemies(), 38))
	box.add_child(_modal_label("调试得卡", 17))
	var grid := GridContainer.new()
	grid.columns = 2
	box.add_child(grid)
	var names := CONFIG.reward_names()
	for index in range(names.size()):
		var button := PrototypeUI.button(names[index], func(): run.debug_grant(index), 38)
		button.disabled = not run.CARD_POOL.eligible(index, run.reward_counts)
		grid.add_child(button)
	box.add_child(PrototypeUI.button("返回", func(): run.debug_close(), 38))

func show_pause(_gold: int = -1) -> void:
	var box := _screen("已暂停", "V4.1 · 六间战斗房与守庭者")
	box.add_child(_modal_label("左键点按三连，Space 穿阵一线，右键掷剑旋斩。\n击杀积累修为，三种攻击同时进阶。\n清完全部波次选择属性奖励，再走右侧出口。\n进入独立样板会结束本局。", 17))
	_add_button(box, "继续  [Esc]", func(): resume_requested.emit())
	_add_button(box, "重新开始", func(): restart_requested.emit())
	_add_button(box, "庭院 / 镜头独立样板（结束本局）", func(): _open_sample("courtyard_trial"))
	_add_button(box, "挥剑慢动作样板（结束本局）", func(): _open_sample("sword_motion_trial"))

func _open_sample(scene: String) -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/" + scene + ".tscn")

func show_stats() -> void:
	var box := _screen("角色属性", CONFIG.CULTIVATION_NAMES[player.cultivation])
	box.add_child(_modal_label("生命 %.0f / %.0f · 体力 %.0f / %.0f\n%s" % [player.health, player.max_health, player.stamina, player.max_stamina, reward_summary()], 17))
	for i in range(player.combo.stages.size()):
		var data: Dictionary = player.combo.stages[i]
		box.add_child(_modal_label("%d %s · 伤害 %.1f · 距离 %.0f" % [i + 1, data.name, float(data.damage) * player.damage_multiplier, float(data.reach) + CONFIG.SWORD_EXTENSION[player.cultivation]], 17, Color("e1cc9c")))
	var rank: int = player.cultivation
	var mult: float = player.combo.card_multiplier * player.damage_multiplier
	box.add_child(_modal_label("穿阵一线 · 距离 %.0f · 体力 %.0f · 冷却 %.1f 秒\n直接伤害 %.1f · 剑痕伤害 %.1f" % [CONFIG.DASH_DISTANCE[rank], CONFIG.DASH_COST, CONFIG.DASH_COOLDOWN, CONFIG.DASH_DAMAGE[rank] * mult, CONFIG.DASH_MARK_DAMAGE[rank] * mult], 16))
	box.add_child(_modal_label("掷剑旋斩 · 距离 %.0f · 体力 %.0f · 冷却 %.1f 秒\n飞出 %.1f · 旋斩 %.1f · 回程 %.1f" % [CONFIG.THROW_DISTANCE[rank], CONFIG.THROW_COST, CONFIG.THROW_COOLDOWN, CONFIG.THROW_OUT_DAMAGE[rank] * mult, CONFIG.THROW_SPIN_DAMAGE[rank] * mult, CONFIG.THROW_RETURN_DAMAGE[rank] * mult], 16))
	_add_button(box, "返回战斗  [Tab / Esc]", func(): resume_requested.emit())

func show_run_result(won: bool) -> void:
	var box := _screen("本局通关" if won else "角色倒下", "已击败守庭者" if won else "倒在第 %d / %d 间" % [run.room_index + 1, CONFIG.RUN_ROOMS])
	box.add_child(_modal_label("本局击败 %d / %d\n%s" % [run.run_kills, CONFIG.run_total(), reward_summary()], 19))
	box.add_child(_modal_label("重新开始：第1间、满生命与体力、清空奖励。", 17))
	_add_button(box, "重新开始  [Enter / R]", func(): restart_requested.emit())

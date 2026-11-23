extends "res://scripts/room_game.gd"

const CONFIG = preload("res://scripts/v4_config.gd")
const COMBO_PLAYER = preload("res://scenes/player_combo.tscn")
var room_index := 0
var reward_counts: Array[int] = [0, 0, 0]
var run_kills := 0
var base_stages: Array[Dictionary] = []
var base_health := 100.0
var base_roll := 0.65

func _create_player() -> SurvivorPlayer:
	return COMBO_PLAYER.instantiate()

func _build_ui() -> void:
	super._build_ui()
	hud.run = self
	hud.reward_selected.connect(select_reward)

# All existing restart signals reset the run; room transitions use _enter_room.
func start_room() -> void:
	room_index = 0
	reward_counts.assign([0, 0, 0])
	run_kills = 0
	_enter_room()

func _enter_room() -> void:
	var carried_health := -1.0
	var carried_stamina := -1.0
	if room_index > 0 and is_instance_valid(player):
		carried_health = player.health
		carried_stamina = player.stamina
	super.start_room()
	world.triggered.fill(true)
	world.reward_visible = false
	world.room_cleared = false
	base_stages = player.combo.stages.duplicate(true)
	base_health = player.max_health
	base_roll = player.roll_cooldown
	_apply_rewards()
	if carried_health >= 0.0:
		player.health = carried_health
		player.stamina = carried_stamina
	player.weapon.heavy_hit.connect(func(): feedback.shake_strength = maxf(feedback.shake_strength, 6.0))
	if room_index == CONFIG.ROOMS.size():
		total = 0
		remaining = 0
		triggered_count = 0
		phase = "cleared"
		world.room_cleared = true
		_update_status()
		_show_result(true)
	else:
		var kinds: Array = CONFIG.ROOMS[room_index]
		total = kinds.size()
		remaining = total
		triggered_count = total
		for i in range(total):
			var enemy: SurvivorEnemy = ENEMY.instantiate()
			enemy.world = world
			enemy.kind = kinds[i]
			enemy.dodge_enabled = false
			enemy.collision_mask = 1 | 2 | 4
			enemy.position = world.cell_center(CONFIG.SPAWN_CELLS[i])
			enemy.killed.connect(_on_enemy_killed)
			enemy.damaged.connect(func(point: Vector2, amount: float): feedback.show_damage(point, amount, false))
			world.actors.add_child(enemy)
		_update_status()
	hud.update_room(remaining, total, triggered_count)
	world.queue_redraw()

func _apply_rewards() -> void:
	player.combo.stages = base_stages.duplicate(true)
	for data in player.combo.stages:
		data.damage = float(data.damage) * (1.0 + CONFIG.SWORD_BONUS * reward_counts[0])
	player.max_health = base_health + CONFIG.HEALTH_BONUS * reward_counts[1]
	player.roll_cooldown = base_roll * pow(CONFIG.ROLL_FACTOR, reward_counts[2])

func _on_enemy_killed(_point: Vector2, _xp: int) -> void:
	if phase != "combat":
		return
	remaining -= 1
	run_kills += 1
	if remaining == 0:
		phase = "reward_wait"
		world.room_cleared = true
		world.reward_visible = true
		world.queue_redraw()
	_update_status()

func _physics_process(_delta: float) -> void:
	if get_tree().paused:
		return
	if phase == "reward_wait" and player.global_position.distance_to(world.cell_center(CONFIG.REWARD_CELL)) <= CONFIG.REWARD_RADIUS:
		phase = "reward_select"
		get_tree().paused = true
		hud.show_rewards()
	elif phase == "exit_ready" and player.global_position.distance_to(world.cell_center(world.PORTAL_CELL)) < 34.0:
		room_index += 1
		phase = "transition"
		_enter_room.call_deferred()

func select_reward(index: int) -> void:
	if phase != "reward_select" or index < 0 or index >= reward_counts.size():
		return
	phase = "exit_ready"
	reward_counts[index] += 1
	_apply_rewards()
	if index == 1:
		player.health = minf(player.max_health, player.health + CONFIG.HEALTH_BONUS)
	world.reward_visible = false
	world.portal_open = true
	world.queue_redraw()
	hud.hide_screen()
	get_tree().paused = false
	_update_status()

func _update_status() -> void:
	match phase:
		"combat": status.text = "第 %d / 3 间 · 清除全部敌人" % (room_index + 1)
		"reward_wait", "reward_select": status.text = "已清场 · 靠近中央金色奖励，选择后开放出口"
		"exit_ready": status.text = "已领奖 · 前往右侧出口"
		"cleared": status.text = "终点房间 · 本局通关"
		"dead": status.text = "角色倒下 · 重开将清空本局奖励"

func toggle_pause() -> void:
	if menu_open:
		resume_room()
	elif phase in ["combat", "reward_wait", "exit_ready"]:
		menu_open = true
		stats_open = false
		get_tree().paused = true
		hud.show_pause()

func toggle_stats() -> void:
	if menu_open:
		resume_room()
	elif phase in ["combat", "reward_wait", "exit_ready"]:
		menu_open = true
		stats_open = true
		get_tree().paused = true
		hud.show_stats()

func _show_result(completed: bool) -> void:
	menu_open = false
	stats_open = false
	get_tree().paused = true
	hud.update_room(remaining, total, triggered_count)
	hud.show_run_result(completed)

extends "res://scripts/room_game.gd"

const CONFIG = preload("res://scripts/v41_config.gd")
const COMBO_PLAYER = preload("res://scenes/player_v41.tscn")
var room_index := 0
var reward_counts: Array[int] = [0, 0, 0, 0]
var run_kills := 0
var base_stages: Array[Dictionary] = []
var close_view := false
var scheduler: RefCounted
var wave_index := 0
var wave_remaining := 0
var reward_options: Array[int] = []
var reward_rng := RandomNumberGenerator.new()

func _ready() -> void:
	_setup_inputs()
	world.build_battle()
	_build_ui()
	get_viewport().size_changed.connect(_update_camera)
	start_room()

func _create_player() -> SurvivorPlayer:
	return COMBO_PLAYER.instantiate()

func _build_ui() -> void:
	super._build_ui()
	reward_rng.randomize()
	hud.run = self
	hud.reward_selected.connect(select_reward)

# All existing restart signals reset the run; room transitions use _enter_room.
func start_room() -> void:
	room_index = 0
	reward_counts.assign([0, 0, 0, 0])
	run_kills = 0
	reward_options.clear()
	_enter_room()

func _enter_room() -> void:
	var carried_health := -1.0
	var carried_stamina := -1.0
	if room_index > 0 and is_instance_valid(player):
		carried_health = player.health
		carried_stamina = player.stamina
	get_tree().paused = false
	menu_open = false
	stats_open = false
	scheduler = null
	for child in world.actors.get_children():
		child.free()
	for child in feedback.get_children():
		child.free()
	feedback.popups.clear()
	feedback.bursts.clear()
	feedback.shake_time = 0.0
	feedback.shake_strength = 0.0
	$Camera2D.offset = Vector2.ZERO
	world.portal_open = false
	phase = "combat"
	player = _create_player()
	player.position = CONFIG.ENTRY_POINT
	player.collision_mask = 1 | 4
	world.actors.add_child(player)
	player.enable_dual_attack()
	player.camera.enabled = false
	world.visitor = player
	$Camera2D.make_current()
	feedback.camera = $Camera2D
	player.died.connect(_on_player_died)
	player.damage_received.connect(func(amount): feedback.show_damage(player.global_position, amount, true))
	player.hurt.connect(hud.flash_damage)
	player.bow_fired.connect(func():
		feedback.shake_strength = maxf(feedback.shake_strength, 3.5)
		feedback.shake_time = maxf(feedback.shake_time, 0.18))
	hud.player = player
	hud.hurt_flash.color.a = 0.0
	hud.notice_time = 0.0
	hud.notice.text = ""
	hud.hide_screen()
	world.reward_visible = false
	world.room_cleared = false
	base_stages = player.combo.stages.duplicate(true)
	_apply_rewards()
	player.combo.hold_threshold = CONFIG.HOLD_THRESHOLD
	player.combo.charge_duration = CONFIG.CHARGE_DURATION
	player.combo.charged_attack = player.combo.charged_attack.duplicate(true)
	player.combo.charged_attack.reach = CONFIG.CHARGE_REACH
	player.combo.charged_attack.angle = CONFIG.CHARGE_ANGLE
	if carried_health >= 0.0:
		player.health = carried_health
		player.stamina = carried_stamina
	player.weapon.heavy_hit.connect(func():
		feedback.shake_strength = maxf(feedback.shake_strength, 9.0 if player.combo.charged_swing else 6.0)
		feedback.shake_time = maxf(feedback.shake_time, 0.18))
	if room_index == CONFIG.WAVES.size():
		total = 0
		remaining = 0
		triggered_count = 0
		phase = "cleared"
		world.room_cleared = true
		_update_status()
		_show_result(true)
	else:
		wave_index = 0
		total = CONFIG.room_total(room_index)
		remaining = total
		triggered_count = 0
		reward_options.clear()
		_spawn_wave()
		_update_status()
	hud.update_room(remaining, total, triggered_count)
	world.queue_redraw()
	_update_camera()

func _apply_rewards() -> void:
	player.combo.stages = base_stages.duplicate(true)
	for data in player.combo.stages:
		data.damage = float(data.damage) * (1.0 + CONFIG.SWORD_BONUS * reward_counts[0])
	player.combo.charge_damage_min = CONFIG.CHARGE_MIN * (1.0 + CONFIG.SWORD_BONUS * reward_counts[0])
	player.combo.charge_damage_max = CONFIG.CHARGE_MAX * (1.0 + CONFIG.SWORD_BONUS * reward_counts[0])
	player.combo.roll_reward = reward_counts[1] > 0
	player.combo.heavy_reward = reward_counts[3] > 0

func _spawn_wave() -> void:
	if phase == "dead":
		return
	phase = "combat"
	var kinds: Array = CONFIG.WAVES[room_index][wave_index]
	wave_remaining = kinds.size()
	var points: Array[Vector2] = CONFIG.SPAWN_POINTS.duplicate()
	var melee: Array = []
	# Six spaced courtyard points for at most four enemies; avoid the player.
	points = points.filter(func(point): return point.distance_to(player.position) >= CONFIG.SPAWN_CLEARANCE)
	for i in range(kinds.size()):
		var type: int = kinds[i]
		var enemy: SurvivorEnemy = ENEMY.instantiate()
		enemy.world = world
		enemy.kind = SurvivorEnemy.Kind.RANGED if type == CONFIG.RANGED else SurvivorEnemy.Kind.HOSTILE
		enemy.dodge_enabled = false
		enemy.fast_chaser = type == CONFIG.THRUST
		enemy.thrust_type = type == CONFIG.THRUST
		enemy.encounter_id = 0
		enemy.max_simultaneous_attackers = CONFIG.ATTACK_LIMIT
		enemy.collision_mask = 1 | 2 | 4
		enemy.position = points[i]
		enemy.waiting_radius = CONFIG.WAITING_RADIUS
		enemy.home_position = enemy.position
		enemy.side_sign = 1.0 if i % 2 == 0 else -1.0
		enemy.killed.connect(_on_enemy_killed)
		enemy.damaged.connect(func(point: Vector2, amount: float): feedback.show_damage(point, amount, false))
		world.actors.add_child(enemy)
		var stats: Dictionary = CONFIG.ENEMY_STATS[type]
		enemy.max_health = float(stats.health) * CONFIG.ROOM_SCALES[room_index]
		enemy.health = enemy.max_health
		enemy.damage = float(stats.damage) * CONFIG.ROOM_SCALES[room_index]
		triggered_count += 1
		if enemy.kind == SurvivorEnemy.Kind.HOSTILE:
			melee.append(enemy)
	scheduler = preload("res://scripts/pair_scheduler.gd").new()
	scheduler.configure(melee, CONFIG.PAIR_SIZE, CONFIG.PAIR_APPROACH_TIMEOUT)
	_update_status()

func _on_enemy_killed(_point: Vector2, _xp: int) -> void:
	if phase != "combat":
		return
	remaining -= 1
	wave_remaining -= 1
	run_kills += 1
	if not player.dead:
		player.health = minf(player.max_health, player.health + CONFIG.KILL_HEAL * reward_counts[2])
	if wave_remaining == 0 and remaining > 0:
		phase = "wave_transition"
		wave_index += 1
		_spawn_wave.call_deferred()
	elif remaining == 0:
		phase = "reward_wait"
		world.room_cleared = true
		world.reward_visible = true
		world.queue_redraw()
	_update_status()

func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	if phase == "combat" and is_instance_valid(scheduler):
		scheduler.tick(delta)
	_update_camera()
	if phase == "reward_wait" and player.global_position.distance_to(CONFIG.REWARD_POINT) <= CONFIG.REWARD_RADIUS:
		phase = "reward_select"
		get_tree().paused = true
		_draw_rewards()
		hud.show_rewards()
	elif phase == "exit_ready" and player.global_position.distance_to(CONFIG.EXIT_POINT) < 34.0:
		room_index += 1
		phase = "transition"
		_enter_room.call_deferred()

func _draw_rewards() -> void:
	reward_options.assign([0, 1, 2, 3])
	for i in range(reward_options.size() - 1, 0, -1):
		var j := reward_rng.randi_range(0, i)
		var previous := reward_options[i]
		reward_options[i] = reward_options[j]
		reward_options[j] = previous
	reward_options.resize(3)

func can_select_reward(index: int) -> bool:
	return index in reward_options and not (index in [1, 3] and reward_counts[index] > 0)

func select_reward(index: int) -> void:
	if phase != "reward_select" or not can_select_reward(index):
		return
	phase = "exit_ready"
	reward_counts[index] += 1
	_apply_rewards()
	world.reward_visible = false
	world.portal_open = true
	world.queue_redraw()
	hud.hide_screen()
	get_tree().paused = false
	_update_status()

func _update_status() -> void:
	match phase:
		"combat": status.text = "第 %d / 3 间 · 第 %d / %d 波" % [room_index + 1, wave_index + 1, CONFIG.WAVES[room_index].size()]
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

func toggle_view() -> void:
	close_view = not close_view
	_update_camera()

func _update_camera() -> void:
	if not is_instance_valid(player):
		return
	var viewport := get_viewport_rect().size
	var fit: float = maxf(viewport.x / world.ART_SIZE.x, viewport.y / world.ART_SIZE.y)
	$Camera2D.zoom = Vector2.ONE * fit * (1.3 if close_view else 1.0)
	var half: Vector2 = viewport / $Camera2D.zoom * 0.5
	var focus: Vector2 = player.position if close_view else world.ART_SIZE * 0.5
	$Camera2D.position = Vector2(clampf(focus.x, half.x, world.ART_SIZE.x - half.x), clampf(focus.y, half.y, world.ART_SIZE.y - half.y))

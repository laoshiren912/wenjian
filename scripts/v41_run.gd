extends "res://scripts/room_game.gd"

const CONFIG = preload("res://scripts/v41_config.gd")
const MINI_BOSS = preload("res://scripts/v41_boss.gd")
const COMBO_PLAYER = preload("res://scenes/player_v41.tscn")
const CARD_POOL = preload("res://scripts/v41_card_pool.gd")
const MELEE_DEATH_SMOKE = preload("res://assets/vfx/pvfx-small-explosion-tail/smoke-frames.tres")
var room_index := 0
var reward_counts: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
var run_kills := 0
var base_stages: Array[Dictionary] = []
var close_view := false
var scheduler: RefCounted
var boss: SurvivorEnemy
var wave_index := 0
var wave_remaining := 0
var reward_options: Array[int] = []
var reward_rng := RandomNumberGenerator.new()
var cultivation_override := -1
var gm_invincible := false
var gm_infinite_stamina := false
var gm_spawned: Array[Node] = []
var hitstop_generation := 0
var saved_time_scale := 1.0
var hitstop_active := false

func _end_hitstop() -> void:
	hitstop_generation += 1
	if hitstop_active:
		Engine.time_scale = saved_time_scale
		hitstop_active = false

func _exit_tree() -> void:
	_end_hitstop()

func _third_impact(_point: Vector2) -> void:
	feedback.shake_strength = maxf(feedback.shake_strength, CONFIG.THIRD_SHAKE)
	feedback.shake_time = maxf(feedback.shake_time, CONFIG.THIRD_SHAKE_TIME)
	if hitstop_active:
		return
	saved_time_scale = Engine.time_scale
	hitstop_active = true
	hitstop_generation += 1
	var generation := hitstop_generation
	Engine.time_scale = CONFIG.THIRD_HITSTOP_SCALE
	await get_tree().create_timer(CONFIG.THIRD_HITSTOP, true, false, true).timeout
	if generation == hitstop_generation:
		_end_hitstop()

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
	_end_hitstop()
	gm_invincible = false
	gm_infinite_stamina = false
	room_index = 0
	reward_counts.assign([0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
	run_kills = 0
	cultivation_override = -1
	reward_options.clear()
	_enter_room()

func _enter_room(returning_to_room_one := false) -> void:
	_end_hitstop()
	var carried_health := -1.0
	var carried_stamina := -1.0
	if room_index > 0 and is_instance_valid(player):
		carried_health = player.health
		carried_stamina = player.stamina
	get_tree().paused = false
	menu_open = false
	stats_open = false
	scheduler = null
	boss = null
	for child in world.actors.get_children():
		child.free()
	for child in feedback.get_children():
		child.free()
	feedback.popups.clear()
	feedback.bursts.clear()
	feedback.guard_effects.clear()
	feedback.reset_sword_cues()
	feedback.shake_time = 0.0
	feedback.shake_strength = 0.0
	$Camera2D.offset = Vector2.ZERO
	world.portal_open = false
	world.set_room_style(room_index)
	phase = "combat"
	player = _create_player()
	gm_spawned.clear()
	player.gm_invulnerable = OS.is_debug_build() and gm_invincible
	player.gm_infinite_stamina = OS.is_debug_build() and gm_infinite_stamina
	player.position = CONFIG.ROOM1_RETURN if returning_to_room_one else CONFIG.ROOM_ENTRY_POINTS[room_index]
	player.collision_mask = world.terrain_movement_mask | 4
	player.terrain_mask = world.terrain_movement_mask
	world.actors.add_child(player)
	if room_index == 0 and not returning_to_room_one:
		player.visual.update_pose(Vector2.ZERO, Vector2.UP, Color.WHITE, Vector2.UP)
	player.enable_dual_attack()
	player.max_stamina = CONFIG.STAMINA_MAX
	player.stamina = CONFIG.STAMINA_MAX
	player.stamina_regen = CONFIG.STAMINA_REGEN
	player.camera.enabled = false
	world.visitor = player
	$Camera2D.make_current()
	feedback.camera = $Camera2D
	player.died.connect(_on_player_died)
	player.damage_received.connect(func(amount): feedback.show_damage(player.global_position, amount, true))
	player.hurt.connect(hud.flash_damage)
	hud.player = player
	hud.hurt_flash.color.a = 0.0
	hud.notice_time = 0.0
	hud.notice.text = ""
	hud.hide_screen()
	world.reward_visible = false
	world.room_cleared = false
	base_stages = player.combo.stages.duplicate(true)
	_apply_rewards()
	player.cultivation = _cultivation_rank()
	if carried_health >= 0.0:
		player.health = carried_health
		player.stamina = carried_stamina
	player.combo.finisher_contact.connect(_third_impact)
	player.combo.guard_broken.connect(feedback.show_guard_break)
	player.sword_cue.connect(feedback.play_sword_cue)
	wave_index = 0
	total = 1 if room_index == CONFIG.BOSS_ROOM else CONFIG.room_total(room_index)
	remaining = total
	triggered_count = 0
	reward_options.clear()
	if room_index == CONFIG.BOSS_ROOM:
		_spawn_boss()
	else:
		_spawn_wave()
	_update_status()
	hud.update_room(remaining, total, triggered_count)
	world.queue_redraw()
	_update_camera()

func _apply_rewards() -> void:
	player.combo.stages = base_stages.duplicate(true)
	player.combo.card_multiplier = 1.0 + CONFIG.SWORD_BONUS * reward_counts[0]
	for data in player.combo.stages:
		data.damage = float(data.damage) * player.combo.card_multiplier
	player.combo.dash_reward = reward_counts[1] > 0
	player.combo.heavy_reward = reward_counts[3] > 0

func _cultivation_rank() -> int:
	if cultivation_override >= 0:
		return cultivation_override
	for rank in range(CONFIG.CULTIVATION_KILLS.size() - 1, 0, -1):
		if run_kills >= CONFIG.CULTIVATION_KILLS[rank]:
			return rank
	return 0

func _spawn_wave() -> void:
	if phase == "dead":
		return
	phase = "combat"
	var kinds: Array = CONFIG.WAVES[room_index][wave_index]
	wave_remaining = kinds.size()
	var points: Array[Vector2] = (CONFIG.ROOM2_SPAWN_POINTS if room_index == 1 else CONFIG.SPAWN_POINTS).duplicate()
	var melee: Array = []
	# Six spaced courtyard points for at most five enemies; avoid the player.
	points = points.filter(func(point): return point.distance_to(player.position) >= CONFIG.SPAWN_CLEARANCE)
	for i in range(kinds.size()):
		var type: int = kinds[i]
		var enemy: SurvivorEnemy = ENEMY.instantiate()
		enemy.get_node("VisualRoot").set_script(preload("res://scripts/v41_pixel_visual.gd"))
		enemy.world = world
		enemy.kind = SurvivorEnemy.Kind.RANGED if type == CONFIG.RANGED else SurvivorEnemy.Kind.HOSTILE
		enemy.dodge_enabled = false
		enemy.fast_chaser = type == CONFIG.THRUST
		enemy.thrust_type = type == CONFIG.THRUST
		enemy.encounter_id = 0
		enemy.v41_pressure = true
		enemy.intro_room = room_index < 2
		enemy.max_simultaneous_attackers = CONFIG.ATTACK_LIMIT
		enemy.collision_mask = world.terrain_movement_mask | 2 | 4
		enemy.position = points[i]
		enemy.waiting_radius = 180.0 if room_index < 2 else CONFIG.WAITING_RADIUS
		enemy.home_position = enemy.position
		enemy.side_sign = 1.0 if i % 2 == 0 else -1.0
		_connect_enemy(enemy)
		if room_index == 0 and type == CONFIG.MELEE:
			enemy.killed.connect(_play_melee_death_smoke, CONNECT_ONE_SHOT)
		world.actors.add_child(enemy)
		var stats: Dictionary = CONFIG.ENEMY_STATS[type]
		enemy.speed = float(stats.speed)
		enemy.guard_cooldown = 0.0
		enemy.attack_cooldown = 0.25 if type == CONFIG.RANGED else 0.0
		enemy.max_health = float(stats.health) * CONFIG.ROOM_SCALES[room_index]
		enemy.health = enemy.max_health
		enemy.damage = float(stats.damage) * CONFIG.ROOM_SCALES[room_index]
		triggered_count += 1
		if enemy.kind == SurvivorEnemy.Kind.HOSTILE:
			melee.append(enemy)
	scheduler = preload("res://scripts/pair_scheduler.gd").new()
	scheduler.configure(melee, CONFIG.PAIR_SIZE, CONFIG.PAIR_APPROACH_TIMEOUT)
	melee[0].alert_encounter(player.global_position)
	_update_status()

func _spawn_boss() -> void:
	boss = ENEMY.instantiate()
	boss.set_script(MINI_BOSS)
	boss.world = world
	boss.position = CONFIG.REWARD_POINT
	boss.collision_mask = 1 | 2
	_connect_enemy(boss)
	world.actors.add_child(boss)
	wave_remaining = 1
	triggered_count = 1

func _connect_enemy(enemy: SurvivorEnemy) -> void:
	enemy.killed.connect(_on_enemy_killed)
	enemy.damaged.connect(func(point: Vector2, amount: float):
		feedback.show_damage(point, amount, false, enemy.damage_shakes_camera,
			enemy.last_hit_blocked))

func _play_melee_death_smoke(point: Vector2, _xp: int) -> void:
	var smoke := AnimatedSprite2D.new()
	smoke.sprite_frames = MELEE_DEATH_SMOKE
	smoke.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	smoke.centered = false
	# Align the source ground pivot with the Bandit's feet, below its body origin.
	smoke.offset = Vector2(-32, -57)
	smoke.animation_finished.connect(smoke.queue_free)
	world.actors.add_child(smoke)
	smoke.global_position = point + Vector2(0, 12)
	smoke.play()

func _on_enemy_killed(_point: Vector2, _xp: int) -> void:
	if phase != "combat":
		return
	remaining -= 1
	wave_remaining -= 1
	run_kills += 1
	if not player.dead:
		player.health = minf(player.max_health, player.health + CONFIG.KILL_HEAL * reward_counts[2])
		var rank := _cultivation_rank()
		if player.cultivation != rank:
			player.cultivation = rank
			hud.show_notice("修为进阶 · " + CONFIG.CULTIVATION_NAMES[rank])
	if room_index == CONFIG.BOSS_ROOM:
		phase = "cleared"
		world.room_cleared = true
		_update_status()
		_show_result(true)
		return
	if wave_remaining == 0 and remaining > 0:
		phase = "wave_transition"
		wave_index += 1
		_spawn_wave.call_deferred()
	elif remaining == 0:
		phase = "reward_select"
		world.room_cleared = true
		world.queue_redraw()
		get_tree().paused = true
		_draw_rewards()
		hud.show_rewards()
	_update_status()

func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	if phase == "combat" and is_instance_valid(scheduler):
		scheduler.tick(delta)
	_update_camera()
	if phase == "exit_ready" and world.at_exit(player.global_position):
		room_index += 1
		phase = "transition"
		_enter_room.call_deferred()

func _input(event: InputEvent) -> void:
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_QUOTELEFT:
		_debug_menu()
		get_viewport().set_input_as_handled()
		return
	super._input(event)

func _draw_rewards() -> void:
	reward_options = CARD_POOL.draw(reward_counts, reward_rng)

func can_select_reward(index: int) -> bool:
	return index in reward_options and CARD_POOL.eligible(index, reward_counts)

func select_reward(index: int) -> void:
	if phase != "reward_select" or not can_select_reward(index):
		return
	reward_counts[index] += 1
	_apply_rewards()
	phase = "exit_ready"
	world.reward_visible = false
	world.portal_open = true
	world.queue_redraw()
	hud.hide_screen()
	get_tree().paused = false
	_update_status()

func _debug_menu() -> void:
	if not OS.is_debug_build():
		return
	get_tree().paused = true
	hud.show_card_debug()

func debug_toggle_invincible() -> void:
	if not OS.is_debug_build(): return
	gm_invincible = not gm_invincible
	player.gm_invulnerable = gm_invincible
	hud.show_card_debug()

func debug_toggle_stamina() -> void:
	if not OS.is_debug_build(): return
	gm_infinite_stamina = not gm_infinite_stamina
	player.gm_infinite_stamina = gm_infinite_stamina
	hud.show_card_debug()

func debug_fill_stamina() -> void:
	if not OS.is_debug_build(): return
	player.stamina = player.max_stamina

func debug_jump(index: int) -> void:
	if not OS.is_debug_build() or index < 0 or index >= CONFIG.RUN_ROOMS: return
	var returning_to_room_one := room_index == 1 and index == 0
	room_index = index
	_enter_room(returning_to_room_one)
	get_tree().paused = true
	hud.show_card_debug()

func debug_spawn(kind: int, count: int) -> void:
	if not OS.is_debug_build() or kind < 0 or kind > 3: return
	var spawn_count := clampi(count, 1, 20)
	var use_walkable_spawns := room_index == 0 or room_index >= 3
	var available: Array[Vector2] = []
	if use_walkable_spawns:
		available.assign(world.floor_cells.map(world.cell_center))
		for actor in world.actors.get_children():
			if actor is CharacterBody2D:
				available = available.filter(func(point): return point.distance_squared_to(actor.position) >= 32.0 * 32.0)
	for i in range(spawn_count):
		var target: Vector2 = player.position + player.aim_direction.normalized() * 100.0 + player.aim_direction.orthogonal() * (i - (spawn_count - 1) * 0.5) * 35.0
		var point := target
		if use_walkable_spawns:
			if available.is_empty():
				break
			available.sort_custom(func(a, b): return a.distance_squared_to(target) < b.distance_squared_to(target))
			point = available.pop_front()
		var enemy: SurvivorEnemy = ENEMY.instantiate()
		if kind != 3:
			enemy.get_node("VisualRoot").set_script(preload("res://scripts/v41_pixel_visual.gd"))
		if kind == 3:
			enemy.set_script(MINI_BOSS)
		enemy.world = world
		enemy.position = point
		enemy.collision_mask = world.terrain_movement_mask | 2 | 4
		if kind != 3:
			enemy.kind = SurvivorEnemy.Kind.RANGED if kind == 2 else SurvivorEnemy.Kind.HOSTILE
			enemy.encounter_id = 0
			enemy.v41_pressure = true
			enemy.intro_room = room_index < 2
			enemy.home_position = enemy.position
		enemy.damaged.connect(func(point: Vector2, amount: float): feedback.show_damage(point, amount, false, enemy.damage_shakes_camera, enemy.last_hit_blocked))
		world.actors.add_child(enemy)
		gm_spawned.append(enemy)
		if kind != 3:
			var stats: Dictionary = CONFIG.ENEMY_STATS[CONFIG.RANGED if kind == 2 else CONFIG.MELEE]
			enemy.speed = stats.speed
			enemy.max_health = stats.health
			enemy.health = enemy.max_health
			enemy.damage = stats.damage
			enemy.alert_encounter(player.global_position)
			if kind == 1:
				enemy.guard_direction = (player.global_position - enemy.global_position).normalized()
				enemy.guard_time = CONFIG.GUARD_HOLD
				enemy.guard_visual_time = CONFIG.GUARD_DISPLAY
			if kind != 2:
				if not is_instance_valid(scheduler):
					scheduler = preload("res://scripts/pair_scheduler.gd").new()
					scheduler.configure([enemy], CONFIG.PAIR_SIZE, CONFIG.PAIR_APPROACH_TIMEOUT)
				else:
					scheduler.groups.append([enemy])
					enemy.pair_scheduler = scheduler

func debug_clear_enemies() -> void:
	if not OS.is_debug_build(): return
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.dead: continue
		enemy.take_damage(enemy.health * 4.0 + 1.0, Vector2.ZERO, true)

func debug_grant(index: int) -> void:
	if not OS.is_debug_build() or not CARD_POOL.eligible(index, reward_counts):
		return
	reward_counts[index] += 1
	_apply_rewards()
	hud.show_card_debug()

func debug_cultivation(rank: int) -> void:
	if not OS.is_debug_build() or not is_instance_valid(player) or player.dead:
		return
	cultivation_override = clampi(rank, -1, CONFIG.CULTIVATION_NAMES.size() - 1)
	player.clear_dash_effects()
	player.clear_throw()
	player.combo.reset_chain()
	player.combo.swing_time = 0.0
	player.visual.cancel_attack()
	player.dash_cooldown = 0.0
	player.throw_cooldown = 0.0
	player.cultivation = _cultivation_rank()
	hud.show_card_debug()

func debug_close() -> void:
	if not OS.is_debug_build():
		return
	if phase == "reward_select":
		hud.show_rewards()
	else:
		hud.hide_screen()
		get_tree().paused = false

func _update_status() -> void:
	match phase:
		"combat":
			status.text = "守庭者 · 躲开横扫扇区与突进直线，趁收招反击" if room_index == CONFIG.BOSS_ROOM else "第 %d / %d 间 · 第 %d / %d 波" % [room_index + 1, CONFIG.RUN_ROOMS, wave_index + 1, CONFIG.WAVES[room_index].size()]
		"reward_select": status.text = "已清场 · 选择奖励后开放出口"
		"exit_ready": status.text = "已领奖 · 前往" + CONFIG.ROOM_EXIT_LABELS[room_index]
		"cleared": status.text = "守庭者已击败 · 本局通关"
		"dead": status.text = "角色倒下 · 重开将清空本局奖励"

func toggle_pause() -> void:
	if menu_open:
		resume_room()
	elif phase in ["combat", "exit_ready"]:
		menu_open = true
		stats_open = false
		get_tree().paused = true
		hud.show_pause()

func toggle_stats() -> void:
	if menu_open:
		resume_room()
	elif phase in ["combat", "exit_ready"]:
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
	var fit: float = minf(viewport.x / world.ART_SIZE.x, viewport.y / world.ART_SIZE.y)
	if room_index <= 1 or not close_view:
		$Camera2D.zoom = Vector2.ONE * fit
		$Camera2D.position = world.ART_SIZE * 0.5
		return
	$Camera2D.zoom = Vector2.ONE * fit * 1.3
	var half: Vector2 = (viewport / $Camera2D.zoom * 0.5).min(world.ART_SIZE * 0.5)
	$Camera2D.position = player.position.clamp(half, world.ART_SIZE - half)

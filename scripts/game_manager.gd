class_name SurvivorGame
extends Node2D

const PLAYER_SCENE = preload("res://scenes/player.tscn")
const ENEMY_SCENE = preload("res://scenes/enemy.tscn")
const RUN_DURATION: float = 180.0
const START_GOLD: int = 300
const FLOOR_GOLD: int = 250
@export var v31_classic: bool = false
const EQUIPMENT: Array[Dictionary] = [
	{"category": 0, "name": "长锋石", "price": 200, "effect": "伤害倍率 +10 个百分点；攻击距离 +25"},
	{"category": 0, "name": "猎手护符", "price": 250, "effect": "攻速倍率 +10 个百分点；击杀恢复 5 体力"},
	{"category": 0, "name": "破阵徽章", "price": 450, "effect": "伤害倍率 +15 个百分点；剑多击中 1 个目标 / 矛距离 +25 / 弓多射 1 支"},
	{"category": 2, "name": "守护甲", "price": 200, "effect": "生命上限与当前生命 +20；受伤减免 5%"},
	{"category": 2, "name": "汲生甲", "price": 250, "effect": "生命上限与当前生命 +20；击杀恢复 3 生命"},
	{"category": 2, "name": "坚壁甲", "price": 450, "effect": "生命上限与当前生命 +35；受伤减免 10%"},
	{"category": 3, "name": "轻行靴", "price": 200, "effect": "移速 +8；体力恢复 +8 / 秒"},
	{"category": 3, "name": "灵巧靴", "price": 250, "effect": "移速 +8；翻滚冷却 -0.10 秒"},
	{"category": 3, "name": "远行靴", "price": 450, "effect": "移速 +15；翻滚距离 +30"},
]
enum State { START, PLAYING, PAUSED, DEAD, WON, SHOP, SHOP_PROMPT }
var state: int = State.START
var player: SurvivorPlayer
var elapsed: float = 0.0
var kills: int = 0
var spawn_timer: float = 4.0
var stats_open: bool = false
var selected_profession: int = 0
var floor_number: int = 1
var remaining: int = 0
var gold: int = START_GOLD
var clear_pending: bool = false
var purchased: Array[bool] = [false, false, false, false, false, false, false, false, false]
var shop_category: int = 4
var manual_claimed_floor: int = 0
var gm_bonus_granted: bool = false
var pending_wave: Array[Dictionary] = []
var wave_delay: float = 0.0
@onready var world: SurvivorWorld = $World
@onready var hud = $HUD
@onready var feedback = $World/CombatFeedback

func _ready() -> void:
	_setup_inputs()
	world.build()
	player = PLAYER_SCENE.instantiate()
	player.position = SurvivorWorld.SPAWN
	if not v31_classic:
		player.collision_mask = 1 | 4
	world.actors.add_child(player)
	if not v31_classic:
		player.enable_dual_attack()
	player.camera.limit_left = 0
	player.camera.limit_top = 0
	player.camera.limit_right = int(SurvivorWorld.SIZE.x)
	player.camera.limit_bottom = int(SurvivorWorld.SIZE.y)
	player.camera.reset_smoothing()
	player.died.connect(_on_death)
	player.level_gained.connect(_on_level_gained)
	player.hurt.connect(hud.flash_damage)
	feedback.camera = player.camera
	feedback.hud_obstacles.assign(hud.combat_panels)
	player.damage_received.connect(_on_player_damaged)
	player.experience_received.connect(_on_experience_received)
	hud.player = player
	hud.start_requested.connect(start_run)
	hud.profession_requested.connect(select_profession)
	hud.restart_requested.connect(restart_run)
	hud.stats_requested.connect(show_stats)
	hud.pause_requested.connect(toggle_pause)
	hud.resume_requested.connect(resume_run)
	hud.purchase_requested.connect(buy_item)
	hud.shop_category_requested.connect(select_shop_category)
	hud.shop_continue_requested.connect(open_shop)
	hud.next_floor_requested.connect(next_floor)
	hud.manual_requested.connect(claim_manual)
	hud.manual_upgrade_requested.connect(upgrade_manual)
	hud.gm_toggle_requested.connect(set_gm_mode)
	hud.gm_gold_requested.connect(add_gm_gold)
	hud.gm_kill_requested.connect(gm_kill_floor)
	hud.gm_floor_requested.connect(gm_select_floor)
	_spawn_floor()
	hud.update_game(elapsed, kills, RUN_DURATION)
	if v31_classic:
		hud.show_start()
		get_tree().paused = true
	else:
		start_run()

func _setup_inputs() -> void:
	var keys := {"move_up": KEY_W, "move_down": KEY_S, "move_left": KEY_A, "move_right": KEY_D, "profession_1": KEY_1, "profession_2": KEY_2, "profession_3": KEY_3, "stats": KEY_TAB, "pause": KEY_ESCAPE, "restart": KEY_R, "roll": KEY_SPACE, "skill_1": KEY_Q, "skill_2": KEY_E}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var event := InputEventKey.new()
			event.physical_keycode = keys[action]
			InputMap.action_add_event(action, event)
			# Also accept logical key events from virtual keyboards and accessibility tools.
			var logical := InputEventKey.new()
			logical.keycode = keys[action]
			InputMap.action_add_event(action, logical)
	if not InputMap.has_action("attack"):
		InputMap.add_action("attack")
		var mouse := InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("attack", mouse)
	if not InputMap.has_action("ranged_attack"):
		InputMap.add_action("ranged_attack")
		var mouse := InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_RIGHT
		InputMap.action_add_event("ranged_attack", mouse)

func select_profession(index: int) -> void:
	if state != State.START or index < 0 or index >= SurvivorPlayer.PROFESSIONS.size():
		return
	selected_profession = index
	hud.select_profession(index)

func set_gm_mode(enabled: bool) -> void:
	if not preload("res://scripts/test_runtime.gd").enabled():
		return
	if state != State.START and state != State.PAUSED:
		return
	player.gm_invulnerable = enabled
	if enabled:
		player.health = player.max_health
		if state == State.PAUSED:
			_grant_gm_bonus()
	if state == State.PAUSED:
		hud.show_gm_panel(gold)

func add_gm_gold() -> void:
	if not preload("res://scripts/test_runtime.gd").enabled():
		return
	if state == State.PAUSED and player.gm_invulnerable:
		gold += 1000
		hud.show_gm_panel(gold)

func gm_kill_floor() -> void:
	if not preload("res://scripts/test_runtime.gd").enabled():
		return
	if state != State.PAUSED or not player.gm_invulnerable:
		return
	remaining = maxi(0, remaining - pending_wave.size())
	pending_wave.clear()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy.dead:
			enemy.take_damage(enemy.health + 1.0, Vector2.ZERO, true)
	resume_run()

func gm_select_floor(floor: int) -> void:
	if not preload("res://scripts/test_runtime.gd").enabled():
		return
	if state != State.PAUSED or not player.gm_invulnerable or floor < 1 or floor > 4:
		return
	floor_number = floor
	world.rebuild_floor(player)
	_spawn_floor()
	clear_pending = false
	resume_run()
	hud.show_notice("GM 选关 · 第 %d 层" % floor)

func _grant_gm_bonus() -> void:
	if not preload("res://scripts/test_runtime.gd").enabled():
		return
	if not gm_bonus_granted:
		gold += 5000
		gm_bonus_granted = true

func start_run() -> void:
	if state != State.START:
		return
	if v31_classic and not player.initialize_profession(selected_profession):
		return
	if player.gm_invulnerable:
		_grant_gm_bonus()
	state = State.PLAYING
	hud.hide_screen()
	hud.update_game(elapsed, kills, RUN_DURATION)
	get_tree().paused = false
	hud.show_notice("试炼开始 · 击败敌人获得经验")

func _process(delta: float) -> void:
	if state == State.PLAYING and not get_tree().paused:
		elapsed += delta
		if not v31_classic and not pending_wave.is_empty():
			wave_delay -= delta
			if wave_delay <= 0.0:
				_spawn_rear_wave()
		if remaining == 0 and not clear_pending:
			clear_pending = true
			_floor_cleared.call_deferred()
	var nearest: Vector2 = Vector2.ZERO
	var best := INF
	if is_instance_valid(player):
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if enemy.dead:
				continue
			var distance: float = player.global_position.distance_squared_to(enemy.global_position)
			if distance < best:
				best = distance
				nearest = (enemy.global_position - player.global_position).normalized()
	hud.update_tower(floor_number, remaining, gold, nearest, pending_wave.size())
	hud.update_game(elapsed, kills, RUN_DURATION)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	# Space is the combat roll key. Do not let it activate the focused result button.
	if (state == State.DEAD or state == State.WON) and event is InputEventKey and (event.keycode == KEY_SPACE or event.physical_keycode == KEY_SPACE):
		get_viewport().set_input_as_handled()
		return
	if state == State.START:
		for index in range(SurvivorPlayer.PROFESSIONS.size()):
			if event.is_action_pressed("profession_%d" % (index + 1)):
				select_profession(index)
				get_viewport().set_input_as_handled()
				return
		if event is InputEventKey and event.pressed and (event.keycode in [KEY_ENTER, KEY_KP_ENTER] or event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]):
			start_run()
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("stats"):
		if state == State.PLAYING:
			show_stats()
		elif state == State.PAUSED:
			resume_run()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("restart") and (state == State.DEAD or state == State.WON):
		restart_run()

func _spawn_enemy(kind: int, location: Vector2, fast: bool = false) -> SurvivorEnemy:
	var enemy: SurvivorEnemy = ENEMY_SCENE.instantiate()
	enemy.kind = kind
	enemy.fast_chaser = fast
	enemy.legacy_ai = v31_classic
	enemy.dodge_enabled = false
	if not v31_classic and kind != SurvivorEnemy.Kind.BOSS:
		enemy.collision_mask = 1 | 2 | 4
	enemy.position = location
	enemy.world = world
	# New enemies gain 50% of base HP per elapsed minute; existing HP is never refilled.
	enemy.health_multiplier = 1.0 + (floor_number - 1) * 0.15 if kind != SurvivorEnemy.Kind.BOSS else 1.0
	enemy.killed.connect(_on_enemy_killed)
	enemy.damaged.connect(_on_enemy_damaged)
	world.actors.add_child(enemy)
	return enemy

func spawn_random_enemy() -> void:
	var point := world.random_spawn(player.global_position)
	if point != Vector2.ZERO:
		var kind: int = SurvivorEnemy.Kind.HOSTILE if world.random.randf() < 0.65 else SurvivorEnemy.Kind.PASSIVE
		_spawn_enemy(kind, point)

func _on_enemy_killed(_location: Vector2, value: int) -> void:
	kills += 1
	remaining = maxi(0, remaining - 1)
	player.health = minf(player.max_health, player.health + player.heal_on_kill)
	player.stamina = minf(player.max_stamina, player.stamina + player.stamina_on_kill)
	if value <= 0:
		return
	player.gain_experience(value)

func _on_enemy_damaged(location: Vector2, amount: float) -> void:
	feedback.show_damage(location, amount, false)

func _on_player_damaged(amount: float) -> void:
	feedback.show_damage(player.global_position, amount, true)

func _on_experience_received(amount: int) -> void:
	feedback.show_experience(player.global_position, amount)

func _on_level_gained() -> void:
	hud.show_notice("等级提升 · 获得 1 技能点，可在 Tab 属性页修炼秘籍")

func _spawn_floor() -> void:
	var count: int = [8, 12, 16, 1][floor_number - 1]
	pending_wave.clear()
	remaining = count
	if not v31_classic:
		var ranged: int = [0, 2, 4, 0][floor_number - 1]
		wave_delay = 12.0
		for index in range(count):
			var kind: int = SurvivorEnemy.Kind.BOSS if floor_number == 4 else (SurvivorEnemy.Kind.RANGED if index < ranged else SurvivorEnemy.Kind.HOSTILE)
			var fast: bool = floor_number < 4 and kind == SurvivorEnemy.Kind.HOSTILE and (index == ranged or index == count - 1)
			if floor_number < 4 and index >= count / 2:
				pending_wave.append({"kind": kind, "fast": fast})
				continue
			var point := world.random_spawn(player.global_position)
			if point == Vector2.ZERO:
				pending_wave.append({"kind": kind, "fast": fast})
				continue
			_spawn_enemy(kind, point, fast)
		return
	if floor_number == 4:
		var point := world.random_spawn(player.global_position)
		if point == Vector2.ZERO:
			point = world.cell_center(world.floor_cells.back())
		_spawn_enemy(SurvivorEnemy.Kind.BOSS, point)
		return
	var groups := world.encounter_positions(count / 4, player.global_position)
	if groups.size() * 4 != count:
		# Never require kills for enemies that could not be placed.
		remaining = groups.size() * 4
	for group_id in range(groups.size()):
		var positions: Array = groups[group_id]
		for member in range(positions.size()):
			var ranged := floor_number > 1 and member == 3 and (floor_number == 3 or group_id < 2)
			var enemy := _spawn_enemy(SurvivorEnemy.Kind.RANGED if ranged else SurvivorEnemy.Kind.HOSTILE, positions[member], not ranged and member == 1)
			enemy.encounter_id = group_id
			enemy.home_position = positions[member]
			enemy.thrust_type = not ranged and member == 1
			enemy.side_sign = 1.0 if member % 2 == 0 else -1.0

func _spawn_rear_wave() -> void:
	# Behind means opposite the weapon aim, including while retreating.
	var facing: Vector2 = player.aim_direction.normalized()
	if facing.is_zero_approx():
		facing = Vector2.DOWN
	var spawned := 0
	while not pending_wave.is_empty():
		var point := world.rear_spawn(player.global_position, facing)
		if point == Vector2.ZERO:
			wave_delay = 2.0
			hud.show_notice("援军入口受阻 · 请离开墙边")
			return
		var enemy_data: Dictionary = pending_wave.pop_front()
		_spawn_enemy(int(enemy_data.kind), point, bool(enemy_data.fast))
		spawned += 1
	if spawned > 0:
		hud.show_notice("援军出现 · 留意身后")

func _floor_cleared() -> void:
	if state != State.PLAYING or remaining != 0:
		clear_pending = false
		return
	if floor_number == 4:
		_end_run(true)
		return
	gold += FLOOR_GOLD
	state = State.SHOP_PROMPT
	get_tree().paused = true
	hud.show_shop_prompt(floor_number, gold)

func open_shop() -> void:
	if state != State.SHOP_PROMPT:
		return
	state = State.SHOP
	show_shop()

func show_shop(message: String = "") -> void:
	hud.show_shop(gold, purchased, shop_category, message, floor_number <= 2 and manual_claimed_floor != floor_number)

func claim_manual(index: int) -> void:
	if state != State.SHOP or player.profession_index != 0 or floor_number > 2 or manual_claimed_floor == floor_number:
		return
	if index < 0 or index >= player.MANUAL_NAMES.size() or player.manuals.has(index) or player.manuals.size() >= 2:
		return
	player.manuals.append(index)
	manual_claimed_floor = floor_number
	show_shop("已获得：%s" % player.MANUAL_NAMES[index])

func upgrade_manual(slot: int) -> void:
	if state != State.PAUSED or not stats_open:
		return
	if player.upgrade_manual(slot):
		hud.show_stats()

func select_shop_category(index: int) -> void:
	if state != State.SHOP or index < 0 or index > 4:
		return
	shop_category = index
	show_shop()

func buy_item(index: int) -> void:
	if state != State.SHOP or index < 0 or index >= EQUIPMENT.size():
		return
	if purchased[index]:
		show_shop("本局已购买")
		return
	var item: Dictionary = EQUIPMENT[index]
	if gold < int(item.price):
		show_shop("金币不足：需要 %d 金币" % int(item.price))
		return
	gold -= int(item.price)
	purchased[index] = true
	player.equipment_names.append(str(item.name))
	match index:
		0:
			player.damage_multiplier += 0.10
			player.reach_bonus += 25.0
		1:
			player.attack_speed_multiplier += 0.10
			player.stamina_on_kill += 5.0
		2:
			player.damage_multiplier += 0.15
			match player.profession_index:
				0: player.extra_targets += 1
				1: player.reach_bonus += 25.0
				2: player.extra_arrows += 1
		3:
			player.max_health += 20.0
			player.health += 20.0
			player.damage_reduction += 0.05
		4:
			player.max_health += 20.0
			player.health += 20.0
			player.heal_on_kill += 3.0
		5:
			player.max_health += 35.0
			player.health += 35.0
			player.damage_reduction += 0.10
		6:
			player.speed += 8.0
			player.stamina_regen += 8.0
		7:
			player.speed += 8.0
			player.roll_cooldown -= 0.10
		8:
			player.speed += 15.0
			player.roll_distance += 30.0
	show_shop("购买成功：%s" % item.name)

func next_floor() -> void:
	if state != State.SHOP:
		return
	floor_number += 1
	world.rebuild_floor(player)
	_spawn_floor()
	clear_pending = false
	hud.hide_screen()
	state = State.PLAYING
	get_tree().paused = false
	hud.show_notice("第 %d 层" % floor_number)

func show_stats() -> void:
	if state != State.PLAYING:
		return
	state = State.PAUSED
	stats_open = true
	get_tree().paused = true
	hud.show_stats()

func toggle_pause() -> void:
	if state == State.PAUSED:
		resume_run()
	elif state == State.PLAYING:
		state = State.PAUSED
		stats_open = false
		get_tree().paused = true
		hud.show_pause(gold)

func resume_run() -> void:
	if state != State.PAUSED:
		return
	state = State.PLAYING
	stats_open = false
	hud.hide_screen()
	get_tree().paused = false

func _on_death() -> void:
	_end_run(false)

func _end_run(won: bool) -> void:
	state = State.WON if won else State.DEAD
	get_tree().paused = true
	hud.show_result(won, elapsed, kills)

func restart_run() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

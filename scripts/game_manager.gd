class_name SurvivorGame
extends Node2D

const PLAYER_SCENE = preload("res://scenes/player.tscn")
const ENEMY_SCENE = preload("res://scenes/enemy.tscn")
const PICKUP_SCENE = preload("res://scenes/experience_pickup.tscn")
const RUN_DURATION: float = 180.0
enum State { START, PLAYING, LEVEL_UP, PAUSED, DEAD, WON }
var state: int = State.START
var player: SurvivorPlayer
var elapsed: float = 0.0
var kills: int = 0
var pending_levels: int = 0
var spawn_timer: float = 4.0
var stats_open: bool = false
@onready var world: SurvivorWorld = $World
@onready var hud = $HUD
@onready var feedback = $World/CombatFeedback

func _ready() -> void:
	_setup_inputs()
	world.build()
	player = PLAYER_SCENE.instantiate()
	player.position = SurvivorWorld.SPAWN
	world.actors.add_child(player)
	player.camera.limit_left = 0
	player.camera.limit_top = 0
	player.camera.limit_right = int(SurvivorWorld.SIZE.x)
	player.camera.limit_bottom = int(SurvivorWorld.SIZE.y)
	player.camera.reset_smoothing()
	player.died.connect(_on_death)
	player.level_gained.connect(_queue_level)
	player.hurt.connect(hud.flash_damage)
	feedback.camera = player.camera
	feedback.hud_obstacles.assign(hud.combat_panels)
	player.damage_received.connect(_on_player_damaged)
	player.experience_received.connect(_on_experience_received)
	hud.player = player
	hud.start_requested.connect(start_run)
	hud.restart_requested.connect(restart_run)
	hud.stats_requested.connect(show_stats)
	hud.pause_requested.connect(toggle_pause)
	hud.resume_requested.connect(resume_run)
	hud.level_ui.chosen.connect(choose_upgrade)
	_spawn_enemy(SurvivorEnemy.Kind.PASSIVE, SurvivorWorld.SPAWN + Vector2(160, -70))
	_spawn_enemy(SurvivorEnemy.Kind.HOSTILE, SurvivorWorld.SPAWN + Vector2(280, 100))
	for index in range(16):
		spawn_random_enemy()
	hud.update_game(elapsed, kills, RUN_DURATION)
	hud.show_start()
	get_tree().paused = true

func _setup_inputs() -> void:
	var keys := {"move_up": KEY_W, "move_down": KEY_S, "move_left": KEY_A, "move_right": KEY_D, "weapon_1": KEY_1, "weapon_2": KEY_2, "weapon_3": KEY_3, "upgrade_1": KEY_1, "upgrade_2": KEY_2, "upgrade_3": KEY_3, "stats": KEY_TAB, "pause": KEY_ESCAPE, "restart": KEY_R, "roll": KEY_SPACE}
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

func start_run() -> void:
	if state != State.START:
		return
	state = State.PLAYING
	hud.hide_screen()
	get_tree().paused = false
	hud.show_notice("试炼开始 · 拾取蓝色晶体来升级")

func _process(delta: float) -> void:
	if state == State.PLAYING and not get_tree().paused:
		elapsed += delta
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			spawn_timer = maxf(2.4, 4.5 - elapsed / 90.0)
			if get_tree().get_nodes_in_group("enemies").size() < 28:
				spawn_random_enemy()
		if elapsed >= RUN_DURATION:
			elapsed = RUN_DURATION
			_end_run(true)
	hud.update_game(elapsed, kills, RUN_DURATION)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
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

func _spawn_enemy(kind: int, location: Vector2) -> SurvivorEnemy:
	var enemy: SurvivorEnemy = ENEMY_SCENE.instantiate()
	enemy.kind = kind
	enemy.position = location
	enemy.world = world
	# New enemies gain 50% of base HP per elapsed minute; existing HP is never refilled.
	enemy.health_multiplier = 1.0 + elapsed / 120.0
	enemy.killed.connect(_on_enemy_killed)
	enemy.damaged.connect(_on_enemy_damaged)
	world.actors.add_child(enemy)
	return enemy

func spawn_random_enemy() -> void:
	var point := world.random_spawn(player.global_position)
	if point != Vector2.ZERO:
		var kind: int = SurvivorEnemy.Kind.HOSTILE if world.random.randf() < 0.65 else SurvivorEnemy.Kind.PASSIVE
		_spawn_enemy(kind, point)

func _on_enemy_killed(location: Vector2, value: int) -> void:
	kills += 1
	var pickup = PICKUP_SCENE.instantiate()
	pickup.position = location
	pickup.value = value
	world.actors.add_child.call_deferred(pickup)

func _on_enemy_damaged(location: Vector2, amount: float) -> void:
	feedback.show_damage(location, amount, false)

func _on_player_damaged(amount: float) -> void:
	feedback.show_damage(player.global_position, amount, true)

func _on_experience_received(amount: int) -> void:
	var displayed_total: int = feedback.show_experience(player.global_position, amount)
	hud.show_notice("+%d 经验" % displayed_total)

func _queue_level() -> void:
	pending_levels += 1
	_open_level_up.call_deferred()

func _open_level_up() -> void:
	if pending_levels <= 0 or state != State.PLAYING:
		return
	state = State.LEVEL_UP
	get_tree().paused = true
	hud.level_ui.show_choices(player)

func choose_upgrade(index: int) -> void:
	if state != State.LEVEL_UP or index < 0 or index > 2:
		return
	player.apply_upgrade(index)
	pending_levels -= 1
	hud.level_ui.hide()
	if pending_levels > 0:
		hud.level_ui.show_choices(player)
	else:
		state = State.PLAYING
		get_tree().paused = false
		hud.show_notice("强化已生效")

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
		hud.show_pause()

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
	hud.level_ui.hide()
	hud.show_result(won, elapsed, kills)

func restart_run() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

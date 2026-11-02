extends Node2D

const PLAYER = preload("res://scenes/player.tscn")
const ENEMY = preload("res://scenes/enemy.tscn")
const WARNING_TIME := 0.6
const RISE_TIME := 0.6
const PLAYER_CELL := Vector2i(15, 15)
const SPAWN_CELLS: Array[Vector2i] = [Vector2i(14, 12), Vector2i(20, 11), Vector2i(25, 12), Vector2i(13, 17), Vector2i(18, 16), Vector2i(24, 17), Vector2i(26, 14)]
var player: SurvivorPlayer
var spawned: Array[SurvivorEnemy] = []
var rng := RandomNumberGenerator.new()
var phase := "warning"
var phase_time := 0.0
var remaining := 0
var total := 0
var status: Label
var vitals: Label
var restart_button: Button
@onready var world = $World
@onready var feedback = $World/CombatFeedback

func _ready() -> void:
	_setup_inputs()
	rng.randomize()
	world.build_sample()
	_build_ui()
	start_room()

func _setup_inputs() -> void:
	var keys := {"move_up": KEY_W, "move_down": KEY_S, "move_left": KEY_A, "move_right": KEY_D, "roll": KEY_SPACE}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var event := InputEventKey.new()
			event.physical_keycode = keys[action]
			InputMap.action_add_event(action, event)
	for pair in [["attack", MOUSE_BUTTON_LEFT], ["ranged_attack", MOUSE_BUTTON_RIGHT]]:
		if not InputMap.has_action(pair[0]):
			InputMap.add_action(pair[0])
			var event := InputEventMouseButton.new()
			event.button_index = pair[1]
			InputMap.action_add_event(pair[0], event)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(12, 10)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var help := Label.new()
	help.text = "WASD 移动  ·  鼠标瞄准  ·  左键刺击  ·  右键射箭  ·  Space 翻滚"
	box.add_child(help)
	status = Label.new()
	box.add_child(status)
	vitals = Label.new()
	box.add_child(vitals)
	restart_button = Button.new()
	restart_button.text = "重新开始"
	restart_button.focus_mode = Control.FOCUS_NONE
	restart_button.pressed.connect(start_room)
	box.add_child(restart_button)

func start_room() -> void:
	for child in world.actors.get_children():
		child.free()
	spawned.clear()
	world.spawn_points.clear()
	player = PLAYER.instantiate()
	player.position = world.cell_center(PLAYER_CELL)
	player.collision_mask = 1 | 4
	world.actors.add_child(player)
	player.enable_dual_attack()
	player.camera.enabled = false
	$Camera2D.make_current()
	feedback.camera = $Camera2D
	player.died.connect(_on_player_died)
	player.damage_received.connect(func(amount: float): feedback.show_damage(player.global_position, amount, true))
	total = rng.randi_range(5, 6)
	remaining = total
	var choices := SPAWN_CELLS.duplicate()
	for i in range(total):
		var index := rng.randi_range(0, choices.size() - 1)
		var position: Vector2 = world.cell_center(choices[index])
		choices.remove_at(index)
		world.spawn_points.append(position)
		var enemy := ENEMY.instantiate() as SurvivorEnemy
		enemy.world = world
		enemy.kind = SurvivorEnemy.Kind.HOSTILE
		enemy.dodge_enabled = false
		enemy.collision_mask = 1 | 2 | 4
		enemy.collision_layer = 0
		enemy.emerging = true
		enemy.position = position
		enemy.killed.connect(_on_enemy_killed)
		enemy.damaged.connect(func(point: Vector2, amount: float): feedback.show_damage(point, amount, false))
		world.actors.add_child(enemy)
		enemy.remove_from_group("enemies")
		enemy.set_physics_process(false)
		enemy.visual.set_physics_process(false)
		enemy.hide()
		spawned.append(enemy)
	phase = "warning"
	phase_time = 0.0
	world.spawn_progress = 0.0
	world.queue_redraw()
	restart_button.hide()
	_update_status()

func _physics_process(delta: float) -> void:
	if phase == "warning":
		phase_time += delta
		world.spawn_progress = minf(phase_time / WARNING_TIME, 1.0)
		world.queue_redraw()
		if phase_time >= WARNING_TIME:
			phase = "rising"
			phase_time = 0.0
			for enemy in spawned:
				enemy.show()
				enemy.visual.scale = Vector2(1.0, 0.01)
				enemy.visual.position.y = 10.0
	elif phase == "rising":
		phase_time += delta
		var progress := clampf(phase_time / RISE_TIME, 0.0, 1.0)
		for enemy in spawned:
			enemy.visual.scale.y = maxf(0.01, progress)
			enemy.visual.position.y = 10.0 * (1.0 - progress)
		if progress >= 1.0:
			phase = "combat"
			for enemy in spawned:
				enemy.emerging = false
				enemy.visual.set_physics_process(true)
				enemy.collision_layer = 4
				enemy.add_to_group("enemies")
				enemy.set_physics_process(true)
			_update_status()

func _on_enemy_killed(_point: Vector2, _xp: int) -> void:
	remaining -= 1
	if phase == "dead":
		return
	if remaining == 0:
		phase = "cleared"
		restart_button.show()
	_update_status()

func _on_player_died() -> void:
	phase = "dead"
	status.text = "角色倒下"
	restart_button.show()

func _update_status() -> void:
	status.text = "房间清理完成" if phase == "cleared" else "敌人 %d / %d" % [remaining, total]

func _process(_delta: float) -> void:
	if is_instance_valid(player):
		vitals.text = "生命 %.0f / %.0f    体力 %.0f / %.0f" % [player.health, player.max_health, player.stamina, player.max_stamina]

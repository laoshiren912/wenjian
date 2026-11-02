extends Node2D

const PLAYER = preload("res://scenes/player.tscn")
const ENEMY = preload("res://scenes/enemy.tscn")
const SPAWNS: Array[Vector2i] = [Vector2i(24, 14), Vector2i(25, 14), Vector2i(26, 14), Vector2i(24, 15), Vector2i(25, 15), Vector2i(26, 15)]
var player: SurvivorPlayer
var remaining := 0
var selected_count := 1
var status: Label
var vitals: Label
@onready var world = $World
@onready var feedback = $World/CombatFeedback

func _ready() -> void:
	_setup_inputs()
	world.build_sample()
	_build_ui()
	start_sample(1)

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
	help.text = "战斗样板  ·  WASD 移动  左键刺击  右键射箭  Space 翻滚"
	box.add_child(help)
	var row := HBoxContainer.new()
	box.add_child(row)
	for count in [1, 4, 6]:
		var button := Button.new()
		button.text = "%d 只 / 重开" % count
		button.focus_mode = Control.FOCUS_NONE
		button.add_to_group("sample_buttons")
		button.pressed.connect(start_sample.bind(count))
		row.add_child(button)
	status = Label.new()
	row.add_child(status)
	vitals = Label.new()
	box.add_child(vitals)

func start_sample(count: int) -> void:
	selected_count = count
	for child in world.actors.get_children():
		child.free()
	remaining = count
	player = PLAYER.instantiate()
	player.position = world.cell_center(Vector2i(15, 15))
	player.collision_mask = 1 | 4
	world.actors.add_child(player)
	player.enable_dual_attack()
	player.camera.position_smoothing_enabled = false
	player.camera.enabled = false
	var camera := $Camera2D as Camera2D
	camera.make_current()
	feedback.camera = camera
	player.died.connect(_on_player_died)
	player.damage_received.connect(func(amount: float): feedback.show_damage(player.global_position, amount, true))
	for i in range(count):
		var enemy := ENEMY.instantiate() as SurvivorEnemy
		enemy.kind = SurvivorEnemy.Kind.HOSTILE
		enemy.world = world
		enemy.dodge_enabled = false
		enemy.collision_mask = 1 | 2 | 4
		enemy.position = world.cell_center(SPAWNS[i])
		enemy.killed.connect(_on_enemy_killed)
		enemy.damaged.connect(func(point: Vector2, amount: float): feedback.show_damage(point, amount, false))
		world.actors.add_child(enemy)
	_update_status()

func _on_enemy_killed(_point: Vector2, _xp: int) -> void:
	remaining -= 1
	_update_status()

func _on_player_died() -> void:
	status.text = "  角色倒下 · 点击上方按钮重开"

func _update_status() -> void:
	status.text = "  已清场！选择数量再试" if remaining == 0 else "  剩余敌人 %d / %d" % [remaining, selected_count]

func _process(_delta: float) -> void:
	if is_instance_valid(player):
		vitals.text = "生命 %.0f / %.0f    体力 %.0f / %.0f" % [player.health, player.max_health, player.stamina, player.max_stamina]

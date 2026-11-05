extends Node2D

const HERO := preload("res://scenes/player_sword_motion.tscn")
const START := Vector2(640, 425)
var player: SurvivorPlayer
var close_view := false
var paused_panel: Control
var hint: Label
@onready var world = $World
@onready var camera: Camera2D = $Camera2D

func _ready() -> void:
	Engine.time_scale = 1.0
	_setup_inputs()
	world.build_courtyard()
	player = HERO.instantiate()
	player.position = START
	world.actors.add_child(player)
	player.enable_dual_attack()
	player.camera.enabled = false
	player.collision_mask = 1
	world.visitor = player
	camera.make_current()
	_build_ui()
	get_viewport().size_changed.connect(_update_camera)
	_update_camera()

func _setup_inputs() -> void:
	for action in {"move_up": KEY_W, "move_down": KEY_S, "move_left": KEY_A, "move_right": KEY_D, "roll": KEY_SPACE}:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var key := InputEventKey.new()
			key.physical_keycode = {"move_up": KEY_W, "move_down": KEY_S, "move_left": KEY_A, "move_right": KEY_D, "roll": KEY_SPACE}[action]
			InputMap.action_add_event(action, key)
	for action in {"attack": MOUSE_BUTTON_LEFT, "ranged_attack": MOUSE_BUTTON_RIGHT}:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var button := InputEventMouseButton.new()
			button.button_index = {"attack": MOUSE_BUTTON_LEFT, "ranged_attack": MOUSE_BUTTON_RIGHT}[action]
			InputMap.action_add_event(action, button)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	PrototypeUI.fill(root)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var heading := VBoxContainer.new()
	heading.position = Vector2(20, 14)
	root.add_child(heading)
	var title := PrototypeUI.label("庭院 · 夜色", 25, Color("f3dfb2"))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("shadow_offset_y", 2)
	heading.add_child(title)
	heading.add_child(PrototypeUI.label("绕过石灯，看看人物的前后遮挡", 15, Color("d4dadd")))
	var top := HBoxContainer.new()
	root.add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	top.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	top.offset_left = -420
	top.offset_right = -20
	top.offset_top = 16
	top.offset_bottom = 60
	top.alignment = BoxContainer.ALIGNMENT_END
	var reset := PrototypeUI.button("重置位置", reset_position, 34)
	var zoom := PrototypeUI.button("远近切换", func(): close_view = not close_view; _update_camera(), 34)
	var old := PrototypeUI.button("挥剑样板", func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/sword_motion_trial.tscn"), 34)
	for button in [reset, zoom, old]:
		button.focus_mode = Control.FOCUS_NONE
		top.add_child(button)
	var footer := CenterContainer.new()
	root.add_child(footer)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_top = -60
	footer.offset_bottom = -12
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PrototypeUI.panel()
	footer.add_child(panel)
	hint = PrototypeUI.label("WASD 行走 · Space 翻滚 · 左键剑 / 长按蓄力 · 右键弓 · Esc 暂停", 16)
	panel.add_child(hint)
	paused_panel = ColorRect.new()
	paused_panel.color = Color(0.02, 0.04, 0.07, 0.7)
	PrototypeUI.fill(paused_panel)
	root.add_child(paused_panel)
	var center := CenterContainer.new()
	PrototypeUI.fill(center)
	paused_panel.add_child(center)
	var box := VBoxContainer.new()
	center.add_child(box)
	box.add_child(PrototypeUI.label("已暂停", 32))
	box.add_child(PrototypeUI.button("继续  [Esc]", toggle_pause))
	box.add_child(PrototypeUI.button("返回V4.1（新局）", func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/main_v41.tscn")))
	paused_panel.hide()

func reset_position() -> void:
	player.position = START
	player.velocity = Vector2.ZERO
	player.knockback = Vector2.ZERO
	player.combo.reset_chain()
	player._attack_held = false
	player._attack_pending = false
	player._ranged_held = false
	player._ranged_pending = false
	player._roll_requested = false
	player.weapon.swing_time = 0.0
	player.ranged_weapon.swing_time = 0.0
	player.visual.cancel_attack()
	player._roll_remaining = 0.0
	player._roll_cooldown = 0.0
	player.stamina = player.max_stamina
	player._finish_roll()
	for child in world.actors.get_children():
		if child != player:
			child.queue_free()
	_update_camera()

func toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
	paused_panel.visible = get_tree().paused

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		toggle_pause()
		get_viewport().set_input_as_handled()

func _physics_process(_delta: float) -> void:
	if close_view and is_instance_valid(player) and not get_tree().paused:
		_update_camera()

func _update_camera() -> void:
	var viewport := get_viewport_rect().size
	var fit := maxf(viewport.x / world.ART_SIZE.x, viewport.y / world.ART_SIZE.y)
	camera.zoom = Vector2.ONE * fit * (1.3 if close_view else 1.0)
	var half := viewport / camera.zoom * 0.5
	var focus: Vector2 = player.position if close_view and is_instance_valid(player) else world.ART_SIZE * 0.5
	camera.position = Vector2(clampf(focus.x, half.x, world.ART_SIZE.x - half.x), clampf(focus.y, half.y, world.ART_SIZE.y - half.y))

func _exit_tree() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false

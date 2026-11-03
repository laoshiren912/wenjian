extends "res://scripts/corridor_trial.gd"

var menu_open := false
var stats_open := false
@onready var hud = $HUD

func _setup_inputs() -> void:
	super._setup_inputs()
	for action in {"stats": KEY_TAB, "pause": KEY_ESCAPE}:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var key := InputEventKey.new()
			key.physical_keycode = KEY_TAB if action == "stats" else KEY_ESCAPE
			InputMap.action_add_event(action, key)

func _build_ui() -> void:
	status = hud.status_text
	hud.pause_requested.connect(toggle_pause)
	hud.stats_requested.connect(toggle_stats)
	hud.resume_requested.connect(resume_room)
	hud.restart_requested.connect(start_room)
	feedback.hud_obstacles.assign(hud.combat_panels)

func start_room() -> void:
	get_tree().paused = false
	menu_open = false
	stats_open = false
	# Actors include projectiles. Feedback lives outside Actors and needs its own reset.
	for child in feedback.get_children():
		child.free()
	feedback.popups.clear()
	feedback.bursts.clear()
	feedback.shake_time = 0.0
	feedback.shake_strength = 0.0
	$Camera2D.offset = Vector2.ZERO
	super.start_room()
	hud.player = player
	player.hurt.connect(hud.flash_damage)
	hud.hurt_flash.color.a = 0.0
	hud.notice_time = 0.0
	hud.notice.text = ""
	hud.update_room(remaining, total, triggered_count)

func _set_restart_visible(visible: bool) -> void:
	if visible:
		_show_result(true)
	else:
		hud.hide_screen()

func _physics_process(delta: float) -> void:
	if not get_tree().paused:
		super._physics_process(delta)

func _process(_delta: float) -> void:
	if is_instance_valid(player):
		hud.update_room(remaining, total, triggered_count)

func _update_status() -> void:
	status.text = "敌人已清除 · 走到右侧传送点" if world.portal_open else "沿路触发敌人 · 前往右侧"

func toggle_pause() -> void:
	if menu_open:
		resume_room()
	elif phase == "combat":
		menu_open = true
		stats_open = false
		get_tree().paused = true
		hud.show_pause()

func toggle_stats() -> void:
	if menu_open:
		resume_room()
	elif phase == "combat":
		menu_open = true
		stats_open = true
		get_tree().paused = true
		hud.show_stats()

func resume_room() -> void:
	if not menu_open:
		return
	menu_open = false
	stats_open = false
	hud.hide_screen()
	get_tree().paused = false

func _on_player_died() -> void:
	phase = "dead"
	status.text = "角色倒下"
	_show_result(false)

func _show_result(completed: bool) -> void:
	menu_open = false
	stats_open = false
	hud.update_room(remaining, total, triggered_count)
	get_tree().paused = true
	hud.show_room_result(completed, total - remaining, total)

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or event.echo:
		return
	# OS-injected special keys can carry an unrelated scan code. Menu shortcuts
	# use the logical key; player movement retains its existing physical bindings.
	var code: int = event.keycode if event.keycode != 0 else event.physical_keycode
	if get_tree().paused and code == KEY_SPACE:
		get_viewport().set_input_as_handled()
		return
	if not event.pressed:
		return
	if phase in ["dead", "cleared"]:
		if code in [KEY_ENTER, KEY_KP_ENTER, KEY_R]:
			start_room()
			get_viewport().set_input_as_handled()
		return
	if code == KEY_ESCAPE or event.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()
	elif code == KEY_TAB or event.is_action_pressed("stats"):
		toggle_stats()
		get_viewport().set_input_as_handled()

extends SceneTree
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scenes/main_v31.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	game.start_run()
	game.toggle_pause()
	game.gm_select_floor(4)
	check(game.floor_number == 1, "GM required")
	game.set_gm_mode(true)
	var boss_button: Button
	for button in game.hud.find_children("*", "Button", true, false):
		if button.text == "第 4 层 Boss":
			boss_button = button
	check(is_instance_valid(boss_button), "boss floor button visible")
	if is_instance_valid(boss_button):
		boss_button.pressed.emit()
	check(game.floor_number == 4 and game.remaining == 1 and game.state == game.State.PLAYING, "select boss floor")
	var boss = get_nodes_in_group("enemies")[0]
	boss.set_physics_process(false)
	boss.boss_state = boss.BossState.CHARGE_WINDUP
	boss.boss_next_attack = 2
	boss.take_damage(130, Vector2.ZERO)
	check(boss.boss_state == boss.BossState.CHARGE_WINDUP, "one hit does not interrupt")
	boss.take_damage(130, Vector2.ZERO)
	check(boss.boss_state == boss.BossState.STAGGER and boss.boss_next_attack == 2, "pressure opens window and preserves next move")
	boss._boss_process(1.3)
	check(boss.boss_state == boss.BossState.APPROACH, "stagger ends")
	boss.health = boss.max_health * 0.4
	boss._boss_recover(0)
	check(is_equal_approx(boss.boss_timer, 0.7), "second half recovery")
	game.toggle_pause()
	game.gm_kill_floor()
	await process_frame
	await process_frame
	check(game.remaining == 0 and game.state == game.State.WON, "kill boss leads to victory")
	paused = false
	game.queue_free()
	await process_frame
	var other = load("res://scenes/main_v31.tscn").instantiate()
	root.add_child(other)
	current_scene = other
	await process_frame
	other.set_gm_mode(true)
	other.start_run()
	other.toggle_pause()
	other.gm_kill_floor()
	await process_frame
	await process_frame
	check(other.pending_wave.is_empty() and other.remaining == 0 and other.state == other.State.SHOP_PROMPT, "kill clears pending wave and opens shop")
	print("GM BOSS TEST failures: ", failures)
	quit(1 if failures else 0)

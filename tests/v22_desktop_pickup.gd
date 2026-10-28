extends SceneTree

# Real desktop input; controlled XP samples and stationary world, normal player stats.
class Observer extends Node:
	var right_key: bool = false
	var left_presses: int = 0
	func _input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and not event.echo:
			print("DESKTOP XP KEY: " + event.as_text())
			if event.is_action_pressed("move_right"):
				right_key = true
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			left_presses += 1
			print("DESKTOP XP LEFT: " + str(event.position))

const STOP_FILE := "res://artifacts/runtime/v22_desktop_stop"
var game: SurvivorGame
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS: " if ok else "FAIL: ") + description)

func _run() -> void:
	if FileAccess.file_exists(STOP_FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(STOP_FILE))
	root.title = "V2.2 Desktop XP Verification"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	game.start_run()
	game.spawn_timer = 9999
	for enemy in get_nodes_in_group("enemies"):
		enemy.free()
	var observer := Observer.new()
	observer.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(observer)
	var orbs: Array[Node2D] = []
	for value in [18, 28, 38]:
		var orb = SurvivorGame.PICKUP_SCENE.instantiate()
		orb.position = game.player.position + Vector2(30, 0)
		orb.value = value
		game.world.actors.add_child(orb)
		orbs.append(orb)
	for frame in range(10):
		await physics_frame
	check(game.player.total_experience == 0 and orbs[0].position.distance_to(game.player.position) > 28, "Desktop XP starts outside the one-body attraction range and remains uncollected")
	game.hud.show_notice("桌面验收：按 D 靠近右侧经验，依次选择力量、迅捷、活力")
	print("DESKTOP XP READY: press D, then choose 1/2/3 across the three earned levels, then click HUD pause and continue")
	var deadline: int = Time.get_ticks_msec() + 180000
	var last_pending: int = -1
	var upgraded: bool = false
	var paused_once: bool = false
	var pause_elapsed: float = 0
	var pause_frames: int = 0
	var finished: bool = false
	while Time.get_ticks_msec() < deadline and not FileAccess.file_exists(STOP_FILE):
		await process_frame
		if game.state == SurvivorGame.State.LEVEL_UP and game.pending_levels != last_pending:
			last_pending = game.pending_levels
			if last_pending == 3:
				check(observer.right_key and game.player.position.x > SurvivorWorld.SPAWN.x, "Physical D movement brings XP into attraction range")
				check(game.player.total_experience == 84 and game.player.level == 4 and paused, "Actual collected orbs grant 84 XP and queue three paused upgrades")
			elif last_pending == 2:
				check(is_equal_approx(game.player.damage_multiplier, 1.2) and paused, "Physical first choice applies damage once")
			elif last_pending == 1:
				check(is_equal_approx(game.player.attack_speed_multiplier, 1.15) and paused, "Physical second choice applies attack speed once")
		if last_pending == 1 and game.state == SurvivorGame.State.PLAYING and not upgraded:
			upgraded = true
			check(game.player.max_health == 125 and game.pending_levels == 0 and not paused and game.player.stamina == 100, "Physical third choice applies health and restores combat without stamina cost")
			game.hud.show_notice("三次强化通过 · 请点击右上暂停，再点击继续")
		if upgraded and game.state == SurvivorGame.State.PAUSED:
			if not paused_once:
				paused_once = true
				pause_elapsed = game.elapsed
				check(game.player.weapon.attack_count == 0, "Physical HUD pause does not attack")
			pause_frames += 1
		if upgraded and paused_once and game.state == SurvivorGame.State.PLAYING and not finished:
			finished = true
			check(pause_frames > 2 and game.elapsed - pause_elapsed < 0.10 and game.player.weapon.attack_count == 0 and game.player.stamina == 100, "Physical continue resumes after a real pause without a stale attack")
			root.title = "V2.2 Desktop XP PASS"
			game.hud.show_notice("桌面拾取、三次强化、暂停与继续通过")
	print("DESKTOP XP RESULT: %d checks, %d failures; finished=%s; physical_left=%d; XP=%d level=%d" % [checks, failures, finished, observer.left_presses, game.player.total_experience, game.player.level])
	paused = false
	quit(0 if finished and failures == 0 else 1)

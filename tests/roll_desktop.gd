extends SceneTree

# Controlled desktop fixture: real Space/WASD/UI input, normal movement and stamina.
class Observer extends Node:
	var game: SurvivorGame
	var position_before: Vector2
	var stamina_before: float = 100
	var left_key: bool = false
	func _input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and not event.echo:
			print("ROLL DESKTOP KEY: " + event.as_text())
			if event.is_action_pressed("move_left"):
				left_key = true
			if event.is_action_pressed("roll") and game.state == SurvivorGame.State.PLAYING:
				position_before = game.player.position
				stamina_before = game.player.stamina

const STOP_FILE := "res://artifacts/runtime/roll_desktop_stop"
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
	root.title = "Space Roll Desktop Verification"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	game.start_run()
	game.spawn_timer = 9999
	for enemy in get_nodes_in_group("enemies"):
		enemy.free()
	game.player.visual.facing = Vector2.RIGHT
	var observer := Observer.new()
	observer.game = game
	observer.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(observer)
	game.hud.show_notice("桌面翻滚验收：静止时按 Space，向右翻滚")
	print("ROLL DESKTOP READY: Space free roll, Space into fixture wall, A then Space back left, HUD pause then Space Continue")
	var deadline: int = Time.get_ticks_msec() + 180000
	var was_rolling: bool = false
	var starts: int = 0
	var ends: int = 0
	var origin: Vector2
	var wall: StaticBody2D
	var paused_once: bool = false
	var finished: bool = false
	while Time.get_ticks_msec() < deadline and not FileAccess.file_exists(STOP_FILE):
		await process_frame
		var rolling: bool = game.player.is_rolling()
		if rolling and not was_rolling:
			starts += 1
			origin = observer.position_before
			check(game.player.stamina >= observer.stamina_before - 30.01 and game.player.stamina <= observer.stamina_before - 29.0, "Physical Space roll %d spends 30 stamina once" % starts)
			check(game.player.invulnerability == 0 and game.player.weapon.attack_count == 0 and not game.player.weapon.visible, "Physical roll adds no immunity or attack and hides recovery drawing")
			print("ROLL DESKTOP START: number=%d origin=%s direction=%s stamina=%.3f" % [starts, origin, game.player._roll_direction, game.player.stamina])
		if was_rolling and not rolling:
			ends += 1
			var displacement: Vector2 = game.player.position - origin
			if ends == 1:
				check(absf(displacement.x - 150) < 0.6 and absf(displacement.y) < 0.1, "Stationary physical Space follows right-facing body for 150 units")
				wall = StaticBody2D.new()
				wall.position = game.player.position + Vector2(80, 0)
				wall.collision_layer = 1
				wall.collision_mask = 0
				var collider := CollisionShape2D.new()
				var shape := RectangleShape2D.new()
				shape.size = Vector2(16, 120)
				collider.shape = shape
				wall.add_child(collider)
				var block := Polygon2D.new()
				block.polygon = PackedVector2Array([Vector2(-8, -60), Vector2(8, -60), Vector2(8, 60), Vector2(-8, 60)])
				block.color = Color("68818a")
				wall.add_child(block)
				game.world.add_child(wall)
				game.hud.show_notice("第一次通过 · 再按 Space，检查前方细墙碰撞")
			elif ends == 2:
				check(game.player.position.x <= wall.position.x - 21.9 and displacement.x > 0 and displacement.x < 60, "Second physical roll is stopped by a thin physics wall")
				game.hud.show_notice("碰撞通过 · 按 A 转身，再按 Space 向左翻滚")
			elif ends == 3:
				check(observer.left_key and absf(displacement.x + 150) < 0.6, "Physical A turns the body; stationary Space then rolls left")
				check(game.player.visual.rotation == 0 and game.player.weapon.visible, "Physical roll ends with restored body and weapon")
				game.hud.show_notice("三次翻滚通过 · 点击右上暂停，再按 Space 继续")
			print("ROLL DESKTOP END: number=%d displacement=%s stamina=%.3f" % [ends, displacement, game.player.stamina])
		was_rolling = rolling
		if ends == 3 and game.state == SurvivorGame.State.PAUSED:
			paused_once = true
		if paused_once and game.state == SurvivorGame.State.PLAYING and not finished:
			finished = true
			check(starts == 3 and not rolling and game.player.weapon.attack_count == 0, "Space Continue is handled by UI without rolling or attacking")
			root.title = "Space Roll Desktop PASS"
			game.hud.show_notice("桌面翻滚、活力、碰撞和 UI 隔离通过")
	print("ROLL DESKTOP RESULT: %d checks, %d failures; starts=%d ends=%d finished=%s" % [checks, failures, starts, ends, finished])
	paused = false
	quit(0 if finished and failures == 0 else 1)

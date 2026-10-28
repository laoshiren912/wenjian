extends SceneTree

# Interactive native-input fixture: normal stats and combat code, stationary test targets.
# Select a profession with physical 1/2/3, Enter, then click its target.
# Each verified hit returns to selection for the next independent profession run.
class InputObserver extends Node:
	signal observed(event: InputEvent)
	func _input(event: InputEvent) -> void:
		observed.emit(event)

var game: SurvivorGame
var target: SurvivorEnemy
var seen_keys: Dictionary = {}
var verified: Dictionary = {}
var clicks: int = 0
var failures: int = 0
const STOP_FILE := "res://artifacts/runtime/desktop_combat_stop"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if FileAccess.file_exists(STOP_FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(STOP_FILE))
	root.title = "V2.4 Desktop Combat Verification"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	game.spawn_timer = 9999.0
	var observer := InputObserver.new()
	observer.process_mode = Node.PROCESS_MODE_ALWAYS
	observer.observed.connect(_on_input)
	root.add_child(observer)
	print("DESKTOP READY: physical profession 1/2/3, Enter, then click target to the right. Each hit restarts at profession selection.")
	var deadline: int = Time.get_ticks_msec() + 180000
	var active: int = -1
	while Time.get_ticks_msec() < deadline and not FileAccess.file_exists(STOP_FILE) and verified.size() < 3:
		await process_frame
		if game.state == SurvivorGame.State.PLAYING:
			var index: int = game.player.weapon.selected
			if verified.has(index):
				game.restart_run()
				await process_frame
				while not is_instance_valid(current_scene) or not current_scene.is_node_ready():
					await process_frame
				game = current_scene
				# Input dispatch runs in reverse tree order. A reloaded scene is
				# appended after the observer and consumes profession/Enter keys.
				root.move_child(observer, root.get_child_count() - 1)
				active = -1
			elif active != index:
				_prepare_target(index)
				active = index
	print("DESKTOP RESULT: %d/3 weapons verified, %d failures, %d physical left presses" % [verified.size(), failures, clicks])
	paused = false
	quit(0 if verified.size() == 3 and failures == 0 else 1)

func _prepare_target(index: int) -> void:
	for enemy in get_nodes_in_group("enemies"):
		enemy.free()
	for arrow in get_nodes_in_group("projectiles"):
		arrow.free()
	var distance: float = [70.0, 135.0, 200.0][index]
	target = game._spawn_enemy(SurvivorEnemy.Kind.HOSTILE, game.player.position + Vector2(distance, 0))
	target.set_physics_process(false)
	target.damaged.connect(_on_damage)
	game.spawn_timer = 9999.0
	game.hud.show_notice("桌面输入测试：瞄准右侧目标并左键攻击，命中后重新选职业")
	print("DESKTOP TARGET: weapon=%d distance=%.0f HP=%.1f" % [index + 1, distance, target.health])

func _on_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		print("DESKTOP KEY RAW: logical=%d physical=%d text=%s" % [event.keycode, event.physical_keycode, event.as_text()])
		for index in range(3):
			if is_instance_valid(game) and game.state == SurvivorGame.State.START and event.is_action_pressed("profession_%d" % (index + 1)):
				seen_keys[index] = true
				print("DESKTOP PHYSICAL KEY: ", index + 1)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		clicks += 1
		print("DESKTOP LEFT: viewport=%s world=%s aim=%s stamina=%.1f" % [event.position, game.player.get_global_mouse_position(), game.player.aim_direction, game.player.stamina])

func _on_damage(_point: Vector2, amount: float) -> void:
	var index: int = game.player.weapon.selected
	var expected: float = [52.0, 32.0, 21.0][index]
	var ok: bool = seen_keys.has(index) and clicks > 0 and is_equal_approx(amount, expected) and is_equal_approx(game.player.stamina, 100.0)
	if ok:
		verified[index] = true
	else:
		failures += 1
	print("DESKTOP HIT: weapon=%d damage=%.1f expected=%.1f stamina=%.1f aim=%s result=%s" % [index + 1, amount, expected, game.player.stamina, game.player.aim_direction, "PASS" if ok else "FAIL"])
	if verified.size() == 3:
		root.title = "V2.4 Desktop Combat PASS"
		game.hud.show_notice("三武器真实桌面命中通过 · 体力 100")

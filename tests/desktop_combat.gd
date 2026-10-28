extends SceneTree

# Interactive native-input fixture: normal stats and combat code, stationary test targets.
# Send physical keys 1/2/3 and left clicks through the desktop; no synthetic input here.
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
	root.title = "V1 Desktop Combat Verification"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	game.start_run()
	game.spawn_timer = 9999.0
	var observer := InputObserver.new()
	observer.observed.connect(_on_input)
	root.add_child(observer)
	_prepare_target(0)
	print("DESKTOP READY: physical 1/2/3 then aim at and click the target to the right. Normal stats; enemy AI frozen only for input isolation.")
	var deadline: int = Time.get_ticks_msec() + 180000
	while Time.get_ticks_msec() < deadline and not FileAccess.file_exists(STOP_FILE):
		await process_frame
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
	game.hud.show_notice("桌面输入测试：按 1/2/3，瞄准右侧目标并左键攻击")
	print("DESKTOP TARGET: weapon=%d distance=%.0f HP=%.1f" % [index + 1, distance, target.health])

func _on_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		print("DESKTOP KEY RAW: logical=%d physical=%d text=%s" % [event.keycode, event.physical_keycode, event.as_text()])
		for index in range(3):
			if event.is_action_pressed("weapon_%d" % (index + 1)):
				seen_keys[index] = true
				_prepare_target(index)
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
		root.title = "V1 Desktop Combat PASS"
		game.hud.show_notice("三武器真实桌面命中通过 · 体力 100")

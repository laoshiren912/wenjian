extends SceneTree

# Real OS keyboard/pointer input in a controlled 960x540 fixture, no random enemies.
class Observer extends Node:
	var last_key: Key = KEY_NONE
	func _input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and not event.echo:
			last_key = event.keycode if event.keycode != KEY_NONE else event.physical_keycode
			print("V24 DESKTOP KEY: " + event.as_text())
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			print("V24 DESKTOP CLICK: " + str(event.position))

var game: SurvivorGame
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS: " if ok else "FAIL: ") + text)

func _run() -> void:
	root.size = Vector2i(960, 540)
	root.title = "V2.4 Desktop UI Verification"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	var observer := Observer.new()
	observer.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(observer)
	var phase: int = -2
	var battle_lock_checked: bool = false
	var deadline: int = Time.get_ticks_msec() + 600000
	print("V24 DESKTOP READY: click lancer; 3 preview archer; Enter; battle 1; click bottom weapon display; HUD pause + Space continue; attributes + Tab return; mouse option 1, key 2, mouse option 3; mouse restart; click lancer + Enter; battle 3; pause restart; default Enter; Space roll")
	while Time.get_ticks_msec() < deadline and phase < 17:
		await process_frame
		if not is_instance_valid(game):
			if current_scene is SurvivorGame and current_scene.is_node_ready():
				game = current_scene
			else:
				continue
		game.spawn_timer = 9999
		for enemy in get_nodes_in_group("enemies"):
			enemy.free()
		if game.state == SurvivorGame.State.PLAYING:
			game.elapsed = minf(game.elapsed, 10.0)
		match phase:
			-2:
				if game.selected_profession == 1:
					check(paused and game.state == SurvivorGame.State.START and game.player.health == 100 and game.elapsed == 0 and not game.player.weapon.locked, "Mouse lancer preview does not start or apply stats")
					phase = -1
			-1:
				if game.selected_profession == 2:
					check(paused and game.player.weapon.attack_count == 0, "Physical 3 previews archer without starting or attacking")
					phase = 0
			0:
				if game.state == SurvivorGame.State.PLAYING:
					check(game.player.weapon.attack_count == 0 and game.player.stamina == 100 and game.player.health == 80 and game.player.speed == 240 and game.player.weapon.selected == 2 and game.player.weapon.locked, "Physical Enter starts archer with 80 HP, 240 speed and locked bow without attack or roll")
					game.hud.show_notice("战斗中按 1，确认弓箭不会切换")
					phase = 1
			1:
				if game.player.weapon.selected == 2:
					# SceneTree.process_frame precedes GameManager._process/HUD refresh.
					var before_refresh: String = game.hud.weapon_text.text
					await process_frame
					print("V24 HUD REFRESH: before=%s after=%s" % [before_refresh, game.hud.weapon_text.text])
					check(game.hud.weapon_text.text == "弓箭手 · 弓箭", "Archer start updates the single profession/weapon display")
					game.hud.show_notice("按 1 后点击底部职业武器信息，检查透传攻击")
					phase = 2
			2:
				if observer.last_key == KEY_1 and not battle_lock_checked:
					check(game.player.weapon.selected == 2 and game.player.weapon.attack_count == 0, "Physical battle 1 cannot switch locked bow")
					battle_lock_checked = true
				if game.player.weapon.attack_count > 0:
					check(battle_lock_checked and game.player.weapon.selected == 2 and game.player.stamina == 100, "Physical slot click shoots the selected bow for free without mouse weapon selection")
					game.hud.show_notice("点击右上暂停")
					phase = 3
			3:
				if game.state == SurvivorGame.State.PAUSED:
					check(game.player.weapon.attack_count == 1 and game.player.stamina == 100, "Physical HUD pause consumes click without an extra attack")
					phase = 4
			4:
				if game.state == SurvivorGame.State.PLAYING:
					check(game.player.weapon.attack_count == 1 and game.player.stamina == 100 and not game.player.is_rolling() and not game.player._roll_requested, "Physical Space Continue does not attack or roll")
					game.hud.show_notice("点击右上角色属性，再按 Tab 返回")
					phase = 5
			5:
				if game.stats_open:
					check(paused and game.player.weapon.attack_count == 1, "Physical attribute click opens paused stats without attack")
					phase = 6
			6:
				if game.state == SurvivorGame.State.PLAYING:
					check(game.player.weapon.attack_count == 1 and not game.player._attack_held, "Physical Tab returns without stale attack input")
					game.player.gain_experience(84)
					phase = 7
			7:
				if game.state == SurvivorGame.State.LEVEL_UP:
					check(game.hud.level_ui.choice_layout.vertical and game.pending_levels == 3, "Actual 960-wide window uses vertical cards for three queued upgrades")
					phase = 8
			8:
				if game.pending_levels == 2:
					check(is_equal_approx(game.player.damage_multiplier, 1.2) and game.player.weapon.attack_count == 1, "Physical mouse option 1 applies damage once without attack")
					phase = 9
			9:
				if game.pending_levels == 1:
					check(is_equal_approx(game.player.attack_speed_multiplier, 1.15) and game.player.weapon.selected == 2, "Physical key 2 applies speed once without weapon switch")
					phase = 10
			10:
				if game.state == SurvivorGame.State.PLAYING:
					check(game.player.max_health == 105 and game.player.health == 105 and game.player.weapon.attack_count == 1 and game.player.stamina == 100, "Physical mouse option 3 applies health and resumes without attack")
					game.player.take_damage(10000, Vector2.ZERO)
					phase = 11
			11:
				if game.state == SurvivorGame.State.START:
					check(game.selected_profession == 0 and not game.player.weapon.locked and game.player.health == 100 and game.player.weapon.attack_count == 0 and game.player.stamina == 100, "Physical result restart loads a clean default selection")
					phase = 12
			12:
				if game.state == SurvivorGame.State.PLAYING:
					check(game.player.weapon.attack_count == 0 and game.player.stamina == 100 and game.player.profession_index == 1 and game.player.health == 150 and game.player.speed == 180 and game.player.weapon.selected == 1 and game.player.weapon.locked, "Physical mouse lancer selection and Enter start 150 HP, 180 speed and locked spear")
					phase = 13
			13:
				if observer.last_key == KEY_3:
					check(game.player.weapon.selected == 1 and game.player.weapon.attack_count == 0, "Physical battle 3 cannot switch locked spear")
					game.toggle_pause()
					phase = 14
			14:
				if game.state == SurvivorGame.State.START:
					check(game.selected_profession == 0 and not game.player.weapon.locked and game.player.level == 1, "Physical pause-menu restart resets profession and upgrades")
					phase = 15
			15:
				if game.state == SurvivorGame.State.PLAYING:
					check(game.player.profession_index == 0 and game.player.health == 100 and game.player.speed == 225 and game.player.weapon.selected == 0 and game.player.weapon.locked and game.player.weapon.attack_count == 0, "Physical default Enter initializes swordsman without stale input")
					phase = 16
			16:
				if game.player.is_rolling():
					check(game.player.stamina == 70 and game.player.weapon.selected == 0 and game.player.weapon.attack_count == 0, "Physical Space rolls once for 30 stamina with locked sword")
					phase = 17
	print("V24 DESKTOP RESULT: %d checks, %d failures, phase=%d/17" % [checks, failures, phase])
	paused = false
	quit(0 if phase == 17 and failures == 0 else 1)

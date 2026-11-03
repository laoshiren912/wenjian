extends SceneTree

# Controlled input/state fixtures, not a human playthrough.
var checks := 0
var failures := 0
var game: Node

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS: " if ok else "FAIL: ") + message)

func frames(count: int = 3) -> void:
	for i in range(count):
		await physics_frame
	await process_frame

func key(code: int, pressed: bool = true) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	root.push_input(event, true)

func mouse(pressed: bool, point: Vector2, right: bool = false) -> void:
	var action := "ranged_attack" if right else "attack"
	if pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT if right else MOUSE_BUTTON_LEFT
	event.position = point
	event.global_position = point
	event.pressed = pressed
	root.push_input(event, true)

func button(prefix: String) -> Button:
	for candidate in game.hud.root.find_children("*", "Button", true, false):
		if candidate.is_visible_in_tree() and candidate.text.begins_with(prefix):
			return candidate
	assert(false, "Missing button " + prefix)
	return null

func click(prefix: String) -> void:
	var point := button(prefix).get_global_rect().get_center()
	mouse(true, point)
	await frames()
	mouse(false, point)
	await frames()

func visible_text(node: Node) -> String:
	var result := ""
	if node is Control and not node.is_visible_in_tree():
		return result
	if node is Label or node is Button:
		result += node.text + "\n"
	for child in node.get_children():
		result += visible_text(child)
	return result

func snapshot(name: String) -> void:
	await frames()
	var bounds := Rect2(Vector2.ZERO, game.hud.root.size).grow(1)
	for panel in game.hud.combat_panels:
		check(bounds.encloses(panel.get_global_rect()), name + " HUD fits viewport")
	if game.hud.overlay.visible:
		check(bounds.encloses(game.hud.modal_panel.get_global_rect()), name + " modal fits viewport")
	var text := visible_text(game.hud.root)
	for inactive in ["金币", "技能点", "秘籍", "GM", "选择职业", "商店", "Lv."]:
		check(not inactive in text, name + " hides " + inactive)
	if OS.get_cmdline_user_args().has("--visual"):
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/runtime/v32_visual/" + name + ".png")

func run() -> void:
	check(ResourceLoader.exists("res://scenes/main_v32.tscn"), "V3.2 remains available")
	for path in ["main_v31", "main", "corridor_trial"]:
		check(load("res://scenes/" + path + ".tscn") != null, path + " remains loadable")
	game = load("res://scenes/main_v32.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frames()
	check(not paused and not game.hud.overlay.visible and game.player.dual_attack_enabled, "direct single-hero entry")
	check(game.player.speed == 225.0 and game.player.collision_mask == 5 and game.total == 6, "movement collision and six enemies preserved")
	await click("暂停")
	check(paused and game.menu_open and game.player.weapon.attack_count == 0, "HUD pause consumes click")
	await click("继续")
	check(not paused and game.player.weapon.attack_count == 0, "resume consumes click")
	await click("角色属性")
	check(paused and game.stats_open and game.player.weapon.attack_count == 0, "stats consumes click")
	await click("返回战斗")
	check(not paused, "stats button resumes")
	key(KEY_SPACE)
	await frames(2)
	check(game.player.is_rolling() and not paused and game.player.stamina < 100.0, "Space rolls after menu clicks instead of activating buttons")
	key(KEY_SPACE, false)
	await frames(30)
	key(KEY_TAB)
	check(paused and game.stats_open, "Tab opens stats")
	key(KEY_TAB, false)
	key(KEY_TAB)
	check(not paused, "Tab closes stats")
	key(KEY_TAB, false)
	var synthetic_tab := InputEventKey.new()
	synthetic_tab.keycode = KEY_TAB
	synthetic_tab.physical_keycode = KEY_SHIFT
	synthetic_tab.pressed = true
	root.push_input(synthetic_tab, true)
	check(paused and game.stats_open, "logical Tab works with an OS-injected mismatched scan code")
	key(KEY_ESCAPE)
	key(KEY_ESCAPE, false)
	check(not paused, "Esc returns from synthetic Tab stats")
	mouse(true, Vector2(640, 380))
	await frames(55)
	check(game.player.weapon.attack_count >= 2, "held sword still repeats")
	key(KEY_ESCAPE)
	check(paused and not game.player._attack_held, "pause clears held sword")
	key(KEY_ESCAPE, false)
	key(KEY_ESCAPE)
	key(KEY_ESCAPE, false)
	var attacks: int = game.player.weapon.attack_count
	await frames(55)
	check(game.player.weapon.attack_count == attacks, "resume does not repeat old hold")
	mouse(false, Vector2(640, 380))
	mouse(true, Vector2(640, 380), true)
	await frames()
	check(game.player.ranged_weapon.attack_count > 0, "right click fires arrow")
	game.player.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(not game.player._ranged_held and not game.player._attack_held, "focus-loss handler clears holds (simulated notification)")
	mouse(false, Vector2(640, 380), true)
	game.start_room()
	# Queue an emergence and a projectile, then prove both clocks stop under pause.
	game.player.global_position.x = game.world.cell_center(Vector2i(15, 14)).x
	await frames(2)
	check(game.encounters.size() == 1 and game.encounters[0].state == "warning", "walking over trigger starts warning")
	game.player.global_position = game.world.cell_center(Vector2i(13, 14))
	var projectile = load("res://scenes/projectile.tscn").instantiate()
	game.world.actors.add_child(projectile)
	projectile.global_position = game.player.global_position + Vector2(0, 20)
	game.feedback.show_damage(game.player.global_position, 1, false)
	game.toggle_pause()
	var warning_time: float = game.encounters[0].time
	var projectile_position: Vector2 = projectile.position
	var player_position: Vector2 = game.player.position
	var popup_age: float = game.feedback.popups[0].age
	await frames(10)
	check(game.encounters[0].time == warning_time and projectile.position == projectile_position and game.player.position == player_position and game.feedback.popups[0].age == popup_age, "pause freezes emergence projectile player and feedback")
	await click("重新开始")
	check(not paused and game.remaining == 6 and game.encounters.is_empty() and game.world.actors.get_child_count() == 1 and game.feedback.popups.is_empty() and game.feedback.bursts.is_empty() and game.get_node("Camera2D").offset == Vector2.ZERO, "pause restart cleans actors projectiles feedback and camera")
	# Exercise all six inherited encounters through the new controller.
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	for i in range(6):
		game.player.global_position.x = game.world.cell_center(Vector2i(game.world.TRIGGER_X[i], 14)).x
		game._physics_process(0.01)
		var entry: Dictionary = game.encounters[i]
		var enemy: SurvivorEnemy = entry.enemy
		check(enemy.encounter_id == -1 and not enemy.dodge_enabled and enemy.emerging, "trigger %d preserves current AI and protection" % i)
		game._physics_process(0.61)
		game.player.global_position = enemy.global_position
		game._physics_process(0.61)
		check(entry.state == "rising" and enemy.collision_layer == 0, "trigger %d waits for occupied spawn" % i)
		game.player.global_position = game.world.cell_center(Vector2i(13, 14))
		game._physics_process(0.01)
		enemy.set_physics_process(false)
		check(entry.state == "active" and not enemy.emerging, "trigger %d activates" % i)
		enemy.take_damage(10000, Vector2.ZERO)
		await process_frame
		check(game.world.portal_open == (i == 5) and not paused, "trigger %d exit gating without automatic result" % i)
	check(game.player.level == 1 and game.player.skill_points == 0 and game.player.manuals.is_empty(), "no growth or manuals enabled")
	game.player.global_position = game.world.cell_center(game.world.PORTAL_CELL)
	game._physics_process(0.01)
	check(paused and game.phase == "cleared" and game.hud.overlay.visible, "portal opens completed modal and pauses world")
	key(KEY_SPACE)
	key(KEY_SPACE, false)
	await frames()
	check(game.phase == "cleared" and paused, "Space cannot restart result")
	key(KEY_ENTER)
	key(KEY_ENTER, false)
	check(game.phase == "combat" and not paused and not game.world.portal_open, "Enter restarts completed room")
	game.player.take_damage(10000, Vector2.ZERO)
	check(game.phase == "dead" and paused, "death pauses and shows result")
	key(KEY_R)
	key(KEY_R, false)
	check(game.phase == "combat" and not paused and game.player.health == 100.0, "R restarts death")
	for dimensions in [Vector2i(960, 540), Vector2i(1280, 720)]:
		root.size = dimensions
		game.start_room()
		var suffix := "%dx%d" % [dimensions.x, dimensions.y]
		await snapshot("combat_" + suffix)
		game.toggle_pause()
		await snapshot("pause_" + suffix)
		game.resume_room()
		game.toggle_stats()
		await snapshot("stats_" + suffix)
		game.resume_room()
		game.player.take_damage(10000, Vector2.ZERO)
		await snapshot("dead_" + suffix)
		game.start_room()
		game.phase = "cleared"
		game.remaining = 0
		game.triggered_count = game.total
		game.world.triggered.assign([true, true, true, true, true, true])
		game.world.portal_open = true
		game.world.queue_redraw()
		game.player.global_position = game.world.cell_center(game.world.PORTAL_CELL)
		game._update_status()
		game._show_result(true)
		await snapshot("complete_" + suffix)
	paused = false
	game.queue_free()
	await process_frame
	print("ROOM BASE: %d checks, %d failures; controlled fixtures, not human playtest" % [checks, failures])
	quit(1 if failures else 0)

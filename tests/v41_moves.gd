extends SceneTree

const CONFIG = preload("res://scripts/v41_config.gd")
const POOL = preload("res://scripts/v41_card_pool.gd")
var game
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)

func frames(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
	await process_frame

func action(name: String, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = pressed
	root.push_input(event)

func effects(kind: String) -> Array:
	return game.world.actors.get_children().filter(func(n): return n.get_script() != null and n.get_script().resource_path == "res://scripts/v41_move_effect.gd" and n.kind == kind and not n.is_queued_for_deletion())

func arrows() -> Array:
	return get_nodes_in_group("projectiles").filter(func(n): return not n.is_queued_for_deletion() and not n.hostile)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	game = load("res://scenes/main_v41.tscn").instantiate()
	root.add_child(game)
	await process_frame
	check(game.phase == "reward_select" and paused and game.triggered_count == 0, "opening choice before spawn")
	check(game.reward_options == [4, 5, 6], "opening offers three moves")
	var opening_button: Button
	for button in game.hud.modal_panel.find_children("*", "Button", true, false):
		if button.text.begins_with("剑气斩"):
			opening_button = button
	check(opening_button != null, "opening card button exists")
	opening_button.pressed.emit()
	check(not paused and game.phase == "combat" and game.player.move_energy and game.triggered_count == 4, "selection equips and starts")
	var p = game.player
	p.gm_invulnerable = true
	for e in get_nodes_in_group("enemies"):
		e.set_physics_process(false)
	var sword = p.combo
	check(not p.move_echo and not p.move_return, "unselected slots inactive")
	p._roll_cooldown = 0.0
	p.try_roll()
	check(effects("echo").is_empty(), "roll without echo makes no explosion")
	action("ranged_attack", true)
	action("ranged_attack", false)
	check(not p.return_buffered, "roll without return does not buffer")
	p._finish_roll()
	check(p.return_window == 0.0, "roll without return opens no window")
	p.stamina = p.max_stamina
	p._roll_cooldown = 0.0
	sword.charge_time = CONFIG.CHARGE_DURATION * 0.5
	sword._release_charge(Vector2.RIGHT)
	check(effects("energy").is_empty(), "partial charge no energy")
	sword.swing_time = 0.0
	sword.charge_time = CONFIG.CHARGE_DURATION
	sword._release_charge(Vector2.RIGHT)
	check(effects("energy").size() == 1, "full charge energy")
	check(is_equal_approx(effects("energy")[0].damage, CONFIG.CHARGE_MAX * CONFIG.ENERGY_DAMAGE_FACTOR), "energy configured damage")
	check(is_equal_approx(effects("energy")[0].distance, CONFIG.ENERGY_DISTANCE), "energy initial distance")
	var first = get_nodes_in_group("enemies")[0]
	var second = get_nodes_in_group("enemies")[1]
	first.global_position = p.global_position + Vector2(35, 0)
	second.global_position = p.global_position + Vector2(75, 0)
	first.guard_cooldown = 10.0
	second.guard_cooldown = 10.0
	var hp1: float = first.health
	var hp2: float = second.health
	effects("energy")[0]._physics_process(0.2)
	check(is_equal_approx(hp1 - first.health, CONFIG.CHARGE_MAX * CONFIG.ENERGY_DAMAGE_FACTOR) and is_equal_approx(hp2 - second.health, CONFIG.CHARGE_MAX * CONFIG.ENERGY_DAMAGE_FACTOR), "energy penetrates and damages both targets")
	first.guard_cooldown = 0.0
	first.guard_time = 0.0
	first.guard_direction = Vector2.LEFT
	first.encounter_state = first.EncounterState.CHASE
	var guarded_energy = preload("res://scripts/v41_move_effect.gd").new()
	guarded_energy.direction = Vector2.RIGHT
	guarded_energy.distance = CONFIG.ENERGY_DISTANCE
	guarded_energy.damage = CONFIG.CHARGE_MAX * CONFIG.ENERGY_DAMAGE_FACTOR
	game.world.actors.add_child(guarded_energy)
	guarded_energy.global_position = p.global_position
	hp1 = first.health
	guarded_energy._physics_process(0.1)
	check(is_equal_approx(hp1 - first.health, CONFIG.CHARGE_MAX * CONFIG.ENERGY_DAMAGE_FACTOR * CONFIG.GUARD_DAMAGE_FACTOR), "front guard reduces sword energy")
	game.debug_grant(7)
	sword.charge_time = CONFIG.CHARGE_DURATION
	sword._release_charge(Vector2.RIGHT)
	check(is_equal_approx(effects("energy").back().distance, CONFIG.ENERGY_DISTANCE + CONFIG.ENERGY_EXTRA_DISTANCE), "energy upgrade")
	game.debug_grant(5)
	game.debug_grant(6)
	game.debug_grant(1)
	sword.swing_time = 0.0
	p._roll_cooldown = 0.0
	check(p.try_roll(), "roll starts")
	check(effects("echo").size() == 1 and p.combo.roll_armed, "echo leaves roll multiplier armed")
	var echo = effects("echo")[0]
	first.global_position = echo.global_position + Vector2(40, 0)
	first.guard_cooldown = 0.0
	first.guard_time = 0.0
	first.guard_direction = Vector2.LEFT
	hp1 = first.health
	echo._physics_process(CONFIG.ECHO_DELAY + 0.01)
	check(is_equal_approx(hp1 - first.health, CONFIG.ECHO_DAMAGE), "echo damages nearby target")
	check(p.combo.roll_armed, "echo does not consume roll multiplier")
	p.bow_recovery_remaining = 0.6
	p.weapon.swing_time = 0.25
	action("ranged_attack", true)
	action("ranged_attack", false)
	check(p.return_buffered, "press during roll buffered")
	var before: int = p.ranged_weapon.attack_count
	p._finish_roll()
	check(p.ranged_weapon.attack_count == before + 1, "buffered arrow bypasses sword and bow recovery")
	check(not arrows().is_empty() and is_equal_approx(arrows().back().damage, 84.0), "return arrow and roll multiplier stack")
	check(not p.combo.roll_armed, "arrow consumes multiplier")
	p._ranged_pending = true
	p._tick_ranged_attack(0.016, false)
	p._tick_ranged_attack(0.016, false)
	check(p.ranged_weapon.attack_count == before + 1, "one roll cannot fire multiple return arrows")
	p._roll_cooldown = 0.0
	p.weapon.swing_time = 0.0
	p.stamina = p.max_stamina
	p.try_roll()
	before = p.ranged_weapon.attack_count
	action("ranged_attack", true)
	action("ranged_attack", false)
	await frames(24)
	check(not p.is_rolling() and p.ranged_weapon.attack_count == before + 1, "buffered press fires on real roll completion")
	p._roll_cooldown = 0.0
	p.weapon.swing_time = 0.0
	p.stamina = p.max_stamina
	action("ranged_attack", true)
	p.try_roll()
	before = p.ranged_weapon.attack_count
	await frames(24)
	check(not p.is_rolling() and p.ranged_weapon.attack_count == before, "held across real roll without press does not fire")
	action("ranged_attack", false)
	p._roll_cooldown = 0.0
	p.weapon.swing_time = 0.0
	check(p.try_roll(), "second roll")
	p._ranged_held = true
	before = p.ranged_weapon.attack_count
	p._finish_roll()
	check(p.ranged_weapon.attack_count == before, "held without new press does not fire")
	p._ranged_pending = true
	p.weapon.swing_time = 0.2
	p.bow_recovery_remaining = 0.6
	p._tick_ranged_attack(0.016, false)
	check(p.ranged_weapon.attack_count == before + 1, "press in window bypasses recovery")
	p.return_window = 0.0
	p.bow_recovery_remaining = 0.0
	p.weapon.swing_time = 0.0
	p._ranged_pending = true
	before = p.ranged_weapon.attack_count
	p._tick_ranged_attack(0.016, false)
	check(p.ranged_weapon.attack_count == before and is_equal_approx(p.bow_windup_remaining, 0.5), "outside window normal draw")
	p.combo.roll_armed = true
	p.ranged_weapon.cooldown = 0.0
	p.ranged_weapon.attack(Vector2.RIGHT)
	check(is_equal_approx(arrows().back().damage, 42.0) and not p.combo.roll_armed, "normal arrow consumes roll bonus")
	game.debug_grant(8)
	game.debug_grant(9)
	check(p.upgrade_echo and p.upgrade_return, "debug grants upgrades")
	p._roll_cooldown = 0.0
	p.weapon.swing_time = 0.0
	p.try_roll()
	check(is_equal_approx(effects("echo").back().radius, CONFIG.ECHO_UPGRADED_RADIUS), "upgraded echo radius")
	p._finish_roll()
	check(is_equal_approx(p.return_window, 1.2), "upgraded arrow window")
	game._draw_rewards()
	check(game.reward_options.size() == 3 and 4 not in game.reward_options and 5 not in game.reward_options and 6 not in game.reward_options, "clear rewards exclude equipped cards")
	for slot in range(3):
		var empty: Array[int] = [0,0,0,0,0,0,0,0,0,0]
		check(not POOL.eligible(7 + slot, empty), "upgrade requires move")
	game.start_room()
	check(game.opening_choice and game.triggered_count == 0, "restart offers opening")
	var f8 := InputEventKey.new()
	f8.keycode = KEY_QUOTELEFT
	f8.pressed = true
	root.push_input(f8)
	await process_frame
	await process_frame
	var skip_button: Button
	var echo_button: Button
	var echo_upgrade_button: Button
	for button in game.hud.modal_panel.find_children("*", "Button", true, false):
		if button.text == "跳过开局选卡":
			skip_button = button
		if button.text.begins_with("残影步 ·"):
			echo_button = button
		if button.text.begins_with("残影步强化"):
			echo_upgrade_button = button
	check(skip_button != null and not skip_button.disabled, "backtick exposes debug skip")
	check(echo_button != null and echo_upgrade_button != null and echo_upgrade_button.disabled, "debug upgrade initially disabled")
	echo_button.pressed.emit()
	check(game.player.move_echo and game.reward_counts[5] == 1, "debug button grants chosen card")
	for button in game.hud.modal_panel.find_children("*", "Button", true, false):
		if button.text.begins_with("残影步强化"):
			echo_upgrade_button = button
		if button.text == "跳过开局选卡":
			skip_button = button
	check(not echo_upgrade_button.disabled, "debug upgrade enabled after move")
	echo_upgrade_button.pressed.emit()
	check(game.player.upgrade_echo, "debug button grants upgrade")
	for button in game.hud.modal_panel.find_children("*", "Button", true, false):
		if button.text == "跳过开局选卡":
			skip_button = button
	await process_frame
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(root.size))
	check(viewport_rect.encloses(skip_button.get_global_rect()), "debug skip fits viewport")
	root.size = Vector2i(960, 540)
	root.content_scale_size = Vector2i(960, 540)
	await process_frame
	await process_frame
	var small_rect := Rect2(Vector2.ZERO, Vector2(root.size))
	var scroll := game.hud.modal_panel.find_child("*", true, false) as ScrollContainer
	if scroll == null:
		for node in game.hud.modal_panel.find_children("*", "ScrollContainer", true, false):
			scroll = node as ScrollContainer
			break
	if scroll != null:
		scroll.ensure_control_visible(skip_button)
	await process_frame
	await process_frame
	var button_rect := skip_button.get_global_rect()
	print("PANEL=", game.hud.modal_panel.get_global_rect(), " SCROLL=", scroll.get_global_rect() if scroll != null else "missing")
	print("SMALL_VIEWPORT=", small_rect, " BUTTON=", button_rect, " overflow_left=", maxf(0.0, -button_rect.position.x), " overflow_top=", maxf(0.0, -button_rect.position.y), " overflow_right=", maxf(0.0, button_rect.end.x - small_rect.end.x), " overflow_bottom=", maxf(0.0, button_rect.end.y - small_rect.end.y))
	check(scroll != null and small_rect.encloses(button_rect) and scroll.get_global_rect().encloses(button_rect) and skip_button.is_visible_in_tree() and not skip_button.disabled, "debug skip visible and enabled in small viewport")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = button_rect.get_center()
	click.global_position = click.position
	click.pressed = true
	root.push_input(click, true)
	click = click.duplicate()
	click.pressed = false
	root.push_input(click, true)
	await process_frame
	check(game.phase == "combat" and not paused and game.triggered_count == 4, "debug skip clickable in small viewport")
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	game.player.combo.charge_time = CONFIG.CHARGE_DURATION
	game.player.combo._release_charge(Vector2.RIGHT)
	check(effects("energy").is_empty(), "full charge without energy card makes no projectile")
	game.player.combo.swing_time = 0.0
	for room in range(CONFIG.BOSS_ROOM):
		check(game.room_index == room and game.phase == "combat", "combat room %d" % room)
		while game.phase == "combat":
			for enemy in get_nodes_in_group("enemies"):
				if not enemy.dead and not enemy.is_queued_for_deletion():
					enemy.take_damage(100000.0, Vector2.ZERO, true)
			await frames(2)
		check(game.phase == "reward_wait", "room cleared %d" % room)
		game.player.global_position = CONFIG.REWARD_POINT
		var key := InputEventKey.new()
		key.keycode = KEY_E
		key.pressed = true
		root.push_input(key)
		check(game.phase == "reward_select" and paused and game.reward_options.size() == 3, "room reward menu %d" % room)
		var choice: int = game.reward_options[0]
		check(game.can_select_reward(choice), "selectable room reward %d" % room)
		game.select_reward(choice)
		check(game.phase == "exit_ready" and game.world.portal_open and not paused, "reward opens exit %d" % room)
		game.player.global_position = CONFIG.EXIT_POINT
		await frames(3)
	check(game.room_index == CONFIG.BOSS_ROOM and is_instance_valid(game.boss), "boss room reached")
	game.boss.take_damage(100000.0, Vector2.ZERO, true)
	await frames(2)
	check(game.phase == "cleared" and paused, "boss victory")
	print("V41 moves: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures else 0)

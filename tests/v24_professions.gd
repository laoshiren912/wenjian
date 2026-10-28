extends "res://tests/ui_click_probe.gd"

# Real scenes and GUI dispatch; controlled targets are not a play-balance verdict.
func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await frames(2)

func screen_text() -> String:
	var text := ""
	for label in game.hud.root.find_children("*", "Label", true, false):
		if label.is_visible_in_tree():
			text += label.text + "\n"
	return text

func fresh() -> void:
	for action in ["move_up", "move_down", "move_left", "move_right", "attack", "roll"]:
		Input.action_release(action)
	game.restart_run()
	await reloaded()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frames(4)
	fixture()
	check(game.selected_profession == 0 and paused and not game.player.weapon.locked, "Default start selects swordsman without initializing a run")
	await key(KEY_ENTER)
	check(game.state == SurvivorGame.State.PLAYING and game.player.profession_index == 0 and game.player.weapon.locked, "Enter starts the default swordsman")
	var expected_hp := [100.0, 150.0, 80.0]
	var expected_speed := [225.0, 180.0, 240.0]
	var expected_names := ["剑士", "枪兵", "弓箭手"]
	for index in range(3):
		await fresh()
		check(not game.player.initialize_profession(-1) and not game.player.initialize_profession(3) and not game.player.weapon.locked, "Invalid professions cannot initialize or lock a player")
		game.select_profession(-1)
		game.select_profession(3)
		check(game.selected_profession == 0, "Invalid preview selections leave the default unchanged")
		var elapsed: float = game.elapsed
		var position: Vector2 = game.player.position
		await click(game.hud.profession_buttons[(index + 1) % 3])
		check(game.selected_profession == (index + 1) % 3 and paused and game.player.weapon.attack_count == 0, "Mouse card selection previews without starting or attacking")
		await key(KEY_1 + index)
		await frames(15)
		check(game.selected_profession == index and game.elapsed == elapsed and game.player.position == position and game.player.health == 100 and not game.player.weapon.locked, "Numeric selection freezes world/time and leaves actual attributes unapplied")
		await key(KEY_ENTER)
		var player: SurvivorPlayer = game.player
		check(player.profession_index == index and player.weapon.selected == index and player.weapon.locked and player.max_health == expected_hp[index] and player.health == expected_hp[index] and player.speed == expected_speed[index], "Profession %d initializes the specified HP, speed and locked weapon" % (index + 1))
		check(player.stamina == 100 and player.max_stamina == 100 and player.stamina_regen == 26 and player.roll_distance == 150 and player.roll_duration == 0.34 and player.roll_stamina_cost == 30 and player.roll_cooldown == 0.65, "Profession %d keeps the original stamina and roll rules" % (index + 1))
		check(player.weapon.attack_count == 0 and not player._attack_held and not player._attack_pending and not player._roll_requested and not player.is_rolling(), "Card/Enter confirmation leaks no attack or roll")
		check(game.hud.weapon_text.text == "%s · %s" % [expected_names[index], SurvivorWeapon.DATA[index].name], "Combat HUD names only the actual profession and weapon")
		position = player.position
		Input.action_press("move_right")
		await frames(10)
		Input.action_release("move_right")
		check(absf(player.get_real_velocity().x - expected_speed[index]) < 0.1 and player.position.x > position.x, "Profession %d uses its actual configured walking speed" % (index + 1))
		player.position = SurvivorWorld.SPAWN
		for other in range(3):
			await key(KEY_1 + other)
			player.weapon.select_weapon(other)
			player.weapon.selected = other
			game.select_profession(other)
		check(player.weapon.selected == index and player.profession_index == index and game.selected_profession == index and player.weapon.attack_count == 0, "Battle keys, public selection API and selected property cannot switch a locked loadout")
		check(not player.weapon.lock_to((index + 1) % 3) and not player.initialize_profession((index + 1) % 3), "Locked loadout cannot be initialized or locked a second time")
		player.visual.facing = Vector2.RIGHT
		check(player.try_roll(), "Each profession can roll normally")
		for other in range(3):
			await key(KEY_1 + other)
		check(player.is_rolling() and player.weapon.selected == index and player.weapon.attack_count == 0, "Numeric keys cannot switch weapons or attack during a roll")
		await frames(90)
		check(not player.is_rolling() and player.stamina == 100, "Roll finishes and restores stamina at the original rate")
		game.show_stats()
		var text: String = screen_text()
		check(paused and text.contains(expected_names[index]) and text.contains("本局武器固定"), "Stats show the current profession and lock rule")
		for other in range(3):
			var prefix: String = "%s（" % SurvivorWeapon.DATA[other].name
			check(text.contains(prefix) == (other == index), "Stats contain only the current weapon, checked against slot %d" % (other + 1))
		check(not player.initialize_profession(index), "Paused stats cannot reinitialize profession attributes")
		await key(KEY_TAB)
		player.health = expected_hp[index] - 60
		player.gain_experience(player.next_level_xp)
		await frames(3)
		await key(KEY_3)
		check(not paused and player.max_health == expected_hp[index] + 25 and player.health == expected_hp[index] - 20 and player.weapon.selected == index, "Vitality adds 25 maximum HP and heals exactly 40 for profession %d" % (index + 1))
		player.health = player.max_health - 1
		player.gain_experience(player.next_level_xp)
		await frames(3)
		await key(KEY_3)
		check(player.max_health == expected_hp[index] + 50 and player.health == player.max_health, "Vitality healing clamps to the increased maximum")
		player.gain_experience(player.next_level_xp + (18 + player.level * 10))
		await frames(3)
		check(game.pending_levels == 2 and paused, "Earned multi-level gains queue two separate choices")
		await key(KEY_1)
		await key(KEY_2)
		check(not paused and game.pending_levels == 0 and is_equal_approx(player.damage_multiplier, 1.2) and is_equal_approx(player.attack_speed_multiplier, 1.15) and player.weapon.selected == index and player.weapon.attack_count == 0, "Queued numeric upgrades apply once each without switching or attacking")
		var upgraded_hp: float = player.max_health
		var hurt_hp: float = player.health - 7
		player.health = hurt_hp
		game.start_run()
		game.toggle_pause()
		game.start_run()
		game.resume_run()
		check(player.health == hurt_hp and player.max_health == upgraded_hp and player.speed == expected_speed[index] and is_equal_approx(player.damage_multiplier, 1.2), "Repeated start and pause/resume preserve HP, upgrades and profession speed")
		# Rolling moved the player out of the obstacle-free spawn area. Keep the
		# damage fixture inside it so random pillars do not legitimately block hits.
		player.position = SurvivorWorld.SPAWN
		var target: SurvivorEnemy = game._spawn_enemy(SurvivorEnemy.Kind.HOSTILE, player.position + Vector2([70, 135, 200][index], 0))
		target.set_physics_process(false)
		check(player.weapon.attack(Vector2.RIGHT), "Profession %d can perform its real weapon attack" % (index + 1))
		var cooldown: float = player.weapon.cooldown
		player.weapon.select_weapon((index + 1) % 3)
		check(player.weapon.selected == index and player.weapon.cooldown == cooldown and not player.weapon.attack(Vector2.RIGHT), "Rejected weapon switch cannot reset or bypass attack cooldown")
		await frames(30)
		check(is_equal_approx(target.health, target.max_health - float(SurvivorWeapon.DATA[index].damage) * 1.2), "Profession %d keeps original damage and actual upgrade application" % (index + 1))
		fixture()
		game.elapsed = SurvivorGame.RUN_DURATION
		game._end_run(true)
		check(screen_text().contains("本局职业  " + expected_names[index]), "Victory reports the actual run profession")
		await click(button("重新开始"))
		await reloaded()
		check(game.state == SurvivorGame.State.START and game.selected_profession == 0 and not game.player.weapon.locked and game.player.max_health == 100 and game.player.level == 1 and game.player.stamina == 100, "Victory restart clears profession, upgrades and input state")
		game.select_profession(index)
		await click(button("开始试炼"))
		game.player.take_damage(10000, Vector2.ZERO)
		await frames(3)
		check(game.state == SurvivorGame.State.DEAD and screen_text().contains("本局职业  " + expected_names[index]), "Death reports the actual run profession")
		await click(button("重新开始"))
		await reloaded()
		check(game.selected_profession == 0 and game.state == SurvivorGame.State.START and not game.player.weapon.locked, "Death restart allows a new profession selection")
		game.select_profession(index)
		await click(button("开始试炼"))
		game.toggle_pause()
		await click(button("重新开始"))
		await reloaded()
		check(game.selected_profession == 0 and game.state == SurvivorGame.State.START and not game.player.weapon.locked and game.player.weapon.attack_count == 0, "Pause-menu restart returns to default profession without old attacks")
	print("V24 PROFESSION RESULT: %d checks, %d failures" % [checks, failures])
	paused = false
	quit(0 if failures == 0 else 1)

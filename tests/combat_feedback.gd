extends SceneTree

var game: SurvivorGame
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func frames(count: int = 3) -> void:
	for frame in range(count):
		await physics_frame
	await process_frame

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print(("PASS: " if condition else "FAIL: ") + description)

func enemy_at(offset: Vector2, kind: int = SurvivorEnemy.Kind.HOSTILE) -> SurvivorEnemy:
	var enemy := game._spawn_enemy(kind, game.player.position + offset)
	enemy.set_physics_process(false)
	return enemy

func has_popup(kind: String, amount: float) -> bool:
	for popup in game.feedback.popups:
		if popup.kind == kind and is_equal_approx(float(popup.amount), amount):
			return true
	return false

func clear_enemies() -> void:
	for enemy in get_nodes_in_group("enemies"):
		enemy.free()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frames()
	game.start_run()
	clear_enemies()
	game.spawn_timer = 9999.0
	game.elapsed = 0.0
	var early := enemy_at(Vector2(70, 0))
	var passive := enemy_at(Vector2(220, 80), SurvivorEnemy.Kind.PASSIVE)
	check(is_equal_approx(early.max_health, 180.0) and is_equal_approx(passive.max_health, 120.0), "Enemy base HP is now 180 hostile / 120 passive")
	var position_before: Vector2 = game.player.position
	early.take_damage(52.0, Vector2.ZERO)
	check(has_popup("enemy_damage", 52.0), "Enemy damage displays the actual 52 HP lost")
	await frames()
	check(game.player.camera.offset.length() > 0.0 and game.player.position.is_equal_approx(position_before), "Successful hit shakes camera without moving the player")
	await frames(20)
	check(game.player.camera.offset.is_zero_approx(), "Camera shake returns to zero after its short duration")
	game.player.take_damage(12.0, Vector2.ZERO)
	check(has_popup("player_damage", 12.0) and is_equal_approx(game.player.health, 88.0), "Player damage shows red loss matching actual health")
	var popup_count: int = game.feedback.popups.size()
	game.player.take_damage(12.0, Vector2.ZERO)
	check(game.feedback.popups.size() == popup_count, "Blocked damage during invulnerability creates no false damage popup")
	game.player.gain_experience(8)
	check(has_popup("experience", 8.0) and game.hud.notice.text == "+8 经验", "Experience gain displays +8 XP in the world and HUD")
	var all_ignore: bool = true
	for popup in game.feedback.popups:
		all_ignore = all_ignore and popup.label.mouse_filter == Control.MOUSE_FILTER_IGNORE
	check(all_ignore, "Floating text cannot intercept game or GUI mouse input")
	var remaining: float = early.health
	early.take_damage(10000.0, Vector2.ZERO)
	check(has_popup("enemy_damage", remaining), "Lethal popup reports remaining HP lost and survives enemy removal")
	# Keep this visual-expiry fixture from earning another level and pausing itself.
	await frames(2)
	for pickup in get_nodes_in_group("pickups"):
		pickup.free()
	await frames(70)
	check(game.feedback.popups.is_empty() and game.feedback.bursts.is_empty(), "Damage and XP visuals expire without orphan labels")
	game.feedback.show_damage(game.player.position, 5.0, false)
	await frames()
	game.toggle_pause()
	var age: float = game.feedback.popups[0].age
	await frames(30)
	check(is_equal_approx(game.feedback.popups[0].age, age), "Combat visual lifetime pauses with combat")
	game.resume_run()
	await frames(70)
	check(game.feedback.popups.is_empty() and game.player.camera.offset.is_zero_approx(), "Visual cleanup resumes correctly after pause")
	# Six attack upgrades: verify late enemies still survive one actual melee hit.
	clear_enemies()
	for upgrade in range(6):
		game.player.apply_upgrade(0)
	game.elapsed = 180.0
	var late := enemy_at(Vector2(70, 0))
	var late_passive := enemy_at(Vector2(230, 0), SurvivorEnemy.Kind.PASSIVE)
	game.elapsed = 0.0
	check(is_equal_approx(late.max_health, 450.0) and is_equal_approx(late_passive.max_health, 300.0), "Late spawn HP reaches 450 hostile / 300 passive at 180 seconds")
	game.player.weapon.select_weapon(0)
	game.player.weapon.cooldown = 0.0
	game.player.weapon.attack(Vector2.RIGHT)
	check(not late.dead and is_equal_approx(late.health, late.max_health - 52.0 * 2.2), "Late enemy survives a sword hit after six damage upgrades")
	var late_health: float = late.health
	game.elapsed = 150.0
	await frames()
	check(is_equal_approx(late.health, late_health), "Time progression does not refill existing enemy HP")
	game.elapsed = 0.0
	clear_enemies()
	var far := enemy_at(Vector2(85, 0))
	var near := enemy_at(Vector2(50, 0))
	game.player.weapon.cooldown = 0.0
	game.player.weapon.attack(Vector2.RIGHT)
	check(is_equal_approx(far.health, far.max_health) and near.health < near.max_health, "Sword chooses nearest valid enemy rather than scene insertion order")
	game.player.weapon.select_weapon(1)
	await frames()
	check(game.hud.weapon_detail.text.contains("群体穿刺") and SurvivorWeapon.DATA.size() == 3, "HUD shows current weapon role and current upgraded damage")
	print("COMBAT FEEDBACK RESULT: %d checks, %d failures" % [checks, failures])
	if OS.get_cmdline_user_args().has("--visual"):
		game.restart_run()
		await frames(4)
		game = current_scene
		game.start_run()
		clear_enemies()
		game.spawn_timer = 9999.0
		var left := enemy_at(Vector2(-135, -40))
		var right := enemy_at(Vector2(140, -40))
		left.take_damage(52.0, Vector2.ZERO)
		right.take_damage(32.0, Vector2.ZERO)
		game.player.invulnerability = 0.0
		game.player.take_damage(12.0, Vector2.ZERO)
		game.player.gain_experience(4)
		await frames(3)
		paused = true
		print("VISUAL FIXTURE: paused test display of enemy -52/-32, player -12, XP +4. Not a normal-difficulty playthrough.")
		return
	paused = false
	quit(0 if failures == 0 else 1)

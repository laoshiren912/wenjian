extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	printerr("FAIL: " + message) if not ok else print("PASS: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	check(game.state == SurvivorGame.State.PLAYING and not paused and not game.hud.overlay.visible, "starts directly in battle")
	check(game.player.dual_attack_enabled and not game.player.weapon.locked and game.player.ranged_weapon.selected == 2, "single player has sword and bow")
	check(get_nodes_in_group("enemies").size() == 4 and game.pending_wave.size() == 4, "first floor still spawns four plus four")
	for enemy in get_nodes_in_group("enemies"):
		check(not enemy.dodge_enabled and enemy.collision_mask == 7, "enemy matches sample dodge and collision")
		enemy.set_physics_process(false)
	var hero: SurvivorPlayer = game.player
	check(hero.weapon.attack(Vector2.RIGHT), "sword attack works")
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	right.position = Vector2(1000, 400)
	hero._unhandled_input(right)
	await physics_frame
	check(hero.ranged_weapon.attack_count == 0, "bow waits for sword action")
	right.pressed = false
	hero._input(right)
	check(hero.try_roll() and hero.weapon.swing_time == 0.0, "roll interrupts sword")
	for i in range(25): await physics_frame
	right.pressed = true
	hero._unhandled_input(right)
	await physics_frame
	await physics_frame
	check(hero.ranged_weapon.attack_count == 1, "right click fires bow")
	right.pressed = false
	hero._input(right)
	for enemy in get_nodes_in_group("enemies"):
		enemy.take_damage(10000, Vector2.ZERO)
	game.pending_wave.clear()
	game.remaining = 0
	game._floor_cleared()
	check(game.state == SurvivorGame.State.SHOP_PROMPT and paused, "clear opens shop prompt")
	game.open_shop()
	check(game.state == SurvivorGame.State.SHOP, "shop opens")
	game.gold = 450
	game.buy_item(2)
	check(hero.extra_targets == 1 and game.gold == 0, "badge remains sword extra target")
	game.next_floor()
	check(game.floor_number == 2 and game.state == SurvivorGame.State.PLAYING and not paused, "continue to next floor")
	hero.take_damage(10000, Vector2.RIGHT)
	check(game.state == SurvivorGame.State.DEAD, "death screen opens")
	paused = false
	game.queue_free()
	await process_frame
	var fresh = load("res://scenes/main.tscn").instantiate()
	root.add_child(fresh)
	await process_frame
	check(fresh.state == SurvivorGame.State.PLAYING and not paused, "new run enters battle directly")
	print("SINGLE HERO: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	printerr("FAIL: " + label) if not ok else print("PASS: " + label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var sample = load("res://scenes/combat_sample.tscn").instantiate()
	root.add_child(sample)
	await process_frame
	await physics_frame
	check(sample.remaining == 1 and get_nodes_in_group("enemies").size() == 1, "single enemy on startup")
	for button in get_nodes_in_group("sample_buttons"):
		check(button.focus_mode == Control.FOCUS_NONE, "restart button cannot consume Space")
	check(sample.player.dual_attack_enabled and not sample.player.weapon.locked and sample.player.ranged_weapon.selected == 2, "dual weapons without profession lock")
	var enemy: SurvivorEnemy = get_first_node_in_group("enemies")
	check(not enemy.dodge_enabled, "enemy dodge disabled")
	var initial_position: Vector2 = sample.player.global_position
	Input.action_press("move_right")
	for i in range(12): await physics_frame
	Input.action_release("move_right")
	check(sample.player.global_position.x > initial_position.x + 10.0, "movement works")
	var weapon: SurvivorWeapon = sample.player.weapon
	var bow: SurvivorWeapon = sample.player.ranged_weapon
	check(weapon.attack(Vector2.RIGHT), "sword starts")
	check(not sample.player.movement_multiplier() > 0.0, "movement locked during sword")
	var before: int = bow.attack_count
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	click.position = Vector2(900, 400)
	sample.player._unhandled_input(click)
	await physics_frame
	check(bow.attack_count == before, "no simultaneous ranged attack during sword")
	click.pressed = false
	sample.player._input(click)
	check(sample.player.try_roll(), "roll starts during sword")
	check(weapon.swing_time == 0.0 and weapon.cooldown > 0.0, "roll cancels sword but keeps cooldown")
	for i in range(25): await physics_frame
	click.pressed = true
	sample.player._unhandled_input(click)
	await physics_frame
	await physics_frame
	check(bow.attack_count == before + 1 and get_nodes_in_group("projectiles").size() == 1, "right click fires independent bow")
	click.pressed = false
	sample.player._input(click)
	check(weapon.cooldown > 0.0, "sword cooldown remains independent")
	for count in [4, 6]:
		sample.start_sample(count)
		await physics_frame
		check(get_nodes_in_group("enemies").size() == count and sample.remaining == count, "fixed group count %d" % count)
		for target in get_nodes_in_group("enemies"):
			target.take_damage(1000, Vector2.ZERO)
		check(sample.remaining == 0 and "清场" in sample.status.text, "clear result %d" % count)
		sample.start_sample(1)
		await physics_frame
	check(sample.remaining == 1, "restart restores encounter")
	print("SAMPLE RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

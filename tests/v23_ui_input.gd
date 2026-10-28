extends "res://tests/ui_click_probe.gd"

# GUI dispatch at actual control positions; headless Input state is supplied by base helpers.
func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frames(4)
	for size in [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(1024, 768), Vector2i(1920, 1080)]:
		root.size = size
		game.restart_run()
		await reloaded()
		await click(button("开始试炼"))
		check(not paused and game.player.weapon.attack_count == 0, "%s Start click is isolated from combat" % size)
		for prefix in ["暂停", "角色属性"]:
			var attacks: int = game.player.weapon.attack_count
			var stamina: float = game.player.stamina
			await click(button(prefix))
			check(paused and game.player.weapon.attack_count == attacks and game.player.stamina == stamina and not game.player.is_rolling(), "%s %s click consumes input without an attack or roll" % [size, prefix])
			await click(button("继续" if prefix == "暂停" else "返回战斗"))
			await frames(35)
			check(not paused and game.player.weapon.attack_count == attacks and game.player.stamina == stamina, "%s Returning from %s retains no old held attack" % [size, prefix])
		for slot in game.hud.weapon_slots:
			await frames(35)
			var selected: int = game.player.weapon.selected
			var attacks: int = game.player.weapon.attack_count
			await click(slot)
			check(game.player.weapon.attack_count == attacks + 1 and game.player.weapon.selected == selected and game.player.stamina == 100, "%s Weapon slot display permits a normal attack without mouse-selecting a weapon" % size)
		for bar in [game.hud.health_bar, game.hud.xp_bar]:
			await frames(35)
			var attacks: int = game.player.weapon.attack_count
			await click(bar)
			check(game.player.weapon.attack_count == attacks + 1, "%s Noninteractive bar permits normal world input" % size)
		for index in range(3):
			game.player.weapon.select_weapon(index)
			var attacks: int = game.player.weapon.attack_count
			game.player.gain_experience(game.player.next_level_xp)
			await frames(4)
			var remaining: int = game.pending_levels
			var before: Array = [game.player.damage_multiplier, game.player.attack_speed_multiplier, game.player.max_health]
			mouse(true, Vector2(10, 10))
			mouse(false, Vector2(10, 10))
			await frames(3)
			check(paused and game.pending_levels == remaining and game.player.weapon.attack_count == attacks, "%s Upgrade backdrop blocks combat and does not select an option" % size)
			await click(game.hud.level_ui.choices[index])
			await frames(40)
			var after: Array = [game.player.damage_multiplier, game.player.attack_speed_multiplier, game.player.max_health]
			var changes: Array = [0.2, 0.15, 25.0]
			var correct: bool = not paused and game.pending_levels == 0 and game.player.weapon.selected == index and game.player.weapon.attack_count == attacks and game.player.stamina == 100
			for other in range(3):
				correct = correct and is_equal_approx(after[other], before[other] + (changes[other] if other == index else 0.0))
			check(correct, "%s Mouse option %d applies only its upgrade once and resumes without attacking" % [size, index + 1])
		game.player.take_damage(10000, Vector2.ZERO)
		await frames(3)
		await click(button("重新开始"))
		await reloaded()
		check(game.state == SurvivorGame.State.START and game.player.weapon.attack_count == 0 and game.player.stamina == 100, "%s Result restart does not leak input into the new run" % size)
	print("V23 UI INPUT RESULT: %d checks, %d failures" % [checks, failures])
	paused = false
	quit(0 if failures == 0 else 1)

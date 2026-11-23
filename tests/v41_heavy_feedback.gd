extends SceneTree

const CONFIG = preload("res://scripts/v41_config.gd")
var game
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	printerr(("PASS: " if ok else "FAIL: ") + label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	game = load("res://scenes/main_v41.tscn").instantiate()
	root.add_child(game)
	var p = game.player
	var sword = p.combo
	var enemies := get_nodes_in_group("enemies")
	var target = enemies[0]
	for i in range(1, enemies.size()):
		enemies[i].free()
	p.set_physics_process(false)
	sword.set_physics_process(false)
	target.set_physics_process(false)
	p.position = Vector2(600, 420)
	target.position = Vector2(665, 420)
	target.health = 1000.0
	target.max_health = 1000.0
	target.guard_cooldown = 10.0
	for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		sword.stage = 2
		sword.charged_swing = false
		sword.swing_direction = direction
		var start: PackedVector2Array = sword.blade_segment(0.0)
		var end: PackedVector2Array = sword.blade_segment(1.0)
		check(start[1].y < end[1].y and start[0].y < end[0].y, "third blade descends " + str(direction))
		check(sword.display_segment(0.35)[1] == sword.blade_segment(0.35)[1], "draw and hit share blade edge " + str(direction))
	sword.swing_time = 0.0
	sword.next_stage = 0
	sword.chain_time = 0.0
	sword.attack(Vector2.RIGHT)
	for i in range(50): sword._physics_process(0.01)
	check(game.hitstop_active and is_equal_approx(Engine.time_scale, CONFIG.LIGHT_HITSTOP_SCALE), "first hit starts light hitstop")
	await create_timer(CONFIG.LIGHT_HITSTOP + 0.02, true, false, true).timeout
	check(not game.hitstop_active and is_equal_approx(Engine.time_scale, 1.0), "light hitstop restores time scale")
	# Isolate the second contact from the first contact's real-time throttle.
	game.last_combo_impact_ms = -1000
	sword.swing_time = 0.0
	sword.next_stage = 1
	sword.chain_time = 0.2
	sword.attack(Vector2.RIGHT)
	for i in range(50): sword._physics_process(0.01)
	check(game.hitstop_active and is_equal_approx(Engine.time_scale, CONFIG.LIGHT_HITSTOP_SCALE), "second hit starts light hitstop")
	sword.swing_time = 0.0
	sword.next_stage = 2
	sword.chain_time = 0.2
	target.guard_time = CONFIG.GUARD_HOLD
	target.guard_cooldown = 0.0
	target.guard_direction = Vector2.LEFT
	sword.attack(Vector2.RIGHT)
	for i in range(50): sword._physics_process(0.01)
	check(game.hitstop_active and is_equal_approx(Engine.time_scale, CONFIG.THIRD_HITSTOP_SCALE), "third hit starts hitstop")
	check(is_equal_approx(target.knockback.length(), CONFIG.THIRD_MOB_PUSH) and target.v41_heavy_stun > 0.0, "third hit suppresses with configured small push")
	check(not target.last_hit_blocked and is_equal_approx(target.guard_cooldown, CONFIG.HEAVY_BASE_BREAK) and is_equal_approx(target.v41_heavy_stun, CONFIG.BREAK_STUN), "third breaks active guard for base duration and stun")
	check(not game.feedback.guard_effects.is_empty() and game.feedback.guard_effects.back().broken and game.feedback.break_sound.data.size() > 0, "third emits break shards and sound")
	var clean_numbers: bool = not game.feedback.popups.is_empty()
	for popup in game.feedback.popups:
		clean_numbers = clean_numbers and popup.kind == "enemy_damage" and popup.label.text.begins_with("-") and popup.label.text.substr(1).is_valid_int()
		clean_numbers = clean_numbers and popup.label.get_theme_font_size("font_size") == 21 and popup.label.get_theme_color("font_color") == Color("f6ecd4") and popup.label.scale == Vector2.ONE
	check(clean_numbers, "guard-breaking critical hits only emit default damage numbers")
	check(game.feedback.shake_strength >= CONFIG.THIRD_SHAKE and game.feedback.shake_time > 0.0, "third hit shakes camera")
	await create_timer(CONFIG.THIRD_HITSTOP + 0.05, true, false, true).timeout
	check(not game.hitstop_active and is_equal_approx(Engine.time_scale, 1.0), "hitstop restores time scale")
	var before: Vector2 = target.position
	target._encounter_process(1.0 / 60.0)
	check(target.position.distance_to(before) > 0.1 and target.v41_heavy_stun > 0.0, "stunned enemy actually moves from the push")
	game.reward_counts[6] = 1
	game._apply_rewards()
	p.dash_cooldown = 1.0
	target.guard_time = CONFIG.GUARD_HOLD
	target.guard_cooldown = 0.0
	target.v41_heavy_stun = 0.0
	sword._deal_hit(target, 60.0, Vector2.RIGHT * CONFIG.THIRD_MOB_PUSH)
	check(not target.last_hit_blocked and is_equal_approx(target.guard_cooldown, CONFIG.HEAVY_BASE_BREAK) and is_equal_approx(target.v41_heavy_stun, CONFIG.BREAK_STUN) and p.dash_cooldown == 0.0, "third breaks active guard and refreshes dash with 踏雪无痕")
	game._end_hitstop()
	target.position = Vector2(1100, 500)
	sword.swing_time = 0.0
	sword.next_stage = 2
	sword.chain_time = 0.2
	sword.attack(Vector2.RIGHT)
	for i in range(50): sword._physics_process(0.01)
	check(not game.hitstop_active, "missed third does not start hitstop")
	print("V41 HEAVY: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures else 0)

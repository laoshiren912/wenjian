extends SceneTree

const CONFIG = preload("res://scripts/v41_config.gd")
var checks := 0
var failures := 0
var game

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	run.call_deferred()

func tick() -> void:
	await physics_frame
	await process_frame

func run() -> void:
	game = load("res://scenes/main_v41.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	for enemy in get_nodes_in_group("enemies"):
		enemy.free()
	game.scheduler = null
	var p = game.player
	check(p.max_stamina == CONFIG.STAMINA_MAX and p.stamina == CONFIG.STAMINA_MAX and p.stamina_regen == CONFIG.STAMINA_REGEN, "configured stamina values on F5 player")
	check(not p.try_roll() and is_equal_approx(p.stamina, 100.0), "old roll cannot spend stamina")
	p.request_dash(Vector2.RIGHT)
	await tick()
	check(is_equal_approx(p.stamina, 100.0 - CONFIG.DASH_COST) and p.dash_cooldown > 0.0, "dash pays exactly its original cost")
	check(absf(p.stamina_delay - CONFIG.STAMINA_REGEN_DELAY) < 0.035, "dash resets stamina recovery delay")
	while p.dash_state != p.Dash.IDLE:
		await tick()
	p.stamina = CONFIG.THROW_COST - 1.0
	p._request_throw(Vector2.RIGHT)
	await tick()
	check(p.throw_cooldown == 0.0 and not is_instance_valid(p.thrown_sword), "unaffordable cast consumes no cooldown")
	p.stamina = 30.0
	p._request_throw(Vector2.RIGHT)
	await tick()
	check(is_equal_approx(p.stamina, 30.0 - CONFIG.THROW_COST) and is_instance_valid(p.thrown_sword), "throw pays its own cost")
	var remaining_delay: float = p.stamina_delay
	var stamina_before: float = p.stamina
	while p.stamina_delay > 0.04:
		await tick()
	check(is_equal_approx(p.stamina, stamina_before), "stamina does not recover during delay")
	for i in range(33):
		await tick()
	check(is_equal_approx(p.stamina - stamina_before, CONFIG.STAMINA_REGEN * 0.5) or absf(p.stamina - stamina_before - CONFIG.STAMINA_REGEN * 0.5) < 0.6,
		"stamina recovers at the configured rate")
	check(remaining_delay > 0.8 and not is_instance_valid(p.thrown_sword), "throw recovers while the stamina delay runs")
	print("V41 STAMINA: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures else 0)

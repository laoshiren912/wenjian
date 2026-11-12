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
	game.debug_opening(true)
	for enemy in get_nodes_in_group("enemies"):
		enemy.free()
	game.scheduler = null
	var p = game.player
	check(p.max_stamina == CONFIG.STAMINA_MAX and p.stamina == CONFIG.STAMINA_MAX and p.roll_stamina_cost == CONFIG.ROLL_STAMINA_COST and p.stamina_regen == CONFIG.STAMINA_REGEN, "configured stamina values on F5 player")
	for roll in range(6):
		check(p.try_roll(), "consecutive roll %d succeeds" % (roll + 1))
		check(is_equal_approx(p.stamina_delay, CONFIG.STAMINA_REGEN_DELAY), "each roll resets recovery delay")
		while p.is_rolling():
			await tick()
		while p._roll_cooldown > 0.0:
			await tick()
	check(is_equal_approx(p.stamina, 10.0), "six fast rolls leave 10 stamina")
	check(not p.try_roll(), "seventh fast roll blocked by stamina")
	var remaining_delay: float = p.stamina_delay
	var stamina_before: float = p.stamina
	while p.stamina_delay > 0.04:
		await tick()
	check(is_equal_approx(p.stamina, stamina_before), "stamina does not recover during delay")
	var elapsed := 0.0
	while p.stamina < CONFIG.ROLL_STAMINA_COST and elapsed < 2.0:
		await tick()
		elapsed += 1.0 / 60.0
	check(p.stamina >= CONFIG.ROLL_STAMINA_COST and elapsed >= 0.25 and elapsed <= 0.4, "recovery at configured rate after delay")
	check(remaining_delay > 0.4 and p.try_roll(), "roll works again after recovery")
	print("V41 STAMINA: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures else 0)

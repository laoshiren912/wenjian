extends "res://tests/v41_third_probe.gd"

# Controlled initial placement only. Real AI, collision, mouse input and damage.
const CONFIG = preload("res://scripts/v41_config.gd")
var checks := 0
var failures := 0
var clock_time := 0.0
var capture := false
var captured := {}

func check(ok: bool, label: String):
	checks += 1
	if not ok: failures += 1
	print("CHECK ", label, " ", ok)

func tick():
	clock_time += Engine.time_scale / 60.0
	await super.tick()

func snapshot(label: String):
	if not capture or captured.has(label): return
	captured[label] = true
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/v41_finisher_" + label + ".png")

func fresh(count: int, direction: Vector2, distance: float):
	release_move()
	game.start_room()
	await tick()
	var p = game.player
	p.position = Vector2(620, 420)
	var es = get_nodes_in_group("enemies")
	for i in range(count, es.size()): es[i].free()
	es.resize(count)
	for i in range(count):
		es[i].position = p.position + direction * distance + direction.orthogonal() * i * 65.0
		es[i].home_position = es[i].position
		es[i].guard_direction = -direction
	game.scheduler.configure(es, 2, 1.65)
	return es

func run():
	capture = "--capture" in OS.get_cmdline_user_args()
	game = load("res://scenes/main_v41.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await tick()
	await combo_timing()
	await front_block()
	for count in [1, 2]:
		for direction in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
			await counter(count, direction)
	# The visual edge and swept edge share the same projected drop.
	var sword = game.player.combo
	sword.charged_swing = false
	sword.stage = 2
	for direction in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
		sword.swing_direction = direction
		var matches := true
		for i in range(11):
			matches = matches and sword.blade_segment(i / 10.0)[1] == sword.display_segment(i / 10.0)[1]
		check(matches, "overhead display/collision " + str(direction))
	game._end_hitstop()
	check(is_equal_approx(Engine.time_scale, 1.0), "hitstop restores speed")
	print("FINISHER_RESULT checks=", checks, " failures=", failures)
	game.free()
	await tick()
	quit(1 if failures else 0)

func combo_timing():
	await fresh(0, Vector2.RIGHT, 100.0)
	var p = game.player
	var pressed := false
	var next_click := frame
	var starts := []
	var third_active := -1.0
	var count := 0
	for i in range(100):
		if pressed:
			click(false, Vector2(900,420))
			pressed = false
			next_click = frame + 10
		elif frame >= next_click and p.combo.attack_count < 3:
			click(true, Vector2(900,420))
			pressed = true
		await tick()
		if count != p.combo.attack_count:
			count = p.combo.attack_count
			starts.append(clock_time)
		if p.combo.stage == 2 and p.combo.phase() == "active" and third_active < 0.0:
			third_active = clock_time
		if count == 3 and p.combo.swing_time <= 0.0: break
	check(starts.size() == 3 and third_active > 0.0, "three normal buffered clicks")
	check(not game.hitstop_active, "third whiff never hitstops")
	for i in range(3):
		var data: Dictionary = p.combo.stages[i]
		check(Vector3(data.windup,data.active,data.recovery).is_equal_approx(CONFIG.SWORD_TIMINGS[i]), "configured full timing stage " + str(i+1))
	print("TIMING starts=",starts," third_active_from_first=", third_active-starts[0], " completion_from_first=",clock_time-starts[0])

func front_block():
	var es = await fresh(1, Vector2.RIGHT, 100.0)
	var target = es[0]
	target.v41_guard_elite = true
	var p = game.player
	click(true, target.position)
	await tick()
	click(false, target.position)
	for i in range(30):
		await tick()
		if target.health < target.max_health: break
	check(is_equal_approx(target.max_health - target.health, 8.0), "normal first front guard 32 x 25%")
	check(target.last_hit_blocked and target.guard_visual_time > CONFIG.GUARD_HOLD, "blue arc display extended without AI wait")
	check(not game.feedback.guard_effects.is_empty(), "block sparks emitted")
	var caption := false
	for popup in game.feedback.popups:
		if popup.label.text == "-8" and popup.label.get_theme_font_size("font_size") == 21 and popup.label.get_theme_color("font_color") == Color("f6ecd4") and popup.label.scale == Vector2.ONE:
			caption = true
	check(caption, "blocked hit uses the plain default damage number")
	check(game.feedback.guard_sound.data.size() > 0, "block sound samples present")
	check(not game.hitstop_active, "first hit has no finisher hitstop")
	await snapshot("guard")

func counter(count: int, direction: Vector2):
	var es = await fresh(count, direction, 55.0)
	var target = es[0]
	var p = game.player
	var mark := {"end": -1.0, "first": -1.0, "third": -1.0, "next_damage_due": -1.0, "next_actual": -1.0, "recovered": -1.0, "third_distance": -1.0, "push": -1.0}
	var hits := []
	var damage_taken := []
	var start := clock_time
	target.damaged.connect(func(_point, amount):
		hits.append([snappedf(clock_time - start, 0.001), p.combo.stage + 1, amount, target.last_hit_blocked])
		if p.combo.stage == 2:
			mark.third = clock_time
			mark.third_distance = p.position.distance_to(target.position)
	)
	p.damage_received.connect(func(amount): damage_taken.append([snappedf(clock_time - start, 0.001), amount]))
	var state := 0
	var previous_lunge := 0.0
	var pressed := false
	var next_click := 0
	var saw_next := false
	for i in range(350):
		await tick()
		if not is_instance_valid(target) or p.dead: break
		if previous_lunge > 0.0 and target.lunge_time <= 0.0 and target.v41_heavy_stun <= 0.0:
			if mark.end < 0.0: mark.end = clock_time
			elif mark.next_actual < 0.0: mark.next_actual = clock_time
		previous_lunge = target.lunge_time
		if mark.end > 0.0 and target.windup > 0.0 and not saw_next:
			saw_next = true
			mark.next_damage_due = clock_time + target.windup + target.ENCOUNTER_LUNGE_TIME
		if mark.third > 0.0:
			if mark.push < 0.0:
				mark.push = target.knockback.length()
				check(not target.last_hit_blocked and target.v41_heavy_stun > 0.60, "third full break count=%d dir=%s" % [count,direction])
				check(is_equal_approx(hits[-1][2], 60.0), "third damage remains 60")
				check(game.hitstop_active, "third actual hit starts hitstop")
				await snapshot("third_break")
			if mark.recovered < 0.0 and p.combo.swing_time <= 0.0: mark.recovered = clock_time
			if clock_time - mark.third > 1.1: break
		if state == 0 and target.windup > 0.0:
			move_to(direction.orthogonal())
			dash(direction.orthogonal())
			state = 1
		elif state == 1 and p.dash_state == p.Dash.IDLE:
			release_move()
			state = 2
		elif state == 2 and mark.end > 0.0:
			state = 3
		elif state == 3:
			var offset: Vector2 = target.position - p.position
			if offset.length() > 55.0: move_to(offset)
			else:
				release_move()
				mark.first = clock_time
				click(true, target.position)
				pressed = true
				state = 4
		elif state == 4:
			# Pursue during the legal sword movement, never teleport or stall AI.
			if p.position.distance_to(target.position) > 55.0: move_to(target.position - p.position)
			else: release_move()
			if pressed:
				click(false, target.position)
				pressed = false
				next_click = frame + 10
			elif frame >= next_click and p.combo.attack_count < 4:
				click(true, target.position)
				pressed = true
		if state == 4 and mark.third < 0 and p.combo.attack_count >= 4 and p.combo.swing_time <= 0: break
	release_move()
	if pressed: click(false, p.position)
	print("COUNTER count=",count," dir=",direction," end=",snappedf(mark.end-start,0.001)," first=",snappedf(mark.first-start,0.001)," hits=",hits," third_minus_actual=",snappedf(mark.third-mark.next_actual,0.001) if mark.third>0 and mark.next_actual>0 else "not observed", " marks=",mark," player_damage=",damage_taken)

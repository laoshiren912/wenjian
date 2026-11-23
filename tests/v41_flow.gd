extends SceneTree

# Real F5 scene, spawned enemies and GUI events. AI stays live.
# Invulnerability and direct damage in flow fixtures isolate individual rules.
const CONFIG = preload("res://scripts/v41_config.gd")
const POOL = preload("res://scripts/v41_card_pool.gd")
const CARDS = POOL.Card
const OUT := "res://artifacts/v41_review_2026-11-05/"
var game
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS: " if ok else "FAIL: ") + label)

func frames(count: int = 2) -> void:
	for i in range(count):
		await physics_frame
	await process_frame

func enemies() -> Array:
	return get_nodes_in_group("enemies").filter(func(e): return not e.dead and not e.is_queued_for_deletion())

func reset() -> void:
	Input.action_release("attack")
	Input.action_release("ranged_attack")
	game.start_room()
	game.player.gm_invulnerable = true

func click_mouse(down: bool, point := Vector2(670, 390), right := false) -> void:
	var action := "ranged_attack" if right else "attack"
	if down:
		Input.action_press(action)
	else:
		Input.action_release(action)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT if right else MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = point
	event.global_position = point
	root.push_input(event, true)

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)

func wait_clear_celebration(limit: int = 160) -> void:
	var n := 0
	while game.phase == "clear_celebration" and n < limit:
		await frames(1)
		n += 1

func clear_wave() -> void:
	for enemy in enemies():
		enemy.take_damage(10000.0, enemy.global_position - game.player.global_position)
	await frames()
	if game.phase == "wave_transition":
		check(enemies().is_empty(), "wave transition pauses with summoning telegraph before spawning next wave")
		var wn := 0
		while game.phase == "wave_transition" and wn < 80:
			await frames(1)
			wn += 1
	if game.phase == "clear_celebration":
		check(not paused and game.world.room_cleared, "clear celebration keeps world running for death animation")
		await wait_clear_celebration(160)

func clear_room() -> void:
	while game.phase == "combat":
		await clear_wave()

func reward(index: int) -> void:
	check(game.phase == "reward_select" and paused, "stepping into exit portal opens reward selection")
	# Seed-independent deterministic choice fixture after verifying actual draw.
	check(game.reward_options.size() == 3 and game.reward_options[0] != game.reward_options[1] and game.reward_options[1] != game.reward_options[2] and game.reward_options[0] != game.reward_options[2], "three random options are distinct")
	check(game.reward_options.all(func(card): return POOL.eligible(card, game.reward_counts, game.reward_rank())), "all offered cards are unlocked by rank")
	if index not in game.reward_options:
		game.reward_options[0] = index
	game.hud.show_rewards()
	game.select_reward(index)
	await frames()

func advance() -> void:
	game.player.position = game.world.exit_point
	await frames()

func target_at(point: Vector2) -> SurvivorEnemy:
	# Reposition a real room-spawned enemy, never substitute a mock enemy class.
	var enemy: SurvivorEnemy = enemies()[0]
	enemy.position = point
	enemy.health = 1000.0
	enemy.max_health = 1000.0
	enemy.guard_time = 0.0
	enemy.guard_cooldown = 10.0
	enemy.windup = 0.0
	enemy.lunge_time = 0.0
	enemy.knockback = Vector2.ZERO
	return enemy

func tick_sword(count: int) -> void:
	for i in range(count):
		game.player.weapon._physics_process(0.01)

func check_melee_cue_and_facing() -> void:
	for flank in [false, true]:
		reset()
		var player: CharacterBody2D = game.player
		player.gm_invulnerable = false
		player.position = Vector2(580, 420)
		var actors := enemies()
		var enemy: SurvivorEnemy = actors[0]
		enemy.position = Vector2(635, 420)
		for i in range(1, actors.size()):
			actors[i].position = Vector2(1000, 350 + i * 55)
		await frames(2)
		var facing := enemy.attack_direction
		check(enemy.windup > 0.5 and facing.dot(Vector2.LEFT) > 0.99 and player.health == 100.0, "live melee raises warning before dealing damage")
		if flank:
			# Place the player behind the telegraph while it is still tracking on the old build.
			player.position = enemy.position - facing * 50.0
		var held_facing := true
		var before := enemy.health
		var sword_started := false
		var stayed_safe := true
		while enemy.windup > 0.0:
			held_facing = held_facing and enemy.attack_direction.is_equal_approx(facing) and enemy.visual.facing == Vector2.LEFT
			stayed_safe = stayed_safe and player.health == 100.0
			if flank and not sword_started and enemy.windup <= 0.08:
				var aim := root.get_canvas_transform() * enemy.global_position
				click_mouse(true, aim)
				click_mouse(false, aim)
				sword_started = true
			await frames(1)
		check(stayed_safe and player.health == 100.0 and enemy.lunge_time > 0.0, "warning completes before melee contact begins")
		if flank:
			var hit_during_swing := false
			check(enemy.health == before, "rear sword is still winding up when enemy starts its swing")
			while enemy.lunge_time > 0.0:
				held_facing = held_facing and enemy.attack_direction.is_equal_approx(facing) and enemy.visual.facing == Vector2.LEFT
				await frames(1)
				hit_during_swing = hit_during_swing or (enemy.lunge_time > 0.0 and is_equal_approx(before - enemy.health, 32.0))
			check(hit_during_swing and not enemy.last_hit_blocked, "real sword from behind the swing deals full 32 damage")
		else:
			await frames(12)
		check(held_facing, "melee keeps its original facing through warning and swing")
		var expected_hp: float = 100.0 if flank else 100.0 - float(CONFIG.ENEMY_STATS[CONFIG.MELEE].damage)
		check(is_equal_approx(player.health, expected_hp), "live swing misses the rear and hits the front for %.0f" % float(CONFIG.ENEMY_STATS[CONFIG.MELEE].damage))
		if flank:
			check(enemy.visual.facing == Vector2.LEFT and enemy.guard_direction.dot(Vector2.LEFT) > 0.99, "short recovery keeps the original guard and body facing")
			await frames(15)
			check(enemy.visual.facing == Vector2.RIGHT and enemy.guard_direction.dot(Vector2.RIGHT) > 0.9, "enemy turns again after the recovery facing window")

func wait_boss_state(enemy: SurvivorEnemy, state: int, limit: int = 180) -> bool:
	for i in range(limit):
		if enemy.boss_state == state:
			return true
		await frames(1)
	return false

func check_final_boss() -> void:
	var boss: SurvivorEnemy = game.boss
	check(CONFIG.WAVES.size() == 6 and game.room_index == 6 and enemies() == [boss] and game.remaining == 1 and game.run_kills == CONFIG.run_total() - 1, "six rooms lead to one live boss with no adds")
	check(not game.world.portal_open and not game.world.reward_visible and game.reward_counts == [1, 1, 0, 1, 0, 1, 0, 1, 1, 0], "six mastered cards carry into a closed boss arena")
	if not is_instance_valid(boss):
		return
	var player: SurvivorPlayer = game.player
	player.health = 100.0
	player.position = boss.position + Vector2.LEFT * 75.0
	check(await wait_boss_state(boss, boss.BossState.COMBO_WINDUP), "boss approaches and starts the orange sweep warning")
	await frames(25)
	check(boss.boss_state == boss.BossState.COMBO_WINDUP and player.health == 100.0, "boss sweep windup deals no damage")
	var after_sweep_hp: float = 100.0 - boss.SWEEP_DAMAGE
	check(await wait_boss_state(boss, boss.BossState.RECOVERY) and is_equal_approx(player.health, after_sweep_hp), "remaining in the sweep takes real damage after the warning")
	check(await wait_boss_state(boss, boss.BossState.CHARGE_WINDUP), "boss alternates to its short charge warning")
	var facing := boss.boss_charge_aim
	player.position = boss.position + facing.orthogonal() * 78.0
	await frames(20)
	check(boss.boss_state == boss.BossState.CHARGE_WINDUP and boss.boss_charge_aim.is_equal_approx(facing) and is_equal_approx(player.health, after_sweep_hp), "charge warning is harmless and stays locked after a sidestep")
	check(await wait_boss_state(boss, boss.BossState.CHARGING), "charge begins after its warning")
	check(await wait_boss_state(boss, boss.BossState.RECOVERY) and is_equal_approx(player.health, after_sweep_hp) and boss.boss_charge_aim.is_equal_approx(facing), "sidestep avoids the real locked charge")
	player.position = boss.position - facing * 55.0
	boss.health = 30.0
	await frames(2)
	var aim := root.get_canvas_transform() * boss.global_position
	click_mouse(true, aim)
	click_mouse(false, aim)
	await frames(22)
	check(game.phase == "clear_celebration" and not paused, "boss defeat enters clear celebration before victory modal")
	await wait_clear_celebration(170)
	check(game.phase == "victory" and paused and game.hud.overlay.visible and game.run_kills == CONFIG.run_total() and not game.world.reward_visible, "real sword finishes boss and opens victory settlement")
	check(game.hud.modal_panel.find_children("*", "Label", true, false).any(func(label):
		return label.text.begins_with("已习得功法") and "万剑归宗·极" in label.text and "青莲剑气" in label.text),
		"victory shows the learned cards alongside the kill total")
	key(KEY_ENTER)
	check(game.room_index == 0 and game.reward_counts == [0, 0, 0, 0, 0, 0, 0, 0, 0, 0] and game.player.health == 100.0 and not paused and game.phase == "combat" and game.player.cultivation == 0, "Enter after boss win restarts a fresh run")
	game.room_index = CONFIG.BOSS_ROOM
	game.reward_counts[0] = 2
	game._enter_room()
	boss = game.boss
	player = game.player
	player.health = 18.0
	player.position = boss.position + Vector2.LEFT * 70.0
	check(await wait_boss_state(boss, boss.BossState.COMBO_WINDUP), "boss starts its attack on a fresh entry")
	await frames(82)
	check(game.phase == "dead" and paused and game.hud.overlay.visible, "lethal boss attack opens death result")
	key(KEY_R)
	check(game.room_index == 0 and game.reward_counts == [0, 0, 0, 0, 0, 0, 0, 0, 0, 0] and game.player.health == 100.0 and not paused and game.phase == "combat" and game.player.cultivation == 0, "R after boss death clears rewards and returns to room one")

func check_dash_links() -> void:
	for target_stage in range(3):
		reset()
		var player: SurvivorPlayer = game.player
		var sword = player.combo
		for stage_index in range(target_stage + 1):
			click_mouse(true)
			click_mouse(false)
			await frames(2)
			for tick in range(60):
				if sword.phase() == "recovery":
					break
				await frames(1)
			if stage_index < target_stage:
				while sword.swing_time > 0.0:
					await frames(1)
		check(sword.stage == target_stage and sword.phase() == "recovery", "real input reaches recovery stage " + str(target_stage))
		var attacks: int = sword.attack_count
		key(KEY_SPACE)
		await frames(2)
		check(not player.is_rolling() and game.player.dash_state == game.player.Dash.WINDUP, "Space cancels recovery immediately after stage " + str(target_stage))
		for tick in range(60):
			if game.player.dash_state == game.player.Dash.RECOVERY and game.player.dash_time <= 0.10:
				break
			await frames(1)
		check(game.player.dash_state == game.player.Dash.RECOVERY and sword.swing_time == 0.0, "dash starts after sword recovery")
		click_mouse(true)
		click_mouse(false)
		await frames(9)
		var expected_stage := (target_stage + 1) % 3
		check(sword.attack_count == attacks + 1 and sword.stage == expected_stage, "late dash recovery continues preserved sword chain")
		check(game.player.dash_cooldown > 0.0 and not player.is_rolling(), "dash has one cooldown and no roll state")
	reset()
	game.room_index = 1
	game._enter_room()
	game.player.gm_invulnerable = true
	game.player.position = Vector2(620, 420)
	var cap_ok := true
	var pair_seen := false
	for tick in range(420):
		await frames(1)
		var busy := enemies().filter(func(e): return e.windup > 0.0 or e.lunge_time > 0.0)
		cap_ok = cap_ok and busy.size() <= 2
		pair_seen = pair_seen or busy.filter(func(e): return e.kind == e.Kind.HOSTILE).size() == 2
	check(cap_ok and pair_seen, "room two keeps a real melee pair and at most two simultaneous threats")


func snapshot(label: String) -> void:
	await frames(4)
	var bounds := Rect2(Vector2.ZERO, game.hud.root.size).grow(1)
	for panel in game.hud.combat_panels:
		check(bounds.encloses(panel.get_global_rect()), label + " HUD fits")
	if game.hud.overlay.visible:
		check(bounds.encloses(game.hud.modal_panel.get_global_rect()), label + " modal fits")
		for item in game.hud.modal_panel.find_children("*", "Control", true, false):
			if item.is_visible_in_tree():
				check(bounds.encloses(item.get_global_rect()), label + " text/button fits")
	if OS.get_cmdline_user_args().has("--visual"):
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(OUT + label + ".png") == OK, label + " screenshot saved")

func run() -> void:
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/main_v41.tscn", "F5 uses integrated V4.1")
	game = load("res://scenes/main_v41.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frames()
	reset()
	check(game.total == 4 and enemies().size() == 4 and game.scheduler.groups.size() == 2, "room1: four spawned melee, two real pairs")
	check(game.world.backdrop.texture != null and game.world.lanterns.is_empty(), "courtyard texture available without legacy lanterns")
	check(game.player.combo.get_script() == load("res://scripts/v41_sword.gd") and game.player.combo.has_method("motion_pose"), "F5 uses orbit sword with rewards")
	var draws := {}
	var offered := {}
	for seed_value in range(16):
		game.reward_rng.seed = seed_value
		game._draw_rewards()
		draws[str(game.reward_options)] = true
		for index in game.reward_options: offered[index] = true
	check(draws.size() > 1 and draws.keys().all(func(draw):
		var cards: Array = JSON.parse_string(draw).map(func(value): return int(value))
		return cards.size() == 3 and cards.all(func(card): return POOL.tier(card) == 0)) and offered.size() == 3, "first-room draws offer exactly the three basic cards")
	for point in CONFIG.SPAWN_POINTS + [CONFIG.ROOM1_SPAWN, CONFIG.REWARD_POINT, game.world.exit_point]:
		check(Geometry2D.is_point_in_polygon(point, game.world.walkable) and not game.world.path_between(CONFIG.ROOM1_SPAWN, point).is_empty(), "configured point reachable: " + str(point))
	for e in enemies():
		check(e.encounter_id == 0 and e.max_simultaneous_attackers == 3 and e.health == CONFIG.ENEMY_STATS[CONFIG.MELEE].health and e.damage == CONFIG.ENEMY_STATS[CONFIG.MELEE].damage, "spawn enables encounter mechanics and configured stats")
	# Actual spawned defender: let real physics update its direction, then inspect hit.
	var defender: SurvivorEnemy = enemies()[0]
	defender.v41_guard_elite = true
	game.player.set_physics_process(false)
	game.player.position = Vector2(570, 400)
	defender.position = Vector2(660, 400)
	defender.guard_cooldown = 0.0
	await frames(1)
	var hp := defender.health
	defender.take_damage(100.0, Vector2.RIGHT * 100.0)
	check(is_equal_approx(hp - defender.health, 25.0) and defender.guard_time > 0.0 and defender.guard_direction.x < -0.9, "REAL F5 defender: front 25 percent and active blue-arc state")
	hp = defender.health
	defender.take_damage(30.0, Vector2.LEFT * 100.0)
	check(is_equal_approx(hp - defender.health, 30.0), "REAL F5 defender: back full damage")
	await snapshot("guard")
	reset()
	# Pair scheduler with real AI running: track starts, recovery and alternation.
	game.player.set_physics_process(false)
	game.player.position = Vector2(620, 420)
	for i in range(enemies().size()):
		var e = enemies()[i]
		e.position = game.player.position + Vector2.RIGHT.rotated(i * TAU / 4.0) * 55.0
		e.home_position = e.position
	var violation := false
	var waiting_moved := false
	var starts := 0
	var simultaneous_pair := false
	var first_start := -1
	var second_start := -1
	var last_first_pair_busy := -1
	var first_handoff_frame := -1
	var previous: Dictionary = {}
	for i in range(480):
		await frames(1)
		if game.scheduler.history.size() == 2 and first_handoff_frame < 0:
			first_handoff_frame = i
		var active_groups := {}
		var active_count := 0
		for g in range(game.scheduler.groups.size()):
			for e in game.scheduler.groups[g]:
				if not game.scheduler.alive(e): continue
				var busy: bool = e.windup > 0.0 or e.lunge_time > 0.0
				if busy:
					active_groups[g] = true
					active_count += 1
				if busy and g == 0 and game.scheduler.history.size() == 1:
					last_first_pair_busy = i
				if busy and not previous.get(e.get_instance_id(), false):
					starts += 1
					if starts == 1: first_start = i
					if starts == 2: second_start = i
				previous[e.get_instance_id()] = busy
				if not game.scheduler.owns_turn(e) and e.get_real_velocity().length() > 1.0: waiting_moved = true
		simultaneous_pair = simultaneous_pair or active_count == 2
		violation = violation or active_groups.size() > 1 or active_count > CONFIG.PAIR_SIZE
	check(not violation and starts >= 4 and simultaneous_pair, "real physics: only selected pair attacks, multiple attack rounds occur")
	check(game.scheduler.history.size() >= 3 and game.scheduler.history[0] == 0 and game.scheduler.history[1] == 1 and game.scheduler.history[2] == 0, "real physics: pair 0 -> pair 1 -> pair 0, not a mere cap")
	check(first_start >= 0 and second_start - first_start <= 1 and first_handoff_frame > last_first_pair_busy and first_handoff_frame - last_first_pair_busy <= 40, "live pair starts promptly and hands off after ordinary recovery without added waiting")
	check(waiting_moved, "real physics: non-active pair moves aside")
	# Adjustable queue and failure paths use the same actual spawned actors.
	game.scheduler.configure(enemies(), 1, 0.2)
	check(game.scheduler.groups.size() == 4 and game.scheduler.can_start(enemies()[0]) and not game.scheduler.can_start(enemies()[1]), "configurable pair size changes permission, not just number cap")
	game.scheduler.tick(0.21)
	check(game.scheduler.current == 1, "unreachable/unstarted turn times out instead of stalling queue")
	var previous_turn: int = game.scheduler.current
	var owner = game.scheduler.groups[previous_turn][0]
	owner.windup = 0.0
	owner.lunge_time = 0.0
	owner.attack_cooldown = 0.0
	game.scheduler.attack_started(owner)
	game.scheduler.tick(0.0)
	check(game.scheduler.current == previous_turn + 1, "finished recovery hands off immediately without artificial delay")
	owner = game.scheduler.groups[game.scheduler.current][0]
	owner.take_damage(10000.0, Vector2.ZERO)
	game.scheduler.tick(0.0)
	check(game.scheduler.current == 3, "dead active member immediately releases turn")
	# Room/wave totals, final-wave reward gate, stats and actual ranged retreat.
	reset()
	game.player.set_physics_process(false)
	await clear_room()
	check(game.phase == "exit_ready" and not paused and game.world.portal_open, "full room clear opens exit portal without forced modal")
	game.player.health = 63.0
	game.player.stamina = 47.0
	await advance()
	await reward(0)
	game.player.set_physics_process(false)
	check(game.room_index == 1 and game.total == 6 and game.remaining == 6 and enemies().size() == 3, "room2 starts only wave1 of six total")
	check(game.world.exit_point == CONFIG.ROOM_EXIT_POINTS[1] and not game.world.path_between(CONFIG.ROOM_ENTRY_POINTS[1], game.world.exit_point).is_empty(), "room2 small-room exit is reachable")
	check(not Geometry2D.is_point_in_polygon(Vector2(600, 600), game.world.walkable) and Geometry2D.is_point_in_polygon(Vector2(300, 480), game.world.walkable) and Geometry2D.is_point_in_polygon(Vector2(950, 480), game.world.walkable), "room2 compact bounds contain both sides without L-shaped exclusion")
	for point in CONFIG.ROOM2_SPAWN_POINTS:
		check(Geometry2D.is_point_in_polygon(point, game.world.walkable) and not game.world.path_between(CONFIG.ROOM_ENTRY_POINTS[1], point).is_empty(), "room2 spawn reachable: " + str(point))
	check(game.player.health == 63.0 and game.player.stamina >= 47.0 and game.player.stamina < 50.0 and game.reward_counts[0] == 1, "vitals preserved; only normal stamina regeneration after entry")
	var ranger: SurvivorEnemy
	for e in enemies():
		check(is_equal_approx(e.health, float(CONFIG.ENEMY_STATS[CONFIG.RANGED if e.kind == e.Kind.RANGED else (CONFIG.THRUST if e.thrust_type else CONFIG.MELEE)].health) * 1.2) and is_equal_approx(e.damage, float(CONFIG.ENEMY_STATS[CONFIG.RANGED if e.kind == e.Kind.RANGED else CONFIG.MELEE].damage) * 1.2), "room2 scales both health and damage")
		if e.kind == e.Kind.RANGED: ranger = e
	ranger.position = Vector2(470, 385)
	game.player.position = Vector2(370, 385)
	ranger.windup = 0.0
	ranger.attack_cooldown = 0.45
	var before: float = ranger.position.distance_to(game.player.position)
	await frames(6)
	check(ranger.position.distance_to(game.player.position) > before + 3.0 and ranger.velocity.x > 0, "REAL F5 spawned ranger physically retreats at close range")
	await snapshot("ranged_retreat")
	var fired := false
	for i in range(100):
		await frames(1)
		if ranger.windup <= 0.0 and ranger.attack_cooldown > 1.0:
			fired = true
			break
	check(fired and ranger.position.distance_to(game.player.position) < CONFIG.RANGED_REACH, "retreating ranger can fire while player stays close")
	await clear_wave()
	check(game.wave_index == 1 and enemies().size() == 3 and game.remaining == 3 and not game.world.reward_visible, "second wave only after first clear, no early reward")
	await clear_wave()
	await advance()
	await reward(1)
	game.player.set_physics_process(false)
	var room3_total := CONFIG.room_total(2)
	check(game.total == room3_total and enemies().size() == CONFIG.WAVES[2][0].size() and game.remaining == room3_total, "room3 starts first wave of room total")
	await clear_wave()
	var thrusts := 0
	for e in enemies():
		if e.thrust_type and e.fast_chaser: thrusts += 1
		check(is_equal_approx(e.health, float(CONFIG.ENEMY_STATS[CONFIG.RANGED if e.kind == e.Kind.RANGED else (CONFIG.THRUST if e.thrust_type else CONFIG.MELEE)].health) * 1.4), "room3 health scale")
	check(thrusts == 1 and game.scheduler.groups.size() == 2 and game.scheduler.groups[0].size() == 2 and enemies().any(func(e): return e.v41_guard_elite), "third room second wave includes thrust, guard elite and two scheduled groups")
	await clear_room()
	await advance()
	await reward(CARDS.SPLIT)
	for room in range(3, 6):
		check(game.room_index == room and game.total == CONFIG.room_total(room) and game.phase == "combat", "enters ordinary room %d in sequence" % (room + 1))
		await clear_room()
		check(game.phase == "exit_ready" and not paused and game.world.portal_open, "room %d clear opens exit portal" % (room + 1))
		await advance()
		check(game.phase == "reward_select" and paused, "room %d portal triggers reward modal" % (room + 1))
		await reward([CARDS.CRITICAL, CARDS.RAIN, CARDS.FAN][room - 3])
	await check_final_boss()
	# Mixed real AI cannot exceed the configurable overall attack budget.
	game.room_index = 2
	game._enter_room()
	game.player.gm_invulnerable = true
	game.player.set_physics_process(false)
	game.player.position = Vector2(610, 420)
	var cap_violation := false
	var ranged_started := false
	for i in range(240):
		await frames(1)
		var active := 0
		var ranged_active := 0
		for e in enemies():
			if e.windup > 0.0 or e.lunge_time > 0.0:
				active += 1
				if e.kind == e.Kind.RANGED:
					ranged_started = true
					ranged_active += 1
		cap_violation = cap_violation or active > CONFIG.ATTACK_LIMIT or ranged_active > 1
	check(not cap_violation and ranged_started, "real mixed melee/ranged wave respects two melee slots and one ranged slot")
	await check_dash_links()
	await check_melee_cue_and_facing()
	# Input boundaries use real GUI-dispatched press/release and 60Hz physics.
	reset()
	var sword = game.player.combo
	click_mouse(true)
	await frames(6)
	check(sword.attack_count == 1 and sword.stage == 0, "press begins the first sword attack")
	click_mouse(false)
	await frames(2)
	check(sword.attack_count == 1 and sword.stage == 0 and not sword.charged_swing, "release does not start another attack")
	await frames(3)
	click_mouse(true)
	click_mouse(false)
	await frames(26)
	check(sword.attack_count == 2 and sword.stage == 1, "tap buffers second stage")
	click_mouse(true)
	click_mouse(false)
	await frames(28)
	check(sword.attack_count == 3 and sword.stage == 2, "tap buffers third stage")
	reset()
	game.reward_counts[CARDS.CRITICAL] = 1
	game._apply_rewards()
	sword = game.player.combo
	key(KEY_SPACE)
	await frames(31)
	check(sword.dash_armed, "successful dash arms the next attack")
	click_mouse(true)
	click_mouse(false)
	await frames(2)
	check(sword.swing_bonus == 2.0 and not sword.dash_armed, "ordinary attack consumes dash reward even on miss")
	await frames(24)
	click_mouse(true)
	click_mouse(false)
	await frames(2)
	check(sword.swing_bonus == 1.0, "dash multiplier is not reused for second ordinary attack")
	# Actual contact tests use the current F5's spawned enemy and orbit blade.
	reset()
	game.player.set_physics_process(false)
	game.player.combo.set_physics_process(false)
	game.player.position = Vector2(580, 420)
	game.reward_counts[CARDS.CRITICAL] = 1
	game._apply_rewards()
	sword = game.player.combo
	var target := target_at(game.player.position + Vector2(65, 0))
	check(is_equal_approx(sword.stages[0].damage, 32.0), "cards preserve base sword damage")
	game.player.request_dash(Vector2.UP)
	game.player._start_dash()
	game.player.clear_dash_effects()
	check(sword.dash_armed, "dash arms one empowered sword")
	sword.attack(Vector2.RIGHT)
	check(not sword.dash_armed and sword.swing_bonus == 2.0, "attack consumes roll bonus once")
	tick_sword(40)
	check(is_equal_approx(1000.0 - target.health, 64.0), "critical light hit is twice base sword damage")
	# Base third hit opens guard; 血/踏雪 reward the actual guard break.
	for mode in ["base", "reward"]:
		reset()
		game.player.set_physics_process(false)
		game.player.combo.set_physics_process(false)
		game.player.position = Vector2(580, 420)
		game.reward_counts[CARDS.BLOOD] = int(mode != "base")
		game.reward_counts[CARDS.REFRESH] = int(mode != "base")
		game._apply_rewards()
		game.player.dash_cooldown = 1.2
		game.player.stamina = 70.0
		sword = game.player.combo
		target = target_at(game.player.position + Vector2(65, 0))
		target.guard_cooldown = 0.0
		target.guard_direction = Vector2.LEFT
		target.guard_time = CONFIG.GUARD_HOLD
		target.encounter_state = target.EncounterState.CHASE
		sword.next_stage = 2
		sword.chain_time = 0.2
		sword.attack(Vector2.RIGHT)
		tick_sword(40)
		check(is_equal_approx(1000.0 - target.health, 60.0), "guard interaction on front contact: " + mode)
		check(is_equal_approx(target.guard_cooldown, CONFIG.HEAVY_BASE_BREAK), "guard window: " + mode)
		check(is_equal_approx(target.v41_heavy_stun, CONFIG.BREAK_STUN), "third stun: " + mode)
		check(target.guard_time == 0.0 and target.guard_visual_time == 0.0, "third break clears guard and blue arc: " + mode)
		if mode != "base":
			check(is_equal_approx(target.knockback.length(), CONFIG.THIRD_MOB_PUSH) and game.player.dash_cooldown == 0.0 and game.player.stamina == 80.0, "real guard break restores dash and 10 stamina")
	reset()
	game.reward_counts[2] = 2
	game.player.health = 91.0
	var killed = enemies()[0]
	killed.take_damage(10000.0, Vector2.ZERO)
	check(game.player.health == 100.0, "stacked kill heal capped at max health")
	game.player.gm_invulnerable = false
	game.player.invulnerability = 0.0
	game.player.take_damage(10000.0, Vector2.ZERO)
	check(game.phase == "defeat_transition" and not paused, "real damage begins the defeat fade")
	await frames(35)
	check(game.phase == "dead" and paused, "defeat fade opens death result")
	key(KEY_R)
	check(game.reward_counts == [0, 0, 0, 0, 0, 0, 0, 0, 0, 0] and game.player.health == 100.0 and not paused and game.phase == "combat" and game.player.cultivation == 0, "death R resets run and rewards")
	await clear_room()
	game.player.combo.dash_armed = true
	click_mouse(true, Vector2(670, 390), true)
	await frames(8)
	# Step into exit portal while thrown sword is airborne, then pick reward to transition directly.
	await advance()
	click_mouse(false, Vector2(670, 390), true)
	game.reward_options.assign([0, 1, 2])
	game.reward_counts[1] = 2
	game.hud.show_rewards()
	await frames()
	var chosen: Button
	var disabled: Button
	for item in game.hud.modal_panel.find_children("*", "Button", true, false):
		if item.accessibility_name.begins_with("青莲剑气"): chosen = item
		if item.accessibility_name.begins_with("雷霆残影"): disabled = item
	check(disabled != null and disabled.disabled, "maxed-out reward is visibly disabled in injected offer")
	game.select_reward(1)
	check(game.phase == "reward_select", "disabled unique reward cannot be selected through code")
	var point := chosen.get_global_rect().get_center()
	click_mouse(true, point)
	await frames(1)
	click_mouse(false, point)
	await frames(3)
	check(game.room_index == 1 and game.phase == "combat" and game.reward_counts[0] == 1 and game.reward_counts[1] == 2 and not game.player.combo.dash_armed and game.player.throw_cooldown == 0.0 and not is_instance_valid(game.player.thrown_sword) and game.player.combo.attack_count == 0, "real reward button applies once and directly enters next room cleanly")
	# All original imported samples must load with their existing player.
	for path in ["courtyard_trial", "sword_motion_trial", "sword_motion_combat"]:
		var sample = load("res://scenes/" + path + ".tscn").instantiate()
		root.add_child(sample)
		await frames()
		check(sample.player.combo.has_method("press_primary"), "imported sample runs: " + path)
		sample.free()
	# Stable screenshots / viewport bounds at both sizes.
	for size in [Vector2i(960, 540), Vector2i(1280, 720)]:
		root.size = size
		root.content_scale_size = size
		reset()
		await snapshot("%d_courtyard" % size.x)
		game.toggle_view()
		await snapshot("%d_close" % size.x)
		game.toggle_view()
		click_mouse(true, Vector2(670, 390), true)
		await frames(55)
		await snapshot("%d_combat" % size.x)
		game.toggle_pause()
		await snapshot("%d_pause" % size.x)
		check(game.player.dash_request.is_zero_approx(), "pause clears dash buffer")
		game.resume_room()
		click_mouse(false, Vector2(670, 390), true)
		game.toggle_stats()
		await snapshot("%d_stats" % size.x)
		game.resume_room()
		await clear_room()
		await advance()
		await snapshot("%d_rewards" % size.x)
		game.select_reward(game.reward_options.filter(game.can_select_reward)[0])
		await frames()
	paused = false
	game.queue_free()
	await process_frame
	print("V41 FLOW: %d checks, %d failures; real-scene controlled tests, not human play" % [checks, failures])
	quit(1 if failures else 0)

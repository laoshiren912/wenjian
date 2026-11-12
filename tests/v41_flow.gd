extends SceneTree

# Real F5 scene, spawned enemies and GUI events. AI stays live.
# Invulnerability and direct damage in flow fixtures isolate individual rules.
const CONFIG = preload("res://scripts/v41_config.gd")
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

func clear_wave() -> void:
	for enemy in enemies():
		enemy.take_damage(10000.0, enemy.global_position - game.player.global_position)
	await frames()

func clear_room() -> void:
	while game.phase == "combat":
		await clear_wave()

func reward(index: int) -> void:
	game.player.position = CONFIG.ENTRY_POINT
	key(KEY_E)
	check(game.phase == "reward_wait" and not paused, "reward cannot be opened outside the central radius")
	game.player.position = CONFIG.REWARD_POINT
	await frames()
	check(game.phase == "reward_wait" and not paused, "approaching reward waits for E")
	key(KEY_E)
	check(game.phase == "reward_select" and paused, "E at real reward point opens selection")
	# Seed-independent deterministic choice fixture after verifying actual draw.
	check(game.reward_options.size() == 3 and game.reward_options[0] != game.reward_options[1] and game.reward_options[1] != game.reward_options[2] and game.reward_options[0] != game.reward_options[2], "three random options are distinct")
	game.reward_options.assign([index, (index + 1) % 4, (index + 2) % 4])
	game.hud.show_rewards()
	game.select_reward(index)

func advance() -> void:
	game.player.position = CONFIG.EXIT_POINT
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

func check_bow_cycle() -> void:
	reset()
	var player = game.player
	var bow = player.ranged_weapon
	var origin: Vector2 = player.position
	var target := Vector2(670, 390)
	click_mouse(true, target, true)
	await frames(22)
	check(bow.attack_count == 0 and player.bow_windup_remaining > 0.0 and is_equal_approx(player.movement_multiplier(), 0.45), "bow draws for a half second at reduced speed")
	check(player.visual.bow_pull > 0.5 and not player.visual.bow_aim.is_zero_approx(), "bow windup draws the string toward the body")
	await frames(12)
	check(bow.attack_count == 1 and player.bow_recovery_remaining > 0.0, "bow fires once after windup")
	check((player.position - origin).dot(bow.swing_direction) < -1.0 and game.feedback.shake_time == 0.0, "bow shot moves the body backward without shaking the camera")
	check(player.visual.bow_pull == 0.0 and player.visual.bow_release > 0.0, "bow string snaps forward while release pose is visible")
	check(is_equal_approx(player.movement_multiplier(), 0.15), "bow recovery still allows movement")
	click_mouse(false, target, true)
	await frames(24)
	click_mouse(true, target, true)
	await frames(3)
	check(bow.attack_count == 1 and player.bow_windup_remaining == 0.0 and player.bow_recovery_remaining > 0.0, "press near end of recovery cannot queue another shot")
	await frames(75)
	check(bow.attack_count == 1 and player.bow_recovery_remaining == 0.0, "holding through the end of recovery never repeats")
	var retreat: float = -(player.position - origin).dot(bow.swing_direction)
	check(retreat >= 20.0 and retreat <= 27.0, "stationary bow recoil travels about half a body over time")
	check(not bow.projectile_camera_shake, "F5 arrows disable impact camera shake")
	game.feedback.shake_time = 0.0
	enemies()[0].take_damage(21.0, Vector2.ZERO, false, bow.projectile_camera_shake)
	check(game.feedback.shake_time == 0.0, "arrow damage feedback keeps the camera steady")
	click_mouse(false, target, true)
	click_mouse(true, target, true)
	click_mouse(false, target, true)
	await frames(34)
	check(bow.attack_count == 2, "fresh tap after recovery fires even after button release")
	reset()
	click_mouse(true, target, true)
	await frames(5)
	key(KEY_SPACE)
	await frames(2)
	check(game.player.is_rolling() and game.player.bow_windup_remaining == 0.0, "successful roll cancels bow windup")
	click_mouse(false, target, true)
	await frames(35)
	check(game.player.ranged_weapon.attack_count == 0, "cancelled bow never fires after roll")

func check_opening_bow_pressure(retreating: bool) -> void:
	reset()
	var player = game.player
	player.gm_invulnerable = false
	var double_windup := false
	var mouse := Vector2(950, 370)
	if retreating:
		Input.action_press("move_left")
	for i in range(360):
		if player.bow_windup_remaining <= 0.0 and player.bow_recovery_remaining <= 0.0:
			click_mouse(true, mouse, true)
			click_mouse(false, mouse, true)
		await frames(1)
		double_windup = double_windup or enemies().filter(func(e): return e.windup > 0.0).size() == 2
		if player.health < player.max_health:
			break
	if retreating:
		Input.action_release("move_left")
		check(player.position.x < CONFIG.ENTRY_POINT.x - 50.0, "retreating bow fixture moves the player away from the real entry")
	else:
		check(double_windup, "real entry and spawn points bring two melee into overlapping windups")
	check(player.ranged_weapon.attack_count > 0 and player.health < player.max_health, "repeated bow from entry takes real damage, retreating: " + str(retreating))

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
		check(enemy.windup > 0.6 and facing.dot(Vector2.LEFT) > 0.99 and player.health == 100.0, "live melee raises warning before dealing damage")
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
		check(is_equal_approx(player.health, 100.0 if flank else 88.0), "live swing misses the rear and hits the front for 12")
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
	check(CONFIG.WAVES.size() == 6 and game.room_index == 6 and enemies() == [boss] and game.remaining == 1 and game.run_kills == 42, "six rooms lead to one live boss with no adds")
	check(not game.world.portal_open and not game.world.reward_visible and game.reward_counts == [4, 1, 1, 0], "six rewards carry into a closed boss arena")
	if not is_instance_valid(boss):
		return
	var player: SurvivorPlayer = game.player
	player.health = 100.0
	player.position = boss.position + Vector2.LEFT * 75.0
	check(await wait_boss_state(boss, boss.BossState.COMBO_WINDUP), "boss approaches and starts the orange sweep warning")
	await frames(25)
	check(boss.boss_state == boss.BossState.COMBO_WINDUP and player.health == 100.0, "boss sweep windup deals no damage")
	check(await wait_boss_state(boss, boss.BossState.RECOVERY) and player.health == 82.0, "remaining in the sweep takes real damage after the warning")
	check(await wait_boss_state(boss, boss.BossState.CHARGE_WINDUP), "boss alternates to its short charge warning")
	var facing := boss.boss_charge_aim
	player.position = boss.position + facing.orthogonal() * 78.0
	await frames(20)
	check(boss.boss_state == boss.BossState.CHARGE_WINDUP and boss.boss_charge_aim.is_equal_approx(facing) and player.health == 82.0, "charge warning is harmless and stays locked after a sidestep")
	check(await wait_boss_state(boss, boss.BossState.CHARGING), "charge begins after its warning")
	check(await wait_boss_state(boss, boss.BossState.RECOVERY) and player.health == 82.0 and boss.boss_charge_aim.is_equal_approx(facing), "sidestep avoids the real locked charge")
	player.position = boss.position - facing * 55.0
	boss.health = 40.0
	await frames(2)
	var aim := root.get_canvas_transform() * boss.global_position
	click_mouse(true, aim)
	click_mouse(false, aim)
	await frames(22)
	check(game.phase == "cleared" and paused and game.hud.overlay.visible and game.run_kills == CONFIG.run_total() and not game.world.reward_visible, "real sword finishes boss and opens existing victory result")
	key(KEY_ENTER)
	check(game.room_index == 0 and game.reward_counts == [0, 0, 0, 0] and game.player.health == 100.0 and not paused, "Enter after boss win restarts a fresh run")
	game.room_index = CONFIG.BOSS_ROOM
	game.reward_counts[0] = 2
	game._enter_room()
	boss = game.boss
	player = game.player
	player.health = 18.0
	player.position = boss.position + Vector2.LEFT * 70.0
	check(await wait_boss_state(boss, boss.BossState.COMBO_WINDUP), "boss starts its attack on a fresh entry")
	await frames(58)
	check(game.phase == "dead" and paused and game.hud.overlay.visible, "lethal boss attack opens death result")
	key(KEY_R)
	check(game.room_index == 0 and game.reward_counts == [0, 0, 0, 0] and game.player.health == 100.0 and not paused, "R after boss death clears rewards and returns to room one")

func check_roll_links() -> void:
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
		var origin := player.position
		Input.action_press("move_right")
		key(KEY_SPACE)
		await frames(2)
		check(player.is_rolling() and sword.swing_time == 0.0 and player.position.distance_to(origin) > 5.0, "recovery roll cancels and physically moves at stage " + str(target_stage))
		var attacks: int = sword.attack_count
		click_mouse(true)
		click_mouse(false)
		for tick in range(30):
			if not player.is_rolling():
				break
			await frames(1)
		Input.action_release("move_right")
		await frames(2)
		check(sword.attack_count == attacks + 1 and sword.swing_time > 0.0, "tap during roll starts next sword within two frames")
		check(player._roll_cooldown <= 0.0, "roll cooldown has ended with the roll")
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


func check_buffered_charge_links() -> void:
	for target_stage in range(3):
		reset()
		var sword = game.player.combo
		for stage_index in range(target_stage + 1):
			click_mouse(true)
			click_mouse(false)
			await frames(2)
			if stage_index < target_stage:
				while sword.swing_time > 0.0:
					await frames(1)
		check(sword.stage == target_stage and sword.phase() == "windup", "real click starts stage for held-charge link")
		var origin: int = sword.attack_count
		click_mouse(true)
		var saw_active := false
		for tick in range(30):
			if sword.charging:
				break
			saw_active = saw_active or sword.phase() == "active"
			await frames(1)
		check(saw_active and sword.charging and sword.charge_time <= 0.017 and sword.attack_count == origin, "held input enters fresh charge after stage " + str(target_stage))
		click_mouse(false)
		await frames(2)
		check(sword.charged_swing and sword.attack_count == origin + 1, "same held gesture releases charged sword")

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
	check(game.world.backdrop.texture != null and game.world.lanterns.size() == 2, "approved courtyard texture and two collidable lanterns")
	check(game.player.combo.get_script() == load("res://scripts/v41_sword.gd") and game.player.combo.has_method("motion_pose"), "F5 uses orbit sword with rewards")
	var draws := {}
	var offered := {}
	for seed_value in range(16):
		game.reward_rng.seed = seed_value
		game._draw_rewards()
		draws[str(game.reward_options)] = true
		for index in game.reward_options: offered[index] = true
	check(draws.size() > 1 and offered.size() == 4, "seeded draws vary and can offer all four rewards")
	for point in CONFIG.SPAWN_POINTS + [CONFIG.ENTRY_POINT, CONFIG.REWARD_POINT, CONFIG.EXIT_POINT]:
		check(Geometry2D.is_point_in_polygon(point, game.world.walkable) and not game.world.path_between(CONFIG.ENTRY_POINT, point).is_empty(), "configured point reachable: " + str(point))
	for e in enemies():
		check(e.encounter_id == 0 and e.max_simultaneous_attackers == 3 and e.health == CONFIG.ENEMY_STATS[CONFIG.MELEE].health and e.damage == CONFIG.ENEMY_STATS[CONFIG.MELEE].damage, "spawn enables encounter mechanics and configured stats")
	# Actual spawned defender: let real physics update its direction, then inspect hit.
	var defender: SurvivorEnemy = enemies()[0]
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
	check(game.phase == "reward_wait" and not game.world.portal_open, "full room clear required before reward")
	await reward(0)
	game.player.health = 63.0
	game.player.stamina = 47.0
	await advance()
	game.player.set_physics_process(false)
	check(game.room_index == 1 and game.total == 6 and game.remaining == 6 and enemies().size() == 3, "room2 starts only wave1 of six total")
	check(game.player.health == 63.0 and game.player.stamina >= 47.0 and game.player.stamina < 50.0 and game.reward_counts[0] == 1, "vitals preserved; only normal stamina regeneration after entry")
	var ranger: SurvivorEnemy
	for e in enemies():
		check(is_equal_approx(e.health, float(CONFIG.ENEMY_STATS[CONFIG.RANGED if e.kind == e.Kind.RANGED else (CONFIG.THRUST if e.thrust_type else CONFIG.MELEE)].health) * 1.2) and is_equal_approx(e.damage, float(CONFIG.ENEMY_STATS[CONFIG.RANGED if e.kind == e.Kind.RANGED else CONFIG.MELEE].damage) * 1.2), "room2 scales both health and damage")
		if e.kind == e.Kind.RANGED: ranger = e
	ranger.position = Vector2(680, 420)
	game.player.position = Vector2(580, 420)
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
	await reward(1)
	await advance()
	game.player.set_physics_process(false)
	check(game.total == 9 and enemies().size() == 4 and game.remaining == 9, "room3 starts first four of nine")
	await clear_wave()
	var thrusts := 0
	for e in enemies():
		if e.thrust_type and e.fast_chaser: thrusts += 1
		check(is_equal_approx(e.health, float(CONFIG.ENEMY_STATS[CONFIG.RANGED if e.kind == e.Kind.RANGED else (CONFIG.THRUST if e.thrust_type else CONFIG.MELEE)].health) * 1.4), "room3 health scale")
	check(thrusts == 1 and game.scheduler.groups.size() == 2 and game.scheduler.groups[1].size() == 2, "third room second wave includes one fast thrust and two full pairs")
	await clear_wave()
	await reward(2)
	await advance()
	for room in range(3, 6):
		check(game.room_index == room and game.total == CONFIG.room_total(room) and game.phase == "combat", "enters ordinary room %d in sequence" % (room + 1))
		await clear_room()
		check(game.phase == "reward_wait" and not game.world.portal_open, "room %d clears before offering a reward" % (room + 1))
		await reward(0)
		check(game.world.portal_open, "room %d reward opens exit" % (room + 1))
		await advance()
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
	await check_roll_links()
	await check_buffered_charge_links()
	await check_melee_cue_and_facing()
	await check_opening_bow_pressure(false)
	await check_opening_bow_pressure(true)
	await check_bow_cycle()
	# Input boundaries use real GUI-dispatched press/release and 60Hz physics.
	reset()
	var sword = game.player.combo
	click_mouse(true)
	await frames(6)
	check(sword.attack_count == 0 and not sword.charging, "short hold does not attack on press")
	click_mouse(false)
	await frames(2)
	check(sword.attack_count == 1 and sword.stage == 0 and not sword.charged_swing, "short release attacks first stage")
	await frames(3)
	click_mouse(true)
	click_mouse(false)
	await frames(26)
	check(sword.attack_count == 2 and sword.stage == 1, "short release buffers second stage")
	click_mouse(true)
	click_mouse(false)
	await frames(28)
	check(sword.attack_count == 3 and sword.stage == 2, "short release buffers third stage")
	reset()
	sword = game.player.combo
	click_mouse(true)
	await frames(14)
	check(sword.charging and sword.attack_count == 0, "0.22 threshold starts charge without extra ordinary hit")
	await frames(40)
	check(sword.charge_fraction() == 1.0 and sword.attack_count == 0, "0.60 more seconds reaches full charge without auto release")
	click_mouse(false)
	await frames(1)
	check(sword.charged_swing and sword.attack_count == 1 and not sword.charging, "release starts exactly one charged attack")
	reset()
	sword = game.player.combo
	click_mouse(true)
	await frames(18)
	key(KEY_SPACE)
	await frames(2)
	check(game.player.is_rolling() and not sword.charging, "real Space cancels charging only on successful roll")
	click_mouse(false)
	await frames(30)
	check(sword.attack_count == 0, "release after cancelled charge never produces delayed attack")
	reset()
	game.reward_counts[1] = 1
	game._apply_rewards()
	sword = game.player.combo
	game.player.try_roll()
	await frames(24)
	check(sword.roll_armed, "successful roll arms reward while rolling does not consume it")
	click_mouse(true)
	click_mouse(false)
	await frames(2)
	check(sword.swing_bonus == 2.0 and not sword.roll_armed, "ordinary short-release attack consumes roll reward even on miss")
	await frames(24)
	click_mouse(true)
	click_mouse(false)
	await frames(2)
	check(sword.swing_bonus == 1.0, "roll multiplier is not reused for second ordinary attack")
	reset()
	sword = game.player.combo
	click_mouse(true)
	await frames(20)
	game.player._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	click_mouse(false)
	await frames(3)
	check(not sword.charging and sword.attack_count == 0, "focus loss clears hold and release cannot attack")
	# Actual contact tests use the current F5's spawned enemy and orbit blade.
	reset()
	game.player.set_physics_process(false)
	game.player.combo.set_physics_process(false)
	game.player.position = Vector2(580, 420)
	game.reward_counts.assign([1, 1, 0, 1])
	game._apply_rewards()
	sword = game.player.combo
	var target := target_at(game.player.position + Vector2(65, 0))
	check(is_equal_approx(sword.stages[0].damage, 41.6) and is_equal_approx(sword.charge_damage_max, 123.5), "+30 percent applies to ordinary and charged base, without shared bow multiplier")
	game.player.try_roll()
	game.player._finish_roll()
	check(sword.roll_armed, "roll arms one empowered sword")
	sword.gesture_held = true
	sword.charging = true
	sword.charge_time = sword.charge_duration
	sword._release_charge(Vector2.RIGHT)
	check(not sword.roll_armed and sword.swing_bonus == 2.0, "charge release consumes roll bonus once")
	tick_sword(40)
	check(is_equal_approx(1000.0 - target.health, 247.0), "actual charged orbit hit combines 95 x 1.3 x 2")
	check(target.knockback.length() <= 260.1, "third-stage reward never boosts charged knockback")
	# Fresh full charge hits multiple real spawned targets once each.
	reset()
	game.player.set_physics_process(false)
	game.player.combo.set_physics_process(false)
	game.player.position = Vector2(580, 420)
	sword = game.player.combo
	var targets := enemies()
	for i in range(targets.size()):
		targets[i].position = game.player.position + Vector2.RIGHT.rotated(-0.6 + i * 0.4) * 90.0
		targets[i].health = 1000.0
		targets[i].guard_cooldown = 10.0
	sword.charging = true
	sword.charge_time = sword.charge_duration
	sword._release_charge(Vector2.RIGHT)
	tick_sword(70)
	for e in targets:
		check(is_equal_approx(1000.0 - e.health, 95.0), "charged multi-target deals exactly one 95 hit per spawned enemy")
	# Base third hit opens guard; the reward extends that opening and push.
	for mode in ["base", "reward", "charge"]:
		var charged: bool = mode == "charge"
		reset()
		game.player.set_physics_process(false)
		game.player.combo.set_physics_process(false)
		game.player.position = Vector2(580, 420)
		game.reward_counts[3] = int(mode != "base")
		game._apply_rewards()
		sword = game.player.combo
		target = target_at(game.player.position + Vector2(65, 0))
		target.guard_cooldown = 0.0
		target.guard_direction = Vector2.LEFT
		target.encounter_state = target.EncounterState.CHASE
		if charged:
			sword.charging = true
			sword.charge_time = sword.charge_duration
			sword._release_charge(Vector2.RIGHT)
		else:
			sword.next_stage = 2
			sword.chain_time = 0.2
			sword.attack(Vector2.RIGHT)
		tick_sword(40)
		check(is_equal_approx(1000.0 - target.health, 95.0 if charged else 60.0), "guard interaction on front contact: " + mode)
		var guard_window := CONFIG.HEAVY_BASE_BREAK if charged or mode == "base" else CONFIG.GUARD_BREAK_TIME
		check(is_equal_approx(target.guard_cooldown, guard_window), "guard window: " + mode)
		check(is_equal_approx(target.v41_heavy_stun, CONFIG.BREAK_STUN), "third and charge same break stun: " + mode)
		check(target.guard_time == 0.0 and target.guard_visual_time == 0.0, "break clears guard and blue arc: " + mode)
		if mode != "base":
			check(is_equal_approx(target.knockback.length(), 260.0 if charged else CONFIG.THIRD_MOB_PUSH), "correct charged vs small third knockback")
	reset()
	game.reward_counts[2] = 2
	game.player.health = 91.0
	var killed = enemies()[0]
	killed.take_damage(10000.0, Vector2.ZERO)
	check(game.player.health == 100.0, "stacked kill heal capped at max health")
	game.player.gm_invulnerable = false
	game.player.invulnerability = 0.0
	game.player.take_damage(10000.0, Vector2.ZERO)
	check(game.phase == "dead" and paused, "real damage enters death result")
	key(KEY_R)
	check(game.reward_counts == [0, 0, 0, 0] and game.player.health == 100.0 and not paused, "death R resets run and rewards")
	await clear_room()
	game.player.position = CONFIG.REWARD_POINT
	await frames()
	key(KEY_E)
	game.reward_options.assign([0, 1, 3])
	game.reward_counts[1] = 1
	game.hud.show_rewards()
	await frames()
	var chosen: Button
	var disabled: Button
	for item in game.hud.modal_panel.find_children("*", "Button", true, false):
		if item.text.begins_with("剑伤害"): chosen = item
		if item.text.begins_with("翻滚后"): disabled = item
	check(disabled != null and disabled.disabled, "already unlocked unique reward is visibly disabled")
	game.select_reward(1)
	check(game.phase == "reward_select", "disabled unique reward cannot be selected through code")
	var count_before: int = game.player.weapon.attack_count
	var point := chosen.get_global_rect().get_center()
	click_mouse(true, point)
	await frames(1)
	click_mouse(false, point)
	await frames(2)
	check(game.phase == "exit_ready" and game.reward_counts[0] == 1 and game.player.weapon.attack_count == count_before, "real reward button applies once without ordinary or charged attack")
	game.player.combo.roll_armed = true
	click_mouse(true)
	await frames(18)
	# Change rooms through the real exit while holding a charge.
	await advance()
	click_mouse(false)
	await frames(2)
	check(game.room_index == 1 and game.reward_counts[1] == 1 and not game.player.combo.roll_armed and not game.player.combo.charging and game.player.combo.attack_count == 0, "room transition preserves unlock but clears armed multiplier and held charge")
	# All original imported samples must load with compatible charge-aware player.
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
		click_mouse(true)
		await frames(55)
		await snapshot("%d_charge" % size.x)
		game.toggle_pause()
		await snapshot("%d_pause" % size.x)
		check(not game.player.combo.charging and not game.player.combo.gesture_held, "pause clears charge gesture")
		game.resume_room()
		click_mouse(false)
		game.toggle_stats()
		await snapshot("%d_stats" % size.x)
		game.resume_room()
		await clear_room()
		game.player.position = CONFIG.REWARD_POINT
		await frames()
		key(KEY_E)
		await snapshot("%d_rewards" % size.x)
		game.select_reward(game.reward_options.filter(game.can_select_reward)[0])
	paused = false
	game.queue_free()
	await process_frame
	print("V41 FLOW: %d checks, %d failures; real-scene controlled tests, not human play" % [checks, failures])
	quit(1 if failures else 0)

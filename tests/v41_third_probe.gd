extends SceneTree
var game
var frame := 0
func _initialize(): run.call_deferred()
func tick():
	await physics_frame
	await process_frame
	frame += 1
func click(down: bool, point: Vector2):
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = down
	ev.position = root.get_canvas_transform() * point
	ev.global_position = ev.position
	root.push_input(ev, true)
func dash(direction: Vector2 = Vector2.RIGHT):
	var motion := InputEventMouseMotion.new()
	motion.position = root.get_canvas_transform() * (game.player.global_position + direction * 200.0)
	root.push_input(motion, true)
	var ev := InputEventKey.new()
	ev.keycode = KEY_SPACE
	ev.physical_keycode = KEY_SPACE
	ev.pressed = true
	root.push_input(ev, true)
	ev = ev.duplicate()
	ev.pressed = false
	root.push_input(ev, true)
func release_move():
	for action in ["move_left", "move_right", "move_up", "move_down"]: Input.action_release(action)
func move_to(offset: Vector2):
	var d := offset.normalized()
	Input.action_press("move_left", maxf(0.0, -d.x))
	Input.action_press("move_right", maxf(0.0, d.x))
	Input.action_press("move_up", maxf(0.0, -d.y))
	Input.action_press("move_down", maxf(0.0, d.y))
func run():
	game = load("res://scenes/main_v41.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await tick()
	for count in [1, 2]:
		for reward in [false, true]:
			for tactic in [0, 1, 2]:
				await trial(count, reward, tactic)
	quit()
func trial(count: int, reward: bool, tactic: int):
	release_move()
	game.start_room()
	await tick()
	var p = game.player
	var es = get_nodes_in_group("enemies")
	for i in range(count, es.size()): es[i].free()
	es.resize(count)
	game.scheduler.configure(es, 2, 1.65)
	if reward:
		game.reward_counts[8] = 1
		game._apply_rewards()
	p.position = Vector2(620, 420)
	for i in range(count):
		es[i].position = Vector2(685, 420 + (i * 65))
		es[i].home_position = es[i].position
	var target = es[0]
	var hits := []
	var mark := {"third": -1, "recovered": -1, "guard": -1, "attack": -1, "follow": -1, "damage": 0.0, "blocked": false, "distance": 0.0, "hp_at_third": -1.0, "maxdist": 0.0, "target_windup_at_hit": 0.0, "other_windup_at_hit": 0.0}
	target.damaged.connect(func(_pos, amount):
		hits.append([frame, p.combo.stage, amount, target.last_hit_blocked, p.position.distance_to(target.position)])
		if p.combo.stage == 2 and mark.third < 0:
			mark.third = frame
			mark.distance = p.position.distance_to(target.position)
			mark.hp_at_third = p.health
			mark.target_windup_at_hit = target.windup
			mark.other_windup_at_hit = es[1].windup if count == 2 and is_instance_valid(es[1]) else 0.0
		elif mark.third >= 0:
			mark.follow = frame
			mark.damage = amount
			mark.blocked = target.last_hit_blocked
	)
	var state := 0
	var pressed := false
	var next_click := 0
	var hit_before := 100.0
	var attacks := 0
	var windup_seen := false
	for i in range(400):
		await tick()
		if not is_instance_valid(target) or p.dead: break
		if target.windup > 0.0: windup_seen = true
		if mark.third >= 0:
			mark.maxdist = maxf(mark.maxdist, p.position.distance_to(target.position))
			if mark.recovered < 0 and p.combo.swing_time <= 0.0: mark.recovered = frame
			if mark.guard < 0 and target.guard_cooldown <= 0.0: mark.guard = frame
			if mark.attack < 0 and target.windup > 0.0: mark.attack = frame
			if frame - mark.third > 110: break
		if state == 0 and windup_seen:
			Input.action_press("move_up" if tactic != 1 else "move_down")
			dash(Vector2.UP if tactic != 1 else Vector2.DOWN)
			state = 1
		elif state == 1 and p.dash_state == p.Dash.IDLE:
			release_move()
			state = 2
		elif state == 2:
			var offset: Vector2 = target.position - p.position
			if offset.length() > (70.0 if tactic != 2 else 50.0): move_to(offset)
			else:
				release_move()
				click(true, target.global_position)
				pressed = true
				state = 3
		elif state == 3:
			if pressed:
				click(false, target.global_position)
				pressed = false
				next_click = frame + 10
			elif frame >= next_click and p.combo.attack_count < 4:
				click(true, target.global_position)
				pressed = true
			if mark.third >= 0 and p.combo.swing_time <= 0.0 and p.position.distance_to(target.position) > 85:
				move_to(target.position - p.position)
			if p.combo.attack_count != attacks:
				attacks = p.combo.attack_count
				print("SWING count=",count," reward=",reward," tactic=",tactic," n=",attacks," frame=",frame," dist=",p.position.distance_to(target.position)," hp=",p.health)
		if p.health < hit_before:
			print("PLAYER_HIT count=",count," reward=",reward," tactic=",tactic," frame=",frame," health=",p.health)
			hit_before = p.health
	release_move()
	if pressed: click(false, p.global_position)
	print("TRIAL count=",count," reward=",reward," tactic=",tactic," hits=",hits," third=",mark," hp=",p.health," attacks=",attacks)

extends SceneTree

var game
var frame := 0
var target
var health_before := 0.0
var target_health := 0.0
var first_input := -1
var third_hit := -1
var rolled_out := false
var stage_hits := []

func _initialize() -> void:
	run.call_deferred()

func tick() -> void:
	await physics_frame
	await process_frame
	frame += 1

func click(down: bool, world_point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = root.get_canvas_transform() * world_point
	event.global_position = event.position
	root.push_input(event, true)

func key_roll() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	event.physical_keycode = KEY_SPACE
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)

func run() -> void:
	game = load("res://scenes/main_v41.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await tick()
	var p = game.player
	p.position = Vector2(620, 420)
	p.gm_invulnerable = false
	var es = get_nodes_in_group("enemies")
	var positions = [Vector2(675, 400), Vector2(675, 440), Vector2(840, 350), Vector2(840, 490)]
	for i in range(4):
		es[i].position = positions[i]
		es[i].home_position = positions[i]
	var previous := {}
	var rolling := false
	var phase := 0
	var pressed := false
	var next_click := 0
	var attack_count := 0
	health_before = p.health
	for i in range(400):
		await tick()
		if p.combo.attack_count != attack_count:
			attack_count = p.combo.attack_count
			print("TRACE swing f=",frame," stage=",p.combo.stage," distance=",p.position.distance_to(target.position) if is_instance_valid(target) else -1)
		for j in range(4):
			var e = es[j]
			if not is_instance_valid(e) or e.dead: continue
			var state = "windup" if e.windup > 0.0 else ("lunge" if e.lunge_time > 0.0 else ("recovery" if e.attack_cooldown > 0.0 else "idle"))
			if previous.get(j, "") != state:
				print("TRACE f=",frame," enemy=",j," state=",state," hp=",p.health," pos=",e.position," group=",game.scheduler.current)
				previous[j] = state
		if phase == 0 and es[0].windup > 0.0 and es[1].windup > 0.0:
			Input.action_press("move_up")
			key_roll()
			rolling = true
			phase = 1
			print("TRACE dodge f=",frame)
		elif phase == 1 and rolling and not p.is_rolling():
			Input.action_release("move_up")
			target = es[0] if is_instance_valid(es[0]) and not es[0].dead else es[1]
			phase = 5
			print("TRACE roll end f=",frame," pos=",p.position)
		elif phase == 5 and es[0].attack_cooldown > 0.0 and es[1].attack_cooldown > 0.0:
			phase = 2
			print("TRACE both missed f=",frame)
		elif phase == 2:
			var offset: Vector2 = target.position - p.position
			if offset.length() > 78:
				Input.action_press("move_right", maxf(0.0, offset.normalized().x))
				Input.action_press("move_down", maxf(0.0, offset.normalized().y))
				Input.action_press("move_up", maxf(0.0, -offset.normalized().y))
			else:
				Input.action_release("move_right")
				Input.action_release("move_down")
				Input.action_release("move_up")
				target_health = target.health
				first_input = frame
				click(true, target.global_position)
				pressed = true
				phase = 3
				print("TRACE first press f=",frame," target=",target.get_instance_id()," distance=",offset.length())
		elif phase == 3:
			if pressed:
				click(false, target.global_position)
				pressed = false
				next_click = frame + 10
			elif p.combo.attack_count < 3 and frame >= next_click:
				click(true, target.global_position)
				pressed = true
			if target.health < target_health:
				stage_hits.append([p.combo.stage, frame, target_health - target.health])
				target_health = target.health
				print("TRACE hit stage=",p.combo.stage," f=",frame," player hp=",p.health)
				if p.combo.stage == 2:
					third_hit = frame
			if third_hit >= 0 and p.combo.can_roll():
				Input.action_press("move_up")
				key_roll()
				phase = 4
		elif phase == 4 and p.is_rolling():
			rolled_out = true
			break
		if p.health < health_before:
			print("TRACE player hit f=",frame," health=",p.health," phase=",phase)
			break
	var counter_ok: bool = first_input > 0 and third_hit > first_input and stage_hits.size() == 3 and stage_hits[0][0] == 0 and stage_hits[1][0] == 1 and stage_hits[2][0] == 2 and rolled_out and p.health == health_before
	print("OBSERVATION counter=",counter_ok," first=",first_input," third=",third_hit," elapsed=",(third_hit - first_input) / 60.0," hits=",stage_hits," rolled=",rolled_out," hp=",p.health)
	for action in ["move_up", "move_down", "move_right", "move_left"]:
		Input.action_release(action)
	game.start_room()
	await tick()
	p = game.player
	p.position = Vector2(620, 420)
	p.gm_invulnerable = false
	es = get_nodes_in_group("enemies")
	for i in range(4):
		es[i].position = positions[i]
		es[i].home_position = positions[i]
	for i in range(150):
		await tick()
		if p.health < 100.0:
			break
	var face_risk: bool = p.health < 100.0
	print("RESULT standing_risk=",face_risk," hp=",p.health)
	# A full three-hit punish is an observation, not a required outcome.
	quit(0 if face_risk else 1)

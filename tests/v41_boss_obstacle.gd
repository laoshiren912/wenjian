extends SceneTree

var game
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func tick() -> void:
	await physics_frame
	await process_frame

func run() -> void:
	game = load("res://scenes/main_v41.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await tick()
	for pillar in game.world.lanterns:
		for setup in [[Vector2.RIGHT, 0.0], [Vector2.LEFT, 0.0], [Vector2.UP, 0.0], [Vector2.DOWN, 0.0], [Vector2.RIGHT, 18.0], [Vector2.LEFT, 18.0], [Vector2.UP, 18.0], [Vector2.DOWN, 18.0]]:
			var side: Vector2 = setup[0]
			for mode in ["still", "along", "open"]:
				game.start_room()
				game.room_index = 6
				game._enter_room()
				var p = game.player
				var b = game.boss
				var tangent: Vector2 = side.orthogonal()
				# Real scene, actors and collision; only initial placement is controlled.
				p.position = pillar.position + side * 96.0 + tangent * float(setup[1])
				b.position = pillar.position - side * 54.0 + tangent * float(setup[1])
				b.boss_next_attack = 1
				b.boss_timer = 0.0
				var start: Vector2 = b.position
				var casts := 0
				var last_state = b.boss_state
				var max_displacement := 0.0
				for frame in range(420):
					if mode != "still" and frame == 30:
						var direction: Vector2 = tangent if mode == "along" else side
						Input.action_press("move_right", maxf(0, direction.x))
						Input.action_press("move_left", maxf(0, -direction.x))
						Input.action_press("move_down", maxf(0, direction.y))
						Input.action_press("move_up", maxf(0, -direction.y))
					if frame == 60:
						for action in ["move_right", "move_left", "move_down", "move_up"]:
							Input.action_release(action)
					await tick()
					max_displacement = maxf(max_displacement, b.position.distance_to(start))
					if b.boss_state != last_state and b.boss_state in [b.BossState.COMBO_WINDUP, b.BossState.CHARGE_WINDUP]:
						casts += 1
						if b.boss_state == b.BossState.CHARGE_WINDUP and b.boss_charge_distance + b.CHARGE_WIDTH < b.position.distance_to(p.position) - 4.0:
							failures += 1
							print("FAIL unreachable charge at windup start")
					last_state = b.boss_state
					if p.health < 100.0: break
				var ok: bool = p.health < 100.0
				if not ok: failures += 1
				print("PILLAR ",pillar.position," margin=",setup[1]," side=",side," mode=",mode," hp=",p.health," displacement=",max_displacement," casts=",casts," boss=",b.position," player=",p.position," ok=",ok)
				for action in ["move_right", "move_left", "move_down", "move_up"]:
					Input.action_release(action)
	print("PILLAR_RESULT failures=", failures)
	quit(1 if failures else 0)






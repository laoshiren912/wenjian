extends "res://tests/v21_animation.gd"

const TURN_OUTPUT := "res://artifacts/v21_turn_visual_2026-10-28/"
const STOP_FILE := "res://artifacts/runtime/turning_stop"

class DesktopObserver extends Node:
	var player: SurvivorPlayer
	var seen: Dictionary = {}
	var keys: Dictionary = {}
	func _input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and not event.echo:
			for action in ["move_up", "move_down", "move_left", "move_right"]:
				if event.is_action_pressed(action):
					keys[action] = true
					print("DESKTOP TURN KEY: " + action)
	func _physics_process(_delta: float) -> void:
		var actual: Vector2 = player.get_real_velocity()
		var direction: Vector2 = player.visual.facing
		if actual.length() > 1 and direction.dot(actual.normalized()) > 0.99 and not seen.has(direction):
			seen[direction] = true
			print("DESKTOP TURN: facing=%s motion=%s aim=%s PASS" % [direction, actual, player.aim_direction])
			if seen.size() == 4:
				get_window().title = "V2.1 Walking Turns PASS"

func _run() -> void:
	root.size = Vector2i(1280, 720)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frames()
	game.start_run()
	game.spawn_timer = 9999.0
	clear_targets()
	var player: SurvivorPlayer = game.player
	if OS.get_cmdline_user_args().has("--desktop"):
		if FileAccess.file_exists(STOP_FILE):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(STOP_FILE))
		root.title = "V2.1 Walking Turns"
		var observer := DesktopObserver.new()
		observer.player = player
		observer.process_priority = 1
		root.add_child(observer)
		print("DESKTOP TURN READY: physical WASD, normal stats; random enemies cleared and spawns stopped")
		var deadline: int = Time.get_ticks_msec() + 90000
		while Time.get_ticks_msec() < deadline and not FileAccess.file_exists(STOP_FILE):
			await process_frame
		print("DESKTOP TURN RESULT: %d/4 facing directions; %d/4 physical keys" % [observer.seen.size(), observer.keys.size()])
		quit(0 if observer.seen.size() == 4 and observer.keys.size() == 4 else 1)
		return
	if OS.get_cmdline_user_args().has("--render"):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TURN_OUTPUT))
		player.set_physics_process(false)
		player.camera.position_smoothing_enabled = false
		player.camera.reset_smoothing()
		await frames()
		var directions := [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT]
		var names := ["front", "back", "left", "right"]
		for index in range(directions.size()):
			player.aim_direction = -directions[index]
			player.visual.update_pose(directions[index] * 225.0, directions[index], Color("79e2d0"))
			await frames(5)
			await RenderingServer.frame_post_draw
			var frame: Image = root.get_texture().get_image()
			check(frame.save_png(TURN_OUTPUT + names[index] + ".png") == OK, "Native render " + names[index])
			var center: Vector2 = player.get_global_transform_with_canvas().origin
			var crop := frame.get_region(Rect2i(int(center.x) - 56, int(center.y) - 56, 112, 112))
			crop.resize(672, 672, Image.INTERPOLATE_NEAREST)
			check(crop.save_png(TURN_OUTPUT + names[index] + "_detail.png") == OK, "Native detail " + names[index])
		print("TURN VISUAL RESULT: %d image saves, %d failures; controlled poses, not desktop input" % [checks, failures])
		quit(0 if failures == 0 else 1)
		return
	await aim(Vector2.LEFT)
	movement(Vector2.RIGHT)
	await frames(8)
	check(player.visual.facing == Vector2.LEFT and player.visual.leg_facing == Vector2.RIGHT and player.visual.motion.x > 1 and player.aim_direction.x < -0.99, "Right walk keeps torso toward left aim and legs toward movement")
	movement(Vector2.LEFT)
	await frames(2)
	check(player.visual.facing == Vector2.LEFT and player.visual.leg_facing == Vector2.LEFT and player.visual.motion.x < -1, "Reversing movement turns legs immediately")
	await aim(Vector2.RIGHT)
	check(player.visual.facing == Vector2.RIGHT and player.visual.leg_facing == Vector2.LEFT and player.aim_direction.x > 0.99, "Changing aim turns torso independently of leftward legs")
	movement(Vector2.ZERO)
	await frames(2)
	await aim(Vector2.DOWN)
	check(player.visual.facing == Vector2.DOWN and player.visual.walk_phase == 0, "Idle follows aim without a walking animation")
	player.position = Vector2(79, 640)
	movement(Vector2.LEFT)
	await frames(25)
	check(player.visual.leg_facing == Vector2.LEFT and player.visual.motion.length() < 1 and player.visual.walk_phase == 0, "Wall contact keeps intended leg direction without walking in place")
	movement(Vector2.ZERO)
	player.position = SurvivorWorld.SPAWN
	player.knockback = Vector2(180, 0)
	await frames(2)
	check(player.visual.facing.dot(player.aim_direction) > 0.70 and player.visual.motion.x > 1, "Knockback does not turn the resting body away from aim")
	player.knockback = Vector2.ZERO
	player.position = SurvivorWorld.SPAWN
	await aim(Vector2.RIGHT)
	for index in range(3):
		await begin_profession(index)
		player = game.player
		player.visual.facing = Vector2.LEFT
		await aim(Vector2.RIGHT)
		player.weapon.cooldown = 0.0
		var enemy := target_at([70.0, 135.0, 200.0][index])
		player.weapon.attack(player.aim_direction)
		check(player.visual.facing == Vector2.RIGHT and player.visual.attack_direction.x > 0.99 and player.weapon.swing_direction.x > 0.99, "Weapon %d and torso follow aim" % (index + 1))
		await frames(30)
		check(is_equal_approx(enemy.health, enemy.max_health - float(SurvivorWeapon.DATA[index].damage)) and player.stamina == 100.0, "Weapon %d still hits at the original damage without stamina cost" % (index + 1))
	print("TURN REGRESSION RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

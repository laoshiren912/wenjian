extends SceneTree

# Controlled fixtures, not a normal-difficulty playthrough. No production values are tuned.
var game: SurvivorGame
var checks: int = 0
var failures: int = 0
const OUTPUT := "res://artifacts/v21_visual_2026-10-28/"

func _initialize() -> void:
	_run.call_deferred()

func frames(count: int = 3) -> void:
	for frame in range(count):
		await physics_frame
	await process_frame

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS: " if ok else "FAIL: ") + description)

func clear_targets() -> void:
	for group in ["enemies", "pickups", "projectiles", "death_visuals"]:
		for node in get_nodes_in_group(group):
			node.free()

func target_at(distance: float, kind: int = SurvivorEnemy.Kind.HOSTILE) -> SurvivorEnemy:
	var enemy := game._spawn_enemy(kind, game.player.position + Vector2(distance, 0))
	enemy.set_physics_process(false)
	return enemy

func aim(direction: Vector2) -> void:
	game.player.camera.reset_smoothing()
	await frames(2)
	var event := InputEventMouseMotion.new()
	event.position = game.player.get_global_transform_with_canvas().origin + direction * 200.0
	event.global_position = event.position
	Input.parse_input_event(event)
	await frames(2)

func movement(direction: Vector2) -> void:
	for pair in [["move_left", -direction.x], ["move_right", direction.x], ["move_up", -direction.y], ["move_down", direction.y]]:
		if float(pair[1]) > 0:
			Input.action_press(pair[0])
		else:
			Input.action_release(pair[0])

func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var frame: Image = root.get_texture().get_image()
	check(frame.save_png(OUTPUT + name + ".png") == OK, "Render " + name)
	var center: Vector2 = game.player.get_global_transform_with_canvas().origin
	var crop := frame.get_region(Rect2i(int(center.x) - 64, int(center.y) - 64, 288, 144))
	crop.resize(1152, 576, Image.INTERPOLATE_NEAREST)
	check(crop.save_png(OUTPUT + name + "_detail.png") == OK, "Render detail " + name)

func render_samples() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	game.player.set_physics_process(false)
	game.player.camera.position_smoothing_enabled = false
	game.player.camera.reset_smoothing()
	await frames()
	for index in range(3):
		clear_targets()
		game.player.weapon.select_weapon(index)
		game.player.weapon.cooldown = 0.0
		game.player.aim_direction = Vector2.RIGHT
		game.player.visual.update_pose(Vector2.ZERO, Vector2.RIGHT, Color("79e2d0"))
		var enemy := target_at([70.0, 135.0, 200.0][index])
		game.player.weapon.attack(Vector2.RIGHT)
		await capture("0%d_attack" % (index + 1))
		await frames(24)
	clear_targets()
	game.player.weapon.select_weapon(0)
	game.player.visual.update_pose(Vector2(225, 0), Vector2.UP, Color("79e2d0"))
	var walking := target_at(95.0, SurvivorEnemy.Kind.PASSIVE)
	walking.visual.update_pose(Vector2(85, 0), Vector2.RIGHT, Color("d4bb76"))
	await frames(5)
	await capture("04_strafe_walk")
	walking.take_damage(1.0, Vector2.ZERO)
	await capture("05_enemy_hurt")
	walking.take_damage(10000.0, Vector2.ZERO)
	await frames(4)
	await capture("06_enemy_death")
	print("V21 VISUAL RESULT: %d image saves, %d failures; controlled native renders only" % [checks, failures])

func _run() -> void:
	root.size = Vector2i(1280, 720)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frames()
	game.start_run()
	game.spawn_timer = 9999.0
	clear_targets()
	if OS.get_cmdline_user_args().has("--render"):
		await render_samples()
		quit(0 if failures == 0 else 1)
		return
	var player: SurvivorPlayer = game.player
	check(player.visual.get_parent() == player and player.get_node("CollisionShape2D").shape.radius == 14.0, "Player animation is a separate non-physical child; collider radius stays 14")
	for direction in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP, Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]:
		var resting_facing: Vector2 = player.visual.facing
		await aim(direction.normalized())
		check(player.visual.facing == resting_facing and player.aim_direction.dot(direction.normalized()) > 0.99, "Resting body keeps its direction while the mouse independently aims %s" % direction)
	for direction in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP, Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]:
		player.position = SurvivorWorld.SPAWN
		await aim(-direction.normalized())
		var before: Vector2 = player.position
		movement(direction)
		await frames(8)
		check((player.position - before).dot(direction.normalized()) > 20.0 and player.visual.walk_phase > 0.0 and player.visual.facing.dot(direction.normalized()) > 0.70 and player.aim_direction.dot(-direction.normalized()) > 0.98, "Walking turns the body toward %s despite opposite mouse aim" % direction)
		var walking_facing: Vector2 = player.visual.facing
		movement(Vector2.ZERO)
		await frames(2)
		check(player.visual.walk_phase == 0.0 and player.visual.motion.is_zero_approx() and player.visual.facing == walking_facing, "Stopping clears gait and keeps the last walking direction for %s" % direction)
	player.position = Vector2(79, 640)
	movement(Vector2.LEFT)
	await frames(25)
	check(player.position.x >= 77.0 and player.visual.motion.length() < 1.0 and player.visual.walk_phase == 0.0, "Walking into a wall cannot animate sliding in place")
	movement(Vector2.ZERO)
	player.position = SurvivorWorld.SPAWN
	await aim(Vector2.RIGHT)
	for index in range(3):
		clear_targets()
		player.weapon.select_weapon(index)
		player.weapon.cooldown = 0.0
		var enemy := target_at([70.0, 135.0, 200.0][index])
		var position_before: Vector2 = player.position
		check(player.weapon.attack(Vector2.RIGHT) and player.visual.attack_time > 0.0 and player.visual.attack_weapon == index, "Weapon %d starts its matching pose on the accepted attack" % (index + 1))
		if index < 2:
			check(is_equal_approx(enemy.health, enemy.max_health - float(SurvivorWeapon.DATA[index].damage)), "Weapon %d deals damage immediately, without an animation windup" % (index + 1))
		else:
			check(get_nodes_in_group("projectiles").size() == 1 and enemy.health == enemy.max_health, "Bow spawns the arrow immediately instead of waiting for a visual callback")
		check(player.position.is_equal_approx(position_before) and player.visual.position.is_zero_approx() and player.get_node("CollisionShape2D").position.is_zero_approx(), "Weapon %d poses never move the physical actor or collider" % (index + 1))
		var attacks: int = player.weapon.attack_count
		check(not player.weapon.attack(Vector2.UP) and player.weapon.attack_count == attacks, "Weapon %d cannot bypass cooldown through animation" % (index + 1))
		var cooldown: float = player.weapon.cooldown
		player.weapon.select_weapon((index + 1) % 3)
		check(player.visual.attack_time == 0.0 and player.weapon.swing_time == 0.0 and player.weapon.cooldown == cooldown, "Switching from weapon %d clears its pose but preserves cooldown" % (index + 1))
		await frames(20)
	clear_targets()
	player.attack_speed_multiplier = 4.0
	player.weapon.select_weapon(0)
	player.weapon.cooldown = 0.0
	var fast_target := target_at(70.0)
	player.weapon.attack(Vector2.RIGHT)
	check(player.visual.attack_duration <= player.weapon.cooldown and is_equal_approx(player.weapon.swing_duration, 0.12), "Fast attack recovery is capped by the upgraded cooldown")
	await frames(8)
	check(player.weapon.attack(Vector2.RIGHT) and fast_target.health == fast_target.max_health - 104.0, "A new fast attack restarts the pose without delaying or doubling hits")
	player.attack_speed_multiplier = 1.0
	await frames(20)
	clear_targets()
	var walker := game._spawn_enemy(SurvivorEnemy.Kind.HOSTILE, player.position + Vector2(200, 0))
	# Allow the existing grid path to finish its initial cell-center approach.
	await frames(60)
	print("WALK FIXTURE: motion=%s facing=%s phase=%.3f distance=%.2f" % [walker.visual.motion, walker.visual.facing, walker.visual.walk_phase, walker.position.distance_to(player.position)])
	check(walker.visual.motion.length() > 1.0 and walker.visual.walk_phase > 0.0 and walker.visual.facing.dot(walker.visual.motion.normalized()) > 0.70 and walker.position.distance_to(player.position) < 200.0, "Hostile pursuit drives real movement and faces its current path segment")
	clear_targets()
	var passive := game._spawn_enemy(SurvivorEnemy.Kind.PASSIVE, player.position + Vector2(100, 0))
	passive.wander_target = passive.position + Vector2(40, 0)
	passive.wander_timer = 5.0
	await frames(10)
	check(not passive.aggro and passive.visual.appearance == 2 and passive.visual.walk_phase > 0.0, "Passive wandering has a distinct body and gait without triggering aggression")
	passive.take_damage(1.0, Vector2.ZERO)
	check(passive.visual.hurt_time > 0.0 and passive.aggro, "Enemy hit reaction begins with the existing damage and retaliation")
	clear_targets()
	player.position = SurvivorWorld.SPAWN
	player.knockback = Vector2.ZERO
	player.invulnerability = 0.0
	player.take_damage(12.0, Vector2.ZERO)
	check(player.visual.hurt_time > 0.0 and player.health == 88.0 and player.invulnerability == 0.7, "Player hit pose preserves actual damage and invulnerability")
	var victim := target_at(80.0)
	var victim_position: Vector2 = victim.position
	var kills: int = game.kills
	var ghost: ActorVisual = victim.visual
	victim.take_damage(10000.0, Vector2.ZERO)
	victim.take_damage(10000.0, Vector2.ZERO)
	check(game.kills == kills + 1 and victim.is_queued_for_deletion(), "Death still queues the enemy removal and counts exactly once immediately")
	check(ghost.get_parent() == game.world.actors and ghost.dying and ghost.global_position.is_equal_approx(victim_position), "Only the visual detaches at the original world position")
	check(not ghost.is_in_group("enemies") and ghost.find_children("*", "CollisionObject2D", true, false).is_empty(), "Death residual has no enemy membership or colliders")
	await frames(2)
	check(not is_instance_valid(victim) and get_nodes_in_group("pickups").size() == 1 and is_instance_valid(ghost), "Enemy and XP lifecycle are independent of the fading residual")
	game.toggle_pause()
	var death_age: float = ghost.death_age
	await frames(30)
	check(ghost.death_age == death_age, "Death fade freezes during combat pause")
	game.resume_run()
	var behind_ghost := target_at(130.0)
	player.weapon.select_weapon(2)
	player.weapon.cooldown = 0.0
	player.weapon.attack(Vector2.RIGHT)
	await frames(10)
	check(is_instance_valid(ghost) and is_equal_approx(behind_ghost.health, behind_ghost.max_health - 21.0), "Arrow passes the still-visible residual and damages the living enemy behind it")
	await frames(10)
	check(not is_instance_valid(ghost) and get_nodes_in_group("death_visuals").is_empty(), "Death residual cleans itself after 0.22 active seconds")
	clear_targets()
	player.weapon.select_weapon(0)
	player.weapon.cooldown = 0.0
	player.weapon.attack(Vector2.RIGHT)
	await frames(2)
	game.toggle_pause()
	var pose_time: float = player.visual.attack_time
	var swing_time: float = player.weapon.swing_time
	await frames(30)
	check(player.visual.attack_time == pose_time and player.weapon.swing_time == swing_time, "Body and weapon poses pause together")
	game.resume_run()
	await frames(15)
	check(player.visual.attack_time == 0.0 and player.weapon.swing_time == 0.0, "Body and weapon return to rest after resume")
	var restart_victim := target_at(180.0)
	restart_victim.take_damage(10000.0, Vector2.ZERO)
	game.restart_run()
	await frames(4)
	game = current_scene
	check(get_nodes_in_group("death_visuals").is_empty() and game.player.visual.attack_time == 0.0 and game.state == SurvivorGame.State.START, "Restart removes old residuals and creates a resting player")
	print("V21 ANIMATION RESULT: %d checks, %d failures" % [checks, failures])
	paused = false
	quit(0 if failures == 0 else 1)

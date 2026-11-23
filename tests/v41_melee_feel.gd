extends SceneTree

const CONFIG = preload("res://scripts/v41_config.gd")
const OUT := "res://artifacts/runtime/melee-feel/"
var game
var checks := 0
var failures := 0
var capture := false

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", text)

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
	await process_frame

func run() -> void:
	root.size = Vector2i(1280, 720)
	capture = "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	if capture:
		DirAccess.make_dir_recursive_absolute(OUT)
	game = load("res://scenes/main_v41.tscn").instantiate()
	root.add_child(game)
	await frames(2)
	var p = game.player
	p.gm_invulnerable = true
	var foes := get_nodes_in_group("enemies")
	var enemy = foes[0]
	for other in foes.slice(1):
		other.free()
	enemy.set_physics_process(false)
	enemy.health = 10000.0
	var sword = p.combo
	for slot in range(3):
		for prefix in ["combo_swing_", "combo_hit_"]:
			var sound: AudioStreamWAV = game.feedback.sword_sounds[prefix + str(slot)]
			var peak := 0.0
			for sample in range(sound.data.size() / 2):
				peak = maxf(peak, absf(float(sound.data.decode_s16(sample * 2))) / 32767.0)
			check(peak > 0.0 and peak < 0.95, "nonempty sound with sample headroom")
	for slot in range(3):
		game._end_hitstop()
		if paused:
			game.resume_room()
		game.last_combo_impact_ms = -10000
		game.feedback.reset_sword_cues()
		p.position = Vector2(540, 460)
		enemy.position = Vector2(615, 460)
		enemy.guard_time = 0.0
		enemy.guard_cooldown = 10.0
		enemy.thrust_type = true
		enemy.windup = 0.8 if slot == 2 else 0.0
		enemy.lunge_time = 0.0
		sword.swing_time = 0.0
		sword.next_stage = slot
		sword.chain_time = 0.3
		var hp: float = enemy.health
		check(sword.attack(Vector2.RIGHT), "real swing starts")
		for i in range(30):
			if capture and paused:
				game.resume_room()
			await frames(1)
			if enemy.health < hp:
				break
		print("SLOT ", slot, " health=", enemy.health, " player=", p.position, " enemy=", enemy.position, " phase=", game.phase, " paused=", paused)
		check(enemy.health < hp and game.hitstop_active, "real hit starts a stop")
		check(is_equal_approx(game.hitstop_current_duration, CONFIG.COMBO_HITSTOPS[slot]), "exact per-slot duration")
		check(is_equal_approx(enemy.knockback.length(), CONFIG.COMBO_PUSH[slot]), "per-slot knockback")
		check(enemy.visual.melee_flash and enemy.visual.hurt_time > 0.0, "melee white flash active")
		check(game.feedback.shake_direction.x > 0.0 and (slot != 2 or game.feedback.shake_direction.y > 0.0), "directional kick with downward heavy component")
		if slot == 2:
			check(enemy.windup == 0.0 and enemy.v41_heavy_stun > 0.0, "heavy interrupts thrust mob windup")
		if capture:
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(OUT + "combo-%d.png" % (slot + 1)) == OK, "native capture")
			if slot == 2:
				await frames(7)
				await RenderingServer.frame_post_draw
				check(root.get_texture().get_image().save_png(OUT + "combo-3-impact.png") == OK, "native heavy impact peak")
		await create_timer(0.12, false, false, true).timeout
		await frames(60)
		check(not game.hitstop_active, "stop restores time")
		check(p.position.x > 540.0 and p.position.x <= 540.0 + CONFIG.COMBO_LUNGE[slot] + 1.0, "small collision-based forward step")
	# No contact may trigger stop, camera kick or an impact wave.
	for slot in range(3):
		game._end_hitstop()
		game.feedback.reset_sword_cues()
		enemy.position = Vector2(1000, 400)
		sword.swing_time = 0.0
		sword.next_stage = slot
		sword.chain_time = 0.3
		sword.attack(Vector2.LEFT)
		await frames(55)
		check(not game.hitstop_active and game.feedback.shake_strength == 0.0 and game.feedback.slash_impacts.is_empty(), "whiff has no contact feedback")
	game._trigger_combo_hitstop(0.065, 0.12, true, 0)
	game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	var generation: int = game.hitstop_generation
	await create_timer(0.12, true, false, true).timeout
	check(paused and game.hitstop_active and game.hitstop_generation == generation, "focus pause freezes hitstop timer")
	game.resume_room()
	await create_timer(0.10, false, false, true).timeout
	check(not game.hitstop_active and Engine.time_scale == 1.0, "resume safely completes stop")
	game._trigger_combo_hitstop(0.065, 0.12, true, 0)
	game.start_room()
	await create_timer(0.10, true, false, true).timeout
	check(not game.hitstop_active and Engine.time_scale == 1.0, "old timer cannot alter restarted run")
	for slot in range(3):
		game.room_index = 1
		game._enter_room()
		await frames(2)
		var walker = game.player
		walker.gm_invulnerable = true
		walker.position = Vector2(276, 400)
		walker.combo.next_stage = slot
		walker.combo.chain_time = 0.3
		walker.combo.attack(Vector2.LEFT)
		await frames(60)
		check(walker.position.x >= 260.0 and Geometry2D.is_point_in_polygon(walker.position, game.world.walkable), "step cannot cross terrain boundary")
	game.free()
	await frames(2)
	print("MELEE_FEEL checks=", checks, " FAILED=", failures)
	quit(1 if failures else 0)

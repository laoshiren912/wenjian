extends SceneTree

var count := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	count += 1
	if not ok: failures += 1
	printerr("FAIL: " + label) if not ok else print("PASS: " + label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var dual = load("res://scenes/main.tscn").instantiate()
	root.add_child(dual)
	await process_frame
	check(dual.state == SurvivorGame.State.PLAYING and dual.player.dual_attack_enabled and not dual.player.weapon.locked, "single hero floor starts directly")
	check(dual.pending_wave.size() == 4, "single hero keeps first-floor 4+4 spawn")
	dual.player.manuals.append(0)
	dual.player.weapon.swing_time = 0.2
	dual.player.ranged_weapon.swing_time = 0.15
	dual.player.ranged_weapon.cooldown = 0.3
	dual.player.use_manual(0)
	check(dual.player.weapon.swing_time == 0.0 and dual.player.ranged_weapon.swing_time == 0.0 and dual.player.ranged_weapon.cooldown > 0.0, "manual cancels both attack animations without resetting cooldown")
	dual.player._roll_remaining = 0.2
	var press := InputEventAction.new()
	press.action = "attack"
	press.pressed = true
	dual.player._unhandled_input(press)
	check(not dual.player._attack_pending, "single hero does not queue an attack during roll")
	dual.queue_free()
	await process_frame
	var classic = load("res://scenes/main_v31.tscn").instantiate()
	root.add_child(classic)
	await process_frame
	check(classic.v31_classic and classic.state == SurvivorGame.State.START and paused, "V3.1 shows profession selection")
	classic.select_profession(2)
	classic.start_run()
	check(classic.player.profession_index == 2 and classic.player.weapon.locked and not classic.player.dual_attack_enabled, "V3.1 locks selected profession weapon")
	check(classic.pending_wave.is_empty() and get_nodes_in_group("enemies").size() == 8, "V3.1 keeps stationed encounter groups")
	paused = false
	print("MERGE MODES: %d checks, %d failures" % [count, failures])
	quit(0 if failures == 0 else 1)

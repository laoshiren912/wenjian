extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	printerr("FAIL: " + message) if not ok else print("PASS: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	check(ResourceLoader.exists("res://scenes/trigger_room.tscn"), "previous trigger room remains available")
	var room = load("res://scenes/trigger_room.tscn").instantiate()
	root.add_child(room)
	await process_frame
	room.set_physics_process(false)
	room.player.set_physics_process(false)
	check(room.phase == "warning" and room.spawned.size() == 2 and room.total == 6 and room.world.trigger_visible, "two initial enemies and visible trigger")
	room._physics_process(0.61)
	room._physics_process(0.61)
	check(room.phase == "combat" and get_nodes_in_group("enemies").size() == 2, "two enemies activate")
	var first_wave: Array = room.spawned.duplicate()
	for enemy in first_wave:
		enemy.take_damage(10000, Vector2.ZERO)
	await process_frame
	check(room.remaining == 4 and room.phase == "combat" and not room.restart_button.visible, "untriggered enemies prevent early clear")
	room._physics_process(0.1)
	check(not room.trigger_used, "outside trigger does not spawn wave")
	room.player.global_position = room.world.trigger_center
	room._physics_process(0.1)
	check(room.trigger_used and room.phase == "warning" and room.spawned.size() == 4 and not room.world.trigger_visible, "stepping into trigger schedules four")
	var safe := true
	for enemy in room.spawned:
		if enemy.global_position.distance_to(room.player.global_position) < room.SAFE_DISTANCE or enemy.collision_layer != 0 or not enemy.emerging:
			safe = false
		var hp: float = enemy.health
		enemy.take_damage(100, Vector2.ZERO)
		if enemy.health != hp: safe = false
	check(safe, "warning spawns are separated and protected")
	room._physics_process(0.61)
	var blocked: SurvivorEnemy = room.spawned[0]
	room.player.global_position = blocked.global_position
	room._physics_process(0.61)
	check(room.phase == "rising" and blocked.collision_layer == 0, "activation waits if player occupies marker")
	room.player.global_position = room.world.cell_center(Vector2i(15, 15))
	room._physics_process(0.02)
	check(room.phase == "combat" and get_nodes_in_group("enemies").size() == 4, "reinforcements activate after space clears")
	room.player.global_position = room.world.trigger_center
	room._physics_process(0.2)
	check(room.spawned.size() == 4 and room.remaining == 4, "trigger cannot repeat")
	for enemy in room.spawned:
		enemy.take_damage(10000, Vector2.ZERO)
	check(room.phase == "cleared" and room.remaining == 0 and room.restart_button.visible, "last enemy clears room")
	room.start_room()
	room.set_physics_process(false)
	room.player.global_position = room.world.trigger_center
	room._physics_process(0.2)
	room.player.global_position = room.world.cell_center(Vector2i(15, 15))
	room._physics_process(0.5)
	room._physics_process(0.61)
	check(room.trigger_used and room.phase == "warning" and room.spawned.size() == 4, "early trigger is remembered")
	room.start_room()
	check(not room.trigger_used and not room.pending_trigger and room.remaining == 6 and room.spawned.size() == 2, "restart resets trigger and wave")
	print("TRIGGER ROOM: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

extends SceneTree

var game
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	game = load("res://scenes/main_v41.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var p = game.player
	check(OS.is_debug_build() and not p.gm_invulnerable and not p.gm_infinite_stamina, "GM switches default off")
	var key := InputEventKey.new()
	key.keycode = KEY_QUOTELEFT
	key.pressed = true
	game._input(key)
	check(paused and game.hud.modal_panel != null, "backtick panel opens paused")
	game.debug_toggle_invincible()
	var hp: float = p.health
	p.take_damage(12.0, Vector2.RIGHT)
	check(p.gm_invulnerable and is_equal_approx(p.health, hp), "invincible prevents damage")
	game.debug_toggle_invincible()
	check(not p.gm_invulnerable, "invincible toggles off")
	p.stamina = 1.0
	game.debug_fill_stamina()
	check(is_equal_approx(p.stamina, p.max_stamina), "refill stamina")
	game.debug_toggle_stamina()
	p.stamina = 1.0
	check(p.spend_stamina(15.0) and is_equal_approx(p.stamina, 1.0), "infinite stamina prevents spending")
	game.debug_toggle_stamina()
	check(not p.spend_stamina(15.0), "normal stamina enforced when off")
	var before := get_nodes_in_group("enemies").size()
	game.debug_spawn(0, 2)
	check(get_nodes_in_group("enemies").size() == before + 2, "spawn two melee")
	game.debug_spawn(1, 1)
	var guard = game.gm_spawned.back()
	check(guard.guard_time > 0.0 and guard.guard_visual_time > 0.0, "spawn guard with shield raised")
	game.debug_spawn(2, 1)
	check(game.gm_spawned.back().kind == SurvivorEnemy.Kind.RANGED, "spawn ranged")
	game.debug_spawn(3, 1)
	check(game.gm_spawned.back().kind == SurvivorEnemy.Kind.BOSS, "spawn boss")
	game.debug_clear_enemies()
	check(get_nodes_in_group("enemies").all(func(e): return e.dead), "clear all current enemies")
	game.debug_jump(6)
	check(game.room_index == 6 and is_instance_valid(game.boss), "jump to boss room")
	game.debug_jump(2)
	check(game.room_index == 2 and game.phase == "combat", "jump to combat room")
	game.debug_close()
	check(not paused, "close GM panel resumes")
	print("V41 GM: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures else 0)

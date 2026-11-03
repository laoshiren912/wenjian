extends "res://scripts/room_game.gd"

const COMBO_PLAYER = preload("res://scenes/player_combo.tscn")
const FOUR_CELLS: Array[Vector2i] = [Vector2i(22, 14), Vector2i(24, 15), Vector2i(25, 13), Vector2i(26, 16)]

func _create_player() -> SurvivorPlayer:
	return COMBO_PLAYER.instantiate()

func start_room() -> void:
	super.start_room()
	total = 4
	remaining = 4
	triggered_count = 4
	# Hide the old trigger drawing. This scene never executes trigger spawning.
	world.triggered.fill(true)
	for cell in FOUR_CELLS:
		var enemy: SurvivorEnemy = ENEMY.instantiate()
		enemy.world = world
		enemy.kind = SurvivorEnemy.Kind.HOSTILE
		enemy.dodge_enabled = false
		enemy.collision_mask = 1 | 2 | 4
		enemy.position = world.cell_center(cell)
		enemy.killed.connect(_on_enemy_killed)
		enemy.damaged.connect(func(point: Vector2, amount: float): feedback.show_damage(point, amount, false))
		world.actors.add_child(enemy)
	player.weapon.heavy_hit.connect(func(): feedback.shake_strength = maxf(feedback.shake_strength, 6.0))
	_update_status()
	hud.update_room(remaining, total, triggered_count)
	world.queue_redraw()

func _physics_process(_delta: float) -> void:
	if get_tree().paused or phase != "combat":
		return
	if world.portal_open and player.global_position.distance_to(world.cell_center(world.PORTAL_CELL)) < 34.0:
		phase = "cleared"
		_show_result(true)

func _update_status() -> void:
	status.text = "敌人已清除 · 前往右侧传送点" if world.portal_open else "清除四只近战怪 · 点击左键衔接三段剑击"

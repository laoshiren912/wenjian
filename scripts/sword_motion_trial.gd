extends "res://scripts/combo_room.gd"

func _create_player() -> SurvivorPlayer:
	return preload("res://scenes/player_sword_motion.tscn").instantiate()

func start_room() -> void:
	super.start_room()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.free()
	total = 0
	remaining = 0
	player.position = world.cell_center(Vector2i(19, 14))
	$Camera2D.position = player.position
	$Camera2D.zoom = Vector2.ONE * 1.8
	_update_status()
	hud.update_room(remaining, total, triggered_count)

func _physics_process(_delta: float) -> void:
	if is_instance_valid(player):
		$Camera2D.position = player.position

func _update_status() -> void:
	status.text = "空场观察 · 鼠标朝任意方向 · 短按连击 / 长按蓄力"

func _exit_tree() -> void:
	Engine.time_scale = 1.0

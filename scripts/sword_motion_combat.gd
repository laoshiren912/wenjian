extends "res://scripts/combo_room.gd"

func _create_player() -> SurvivorPlayer:
	return preload("res://scenes/player_sword_motion.tscn").instantiate()

func start_room() -> void:
	super.start_room()
	player.weapon.heavy_hit.connect(func():
		feedback.shake_strength = maxf(feedback.shake_strength, 9.0 if player.combo.charged_swing else 6.0)
		feedback.shake_time = maxf(feedback.shake_time, 0.18))

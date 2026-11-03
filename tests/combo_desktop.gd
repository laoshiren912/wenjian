extends SceneTree

# Observe OS-input sessions without changing combat stats, positions or AI.
func _initialize() -> void:
	start.call_deferred()

func start() -> void:
	var game = load("res://scenes/main_v33.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.player.weapon.attack_started.connect(func(_index: int, _direction: Vector2): print("DESKTOP SWORD stage=%d" % [game.player.weapon.stage + 1]))
	game.player.ranged_weapon.attack_started.connect(func(_index: int, _direction: Vector2): print("DESKTOP BOW"))
	game.player.damage_received.connect(func(amount: float): print("DESKTOP HURT %.0f" % amount))

extends SceneTree

# Diagnostic for OS-level injected keys, not a normal-difficulty playthrough.
class KeyProbe extends Node:
	func _input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed:
			print("DESKTOP KEY code=%d physical=%d stats=%s pause=%s" % [event.keycode, event.physical_keycode, event.is_action_pressed("stats"), event.is_action_pressed("pause")])

func _initialize() -> void:
	start.call_deferred()

func start() -> void:
	var game = load("res://scenes/main_v32.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var probe := KeyProbe.new()
	probe.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(probe)

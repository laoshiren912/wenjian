extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)

func find_button(node: Node, fragment: String) -> Button:
	if node is Button and fragment in node.text:
		return node
	for child in node.get_children():
		var found := find_button(child, fragment)
		if found != null:
			return found
	return null

func find_label(node: Node, fragment: String) -> bool:
	if node is Label and fragment in node.text:
		return true
	for child in node.get_children():
		if find_label(child, fragment):
			return true
	return false

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for dimensions in [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1024, 768), Vector2i(1920, 1080)]:
		root.size = dimensions
		var game = load("res://scenes/main.tscn").instantiate()
		root.add_child(game)
		await process_frame
		game.start_run()
		game.player.gain_experience(game.player.next_level_xp)
		await process_frame
		await process_frame
		check(game.state == game.State.PLAYING and not paused and game.player.skill_points == 1, "level grants skill point without pausing")
		game.state = game.State.SHOP
		paused = true
		game.show_shop()
		await process_frame
		check(game.hud.modal_panel.size.x <= game.hud.root.size.x and game.hud.modal_panel.size.y <= game.hud.root.size.y, "shop panel fits %s" % dimensions)
		check(find_button(game.hud.modal_panel, "长锋石") != null, "AD listing")
		var ap := find_button(game.hud.modal_panel, "AP（未开放）")
		ap.pressed.emit()
		check(find_label(game.hud.modal_panel, "技能系统尚未实现"), "AP unavailable explanation")
		find_button(game.hud.modal_panel, "防御").pressed.emit()
		await process_frame
		check(find_button(game.hud.modal_panel, "守护甲") != null, "defense listing")
		check(game.hud.modal_panel.size.y <= game.hud.root.size.y, "defense panel fits")
		find_button(game.hud.modal_panel, "机动").pressed.emit()
		await process_frame
		check(find_button(game.hud.modal_panel, "轻行靴") != null, "mobility listing")
		check(game.hud.modal_panel.size.y <= game.hud.root.size.y, "mobility panel fits")
		game.gold = 0
		game.show_shop()
		find_button(game.hud.modal_panel, "轻行靴").pressed.emit()
		game.hud.shop_buy_button.pressed.emit()
		check(find_label(game.hud.modal_panel, "金币不足"), "insufficient funds visible")
		paused = false
		game.queue_free()
		await process_frame
	print("ECONOMY UI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

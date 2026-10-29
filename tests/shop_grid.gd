extends SceneTree

# Controlled shop fixture: no claims about natural battle or balance.
var checks := 0
var failures := 0
func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + description)
func button_containing(node: Node, text: String) -> Button:
	if node is Button and text in node.text:
		return node
	for child in node.get_children():
		var found := button_containing(child, text)
		if found:
			return found
	return null
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	for dimensions in [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1024, 768), Vector2i(1920, 1080)]:
		root.size = dimensions
		var game = load("res://scenes/main.tscn").instantiate()
		root.add_child(game)
		current_scene = game
		await process_frame
		game.start_run()
		game.state = game.State.SHOP
		paused = true
		game.show_shop()
		await process_frame
		await process_frame
		if OS.get_cmdline_user_args().has("--desktop"):
			root.title = "Shop Grid Review"
			print("SHOP GRID READY: controlled fixture; no natural battle")
			await create_timer(90.0, true).timeout
			quit()
			return
		var hud = game.hud
		check(hud.shop_grid.get_child_count() == 9, "all equipment visible at %s" % dimensions)
		var bounds := Rect2(Vector2.ZERO, hud.root.size).grow(1.0)
		check(bounds.encloses(hud.modal_panel.get_global_rect()), "shop fits %s" % dimensions)
		var original_gold: int = game.gold
		button_containing(hud.modal_panel, "猎手护符").pressed.emit()
		check(game.gold == original_gold and hud.shop_selected == 1 and not game.purchased[1], "selecting does not purchase")
		check(hud.shop_detail.get_child(1).text == "猎手护符", "detail follows selection")
		hud.shop_buy_button.pressed.emit()
		check(game.gold == original_gold - 250 and game.purchased[1] and hud.shop_selected == 1, "explicit purchase preserves selection")
		check(hud.shop_buy_button.disabled, "purchased item cannot be bought again")
		button_containing(hud.modal_panel, "破阵徽章").pressed.emit()
		hud.shop_buy_button.pressed.emit()
		check(not game.purchased[2] and game.gold == 50, "insufficient funds does not purchase")
		check(button_containing(hud.modal_panel, "进入下一层") != null, "next floor remains available")
		game.select_shop_category(1)
		check(hud.shop_grid.get_child_count() == 0 and hud.shop_buy_button == null, "AP has no purchasable equipment")
		game.select_shop_category(2)
		check(hud.shop_grid.get_child_count() == 3 and hud.shop_selected == 3, "defense filter selects valid item")
		game.select_shop_category(3)
		check(hud.shop_grid.get_child_count() == 3 and hud.shop_selected == 6, "mobility filter selects valid item")
		game.select_shop_category(4)
		check(hud.shop_grid.get_child_count() == 9, "all filter restores nine items")
		paused = false
		game.queue_free()
		await process_frame
	print("SHOP GRID: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

extends "res://scripts/charged_hud.gd"

func _ready() -> void:
	super._ready()
	var center := CenterContainer.new()
	root.add_child(center)
	root.move_child(center, 0)
	center.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	center.position.y = 112
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar := HBoxContainer.new()
	center.add_child(bar)
	var slow := PrototypeUI.button("慢动作 ×0.45", func(): Engine.time_scale = 0.45, 34)
	var normal := PrototypeUI.button("正常速度", func(): Engine.time_scale = 1.0, 34)
	var combat := PrototypeUI.button("四怪实战 →", func():
		get_tree().paused = false
		Engine.time_scale = 1.0
		get_tree().change_scene_to_file("res://scenes/sword_motion_combat.tscn"), 34)
	for button in [slow, normal, combat]:
		button.focus_mode = Control.FOCUS_NONE
		bar.add_child(button)
	root.move_child(overlay, root.get_child_count() - 1)

func update_room(remaining: int, total: int, triggered: int) -> void:
	super.update_room(remaining, total, triggered)
	timer_text.text = "挥剑动作样板"
	status_text.text = "空场观察 · 鼠标朝任意方向 · 短按连击 / 长按蓄力"

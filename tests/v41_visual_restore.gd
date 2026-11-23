extends SceneTree

const SLASH = preload("res://assets/shaders/v41_combo_slash.gdshader")
const GROUND = preload("res://assets/shaders/v41_bagua_seal.gdshader")
const FEEDBACK = preload("res://scripts/v41_feedback.gd")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	if DisplayServer.get_name() == "headless":
		print("VISUAL_RESTORE SKIP: requires GL rendering; verified in native paired captures")
		quit(0)
		return
	var output := "res://artifacts/runtime/visual-restore/current/"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	var tex_image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	tex_image.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(tex_image)
	var failures := 0
	for rank in range(3):
		for slot in range(3):
			var viewport := SubViewport.new()
			viewport.size = Vector2i(384, 256)
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			root.add_child(viewport)
			var background := ColorRect.new()
			background.color = Color("eeeeec")
			background.size = Vector2(384, 256)
			viewport.add_child(background)
			var mat := ShaderMaterial.new()
			mat.shader = SLASH
			mat.set_shader_parameter("rank_stage", rank)
			mat.set_shader_parameter("combo_slot", slot)
			mat.set_shader_parameter("slash_progress", 0.65)
			mat.set_shader_parameter("half_arc", [1.12, 1.24, 0.92][slot])
			mat.set_shader_parameter("pixel_grid", 100.0)
			var blade := Sprite2D.new()
			blade.texture = texture
			blade.material = mat
			blade.position = Vector2(125, 90)
			blade.scale = Vector2(170, 170)
			viewport.add_child(blade)
			var ground_mat := ShaderMaterial.new()
			ground_mat.shader = GROUND
			ground_mat.set_shader_parameter("effect_mode", 1)
			ground_mat.set_shader_parameter("progress", 0.40)
			ground_mat.set_shader_parameter("primary_color", [Color("d6e6f5"), Color("55e8e3"), Color("44cfff")][rank])
			ground_mat.set_shader_parameter("core_color", Color.WHITE)
			var ground := Sprite2D.new()
			ground.texture = texture
			ground.material = ground_mat
			ground.position = Vector2(125, 200)
			ground.scale = Vector2(100, 100)
			viewport.add_child(ground)
			var feedback := FEEDBACK.new()
			viewport.add_child(feedback)
			feedback.set_process(false)
			feedback.set_physics_process(false)
			feedback._spawn_slash_impact("hit", Vector2(285, 100), Vector2.RIGHT, slot, rank)
			feedback.slash_impacts.back().age = 0.06
			feedback.queue_redraw()
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			if viewport.get_texture().get_image().save_png(output.path_join("%d-%d.png" % [rank, slot])) != OK:
				failures += 1
			viewport.free()
	print("VISUAL_RESTORE captures=9 FAILED=", failures)
	quit(1 if failures else 0)

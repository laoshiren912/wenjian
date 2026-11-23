extends RefCounted

# No input, project setting, user argument or headless flag can enable this.
# Only an explicit SceneTree test script can inject state; tests are not exported.
static func enabled() -> bool:
	if not OS.is_debug_build():
		return false
	var tree := Engine.get_main_loop()
	if tree == null:
		return false
	var script: Script = tree.get_script()
	return script != null and script.resource_path.begins_with("res://tests/")

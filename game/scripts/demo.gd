## Self-run demo for screenshots: `godot --path game -- --demo=<dir> [--name=Captain]`.
## Each scene asks `Demo.active()` and, if set, performs its step and saves `<dir>/<n>-<name>.png`.
class_name Demo
extends RefCounted


static func arg(key: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + key + "="):
			return a.substr(key.length() + 3)
	return ""


static func active() -> bool:
	return not arg("demo").is_empty()


static func shot(node: Node, file: String) -> void:
	await RenderingServer.frame_post_draw
	var img := node.get_viewport().get_texture().get_image()
	var path := arg("demo").path_join(file + ".png")
	img.save_png(path)
	print("demo: saved ", path)

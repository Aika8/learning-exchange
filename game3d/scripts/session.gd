## Session service (autoload): server address from the command line, scene changes with a fade, the fps overlay
## and the self-run demo used for screenshots: `godot --path game3d -- --server=http://localhost:8090 --demo=<dir>`.
extends Node

var _fade: ColorRect
var _fps: Label
var _layer: CanvasLayer
var spawn: String = "start"  ## where the harbour places the captain: start | pier | exchange


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var server := arg("server")
	if not server.is_empty():
		ExchangeApi.base_url = server.trim_suffix("/") + "/api/v1"
		MarketStream.url = server.trim_suffix("/").replace("http", "ws") + "/ws"
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)
	_fade = ColorRect.new()
	_fade.color = Color(Hud.INK, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_fade)
	_fps = Hud.text("", 14, Hud.MUTED)
	_fps.position = Vector2(12, 8)
	_fps.visible = active() or not arg("fps").is_empty()
	_layer.add_child(_fps)
	if not arg("audit").is_empty():
		Audit.run.call_deferred(get_tree())
	elif not arg("views").is_empty():
		Audit.views.call_deferred(get_tree())
	elif not arg("fps").is_empty() and arg("fps") != "1":
		Audit.fps.call_deferred(get_tree())
	elif not arg("profile").is_empty():
		Audit.profile.call_deferred(get_tree())
	elif not arg("people").is_empty():
		Audit.people.call_deferred(get_tree())
	elif not arg("gait").is_empty():
		Audit.gait.call_deferred(get_tree())


func _process(_delta: float) -> void:
	if _fps.visible:
		_fps.text = tr("FPS") % str(Engine.get_frames_per_second())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fps"):
		_fps.visible = not _fps.visible


func go(scene: String) -> void:
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, 0.35)
	await t.finished
	get_tree().change_scene_to_file("res://scenes/%s.tscn" % scene)
	await get_tree().process_frame
	var back := create_tween()
	back.tween_property(_fade, "color:a", 0.0, 0.5)


static func arg(key: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + key + "="):
			return a.substr(key.length() + 3)
		if a == "--" + key:
			return "1"
	return ""


## True for the audit, views and gait runs: no mouse capture, the scripts drive the scene.
static func tooling() -> bool:
	return not (arg("audit") + arg("views") + arg("gait") + arg("profile") + arg("people")).is_empty() or arg("fps").length() > 1


static func active() -> bool:
	return not arg("demo").is_empty()


func shot(node: Node, file: String) -> void:
	# wait for a drawn frame, but never hang if the OS stops drawing a hidden window
	var drawn := [false]
	RenderingServer.frame_post_draw.connect(func() -> void: drawn[0] = true, CONNECT_ONE_SHOT)
	for i in 60:
		if drawn[0]:
			break
		await get_tree().create_timer(0.05).timeout
	var img := node.get_viewport().get_texture().get_image()
	var path := arg("demo").path_join(file + ".png")
	img.save_png(path)
	print("demo: saved ", path, " fps=", Engine.get_frames_per_second())


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

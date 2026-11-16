## Session service (autoload): server address from the command line, scene changes with a fade, the fps overlay
## and the self-run demo used for screenshots: `godot --path game3d -- --server=http://localhost:8090 --demo=<dir>`.
extends Node

var _fade: ColorRect
var _fps: Label
var _layer: CanvasLayer
var ink_mode := 1  ## the ink post-effect: 0 off, 1 outline, 2 engraving (ADR-0024); V switches it
var ink_limit := 2
var _ink: MeshInstance3D
var _ink_label: Label
var spawn: String = "start"  ## where the harbour places the captain: start | pier | exchange


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var server := arg("server")
	if not server.is_empty():
		ExchangeApi.base_url = server.trim_suffix("/") + "/api/v1"
		MarketStream.url = server.trim_suffix("/").replace("http", "ws") + "/ws"
	_build_ink()
	if Assets.available() and Assets.person("sailor") == null:
		push_warning("The MakeHuman people are not in game3d/assets/models/people (make assets cannot download them): stand-in figures are shown. See game3d/ASSETS.md.")
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
	elif event.is_action_pressed("toggle_ink"):
		set_ink((ink_mode + 1) % 3)
		_ink_label.text = ["INK_OFF", "INK_OUTLINE", "INK_ENGRAVING"][ink_mode]
		_ink_label.modulate.a = 1.0
		create_tween().tween_property(_ink_label, "modulate:a", 0.0, 0.6).set_delay(1.2)


## The ink post-effect: one quad in front of every camera of the game (ADR-0024).
func _build_ink() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/ink.gdshader")
	m.render_priority = 100
	_ink = MeshInstance3D.new()
	_ink.name = "Ink"
	_ink.mesh = quad
	_ink.material_override = m
	_ink.extra_cull_margin = 16384.0
	_ink.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ink.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(_ink)
	_ink_label = Hud.text("", 20, Hud.BRASS)
	_ink_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_ink_label.position = Vector2(-80, 60)
	_ink_label.modulate.a = 0.0
	_layer_ready.call_deferred()
	if not arg("ink").is_empty():
		ink_mode = clampi(int(arg("ink")), 0, 2)
	set_ink(ink_mode)


func _layer_ready() -> void:
	_layer.add_child(_ink_label)


func set_ink(mode: int) -> void:
	ink_mode = mode
	var shown := mini(mode, ink_limit)
	_ink.visible = shown > 0
	(_ink.material_override as ShaderMaterial).set_shader_parameter("mode", shown)


## A scene that must stay readable in colour (the Exchange hall: bid and ask on the board) caps the effect at the
## outline while it is open; 2 lifts the cap.
func limit_ink(limit: int) -> void:
	ink_limit = limit
	set_ink(ink_mode)


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

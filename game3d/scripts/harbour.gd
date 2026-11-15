## Spark Harbour in 3D: walk the captain (WASD + mouse) or fly the camera (Tab). E near the windmill enters the
## Exchange hall, near the pier sets sail for Silk Reach, near Mara starts her line.
extends Node3D

var _captain: Captain
var _fly: Camera3D
var _flying := false
var _prompt: Label
var _help: Label
var _dialog: PanelContainer
var _account: Label
var _parts: Dictionary
var _target := ""
var _fly_yaw := 0.0
var _fly_pitch := -0.3


func _ready() -> void:
	Archipelago.sky(self)
	_parts = Archipelago.build(self)
	var ship := Proc.ship()
	ship.name = "Wayfarer"
	ship.position = Archipelago.PIER_END + Vector3(0, 1.2, 4.5)
	ship.rotation.y = PI / 2
	add_child(ship)
	var mara := Proc.figure(Color("7a4e8a"), Color("2a3550"))
	mara.position = Archipelago.MARA_POS
	mara.rotation.y = -PI / 2
	add_child(mara)
	_captain = Captain.new()
	add_child(_captain)
	match Session.spawn:
		"pier":
			_captain.position = Archipelago.PIER_END + Vector3(-6, 0.5, 0)
			_captain.yaw = PI / 2
		"exchange":
			_captain.position = Archipelago.EXCHANGE_DOOR + Vector3(0, 0.5, 3)
			_captain.yaw = 0.0
		_:
			_captain.position = Vector3(6, 0.5, 10)
			_captain.yaw = 0.5
	_fly = Camera3D.new()
	_fly.fov = 65
	add_child(_fly)
	_build_ui()
	if not Session.active():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		_demo()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.theme = Hud.theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 28
	top.offset_right = -28
	top.offset_top = 30
	root.add_child(top)
	var titles := VBoxContainer.new()
	var title := Hud.text("HARBOUR_TITLE", 40, Hud.BRASS)
	title.add_theme_font_override("font", Hud.serif())
	titles.add_child(title)
	_account = Hud.text("", 16, Hud.TEXT)
	titles.add_child(_account)
	top.add_child(titles)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	top.add_child(Hud.lang_switch())
	_prompt = Hud.text("", 24, Hud.TEXT)
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.offset_top = -170
	_prompt.offset_left = -400
	_prompt.offset_right = 400
	root.add_child(_prompt)
	_help = Hud.text("HARBOUR_HELP", 15, Hud.MUTED)
	_help.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_help.offset_left = 28
	_help.offset_top = -44
	root.add_child(_help)
	var line := Hud.text("HARBOUR_MARA", 19)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD
	line.custom_minimum_size = Vector2(760, 0)
	_dialog = Hud.panel(line)
	_dialog.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_dialog.offset_left = -400
	_dialog.offset_right = 400
	_dialog.offset_top = -320
	_dialog.offset_bottom = -200
	_dialog.visible = false
	root.add_child(_dialog)
	Locale.locale_changed.connect(_on_locale)
	_on_locale("")


func _on_locale(_code: String) -> void:
	_account.text = tr("HARBOUR_ACCOUNT") % [ExchangeApi.account.get("name", "—"), ExchangeApi.account.get("accountId", "—")]


func _process(delta: float) -> void:
	var blades: Node3D = _parts.get("blades")
	if blades:
		blades.rotation.z += delta * 0.5
	var ship: Node3D = get_node_or_null("Wayfarer")
	if ship:
		ship.position.y = Archipelago.PIER_END.y + 1.2 + sin(Time.get_ticks_msec() * 0.0012) * 0.25
	if _flying:
		_fly_move(delta)
	_target = _nearest()
	var keys := {"exchange": "PROMPT_EXCHANGE", "ship": "PROMPT_SHIP", "mara": "PROMPT_MARA"}
	_prompt.text = keys.get(_target, "")
	if _target != "mara":
		_dialog.visible = false


func _nearest() -> String:
	if _flying:
		return ""
	var p := _captain.global_position
	if p.distance_to(Archipelago.EXCHANGE_DOOR) < 5.0:
		return "exchange"
	if p.distance_to(Archipelago.PIER_END) < 9.0:
		return "ship"
	if p.distance_to(Archipelago.MARA_POS) < 4.0:
		return "mara"
	return ""


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("toggle_camera"):
		set_flying(not _flying)
	elif event.is_action_pressed("interact"):
		interact()
	elif _flying and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var m := event as InputEventMouseMotion
		_fly_yaw -= m.relative.x * 0.004
		_fly_pitch = clampf(_fly_pitch - m.relative.y * 0.003, -1.4, 1.4)


func set_flying(on: bool) -> void:
	_flying = on
	_captain.controlled = not on
	if on:
		_fly.global_transform = _captain.camera.global_transform
		_fly_yaw = _fly.rotation.y
		_fly_pitch = _fly.rotation.x
		_fly.current = true
		_help.text = "HARBOUR_FLY"
	else:
		_captain.camera.current = true
		_help.text = "HARBOUR_HELP"


func _fly_move(delta: float) -> void:
	_fly.rotation = Vector3(_fly_pitch, _fly_yaw, 0)
	var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var up := float(Input.is_key_pressed(KEY_SPACE)) - float(Input.is_key_pressed(KEY_SHIFT))
	var speed := 30.0 if Input.is_key_pressed(KEY_CTRL) else 14.0
	_fly.position += (_fly.basis * Vector3(v.x, 0, v.y) + Vector3.UP * up) * speed * delta


func interact() -> void:
	match _target:
		"exchange":
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			Session.go("hall")
		"ship":
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			Session.go("voyage")
		"mara":
			_dialog.visible = not _dialog.visible


func _demo() -> void:
	if Session.spawn == "exchange":  # second visit in the demo: back from the hall, go to the ship
		await Session.wait(1.0)
		_captain.position = Archipelago.PIER_END + Vector3(-5, 0.5, 0)
		await Session.wait(0.4)
		interact()
		return
	await Session.wait(2.0)
	await Session.shot(self, "3-harbour-walk")
	_captain.position = Archipelago.MARA_POS + Vector3(-2.5, 0.5, 1)
	_captain.yaw = 1.9
	_captain.pitch = -0.2
	await Session.wait(0.6)
	interact()
	await Session.wait(1.6)  # let the 1-second fps average settle after the teleport
	await Session.shot(self, "4-harbour-mara")
	set_flying(true)
	_fly.position = Vector3(70, 26, 48)
	_fly.look_at(Vector3(5, 4, -8))
	_fly_yaw = _fly.rotation.y
	_fly_pitch = _fly.rotation.x
	await Session.wait(1.0)
	await Session.shot(self, "5-harbour-fly")
	set_flying(false)
	_captain.position = Archipelago.EXCHANGE_DOOR + Vector3(0, 0.5, 2)
	await Session.wait(0.3)
	interact()

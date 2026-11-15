## Main menu over a live 3D view of the archipelago: captain's name (= exchange account), ru/en on the fly, set sail.
extends Node3D

var _name_edit: LineEdit
var _status: Label
var _start: Button
var _cam: Camera3D
var _parts: Dictionary
var _t := 0.0


func _ready() -> void:
	Archipelago.sky(self)
	_parts = Archipelago.build(self)
	var ship := Proc.ship()
	ship.position = Archipelago.PIER_END + Vector3(0, 1.2, 0)
	ship.rotation.y = PI / 2
	add_child(ship)
	_cam = Camera3D.new()
	_cam.fov = 55
	add_child(_cam)
	_ui()
	if Session.active():
		_demo()


func _process(delta: float) -> void:
	_t += delta
	var a := 0.9 + _t * 0.035
	_cam.position = Vector3(cos(a) * 95, 34 + sin(_t * 0.2) * 3, sin(a) * 95) + Vector3(10, 0, 0)
	_cam.look_at(Vector3(18, 2, -4))
	var blades: Node3D = _parts.get("blades")
	if blades:
		blades.rotation.z += delta * 0.4


func _ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.theme = Hud.theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.position = Vector2(110, 210)
	box.custom_minimum_size = Vector2(560, 0)
	root.add_child(box)
	var title := Hud.text("GAME_TITLE", 74, Hud.BRASS)
	title.add_theme_font_override("font", Hud.serif())
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.12, 0.55))
	box.add_child(title)
	box.add_child(Hud.text("GAME_SUBTITLE3D", 22, Hud.TEXT))
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 10)
	box.add_child(Hud.panel(card))
	card.add_child(Hud.text("MENU_NAME", 16, Hud.MUTED))
	_name_edit = LineEdit.new()
	_name_edit.text = Session.arg("name") if not Session.arg("name").is_empty() else "Captain"
	_name_edit.max_length = 32
	card.add_child(_name_edit)
	_start = Hud.button("MENU_START")
	_start.name = "Start"
	_start.custom_minimum_size = Vector2(0, 52)
	_start.pressed.connect(_on_start)
	card.add_child(_start)
	var quit := Hud.button("MENU_QUIT")
	quit.pressed.connect(func() -> void: get_tree().quit())
	card.add_child(quit)
	card.add_child(Hud.lang_switch())
	var server := Hud.text("", 13, Hud.MUTED)
	server.text = tr("MENU_SERVER") % ExchangeApi.base_url
	Locale.locale_changed.connect(func(_c: String) -> void: server.text = tr("MENU_SERVER") % ExchangeApi.base_url)
	card.add_child(server)
	_status = Hud.text("", 16, Hud.ASK)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	card.add_child(_status)


func _on_start() -> void:
	_start.disabled = true
	_status.text = "MENU_LOGGING_IN"
	var r: Dictionary = await ExchangeApi.login(_name_edit.text.strip_edges())
	_start.disabled = false
	if not r["ok"]:
		_status.text = "ERR_" + str(r["code"])
		return
	Session.spawn = "start"
	Session.go("harbour")


func _demo() -> void:
	await Session.wait(2.5)
	await Session.shot(self, "1-menu-ru")
	Locale.set_locale("en")
	await Session.wait(0.4)
	await Session.shot(self, "2-menu-en")
	Locale.set_locale("ru")
	_on_start()

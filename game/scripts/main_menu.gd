## Main menu: captain's name (= exchange account), language switch on the fly, set sail.
extends Control

var _name_edit: LineEdit
var _status: Label
var _start: Button


func _ready() -> void:
	theme = UI.theme()
	add_child(SkyBackdrop.new())
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(460, 0)
	box.position = Vector2(-230, -230)
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	box.add_child(UI.label("GAME_TITLE", 44, UI.BRASS))
	box.add_child(UI.label("GAME_SUBTITLE", 15, UI.TEXT))
	box.add_child(UI.label("MENU_NAME", 15, UI.MUTED))
	_name_edit = LineEdit.new()
	_name_edit.text = Demo.arg("name") if not Demo.arg("name").is_empty() else "Captain"
	_name_edit.max_length = 32
	box.add_child(_name_edit)
	_start = UI.button("MENU_START")
	_start.name = "Start"
	_start.pressed.connect(_on_start)
	box.add_child(_start)
	var quit := UI.button("MENU_QUIT")
	quit.pressed.connect(func() -> void: get_tree().quit())
	box.add_child(quit)
	box.add_child(UI.lang_switch())
	_status = UI.label("", 15, UI.ASK)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(_status)
	if Demo.active():
		_demo()


func _on_start() -> void:
	_start.disabled = true
	_status.text = "MENU_LOGGING_IN"
	var r := await ExchangeApi.login(_name_edit.text.strip_edges())
	_start.disabled = false
	if not r["ok"]:
		_status.text = "ERR_" + str(r["code"])
		return
	get_tree().change_scene_to_file("res://scenes/harbour.tscn")


func _demo() -> void:
	await get_tree().create_timer(0.6).timeout
	await Demo.shot(self, "1-menu-ru")
	Locale.set_locale("en")
	await get_tree().create_timer(0.3).timeout
	await Demo.shot(self, "2-menu-en")
	Locale.set_locale("ru")
	_on_start()

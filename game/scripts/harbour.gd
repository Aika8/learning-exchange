## Spark Harbour: the first place of the world. Mara introduces the Ladder by its real name (ADR-0012).
extends Control

var _account: Label


func _ready() -> void:
	theme = UI.theme()
	add_child(SkyBackdrop.new())
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 20
	top.offset_right = -20
	top.offset_top = 14
	add_child(top)
	top.add_child(UI.label("HARBOUR_TITLE", 30, UI.BRASS))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	top.add_child(UI.lang_switch())
	_account = UI.label("", 15, UI.MUTED)
	_account.position = Vector2(22, 60)
	add_child(_account)

	var dialog := VBoxContainer.new()
	dialog.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	dialog.offset_left = 40
	dialog.offset_right = -40
	dialog.offset_top = -170
	dialog.offset_bottom = -24
	add_child(dialog)
	var line := UI.label("HARBOUR_MARA", 18)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD
	dialog.add_child(UI.panel(line))
	var buttons := HBoxContainer.new()
	dialog.add_child(buttons)
	var go := UI.button("HARBOUR_TO_EXCHANGE")
	go.name = "ToExchange"
	go.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/ladder.tscn"))
	buttons.add_child(go)
	var back := UI.button("HARBOUR_BACK")
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	buttons.add_child(back)
	Locale.locale_changed.connect(func(_c: String) -> void: _refresh())
	_refresh()
	if Demo.active():
		await get_tree().create_timer(0.8).timeout
		await Demo.shot(self, "3-harbour")
		go.pressed.emit()


func _refresh() -> void:
	_account.text = tr("HARBOUR_ACCOUNT") % [ExchangeApi.account.get("name", "—"), ExchangeApi.account.get("accountId", "—")]

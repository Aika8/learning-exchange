## The Exchange hall inside the windmill: the live order book glows on a 3D board; the order ticket, balances,
## my orders and the trade tape are a HUD. Scenes never touch the socket or HTTP — only the autoloads do.
extends Node3D

const INSTRUMENT := "SILK-SPARK"

var _board: Board
var _cam: Camera3D
var _yaw := 0.0
var _pitch := -0.08
var _dist := 15.0
var _book: BookModel = BookModel.new()
var _last_trade := -1
var _draft := OrderDraft.new()
var _ui: Dictionary = {}
var _details: Dictionary = {}
var _orders: Array = []
var _tape: Array = []
var _live: Label


func _ready() -> void:
	Archipelago.sky(self, true)
	_room()
	_board = Board.new()
	_board.position = Vector3(0, 0.6, -9.0)
	add_child(_board)
	_cam = Camera3D.new()
	_cam.fov = 58
	add_child(_cam)
	_build_ui()
	MarketStream.book_received.connect(_on_book)
	MarketStream.trades_received.connect(_on_trades)
	MarketStream.account_changed.connect(func(_r: Array) -> void: ExchangeApi.refresh_account())
	MarketStream.connection_changed.connect(_on_live)
	ExchangeApi.account_updated.connect(_on_account)
	ExchangeApi.orders_updated.connect(_on_orders)
	Locale.locale_changed.connect(_on_locale)
	var ch: Array[String] = ["market.%s.book" % INSTRUMENT, "market.%s.trades" % INSTRUMENT, "clock"]
	if ExchangeApi.account.has("accountId"):
		ch.append("account.%s" % ExchangeApi.account["accountId"])
	MarketStream.open(ExchangeApi.token, ch)
	ExchangeApi.refresh_account()
	_on_live(MarketStream.is_live())
	_redraw()
	if Session.active():
		_demo()


func _exit_tree() -> void:
	MarketStream.close()


func _room() -> void:
	var floor_mesh := CylinderMesh.new()
	floor_mesh.top_radius = 14.0
	floor_mesh.bottom_radius = 14.0
	floor_mesh.height = 0.4
	floor_mesh.radial_segments = 24
	add_child(Proc.mesh_node(floor_mesh, Proc.mat(Color("6b4a33")), Vector3(0, -0.2, 0)))
	for i in 12:  # floor planks ring
		var a := TAU * i / 12.0
		var plank := Proc.box(Vector3(0.12, 0.02, 13.0), Color("4e3424"), Vector3(sin(a) * 6.5, 0.01, cos(a) * 6.5))
		plank.rotation.y = a
		add_child(plank)
	var wall := CylinderMesh.new()
	wall.top_radius = 13.0
	wall.bottom_radius = 14.0
	wall.height = 16.0
	wall.radial_segments = 24
	wall.cap_top = false
	wall.cap_bottom = false
	var wall_mat := Proc.mat(Color("d8c4a2")).duplicate() as StandardMaterial3D
	wall_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	add_child(Proc.mesh_node(wall, wall_mat, Vector3(0, 8.0, 0)))
	var ceiling := Proc.cyl(13.0, 13.0, 0.4, 24, Color("5e3b28"), Vector3(0, 16.0, 0))
	add_child(ceiling)
	for i in 12:  # beams and pillars
		var a := TAU * i / 12.0
		var p := Vector3(sin(a) * 12.6, 8.0, cos(a) * 12.6)
		add_child(Proc.cyl(0.35, 0.4, 16.0, 6, Proc.TIMBER_DARK, p))
		var beam := Proc.box(Vector3(0.4, 0.5, 12.6), Proc.TIMBER_DARK, Vector3(sin(a) * 6.3, 15.6, cos(a) * 6.3))
		beam.rotation.y = a
		add_child(beam)
	# the central gear of the mill: turns slowly over the trading floor
	var gear := Node3D.new()
	gear.name = "Gear"
	gear.position = Vector3(0, 13.5, -2)
	gear.add_child(Proc.cyl(2.4, 2.4, 0.5, 16, Proc.BRASS))
	for k in 12:
		var t := Proc.box(Vector3(0.5, 0.5, 0.6), Proc.BRASS.darkened(0.2), Vector3(sin(TAU * k / 12.0) * 2.6, 0, cos(TAU * k / 12.0) * 2.6))
		t.rotation.y = TAU * k / 12.0
		gear.add_child(t)
	add_child(gear)
	# trading desks and figures of the Money-changers' guild (market makers stand on both sides of the spread)
	for side in [-1.0, 1.0]:
		for k in 2:
			var desk := Proc.box(Vector3(3.0, 1.0, 1.2), Proc.TIMBER, Vector3(side * (4.5 + k * 3.5), 0.5, -3.0 + k * 2.5))
			desk.rotation.y = side * 0.4
			add_child(desk)
			var f := Proc.figure(Hud.BID.darkened(0.3) if side < 0 else Hud.ASK.darkened(0.3), Color("2a3550"))
			f.position = Vector3(side * (4.5 + k * 3.5), 0, -4.2 + k * 2.5)
			add_child(f)
	# warm lanterns
	for i in 6:
		var a := TAU * (i + 0.5) / 6.0
		var pos := Vector3(sin(a) * 10.5, 9.0, cos(a) * 10.5)
		add_child(Proc.ball(0.35, Color("ffcf6e"), pos, 5.0))
		var l := OmniLight3D.new()
		l.position = pos
		l.light_color = Color("ffbe6e")
		l.light_energy = 2.2
		l.omni_range = 12.0
		l.light_volumetric_fog_energy = 1.0
		add_child(l)
	var board_light := SpotLight3D.new()
	board_light.position = Vector3(0, 12, -1)
	board_light.rotation_degrees = Vector3(-50, 0, 0)
	board_light.light_color = Color("ffe1b0")
	board_light.light_energy = 3.0
	board_light.spot_range = 20.0
	board_light.spot_angle = 30.0
	board_light.shadow_enabled = true
	add_child(board_light)
	# windows with outside light shafts
	for i in 3:
		var a := PI + (i - 1) * 0.6
		var w := Proc.box(Vector3(1.4, 2.6, 0.2), Color("ffe6b8"), Vector3(sin(a + PI) * -13.2, 10.0, cos(a + PI) * -13.2))
		w.material_override = Proc.mat(Color("ffe6b8"), 3.0)
		w.rotation.y = a
		add_child(w)


func _process(delta: float) -> void:
	var gear: Node3D = get_node_or_null("Gear")
	if gear:
		gear.rotation.y += delta * 0.15
	var focus := Vector3(0, 6.0, -9.0)
	var dir := Vector3(sin(_yaw) * cos(_pitch), -sin(_pitch), cos(_yaw) * cos(_pitch))
	_cam.position = focus + dir * _dist + Vector3(0, 0, 0)
	_cam.position.y = clampf(_cam.position.y, 1.5, 14.0)
	_cam.look_at(focus + Vector3(-1.8 * (_dist / 15.0), 0, 0))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var m := event as InputEventMouseMotion
		_yaw = clampf(_yaw - m.relative.x * 0.004, -0.9, 0.9)
		_pitch = clampf(_pitch + m.relative.y * 0.003, -0.5, 0.4)
	elif event is InputEventMouseButton and event.pressed:
		var b := event as InputEventMouseButton
		if b.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = maxf(8.0, _dist - 0.8)
		elif b.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = minf(22.0, _dist + 0.8)
	elif event.is_action_pressed("ui_cancel"):
		_leave()


func _leave() -> void:
	Session.spawn = "exchange"
	Session.go("harbour")


# ---------------------------------------------------------------- HUD

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
	top.offset_top = 26
	top.add_theme_constant_override("separation", 18)
	root.add_child(top)
	var titles := VBoxContainer.new()
	var title := Hud.text("HALL_TITLE", 38, Hud.BRASS)
	title.add_theme_font_override("font", Hud.serif())
	titles.add_child(title)
	titles.add_child(Hud.lore("HALL_LORE"))
	top.add_child(titles)
	_live = Hud.text("", 15, Hud.MUTED)
	top.add_child(_live)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	top.add_child(Hud.lang_switch())
	var back := Hud.button("HALL_BACK")
	back.name = "Back"
	back.pressed.connect(_leave)
	top.add_child(back)
	var help := Hud.text("HALL_HELP", 15, Hud.MUTED)
	help.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	help.offset_left = 28
	help.offset_top = -44
	root.add_child(help)

	# right column: order ticket, balances, my orders
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	col.offset_left = -470
	col.offset_right = -28
	col.offset_top = 110
	col.offset_bottom = -60
	col.add_theme_constant_override("separation", 12)
	root.add_child(col)
	var form := VBoxContainer.new()
	form.add_theme_constant_override("separation", 8)
	col.add_child(Hud.panel(form))
	form.add_child(Hud.text("FORM_TITLE", 22, Hud.BRASS))
	var sides := HBoxContainer.new()
	form.add_child(sides)
	_ui["buy"] = _toggle(sides, "FORM_BUY", func() -> void: _set_side("BUY"))
	_ui["sell"] = _toggle(sides, "FORM_SELL", func() -> void: _set_side("SELL"))
	var types := HBoxContainer.new()
	form.add_child(types)
	var lim := VBoxContainer.new()
	var mkt := VBoxContainer.new()
	lim.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mkt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	types.add_child(lim)
	types.add_child(mkt)
	_ui["limit"] = _toggle(lim, "FORM_LIMIT", func() -> void: _set_type("LIMIT"))
	lim.add_child(Hud.lore("FORM_LIMIT_LORE"))
	_ui["market"] = _toggle(mkt, "FORM_MARKET", func() -> void: _set_type("MARKET"))
	mkt.add_child(Hud.lore("FORM_MARKET_LORE"))
	_ui["price_label"] = Hud.text("", 15, Hud.MUTED)
	form.add_child(_ui["price_label"])
	var price := LineEdit.new()
	price.name = "Price"
	price.text_changed.connect(func(t: String) -> void: _draft.price_text = t; _redraw())
	form.add_child(price)
	_ui["price"] = price
	_ui["hint"] = Hud.text("FORM_MARKET_HINT", 14, Hud.MUTED)
	(_ui["hint"] as Label).autowrap_mode = TextServer.AUTOWRAP_WORD
	form.add_child(_ui["hint"])
	_ui["qty_label"] = Hud.text("", 15, Hud.MUTED)
	form.add_child(_ui["qty_label"])
	var qty := LineEdit.new()
	qty.name = "Qty"
	qty.text_changed.connect(func(t: String) -> void: _draft.qty_text = t; _redraw())
	form.add_child(qty)
	_ui["qty"] = qty
	_ui["fee"] = Hud.text("", 14, Hud.MUTED)
	form.add_child(_ui["fee"])
	var submit := Hud.button("FORM_SUBMIT")
	submit.name = "Submit"
	submit.custom_minimum_size = Vector2(0, 46)
	submit.pressed.connect(_submit)
	form.add_child(submit)
	_ui["submit"] = submit
	_ui["result"] = Hud.text("", 15, Hud.TEXT)
	(_ui["result"] as Label).autowrap_mode = TextServer.AUTOWRAP_WORD
	form.add_child(_ui["result"])

	var bal := VBoxContainer.new()
	col.add_child(Hud.panel(bal))
	bal.add_child(Hud.text("BALANCES_TITLE", 18, Hud.BRASS))
	_ui["balances"] = Hud.text("", 15)
	(_ui["balances"] as Label).autowrap_mode = TextServer.AUTOWRAP_WORD
	bal.add_child(_ui["balances"])
	var ords := VBoxContainer.new()
	col.add_child(Hud.panel(ords))
	ords.add_child(Hud.text("ORDERS_TITLE", 18, Hud.BRASS))
	_ui["orders"] = Hud.text("", 14)
	ords.add_child(_ui["orders"])

	# left column: trade tape
	var tape := VBoxContainer.new()
	var tp := Hud.panel(tape)
	tp.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	tp.offset_left = 28
	tp.offset_right = 330
	tp.offset_top = 130
	tp.offset_bottom = -470
	root.add_child(tp)
	tape.add_child(Hud.text("TAPE_TITLE", 18, Hud.BRASS))
	_ui["tape"] = Hud.text("", 15)
	tape.add_child(_ui["tape"])
	_set_side("BUY")
	_set_type("LIMIT")


func _toggle(parent: Control, key: String, on_press: Callable) -> Button:
	var b := Hud.button(key)
	b.toggle_mode = true
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.name = key.capitalize().replace(" ", "")
	b.pressed.connect(on_press)
	parent.add_child(b)
	return b


func _set_side(s: String) -> void:
	_draft.side = s
	(_ui["buy"] as Button).set_pressed_no_signal(s == "BUY")
	(_ui["sell"] as Button).set_pressed_no_signal(s == "SELL")
	_redraw()


func _set_type(t: String) -> void:
	_draft.type = t
	(_ui["limit"] as Button).set_pressed_no_signal(t == "LIMIT")
	(_ui["market"] as Button).set_pressed_no_signal(t == "MARKET")
	_redraw()


func _ins() -> Dictionary:
	return ExchangeApi.instrument(INSTRUMENT)


func _redraw() -> void:
	if _ui.is_empty():
		return
	var ins := _ins()
	_draft.instrument = INSTRUMENT
	_draft.price_scale = int(ins["priceScale"])
	_draft.qty_scale = int(ins["qtyScale"])
	var limit := _draft.type == "LIMIT"
	(_ui["price"] as LineEdit).visible = limit
	(_ui["price_label"] as Label).visible = limit
	(_ui["hint"] as Label).visible = not limit
	(_ui["price_label"] as Label).text = tr("FORM_PRICE") % ins["quote"]
	(_ui["qty_label"] as Label).text = tr("FORM_QTY") % ins["base"]
	(_ui["fee"] as Label).text = tr("FEE_LORE") % Money.format(int(ins["feeBps"]), 2, Locale.current())
	(_ui["submit"] as Button).disabled = not _draft.is_valid()
	_board.show_book(_book, _last_text())
	_on_account(_details)
	_on_orders(_orders)
	_draw_tape()


func _on_locale(_c: String) -> void:
	(_ui["result"] as Label).text = ""
	_on_live(MarketStream.is_live())
	_redraw()


func _last_text() -> String:
	if _book.last_price < 0:
		return tr("LADDER_LAST_NONE")
	return tr("LADDER_LAST") % Money.format(_book.last_price, int(_ins()["priceScale"]), Locale.current())


func _on_live(live: bool) -> void:
	_live.text = "● " + tr("LADDER_LIVE") if live else "○ " + tr("LADDER_OFFLINE")
	_live.add_theme_color_override("font_color", Hud.BID if live else Hud.ASK)


func _on_book(book: BookModel) -> void:
	if book.instrument != INSTRUMENT:
		return
	_book = book
	_board.show_book(_book, _last_text())


func _on_trades(trades: Array) -> void:
	for t: Variant in trades:
		if t is Dictionary:
			_tape.push_front(t)
	_tape = _tape.slice(0, 12)
	_draw_tape()


func _draw_tape() -> void:
	if _tape.is_empty():
		(_ui["tape"] as Label).text = tr("TAPE_EMPTY")
		return
	var ins := _ins()
	var lines: PackedStringArray = []
	for t: Dictionary in _tape:
		var side := "▲" if str(t.get("aggressorSide", "BUY")) == "BUY" else "▼"
		lines.append("%s %s × %s" % [side, Money.format(int(t["price"]), int(ins["priceScale"]), Locale.current()),
			Money.format(int(t["qty"]), int(ins["qtyScale"]), Locale.current())])
	(_ui["tape"] as Label).text = "\n".join(lines)


func _on_account(details: Dictionary) -> void:
	_details = details
	var lines: PackedStringArray = []
	for b: Dictionary in details.get("balances", []):
		var asset := str(b["asset"])
		var scale := 2 if asset == "SPARK" else 0
		lines.append(tr("BALANCE_ROW") % [asset, Money.format(int(b["available"]), scale, Locale.current()),
			Money.format(int(b["reserved"]), scale, Locale.current())])
	(_ui["balances"] as Label).text = "\n".join(lines)


func _on_orders(orders: Array) -> void:
	_orders = orders
	if orders.is_empty():
		(_ui["orders"] as Label).text = tr("ORDERS_EMPTY")
		return
	var ins := _ins()
	var lines: PackedStringArray = []
	for o: Dictionary in orders.slice(0, 6):
		var price := Money.format(int(o["price"]), int(ins["priceScale"]), Locale.current()) if o.get("price") != null and str(o["type"]) == "LIMIT" else "—"
		lines.append(tr("ORDERS_ROW") % [str(int(o["orderId"])), tr("SIDE_" + str(o["side"])), tr("TYPE_" + str(o["type"])),
			price, Money.format(int(o["qty"]), int(ins["qtyScale"]), Locale.current()), tr("STATUS_" + str(o["status"]))])
	(_ui["orders"] as Label).text = "\n".join(lines)


func _submit() -> void:
	var body := _draft.to_request()
	var result: Label = _ui["result"]
	if body.is_empty():
		result.text = "FORM_INVALID"
		return
	(_ui["submit"] as Button).disabled = true
	result.text = "FORM_SENDING"
	var r: Dictionary = await ExchangeApi.place_order(body)
	(_ui["submit"] as Button).disabled = false
	if r["ok"]:
		var o: Dictionary = r["data"]
		var qs := int(_ins()["qtyScale"])
		result.text = tr("FORM_PLACED") % [str(int(o["orderId"])), tr("STATUS_" + str(o["status"])),
			Money.format(int(o["filledQty"]), qs, Locale.current()), Money.format(int(o["qty"]), qs, Locale.current())]
		result.add_theme_color_override("font_color", Hud.BID)
	else:
		result.text = tr("ERR_" + str(r["code"]))
		result.add_theme_color_override("font_color", Hud.ASK)
	ExchangeApi.refresh_account()


## Demo: wait for the live book, place a limit order below the best bid and a small market buy, take screenshots.
func _demo() -> void:
	for i in 40:
		if _book.best_bid() > 0:
			break
		await Session.wait(0.25)
	await Session.wait(1.0)
	await Session.shot(self, "6-hall-board")
	var ps := int(_ins()["priceScale"])
	var bid := _book.best_bid() if _book.best_bid() > 0 else 10000
	_set_side("BUY")
	_set_type("LIMIT")
	(_ui["price"] as LineEdit).text = Money.format(bid - 5 * int(pow(10, ps - 1)), ps, "en").replace(",", "")
	(_ui["price"] as LineEdit).text_changed.emit((_ui["price"] as LineEdit).text)
	(_ui["qty"] as LineEdit).text = "5"
	(_ui["qty"] as LineEdit).text_changed.emit("5")
	await _submit()
	await Session.wait(1.2)
	await Session.shot(self, "7-hall-limit")
	_set_type("MARKET")
	(_ui["qty"] as LineEdit).text = "2"
	(_ui["qty"] as LineEdit).text_changed.emit("2")
	await _submit()
	await Session.wait(1.2)
	Locale.set_locale("en")
	_yaw = -0.35
	_dist = 12.0
	await Session.wait(0.6)
	await Session.shot(self, "8-hall-market-en")
	Locale.set_locale("ru")
	_leave()

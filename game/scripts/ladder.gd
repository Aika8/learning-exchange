## The Ladder (order book) scene. Driven only by server data: REST for commands, WebSocket for the book (ADR-0011).
## Real terms lead every label; lore names are muted captions (ADR-0012).
extends Control

const DEPTH := 10
const INSTRUMENT := "SILK-SPARK"

var _ins: Dictionary
var _book: BookModel = null
var _orders: Array = []
var _trades: Array = []
var _details: Dictionary = {}
var _draft := OrderDraft.new()
var _last_result: Dictionary = {}

var _ask_rows: Array[LadderRow] = []
var _bid_rows: Array[LadderRow] = []
var _spread: Label
var _last: Label
var _live: Label
var _hdr: Array[Label] = []
var _balances: Label
var _orders_box: Label
var _tape_box: Label
var _price_label: Label
var _qty_label: Label
var _price: LineEdit
var _qty: LineEdit
var _side_buy: Button
var _side_sell: Button
var _type_limit: Button
var _type_market: Button
var _hint: Label
var _fee: Label
var _result: Label
var _submit: Button


func _ready() -> void:
	theme = UI.theme()
	_ins = ExchangeApi.instrument(INSTRUMENT)
	_draft.instrument = INSTRUMENT
	_draft.price_scale = int(_ins["priceScale"])
	_draft.qty_scale = int(_ins["qtyScale"])
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 16
	root.offset_top = 12
	root.offset_right = -16
	root.offset_bottom = -12
	add_child(root)
	root.add_child(_top_bar())
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 14)
	root.add_child(cols)
	cols.add_child(_ladder_panel())
	cols.add_child(_form_panel())
	cols.add_child(_side_panel())

	MarketStream.book_received.connect(_on_book)
	MarketStream.trades_received.connect(_on_trades)
	MarketStream.account_changed.connect(func(_r: Array) -> void: ExchangeApi.refresh_account())
	MarketStream.connection_changed.connect(func(_l: bool) -> void: _refresh_texts())
	ExchangeApi.account_updated.connect(func(d: Dictionary) -> void: _details = d; _refresh_texts())
	ExchangeApi.orders_updated.connect(func(o: Array) -> void: _orders = o; _refresh_texts())
	Locale.locale_changed.connect(func(_c: String) -> void: _refresh_texts(); _render_book())
	var channels: Array[String] = ["market.%s.book" % INSTRUMENT, "market.%s.trades" % INSTRUMENT]
	if not ExchangeApi.account.is_empty():
		channels.append("account." + str(ExchangeApi.account["accountId"]))
	MarketStream.open(ExchangeApi.token, channels)
	ExchangeApi.refresh_account()
	_refresh_texts()
	if Demo.active():
		_demo()


func _exit_tree() -> void:
	MarketStream.close()


# ---------- layout ----------

func _top_bar() -> HBoxContainer:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	var back := UI.button("LADDER_BACK")
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/harbour.tscn"))
	top.add_child(back)
	top.add_child(UI.label("LADDER_TITLE", 26, UI.BRASS))
	var lore := UI.lore("LADDER_LORE")
	lore.size_flags_vertical = Control.SIZE_SHRINK_END
	top.add_child(lore)
	top.add_child(UI.label(INSTRUMENT, 22, UI.TEXT))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	_live = UI.label("", 15, UI.MUTED)
	top.add_child(_live)
	top.add_child(UI.lang_switch())
	return top


func _ladder_panel() -> PanelContainer:
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(430, 0)
	var head := HBoxContainer.new()
	for i in 3:
		var l := UI.label("", 14, UI.MUTED)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		_hdr.append(l)
		head.add_child(l)
	v.add_child(head)
	v.add_child(UI.label("LADDER_ASKS", 13, UI.ASK))
	for i in DEPTH:
		var r := LadderRow.new()
		_ask_rows.append(r)
		v.add_child(r)
	var mid := VBoxContainer.new()
	_spread = UI.label("", 17, UI.BRASS)
	_spread.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(_spread)
	var chasm := UI.lore("LADDER_SPREAD_LORE")
	chasm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(chasm)
	_last = UI.label("", 15, UI.TEXT)
	_last.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(_last)
	v.add_child(mid)
	for i in DEPTH:
		var r := LadderRow.new()
		_bid_rows.append(r)
		v.add_child(r)
	v.add_child(UI.label("LADDER_BIDS", 13, UI.BID))
	return UI.panel(v)


func _form_panel() -> PanelContainer:
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(340, 0)
	v.add_theme_constant_override("separation", 8)
	v.add_child(UI.label("FORM_TITLE", 20, UI.BRASS))
	var sides := HBoxContainer.new()
	var group := ButtonGroup.new()
	_side_buy = _toggle("FORM_BUY", group, true, func() -> void: _draft.side = "BUY")
	_side_sell = _toggle("FORM_SELL", group, false, func() -> void: _draft.side = "SELL")
	_side_buy.name = "Buy"
	_side_sell.name = "Sell"
	sides.add_child(_side_buy)
	sides.add_child(_side_sell)
	v.add_child(sides)
	var types := HBoxContainer.new()
	var tg := ButtonGroup.new()
	_type_limit = _toggle("FORM_LIMIT", tg, true, func() -> void: _draft.type = "LIMIT"; _refresh_texts())
	_type_market = _toggle("FORM_MARKET", tg, false, func() -> void: _draft.type = "MARKET"; _refresh_texts())
	types.add_child(_type_limit)
	types.add_child(_type_market)
	v.add_child(types)
	var lores := HBoxContainer.new()
	for k: String in ["FORM_LIMIT_LORE", "FORM_MARKET_LORE"]:
		var l := UI.lore(k)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lores.add_child(l)
	v.add_child(lores)
	_price_label = UI.label("", 15, UI.MUTED)
	v.add_child(_price_label)
	_price = LineEdit.new()
	_price.name = "Price"
	_price.text_changed.connect(func(t: String) -> void: _draft.price_text = t; _refresh_texts())
	v.add_child(_price)
	_qty_label = UI.label("", 15, UI.MUTED)
	v.add_child(_qty_label)
	_qty = LineEdit.new()
	_qty.name = "Qty"
	_qty.text = "1"
	_draft.qty_text = "1"
	_qty.text_changed.connect(func(t: String) -> void: _draft.qty_text = t; _refresh_texts())
	v.add_child(_qty)
	_hint = UI.label("", 14, UI.MUTED)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(_hint)
	_fee = UI.label("", 14, UI.MUTED)
	v.add_child(_fee)
	_submit = UI.button("FORM_SUBMIT")
	_submit.name = "Submit"
	_submit.pressed.connect(_on_submit)
	v.add_child(_submit)
	_result = UI.label("", 16, UI.BRASS)
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(_result)
	v.add_child(HSeparator.new())
	v.add_child(UI.label("BALANCES_TITLE", 18, UI.BRASS))
	_balances = UI.label("", 15)
	_balances.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(_balances)
	return UI.panel(v)


func _side_panel() -> PanelContainer:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UI.label("ORDERS_TITLE", 18, UI.BRASS))
	_orders_box = UI.label("", 14)
	v.add_child(_orders_box)
	v.add_child(HSeparator.new())
	v.add_child(UI.label("TAPE_TITLE", 18, UI.BRASS))
	_tape_box = UI.label("", 14)
	v.add_child(_tape_box)
	return UI.panel(v)


func _toggle(key: String, group: ButtonGroup, on: bool, cb: Callable) -> Button:
	var b := UI.button(key)
	b.toggle_mode = true
	b.button_group = group
	b.button_pressed = on
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	return b


# ---------- data ----------

func _on_book(book: BookModel) -> void:
	if book.instrument != INSTRUMENT:
		return
	_book = book
	if _price.text.is_empty() and book.best_bid() > 0:
		_price.text = _fmt(book.best_bid()).replace(" ", "")
		_draft.price_text = _price.text
	_render_book()


func _on_trades(trades: Array) -> void:
	for t: Variant in trades:
		_trades.push_front(t)
	_trades = _trades.slice(0, 12)
	_refresh_texts()


func _on_submit() -> void:
	var req := _draft.to_request()
	if req.is_empty():
		_result.text = "FORM_INVALID"
		return
	_submit.disabled = true
	_result.text = "FORM_SENDING"
	var r := await ExchangeApi.place_order(req)
	_submit.disabled = false
	_last_result = r
	_refresh_texts()
	ExchangeApi.refresh_account()


# ---------- rendering ----------

func _fmt(minor: int) -> String:
	return Money.format(minor, int(_ins["priceScale"]), Locale.current())


func _q(n: int) -> String:
	return Money.format(n, int(_ins["qtyScale"]), Locale.current())


func _render_book() -> void:
	if _book == null:
		return
	var mx := _book.max_qty(DEPTH)
	var asks := _book.asks_top_down(DEPTH)
	var pad := DEPTH - asks.size()
	for i in DEPTH:
		var row := _ask_rows[i]
		if i < pad:
			row.set_level("", "", "", 0.0, UI.ASK)
		else:
			var l: Dictionary = asks[i - pad]
			row.set_level(_fmt(l["price"]), _q(l["qty"]), str(l["orders"]), float(l["qty"]) / mx, UI.ASK)
	for i in DEPTH:
		var row := _bid_rows[i]
		if i < _book.bids.size():
			var l: Dictionary = _book.bids[i]
			row.set_level(_fmt(l["price"]), _q(l["qty"]), str(l["orders"]), float(l["qty"]) / mx, UI.BID)
		else:
			row.set_level("", "", "", 0.0, UI.BID)
	var sp := _book.spread()
	_spread.text = tr("LADDER_SPREAD") % [_fmt(sp), _ins["quote"]] if sp >= 0 else tr("LADDER_SPREAD_NONE")
	_last.text = tr("LADDER_LAST") % _fmt(_book.last_price) if _book.last_price >= 0 else tr("LADDER_LAST_NONE")


func _refresh_texts() -> void:
	if _hdr.is_empty():
		return
	var quote: String = _ins["quote"]
	var base: String = _ins["base"]
	_hdr[0].text = tr("LADDER_PRICE") % quote
	_hdr[1].text = tr("LADDER_QTY") % base
	_hdr[2].text = tr("LADDER_ORDERS")
	_live.text = tr("LADDER_LIVE") if MarketStream.is_live() else tr("LADDER_OFFLINE")
	_live.add_theme_color_override("font_color", UI.BID if MarketStream.is_live() else UI.ASK)
	_price_label.text = tr("FORM_PRICE") % quote
	_qty_label.text = tr("FORM_QTY") % base
	_price.editable = _draft.type == "LIMIT"
	_hint.text = tr("FORM_MARKET_HINT") if _draft.type == "MARKET" else ""
	var bps := int(_ins["feeBps"])
	var fee_line := tr("FEE_LORE") % Money.format(bps, 2, Locale.current())
	var n := _draft.notional()
	if n > 0:
		fee_line += "  ≈ %s %s" % [_fmt(Money.fee(n, bps)), quote]
	_fee.text = fee_line
	if not _last_result.is_empty():
		var r := _last_result
		if r["ok"]:
			var o: Dictionary = r["data"]
			_result.text = tr("FORM_PLACED") % [str(int(o["orderId"])), tr("STATUS_" + str(o["status"])),
				_q(int(o["filledQty"])), _q(int(o["qty"]))]
			_result.add_theme_color_override("font_color", UI.BID)
		else:
			_result.text = tr("ERR_" + str(r["code"]))
			_result.add_theme_color_override("font_color", UI.ASK)
	var bl := PackedStringArray()
	for b: Dictionary in _details.get("balances", []):
		var asset: String = b["asset"]
		var scale := int(_ins["priceScale"]) if asset == quote else int(_ins["qtyScale"])
		bl.append(tr("BALANCE_ROW") % [asset, Money.format(int(b["available"]), scale, Locale.current()),
			Money.format(int(b["reserved"]), scale, Locale.current())])
	_balances.text = "\n".join(bl)
	var ol := PackedStringArray()
	for o: Dictionary in _orders:
		var price := _fmt(int(o["price"])) if o["type"] == "LIMIT" else "—"
		ol.append(tr("ORDERS_ROW") % [str(int(o["orderId"])), tr("SIDE_" + str(o["side"])), tr("TYPE_" + str(o["type"])),
			price, _q(int(o["qty"])), tr("STATUS_" + str(o["status"]))])
	_orders_box.text = "\n".join(ol) if not ol.is_empty() else tr("ORDERS_EMPTY")
	var tl := PackedStringArray()
	for t: Dictionary in _trades:
		var arrow := "▲" if t["aggressorSide"] == "BUY" else "▼"
		tl.append("%s %s × %s" % [arrow, _fmt(int(t["price"])), _q(int(t["qty"]))])
	_tape_box.text = "\n".join(tl) if not tl.is_empty() else tr("TAPE_EMPTY")


# ---------- demo ----------

func _demo() -> void:
	await get_tree().create_timer(2.0).timeout
	await Demo.shot(self, "4-ladder-live")
	# Limit buy below the market: rests on the book (status New), visible in web and mobile.
	if _book != null and _book.best_bid() > 0:
		_price.text = _fmt(_book.best_bid() - 100).replace(" ", "")
		_draft.price_text = _price.text
	_qty.text = "3"
	_draft.qty_text = "3"
	_on_submit()
	await get_tree().create_timer(1.5).timeout
	await Demo.shot(self, "5-limit-order-placed")
	# Market buy: crosses the spread and fills at once.
	_type_market.button_pressed = true
	_type_market.pressed.emit()
	_qty.text = "1"
	_draft.qty_text = "1"
	_on_submit()
	await get_tree().create_timer(1.5).timeout
	Locale.set_locale("en")
	await get_tree().create_timer(0.5).timeout
	await Demo.shot(self, "6-market-fill-en")
	get_tree().quit()

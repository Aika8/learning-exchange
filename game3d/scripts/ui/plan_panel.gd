## Plan voyage with Mara: instrument, entry, the Anchor (stop-loss) and the size; Mara checks risk ≤ 1% of the trading
## capital and that the Anchor is below the entry. Real terms on every control, lore names small (ADR-0012).
class_name PlanPanel
extends PanelContainer

signal approved
signal cancelled

const CHOICES := ["SILK-SPARK", "FORGE-SPARK"]

var plan := VoyagePlan.new()
var _ui: Dictionary = {}
var _atr := 0


func _ready() -> void:
	add_theme_stylebox_override("panel", Hud.box(Color(0.09, 0.11, 0.17, 0.95), Hud.BRASS, 2, 16))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size = Vector2(620, 0)
	add_child(box)
	var title := Hud.text("PLAN_TITLE", 30, Hud.BRASS)
	title.add_theme_font_override("font", Hud.serif())
	box.add_child(title)
	box.add_child(Hud.lore("PLAN_LORE"))
	var row := HBoxContainer.new()
	box.add_child(row)
	for id: String in CHOICES:
		var b := Hud.button(id)
		b.toggle_mode = true
		b.name = id.replace("-", "")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void: pick(id))
		row.add_child(b)
		_ui[id] = b
	_ui["capital"] = Hud.text("", 16, Hud.MUTED)
	box.add_child(_ui["capital"])
	for f: Array in [["entry", "PLAN_ENTRY", "PLAN_ENTRY_LORE"], ["stop", "PLAN_STOP", "PLAN_STOP_LORE"], ["qty", "PLAN_QTY", "PLAN_QTY_LORE"]]:
		var h := HBoxContainer.new()
		var labels := VBoxContainer.new()
		labels.custom_minimum_size = Vector2(300, 0)
		labels.add_child(Hud.text(f[1], 17))
		labels.add_child(Hud.lore(f[2]))
		h.add_child(labels)
		var e := LineEdit.new()
		e.name = str(f[0]).capitalize()
		e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		e.text_changed.connect(func(_t: String) -> void: _read())
		h.add_child(e)
		box.add_child(h)
		_ui[f[0]] = e
	_ui["atr"] = Hud.text("", 14, Hud.MUTED)
	box.add_child(_ui["atr"])
	var max_b := Hud.button("PLAN_MAX")
	max_b.name = "Max"
	max_b.pressed.connect(fill_max)
	box.add_child(max_b)
	_ui["risk"] = Hud.text("", 18)
	box.add_child(_ui["risk"])
	_ui["verdict"] = Hud.text("", 17, Hud.ASK)
	(_ui["verdict"] as Label).autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(_ui["verdict"])
	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	var check := Hud.button("PLAN_CHECK")
	check.name = "Check"
	check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	check.pressed.connect(submit)
	buttons.add_child(check)
	var cancel := Hud.button("PLAN_CANCEL")
	cancel.pressed.connect(func() -> void: cancelled.emit())
	buttons.add_child(cancel)
	Locale.locale_changed.connect(func(_c: String) -> void: _paint([]))


## Picks the instrument: entry = last price, Anchor = two ATR waves under it (Mara's habit, M2c).
func pick(id: String) -> void:
	plan.instrument = id
	for c: String in CHOICES:
		(_ui[c] as Button).set_pressed_no_signal(c == id)
	plan.fee_bps = int(ExchangeApi.instrument(id).get("feeBps", 10))
	plan.capital = await Game.trading_capital()
	plan.entry = await Game.last_price(id)
	_atr = await Game.atr_of(id)
	plan.stop = VoyagePlan.suggest_stop(plan.entry, _atr)
	plan.qty = 0
	_write()


func fill_max() -> void:
	plan.qty = plan.max_qty()
	_write()


func set_qty(q: int) -> void:
	plan.qty = q
	_write()


func _write() -> void:
	var loc := "en"
	(_ui["entry"] as LineEdit).text = Money.format(plan.entry, 2, loc).replace(",", "")
	(_ui["stop"] as LineEdit).text = Money.format(plan.stop, 2, loc).replace(",", "")
	(_ui["qty"] as LineEdit).text = str(plan.qty)
	_paint([])


func _read() -> void:
	plan.entry = maxi(0, Money.parse((_ui["entry"] as LineEdit).text, 2))
	plan.stop = maxi(0, Money.parse((_ui["stop"] as LineEdit).text, 2))
	plan.qty = maxi(0, (_ui["qty"] as LineEdit).text.to_int())
	_paint([])


func _paint(verdict: Array) -> void:
	var loc := Locale.current()
	(_ui["capital"] as Label).text = tr("PLAN_CAPITAL") % [Money.format(plan.capital, 2, loc), Money.format(plan.budget(), 2, loc)]
	(_ui["atr"] as Label).text = tr("PLAN_ATR") % Money.format(_atr, 2, loc) if _atr > 0 else tr("PLAN_ATR_NONE")
	(_ui["risk"] as Label).text = tr("PLAN_RISK") % [Money.format(plan.risk(), 2, loc), Money.format(plan.risk_bps(), 2, loc)]
	(_ui["risk"] as Label).add_theme_color_override("font_color", Hud.ASK if plan.risk() > plan.budget() else Hud.BID)
	var lines: PackedStringArray = []
	for k: String in verdict:
		lines.append(tr(k))
	(_ui["verdict"] as Label).text = "\n".join(lines)


## Shows the plan to Mara. Approved → `approved`; otherwise her refusals are listed.
func submit() -> void:
	_read()
	var verdict: Array[String] = await Game.approve(plan)
	if verdict.is_empty():
		(_ui["verdict"] as Label).add_theme_color_override("font_color", Hud.BID)
		(_ui["verdict"] as Label).text = "MARA_OK"
		approved.emit()
	else:
		(_ui["verdict"] as Label).add_theme_color_override("font_color", Hud.ASK)
		_paint(verdict)

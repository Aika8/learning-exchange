## The 3D order-book board in the Exchange hall: a brass frame with glowing rows (price · quantity · orders) and
## depth bars. It only draws `BoardLayout` rows — the data comes from the server (ADR-0011: the Ladder is server-driven).
class_name Board
extends Node3D

const DEPTH := 8
const ROW_H := 0.62
const WIDTH := 9.0

var _rows: Array[Dictionary] = []  ## {price: Label3D, qty: Label3D, orders: Label3D, bar: MeshInstance3D}
var _title: Label3D
var _lore: Label3D
var _header: Label3D
var _last: Label3D
var _bid_mat: StandardMaterial3D
var _ask_mat: StandardMaterial3D
var _flash := 0.0
var _bars_target: Array[float] = []


func _ready() -> void:
	var h := (DEPTH * 2 + 1) * ROW_H + 2.6
	name = "Board"
	Solid.box(self, Vector3(WIDTH + 0.8, h + 0.8, 0.5), Vector3(0, h * 0.5, -0.12))
	add_child(Proc.box(Vector3(WIDTH + 0.8, h + 0.8, 0.3), Proc.BRASS, Vector3(0, h * 0.5, -0.2)))
	var panel := Proc.box(Vector3(WIDTH, h, 0.2), Color("0f141f"), Vector3(0, h * 0.5, -0.02))
	add_child(panel)
	for x in [-WIDTH * 0.5 - 0.4, WIDTH * 0.5 + 0.4]:
		add_child(Proc.ball(0.28, Color("ffcf6e"), Vector3(x, h + 0.4, 0), 4.0))
	_bid_mat = Proc.mat(Hud.BID.darkened(0.55), 0.9).duplicate()
	_ask_mat = Proc.mat(Hud.ASK.darkened(0.55), 0.9).duplicate()
	_title = _label(0.0, h - 0.55, 64, Hud.BRASS, HORIZONTAL_ALIGNMENT_CENTER)
	_lore = _label(0.0, h - 1.05, 30, Hud.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_header = _label(0.0, h - 1.6, 30, Hud.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_last = _label(0.0, -0.5, 40, Hud.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	for i in DEPTH * 2 + 1:
		var y := h - 2.3 - i * ROW_H
		var bar := Proc.box(Vector3(1, ROW_H * 0.78, 0.04), Color.WHITE, Vector3(0, y, 0.1))
		bar.material_override = _bid_mat if i > DEPTH else _ask_mat
		bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bar.scale.x = 0.001
		add_child(bar)
		var c := Hud.TEXT if i != DEPTH else Hud.BRASS
		_rows.append({"price": _label(-1.6, y, 44, c, HORIZONTAL_ALIGNMENT_RIGHT), "qty": _label(1.6, y, 40, c, HORIZONTAL_ALIGNMENT_RIGHT),
			"orders": _label(3.9, y, 30, Hud.MUTED, HORIZONTAL_ALIGNMENT_RIGHT), "bar": bar, "y": y})
		_bars_target.append(0.0)
	Locale.locale_changed.connect(_on_locale)
	_on_locale("")


func _label(x: float, y: float, size: int, color: Color, align: HorizontalAlignment) -> Label3D:
	var l := Label3D.new()
	l.position = Vector3(x, y, 0.16)
	l.font_size = size
	l.pixel_size = 0.006
	l.modulate = color
	l.outline_size = 0
	l.horizontal_alignment = align
	l.shaded = false
	l.double_sided = false
	l.no_depth_test = true
	l.render_priority = 2
	l.font = Hud.mono()
	add_child(l)
	return l


func _on_locale(_c: String) -> void:
	_title.text = tr("LADDER_TITLE")
	_lore.text = tr("LADDER_LORE")
	var ins := ExchangeApi.instrument("SILK-SPARK")
	_header.text = "%s        %s        %s" % [tr("LADDER_PRICE") % ins["quote"], tr("LADDER_QTY") % ins["base"], tr("LADDER_ORDERS")]


func show_book(book: BookModel, last_text: String) -> void:
	var ins := ExchangeApi.instrument(book.instrument if not book.instrument.is_empty() else "SILK-SPARK")
	var rows := BoardLayout.rows(book, DEPTH, int(ins["priceScale"]), int(ins["qtyScale"]), Locale.current())
	for i in rows.size():
		var r: Dictionary = rows[i]
		var cells: Dictionary = _rows[i]
		if r["kind"] == "spread":
			(cells["price"] as Label3D).text = tr("LADDER_SPREAD") % [r["price"], ins["quote"]]
			(cells["price"] as Label3D).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			(cells["price"] as Label3D).position.x = 0.0
			(cells["qty"] as Label3D).text = ""
			(cells["orders"] as Label3D).text = tr("LADDER_SPREAD_LORE")
		else:
			(cells["price"] as Label3D).text = r["price"]
			(cells["qty"] as Label3D).text = r["qty"]
			(cells["orders"] as Label3D).text = r["orders"]
			(cells["price"] as Label3D).modulate = Hud.ASK.lightened(0.25) if r["kind"] == "ask" else Hud.BID.lightened(0.25)
		_bars_target[i] = float(r["bar"])
	_last.text = last_text
	_flash = 1.0


func _process(delta: float) -> void:
	for i in _rows.size():
		var bar: MeshInstance3D = _rows[i]["bar"]
		var w := lerpf(bar.scale.x, maxf(_bars_target[i] * (WIDTH - 1.0), 0.001), 8.0 * delta)
		bar.scale.x = w
		bar.position.x = WIDTH * 0.5 - 0.5 - w * 0.5
	_flash = maxf(0.0, _flash - delta * 2.0)
	_bid_mat.emission_energy_multiplier = 0.9 + _flash * 0.9
	_ask_mat.emission_energy_multiplier = 0.9 + _flash * 0.9

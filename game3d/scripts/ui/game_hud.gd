## The M3 overlay every scene adds: the day's flow bar (real step names, lore names small — ADR-0012), refusal
## toasts, lesson cards, «Словарь капитана» (G) and the report-night banner. Observes the Game autoload only.
class_name GameHud
extends CanvasLayer

signal modal_changed(open: bool)

var _root: Control
var _chips: Array[PanelContainer] = []
var _toast: Label
var _toast_t := 0.0
var _card: PanelContainer
var _card_box: VBoxContainer
var _queue: Array = []
var _book: PanelContainer
var _book_list: VBoxContainer
var _banner: PanelContainer
var _banner_text: Label
var _current: Array = []  ## [id, args] of the card on screen


func _ready() -> void:
	layer = 20
	_root = Control.new()
	_root.theme = Hud.theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_flow()
	_toast = Hud.text("", 20, Hud.ASK)
	_toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.offset_left = -500
	_toast.offset_right = 500
	_toast.offset_top = -130
	_root.add_child(_toast)
	_build_card()
	_build_book()
	_build_banner()
	Game.flow_changed.connect(func(_s: int) -> void: _paint_flow())
	Game.refused.connect(toast)
	Game.lesson_met.connect(func(id: String, args: Array) -> void: show_lesson(id, args))
	Game.report_event.connect(_on_report)
	Locale.locale_changed.connect(func(_c: String) -> void: _relocale())
	_paint_flow()


func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast.modulate.a = clampf(_toast_t, 0.0, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k == KEY_G:
			toggle_book()
			get_viewport().set_input_as_handled()
		elif (k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_ESCAPE) and _card.visible:
			_next_card()
			get_viewport().set_input_as_handled()
		elif k == KEY_ESCAPE and _book.visible:
			toggle_book()
			get_viewport().set_input_as_handled()


func is_modal() -> bool:
	return _card.visible or _book.visible


# ---------------------------------------------------------------- flow bar

func _build_flow() -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar.offset_left = -430
	bar.offset_right = 430
	bar.offset_top = -78
	bar.offset_bottom = -20
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 6)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bar)
	for i in GameFlow.KEYS.size():
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		v.add_child(Hud.text(GameFlow.KEYS[i], 15))
		v.add_child(Hud.lore(GameFlow.LORE_KEYS[i]))
		var chip := Hud.panel(v)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(chip)
		_chips.append(chip)
		if i < GameFlow.KEYS.size() - 1:
			bar.add_child(Hud.text("›", 18, Hud.MUTED))


func _paint_flow() -> void:
	for i in _chips.size():
		var on := i == Game.flow.state
		_chips[i].add_theme_stylebox_override("panel", Hud.box(Color(0.35, 0.27, 0.1, 0.92) if on else Color(0.106, 0.133, 0.196, 0.7),
			Hud.BRASS if on else Hud.LINE, 2 if on else 1, 10))


func toast(key: String) -> void:
	_toast.text = key
	_toast_t = 4.0
	_toast.modulate.a = 1.0


# ---------------------------------------------------------------- lesson cards

func _build_card() -> void:
	_card_box = VBoxContainer.new()
	_card_box.add_theme_constant_override("separation", 10)
	_card_box.custom_minimum_size = Vector2(780, 0)
	_card = Hud.panel(_card_box)
	_card.set_anchors_preset(Control.PRESET_CENTER)
	_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_card.grow_vertical = Control.GROW_DIRECTION_BOTH
	_card.add_theme_stylebox_override("panel", Hud.box(Color(0.09, 0.11, 0.17, 0.95), Hud.BRASS, 2, 16))
	_card.visible = false
	_root.add_child(_card)


func show_lesson(id: String, args: Array = []) -> void:
	_queue.append([id, args])
	if not _card.visible:
		_next_card()


func _next_card() -> void:
	if _queue.is_empty():
		_card.visible = false
		_current = []
		modal_changed.emit(is_modal())
		return
	_current = _queue.pop_front()
	_render_card()
	_card.visible = true
	modal_changed.emit(true)


func _render_card() -> void:
	for c in _card_box.get_children():
		c.queue_free()
	var id: String = _current[0]
	var args: Array = _current[1]
	_card_box.add_child(Hud.text("LESSON_CARD_HEAD", 14, Hud.MUTED))
	var title := Hud.text(Lessons.title_key(id), 34, Hud.BRASS)
	title.add_theme_font_override("font", Hud.serif())
	_card_box.add_child(title)
	_card_box.add_child(Hud.text(tr("LESSON_REAL_NAME") % tr(Lessons.real_key(id)), 20, Hud.TEXT))
	var body := Hud.text(Chronicler.render({"key": Lessons.text_key(id), "args": args}, tr, Locale.current()), 18)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	_card_box.add_child(body)
	var names: PackedStringArray = []
	for t: String in Lessons.terms(id):
		names.append(Game.glossary.real_name(t, Locale.current()))
	var terms := Hud.text(tr("LESSON_TO_BOOK") % ", ".join(names), 15, Hud.BID)
	terms.autowrap_mode = TextServer.AUTOWRAP_WORD
	_card_box.add_child(terms)
	var ok := Hud.button("LESSON_OK")
	ok.name = "LessonOk"
	ok.pressed.connect(_next_card)
	_card_box.add_child(ok)


# ---------------------------------------------------------------- glossary book

func _build_book() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var title := Hud.text("BOOK_TITLE", 30, Hud.BRASS)
	title.add_theme_font_override("font", Hud.serif())
	box.add_child(title)
	box.add_child(Hud.lore("BOOK_LORE"))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(820, 600)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_book_list = VBoxContainer.new()
	_book_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_book_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_book_list)
	box.add_child(Hud.text("BOOK_HELP", 14, Hud.MUTED))
	_book = Hud.panel(box)
	_book.set_anchors_preset(Control.PRESET_CENTER)
	_book.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_book.grow_vertical = Control.GROW_DIRECTION_BOTH
	_book.visible = false
	_root.add_child(_book)


func toggle_book() -> void:
	_book.visible = not _book.visible
	if _book.visible:
		_fill_book()
	modal_changed.emit(is_modal())


func _fill_book() -> void:
	for c in _book_list.get_children():
		c.queue_free()
	var rows := Game.glossary.rows(Locale.current())
	if rows.is_empty():
		_book_list.add_child(Hud.text("BOOK_EMPTY", 16, Hud.MUTED))
	for r in rows:
		var head := Hud.text(str(r["real"]), 20, Hud.TEXT)
		_book_list.add_child(head)
		_book_list.add_child(Hud.lore(str(r["lore"])))
		var d := Hud.text(str(r["definition"]), 15, Hud.MUTED)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD
		d.custom_minimum_size = Vector2(780, 0)
		_book_list.add_child(d)


# ---------------------------------------------------------------- report night

func _build_banner() -> void:
	_banner_text = Hud.text("", 18)
	_banner_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	_banner_text.custom_minimum_size = Vector2(520, 0)
	_banner = Hud.panel(_banner_text)
	_banner.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_banner.offset_left = -580
	_banner.offset_right = -28
	_banner.offset_top = 170
	_banner.visible = false
	_root.add_child(_banner)


var _banner_kind := ""
var _banner_data: Dictionary = {}


func _on_report(kind: String, data: Dictionary) -> void:
	_banner_kind = kind
	_banner_data = data
	_render_banner()
	_banner.visible = true


func _render_banner() -> void:
	var loc := Locale.current()
	match _banner_kind:
		"CONSENSUS":
			var c: Dictionary = _banner_data.get("consensus", {})
			_banner_text.text = tr("REPORT_CONSENSUS") % [Money.format(int(c.get("eps", 0)), 2, loc), SimClock.format_time(int(c.get("reportAt", 0)))]
		"NIGHT":
			_banner_text.text = tr("REPORT_NIGHT")
		"OPENED":
			var d := _banner_data
			_banner_text.text = tr("REPORT_OPENED") % [Money.format(int(d["eps"]), 2, loc), Money.format(int(d["consensusEps"]), 2, loc),
				Chronicler.arg_text({"dbps": d["surpriseBps"]}, tr, loc), Chronicler.arg_text({"dbps": d["gapBps"]}, tr, loc),
				tr("QUEST_OUTCOME_" + str(d["outcome"]))]


func _relocale() -> void:
	if _card.visible and not _current.is_empty():
		_render_card()
	if _book.visible:
		_fill_book()
	if _banner.visible:
		_render_banner()

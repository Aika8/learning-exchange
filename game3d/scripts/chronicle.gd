## Evening chronicle (GameFlow state CHRONICLE): the Chronicler narrates SessionFacts computed from the day log —
## R per voyage, expectancy, fees and spread paid, the day against Бабушка Ветла's basket, each lesson's real name.
## «Перечитать летопись» replays the day: the same fold over the first n events (ADR-0023). Template adapter only (M4: LLM).
extends Node3D

var _cam: Camera3D
var _t := 0.0
var _lines: VBoxContainer
var _facts: Label
var _replay_box: VBoxContainer
var _events: Label
var _slider: HSlider
var _playing := false
var _cursor := -1  ## -1 = the whole day
var _play_t := 0.0
var _hud: GameHud
var chronicler: Chronicler = Chronicler.Template.new()


func _ready() -> void:
	Archipelago.sky(self)
	Archipelago.build(self)
	Archipelago.weather(self, 0.0, 1.0)
	for i in 6:  # lanterns on the square at night
		var l := OmniLight3D.new()
		l.light_color = Color("ffb35c")
		l.light_energy = 2.5
		l.omni_range = 9.0
		l.position = Vector3(cos(i * 1.05) * 14, 3, sin(i * 1.05) * 14)
		add_child(l)
	_cam = Camera3D.new()
	_cam.fov = 55
	add_child(_cam)
	_build_ui()
	_hud = GameHud.new()
	add_child(_hud)
	Locale.locale_changed.connect(func(_c: String) -> void: render())
	await Game.sync()
	Game.lesson("CHRONICLE")
	render()
	if Session.active():
		Demo.chronicle(self)


func _process(delta: float) -> void:
	_t += delta
	var a := 2.2 + _t * 0.02
	_cam.position = Vector3(cos(a) * 70, 30, sin(a) * 70)
	_cam.look_at(Vector3(10, 0, 0))
	if _playing:
		_play_t -= delta
		if _play_t <= 0.0:
			_play_t = 0.6
			if _cursor >= Game.daylog.size():
				_playing = false
			else:
				_slider.value = _cursor + 1


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
	top.offset_top = 22
	root.add_child(top)
	var titles := VBoxContainer.new()
	var title := Hud.text("CHRONICLE_TITLE", 36, Hud.BRASS)
	title.add_theme_font_override("font", Hud.serif())
	titles.add_child(title)
	titles.add_child(Hud.lore("CHRONICLE_LORE"))
	top.add_child(titles)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var book := Hud.button("BOOK_BUTTON")
	book.pressed.connect(func() -> void: _hud.toggle_book())
	top.add_child(book)
	top.add_child(Hud.lang_switch())

	# left: the Chronicler's text
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	var lp := Hud.panel(left)
	lp.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	lp.offset_left = 28
	lp.offset_right = 960
	lp.offset_top = 170
	lp.offset_bottom = -110
	root.add_child(lp)
	left.add_child(Hud.text("CHRONICLE_VOICE", 18, Hud.BRASS))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	_lines = VBoxContainer.new()
	_lines.add_theme_constant_override("separation", 8)
	_lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_lines)

	# right: the facts and the replay
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	right.offset_left = -900
	right.offset_right = -28
	right.offset_top = 170
	right.offset_bottom = -110
	root.add_child(right)
	var fb := VBoxContainer.new()
	right.add_child(Hud.panel(fb))
	fb.add_child(Hud.text("FACTS_TITLE", 18, Hud.BRASS))
	fb.add_child(Hud.lore("FACTS_LORE"))
	_facts = Hud.text("", 16)
	_facts.add_theme_font_override("font", Hud.mono())
	fb.add_child(_facts)
	_replay_box = VBoxContainer.new()
	var rp := Hud.panel(_replay_box)
	rp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(rp)
	_replay_box.add_child(Hud.text("REPLAY_TITLE", 18, Hud.BRASS))
	_replay_box.add_child(Hud.lore("REPLAY_LORE"))
	_slider = HSlider.new()
	_slider.min_value = 0
	_slider.step = 1
	_slider.value_changed.connect(func(v: float) -> void: _cursor = int(v); render())
	_replay_box.add_child(_slider)
	var ev_scroll := ScrollContainer.new()
	ev_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ev_scroll.custom_minimum_size = Vector2(0, 200)
	_replay_box.add_child(ev_scroll)
	_events = Hud.text("", 14, Hud.MUTED)
	_events.autowrap_mode = TextServer.AUTOWRAP_WORD
	_events.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ev_scroll.add_child(_events)
	_replay_box.visible = false

	var bottom := HBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 28
	bottom.offset_right = -28
	bottom.offset_top = -86
	bottom.offset_bottom = -30
	bottom.add_theme_constant_override("separation", 14)
	root.add_child(bottom)
	var replay := Hud.button("CHRONICLE_REPLAY")
	replay.name = "Replay"
	replay.pressed.connect(start_replay)
	bottom.add_child(replay)
	var whole := Hud.button("CHRONICLE_WHOLE")
	whole.pressed.connect(func() -> void: _playing = false; _cursor = -1; _replay_box.visible = false; render())
	bottom.add_child(whole)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(sp)
	bottom.add_child(Hud.text("CHRONICLE_NO_ADVICE", 14, Hud.MUTED))
	var next := Hud.button("CHRONICLE_NEXT_DAY")
	next.name = "NextDay"
	next.pressed.connect(next_day)
	bottom.add_child(next)


## Replay: the facts and the chronicle as they stood after each event of the day.
func start_replay() -> void:
	_replay_box.visible = true
	_slider.max_value = Game.daylog.size()
	_slider.set_value_no_signal(0)
	_cursor = 0
	_playing = true
	_play_t = 0.3
	render()


func render() -> void:
	var f := Game.facts(_cursor)
	for c in _lines.get_children():
		c.queue_free()
	for l in chronicler.review(f):
		var key: String = l["key"]
		var size := 20 if key == "CHR_INTRO" else 17
		var color := Hud.MUTED if key == "CHR_DISCLAIMER" or key == "CHR_FEW_TRADES" else Hud.TEXT
		if key == "CHR_LESSON":
			color = Hud.BRASS.lightened(0.2)
		var lab := Hud.text(Chronicler.render(l, tr, Locale.current()), size, color)
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD
		lab.custom_minimum_size = Vector2(880, 0)
		_lines.add_child(lab)
	_facts.text = _facts_text(f)
	if _replay_box.visible:
		_events.text = _events_text(_cursor)


func _facts_text(f: SessionFacts) -> String:
	var loc := Locale.current()
	var rows: PackedStringArray = []
	for v in f.traded():
		rows.append(tr("FACTS_VOYAGE") % [str(v["n"]), str(v["instrument"]), Chronicler.arg_text({"m": v["pnl"]}, tr, loc),
			Chronicler.arg_text({"r": v["r_x100"]}, tr, loc), tr("FACTS_OPEN") if v["open"] else ""])
	if rows.is_empty():
		rows.append(tr("FACTS_NONE"))
	rows.append(tr("FACTS_EXPECTANCY") % Chronicler.arg_text({"r": f.expectancy_x100}, tr, loc))
	rows.append(tr("FACTS_FEES") % Money.format(f.fees, 2, loc))
	rows.append(tr("FACTS_SPREAD") % Money.format(f.spread, 2, loc))
	rows.append(tr("FACTS_YOU") % [Chronicler.arg_text({"m": f.pnl}, tr, loc), Chronicler.arg_text({"bps": f.return_bps()}, tr, loc)])
	rows.append(tr("FACTS_BASKET") % [Chronicler.arg_text({"m": f.basket_pnl()}, tr, loc), Chronicler.arg_text({"bps": f.basket_bps()}, tr, loc)])
	rows.append(tr("FACTS_EVENTS") % [str(_cursor if _cursor >= 0 else Game.daylog.size()), str(Game.daylog.size())])
	return "\n".join(rows)


func _events_text(n: int) -> String:
	var out: PackedStringArray = []
	var loc := Locale.current()
	for e in Game.daylog.upto(n):
		var d: Dictionary = e["data"]
		var t := SimClock.format_time(int(e["t"]))
		var what := ""
		match str(e["kind"]):
			"STATE":
				what = tr("EV_STATE") % tr("FLOW_" + str(d["state"]))
			"LESSON":
				what = tr("EV_LESSON") % [tr(Lessons.title_key(str(d["id"]))), tr(Lessons.real_key(str(d["id"])))]
			"PLAN":
				what = tr("EV_PLAN") % [str(d["instrument"]), Money.format(int(d["entry"]), 2, loc), Money.format(int(d["stop"]), 2, loc), str(d["qty"]), Money.format(int(d["risk"]), 2, loc)]
			"FILL":
				what = tr("EV_FILL") % [tr("SIDE_" + str(d["side"])), str(d["qty"]), str(d["instrument"]), Money.format(int(d["price"]), 2, loc), Money.format(int(d["fee"]), 2, loc)]
			"ANCHOR":
				what = tr("EV_ANCHOR") % [Money.format(int(d["trigger"]), 2, loc), Money.format(int(d["limit"]), 2, loc)]
			"STOP_FIRED":
				what = tr("EV_STOP_FIRED") % [Money.format(int(d["trigger"]), 2, loc), Money.format(int(d["trade"]), 2, loc), str(d.get("filled", 0)), str(d.get("qty", 0))]
			"REPORT":
				what = tr("EV_REPORT") % [Chronicler.arg_text({"bps": d["surpriseBps"]}, tr, loc), Chronicler.arg_text({"bps": d["gapBps"]}, tr, loc)]
			_:
				what = tr("EV_" + str(e["kind"]))
		out.append("%s  %s" % [t, what])
	out.reverse()  # newest first
	return "\n".join(out)


func next_day() -> void:
	Game.move(GameFlow.State.PORT)
	await Game.start_day()
	Session.spawn = "start"
	Session.go("harbour")


func hud() -> GameHud:
	return _hud

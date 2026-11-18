## Voyage (GameFlow state SAILING): the player flies the ship between the islands — W/S trim the sail, A/D the
## wheel, Space up, Shift down, E moors at a pier (ADR-0032). The flight itself is `FlightModel`; this scene reads
## the keys, steps the model and draws. While under way the exchange's simulation clock runs ×60 and goes back to ×1
## on mooring (PUT /clock). The first voyage of a day meets a storm (volatility); the Anchor (stop-loss) is watched
## and may fire at sea. Clock: GET /clock once, then the `clock` channel; extrapolated between messages — SimClock.
extends Node3D

const SEA_SPEED := 60
const STORM_FROM := 0.3  ## of the straight distance to the destination
const STORM_TO := 0.72
const FREE_STORM := 400.0  ## the distance the storm is measured against when flying free

var _instrument := "SILK-SPARK"
var _storm := 0.0
var _storm_met := false
var _rain: GPUParticles3D
var _flash := 0.0
var _sync_t := 0.0
var _fired_seen := 0
var _ghud: GameHud
var _from := "harbour"
var _to := ""  ## the island marked on the chart; "" = flying free
var _span := FREE_STORM  ## straight distance from the berth left to the one marked

var model: FlightModel
var _ship: Node3D
var _cam: Camera3D
var _yaw := 0.0  ## the camera, round the ship: 0 = from astern
var _pitch := -0.22
var _dist := 26.0
var _wind := Vector3(1, 0, -0.6)
var _clock: SimClock
var _start_sim := -1
var _last := -1
var _ui: Dictionary = {}
var _parts: Dictionary
var _arrived := false
var _at := ""  ## the port the ship can moor at now
var _t := 0.0
var _auto := false  ## the demo run steers by the compass
var _gust_t := 0.0


func _ready() -> void:
	Archipelago.sky(self)
	_parts = Archipelago.build(self)
	if Game.plan != null:
		_instrument = Game.plan.instrument
	_from = Game.island if Ports.has(Game.island) else "harbour"
	_to = Game.destination if Ports.has(Game.destination) and Game.destination != _from else ""
	Session.set_style(Game.island)  # under way the ship is still drawn the way the island it left is
	model = Ports.cast_off(_from)
	if not _to.is_empty():
		_span = maxf(model.distance_to(Ports.berth(_to)), 1.0)
	_ship = Proc.ship()
	_ship.position = model.position
	add_child(_ship)
	var monkey := Monkey.new()  # under way she lives in the rig (ADR-0036)
	monkey.ship = _ship
	add_child(monkey)
	_cam = Camera3D.new()
	_cam.fov = 60
	_cam.far = 3000
	add_child(_cam)
	_build_ui()
	_ghud = GameHud.new()
	add_child(_ghud)
	_rain = _make_rain()
	_cam.add_child(_rain)
	_storm_met = Game.facts().storms > 0
	Game.record("VOYAGE_START", {"from": _from, "to": _to if not _to.is_empty() else "free"})
	Game.set_speed(SEA_SPEED)
	MarketStream.clock_received.connect(_on_clock)
	MarketStream.trades_received.connect(_on_trades)
	MarketStream.book_received.connect(func(bk: BookModel) -> void: if bk.last_price >= 0: _last = bk.last_price)
	MarketStream.open(ExchangeApi.token, ["clock", "market.%s.trades" % _instrument, "market.%s.book" % _instrument])
	var r: Dictionary = await ExchangeApi.call_api(HTTPClient.METHOD_GET, "/clock")
	if r["ok"] and r["data"] is Dictionary:
		_on_clock(SimClock.from_dict(r["data"], Time.get_ticks_msec()))
	if Session.active():
		Demo.voyage(self)


func _exit_tree() -> void:
	MarketStream.close()


func _on_clock(c: SimClock) -> void:
	_clock = c
	if _start_sim < 0:
		_start_sim = c.at(Time.get_ticks_msec())


func _on_trades(trades: Array) -> void:
	if not trades.is_empty() and trades[-1] is Dictionary:
		_last = int(trades[-1]["price"])


func _process(delta: float) -> void:
	_t += delta
	_wind = Vector3(cos(_t * 0.05) * 1.0, 0, -0.6 + sin(_t * 0.07) * 0.4)
	_weather(delta)
	_sync_t -= delta
	if _sync_t <= 0.0:
		_sync_t = 2.0
		_watch_anchor()
	var keys := _keys()
	if not _arrived:
		fly(delta, keys.x, keys.y, keys.z)
	_ship.position = model.position + Vector3(0, sin(_t * 1.3) * 0.35, 0)
	var roll := 1.0 + _storm * 3.0
	var lean := -keys.x * 0.12 * clampf(model.speed / FlightModel.BASE_SPEED, 0.0, 1.0)  # she heels into a turn
	_ship.rotation = Vector3(sin(_t * 0.9) * 0.025 * roll, model.yaw, sin(_t * 1.1) * 0.05 * roll + lean)
	Wayfarer.set_trim(_ship, model.trim, minf(4.0 * delta, 1.0))
	var blades: Node3D = _parts.get("blades")
	if blades:
		blades.rotation.z += delta * 0.5
	var around := model.yaw + _yaw
	var dir := Vector3(sin(around) * cos(_pitch), -sin(_pitch), cos(around) * cos(_pitch))
	var focus := _ship.position + Vector3(0, 3, 0)
	_cam.position = _cam.position.lerp(focus + dir * _dist, minf(1.0, 6.0 * delta)) if _t > 0.2 else focus + dir * _dist
	_cam.look_at(focus)
	_hud()


## What the player asks of the ship now: x = wheel (1 = to port), y = sail (1 = let out), z = climb.
func _keys() -> Vector3:
	if _arrived:
		return Vector3.ZERO
	if _auto:
		return _autopilot()
	if _ghud != null and _ghud.is_modal():
		return Vector3.ZERO
	return Vector3(Input.get_axis("move_right", "move_left"), Input.get_axis("move_back", "move_forward"),
		float(Input.is_key_pressed(KEY_SPACE)) - float(Input.is_key_pressed(KEY_SHIFT)))


## One step of flight with the weather of the moment. The tests and the demo call it too.
func fly(delta: float, rudder: float, sail: float, climb: float) -> void:
	_gust_t += delta
	var gust := Vector3(sin(_gust_t * 1.7), 0, cos(_gust_t * 1.3)) * 4.0 * _storm
	model.step(delta, rudder, sail, climb, _wind, lerpf(1.0, 0.6, clampf(_storm * 2.0 - 0.5, 0.0, 1.0)), gust)
	_at = Ports.mooring(model)
	if model.flown < 60.0 and _at == _from:
		_at = ""  # just cast off: not asked to moor where she lay


## The screenshot run has nobody at the wheel: a helmsman steers for the marked island by the compass.
func _autopilot() -> Vector3:
	return Ports.steer(model, _to if not _to.is_empty() else "silk")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var m := event as InputEventMouseMotion
		_yaw -= m.relative.x * 0.005
		_pitch = clampf(_pitch + m.relative.y * 0.004, -1.2, 0.5)
	elif event is InputEventMouseButton and event.pressed:
		var b := event as InputEventMouseButton
		if b.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = maxf(10.0, _dist - 1.5)
		elif b.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = minf(70.0, _dist + 1.5)
	elif event.is_action_pressed("interact") and not _arrived:
		moor()


## Moors at the pier the ship lies off, if there is one. True when she did.
func moor() -> bool:
	if _arrived or _at.is_empty():
		return false
	_arrive(_at)
	return true


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
	root.add_child(top)
	var title := Hud.text("", 32, Hud.BRASS)
	title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	title.add_theme_font_override("font", Hud.serif())
	top.add_child(title)
	_ui["title"] = title
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	top.add_child(Hud.lang_switch())
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 4)
	var panel := Hud.panel(card)
	panel.position = Vector2(28, 100)
	panel.custom_minimum_size = Vector2(430, 0)
	root.add_child(panel)
	for k: String in ["clock", "clock_lore", "speed", "elapsed", "progress", "wind", "helm", "market"]:
		var l := Hud.text("", 26 if k == "clock" else 16, Hud.BRASS if k == "clock" else Hud.TEXT)
		if k == "clock":
			l.add_theme_font_override("font", Hud.mono())
		if k == "clock_lore":
			l = Hud.lore("VOYAGE_CLOCK_LORE")
		if k != "clock_lore":
			l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		card.add_child(l)
		_ui[k] = l
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 10)
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.add_theme_stylebox_override("fill", Hud.box(Hud.BRASS, Hud.BRASS, 0, 4))
	bar.add_theme_stylebox_override("background", Hud.box(Color(0, 0, 0, 0.35), Hud.LINE, 0, 4))
	card.add_child(bar)
	_ui["bar"] = bar
	var help := Hud.text("VOYAGE_HELP", 15, Hud.MUTED)
	help.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	help.offset_left = 28
	help.offset_top = -44
	root.add_child(help)
	var arrive := VBoxContainer.new()
	arrive.add_theme_constant_override("separation", 10)
	var arrive_panel := Hud.panel(arrive)
	arrive_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	arrive_panel.offset_left = -300
	arrive_panel.offset_right = 300
	arrive_panel.offset_top = -230
	arrive_panel.offset_bottom = -110
	arrive_panel.visible = false
	root.add_child(arrive_panel)
	var msg := Hud.text("", 22, Hud.TEXT)
	msg.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrive.add_child(msg)
	_ui["arrived"] = msg
	var compass := FlightCompass.new()
	compass.set_anchors_preset(Control.PRESET_CENTER_TOP)
	compass.position = Vector2(-330, 84)
	compass.size = Vector2(660, 56)
	root.add_child(compass)
	_ui["compass"] = compass
	var chart := FlightChart.new()
	chart.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	chart.position = Vector2(-260, -330)
	chart.size = Vector2(232, 232)
	root.add_child(chart)
	_ui["chart"] = chart
	var prompt := Hud.text("", 24, Hud.TEXT)
	prompt.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.offset_top = -170
	prompt.offset_left = -500
	prompt.offset_right = 500
	root.add_child(prompt)
	_ui["prompt"] = prompt
	var home := Hud.button("VOYAGE_ASHORE")
	home.name = "Home"
	home.pressed.connect(disembark)
	arrive.add_child(home)
	_ui["arrive"] = arrive_panel


func _hud() -> void:
	var now := Time.get_ticks_msec()
	var names := Ports.all()
	(_ui["title"] as Label).text = tr("VOYAGE_COURSE") % tr(names[_to]["name"]) if not _to.is_empty() else tr("VOYAGE_FREE")
	if _clock != null:
		var sim := _clock.at(now)
		(_ui["clock"] as Label).text = tr("VOYAGE_CLOCK") % SimClock.format_time(sim)
		(_ui["speed"] as Label).text = tr("VOYAGE_PAUSED") if _clock.paused else tr("VOYAGE_SPEED") % str(_clock.speed)
		(_ui["elapsed"] as Label).text = tr("VOYAGE_ELAPSED") % SimClock.format_duration(sim - _start_sim)
	var left := model.distance_to(Ports.berth(_to)) if not _to.is_empty() else 0.0
	(_ui["progress"] as Label).text = tr("VOYAGE_LEFT") % str(int(left)) if not _to.is_empty() else tr("VOYAGE_FLOWN") % str(int(model.flown))
	(_ui["bar"] as ProgressBar).value = clampf(1.0 - left / _span, 0.0, 1.0) if not _to.is_empty() else 0.0
	var help := model.wind_help(_wind)
	(_ui["wind"] as Label).text = tr("VOYAGE_WIND") % tr("VOYAGE_WIND_FAIR" if help > 0.3 else ("VOYAGE_WIND_HEAD" if help < -0.3 else "VOYAGE_WIND_SIDE"))
	(_ui["helm"] as Label).text = tr("VOYAGE_HELM") % [str(int(model.speed)), str(int(model.trim * 100.0)), str(int(model.position.y - model.floor_y))]
	var ps := int(ExchangeApi.instrument(_instrument)["priceScale"])
	(_ui["market"] as Label).text = tr("VOYAGE_MARKET") % [_instrument, Money.format(_last, ps, Locale.current()) if _last >= 0 else "—"]
	var prompt := ""
	if not _arrived and not _at.is_empty():
		prompt = tr("VOYAGE_MOOR") % tr(names[_at]["name"])
	elif not _arrived and model.edge_push() > 0.05:
		prompt = tr("VOYAGE_EDGE")
	elif not _arrived and not _to.is_empty() and model.distance_to(Ports.berth(_to)) < 60.0 and model.speed > FlightModel.MOOR_SPEED:
		prompt = tr("VOYAGE_TOO_FAST")
	(_ui["prompt"] as Label).text = prompt
	(_ui["compass"] as FlightCompass).show_from(model, _to, _wind)
	(_ui["chart"] as FlightChart).show_from(model, _to)


func _arrive(at: String) -> void:
	_arrived = true
	(_ui["arrived"] as Label).text = tr("VOYAGE_ARRIVED_AT") % tr(Ports.all()[at]["name"])
	(_ui["arrive"] as Control).visible = true
	Game.island = at
	Game.destination = ""
	Game.record("VOYAGE_END", {"at": Game.island})
	await Game.set_speed(1)
	await Game.sync()


func disembark() -> void:
	Session.spawn = "pier"
	Session.go("harbour")


# ---------------------------------------------------------------- storm and the Anchor

## The first voyage of the day crosses a storm between STORM_FROM and STORM_TO of the route.
func _weather(delta: float) -> void:
	var p := model.flown / _span  # the storm lies across the way: a share of the straight distance
	var want := 1.0 if (not _storm_met or _storm > 0.0) and p > STORM_FROM and p < STORM_TO else 0.0
	if want > 0.0 and _storm == 0.0 and not _storm_met:
		_storm_met = true
		Game.record("STORM")
		_storm_lesson()
	if _storm_met or _storm > 0.0:
		_storm = move_toward(_storm, want if p < STORM_TO else 0.0, delta * 0.5)
	_flash = maxf(0.0, _flash - delta * 3.0)
	if _storm > 0.6 and randf() < delta * 0.25:
		_flash = 1.0
	Archipelago.weather(self, _storm)
	var sun: DirectionalLight3D = get_node_or_null("Sun")
	if sun and _flash > 0.0:
		sun.light_energy += _flash * 3.0
	_rain.emitting = _storm > 0.25
	_rain.amount_ratio = clampf(_storm, 0.0, 1.0)


func _storm_lesson() -> void:
	var r: Dictionary = await ExchangeApi.call_api(HTTPClient.METHOD_GET, "/economy/rates")
	var vol := int(r["data"].get("volatilityPct", 100)) if r["ok"] and r["data"] is Dictionary else 100
	var atr: int = await Game.atr_of(_instrument)
	Game.lesson("STORM", [str(vol), {"p": atr}, {"p": 2 * atr}])


func _watch_anchor() -> void:
	await Game.sync()
	var f := Game.facts()
	if f.stops_fired > _fired_seen:
		_fired_seen = f.stops_fired
		var e := Game.daylog.last_of("STOP_FIRED")
		var d: Dictionary = e.get("data", {})
		_ghud.toast(tr("VOYAGE_ANCHOR_FIRED") % [Money.format(int(d.get("trigger", 0)), 2, Locale.current()),
			Money.format(int(d.get("trade", 0)), 2, Locale.current())])


func _make_rain() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 2500
	p.lifetime = 1.2
	p.emitting = false
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-40, -40, -40), Vector3(80, 80, 80))
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(30, 2, 30)
	m.direction = Vector3(0.2, -1, 0.1)
	m.spread = 4.0
	m.initial_velocity_min = 38.0
	m.initial_velocity_max = 46.0
	m.gravity = Vector3(0, -20, 0)
	p.process_material = m
	var q := QuadMesh.new()
	q.size = Vector2(0.03, 0.9)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.8, 0.85, 0.95, 0.35)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	q.material = mat
	p.draw_pass_1 = q
	p.position = Vector3(0, 14, -6)
	return p


## Demo hooks: the screenshot run puts the ship a share of the way along the straight line to the marked island
## and lets the compass steer her in.
func demo_progress(p: float, yaw: float, pitch: float, dist: float) -> void:
	var to := Ports.berth(_to if not _to.is_empty() else "silk")
	var from := Ports.berth(_from)
	_auto = true
	model.position = from.lerp(to, p) + Vector3(0, 40.0 * sin(PI * clampf(p, 0.0, 1.0)), 0)
	model.flown = _span * p
	model.yaw = atan2(-(to.x - from.x), -(to.z - from.z))
	_yaw = yaw
	_pitch = pitch
	_dist = dist
	if p > 0.95:
		model.speed = 2.0
		model.trim = 0.2
		model.position = to - model.heading() * 8.0
		_at = Ports.mooring(model)
		moor()


func demo_storm(level: float) -> void:
	_storm_met = true
	_storm = level


func hud() -> GameHud:
	return _ghud


func arrived() -> bool:
	return _arrived

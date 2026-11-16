## Voyage between Spark Harbour and Silk Reach (GameFlow state SAILING): the ship sails a route over the cloud sea and
## the sail itself advances the exchange's simulation clock (×60 while at sea, ×1 again on arrival — PUT /clock).
## The first voyage of a day meets a storm (volatility); the Anchor (stop-loss) is watched and may fire at sea.
## Clock: GET /clock once, then the `clock` channel; extrapolated between messages — SimClock.
extends Node3D

const SEA_SPEED := 60
const STORM_FROM := 0.3
const STORM_TO := 0.72

var _instrument := "SILK-SPARK"
var _storm := 0.0
var _storm_met := false
var _rain: GPUParticles3D
var _flash := 0.0
var _sync_t := 0.0
var _fired_seen := 0
var _hud: GameHud
var _home := false

var _model: VoyageModel
var _ship: Node3D
var _sail: Node3D
var _cam: Camera3D
var _yaw := 2.4
var _pitch := -0.22
var _dist := 26.0
var _sail_up := true
var _wind := Vector3(1, 0, -0.6)
var _clock: SimClock
var _start_sim := -1
var _last := -1
var _ui: Dictionary = {}
var _parts: Dictionary
var _arrived := false
var _t := 0.0


func _ready() -> void:
	Archipelago.sky(self)
	_parts = Archipelago.build(self)
	if Game.plan != null:
		_instrument = Game.plan.instrument
	_home = Game.island == "silk"
	var a := Archipelago.PIER_END + Vector3(4, 1.2, 4.5)
	var b := Archipelago.SILK_DOCK + Vector3(-4, 1.2, 4)
	_model = VoyageModel.new(b, Vector3(200, 14, 60), a) if _home else VoyageModel.new(a, Vector3(200, 14, 60), b)
	_ship = Proc.ship()
	_ship.position = a
	add_child(_ship)
	_sail = _ship.get_node_or_null("Sail")  # the model ship (ADR-0019) has fixed sails
	_cam = Camera3D.new()
	_cam.fov = 60
	_cam.far = 3000
	add_child(_cam)
	_build_ui()
	_hud = GameHud.new()
	add_child(_hud)
	_rain = _make_rain()
	_cam.add_child(_rain)
	_storm_met = Game.facts().storms > 0
	Game.record("VOYAGE_START", {"from": Game.island, "to": "harbour" if _home else "silk"})
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
	if not _arrived:
		_model.advance(delta * (0.6 if _storm > 0.5 else 1.0), _sail_up, _wind)
		if _model.arrived():
			_arrive()
	var p := _model.progress()
	var h := _model.heading(p)
	var pos := _model.point(p)
	pos.y += sin(_t * 1.3) * 0.35
	_ship.position = pos
	var roll := 1.0 + _storm * 3.0
	_ship.rotation = Vector3(sin(_t * 0.9) * 0.025 * roll, atan2(-h.x, -h.z), sin(_t * 1.1) * 0.05 * roll - 0.04 * _model.wind_help(_wind))
	if _sail:
		_sail.scale.y = lerpf(_sail.scale.y, 1.0 if _sail_up else 0.25, 4.0 * delta)
		_sail.position.y = 4.8 + (1.0 - _sail.scale.y) * 2.4
	var blades: Node3D = _parts.get("blades")
	if blades:
		blades.rotation.z += delta * 0.5
	var dir := Vector3(sin(_yaw) * cos(_pitch), -sin(_pitch), cos(_yaw) * cos(_pitch))
	var focus := _ship.position + Vector3(0, 3, 0)
	_cam.position = _cam.position.lerp(focus + dir * _dist, minf(1.0, 6.0 * delta)) if _t > 0.2 else focus + dir * _dist
	_cam.look_at(focus)
	_hud()


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
	elif event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_SPACE:
		_sail_up = not _sail_up


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
	var title := Hud.text("VOYAGE_TITLE_HOME" if _home else "VOYAGE_TITLE", 32, Hud.BRASS)
	title.add_theme_font_override("font", Hud.serif())
	top.add_child(title)
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
	for k: String in ["clock", "clock_lore", "speed", "elapsed", "progress", "wind", "market"]:
		var l := Hud.text("", 26 if k == "clock" else 16, Hud.BRASS if k == "clock" else Hud.TEXT)
		if k == "clock":
			l.add_theme_font_override("font", Hud.mono())
		if k == "clock_lore":
			l = Hud.lore("VOYAGE_CLOCK_LORE")
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
	var msg := Hud.text("VOYAGE_ARRIVED_HOME" if _home else "VOYAGE_ARRIVED", 22, Hud.TEXT)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrive.add_child(msg)
	var home := Hud.button("VOYAGE_ASHORE")
	home.name = "Home"
	home.pressed.connect(disembark)
	arrive.add_child(home)
	_ui["arrive"] = arrive_panel


func _hud() -> void:
	var now := Time.get_ticks_msec()
	if _clock != null:
		var sim := _clock.at(now)
		(_ui["clock"] as Label).text = tr("VOYAGE_CLOCK") % SimClock.format_time(sim)
		(_ui["speed"] as Label).text = tr("VOYAGE_PAUSED") if _clock.paused else tr("VOYAGE_SPEED") % str(_clock.speed)
		(_ui["elapsed"] as Label).text = tr("VOYAGE_ELAPSED") % SimClock.format_duration(sim - _start_sim)
	(_ui["progress"] as Label).text = tr("VOYAGE_PROGRESS") % str(int(_model.progress() * 100.0))
	(_ui["bar"] as ProgressBar).value = _model.progress()
	(_ui["wind"] as Label).text = tr("VOYAGE_WIND") % tr("VOYAGE_WIND_FAIR" if _model.wind_help(_wind) > 0.3 else "VOYAGE_WIND_SIDE")
	var ps := int(ExchangeApi.instrument(_instrument)["priceScale"])
	(_ui["market"] as Label).text = tr("VOYAGE_MARKET") % [_instrument, Money.format(_last, ps, Locale.current()) if _last >= 0 else "—"]


func _arrive() -> void:
	_arrived = true
	(_ui["arrive"] as Control).visible = true
	Game.island = "harbour" if _home else "silk"
	Game.record("VOYAGE_END", {"at": Game.island})
	await Game.set_speed(1)
	await Game.sync()


func disembark() -> void:
	Session.spawn = "pier"
	Session.go("harbour")


# ---------------------------------------------------------------- storm and the Anchor

## The first voyage of the day crosses a storm between STORM_FROM and STORM_TO of the route.
func _weather(delta: float) -> void:
	var p := _model.progress()
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
		_hud.toast(tr("VOYAGE_ANCHOR_FIRED") % [Money.format(int(d.get("trigger", 0)), 2, Locale.current()),
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


## Demo hooks.
func demo_progress(p: float, yaw: float, pitch: float, dist: float) -> void:
	_model.travelled = _model.length * p
	_yaw = yaw
	_pitch = pitch
	_dist = dist


func demo_storm(level: float) -> void:
	_storm_met = true
	_storm = level


func hud() -> GameHud:
	return _hud


func arrived() -> bool:
	return _arrived

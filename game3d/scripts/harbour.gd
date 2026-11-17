## Port scene of both islands of the slice (GameFlow state PORT / PLAN). Spark Harbour: the Exchange, Mara (plan the
## voyage), Ольва Перо (consensus of the Кузня report), the Chronicler (evening), Act I spots — grandfather's chest
## (debt), provisions (cushion), the garden (compound interest), the Treasurers' notice board (fog = inflation).
## Silk Reach: the silk trading post (liquidity). Walk the captain (WASD + mouse) or fly (Tab); E interacts, G — glossary.
extends Node3D

## id → [position, prompt key, radius]; positions on the island top (y = 0 at the harbour, −6 at Silk Reach).
const HARBOUR_SPOTS := {
	"exchange": [Archipelago.EXCHANGE_DOOR, "PROMPT_EXCHANGE", 5.0],
	"ship": [Archipelago.PIER_END, "PROMPT_SHIP", 9.0],
	"mara": [Archipelago.MARA_POS, "PROMPT_MARA", 4.0],
	"olva": [Vector3(10, 0, 9), "PROMPT_OLVA", 3.5],
	"chronicler": [Vector3(-7, 0, -4), "PROMPT_CHRONICLER", 3.5],
	"debt": [Vector3(38, Archipelago.DECK_Y, -2.4), "PROMPT_DEBT", 3.2],
	"provisions": [Vector3(37, Archipelago.DECK_Y, 10.4), "PROMPT_PROVISIONS", 3.2],
	"garden": [Vector3(-14, 0, 12), "PROMPT_GARDEN", 4.0],
	"fog": [Vector3(15, 0, -4), "PROMPT_FOG", 3.2],
	"ferry": [FERRY_POST + Vector3(0, 0, 1.3), "PROMPT_FERRY", 2.4],
}
const FERRY_POST := Vector3(33.0, Archipelago.DECK_Y, -3.9)  ## the signpost of the packet boat to Amber Cliff
const SILK_POST := Archipelago.SILK + Vector3(-12, 0, 8)
const SILK_SPOTS := {
	"post": [SILK_POST, "PROMPT_POST", 5.0],
	"ship": [Archipelago.SILK_DOCK, "PROMPT_SHIP_HOME", 9.0],
}
const DEBT := 5000000  ## grandfather's debt: 50 000.00 ✦
const DEBT_RATE := 3600  ## 36% a year, monthly

var _captain: Captain
var _fly: Camera3D
var _flying := false
var _prompt: Label
var _help: Label
var _dialog: PanelContainer
var _dialog_text: Label
var _account: Label
var _parts: Dictionary
var _target := ""
var _fly_yaw := 0.0
var _fly_pitch := -0.3
var _hud: GameHud
var _plan: PlanPanel
var _post: PanelContainer
var _post_text: Label
var _post_qty := 0
var _villagers: Array[Villager] = []
var _idlers: Array[Walker] = []
var _nav: NavigationRegion3D
var _report_timer := 0.0
var _comic: ComicPage
var _talker: Villager
var _glossing := false  ## T is held: the island's words are shown in the game's language (ADR-0028)
var _gloss: Label
var _signs: Array[Label3D] = []
var _title: Label


func _silk() -> bool:
	return Game.island == "silk"


func _amber() -> bool:
	return Game.island == AmberCliff.ID


## Amber Cliff (ADR-0028): each keeper teaches one idea, in French. id → [position, prompt key, radius].
static func amber_spots() -> Dictionary:
	var out := {"ship": [AmberCliff.PIER_FROM + Vector3(6.0, 0, 2.4), "AMB_PROMPT_SHIP", 5.0],
		"lighthouse": [AmberCliff.lighthouse_spot()[1], "AMB_PROMPT_LIGHTHOUSE", 3.0]}
	for id: String in ["change", "bank", "bakery", "cafe", "books"]:
		out[id] = [AmberCliff.door(id)[1], "AMB_PROMPT_" + id.to_upper(), 3.0]
	return out


func _spots() -> Dictionary:
	if _amber():
		return amber_spots()
	return SILK_SPOTS if _silk() else HARBOUR_SPOTS


## The words of `key` as the island the captain stands on says them; with T held, in the game's language.
func _shown(key: String) -> String:
	return tr(key) if _glossing else IslandTongue.shown(key, Game.island)


func _ready() -> void:
	Archipelago.sky(self)
	_parts = Archipelago.build(self)
	_dress()
	_nav = Nav.bake(self, Archipelago.walk_areas(Game.island))
	for l in find_children("Sign", "Label3D", true, false):
		_signs.append(l)
	var ship := Proc.ship()
	ship.name = "Wayfarer"
	ship.position = (Archipelago.SILK_DOCK + Vector3(-4, 1.2, 4)) if _silk() else Archipelago.PIER_END + Vector3(0, 1.2, 5.5)  # the wind vane clears the heads of people on the pier
	if _amber():
		ship.position = AmberCliff.DOCK + Vector3(0, 1.2, 0)
	ship.rotation.y = PI / 2
	add_child(ship)
	_captain = Captain.new()
	add_child(_captain)
	var at := Archipelago.spawn_point(Game.island, Session.spawn)
	_captain.position = at[0]
	_captain.respawn = at[0]
	_captain.yaw = at[1]
	Session.set_style(Game.island)
	if Game.attuned != Game.island and not Session.tooling():
		Session.attune(_captain, Game.attuned, Game.island)  # the island's wind takes the newcomer in (ADR-0025)
	_fly = Camera3D.new()
	_fly.fov = 65
	add_child(_fly)
	_build_ui()
	_hud = GameHud.new()
	add_child(_hud)
	_hud.modal_changed.connect(_on_modal)
	Game.report_event.connect(_on_report)
	if Game.flow.state == GameFlow.State.SAILING:  # arrived
		Game.move(GameFlow.State.PORT)
	if Session.active():
		_demo()
	elif not Session.tooling():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## People and Act I props. Each NPC is a MakeHuman character when downloaded (ADR-0019). Everything stands on the
## ground and has a collider; the strollers walk the navmesh (Villager).
func _dress() -> void:
	if _amber():
		_dress_amber()
		return
	if _silk():
		var post_y := Archipelago.silk_ground(SILK_POST - Archipelago.SILK)
		var keeper := _npc("trader", Color("9a6ab0"), SILK_POST + Vector3(0, post_y, -1.6), 0.0)
		keeper.name = "PostKeeper"
		for i in 4:
			var at := SILK_POST + Vector3(-2.2 + i * 1.4, 0, -2.8)
			at.y += Archipelago.silk_ground(at - Archipelago.SILK)
			Assets.put(self, "wooden_crate_02" if i % 2 else "wooden_crate_01", at, i * 0.4, 1.0)
		_villager("child", Color("6a9ab0"), Archipelago.SILK + Vector3(2, 0, 4), 9.0)
		_villager("sailor", Color("4e6fa8"), Archipelago.SILK + Vector3(-12, 0, 12), 8.0, "sailor2")
		return
	var post := Node3D.new()  # the packet boat to Amber Cliff: a signpost on the wharf (ADR-0028)
	post.name = "FerryPost"
	post.position = FERRY_POST
	add_child(post)
	post.add_child(Proc.box(Vector3(0.14, 2.6, 0.14), Proc.TIMBER_DARK, Vector3(0, 1.3, 0)))
	post.add_child(Proc.box(Vector3(2.3, 0.5, 0.08), Color("2b4f8c"), Vector3(0, 2.4, 0)))
	post.add_child(AmberCliff.word_sign("AMB_SIGN_FERRY", Vector3(0, 2.4, 0.05), 0.0, 40, AmberCliff.TRIM))
	Solid.post(post, 0.1, 2.6, Vector3.ZERO)
	var mara := _npc("trader", Color("7a4e8a"), Archipelago.MARA_POS, -PI / 2, "mara")
	mara.name = "Mara"
	_npc("trader", Color("5a7a4a"), HARBOUR_SPOTS["olva"][0], PI * 0.8, "olva").name = "Olva"
	_npc("", Color("3a3a5a"), HARBOUR_SPOTS["chronicler"][0], 0.6, "chronicler").name = "Chronicler"
	if Assets.put(self, "treasure_chest", HARBOUR_SPOTS["debt"][0], 1.2, 1.0) == null:
		add_child(Props.chest(HARBOUR_SPOTS["debt"][0], 1.2))  # grandfather's chest, as on sheet 25
	for i in 5:
		var p: Vector3 = HARBOUR_SPOTS["provisions"][0] + (Vector3(-1.6 + i * 1.2, 0, -1.4) if i < 3 else Vector3(-2.6 + (i - 3) * 4.4, 0, -0.2))
		if Assets.put(self, "wooden_barrels_01" if i == 4 else "wooden_crate_01", p, i * 0.5, 1.0) == null:
			add_child(Props.barrel(p) if i == 4 else Props.crate(p, i * 0.5))
	var g: Vector3 = HARBOUR_SPOTS["garden"][0]
	var rng := RandomNumberGenerator.new()
	rng.seed = 72
	for i in 3:  # the garden: three trees, each season taller (compound interest)
		var at := g + Vector3(-3 + i * 3, 0, -2)
		var size := 0.6 + 0.45 * i
		var t := Assets.thinned("island_tree_02", 3)
		if t != null:
			t.set_meta("asset", "island_tree_02")
			t.scale = Vector3.ONE * size * 1.3
			t.rotation.y = i * 2.1
		else:
			t = Proc.round_tree(rng)
			t.scale = Vector3.ONE * size
		t.name = "GardenTree"
		t.position = at
		add_child(t)
		Solid.model(self, t, "island_tree_02" if t.has_meta("asset") else "procedural")
	var board := Node3D.new()  # the Treasurers' notice board: one object on two legs
	board.name = "TreasuryBoard"
	board.position = HARBOUR_SPOTS["fog"][0] + Vector3(0, 0, -1.4)
	add_child(board)
	board.add_child(Proc.box(Vector3(2.4, 1.6, 0.12), Proc.TIMBER_DARK, Vector3(0, 1.9, 0)))
	board.add_child(Proc.box(Vector3(2.1, 1.3, 0.14), Proc.TIMBER, Vector3(0, 1.9, 0.02)))
	var pinned := Kit.new()  # sheet 25: a little roof and papers pinned to the planks
	Props.notice_papers(pinned, 2.4, 1.9, 0.02)
	board.add_child(pinned.commit("Papers"))
	for x: float in [-1.0, 1.0]:
		board.add_child(Proc.box(Vector3(0.12, 1.2, 0.12), Proc.TIMBER_DARK, Vector3(x, 0.6, 0)))
		Solid.post(board, 0.09, 1.2, Vector3(x, 0, 0))
	Solid.box(board, Vector3(2.4, 1.6, 0.14), Vector3(0, 1.9, 0))
	var label := Label3D.new()
	label.render_priority = 110  # drawn after the ink post-effect (priority 100), so the writing stays readable
	label.outline_render_priority = 109
	label.text = "BOARD_TREASURY"
	label.font_size = 40
	label.outline_size = 8
	label.modulate = Proc.TIMBER_DARK
	label.position = Vector3(0, 2.3, 0.12)
	board.add_child(label)
	var homes := [[Vector3(2, 0, 3), 7.0], [Vector3(-6, 0, 2), 9.0], [Vector3(8, 0, 4), 8.0], [Vector3(-3, 0, -3), 10.0], [Vector3(30, 0.2, 2), 6.0]]
	var who := ["child", "oldman", "sailor", "trader", "sailor"]
	var roles := ["child", "townsman", "sailor", "trader", "sailor3"]
	for i in homes.size():  # villagers strolling round the square and the wharf
		_villager(who[i], Color("8a6a4a"), homes[i][0], homes[i][1], roles[i])


## Amber Cliff: a keeper at every door and five people strolling, each with a talk of their own (data/talks.json).
func _dress_amber() -> void:
	var cast := ComicScript.read().cast
	var keepers := {"change": "changeur", "bank": "banquiere", "bakery": "boulangere", "cafe": "garcon", "books": "libraire"}
	for shop: String in keepers:
		var c: Dictionary = cast[keepers[shop]]
		var at := AmberCliff.door(shop)
		var n := _npc(str(c["who"]), Color(str(c["coat"])), at[0], atan2(at[1].x - at[0].x, at[1].z - at[0].z), str(c["role"]))
		n.name = "Keeper_" + shop
	var light := AmberCliff.lighthouse_spot()
	var g: Dictionary = cast["gardienne"]
	_npc(str(g["who"]), Color(str(g["coat"])), light[0], atan2(light[1].x - light[0].x, light[1].z - light[0].z), str(g["role"])).name = "Keeper_lighthouse"
	var homes := {"marin": [Vector3(-26, 0, 0), 6.0], "fleuriste": [Vector3(-4, 0, 6), 5.0], "enfant": [Vector3(5, 0, -5), 8.0],
		"monsieur": [Vector3(-22, 0, 1), 8.0], "etudiante": [Vector3(24, 0, 0), 6.0]}
	for id: String in homes:
		var c: Dictionary = cast[id]
		_villager(str(c["who"]), Color(str(c["coat"])), AmberCliff.AT + (homes[id][0] as Vector3), homes[id][1], str(c["role"]))
		_villagers[-1].set_meta("talk", "amber_" + id)


func _npc(who: String, coat: Color, pos: Vector3, yaw: float, role: String = "") -> Node3D:
	var n := Proc.figure(coat, Color("2a3550"), who, role)
	n.position = pos
	n.rotation.y = yaw
	add_child(n)
	n.set_meta("solid", Solid.person(self, pos))
	var w := Walker.attach(n)  # stands, breathes, shifts weight
	_idlers.append(w)
	return n


func _villager(who: String, coat: Color, home: Vector3, roam: float, role: String = "") -> void:
	var v := Villager.new()
	v.setup(who, coat, home, roam)
	v.role = role
	add_child(v)
	_villagers.append(v)


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
	var title := Hud.text("SILK_TITLE" if _silk() else "HARBOUR_TITLE", 36, Hud.BRASS)
	title.add_theme_font_override("font", Hud.serif())
	titles.add_child(title)
	_title = title
	if _amber():  # the island names itself in its own tongue
		title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		title.text = _shown("AMB_TITLE")
	_account = Hud.text("", 15, Hud.TEXT)
	titles.add_child(_account)
	top.add_child(titles)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var book := Hud.button("BOOK_BUTTON")
	book.pressed.connect(func() -> void: _hud.toggle_book())
	top.add_child(book)
	top.add_child(Hud.lang_switch())
	_prompt = Hud.text("", 24, Hud.TEXT)
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.offset_top = -170
	_prompt.offset_left = -500
	_prompt.offset_right = 500
	root.add_child(_prompt)
	_prompt.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_gloss = Hud.text("", 20, Hud.BRASS)  # the nearest sign, read aloud in the game's language while T is held
	_gloss.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_gloss.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_gloss.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gloss.offset_top = -210
	_gloss.offset_left = -500
	_gloss.offset_right = 500
	root.add_child(_gloss)
	_help = Hud.text("AMBER_HELP" if _amber() else "HARBOUR_HELP", 15, Hud.MUTED)
	_help.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_help.offset_left = 28
	_help.offset_top = -44
	root.add_child(_help)
	_dialog_text = Hud.text("", 19)
	_dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	_dialog_text.custom_minimum_size = Vector2(860, 0)
	_dialog = Hud.panel(_dialog_text)
	_dialog.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_dialog.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_dialog.offset_left = -450
	_dialog.offset_right = 450
	_dialog.offset_bottom = -210
	_dialog.visible = false
	root.add_child(_dialog)
	_plan = PlanPanel.new()
	_plan.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_plan.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_plan.grow_vertical = Control.GROW_DIRECTION_BOTH
	_plan.offset_right = -40
	_plan.visible = false
	root.add_child(_plan)
	_plan.approved.connect(_on_plan_approved)
	_plan.cancelled.connect(_close_plan)
	_build_post(root)
	_comic = ComicPage.new()
	root.add_child(_comic)
	_comic.finished.connect(_on_talk_over)
	Locale.locale_changed.connect(_on_locale)
	_on_locale("")


func _on_locale(_code: String) -> void:
	_account.text = tr("HARBOUR_ACCOUNT") % [ExchangeApi.account.get("name", "—"), ExchangeApi.account.get("accountId", "—")]
	if _post.visible:
		_paint_post()


func _process(delta: float) -> void:
	var blades: Node3D = _parts.get("blades")
	if blades:
		blades.rotation.z += delta * 0.5
	var ship: Node3D = get_node_or_null("Wayfarer")
	if ship:
		ship.position.y = (AmberCliff.DOCK.y if _amber() else (Archipelago.SILK_DOCK.y if _silk() else Archipelago.PIER_END.y)) + 1.2 + sin(Time.get_ticks_msec() * 0.0012) * 0.25
	for w in _idlers:
		w.step(delta, 0.0)
	if _flying:
		_fly_move(delta)
	_target = _nearest()
	var prompt: String = ("PROMPT_TALK" if _target.begins_with("talk:") else _spots()[_target][1]) if not _target.is_empty() else ""
	if _amber() and prompt == "PROMPT_TALK":
		prompt = "AMB_PROMPT_TALK"
	_prompt.text = _shown(prompt) if not prompt.is_empty() else ""
	if _amber():
		_glossing = Input.is_key_pressed(KEY_T) and not _comic.is_open()
		_title.text = _shown("AMB_TITLE")
		_gloss.text = _read_sign() if _glossing else ""
	if _target.is_empty():
		_dialog.visible = false
	_report_timer -= delta
	if _report_timer <= 0.0 and not _silk() and not _amber():
		_report_timer = 2.0
		Game.watch_report()


## The nearest sign the captain can read from here, as "French — the game's language".
func _read_sign() -> String:
	var p := _captain.global_position
	var best: Label3D
	for l: Label3D in _signs:
		if l.global_position.distance_to(p) < 16.0 and (best == null or l.global_position.distance_to(p) < best.global_position.distance_to(p)):
			best = l
	return "%s — %s" % [best.text, tr(str(best.get_meta("key")))] if best != null else ""


func _nearest() -> String:
	if _flying or _hud.is_modal() or _plan.visible or _comic.is_open():
		return ""
	var p := _captain.global_position
	for i in _villagers.size():  # a stroller at arm's length comes before the place they walk through
		if _villagers[i].global_position.distance_to(p) < 2.4:
			return "talk:%d" % i
	var spots := _spots()
	for id: String in spots:
		var pos: Vector3 = spots[id][0]
		if Vector2(p.x, p.z).distance_to(Vector2(pos.x, pos.z)) < float(spots[id][2]):
			return id
	return ""


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _plan.visible:
			_close_plan()
		elif _post.visible:
			_post.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not _ui_open():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("toggle_camera"):
		set_flying(not _flying)
	elif event.is_action_pressed("interact"):
		interact()
	elif _flying and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var m := event as InputEventMouseMotion
		_fly_yaw -= m.relative.x * 0.004
		_fly_pitch = clampf(_fly_pitch - m.relative.y * 0.003, -1.4, 1.4)


func _ui_open() -> bool:
	return _plan.visible or _post.visible or _hud.is_modal() or _comic.is_open()


func _on_modal(open: bool) -> void:
	_captain.controlled = not open and not _plan.visible and not _post.visible and not _flying
	if open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func set_flying(on: bool) -> void:
	_flying = on
	_captain.controlled = not on
	if on:
		_fly.global_transform = _captain.camera.global_transform
		_fly_yaw = _fly.rotation.y
		_fly_pitch = _fly.rotation.x
		_fly.current = true
		_help.text = "HARBOUR_FLY"
	else:
		_captain.camera.current = true
		_help.text = "HARBOUR_HELP"


func _fly_move(delta: float) -> void:
	_fly.rotation = Vector3(_fly_pitch, _fly_yaw, 0)
	var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var up := float(Input.is_key_pressed(KEY_SPACE)) - float(Input.is_key_pressed(KEY_SHIFT))
	var speed := 30.0 if Input.is_key_pressed(KEY_CTRL) else 14.0
	_fly.position += (_fly.basis * Vector3(v.x, 0, v.y) + Vector3.UP * up) * speed * delta


func _say(text: String) -> void:
	_dialog_text.text = text
	_dialog.visible = true


## Opens talk `id` as a comic page (ADR-0027) and waits until it is closed. Tool runs have nobody to read it.
func talk(id: String, vars: Dictionary = {}) -> void:
	if Session.active() or Session.tooling() or not _comic.open(id, vars):
		return
	_dialog.visible = false
	_captain.controlled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _comic.finished


func _on_talk_over(_id: String) -> void:
	_captain.controlled = not _flying and not _plan.visible and not _post.visible
	if _talker != null:
		_talker.set_physics_process(true)
		_talker = null
	if not Session.tooling():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## The first meeting with somebody is a page; later they get straight to business.
func _meet(id: String) -> void:
	if not Game.met.has(id):
		Game.met[id] = true
		await talk(id)


func comic() -> ComicPage:
	return _comic


func interact() -> void:
	if _target.begins_with("talk:"):
		_talker = _villagers[int(_target.substr(5))]
		_talker.set_physics_process(false)  # stands and listens
		_talker.walker.step(0.2, 0.0)
		var role: String = _talker.role if not _talker.role.is_empty() else {"oldman": "townsman"}.get(_talker.who, _talker.who)
		await talk(str(_talker.get_meta("talk", "stroll_" + role)))
		return
	if _amber():
		if _target == "ship":  # the packet boat home: no trading day is needed for this passage
			_sail_to("harbour")
		elif not _target.is_empty():
			await talk("amber_" + _target)
		return
	match _target:
		"exchange":
			if Game.approved and Game.flow.state != GameFlow.State.TRADING:
				Game.move(GameFlow.State.TRADING)
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			Session.go("hall")
		"ship":
			if Game.move(GameFlow.State.SAILING):
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				Session.go("voyage")
		"ferry":
			_sail_to(AmberCliff.ID)
		"mara":
			await _meet("mara_first")
			open_plan()
		"olva":
			_olva()
		"chronicler":
			if not Game.flow.can(GameFlow.State.CHRONICLE, Game.ctx()):
				await talk("chronicler_day")
			elif Game.move(GameFlow.State.CHRONICLE):
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				Session.go("chronicle")
		"debt":
			var year := Lessons.debt_after(DEBT, DEBT_RATE, 12, 12)
			_say(tr("DEBT_LINE") % [Money.format(DEBT, 2, Locale.current()), Money.format(year, 2, Locale.current())])
			Game.lesson("DEBT", [{"m": DEBT}, {"bps": DEBT_RATE}, {"m": year}, {"m": year - DEBT}])
		"provisions":
			Game.provisions = true
			var cushion := Lessons.cushion(Game.MONTHLY_COSTS)
			var capital: int = await Game.trading_capital()
			_say(tr("PROVISIONS_LINE") % Money.format(cushion, 2, Locale.current()))
			Game.lesson("CUSHION", [{"m": Game.MONTHLY_COSTS}, {"m": cushion}, {"m": capital}])
		"garden":
			var rates := await _rates()
			var rate := int(rates.get("savingsRateBps", 1400))
			var x10 := Lessons.years_to_double_x10(rate)
			Game.lesson("GARDEN", [{"bps": rate}, "%d,%d" % [x10 / 10, x10 % 10] if Locale.current() == "ru" else "%d.%d" % [x10 / 10, x10 % 10],
				{"m": 10000000}, {"m": Lessons.compound(10000000, rate, 10)}])
		"fog":
			var rates := await _rates()
			var infl := int(rates.get("inflationBps", 1100))
			var dep := int(rates.get("savingsRateBps", 1400))
			Game.lesson("FOG", [{"bps": infl}, {"bps": dep}, {"bps": Lessons.real_rate_bps(dep, infl)}, {"m": 10000000},
				{"m": Lessons.after_fog(10000000, infl, 5)}])
		"post":
			await _meet("keeper_first")
			await open_post()


## The packet boat between Spark Harbour and Amber Cliff: a fade, and the captain is on the other pier.
func _sail_to(island: String) -> void:
	Game.island = island
	Session.spawn = "pier"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Session.go("harbour")


func _rates() -> Dictionary:
	var r: Dictionary = await ExchangeApi.call_api(HTTPClient.METHOD_GET, "/economy/rates")
	return r["data"] if r["ok"] and r["data"] is Dictionary else {}


# ---------------------------------------------------------------- Mara's plan

func open_plan() -> void:
	if Game.flow.state == GameFlow.State.PORT and not Game.move(GameFlow.State.PLAN):
		_say(tr("MARA_PROVISIONS_FIRST"))
		return
	if Game.flow.state != GameFlow.State.PLAN:
		_say(tr("MARA_BUSY"))
		return
	_dialog.visible = false
	_plan.visible = true
	_captain.controlled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if Game.plan == null:
		await _plan.pick(VoyagePlan.new().instrument)


func _close_plan() -> void:
	_plan.visible = false
	_captain.controlled = true
	if Game.flow.state == GameFlow.State.PLAN and not Game.approved:
		Game.move(GameFlow.State.PORT)


func _on_plan_approved() -> void:
	await Session.wait(1.2)
	_plan.visible = false
	_captain.controlled = true
	_say(tr("MARA_APPROVED") % [_plan.plan.instrument, Money.format(_plan.plan.stop, 2, Locale.current())])


# ---------------------------------------------------------------- Ольва Перо and the report season

func _olva() -> void:
	await Game.watch_report()
	var co: Dictionary = Game.report["company"]
	var loc := Locale.current()
	if co.get("consensus") is Dictionary:
		var c: Dictionary = co["consensus"]
		_say(tr("OLVA_CONSENSUS") % [Money.format(int(c["eps"]), 2, loc), Money.format(int(c["revenue"]), 2, loc)])
		await talk("olva_consensus", {"eps": Money.format(int(c["eps"]), 2, loc), "revenue": Money.format(int(c["revenue"]), 2, loc)})
		Game.lesson("CONSENSUS", [{"p": int(c["eps"])}])
	elif co.get("lastReport") is Dictionary:
		var r: Dictionary = co["lastReport"]
		_say(tr("OLVA_LAST") % [str(int(r["season"])), Money.format(int(r["eps"]), 2, loc), Money.format(int(r["consensusEps"]), 2, loc)])
		await talk("olva_last", {"season": str(int(r["season"])), "eps": Money.format(int(r["eps"]), 2, loc), "consensus": Money.format(int(r["consensusEps"]), 2, loc)})
	else:
		_say(tr("OLVA_WAIT"))
		await talk("olva_wait")


func _on_report(kind: String, data: Dictionary) -> void:
	if kind == "OPENED" and Game.anchor.get("instrument", "") == Game.FORGE:
		var a := Game.anchor
		if ReportSeason.through_anchor(int(data["open"]), int(a["trigger"]), int(a["limit"])):
			Game.lesson("GAP", [{"p": int(a["trigger"])}, {"p": int(data["open"])}])


# ---------------------------------------------------------------- Silk Reach trading post (liquidity)

func _build_post(root: Control) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(600, 0)
	var title := Hud.text("POST_TITLE", 28, Hud.BRASS)
	title.add_theme_font_override("font", Hud.serif())
	box.add_child(title)
	box.add_child(Hud.lore("POST_LORE"))
	_post_text = Hud.text("", 17)
	_post_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(_post_text)
	var sell := Hud.button("POST_SELL")
	sell.name = "PostSell"
	sell.pressed.connect(sell_cargo)
	box.add_child(sell)
	var close := Hud.button("POST_CLOSE")
	close.pressed.connect(func() -> void: _post.visible = false; _captain.controlled = true)
	box.add_child(close)
	_post = Hud.panel(box)
	_post.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_post.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_post.grow_vertical = Control.GROW_DIRECTION_BOTH
	_post.offset_right = -40
	_post.visible = false
	root.add_child(_post)


var _walk: Dictionary = {}
var _bids: Array = []


func open_post() -> void:
	var f := Game.facts()
	_post_qty = 0
	for v in f.voyages:
		if v["instrument"] == "SILK-SPARK":
			_post_qty += maxi(0, int(v["qty"]))
	var r: Dictionary = await ExchangeApi.call_api(HTTPClient.METHOD_GET, "/instruments/SILK-SPARK/book")
	_bids = []
	if r["ok"]:
		for b: Dictionary in BookModel.from_snapshot(r["data"]).bids:
			_bids.append([int(b["price"]), int(b["qty"])])
	var probe := maxi(_post_qty, 200)  # the whole hold, or a big cargo to show the depth
	_walk = Lessons.walk_book(_bids, probe)
	_walk["probe"] = probe
	_paint_post()
	_post.visible = true
	_captain.controlled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not _bids.is_empty():
		Game.lesson("LIQUIDITY", [probe, {"p": int(_bids[0][0])}, {"p": int(_walk["worst"])}, {"m": int(_walk["cost"])}, int(_walk["filled"])])


func _paint_post() -> void:
	var loc := Locale.current()
	if _bids.is_empty():
		_post_text.text = tr("POST_EMPTY")
		return
	var top := int(_bids[0][1])
	_post_text.text = tr("POST_BOOK") % [Money.format(int(_bids[0][0]), 2, loc), str(top), str(int(_walk["probe"])),
		Money.format(int(_walk["worst"]), 2, loc), Money.format(int(_walk["cost"]), 2, loc), str(_post_qty)]


## Sells the hold at market at the post (Trading on Silk Reach), then back to port.
func sell_cargo() -> void:
	if _post_qty <= 0:
		_post_text.text = tr("POST_NOTHING")
		return
	if not Game.move(GameFlow.State.TRADING):
		return
	var r: Dictionary = await Game.place({"instrument": "SILK-SPARK", "side": "SELL", "type": "MARKET", "qty": _post_qty})
	Game.move(GameFlow.State.PORT)
	if r["ok"]:
		var sold := int(r["data"]["filledQty"])
		if sold >= _post_qty:
			await Game.lift_anchor()  # nothing left to protect
		_post_text.text = tr("POST_SOLD") % [str(sold), str(_post_qty)]
		var f := Game.facts()
		Game.lesson("FEES", [{"m": f.fees}, {"m": f.spread}, Money.format(int(ExchangeApi.instrument("SILK-SPARK")["feeBps"]), 2, Locale.current())])
		_post_qty = 0
	else:
		_post_text.text = tr("ERR_" + str(r["code"]))


# ---------------------------------------------------------------- demo (screenshots for docs/demo/M3.md)

func _demo() -> void:
	await Demo.harbour(self)


func demo_go(spot: String, yaw: float = 0.0, pitch: float = -0.25) -> void:
	var p: Vector3 = _spots()[spot][0]
	var dir := Vector3(sin(yaw), 0, cos(yaw))
	_captain.position = p - dir * 2.2 + Vector3(0, 0.6, 0)
	_captain.velocity = Vector3.ZERO
	_captain.yaw = yaw + PI
	_captain.pitch = pitch
	_captain.body.rotation.y = yaw
	await Session.wait(0.4)
	_target = spot
	await interact()


func demo_view(pos: Vector3, look: Vector3) -> void:
	set_flying(true)
	_fly.position = pos
	_fly.look_at(look)
	_fly_yaw = _fly.rotation.y
	_fly_pitch = _fly.rotation.x


func demo_walk() -> void:
	set_flying(false)


func plan_panel() -> PlanPanel:
	return _plan


func hud() -> GameHud:
	return _hud

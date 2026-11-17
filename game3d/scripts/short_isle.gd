## Pattern: Builder — the short sellers' island (working name; `docs/design/concepts/35…40`): a town on a rock that
## looks as if it were sliding off — a great tilted slab behind it, crooked houses, towers that lean, and on the
## cliff edge the Exchange of Falling Prices, a leaning mill with broken blades and a red board. People stand on a
## flat cap; the tilt is drawn (the picture leans, the collider stands). Black, white and one red: the island's
## materials are light plaster, dark timber and slate, and red only where the sheets put it.
## See docs/adr/0030-game3d-short-sellers-island-in-noir.md
class_name ShortIsle
extends RefCounted

const ID := "shorts"
const AT := Vector3(150, -10, 340)  ## the island's centre in the world
const RADIUS := 36.0
const SEED := 47
const DECK_Y := 0.12
const PIER_FROM := AT + Vector3(-52.0, DECK_Y, -2.4)
const PIER_TO := AT + Vector3(-23.0, DECK_Y, 2.4)  ## its island end lies well inside the walkable cap
const DOCK := AT + Vector3(-47.0, 0, 8.5)
const SPAWN := AT + Vector3(-40.0, 0.5, 0)
const EXCHANGE := Vector3(21.5, 0, 0)  ## the Exchange of Falling Prices, in the island's own space
const RED := Color("c4302b")  ## the signal red
const PLASTER := Color("ebe6dc")
const TIMBER := Color("1d1c20")
const SLATE := Color("2a2a31")
const STONE := Color("8e8c88")
const MAX_LEAN := 0.13  ## radians (7.5°): a house leans as one piece with its collider; the mill's foot stays upright

static var _mats: Dictionary = {}


static func walk_areas() -> Array[Dictionary]:
	return [{"name": "shorts", "kind": "disc", "centre": AT, "radius": RADIUS, "seed": SEED},
		{"name": "shorts-pier", "kind": "rect", "from": PIER_FROM, "to": PIER_TO}]


## Where the broker stands by the exchange door and where the captain talks to him: [keeper, spot], world space.
static func door() -> Array[Vector3]:
	return [AT + EXCHANGE + Vector3(-5.6, 0, 2.0), AT + EXCHANGE + Vector3(-7.0, 0, 1.2)]


static func _mat(c: Color, glow: float = 0.0, both_sides: bool = false) -> Material:
	var key := "%s/%s/%s" % [c.to_html(), glow, both_sides]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.9
		if glow > 0.0:
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = glow
		if both_sides:
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats[key] = m
	return _mats[key]


## Every building: [place, facing (0 = the door looks south), floors, width, lean sideways, lean forward, red door].
static func plots() -> Array:
	var out: Array = []
	var leans := [0.06, -0.09, 0.11, -0.05, 0.08, -0.12, 0.1, -0.07]
	var n := 0
	for x: float in [-17.5, -9.5, -1.5, 6.5]:  # the one street, from the pier to the exchange
		out.append([Vector3(x, 0, -8.6), 0.0, 2 + n % 2, 5.4, leans[n % 8], 0.04, n % 3 == 0])
		out.append([Vector3(x + 1.0, 0, 8.6), PI, 2 + (n + 1) % 2, 5.2, leans[(n + 3) % 8], -0.05, n % 3 == 1])
		n += 1
	for p: Array in [[Vector3(14.0, 0, -10.5), 0.5, 5], [Vector3(15.0, 0, 10.5), PI - 0.5, 4], [Vector3(26.0, 0, -11.0), 0.9, 5],
			[Vector3(-4.0, 0, -21.0), 0.0, 4], [Vector3(-16.0, 0, 20.5), PI, 3], [Vector3(8.0, 0, 21.0), PI, 4], [Vector3(-25.0, 0, -15.5), 0.3, 3]]:
		out.append([p[0], p[1], p[2], 4.9, leans[n % 8] * 1.05, 0.06 if n % 2 == 0 else -0.06, n % 2 == 0])  # the towers
		n += 1
	return out


## The whole island. `town` = false gives the rock, the slab and dark blocks: what is seen from far away.
static func build(town: bool) -> Node3D:
	var isl := Node3D.new()
	isl.name = "ShortIsle"
	isl.add_child(Archipelago.island(RADIUS, 46.0, SEED, 0.0, true))
	isl.add_child(_slab())
	var rng := RandomNumberGenerator.new()
	rng.seed = 1929
	for p: Array in plots():
		var hs: Node3D
		if town:
			hs = crooked_house(rng, p[2], p[3], Vector2(p[4], p[5]), p[6])
		else:
			hs = Node3D.new()
			hs.add_child(Proc.box(Vector3(p[3], 2.9 * int(p[2]), 5.0), TIMBER, Vector3(0, 1.45 * int(p[2]), 0)))
			hs.rotation.z = p[4]
		hs.position = p[0]
		hs.rotation.y = p[1]
		isl.add_child(hs)
	isl.add_child(_exchange(town))
	if not town:
		return isl
	for x: float in [-21.0, -13.5, -5.5, 2.5, 10.5]:
		isl.add_child(_lamp(Vector3(x, 0, -3.4 if int(x) % 2 == 0 else 3.4), 0.05 if int(x) % 2 == 0 else -0.06))
	isl.add_child(_signpost(Vector3(-26.5, 0, 4.2)))
	isl.add_child(_ship_lantern(Vector3(-50.5, DECK_Y, -1.6)))
	isl.add_child(_umbrella_stand(EXCHANGE + Vector3(-4.6, 0, -2.4)))
	isl.add_child(_ticker(EXCHANGE + Vector3(-5.4, 0, 4.4)))
	isl.add_child(Archipelago._deck("Pier", PIER_FROM - AT, PIER_TO - AT, [true, false, true, true], PIER_TO - AT + Vector3(0, 0, -2)))
	var f := Node3D.new()
	f.name = "Fences"
	isl.add_child(f)
	Solid.fence_areas(f, walk_areas(), AT)
	return isl


## The tilt, drawn: a slab of rock rising behind the town to a broken peak, with red etherite under it. Nobody can
## reach it (it lies beyond the fence), so it has no collider.
static func _slab() -> Node3D:
	var n := Node3D.new()
	n.name = "Slab"
	n.set_meta("flat", true)
	var rock := Proc.mesh_node(Proc.island_mesh(27.0, 26.0, SEED + 5, 2.0), Proc.terrain_mat())
	rock.position = Vector3(-10.0, 7.5, -62.0)
	rock.rotation = Vector3(-0.3, 0.3, 0.12)  # the near edge dips towards the town, the far one stands up
	n.add_child(rock)
	for p: Array in [[Vector3(-22, 17, -76), 7.0, 13.0, 0.35], [Vector3(-9, 19, -82), 5.0, 17.0, 0.2], [Vector3(2, 15, -74), 4.0, 9.0, 0.5]]:
		var peak := Proc.cyl(0.0, p[1], p[2], 4, STONE, p[0])
		peak.rotation = Vector3(-0.3, 0.8, p[3])
		n.add_child(peak)
	var rng := RandomNumberGenerator.new()
	rng.seed = 73
	for i in 12:  # the red crystals of the sheet, under the slab and under the town's rim
		var a := rng.randf() * TAU
		var under_town := i >= 7
		var c := (Vector3(cos(a) * 26.0, -9.0 - rng.randf() * 6.0, sin(a) * 26.0)) if under_town else Vector3(-10.0 + cos(a) * 14.0, -6.0 - rng.randf() * 5.0, -58.0 + sin(a) * 12.0)
		var h := rng.randf_range(4.0, 8.0)
		var crystal := Proc.mesh_node(Proc._cyl_mesh(0.0, h * 0.22, h, 5), _mat(RED, 2.0), c)
		crystal.rotation = Vector3(PI + rng.randf_range(-0.35, 0.35), rng.randf() * TAU, rng.randf_range(-0.35, 0.35))
		crystal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(crystal)
	return n


## A crooked house of sheet 38: skewed plinth, storeys that jut out over one another, crooked windows, a steep roof
## with a sagging ridge, a bent chimney. `floors` 2–3 is a house, 4–5 a tower. `lean` (sideways, forward) tilts the
## whole picture; the collider is an upright box. The door looks +z; `red_door` paints it the signal red.
static func crooked_house(rng: RandomNumberGenerator, floors: int, w: float, lean: Vector2, red_door: bool) -> Node3D:
	var hs := Node3D.new()
	hs.name = "CrookedHouse"
	var d := 5.0
	var storey := 2.8
	var top := 0.5 + storey * floors
	var k := Kit.new()
	var plaster := _mat(PLASTER)
	var timber := _mat(TIMBER)
	var slate := _mat(SLATE, 0.0, true)
	var red := _mat(RED, 1.6)
	var glass := _mat(Color("15151a"))
	k.box(_mat(STONE), Vector3(w + 0.3, 2.0, d + 0.3), Vector3(0, -0.5, 0), Vector3(0, 0, 0.04))
	for i in floors:
		var out := 0.28 * i  # each storey juts out a little further
		var y := 0.5 + storey * (i + 0.5)
		var flush := 0.2 if i == 0 else 0.0  # the ground storey is as wide as the collider: no sliver beside the wall
		k.box(plaster, Vector3(w + out + flush, storey, d + out + flush), Vector3(0, y, 0))
		k.box(timber, Vector3(w + out + 0.14, 0.2, d + out + 0.14), Vector3(0, y - storey * 0.5, 0))
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				k.box(timber, Vector3(0.2, storey, 0.2), Vector3(sx * (w + out) * 0.5, y, sz * (d + out) * 0.5))
			k.box(timber, Vector3(0.12, storey * 1.1, 0.06), Vector3(sx * (w + out) * 0.28, y, (d + out) * 0.5 + 0.02), Vector3(0, 0, sx * 0.5))  # braces
		for sx: float in [-1.0, 1.0]:  # crooked windows, front and back; one in three burns red
			if i == 0 and absf(sx) > 0.0 and w < 4.8:
				continue
			var tilt := rng.randf_range(-0.1, 0.1)
			var lit: bool = i > 0 and rng.randf() < 0.34
			for sz: float in [-1.0, 1.0]:
				var z := sz * ((d + out) * 0.5 + 0.03)
				k.box(timber, Vector3(1.0, 1.5, 0.1), Vector3(sx * (w * 0.25 + 0.2), y + 0.1, z), Vector3(0, 0, tilt))
				k.box(red if lit and sz > 0 else glass, Vector3(0.74, 1.24, 0.12), Vector3(sx * (w * 0.25 + 0.2), y + 0.1, z), Vector3(0, 0, tilt))
	var jut := 0.28 * (floors - 1)
	var front := d * 0.5
	k.box(timber, Vector3(1.3, 2.3, 0.12), Vector3(0, 1.6, front + 0.03), Vector3(0, 0, 0.05))
	k.box(red if red_door else _mat(Color("101014")), Vector3(1.0, 2.05, 0.14), Vector3(0, 1.5, front + 0.05), Vector3(0, 0, 0.05))
	var step := Kit.new()  # the broken step: its own mesh, upright like its collider
	# the roof: steep, its ridge sagging to one end
	var hw := (w + jut) * 0.5 + 0.35
	var hd := (d + jut) * 0.5 + 0.3
	var rise := (2.6 if floors < 4 else 4.2)
	var sag := rng.randf_range(0.3, 0.7) * (1.0 if rng.randf() < 0.5 else -1.0)
	var a := Vector3(-hw, top, hd)
	var b := Vector3(hw, top, hd)
	var c := Vector3(hw, top + rise + sag * 0.5, 0)
	var e := Vector3(-hw, top + rise - sag * 0.5, 0)
	k.quad(slate, a, b, c, e)
	k.quad(slate, Vector3(hw, top, -hd), Vector3(-hw, top, -hd), e, c)
	k.tri(plaster, Vector3(hw - 0.3, top, -hd + 0.3), Vector3(hw - 0.3, top, hd - 0.3), c + Vector3(-0.3, -0.1, 0))
	k.tri(plaster, Vector3(-hw + 0.3, top, hd - 0.3), Vector3(-hw + 0.3, top, -hd + 0.3), e + Vector3(0.3, -0.1, 0))
	for j in 3:  # the bent chimney
		k.box(_mat(STONE.darkened(0.3)), Vector3(0.6, 0.9, 0.6), Vector3(w * 0.26 + j * 0.13, top + rise * 0.55 + j * 0.8, -d * 0.15), Vector3(0, 0, -0.12 * j))
	if floors >= 3:  # a hanging balcony
		k.box(timber, Vector3(2.0, 0.12, 0.8), Vector3(0, 0.5 + storey * 2.0 + 0.1, front + jut * 0.5 + 0.4))
		k.box(timber, Vector3(2.0, 0.06, 0.06), Vector3(0, 0.5 + storey * 2.0 + 0.9, front + jut * 0.5 + 0.78))
		for bx: float in [-0.95, -0.47, 0.0, 0.47, 0.95]:
			k.box(timber, Vector3(0.05, 0.8, 0.05), Vector3(bx, 0.5 + storey * 2.0 + 0.5, front + jut * 0.5 + 0.78))
	var body := Node3D.new()  # the picture leans; the collider below stands
	body.name = "Body"
	body.rotation = Vector3(clampf(lean.y, -MAX_LEAN, MAX_LEAN), 0, clampf(lean.x, -MAX_LEAN, MAX_LEAN))
	body.add_child(k.commit("Walls"))
	hs.add_child(body)
	step.box(_mat(STONE), Vector3(1.9, 0.5, 1.1), Vector3(0, 0.2, front + 0.45), Vector3(0, 0.07, 0))
	hs.add_child(step.commit("Step"))
	Solid.box(body, Vector3(w + 0.2, top + 1.0, d + 0.2), Vector3(0, (top - 1.0) * 0.5, 0))  # flush with the corner posts; it leans with the walls
	Solid.box(hs, Vector3(1.9, 0.5, 1.1), Vector3(0, 0.2, front + 0.45))
	hs.set_meta("size", Vector3(w, top, d))
	return hs


## The Exchange of Falling Prices (sheet 39): a mill tower leaning out over the cliff, two of its four blades
## broken, a weathercock, and a great red board on the side the street comes from, its line going down.
static func _exchange(town: bool) -> Node3D:
	var n := Node3D.new()
	n.name = "FallingExchange"
	n.position = EXCHANGE
	var k := Kit.new()
	var stone := _mat(STONE)
	var wall := _mat(PLASTER.darkened(0.08))
	var timber := _mat(TIMBER)
	var foot := Kit.new()  # the stone foot stands straight: it is what a walker meets, and its collider is a cylinder
	foot.mesh(stone, Proc._cyl_mesh(3.6, 3.8, 1.8, 14), Transform3D(Basis(), Vector3(0, 0.9, 0)))
	k.mesh(wall, Proc._cyl_mesh(2.4, 3.3, 9.0, 10), Transform3D(Basis(), Vector3(0, 6.1, 0)))
	for y: float in [3.2, 6.0, 8.8]:
		k.mesh(timber, Proc._cyl_mesh(3.4 - y * 0.1, 3.45 - y * 0.1, 0.22, 10), Transform3D(Basis(), Vector3(0, y, 0)))
	k.mesh(timber, Proc._cyl_mesh(3.0, 3.0, 0.2, 10), Transform3D(Basis(), Vector3(0, 10.6, 0)))  # the gallery
	k.mesh(_mat(SLATE), Proc._cyl_mesh(0.1, 2.7, 3.0, 8), Transform3D(Basis(), Vector3(0, 12.2, 0)))
	k.box(timber, Vector3(0.08, 1.4, 0.08), Vector3(0, 14.3, 0))
	k.box(timber, Vector3(0.9, 0.06, 0.06), Vector3(0.2, 14.9, 0), Vector3(0, 0, 0.3))  # the weathercock, askew
	if town:
		var hub := Vector3(-2.9, 9.4, 0)  # the blades face the street
		k.box(timber, Vector3(0.7, 0.5, 0.5), hub + Vector3(0.3, 0, 0))
		var lengths := [6.2, 3.1, 5.6, 2.2]  # two are broken
		for i in 4:
			var turn := 0.5 + i * PI / 2.0
			var len: float = lengths[i]
			var mid := hub + Vector3(-0.1, cos(turn) * len * 0.5, sin(turn) * len * 0.5)
			k.box(timber, Vector3(0.12, len, 0.14), mid, Vector3(turn, 0, 0))
			k.box(_mat(Color("d9d4ca"), 0.0, true), Vector3(0.04, len * 0.72, 1.1), mid + Vector3(0, cos(turn) * len * 0.08, sin(turn) * len * 0.08), Vector3(turn, 0, 0))
		# the red board: a broken line that falls, and its arrow
		var board := Vector3(-3.25, 4.6, 0)
		k.box(timber, Vector3(0.14, 2.7, 3.9), board, Vector3(0, 0, -0.08))
		k.box(_mat(RED, 1.6), Vector3(0.16, 2.4, 3.6), board + Vector3(-0.03, 0, 0), Vector3(0, 0, -0.08))
		var white := _mat(Color("f4efe6"), 0.6)
		var pts := [Vector3(0, 0.75, -1.5), Vector3(0, 0.3, -0.8), Vector3(0, 0.55, -0.2), Vector3(0, -0.2, 0.5), Vector3(0, 0.05, 0.9), Vector3(0, -0.8, 1.5)]  # seen from the street it falls to the right
		for i in pts.size() - 1:
			var p0: Vector3 = pts[i]
			var p1: Vector3 = pts[i + 1]
			k.box(white, Vector3(0.05, 0.1, p0.distance_to(p1) + 0.08), board + Vector3(-0.13, 0, 0) + (p0 + p1) * 0.5, Vector3(atan2(-(p1.y - p0.y), p1.z - p0.z), 0, 0))
		k.box(white, Vector3(0.05, 0.36, 0.36), board + Vector3(-0.13, -0.8, 1.5), Vector3(PI / 4, 0, 0))
		foot.box(timber, Vector3(0.2, 1.7, 1.2), Vector3(-3.66, 0.85, 0.0))  # the low door in the foot, under the board
		foot.box(_mat(Color("101014")), Vector3(0.22, 1.5, 0.9), Vector3(-3.68, 0.75, 0.0))
	var body := Node3D.new()
	body.name = "Body"
	body.rotation.z = -MAX_LEAN  # it leans out over the cliff, away from the street
	body.add_child(k.commit("Mill"))
	n.add_child(body)
	n.add_child(foot.commit("Foot"))
	Solid.post(n, 3.75, 1.8, Vector3.ZERO)
	Solid.box(n, Vector3(0.3, 1.7, 1.2), Vector3(-3.66, 0.85, 0.0))
	Solid.post(n, 3.3, 9.0, Vector3(0, 1.8, 0))
	return n


## The street lamp of sheet 40: a black post with a crown and a red lantern.
static func _lamp(at: Vector3, lean: float) -> Node3D:
	var n := Node3D.new()
	n.name = "RedLamp"
	n.position = at
	var k := Kit.new()
	var iron := _mat(TIMBER)
	k.mesh(iron, Proc._cyl_mesh(0.12, 0.24, 0.5, 8), Transform3D(Basis(), Vector3(0, 0.25, 0)))
	k.mesh(iron, Proc._cyl_mesh(0.06, 0.09, 2.9, 6), Transform3D(Basis(), Vector3(0, 1.95, 0)))
	k.box(iron, Vector3(0.7, 0.05, 0.05), Vector3(0, 3.05, 0))
	k.box(_mat(RED, 2.2), Vector3(0.3, 0.44, 0.3), Vector3(0, 3.62, 0))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.box(iron, Vector3(0.035, 0.48, 0.035), Vector3(sx * 0.16, 3.62, sz * 0.16))
	k.mesh(iron, Proc._cyl_mesh(0.02, 0.28, 0.26, 4), Transform3D(Basis.from_euler(Vector3(0, PI / 4, 0)), Vector3(0, 3.98, 0)))
	k.box(iron, Vector3(0.4, 0.05, 0.4), Vector3(0, 3.38, 0))
	var body := Node3D.new()
	body.name = "Body"
	body.rotation.z = lean
	body.add_child(k.commit("Lamp"))
	n.add_child(body)
	Solid.post(n, 0.16, 3.4, Vector3.ZERO)
	return n


## The crooked signpost by the pier: three boards, one of them red.
static func _signpost(at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = "CrookedSignpost"
	n.position = at
	var k := Kit.new()
	var wood := _mat(Color("3a3836"))
	k.box(wood, Vector3(0.18, 3.4, 0.18), Vector3(0, 1.7, 0))
	k.box(_mat(PLASTER), Vector3(1.5, 0.3, 0.07), Vector3(0.5, 3.0, 0.1), Vector3(0, 0.2, 0.06))
	k.box(_mat(RED, 1.2), Vector3(1.4, 0.3, 0.07), Vector3(-0.45, 2.5, 0.1), Vector3(0, -0.15, -0.08))
	k.box(_mat(PLASTER), Vector3(1.2, 0.26, 0.07), Vector3(0.4, 2.05, 0.1), Vector3(0, 0.1, 0.1))
	var body := Node3D.new()
	body.name = "Body"
	body.rotation.z = 0.12
	body.add_child(k.commit("Signpost"))
	n.add_child(body)
	Solid.post(n, 0.18, 3.2, Vector3.ZERO)
	return n


## The black ship's lantern at the end of the pier.
static func _ship_lantern(at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = "ShipLantern"
	n.position = at
	var k := Kit.new()
	var iron := _mat(TIMBER)
	k.mesh(iron, Proc._cyl_mesh(0.26, 0.3, 0.14, 8), Transform3D(Basis(), Vector3(0, 0.07, 0)))
	k.mesh(_mat(RED, 2.0), Proc._cyl_mesh(0.2, 0.2, 0.46, 8), Transform3D(Basis(), Vector3(0, 0.38, 0)))
	for i in 6:
		k.box(iron, Vector3(0.03, 0.5, 0.03), Vector3(cos(i * TAU / 6.0) * 0.22, 0.38, sin(i * TAU / 6.0) * 0.22))
	k.mesh(iron, Proc._cyl_mesh(0.08, 0.26, 0.2, 8), Transform3D(Basis(), Vector3(0, 0.72, 0)))
	n.add_child(k.commit("Lantern"))
	Solid.post(n, 0.3, 0.85, Vector3.ZERO)
	return n


static func _umbrella_stand(at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = "UmbrellaStand"
	n.position = at
	var k := Kit.new()
	var iron := _mat(TIMBER)
	k.mesh(iron, Proc._cyl_mesh(0.3, 0.24, 0.7, 8), Transform3D(Basis(), Vector3(0, 0.35, 0)))
	for i in 4:
		var red: bool = i == 2
		var lean := Vector3(0.14 * cos(i * 1.7), 0, 0.14 * sin(i * 1.7))
		k.box(_mat(RED, 1.0) if red else iron, Vector3(0.07, 1.0, 0.07), Vector3(lean.x, 0.9, lean.z), Vector3(lean.z, 0, -lean.x))
		k.box(iron, Vector3(0.03, 0.16, 0.12), Vector3(lean.x * 2.0, 1.45, lean.z * 2.0))
	n.add_child(k.commit("Stand"))
	Solid.post(n, 0.32, 1.4, Vector3.ZERO)
	return n


## The ticker machine under its glass, the tape running out of it.
static func _ticker(at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = "Ticker"
	n.position = at
	var k := Kit.new()
	k.box(_mat(Color("3a3836")), Vector3(0.7, 1.0, 0.7), Vector3(0, 0.5, 0))
	k.box(_mat(TIMBER), Vector3(0.84, 0.1, 0.84), Vector3(0, 1.03, 0))
	k.box(_mat(TIMBER), Vector3(0.34, 0.3, 0.3), Vector3(0, 1.24, 0))
	k.box(_mat(Color("f4efe6")), Vector3(0.12, 0.02, 0.9), Vector3(0, 1.1, 0.5), Vector3(0.5, 0, 0))
	k.box(_mat(RED, 1.0), Vector3(0.1, 0.022, 0.2), Vector3(0, 0.92, 0.84), Vector3(0.5, 0, 0))
	n.add_child(k.commit("Ticker"))
	Solid.box(n, Vector3(0.84, 1.4, 0.84), Vector3(0, 0.7, 0))
	return n

## Pattern: Builder — the crypto island (working name; `docs/design/concepts/41…46`): a night town of block towers
## with neon bands, glass walls and antennas, neon palms, a pier, and at the end of the street the Exchange That
## Never Closes, a tower with four neon blades. Its own coin is the wind coin (a gold coin with a wind curl): no
## real coin's mark or ticker appears anywhere. Dark bodies, a few neon parts that glow: the pixel technique keeps
## what is bright and saturated as neon and sorts the rest into its violet ramp.
## See docs/adr/0031-game3d-crypto-island-in-pixel-synthwave.md
class_name CryptoIsle
extends RefCounted

const ID := "crypto"
const AT := Vector3(-130, 14, -370)  ## the island's centre in the world
const RADIUS := 34.0
const SEED := 59
const DECK_Y := 0.12
const PIER_FROM := AT + Vector3(-50.0, DECK_Y, -2.4)
const PIER_TO := AT + Vector3(-21.0, DECK_Y, 2.4)  ## its island end lies well inside the walkable cap
const DOCK := AT + Vector3(-45.0, 0, 8.5)
const SPAWN := AT + Vector3(-38.0, 0.5, 0)
const EXCHANGE := Vector3(20.0, 0, 0)  ## the Exchange That Never Closes, in the island's own space
const NIGHT := Color("241a4a")
const WALL := Color("3a2a6a")
const WALL_WARM := Color("5a2450")
const PINK := Color("ff2e88")
const CYAN := Color("00f0ff")
const GOLD := Color("ffcc00")
const ORANGE := Color("ff7a3d")
## The three robots: id → [place on the island, facing]. Each is a talk spot.
const BOTS := {"bot_trader": [Vector3(13.5, 0, 3.4), -1.9], "bot_miner": [Vector3(-9.5, 0, -5.6), 0.4], "bot_info": [Vector3(-23.0, 0, -4.2), 0.9]}

static var _mats: Dictionary = {}


static func walk_areas() -> Array[Dictionary]:
	return [{"name": "crypto", "kind": "disc", "centre": AT, "radius": RADIUS, "seed": SEED},
		{"name": "crypto-pier", "kind": "rect", "from": PIER_FROM, "to": PIER_TO}]


## Where the captain stands to talk to a robot, world space.
static func spot(bot: String) -> Vector3:
	var b: Array = BOTS[bot]
	return AT + (b[0] as Vector3) + Vector3(sin(float(b[1])), 0, cos(float(b[1]))) * 1.7


static func _mat(c: Color, glow: float = 0.0) -> Material:
	var key := "%s/%s" % [c.to_html(), glow]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.85
		if glow > 0.0:
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = glow
		_mats[key] = m
	return _mats[key]


static func _neon(c: Color) -> Material:
	return _mat(c, 2.4)


## Every building: [place, facing (0 = the front looks south), floors, width, accent colour, glass floor or −1].
static func plots() -> Array:
	var out: Array = []
	var accents := [PINK, CYAN, GOLD, PINK, CYAN, ORANGE]
	var n := 0
	for x: float in [-16.0, -8.0, 0.0, 8.0]:
		out.append([Vector3(x, 0, -8.4), 0.0, [2, 4, 1, 3][n % 4], 5.6, accents[n % 6], 1 if n % 2 == 1 else -1])
		out.append([Vector3(x + 0.6, 0, 8.4), PI, [3, 1, 5, 2][n % 4], 5.4, accents[(n + 2) % 6], 2 if n % 2 == 0 else -1])
		n += 1
	for p: Array in [[Vector3(-3.0, 0, -19.5), 0.0, 6], [Vector3(9.0, 0, -19.0), 0.0, 4], [Vector3(-14.0, 0, 19.5), PI, 5], [Vector3(5.0, 0, 20.0), PI, 7],
			[Vector3(-23.0, 0, -15.0), 0.3, 3], [Vector3(18.0, 0, 16.0), PI + 0.4, 4]]:
		out.append([p[0], p[1], p[2], 5.0, accents[n % 6], 1 + n % 3])
		n += 1
	return out


## The whole island. `town` = false gives the rock and dark blocks with a neon band: what is seen from far away.
static func build(town: bool) -> Node3D:
	var isl := Node3D.new()
	isl.name = "CryptoIsle"
	isl.add_child(Archipelago.island(RADIUS, 44.0, SEED, 0.0, true))
	var rng := RandomNumberGenerator.new()
	rng.seed = 2009
	for p: Array in plots():
		var t: Node3D
		if town:
			t = tower(rng, p[2], p[3], p[4], p[5])
		else:
			t = Node3D.new()
			t.add_child(Proc.box(Vector3(p[3], 3.0 * int(p[2]), 5.0), NIGHT, Vector3(0, 1.5 * int(p[2]), 0)))
			t.add_child(Proc.mesh_node(BoxMesh.new(), _neon(p[4]), Vector3(0, 3.0 * int(p[2]) - 0.4, 0)))
			(t.get_child(1) as MeshInstance3D).scale = Vector3(float(p[3]) + 0.1, 0.2, 5.1)
		t.position = p[0]
		t.rotation.y = p[1]
		isl.add_child(t)
	isl.add_child(_exchange(town))
	if not town:
		return isl
	for p: Vector3 in [Vector3(-20.5, 0, 4.0), Vector3(-5.0, 0, -3.8), Vector3(-4.0, 0, 3.8), Vector3(4.2, 0, -3.6), Vector3(12.0, 0, -4.2), Vector3(-27.0, 0, 8.0),
			Vector3(24.0, 0, -9.0), Vector3(-26.0, 0, -8.0)]:
		isl.add_child(palm(rng, p))
	isl.add_child(_monument(Vector3(4.0, 0, 3.9)))
	isl.add_child(_mining_machine(Vector3(-12.0, 0, -5.0)))
	isl.add_child(_vending(Vector3(-25.2, 0, -3.9)))
	isl.add_child(_ticker(Vector3(-17.5, 0, 0)))
	for id: String in BOTS:
		var b := bot(id)
		b.position = BOTS[id][0]
		b.rotation.y = BOTS[id][1]
		isl.add_child(b)
	isl.add_child(Archipelago._deck("Pier", PIER_FROM - AT, PIER_TO - AT, [true, false, true, true], PIER_TO - AT + Vector3(0, 0, -2)))
	var f := Node3D.new()
	f.name = "Fences"
	isl.add_child(f)
	Solid.fence_areas(f, walk_areas(), AT)
	return isl


## A block tower of sheet 42: dark storeys stacked a little askew in size, a neon band round each, a neon door
## frame, lit windows, on one storey a wall of cyan glass, sign boards with pictures, antennas on the tall ones.
## The front looks +z.
static func tower(rng: RandomNumberGenerator, floors: int, w: float, accent: Color, glass_floor: int) -> Node3D:
	var t := Node3D.new()
	t.name = "NeonTower"
	var d := 5.0
	var storey := 3.0
	var k := Kit.new()
	var glow := Kit.new()  # the neon is its own mesh: no shadows, nothing to dim it
	var neon := _neon(accent)
	var other := _neon(CYAN if accent != CYAN else PINK)
	for i in floors:
		var inset := 0.25 * (i % 2)
		var y := storey * (i + 0.5)
		var ww := w - inset
		var dd := d - inset
		k.box(_mat(WALL if i % 3 != 2 else WALL_WARM), Vector3(ww, storey, dd), Vector3(0, y, 0))
		k.box(_mat(NIGHT), Vector3(ww + 0.2, 0.3, dd + 0.2), Vector3(0, y + storey * 0.5 - 0.15, 0))
		glow.box(neon if i % 2 == 0 else other, Vector3(ww + 0.24, 0.12, dd + 0.24), Vector3(0, y + storey * 0.5 - 0.42, 0))
		if i == glass_floor:  # a wall of glass, front and one side
			glow.box(_mat(Color("12b8c8"), 1.3), Vector3(ww - 0.6, storey - 0.9, 0.06), Vector3(0, y - 0.1, dd * 0.5 + 0.02))
			for gx in 5:
				k.box(_mat(NIGHT), Vector3(0.06, storey - 0.9, 0.1), Vector3(-ww * 0.5 + 0.3 + gx * (ww - 0.6) / 4.0, y - 0.1, dd * 0.5 + 0.03))
			for gy in 3:
				k.box(_mat(NIGHT), Vector3(ww - 0.6, 0.06, 0.1), Vector3(0, y - 0.1 - (storey - 0.9) * 0.5 + gy * (storey - 0.9) / 2.0, dd * 0.5 + 0.03))
		elif i > 0:
			for sx: float in [-1.0, 1.0]:  # two windows a storey, some lit gold
				var lit := rng.randf() < 0.45
				var pane := _mat(GOLD, 1.8) if lit else _mat(Color("15102e"))
				(glow if lit else k).box(pane, Vector3(0.9, 1.1, 0.06), Vector3(sx * ww * 0.25, y, dd * 0.5 + 0.02))
		if i > 0 and rng.randf() < 0.5:  # a sign board with a picture: a line that climbs or falls
			var bx := (rng.randf() - 0.5) * (ww - 2.4)
			k.box(_mat(NIGHT), Vector3(1.7, 0.7, 0.1), Vector3(bx, y + 0.9, dd * 0.5 + 0.09))
			glow.box(other, Vector3(1.5, 0.06, 0.04), Vector3(bx, y + 0.72, dd * 0.5 + 0.15))
			glow.box(neon, Vector3(0.7, 0.06, 0.04), Vector3(bx - 0.3, y + 0.95, dd * 0.5 + 0.15), Vector3(0, 0, 0.5 if rng.randf() < 0.5 else -0.5))
			glow.box(neon, Vector3(0.7, 0.06, 0.04), Vector3(bx + 0.3, y + 0.95, dd * 0.5 + 0.15), Vector3(0, 0, -0.5 if rng.randf() < 0.5 else 0.5))
	k.box(_mat(Color("15102e")), Vector3(1.2, 2.2, 0.1), Vector3(0, 1.1, d * 0.5 + 0.03))  # the door and its neon frame
	for sx: float in [-1.0, 1.0]:
		glow.box(neon, Vector3(0.08, 2.3, 0.08), Vector3(sx * 0.68, 1.15, d * 0.5 + 0.07))
	glow.box(neon, Vector3(1.44, 0.08, 0.08), Vector3(0, 2.32, d * 0.5 + 0.07))
	var top := storey * floors
	if floors >= 4:  # antennas
		for ax: float in [-0.9, 0.8]:
			k.box(_mat(NIGHT), Vector3(0.08, 2.6, 0.08), Vector3(ax, top + 1.3, 0.4))
			glow.box(_neon(GOLD), Vector3(0.22, 0.22, 0.22), Vector3(ax, top + 2.7, 0.4))
	else:
		k.box(_mat(NIGHT), Vector3(1.2, 0.5, 0.9), Vector3(w * 0.2, top + 0.25, -0.6))
	t.add_child(k.commit("Walls"))
	var lights := glow.commit("Neon")
	lights.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	t.add_child(lights)
	Solid.box(t, Vector3(w + 0.2, top + 1.0, d + 0.2), Vector3(0, (top - 1.0) * 0.5, 0))
	t.set_meta("size", Vector3(w, top, d))
	return t


## The Exchange That Never Closes (sheet 43): a dark tapering tower with four neon blades, a red flag, a magenta
## doorway, and a board of two lines that cross.
static func _exchange(town: bool) -> Node3D:
	var n := Node3D.new()
	n.name = "OpenExchange"
	n.position = EXCHANGE
	var k := Kit.new()
	var glow := Kit.new()
	k.mesh(_mat(NIGHT), Proc._cyl_mesh(3.6, 3.8, 1.8, 14), Transform3D(Basis(), Vector3(0, 0.9, 0)))
	k.mesh(_mat(WALL), Proc._cyl_mesh(2.2, 3.2, 9.5, 12), Transform3D(Basis(), Vector3(0, 6.5, 0)))
	k.mesh(_mat(WALL_WARM), Proc._cyl_mesh(0.2, 2.5, 2.8, 10), Transform3D(Basis(), Vector3(0, 12.6, 0)))
	for y: float in [3.4, 6.4, 9.4]:
		glow.mesh(_neon(PINK if y < 5.0 or y > 9.0 else CYAN), Proc._cyl_mesh(3.42 - y * 0.105, 3.47 - y * 0.105, 0.14, 12), Transform3D(Basis(), Vector3(0, y, 0)))
	k.box(_mat(NIGHT), Vector3(0.08, 1.8, 0.08), Vector3(0, 14.8, 0))
	glow.box(_neon(Color("ff3b3b")), Vector3(0.05, 0.6, 0.9), Vector3(0, 15.3, 0.5))  # the flag
	if town:
		var hub := Vector3(-2.75, 9.6, 0)
		k.box(_mat(NIGHT), Vector3(0.7, 0.5, 0.5), hub + Vector3(0.3, 0, 0))
		for i in 4:
			var turn := PI / 4.0 + i * PI / 2.0
			var len := 5.6
			var mid := hub + Vector3(-0.1, cos(turn) * len * 0.5, sin(turn) * len * 0.5)
			k.box(_mat(NIGHT), Vector3(0.14, len, 1.0), mid, Vector3(turn, 0, 0))
			glow.box(_neon(CYAN), Vector3(0.16, len - 0.6, 0.12), mid + Vector3(-0.02, 0, 0), Vector3(turn, 0, 0))
			glow.box(_neon(PINK), Vector3(0.16, len - 1.4, 0.08), mid + Vector3(-0.02, sin(turn) * 0.3, -cos(turn) * 0.3), Vector3(turn, 0, 0))
		glow.box(_neon(Color("ff2e88")), Vector3(0.2, 1.7, 1.3), Vector3(-3.66, 0.85, 0.0))  # the doorway is light itself: always open
		k.box(_mat(NIGHT), Vector3(0.14, 2.3, 3.6), Vector3(-3.3, 4.4, 0))  # the board: two lines that cross, no letters
		var a := [Vector3(0, -0.6, -1.5), Vector3(0, 0.1, -0.7), Vector3(0, -0.3, 0.0), Vector3(0, 0.7, 0.8), Vector3(0, 0.4, 1.5)]
		var b := [Vector3(0, 0.6, -1.5), Vector3(0, 0.2, -0.6), Vector3(0, 0.5, 0.1), Vector3(0, -0.4, 0.9), Vector3(0, -0.7, 1.5)]
		for line: Array in [[a, CYAN], [b, PINK]]:
			var pts: Array = line[0]
			for i in pts.size() - 1:
				var p0: Vector3 = pts[i]
				var p1: Vector3 = pts[i + 1]
				glow.box(_neon(line[1]), Vector3(0.05, 0.1, p0.distance_to(p1) + 0.08), Vector3(-3.4, 4.4, 0) + (p0 + p1) * 0.5, Vector3(atan2(-(p1.y - p0.y), p1.z - p0.z), 0, 0))
	n.add_child(k.commit("Tower"))
	var lights := glow.commit("Neon")
	lights.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(lights)
	Solid.post(n, 3.75, 1.8, Vector3.ZERO)
	Solid.post(n, 3.3, 9.0, Vector3(0, 1.8, 0))
	Solid.box(n, Vector3(0.3, 1.7, 1.3), Vector3(-3.66, 0.85, 0.0))
	return n


## A neon palm: a dark trunk and six glowing fronds, pink and cyan.
static func palm(rng: RandomNumberGenerator, at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = "NeonPalm"
	n.position = at
	var h := rng.randf_range(3.6, 4.6)
	var k := Kit.new()
	var glow := Kit.new()
	k.mesh(_mat(Color("3a1f4a")), Proc._cyl_mesh(0.1, 0.17, h, 6), Transform3D(Basis.from_euler(Vector3(0, 0, 0.06)), Vector3(0, h * 0.5, 0)))
	for i in 6:
		var a := TAU * i / 6.0 + rng.randf() * 0.3
		var dir := Vector3(cos(a), 0, sin(a))
		for j in 3:  # each frond bends down in three pieces
			var out := 0.45 + j * 0.62
			glow.box(_neon(PINK if i % 2 == 0 else CYAN), Vector3(0.7, 0.07, 0.16), Vector3(-0.12, h + 0.25 - j * j * 0.16, 0) + dir * out, Vector3(0, -a, -0.15 - j * 0.33))
	n.add_child(k.commit("Trunk"))
	var lights := glow.commit("Fronds")
	lights.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(lights)
	Solid.post(n, 0.2, h, Vector3.ZERO)
	return n


## The coin monument (sheet 45): our own coin — gold, with a wind curl — standing on edge on a plinth.
static func _monument(at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = "WindCoin"
	n.position = at
	var k := Kit.new()
	var glow := Kit.new()
	k.mesh(_mat(Color("3a3f6a")), Proc._cyl_mesh(0.9, 1.1, 0.9, 10), Transform3D(Basis(), Vector3(0, 0.45, 0)))
	glow.mesh(_neon(CYAN), Proc._cyl_mesh(0.94, 0.94, 0.08, 10), Transform3D(Basis(), Vector3(0, 0.82, 0)))
	var face := Basis.from_euler(Vector3(PI / 2, 0, 0))  # the coin stands on edge, its faces look ±z
	glow.mesh(_mat(GOLD, 1.5), Proc._cyl_mesh(1.25, 1.25, 0.22, 20), Transform3D(face, Vector3(0, 2.3, 0)))
	glow.mesh(_mat(Color("ffb400"), 1.5), Proc._cyl_mesh(1.05, 1.05, 0.26, 20), Transform3D(face, Vector3(0, 2.3, 0)))
	for sz: float in [-1.0, 1.0]:  # the wind curl: three strokes, the upper two ending in a hook
		for i in 3:
			var y := 2.62 - i * 0.32
			k.box(_mat(Color("1b1035")), Vector3(1.2 - i * 0.2, 0.16, 0.06), Vector3(-0.1 + i * 0.1, y, sz * 0.15))
			if i < 2:
				k.box(_mat(Color("1b1035")), Vector3(0.1, 0.24, 0.04), Vector3(0.55 - i * 0.02, y + 0.11, sz * 0.15))
				k.box(_mat(Color("1b1035")), Vector3(0.26, 0.1, 0.04), Vector3(0.42 - i * 0.02, y + 0.22, sz * 0.15))
	n.add_child(k.commit("Plinth"))
	n.add_child(glow.commit("Coin"))
	Solid.post(n, 1.1, 0.9, Vector3.ZERO)
	Solid.box(n, Vector3(1.8, 2.0, 0.3), Vector3(0, 2.5, 0))  # the coin itself, above every head: thin, on edge
	return n


## The mining machine: a rack of boards and screens on a drilling base.
static func _mining_machine(at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = "MiningMachine"
	n.position = at
	var k := Kit.new()
	var glow := Kit.new()
	k.box(_mat(Color("2f3260")), Vector3(2.6, 0.7, 1.8), Vector3(0, 0.35, 0))
	k.box(_mat(Color("3a3f6a")), Vector3(2.4, 1.6, 1.7), Vector3(0, 1.5, 0))
	k.box(_mat(Color("2f3260")), Vector3(2.6, 2.3, 0.5), Vector3(0, 1.15, 1.2))  # the housing over the drills
	for i in 3:
		glow.box(_neon([PINK, CYAN, Color("9a5cff")][i]), Vector3(0.6, 0.5, 0.05), Vector3(-0.72 + i * 0.72, 1.85, 1.46))
		glow.box(_neon(Color("3dff9a")), Vector3(0.6, 0.1, 0.05), Vector3(-0.72 + i * 0.72, 1.35, 1.46))
	n.add_child(k.commit("Machine"))
	n.add_child(glow.commit("Screens"))
	Solid.box(n, Vector3(2.6, 2.3, 2.4), Vector3(0, 1.15, 0.28))  # one box, drills and all: nothing low to climb onto, and not so tall that the audit takes its top for ground
	return n


static func _vending(at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = "VendingMachine"
	n.position = at
	var k := Kit.new()
	var glow := Kit.new()
	k.box(_mat(Color("3a3f8a")), Vector3(1.3, 2.2, 0.9), Vector3(0, 1.1, 0))
	glow.box(_mat(Color("12b8c8"), 1.2), Vector3(0.8, 1.2, 0.05), Vector3(-0.15, 1.45, 0.46))
	for r in 3:
		for c in 3:
			glow.box(_neon([PINK, GOLD, CYAN][(r + c) % 3]), Vector3(0.14, 0.24, 0.06), Vector3(-0.4 + c * 0.25, 1.85 - r * 0.38, 0.48))
	glow.box(_neon(PINK), Vector3(1.0, 0.08, 0.05), Vector3(0, 0.3, 0.46))
	n.add_child(k.commit("Machine"))
	n.add_child(glow.commit("Lights"))
	Solid.box(n, Vector3(1.3, 2.2, 0.9), Vector3(0, 1.1, 0))
	return n


## The ticker board over the street: a chart line and an arrow, no letters, high above every hat.
static func _ticker(at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = "TickerBoard"
	n.position = at
	n.set_meta("hung", true)
	var k := Kit.new()
	var glow := Kit.new()
	for sz: float in [-4.4, 4.4]:
		k.box(_mat(NIGHT), Vector3(0.16, 5.4, 0.16), Vector3(0, 2.7, sz))
		Solid.post(n, 0.12, 5.4, Vector3(0, 0, sz))
	k.box(_mat(Color("15102e")), Vector3(0.16, 1.2, 8.8), Vector3(0, 4.7, 0))
	var pts := [Vector3(0, -0.3, -3.8), Vector3(0, 0.1, -2.9), Vector3(0, -0.2, -2.1), Vector3(0, 0.3, -1.2), Vector3(0, 0.0, -0.4), Vector3(0, 0.4, 0.5)]
	for sx: float in [-1.0, 1.0]:
		for i in pts.size() - 1:
			var p0: Vector3 = pts[i]
			var p1: Vector3 = pts[i + 1]
			glow.box(_neon(Color("3dff9a")), Vector3(0.04, 0.07, p0.distance_to(p1) + 0.05), Vector3(sx * 0.1, 4.7, 0) + (p0 + p1) * 0.5, Vector3(atan2(-(p1.y - p0.y), p1.z - p0.z), 0, 0))
		glow.box(_neon(GOLD), Vector3(0.04, 0.5, 0.5), Vector3(sx * 0.1, 4.7, 2.0), Vector3(PI / 4, 0, 0))  # the wind coin
		glow.box(_neon(Color("3dff9a")), Vector3(0.04, 0.36, 0.36), Vector3(sx * 0.1, 4.75, 3.3), Vector3(PI / 4, 0, 0))  # an arrow up, for now
	n.add_child(k.commit("Board"))
	n.add_child(glow.commit("Lines"))
	return n


## A robot of sheet 44, built whole in code: `bot_trader` hovers on jets, `bot_miner` rides tracks, `bot_info`
## stands on thin legs and listens with five antennas. All have a screen for a face.
static func bot(kind: String) -> Node3D:
	var n := Node3D.new()
	n.name = "Bot_" + kind
	var k := Kit.new()
	var glow := Kit.new()
	var steel := _mat(Color("8a8fb0"))
	var dark := _mat(Color("3a3f6a"))
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 12
	ball.rings = 6
	var body_y := 1.25 if kind == "bot_trader" else 0.95
	k.mesh(steel, ball, Transform3D(Basis().scaled(Vector3(1.1, 1.2, 1.0)), Vector3(0, body_y, 0)))
	k.box(dark, Vector3(0.74, 0.5, 0.1), Vector3(0, body_y + 0.1, 0.44))
	glow.box(_mat(Color("0a2a3a"), 0.6), Vector3(0.64, 0.4, 0.06), Vector3(0, body_y + 0.1, 0.47))
	for sx: float in [-1.0, 1.0]:  # eyes on the screen, and arms
		glow.box(_neon(CYAN), Vector3(0.12, 0.16, 0.04), Vector3(sx * 0.16, body_y + 0.14, 0.51))
		k.box(steel, Vector3(0.12, 0.5, 0.12), Vector3(sx * 0.66, body_y - 0.1, 0.05), Vector3(0, 0, sx * 0.3))
	glow.box(_neon(CYAN), Vector3(0.2, 0.04, 0.04), Vector3(0, body_y - 0.02, 0.51))
	match kind:
		"bot_trader":
			glow.box(_neon(PINK), Vector3(0.5, 0.05, 0.04), Vector3(0, 0.98, 0.46))  # a little chart on the belly
			for sx: float in [-0.3, 0.0, 0.3]:
				k.mesh(dark, Proc._cyl_mesh(0.1, 0.07, 0.2, 6), Transform3D(Basis(), Vector3(sx, 0.6, 0)))
				glow.mesh(_neon(ORANGE), Proc._cyl_mesh(0.06, 0.01, 0.3, 6), Transform3D(Basis(), Vector3(sx, 0.36, 0)))
		"bot_miner":
			for sx: float in [-1.0, 1.0]:
				k.box(dark, Vector3(0.3, 0.36, 1.1), Vector3(sx * 0.42, 0.18, 0))
			k.box(_mat(GOLD), Vector3(0.36, 0.2, 0.3), Vector3(0, body_y + 0.72, 0.05))  # the lamp on its head
			glow.box(_neon(CYAN), Vector3(0.16, 0.12, 0.05), Vector3(0, body_y + 0.72, 0.21))
		_:
			for i in 4:
				var a := PI / 4.0 + i * PI / 2.0
				k.box(steel, Vector3(0.06, 0.6, 0.06), Vector3(cos(a) * 0.36, 0.3, sin(a) * 0.36), Vector3(sin(a) * 0.35, 0, -cos(a) * 0.35))
			for i in 5:
				var x := -0.3 + i * 0.15
				k.box(dark, Vector3(0.03, 0.4 + (i % 2) * 0.15, 0.03), Vector3(x, body_y + 0.75, 0), Vector3(0, 0, -x * 0.8))
				glow.box(_neon(GOLD if i == 2 else PINK), Vector3(0.07, 0.07, 0.07), Vector3(x - x * 0.2, body_y + 0.98 + (i % 2) * 0.08, 0))
	n.add_child(k.commit("Body"))
	var lights := glow.commit("Lights")
	lights.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(lights)
	Solid.post(n, 0.6, 1.9, Vector3.ZERO)
	return n

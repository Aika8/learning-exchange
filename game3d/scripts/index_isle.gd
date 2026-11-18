## Pattern: Builder — the index island (working name; `docs/design/concepts/47…51`): very rich and very boring. A
## town mirror-symmetrical about its avenue: a pier with sky yachts, the avenue, a round square with a fountain
## that drops a coin, identical mansions in mirrored pairs, clipped hedges, lollipop trees, and at the end the Bank
## Palace under its dome. Pastel paint from the sheets' palette; nothing is traded here yet.
## See docs/adr/0033-game3d-index-island-as-a-toy-town.md
class_name IndexIsle
extends RefCounted

const ID := "index"
const AT := Vector3(380, 4, 120)  ## the island's centre in the world
const RADIUS := 40.0
const SEED := 71
const DECK_Y := 0.12
const PIER_FROM := AT + Vector3(-56.0, DECK_Y, -2.4)
const PIER_TO := AT + Vector3(-27.0, DECK_Y, 2.4)  ## its island end lies well inside the walkable cap
const DOCK := AT + Vector3(-51.0, 0, 8.5)
const SPAWN := AT + Vector3(-44.0, 0.5, 0)
const PALACE := Vector3(24.0, 0, 0)  ## the Bank Palace, in the island's own space; the avenue runs along x to it
const FOUNTAIN := Vector3(2.0, 0, 0)
const COIN_EVERY := 4.0  ## seconds between two coins of the fountain
const PINK := Color("ffb7b2")
const MINT := Color("b5e2b8")
const BUTTER := Color("ffeb99")
const BLUE := Color("a8dadc")
const LAVENDER := Color("e2cee2")
const TEAL := Color("1a5b5c")
const GOLD := Color("d9a441")
const CREAM := Color("fdf5e6")

static var _mats: Dictionary = {}


static func walk_areas() -> Array[Dictionary]:
	return [{"name": "index", "kind": "disc", "centre": AT, "radius": RADIUS, "seed": SEED},
		{"name": "index-pier", "kind": "rect", "from": PIER_FROM, "to": PIER_TO}]


## Where the gentleman stands by the palace door and where the captain talks to him: [keeper, spot], world space.
static func door() -> Array[Vector3]:
	return [AT + PALACE + Vector3(-7.4, 0, 2.2), AT + PALACE + Vector3(-8.8, 0, 1.2)]


static func _mat(c: Color, glow: float = 0.0, both_sides: bool = false) -> Material:
	var key := "%s/%s/%s" % [c.to_html(), glow, both_sides]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.6
		if both_sides:
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		if glow > 0.0:
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = glow
		_mats[key] = m
	return _mats[key]


## One side of the town, z > 0; the other side is its mirror. Mansions: [place, roof colour]; they face the avenue.
static func mansions() -> Array:
	return [[Vector3(-19.0, 0, 11.5), BLUE], [Vector3(-7.5, 0, 11.5), LAVENDER], [Vector3(11.0, 0, 13.0), BLUE], [Vector3(-13.0, 0, 25.0), LAVENDER], [Vector3(2.0, 0, 26.5), BLUE]]


static func trees() -> Array[Vector3]:
	return [Vector3(-25.0, 0, 4.2), Vector3(-17.0, 0, 4.2), Vector3(-9.0, 0, 4.2), Vector3(10.5, 0, 5.0), Vector3(16.0, 0, 7.5), Vector3(-1.5, 0, 9.0), Vector3(5.5, 0, 9.0),
		Vector3(-22.0, 0, 19.0), Vector3(21.0, 0, 16.0), Vector3(-5.0, 0, 19.5)]


## The whole island. `town` = false gives the rock and plain pastel blocks: what is seen from far away.
static func build(town: bool) -> Node3D:
	var isl := Node3D.new()
	isl.name = "IndexIsle"
	isl.add_child(Archipelago.island(RADIUS, 40.0, SEED, 0.0, true))
	for side: float in [1.0, -1.0]:
		for m: Array in mansions():
			var at: Vector3 = m[0]
			var hs: Node3D
			if town:
				hs = mansion(m[1])
			else:
				hs = Node3D.new()
				hs.add_child(Proc.box(Vector3(7.0, 6.0, 5.6), PINK, Vector3(0, 3.0, 0)))
				hs.add_child(Proc.box(Vector3(6.0, 1.6, 4.6), m[1], Vector3(0, 6.8, 0)))
			hs.position = Vector3(at.x, 0, at.z * side)
			hs.rotation.y = PI if side > 0 else 0.0  # the door looks at the avenue
			hs.set_meta("mirror", side)
			isl.add_child(hs)
	isl.add_child(_palace(town))
	if not town:
		return isl
	isl.add_child(_paving())
	isl.add_child(_fountain())
	var coin := Proc.mesh_node(Proc._cyl_mesh(0.22, 0.22, 0.05, 12), _mat(GOLD, 0.6), FOUNTAIN + Vector3(0, 2.0, 0))
	coin.name = "Coin"  # a thing of its own, in the air on purpose: the port scene throws it (`coin_height`)
	coin.set_meta("hung", true)
	coin.rotation.x = PI / 2
	isl.add_child(coin)
	for side: float in [1.0, -1.0]:
		for at: Vector3 in trees():
			var t := lollipop(Vector3(at.x, 0, at.z * side), int(absf(at.x)) % 2 == 0)
			t.set_meta("mirror", side)
			isl.add_child(t)
		for h: Array in [[Vector3(-13.5, 0, 6.6), 22.0], [Vector3(14.0, 0, 9.6), 9.0]]:  # clipped hedges along the avenue
			var hedge := Node3D.new()
			hedge.name = "Hedge"
			hedge.position = Vector3((h[0] as Vector3).x, 0, (h[0] as Vector3).z * side)
			hedge.add_child(Proc.box(Vector3(h[1], 0.9, 0.9), Color("8fcf9a"), Vector3(0, 0.45, 0)))
			Solid.box(hedge, Vector3(h[1], 0.9, 0.9), Vector3(0, 0.45, 0))
			hedge.set_meta("mirror", side)
			isl.add_child(hedge)
		for x: float in [-49.0, -40.0]:  # sky yachts moored either side of the pier
			var y := yacht(x < -45.0)
			y.position = Vector3(x, 0.6, 7.5 * side)
			y.rotation.y = PI / 2
			y.set_meta("mirror", side)
			isl.add_child(y)
		var lamp := _lamp(Vector3(-29.0, 0, 3.6 * side))
		lamp.set_meta("mirror", side)
		isl.add_child(lamp)
	isl.add_child(Archipelago._deck("Pier", PIER_FROM - AT, PIER_TO - AT, [true, false, true, true], PIER_TO - AT + Vector3(0, 0, -2)))
	var f := Node3D.new()
	f.name = "Fences"
	isl.add_child(f)
	Solid.fence_areas(f, walk_areas(), AT)
	return isl


## A mansion of sheet 48, the same every time but for the colour of its roof: pink walls, mint trim, arched
## white windows, a balcony over a lavender door, a hipped roof with gold finials. The door looks +z.
static func mansion(roof: Color) -> Node3D:
	var hs := Node3D.new()
	hs.name = "Mansion"
	var w := 7.0
	var d := 5.6
	var top := 6.2
	var k := Kit.new()
	var wall := _mat(PINK)
	var trim := _mat(MINT)
	var white := _mat(CREAM)
	var glass := _mat(BLUE)
	k.box(_mat(Color("e8dcc8")), Vector3(w + 0.5, 1.6, d + 0.5), Vector3(0, -0.5, 0))
	k.box(wall, Vector3(w, top - 0.3, d), Vector3(0, 0.3 + (top - 0.3) * 0.5, 0))
	for y: float in [0.45, 3.2, top - 0.1]:
		k.box(trim, Vector3(w + 0.24, 0.26, d + 0.24), Vector3(0, y, 0))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.box(trim, Vector3(0.34, top - 0.3, 0.34), Vector3(sx * w * 0.5, 0.3 + (top - 0.3) * 0.5, sz * d * 0.5))
	for floor_i in 2:
		var y := 1.9 + floor_i * 2.8
		for x: float in [-2.3, 2.3] if floor_i == 0 else [-2.3, 0.0, 2.3]:
			for sz: float in [1.0, -1.0]:
				var z := sz * (d * 0.5 + 0.02)
				k.box(white, Vector3(1.1, 1.6, 0.1), Vector3(x, y, z))
				k.mesh(white, Proc._cyl_mesh(0.55, 0.55, 0.1, 10), Transform3D(Basis.from_euler(Vector3(PI / 2, 0, 0)), Vector3(x, y + 0.8, z)))
				k.box(glass, Vector3(0.82, 1.36, 0.12), Vector3(x, y, z + sz * 0.01))
				k.box(white, Vector3(0.06, 1.36, 0.14), Vector3(x, y, z + sz * 0.01))
	var front := d * 0.5
	k.box(white, Vector3(1.5, 2.5, 0.12), Vector3(0, 1.55, front + 0.02))
	k.box(_mat(LAVENDER.darkened(0.12)), Vector3(1.16, 2.2, 0.14), Vector3(0, 1.4, front + 0.04))
	k.box(_mat(GOLD), Vector3(0.08, 0.08, 0.08), Vector3(0.4, 1.4, front + 0.13))
	k.box(white, Vector3(2.6, 0.14, 0.9), Vector3(0, 3.35, front + 0.45))  # the balcony
	for bx: float in [-1.2, -0.6, 0.0, 0.6, 1.2]:
		k.box(white, Vector3(0.1, 0.7, 0.1), Vector3(bx, 3.75, front + 0.85))
	k.box(white, Vector3(2.6, 0.1, 0.1), Vector3(0, 4.1, front + 0.85))
	for cx: float in [-1.15, 1.15]:
		k.box(white, Vector3(0.22, 3.0, 0.22), Vector3(cx, 1.8, front + 0.8))
	# the hipped roof and its gold finials
	var hw := w * 0.5 + 0.35
	var hd := d * 0.5 + 0.35
	var ridge := 1.6
	var rise := 2.2
	var tiles := _mat(roof, 0.0, true)
	var a := Vector3(-hw, top, hd)
	var b := Vector3(hw, top, hd)
	var c := Vector3(ridge, top + rise, 0)
	var e := Vector3(-ridge, top + rise, 0)
	k.quad(tiles, a, b, c, e)
	k.quad(tiles, Vector3(hw, top, -hd), Vector3(-hw, top, -hd), e, c)
	k.tri(tiles, Vector3(hw, top, -hd), Vector3(hw, top, hd), c)
	k.tri(tiles, Vector3(-hw, top, hd), Vector3(-hw, top, -hd), e)
	for fx: float in [-ridge, ridge]:
		k.mesh(_mat(GOLD), Proc._cyl_mesh(0.0, 0.14, 0.5, 6), Transform3D(Basis(), Vector3(fx, top + rise + 0.25, 0)))
	k.box(_mat(Color("e8dcc8")), Vector3(2.0, 0.3, 1.0), Vector3(0, 0.15, front + 0.5))  # the step
	hs.add_child(k.commit("Walls"))
	Solid.box(hs, Vector3(w + 0.34, top + 1.6, d + 0.34), Vector3(0, top * 0.5 - 0.5, 0))
	Solid.box(hs, Vector3(2.0, 0.3, 1.0), Vector3(0, 0.15, front + 0.5))  # the step
	for cx: float in [-1.15, 1.15]:  # the two columns under the balcony
		Solid.post(hs, 0.16, 3.3, Vector3(cx, 0.3, front + 0.8))
	hs.set_meta("size", Vector3(w, top, d))
	return hs


## The Bank Palace (sheet 47): a round stone base, pink walls with cream columns and a pediment facing the avenue,
## two wings, a rose dome with a gold lantern and a flag.
static func _palace(town: bool) -> Node3D:
	var n := Node3D.new()
	n.name = "BankPalace"
	n.position = PALACE
	var k := Kit.new()
	var wall := _mat(PINK)
	var cream := _mat(CREAM)
	k.mesh(_mat(Color("e8dcc8")), Proc._cyl_mesh(8.6, 8.9, 1.0, 20), Transform3D(Basis(), Vector3(0, 0.5, 0)))
	k.mesh(wall, Proc._cyl_mesh(6.4, 6.4, 7.0, 16), Transform3D(Basis(), Vector3(0, 4.5, 0)))
	k.mesh(_mat(MINT), Proc._cyl_mesh(6.7, 6.7, 0.4, 16), Transform3D(Basis(), Vector3(0, 8.0, 0)))
	var dome := SphereMesh.new()
	dome.radius = 4.6
	dome.height = 9.2
	dome.radial_segments = 16
	dome.rings = 8
	k.mesh(_mat(Color("f4a6b0")), dome, Transform3D(Basis().scaled(Vector3(1, 0.8, 1)), Vector3(0, 8.4, 0)))
	k.mesh(_mat(GOLD), Proc._cyl_mesh(0.5, 0.7, 1.0, 8), Transform3D(Basis(), Vector3(0, 12.4, 0)))
	k.box(_mat(GOLD), Vector3(0.08, 1.6, 0.08), Vector3(0, 13.7, 0))
	k.box(_mat(PINK.darkened(0.1)), Vector3(0.05, 0.5, 0.8), Vector3(0, 14.2, 0.45))
	if town:
		for sz: float in [-1.0, 1.0]:  # the wings
			k.box(wall, Vector3(5.0, 5.0, 4.6), Vector3(-1.0, 3.5, sz * 8.0))
			k.box(_mat(MINT), Vector3(5.3, 0.3, 4.9), Vector3(-1.0, 6.1, sz * 8.0))
			k.box(_mat(BLUE), Vector3(4.4, 0.7, 4.0), Vector3(-1.0, 6.6, sz * 8.0))
			for wy: float in [2.4, 4.6]:
				k.box(cream, Vector3(0.1, 1.3, 1.0), Vector3(-3.52, wy, sz * 8.0))
				k.box(_mat(BLUE), Vector3(0.12, 1.1, 0.8), Vector3(-3.53, wy, sz * 8.0))
		for cz: float in [-3.0, -1.0, 1.0, 3.0]:  # the portico towards the avenue
			k.mesh(cream, Proc._cyl_mesh(0.32, 0.36, 5.4, 10), Transform3D(Basis(), Vector3(-7.2, 3.7, cz)))
		k.box(cream, Vector3(1.6, 0.5, 7.6), Vector3(-7.0, 6.65, 0))
		k.tri(cream, Vector3(-7.75, 6.9, 3.8), Vector3(-7.75, 6.9, -3.8), Vector3(-7.75, 8.6, 0))
		k.box(cream, Vector3(1.6, 0.1, 7.6), Vector3(-7.0, 6.95, 0), Vector3(0, 0, 0))
		k.box(_mat(Color("b98a6a")), Vector3(0.2, 3.2, 1.8), Vector3(-6.45, 2.6, 0))  # the door
		k.box(_mat(GOLD), Vector3(0.22, 0.12, 0.12), Vector3(-6.5, 2.6, 0.3))
	n.add_child(k.commit("Palace"))
	Solid.post(n, 8.9, 1.0, Vector3.ZERO)
	Solid.post(n, 6.5, 8.0, Vector3(0, 1.0, 0))
	if town:
		for sz: float in [-1.0, 1.0]:
			Solid.box(n, Vector3(5.3, 6.0, 4.9), Vector3(-1.0, 4.0, sz * 8.0))
		for cz: float in [-3.0, -1.0, 1.0, 3.0]:
			Solid.post(n, 0.36, 5.4, Vector3(-7.2, 1.0, cz))
	return n


## Pale stone under the avenue and the round square.
static func _paving() -> Node3D:
	var n := Node3D.new()
	n.name = "Paving"
	n.set_meta("flat", true)
	var k := Kit.new()
	var disc := Proc._cyl_mesh(8.0, 8.0, 0.06, 28)
	k.mesh(_mat(Color("f6dcd6")), disc, Transform3D(Basis(), FOUNTAIN + Vector3(0, 0.03, 0)))
	k.box(_mat(Color("f3ead6")), Vector3(46.0, 0.06, 5.0), Vector3(-9.0, 0.02, 0))
	n.add_child(k.commit("Slabs"))
	return n


## The fountain: two tiers of pale blue stone. A coin (the island's child "Coin") is thrown up over it and falls
## back every COIN_EVERY seconds; `coin_height` says where it is.
static func _fountain() -> Node3D:
	var n := Node3D.new()
	n.name = "CoinFountain"
	n.position = FOUNTAIN
	n.add_child(Proc.cyl(2.4, 2.6, 0.6, 16, Color("dfeaf0"), Vector3(0, 0.3, 0)))
	n.add_child(Proc.cyl(2.1, 2.1, 0.06, 16, BLUE, Vector3(0, 0.62, 0)))
	n.add_child(Proc.cyl(0.3, 0.45, 1.6, 10, Color("dfeaf0"), Vector3(0, 0.9, 0)))
	n.add_child(Proc.cyl(1.0, 0.4, 0.25, 12, Color("dfeaf0"), Vector3(0, 1.8, 0)))
	Solid.post(n, 2.6, 0.7, Vector3.ZERO)
	Solid.post(n, 0.5, 2.0, Vector3.ZERO)
	return n


## Where the fountain's coin is `t` seconds into its cycle: metres above the bowl's top, or −1 when it is under water.
static func coin_height(t: float) -> float:
	var u := fposmod(t, COIN_EVERY)
	if u > 1.2:
		return -1.0
	return 2.4 * 4.0 * (u / 1.2) * (1.0 - u / 1.2)  # up 2.4 m and down again in 1.2 s


## A lollipop tree: a cream stick and a round or pointed teal sweet.
static func lollipop(at: Vector3, pointed: bool) -> Node3D:
	var t := Node3D.new()
	t.name = "Lollipop"
	t.position = at
	t.add_child(Proc.cyl(0.12, 0.14, 2.3, 6, Color("e8dcc8"), Vector3(0, 1.15, 0)))
	if pointed:
		t.add_child(Proc.cyl(0.0, 0.95, 2.6, 10, Color("2f8f86"), Vector3(0, 3.5, 0)))
	else:
		t.add_child(Proc.ball(1.05, Color("8fcf9a"), Vector3(0, 3.3, 0)))
	Solid.post(t, 0.2, 2.3, Vector3.ZERO)  # the sweet is above every hat: only the stick stops a walker
	return t


## A sky yacht at the pier: a cream hull and a tall pastel sail. Decoration beyond the rail: nobody reaches it.
static func yacht(pink_sail: bool) -> Node3D:
	var n := Node3D.new()
	n.name = "SkyYacht"
	n.set_meta("flat", true)
	var hull := Proc.mesh_node(Proc.hull_mesh(4.6, 1.5, 0.9), _mat(CREAM))
	n.add_child(hull)
	n.add_child(Proc.box(Vector3(0.1, 4.6, 0.1), GOLD, Vector3(0, 2.6, 0)))
	var k := Kit.new()
	k.tri(_mat(PINK if pink_sail else BLUE), Vector3(0, 0.9, 0.1), Vector3(0, 4.8, 0.1), Vector3(0, 0.9, 2.1))
	k.tri(_mat(PINK if pink_sail else BLUE), Vector3(0, 0.9, 0.1), Vector3(0, 0.9, 2.1), Vector3(0, 4.8, 0.1))
	k.tri(_mat(BUTTER), Vector3(0, 0.9, -0.1), Vector3(0, 0.9, -1.5), Vector3(0, 3.6, -0.1))
	k.tri(_mat(BUTTER), Vector3(0, 0.9, -0.1), Vector3(0, 3.6, -0.1), Vector3(0, 0.9, -1.5))
	n.add_child(k.commit("Sails"))
	return n


static func _lamp(at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = "ToyLamp"
	n.position = at
	n.add_child(Proc.cyl(0.08, 0.12, 2.8, 8, CREAM, Vector3(0, 1.4, 0)))
	n.add_child(Proc.ball(0.3, BUTTER, Vector3(0, 3.0, 0), 1.2))
	n.add_child(Proc.cyl(0.0, 0.2, 0.25, 8, GOLD, Vector3(0, 3.4, 0)))
	Solid.post(n, 0.12, 3.0, Vector3.ZERO)
	return n

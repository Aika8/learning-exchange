## Pattern: Builder — the index island (working name; `docs/design/concepts/59…66`): a canal town of the Dutch
## Golden Age. From the pier a street crosses a canal by a stone bridge and comes to a square with a fountain that
## drops a coin, and to the Exchange under its clock tower. Narrow brick houses with stepped and bell gables stand
## in rows along the quays; lindens, lanterns, a market stall, boats on the canal, sky ships at the pier.
## Brick, ochre, olive, Delft blue, cream and soot, from the sheets' palette. Nothing is traded here yet.
## See docs/adr/0035-game3d-index-island-as-a-dutch-golden-age-painting.md
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
const EXCHANGE := Vector3(25.0, 0, 0)  ## the Exchange, in the island's own space; the street runs along x to it
const FOUNTAIN := Vector3(10.0, 0, 0)
const COIN_EVERY := 4.0  ## seconds between two coins of the fountain
const CANAL_X := -9.0  ## the canal runs along z, across the street
const CANAL_W := 5.0
const CANAL_END := 30.0
const HOUSE_W := 4.6
const HOUSE_D := 6.0
const BRICK := Color("9a3b26")
const OCHRE := Color("a0781c")
const OLIVE := Color("5a5632")
const DELFT := Color("214375")
const CREAM := Color("eae2ca")
const GOLD := Color("cbb45e")
const SOOT := Color("1c1c1c")
const STONE := Color("b3a58a")
const TILE := Color("7a3324")
const SLATE := Color("2f4566")
const WATER := Color("4c7078")
const TIMBER := Color("6a4a30")
## The crossings of the canal: [z of the middle, width]. The first is the street's own bridge.
const BRIDGES := [[0.0, 6.0], [18.5, 3.0], [-18.5, 3.0]]

static var _mats: Dictionary = {}


static func walk_areas() -> Array[Dictionary]:
	return [{"name": "index", "kind": "disc", "centre": AT, "radius": RADIUS, "seed": SEED},
		{"name": "index-pier", "kind": "rect", "from": PIER_FROM, "to": PIER_TO}]


## Where the merchant stands before the Exchange's arcade and where the captain talks to him: [keeper, spot], world space.
static func door() -> Array[Vector3]:
	return [AT + EXCHANGE + Vector3(-8.4, 0, 2.0), AT + EXCHANGE + Vector3(-9.8, 0, 1.0)]


## Where the market woman stands by her stall, and where the captain talks to her.
static func stall() -> Array[Vector3]:
	return [AT + Vector3(8.6, 0, 9.4), AT + Vector3(9.4, 0, 7.8)]


## A material. A surface of a `Kit` is built either from boxes and ready meshes or from quads and triangles, never
## both: `flat` = true is the material for quads and triangles (drawn from both sides).
static func _mat(c: Color, glow: float = 0.0, flat: bool = false) -> Material:
	var key := "%s/%s/%s" % [c.to_html(), glow, flat]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.85
		if flat:
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		if glow > 0.0:
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = glow
		_mats[key] = m
	return _mats[key]


## Every house: [place, the way its door looks (radians round y), front colour, roof colour, bell gable?].
## Two rows face each other across the canal; four more close the square. No two neighbours share a front.
static func houses() -> Array:
	var out: Array = []
	var fronts := [BRICK, OCHRE, BRICK.darkened(0.18), OLIVE.lightened(0.12), BRICK.lightened(0.08), OCHRE.darkened(0.15)]
	var n := 0
	for side: float in [1.0, -1.0]:  # the two halves of the town, either side of the street
		for i in 4:
			var z := side * (6.4 + i * 4.9)
			out.append([Vector3(CANAL_X - CANAL_W * 0.5 - 4.2 - HOUSE_D * 0.5, 0, z), PI / 2, fronts[n % 6], TILE if n % 2 == 0 else SLATE, n % 3 == 2])
			n += 1
			out.append([Vector3(CANAL_X + CANAL_W * 0.5 + 4.2 + HOUSE_D * 0.5, 0, z), -PI / 2, fronts[(n + 2) % 6], SLATE if n % 2 == 0 else TILE, n % 3 == 0])
			n += 1
		for x: float in [9.0, 14.2]:  # on the square, looking at it
			out.append([Vector3(x, 0, side * 15.5), PI if side > 0 else 0.0, fronts[(n + 1) % 6], TILE if n % 2 == 0 else SLATE, n % 2 == 1])
			n += 1
	return out


## Lindens along both quays, either side of every house door: [place].
static func lindens() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for side: float in [1.0, -1.0]:
		for z: float in [8.9, 13.8, 23.4]:
			out.append(Vector3(CANAL_X - CANAL_W * 0.5 - 1.1, 0, side * z))
			out.append(Vector3(CANAL_X + CANAL_W * 0.5 + 1.1, 0, side * z))
	return out


## The whole island. `town` = false gives the rock, plain blocks and the Exchange's tower: what is seen from far away.
static func build(town: bool) -> Node3D:
	var isl := Node3D.new()
	isl.name = "IndexIsle"
	isl.add_child(Archipelago.island(RADIUS, 40.0, SEED, 0.0, true))
	var n := 0
	for h: Array in houses():
		var hs: Node3D
		if town:
			hs = house(h[2], h[3], h[4])
		else:
			hs = Node3D.new()
			hs.add_child(Proc.box(Vector3(HOUSE_W, 7.6, HOUSE_D), h[2], Vector3(0, 3.8, 0)))
			hs.add_child(Proc.box(Vector3(HOUSE_W * 0.5, 2.4, HOUSE_D), h[3], Vector3(0, 8.8, 0)))
		n += 1
		hs.name = "House%d" % n
		hs.position = h[0]
		hs.rotation.y = h[1]
		isl.add_child(hs)
	isl.add_child(_exchange(town))
	if not town:
		return isl
	isl.add_child(_paving())
	_canal(isl)
	isl.add_child(_fountain())
	var coin := Proc.mesh_node(Proc._cyl_mesh(0.2, 0.2, 0.05, 12), _mat(GOLD, 0.6), FOUNTAIN + Vector3(0, 2.0, 0))
	coin.name = "Coin"  # a thing of its own, in the air on purpose: the port scene throws it (`coin_height`)
	coin.set_meta("hung", true)
	coin.rotation.x = PI / 2
	isl.add_child(coin)
	n = 0
	for at: Vector3 in lindens():
		n += 1
		var t := linden(at, n)
		isl.add_child(t)
	_props(isl)
	for side: float in [1.0, -1.0]:
		for x: float in [-49.0, -40.0]:  # sky ships moored either side of the pier
			var y := sky_ship()
			y.position = Vector3(x, 0.6, 7.5 * side)
			y.rotation.y = PI / 2
			isl.add_child(y)
	isl.add_child(Archipelago._deck("Pier", PIER_FROM - AT, PIER_TO - AT, [true, false, true, true], PIER_TO - AT + Vector3(0, 0, -2)))
	var f := Node3D.new()
	f.name = "Fences"
	isl.add_child(f)
	Solid.fence_areas(f, walk_areas(), AT)
	return isl


## A canal house of sheet 60: three floors of brick, cream bands and window frames, shutters, an arched door up a
## step, a tiled roof between two gables — stepped, or bell-shaped with a cream crown. The door looks +z.
static func house(front: Color, roof: Color, bell: bool) -> Node3D:
	var hs := Node3D.new()
	var w := HOUSE_W
	var d := HOUSE_D
	var top := 7.6
	var k := Kit.new()
	var wall := _mat(front)
	var side_wall := _mat(front.darkened(0.14))
	var cream := _mat(CREAM)
	var glass := _mat(Color("2b3138"))
	var shutter := _mat(SOOT if not bell else OLIVE.darkened(0.2))
	k.box(_mat(STONE.darkened(0.15)), Vector3(w + 0.2, 1.4, d + 0.2), Vector3(0, -0.3, 0))  # the plinth
	k.box(side_wall, Vector3(w - 0.3, top - 0.4, d - 0.5), Vector3(0, 0.4 + (top - 0.4) * 0.5, 0))
	var face := d * 0.5 - 0.2
	for sz: float in [1.0, -1.0]:  # the two gable walls, front and back
		k.box(wall, Vector3(w, top - 0.4, 0.4), Vector3(0, 0.4 + (top - 0.4) * 0.5, sz * face))
		if bell:
			k.box(wall, Vector3(w - 1.2, 1.7, 0.4), Vector3(0, top + 0.85, sz * face))
			k.box(wall, Vector3(w - 2.6, 1.2, 0.4), Vector3(0, top + 2.3, sz * face))
			k.mesh(cream, Proc._cyl_mesh(0.85, 0.85, 0.44, 12), Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, top + 2.9, sz * face)))
			for sx: float in [-1.0, 1.0]:  # the scrolls on the shoulders
				k.mesh(cream, Proc._cyl_mesh(0.42, 0.42, 0.44, 10), Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(sx * (w * 0.5 - 0.5), top + 0.4, sz * face)))
				k.mesh(cream, Proc._cyl_mesh(0.3, 0.3, 0.44, 10), Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(sx * (w * 0.5 - 1.25), top + 1.85, sz * face)))
			k.box(cream, Vector3(w + 0.1, 0.2, 0.46), Vector3(0, top, sz * face))
		else:
			for i in 4:  # the steps of the gable, each with its cream cap
				var sw := w - 0.2 - i * 1.1
				k.box(wall, Vector3(sw, 0.86, 0.4), Vector3(0, top + 0.43 + i * 0.86, sz * face))
				for sx: float in [-1.0, 1.0]:
					k.box(cream, Vector3(0.62, 0.12, 0.46), Vector3(sx * (sw * 0.5 - 0.26), top + 0.92 + i * 0.86, sz * face))
			k.box(cream, Vector3(0.5, 0.5, 0.46), Vector3(0, top + 3.6, sz * face))
		for y: float in [0.5, 2.9, 5.3]:
			k.box(cream, Vector3(w + 0.06, 0.14, 0.44), Vector3(0, y, sz * face))
	var z := d * 0.5 + 0.01
	for back: float in [1.0, -1.0]:  # windows on both gable walls: two a floor, three on the top one; shutters on the middle floor
		for floor_i in 3:
			var y := 1.75 + floor_i * 2.4
			for x: float in [-1.15, 1.15] if floor_i < 2 else [-1.3, 0.0, 1.3]:
				if floor_i == 0 and x < 0.0 and back > 0.0:
					continue  # the door is here
				var ww := 0.9 if floor_i < 2 else 0.7
				k.box(cream, Vector3(ww + 0.2, 1.5, 0.08), Vector3(x, y, back * z))
				k.box(glass, Vector3(ww, 1.3, 0.1), Vector3(x, y, back * (z + 0.01)))
				k.box(cream, Vector3(0.05, 1.3, 0.12), Vector3(x, y, back * (z + 0.01)))
				k.box(cream, Vector3(ww, 0.05, 0.12), Vector3(x, y + 0.1, back * (z + 0.01)))
				if floor_i == 1:
					for sx: float in [-1.0, 1.0]:
						k.box(shutter, Vector3(0.36, 1.3, 0.07), Vector3(x + sx * (ww * 0.5 + 0.28), y, back * (z + 0.01)))
	k.box(cream, Vector3(0.5, 0.7, 0.08), Vector3(0, top + 1.2, z))  # the loft hatch
	k.box(glass, Vector3(0.36, 0.56, 0.1), Vector3(0, top + 1.2, z + 0.01))
	var door_c := OLIVE.darkened(0.25) if not bell else Color("5a1f1c")
	k.box(cream, Vector3(1.3, 2.5, 0.1), Vector3(-1.15, 1.65, z))
	k.mesh(cream, Proc._cyl_mesh(0.65, 0.65, 0.1, 12), Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(-1.15, 2.9, z)))
	k.box(_mat(door_c), Vector3(0.96, 2.2, 0.12), Vector3(-1.15, 1.5, z + 0.01))
	k.box(_mat(GOLD), Vector3(0.07, 0.07, 0.07), Vector3(-0.82, 1.5, z + 0.09))
	k.box(_mat(STONE), Vector3(1.6, 0.4, 0.8), Vector3(-1.15, 0.2, d * 0.5 + 0.4))  # the step
	k.box(_mat(front.darkened(0.3)), Vector3(0.6, 1.5, 0.6), Vector3(w * 0.5 - 0.8, top + 2.0, -0.9))  # the chimney
	var tiles := _mat(roof, 0.0, true)  # the roof between the gables
	var ridge := top + (2.9 if bell else 3.3)
	var hw := w * 0.5 - 0.1
	k.quad(tiles, Vector3(-hw, top, face), Vector3(-hw, top, -face), Vector3(0, ridge, -face), Vector3(0, ridge, face))
	k.quad(tiles, Vector3(hw, top, -face), Vector3(hw, top, face), Vector3(0, ridge, face), Vector3(0, ridge, -face))
	hs.add_child(k.commit("Walls"))
	Solid.box(hs, Vector3(w, top + 1.0, d), Vector3(0, top * 0.5, 0))
	Solid.box(hs, Vector3(1.6, 0.4, 0.8), Vector3(-1.15, 0.2, d * 0.5 + 0.4))
	return hs


## The Exchange (sheet 59): a cream classical front with an open arcade of five arches and a pediment, brick
## wings, and behind them a brick clock tower with a slate spire. Through the arches the courtyard is dark:
## nobody goes in yet. The front looks −x, down the street.
static func _exchange(town: bool) -> Node3D:
	var n := Node3D.new()
	n.name = "Exchange"
	n.position = EXCHANGE
	var k := Kit.new()
	var cream := _mat(CREAM)
	var brick := _mat(BRICK.darkened(0.1))
	k.box(_mat(STONE), Vector3(11.0, 0.5, 15.0), Vector3(-0.5, 0.25, 0))  # the plinth
	k.box(brick, Vector3(8.0, 8.0, 14.0), Vector3(1.0, 4.5, 0))  # the hall behind the front
	k.box(_mat(SLATE), Vector3(8.4, 0.5, 14.4), Vector3(1.0, 8.7, 0))
	k.box(brick, Vector3(4.0, 17.0, 4.0), Vector3(3.0, 9.0, 0))  # the tower
	k.box(cream, Vector3(4.4, 0.4, 4.4), Vector3(3.0, 14.6, 0))
	k.box(cream, Vector3(4.4, 0.4, 4.4), Vector3(3.0, 17.6, 0))
	k.mesh(_mat(SLATE), Proc._cyl_mesh(1.4, 2.0, 1.6, 8), Transform3D(Basis(), Vector3(3.0, 18.6, 0)))
	var onion := SphereMesh.new()
	onion.radius = 1.3
	onion.height = 2.6
	onion.radial_segments = 12
	onion.rings = 6
	k.mesh(_mat(SLATE), onion, Transform3D(Basis(), Vector3(3.0, 20.2, 0)))
	k.mesh(_mat(SLATE), Proc._cyl_mesh(0.0, 0.7, 2.6, 8), Transform3D(Basis(), Vector3(3.0, 22.4, 0)))
	k.mesh(_mat(GOLD), Proc._sphere(0.22), Transform3D(Basis(), Vector3(3.0, 23.8, 0)))
	if town:
		for face in 4:  # a clock on each face of the tower
			var turn := Basis(Vector3.UP, face * PI / 2)
			k.mesh(_mat(GOLD), Proc._cyl_mesh(1.25, 1.25, 0.1, 18), Transform3D(turn * Basis(Vector3.RIGHT, PI / 2), Vector3(3.0, 16.1, 0) + turn * Vector3(0, 0, 2.02)))
			k.mesh(_mat(SOOT.lightened(0.08)), Proc._cyl_mesh(1.05, 1.05, 0.12, 18), Transform3D(turn * Basis(Vector3.RIGHT, PI / 2), Vector3(3.0, 16.1, 0) + turn * Vector3(0, 0, 2.04)))
			k.box(_mat(GOLD), Vector3(0.08, 0.8, 0.04), Vector3(3.0, 16.45, 0) + turn * Vector3(0, 0, 2.12), Vector3(0, face * PI / 2, 0))
			k.box(_mat(GOLD), Vector3(0.5, 0.08, 0.04), Vector3(3.0, 16.1, 0) + turn * Vector3(0.22, 0, 2.12), Vector3(0, face * PI / 2, 0))
		# the front: an arcade of five arches, an upper floor of windows, a pediment
		k.box(cream, Vector3(1.2, 3.6, 12.0), Vector3(-5.0, 6.3, 0))
		k.box(cream, Vector3(1.6, 0.4, 12.4), Vector3(-5.0, 8.3, 0))
		k.box(cream, Vector3(1.6, 0.3, 12.4), Vector3(-5.0, 4.5, 0))
		k.box(_mat(Color("2a211b")), Vector3(0.3, 4.0, 11.6), Vector3(-5.2, 2.5, 0))  # the dark gates in the arches: the courtyard is closed
		for i in 6:
			var z := -5.6 + i * 2.24
			k.box(cream, Vector3(1.0, 4.0, 0.56), Vector3(-5.0, 2.5, z))
		for i in 5:
			var z := -4.48 + i * 2.24
			k.box(cream, Vector3(1.0, 0.7, 1.7), Vector3(-5.0, 4.15, z))
			k.mesh(_mat(Color("2a211b")), Proc._cyl_mesh(0.8, 0.8, 1.04, 16), Transform3D(Basis(Vector3.FORWARD, PI / 2), Vector3(-5.0, 3.5, z)))  # the arch's opening
			k.box(_mat(Color("2b3138")), Vector3(0.1, 1.6, 0.9), Vector3(-5.62, 6.4, z))
			k.box(cream, Vector3(0.12, 0.06, 1.1), Vector3(-5.64, 7.25, z))
		var gable := _mat(CREAM, 0.0, true)
		k.tri(gable, Vector3(-5.8, 8.5, 6.2), Vector3(-5.8, 8.5, -6.2), Vector3(-5.8, 10.6, 0))
		k.quad(gable, Vector3(-5.8, 8.5, 6.2), Vector3(-4.2, 8.5, 6.2), Vector3(-4.2, 10.6, 0), Vector3(-5.8, 10.6, 0))
		k.quad(gable, Vector3(-4.2, 8.5, -6.2), Vector3(-5.8, 8.5, -6.2), Vector3(-5.8, 10.6, 0), Vector3(-4.2, 10.6, 0))
		k.mesh(_mat(GOLD), Proc._sphere(0.3), Transform3D(Basis(), Vector3(-5.0, 10.9, 0)))
	n.add_child(k.commit("Exchange", false))  # the arches and the clock stay round from the far end of the street
	Solid.box(n, Vector3(11.0, 0.5, 15.0), Vector3(-0.5, 0.25, 0))
	Solid.box(n, Vector3(8.0, 9.0, 14.0), Vector3(1.0, 4.5, 0))
	Solid.box(n, Vector3(2.5, 9.0, 12.0), Vector3(-4.25, 4.5, 0))  # the arcade is closed: its columns and gates stop a walker
	return n


## Brick underfoot over the whole town, pale stone on the square, a darker band for the street.
static func _paving() -> Node3D:
	var n := Node3D.new()
	n.name = "Paving"
	n.set_meta("flat", true)
	var k := Kit.new()
	k.mesh(_mat(Color("8c6a52")), Proc._cyl_mesh(35.0, 35.0, 0.06, 48), Transform3D(Basis(), Vector3(0, 0.02, 0)))
	k.mesh(_mat(STONE), Proc._cyl_mesh(7.5, 7.5, 0.06, 28), Transform3D(Basis(), FOUNTAIN + Vector3(0, 0.04, 0)))
	k.box(_mat(Color("7a5a46")), Vector3(44.0, 0.06, 4.6), Vector3(-6.0, 0.035, 0))
	n.add_child(k.commit("Slabs"))
	return n


## The canal: water at street level between brick quay walls, closed at both ends, with three crossings. A bridge
## is a level stone deck with sides that rise in an arc, and a lantern at each corner.
static func _canal(isl: Node3D) -> void:
	var water := Node3D.new()
	water.name = "Canal"
	water.set_meta("flat", true)
	water.add_child(Proc.box(Vector3(CANAL_W, 0.08, CANAL_END * 2.0), WATER, Vector3(CANAL_X, 0.05, 0)))
	for b: Array in [[9.5, 0.6], [-11.0, -0.5], [25.0, 0.7]]:  # canal boats, moored against the west wall
		var boat := Proc.mesh_node(Proc.hull_mesh(3.4, 1.3, 0.7), _mat(TIMBER, 0.0, true), Vector3(CANAL_X + float(b[1]), 0.5, b[0]))
		water.add_child(boat)
	isl.add_child(water)
	var x0 := CANAL_X - CANAL_W * 0.5 - 0.2
	var x1 := CANAL_X + CANAL_W * 0.5 + 0.2
	var cuts: Array = []  # the stretches of wall between the crossings, along z
	var from := -CANAL_END + 0.26  # the end walls close the corners
	var sorted := BRIDGES.duplicate()
	sorted.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for b: Array in sorted:
		cuts.append([from, float(b[0]) - float(b[1]) * 0.5 - 0.45])  # a wall stops at the bridge's own side
		from = float(b[0]) + float(b[1]) * 0.5 + 0.45
	cuts.append([from, CANAL_END - 0.26])
	var bed := Node3D.new()  # water is not ground: solid to the height of the walls, so nobody stands on it
	bed.name = "CanalBed"
	isl.add_child(bed)
	var n := 0
	for c: Array in cuts:
		var len := float(c[1]) - float(c[0])
		Solid.box(bed, Vector3(CANAL_W, 1.2, len), Vector3(CANAL_X, 0.6, (float(c[0]) + float(c[1])) * 0.5))
		for x: float in [x0, x1]:
			n += 1
			var wall := Node3D.new()
			wall.name = "QuayWall%d" % n
			wall.position = Vector3(x, 0, (float(c[0]) + float(c[1])) * 0.5)
			wall.add_child(Proc.box(Vector3(0.4, 0.62, len), BRICK.darkened(0.22), Vector3(0, 0.31, 0)))
			wall.add_child(Proc.box(Vector3(0.52, 0.1, len), STONE, Vector3(0, 0.67, 0)))
			Solid.box(wall, Vector3(0.52, 1.2, len), Vector3(0, 0.6, 0))  # taller than it looks, like a rail: nobody climbs into the canal
			isl.add_child(wall)
	for sz: float in [-1.0, 1.0]:  # the ends
		n += 1
		var end_wall := Node3D.new()
		end_wall.name = "QuayWall%d" % n
		end_wall.position = Vector3(CANAL_X, 0, sz * CANAL_END)
		end_wall.add_child(Proc.box(Vector3(CANAL_W + 0.92, 0.62, 0.4), BRICK.darkened(0.22), Vector3(0, 0.31, 0)))
		end_wall.add_child(Proc.box(Vector3(CANAL_W + 0.92, 0.1, 0.52), STONE, Vector3(0, 0.67, 0)))
		Solid.box(end_wall, Vector3(CANAL_W + 0.92, 1.2, 0.52), Vector3(0, 0.6, 0))
		isl.add_child(end_wall)
	n = 0
	for b: Array in BRIDGES:
		n += 1
		var br := _bridge(float(b[1]))
		br.name = "Bridge%d" % n
		br.position = Vector3(CANAL_X, 0, b[0])
		isl.add_child(br)


static func _bridge(width: float) -> Node3D:
	var n := Node3D.new()
	var len := CANAL_W + 0.92
	var deck := Proc.box(Vector3(len, 0.1, width), STONE.darkened(0.08), Vector3(0, 0.07, 0))
	n.add_child(deck)
	for sz: float in [-1.0, 1.0]:
		var z := sz * (width * 0.5 + 0.2)
		for i in 5:  # the side rises to the middle and falls again
			var h := 0.8 + 0.34 * sin(PI * (i + 0.5) / 5.0)
			n.add_child(Proc.box(Vector3(len / 5.0, h, 0.4), STONE, Vector3(-len * 0.5 + (i + 0.5) * len / 5.0, h * 0.5, z)))
		Solid.box(n, Vector3(len, 1.14, 0.4), Vector3(0, 0.57, z))
		for sx: float in [-1.0, 1.0]:
			var at := Vector3(sx * (len * 0.5 + 0.1), 0, z)
			n.add_child(Proc.box(Vector3(0.5, 1.3, 0.5), STONE.darkened(0.1), at + Vector3(0, 0.65, 0)))
			n.add_child(Proc.box(Vector3(0.1, 1.5, 0.1), SOOT, at + Vector3(0, 2.05, 0)))
			n.add_child(Proc.box(Vector3(0.3, 0.4, 0.3), Color("ffd98a"), at + Vector3(0, 2.95, 0)))
			n.add_child(Proc.box(Vector3(0.4, 0.08, 0.4), SOOT, at + Vector3(0, 3.2, 0)))
			Solid.post(n, 0.3, 3.2, at)
	return n


## The stone fountain of sheet 64: two tiers and a finial. A coin (the island's child "Coin") is thrown up over it
## and falls back every COIN_EVERY seconds; `coin_height` says where it is.
static func _fountain() -> Node3D:
	var n := Node3D.new()
	n.name = "CoinFountain"
	n.position = FOUNTAIN
	n.add_child(Proc.cyl(2.3, 2.5, 0.6, 16, STONE, Vector3(0, 0.3, 0)))
	n.add_child(Proc.cyl(2.0, 2.0, 0.06, 16, WATER, Vector3(0, 0.62, 0)))
	n.add_child(Proc.cyl(0.3, 0.45, 1.6, 10, STONE.darkened(0.08), Vector3(0, 0.9, 0)))
	n.add_child(Proc.cyl(1.0, 0.4, 0.25, 12, STONE, Vector3(0, 1.8, 0)))
	n.add_child(Proc.ball(0.2, STONE.darkened(0.1), Vector3(0, 2.05, 0)))
	Solid.post(n, 2.5, 0.7, Vector3.ZERO)
	Solid.post(n, 0.5, 2.0, Vector3.ZERO)
	return n


## Where the fountain's coin is `t` seconds into its cycle: metres above the bowl's top, or −1 when it is under water.
static func coin_height(t: float) -> float:
	var u := fposmod(t, COIN_EVERY)
	if u > 1.2:
		return -1.0
	return 2.4 * 4.0 * (u / 1.2) * (1.0 - u / 1.2)  # up 2.4 m and down again in 1.2 s


## A linden on the quay: a dark trunk and three olive masses, all above every hat.
static func linden(at: Vector3, number: int) -> Node3D:
	var t := Node3D.new()
	t.name = "Linden%d" % number
	t.position = at
	t.add_child(Proc.cyl(0.14, 0.2, 3.0, 7, Color("4a3a2a"), Vector3(0, 1.5, 0)))
	var lean := 0.3 * sin(number * 2.4)
	t.add_child(Proc.ball(1.5, OLIVE, Vector3(lean, 4.3, 0)))
	t.add_child(Proc.ball(1.1, OLIVE.lightened(0.1), Vector3(lean + 0.8, 3.7, 0.5)))
	t.add_child(Proc.ball(1.0, OLIVE.darkened(0.12), Vector3(lean - 0.7, 3.8, -0.6)))
	Solid.post(t, 0.24, 3.0, Vector3.ZERO)  # the crown is above every hat: only the trunk stops a walker
	return t


## Things of sheet 64: the market stall with cheeses and loaves, benches by the fountain, barrels and crates at
## the head of the pier.
static func _props(isl: Node3D) -> void:
	var st := Node3D.new()
	st.name = "MarketStall"
	st.position = Vector3(7.2, 0, 9.6)
	st.add_child(Proc.box(Vector3(2.4, 0.9, 1.1), TIMBER, Vector3(0, 0.45, 0)))
	for i in 3:
		st.add_child(Proc.cyl(0.26, 0.26, 0.2, 10, Color("d9b040"), Vector3(-0.75 + i * 0.5, 1.0, -0.15)))
	for i in 2:
		st.add_child(Proc.box(Vector3(0.5, 0.2, 0.26), Color("b9824a"), Vector3(-0.3 + i * 0.7, 1.0, 0.3)))
	for x: float in [-1.2, 1.2]:
		st.add_child(Proc.box(Vector3(0.1, 2.5, 0.1), TIMBER.darkened(0.2), Vector3(x, 1.25, 0.6)))
		Solid.post(st, 0.1, 2.5, Vector3(x, 0, 0.6))
	var awning := Kit.new()
	awning.quad(_mat(Color("cbbf9c"), 0.0, true), Vector3(-1.4, 2.5, 0.7), Vector3(1.4, 2.5, 0.7), Vector3(1.4, 2.0, -0.9), Vector3(-1.4, 2.0, -0.9))
	st.add_child(awning.commit("Awning"))
	Solid.box(st, Vector3(2.4, 0.9, 1.1), Vector3(0, 0.45, 0))
	isl.add_child(st)
	var n := 0
	for sz: float in [1.0, -1.0]:
		n += 1
		var bench := Node3D.new()
		bench.name = "Bench%d" % n
		bench.position = FOUNTAIN + Vector3(0, 0, sz * 4.6)
		bench.add_child(Proc.box(Vector3(2.0, 0.1, 0.5), TIMBER, Vector3(0, 0.5, 0)))
		bench.add_child(Proc.box(Vector3(2.0, 0.6, 0.08), TIMBER, Vector3(0, 0.84, sz * 0.24)))
		for x: float in [-0.85, 0.85]:
			bench.add_child(Proc.box(Vector3(0.12, 0.5, 0.5), TIMBER.darkened(0.2), Vector3(x, 0.25, 0)))
		Solid.box(bench, Vector3(2.0, 1.1, 0.56), Vector3(0, 0.55, 0))
		isl.add_child(bench)
	isl.add_child(Props.barrel(Vector3(-24.6, 0, 3.6)))
	isl.add_child(Props.barrel(Vector3(-23.6, 0, 3.9)))
	isl.add_child(Props.crate(Vector3(-24.2, 0, -3.8), 0.3))
	isl.add_child(Props.crate(Vector3(-22.8, 0, -3.6), -0.2, 0.8))


## A sky ship at the pier: a timber hull, a mast, two cream sails. Decoration beyond the rail: nobody reaches it.
static func sky_ship() -> Node3D:
	var n := Node3D.new()
	n.name = "SkyShip"
	n.set_meta("flat", true)
	n.add_child(Proc.mesh_node(Proc.hull_mesh(5.0, 1.7, 1.0), _mat(TIMBER, 0.0, true)))
	n.add_child(Proc.box(Vector3(0.12, 5.0, 0.12), TIMBER.darkened(0.25), Vector3(0, 2.8, 0)))
	var k := Kit.new()
	var sail := _mat(Color("d9cfae"), 0.0, true)
	k.quad(sail, Vector3(-1.3, 1.6, 0.1), Vector3(1.3, 1.6, 0.1), Vector3(1.1, 3.4, 0.25), Vector3(-1.1, 3.4, 0.25))
	k.quad(sail, Vector3(-0.9, 3.6, 0.1), Vector3(0.9, 3.6, 0.1), Vector3(0.7, 4.9, 0.2), Vector3(-0.7, 4.9, 0.2))
	k.tri(_mat(BRICK, 0.0, true), Vector3(0, 5.3, 0), Vector3(0, 5.0, 0), Vector3(0, 5.15, 0.8))
	n.add_child(k.commit("Sails"))
	return n

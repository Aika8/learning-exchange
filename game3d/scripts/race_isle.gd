## Pattern: Builder — the race island (working name; `docs/design/concepts/52…58`): the Grand Prix of the Winds, our
## own sky race. A banked track in the air round the rock, on brackets, with brass rails and red signal gates; the
## stepped timing tower in the middle; pit boxes along the pit lane with a skiff on a stand; a grandstand under a
## sunburst canopy; ceremonial gates at the pier; four sky skiffs as decoration. Navy, midnight teal, ivory, brass,
## copper and one signal red, from the sheets' palette. Nothing is raced or repaired here yet.
## See docs/adr/0034-game3d-race-island-in-art-deco.md
class_name RaceIsle
extends RefCounted

const ID := "race"
const AT := Vector3(-390, 8, -120)  ## the island's centre in the world
const RADIUS := 40.0
const REACH := 50.0  ## how far the track reaches from the centre: the ship keeps clear of it
const SEED := 83
const DECK_Y := 0.12
const PIER_FROM := AT + Vector3(-68.0, DECK_Y, -2.4)
const PIER_TO := AT + Vector3(-27.0, DECK_Y, 2.4)  ## its island end lies well inside the walkable cap
const DOCK := AT + Vector3(-63.0, 0, 8.5)
const SPAWN := AT + Vector3(-56.0, 0.5, 0)
const TOWER := Vector3(6.0, 0, 0)  ## the timing tower, in the island's own space; the avenue runs along x to it
const PITS := Vector3(-2.0, 0, 22.0)  ## the middle of the row of pit boxes; their shutters look −z, at the pit lane
const STAND := Vector3(2.0, 0, -24.0)  ## the grandstand; it looks +z, at the tower
const TRACK_R := 46.0  ## the middle line of the track
const TRACK_W := 5.0
const TRACK_Y := 6.6  ## above every hat and under the ship's keel
const BRACKETS := 12
const NAVY := Color("1a2f4c")
const TEAL := Color("103c42")
const IVORY := Color("f4efe2")
const BRASS := Color("e0aa3e")
const COPPER := Color("b25329")
const RED := Color("c83e3c")
const STEEL := Color("5c626e")
const TYRE := Color("1c1f26")
## The four skiffs of sheet 55: [hull above, hull below, the stripe, sail].
const SKIFFS := {"star": [Color("1f2e4d"), Color("fdfbf5"), Color("c8102e"), Color("fdfbf5")],
	"storm": [Color("004f5b"), Color("004f5b"), Color("b05c31"), Color("004f5b")],
	"phoenix": [Color("c8102e"), Color("b05c31"), Color("d4a23e"), Color("e0aa3e")],
	"admiral": [Color("d4a23e"), Color("1f2e4d"), Color("fdfbf5"), Color("1f2e4d")]}

static var _mats: Dictionary = {}


static func walk_areas() -> Array[Dictionary]:
	return [{"name": "race", "kind": "disc", "centre": AT, "radius": RADIUS, "seed": SEED},
		{"name": "race-pier", "kind": "rect", "from": PIER_FROM, "to": PIER_TO}]


## Where the marshal stands by the tower door and where the captain talks to him: [keeper, spot], world space.
static func tower_door() -> Array[Vector3]:
	return [AT + TOWER + Vector3(-6.2, 0, 1.8), AT + TOWER + Vector3(-7.6, 0, 0.9)]


## Where the chief mechanic stands by the skiff in the pit lane, and where the captain talks to him.
static func pit_spot() -> Array[Vector3]:
	return [AT + PITS + Vector3(-5.0, 0, -6.6), AT + PITS + Vector3(-5.6, 0, -8.2)]


static func _mat(c: Color, glow: float = 0.0, both_sides: bool = false) -> Material:
	var key := "%s/%s/%s" % [c.to_html(), glow, both_sides]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.7
		if both_sides:
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		if glow > 0.0:
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = glow
		_mats[key] = m
	return _mats[key]


## A point of the island's space given the way the track is: radius, height, angle, and a step along the tangent.
static func ring(r: float, y: float, a: float, along: float = 0.0) -> Vector3:
	return Vector3(cos(a) * r - sin(a) * along, y, sin(a) * r + cos(a) * along)


## Height of the track's surface at radius `r`: it is banked, the outer edge higher.
static func bank(r: float) -> float:
	return TRACK_Y + (r - TRACK_R) * 0.22


## The whole island. `town` = false gives the rock, the track and a plain tower: what is seen from far away.
static func build(town: bool) -> Node3D:
	var isl := Node3D.new()
	isl.name = "RaceIsle"
	isl.add_child(Archipelago.island(RADIUS, 44.0, SEED, 0.0, true))
	isl.add_child(_track(town))
	isl.add_child(_tower(town))
	if not town:
		return isl
	isl.add_child(_paving())
	for i in BRACKETS:
		var foot := _bracket_foot(TAU * (i + 0.5) / BRACKETS)
		foot.name = "BracketFoot%d" % (i + 1)
		isl.add_child(foot)
	_pit_lane(isl)
	isl.add_child(_grandstand())
	for side: float in [1.0, -1.0]:
		isl.add_child(_gate_pylon(Vector3(-25.0, 0, 5.2 * side), side))
		for x: float in [-17.0, -9.0]:
			isl.add_child(_lamp(Vector3(x, 0, 4.6 * side)))
	_props(isl)
	var moored := skiff("admiral")
	moored.position = Vector3(-50.0, 1.0, -7.6)
	moored.rotation.y = PI / 2
	moored.set_meta("flat", true)
	isl.add_child(moored)
	isl.add_child(Archipelago._deck("Pier", PIER_FROM - AT, PIER_TO - AT, [true, false, true, true], PIER_TO - AT + Vector3(0, 0, -2)))
	var f := Node3D.new()
	f.name = "Fences"
	isl.add_child(f)
	Solid.fence_areas(f, walk_areas(), AT)
	return isl


## The track: a banked ivory ribbon with brass bands and a brass middle line, navy below, brass rails along both
## edges, the arms that carry it, red signal gates across it and two skiffs on it. All of it is above every head
## and beyond the island's fence: scenery nobody reaches.
static func _track(town: bool) -> Node3D:
	var n := Node3D.new()
	n.name = "Track"
	n.set_meta("flat", true)
	var k := Kit.new()
	var ivory := _mat(IVORY, 0.0, true)
	var brass := _mat(BRASS, 0.0, true)
	var navy := _mat(NAVY, 0.0, true)
	var ri := TRACK_R - TRACK_W * 0.5
	var ro := TRACK_R + TRACK_W * 0.5
	var parts := 72 if town else 36
	for i in parts:
		var a := TAU * i / parts
		var b := TAU * (i + 1) / parts
		k.quad(ivory, ring(ri, bank(ri), a), ring(ro, bank(ro), a), ring(ro, bank(ro), b), ring(ri, bank(ri), b))
		for band: Array in [[ri, ri + 0.45], [ro - 0.45, ro], [TRACK_R - 0.2, TRACK_R + 0.2]]:
			var r0: float = band[0]
			var r1: float = band[1]
			k.quad(brass, ring(r0, bank(r0) + 0.03, a), ring(r1, bank(r1) + 0.03, a), ring(r1, bank(r1) + 0.03, b), ring(r0, bank(r0) + 0.03, b))
		k.quad(navy, ring(ri, bank(ri) - 0.7, a), ring(ro, bank(ro) - 0.7, a), ring(ro, bank(ro) - 0.7, b), ring(ri, bank(ri) - 0.7, b))
		for r: float in [ri, ro]:
			k.quad(navy, ring(r, bank(r), a), ring(r, bank(r), b), ring(r, bank(r) - 0.7, b), ring(r, bank(r) - 0.7, a))
			if town:  # the rail
				k.quad(brass, ring(r, bank(r) + 0.62, a), ring(r, bank(r) + 0.62, b), ring(r, bank(r) + 0.74, b), ring(r, bank(r) + 0.74, a))
				if i % 3 == 0:
					k.box(_mat(BRASS), Vector3(0.1, 0.7, 0.1), ring(r, bank(r) + 0.35, a))  # a surface is built either from quads or from boxes, never both
	for i in BRACKETS:  # the arms: tapered navy beams from the feet on the rim up to the track, a brass edge on top
		var a := TAU * (i + 0.5) / BRACKETS
		for side: float in [-0.28, 0.28]:
			k.quad(navy, ring(36.0, 3.3, a, side), ring(ro - 0.6, bank(ro) - 0.7, a, side), ring(ro - 0.6, bank(ro) - 1.5, a, side), ring(37.0, 1.9, a, side))
		k.quad(brass, ring(36.0, 3.32, a, -0.28), ring(ro - 0.6, bank(ro) - 0.68, a, -0.28), ring(ro - 0.6, bank(ro) - 0.68, a, 0.28), ring(36.0, 3.32, a, 0.28))
		k.quad(navy, ring(37.0, 1.9, a, -0.28), ring(ro - 0.6, bank(ro) - 1.5, a, -0.28), ring(ro - 0.6, bank(ro) - 1.5, a, 0.28), ring(37.0, 1.9, a, 0.28))
	n.add_child(k.commit("Ribbon", false))  # the bands and rails are thin: no simplifying
	if not town:
		return n
	var g := Kit.new()
	var red := _mat(RED, 0.3)
	for a: float in [0.55, 2.3, 4.05, 5.5]:  # the signal gates
		for r: float in [ri + 0.1, ro - 0.1]:
			g.box(red, Vector3(0.16, 2.6, 0.16), ring(r, bank(r) + 1.3, a))
		g.box(red, Vector3(0.16, 0.16, TRACK_W - 0.1), ring(TRACK_R, bank(TRACK_R) + 2.6, a), Vector3(0, -a + PI / 2, 0))
	n.add_child(g.commit("Gates"))
	for s: Array in [["star", 1.15], ["storm", 3.6]]:
		var boat := skiff(str(s[0]))
		var a: float = s[1]
		boat.position = ring(TRACK_R, bank(TRACK_R) + 1.0, a)
		boat.rotation.y = -a
		n.add_child(boat)
	return n


## The foot of a bracket on the island's rim: a stepped navy pylon with an ivory fin and a brass band.
static func _bracket_foot(a: float) -> Node3D:
	var n := Node3D.new()
	n.name = "BracketFoot"
	n.position = ring(36.5, 0, a)
	n.rotation.y = -a
	n.add_child(Proc.box(Vector3(1.3, 3.4, 0.9), NAVY, Vector3(0, 1.7, 0)))
	n.add_child(Proc.box(Vector3(1.5, 0.3, 1.1), BRASS, Vector3(0, 0.15, 0)))
	n.add_child(Proc.box(Vector3(0.5, 2.6, 1.0), IVORY, Vector3(-0.3, 1.5, 0)))
	Solid.box(n, Vector3(1.5, 3.4, 1.1), Vector3(0, 1.7, 0))
	return n


## The timing tower (sheet 53, "главная вышка"): three navy steps, a teal shaft with ivory fins and brass lines, a
## clock on each face, a copper crown, a brass mast with a red light. The door looks −x, down the avenue.
static func _tower(town: bool) -> Node3D:
	var n := Node3D.new()
	n.name = "TimingTower"
	n.position = TOWER
	var k := Kit.new()
	var navy := _mat(NAVY)
	var teal := _mat(TEAL)
	var ivory := _mat(IVORY)
	var brass := _mat(BRASS)
	var copper := _mat(COPPER)
	var steps := [[10.0, 2.6], [8.0, 2.4], [6.0, 2.4]]
	var y := 0.0
	for s: Array in steps:
		k.box(navy, Vector3(s[0], s[1], s[0]), Vector3(0, y + float(s[1]) * 0.5, 0))
		if town:
			k.box(copper, Vector3(float(s[0]) + 0.16, 0.22, float(s[0]) + 0.16), Vector3(0, y + float(s[1]) - 0.11, 0))
		y += float(s[1])
	k.box(teal, Vector3(4.2, 13.0, 4.2), Vector3(0, y + 6.5, 0))
	k.box(copper, Vector3(4.6, 0.5, 4.6), Vector3(0, y + 13.2, 0))
	k.box(navy, Vector3(3.2, 1.6, 3.2), Vector3(0, y + 14.2, 0))
	k.box(ivory, Vector3(2.0, 1.4, 2.0), Vector3(0, y + 15.7, 0))
	k.box(brass, Vector3(0.14, 5.0, 0.14), Vector3(0, y + 18.9, 0))
	k.mesh(_mat(RED, 1.2), Proc._sphere(0.28), Transform3D(Basis(), Vector3(0, y + 21.5, 0)))
	if town:
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:  # the stepped ivory fins at the corners
				k.box(ivory, Vector3(1.0, 9.0, 1.0), Vector3(sx * 2.3, y + 4.5, sz * 2.3))
				k.box(ivory, Vector3(0.7, 2.4, 0.7), Vector3(sx * 2.3, y + 10.2, sz * 2.3))
		for face in 4:
			var turn := Basis(Vector3.UP, face * PI / 2)
			for x: float in [-0.5, 0.0, 0.5]:  # brass lines up the shaft
				k.box(brass, Vector3(0.08, 7.0, 0.05), turn * Vector3(x, y + 4.0, 2.12), Vector3(0, face * PI / 2, 0))
			k.mesh(brass, Proc._cyl_mesh(1.25, 1.25, 0.1, 20), Transform3D(turn * Basis(Vector3.RIGHT, PI / 2), turn * Vector3(0, y + 10.4, 2.14)))
			k.mesh(ivory, Proc._cyl_mesh(1.05, 1.05, 0.12, 20), Transform3D(turn * Basis(Vector3.RIGHT, PI / 2), turn * Vector3(0, y + 10.4, 2.16)))
			k.box(navy, Vector3(0.07, 0.8, 0.04), turn * Vector3(0, y + 10.75, 2.24), Vector3(0, face * PI / 2, 0))
			k.box(navy, Vector3(0.5, 0.07, 0.04), turn * Vector3(0.22, y + 10.4, 2.24), Vector3(0, face * PI / 2, 0))
			k.mesh(_mat(RED, 1.0), Proc._sphere(0.16), Transform3D(Basis(), turn * Vector3(1.6, y + 12.4, 2.14)))
		k.box(_mat(COPPER.darkened(0.25)), Vector3(0.2, 2.2, 1.6), Vector3(-5.02, 1.1, 0))  # the door
		k.box(brass, Vector3(0.22, 0.3, 2.0), Vector3(-5.02, 2.35, 0))
		k.box(ivory, Vector3(1.4, 0.24, 2.6), Vector3(-5.6, 0.12, 0))  # the step
	n.add_child(k.commit("Tower"))
	y = 0.0
	for s: Array in steps:
		Solid.box(n, Vector3(s[0], s[1], s[0]), Vector3(0, y + float(s[1]) * 0.5, 0))
		y += float(s[1])
	Solid.box(n, Vector3(4.2, 13.0, 4.2), Vector3(0, y + 6.5, 0))
	if town:
		Solid.box(n, Vector3(1.4, 0.24, 2.6), Vector3(-5.6, 0.12, 0))
	return n


## Dark teal paving under the whole town, an ivory avenue from the pier, and a sunburst round the tower: wide
## wedges of two close teals, laid on the ground.
static func _paving() -> Node3D:
	var n := Node3D.new()
	n.name = "Paving"
	n.set_meta("flat", true)
	var k := Kit.new()
	k.mesh(_mat(TEAL), Proc._cyl_mesh(35.0, 35.0, 0.06, 48), Transform3D(Basis(), Vector3(0, 0.02, 0)))
	var wedge := _mat(TEAL.lightened(0.09), 0.0, true)
	for i in 12:
		var a := TAU * (i * 2) / 24.0
		var b := TAU * (i * 2 + 1) / 24.0
		k.tri(wedge, TOWER + Vector3(0, 0.06, 0), TOWER + ring(15.0, 0.06, a), TOWER + ring(15.0, 0.06, b))
	k.box(_mat(IVORY.darkened(0.08)), Vector3(22.0, 0.06, 5.0), Vector3(-20.0, 0.05, 0))
	for z: float in [-2.7, 2.7]:
		k.box(_mat(BRASS), Vector3(22.0, 0.07, 0.3), Vector3(-20.0, 0.055, z))
	k.box(_mat(STEEL.darkened(0.2)), Vector3(34.0, 0.06, 6.0), PITS + Vector3(0, 0.05, -7.0))  # the pit lane
	n.add_child(k.commit("Slabs"))
	return n


## A pit box (sheet 53): a navy box with rounded shoulders, copper bands, a brass cornice and a ribbed steel
## shutter. The shutter looks −z.
static func pit_box(number: int) -> Node3D:
	var n := Node3D.new()
	n.name = "PitBox"
	var w := 7.0
	var h := 4.2
	var d := 6.0
	var k := Kit.new()
	var navy := _mat(NAVY)
	k.box(navy, Vector3(w - 1.2, h, d), Vector3(0, h * 0.5, 0))
	for sx: float in [-1.0, 1.0]:  # the rounded shoulders
		for sz: float in [-1.0, 1.0]:
			k.mesh(navy, Proc._cyl_mesh(0.6, 0.6, h, 10), Transform3D(Basis(), Vector3(sx * (w * 0.5 - 0.6), h * 0.5, sz * (d * 0.5 - 0.6))))
		k.box(navy, Vector3(0.6, h, d - 1.2), Vector3(sx * (w * 0.5 - 0.3), h * 0.5, 0))
	for y: float in [0.5, 0.85, 3.3]:
		k.box(_mat(COPPER), Vector3(w + 0.1, 0.16, d + 0.1), Vector3(0, y, 0))
	k.box(_mat(BRASS), Vector3(w + 0.2, 0.3, d + 0.2), Vector3(0, h - 0.05, 0))
	k.box(_mat(STEEL), Vector3(3.6, 2.8, 0.12), Vector3(0, 1.4, -d * 0.5 - 0.02))
	for i in 6:
		k.box(_mat(STEEL.lightened(0.25)), Vector3(3.6, 0.08, 0.14), Vector3(0, 0.3 + i * 0.45, -d * 0.5 - 0.03))
	k.box(_mat(COPPER), Vector3(4.0, 0.2, 0.2), Vector3(0, 2.9, -d * 0.5 - 0.02))
	k.mesh(_mat(IVORY), Proc._cyl_mesh(0.42, 0.42, 0.08, 14), Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 3.65, -d * 0.5 - 0.04)))  # the box's number plate
	for i in number:
		k.box(_mat(NAVY), Vector3(0.07, 0.4, 0.05), Vector3((i - (number - 1) * 0.5) * 0.16, 3.65, -d * 0.5 - 0.09))
	n.add_child(k.commit("Box"))
	Solid.box(n, Vector3(w, h, d), Vector3(0, h * 0.5, 0))
	return n


## The pit lane: four boxes in a row and, before the second, the skiff «Феникс» on its lift with the fuel cart.
## Each is a thing of its own on the island.
static func _pit_lane(isl: Node3D) -> void:
	for i in 4:
		var box := pit_box(i + 1)
		box.name = "PitBox%d" % (i + 1)
		box.position = PITS + Vector3(-11.4 + i * 7.6, 0, 0)
		isl.add_child(box)
	var bay := Node3D.new()
	bay.name = "PitSkiff"
	bay.position = PITS + Vector3(-3.8, 0, -7.0)
	var boat := skiff("phoenix")
	boat.position = Vector3(0, 3.1, 0)  # on the lift, above every hat: the crew works under it
	boat.rotation.y = PI / 2
	bay.add_child(boat)
	bay.add_child(Proc.box(Vector3(4.4, 0.5, 1.2), NAVY, Vector3(0, 0.25, 0)))  # the lift's plinth
	bay.add_child(Proc.box(Vector3(4.6, 0.12, 1.3), BRASS, Vector3(0, 0.56, 0)))
	Solid.box(bay, Vector3(4.6, 0.62, 1.3), Vector3(0, 0.31, 0))
	for x: float in [-1.5, 1.5]:
		bay.add_child(Proc.cyl(0.14, 0.18, 2.1, 8, BRASS, Vector3(x, 1.65, 0)))
		Solid.post(bay, 0.18, 2.1, Vector3(x, 0.6, 0))
	isl.add_child(bay)
	var cart := Node3D.new()  # the copper fuel tank on its cart (sheet 54)
	cart.name = "FuelCart"
	cart.position = PITS + Vector3(1.9, 0, -6.2)
	var tank := Proc.cyl(0.62, 0.62, 1.7, 14, COPPER, Vector3(0, 1.0, 0))
	tank.rotation.z = PI / 2
	cart.add_child(tank)
	for x: float in [-0.5, 0.5]:
		var hoop := Proc.cyl(0.65, 0.65, 0.1, 14, BRASS, Vector3(x, 1.0, 0))
		hoop.rotation.z = PI / 2
		cart.add_child(hoop)
	cart.add_child(Proc.cyl(0.16, 0.2, 0.2, 8, BRASS, Vector3(0, 1.7, 0)))
	cart.add_child(Proc.box(Vector3(1.9, 0.5, 1.0), NAVY, Vector3(0, 0.25, 0)))
	Solid.box(cart, Vector3(1.9, 1.7, 1.24), Vector3(0, 0.85, 0))
	isl.add_child(cart)


## The grandstand (sheet 53): a navy plinth with copper bands, five ivory rows, a canopy on a curved ivory back
## with a brass sunburst on top, and flags. It looks +z.
static func _grandstand() -> Node3D:
	var n := Node3D.new()
	n.name = "Grandstand"
	n.position = STAND
	var w := 22.0
	var k := Kit.new()
	k.box(_mat(NAVY), Vector3(w, 1.2, 8.0), Vector3(0, 0.6, 0))
	k.box(_mat(COPPER), Vector3(w + 0.1, 0.16, 8.1), Vector3(0, 1.0, 0))
	for i in 5:
		k.box(_mat(IVORY.darkened(0.04 * (i % 2))), Vector3(w - 1.0, 0.6, 1.3), Vector3(0, 1.5 + i * 0.6, 3.0 - i * 1.3))
	k.box(_mat(IVORY), Vector3(w, 7.6, 0.8), Vector3(0, 3.8, -3.6))  # the back
	var roof := _mat(NAVY, 0.0, true)
	var front := Vector3(0, 6.6, 4.4)
	var back := Vector3(0, 7.9, -4.0)
	k.quad(roof, back + Vector3(-w * 0.5, 0, 0), back + Vector3(w * 0.5, 0, 0), front + Vector3(w * 0.5, 0, 0), front + Vector3(-w * 0.5, 0, 0))
	k.quad(_mat(IVORY, 0.0, true), front + Vector3(-w * 0.5, 0, 0), front + Vector3(w * 0.5, 0, 0), front + Vector3(w * 0.5, -0.35, 0), front + Vector3(-w * 0.5, -0.35, 0))
	var burst := _mat(BRASS, 0.0, true)
	for i in 7:  # the sunburst on the canopy: rays from the middle of the back edge
		var x0 := -w * 0.5 + w * (i * 2 + 0.5) / 14.0
		var x1 := -w * 0.5 + w * (i * 2 + 1.5) / 14.0
		k.tri(burst, back + Vector3(0, 0.03, 0), front + Vector3(x0, 0.03, 0), front + Vector3(x1, 0.03, 0))
		k.tri(burst, back + Vector3(0, -0.03, 0), front + Vector3(x0, -0.03, 0), front + Vector3(x1, -0.03, 0))
	for x: float in [-w * 0.5 + 0.3, w * 0.5 - 0.3]:
		k.box(_mat(IVORY), Vector3(0.5, 6.6, 0.5), Vector3(x, 3.3, 4.0))
	for i in 5:  # flags
		var x := -w * 0.5 + 1.0 + i * (w - 2.0) / 4.0
		k.box(_mat(BRASS), Vector3(0.08, 2.6, 0.08), Vector3(x, 9.2, -3.8))
		var cloth := _mat(RED if i % 2 == 0 else BRASS, 0.0, true)
		k.tri(cloth, Vector3(x, 10.4, -3.8), Vector3(x, 9.8, -3.8), Vector3(x + 1.1, 10.1, -3.8))
	n.add_child(k.commit("Stand"))
	Solid.box(n, Vector3(w, 1.2, 8.0), Vector3(0, 0.6, 0))
	for i in 5:
		Solid.box(n, Vector3(w - 1.0, 0.6, 1.3), Vector3(0, 1.5 + i * 0.6, 3.0 - i * 1.3))
	Solid.box(n, Vector3(w, 7.6, 0.8), Vector3(0, 3.8, -3.6))
	for x: float in [-w * 0.5 + 0.3, w * 0.5 - 0.3]:
		Solid.box(n, Vector3(0.5, 6.6, 0.5), Vector3(x, 3.3, 4.0))
	return n


## One side of the ceremonial gates (sheet 53): three ivory slabs stepping down from the avenue, a brass foot, a
## mast with a pennant.
static func _gate_pylon(at: Vector3, side: float) -> Node3D:
	var n := Node3D.new()
	n.name = "GatePylon"
	n.position = at
	for i in 3:
		n.add_child(Proc.box(Vector3(1.4, 6.4 - i * 1.5, 0.9), IVORY.darkened(0.03 * i), Vector3(0, (6.4 - i * 1.5) * 0.5, side * i * 0.95)))
	n.add_child(Proc.box(Vector3(1.6, 0.5, 3.1), BRASS, Vector3(0, 0.25, side * 0.95)))
	n.add_child(Proc.box(Vector3(0.1, 3.4, 0.1), BRASS, Vector3(0, 8.1, 0)))
	var k := Kit.new()
	k.tri(_mat(RED, 0.0, true), Vector3(0, 9.7, 0), Vector3(0, 9.1, 0), Vector3(-1.2, 9.4, 0))
	n.add_child(k.commit("Pennant"))
	Solid.box(n, Vector3(1.6, 6.4, 3.1), Vector3(0, 3.2, side * 0.95))
	return n


static func _lamp(at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = "DecoLamp"
	n.position = at
	n.add_child(Proc.box(Vector3(0.5, 0.4, 0.5), BRASS, Vector3(0, 0.2, 0)))
	n.add_child(Proc.box(Vector3(0.22, 3.0, 0.22), NAVY, Vector3(0, 1.9, 0)))
	n.add_child(Proc.box(Vector3(0.6, 0.12, 0.6), BRASS, Vector3(0, 3.4, 0)))
	n.add_child(Proc.ball(0.3, Color("ffe6b0"), Vector3(0, 3.75, 0), 1.2))
	Solid.post(n, 0.3, 3.4, Vector3.ZERO)
	return n


## The props of sheet 57 in the pit lane and by the tower: fuel barrels, stacks of wheels, spare air screws on a
## stand, a tool trolley, a loudspeaker on a tripod.
static func _props(isl: Node3D) -> void:
	for at: Vector3 in [PITS + Vector3(-14.6, 0, -4.2), PITS + Vector3(-13.5, 0, -4.4), PITS + Vector3(12.8, 0, -4.3)]:
		var b := Node3D.new()
		b.name = "FuelBarrel"
		b.position = at
		b.add_child(Proc.cyl(0.42, 0.42, 1.1, 12, COPPER, Vector3(0, 0.55, 0)))
		for y: float in [0.3, 0.8]:
			b.add_child(Proc.cyl(0.44, 0.44, 0.1, 12, NAVY, Vector3(0, y, 0)))
		Solid.post(b, 0.44, 1.1, Vector3.ZERO)
		isl.add_child(b)
	for at: Vector3 in [PITS + Vector3(6.4, 0, -4.4), PITS + Vector3(14.2, 0, -4.6)]:
		var w := Node3D.new()
		w.name = "WheelStack"
		w.position = at
		for i in 3:
			w.add_child(Proc.cyl(0.5, 0.5, 0.3, 14, TYRE, Vector3(0, 0.16 + i * 0.32, 0)))
		w.add_child(Proc.cyl(0.24, 0.24, 0.04, 12, BRASS, Vector3(0, 0.96, 0)))
		Solid.post(w, 0.5, 0.96, Vector3.ZERO)
		isl.add_child(w)
	var screws := Node3D.new()  # spare air screws on their stand
	screws.name = "AirScrews"
	screws.position = PITS + Vector3(10.2, 0, -4.4)
	screws.add_child(Proc.box(Vector3(1.0, 0.16, 0.6), IVORY, Vector3(0, 0.08, 0)))
	screws.add_child(Proc.box(Vector3(0.12, 2.9, 0.12), BRASS, Vector3(0, 1.5, 0)))
	for i in 2:
		var blade := Proc.box(Vector3(1.5, 0.2, 0.06), COPPER if i == 0 else BRASS, Vector3(0, 2.2 + i * 0.45, -0.1))
		blade.rotation.z = 0.35 - i * 0.7
		screws.add_child(blade)
	Solid.box(screws, Vector3(1.0, 0.16, 0.6), Vector3(0, 0.08, 0))
	Solid.post(screws, 0.12, 2.9, Vector3.ZERO)  # the blades are above every hat
	isl.add_child(screws)
	var trolley := Node3D.new()
	trolley.name = "ToolTrolley"
	trolley.position = PITS + Vector3(-9.6, 0, -4.4)
	trolley.add_child(Proc.box(Vector3(1.6, 0.3, 0.7), NAVY, Vector3(0, 0.35, 0)))
	trolley.add_child(Proc.box(Vector3(1.7, 0.08, 0.8), COPPER, Vector3(0, 0.54, 0)))
	trolley.add_child(Proc.box(Vector3(1.5, 0.9, 0.1), NAVY, Vector3(0, 1.0, 0.3)))
	for i in 5:
		trolley.add_child(Proc.box(Vector3(0.08, 0.6, 0.05), STEEL.lightened(0.3) if i % 2 == 0 else BRASS, Vector3(-0.5 + i * 0.25, 0.98, 0.22)))
	Solid.box(trolley, Vector3(1.7, 1.45, 0.8), Vector3(0, 0.72, 0))
	isl.add_child(trolley)
	var horn := Node3D.new()  # the loudspeaker by the tower
	horn.name = "Loudspeaker"
	horn.position = TOWER + Vector3(-6.4, 0, -4.2)
	horn.add_child(Proc.cyl(0.04, 0.3, 1.5, 6, NAVY, Vector3(0, 0.75, 0)))
	var cone := Proc.cyl(0.55, 0.08, 1.1, 14, NAVY, Vector3(-0.2, 1.75, 0))
	cone.rotation.z = -PI / 2 + 0.25
	horn.add_child(cone)
	horn.add_child(Proc.ball(0.12, BRASS, Vector3(0.3, 1.62, 0)))
	Solid.post(horn, 0.32, 1.6, Vector3.ZERO)
	isl.add_child(horn)


## A sky skiff of sheet 55: a streamlined two-tone hull with a stripe along it, a glazed cockpit, tail fins, two
## air screws at the stern and a small triangular sail. It lies along z, bow to −z. Decoration: it does not move.
static func skiff(kind: String) -> Node3D:
	var c: Array = SKIFFS[kind]
	var n := Node3D.new()
	n.name = "Skiff_" + kind
	n.set_meta("hung", true)
	var k := Kit.new()
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 14
	ball.rings = 8
	k.mesh(_mat(c[0]), ball, Transform3D(Basis().scaled(Vector3(1.3, 1.0, 6.4)), Vector3.ZERO))
	k.mesh(_mat(c[1]), ball, Transform3D(Basis().scaled(Vector3(1.24, 0.8, 6.2)), Vector3(0, -0.14, 0)))
	k.mesh(_mat(c[2]), ball, Transform3D(Basis().scaled(Vector3(1.36, 0.14, 6.0)), Vector3(0, 0.02, 0)))
	k.mesh(_mat(Color("bfd3dc")), ball, Transform3D(Basis().scaled(Vector3(0.6, 0.5, 1.3)), Vector3(0, 0.42, -0.5)))
	var fin := _mat(c[2], 0.0, true)
	k.tri(fin, Vector3(0, 0.3, 1.6), Vector3(0, 1.2, 3.1), Vector3(0, 0.2, 3.0))
	for sx: float in [-1.0, 1.0]:
		k.tri(fin, Vector3(sx * 0.4, 0, 1.8), Vector3(sx * 1.3, 0, 3.1), Vector3(sx * 0.3, 0, 3.0))
		k.box(_mat(BRASS), Vector3(0.9, 0.08, 0.05), Vector3(sx * 0.45, 0, 3.3), Vector3(0, 0, 0.6))  # the air screws
		k.box(_mat(BRASS), Vector3(0.9, 0.08, 0.05), Vector3(sx * 0.45, 0, 3.3), Vector3(0, 0, -0.95))
	k.box(_mat(BRASS), Vector3(0.06, 1.7, 0.06), Vector3(0, 1.2, 0.5))
	k.tri(_mat(c[3], 0.0, true), Vector3(0, 0.6, 0.56), Vector3(0, 2.0, 0.56), Vector3(0, 0.6, 1.9))
	n.add_child(k.commit("Hull"))
	return n

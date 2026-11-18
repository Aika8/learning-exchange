## Pattern: Builder with a State read from one counter — the pyramid island (working name; `docs/design/concepts/73…79`):
## a pastel fairground under a gold-ribbed glass dome — the pyramid of booths with the golden pavilion, a carousel,
## a big wheel, a wheel of fortune, ticket booths, the coin fountain, balloons and bunting. Every building is a front
## only: from behind it is plywood on grey scaffolding with sandbags. `stage(visits)` says how far it has decayed
## (sheet 77), and the builder reads the stage like any other data. Signs carry pictograms, never words or numbers.
## Nothing here takes or pays money: it is a place to look at (no Ponzi mechanics).
## See docs/adr/0038-game3d-pyramid-island-a-fairground-that-decays.md
class_name PyramidIsle
extends RefCounted

const ID := "pyramid"
const AT := Vector3(-60, 10, 430)  ## the island's centre in the world
const RADIUS := 40.0  ## the rock
const WALK := 31.0  ## the walkable disc under the dome
const DOME_R := 35.0
const DOME_H := 24.0
const SEED := 97
const DECK_Y := 0.12
const PIER_FROM := AT + Vector3(-66.0, DECK_Y, -2.4)
const PIER_TO := AT + Vector3(-22.0, DECK_Y, 2.4)  ## runs in through the dome's door, well onto the walkable disc
const DOCK := AT + Vector3(-61.0, 0, 8.5)
const SPAWN := AT + Vector3(-54.0, 0.5, 0)
const PYRAMID := Vector3(12.0, 0, 0)  ## the pyramid of booths; its stairs look −x, down the avenue
const CAROUSEL := Vector3(-8.0, 0, 13.0)
const WHEEL := Vector3(4.0, 0, -19.0)  ## the big wheel; it turns in the x–y plane
const FORTUNE := Vector3(-11.0, 0, -15.0)  ## the wheel of fortune; its face looks −x
const FOUNTAIN := Vector3(-3.0, 0, -10.0)
const STAGES := 4
const PINK := Color("f7b6c8")
const MINT := Color("a8e2c4")
const BUTTER := Color("fbe39a")
const BABY := Color("a9cdee")
const LILAC := Color("c9b2ea")
const CREAM := Color("f6eedd")
const PEACH := Color("f7c3a4")
const GOLD := Color("e1b04a")
const PLY := Color("caa47a")  ## raw plywood
const PLY_DARK := Color("a8835c")
const SCAFF := Color("8e9096")  ## grey scaffolding
const SAND := Color("9b9584")
const PASTELS: Array[Color] = [PINK, MINT, BUTTER, BABY, LILAC, PEACH]

static var _mats: Dictionary = {}


## The stage of decay at the captain's `visits`-th landing here (1 = the first): 1 shining, 2 fewer people, 3 cracks
## and bare plywood, 4 the dome broken. Before any visit it shows as on the first.
static func stage(visits: int) -> int:
	return clampi(visits, 1, STAGES)


## What a stage changes, as data: how many strangers stroll, how many balloons fly, which fronts are bare
## plywood (by index), how fast the rides turn, and whether the dome is cracked or broken.
static func look(s: int) -> Dictionary:
	return [
		{"crowd": 10, "balloons": 9, "bare": [], "spin": 1.0, "cracks": false, "broken": false, "shut": 0, "tickets": 0},
		{"crowd": 4, "balloons": 5, "bare": [], "spin": 0.55, "cracks": false, "broken": false, "shut": 1, "tickets": 6},
		{"crowd": 1, "balloons": 2, "bare": [1, 3], "spin": 0.0, "cracks": true, "broken": false, "shut": 3, "tickets": 18},
		{"crowd": 0, "balloons": 0, "bare": [0, 1, 2, 3], "spin": 0.0, "cracks": true, "broken": true, "shut": 4, "tickets": 40},
	][clampi(s, 1, STAGES) - 1]


static func walk_areas() -> Array[Dictionary]:
	return [{"name": ID, "kind": "disc", "centre": AT, "radius": WALK, "seed": SEED},
		{"name": ID + "-pier", "kind": "rect", "from": PIER_FROM, "to": PIER_TO}]


## Where the host stands at the foot of the pyramid's stairs and where the captain talks to him: [keeper, spot].
static func stairs() -> Array[Vector3]:
	return [AT + PYRAMID + Vector3(-10.4, 0, 3.4), AT + PYRAMID + Vector3(-11.6, 0, 2.2)]


## Open ground for strangers to stroll on, clear of the rides, booths and the pyramid (island space).
const CROWD_HOMES: Array[Vector3] = [Vector3(-4, 0, -4), Vector3(-26, 0, -14), Vector3(12, 0, -13), Vector3(12, 0, 14), Vector3(-24, 0, 14),
	Vector3(-2, 0, 24), Vector3(-18, 0, -20), Vector3(0, 0, 4), Vector3(22, 0, 2), Vector3(-26, 0, 6)]


## Where the barker stands by the first ticket booth, and where the captain talks to him.
static func booth() -> Array[Vector3]:
	return [AT + Vector3(-19.0, 0, -5.6), AT + Vector3(-20.4, 0, -4.4)]


static func _mat(c: Color, glow: float = 0.0, both_sides: bool = false) -> Material:
	var key := "%s/%s/%s" % [c.to_html(), glow, both_sides]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.35  # gloss: the toy look (sheet 79)
		if both_sides:
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		if glow > 0.0:
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = glow
		_mats[key] = m
	return _mats[key]


static func _glass() -> Material:
	if not _mats.has("glass"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.88, 0.86, 1.0, 0.16)  # faint: the fair is seen through it, nothing shimmers
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.disable_receive_shadows = true
		_mats["glass"] = m
	return _mats["glass"]


## A point on the dome at angle `a` round and `t` up (0 rim, 1 top).
static func dome_point(a: float, t: float) -> Vector3:
	var e := t * PI / 2
	return Vector3(cos(a) * cos(e) * DOME_R, sin(e) * DOME_H, sin(a) * cos(e) * DOME_R)


## The whole island at stage `s`. `town` = false gives the rock, the dome and the pyramid: what is seen from afar.
static func build(town: bool, s: int = 1) -> Node3D:
	var lk := look(s)
	var isl := Node3D.new()
	isl.name = "PyramidIsle"
	isl.set_meta("stage", s)
	isl.add_child(Archipelago.island(RADIUS, 40.0, SEED, 0.0, true))
	isl.add_child(_crystals())
	isl.add_child(_dome(lk))
	isl.add_child(_pyramid(town, lk))
	if not town:
		return isl
	isl.add_child(_ground(lk))
	var fronts := [["tent", Vector3(-2.0, 0, 26.0), PI], ["pavilion", Vector3(18.0, 0, 18.0), PI * 0.75],
		["blocks", Vector3(20.0, 0, -15.0), PI * 0.25], ["tent", Vector3(-20.0, 0, 21.0), PI * 1.2]]
	for i in fronts.size():
		var f := facade(str(fronts[i][0]), i in (lk["bare"] as Array), i)
		f.name = "Facade%d" % (i + 1)
		f.position = fronts[i][1]
		f.rotation.y = atan2(-(fronts[i][1] as Vector3).x, -(fronts[i][1] as Vector3).z)  # the face looks at the fair
		isl.add_child(f)
	var c := carousel(float(lk["spin"]) > 0.0 or s < 3)
	c.position = CAROUSEL
	c.set_meta("spin", 0.35 * maxf(float(lk["spin"]), 0.25 if s == 3 else 0.0))
	isl.add_child(c)
	var w := big_wheel(s >= 3)
	w.position = WHEEL
	w.get_node("Wheel").set_meta("spin", 0.12 * float(lk["spin"]))
	isl.add_child(w)
	var fw := fortune_wheel()
	fw.position = FORTUNE
	fw.rotation.y = PI / 2
	isl.add_child(fw)
	for i in 4:
		var b := ticket_booth(i < int(lk["shut"]), s >= 4)
		b.name = "Booth%d" % (i + 1)
		b.position = Vector3(-19.0 + i * 5.0 if i < 2 else -24.0 + (i - 2) * 5.0, 0, -7.6 if i < 2 else 7.4)
		b.rotation.y = 0.0 if i < 2 else PI
		isl.add_child(b)
	var fo := coin_fountain(s)
	fo.position = FOUNTAIN
	isl.add_child(fo)
	if int(lk["balloons"]) > 0:
		isl.add_child(_balloons(int(lk["balloons"])))
	if s < 4:
		isl.add_child(_bunting(s))
	_lamps(isl)
	if bool(lk["broken"]):
		isl.add_child(_shards())
	if int(lk["tickets"]) > 0:
		isl.add_child(_tickets(int(lk["tickets"])))
	isl.add_child(Archipelago._deck("Pier", PIER_FROM - AT, PIER_TO - AT, [true, false, true, true], PIER_TO - AT + Vector3(0, 0, -2)))
	var fences := Node3D.new()
	fences.name = "Fences"
	isl.add_child(fences)
	Solid.fence_areas(fences, walk_areas(), AT)
	return isl


## Pastel crystals under the rim (sheet 73): long prisms in pink, mint, lilac and blue, pointing out and down.
static func _crystals() -> Node3D:
	var n := Node3D.new()
	n.name = "Crystals"
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED * 7
	var k := Kit.new()
	for i in 22:
		var a := TAU * i / 22.0 + rng.randf_range(-0.1, 0.1)
		var h := rng.randf_range(3.0, 9.0)
		var c: Color = [PINK, MINT, LILAC, BABY][i % 4]
		var tilt := Basis(Vector3(-sin(a), 0, cos(a)), rng.randf_range(0.5, 1.1)) * Basis(Vector3.RIGHT, PI)
		k.mesh(_mat(c.lightened(0.15), 0.35), Proc._cyl_mesh(0.0, h * 0.18, h, 6), Transform3D(tilt, Vector3(cos(a), 0, sin(a)) * (RADIUS - 3.0) + Vector3(0, -2.0 - h * 0.3, 0)))
	var mi := k.commit("Prisms")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mi)
	return n


## The dome (sheet 73): faint glass on gold ribs — sixteen meridians, three rings and a crown — with the door to the
## pier at −x. Cracked (stage 3): white lines across some panes. Broken (stage 4): a third of the panes are gone.
static func _dome(lk: Dictionary) -> Node3D:
	var n := Node3D.new()
	n.name = "Dome"
	n.set_meta("flat", true)  # scenery: over every head inside, beyond the fence outside; the door is left open
	var ribs := Kit.new()
	var gold := _mat(GOLD)
	var meridians := 16
	var rows := 6
	var pane := Kit.new()
	var glass := _glass()
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 5
	for i in meridians:
		var a := TAU * (i + 0.5) / meridians  # half a step round: no rib stands in the door at −x
		var b := TAU * (i + 1.5) / meridians
		for j in rows:
			var t0 := float(j) / rows
			var t1 := float(j + 1) / rows
			var door := absf(wrapf(a + PI / meridians - PI, -PI, PI)) < 0.1 and j == 0  # the opening for the avenue
			if door or (bool(lk["broken"]) and rng.randf() < 0.33):
				continue
			pane.quad(glass, dome_point(a, t0), dome_point(b, t0), dome_point(b, t1), dome_point(a, t1))
		for j in 12:  # the rib: a chain of thin boxes up the meridian
			var p0 := dome_point(a, j / 12.0)
			var p1 := dome_point(a, (j + 1) / 12.0)
			ribs.mesh(gold, Proc._cyl_mesh(0.16, 0.16, p0.distance_to(p1), 6), Transform3D(_along(p1 - p0), (p0 + p1) * 0.5))
	for t: float in [0.0, 0.33, 0.66]:
		for i in 48:
			if t == 0.0 and absf(wrapf(TAU * (i + 0.5) / 48.0 - PI, -PI, PI)) < 0.2:
				continue  # the door: the pier runs in here
			var p0 := dome_point(TAU * i / 48.0, t)
			var p1 := dome_point(TAU * (i + 1) / 48.0, t)
			ribs.mesh(gold, Proc._cyl_mesh(0.14 if t > 0.0 else 0.3, 0.14 if t > 0.0 else 0.3, p0.distance_to(p1), 6), Transform3D(_along(p1 - p0), (p0 + p1) * 0.5))
	ribs.mesh(gold, Proc._sphere(1.2), Transform3D(Basis(), Vector3(0, DOME_H + 0.6, 0)))
	n.add_child(ribs.commit("Ribs"))
	var g := pane.commit("Glass", false)
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(g)
	if bool(lk["cracks"]):
		var cr := Kit.new()
		var white := _mat(Color(1, 1, 1), 0.4, true)
		for c in 9:  # a star of cracks round a point on the dome
			var a := rng.randf() * TAU
			var t := rng.randf_range(0.15, 0.7)
			var centre := dome_point(a, t)
			for ray in 6:
				var d := Vector2(cos(ray * 1.05 + c), sin(ray * 1.05 + c)) * rng.randf_range(0.08, 0.16)
				var tip := dome_point(a + d.x, clampf(t + d.y, 0.02, 0.95))
				cr.mesh(white, Proc._cyl_mesh(0.05, 0.05, centre.distance_to(tip), 4), Transform3D(_along(tip - centre), (centre + tip) * 0.5 * 1.004))
		var m := cr.commit("Cracks", false)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(m)
	return n


## A collider round the rod from `a` to `b` of radius `r`: a thin convex box along it.
static func _rod(parent: Node3D, a: Vector3, b: Vector3, r: float) -> void:
	var basis := _along(b - a)
	var pts := PackedVector3Array()
	for end: Vector3 in [a, b]:
		for cx: float in [-r, r]:
			for cz: float in [-r, r]:
				pts.append(end + basis.x * cx + basis.z * cz)
	Solid.convex(parent, pts)


## A basis whose y axis points along `dir` (for cylinders laid between two points).
static func _along(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	return Basis(x, y, x.cross(y) * -1.0)


## The fair's ground: cream paving, a pink avenue from the door to the pyramid, mint lawns, a lilac ring path.
static func _ground(lk: Dictionary) -> Node3D:
	var n := Node3D.new()
	n.name = "Ground"
	n.set_meta("flat", true)
	var k := Kit.new()
	var worn := bool(lk["cracks"])
	k.mesh(_mat(CREAM.darkened(0.12 if worn else 0.0)), Proc._cyl_mesh(33.0, 33.0, 0.06, 48), Transform3D(Basis(), Vector3(0, 0.02, 0)))
	k.mesh(_mat(LILAC.lerp(CREAM, 0.4)), Proc._cyl_mesh(24.0, 24.0, 0.065, 48), Transform3D(Basis(), Vector3(0, 0.025, 0)))
	k.mesh(_mat(MINT.darkened(0.25 if worn else 0.0)), Proc._cyl_mesh(21.5, 21.5, 0.07, 48), Transform3D(Basis(), Vector3(0, 0.03, 0)))
	k.box(_mat(PINK.lerp(CREAM, 0.3)), Vector3(34.0, 0.08, 5.0), Vector3(-15.0, 0.04, 0))
	for z: float in [-2.6, 2.6]:
		k.box(_mat(GOLD), Vector3(34.0, 0.09, 0.22), Vector3(-15.0, 0.045, z))
	n.add_child(k.commit("Paving"))
	return n


## The pyramid of booths (sheet 75): three stepped peach tiers, pastel booths with gold roofs on each step, a
## staircase up the front in rainbow steps, and on top the golden pavilion with onion domes. Stage 3 and on: the
## golden pavilion is plywood showing through, and the booths on the lower tier are shut.
static func _pyramid(town: bool, lk: Dictionary) -> Node3D:
	var n := Node3D.new()
	n.name = "Pyramid"
	n.position = PYRAMID
	var k := Kit.new()
	var tiers := [[18.0, 2.6], [13.0, 2.6], [8.0, 2.6]]
	var y := 0.0
	var bare := (lk["bare"] as Array).size() >= 2
	for i in tiers.size():
		var w: float = tiers[i][0]
		var h: float = tiers[i][1]
		k.box(_mat(PEACH.lerp(CREAM, 0.35 + i * 0.1)), Vector3(w, h, w), Vector3(0, y + h * 0.5, 0))
		k.box(_mat(GOLD), Vector3(w + 0.1, 0.14, w + 0.1), Vector3(0, y + h - 0.07, 0))
		y += h
	var gold := _mat(PLY if bare else GOLD)
	k.box(gold, Vector3(5.0, 3.4, 5.0), Vector3(0, y + 1.7, 0))
	k.box(_mat(PINK.lerp(CREAM, 0.3)), Vector3(4.0, 2.4, 0.1), Vector3(-2.52, y + 1.4, 0))
	for c: Vector3 in [Vector3(0, 0, 0), Vector3(1.7, 0, 1.7), Vector3(-1.7, 0, 1.7), Vector3(1.7, 0, -1.7), Vector3(-1.7, 0, -1.7)]:
		var big := c == Vector3.ZERO
		var r := 1.5 if big else 0.7
		var top := y + 3.4 + (1.2 if big else 0.0)
		if big:
			k.box(gold, Vector3(2.2, 1.2, 2.2), Vector3(0, y + 4.0, 0))
		k.mesh(gold, Proc._sphere(r), Transform3D(Basis().scaled(Vector3(1, 1.15, 1)), c + Vector3(0, top + r * 0.8, 0)))
		k.mesh(gold, Proc._cyl_mesh(0.0, r * 0.35, r * 1.4, 8), Transform3D(Basis(), c + Vector3(0, top + r * 1.9 + r * 0.6, 0)))
	n.add_child(k.commit("Tiers"))
	y = 0.0
	for t: Array in tiers:
		Solid.box(n, Vector3(t[0], t[1], t[0]), Vector3(0, y + float(t[1]) * 0.5, 0))
		y += float(t[1])
	Solid.box(n, Vector3(5.0, 8.0, 5.0), Vector3(0, y + 4.0, 0))  # the golden pavilion and its domes
	if not town:
		return n
	var st := Kit.new()
	for i in 24:  # the staircase up the front (−x), each step its own pastel
		var h := (i + 1) * 7.8 / 24.0
		var x := -14.0 + (i + 0.5) * 10.0 / 24.0
		st.box(_mat(PASTELS[i % PASTELS.size()]), Vector3(10.0 / 24.0, h, 2.6), Vector3(x, h * 0.5, 0))
	for z: float in [-1.4, 1.4]:
		var p0 := Vector3(-14.0, 1.0, z)
		var p1 := Vector3(-4.0, 8.8, z)
		st.mesh(_mat(GOLD), Proc._cyl_mesh(0.07, 0.07, p0.distance_to(p1), 6), Transform3D(_along(p1 - p0), (p0 + p1) * 0.5))
	n.add_child(st.commit("Stairs"))
	for i in 12:  # the stairs' collider in steps of two treads, so it keeps to their shape
		var h := (i * 2 + 2) * 7.8 / 24.0
		Solid.box(n, Vector3(10.0 / 12.0, h, 2.6), Vector3(-14.0 + (i + 0.5) * 10.0 / 12.0, h * 0.5, 0))
	var shut := int(lk["shut"])
	var slot := 0
	y = 0.0
	for i in 2:  # booths on the two lower steps, on the three sides away from the stairs and beside them
		var w: float = tiers[i][0]
		var nw: float = tiers[i + 1][0]
		var ring := (w + nw) * 0.25
		y += float(tiers[i][1])
		for side in 4:
			for off: float in ([-1.0, 1.0] if side == 2 else [0.0]):
				var turn := Basis(Vector3.UP, side * PI / 2)
				var at := turn * Vector3(ring, y, off * 3.6)
				if side == 2 and absf(off) < 0.5:
					continue
				var b := _small_booth(PASTELS[slot % PASTELS.size()], slot < shut * 2)
				b.position = at
				b.rotation.y = side * PI / 2 + PI / 2
				n.add_child(b)
				slot += 1
	return n


## A small booth on the pyramid's step: a pastel box, a gold roof, a counter; shut = a plywood board over it.
static func _small_booth(c: Color, shut: bool) -> Node3D:
	var n := Node3D.new()
	n.name = "StepBooth"
	var k := Kit.new()
	k.box(_mat(c), Vector3(1.6, 1.6, 1.4), Vector3(0, 0.8, 0))
	k.box(_mat(GOLD), Vector3(1.9, 0.3, 1.7), Vector3(0, 1.75, 0))
	k.box(_mat(c.darkened(0.3) if not shut else PLY), Vector3(1.0, 0.7, 0.06), Vector3(0, 1.0, 0.72))
	n.add_child(k.commit("Booth"))
	return n


## A front with nothing behind it (sheet 74): the glossy pastel face of a tent-pyramid, a domed pavilion or a block
## of toy cubes on a shell a metre deep, and behind it plywood, grey scaffolding and sandbags. `bare` shows the
## plywood on the front too. The face looks +z.
static func facade(kind: String, bare: bool, n_i: int = 0) -> Node3D:
	var n := Node3D.new()
	n.name = "Facade"
	n.set_meta("kind", kind)
	n.set_meta("bare", bare)
	var k := Kit.new()
	var main := _mat(PLY if bare else [PINK, MINT, BABY, LILAC][n_i % 4])
	var trim := _mat(PLY_DARK if bare else [MINT, PINK, BUTTER, BUTTER][n_i % 4])
	var w := 9.0
	match kind:
		"tent":
			k.tri(main, Vector3(-w * 0.5, 0.6, 0.5), Vector3(0, 9.0, 0.5), Vector3(w * 0.5, 0.6, 0.5))
			k.tri(_mat(PLY_DARK), Vector3(w * 0.5, 0.6, -0.5), Vector3(0, 9.0, -0.5), Vector3(-w * 0.5, 0.6, -0.5))
			k.quad(main, Vector3(-w * 0.5, 0.6, -0.5), Vector3(-w * 0.5, 0.6, 0.5), Vector3(0, 9.0, 0.5), Vector3(0, 9.0, -0.5))
			k.quad(main, Vector3(w * 0.5, 0.6, 0.5), Vector3(w * 0.5, 0.6, -0.5), Vector3(0, 9.0, -0.5), Vector3(0, 9.0, 0.5))
			n.add_child(k.commit("Face"))
			k = Kit.new()
			k.box(_mat(PINK.darkened(0.2) if not bare else PLY), Vector3(w + 1.0, 0.6, 2.4), Vector3(0, 0.3, 0.6))
			k.box(trim, Vector3(2.0, 3.0, 0.2), Vector3(0, 2.1, 0.62))
			k.box(_mat(GOLD if not bare else PLY_DARK), Vector3(0.1, 1.6, 0.1), Vector3(0, 9.8, 0.4))
		"pavilion":
			k.box(main, Vector3(w, 6.0, 1.0), Vector3(0, 3.6, 0))
			k.box(trim, Vector3(w + 0.4, 0.5, 1.3), Vector3(0, 6.8, 0))
			k.mesh(trim, Proc._sphere(2.6), Transform3D(Basis().scaled(Vector3(1, 0.9, 0.35)), Vector3(0, 7.2, 0)))
			for x: float in [-3.0, -1.0, 1.0, 3.0]:
				k.box(_mat(CREAM if not bare else PLY_DARK), Vector3(0.9, 2.6, 0.2), Vector3(x, 2.4, 0.55))
			k.box(_mat(MINT.darkened(0.15) if not bare else PLY), Vector3(w + 1.0, 0.6, 2.4), Vector3(0, 0.3, 0.6))
		_:  # blocks
			var cubes := [[Vector3(-2.8, 1.9, 0), 3.2], [Vector3(0.6, 2.2, 0), 3.8], [Vector3(3.2, 1.6, 0), 2.6], [Vector3(-1.2, 5.3, 0), 3.0], [Vector3(1.9, 5.0, 0), 2.2], [Vector3(0.2, 7.9, 0), 2.0]]
			for i in cubes.size():
				var c := _mat(PLY if bare else PASTELS[(i + n_i) % PASTELS.size()])
				k.box(c, Vector3(cubes[i][1], cubes[i][1], 1.0), cubes[i][0] + Vector3(0, 0.3, 0))
			k.box(_mat(BUTTER.darkened(0.1) if not bare else PLY), Vector3(w + 1.0, 0.6, 2.4), Vector3(0, 0.3, 0.6))
	n.add_child(k.commit("Front"))
	n.add_child(_props_behind(w))
	Solid.box(n, Vector3(w, 9.0 if kind == "tent" else 8.0, 1.2), Vector3(0, 4.5 if kind == "tent" else 4.0, 0))
	Solid.box(n, Vector3(w + 1.0, 0.6, 2.4), Vector3(0, 0.3, 0.6))
	Solid.box(n, Vector3(w * 0.95 + 0.1, 6.6, 1.8), Vector3(0, 3.3, -1.8))  # the scaffold
	for x: float in [-w * 0.35, w * 0.35]:  # each strut and its sandbags
		var strut := Basis.from_euler(Vector3(-0.9, 0, 0)).scaled_local(Vector3(0.12, 0.5, 6.4))
		var pts := PackedVector3Array()
		for cx: float in [-0.5, 0.5]:
			for cy: float in [-0.5, 0.5]:
				for cz: float in [-0.5, 0.5]:
					pts.append(strut * Vector3(cx, cy, cz) + Vector3(x, 3.2, -3.0))
		Solid.convex(n, pts)
		for z: float in [-5.2, -5.6]:
			Solid.box(n, Vector3(0.9, 0.35, 0.5), Vector3(x + (z + 5.4) * 2.0, 0.18, z))
	return n


## What holds a front up, behind it (sheet 74): two struts of plywood, a grey scaffold with ladders and planks, a
## plywood hoarding round its foot, and sandbags on the feet.
static func _props_behind(w: float) -> Node3D:
	var n := Node3D.new()
	n.name = "Props"
	var k := Kit.new()
	var steel := _mat(SCAFF)
	var ply := _mat(PLY)
	for x: float in [-w * 0.35, w * 0.35]:
		k.box(ply, Vector3(0.12, 0.5, 6.4), Vector3(x, 3.2, -3.0), Vector3(-0.9, 0, 0))  # the strut
		for z: float in [-5.2, -5.6]:
			k.box(_mat(SAND), Vector3(0.9, 0.35, 0.5), Vector3(x + (z + 5.4) * 2.0, 0.18, z))
	for x in 4:
		for z: float in [-1.0, -2.6]:
			k.box(steel, Vector3(0.1, 6.6, 0.1), Vector3(-w * 0.45 + x * w * 0.3, 3.3, z))
	for y: float in [1.6, 3.4, 5.2]:
		for z: float in [-1.0, -2.6]:
			k.box(steel, Vector3(w * 0.95, 0.08, 0.08), Vector3(0, y, z))
		k.box(ply, Vector3(w * 0.9, 0.06, 1.5), Vector3(0, y + 0.06, -1.8))
	k.box(steel, Vector3(0.4, 5.0, 0.06), Vector3(w * 0.3, 2.5, -2.9), Vector3(0.12, 0, 0))  # a ladder
	k.box(ply, Vector3(w * 0.95 + 0.1, 2.4, 0.06), Vector3(0, 1.2, -2.68))  # plywood hoarding round the scaffold's foot
	for x: float in [-w * 0.475 - 0.02, w * 0.475 + 0.02]:
		k.box(ply, Vector3(0.06, 2.4, 1.8), Vector3(x, 1.2, -1.8))
	n.add_child(k.commit("Scaffold"))
	return n


## The carousel (sheet 75): a pink plinth, a lilac-and-mint striped canopy with a gold crown, gold poles and
## horses. `spin` is the turn speed (rad/s) read by the scene.
static func carousel(lit: bool) -> Node3D:
	var n := Node3D.new()
	n.name = "Carousel"
	n.add_to_group("pyramid_spin")
	var k := Kit.new()
	k.mesh(_mat(PINK), Proc._cyl_mesh(5.0, 5.2, 0.6, 32), Transform3D(Basis(), Vector3(0, 0.3, 0)))
	k.mesh(_mat(GOLD), Proc._cyl_mesh(5.25, 5.25, 0.14, 32), Transform3D(Basis(), Vector3(0, 0.62, 0)))
	k.mesh(_mat(CREAM), Proc._cyl_mesh(0.6, 0.6, 4.2, 12), Transform3D(Basis(), Vector3(0, 2.7, 0)))
	for i in 12:  # the canopy: a cone in alternating stripes
		var a := TAU * i / 12.0
		var b := TAU * (i + 1) / 12.0
		var c := _mat([LILAC, MINT, PINK][i % 3], 0.0, true)
		k.tri(c, Vector3(0, 6.6, 0), Vector3(cos(a) * 5.4, 4.8, sin(a) * 5.4), Vector3(cos(b) * 5.4, 4.8, sin(b) * 5.4))
		k.tri(c, Vector3(cos(a) * 5.4, 4.8, sin(a) * 5.4), Vector3(cos(a) * 5.4, 4.3, sin(a) * 5.4) * Vector3(1, 1, 1), Vector3(cos(b) * 5.4, 4.8, sin(b) * 5.4))
	n.add_child(k.commit("Body"))
	var top := Kit.new()
	top.mesh(_mat(GOLD), Proc._sphere(0.45), Transform3D(Basis(), Vector3(0, 6.9, 0)))
	for i in 8:
		var a := TAU * i / 8.0
		var p := Vector3(cos(a) * 3.8, 0, sin(a) * 3.8)
		top.mesh(_mat(GOLD), Proc._cyl_mesh(0.06, 0.06, 4.2, 6), Transform3D(Basis(), p + Vector3(0, 2.7, 0)))
		var horse := _mat([CREAM, PINK, BABY, MINT][i % 4])
		var h := 1.5 + 0.3 * sin(i)
		top.box(horse, Vector3(0.45, 0.6, 1.3), p + Vector3(0, h, 0), Vector3(0, -a, 0))
		top.box(horse, Vector3(0.3, 0.7, 0.35), p + Vector3(0, h + 0.5, 0) + Vector3(-sin(a), 0, cos(a)) * 0.6, Vector3(0, -a, 0))
	if lit:
		for i in 12:
			var a := TAU * i / 12.0
			top.mesh(_mat(BUTTER, 1.6), Proc._sphere(0.12), Transform3D(Basis(), Vector3(cos(a) * 5.4, 4.55, sin(a) * 5.4)))
	n.add_child(top.commit("Ride"))
	Solid.post(n, 5.2, 0.62, Vector3.ZERO)  # the plinth
	Solid.post(n, 4.1, 4.8, Vector3.ZERO)  # the ring of horses: they turn inside it
	return n


## The big wheel (sheet 75): a cream rim with gold spokes on a pink stand, eight pastel cabins. Stopped from stage 3.
static func big_wheel(stopped: bool) -> Node3D:
	var n := Node3D.new()
	n.name = "BigWheel"
	var r := 8.0
	var hub := Vector3(0, r + 3.4, 0)  # the lowest cabin hangs above every head
	var stand := Kit.new()
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.4, 1.4]:
			var foot := Vector3(x * 4.0, 0, z)
			stand.mesh(_mat(PINK), Proc._cyl_mesh(0.22, 0.3, foot.distance_to(hub), 8), Transform3D(_along(hub - foot), (foot + hub) * 0.5))
			_rod(n, foot, hub, 0.3)
	stand.box(_mat(PINK.darkened(0.15)), Vector3(9.5, 0.5, 3.6), Vector3(0, 0.25, 0))
	n.add_child(stand.commit("Stand"))
	Solid.box(n, Vector3(9.5, 0.6, 3.6), Vector3(0, 0.3, 0))
	var ride := Node3D.new()
	ride.name = "Wheel"
	ride.position = hub
	ride.set_meta("axis", "z")
	ride.set_meta("spin", 0.0 if stopped else 0.12)
	ride.add_to_group("pyramid_spin")
	var k := Kit.new()
	for i in 32:
		var a := TAU * i / 32.0
		var b := TAU * (i + 1) / 32.0
		var p0 := Vector3(cos(a) * r, sin(a) * r, 0)
		var p1 := Vector3(cos(b) * r, sin(b) * r, 0)
		k.mesh(_mat(CREAM), Proc._cyl_mesh(0.16, 0.16, p0.distance_to(p1), 6), Transform3D(_along(p1 - p0), (p0 + p1) * 0.5))
	for i in 8:
		var a := TAU * i / 8.0
		var p := Vector3(cos(a) * r, sin(a) * r, 0)
		k.mesh(_mat(GOLD), Proc._cyl_mesh(0.07, 0.07, r, 6), Transform3D(_along(p), p * 0.5))
		k.box(_mat(PASTELS[i % PASTELS.size()]), Vector3(1.2, 1.1, 1.2), p + Vector3(0, -1.0, 0))
	k.mesh(_mat(GOLD), Proc._sphere(0.6), Transform3D())
	ride.add_child(k.commit("Rim"))
	n.add_child(ride)
	return n


## The wheel of fortune (sheet 75): a gold-rimmed disc in pastel wedges on a pink stand, a pointer on top. It
## does not turn and nobody plays it.
static func fortune_wheel() -> Node3D:
	var n := Node3D.new()
	n.name = "FortuneWheel"
	var k := Kit.new()
	var c := Vector3(0, 2.6, 0)
	for i in 12:
		var a := TAU * i / 12.0
		var b := TAU * (i + 1) / 12.0
		k.tri(_mat(PASTELS[i % PASTELS.size()], 0.0, true), c + Vector3(0.1, 0, 0), c + Vector3(0.1, sin(a) * 1.8, cos(a) * 1.8), c + Vector3(0.1, sin(b) * 1.8, cos(b) * 1.8))
	n.add_child(k.commit("Face"))
	var f := Kit.new()
	f.mesh(_mat(GOLD), Proc._cyl_mesh(1.95, 1.95, 0.16, 32), Transform3D(Basis(Vector3.FORWARD, PI / 2), c))
	f.box(_mat(PINK), Vector3(0.6, 1.0, 1.8), Vector3(0, 0.5, 0))
	f.box(_mat(GOLD), Vector3(0.2, 0.5, 0.2), c + Vector3(0.2, 2.0, 0))
	n.add_child(f.commit("Stand"))
	Solid.box(n, Vector3(0.6, 1.0, 1.8), Vector3(0, 0.5, 0))
	return n


## A ticket booth (sheet 75): a lilac kiosk with a striped dome roof and a window; over the window a gold ticket
## pictogram, no word. Shut: a plywood board across the window. `bare` (stage 4): plywood all over.
static func ticket_booth(shut: bool, bare: bool) -> Node3D:
	var n := Node3D.new()
	n.name = "TicketBooth"
	var k := Kit.new()
	var body := _mat(PLY if bare else LILAC)
	k.box(body, Vector3(2.2, 2.6, 2.2), Vector3(0, 1.3, 0))
	k.box(_mat(PLY_DARK if bare else MINT), Vector3(2.5, 0.3, 2.5), Vector3(0, 2.75, 0))
	k.mesh(_mat(PLY_DARK if bare else PINK), Proc._cyl_mesh(0.2, 1.3, 1.2, 8), Transform3D(Basis(), Vector3(0, 3.5, 0)))
	k.box(_mat(PLY if shut else CREAM.darkened(0.3)), Vector3(1.3, 0.9, 0.06), Vector3(0, 1.6, 1.12))
	k.box(_mat(GOLD), Vector3(0.8, 0.42, 0.05), Vector3(0, 2.35, 1.13))  # the ticket pictogram
	k.box(_mat(GOLD.darkened(0.3)), Vector3(0.08, 0.3, 0.06), Vector3(0.2, 2.35, 1.15))
	n.add_child(k.commit("Booth"))
	Solid.box(n, Vector3(2.2, 2.6, 2.2), Vector3(0, 1.3, 0))
	return n


## The coin fountain (sheet 78): three wooden bowls of pastel coins stacked on grey scaffolding, a gold coin on top.
## It empties stage by stage; on stage 4 the bowls are bare.
static func coin_fountain(s: int) -> Node3D:
	var n := Node3D.new()
	n.name = "CoinFountain"
	var k := Kit.new()
	var wood := _mat(PLY_DARK)
	var steel := _mat(SCAFF)
	var tiers := [[2.6, 0.8], [1.9, 1.9], [1.2, 2.9]]
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 11
	for i in 8:
		var a := TAU * i / 8.0
		k.box(steel, Vector3(0.08, 2.9, 0.08), Vector3(cos(a) * 2.4, 1.45, sin(a) * 2.4))
	for t: Array in tiers:
		var r: float = t[0]
		var y: float = t[1]
		k.mesh(wood, Proc._cyl_mesh(r, r * 0.8, 0.5, 20), Transform3D(Basis(), Vector3(0, y, 0)))
		var coins := maxi(0, int(r * 8.0) * (STAGES - s) / (STAGES - 1))
		for c in coins:
			var a := rng.randf() * TAU
			var d := rng.randf() * r * 0.8
			k.mesh(_mat(PASTELS[c % PASTELS.size()] if c % 3 else GOLD), Proc._cyl_mesh(0.22, 0.22, 0.06, 10),
				Transform3D(Basis(Vector3.RIGHT, rng.randf_range(-0.4, 0.4)), Vector3(cos(a) * d, y + 0.28, sin(a) * d)))
	if s < STAGES:
		k.mesh(_mat(GOLD, 0.4), Proc._cyl_mesh(0.5, 0.5, 0.1, 16), Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 4.0, 0)))
	n.add_child(k.commit("Tiers"))
	Solid.post(n, 2.6, 1.05, Vector3.ZERO)  # the lowest bowl
	Solid.post(n, 1.9, 3.2, Vector3.ZERO)
	for i in 8:
		var a := TAU * i / 8.0
		Solid.post(n, 0.08, 2.9, Vector3(cos(a) * 2.4, 0, sin(a) * 2.4))
	return n


## Bunches of balloons tied over the fair, `count` of them; they rise on strings and do not move.
static func _balloons(count: int) -> Node3D:
	var n := Node3D.new()
	n.name = "Balloons"
	n.set_meta("hung", true)
	n.set_meta("walk_through", true)  # strings and a thin stake: nothing to bump into
	var k := Kit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 3
	for i in count:
		var a := TAU * (i + 0.5) / maxf(count, 1) + PI  # half a step off the avenue, which runs along −x
		var foot := Vector3(cos(a) * 23.5, 0, sin(a) * 23.5)  # on the ring path, clear of the pyramid's corners
		k.box(_mat(SCAFF), Vector3(0.12, 1.2, 0.12), foot + Vector3(0, 0.6, 0))
		Solid.post(n, 0.08, 1.2, foot)
		for b in 5:
			var p := foot + Vector3(rng.randf_range(-0.8, 0.8), 6.0 + rng.randf_range(0.0, 1.6), rng.randf_range(-0.8, 0.8))
			k.mesh(_mat([PINK, MINT, LILAC, BABY, BUTTER][b]), Proc._sphere(0.55), Transform3D(Basis().scaled(Vector3(1, 1.2, 1)), p))
			k.mesh(_mat(CREAM), Proc._cyl_mesh(0.015, 0.015, p.y - 1.2, 3), Transform3D(_along(p - foot - Vector3(0, 1.2, 0)), (p + foot + Vector3(0, 1.2, 0)) * 0.5))
	n.add_child(k.commit("Bunches"))
	return n


## Bunting from the dome's crown down to the ring path: pastel pennants on gold lines. Fewer at stage 2.
static func _bunting(s: int) -> Node3D:
	var n := Node3D.new()
	n.name = "Bunting"
	n.set_meta("flat", true)
	var k := Kit.new()
	var lines := 8 if s == 1 else 4
	for i in lines:
		var a := TAU * i / lines + 0.2
		var from := Vector3(0, DOME_H - 4.0, 0)
		var to := Vector3(cos(a) * 24.0, 5.0, sin(a) * 24.0)
		for j in 14:
			var p := from.lerp(to, j / 14.0) - Vector3(0, sin(PI * j / 14.0) * 2.0, 0)
			var q := from.lerp(to, (j + 1) / 14.0) - Vector3(0, sin(PI * (j + 1) / 14.0) * 2.0, 0)
			k.tri(_mat(PASTELS[j % PASTELS.size()], 0.0, true), p, q, (p + q) * 0.5 - Vector3(0, 0.9, 0))
	n.add_child(k.commit("Pennants", false))
	return n


## Pastel lamp posts along the avenue and round the ring path.
static func _lamps(isl: Node3D) -> void:
	for x: float in [-28.0, -22.0, -16.0, -10.0]:
		for z: float in [-3.4, 3.4]:
			var n := Node3D.new()
			n.name = "Lamp"
			n.position = Vector3(x, 0, z)
			var k := Kit.new()
			k.mesh(_mat(MINT), Proc._cyl_mesh(0.08, 0.12, 3.4, 8), Transform3D(Basis(), Vector3(0, 1.7, 0)))
			k.mesh(_mat(BUTTER, 1.4), Proc._sphere(0.3), Transform3D(Basis(), Vector3(0, 3.6, 0)))
			n.add_child(k.commit("Post"))
			Solid.post(n, 0.14, 3.4, Vector3.ZERO)
			isl.add_child(n)


## Shards of the dome on the ground (stage 4, sheet 78): flat pale glass triangles round the rim.
static func _shards() -> Node3D:
	var n := Node3D.new()
	n.name = "Shards"
	n.set_meta("flat", true)
	var k := Kit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 17
	var m := _mat(BABY.lerp(Color.WHITE, 0.6), 0.2, true)
	for i in 60:
		var a := rng.randf() * TAU
		var p := Vector3(cos(a), 0, sin(a)) * rng.randf_range(20.0, 31.0) + Vector3(0, 0.1, 0)
		var s := rng.randf_range(0.3, 0.9)
		var t := rng.randf() * TAU
		k.tri(m, p, p + Vector3(cos(t), 0.02, sin(t)) * s, p + Vector3(cos(t + 1.9), 0.04, sin(t + 1.9)) * s * 0.7)
	n.add_child(k.commit("Glass", false))
	return n


## Dropped tickets on the ground: small gold and pink slips, more each stage.
static func _tickets(count: int) -> Node3D:
	var n := Node3D.new()
	n.name = "Tickets"
	n.set_meta("flat", true)
	var k := Kit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 23
	for i in count:
		var a := rng.randf() * TAU
		var p := Vector3(cos(a), 0, sin(a)) * rng.randf_range(4.0, 28.0) + Vector3(0, 0.1, 0)
		k.box(_mat(GOLD if i % 2 else PINK), Vector3(0.36, 0.015, 0.18), p, Vector3(0, rng.randf() * TAU, 0))
	n.add_child(k.commit("Slips", false))
	return n

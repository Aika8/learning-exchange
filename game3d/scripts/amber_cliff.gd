## Pattern: Builder — Amber Cliff («La Falaise d'Ambre»), the French-speaking island: a quay, a market square with a
## fountain, a bank, a bureau de change, a bakery, a café, a bookshop, a lighthouse and streets of town houses with
## slate mansard roofs. Everything is built in code; every sign is a word in the island's tongue.
## See docs/adr/0028-game3d-amber-cliff-speaks-french.md
class_name AmberCliff
extends RefCounted

const ID := "amber"
const AT := Vector3(-290, 6, 170)  ## the island's centre in the world
const RADIUS := 46.0
const SEED := 31
const DECK_Y := 0.12
const PIER_FROM := AT + Vector3(-62.0, DECK_Y, -2.4)
const PIER_TO := AT + Vector3(-33.0, DECK_Y, 2.4)  ## its island end lies well inside the walkable cap
const DOCK := AT + Vector3(-57.0, 0, 8.5)  ## where the packet boat is moored
const SPAWN := AT + Vector3(-50.0, 0.5, 0)
const WALLS: Array[Color] = [Color("f2e3c2"), Color("efd3a4"), Color("e9c1a3"), Color("f4ead8"), Color("d9c9a8"), Color("f0d9b5")]
const SHUTTERS: Array[Color] = [Color("3f7f8c"), Color("6a8f5a"), Color("8c3b3b"), Color("3b5a8c"), Color("c98a3a")]
const SLATE := Color("55647a")
const TRIM := Color("f6efdc")
const IRON := Color("24272e")

## The shops and the people who keep them: id → [place on the island, facing (radians, 0 = door looks south),
## width, floors, sign key, awning colour, talk, cast id of the keeper]. Places are in the island's own space.
const SHOPS := {
	"bank": [Vector3(0, 0, -19.0), 0.0, 12.0, 3, "AMB_SIGN_BANK", Color.TRANSPARENT],
	"change": [Vector3(17.0, 0, -11.0), -0.95, 6.4, 3, "AMB_SIGN_CHANGE", Color("2f6f8c")],
	"bakery": [Vector3(-17.0, 0, -11.0), 0.95, 6.4, 2, "AMB_SIGN_BAKERY", Color("c9503f")],
	"cafe": [Vector3(17.5, 0, 11.5), -2.2, 7.0, 3, "AMB_SIGN_CAFE", Color("c98a3a")],
	"books": [Vector3(-17.0, 0, 11.0), 2.2, 6.0, 3, "AMB_SIGN_BOOKS", Color("4f7f52")],
}
const LIGHTHOUSE := Vector3(36.5, 0, 0)
const FOUNTAIN_R := 2.6

static var _mats: Dictionary = {}


static func walk_areas() -> Array[Dictionary]:
	return [{"name": "amber", "kind": "disc", "centre": AT, "radius": RADIUS, "seed": SEED},
		{"name": "amber-pier", "kind": "rect", "from": PIER_FROM, "to": PIER_TO}]


## Where a keeper stands (in front of the door) and where the captain talks to them: [keeper, spot], world space.
static func door(shop: String) -> Array[Vector3]:
	var s: Array = SHOPS[shop]
	var front := Vector3(sin(float(s[1])), 0, cos(float(s[1])))
	var at: Vector3 = s[0]
	var side := Vector3(front.z, 0, -front.x) * 1.6  # beside the door, not in it
	return [AT + at + front * 4.3 + side, AT + at + front * 5.6 + side * 0.5]


static func lighthouse_spot() -> Array[Vector3]:
	return [AT + LIGHTHOUSE + Vector3(-4.2, 0, 1.6), AT + LIGHTHOUSE + Vector3(-5.6, 0, 0.8)]


## The whole island. `town` = false gives the rock, the lighthouse and plain blocks: what is seen from far away.
static func build(town: bool) -> Node3D:
	var isl := Node3D.new()
	isl.name = "AmberCliff"
	isl.add_child(Archipelago.island(RADIUS, 58.0, SEED, 0.0, true))
	var rng := RandomNumberGenerator.new()
	rng.seed = 314
	isl.add_child(_lighthouse())
	var houses := _plots()
	for i in houses.size():
		var p: Array = houses[i]
		var hs: Node3D
		if not town:
			hs = Node3D.new()
			hs.add_child(Proc.box(Vector3(p[2], 9.0, 6.0), WALLS[i % WALLS.size()], Vector3(0, 4.5, 0)))
			hs.add_child(Proc.box(Vector3(float(p[2]) - 1.2, 1.8, 4.8), SLATE, Vector3(0, 9.9, 0)))
		else:
			hs = townhouse(rng, WALLS[i % WALLS.size()], SHUTTERS[i % SHUTTERS.size()], p[3], p[2], str(p[4]), p[5])
		hs.position = p[0]
		hs.rotation.y = p[1]
		isl.add_child(hs)
	if not town:
		return isl
	isl.add_child(_paving())
	isl.add_child(_fountain())
	isl.add_child(_kiosk(Vector3(7.5, 0, 6.0)))
	for i in 10:  # clipped trees round the square, the streets left open
		var a := TAU * (i + 0.5) / 10.0
		if absf(sin(a)) < 0.35:
			continue
		isl.add_child(_tree(rng, Vector3(cos(a) * 10.5, 0, sin(a) * 10.5)))
	for x: float in [-30.0, -24.0, 24.0, 30.0]:
		for z: float in [-3.6, 3.6]:
			if absf(x) < 26.0 or z > 0:
				isl.add_child(_lamp(Vector3(x, 0, z)))
	for p: Vector3 in [Vector3(-5.5, 0, -8.5), Vector3(5.5, 0, -8.5), Vector3(-8.5, 0, 7.0), Vector3(-36.0, 0, 5.0), Vector3(-36.0, 0, -5.0)]:
		isl.add_child(_lamp(p))
	_terrace(isl, rng)
	var flowers := Archipelago._stall(Vector3(-6.5, 0, 9.5), 0)
	flowers.rotation.y = PI
	isl.add_child(flowers)
	flowers.add_child(word_sign("AMB_SIGN_FLOWERS", Vector3(0, 2.75, -0.95), PI, 56, Color("7a2f4a")))
	isl.add_child(Archipelago._deck("Pier", PIER_FROM - AT, PIER_TO - AT, [true, false, true, true], PIER_TO - AT + Vector3(0, 0, -2)))
	for p: Array in [["AMB_SIGN_QUAY", Vector3(-31.5, 0, 4.4), -PI / 2], ["AMB_SIGN_STREET", Vector3(-21.5, 0, -3.9), 0.0],
			["AMB_SIGN_SQUARE", Vector3(-10.8, 0, 3.3), -PI / 2]]:
		isl.add_child(_street_plate(p[0], p[1], p[2]))
	var f := Node3D.new()
	f.name = "Fences"
	isl.add_child(f)
	Solid.fence_areas(f, walk_areas(), AT)
	return isl


## Every building: [place, facing, width, floors, sign key or "", awning colour]. The shops first, then the streets.
static func _plots() -> Array:
	var out: Array = []
	for id: String in SHOPS:
		out.append(SHOPS[id])
	for x: float in [-24.5, -31.5]:  # Rue de l'Épargne, from the quay to the square
		out.append([Vector3(x, 0, -8.6), 0.0, 6.4, 3 if x < -30.0 else 2, "", Color.TRANSPARENT])
		out.append([Vector3(x, 0, 8.6), PI, 6.4, 3, "", Color.TRANSPARENT])
	out.append([Vector3(26.5, 0, -9.0), 0.0, 6.0, 2, "", Color.TRANSPARENT])  # the way to the lighthouse
	out.append([Vector3(27.0, 0, 9.4), PI, 6.4, 3, "", Color.TRANSPARENT])
	out.append([Vector3(0, 0, 20.0), PI, 9.0, 3, "AMB_SIGN_HOTEL", Color("3b5a8c")])
	for p: Vector3 in [Vector3(-14.0, 0, -27.0), Vector3(14.0, 0, -27.0), Vector3(-13.5, 0, 28.5), Vector3(13.5, 0, 28.5), Vector3(-29.0, 0, -20.0),
			Vector3(-29.0, 0, 20.5), Vector3(29.0, 0, -21.0), Vector3(29.0, 0, 21.5)]:
		out.append([p, atan2(-p.x, -p.z), 6.0, 2 + (int(absf(p.x)) % 2), "", Color.TRANSPARENT])
	return out


static func _mat(c: Color, both_sides: bool = false) -> Material:
	var key := c.to_html() + ("/2" if both_sides else "")
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.85
		if both_sides:
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats[key] = m
	return _mats[key]


## A town house: pale plaster, tall windows with shutters, a balcony rail, a slate mansard roof with dormers and
## chimney pots. `shop` (a sign key) gives it a shopfront with a striped awning and the sign; the door looks +z.
static func townhouse(rng: RandomNumberGenerator, wall: Color, shutter: Color, floors: int, w: float, shop: String = "",
		awning: Color = Color.TRANSPARENT) -> Node3D:
	var hs := Node3D.new()
	hs.name = "TownHouse"
	var d := 6.0
	var ground := 3.5
	var storey := 2.9
	var top := ground + storey * (floors - 1)
	var plaster := _mat(wall)
	var trim := _mat(TRIM)
	var slate := _mat(SLATE, true)
	var glass := _mat(Color("24364d"))
	var paint := _mat(shutter)
	var iron := _mat(IRON)
	var stone := _mat(Color("b7a88f"))
	var k := Kit.new()
	k.box(stone, Vector3(w + 0.2, 2.0, d + 0.2), Vector3(0, -0.5, 0))  # the base goes into the ground
	k.box(plaster, Vector3(w, top - 0.5, d), Vector3(0, 0.5 + (top - 0.5) * 0.5, 0))
	k.box(trim, Vector3(w + 0.24, 0.2, d + 0.24), Vector3(0, ground, 0))
	k.box(trim, Vector3(w + 0.5, 0.3, d + 0.5), Vector3(0, top + 0.15, 0))
	# the mansard: four steep slate sides, a flat zinc top
	var m0 := top + 0.3
	var m1 := m0 + 2.0
	var a := Vector2(w * 0.5 + 0.2, d * 0.5 + 0.2)
	var b := a - Vector2(0.95, 0.95)
	k.quad(slate, Vector3(-a.x, m0, a.y), Vector3(a.x, m0, a.y), Vector3(b.x, m1, b.y), Vector3(-b.x, m1, b.y))
	k.quad(slate, Vector3(a.x, m0, -a.y), Vector3(-a.x, m0, -a.y), Vector3(-b.x, m1, -b.y), Vector3(b.x, m1, -b.y))
	k.quad(slate, Vector3(a.x, m0, a.y), Vector3(a.x, m0, -a.y), Vector3(b.x, m1, -b.y), Vector3(b.x, m1, b.y))
	k.quad(slate, Vector3(-a.x, m0, -a.y), Vector3(-a.x, m0, a.y), Vector3(-b.x, m1, b.y), Vector3(-b.x, m1, -b.y))
	k.box(_mat(Color("8996a8")), Vector3(b.x * 2.0 + 0.1, 0.14, b.y * 2.0 + 0.1), Vector3(0, m1, 0))
	var bays := maxi(2, int(round(w / 2.3)))
	for i in bays:
		var x := -w * 0.5 + w * (i + 0.5) / bays
		if i % 2 == 0 or bays < 4:  # dormers on the front slope
			k.box(trim, Vector3(1.0, 1.25, 1.0), Vector3(x, m0 + 0.8, d * 0.5 - 0.25))
			k.box(glass, Vector3(0.66, 0.85, 0.06), Vector3(x, m0 + 0.8, d * 0.5 + 0.26))
			k.box(_mat(SLATE.darkened(0.15)), Vector3(1.2, 0.12, 1.2), Vector3(x, m0 + 1.48, d * 0.5 - 0.22))
		for fl in range(1, floors):  # tall windows with shutters, front and back; a rail on the first floor
			var y := ground + storey * (fl - 1) + storey * 0.5 + 0.05
			for side: float in [1.0, -1.0]:
				var z := side * d * 0.5
				k.box(trim, Vector3(1.04, 1.96, 0.08), Vector3(x, y, z + side * 0.01))
				k.box(glass, Vector3(0.82, 1.74, 0.08), Vector3(x, y, z + side * 0.03))
				k.box(trim, Vector3(0.05, 1.74, 0.1), Vector3(x, y, z + side * 0.03))
				for sx: float in [-1.0, 1.0]:
					k.box(paint, Vector3(0.4, 1.8, 0.06), Vector3(x + sx * 0.74, y, z + side * 0.06))
				if side > 0 and fl == 1:
					k.box(iron, Vector3(1.3, 0.05, 0.34), Vector3(x, y - 0.95, z + 0.2))
					k.box(iron, Vector3(1.3, 0.05, 0.04), Vector3(x, y - 0.45, z + 0.36))
					for bx: float in [-0.62, -0.31, 0.0, 0.31, 0.62]:
						k.box(iron, Vector3(0.03, 0.5, 0.03), Vector3(x + bx, y - 0.7, z + 0.36))
	for cx: float in [-w * 0.3, w * 0.32]:  # chimneys with clay pots
		k.box(_mat(Color("a85a40")), Vector3(0.7, 1.5, 0.5), Vector3(cx, m1 + 0.6, -d * 0.12))
		for px: float in [-0.18, 0.18]:
			k.box(_mat(Color("d98a4f")), Vector3(0.2, 0.36, 0.2), Vector3(cx + px, m1 + 1.5, -d * 0.12))
	var front := d * 0.5
	if shop.is_empty():
		k.box(trim, Vector3(1.4, 2.6, 0.1), Vector3(0, 1.3, front + 0.01))
		k.box(paint, Vector3(1.1, 2.3, 0.1), Vector3(0, 1.15, front + 0.05))
		k.box(_mat(Color("d9a441")), Vector3(0.07, 0.07, 0.07), Vector3(0.38, 1.15, front + 0.12))
		for sx: float in [-1.0, 1.0]:
			if w > 5.0:
				var x := sx * (w * 0.5 - 1.25)
				k.box(trim, Vector3(1.04, 1.7, 0.08), Vector3(x, 1.75, front + 0.01))
				k.box(glass, Vector3(0.82, 1.5, 0.08), Vector3(x, 1.75, front + 0.03))
				for s2: float in [-1.0, 1.0]:
					k.box(paint, Vector3(0.4, 1.56, 0.06), Vector3(x + s2 * 0.74, 1.75, front + 0.06))
	else:  # a shopfront: painted wood, big panes, the name on the fascia, a striped awning
		var wood := _mat(awning.darkened(0.25) if awning.a > 0.0 else Color("2f3a4a"))
		k.box(wood, Vector3(w - 0.5, 3.1, 0.14), Vector3(0, 1.75, front + 0.02))
		for sx: float in [-1.0, 1.0]:
			k.box(glass, Vector3((w - 2.6) * 0.5, 1.7, 0.1), Vector3(sx * ((w - 2.6) * 0.25 + 0.85), 1.55, front + 0.07))
		k.box(_mat(Color("3a2a22")), Vector3(1.1, 2.3, 0.1), Vector3(0, 1.15, front + 0.07))
		k.box(glass, Vector3(0.7, 1.0, 0.1), Vector3(0, 1.6, front + 0.09))
		k.box(trim, Vector3(w - 0.9, 0.6, 0.06), Vector3(0, 2.92, front + 0.1))
		if awning.a > 0.0:
			var stripes := Costume.striped(awning, TRIM, w * 1.4)
			k.box(stripes, Vector3(w - 0.6, 0.05, 1.7), Vector3(0, 2.36, front + 0.9), Vector3(0.3, 0, 0))
			k.box(stripes, Vector3(w - 0.6, 0.3, 0.04), Vector3(0, 1.97, front + 1.7))
		else:  # the bank: columns and a pediment instead
			for cx: float in [-w * 0.36, -w * 0.14, w * 0.14, w * 0.36]:
				k.box(trim, Vector3(0.5, 3.3, 0.5), Vector3(cx, 1.65, front + 0.9))
				Solid.post(hs, 0.3, 3.3, Vector3(cx, 0, front + 0.9))
			k.box(trim, Vector3(w * 0.86, 0.5, 1.5), Vector3(0, 3.55, front + 0.5))
		hs.add_child(word_sign(shop, Vector3(0, 2.92, front + 0.14), 0.0, 62 if shop.length() < 16 else 54, IRON))
	hs.add_child(k.commit("Walls"))
	Solid.box(hs, Vector3(w + 0.2, top + 2.0, d + 0.2), Vector3(0, (top - 1.0) * 0.5 - 0.5 + 0.5, 0))
	hs.set_meta("size", Vector3(w, top, d))
	return hs


## A word of the island on a wall or a board. `key` stays on the node so the gloss can be asked for (T).
static func word_sign(key: String, at: Vector3, yaw: float, font_size: int, colour: Color) -> Label3D:
	var l := Label3D.new()
	l.name = "Sign"
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.text = IslandTongue.say(key, "fr")
	l.set_meta("key", key)
	l.font = Hud.serif()
	l.font_size = font_size
	l.outline_size = 0
	l.modulate = colour
	l.double_sided = false
	l.render_priority = 110  # after the ink effect, so the letters stay sharp
	l.position = at
	l.rotation.y = yaw
	return l


static func _street_plate(key: String, at: Vector3, yaw: float) -> Node3D:
	var n := Node3D.new()
	n.name = "StreetPlate"
	n.position = at
	n.rotation.y = yaw
	n.add_child(Proc.box(Vector3(0.1, 2.6, 0.1), IRON, Vector3(0, 1.3, 0)))
	Solid.post(n, 0.08, 2.6, Vector3.ZERO)
	n.add_child(Proc.box(Vector3(2.5, 0.5, 0.06), Color("2b4f8c"), Vector3(0, 2.5, 0)))
	n.add_child(word_sign(key, Vector3(0, 2.5, 0.04), 0.0, 40, TRIM))
	var back := word_sign(key, Vector3(0, 2.5, -0.04), PI, 40, TRIM)
	n.add_child(back)
	return n


## Pale stone under the square and the streets: flat slabs a finger above the grass.
static func _paving() -> Node3D:
	var n := Node3D.new()
	n.name = "Paving"
	n.set_meta("flat", true)
	var k := Kit.new()
	var slab := _mat(Color("e4d3ae"))
	var disc := CylinderMesh.new()
	disc.top_radius = 13.5
	disc.bottom_radius = 13.5
	disc.height = 0.06
	disc.radial_segments = 28
	disc.rings = 1
	k.mesh(slab, disc, Transform3D(Basis(), Vector3(0, 0.03, 0)))
	k.box(_mat(Color("d8c69c")), Vector3(26.0, 0.06, 5.6), Vector3(-23.0, 0.02, 0))
	k.box(_mat(Color("d8c69c")), Vector3(22.0, 0.06, 5.0), Vector3(23.0, 0.02, 0))
	n.add_child(k.commit("Slabs"))
	return n


static func _fountain() -> Node3D:
	var n := Node3D.new()
	n.name = "Fountain"
	n.add_child(Proc.cyl(FOUNTAIN_R, FOUNTAIN_R + 0.15, 0.7, 12, Color("cdbf9f"), Vector3(0, 0.35, 0)))
	n.add_child(Proc.cyl(FOUNTAIN_R - 0.3, FOUNTAIN_R - 0.3, 0.06, 12, Color("6fb7c9"), Vector3(0, 0.7, 0)))
	n.add_child(Proc.cyl(0.35, 0.5, 2.2, 8, Color("cdbf9f"), Vector3(0, 1.1, 0)))
	n.add_child(Proc.cyl(1.1, 0.4, 0.3, 10, Color("cdbf9f"), Vector3(0, 2.3, 0)))
	n.add_child(Proc.ball(0.32, Color("e0a23a"), Vector3(0, 2.75, 0)))  # a drop of amber on top
	Solid.post(n, FOUNTAIN_R + 0.15, 0.75, Vector3.ZERO)
	Solid.post(n, 0.5, 2.6, Vector3.ZERO)
	return n


## The round column with a little dome where the day's amber rate is posted.
static func _kiosk(at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = "Kiosk"
	n.position = at
	n.add_child(Proc.cyl(0.75, 0.75, 2.9, 10, Color("3f6f5a"), Vector3(0, 1.45, 0)))
	n.add_child(Proc.cyl(0.95, 0.95, 0.16, 10, Color("2f4f42"), Vector3(0, 2.95, 0)))
	n.add_child(Proc.cyl(0.1, 0.85, 0.7, 10, Color("2f4f42"), Vector3(0, 3.38, 0)))
	n.add_child(Proc.box(Vector3(0.9, 1.3, 0.04), TRIM, Vector3(0, 1.7, 0.76)))
	n.add_child(word_sign("AMB_SIGN_KIOSK", Vector3(0, 2.05, 0.79), 0.0, 22, IRON))
	n.add_child(word_sign("AMB_SIGN_RATES", Vector3(0, 1.6, 0.79), 0.0, 26, Color("8c3b3b")))
	Solid.post(n, 0.8, 3.0, Vector3.ZERO)
	return n


## A plane tree clipped to a ball, as they stand round French squares.
static func _tree(rng: RandomNumberGenerator, at: Vector3) -> Node3D:
	var t := Node3D.new()
	t.name = "PlaneTree"
	t.position = at
	var h := rng.randf_range(2.6, 3.1)
	t.add_child(Proc.cyl(0.16, 0.2, h, 6, Color("b9a98c"), Vector3(0, h * 0.5, 0)))
	var crown := Proc.ball(1.5, Color("7fae5a").lerp(Color("a7b85a"), rng.randf() * 0.5), Vector3(0, h + 0.9, 0))
	crown.scale = Vector3(1, 0.8, 1)
	t.add_child(crown)
	Solid.post(t, 0.2, h, Vector3.ZERO)
	return t


static func _lamp(at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = "Lamp"
	n.position = at
	n.add_child(Proc.cyl(0.07, 0.11, 3.2, 6, IRON, Vector3(0, 1.6, 0)))
	n.add_child(Proc.box(Vector3(0.34, 0.46, 0.34), Color("ffe6a8"), Vector3(0, 3.4, 0)))
	n.add_child(Proc.box(Vector3(0.46, 0.08, 0.46), IRON, Vector3(0, 3.68, 0)))
	Solid.post(n, 0.1, 3.2, Vector3.ZERO)
	return n


## The café terrace: round tables under striped parasols.
static func _terrace(isl: Node3D, rng: RandomNumberGenerator) -> void:
	var cafe: Array = SHOPS["cafe"]
	var front := Vector3(sin(float(cafe[1])), 0, cos(float(cafe[1])))
	var side := Vector3(front.z, 0, -front.x)
	for i in 3:
		var t := Node3D.new()
		t.name = "CafeTable"
		t.position = (cafe[0] as Vector3) + front * 4.3 + side * (-2.7 - i * 2.2 + rng.randf() * 0.2)  # clear of the street
		t.add_child(Proc.cyl(0.05, 0.05, 2.9, 6, IRON, Vector3(0, 1.45, 0)))
		t.add_child(Proc.cyl(0.55, 0.55, 0.05, 10, TRIM, Vector3(0, 0.78, 0)))
		t.add_child(Proc.mesh_node(Proc._cyl_mesh(0.05, 1.3, 0.5, 8), Costume.striped(Color("c98a3a"), TRIM, 8.0), Vector3(0, 3.1, 0)))  # well above the tallest hat
		for a: float in [0.6, 3.7]:
			t.add_child(Proc.box(Vector3(0.4, 0.45, 0.4), Color("3f6f5a"), Vector3(cos(a) * 0.95, 0.225, sin(a) * 0.95)))
			Solid.box(t, Vector3(0.4, 0.45, 0.4), Vector3(cos(a) * 0.95, 0.225, sin(a) * 0.95))
		Solid.post(t, 0.55, 0.8, Vector3.ZERO)
		isl.add_child(t)


## The lighthouse on the east cliff: a tapering white tower with amber bands, a gallery and a lantern.
static func _lighthouse() -> Node3D:
	var n := Node3D.new()
	n.name = "Lighthouse"
	n.position = LIGHTHOUSE
	n.add_child(Proc.cyl(3.6, 4.0, 1.2, 12, Color("b7a88f"), Vector3(0, 0.6, 0)))
	var bands := [Color("f6efdc"), Color("d9903a"), Color("f6efdc"), Color("d9903a"), Color("f6efdc")]
	var r := 3.0
	for i in bands.size():
		n.add_child(Proc.cyl(r - 0.28, r, 3.6, 12, bands[i], Vector3(0, 1.2 + 1.8 + i * 3.6, 0)))
		r -= 0.28
	var top := 1.2 + bands.size() * 3.6
	n.add_child(Proc.cyl(2.5, 2.5, 0.25, 12, IRON, Vector3(0, top + 0.12, 0)))
	n.add_child(Proc.cyl(1.2, 1.2, 1.8, 8, Color("ffe6a8"), Vector3(0, top + 1.15, 0)))
	n.add_child(Proc.cyl(0.1, 1.5, 1.2, 8, Color("8c3b3b"), Vector3(0, top + 2.65, 0)))
	n.add_child(Proc.box(Vector3(0.2, 2.2, 1.2), Color("3b5a8c"), Vector3(-2.98, 2.3, 0)))  # the door, towards the town
	var name_plate := word_sign("AMB_SIGN_LIGHTHOUSE", Vector3(-3.12, 4.0, 0), -PI / 2, 60, IRON)
	n.add_child(name_plate)
	Solid.post(n, 4.0, 1.2, Vector3.ZERO)
	Solid.post(n, 3.05, 12.0, Vector3.ZERO)
	return n

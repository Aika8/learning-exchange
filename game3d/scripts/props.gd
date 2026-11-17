## Pattern: Builder — the props of the world as Aika drew them on sheet 25 (docs/design/concepts/25-props.jpg):
## each is one mesh built in code from the palette, with a collider that follows it. Used by the low-poly look
## (ADR-0024); `--pbr` keeps the downloaded models.
class_name Props
extends RefCounted

const IRON := Color("2f2f36")
const ROPE := Color("c9a56a")
const PAPER := Color("f3e9d2")
const TEAL := Color("3f8f8a")
const SIGNS: Array[String] = ["anchor", "quill", "coin", "sail", "loaf"]


static func _m(c: Color) -> Material:
	return Proc.mat(c)


static func _cyl(k: Kit, m: Material, top: float, bottom: float, h: float, at: Vector3, sides: int = 10, rot: Vector3 = Vector3.ZERO) -> void:
	k.mesh(m, Proc._cyl_mesh(top, bottom, h, sides), Transform3D(Basis.from_euler(rot), at))


static func _node(name: String, k: Kit, at: Vector3, yaw: float) -> Node3D:
	var n := Node3D.new()
	n.name = name
	n.position = at
	n.rotation.y = yaw
	n.add_child(k.commit(name))
	return n


## The street lamp: a turned timber post on a plinth, an iron scroll bracket, a brass lantern with a pointed roof.
## The lantern hangs at +z. Only the picture: the caller adds the collider and the light.
static func lamp(k: Kit) -> void:
	var dark := _m(Proc.TIMBER_DARK)
	var wood := _m(Proc.TIMBER)
	var iron := _m(IRON)
	var brass := _m(Proc.BRASS)
	k.box(dark, Vector3(0.34, 0.5, 0.34), Vector3(0, 0.25, 0))
	k.box(wood, Vector3(0.24, 0.5, 0.24), Vector3(0, 0.75, 0))
	k.box(dark, Vector3(0.3, 0.08, 0.3), Vector3(0, 1.02, 0))
	k.box(wood, Vector3(0.18, 2.1, 0.18), Vector3(0, 2.1, 0))
	k.box(dark, Vector3(0.28, 0.1, 0.28), Vector3(0, 3.18, 0))
	_cyl(k, wood, 0.02, 0.1, 0.3, Vector3(0, 3.38, 0), 6)
	k.box(iron, Vector3(0.05, 0.05, 0.7), Vector3(0, 2.75, 0.4))  # the arm
	k.box(iron, Vector3(0.04, 0.04, 0.62), Vector3(0, 2.5, 0.3), Vector3(0.7, 0, 0))  # the scroll under it
	k.box(iron, Vector3(0.03, 0.14, 0.03), Vector3(0, 2.66, 0.68))
	k.box(brass, Vector3(0.3, 0.05, 0.3), Vector3(0, 2.58, 0.68))
	_cyl(k, brass, 0.02, 0.22, 0.2, Vector3(0, 2.7, 0.68), 4, Vector3(0, PI / 4, 0))
	k.box(Proc.mat(Color("ffd98a"), 3.0), Vector3(0.2, 0.34, 0.2), Vector3(0, 2.38, 0.68))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.box(brass, Vector3(0.03, 0.36, 0.03), Vector3(sx * 0.11, 2.38, 0.68 + sz * 0.11))
	k.box(brass, Vector3(0.26, 0.05, 0.26), Vector3(0, 2.19, 0.68))


## The market stall: a plank counter, four posts, a striped awning with a scalloped edge. Picture only.
static func stall(k: Kit, colour: Color) -> void:
	var wood := _m(Proc.TIMBER)
	var dark := _m(Proc.TIMBER_DARK)
	k.box(wood, Vector3(2.6, 0.9, 1.4), Vector3(0, 0.45, 0))
	k.box(dark, Vector3(2.8, 0.1, 1.6), Vector3(0, 0.95, 0))
	for i in 5:
		k.box(dark, Vector3(0.04, 0.8, 0.02), Vector3(-1.04 + i * 0.52, 0.45, 0.71))
	for x: float in [-1.3, 1.3]:
		k.box(dark, Vector3(0.1, 2.4, 0.1), Vector3(x, 1.2, 0.9))
		k.box(dark, Vector3(0.1, 2.8, 0.1), Vector3(x, 1.4, -0.66))
	k.box(dark, Vector3(2.7, 0.08, 0.08), Vector3(0, 2.4, 0.9))
	k.box(dark, Vector3(2.7, 0.08, 0.08), Vector3(0, 2.8, -0.66))
	var cream := _m(PAPER)
	var paint := _m(colour)
	for i in 8:  # eight stripes, each ending in a scallop
		var x := -1.4 + (i + 0.5) * 0.35
		var m: Material = paint if i % 2 == 0 else cream
		k.box(m, Vector3(0.35, 0.05, 1.75), Vector3(x, 2.66, 0.14), Vector3(0.25, 0, 0))
		_cyl(k, m, 0.175, 0.175, 0.05, Vector3(x, 2.36, 1.0), 8, Vector3(PI / 2, 0, 0))


static func crate(at: Vector3, yaw: float, size: float = 0.9) -> Node3D:
	var k := Kit.new()
	var wood := _m(Proc.TIMBER)
	var dark := _m(Proc.TIMBER_DARK)
	var iron := _m(IRON)
	var h := size * 0.5
	k.box(wood, Vector3.ONE * size, Vector3(0, h, 0))
	var t := size * 0.11
	for a: float in [-1.0, 1.0]:
		for b: float in [-1.0, 1.0]:
			k.box(dark, Vector3(t, size + 0.04, t), Vector3(a * (h - t * 0.4), h, b * (h - t * 0.4)))
			k.box(dark, Vector3(size + 0.04, t, t), Vector3(0, h + a * (h - t * 0.4), b * (h - t * 0.4)))
			k.box(dark, Vector3(t, t, size + 0.04), Vector3(a * (h - t * 0.4), h + b * (h - t * 0.4), 0))
			for c: float in [-1.0, 1.0]:
				k.box(iron, Vector3.ONE * t * 1.25, Vector3(a * h, h + b * h, c * h) * 0.97 + Vector3(0, h * 0.03, 0))
	for s: float in [-1.0, 1.0]:  # a brace across two faces
		k.box(dark, Vector3(t * 0.8, size * 1.2, 0.03), Vector3(0, h, s * (h + 0.01)), Vector3(0, 0, s * 0.78))
	var n := _node("Crate", k, at, yaw)
	n.set_meta("solid", Solid.box(n, Vector3.ONE * size, Vector3(0, h, 0)))
	return n


static func barrel(at: Vector3, yaw: float = 0.0) -> Node3D:
	var k := Kit.new()
	var wood := _m(Proc.TIMBER)
	var iron := _m(IRON)
	_cyl(k, wood, 0.43, 0.34, 0.36, Vector3(0, 0.18, 0), 12)
	_cyl(k, wood, 0.43, 0.43, 0.3, Vector3(0, 0.51, 0), 12)
	_cyl(k, wood, 0.34, 0.43, 0.36, Vector3(0, 0.84, 0), 12)
	for y: float in [0.1, 0.36, 0.66, 0.92]:
		var r := 0.36 if y < 0.2 or y > 0.9 else 0.445
		_cyl(k, iron, r + 0.012, r + 0.012, 0.06, Vector3(0, y, 0), 12)
	_cyl(k, _m(Proc.TIMBER_DARK), 0.31, 0.31, 0.02, Vector3(0, 1.0, 0), 12)
	var n := _node("Barrel", k, at, yaw)
	n.set_meta("solid", Solid.post(n, 0.44, 1.02, Vector3.ZERO))
	return n


## Grandfather's chest: banded timber, a rounded lid, brass edges and a padlock.
static func chest(at: Vector3, yaw: float) -> Node3D:
	var k := Kit.new()
	var wood := _m(Proc.TIMBER)
	var brass := _m(Proc.BRASS)
	k.box(wood, Vector3(1.2, 0.5, 0.8), Vector3(0, 0.25, 0))
	var lid := Proc._cyl_mesh(0.4, 0.4, 1.2, 10)
	k.mesh(wood, lid, Transform3D(Basis.from_euler(Vector3(0, 0, PI / 2)).scaled(Vector3(1, 0.55, 1)), Vector3(0, 0.5, 0)))
	for x: float in [-0.56, 0.0, 0.56]:
		k.box(brass, Vector3(0.09, 0.52, 0.84), Vector3(x, 0.25, 0))
		k.mesh(brass, Proc._cyl_mesh(0.415, 0.415, 0.09, 10), Transform3D(Basis.from_euler(Vector3(0, 0, PI / 2)).scaled(Vector3(1, 0.55, 1)), Vector3(x, 0.5, 0)))
	k.box(brass, Vector3(1.24, 0.06, 0.84), Vector3(0, 0.5, 0))
	k.box(_m(IRON), Vector3(0.16, 0.2, 0.06), Vector3(0, 0.4, 0.43))
	var n := _node("Chest", k, at, yaw)
	n.set_meta("solid", Solid.box(n, Vector3(1.2, 0.72, 0.8), Vector3(0, 0.36, 0)))
	return n


static func rope_coil(at: Vector3) -> Node3D:
	var k := Kit.new()
	var rope := _m(ROPE)
	for i in 3:
		var ring := TorusMesh.new()
		ring.inner_radius = 0.22 - i * 0.02
		ring.outer_radius = 0.42 - i * 0.02
		ring.rings = 14
		ring.ring_segments = 6
		k.mesh(rope, ring, Transform3D(Basis().scaled(Vector3(1, 0.8, 1)), Vector3(0, 0.08 + i * 0.14, 0)))
	k.box(rope, Vector3(0.08, 0.08, 0.5), Vector3(0.36, 0.05, 0.3), Vector3(0, 0.5, 0))
	var n := _node("RopeCoil", k, at, 0.0)
	n.set_meta("solid", Solid.post(n, 0.42, 0.46, Vector3.ZERO))
	return n


static func bollard(at: Vector3) -> Node3D:
	var k := Kit.new()
	var dark := _m(Proc.TIMBER_DARK)
	_cyl(k, dark, 0.17, 0.2, 0.5, Vector3(0, 0.25, 0), 10)
	_cyl(k, dark, 0.27, 0.19, 0.12, Vector3(0, 0.55, 0), 10)
	_cyl(k, dark, 0.2, 0.27, 0.1, Vector3(0, 0.66, 0), 10)
	var n := _node("Bollard", k, at, 0.0)
	n.set_meta("solid", Solid.post(n, 0.26, 0.7, Vector3.ZERO))
	return n


## An anchor standing against something: the sign of the Anchor Order by Mara's place.
static func anchor(at: Vector3, yaw: float) -> Node3D:
	var k := Kit.new()
	var iron := _m(IRON)
	k.box(iron, Vector3(0.09, 1.3, 0.09), Vector3(0, 0.75, 0))
	k.box(iron, Vector3(0.6, 0.08, 0.08), Vector3(0, 1.25, 0))
	var ring := TorusMesh.new()
	ring.inner_radius = 0.08
	ring.outer_radius = 0.13
	ring.rings = 10
	ring.ring_segments = 5
	k.mesh(iron, ring, Transform3D(Basis.from_euler(Vector3(PI / 2, 0, 0)), Vector3(0, 1.5, 0)))
	for sx: float in [-1.0, 1.0]:
		k.box(iron, Vector3(0.5, 0.1, 0.1), Vector3(sx * 0.2, 0.2, 0), Vector3(0, 0, sx * 0.55))
		k.box(iron, Vector3(0.2, 0.2, 0.06), Vector3(sx * 0.42, 0.38, 0), Vector3(0, 0, sx * 0.9))
	var n := _node("Anchor", k, at, yaw)
	n.rotation.x = -0.2  # leaning back
	n.set_meta("solid", Solid.box(n, Vector3(0.95, 1.6, 0.3), Vector3(0, 0.8, 0)))
	return n


## What goes on the notice board: a little roof beam and pinned papers. `k` already holds the board itself.
static func notice_papers(k: Kit, width: float, y: float, z: float) -> void:
	var dark := _m(Proc.TIMBER_DARK)
	k.box(dark, Vector3(width + 0.5, 0.12, 0.3), Vector3(0, y + 0.95, z - 0.06))
	var paper := _m(PAPER)
	var places := [Vector3(-0.72, 0.28, 0.1), Vector3(-0.2, -0.3, -0.08), Vector3(0.45, 0.3, 0.06), Vector3(0.78, -0.32, -0.12)]
	for i in places.size():
		var p: Vector3 = places[i]
		k.box(paper, Vector3(0.42, 0.52, 0.015), Vector3(p.x, y + p.y, z + 0.085), Vector3(0, 0, p.z))
		k.box(_m(Color("8a3b32")), Vector3(0.05, 0.05, 0.02), Vector3(p.x, y + p.y + 0.2, z + 0.1))
		for line in 3:
			k.box(dark, Vector3(0.28, 0.02, 0.005), Vector3(p.x, y + p.y + 0.08 - line * 0.1, z + 0.096), Vector3(0, 0, p.z))


## The brass scales and the ledger for a stall counter.
static func scales(k: Kit, at: Vector3) -> void:
	var brass := _m(Proc.BRASS)
	_cyl(k, brass, 0.1, 0.14, 0.05, at + Vector3(0, 0.025, 0), 8)
	_cyl(k, brass, 0.02, 0.03, 0.5, at + Vector3(0, 0.3, 0), 6)
	k.box(brass, Vector3(0.6, 0.03, 0.03), at + Vector3(0, 0.52, 0))
	for sx: float in [-1.0, 1.0]:
		k.box(brass, Vector3(0.01, 0.24, 0.01), at + Vector3(sx * 0.28, 0.4, 0))
		_cyl(k, brass, 0.13, 0.08, 0.04, at + Vector3(sx * 0.28, 0.27, 0), 8)


static func ledger(k: Kit, at: Vector3) -> void:
	k.box(_m(Color("7a4a32")), Vector3(0.42, 0.1, 0.32), at + Vector3(0, 0.05, 0), Vector3(0, 0.3, 0))
	k.box(_m(PAPER), Vector3(0.39, 0.07, 0.3), at + Vector3(0.012, 0.05, 0.004), Vector3(0, 0.3, 0))
	k.box(_m(Proc.BRASS), Vector3(0.05, 0.11, 0.08), at + Vector3(0.2, 0.05, 0.06), Vector3(0, 0.3, 0))


## A hanging signboard with a picture, no words: `kind` is one of SIGNS. The plaque hangs in the x plane at z ≈ 0.7.
static func signboard(k: Kit, kind: String) -> void:
	var iron := _m(IRON)
	var dark := _m(Proc.TIMBER_DARK)
	var brass := _m(Proc.BRASS)
	k.box(iron, Vector3(0.05, 0.05, 1.15), Vector3(0, 0.35, 0.58))
	_cyl(k, iron, 0.0, 0.05, 0.14, Vector3(0, 0.35, 1.22), 6, Vector3(PI / 2, 0, 0))
	for z: float in [0.45, 0.95]:
		k.box(iron, Vector3(0.02, 0.2, 0.02), Vector3(0, 0.23, z))
	k.box(dark, Vector3(0.08, 0.7, 0.78), Vector3(0, -0.22, 0.7))
	k.box(_m(Proc.TIMBER), Vector3(0.1, 0.58, 0.66), Vector3(0, -0.22, 0.7))
	var c := Vector3(0, -0.22, 0.7)
	for sx: float in [-1.0, 1.0]:  # the picture on both faces
		var x := sx * 0.06
		match kind:
			"anchor":
				k.box(iron, Vector3(0.02, 0.36, 0.05), c + Vector3(x, 0.0, 0))
				k.box(iron, Vector3(0.02, 0.04, 0.22), c + Vector3(x, 0.13, 0))
				k.box(iron, Vector3(0.02, 0.05, 0.2), c + Vector3(x, -0.14, -0.08), Vector3(0.6, 0, 0))
				k.box(iron, Vector3(0.02, 0.05, 0.2), c + Vector3(x, -0.14, 0.08), Vector3(-0.6, 0, 0))
			"quill":
				k.box(_m(PAPER), Vector3(0.02, 0.42, 0.1), c + Vector3(x, 0.02, 0), Vector3(0.5, 0, 0))
				k.box(iron, Vector3(0.022, 0.46, 0.02), c + Vector3(x, 0.0, 0), Vector3(0.5, 0, 0))
			"coin":
				_cyl(k, brass, 0.2, 0.2, 0.03, c + Vector3(x, 0, 0), 12, Vector3(0, 0, PI / 2))
				_cyl(k, _m(Proc.BRASS.darkened(0.25)), 0.13, 0.13, 0.035, c + Vector3(x, 0, 0), 12, Vector3(0, 0, PI / 2))
			"sail":
				k.box(_m(Proc.TIMBER_DARK), Vector3(0.02, 0.07, 0.36), c + Vector3(x, -0.17, 0))
				k.box(_m(Proc.TIMBER_DARK), Vector3(0.02, 0.36, 0.03), c + Vector3(x, 0.02, 0))
				k.box(_m(PAPER), Vector3(0.02, 0.24, 0.24), c + Vector3(x, 0.05, 0.0))
			_:
				_cyl(k, _m(Color("d9a15a")), 0.11, 0.11, 0.03, c + Vector3(x, 0, 0), 10, Vector3(0, 0, PI / 2))
				k.box(_m(Color("d9a15a")), Vector3(0.03, 0.2, 0.3), c + Vector3(x, 0, 0))
				for i in 3:
					k.box(_m(Color("a8703a")), Vector3(0.032, 0.14, 0.025), c + Vector3(x, 0.02, -0.1 + i * 0.1), Vector3(0.5, 0, 0))

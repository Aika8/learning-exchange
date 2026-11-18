## Pattern: Factory (procedural art) — every mesh of the world is built here from primitives, so the art is code,
## reviewable and ours (CC0, game3d/ASSETS.md). Look: docs/design/game3d-style.md. See docs/adr/0017-game3d-stylised-lowpoly-godot.md
class_name Proc
extends RefCounted

const GRASS := Color("7fb069")
const GRASS_DARK := Color("4f7f52")
const ROCK := Color("b07a57")
const ROCK_DARK := Color("6e4a3b")
const CRYSTAL := Color("7fe3ff")
const TIMBER := Color("8a5a3c")
const TIMBER_DARK := Color("5e3b28")
const CANVAS := Color("f3e9d2")
const BRASS := Color("d9a441")
const PLASTER := Color("efe2c8")
const ROOF_RED := Color("c4643f")
const ROOF_TEAL := Color("3f8f8a")

const SHIP_SCALE := 0.46
const SHIP_YAW := PI / 2
const SHIP_LIFT := -0.6

static var _materials: Dictionary = {}


## Flat toon material, cached per colour so the renderer can batch.
static func mat(color: Color, emission: float = 0.0) -> BaseMaterial3D:
	var key := "%s/%s" % [color.to_html(), emission]
	if _materials.has(key):
		return _materials[key]
	if emission == 0.0 and Assets.available():
		var p := _pbr_for(color)
		if p != null:
			_materials[key] = p
			return p
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.75
	if color == BRASS:
		m.metallic = 1.0
		m.roughness = 0.35
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	_materials[key] = m
	return m


## Palette colour → PBR texture set (ADR-0019). Unknown colours keep a plain material.
static func _pbr_for(color: Color) -> BaseMaterial3D:
	if color == TIMBER:
		return Assets.pbr("weathered_planks", Color.WHITE, 0.6)
	if color == TIMBER_DARK:
		return Assets.pbr("dark_wood", Color.WHITE, 0.8)
	if color.is_equal_approx(PLASTER) or (absf(color.h - PLASTER.h) < 0.02 and absf(color.s - PLASTER.s) < 0.05):
		return Assets.pbr("plastered_wall_02", Color(color.v / PLASTER.v, color.v / PLASTER.v, color.v / PLASTER.v), 0.4)
	if color == ROOF_RED or color == Color("d08a3b"):
		return Assets.pbr("clay_roof_tiles_02", Color.WHITE, 0.6)
	if color == ROOF_TEAL:
		return Assets.pbr("clay_roof_tiles_02", Color("7fb0ab"), 0.6)
	if color == ROCK or color == ROCK_DARK:
		return Assets.pbr("mossy_rock", Color.WHITE, 0.3)
	if color == Color("cdb898") or color == Color("d8c7a6"):
		return Assets.pbr("cobblestone_floor_04", Color.WHITE, 0.35)
	return null


## Terrain material for floating islands: grass on tops, rock on the sides (shaders/terrain.gdshader).
static func terrain_mat() -> Material:
	if not Assets.available():
		return vertex_mat()
	if _materials.has("terrain"):
		return _materials["terrain"]
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/terrain.gdshader")
	for k in ["diff", "nor", "arm"]:
		var map: String = "nor_gl" if k == "nor" else k
		m.set_shader_parameter("grass_" + k, Assets.tex("leafy_grass", map))
		m.set_shader_parameter("rock_" + k, Assets.tex("rock_face_03", map))
	_materials["terrain"] = m
	return m


static func vertex_mat() -> StandardMaterial3D:
	if _materials.has("vertex"):
		return _materials["vertex"]
	var m := StandardMaterial3D.new()
	m.roughness = 0.9
	m.vertex_color_use_as_albedo = true
	_materials["vertex"] = m
	return m


static func mesh_node(mesh: Mesh, material: Material, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	return mi


static func box(size: Vector3, color: Color, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return mesh_node(b, mat(color), pos)


static func cyl(top: float, bottom: float, h: float, sides: int, color: Color, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = sides
	c.rings = 1
	return mesh_node(c, mat(color), pos)


static func ball(r: float, color: Color, pos: Vector3 = Vector3.ZERO, emission: float = 0.0) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 10
	s.rings = 6
	return mesh_node(s, mat(color, emission), pos)


## Floating island: flat grassy cap, overhanging lip, craggy underside tapering to a tip. Flat-shaded, vertex colours.
## `bumps` > 0 makes small hills on the cap (only for islands nobody walks on).
static func island_mesh(radius: float, depth: float, seed_value: int, bumps: float = 0.0) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var sides := 30
	# rings: [radius factor, y, colour]
	var rings: Array = [
		[0.0, 0.0, GRASS], [0.55, 0.0, GRASS], [0.92, 0.0, GRASS], [1.0, -0.35, GRASS_DARK],
		[0.97, -1.6, ROCK], [0.82, -depth * 0.3, ROCK], [0.6, -depth * 0.55, ROCK.darkened(0.1)],
		[0.34, -depth * 0.8, ROCK_DARK], [0.0, -depth, ROCK_DARK]]
	var jitter: Array[PackedFloat32Array] = []
	for ri in rings.size():
		var row := PackedFloat32Array()
		for s in sides:
			var j := 1.0 + rng.randf_range(-0.07, 0.07) if ri >= 3 else 1.0 + rng.randf_range(-0.03, 0.03)
			row.append(j)
		jitter.append(row)
	var shape := PackedFloat32Array()  # global outline wobble, same for every ring
	for s in sides:
		shape.append(1.0 + 0.12 * sin(s * 0.62 + seed_value) + 0.06 * sin(s * 1.7 + seed_value * 0.3))
	var pts: Array[PackedVector3Array] = []
	for ri in rings.size():
		var row := PackedVector3Array()
		for s in sides:
			var a := TAU * s / sides
			var r: float = radius * float(rings[ri][0]) * shape[s] * jitter[ri][s]
			var y: float = float(rings[ri][1])
			if ri >= 4 and ri < rings.size() - 1:
				y += rng.randf_range(-1.0, 1.0) * depth * 0.06
			if ri == 1 and bumps > 0.0:
				y += maxf(0.0, sin(a * 3.0 + seed_value)) * bumps
			row.append(Vector3(cos(a) * r, y, sin(a) * r))
		pts.append(row)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0xFFFFFFFF)
	for ri in rings.size() - 1:
		var c0: Color = rings[ri][2]
		var c1: Color = rings[ri + 1][2]
		for s in sides:
			var n := (s + 1) % sides
			var a0 := pts[ri][s]
			var a1 := pts[ri][n]
			var b0 := pts[ri + 1][s]
			var b1 := pts[ri + 1][n]
			var tint := 1.0 + rng.randf_range(-0.05, 0.05)
			var ca := Color(c0.r * tint, c0.g * tint, c0.b * tint)
			var cb := Color(c1.r * tint, c1.g * tint, c1.b * tint)
			# rings go outward on the cap and inward underneath; winding is fixed below by normal direction
			_tri(st, a0, b0, a1, ca, cb, ca)
			_tri(st, a1, b0, b1, ca, cb, cb)
	st.generate_normals()
	return st.commit()


## How far the flat, walkable cap of an island reaches in direction `angle` (atan2(z, x)); follows the outline of
## whichever mesh is in use, so fences, the navmesh and the audit agree with the ground.
static func cap_radius(radius: float, seed_value: int, angle: float) -> float:
	if Assets.available():
		return radius * 0.97 * (7.0 / 7.8) * (1.0  # the last flat ring of island_mesh_hd
			 + 0.12 * sin(angle * 6.0 + seed_value) + 0.06 * sin(angle * 17.0 + seed_value * 0.3))
	var s := fposmod(angle, TAU) / TAU * 30.0  # low-poly island: 30 sides, the outline is per side
	var lo := 1.0e9
	for k: int in [int(floor(s)) % 30, int(ceil(s)) % 30]:
		lo = minf(lo, 1.0 + 0.12 * sin(k * 0.62 + seed_value) + 0.06 * sin(k * 1.7 + seed_value * 0.3))
	return radius * 0.92 * 0.97 * lo * cos(PI / 30.0)


## Dense island for the PBR look (ADR-0019): 120 sides, 26 rings, noise-carved cliffs with ledges (strata) and a
## grass lip that rolls over the edge. Cap stays flat at y=0 inside 0.9 radius so walking and placement are unchanged.
static func island_mesh_hd(radius: float, depth: float, seed_value: int, bumps: float = 0.0) -> ArrayMesh:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.frequency = 0.08
	n.fractal_octaves = 4
	var sides := 120
	var rings := 26
	var pts: Array[PackedVector3Array] = []
	for ri in rings + 1:
		var t := float(ri) / rings  # 0 = centre of the cap, 1 = bottom tip
		var row := PackedVector3Array()
		for s in sides:
			var a := TAU * s / sides
			var dir := Vector2(cos(a), sin(a))
			var outline := 1.0 + 0.12 * sin(s * TAU / sides * 6.0 + seed_value) + 0.06 * sin(s * TAU / sides * 17.0 + seed_value * 0.3)
			var r: float
			var y: float
			if t <= 0.3:  # cap: flat disc out to 0.9 r, then a rounded lip
				var k := t / 0.3
				r = radius * (k * 0.97)
				y = 0.0
				if k > 0.93:
					y = -(k - 0.93) / 0.07 * 0.5
				if bumps > 0.0 and k > 0.4 and k < 0.85:
					y += maxf(0.0, sin(a * 3.0 + seed_value)) * bumps * sin((k - 0.4) / 0.45 * PI)
			else:  # body: tapering cone with stepped ledges
				var k := (t - 0.3) / 0.7
				var taper := pow(1.0 - k, 0.85)
				var strata: float = 0.06 * floor(k * 9.0 + n.get_noise_2d(a * 3.0, 0.0) * 1.5) / 9.0
				r = radius * (0.97 * taper + strata)
				r *= 1.0 + 0.22 * n.get_noise_3d(dir.x * 9.0, k * 14.0, dir.y * 9.0) * (1.0 - k * 0.5)
				y = -0.5 - k * depth + n.get_noise_2d(dir.x * 20.0 + dir.y * 7.0, k * 5.0) * depth * 0.05 * (1.0 - k)
			r *= outline if t > 0.0 else 1.0
			row.append(Vector3(dir.x * r, y, dir.y * r))
		pts.append(row)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ri in rings:
		for s in sides:
			var m := (s + 1) % sides
			_tri(st, pts[ri][s], pts[ri + 1][s], pts[ri][m], Color.WHITE, Color.WHITE, Color.WHITE)
			_tri(st, pts[ri][m], pts[ri + 1][s], pts[ri + 1][m], Color.WHITE, Color.WHITE, Color.WHITE)
	st.index()  # weld shared vertices so the rock reads smooth, not faceted
	st.generate_normals()
	var im := ImporterMesh.new()  # LODs: far islands and the underside cost a fraction of the triangles
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, st.commit_to_arrays())
	im.generate_lods(25.0, 60.0, [])
	return im.get_mesh()


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	if a.distance_squared_to(b) < 1e-6 or a.distance_squared_to(c) < 1e-6 or b.distance_squared_to(c) < 1e-6:
		return
	# Godot front faces are clockwise seen from outside; make the face normal point away from the island axis or up.
	var n := (b - a).cross(c - a)
	var centre := (a + b + c) / 3.0
	var out := Vector3(centre.x, 0.0, centre.z)
	if centre.y > -0.01 and absf(n.normalized().y) > 0.5:
		out = Vector3.UP
	if n.dot(out) > 0.0:
		var t := b
		b = c
		c = t
		var tc := cb
		cb = cc
		cc = tc
	st.set_color(ca)
	st.add_vertex(a)
	st.set_color(cb)
	st.add_vertex(b)
	st.set_color(cc)
	st.add_vertex(c)


## Glowing ether crystals hanging under an island (lore: эфирит keeps islands afloat).
static func crystals(parent: Node3D, radius: float, depth: float, count: int, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in count:
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.05, 0.45) * radius
		var h := rng.randf_range(2.0, 5.5) * radius / 20.0
		var c := cyl(0.0, h * 0.28, h, 5, CRYSTAL, Vector3(cos(a) * r, -depth * (0.55 + 0.4 * (1.0 - r / radius)), sin(a) * r))
		c.material_override = mat(CRYSTAL, 2.2)
		c.rotation = Vector3(PI + rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3))
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(c)


static func tree(rng: RandomNumberGenerator) -> Node3D:
	var t := Node3D.new()
	var h := rng.randf_range(2.2, 4.0)
	t.add_child(cyl(0.18, 0.26, h * 0.45, 5, TIMBER, Vector3(0, h * 0.22, 0)))
	var green := GRASS_DARK.lerp(Color("9cc46b"), rng.randf())
	for k in 3:
		var r := h * (0.42 - k * 0.1)
		t.add_child(cyl(0.0, r, h * 0.42, 7, green.lightened(k * 0.06), Vector3(0, h * (0.45 + k * 0.2), 0)))
	return t


## Round leafy tree for the harbour (a squashed ball on a trunk).
static func round_tree(rng: RandomNumberGenerator) -> Node3D:
	var t := Node3D.new()
	var h := rng.randf_range(2.0, 3.0)
	t.add_child(cyl(0.16, 0.22, h, 5, TIMBER, Vector3(0, h * 0.5, 0)))
	var crown := ball(rng.randf_range(1.1, 1.6), Color("8fbf5e").lerp(Color("cfa94a"), rng.randf() * 0.35), Vector3(0, h + 0.6, 0))
	crown.scale = Vector3(1, 0.85, 1)
	t.add_child(crown)
	return t


## The Wind Exchange: a round-towered windmill with four canvas blades on a stone base, a gallery, framed windows
## and a porch. Colliders follow the tapering base and tower. Returns the node; the blades are the child "Blades".
static func windmill() -> Node3D:
	var w := Node3D.new()
	w.name = "Windmill"
	var k := Kit.new()
	var plaster := mat(PLASTER)
	var dark := mat(TIMBER_DARK)
	var brass := mat(BRASS)
	var glow := mat(Color("ffd27a"), 1.2)
	k.mesh(mat(ROCK), _cyl_mesh(4.2, 5.4, 2.0, 32), Transform3D(Basis(), Vector3(0, 1.0, 0)))
	k.mesh(plaster, _cyl_mesh(3.4, 4.6, 11.0, 32), Transform3D(Basis(), Vector3(0, 7.5, 0)))
	for y: float in [2.1, 6.0, 12.6]:  # timber bands round the tower
		var r := lerpf(4.6, 3.4, (y - 2.0) / 11.0) + 0.06
		k.mesh(dark, _cyl_mesh(r, r + 0.03, 0.32, 32), Transform3D(Basis(), Vector3(0, y, 0)))
	k.mesh(dark, _cyl_mesh(5.0, 4.9, 0.18, 32), Transform3D(Basis(), Vector3(0, 6.25, 0)))  # the gallery
	for i in 24:
		var a := TAU * i / 24.0
		k.box(dark, Vector3(0.09, 0.9, 0.09), Vector3(sin(a) * 4.85, 6.8, cos(a) * 4.85))
	k.mesh(dark, _cyl_mesh(4.92, 4.92, 0.08, 32), Transform3D(Basis(), Vector3(0, 7.25, 0)))
	k.mesh(brass, _cyl_mesh(3.6, 3.6, 0.5, 32), Transform3D(Basis(), Vector3(0, 13.0, 0)))
	k.mesh(mat(ROOF_TEAL), _cyl_mesh(0.0, 4.4, 4.5, 32), Transform3D(Basis(), Vector3(0, 15.4, 0)))
	var knob := SphereMesh.new()
	knob.radius = 0.45
	knob.height = 0.9
	k.mesh(mat(BRASS, 0.6), knob, Transform3D(Basis(), Vector3(0, 17.9, 0)))
	# porch facing +z: stone surround, double door, lintel, two steps
	k.box(mat(ROCK), Vector3(3.4, 4.1, 0.9), Vector3(0, 2.05, 4.5))
	k.box(dark, Vector3(2.4, 3.2, 0.3), Vector3(0, 1.9, 4.9))
	k.box(brass, Vector3(0.06, 3.2, 0.32), Vector3(0, 1.9, 4.91))
	for x: float in [-0.3, 0.3]:
		k.box(brass, Vector3(0.1, 0.1, 0.1), Vector3(x, 1.8, 5.08))
	k.box(brass, Vector3(3.0, 0.35, 1.0), Vector3(0, 4.25, 4.55))
	k.box(mat(Color("cdb898")), Vector3(4.2, 0.16, 1.0), Vector3(0, 0.38, 5.4))
	for i in 6:
		var a := TAU * (i + 0.5) / 6.0
		var out := Vector3(sin(a), 0, cos(a))
		var side := Vector3(cos(a), 0, -sin(a))
		var at := out * 4.0 + Vector3(0, 9.0, 0)
		var rot := Vector3(0, a, 0)
		k.box(glow, Vector3(0.8, 1.3, 0.2), at, rot)
		k.box(dark, Vector3(1.0, 0.1, 0.3), at + Vector3(0, 0.7, 0), rot)
		k.box(dark, Vector3(1.2, 0.1, 0.42), at + Vector3(0, -0.7, 0), rot)
		k.box(dark, Vector3(0.06, 1.3, 0.26), at, rot)
		for sx: float in [-1.0, 1.0]:
			k.box(dark, Vector3(0.1, 1.5, 0.3), at + side * sx * 0.45, rot)
			k.box(mat(ROOF_TEAL), Vector3(0.4, 1.3, 0.06), at + side * sx * 0.72 + out * 0.03, rot)
	w.add_child(k.commit("Tower"))
	Solid.convex(w, _frustum(5.4, 4.2, 0.0, 2.0))
	Solid.convex(w, _frustum(4.6, 3.4, 2.0, 13.0))
	Solid.box(w, Vector3(3.4, 4.1, 0.9), Vector3(0, 2.05, 4.5))
	Solid.box(w, Vector3(4.2, 0.16, 1.0), Vector3(0, 0.38, 5.4))
	var hub := Node3D.new()
	hub.name = "Blades"
	hub.position = Vector3(0, 12.0, 4.3)
	hub.add_child(cyl(0.6, 0.6, 1.2, 12, TIMBER_DARK, Vector3.ZERO))
	(hub.get_child(0) as Node3D).rotation.x = PI / 2
	for i in 4:
		var arm := Node3D.new()
		arm.rotation.z = TAU * i / 4.0 + 0.3
		arm.add_child(box(Vector3(0.35, 9.0, 0.25), TIMBER, Vector3(0, 4.7, 0.5)))
		arm.add_child(box(Vector3(2.1, 6.8, 0.08), CANVAS, Vector3(1.2, 5.4, 0.6)))
		for j in 5:  # the lattice the canvas is laced to
			arm.add_child(box(Vector3(2.2, 0.08, 0.1), TIMBER_DARK, Vector3(1.2, 2.4 + j * 1.5, 0.66)))
		hub.add_child(arm)
	w.add_child(hub)
	return w


static func _cyl_mesh(top: float, bottom: float, h: float, sides: int) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = sides
	c.rings = 1
	return c


## Corner points of a tapering round solid (for a convex collider).
static func _frustum(bottom: float, top: float, y0: float, y1: float) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(Vector3(cos(a) * bottom, y0, sin(a) * bottom))
		pts.append(Vector3(cos(a) * top, y1, sin(a) * top))
	return pts


## Height of an island's cap at (x, z) in the island's own space: 0 on a flat island, the hills when `bumps` > 0.
## Follows the rings of whichever mesh is in use, so things can be stood on the ground while the world is built.
static func cap_height(radius: float, seed_value: int, bumps: float, x: float, z: float) -> float:
	if bumps <= 0.0:
		return 0.0
	var a := atan2(z, x)
	var d := Vector2(x, z).length()
	var hill := maxf(0.0, sin(a * 3.0 + seed_value)) * bumps
	if not Assets.available():
		var k := d / radius
		return hill * k / 0.55 if k < 0.55 else hill * clampf(1.0 - (k - 0.55) / 0.37, 0.0, 1.0)
	var outline := 1.0 + 0.12 * sin(a * 6.0 + seed_value) + 0.06 * sin(a * 17.0 + seed_value * 0.3)
	var f := d / (radius * 0.97 * outline) * 7.8  # rings of island_mesh_hd lie at k = i / 7.8
	var i := floorf(f)
	var ys: Array[float] = []
	for ring: float in [i, i + 1.0]:
		var k := ring / 7.8
		ys.append(hill * sin((k - 0.4) / 0.45 * PI) if k > 0.4 and k < 0.85 and ring <= 7.0 else 0.0)
	return lerpf(ys[0], ys[1], f - i)


## Ship hull lofted from U-shaped cross-sections, bow at -z. Flat shaded, two timber tones.
static func hull_mesh(length: float, width: float, height: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0xFFFFFFFF)
	var slices := 10
	var profile := [Vector2(-1.0, 0.0), Vector2(-0.95, -0.45), Vector2(-0.6, -0.85), Vector2(0.0, -1.0),
		Vector2(0.6, -0.85), Vector2(0.95, -0.45), Vector2(1.0, 0.0)]
	var secs: Array[PackedVector3Array] = []
	for i in slices + 1:
		var t := float(i) / slices  # 0 = stern, 1 = bow
		var z := lerpf(length * 0.5, -length * 0.5, t)
		var wf := sin(clampf(t * 1.15, 0.0, 1.0) * PI * 0.5 + 0.35) if t < 0.6 else cos((t - 0.6) / 0.4 * PI * 0.5)
		wf = maxf(wf, 0.02)
		var lift := 0.0 if t < 0.75 else (t - 0.75) * height * 1.4
		var row := PackedVector3Array()
		for p: Vector2 in profile:
			row.append(Vector3(p.x * width * 0.5 * wf, p.y * height * (0.5 + 0.5 * wf) + lift, z))
		secs.append(row)
	for i in slices:
		for k in profile.size() - 1:
			var c := TIMBER if k % 2 == 0 else TIMBER.darkened(0.12)
			var a0 := secs[i][k]
			var a1 := secs[i][k + 1]
			var b0 := secs[i + 1][k]
			var b1 := secs[i + 1][k + 1]
			for v: Vector3 in [a0, b0, a1, a1, b0, b1]:
				st.set_color(c)
				st.add_vertex(v)
	# deck
	for i in slices:
		var a0 := secs[i][0]
		var a1 := secs[i][profile.size() - 1]
		var b0 := secs[i + 1][0]
		var b1 := secs[i + 1][profile.size() - 1]
		for v: Vector3 in [a0, a1, b0, a1, b1, b0]:
			st.set_color(Color("c49a6c"))
			st.add_vertex(v)
	st.generate_normals()
	var m := st.commit()
	return m


## The player's ship «Попутчик» (ADR-0036): built by `Wayfarer`, the one realistic thing in the game.
static func ship() -> Node3D:
	return Wayfarer.build()


## A villager figure: body, head, hat. `coat` and `hat` colours tell people apart. `who` picks a MakeHuman
## character (sailor, trader, oldman, child) when it is downloaded, dressed for the age of sail by `Costume` (`role`:
## captain, sailor, trader, townsman, child; by default the one that fits `who`); otherwise the procedural person stands in.
static func figure(coat: Color, hat: Color, who: String = "", role: String = "") -> Node3D:
	if role == "chronicler":  # not a human: built whole in code (docs/design/concepts/05-chronicler.jpg)
		return Costume.stand_in(role, coat)
	if not who.is_empty():
		var dress: String = role if not role.is_empty() else {"oldman": "townsman"}.get(who, who)
		var p := Assets.person(who)
		if p != null:
			if Session.arg("plain").is_empty():  # `--plain` shows the people as downloaded (before/after pictures)
				Costume.dress(p, dress, coat)
			return p
		if Session.arg("oldstandin").is_empty():  # the people are not on disk: a stand-in in the same costume
			return Costume.stand_in(dress, coat)
	if Assets.available():
		return _person(coat, hat)
	var f := Node3D.new()
	f.add_child(cyl(0.32, 0.5, 1.2, 8, coat, Vector3(0, 0.6, 0)))
	f.add_child(cyl(0.38, 0.32, 0.25, 8, coat.darkened(0.25), Vector3(0, 1.25, 0)))
	f.add_child(ball(0.32, Color("f1c9a5"), Vector3(0, 1.62, 0)))
	f.add_child(cyl(0.22, 0.26, 0.35, 8, hat, Vector3(0, 2.0, 0)))
	f.add_child(cyl(0.48, 0.48, 0.05, 10, hat, Vector3(0, 1.84, 0)))
	f.add_child(box(Vector3(0.1, 0.1, 0.1), Color("2a2a2a"), Vector3(0.12, 1.66, 0.29)))
	f.add_child(box(Vector3(0.1, 0.1, 0.1), Color("2a2a2a"), Vector3(-0.12, 1.66, 0.29)))
	return f


## A person with human proportions in a fabric coat and a Poly Haven hat (ADR-0019). ~1.8 m, faces +z.
static func _person(coat: Color, hat: Color) -> Node3D:
	var f := Node3D.new()
	var cloth := Assets.pbr("denim_fabric", coat.lightened(0.25), 2.0)
	var trousers := Assets.pbr("denim_fabric", Color("3a3530"), 2.0)
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color("d9a882")
	skin.roughness = 0.6
	skin.subsurf_scatter_enabled = true
	skin.subsurf_scatter_strength = 0.3
	var leather := Assets.pbr("dark_wood", Color("5a4030"), 2.0)
	for x in [-0.11, 0.11]:
		_part(f, _capsule(0.085, 0.82), trousers, Vector3(x, 0.45, 0))
		_part(f, _capsule(0.1, 0.24), leather, Vector3(x, 0.08, 0.04), Vector3(PI / 2, 0, 0))
	var skirt := CylinderMesh.new()
	skirt.top_radius = 0.2
	skirt.bottom_radius = 0.34
	skirt.height = 0.6
	skirt.radial_segments = 20
	_part(f, skirt, cloth, Vector3(0, 0.72, 0))
	_part(f, _capsule(0.2, 0.62), cloth, Vector3(0, 1.22, 0), Vector3.ZERO, Vector3(1.0, 1.0, 0.75))
	var belt := CylinderMesh.new()
	belt.top_radius = 0.205
	belt.bottom_radius = 0.205
	belt.height = 0.07
	belt.radial_segments = 20
	_part(f, belt, leather, Vector3(0, 1.0, 0), Vector3.ZERO, Vector3(1.0, 1.0, 0.78))
	for x in [-0.27, 0.27]:
		_part(f, _capsule(0.065, 0.62), cloth, Vector3(x, 1.18, 0.02), Vector3(0, 0, -0.12 * signf(x)))
		_part(f, _sphere(0.055), skin, Vector3(x * 1.08, 0.86, 0.04))
	_part(f, _capsule(0.06, 0.16), skin, Vector3(0, 1.55, 0))
	_part(f, _sphere(0.12), skin, Vector3(0, 1.68, 0.01), Vector3.ZERO, Vector3(0.9, 1.1, 0.95))
	var h := Assets.model("fishermans_hat")
	if h != null:
		h.position = Vector3(0, 1.74, 0)
		f.add_child(h)
	else:
		_part(f, _sphere(0.13), mat(hat), Vector3(0, 1.78, 0), Vector3.ZERO, Vector3(1.1, 0.5, 1.1))
	return f


static func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 16
	c.rings = 6
	return c


static func _sphere(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 20
	m.rings = 10
	return m


static func _part(parent: Node3D, mesh: Mesh, m: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> void:
	var mi := mesh_node(mesh, m, pos)
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)


## Silk racks of Silk Reach: poles with coloured wind-silk drying in rows.
static func silk_rack(rng: RandomNumberGenerator) -> Node3D:
	var r := Node3D.new()
	var colors := [Color("e9a6b8"), Color("f3d37a"), Color("9fd3e6"), Color("c9b2e8"), CANVAS]
	for x in [-2.0, 2.0]:
		r.add_child(cyl(0.1, 0.12, 3.0, 5, TIMBER, Vector3(x, 1.5, 0)))
	r.add_child(box(Vector3(4.2, 0.12, 0.12), TIMBER, Vector3(0, 2.95, 0)))
	for k in 3:
		var cloth := box(Vector3(1.1, 2.0, 0.05), colors[rng.randi() % colors.size()], Vector3(-1.3 + k * 1.3, 1.9, 0))
		r.add_child(cloth)
	return r


static func lantern_post() -> Node3D:
	var p := Node3D.new()
	p.add_child(cyl(0.08, 0.1, 2.6, 5, TIMBER_DARK, Vector3(0, 1.3, 0)))
	p.add_child(ball(0.22, Color("ffcf6e"), Vector3(0, 2.75, 0), 4.0))
	return p

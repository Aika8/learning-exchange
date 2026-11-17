## Pattern: Builder — assembles the shared world (sky, light, fog, cloud sea, Spark Harbour, Silk Reach, distant
## islands) so the menu, the harbour and the voyage show the same place. Look: docs/design/game3d-style.md.
class_name Archipelago
extends RefCounted

const HARBOUR := Vector3.ZERO
const HARBOUR_RADIUS := 34.0
const EXCHANGE_DOOR := Vector3(0, 0, -9.5)  ## where the player enters the hall
const EXCHANGE_POS := Vector3(0, 0, -15)
const PIER_END := Vector3(48, 0, 4)  ## where the ship is moored
const MARA_POS := Vector3(30, 0.12, 8)
const SILK := Vector3(330, -6, -260)
const SILK_RADIUS := 26.0
const SILK_DOCK := Vector3(330 - 34, -6, -260 + 14)
const CLOUD_LEVEL := -55.0
const HARBOUR_SEED := 11
const SILK_SEED := 23
const SILK_BUMPS := 1.2
const DECK_Y := 0.12  ## top of the timber decks over the grass
const WHARF_FROM := Vector3(23.5, DECK_Y, -4.6)  ## the Spark Harbour wharf: a deck from the cliff out over the void
const WHARF_TO := Vector3(40.5, DECK_Y, 12.6)
const PIER_FROM := Vector3(40.0, DECK_Y, 2.0)  ## the pier the ship moors at
const PIER_TO := Vector3(49.4, DECK_Y, 6.0)
const SILK_PIER_FROM := SILK + Vector3(-36.8, DECK_Y, 12.0)
const SILK_PIER_TO := SILK + Vector3(-13.0, DECK_Y, 16.0)  ## its island end lies well inside the walkable cap of both looks


## Where people can stand on an island: the flat cap (a wobbly disc) and the pier (a rectangle).
static func walk_areas(island_id: String) -> Array[Dictionary]:
	if island_id == "silk":
		return [{"name": "silk", "kind": "disc", "centre": SILK, "radius": SILK_RADIUS, "seed": SILK_SEED},
			{"name": "silk-pier", "kind": "rect", "from": SILK_PIER_FROM, "to": SILK_PIER_TO}]
	return [{"name": "harbour", "kind": "disc", "centre": HARBOUR, "radius": HARBOUR_RADIUS, "seed": HARBOUR_SEED},
		{"name": "wharf", "kind": "rect", "from": WHARF_FROM, "to": WHARF_TO},
		{"name": "pier", "kind": "rect", "from": PIER_FROM, "to": PIER_TO}]


## Where the captain appears: [position, camera yaw]. `spawn` is Session.spawn (start | pier | exchange).
static func spawn_point(island_id: String, spawn: String) -> Array:
	if island_id == "silk":
		return [SILK_DOCK + Vector3(8, 0.5, 0), -2.3]  # every arrival at Silk Reach is by ship
	match spawn:
		"pier":
			return [PIER_END + Vector3(-6, 0.5, 0), PI / 2]
		"exchange":
			return [EXCHANGE_DOOR + Vector3(0, 0.5, 3), 0.0]
	return [Vector3(6, 0.5, 10), 0.5]


## Environment, sun and cloud sea. `hall` = indoor variant (no clouds, warm and dim).
static func sky(root: Node3D, hall: bool = false) -> WorldEnvironment:
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("3d6ea8")
	sky_mat.sky_horizon_color = Color("f2c58a")
	sky_mat.sky_curve = 0.12
	sky_mat.ground_bottom_color = Color("a9b4cf")
	sky_mat.ground_horizon_color = Color("f2c58a")
	sky_mat.sun_angle_max = 18.0
	sky_mat.sun_curve = 0.08
	var sky_res := Sky.new()
	sky_res.sky_material = sky_mat
	sky_res.radiance_size = Sky.RADIANCE_SIZE_256
	if Assets.available():  # ADR-0019: HDRI sky lights the scene
		var pano := PanoramaSkyMaterial.new()
		pano.panorama = load(Assets.HDRI)
		pano.energy_multiplier = 0.85
		sky_res.sky_material = pano
		sky_res.process_mode = Sky.PROCESS_MODE_QUALITY
	env.background_mode = Environment.BG_SKY
	env.sky = sky_res
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55 if not hall else 0.25
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.92 if not Assets.available() else 0.8
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.4 if hall else 1.8
	# indoors: screen-space GI and reflections on the floor and brass. Outdoors the sky lights the scene and SSAO
	# grounds things: SDFGI is off by default — it cost ~9 fps in the harbour and rebuilt its cascades in one
	# 45–70 ms frame whenever the camera jumped (measured, docs/demo/G3D-polish.md); `--sdfgi` turns it back on
	env.ssil_enabled = hall
	env.ssil_intensity = 0.8
	env.ssr_enabled = hall
	env.ssr_max_steps = 64
	env.sdfgi_enabled = not hall and not Session.arg("sdfgi").is_empty()
	env.sdfgi_use_occlusion = true
	env.sdfgi_cascades = 3
	env.sdfgi_min_cell_size = 0.2
	env.sdfgi_energy = 0.9
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.06
	if hall:
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color("1a1410")
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color("6b5240") if not Assets.available() else Color("8a7058")
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.02 if not Assets.available() else 0.007
		env.volumetric_fog_albedo = Color("ffe3c0")
		env.volumetric_fog_anisotropy = 0.5
		env.volumetric_fog_length = 40.0
	else:
		env.fog_enabled = true
		env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
		env.fog_light_color = Color("e9c9a3")
		env.fog_density = 0.0009 if not Assets.available() else 0.0004
		env.fog_sun_scatter = 0.35
		env.fog_aerial_perspective = 0.3
		env.fog_sky_affect = 0.15
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.0012 if not Assets.available() else 0.0005
		env.volumetric_fog_albedo = Color("fff0dc")
		env.volumetric_fog_anisotropy = 0.65
		env.volumetric_fog_length = 160.0
		env.volumetric_fog_detail_spread = 2.0
		env.volumetric_fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	root.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color("ffe1b0")
	sun.light_energy = 1.35 if not hall else 0.0
	sun.rotation_degrees = Vector3(-34, -128, 0)
	sun.shadow_enabled = not hall
	sun.shadow_blur = 1.0
	sun.light_angular_distance = 0.8
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 120.0  # the island is 60 m across; the far ones never had shadows
	sun.directional_shadow_blend_splits = true
	sun.light_volumetric_fog_energy = 1.6
	root.add_child(sun)
	if not hall:
		root.add_child(cloud_sea())
	return we


static func cloud_sea() -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2(2600, 2600)
	plane.subdivide_width = 180
	plane.subdivide_depth = 180
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/cloud_sea.gdshader")
	m.set_shader_parameter("noise_a", _noise(7, 0.012))
	m.set_shader_parameter("noise_b", _noise(19, 0.03))
	var mi := Proc.mesh_node(plane, m, Vector3(150, CLOUD_LEVEL, -120))
	mi.name = "CloudSea"
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 20.0
	return mi


static func _noise(seed_value: int, freq: float) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.frequency = freq
	n.fractal_octaves = 4
	var t := NoiseTexture2D.new()
	t.width = 256
	t.height = 256
	t.seamless = true
	t.noise = n
	return t


## A floating island node with collision on its cap; crystals underneath.
static func island(radius: float, depth: float, seed_value: int, bumps: float = 0.0, collide: bool = false) -> Node3D:
	var root := Node3D.new()
	var hd := Assets.available()
	var mesh := Proc.island_mesh_hd(radius, depth, seed_value, bumps) if hd else Proc.island_mesh(radius, depth, seed_value, bumps)
	var mi := Proc.mesh_node(mesh, Proc.terrain_mat())
	root.add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		shape.shape = mesh.create_trimesh_shape()
		body.add_child(shape)
		root.add_child(body)
	Proc.crystals(root, radius, depth, int(radius / 3.0), seed_value + 1)
	if hd:
		_dress_island(root, radius, depth, seed_value, collide)
	return root


## Real rock faces on the rim, cliffs lower down, roots hanging from under the grass lip (ADR-0019).
## `near` islands (the ones you walk on) get the full set; far ones a light one to keep the frame rate.
static func _dress_island(root: Node3D, radius: float, depth: float, seed_value: int, near: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 31
	var count := int(radius * (0.7 if near else 0.35))
	for i in count:
		var a := TAU * (i + rng.randf() * 0.6) / count
		var dir := Vector3(cos(a), 0, sin(a))
		var face := Node3D.new()
		var kind: String = ["rock_face_01", "rock_face_02", "namaqualand_cliff_01"][i % 3]
		var m := Assets.model(kind)
		if m == null:
			return
		face.add_child(m)
		var sc := clampf(radius / 16.0, 0.5, 2.0) * rng.randf_range(0.8, 1.2)
		var k := rng.randf_range(0.1, 0.45)  # how far down the body, 0 = just under the grass lip
		var y := -1.2 - k * depth * 0.8 - 3.5 * sc
		face.position = dir * radius * (0.97 * pow(1.0 - (k * 0.8 + 0.1), 0.85) - 0.02) + Vector3(0, y, 0)
		face.scale = Vector3.ONE * sc
		face.rotation = Vector3(0, -a + PI / 2 + rng.randf_range(-0.6, 0.6), rng.randf_range(-0.15, 0.15))
		root.add_child(face)
	if not near:
		return
	for i in int(radius * 0.4):
		var a := rng.randf() * TAU
		var dir := Vector3(cos(a), 0, sin(a))
		var root_kind := "root_cluster_01" if i % 8 == 0 else "single_root"
		var r := Assets.model(root_kind)
		r.position = dir * radius * rng.randf_range(0.86, 0.95) + Vector3(0, -0.6, 0)
		r.rotation = Vector3(PI / 2 + rng.randf_range(-0.2, 0.2), -a + PI / 2, rng.randf_range(-0.3, 0.3))
		r.scale = Vector3.ONE * (rng.randf_range(1.5, 2.5) if root_kind == "single_root" else rng.randf_range(0.8, 1.2))
		root.add_child(r)
	for i in int(radius * 0.8):  # pebbles on the cap edge
		var a := rng.randf() * TAU
		Assets.put(root, "rock_07" if i % 2 == 0 else "rock_09", Vector3(cos(a), 0, sin(a)) * radius * rng.randf_range(0.8, 0.9), rng.randf() * TAU, rng.randf_range(4.0, 9.0))


## Whole world. `detail` false = skip small props (used by far views).
static func build(root: Node3D, detail: bool = true) -> Dictionary:
	var parts: Dictionary = {}
	var harbour := _spark_harbour(detail)
	root.add_child(harbour)
	parts["harbour"] = harbour
	parts["blades"] = harbour.find_child("Blades", true, false)
	var silk := _silk_reach()
	silk.position = SILK
	root.add_child(silk)
	parts["silk"] = silk
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var far: Array[Node3D] = []
	for i in 14:
		var a := TAU * i / 14.0 + rng.randf_range(-0.2, 0.2)
		var d := rng.randf_range(160.0, 520.0)
		var r := rng.randf_range(8.0, 22.0)
		var isl := island(r, r * rng.randf_range(1.0, 1.6), 100 + i, rng.randf_range(0.0, 2.0))
		isl.position = Vector3(cos(a) * d + 120, rng.randf_range(-25.0, 30.0), sin(a) * d - 100)
		isl.rotation.y = rng.randf() * TAU
		for k in int(r / 3.0):
			var tr := Proc.tree(rng)
			var ta := rng.randf() * TAU
			var td := rng.randf() * r * 0.7
			tr.position = Vector3(cos(ta) * td, 0, sin(ta) * td)
			tr.scale = Vector3.ONE * rng.randf_range(0.9, 1.5)
			isl.add_child(tr)
		root.add_child(isl)
		far.append(isl)
	parts["far"] = far
	return parts


static func _spark_harbour(detail: bool) -> Node3D:
	var h := Node3D.new()
	h.name = "SparkHarbour"
	h.add_child(island(HARBOUR_RADIUS, 42.0, HARBOUR_SEED, 0.0, true))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# the Wind Exchange on a stepped terrace
	var mill := Proc.windmill()
	mill.position = EXCHANGE_POS
	h.add_child(mill)
	h.add_child(_terrace(EXCHANGE_POS + Vector3(0, 0, 1)))
	# paved road from the exchange to the wharf: one ribbon, no overlapping slabs
	h.add_child(_road([Vector3(0, 0, -6.6), Vector3(5, 0, -3), Vector3(15, 0, 1.5), Vector3(24.6, 0, 4)], 3.2))
	Decals.ground(h, Vector3(1, 0, 3), 14.0)  # the trodden square
	# houses around a square
	var spots := [Vector3(-14, 0, -2), Vector3(-17, 0, 8), Vector3(-6, 0, 15), Vector3(8, 0, 17), Vector3(15, 0, -11),
		Vector3(-12, 0, -16), Vector3(19, 0, 14), Vector3(-22, 0, -6)]
	var roofs := [Proc.ROOF_RED, Proc.ROOF_TEAL, Color("d08a3b"), Proc.ROOF_RED]
	for i in spots.size():
		var at := fit(spots[i], HARBOUR_RADIUS, HARBOUR_SEED, 5.0)
		var hs := Houses.house(rng, roofs[i % roofs.size()], 0, i % 3 == 0)
		hs.position = at
		hs.rotation.y = atan2(-at.x, -at.z)  # the door looks at the square
		h.add_child(hs)
	# trees on the rim
	for i in 22:
		var a := rng.randf() * TAU
		var d := rng.randf_range(22.0, 30.0)
		var pos := fit(Vector3(cos(a) * d, 0, sin(a) * d), HARBOUR_RADIUS, HARBOUR_SEED, 2.0)
		if pos.x > 18.0 and absf(pos.z - 4.0) < 12.0:
			continue  # the wharf
		var clear := true
		for s: Vector3 in spots:
			clear = clear and pos.distance_to(s) > 6.0
		if not clear:
			continue
		if Assets.available():  # ADR-0019: a few real trees instead of a ring of cones
			if i % 4 == 0:
				var tree := Assets.thinned("island_tree_02", 3)
				tree.position = pos
				tree.rotation.y = rng.randf() * TAU
				tree.scale = Vector3.ONE * rng.randf_range(2.2, 2.9)
				tree.set_meta("asset", "island_tree_02")
				h.add_child(tree)
				Solid.model(h, tree, "island_tree_02")
			continue
		var t := Proc.round_tree(rng) if rng.randf() < 0.6 else Proc.tree(rng)
		t.position = pos
		h.add_child(t)
		Solid.model(h, t, "procedural")
	h.add_child(_deck("Wharf", WHARF_FROM, WHARF_TO, [true, false, true, false], Vector3(WHARF_FROM.x, 0, 4)))
	h.add_child(_deck("Pier", PIER_FROM, PIER_TO, [true, true, false, false], Vector3(PIER_FROM.x, 0, 4)))
	if detail:
		for p: Vector3 in [Vector3(4.6, 0, -4.4), Vector3(-4.6, 0, -4.4), Vector3(16, 0, 4.4), Vector3(27, DECK_Y, 6.6), Vector3(46, DECK_Y, 5.6)]:
			h.add_child(lamp_post(p, PI / 2 if p.x > 20.0 else (0.0 if absf(p.x) < 5.0 else PI)))
		var light := OmniLight3D.new()
		light.position = EXCHANGE_POS + Vector3(0, 4, 6)
		light.light_color = Color("ffc979")
		light.light_energy = 2.0
		light.omni_range = 12.0
		h.add_child(light)
		# market stalls with awnings near the square
		for i in 3:
			h.add_child(_stall(Vector3(-4 + i * 5, 0, 7), i))
		_harbour_props(h)
	fence_areas(h, "harbour")
	return h


## A street lamp: a timber post with the Poly Haven bracket lantern on it (the model is a wall lamp, so it needs
## something to hang on) and a warm light. The bracket points along +z turned by `yaw`.
static func lamp_post(at: Vector3, yaw: float) -> Node3D:
	var lp := Node3D.new()
	lp.name = "LampPost"
	lp.position = at
	lp.rotation.y = yaw
	lp.add_child(Proc.cyl(0.09, 0.12, 3.3, 8, Proc.TIMBER_DARK, Vector3(0, 1.65, 0)))
	lp.add_child(Proc.box(Vector3(0.3, 0.08, 0.3), Proc.TIMBER_DARK, Vector3(0, 3.32, 0)))
	Solid.post(lp, 0.12, 3.3, Vector3.ZERO)
	var lantern := Assets.model("street_lamp_02")
	if lantern != null:
		lantern.position = Vector3(0, 2.2, 0.08)
		lp.add_child(lantern)
	else:
		lp.add_child(Proc.ball(0.2, Color("ffcf6e"), Vector3(0, 2.7, 0.26), 4.0))
	var ll := OmniLight3D.new()
	ll.position = Vector3(0, 2.7, 0.7)
	ll.light_color = Color("ffc979")
	ll.light_energy = 1.2
	ll.omni_range = 7.0
	ll.distance_fade_enabled = true
	ll.distance_fade_begin = 45.0
	ll.distance_fade_length = 10.0
	lp.add_child(ll)
	return lp


## Pulls a spot on an island towards its centre until it is `margin` metres inside the flat cap.
static func fit(pos: Vector3, radius: float, seed_value: int, margin: float) -> Vector3:
	var flat := Vector2(pos.x, pos.z)
	var limit := Proc.cap_radius(radius, seed_value, atan2(flat.y, flat.x)) - margin
	if flat.length() > limit:
		flat = flat.normalized() * limit
	return Vector3(flat.x, pos.y, flat.y)


## Invisible walls round the walkable outline of an island, in the island node's own space.
static func fence_areas(island_node: Node3D, island_id: String) -> void:
	var f := Node3D.new()
	f.name = "Fences"
	island_node.add_child(f)
	Solid.fence_areas(f, walk_areas(island_id), SILK if island_id == "silk" else HARBOUR)


## The stone terrace of the Exchange: two low steps all round, so the door is reached by stairs.
static func _terrace(at: Vector3) -> Node3D:
	var t := Node3D.new()
	t.name = "Terrace"
	t.position = at
	t.set_meta("flat", true)
	var stone := Proc.mat(Color("cdb898"))
	var k := Kit.new()
	k.box(stone, Vector3(15.2, 0.4, 15.2), Vector3(0, -0.05, 0))
	k.box(stone, Vector3(14.0, 0.4, 14.0), Vector3(0, 0.1, 0))
	t.add_child(k.commit("Stone"))
	Solid.box(t, Vector3(15.2, 0.4, 15.2), Vector3(0, -0.05, 0))
	Solid.box(t, Vector3(14.0, 0.4, 14.0), Vector3(0, 0.1, 0))
	return t


## A cobbled ribbon along `points`, `width` wide, lying 3 cm over the grass.
static func _road(points: Array, width: float) -> MeshInstance3D:
	var k := Kit.new()
	var stone := Proc.mat(Color("d8c7a6"))
	var left: Array[Vector3] = []
	var right: Array[Vector3] = []
	for i in points.size():
		var p: Vector3 = points[i]
		var dir: Vector3 = ((points[mini(i + 1, points.size() - 1)] as Vector3) - (points[maxi(i - 1, 0)] as Vector3)).normalized()
		var side := Vector3(-dir.z, 0, dir.x) * width * 0.5
		left.append(p - side + Vector3(0, 0.03, 0))
		right.append(p + side + Vector3(0, 0.03, 0))
	for i in points.size() - 1:
		k.quad(stone, left[i], right[i], right[i + 1], left[i + 1], 0.35)
	var mi := k.commit("Road")
	mi.set_meta("flat", true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## A timber deck over the void between `from` and `to` (island space): planks, edge beams, piles with braces,
## rope rails on the sides marked in `rails` [−z, +x, +z, −x] (each with its own collider: a side people walk in
## by has no rail), and one collider for the whole floor.
static func _deck(name: String, from: Vector3, to: Vector3, rails: Array, shore: Vector3) -> Node3D:
	var dk := Node3D.new()
	dk.name = name
	dk.set_meta("flat", true)
	var size := Vector3(to.x - from.x, 0.24, to.z - from.z)
	var mid := Vector3((from.x + to.x) * 0.5, DECK_Y - 0.12, (from.z + to.z) * 0.5)
	var planks := Proc.mat(Proc.TIMBER)
	var dark := Proc.mat(Proc.TIMBER_DARK)
	var k := Kit.new()
	k.box(planks, size, mid)
	Solid.box(dk, size, mid)
	for z: float in [from.z, to.z]:  # edge beams
		k.box(dark, Vector3(size.x + 0.3, 0.3, 0.3), Vector3(mid.x, DECK_Y - 0.2, z))
	for x: float in [from.x, to.x]:
		k.box(dark, Vector3(0.3, 0.3, size.z + 0.3), Vector3(x, DECK_Y - 0.2, mid.z))
	var pile := CylinderMesh.new()
	pile.top_radius = 0.2
	pile.bottom_radius = 0.24
	pile.height = 4.4
	pile.radial_segments = 8
	pile.rings = 1
	var nx := maxi(2, int(round(size.x / 4.0)) + 1)
	var nz := maxi(2, int(round(size.z / 4.0)) + 1)
	for ix in nx:
		for iz in nz:
			if ix > 0 and ix < nx - 1 and iz > 0 and iz < nz - 1:
				continue
			var p := Vector3(from.x + size.x * ix / (nx - 1), 0, from.z + size.z * iz / (nz - 1))
			if Vector2(p.x - shore.x, p.z - shore.z).length() < 2.0 or p.x < shore.x + 2.5:
				continue  # that corner rests on the island
			k.mesh(dark, pile, Transform3D(Basis(), p + Vector3(0, DECK_Y - 2.3, 0)))
			k.box(dark, Vector3(0.14, 0.14, 2.6), p + Vector3(0, DECK_Y - 1.3, 0.0), Vector3(0.9, 0, 0))
	# rope rails: posts every two metres, two ropes
	var rope := Houses._paint(Color("b89a6a"))
	var corners := [Vector3(from.x, DECK_Y, from.z), Vector3(to.x, DECK_Y, from.z), Vector3(to.x, DECK_Y, to.z), Vector3(from.x, DECK_Y, to.z)]
	for side in 4:
		if not rails[side]:
			continue
		var a: Vector3 = corners[side]
		var b: Vector3 = corners[(side + 1) % 4]
		var n := int(round(a.distance_to(b) / 2.0))
		for i in n + 1:
			var p := a.lerp(b, float(i) / n)
			k.box(dark, Vector3(0.14, 1.05, 0.14), p + Vector3(0, 0.52, 0))
		var yaw := atan2(-(b.z - a.z), b.x - a.x)
		for y: float in [0.55, 0.95]:
			k.box(rope, Vector3(a.distance_to(b), 0.05, 0.05), (a + b) * 0.5 + Vector3(0, y, 0), Vector3(0, yaw, 0))
		Solid.box(dk, Vector3(a.distance_to(b) + 0.14, 1.05, 0.14), (a + b) * 0.5 + Vector3(0, 0.52, 0), yaw)  # a rail you see stops you
	dk.add_child(k.commit("Deck"))
	return dk


static func _stall(at: Vector3, i: int) -> Node3D:
	var stall := Node3D.new()
	stall.name = "Stall"
	stall.position = at
	stall.add_child(Proc.box(Vector3(2.6, 1.0, 1.4), Proc.TIMBER, Vector3(0, 0.5, 0)))
	Solid.box(stall, Vector3(2.6, 1.0, 1.4), Vector3(0, 0.5, 0))
	var awn_color: Color = [Color("e0705f"), Color("f3d37a"), Color("5fb98a")][i]
	var awn := Proc.box(Vector3(3.0, 0.04, 2.0), awn_color, Vector3(0, 2.36, 0.2))
	awn.rotation.x = 0.25
	if Assets.available():
		awn.material_override = Assets.pbr("quatrefoil_jacquard_fabric", awn_color, 1.2)
	stall.add_child(awn)
	for x: float in [-1.3, 1.3]:
		stall.add_child(Proc.cyl(0.06, 0.06, 2.4, 8, Proc.TIMBER_DARK, Vector3(x, 1.2, 0.9)))
		stall.add_child(Proc.cyl(0.06, 0.06, 2.8, 8, Proc.TIMBER_DARK, Vector3(x, 1.4, -0.66)))
		Solid.post(stall, 0.08, 2.4, Vector3(x, 0, 0.9))
		Solid.post(stall, 0.08, 2.8, Vector3(x, 0, -0.66))
	if Assets.available():
		Assets.put(stall, "wooden_bucket_01", Vector3(-0.8, 1.0, 0), 0.0, 1.0)
		Assets.put(stall, "wooden_crate_01", Vector3(0.4, 1.0, 0), 0.2, 1.0)
	else:
		for k in 3:
			stall.add_child(Proc.box(Vector3(0.5, 0.4, 0.5), [Color("e9a6b8"), Color("f3e9d2"), Color("9fd3e6")][k], Vector3(-0.8 + k * 0.8, 1.2, 0)))
	return stall


## Cargo, rope, nets and rocks from Poly Haven (ADR-0019): the pier and square look worked-in. Skipped without assets.
static func _harbour_props(h: Node3D) -> void:
	if not Assets.available():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	# cargo stacked along the pier and the wharf
	for i in 7:
		var x := 28.0 + i * 3.0
		var z := (2.7 if i % 2 == 0 else 5.4) if x > WHARF_TO.x else (-4.1 if i % 2 == 0 else 12.1)
		var kind: String = ["wine_barrel_01", "wooden_crate_01", "wooden_crate_02", "wooden_barrels_01", "wooden_bucket_01"][i % 5]
		Assets.put(h, kind, Vector3(x, DECK_Y, z), rng.randf() * TAU, 1.2)
	for i in 3:
		Assets.put(h, "wooden_crate_01", Vector3(31.5, DECK_Y + i * 0.6, 12.1), rng.randf_range(-0.2, 0.2), 1.2)
	var buoy := Assets.put(h, "lifebuoy", Vector3(34, 0.72, WHARF_TO.z - 0.1), 0.0, 1.0)
	buoy.set_meta("hung", true)  # hangs on the rail
	Assets.put(h, "wooden_lantern_01", Vector3(48.6, DECK_Y, 2.5), 0.0, 1.4)
	Assets.put(h, "wooden_lantern_01", Vector3(48.6, DECK_Y, 5.5), 0.0, 1.4)
	Assets.put(h, "wine_barrel_01", Vector3(-2.2, 0, 7.9), 0.0, 1.0)
	# market goods by the stalls and the square
	for p: Vector3 in [Vector3(-6.4, 0, 8.4), Vector3(-5.4, 0, 9.0), Vector3(4.5, 0, 9.0), Vector3(9, 0, -2), Vector3(-11, 0, 3.4)]:
		Assets.put(h, ["wine_barrel_01", "wooden_crate_02", "wooden_bucket_01"][rng.randi() % 3], p, rng.randf() * TAU, 1.1)
	Assets.put(h, "treasure_chest", Vector3(6.2, 0.26, -7.6), 0.3, 0.9)
	# rocks, ferns and shrubs on the rim
	for i in 10:
		var a := rng.randf() * TAU
		var pos := fit(Vector3(cos(a), 0, sin(a)) * rng.randf_range(24.0, 31.0), HARBOUR_RADIUS, HARBOUR_SEED, 1.5) + Vector3(0, -0.1, 0)
		if pos.x > 18.0 and absf(pos.z - 4.0) < 11.0:
			continue
		Assets.put(h, "rock_moss_set_01" if i % 3 == 0 else "boulder_01", pos, rng.randf() * TAU, rng.randf_range(0.6, 1.2))
	for i in 26:
		var a := rng.randf() * TAU
		var pos := fit(Vector3(cos(a), 0, sin(a)) * rng.randf_range(8.0, 30.0), HARBOUR_RADIUS, HARBOUR_SEED, 1.0)
		if pos.distance_to(Vector3(20, 0, 4)) < 6.0 or pos.distance_to(Vector3(0, 0, -15)) < 9.0:
			continue
		Assets.put(h, ["fern_02", "shrub_01", "grass_medium_01"][i % 3], pos, rng.randf() * TAU, rng.randf_range(1.0, 2.2))


static func _silk_reach() -> Node3D:
	var s := Node3D.new()
	s.name = "SilkReach"
	s.add_child(island(SILK_RADIUS, 34.0, SILK_SEED, SILK_BUMPS, true))  # walkable since M3
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	for row in 4:
		for col in 3:
			var r := Proc.silk_rack(rng)
			r.name = "SilkRack"
			var at := Vector3(-8 + col * 6.5, 0, -10 + row * 5)
			r.position = at + Vector3(0, silk_ground(at) - 0.15, 0)
			r.rotation.y = 0.2
			s.add_child(r)
			for x: float in [-2.0, 2.0]:
				Solid.post(r, 0.14, 3.0, Vector3(x, 0, 0))
			Solid.box(r, Vector3(3.9, 2.0, 0.12), Vector3(0, 1.9, 0))
	for i in 3:
		var hs := Houses.house(rng, Color("c9b2e8"), 1, i == 0)
		var at := fit([Vector3(8, 0, 13), Vector3(15, 0, 2), Vector3(11, 0, -11)][i], SILK_RADIUS, SILK_SEED, 5.5)
		hs.position = at + Vector3(0, silk_ground(at), 0)
		hs.rotation.y = atan2(-at.x, -at.z)
		s.add_child(hs)
	for i in 12:
		var a := rng.randf() * TAU
		var pos := fit(Vector3(cos(a) * 20, 0, sin(a) * 20), SILK_RADIUS, SILK_SEED, 2.0)
		pos.y = silk_ground(pos) - 0.3  # roots in the ground, whatever the slope
		var yaw := rng.randf() * TAU
		var size := rng.randf_range(2.0, 2.8)
		if pos.x < -12.0 and absf(pos.z - 14.0) < 6.0:
			continue  # the way to the pier
		# ADR-0019: real thinned trees on the rim (every other slot; shrubs fill the rest), balls only without assets
		var kind := "island_tree_02" if i % 2 == 0 else "shrub_01"
		var real := Assets.thinned(kind, 3) if i % 2 == 0 else Assets.model(kind)
		if real != null:
			real.position = pos
			real.rotation.y = yaw
			real.scale = Vector3.ONE * (size if i % 2 == 0 else size * 1.4)
			real.set_meta("asset", kind)
			s.add_child(real)
			Solid.model(s, real, kind)
			continue
		var t := Proc.round_tree(rng)
		t.position = pos
		s.add_child(t)
		Solid.model(s, t, "procedural")
	s.add_child(_deck("Pier", SILK_PIER_FROM - SILK, SILK_PIER_TO - SILK, [true, false, true, true], SILK_PIER_TO - SILK + Vector3(0, 0, -2)))
	fence_areas(s, "silk")
	return s


## Height of the ground of Silk Reach at a point given in the island's own space.
static func silk_ground(local: Vector3) -> float:
	return Proc.cap_height(SILK_RADIUS, SILK_SEED, SILK_BUMPS, local.x, local.z)


## Weather over the base sky: 0 = the calm late afternoon, 1 = a storm (grey fog, dim sun, darker sky), and `night`
## for the report night and the evening chronicle. Only parameters of the existing environment change (60 fps).
static func weather(root: Node3D, storm: float, night: float = 0.0) -> void:
	var we: WorldEnvironment = root.find_child("WorldEnvironment", false, false)
	if we == null:
		for c in root.get_children():
			if c is WorldEnvironment:
				we = c
	var sun: DirectionalLight3D = root.get_node_or_null("Sun")
	if we == null or sun == null:
		return
	var env := we.environment
	var calm_fog := 0.0004 if Assets.available() else 0.0009
	env.fog_density = lerpf(calm_fog, 0.006, storm)
	env.fog_light_color = Color("e9c9a3").lerp(Color("5a6270"), storm).lerp(Color("1c2236"), night)
	env.volumetric_fog_density = lerpf(0.0005, 0.004, storm)
	env.volumetric_fog_albedo = Color("fff0dc").lerp(Color("8a92a0"), storm)
	env.ambient_light_energy = lerpf(0.55, 0.3, storm) * lerpf(1.0, 0.35, night)
	env.adjustment_saturation = lerpf(1.08, 0.6, storm) * lerpf(1.0, 0.7, night)
	env.adjustment_brightness = lerpf(1.0, 0.75, storm) * lerpf(1.0, 0.45, night)
	if env.sky and env.sky.sky_material is PanoramaSkyMaterial:
		(env.sky.sky_material as PanoramaSkyMaterial).energy_multiplier = lerpf(0.85, 0.35, storm) * lerpf(1.0, 0.25, night)
	sun.light_energy = lerpf(1.35, 0.25, storm) * lerpf(1.0, 0.12, night)
	sun.light_color = Color("ffe1b0").lerp(Color("9fb4d8"), night)

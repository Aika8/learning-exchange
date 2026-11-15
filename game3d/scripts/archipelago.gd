## Pattern: Builder — assembles the shared world (sky, light, fog, cloud sea, Spark Harbour, Silk Reach, distant
## islands) so the menu, the harbour and the voyage show the same place. Look: docs/design/game3d-style.md.
class_name Archipelago
extends RefCounted

const HARBOUR := Vector3.ZERO
const HARBOUR_RADIUS := 34.0
const EXCHANGE_DOOR := Vector3(0, 0, -9.5)  ## where the player enters the hall
const EXCHANGE_POS := Vector3(0, 0, -15)
const PIER_END := Vector3(48, 0, 4)  ## where the ship is moored
const MARA_POS := Vector3(30, 0, 8)
const SILK := Vector3(330, -6, -260)
const SILK_RADIUS := 26.0
const SILK_DOCK := Vector3(330 - 34, -6, -260 + 14)
const CLOUD_LEVEL := -55.0


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
	env.ssao_intensity = 1.4
	# indoors: screen-space GI and reflections on the floor and brass; outdoors SDFGI does the bounce light
	# and there is nothing glossy enough for SSR, so both are off there to hold 60 fps
	env.ssil_enabled = hall
	env.ssil_intensity = 0.8
	env.ssr_enabled = hall
	env.ssr_max_steps = 64
	env.sdfgi_enabled = not hall
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
	sun.directional_shadow_max_distance = 160.0
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
	h.add_child(island(HARBOUR_RADIUS, 42.0, 11, 0.0, true))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# the Wind Exchange on a terrace
	var mill := Proc.windmill()
	mill.position = EXCHANGE_POS
	h.add_child(mill)
	h.add_child(Proc.box(Vector3(14, 0.4, 14), Color("cdb898"), EXCHANGE_POS + Vector3(0, 0.05, 1)))
	# paved road from the exchange to the pier
	for i in 12:
		var t := i / 11.0
		var p := Vector3(0, 0.06, -8).lerp(Vector3(34, 0.06, 4), t)
		var stone := Proc.box(Vector3(3.2, 0.12, 3.2), Color("d8c7a6").darkened(rng.randf() * 0.08), p)
		stone.rotation.y = rng.randf_range(-0.2, 0.2)
		if Assets.available():
			stone.material_override = Assets.pbr("cobblestone_floor_04", Color.WHITE, 0.35)
		h.add_child(stone)
	# houses around a square
	var spots := [Vector3(-14, 0, -2), Vector3(-17, 0, 8), Vector3(-6, 0, 14), Vector3(8, 0, 16), Vector3(14, 0, -10),
		Vector3(-12, 0, -16), Vector3(20, 0, 14), Vector3(-22, 0, -6)]
	var roofs := [Proc.ROOF_RED, Proc.ROOF_TEAL, Color("d08a3b"), Proc.ROOF_RED]
	for i in spots.size():
		var hs := Proc.house(rng, roofs[i % roofs.size()])
		hs.position = spots[i]
		hs.look_at_from_position(spots[i], Vector3(0, 0, 0), Vector3.UP)
		hs.rotate_y(PI)
		h.add_child(hs)
		_solid(h, spots[i], 2.2)
	# trees on the rim
	for i in 22:
		var a := rng.randf() * TAU
		var d := rng.randf_range(22.0, 30.0)
		var pos := Vector3(cos(a) * d, 0, sin(a) * d)
		if pos.distance_to(Vector3(40, 0, 4)) < 14.0:
			continue
		if Assets.available():  # ADR-0019: a few real trees instead of a ring of cones
			if i % 4 == 0:
				var tree := Assets.thinned("island_tree_02", 3)
				tree.position = pos
				tree.rotation.y = rng.randf() * TAU
				tree.scale = Vector3.ONE * rng.randf_range(2.2, 2.9)
				h.add_child(tree)
			continue
		var t := Proc.round_tree(rng) if rng.randf() < 0.6 else Proc.tree(rng)
		t.position = pos
		h.add_child(t)
	# pier
	for i in 9:
		h.add_child(Proc.box(Vector3(3.6, 0.3, 4.0), Proc.TIMBER.lightened(0.1 * (i % 2)), Vector3(30 + i * 2.2, -0.1, 4)))
	for i in 5:
		for z in [2.0, 6.0]:
			h.add_child(Proc.cyl(0.18, 0.18, 3.0, 6, Proc.TIMBER_DARK, Vector3(30 + i * 4.4, -1.0, z)))
	if detail:
		for p: Vector3 in [Vector3(4, 0, -6), Vector3(-4, 0, -6), Vector3(16, 0, 1), Vector3(28, 0, 6), Vector3(46, 0, 6.5)]:
			if Assets.put(h, "street_lamp_02", p, p.x * 0.3, 1.6) == null:
				var lp := Proc.lantern_post()
				lp.position = p
				h.add_child(lp)
			else:
				var ll := OmniLight3D.new()
				ll.position = p + Vector3(0, 2.6, 0)
				ll.light_color = Color("ffc979")
				ll.light_energy = 1.2
				ll.omni_range = 7.0
				h.add_child(ll)
		var light := OmniLight3D.new()
		light.position = EXCHANGE_POS + Vector3(0, 4, 6)
		light.light_color = Color("ffc979")
		light.light_energy = 2.0
		light.omni_range = 12.0
		h.add_child(light)
		# market stalls with awnings near the square
		for i in 3:
			var stall := Node3D.new()
			stall.position = Vector3(-4 + i * 5, 0, 6)
			stall.add_child(Proc.box(Vector3(2.6, 1.0, 1.4), Proc.TIMBER, Vector3(0, 0.5, 0)))
			var awn_color: Color = [Color("e0705f"), Color("f3d37a"), Color("5fb98a")][i]
			var awn := Proc.box(Vector3(3.0, 0.04, 2.0), awn_color, Vector3(0, 2.4, 0.2))
			awn.rotation.x = 0.25
			if Assets.available():
				awn.material_override = Assets.pbr("quatrefoil_jacquard_fabric", awn_color, 1.2)
			stall.add_child(awn)
			for x in [-1.3, 1.3]:
				stall.add_child(Proc.cyl(0.06, 0.06, 2.4, 8, Proc.TIMBER_DARK, Vector3(x, 1.2, 0.9)))
			if Assets.available():
				Assets.put(stall, "wooden_bucket_01", Vector3(-0.8, 1.0, 0), 0.0, 1.0)
				Assets.put(stall, "wooden_crate_01", Vector3(0.4, 1.0, 0), 0.2, 1.0)
				Assets.put(stall, "wine_barrel_01", Vector3(1.6, 0, 0.6), 0.0, 1.0)
			else:
				for k in 3:
					stall.add_child(Proc.box(Vector3(0.5, 0.4, 0.5), [Color("e9a6b8"), Color("f3e9d2"), Color("9fd3e6")][k], Vector3(-0.8 + k * 0.8, 1.2, 0)))
			h.add_child(stall)
		var villagers := [[Color("4e6fa8"), Color("d9a441"), Vector3(-2, 0, 2)], [Color("a8574e"), Color("3a4766"), Vector3(9, 0, 4)],
			[Color("6a8f4e"), Color("8a5a3c"), Vector3(-9, 0, 8)]]
		var who := ["sailor", "oldman", "child"]
		for vi in villagers.size():
			var v: Array = villagers[vi]
			var f := Proc.figure(v[0], v[1], who[vi])
			f.position = v[2]
			f.rotation.y = rng.randf() * TAU
			h.add_child(f)
	if detail:
		_harbour_props(h)
	return h


## Cargo, rope, nets and rocks from Poly Haven (ADR-0019): the pier and square look worked-in. Skipped without assets.
static func _harbour_props(h: Node3D) -> void:
	if not Assets.available():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	# cargo stacked along the pier
	for i in 7:
		var x := 31.0 + i * 2.6
		var z := 2.1 if i % 2 == 0 else 5.9
		var kind: String = ["wine_barrel_01", "wooden_crate_01", "wooden_crate_02", "wooden_barrels_01", "wooden_bucket_01"][i % 5]
		Assets.put(h, kind, Vector3(x, 0.05, z), rng.randf() * TAU, 1.2)
	for i in 4:
		Assets.put(h, "wooden_crate_01", Vector3(33.5, 0.05 + i * 0.42, 6.3), rng.randf_range(-0.2, 0.2), 1.2)
	Assets.put(h, "lifebuoy", Vector3(38, 0.6, 6.15), 0.0, 1.0)
	Assets.put(h, "wooden_lantern_01", Vector3(47, 0.05, 2.3), 0.0, 1.4)
	Assets.put(h, "wooden_lantern_01", Vector3(47, 0.05, 5.7), 0.0, 1.4)
	# market goods by the stalls and the square
	for p: Vector3 in [Vector3(-6, 0, 7.5), Vector3(-5.2, 0, 7.8), Vector3(4.5, 0, 7.6), Vector3(9, 0, -2), Vector3(-11, 0, 3)]:
		Assets.put(h, ["wine_barrel_01", "wooden_crate_02", "wooden_bucket_01"][rng.randi() % 3], p, rng.randf() * TAU, 1.1)
	Assets.put(h, "treasure_chest", Vector3(2.6, 0.15, -7.5), 0.3, 0.9)
	# rocks, ferns and shrubs on the rim
	for i in 10:
		var a := rng.randf() * TAU
		var d := rng.randf_range(24.0, 31.0)
		var pos := Vector3(cos(a) * d, -0.1, sin(a) * d)
		if pos.distance_to(Vector3(40, 0, 4)) < 12.0:
			continue
		Assets.put(h, "rock_moss_set_01" if i % 3 == 0 else "boulder_01", pos, rng.randf() * TAU, rng.randf_range(0.6, 1.2))
	for i in 26:
		var a := rng.randf() * TAU
		var d := rng.randf_range(8.0, 30.0)
		var pos := Vector3(cos(a) * d, 0, sin(a) * d)
		if pos.distance_to(Vector3(20, 0, 4)) < 6.0 or pos.distance_to(Vector3(0, 0, -15)) < 9.0:
			continue
		Assets.put(h, ["fern_02", "shrub_01", "grass_medium_01"][i % 3], pos, rng.randf() * TAU, rng.randf_range(1.0, 2.2))


## Invisible collision so the captain can't walk through a building.
static func _solid(parent: Node3D, pos: Vector3, r: float) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var c := CylinderShape3D.new()
	c.radius = r
	c.height = 6.0
	shape.shape = c
	body.position = pos + Vector3(0, 3, 0)
	body.add_child(shape)
	parent.add_child(body)


static func _silk_reach() -> Node3D:
	var s := Node3D.new()
	s.name = "SilkReach"
	s.add_child(island(SILK_RADIUS, 34.0, 23, 1.2))
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	for row in 4:
		for col in 3:
			var r := Proc.silk_rack(rng)
			r.position = Vector3(-8 + col * 6.5, 0, -10 + row * 5)
			r.rotation.y = 0.2
			s.add_child(r)
	for i in 3:
		var hs := Proc.house(rng, Color("c9b2e8"))
		hs.position = Vector3(10 + i * 4, 0, 8 - i * 6)
		hs.rotation.y = -0.8
		s.add_child(hs)
	for i in 12:
		var a := rng.randf() * TAU
		var t := Proc.round_tree(rng)
		t.position = Vector3(cos(a) * 20, 0, sin(a) * 20)
		s.add_child(t)
	for i in 6:
		s.add_child(Proc.box(Vector3(3.6, 0.3, 4.0), Proc.TIMBER, Vector3(-24 - i * 2.2, -0.1, 14)))
	return s

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
	sky_res.radiance_size = Sky.RADIANCE_SIZE_128
	env.background_mode = Environment.BG_SKY
	env.sky = sky_res
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55 if not hall else 0.25
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.92
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 1.6
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.22
	env.adjustment_contrast = 1.12
	if hall:
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color("1a1410")
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color("6b5240")
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.02
		env.volumetric_fog_albedo = Color("ffe3c0")
		env.volumetric_fog_anisotropy = 0.5
		env.volumetric_fog_length = 40.0
	else:
		env.fog_enabled = true
		env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
		env.fog_light_color = Color("e9c9a3")
		env.fog_density = 0.0009
		env.fog_sun_scatter = 0.35
		env.fog_aerial_perspective = 0.3
		env.fog_sky_affect = 0.15
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.0012
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
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 140.0
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
	var mesh := Proc.island_mesh(radius, depth, seed_value, bumps)
	var mi := Proc.mesh_node(mesh, Proc.vertex_mat())
	root.add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		shape.shape = mesh.create_trimesh_shape()
		body.add_child(shape)
		root.add_child(body)
	Proc.crystals(root, radius, depth, int(radius / 3.0), seed_value + 1)
	return root


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
			var lp := Proc.lantern_post()
			lp.position = p
			h.add_child(lp)
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
			var awn := Proc.box(Vector3(3.0, 0.1, 2.0), [Color("e0705f"), Color("f3d37a"), Color("5fb98a")][i], Vector3(0, 2.4, 0.2))
			awn.rotation.x = 0.25
			stall.add_child(awn)
			for x in [-1.3, 1.3]:
				stall.add_child(Proc.cyl(0.06, 0.06, 2.4, 5, Proc.TIMBER_DARK, Vector3(x, 1.2, 0.9)))
			for k in 3:
				stall.add_child(Proc.box(Vector3(0.5, 0.4, 0.5), [Color("e9a6b8"), Color("f3e9d2"), Color("9fd3e6")][k], Vector3(-0.8 + k * 0.8, 1.2, 0)))
			h.add_child(stall)
		var villagers := [[Color("4e6fa8"), Color("d9a441"), Vector3(-2, 0, 2)], [Color("a8574e"), Color("3a4766"), Vector3(9, 0, 4)],
			[Color("6a8f4e"), Color("8a5a3c"), Vector3(-9, 0, 8)]]
		for v: Array in villagers:
			var f := Proc.figure(v[0], v[1])
			f.position = v[2]
			f.rotation.y = rng.randf() * TAU
			h.add_child(f)
	return h


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

## Pattern: Builder — the hero's ship «Попутчик» (`docs/design/concepts/67…71`), the one realistic thing in the
## game: physically based materials, every part of a small two-masted pirate ship, and no island's technique ever
## redraws her. That exception is made by draw order: every material here is in the transparent pass with a
## priority above the effect's (100), fully opaque and writing depth — so she is not in the picture the effect
## reads and is drawn over it afterwards. Bow at −z, the main deck at y = 0, 12 m on deck.
## See docs/adr/0036-game3d-the-ship-is-the-one-realistic-thing.md
class_name Wayfarer
extends RefCounted

const LENGTH := 12.0
const BEAM := 3.6
const DEPTH := 2.3
const FORE_Z := -2.6  ## where the foremast stands
const MAIN_Z := 1.4
const FORE_TOP := 11.0  ## the height of the mast's head
const MAIN_TOP := 12.3
const COURSE_YARD := 5.7  ## the height of the lower yard of the foremast
const TOPSAIL_YARD := 9.4
const MODEL := "res://assets/models/ship_pinnace/ship_pinnace_1k.gltf"  ## Poly Haven's pinnace (CC0, `make assets`): her hull, masts, rigging and sails when it is downloaded
const MODEL_SCALE := 0.36  ## a 33 m hull made 12 m: the berths and the flight model were cut for that
const MODEL_DECK := 2.98  ## the height of the model's waist deck: it becomes y = 0
const MODEL_LOD_BIAS := 0.15  ## she steps down to her lighter meshes early: a quarter of the triangles from where she is flown, all of them only from a few metres
const MODEL_DRAWN := 60000  ## the budget for the model: triangles drawn from where she is flown and seen in port
const AFTER_EFFECT := 101  ## the render priority of the ship: the island's technique is drawn at 100
const MAX_TRIANGLES := 60000
const MAX_MATERIALS := 24
const RIG_SEEN_TO := 150.0  ## metres: beyond this the ropes are not drawn
const OAK := Color("4a3626")
const DECK := Color("8c6e5a")
const DARK := Color("2e2019")
const GILT := Color("c9a24a")
const IRON := Color("1c1c1e")
const CINNABAR := Color("8c2d19")
const CANVAS := Color("dccdb0")
const HEMP := Color("9a8562")
const ETHER := Color("7fe3ff")

static var _mats: Dictionary = {}
static var _rope_mesh: CylinderMesh


## Every material of the ship is made here and nowhere else, so the exception of ADR-0036 holds for all of them.
## `set_name` is a Poly Haven texture set, used when it is downloaded; `flat` = for quads and triangles (two-sided).
static func material(id: String, colour: Color, rough: float, metal: float = 0.0, set_name: String = "", flat: bool = false, glow: float = 0.0) -> BaseMaterial3D:
	var key := "%s/%s" % [id, flat]
	if _mats.has(key):
		return _mats[key]
	var m: BaseMaterial3D
	if not set_name.is_empty() and Assets.tex(set_name, "diff") != null:
		m = Assets.pbr(set_name, colour.lightened(0.45), 0.45).duplicate()
		m.uv1_world_triplanar = false  # the grain travels with the ship
	else:
		m = StandardMaterial3D.new()
		m.albedo_color = colour
		m.roughness = rough
	m.metallic = metal
	if metal > 0.0:
		m.metallic_specular = 0.7
		m.roughness = rough
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = colour
		m.emission_energy_multiplier = glow
	if flat:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA  # in the transparent pass, after the island's technique…
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS  # …but as solid as wood: it writes depth
	m.render_priority = AFTER_EFFECT
	m.resource_name = id
	_mats[key] = m
	return m


static func oak(flat: bool = false) -> BaseMaterial3D:
	return material("oak", OAK, 0.8, 0.0, "dark_wood", flat)


static func planks(flat: bool = false) -> BaseMaterial3D:
	return material("planks", DECK, 0.85, 0.0, "weathered_planks", flat)


static func dark(flat: bool = false) -> BaseMaterial3D:
	return material("dark", DARK, 0.7, 0.0, "", flat)


static func gilt(flat: bool = false) -> BaseMaterial3D:
	return material("gilt", GILT, 0.35, 0.9, "", flat)


static func iron() -> BaseMaterial3D:
	return material("iron", IRON, 0.5, 0.8)


static func paint() -> BaseMaterial3D:
	return material("cinnabar", CINNABAR, 0.6)


## Sailcloth for sails built from quads and triangles (their UVs are in metres): the same shader as the square
## sails, without the billow. `wet` = the wing sails.
static func canvas(wet: bool) -> ShaderMaterial:
	var key := "cloth/%s" % wet
	if not _mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/ship_sail.gdshader")
		m.set_shader_parameter("billow", 0.0)
		m.set_shader_parameter("wet", 1.0 if wet else 0.0)
		m.set_shader_parameter("cloth_scale", Vector2(0.16, 0.16))
		m.render_priority = AFTER_EFFECT + 1
		m.resource_name = "cloth_wet" if wet else "cloth"
		_mats[key] = m
	return _mats[key]


static func hemp() -> BaseMaterial3D:
	return material("hemp", HEMP, 0.95)


static func lit_glass() -> BaseMaterial3D:
	return material("glass", Color("ffd27a"), 0.3, 0.0, "", false, 1.6)


static func ether() -> BaseMaterial3D:
	return material("ether", ETHER, 0.15, 0.0, "", false, 2.4)


## Half the hull's width at `t` along her (0 = the stern, 1 = the stem).
static func half_beam(t: float) -> float:
	if t < 0.6:
		return BEAM * 0.5 * lerpf(0.76, 1.0, smoothstep(0.0, 0.4, t))
	return BEAM * 0.5 * maxf(pow(cos((t - 0.6) / 0.4 * PI * 0.5), 0.75), 0.03)


## The height of the deck's edge at `t`: the sheer rises to the stern and to the bow.
static func sheer(t: float) -> float:
	var aft := 0.55 * pow(maxf(0.3 - t, 0.0) / 0.3, 2.0)
	return aft + maxf(t - 0.72, 0.0) * 2.2


static func along(t: float) -> float:
	return LENGTH * 0.5 - LENGTH * t


## A point on the hull's side at `t`, `up` metres above the deck's edge, `out` metres proud of the planking.
static func side(t: float, sd: float, up: float = 0.0, out: float = 0.0) -> Vector3:
	return Vector3(sd * (half_beam(t) + out), sheer(t) + up, along(t))


## True when the pinnace is downloaded: then she is the ship, and what is built here is added to her.
static func has_model() -> bool:
	return ResourceLoader.exists(MODEL)


## A point given in the model's own space (bow at +z, metres of the real ship) as it lies in the ship's space.
static func at(x: float, y: float, z: float) -> Vector3:
	return Vector3(-x * MODEL_SCALE, (y - MODEL_DECK) * MODEL_SCALE, -z * MODEL_SCALE)


## Where the monkey may sit and run, in the ship's own space: yards, tops and the rail — of the pinnace when she
## is the ship (`model`), else of the built one.
static func perches(model: bool = has_model()) -> Array[Vector3]:
	if model:
		return [at(-3.4, 12.6, 9.4), at(0.5, 12.6, 9.4), at(3.4, 12.6, 9.4), at(0.7, 14.2, 9.7), at(2.4, 18.6, -2.4), at(-2.4, 18.6, -2.4),
			at(0.7, 15.6, -1.8), at(3.6, 12.7, -2.6), at(-4.3, 4.5, 2.0)]
	return [Vector3(-2.6, COURSE_YARD + 0.14, FORE_Z), Vector3(0.4, COURSE_YARD + 0.14, FORE_Z), Vector3(2.6, COURSE_YARD + 0.14, FORE_Z),
		Vector3(0.45, 6.6, FORE_Z), Vector3(1.7, TOPSAIL_YARD + 0.12, FORE_Z), Vector3(-1.7, TOPSAIL_YARD + 0.12, FORE_Z),
		Vector3(0.45, 7.1, MAIN_Z), Vector3(1.5, 0.92, -0.4)]


## The sails are set by `trim` (0 furled … 1 full): the two square sails are gathered up to their yards.
static func set_trim(ship: Node3D, trim: float, weight: float = 1.0) -> void:
	for s: Array in [["Sail", COURSE_YARD, 3.5], ["Topsail", TOPSAIL_YARD, 3.1]]:
		var sail: Node3D = ship.get_node_or_null(str(s[0]))
		if sail == null:
			continue
		sail.scale.y = lerpf(sail.scale.y, lerpf(0.22, 1.0, clampf(trim, 0.0, 1.0)), weight)
		sail.position.y = float(s[1]) - 0.12 - float(s[2]) * 0.5 * sail.scale.y


## How many triangles the ship is at full detail, and how many different materials she is made of.
static func cost(ship: Node3D) -> Vector2i:
	var tris := 0
	var mats: Dictionary = {}
	for mi: MeshInstance3D in ship.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(i)
			tris += (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3 if arr[Mesh.ARRAY_INDEX] != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
			var m := mi.get_active_material(i)
			mats[m] = true
	return Vector2i(tris, mats.size())


## The ship. With `model` and the pinnace downloaded: Poly Haven's model, scaled and turned, every material of it
## put after the island's technique, and on it only the crystal, the flag and the light of her stern lanterns: the
## bird, the wind spirit, the name board and the wing sails built in code fell short of her (ADR-0036, amendment 2). Otherwise the ship built here part by part.
static func build(model: bool = true) -> Node3D:
	var s := Node3D.new()
	s.name = "Wayfarer"
	s.set_meta("flat", true)  # beyond the pier's rail: nobody walks her yet
	var pinnace := _pinnace() if model and has_model() else null
	if pinnace != null:
		s.set_meta("model", true)
		s.add_child(pinnace)
		s.add_child(_pinnace_lights())  # the pinnace is carved already: only the light of her stern lanterns is added
	else:
		s.add_child(_hull())
		s.add_child(_castles())
		s.add_child(_stern())
		s.add_child(_spars())
		s.add_child(_rigging())
		s.add_child(_figurehead())
		s.add_child(_deck_things())
		for sail: Array in [["Sail", COURSE_YARD, 5.6, 3.5, 0.55], ["Topsail", TOPSAIL_YARD, 4.0, 3.1, 0.4]]:
			s.add_child(_square_sail(sail[0], sail[1], sail[2], sail[3], sail[4]))
		s.add_child(_fore_and_aft_sails())
	for sd: float in [-1.0, 1.0]:
		if pinnace == null:  # the wing sails were flat fans beside her real cloth: the pinnace has none (ADR-0036, amendment 2)
			s.add_child(_wing(sd))
	var crystal := _crystal()
	var flag := _flag()
	if pinnace != null:
		crystal.position = at(0, -3.9, 0.5)
		flag.position = at(0, 28.9, -1.8) + Vector3(0, 0, 1.2)
	s.add_child(crystal)
	s.add_child(flag)
	set_trim(s, 1.0)
	return s


## Poly Haven's pinnace as the ship: scaled to twelve metres, turned bow to −z, her waist deck at y = 0. Every
## material is copied into the pass after the island's technique (ADR-0036); the sails get a shader that keeps
## their texture and shape and ripples them. What is inside the hull is not drawn. The rigging — two fifths of her
## triangles — is not drawn from far away, and every mesh steps down its LODs early (`MODEL_LOD_BIAS`).
static func _pinnace() -> Node3D:
	var scene: PackedScene = load(MODEL)
	if scene == null:
		return null
	var n: Node3D = scene.instantiate()
	n.name = "Pinnace"
	n.scale = Vector3.ONE * MODEL_SCALE
	n.rotation.y = PI
	n.position = Vector3(0, -MODEL_DECK * MODEL_SCALE, 0)
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		if str(mi.name).contains("interior"):
			mi.free()  # not in the tree yet: gone at once
			continue
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		mi.lod_bias = MODEL_LOD_BIAS
		if str(mi.name).contains("rigging"):
			mi.visibility_range_end = RIG_SEEN_TO
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # ropes: two fifths of her triangles, in four cascades, for shadows nobody sees
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i) as BaseMaterial3D
			if src == null:
				continue
			mi.set_surface_override_material(i, _hull_after_effect(src) if str(mi.name).ends_with("hull") else _after_effect(src, str(mi.name).contains("sails")))
	return n


## The hull's material drawn after the island's technique, its white bottom toned down to the planking
## (`shaders/ship_model_hull.gdshader`, ADR-0036 amendment 3).
static func _hull_after_effect(src: BaseMaterial3D) -> Material:
	if not _mats.has("model/hull"):
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/ship_model_hull.gdshader")
		m.set_shader_parameter("albedo_tex", src.albedo_texture)
		m.set_shader_parameter("orm_tex", src.roughness_texture if src.roughness_texture != null else src.albedo_texture)
		m.set_shader_parameter("has_normal", src.normal_enabled and src.normal_texture != null)
		if src.normal_texture != null:
			m.set_shader_parameter("normal_tex", src.normal_texture)
		m.render_priority = AFTER_EFFECT
		m.resource_name = "model/hull"
		_mats["model/hull"] = m
	return _mats["model/hull"]


## A copy of one of the model's materials that is drawn after the island's technique. `sail`: the cut-out cloth,
## with its ripple.
static func _after_effect(src: BaseMaterial3D, sail: bool) -> Material:
	var key := "model/%s" % src.resource_name if not src.resource_name.is_empty() else "model/%d" % src.get_instance_id()
	if _mats.has(key):
		return _mats[key]
	var out: Material
	if sail:
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/ship_model_sail.gdshader")
		m.set_shader_parameter("albedo_tex", src.albedo_texture)
		m.set_shader_parameter("orm_tex", src.roughness_texture if src.roughness_texture != null else src.albedo_texture)
		m.set_shader_parameter("has_normal", src.normal_enabled and src.normal_texture != null)
		if src.normal_texture != null:
			m.set_shader_parameter("normal_tex", src.normal_texture)
		m.render_priority = AFTER_EFFECT + 1
		out = m
	else:
		var m: BaseMaterial3D = src.duplicate()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
		m.albedo_color.a = 1.0
		m.render_priority = AFTER_EFFECT
		out = m
	out.resource_name = key
	_mats[key] = out
	return out


## The light of the pinnace's stern lanterns, at each quarter of the taffrail: lights only, her own carving stays.
static func _pinnace_lights() -> Node3D:
	var n := Node3D.new()
	n.name = "Stern"
	for sx: float in [-1.0, 1.0]:
		var lamp := OmniLight3D.new()
		lamp.name = "LanternL" if sx < 0.0 else "LanternR"
		lamp.light_color = Color("ffc66e")
		lamp.light_energy = 0.9
		lamp.omni_range = 5.0
		lamp.position = at(sx * 3.3, 10.4, -18.3)
		n.add_child(lamp)
	return n


## The hull: a lofted shell of oak, the deck, the bulwarks with their rail, a wale and a gilded strake, gun ports
## with their lids up and the muzzles showing.
static func _hull() -> Node3D:
	var n := Node3D.new()
	n.name = "Hull"
	var profile := [Vector2(1.0, 0.0), Vector2(0.96, -0.42), Vector2(0.66, -0.82), Vector2(0.0, -1.0)]
	var slices := 24
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	for sd: float in [-1.0, 1.0]:
		for i in slices:
			var t0 := float(i) / slices
			var t1 := float(i + 1) / slices
			for k in profile.size() - 1:
				var q: Array[Vector3] = []
				for c: Array in [[t0, k], [t1, k], [t1, k + 1], [t0, k + 1]]:
					var t: float = c[0]
					var p: Vector2 = profile[c[1]]
					var deep := DEPTH * (0.45 + 0.55 * half_beam(t) / (BEAM * 0.5))
					q.append(Vector3(sd * half_beam(t) * p.x, sheer(t) + p.y * deep, along(t)))
				for v: Vector3 in ([q[0], q[1], q[2], q[0], q[2], q[3]] if sd > 0.0 else [q[0], q[2], q[1], q[0], q[3], q[2]]):
					st.add_vertex(v)
	st.generate_normals()
	var shell := Proc.mesh_node(st.commit(), oak(true))
	shell.name = "Shell"
	n.add_child(shell)
	var kq := Kit.new()
	for i in slices:
		var t0 := float(i) / slices
		var t1 := float(i + 1) / slices
		kq.quad(planks(true), side(t0, -1.0, -0.02), side(t0, 1.0, -0.02), side(t1, 1.0, -0.02), side(t1, -1.0, -0.02))  # the deck
		for sd: float in [-1.0, 1.0]:
			kq.quad(oak(true), side(t0, sd), side(t1, sd), side(t1, sd, 0.78), side(t0, sd, 0.78))  # the bulwark
			kq.quad(dark(true), side(t0, sd, 0.78, -0.08), side(t1, sd, 0.78, -0.08), side(t1, sd, 0.78, 0.1), side(t0, sd, 0.78, 0.1))  # its rail
			kq.quad(dark(true), side(t0, sd, -0.22, 0.05), side(t1, sd, -0.22, 0.05), side(t1, sd, -0.42, 0.04), side(t0, sd, -0.42, 0.04))  # the wale
			kq.quad(gilt(true), side(t0, sd, 0.6, 0.03), side(t1, sd, 0.6, 0.03), side(t1, sd, 0.52, 0.03), side(t0, sd, 0.52, 0.03))
	kq.quad(oak(true), side(0.0, -1.0, 0.78), side(0.0, 1.0, 0.78), side(0.0, 1.0, -1.2), side(0.0, -1.0, -1.2))  # the transom
	n.add_child(kq.commit("Planking", false))
	var kb := Kit.new()
	for sd: float in [-1.0, 1.0]:
		for t: float in [0.3, 0.42, 0.56]:  # gun ports: a dark opening, a muzzle, a red lid held up
			var at := side(t, sd, -0.72, -0.04)
			kb.box(dark(), Vector3(0.1, 0.46, 0.5), at)
			kb.mesh(iron(), Proc._cyl_mesh(0.09, 0.11, 0.5, 8), Transform3D(Basis(Vector3.FORWARD, PI / 2), at + Vector3(sd * 0.2, 0, 0)))
			kb.box(paint(), Vector3(0.06, 0.46, 0.5), at + Vector3(sd * 0.22, 0.42, 0), Vector3(0, 0, sd * 0.9))
	kb.box(dark(), Vector3(0.12, DEPTH + 0.6, 0.5), Vector3(0, -DEPTH * 0.5 + 0.1, LENGTH * 0.5 + 0.12))  # the rudder
	for y: float in [-0.4, -1.3]:
		kb.box(iron(), Vector3(0.2, 0.08, 0.6), Vector3(0, y, LENGTH * 0.5 + 0.1))
	n.add_child(kb.commit("Ports"))
	return n


## The forecastle and the quarterdeck: raised decks with their bulkheads, ladders and rails.
static func _castles() -> Node3D:
	var n := Node3D.new()
	n.name = "Castles"
	var k := Kit.new()
	# the quarterdeck, aft
	k.box(oak(), Vector3(2.9, 1.5, 3.5), Vector3(0, 0.75, 4.3))
	k.box(planks(), Vector3(3.1, 0.08, 3.7), Vector3(0, 1.54, 4.3))
	k.box(dark(), Vector3(0.7, 1.2, 0.06), Vector3(0, 0.6, 2.52))  # the cabin door
	k.box(gilt(), Vector3(0.06, 0.06, 0.05), Vector3(0.22, 0.62, 2.48))
	for x: float in [-1.0, 1.0]:
		k.box(lit_glass(), Vector3(0.4, 0.4, 0.05), Vector3(x, 0.95, 2.53))
		for i in 5:  # the ladders
			k.box(dark(), Vector3(0.5, 0.05, 0.2), Vector3(x * 1.2, 0.25 + i * 0.26, 2.3 - i * 0.02 + 0.1))
		for z: float in [2.6, 3.8, 5.0, 6.0]:  # rail posts
			k.box(dark(), Vector3(0.08, 0.7, 0.08), Vector3(x * 1.5, 1.9, z))
		k.box(dark(), Vector3(0.1, 0.08, 3.6), Vector3(x * 1.5, 2.27, 4.3))
	for x: float in [-1.0, -0.33, 0.33, 1.0]:
		k.box(dark(), Vector3(0.07, 0.6, 0.07), Vector3(x * 1.2, 1.85, 2.58))
	k.box(dark(), Vector3(3.0, 0.08, 0.1), Vector3(0, 2.17, 2.58))
	n.add_child(k.commit("Decks"))
	var kq := Kit.new()  # the forecastle: a deck level with the rail, following the bows, with its bulkhead and rail
	var steps := 8
	for i in steps:
		var t0 := lerpf(0.77, 0.985, float(i) / steps)
		var t1 := lerpf(0.77, 0.985, float(i + 1) / steps)
		kq.quad(planks(true), side(t0, -1.0, 0.7), side(t0, 1.0, 0.7), side(t1, 1.0, 0.7), side(t1, -1.0, 0.7))
		for sd: float in [-1.0, 1.0]:
			kq.quad(dark(true), side(t0, sd, 1.2, 0.02), side(t1, sd, 1.2, 0.02), side(t1, sd, 1.28, 0.02), side(t0, sd, 1.28, 0.02))
			kq.quad(dark(true), side(t0, sd, 0.78, 0.04), side(t0, sd, 1.24, 0.04), side(t0, sd, 1.24, -0.04), side(t0, sd, 0.78, -0.04))
	kq.quad(oak(true), side(0.77, -1.0, 0.7), side(0.77, 1.0, 0.7), side(0.77, 1.0, -0.02), side(0.77, -1.0, -0.02))
	n.add_child(kq.commit("Forecastle", false))
	return n


## The carved stern of sheet 69: a gallery of five lit windows between gilded mouldings, the wind spirit's face
## under them, the name on a gilded board, a taffrail that rises in the middle, two lanterns on brackets.
static func _stern() -> Node3D:
	var n := Node3D.new()
	n.name = "Stern"
	var z := LENGTH * 0.5 + 0.28
	var k := Kit.new()
	k.box(oak(), Vector3(3.0, 2.3, 0.5), Vector3(0, 1.05, z - 0.02))
	for y: float in [0.05, 0.78, 1.7, 2.22]:  # mouldings
		k.box(gilt(), Vector3(3.14, 0.09, 0.6), Vector3(0, y, z))
	for i in 5:  # the gallery windows, arched
		var x := -1.12 + i * 0.56
		k.box(dark(), Vector3(0.46, 0.8, 0.06), Vector3(x, 1.24, z + 0.26))
		k.box(lit_glass(), Vector3(0.36, 0.62, 0.07), Vector3(x, 1.2, z + 0.27))
		k.mesh(lit_glass(), Proc._cyl_mesh(0.18, 0.18, 0.07, 10), Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(x, 1.51, z + 0.27)))
		k.box(dark(), Vector3(0.03, 0.74, 0.09), Vector3(x, 1.24, z + 0.27))
		k.box(dark(), Vector3(0.36, 0.03, 0.09), Vector3(x, 1.2, z + 0.27))
	for i in 7:  # the taffrail: a carved board, highest in the middle
		var x := -1.26 + i * 0.42
		var h := 0.5 + 0.5 * cos((i - 3) / 3.0 * PI * 0.5)
		k.box(oak(), Vector3(0.44, h, 0.3), Vector3(x, 2.26 + h * 0.5, z - 0.05))
		k.mesh(gilt(), Proc._sphere(0.1), Transform3D(Basis(), Vector3(x, 2.26 + h, z + 0.06)))
		k.mesh(gilt(), Proc._cyl_mesh(0.13, 0.13, 0.06, 10), Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(x, 2.3 + h * 0.5, z + 0.11)))
	# the wind spirit: a round gilded face with puffed cheeks and hair blown to both sides
	var face := Vector3(0, 0.42, z + 0.3)
	k.mesh(gilt(), Proc._sphere(0.27), Transform3D(Basis().scaled(Vector3(1.0, 1.05, 0.6)), face))
	for sx: float in [-1.0, 1.0]:
		k.mesh(gilt(), Proc._sphere(0.11), Transform3D(Basis(), face + Vector3(sx * 0.15, -0.07, 0.11)))
		for j in 4:
			k.mesh(gilt(), Proc._cyl_mesh(0.04, 0.07, 0.5 + j * 0.1, 6), Transform3D(Basis(Vector3.BACK, sx * (1.2 + j * 0.16)), face + Vector3(sx * (0.42 + j * 0.08), 0.12 - j * 0.09, -0.02)))
	k.mesh(gilt(), Proc._sphere(0.045), Transform3D(Basis(), face + Vector3(0, -0.02, 0.17)))
	k.box(gilt(), Vector3(2.0, 0.3, 0.05), Vector3(0, -0.22, z + 0.2))  # the name board
	for sx: float in [-1.0, 1.0]:  # the stern lanterns on their brackets
		var at := Vector3(sx * 1.7, 2.35, z + 0.25)
		k.box(iron(), Vector3(0.3, 0.05, 0.05), at + Vector3(-sx * 0.2, -0.42, 0))
		k.box(iron(), Vector3(0.05, 0.3, 0.05), at + Vector3(0, -0.3, 0))
		k.mesh(lit_glass(), Proc._cyl_mesh(0.14, 0.11, 0.36, 6), Transform3D(Basis(), at))
		k.mesh(gilt(), Proc._cyl_mesh(0.03, 0.18, 0.16, 6), Transform3D(Basis(), at + Vector3(0, 0.26, 0)))
		k.mesh(gilt(), Proc._cyl_mesh(0.16, 0.16, 0.04, 6), Transform3D(Basis(), at + Vector3(0, -0.2, 0)))
		for a in 6:
			var r := Vector3(cos(a * TAU / 6.0), 0, sin(a * TAU / 6.0)) * 0.14
			k.box(gilt(), Vector3(0.02, 0.36, 0.02), at + r)
		var lamp := OmniLight3D.new()
		lamp.name = "LanternL" if sx < 0.0 else "LanternR"
		lamp.light_color = Color("ffc66e")
		lamp.light_energy = 0.9
		lamp.omni_range = 5.0
		lamp.position = at
		n.add_child(lamp)
	n.add_child(k.commit("Carving"))
	var name_board := Label3D.new()
	name_board.name = "Name"
	name_board.text = "ПОПУТЧИК"
	name_board.font_size = 40
	name_board.pixel_size = 0.0058
	name_board.modulate = Color("2a1c12")
	name_board.outline_size = 0
	name_board.position = Vector3(0, -0.22, z + 0.235)
	name_board.render_priority = AFTER_EFFECT + 2
	n.add_child(name_board)
	return n


## Masts with their tops and caps, the yards of the foremast, the gaff and the boom of the main, the bowsprit.
static func _spars() -> Node3D:
	var n := Node3D.new()
	n.name = "Spars"
	var k := Kit.new()
	for m: Array in [[FORE_Z, FORE_TOP, 6.5], [MAIN_Z, MAIN_TOP, 7.0]]:
		var z: float = m[0]
		var top: float = m[1]
		var platform: float = m[2]
		k.mesh(dark(), Proc._cyl_mesh(0.13, 0.19, platform, 10), Transform3D(Basis(), Vector3(0, platform * 0.5, z)))
		k.mesh(dark(), Proc._cyl_mesh(0.07, 0.11, top - platform + 0.6, 8), Transform3D(Basis(), Vector3(0, (top + platform - 0.6) * 0.5, z + 0.16)))
		k.mesh(oak(), Proc._cyl_mesh(0.72, 0.6, 0.1, 12), Transform3D(Basis(), Vector3(0, platform, z + 0.06)))  # the top
		k.box(iron(), Vector3(0.34, 0.12, 0.5), Vector3(0, platform - 0.5, z + 0.08))
		k.mesh(gilt(), Proc._sphere(0.08), Transform3D(Basis(), Vector3(0, top + 0.05, z + 0.16)))
		for a in 8:  # the top's rail
			var r := Vector3(cos(a * TAU / 8.0), 0, sin(a * TAU / 8.0)) * 0.66
			k.box(dark(), Vector3(0.04, 0.4, 0.04), Vector3(0, platform + 0.25, z + 0.06) + r)
	for y: Array in [[COURSE_YARD, 6.6, 0.1], [TOPSAIL_YARD, 4.6, 0.08]]:  # the yards
		k.mesh(dark(), Proc._cyl_mesh(float(y[2]), float(y[2]), float(y[1]), 8), Transform3D(Basis(Vector3.BACK, PI / 2), Vector3(0, y[0], FORE_Z - 0.24)))
		for sx: float in [-1.0, 1.0]:
			k.mesh(dark(), Proc._cyl_mesh(float(y[2]) * 0.6, float(y[2]), 0.5, 8), Transform3D(Basis(Vector3.BACK, sx * PI / 2), Vector3(sx * (float(y[1]) * 0.5 + 0.2), y[0], FORE_Z - 0.24)))
	_spar(k, Vector3(0, 2.5, MAIN_Z + 0.2), Vector3(0, 2.8, 6.9), 0.09)  # the boom
	_spar(k, Vector3(0, 8.2, MAIN_Z + 0.2), Vector3(0, 10.5, 5.7), 0.07)  # the gaff
	_spar(k, Vector3(0, 1.25, -5.0), Vector3(0, 2.75, -9.8), 0.13)  # the bowsprit
	k.box(iron(), Vector3(0.32, 0.1, 0.3), Vector3(0, 1.5, -5.6))
	n.add_child(k.commit("Timber"))
	return n


static func _spar(k: Kit, a: Vector3, b: Vector3, r: float) -> void:
	k.mesh(dark(), Proc._cyl_mesh(r * 0.7, r, 1.0, 8), _between(a, b, 1.0))


## A transform that lays a unit-high cylinder from `a` to `b`, `r` times as thick.
static func _between(a: Vector3, b: Vector3, r: float) -> Transform3D:
	var d := b - a
	var up := d.normalized()
	var x := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(up)
	return Transform3D(Basis(x * r, d, z * r), (a + b) * 0.5)


static func _rope(k: Kit, a: Vector3, b: Vector3, r: float = 0.022) -> void:
	if _rope_mesh == null:
		_rope_mesh = CylinderMesh.new()
		_rope_mesh.top_radius = 1.0
		_rope_mesh.bottom_radius = 1.0
		_rope_mesh.height = 1.0
		_rope_mesh.radial_segments = 5
		_rope_mesh.rings = 0
	k.mesh(hemp(), _rope_mesh, _between(a, b, r))


## The standing rigging: four shrouds a side on each mast with their ratlines and deadeyes, stays to the bowsprit
## and between the masts, backstays; and the lifts and braces of the yards. One mesh, not drawn from far away.
static func _rigging() -> Node3D:
	var n := Node3D.new()
	n.name = "Rigging"
	var k := Kit.new()
	var kd := Kit.new()
	for m: Array in [[FORE_Z, 6.5], [MAIN_Z, 7.0]]:
		var z: float = m[0]
		var top: float = m[1]
		for sd: float in [-1.0, 1.0]:
			var feet: Array[Vector3] = []
			for i in 4:
				var zc := z + 0.25 + i * 0.5
				var t := (LENGTH * 0.5 - zc) / LENGTH
				var foot := side(t, sd, 0.8, 0.12)
				feet.append(foot)
				var head := Vector3(sd * 0.3, top - 0.05, z + 0.06)
				_rope(k, foot + Vector3(0, 0.42, 0), head, 0.026)
				for j in 2:  # a pair of deadeyes and their lanyard
					kd.mesh(dark(), Proc._cyl_mesh(0.075, 0.075, 0.05, 8), Transform3D(Basis(Vector3.BACK, PI / 2), foot + Vector3(0, 0.08 + j * 0.3, 0)))
				_rope(k, foot + Vector3(0, 0.08, 0), foot + Vector3(0, 0.38, 0), 0.014)
			var head := Vector3(sd * 0.3, top - 0.05, z + 0.06)
			var steps := int((top - 2.0) / 0.5)
			for j in steps:  # ratlines
				var f := (1.2 + j * 0.5) / (top - 0.8)
				_rope(k, (feet[0] + Vector3(0, 0.42, 0)).lerp(head, f), (feet[3] + Vector3(0, 0.42, 0)).lerp(head, f), 0.012)
	var tip := Vector3(0, 2.72, -9.7)
	_rope(k, Vector3(0, FORE_TOP - 0.1, FORE_Z + 0.16), tip)  # the stays
	_rope(k, Vector3(0, 6.6, FORE_Z), Vector3(0, 2.2, -7.9))
	_rope(k, Vector3(0, MAIN_TOP - 0.1, MAIN_Z + 0.16), Vector3(0, 6.7, FORE_Z + 0.1))
	_rope(k, Vector3(0, 7.0, MAIN_Z), Vector3(0, 1.2, FORE_Z + 0.2))
	_rope(k, tip, Vector3(0, -0.2, -6.0), 0.03)  # the bobstay
	for sd: float in [-1.0, 1.0]:
		_rope(k, Vector3(0, MAIN_TOP - 0.2, MAIN_Z + 0.16), side(0.06, sd, 0.8, 0.1))  # backstays
		_rope(k, Vector3(0, FORE_TOP - 0.2, FORE_Z + 0.16), side(0.52, sd, 0.8, 0.1))
		_rope(k, Vector3(sd * 3.4, COURSE_YARD, FORE_Z - 0.24), Vector3(0, 7.6, FORE_Z + 0.1), 0.014)  # lifts
		_rope(k, Vector3(sd * 2.4, TOPSAIL_YARD, FORE_Z - 0.24), Vector3(0, FORE_TOP - 0.3, FORE_Z + 0.16), 0.014)
		_rope(k, Vector3(sd * 3.4, COURSE_YARD, FORE_Z - 0.24), side(0.3, sd, 0.8, 0.0), 0.014)  # braces
		_rope(k, Vector3(sd * 2.4, TOPSAIL_YARD, FORE_Z - 0.24), Vector3(sd * 0.3, 7.0, MAIN_Z), 0.012)
		_rope(k, Vector3(0, 10.5, 5.7), side(0.02, sd, 0.8, 0.0), 0.014)  # the gaff's vangs
	_rope(k, Vector3(0, 2.8, 6.9), Vector3(0, 2.3, 5.9), 0.02)  # the sheet of the boom
	_rope(k, Vector3(0, 10.5, 5.7), Vector3(0, MAIN_TOP - 0.3, MAIN_Z + 0.16), 0.014)  # the peak halyard
	var ropes := k.commit("Ropes", false)
	ropes.visibility_range_end = RIG_SEEN_TO
	n.add_child(ropes)
	var eyes := kd.commit("Deadeyes")
	eyes.visibility_range_end = RIG_SEEN_TO
	n.add_child(eyes)
	return n


## The figurehead of sheet 69: a gilded bird of prey under the bowsprit, neck stretched forward, wings swept up
## and back along the bows.
static func _figurehead() -> Node3D:
	var n := Node3D.new()
	n.name = "Figurehead"
	n.position = Vector3(0, 0.9, -6.2)
	var k := Kit.new()
	k.mesh(gilt(), Proc._sphere(0.5), Transform3D(Basis(Vector3.RIGHT, -0.45).scaled(Vector3(0.46, 0.5, 1.25)), Vector3(0, 0, -0.05)))  # the body
	k.mesh(gilt(), Proc._cyl_mesh(0.09, 0.13, 0.42, 8), Transform3D(Basis(Vector3.RIGHT, -1.0), Vector3(0, 0.3, -0.62)))  # the neck
	k.mesh(gilt(), Proc._sphere(0.5), Transform3D(Basis().scaled(Vector3(0.22, 0.22, 0.3)), Vector3(0, 0.42, -0.84)))  # the head
	k.mesh(gilt(), Proc._cyl_mesh(0.0, 0.055, 0.2, 6), Transform3D(Basis(Vector3.RIGHT, -PI / 2 - 0.5), Vector3(0, 0.37, -1.03)))  # the hooked beak
	for sx: float in [-1.0, 1.0]:
		k.mesh(dark(), Proc._sphere(0.022), Transform3D(Basis(), Vector3(sx * 0.085, 0.46, -0.92)))
		k.box(gilt(), Vector3(0.05, 0.3, 0.05), Vector3(sx * 0.1, -0.4, 0.05), Vector3(0.4, 0, 0))  # the legs, drawn up
	n.add_child(k.commit("Bird"))
	var kq := Kit.new()
	for sd: float in [-1.0, 1.0]:  # each wing: one surface of six feathers, fanning up and back
		var shoulder := Vector3(sd * 0.16, 0.18, -0.2)
		var elbow := shoulder + Vector3(sd * 0.25, -0.2, 0.5)
		var tips: Array[Vector3] = []
		for j in 7:
			var a := 0.15 + j * 0.2
			var reach := 1.5 - absf(j - 2.5) * 0.12
			tips.append(shoulder + Vector3(sd * (0.3 + j * 0.13), sin(a) * reach, cos(a) * reach * 0.95))
		for j in 6:
			var notch := tips[j].lerp(tips[j + 1], 0.5).lerp(shoulder, 0.14)  # the gap between two feathers
			kq.tri(gilt(true), shoulder, tips[j], notch)
			kq.tri(gilt(true), shoulder, notch, tips[j + 1])
		kq.tri(gilt(true), shoulder, tips[6], elbow)
	n.add_child(kq.commit("Wings", false))
	return n


## What stands on deck (sheet 70): the wheel, the capstan, the grating, four guns on their carriages, barrels, a
## coil of rope, and the anchor catted at the starboard bow.
static func _deck_things() -> Node3D:
	var n := Node3D.new()
	n.name = "DeckThings"
	var k := Kit.new()
	var wheel := Vector3(0, 2.25, 3.3)  # the wheel: a rim, eight spokes with their handles, a stand
	k.box(dark(), Vector3(0.16, 0.7, 0.3), Vector3(0, 1.9, 3.42))
	var rim := TorusMesh.new()
	rim.inner_radius = 0.3
	rim.outer_radius = 0.37
	rim.rings = 16
	rim.ring_segments = 6
	k.mesh(dark(), rim, Transform3D(Basis(Vector3.RIGHT, PI / 2), wheel))
	for a in 8:
		k.mesh(dark(), Proc._cyl_mesh(0.018, 0.022, 0.98, 5), Transform3D(Basis(Vector3.BACK, a * PI / 8.0), wheel))
	k.mesh(gilt(), Proc._cyl_mesh(0.07, 0.07, 0.1, 8), Transform3D(Basis(Vector3.RIGHT, PI / 2), wheel))
	k.box(dark(), Vector3(1.3, 0.05, 1.3), Vector3(0, 0.03, -0.6))  # the grating
	for i in 6:
		k.box(planks(), Vector3(1.2, 0.06, 0.06), Vector3(0, 0.05, -1.1 + i * 0.2))
		k.box(planks(), Vector3(0.06, 0.07, 1.2), Vector3(-0.5 + i * 0.2, 0.05, -0.6))
	k.mesh(dark(), Proc._cyl_mesh(0.2, 0.28, 0.6, 10), Transform3D(Basis(), Vector3(0, 1.3, -4.3)))  # the capstan
	k.mesh(dark(), Proc._cyl_mesh(0.3, 0.3, 0.1, 10), Transform3D(Basis(), Vector3(0, 1.63, -4.3)))
	for a in 4:
		k.mesh(dark(), Proc._cyl_mesh(0.025, 0.025, 1.3, 5), Transform3D(Basis(Vector3.UP, a * PI / 4.0) * Basis(Vector3.BACK, PI / 2), Vector3(0, 1.63, -4.3)))
	for sd: float in [-1.0, 1.0]:
		for z: float in [-1.5, 0.3]:  # the guns
			var at := Vector3(sd * 1.12, 0, z)
			k.box(oak(), Vector3(0.7, 0.2, 0.44), at + Vector3(0, 0.22, 0))
			k.box(oak(), Vector3(0.4, 0.14, 0.44), at + Vector3(-sd * 0.12, 0.38, 0))
			k.mesh(iron(), Proc._cyl_mesh(0.07, 0.11, 0.95, 10), Transform3D(Basis(Vector3.BACK, sd * PI / 2), at + Vector3(sd * 0.12, 0.5, 0)))
			k.mesh(iron(), Proc._sphere(0.09), Transform3D(Basis(), at + Vector3(-sd * 0.38, 0.5, 0)))
			for wx: float in [-0.22, 0.22]:
				for wz: float in [-0.25, 0.25]:
					k.mesh(dark(), Proc._cyl_mesh(0.11, 0.11, 0.06, 8), Transform3D(Basis(Vector3.RIGHT, PI / 2), at + Vector3(wx, 0.11, wz)))
		for b: Array in [[1.0, 1.95], [0.55, 2.05]]:  # barrels by the quarterdeck
			var at := Vector3(sd * float(b[0]), 0, b[1])
			k.mesh(oak(), Proc._cyl_mesh(0.2, 0.24, 0.3, 10), Transform3D(Basis(), at + Vector3(0, 0.56, 0)))
			k.mesh(oak(), Proc._cyl_mesh(0.24, 0.24, 0.16, 10), Transform3D(Basis(), at + Vector3(0, 0.33, 0)))
			k.mesh(oak(), Proc._cyl_mesh(0.24, 0.2, 0.3, 10), Transform3D(Basis(), at + Vector3(0, 0.15, 0)))
			for y: float in [0.1, 0.33, 0.6]:
				k.mesh(iron(), Proc._cyl_mesh(0.245, 0.245, 0.03, 10), Transform3D(Basis(), at + Vector3(0, y, 0)))
	for i in 4:  # a coil of rope on the forecastle
		var coil := TorusMesh.new()
		coil.inner_radius = 0.16 + i * 0.02
		coil.outer_radius = 0.22 + i * 0.02
		coil.rings = 12
		coil.ring_segments = 5
		k.mesh(hemp(), coil, Transform3D(Basis(), Vector3(-0.55, 1.03 + i * 0.045, -3.7)))
	n.add_child(k.commit("Things"))
	var anchor := Node3D.new()  # the anchor, catted at the starboard bow
	anchor.name = "Anchor"
	anchor.position = side(0.84, 1.0, -0.1, 0.16)
	var ka := Kit.new()
	ka.box(iron(), Vector3(0.08, 1.2, 0.08), Vector3(0, -0.3, 0))
	ka.box(dark(), Vector3(0.1, 0.1, 0.9), Vector3(0, 0.2, 0))
	for sz: float in [-1.0, 1.0]:
		ka.box(iron(), Vector3(0.07, 0.5, 0.08), Vector3(0, -0.75, sz * 0.2), Vector3(sz * 0.9, 0, 0))
		ka.box(iron(), Vector3(0.05, 0.18, 0.22), Vector3(0, -0.62, sz * 0.4), Vector3(sz * 0.9, 0, 0))
	var ring := TorusMesh.new()
	ring.inner_radius = 0.07
	ring.outer_radius = 0.1
	ring.rings = 10
	ring.ring_segments = 5
	ka.mesh(iron(), ring, Transform3D(Basis(Vector3.BACK, PI / 2), Vector3(0, 0.36, 0)))
	anchor.add_child(ka.commit("Iron"))
	n.add_child(anchor)
	return n


## A square sail of the foremast: cloth that billows forward, hung from its yard; `set_trim` gathers it up.
static func _square_sail(name: String, yard: float, width: float, height: float, billow: float) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2(width, height)
	plane.subdivide_width = 10
	plane.subdivide_depth = 8
	plane.orientation = PlaneMesh.FACE_Z
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/ship_sail.gdshader")
	m.set_shader_parameter("billow", billow)
	m.render_priority = AFTER_EFFECT + 1
	var sail := Proc.mesh_node(plane, m, Vector3(0, yard - 0.12 - height * 0.5, FORE_Z - 0.3))
	sail.name = name
	return sail


## The gaff sail of the main mast and its topsail, a staysail between the masts, two jibs on the bowsprit.
static func _fore_and_aft_sails() -> Node3D:
	var n := Node3D.new()
	n.name = "ForeAndAft"
	var k := Kit.new()
	var c := canvas(false)
	k.quad(c, Vector3(0.02, 2.7, MAIN_Z + 0.25), Vector3(0.02, 2.95, 6.7), Vector3(0.02, 10.3, 5.5), Vector3(0.02, 8.15, MAIN_Z + 0.25))
	k.tri(c, Vector3(0.02, 8.4, MAIN_Z + 0.3), Vector3(0.02, 10.55, 5.5), Vector3(0.02, MAIN_TOP - 0.4, MAIN_Z + 0.3))
	k.tri(c, Vector3(-0.03, 9.6, FORE_Z + 0.4), Vector3(-0.03, 6.9, MAIN_Z - 0.2), Vector3(-0.03, 3.2, FORE_Z + 0.4))
	k.tri(c, Vector3(0.03, 2.6, -9.3), Vector3(0.03, 10.2, FORE_Z - 0.1), Vector3(0.03, 1.9, -5.4))
	k.tri(c, Vector3(-0.03, 2.15, -7.7), Vector3(-0.03, 7.9, FORE_Z - 0.2), Vector3(-0.03, 1.7, -4.7))
	n.add_child(k.commit("Canvas", false))
	return n


## A wing sail (sheets 68 and 71): a bat's wing of wet canvas on four spars, low on the side; drops fall from its
## trailing edge.
static func _wing(sd: float) -> Node3D:
	var n := Node3D.new()
	n.name = "WingL" if sd < 0.0 else "WingR"
	var root := Vector3(sd * 1.62, -1.25, 0.3)  # below the gun ports
	var tips: Array[Vector3] = [Vector3(sd * 6.2, -1.5, -3.1), Vector3(sd * 7.4, -2.0, -1.0), Vector3(sd * 7.3, -2.3, 1.3), Vector3(sd * 6.2, -2.4, 3.3), Vector3(sd * 4.4, -2.2, 4.9)]
	var kb := Kit.new()
	var kq := Kit.new()
	for i in tips.size():
		kb.mesh(dark(), Proc._cyl_mesh(0.03, 0.06, 1.0, 6), _between(root, tips[i], 1.0))
		if i == tips.size() - 1:
			break
		var hollow := (tips[i] + tips[i + 1]) * 0.5
		hollow = root.lerp(hollow, 0.8) + Vector3(0, -0.18, 0)  # the edge sags between two spars
		kq.tri(canvas(true), root, tips[i], hollow)
		kq.tri(canvas(true), root, hollow, tips[i + 1])
	kq.tri(canvas(true), root, Vector3(sd * 1.7, -1.25, -1.5), tips[0])
	kq.tri(canvas(true), root, tips[tips.size() - 1], Vector3(sd * 1.5, -1.25, 3.1))
	n.add_child(kb.commit("Spars"))
	n.add_child(kq.commit("Membrane", false))
	var drips := CPUParticles3D.new()  # cloud moisture running off the trailing edge
	drips.name = "Drips"
	drips.amount = 28
	drips.lifetime = 1.3
	drips.preprocess = 1.3
	drips.local_coords = false
	drips.position = Vector3(sd * 6.4, -2.35, 1.0)
	drips.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	drips.emission_box_extents = Vector3(1.2, 0.08, 3.4)
	drips.direction = Vector3.DOWN
	drips.spread = 2.0
	drips.gravity = Vector3(0, -7.0, 0)
	drips.initial_velocity_min = 0.2
	drips.initial_velocity_max = 0.6
	var drop := QuadMesh.new()
	drop.size = Vector2(0.025, 0.14)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.albedo_color = Color(0.82, 0.93, 1.0, 0.75)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	dm.render_priority = AFTER_EFFECT + 3
	drop.material = dm
	drips.mesh = drop
	n.add_child(drips)
	return n


## The etherite crystal under the keel in its brass cage: what keeps her in the air.
static func _crystal() -> Node3D:
	var n := Node3D.new()
	n.name = "Crystal"
	n.position = Vector3(0, -DEPTH - 0.75, 0.2)
	var k := Kit.new()
	for sz: float in [-1.0, 1.0]:
		k.mesh(ether(), Proc._cyl_mesh(0.0, 0.42, 1.0, 6), Transform3D(Basis(Vector3.RIGHT, sz * PI / 2), Vector3(0, 0, sz * 0.5)))
	for z: float in [-0.7, 0.0, 0.7]:  # the cage: three hoops and four bars, hung from the keel by straps
		var hoop := TorusMesh.new()
		hoop.inner_radius = 0.5 - absf(z) * 0.2
		hoop.outer_radius = 0.55 - absf(z) * 0.2
		hoop.rings = 14
		hoop.ring_segments = 5
		k.mesh(gilt(), hoop, Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0, z)))
		k.box(gilt(), Vector3(0.05, 0.5, 0.05), Vector3(0, 0.62, z))
	for a in 4:
		var r := Vector3(cos(a * PI / 2 + PI / 4), sin(a * PI / 2 + PI / 4), 0) * 0.5
		k.box(gilt(), Vector3(0.04, 0.04, 1.9), r)
	n.add_child(k.commit("Cage"))
	var glow := OmniLight3D.new()
	glow.name = "Glow"
	glow.light_color = ETHER
	glow.light_energy = 1.6
	glow.omni_range = 6.0
	n.add_child(glow)
	return n


## The flag at the main mast's head: our sd, in a shader (`shaders/ship_flag.gdshader`).
static func _flag() -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.3, 1.35)
	plane.subdivide_width = 14
	plane.subdivide_depth = 6
	plane.orientation = PlaneMesh.FACE_Z
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/ship_flag.gdshader")
	m.render_priority = AFTER_EFFECT + 1
	var flag := Proc.mesh_node(plane, m, Vector3(0, MAIN_TOP - 0.55, MAIN_Z + 0.16 + 1.2))
	flag.name = "Flag"
	flag.rotation.y = -PI / 2  # the hoist at the mast, the fly streaming aft
	return flag

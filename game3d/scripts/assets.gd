## Pattern: Facade — one door to the downloaded CC0 assets (`make assets`, game3d/assets.lock). Every call
## degrades to null or a plain colour when the files are absent, so tests and a fresh clone still run.
## See docs/adr/0019-game3d-pbr-assets.md
class_name Assets
extends RefCounted

const ROOT := "res://assets"
const HDRI := "res://assets/hdri/qwantani_late_afternoon_puresky_2k.hdr"

static var _mats: Dictionary = {}
static var _scenes: Dictionary = {}
static var _thinned: Dictionary = {}


static func available() -> bool:
	return ResourceLoader.exists(HDRI)


static func tex(set_name: String, map: String) -> Texture2D:
	var p := "%s/textures/%s/%s_%s_1k.jpg" % [ROOT, set_name, set_name, map]
	return load(p) if ResourceLoader.exists(p) else null


## PBR material from a Poly Haven texture set (diff / nor_gl / arm), world triplanar so procedural meshes
## need no UVs. `tint` multiplies the albedo; `scale` is texture repeats per metre.
static func pbr(set_name: String, tint: Color = Color.WHITE, scale: float = 0.5) -> BaseMaterial3D:
	var key := "%s/%s/%s" % [set_name, tint.to_html(), scale]
	if _mats.has(key):
		return _mats[key]
	var m := ORMMaterial3D.new()
	m.albedo_color = tint
	m.roughness = 0.85
	var diff := tex(set_name, "diff")
	if diff != null:
		m.albedo_texture = diff
		m.normal_enabled = true
		m.normal_texture = tex(set_name, "nor_gl")
		m.orm_texture = tex(set_name, "arm")
		m.roughness = 1.0
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_triplanar_sharpness = 4.0
		m.uv1_scale = Vector3.ONE * scale
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mats[key] = m
	return m


## Instance of a Poly Haven glTF model, or null when it is not downloaded.
static func model(name: String) -> Node3D:
	if not _scenes.has(name):
		var p := "%s/models/%s/%s_1k.gltf" % [ROOT, name, name]
		_scenes[name] = load(p) if ResourceLoader.exists(p) else null
	var s: PackedScene = _scenes[name]
	return s.instantiate() if s != null else null


## A MakeHuman character (CC0, posed, game-engine skeleton) from assets/models/people, or null.
static func person(name: String) -> Node3D:
	var key := "people/" + name
	if not _scenes.has(key):
		var p := "%s/models/people/%s.glb" % [ROOT, name]
		_scenes[key] = load(p) if ResourceLoader.exists(p) else null
	var s: PackedScene = _scenes[key]
	return s.instantiate() if s != null else null


## Places a model; returns it (or null) so callers can tweak it.
static func put(parent: Node3D, name: String, pos: Vector3, yaw: float = 0.0, scale: float = 1.0) -> Node3D:
	var n := model(name)
	if n == null:
		return null
	n.position = pos
	n.rotation.y = yaw
	n.scale = Vector3.ONE * scale
	parent.add_child(n)
	return n


## Model whose foliage surfaces (material name contains "leaves") keep only every `keep`-th leaf card.
## Poly Haven trees carry ~700k leaf triangles; thinning them holds 60 fps in the harbour (ADR-0019).
static func thinned(name: String, keep: int = 3) -> Node3D:
	var n := model(name)
	if n == null:
		return null
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var key := "%s/%s/%d" % [name, mi.name, keep]
		if not _thinned.has(key):
			_thinned[key] = _thin_mesh(mi.mesh as ArrayMesh, keep)
		mi.mesh = _thinned[key]
		mi.lod_bias = 2.5  # generated LODs drop whole leaf cards; keep the crown full at distance
	return n


static func _thin_mesh(src: ArrayMesh, keep: int) -> ArrayMesh:
	var out := ImporterMesh.new()  # rebuilds LODs for the thinned mesh
	for s in src.get_surface_count():
		var arrays := src.surface_get_arrays(s)
		var mat := src.surface_get_material(s)
		if mat != null and mat.resource_name.contains("leaves") and arrays[Mesh.ARRAY_INDEX] != null:
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var kept := PackedInt32Array()
			var cards := idx.size() / 6  # a leaf card is a quad = 2 triangles
			for c in cards:
				if c % keep == 0:
					kept.append_array(idx.slice(c * 6, c * 6 + 6))
			arrays[Mesh.ARRAY_INDEX] = kept
			mat = mat.duplicate()
			(mat as BaseMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR  # no depth pre-pass
		out.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, mat)
	out.generate_lods(25.0, 60.0, [])
	return out.get_mesh()

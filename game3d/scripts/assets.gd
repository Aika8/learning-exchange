## Pattern: Facade — one door to the downloaded CC0 assets (`make assets`, game3d/assets.lock). Every call
## degrades to null or a plain colour when the files are absent, so tests and a fresh clone still run.
## See docs/adr/0019-game3d-pbr-assets.md
class_name Assets
extends RefCounted

const ROOT := "res://assets"
const HDRI := "res://assets/hdri/qwantani_late_afternoon_puresky_2k.hdr"

static var _mats: Dictionary = {}
static var _scenes: Dictionary = {}


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

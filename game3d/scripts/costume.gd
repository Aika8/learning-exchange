## Pattern: Builder — dresses a MakeHuman person for the age of sail. The downloaded people wear a T-shirt, jeans and
## a fedora; here their clothes get plain period cloth (or sailor's stripes) instead of the denim and print textures,
## and our own meshes are added on top: tricorn, bandana, slouch hat, long coat with tails, waistcoat, wide sleeves,
## sash, slops, long skirt and apron, sea boots, stockings. Every added piece is rigidly skinned to one bone and all
## of them are one mesh per person, so a costume costs a draw call per material and follows the gait.
## Our own meshes and materials (CC0); generic period dress, no character from a game or a film.
## Roles: captain, sailor, trader, townsman, child. `stand_in()` builds the whole person in code in the same costume
## for when the MakeHuman people are not on disk.
class_name Costume
extends RefCounted

const LINEN := Color("e9dfc8")
const CANVAS := Color("c9b78f")
const LEATHER := Color("3a2618")
const FELT := Color("1f1b1a")
const BRASS := Color("d9a441")
const SASH := Color("a8322a")
const NAVY := Color("22324f")

static var _mats: Dictionary = {}
static var _stripes: Shader


## Dresses `person` (an instance from Assets.person) in place. `tint` varies the main garment between people.
static func dress(person: Node3D, role: String, tint: Color = Color.WHITE) -> void:
	var found := person.find_children("*", "Skeleton3D", true, false)
	if found.is_empty() or role.is_empty():
		return
	var c := Costume.new()
	c.sk = found[0]
	c.person = person
	if c.sk.find_bone("head") < 0 or c.sk.find_bone("pelvis") < 0:
		return
	c._measure()
	match role:
		"captain":
			c._captain()
		"sailor":
			c._sailor(tint)
		"trader":
			c._trader(tint)
		"child":
			c._child(tint)
		_:
			c._townsman(tint)
	c._commit()


var sk: Skeleton3D
var person: Node3D
var k := 1.0  ## size of this person relative to a 1.75 m adult
var top := 1.75  ## top of the skull, skeleton space
var _parts: Dictionary = {}  ## Material → {v, n, b, i}


func _measure() -> void:
	top = _p("head").y + 0.13
	for mi: MeshInstance3D in sk.find_children("*", "MeshInstance3D", true, false):
		if str(mi.name).contains("generic"):  # the body mesh
			top = (mi.transform * mi.get_aabb()).end.y
	k = top / 1.75


func _p(bone: String) -> Vector3:
	if sk == null:  # the stand-in has no skeleton: joints of a 1.75 m adult, scaled
		var side := -1.0 if bone.ends_with("_r") else 1.0
		var j: Vector3 = JOINTS[bone.trim_suffix("_l").trim_suffix("_r")]
		return Vector3(j.x * side, j.y, j.z) * k
	return sk.get_bone_global_rest(sk.find_bone(bone)).origin


## A person built whole in code, in the same costume, for when the MakeHuman people are not on disk (they are made
## with Blender by tools/people/build.sh, `make assets` cannot download them). No skeleton: it glides and bobs.
static func stand_in(role: String, tint: Color = Color.WHITE) -> Node3D:
	var c := Costume.new()
	c.person = Node3D.new()
	c.person.name = "StandIn"
	c.person.set_meta("stand_in", true)
	c.k = {"child": 0.72, "trader": 0.93, "townsman": 0.97}.get(role, 1.0)
	c.top = 1.75 * c.k
	match role:
		"captain":
			c._captain()
		"sailor":
			c._sailor(tint)
		"trader":
			c._trader(tint)
		"child":
			c._child(tint)
		_:
			c._townsman(tint)
	c._body(role)
	c._commit()
	return c.person


const JOINTS := {"head": Vector3(0, 1.61, 0.03), "neck_01": Vector3(0, 1.5, 0.01), "pelvis": Vector3(0, 0.95, 0), "spine_01": Vector3(0, 1.0, 0),
	"spine_02": Vector3(0, 1.1, 0), "spine_03": Vector3(0, 1.2, 0), "thigh": Vector3(0.1, 0.94, 0), "calf": Vector3(0.11, 0.51, 0.01),
	"foot": Vector3(0.11, 0.08, 0), "upperarm": Vector3(0.2, 1.42, 0), "lowerarm": Vector3(0.235, 1.15, 0.01), "hand": Vector3(0.25, 0.9, 0.04)}
var _own: Dictionary = {}  ## stand-in only: what the person's own clothes are made of (top, bot, lea)


## The stand-in's body under the costume: head, neck, hands, trunk, arms, legs, shoes.
func _body(role: String) -> void:
	var skin := _plain("skin", Color("d9a882"), 0.6)
	var shirt: Material = _own.get("top", cloth(LINEN))
	var legs: Material = _own.get("bot", cloth(Color("4a4034")))
	var shoes: Material = _own.get("lea", leather(LEATHER))
	var head := Vector3(0, top - 0.115 * k, _p("head").z)
	_add("head", skin, _sphere(), Transform3D(Basis().scaled(Vector3(0.2, 0.245, 0.22) * k), head))
	_box("head", skin, Vector3(0.03, 0.045, 0.03) * k, head + Vector3(0, -0.02, 0.105) * k)  # nose
	for x: float in [-0.04, 0.04]:
		_ball("head", _plain("eye", Color("2a2420"), 0.4), head + Vector3(x, 0.015, 0.098) * k, 0.012 * k)
	if role in ["trader", "townsman", "captain"]:  # hair under the hat or kerchief
		_dome("head", _plain("hair", Color("9a9a96") if role == "townsman" else Color("3a2a1e"), 0.9), head + Vector3(0, 0.0, -0.012) * k, Vector3(0.106, 0.125, 0.116) * k)
	_tube("neck_01", skin, _p("neck_01") - Vector3(0, 0.03, 0) * k, head - Vector3(0, 0.08, 0) * k, 0.05 * k, 0.048 * k)
	_tube("spine_01", shirt, _p("pelvis"), _p("spine_03"), 0.165 * k, 0.185 * k, 0.72)
	_tube("spine_03", shirt, _p("spine_03"), _p("neck_01") - Vector3(0, 0.02, 0) * k, 0.185 * k, 0.1 * k, 0.72)
	for s: String in ["l", "r"]:
		_ball("spine_03", shirt, _p("upperarm_" + s), 0.062 * k)
		_tube("upperarm_" + s, shirt, _p("upperarm_" + s), _p("lowerarm_" + s), 0.05 * k, 0.045 * k)
		_tube("lowerarm_" + s, shirt, _p("lowerarm_" + s), _p("hand_" + s), 0.045 * k, 0.036 * k)
		_ball("hand_" + s, skin, _p("hand_" + s) - Vector3(0, 0.045, 0) * k, 0.042 * k)
		_tube("thigh_" + s, legs, _p("thigh_" + s), _p("calf_" + s), 0.085 * k, 0.062 * k)
		_tube("calf_" + s, legs, _p("calf_" + s), _p("foot_" + s), 0.062 * k, 0.045 * k)
		_box("foot_" + s, shoes, Vector3(0.09, 0.08, 0.24) * k, _p("foot_" + s) + Vector3(0, -0.04, 0.05) * k)
	_tube("pelvis", legs, _p("pelvis") - Vector3(0, 0.1, 0) * k, _p("pelvis") + Vector3(0, 0.04, 0) * k, 0.16 * k, 0.168 * k, 0.74)


static func _sphere() -> SphereMesh:
	var m := SphereMesh.new()
	m.radial_segments = 16
	m.rings = 8
	return m


# ---------------------------------------------------------------- roles

func _captain() -> void:
	var coat := cloth(Color("1f3557"))
	_recolour("top", coat)
	_recolour("bot", cloth(Color("d8cfb8")))  # pale breeches
	_recolour("lea", leather(LEATHER))
	_hide("fedora")
	_coat(coat, 0.56, true)
	_sleeves(coat, cloth(LINEN), true)
	_sash(cloth(SASH), true)
	_boots(leather(LEATHER), 0.92)
	_tricorn(felt(FELT), metal())


func _sailor(tint: Color) -> void:
	var blue := NAVY.lerp(tint, 0.25)
	_recolour("top", striped(LINEN, blue, 26.0))
	_recolour("bot", cloth(CANVAS.darkened(0.1)))
	_recolour("lea", leather(LEATHER.lightened(0.1)))
	_hide("fedora")
	_sleeves(striped(LINEN, blue, 9.0), null, false)
	_slops(cloth(CANVAS))
	_sash(cloth(SASH.lerp(tint, 0.2)), false)
	_bandana(cloth(SASH.lerp(tint, 0.35)))


func _trader(tint: Color) -> void:
	var gown := Color("5a3d5c").lerp(tint, 0.3).darkened(0.15)
	_recolour("top", cloth(gown))
	_recolour("bot", cloth(gown.darkened(0.2)))
	_recolour("lea", leather(LEATHER))
	_skirt(cloth(gown.darkened(0.12)), cloth(LINEN))
	_sleeves(cloth(LINEN), null, false)
	_shawl(cloth(Color("b9a06a")))
	_kerchief(cloth(LINEN))


func _townsman(tint: Color) -> void:
	var coat := cloth(Color("6b4a2e").lerp(tint, 0.2))
	_recolour("top", coat)  # his own jacket becomes the coat; tails are added
	_recolour("bot", cloth(Color("4a4034")))
	_recolour("lea", leather(LEATHER))
	_hide("fedora")
	_tails(coat, 0.34)
	_stockings(cloth(Color("d6ccb4")))
	_slouch_hat(felt(Color("3b2f26")))


func _child(tint: Color) -> void:
	_recolour("top", cloth(LINEN))
	_recolour("bot", cloth(Color("6a5238").lerp(tint, 0.15)))
	_recolour("lea", leather(LEATHER.lightened(0.15)))
	_sleeves(cloth(LINEN), null, false)
	_sash(cloth(Color("3f6f8f")), false)
	_bandana(cloth(Color("3f6f8f")))


# ---------------------------------------------------------------- the person's own clothes

## Replaces the texture of the clothing surfaces whose material name ends in `part` (top, bot, lea) with `m`,
## keeping the folds of the original normal map.
func _recolour(part: String, m: Material) -> void:
	if sk == null:
		_own[part] = m
		return
	for mi: MeshInstance3D in sk.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var old := mi.mesh.surface_get_material(s) as BaseMaterial3D
			if old == null or not old.resource_name.ends_with("." + part):
				continue
			var mine := m.duplicate()
			if mine is BaseMaterial3D and old.normal_texture != null:
				(mine as BaseMaterial3D).normal_enabled = true
				(mine as BaseMaterial3D).normal_texture = old.normal_texture
			elif mine is ShaderMaterial and old.normal_texture != null:
				(mine as ShaderMaterial).set_shader_parameter("folds", old.normal_texture)
			mi.set_surface_override_material(s, mine)


func _hide(what: String) -> void:
	if sk == null:
		return
	for mi: MeshInstance3D in sk.find_children("*", "MeshInstance3D", true, false):
		if str(mi.name).contains(what):
			mi.visible = false


# ---------------------------------------------------------------- garments (skeleton space, rest pose)

## A coat or waistcoat over the trunk: body, collar, buttons, and two tails that hang from the thighs so they move
## with the legs. `length` is how far the tails reach down the thigh (0..1 of thigh to knee and beyond).
func _coat(m: Material, length: float, buttons: bool) -> void:
	var hip := _p("pelvis")
	var chest := _p("spine_03")
	var neck := _p("neck_01")
	var w := 0.2 * k
	_tube("spine_01", m, hip + Vector3(0, 0.02, 0) * k, chest + Vector3(0, 0.02, 0), w * 0.98, w * 1.06, 0.74)
	_tube("spine_03", m, chest, neck - Vector3(0, 0.05, 0) * k, w * 1.06, w * 0.86, 0.72)
	_box("spine_03", m, Vector3(0.3, 0.05, 0.2) * k, neck + Vector3(0, -0.03, -0.02) * k)  # collar
	_tails(m, length)
	if buttons:
		for i in 4:
			var at := hip.lerp(neck, 0.22 + i * 0.17) + Vector3(0.03, 0, 0.158) * k
			_ball("spine_02", metal(), at, 0.014 * k)


## Coat tails: a flattened tube round each thigh, so they move with the legs.
func _tails(m: Material, length: float) -> void:
	for s: String in ["l", "r"]:
		var thigh := _p("thigh_" + s)
		var knee := _p("calf_" + s)
		var side := signf(thigh.x)
		var end := thigh.lerp(knee, length / 0.56 * 0.62)
		_tube("thigh_" + s, m, thigh + Vector3(side * 0.02, 0.03, -0.02) * k, end + Vector3(side * 0.05, 0, -0.04) * k, 0.125 * k, 0.15 * k, 0.9)


## Sleeves: `m` down the upper arm and (billowing, gathered at the wrist) the forearm. With `cuffs`, the upper sleeve is
## the coat's and a wide turned-back cuff sits at the wrist with the shirt `under` it showing.
func _sleeves(m: Material, under: Material, cuffs: bool) -> void:
	for s: String in ["l", "r"]:
		var sh := _p("upperarm_" + s)
		var el := _p("lowerarm_" + s)
		var wr := _p("hand_" + s)
		_tube("upperarm_" + s, m, sh.lerp(el, 0.02), el, 0.062 * k, 0.058 * k)
		if cuffs:
			_tube("lowerarm_" + s, m, el, el.lerp(wr, 0.72), 0.058 * k, 0.056 * k)
			_tube("lowerarm_" + s, m, el.lerp(wr, 0.6), el.lerp(wr, 0.9), 0.075 * k, 0.082 * k)
			_tube("lowerarm_" + s, under, el.lerp(wr, 0.86), el.lerp(wr, 1.02), 0.05 * k, 0.062 * k)
		else:
			_tube("lowerarm_" + s, m, el, el.lerp(wr, 0.55), 0.058 * k, 0.078 * k)
			_tube("lowerarm_" + s, m, el.lerp(wr, 0.55), el.lerp(wr, 0.93), 0.078 * k, 0.04 * k)


## A sash wound round the waist, knotted on the left hip with the ends hanging (on the thigh, so they swing).
func _sash(m: Material, wide: bool) -> void:
	var hip := _p("pelvis") + Vector3(0, 0.07, 0) * k
	var h := (0.11 if wide else 0.075) * k
	_tube("pelvis", m, hip - Vector3(0, h * 0.5, 0), hip + Vector3(0, h * 0.5, 0), 0.215 * k, 0.212 * k, 0.76)
	var knot := hip + Vector3(0.17, -0.01, 0.07) * k
	_ball("pelvis", m, knot, 0.045 * k)
	_box("thigh_l", m, Vector3(0.05, 0.3, 0.02) * k, knot + Vector3(0.012, -0.17, 0.0) * k, Vector3(0, 0, 0.08))
	_box("thigh_l", m, Vector3(0.045, 0.24, 0.02) * k, knot + Vector3(-0.03, -0.14, 0.012) * k, Vector3(0, 0, -0.1))
	if wide:  # a belt over it with a brass buckle
		_tube("pelvis", leather(LEATHER), hip - Vector3(0, 0.016, 0) * k, hip + Vector3(0, 0.016, 0) * k, 0.222 * k, 0.222 * k, 0.76)
		_box("pelvis", metal(), Vector3(0.055, 0.05, 0.012) * k, hip + Vector3(0, 0, 0.172) * k)


## Sea boots: a leg to under the knee with a wide folded top.
func _boots(m: Material, height: float) -> void:
	for s: String in ["l", "r"]:
		var knee := _p("calf_" + s)
		var ankle := _p("foot_" + s)
		var up := ankle.lerp(knee, height)
		_tube("calf_" + s, m, ankle - Vector3(0, 0.02, 0.012) * k, up - Vector3(0, 0, 0.012) * k, 0.086 * k, 0.096 * k)
		_tube("calf_" + s, m, up - Vector3(0, 0.07, 0.012) * k, up + Vector3(0, 0.01, -0.012) * k, 0.104 * k, 0.116 * k)


## Stockings to the knee with a garter, for breeches.
func _stockings(m: Material) -> void:
	for s: String in ["l", "r"]:
		var knee := _p("calf_" + s)
		var ankle := _p("foot_" + s)
		_tube("calf_" + s, m, ankle + Vector3(0, 0.0, 0) * k, ankle.lerp(knee, 0.9), 0.078 * k, 0.09 * k)
		_tube("calf_" + s, cloth(Color("4a4034")), ankle.lerp(knee, 0.86), ankle.lerp(knee, 0.97), 0.093 * k, 0.096 * k)


## Slops: wide sailor's trousers that end at mid calf.
func _slops(m: Material) -> void:
	for s: String in ["l", "r"]:
		var hip := _p("thigh_" + s)
		var knee := _p("calf_" + s)
		var ankle := _p("foot_" + s)
		_tube("thigh_" + s, m, hip.lerp(knee, 0.12), knee, 0.1 * k, 0.105 * k)
		_tube("calf_" + s, m, knee, knee.lerp(ankle, 0.5), 0.105 * k, 0.115 * k)


## A long skirt in two halves (one per thigh, so it follows the stride) and an apron.
func _skirt(m: Material, apron: Material) -> void:
	var hip := _p("pelvis")
	_tube("pelvis", m, hip + Vector3(0, 0.1, 0) * k, hip - Vector3(0, 0.06, 0) * k, 0.2 * k, 0.24 * k, 0.8)
	for s: String in ["l", "r"]:
		var thigh := _p("thigh_" + s)
		var knee := _p("calf_" + s)
		var ankle := _p("foot_" + s)
		var side := signf(thigh.x)
		_tube("thigh_" + s, m, thigh + Vector3(side * 0.01, 0.02, 0) * k, knee + Vector3(side * 0.03, 0, 0) * k, 0.15 * k, 0.19 * k, 0.9)
		_tube("calf_" + s, m, knee + Vector3(side * 0.03, 0, 0) * k, knee.lerp(ankle, 0.78) + Vector3(side * 0.05, 0, 0) * k, 0.19 * k, 0.22 * k, 0.9)
	_box("pelvis", apron, Vector3(0.26, 0.36, 0.012) * k, hip + Vector3(0, -0.12, 0.215) * k, Vector3(-0.12, 0, 0))
	_tube("pelvis", apron, hip + Vector3(0, 0.07, 0) * k, hip + Vector3(0, 0.1, 0) * k, 0.208 * k, 0.206 * k, 0.8)


## A shawl over the shoulders.
func _shawl(m: Material) -> void:
	var neck := _p("neck_01")
	var chest := _p("spine_03")
	_tube("spine_03", m, chest + Vector3(0, 0.1, 0) * k, neck - Vector3(0, 0.02, 0) * k, 0.24 * k, 0.12 * k, 0.72)


func _tricorn(m: Material, trim: Material) -> void:
	var c := Vector3(0, top - 0.02 * k, _p("head").z - 0.01 * k)
	_tube("head", m, c, c + Vector3(0, 0.085, 0) * k, 0.1 * k, 0.088 * k, 1.0, true)
	_tube("head", trim, c + Vector3(0, 0.004, 0) * k, c + Vector3(0, 0.022, 0) * k, 0.103 * k, 0.102 * k)
	_tube("head", m, c - Vector3(0, 0.006, 0) * k, c + Vector3(0, 0.006, 0) * k, 0.2 * k, 0.2 * k, 1.0, true, 3)  # the brim: a triangle, a point forward
	for i in 3:  # the three sides turned up
		var a := TAU * i / 3.0 + PI / 3.0  # middle of a side
		var out := Vector3(sin(a), 0, cos(a))
		var at := c + out * 0.118 * k + Vector3(0, 0.04, 0) * k
		_box("head", m, Vector3(0.33, 0.085, 0.012) * k, at, Vector3(-0.35, a, 0))
		_box("head", trim, Vector3(0.33, 0.012, 0.016) * k, at + (Vector3(0, 0.04, 0) + out * 0.014) * k, Vector3(-0.35, a, 0))


func _bandana(m: Material) -> void:
	_hide("short")  # the cloth covers the hair
	var c := Vector3(0, top - 0.085 * k, _p("head").z - 0.012 * k)
	_dome("head", m, c, Vector3(0.112, 0.1, 0.128) * k)
	_tube("head", m, c + Vector3(0, -0.018, 0) * k, c + Vector3(0, 0.02, 0) * k, 0.116 * k, 0.114 * k, 1.13)
	var knot := c + Vector3(0.03, 0.0, -0.125) * k
	_ball("head", m, knot, 0.026 * k)
	_box("head", m, Vector3(0.04, 0.13, 0.012) * k, knot + Vector3(0.02, -0.07, -0.012) * k, Vector3(0.25, 0, 0.2))
	_box("head", m, Vector3(0.036, 0.1, 0.012) * k, knot + Vector3(-0.02, -0.055, -0.01) * k, Vector3(0.3, 0, -0.25))


## A kerchief tied over the hair.
func _kerchief(m: Material) -> void:
	var c := Vector3(0, top - 0.075 * k, _p("head").z - 0.02 * k)
	_dome("head", m, c, Vector3(0.112, 0.112, 0.128) * k)
	_box("head", m, Vector3(0.13, 0.12, 0.014) * k, c + Vector3(0, -0.04, -0.118) * k, Vector3(0.2, 0, 0))


## A soft felt hat with a round brim, one side sagging.
func _slouch_hat(m: Material) -> void:
	var c := Vector3(0, top - 0.015 * k, _p("head").z - 0.01 * k)
	_tube("head", m, c, c + Vector3(0, 0.1, 0) * k, 0.1 * k, 0.07 * k, 1.0, true)
	_tube("head", m, c - Vector3(0, 0.008, 0) * k, c + Vector3(0, 0.004, 0) * k, 0.2 * k, 0.185 * k, 1.0, true)


# ---------------------------------------------------------------- materials

static func cloth(c: Color) -> Material:
	return _plain("cloth", c, 0.95)


static func felt(c: Color) -> Material:
	return _plain("felt", c, 1.0)


static func leather(c: Color) -> Material:
	return _plain("leather", c, 0.55)


static func metal() -> Material:
	var key := "brass"
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = BRASS
		m.metallic = 1.0
		m.roughness = 0.35
		_mats[key] = m
	return _mats[key]


static func _plain(kind: String, c: Color, rough: float) -> Material:
	var key := kind + c.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = rough
		m.cull_mode = BaseMaterial3D.CULL_DISABLED  # tails and skirts are open tubes
		_mats[key] = m
	return _mats[key]


## Sailor's stripes across the garment: `count` bands along the height of the UV (or of the tube).
static func striped(a: Color, b: Color, count: float) -> Material:
	var key := "stripes%s%s%s" % [a.to_html(), b.to_html(), count]
	if not _mats.has(key):
		if _stripes == null:
			_stripes = Shader.new()
			_stripes.code = """shader_type spatial;
render_mode cull_disabled;
uniform vec3 a : source_color;
uniform vec3 b : source_color;
uniform float count = 20.0;
uniform sampler2D folds : hint_normal;
uniform bool has_folds = false;
void fragment() {
	ALBEDO = mix(a, b, step(0.56, fract(UV.y * count)));
	ROUGHNESS = 0.95;
	if (has_folds) { NORMAL_MAP = texture(folds, UV).rgb; }
}"""
		var m := ShaderMaterial.new()
		m.shader = _stripes
		m.set_shader_parameter("a", a)
		m.set_shader_parameter("b", b)
		m.set_shader_parameter("count", count)
		_mats[key] = m
	return _mats[key]


# ---------------------------------------------------------------- mesh assembly

## A tube from `a` to `b` (skeleton space), radius `r0` at `a` and `r1` at `b`, squashed front-to-back by `flat`.
func _tube(bone: String, m: Material, a: Vector3, b: Vector3, r0: float, r1: float, flat: float = 1.0, caps: bool = false, sides: int = 14) -> void:
	var c := CylinderMesh.new()
	c.bottom_radius = r0
	c.top_radius = r1
	c.height = maxf(0.001, a.distance_to(b))
	c.radial_segments = sides
	c.rings = 1
	c.cap_top = caps
	c.cap_bottom = caps
	var y := (b - a).normalized()
	var x := Vector3.RIGHT if absf(y.dot(Vector3.RIGHT)) < 0.9 else Vector3.BACK
	var z := x.cross(y).normalized()
	x = y.cross(z).normalized()
	_add(bone, m, c, Transform3D(Basis(x, y, z * flat), (a + b) * 0.5))


func _box(bone: String, m: Material, size: Vector3, at: Vector3, rot: Vector3 = Vector3.ZERO) -> void:
	_add(bone, m, BoxMesh.new(), Transform3D(Basis.from_euler(rot).scaled_local(size), at))


func _ball(bone: String, m: Material, at: Vector3, r: float) -> void:
	var s := SphereMesh.new()
	s.radial_segments = 10
	s.rings = 5
	_add(bone, m, s, Transform3D(Basis().scaled(Vector3.ONE * r * 2.0), at))


## The top half of an ellipsoid with radii `r`, its flat side at `at`.
func _dome(bone: String, m: Material, at: Vector3, r: Vector3) -> void:
	var s := SphereMesh.new()
	s.is_hemisphere = true
	s.radius = 1.0
	s.height = 1.0
	s.radial_segments = 14
	s.rings = 6
	_add(bone, m, s, Transform3D(Basis().scaled(r), at))


func _add(bone: String, m: Material, mesh: Mesh, xf: Transform3D) -> void:
	var idx := sk.find_bone(bone) if sk != null else 0
	if idx < 0 or m == null:
		return
	if not _parts.has(m):
		_parts[m] = {"v": PackedVector3Array(), "n": PackedVector3Array(), "u": PackedVector2Array(), "b": PackedInt32Array(),
			"w": PackedFloat32Array(), "i": PackedInt32Array()}
	var part: Dictionary = _parts[m]
	var src := mesh.surface_get_arrays(0)
	var v: PackedVector3Array = part["v"]
	var n: PackedVector3Array = part["n"]
	var u: PackedVector2Array = part["u"]
	var bones: PackedInt32Array = part["b"]
	var weights: PackedFloat32Array = part["w"]
	var index: PackedInt32Array = part["i"]
	var base := v.size()
	var normal_basis := xf.basis.inverse().transposed()
	var verts: PackedVector3Array = src[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = src[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = src[Mesh.ARRAY_TEX_UV]
	for j in verts.size():
		v.append(xf * verts[j])
		n.append((normal_basis * normals[j]).normalized())
		u.append(uvs[j])
		bones.append_array(PackedInt32Array([idx, 0, 0, 0]))
		weights.append_array(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
	for j: int in (src[Mesh.ARRAY_INDEX] as PackedInt32Array):
		index.append(base + j)
	_parts[m] = {"v": v, "n": n, "u": u, "b": bones, "w": weights, "i": index}  # packed arrays are values: store them back


## One skinned mesh for the whole costume, a surface per material.
func _commit() -> void:
	if _parts.is_empty():
		return
	var mesh := ArrayMesh.new()
	for m: Material in _parts:
		var part: Dictionary = _parts[m]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = part["v"]
		arrays[Mesh.ARRAY_NORMAL] = part["n"]
		arrays[Mesh.ARRAY_TEX_UV] = part["u"]
		if sk != null:
			arrays[Mesh.ARRAY_BONES] = part["b"]
			arrays[Mesh.ARRAY_WEIGHTS] = part["w"]
		arrays[Mesh.ARRAY_INDEX] = part["i"]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, m)
	var mi := MeshInstance3D.new()
	mi.name = "Costume"
	mi.mesh = mesh
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	if sk == null:
		person.add_child(mi)
		return
	mi.skin = sk.create_skin_from_rest_transforms()
	sk.add_child(mi)
	mi.skeleton = NodePath("..")
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED

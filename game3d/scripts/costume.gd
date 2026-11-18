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
const COAT := Color("2f3d62")  ## the captain's coat on the sheet: navy, a little faded
const GOLD := Color("c9983a")  ## braid and edging
const CREAM := Color("e6dcc0")
const CANVAS_LIGHT := Color("d9cba6")
const BOOT := Color("6b4630")
const SHOE := Color("5a3d28")

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
	c._wear(role, tint)
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
	if built:  # a person built in code: joints of a 1.75 m adult, scaled
		var side := -1.0 if bone.ends_with("_r") else 1.0
		var j: Vector3 = JOINTS[bone.trim_suffix("_l").trim_suffix("_r")]
		return Vector3(j.x * side * (0.55 + 0.45 * g), j.y, j.z) * k
	return sk.get_bone_global_rest(sk.find_bone(bone)).origin


## A person built whole in code, in the same costume, for when the MakeHuman people are not on disk (they are made
## with Blender by tools/people/build.sh, `make assets` cannot download them). No skeleton: it glides and bobs.
static func stand_in(role: String, tint: Color = Color.WHITE) -> Node3D:
	var c := Costume.new()
	c.built = true
	c.person = Node3D.new()
	c.person.name = "Person"
	c.person.set_meta("stand_in", true)
	var build: Array = BUILDS.get(role, [1.0, 1.0, 1.15, 0.07])
	c.k = build[0]
	c.g = build[1]
	c.hk = c.k * float(build[2])
	c.nose = build[3]
	c.top = c._p("head").y + 0.14 * c.hk
	if role != "chronicler":  # the owl stands and has no limbs to move
		c.sk = c._skeleton()
		c.person.add_child(c.sk)
	c._wear(role, tint)
	if role != "chronicler":
		c._body(role)
	c._commit()
	return c.person


## The small skeleton of a built person: the bones the gait (Walker) moves, at the joints of JOINTS, all rest
## rotations zero. Costume pieces are skinned to these bones by name.
func _skeleton() -> Skeleton3D:
	var s := Skeleton3D.new()
	s.name = "Skeleton3D"
	var at: Dictionary = {"Root": Vector3.ZERO}
	for b: Array in BONES:
		var name: String = b[0]
		var idx := s.add_bone(name)
		var pos := Vector3.ZERO if name == "Root" else _p(name)
		at[name] = pos
		if b[1] != "":
			s.set_bone_parent(idx, s.find_bone(b[1]))
		var rest := Transform3D(Basis(), pos - (at[b[1]] as Vector3 if b[1] != "" else Vector3.ZERO))
		s.set_bone_rest(idx, rest)
		s.set_bone_pose_position(idx, rest.origin)
	return s


## Exaggerated builds, so everybody is told apart by outline: [height, girth, head-and-hat size, nose length].
const BUILDS := {"captain": [1.0, 0.92, 1.22, 0.07], "sailor": [1.08, 0.82, 1.1, 0.11], "sailor2": [0.9, 1.4, 1.18, 0.05], "sailor3": [0.97, 0.78, 1.12, 0.14],
	"mara": [0.98, 1.08, 1.34, 0.09], "changer": [0.96, 1.32, 1.3, 0.06], "olva": [1.0, 0.8, 1.12, 0.1], "trader": [0.88, 1.45, 1.15, 0.05],
	"townsman": [0.97, 0.86, 1.25, 0.15], "child": [0.68, 0.95, 1.38, 0.04], "chronicler": [1.0, 1.0, 1.0, 0.0],
	"crypto_trader": [1.04, 1.0, 1.12, 0.06], "crypto_miner": [0.98, 1.2, 1.15, 0.05], "crypto_dreamer": [0.96, 0.82, 1.14, 0.06], "crypto_analyst": [1.0, 0.84, 1.12, 0.06],
	"toy_gentleman": [1.0, 1.45, 1.2, 0.05], "toy_lady": [0.98, 0.85, 1.18, 0.04], "toy_grandpa": [0.95, 0.95, 1.2, 0.07], "toy_granny": [0.86, 1.1, 1.22, 0.05], "toy_child": [0.66, 0.92, 1.36, 0.04],
	"noir_broker": [1.06, 1.05, 1.12, 0.07], "noir_tramp": [0.93, 1.15, 1.2, 0.12], "noir_youth": [0.98, 0.74, 1.16, 0.06], "noir_lady": [1.0, 0.85, 1.14, 0.06]}
const BONES := [["Root", ""], ["pelvis", "Root"], ["spine_01", "pelvis"], ["spine_02", "spine_01"], ["spine_03", "spine_02"], ["neck_01", "spine_03"],
	["head", "neck_01"], ["upperarm_l", "spine_03"], ["lowerarm_l", "upperarm_l"], ["hand_l", "lowerarm_l"], ["upperarm_r", "spine_03"],
	["lowerarm_r", "upperarm_r"], ["hand_r", "lowerarm_r"], ["thigh_l", "pelvis"], ["calf_l", "thigh_l"], ["foot_l", "calf_l"],
	["thigh_r", "pelvis"], ["calf_r", "thigh_r"], ["foot_r", "calf_r"]]
const JOINTS := {"head": Vector3(0, 1.61, 0.03), "neck_01": Vector3(0, 1.5, 0.01), "pelvis": Vector3(0, 0.95, 0), "spine_01": Vector3(0, 1.0, 0),
	"spine_02": Vector3(0, 1.1, 0), "spine_03": Vector3(0, 1.2, 0), "thigh": Vector3(0.1, 0.94, 0), "calf": Vector3(0.11, 0.51, 0.01),
	"foot": Vector3(0.11, 0.08, 0), "upperarm": Vector3(0.2, 1.42, 0), "lowerarm": Vector3(0.235, 1.15, 0.01), "hand": Vector3(0.25, 0.9, 0.04)}
var g := 1.0  ## girth: 0.8 lanky .. 1.45 portly (built people); trunk, limbs and what hangs on them follow it
var hk := 1.0  ## size of the head and of everything worn on it: big hats are part of the silhouette
var nose := 0.07  ## length of the nose, metres at k = 1
var built := false  ## true for a person built whole in code (no downloaded body under the costume)
var _bare_arms := false  ## rolled sleeves: the stand-in shows skin on the forearm
var _bare_calves := false
var _own: Dictionary = {}  ## stand-in only: what the person's own clothes are made of (top, bot, lea)


## The built person's body under the costume: head, neck, hands, trunk, arms, legs, shoes. No face: the
## silhouette (hat, coat, sash) says who it is (ADR-0024).
func _body(role: String) -> void:
	var skin := _plain("skin", Color("d9a882"), 0.6)
	var shirt: Material = _own.get("top", cloth(LINEN))
	var legs: Material = _own.get("bot", cloth(Color("4a4034")))
	var shoes: Material = _own.get("lea", leather(LEATHER))
	var head := Vector3(0, top - 0.115 * hk, _p("head").z)
	_add("head", skin, _sphere(), Transform3D(Basis().scaled(Vector3(0.2, 0.245, 0.22) * hk), head))
	if nose > 0.0:  # no face, but a nose: it belongs to the outline
		_tube("head", skin, head + Vector3(0, 0.0, 0.085) * hk, head + Vector3(0, -0.035 * hk, 0.1 * hk + nose * k), 0.032 * hk, 0.008 * hk, 1.0, false, 5)
	if role in ["trader", "townsman", "captain", "mara", "olva", "changer", "child", "noir_tramp", "noir_youth", "noir_lady", "crypto_trader", "crypto_dreamer", "crypto_analyst", "toy_gentleman", "toy_lady", "toy_grandpa", "toy_granny", "toy_child"]:  # hair under the hat or kerchief
		_dome("head", _plain("hair", Color("9a9a96") if role in ["townsman", "mara", "noir_tramp", "toy_grandpa", "toy_granny"] else (Color("1c1a1a") if role.begins_with("noir") else Color("5a3a26")), 0.9), head + Vector3(0, 0.035, -0.03) * hk, Vector3(0.104, 0.1, 0.1) * hk)
	_tube("neck_01", skin, _p("neck_01") - Vector3(0, 0.03, 0) * k, head - Vector3(0, 0.08, 0) * hk, 0.05 * k, 0.048 * k)
	_tube("spine_01", shirt, _p("pelvis"), _p("spine_03"), 0.165 * k, 0.185 * k, 0.72)
	_tube("spine_03", shirt, _p("spine_03"), _p("neck_01") - Vector3(0, 0.02, 0) * k, 0.185 * k, 0.1 * k, 0.72)
	for s: String in ["l", "r"]:
		_ball("spine_03", shirt, _p("upperarm_" + s), 0.062 * k)
		_tube("upperarm_" + s, shirt, _p("upperarm_" + s), _p("lowerarm_" + s), 0.05 * k, 0.045 * k)
		_tube("lowerarm_" + s, skin if _bare_arms else shirt, _p("lowerarm_" + s), _p("hand_" + s), 0.045 * k, 0.036 * k)
		_ball("hand_" + s, skin, _p("hand_" + s) - Vector3(0, 0.045, 0) * k, 0.042 * k)
		_tube("thigh_" + s, legs, _p("thigh_" + s), _p("calf_" + s), 0.085 * k, 0.062 * k)
		_tube("calf_" + s, skin if _bare_calves else legs, _p("calf_" + s), _p("foot_" + s), 0.062 * k, 0.045 * k)
		_box("foot_" + s, shoes, Vector3(0.09, 0.08, 0.24) * k, _p("foot_" + s) + Vector3(0, -0.04, 0.05) * k)
	_tube("pelvis", legs, _p("pelvis") - Vector3(0, 0.1, 0) * k, _p("pelvis") + Vector3(0, 0.04, 0) * k, 0.16 * k, 0.168 * k, 0.74)


static func _sphere() -> SphereMesh:
	var m := SphereMesh.new()
	m.radial_segments = 9
	m.rings = 5
	return m


# ---------------------------------------------------------------- roles (docs/design/concepts/*.jpg)

func _wear(role: String, tint: Color) -> void:
	var fn := "_r_" + role
	call(fn if has_method(fn) else "_r_townsman", tint)


## Sheet 01: tricorn with a gold edge, long open navy coat with gold trim, cream shirt and breeches, red sash under a
## belt with a brass buckle, pouch and spyglass, tall brown boots with wide folded tops.
func _r_captain(_tint: Color) -> void:
	var coat := cloth(COAT)
	_recolour("top", cloth(LINEN))
	_recolour("bot", cloth(CREAM))
	_recolour("lea", leather(BOOT))
	_hide("fedora")
	_breeches(cloth(CREAM), 0.118)
	_open_coat(coat, cloth(GOLD), _p("calf_l").y - 0.1 * k, 56.0, false)
	_coat_sleeves(coat, cloth(GOLD), cloth(LINEN))
	_sash(cloth(SASH), true, 0.42)
	_pouch("r")
	_flask("r")
	_spyglass()
	_boots(leather(BOOT))
	_tricorn(felt(Color("1d2740")), cloth(GOLD))


## Sheet 02, the tall sailor: striped shirt with rolled sleeves, red sash, baggy slops, bandana.
func _r_sailor(tint: Color) -> void:
	_sailor(cloth(SASH.lerp(tint, 0.1)), cloth(CANVAS_LIGHT))
	if built:
		_rope()
	_bandana(cloth(SASH), true)


## Sheet 02, the stocky sailor: navy sash and a knitted cap.
func _r_sailor2(_tint: Color) -> void:
	_sailor(cloth(Color("3b4f7a")), cloth(CANVAS_LIGHT))
	_flask("r")
	_knit_cap(cloth(Color("2f4470")))


## Sheet 02, the old sailor: a navy waistcoat over the stripes, darker slops.
func _r_sailor3(_tint: Color) -> void:
	_sailor(cloth(SASH), cloth(Color("8f7f5e")))
	_waistcoat(cloth(Color("34425f")), 64.0)
	_flask("l")
	_spyglass()
	_bandana(cloth(Color("b5553a")), true)


func _sailor(sash: Material, slops: Material) -> void:
	var stripes := striped(Color("e6dcc3"), Color("33426a"), 13.0)
	_recolour("top", stripes)
	_recolour("bot", slops)
	_recolour("lea", leather(SHOE))
	_hide("fedora")
	_bare_arms = true
	_bare_calves = true
	_rolled_sleeves(striped(Color("e6dcc3"), Color("33426a"), 4.0), cloth(Color("e6dcc3")))
	_slops(slops)
	_bare_legs()
	_sash(sash, false, 0.34)
	_buckles()


## Sheet 03: wide felt hat over a red headscarf, long patched navy storm coat with gold buttons, cravat, the anchor
## badge on a chain, red sash, cream underskirt, boots, a rolled chart under the arm.
func _r_mara(_tint: Color) -> void:
	var coat := cloth(Color("2c3654"))
	_recolour("top", cloth(Color("2a2d3a")))
	_recolour("bot", cloth(CREAM))
	_recolour("lea", leather(BOOT))
	var hem := _p("foot_l").y + 0.2 * k
	_long_skirt(cloth(CREAM), cloth(Color("3a3340")), hem - 0.06 * k, 0.33, false)
	_open_coat(coat, cloth(GOLD.darkened(0.15)), hem, 44.0, true)
	_coat_sleeves(coat, cloth(GOLD.darkened(0.15)), cloth(LINEN))
	for spot: Array in [[150.0, 0.2, 0.34], [215.0, 0.55, 0.36], [80.0, 0.82, 0.38], [300.0, 0.7, 0.37]]:  # patches
		var hip := _p("pelvis")
		_box("pelvis", cloth(Color("6f6a66")), Vector3(0.1, 0.09, 0.012) * k, _on(hip, Vector3(hip.x, hem, hip.z), 0.222 * k, float(spot[2]) * k, 0.8, spot[0], spot[1]),
			Vector3(0, deg_to_rad(spot[0]), 0))
	_sash(cloth(Color("8f2a2e")), false, 0.5)
	_cravat()
	_medallion()
	_chart()
	_boots(leather(BOOT))
	_headscarf(cloth(Color("9a2f33")))
	_wide_hat(felt(Color("262c40")), 0.24, 0.085)


## Sheet 04, the guild money-changer: tricorn, navy coat, brown waistcoat and breeches, white stockings, red sash, pouch.
func _r_changer(tint: Color) -> void:
	var coat := cloth(Color("33466e").lerp(tint, 0.12))
	_recolour("top", cloth(Color("7a5236")))
	_recolour("bot", cloth(Color("6e4c33")))
	_recolour("lea", leather(SHOE))
	_hide("fedora")
	_breeches(cloth(Color("6e4c33")), 0.112)
	_stockings(cloth(Color("e8e0cc")))
	_open_coat(coat, cloth(GOLD), _p("calf_l").y + 0.02 * k, 70.0, false)
	_coat_sleeves(coat, cloth(GOLD), cloth(LINEN))
	_sash(cloth(SASH), false, 0.36)
	_cravat()
	_pouch("l")
	_buckles()
	_tricorn(felt(Color("27324f")), cloth(GOLD))


## Sheet 04, Olva the analyst: cream blouse with full sleeves, dark bodice, long blue skirt, apron, red sash, satchel.
func _r_olva(_tint: Color) -> void:
	_recolour("top", cloth(LINEN))
	_recolour("bot", cloth(Color("3c4d78")))
	_recolour("lea", leather(SHOE))
	_long_skirt(cloth(Color("3c4d78")), cloth(Color("32406a")), _p("foot_l").y + 0.1 * k, 0.4, false)
	_apron(cloth(LINEN), _p("foot_l").y + 0.1 * k, 0.4, false)
	_waistcoat(cloth(Color("2e2e3a")), 40.0)
	_shirt_sleeves(cloth(LINEN))
	_sash(cloth(SASH), false, 0.3)
	_satchel()
	_bun()


## Sheet 04, the market woman: white kerchief, teal shawl knotted in front, red skirt over a teal one, apron.
func _r_trader(tint: Color) -> void:
	var skirt := Color("b04a38").lerp(tint, 0.12)
	_recolour("top", cloth(LINEN))
	_recolour("bot", cloth(skirt))
	_recolour("lea", leather(SHOE))
	_long_skirt(cloth(skirt), cloth(Color("3f7f7a")), _p("foot_l").y + 0.1 * k, 0.4, true)
	_apron(cloth(LINEN), _p("foot_l").y + 0.1 * k, 0.4, true)
	_shirt_sleeves(cloth(LINEN))
	_shawl(cloth(Color("3f8f8a")))
	_kerchief(cloth(Color("efe6d2")))


## Sheet 04, the old man: brown wide hat, long brown coat, green waistcoat, breeches, white stockings, buckled shoes.
## Sheet 44, the trader: a bright cyan jacket to the hip over black, dark trousers.
func _r_crypto_trader(_tint: Color) -> void:
	var jacket := cloth(Color("19d8f0"))
	_recolour("top", cloth(Color("15102e")))
	_recolour("bot", cloth(Color("2a1f4a")))
	_recolour("lea", leather(Color("15102e")))
	_hide("fedora")
	_breeches(cloth(Color("2a1f4a")), 0.09)
	_stockings(cloth(Color("2a1f4a")))
	_open_coat(jacket, cloth(Color("8ff4ff")), _p("pelvis").y - 0.08 * k, 40.0, true)
	_coat_sleeves(jacket, cloth(Color("8ff4ff")), cloth(Color("15102e")))


## Sheet 44, the miner: a long dark coat, a helmet with a lamp.
func _r_crypto_miner(_tint: Color) -> void:
	var coat := cloth(Color("3a3a36"))
	_recolour("top", cloth(Color("5a5648")))
	_recolour("bot", cloth(Color("4a3a30")))
	_recolour("lea", leather(Color("2a2622")))
	_hide("fedora")
	_breeches(cloth(Color("4a3a30")), 0.11)
	_stockings(cloth(Color("4a3a30")))
	_open_coat(coat, cloth(Color("5a5648")), _p("calf_l").y + 0.1 * k, 52.0, false)
	_coat_sleeves(coat, cloth(Color("5a5648")), cloth(Color("3a3a36")))
	_knit_cap(cloth(Color("b0902a")))
	_ball("head", _plain("lamp", Color("fff0a0"), 0.2), Vector3(0, top - 0.02 * hk, 0.19 * hk), 0.05 * hk)


## Sheet 44, the dreamer: a magenta hoodie, dark trousers, nothing on the head.
func _r_crypto_dreamer(_tint: Color) -> void:
	var hoodie := cloth(Color("c02a90"))
	_recolour("top", hoodie)
	_recolour("bot", cloth(Color("1c1530")))
	_recolour("lea", leather(Color("c02a90")))
	_hide("fedora")
	_breeches(cloth(Color("1c1530")), 0.09)
	_stockings(cloth(Color("1c1530")))
	_shirt_sleeves(hoodie)
	_shawl(hoodie)  # the hood, down on the shoulders


## Sheet 44, the analyst: a dark fitted jacket with a cyan edge, olive trousers.
func _r_crypto_analyst(_tint: Color) -> void:
	var jacket := cloth(Color("23283a"))
	_recolour("top", cloth(Color("23283a")))
	_recolour("bot", cloth(Color("5a5a40")))
	_recolour("lea", leather(Color("2a2622")))
	_hide("fedora")
	_breeches(cloth(Color("5a5a40")), 0.1)
	_stockings(cloth(Color("5a5a40")))
	_open_coat(jacket, cloth(Color("19d8f0")), _p("pelvis").y - 0.14 * k, 24.0, true)
	_coat_sleeves(jacket, cloth(Color("19d8f0")), cloth(Color("23283a")))
	_bun()


## Sheet 50, the calm rich gentleman: a mint frock coat with lavender trim over a butter waistcoat, cream
## trousers, a tall powder-blue hat.
func _r_toy_gentleman(_tint: Color) -> void:
	var coat := cloth(Color("b5e2b8"))
	_recolour("top", cloth(Color("ffeb99")))
	_recolour("bot", cloth(Color("f3ead6")))
	_recolour("lea", leather(Color("6b4630")))
	_hide("fedora")
	_breeches(cloth(Color("f3ead6")), 0.12)
	_stockings(cloth(Color("f3ead6")))
	_waistcoat(cloth(Color("ffeb99")), 30.0)
	_open_coat(coat, cloth(Color("d7bde2")), _p("calf_l").y + 0.12 * k, 62.0, false)
	_coat_sleeves(coat, cloth(Color("d7bde2")), cloth(Color("ffffff")))
	_wide_hat(felt(Color("a8cce4")), 0.1, 0.24)


## Sheet 50, the elegant lady: a wide pink gown, a lavender bonnet.
func _r_toy_lady(_tint: Color) -> void:
	_recolour("top", cloth(Color("ffb7b2")))
	_recolour("bot", cloth(Color("ffd9e0")))
	_recolour("lea", leather(Color("f3ead6")))
	_long_skirt(cloth(Color("ffd9e0")), cloth(Color("d7bde2")), _p("foot_l").y + 0.06 * k, 0.56, false)
	_shirt_sleeves(cloth(Color("ffb7b2")))
	_shawl(cloth(Color("ffb7b2")))
	_wide_hat(felt(Color("e2cee2")), 0.26, 0.09)


## Sheet 50, the retired husband: a powder-blue jacket, butter trousers, a flat cap.
func _r_toy_grandpa(_tint: Color) -> void:
	var coat := cloth(Color("a8cce4"))
	_recolour("top", cloth(Color("fdf5e6")))
	_recolour("bot", cloth(Color("f9e79f")))
	_recolour("lea", leather(Color("6b4630")))
	_hide("fedora")
	_breeches(cloth(Color("f9e79f")), 0.11)
	_stockings(cloth(Color("f9e79f")))
	_open_coat(coat, cloth(Color("8fb4d0")), _p("pelvis").y - 0.16 * k, 40.0, true)
	_coat_sleeves(coat, cloth(Color("8fb4d0")), cloth(Color("fdf5e6")))
	_knit_cap(cloth(Color("b9ad8a")))


## Sheet 50, the retired wife: a lavender shawl over a mint dress, a bonnet.
func _r_toy_granny(_tint: Color) -> void:
	_recolour("top", cloth(Color("a2d9ce")))
	_recolour("bot", cloth(Color("a2d9ce")))
	_recolour("lea", leather(Color("6b4630")))
	_long_skirt(cloth(Color("a2d9ce")), cloth(Color("f5b7b1")), _p("foot_l").y + 0.06 * k, 0.38, false)
	_shirt_sleeves(cloth(Color("a2d9ce")))
	_shawl(cloth(Color("d7bde2")))
	_kerchief(cloth(Color("a2d9ce")))


## Sheet 50, the child in a sailor suit: a powder-blue blouse with a dark collar, dark shorts, a sailor cap.
func _r_toy_child(_tint: Color) -> void:
	_recolour("top", cloth(Color("aed6f1")))
	_recolour("bot", cloth(Color("2a3a4a")))
	_recolour("lea", leather(Color("6b4630")))
	_hide("fedora")
	_breeches(cloth(Color("2a3a4a")), 0.1)
	_stockings(cloth(Color("d9d9d9")))
	_shirt_sleeves(cloth(Color("aed6f1")))
	_shawl(cloth(Color("1a5b5c")))  # the sailor collar
	_knit_cap(cloth(Color("aed6f1")))


const NOIR_RED := Color("c4302b")  ## the one colour of the short sellers' island (sheet 36)
const NOIR_BLACK := Color("141417")


## Sheet 36, the broker: a black trench coat to the calf, a dark hat pulled low, a white shirt and a red tie.
func _r_noir_broker(_tint: Color) -> void:
	var coat := cloth(NOIR_BLACK)
	_recolour("top", cloth(Color("e8e4dc")))
	_recolour("bot", cloth(Color("2a2a2e")))
	_recolour("lea", leather(Color("101012")))
	_hide("fedora")
	_breeches(cloth(Color("2a2a2e")), 0.1)
	_stockings(cloth(Color("2a2a2e")))
	_open_coat(coat, cloth(Color("26262a")), _p("calf_l").y - 0.06 * k, 38.0, true)
	_coat_sleeves(coat, cloth(Color("26262a")), cloth(Color("e8e4dc")))
	_box("spine_03", cloth(NOIR_RED), Vector3(0.05, 0.3, 0.02) * k, _p("spine_03") + Vector3(0, 0.02, 0.19) * k, Vector3(-0.08, 0, 0))
	_wide_hat(felt(Color("0f0f12")), 0.15, 0.11)


## Sheet 36, the old man: a long grey coat gone at the hem, a crushed hat, a red band on the left arm.
func _r_noir_tramp(_tint: Color) -> void:
	var coat := cloth(Color("77746f"))
	_recolour("top", cloth(Color("5c5a56")))
	_recolour("bot", cloth(Color("4a4844")))
	_recolour("lea", leather(Color("2a2622")))
	_hide("fedora")
	_breeches(cloth(Color("4a4844")), 0.11)
	_stockings(cloth(Color("4a4844")))
	_open_coat(coat, cloth(Color("5c5a56")), _p("calf_l").y - 0.02 * k, 58.0, false)
	_coat_sleeves(coat, cloth(Color("5c5a56")), cloth(Color("8a8782")))
	_tube("upperarm_l", cloth(NOIR_RED), _p("upperarm_l") + Vector3(0, -0.1, 0) * k, _p("upperarm_l") + Vector3(0, -0.18, 0) * k, 0.07 * k, 0.07 * k)
	_wide_hat(felt(Color("3a3835")), 0.13, 0.12)


## Sheet 36, the pale youth: no hat, a short dark jacket over a red shirt, narrow dark trousers.
func _r_noir_youth(_tint: Color) -> void:
	_recolour("top", cloth(NOIR_RED))
	_recolour("bot", cloth(NOIR_BLACK))
	_recolour("lea", leather(Color("101012")))
	_hide("fedora")
	_breeches(cloth(NOIR_BLACK), 0.085)
	_stockings(cloth(NOIR_BLACK))
	_waistcoat(cloth(Color("242428")), 62.0)
	_shirt_sleeves(cloth(Color("242428")))


## Sheet 36, the woman: a belted black coat over a long skirt, a hat with a wide brim, a long red scarf.
func _r_noir_lady(_tint: Color) -> void:
	var coat := cloth(NOIR_BLACK)
	_recolour("top", cloth(NOIR_BLACK))
	_recolour("bot", cloth(Color("1c1c20")))
	_recolour("lea", leather(Color("101012")))
	var hem := _p("foot_l").y + 0.3 * k
	_long_skirt(cloth(Color("1c1c20")), cloth(Color("2a2a2e")), hem, 0.3, false)
	_open_coat(coat, cloth(Color("2a2a2e")), hem + 0.1 * k, 30.0, true)
	_coat_sleeves(coat, cloth(Color("2a2a2e")), cloth(NOIR_BLACK))
	_shawl(cloth(NOIR_RED))
	_box("spine_02", cloth(NOIR_RED), Vector3(0.09, 0.55, 0.02) * k, _p("spine_02") + Vector3(0.06, -0.08, 0.2) * k, Vector3(-0.06, 0, 0.05))
	_wide_hat(felt(Color("0f0f12")), 0.2, 0.09)


func _r_townsman(tint: Color) -> void:
	var coat := cloth(Color("7a4f33").lerp(tint, 0.1))
	_recolour("top", coat if not built else cloth(Color("5d6b4a")))  # his own bulky jacket is the coat
	_recolour("bot", cloth(Color("5e4633")))
	_recolour("lea", leather(SHOE))
	_hide("fedora")
	_breeches(cloth(Color("5e4633")), 0.108)
	_stockings(cloth(Color("e8e0cc")))
	if built:
		_open_coat(coat, cloth(GOLD.darkened(0.2)), _p("calf_l").y, 60.0, false)
		_coat_sleeves(coat, cloth(GOLD.darkened(0.2)), cloth(LINEN))
	else:
		_coat_skirts(coat, cloth(GOLD.darkened(0.2)), _p("calf_l").y, 70.0, 0.235, 0.3)
	_buckles()
	_wide_hat(felt(Color("6b4a30")), 0.19, 0.1)


## Sheet 04, the child: cream shirt, grey breeches to the knee, red sash, blue beret.
func _r_child(_tint: Color) -> void:
	_recolour("top", cloth(LINEN))
	_recolour("bot", cloth(Color("6f6a66")))
	_recolour("lea", leather(SHOE))
	_bare_calves = true
	_shirt_sleeves(cloth(LINEN))
	_breeches(cloth(Color("6f6a66")), 0.12)
	_bare_legs()
	_sash(cloth(SASH), false, 0.3)
	_buckles()
	_beret(cloth(Color("35466e")))


## Sheet 05, the Chronicler: an owl in a blue robe under a cloak of pale feathers, a blue cowl with a brass clasp,
## round brass spectacles, a chained book and a lit lantern. Built whole in code; there is no human under it.
func _r_chronicler(_tint: Color) -> void:
	var feather := _plain("feather", Color("7a869c"), 1.0)  # sheet 26: a layered robe of slate-blue feathers
	var feather_dark := _plain("feather", Color("5c6880"), 1.0)
	var brown := _plain("feather", Color("a58c6c"), 1.0)
	var robe := cloth(Color("3a4560"))
	var base := Vector3(0, 0.0, 0)
	var neck := Vector3(0, 1.42, 0) * k
	_shell("", robe, base + Vector3(0, 0.12, 0) * k, neck, 0.36 * k, 0.15 * k, 0.86)  # robe
	_shell("", feather_dark, base + Vector3(0, 0.08, 0) * k, base + Vector3(0, 0.3, 0) * k, 0.375 * k, 0.33 * k, 0.86, 320.0, 400.0)
	_box("", brown, Vector3(0.2, 0.5, 0.02) * k, Vector3(0, 1.05, 0.2) * k, Vector3(-0.1, 0, 0))  # the tan breast between the lapels
	for i in 6:  # the cloak: tiers of feathers, open at the front
		var y1 := (1.36 - i * 0.17) * k
		var r := (0.2 + i * 0.045) * k
		_shell("", feather if i % 2 == 0 else feather_dark, Vector3(0, y1 - 0.3 * k, 0), Vector3(0, y1, 0), r + 0.09 * k, r - 0.035 * k, 0.9, 42.0, 318.0, 18)
	for sx: float in [-1.0, 1.0]:  # folded wings
		_add("", feather_dark, _sphere(), Transform3D(Basis.from_euler(Vector3(0, 0, sx * 0.12)).scaled_local(Vector3(0.16, 1.0, 0.36) * k), Vector3(sx * 0.33, 0.78, -0.02) * k))
		_tube("", leather(BOOT), Vector3(sx * 0.1, 0.0, 0.02) * k, Vector3(sx * 0.1, 0.2, 0) * k, 0.07 * k, 0.06 * k)
		_box("", leather(BOOT), Vector3(0.13, 0.07, 0.28) * k, Vector3(sx * 0.1, 0.035, 0.08) * k)
		for t in 3:
			_box("", _plain("claw", Color("2a2622"), 0.5), Vector3(0.025, 0.03, 0.08) * k, Vector3(sx * 0.1 + (t - 1) * 0.045, 0.02, 0.25) * k)
	_shell("", cloth(Color("46526c")), neck - Vector3(0, 0.16, 0) * k, neck + Vector3(0, 0.05, 0) * k, 0.26 * k, 0.15 * k, 0.9)  # cowl
	_ball("", metal(), neck + Vector3(0, -0.1, 0.215) * k, 0.04 * k)
	var head := neck + Vector3(0, 0.2, 0.01) * k
	_add("", brown, _sphere(), Transform3D(Basis().scaled(Vector3(0.36, 0.36, 0.33) * k), head))
	_add("", _plain("feather", Color("efe3c8"), 1.0), _sphere(), Transform3D(Basis().scaled(Vector3(0.3, 0.3, 0.12) * k), head + Vector3(0, -0.01, 0.125) * k))
	for sx: float in [-1.0, 1.0]:
		var eye := head + Vector3(sx * 0.07, 0.02, 0.17) * k
		_ball("", _plain("eye", Color("e0a030"), 0.3), eye, 0.04 * k)
		_ball("", _plain("eye", Color("1c1814"), 0.3), eye + Vector3(0, 0, 0.022) * k, 0.022 * k)
		var rim := TorusMesh.new()
		rim.inner_radius = 0.85
		rim.outer_radius = 1.0
		rim.rings = 14
		rim.ring_segments = 6
		_add("", metal(), rim, Transform3D(Basis.from_euler(Vector3(PI / 2, 0, 0)).scaled(Vector3.ONE * 0.058 * k), eye + Vector3(0, 0, 0.03) * k))
		_tube("", brown, head + Vector3(sx * 0.13, 0.1, 0) * k, head + Vector3(sx * 0.22, 0.25, -0.02) * k, 0.06 * k, 0.0)  # ear tufts
	_box("", metal(), Vector3(0.05, 0.012, 0.012) * k, head + Vector3(0, 0.02, 0.2) * k)
	_tube("", _plain("claw", Color("5a5148"), 0.5), head + Vector3(0, -0.02, 0.17) * k, head + Vector3(0, -0.09, 0.21) * k, 0.03 * k, 0.0)  # beak
	_shell("", leather(BOOT), Vector3(0, 0.9, 0) * k, Vector3(0, 0.96, 0) * k, 0.3 * k, 0.29 * k, 0.86, 40.0, 320.0)  # belt under the cloak
	_box("", leather(BOOT), Vector3(0.06, 0.32, 0.02) * k, Vector3(0.05, 0.76, 0.33) * k, Vector3(-0.12, 0, 0))  # the strap end
	_tube("", _plain("ink", Color("1c2030"), 0.3), Vector3(-0.2, 0.74, 0.3) * k, Vector3(-0.2, 0.86, 0.3) * k, 0.045 * k, 0.045 * k)  # the ink bottle
	_tube("", metal(), Vector3(-0.2, 0.86, 0.3) * k, Vector3(-0.2, 0.9, 0.3) * k, 0.02 * k, 0.02 * k)
	# the chained book on the left hip, the lantern in the right hand
	var book := Vector3(0.36, 0.72, 0.16) * k
	_box("", leather(Color("5a3d26")), Vector3(0.08, 0.34, 0.26) * k, book, Vector3(0, 0.3, 0.1))
	_box("", cloth(LINEN), Vector3(0.062, 0.3, 0.262) * k, book + Vector3(0, -0.012, 0.004) * k, Vector3(0, 0.3, 0.1))
	_ball("", metal(), book + Vector3(0.045, 0.02, 0.02) * k, 0.035 * k)
	for i in 7:
		_ball("", metal(), Vector3(0.3 - i * 0.03, 0.9 - sin(i / 6.0 * PI) * 0.16, 0.3) * k, 0.014 * k)
	var lamp := Vector3(-0.36, 0.62, 0.22) * k
	_tube("", metal(), lamp + Vector3(0, 0.17, 0) * k, lamp + Vector3(0, 0.3, 0) * k, 0.008 * k, 0.008 * k)
	_tube("", metal(), lamp + Vector3(0, 0.09, 0) * k, lamp + Vector3(0, 0.17, 0) * k, 0.06 * k, 0.015 * k, 1.0, true, 6)
	_tube("", _glow(), lamp - Vector3(0, 0.08, 0) * k, lamp + Vector3(0, 0.09, 0) * k, 0.05 * k, 0.05 * k, 1.0, true, 6)
	_tube("", metal(), lamp - Vector3(0, 0.11, 0) * k, lamp - Vector3(0, 0.08, 0) * k, 0.06 * k, 0.06 * k, 1.0, true, 6)
	_add("", feather, _sphere(), Transform3D(Basis().scaled(Vector3(0.1, 0.1, 0.1) * k), lamp + Vector3(0.02, 0.32, -0.02) * k))  # the hand
	var light := OmniLight3D.new()
	light.position = lamp
	light.light_color = Color("ffc56e")
	light.light_energy = 0.8
	light.omni_range = 4.0
	light.distance_fade_enabled = true
	light.distance_fade_begin = 30.0
	person.add_child(light)


static func _glow() -> Material:
	if not _mats.has("glow"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("ffd27a")
		m.emission_enabled = true
		m.emission = Color("ffb84a")
		m.emission_energy_multiplier = 2.5
		_mats["glow"] = m
	return _mats["glow"]


# ---------------------------------------------------------------- the person's own clothes

## Replaces the texture of the clothing surfaces whose material name ends in `part` (top, bot, lea) with `m`,
## keeping the folds of the original normal map.
func _recolour(part: String, m: Material) -> void:
	if built:
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
	if built:
		return
	for mi: MeshInstance3D in sk.find_children("*", "MeshInstance3D", true, false):
		if str(mi.name).contains(what):
			mi.visible = false


# ---------------------------------------------------------------- garments (skeleton space, rest pose)

## A point on a shell from `a` up to `b`: `deg` round from the front (towards the person's left), `t` along it.
func _on(a: Vector3, b: Vector3, r0: float, r1: float, flat: float, deg: float, t: float) -> Vector3:
	var th := deg_to_rad(deg)
	return a.lerp(b, t) + (Vector3.BACK * cos(th) * flat + Vector3.RIGHT * sin(th)) * lerpf(r0, r1, t) * (g if built else 1.0)


## An open long coat: trunk, shoulders, standing collar, skirts down to `hem` (height), a gap of `gap` degrees at the
## front, an edge and a hem in `trim`, a row of buttons. Skirts hang from the thighs (two halves that follow the
## stride) or, for somebody who stands (`standing`), from the hips in one piece.
func _open_coat(m: Material, trim: Material, hem: float, gap: float, standing: bool) -> void:
	var hip := _p("pelvis") + Vector3(0, 0.03, 0) * k
	var chest := _p("spine_03")
	var neck := _p("neck_01")
	var g := gap * 0.5
	_shell("spine_01", m, hip, chest, 0.205 * k, 0.222 * k, 0.88, g, 360.0 - g)
	_shell("spine_03", m, chest, neck - Vector3(0, 0.04, 0) * k, 0.222 * k, 0.13 * k, 0.88, g + 6.0, 354.0 - g)
	_shell("spine_03", m, neck - Vector3(0, 0.06, 0) * k, neck + Vector3(0, 0.035, 0) * k, 0.1 * k, 0.118 * k, 0.9, 62.0, 298.0)  # collar
	for s: String in ["l", "r"]:
		_ball("spine_03", m, _p("upperarm_" + s) + Vector3(0, 0.005, 0) * k, 0.072 * k)
	for e: float in [g, 360.0 - g - 5.0]:  # the gold edge down the front
		_shell("spine_01", trim, hip, chest, 0.208 * k, 0.225 * k, 0.88, e, e + 5.0, 2)
	for i in 5:
		_ball("spine_02", metal(), _on(hip, chest, 0.21 * k, 0.227 * k, 0.88, g + 11.0, 0.08 + i * 0.2), 0.013 * k)
		_ball("spine_02", metal(), _on(hip, chest, 0.21 * k, 0.227 * k, 0.88, 349.0 - g, 0.08 + i * 0.2), 0.013 * k)
	_coat_skirts(m, trim, hem, gap, 0.205, 0.33, standing)


func _coat_skirts(m: Material, trim: Material, hem: float, gap: float, r_top: float, r_hem: float, standing: bool = false) -> void:
	var hip := _p("pelvis") + Vector3(0, 0.04, 0) * k
	var low := Vector3(hip.x, hem, hip.z)
	var g := gap * 0.5
	var halves := [["pelvis", g, 360.0 - g]] if standing else [["thigh_l", g, 180.0], ["thigh_r", 180.0, 360.0 - g]]
	for h: Array in halves:
		_shell(h[0], m, low, hip, r_hem * k, r_top * k, 0.8, h[1], h[2])
		_shell(h[0], trim, low, low + Vector3(0, 0.022, 0) * k, (r_hem + 0.004) * k, (r_hem + 0.003) * k, 0.8, h[1], h[2])
	_shell("pelvis" if standing else "thigh_l", trim, low, hip, (r_hem + 0.004) * k, (r_top + 0.004) * k, 0.8, g, g + 4.0, 2)
	_shell("pelvis" if standing else "thigh_r", trim, low, hip, (r_hem + 0.004) * k, (r_top + 0.004) * k, 0.8, 356.0 - g, 360.0 - g, 2)
	if not standing:  # the vent at the back
		_shell("thigh_l", trim, low, low.lerp(hip, 0.5), (r_hem + 0.004) * k, ((r_hem + r_top) * 0.5 + 0.004) * k, 0.8, 177.0, 180.0, 2)


## A waistcoat or bodice over the shirt, open `gap` degrees at the front.
func _waistcoat(m: Material, gap: float) -> void:
	var hip := _p("pelvis") + Vector3(0, 0.07, 0) * k
	var chest := _p("spine_03")
	var g := gap * 0.5
	_shell("spine_01", m, hip, chest, 0.2 * k, 0.215 * k, 0.88, g, 360.0 - g)
	_shell("spine_03", m, chest, _p("neck_01") - Vector3(0, 0.06, 0) * k, 0.215 * k, 0.15 * k, 0.88, g + 14.0, 346.0 - g)
	for i in 4:
		_ball("spine_02", metal(), _on(hip, chest, 0.204 * k, 0.218 * k, 0.88, g + 8.0, 0.12 + i * 0.24), 0.011 * k)


## Coat sleeves with a wide turned-back cuff edged in `trim` and the shirt's lace at the wrist.
func _coat_sleeves(m: Material, trim: Material, lace: Material) -> void:
	for s: String in ["l", "r"]:
		var sh := _p("upperarm_" + s)
		var el := _p("lowerarm_" + s)
		var wr := _p("hand_" + s)
		_tube("upperarm_" + s, m, sh.lerp(el, 0.02), el, 0.066 * k, 0.06 * k)
		_tube("lowerarm_" + s, m, el, el.lerp(wr, 0.7), 0.06 * k, 0.058 * k)
		_tube("lowerarm_" + s, m, el.lerp(wr, 0.5), el.lerp(wr, 0.9), 0.082 * k, 0.092 * k)
		_tube("lowerarm_" + s, trim, el.lerp(wr, 0.5), el.lerp(wr, 0.56), 0.085 * k, 0.086 * k)
		_tube("lowerarm_" + s, lace, el.lerp(wr, 0.86), el.lerp(wr, 1.04), 0.05 * k, 0.07 * k)
		for i in 2:
			_ball("lowerarm_" + s, metal(), el.lerp(wr, 0.64 + i * 0.14) + Vector3(signf(sh.x) * 0.088, 0, 0) * k, 0.012 * k)


## Full shirt sleeves, billowing and gathered at the wrist.
func _shirt_sleeves(m: Material) -> void:
	for s: String in ["l", "r"]:
		var sh := _p("upperarm_" + s)
		var el := _p("lowerarm_" + s)
		var wr := _p("hand_" + s)
		_tube("upperarm_" + s, m, sh.lerp(el, 0.02), el, 0.068 * k, 0.07 * k)
		_tube("lowerarm_" + s, m, el, el.lerp(wr, 0.6), 0.07 * k, 0.086 * k)
		_tube("lowerarm_" + s, m, el.lerp(wr, 0.6), el.lerp(wr, 0.92), 0.086 * k, 0.042 * k)


## Sleeves rolled above the elbow: the forearm is bare.
func _rolled_sleeves(m: Material, roll: Material) -> void:
	for s: String in ["l", "r"]:
		var sh := _p("upperarm_" + s)
		var el := _p("lowerarm_" + s)
		_tube("upperarm_" + s, m, sh.lerp(el, 0.02), sh.lerp(el, 0.86), 0.07 * k, 0.074 * k)
		_tube("upperarm_" + s, roll, sh.lerp(el, 0.78), sh.lerp(el, 0.98), 0.08 * k, 0.078 * k)


## A sash wound round the waist, knotted on the left hip with a long fringed end on the thigh (it swings with the
## leg). With `belt`, a leather belt with a brass buckle goes over it.
func _sash(m: Material, belt: bool, end: float) -> void:
	var hip := _p("pelvis") + Vector3(0, 0.07, 0) * k
	_shell("pelvis", m, hip - Vector3(0, 0.06, 0) * k, hip + Vector3(0, 0.06, 0) * k, 0.218 * k, 0.214 * k, 0.8)
	var knot := hip + Vector3(0.165, -0.02, 0.085) * k * (g if built else 1.0)
	_ball("pelvis", m, knot, 0.05 * k)
	_box("thigh_l", m, Vector3(0.075, end, 0.02) * k, knot + Vector3(0.012, -end * 0.5, 0.004) * k, Vector3(0, 0.5, 0.07))
	_box("thigh_l", m, Vector3(0.06, end * 0.8, 0.02) * k, knot + Vector3(-0.035, -end * 0.4, 0.016) * k, Vector3(0, 0.5, -0.09))
	if belt:
		_shell("pelvis", leather(Color("5e3b28")), hip - Vector3(0, 0.022, 0) * k, hip + Vector3(0, 0.022, 0) * k, 0.226 * k, 0.226 * k, 0.8)
		_box("pelvis", metal(), Vector3(0.07, 0.06, 0.014) * k, hip + Vector3(0, 0, 0.183) * k * (g if built else 1.0))
		_box("pelvis", leather(Color("5e3b28")), Vector3(0.04, 0.035, 0.016) * k, hip + Vector3(0, 0, 0.184) * k * (g if built else 1.0))


## Breeches: full in the thigh, gathered under the knee.
func _breeches(m: Material, fullness: float) -> void:
	for s: String in ["l", "r"]:
		var hip := _p("thigh_" + s)
		var knee := _p("calf_" + s)
		var ankle := _p("foot_" + s)
		_tube("thigh_" + s, m, hip.lerp(knee, 0.08), knee, 0.1 * k, fullness * k)
		_tube("calf_" + s, m, knee, knee.lerp(ankle, 0.2), fullness * k, 0.066 * k)


## Slops: very baggy sailor's trousers gathered below the knee; the calf is bare.
func _slops(m: Material) -> void:
	for s: String in ["l", "r"]:
		var hip := _p("thigh_" + s)
		var knee := _p("calf_" + s)
		var ankle := _p("foot_" + s)
		_tube("thigh_" + s, m, hip.lerp(knee, 0.06), knee, 0.112 * k, 0.15 * k)
		_tube("calf_" + s, m, knee, knee.lerp(ankle, 0.2), 0.15 * k, 0.13 * k)
		_tube("calf_" + s, m, knee.lerp(ankle, 0.2), knee.lerp(ankle, 0.34), 0.13 * k, 0.062 * k)


## Bare calves below slops or breeches: the downloaded body wears long trousers, so skin goes over them.
func _bare_legs() -> void:
	if built:
		return  # the built person draws its own calves in skin
	for s: String in ["l", "r"]:
		var knee := _p("calf_" + s)
		var ankle := _p("foot_" + s)
		_tube("calf_" + s, _plain("skin", Color("d9a882"), 0.6), knee.lerp(ankle, 0.15) - Vector3(0, 0, 0.012) * k, ankle + Vector3(0, 0.0, -0.01) * k, 0.084 * k, 0.08 * k)


## Sea boots: brown, to the knee, with a wide folded top.
func _boots(m: Material) -> void:
	for s: String in ["l", "r"]:
		var knee := _p("calf_" + s)
		var ankle := _p("foot_" + s)
		var up := ankle.lerp(knee, 0.86)
		_tube("calf_" + s, m, ankle - Vector3(0, 0.05, 0.014) * k, up - Vector3(0, 0, 0.012) * k, 0.092 * k, 0.096 * k)
		_tube("calf_" + s, m, up - Vector3(0, 0.1, 0.012) * k, up + Vector3(0, 0.03, -0.012) * k, 0.1 * k, 0.128 * k)


## White stockings to the knee.
func _stockings(m: Material) -> void:
	for s: String in ["l", "r"]:
		var knee := _p("calf_" + s)
		var ankle := _p("foot_" + s)
		_tube("calf_" + s, m, ankle, knee.lerp(ankle, 0.16), 0.074 * k, 0.086 * k)


## Brass buckles on the shoes.
func _buckles() -> void:
	for s: String in ["l", "r"]:
		_box("foot_" + s, metal(), Vector3(0.05, 0.02, 0.035) * k, _p("foot_" + s) + Vector3(0, 0.0, 0.085) * k, Vector3(0.5, 0, 0))


## A long skirt down to `hem` (height) with a band of another colour at the foot. For somebody who walks it is in
## halves that follow the thighs and calves; for somebody who stands it is one bell from the hips.
func _long_skirt(m: Material, band: Material, hem: float, r_hem: float, walks: bool) -> void:
	var hip := _p("pelvis") + Vector3(0, 0.08, 0) * k
	var low := Vector3(hip.x, hem, hip.z)
	if not walks:
		_shell("pelvis", m, low, hip, r_hem * k, 0.205 * k, 0.86)
		_shell("pelvis", band, low - Vector3(0, 0.04, 0) * k, low + Vector3(0, 0.05, 0) * k, (r_hem + 0.012) * k, (r_hem - 0.004) * k, 0.86)
		return
	var knee_y := _p("calf_l").y
	var mid := Vector3(hip.x, knee_y, hip.z)
	var r_mid := lerpf(0.205, r_hem, (hip.y - knee_y) / (hip.y - hem))
	_shell("pelvis", m, hip - Vector3(0, 0.1, 0) * k, hip, 0.235 * k, 0.205 * k, 0.86)
	for h: Array in [["l", 0.0, 180.0], ["r", 180.0, 360.0]]:
		_shell("thigh_" + str(h[0]), m, mid, hip - Vector3(0, 0.08, 0) * k, r_mid * k, 0.23 * k, 0.86, h[1], h[2])
		_shell("calf_" + str(h[0]), m, low, mid, r_hem * k, r_mid * k, 0.86, h[1], h[2])
		_shell("calf_" + str(h[0]), band, low - Vector3(0, 0.04, 0) * k, low + Vector3(0, 0.05, 0) * k, (r_hem + 0.012) * k, (r_hem - 0.004) * k, 0.86, h[1], h[2])


## An apron lying on a skirt that reaches `hem` with radius `r_hem`; in halves on the thighs when she walks.
func _apron(m: Material, hem: float, r_hem: float, walks: bool) -> void:
	var hip := _p("pelvis") + Vector3(0, 0.08, 0) * k
	var low_y := _p("calf_l").y - 0.2 * k
	var r_low := lerpf(0.205, r_hem, (hip.y - low_y) / (hip.y - hem)) + 0.014
	var low := Vector3(hip.x, low_y, hip.z)
	if walks:
		_shell("thigh_l", m, low, hip, r_low * k, 0.222 * k, 0.86, 0.0, 40.0)
		_shell("thigh_r", m, low, hip, r_low * k, 0.222 * k, 0.86, -40.0, 0.0)
	else:
		_shell("pelvis", m, low, hip, r_low * k, 0.222 * k, 0.86, -40.0, 40.0)
	_shell("pelvis", m, hip - Vector3(0, 0.02, 0) * k, hip + Vector3(0, 0.02, 0) * k, 0.224 * k, 0.222 * k, 0.86)


## A shawl over the shoulders, knotted on the chest with the ends hanging.
func _shawl(m: Material) -> void:
	var neck := _p("neck_01")
	var chest := _p("spine_03")
	_shell("spine_03", m, chest - Vector3(0, 0.02, 0) * k, neck - Vector3(0, 0.02, 0) * k, 0.275 * k, 0.12 * k, 0.76)
	var knot := chest + Vector3(0, 0.05, 0.19 * g) * k
	_ball("spine_03", m, knot, 0.045 * k)
	for sx: float in [-1.0, 1.0]:
		_box("spine_02", m, Vector3(0.07, 0.24, 0.02) * k, knot + Vector3(sx * 0.04, -0.14, 0.0) * k, Vector3(-0.1, 0, sx * 0.22))


func _cravat() -> void:
	var neck := _p("neck_01")
	_ball("spine_03", cloth(LINEN), neck + Vector3(0, -0.035, 0.085) * k, 0.045 * k)
	_box("spine_03", cloth(LINEN), Vector3(0.08, 0.13, 0.03) * k, neck + Vector3(0, -0.11, 0.105 * g) * k, Vector3(-0.25, 0, 0))


## The anchor badge of the Order: a brass ring with an anchor on a chain.
func _medallion() -> void:
	var at := _p("spine_03") + Vector3(0, 0.03, 0.2 * g) * k
	var ring := TorusMesh.new()
	ring.inner_radius = 0.78
	ring.outer_radius = 1.0
	ring.rings = 14
	ring.ring_segments = 6
	_add("spine_03", metal(), ring, Transform3D(Basis.from_euler(Vector3(PI / 2, 0, 0)).scaled(Vector3.ONE * 0.05 * k), at))
	_box("spine_03", metal(), Vector3(0.012, 0.07, 0.01) * k, at)
	_box("spine_03", metal(), Vector3(0.04, 0.012, 0.01) * k, at + Vector3(0, 0.02, 0) * k)
	_box("spine_03", metal(), Vector3(0.05, 0.012, 0.01) * k, at + Vector3(0, -0.028, 0) * k)
	for i in 5:
		for sx: float in [-1.0, 1.0]:
			_ball("spine_03", metal(), at + Vector3(sx * (0.02 + i * 0.018), 0.05 + i * 0.03, -0.006 - i * 0.012) * k, 0.008 * k)


## A rolled chart under the left arm.
func _chart() -> void:
	var at := _p("lowerarm_l") + Vector3(-0.07, -0.02, 0.07) * k
	_tube("spine_02", cloth(Color("e9dcb8")), at + Vector3(0.0, -0.2, -0.12) * k, at + Vector3(0.03, 0.2, 0.12) * k, 0.045 * k, 0.045 * k, 1.0, true, 10)
	_tube("spine_02", leather(Color("5e3b28")), at + Vector3(0.012, -0.04, -0.03) * k, at + Vector3(0.018, 0.04, 0.03) * k, 0.048 * k, 0.048 * k, 1.0, false, 10)


## A leather pouch on the belt.
func _pouch(side: String) -> void:
	var sx := 1.0 if side == "l" else -1.0
	var at := _p("pelvis") + Vector3(sx * 0.16, -0.03, 0.12) * k * Vector3(g, 1, g)
	_box("thigh_" + side, leather(Color("6b4630")), Vector3(0.1, 0.12, 0.05) * k, at, Vector3(0, sx * 0.6, 0))
	_box("thigh_" + side, leather(Color("5e3b28")), Vector3(0.104, 0.05, 0.054) * k, at + Vector3(0, 0.04, 0) * k, Vector3(0, sx * 0.6, 0))
	_ball("thigh_" + side, metal(), at + Vector3(sx * 0.015, 0.02, 0.028) * k, 0.01 * k)


## A brass spyglass hung from the belt on the left.
func _spyglass() -> void:
	var a := _p("pelvis") + Vector3(0.2 * g, 0.02, 0.06 * g) * k
	var b := a + Vector3(0.03, -0.26, 0.05) * k
	_tube("thigh_l", metal(), a, a.lerp(b, 0.6), 0.02 * k, 0.026 * k, 1.0, true, 10)
	_tube("thigh_l", leather(Color("5e3b28")), a.lerp(b, 0.25), a.lerp(b, 0.45), 0.027 * k, 0.028 * k, 1.0, false, 10)
	_tube("thigh_l", metal(), a.lerp(b, 0.6), b, 0.03 * k, 0.036 * k, 1.0, true, 10)


## A flask on a strap at the hip.
func _flask(side: String) -> void:
	var sx := 1.0 if side == "l" else -1.0
	var at := _p("pelvis") + Vector3(sx * 0.19 * g, -0.08, -0.04) * k
	_tube("thigh_" + side, leather(Color("7a5236")), at - Vector3(0, 0.07, 0) * k, at + Vector3(0, 0.05, 0) * k, 0.045 * k, 0.04 * k, 0.55, true, 7)
	_tube("thigh_" + side, metal(), at + Vector3(0, 0.05, 0) * k, at + Vector3(0, 0.085, 0) * k, 0.014 * k, 0.014 * k, 1.0, true, 5)


## A coil of rope worn over one shoulder and across the chest.
func _rope() -> void:
	var coil := TorusMesh.new()
	coil.inner_radius = 0.86
	coil.outer_radius = 1.0
	coil.rings = 10
	coil.ring_segments = 5
	var chest := _p("spine_02") + Vector3(0, 0.06, 0) * k
	for i in 3:
		_add("spine_02", cloth(Color("b89a6a")), coil, Transform3D(Basis.from_euler(Vector3(PI / 2 - 0.1, 0, 0.6 + i * 0.05)).scaled_local(Vector3(0.3 * g, 1.0, 0.36) * k * (1.0 + i * 0.04)), chest))


## A satchel on a strap across the body.
func _satchel() -> void:
	var at := _p("pelvis") + Vector3(-0.2 * g, -0.06, 0.07 * g) * k
	_box("pelvis", leather(Color("6b4630")), Vector3(0.07, 0.17, 0.2) * k, at)
	_box("pelvis", leather(Color("5e3b28")), Vector3(0.074, 0.07, 0.204) * k, at + Vector3(0, 0.05, 0) * k)
	var chest := _p("spine_03")
	_box("spine_02", leather(Color("5e3b28")), Vector3(0.03, 0.62, 0.012) * k, chest.lerp(at, 0.45) + Vector3(0.1, 0.04, 0.178) * k, Vector3(0, 0, -0.62))


## A tricorn: a low crown and a brim turned up on three sides, a point forward, the edge in `trim`.
func _tricorn(m: Material, trim: Material) -> void:
	var c := Vector3(0, top - 0.03 * hk, _p("head").z - 0.012 * hk)
	var turn := Basis(Vector3.UP, PI)  # a corner of the three-sided brim to the front
	_tube("head", m, c, c + Vector3(0, 0.075, 0) * hk, 0.1 * hk, 0.085 * hk, 1.0, true, 12)
	for part: Array in [[m, 0.0, 0.085, 0.13, 0.25], [trim, 0.078, 0.094, 0.248, 0.262]]:
		var brim := CylinderMesh.new()
		brim.bottom_radius = float(part[3]) * hk
		brim.top_radius = float(part[4]) * hk
		brim.height = (float(part[2]) - float(part[1])) * hk
		brim.radial_segments = 3
		brim.rings = 1
		brim.cap_top = false
		brim.cap_bottom = part[0] == m
		_add("head", part[0], brim, Transform3D(turn, c + Vector3(0, (float(part[1]) + float(part[2])) * 0.5 - 0.01, 0) * hk))


## A felt hat with a wide round brim that droops a little.
func _wide_hat(m: Material, brim: float, crown: float) -> void:
	var c := Vector3(0, top - 0.025 * hk, _p("head").z - 0.012 * hk)
	_tube("head", m, c, c + Vector3(0, crown, 0) * hk, 0.105 * hk, 0.085 * hk, 1.0, true)
	_tube("head", m, c - Vector3(0, 0.03, 0) * hk, c + Vector3(0, 0.008, 0) * hk, brim * hk, 0.1 * hk, 1.0, false, 18)
	_tube("head", m, c - Vector3(0, 0.032, 0) * hk, c - Vector3(0, 0.024, 0) * hk, brim * hk, brim * 0.99 * hk, 1.0, true, 18)


## A scarf tied round the head under the hat, its ends hanging at the back.
func _headscarf(m: Material) -> void:
	var c := Vector3(0, top - 0.09 * hk, _p("head").z - 0.014 * hk)
	_dome("head", m, c, Vector3(0.114, 0.085, 0.13) * hk)
	_tube("head", m, c - Vector3(0, 0.03, 0) * hk, c + Vector3(0, 0.012, 0) * hk, 0.118 * hk, 0.116 * hk, 1.13)
	var knot := c + Vector3(0, -0.03, -0.14) * hk
	_ball("head", m, knot, 0.032 * hk)
	for sx: float in [-1.0, 1.0]:
		_box("head", m, Vector3(0.05, 0.2, 0.014) * hk, knot + Vector3(sx * 0.03, -0.1, -0.01) * hk, Vector3(0.2, 0, sx * 0.2))


## A bandana tied over the hair; the knot and its ends sit at the side (`side`) or at the back.
func _bandana(m: Material, side: bool = false) -> void:
	_hide("short")  # the cloth covers the hair
	var c := Vector3(0, top - 0.085 * hk, _p("head").z - 0.012 * hk)
	_dome("head", m, c, Vector3(0.112, 0.1, 0.128) * hk)
	_tube("head", m, c + Vector3(0, -0.02, 0) * hk, c + Vector3(0, 0.02, 0) * hk, 0.116 * hk, 0.114 * hk, 1.13)
	var knot := c + (Vector3(-0.115, -0.01, -0.05) if side else Vector3(0.03, 0.0, -0.125)) * hk
	_ball("head", m, knot, 0.03 * hk)
	_box("head", m, Vector3(0.045, 0.16, 0.012) * hk, knot + Vector3(-0.012, -0.085, -0.012) * hk, Vector3(0.2, 0, 0.3 if side else 0.2))
	_box("head", m, Vector3(0.04, 0.12, 0.012) * hk, knot + Vector3(0.012, -0.065, -0.02) * hk, Vector3(0.3, 0, -0.2))


## A knitted cap with a rolled edge.
func _knit_cap(m: Material) -> void:
	_hide("short")
	var c := Vector3(0, top - 0.075 * hk, _p("head").z - 0.014 * hk)
	_dome("head", m, c, Vector3(0.112, 0.11, 0.126) * hk)
	_tube("head", m, c - Vector3(0, 0.025, 0) * hk, c + Vector3(0, 0.02, 0) * hk, 0.122 * hk, 0.12 * hk, 1.12)


## A soft flat cap, wider than the head.
func _beret(m: Material) -> void:
	var c := Vector3(0, top - 0.045 * hk, _p("head").z - 0.02 * hk)
	_dome("head", m, c, Vector3(0.15, 0.07, 0.16) * hk)
	_tube("head", m, c - Vector3(0, 0.025, 0) * hk, c, 0.112 * hk, 0.15 * hk, 1.07)


## A kerchief tied over the hair, a corner hanging behind.
func _kerchief(m: Material) -> void:
	var c := Vector3(0, top - 0.075 * hk, _p("head").z - 0.02 * hk)
	_dome("head", m, c, Vector3(0.114, 0.105, 0.13) * hk)
	_tube("head", m, c - Vector3(0, 0.03, 0) * hk, c + Vector3(0, 0.01, 0) * hk, 0.118 * hk, 0.116 * hk, 1.12)
	_box("head", m, Vector3(0.14, 0.15, 0.016) * hk, c + Vector3(0, -0.07, -0.125) * hk, Vector3(0.25, 0, 0))


## Hair pinned up in a bun.
func _bun() -> void:
	_ball("head", _plain("hair", Color("5a3a26"), 0.9), Vector3(0, top - 0.02 * hk, _p("head").z - 0.08 * hk), 0.06 * hk)


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
func _tube(bone: String, m: Material, a: Vector3, b: Vector3, r0: float, r1: float, flat: float = 1.0, caps: bool = false, sides: int = 8) -> void:
	var c := CylinderMesh.new()
	c.bottom_radius = r0 * _w(bone)
	c.top_radius = r1 * _w(bone)
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


## How much wider than the standard a piece on `bone` is for this person's girth.
func _w(bone: String) -> float:
	if not built or bone.begins_with("head") or bone.begins_with("neck") or bone.begins_with("foot") or bone.begins_with("hand"):
		return 1.0
	if bone.begins_with("thigh"):
		return pow(g, 0.8)
	if bone.begins_with("calf") or bone.contains("arm"):
		return pow(g, 0.45)
	return g


## An open or closed shell round the vertical line from `a` up to `b`: radius `r0` at `a`, `r1` at `b`, squashed
## front-to-back by `flat`, covering the angles `from`..`to` in degrees, measured from the front towards the left.
func _shell(bone: String, m: Material, a: Vector3, b: Vector3, r0: float, r1: float, flat: float = 1.0, from: float = 0.0, to: float = 360.0, sides: int = 10) -> void:
	r0 *= _w(bone)
	r1 *= _w(bone)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := maxi(1, int(ceil(sides * absf(to - from) / 360.0)))
	for i in steps + 1:
		var th := deg_to_rad(lerpf(from, to, float(i) / steps))
		var out := Vector3.BACK * cos(th) * flat + Vector3.RIGHT * sin(th)
		var n := (Vector3.BACK * cos(th) / maxf(flat, 0.01) + Vector3.RIGHT * sin(th)).normalized()
		for t: float in [0.0, 1.0]:
			st.set_normal(n)
			st.set_uv(Vector2(float(i) / steps, 1.0 - t))
			st.add_vertex(a.lerp(b, t) + out * lerpf(r0, r1, t))
	for i in steps:
		for j: int in [0, 1, 2, 2, 1, 3]:
			st.add_index(i * 2 + j)
	_add(bone, m, st.commit(), Transform3D())


func _box(bone: String, m: Material, size: Vector3, at: Vector3, rot: Vector3 = Vector3.ZERO) -> void:
	_add(bone, m, BoxMesh.new(), Transform3D(Basis.from_euler(rot).scaled_local(size), at))


func _ball(bone: String, m: Material, at: Vector3, r: float) -> void:
	if r < 0.02 * k:  # a button or a chain link: a tiny cube reads the same and costs 12 triangles
		_box(bone, m, Vector3.ONE * r * 1.7, at, Vector3(0.6, 0.6, 0))
		return
	var s := SphereMesh.new()
	s.radial_segments = 8
	s.rings = 4
	_add(bone, m, s, Transform3D(Basis().scaled(Vector3.ONE * r * 2.0), at))


## The top half of an ellipsoid with radii `r`, its flat side at `at`.
func _dome(bone: String, m: Material, at: Vector3, r: Vector3) -> void:
	var s := SphereMesh.new()
	s.is_hemisphere = true
	s.radius = 1.0
	s.height = 1.0
	s.radial_segments = 10
	s.rings = 3
	_add(bone, m, s, Transform3D(Basis().scaled(r), at))


func _add(bone: String, m: Material, mesh: Mesh, xf: Transform3D) -> void:
	var idx := sk.find_bone(bone) if sk != null and not bone.is_empty() else 0
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


## One mesh for the whole costume, a surface per material; skinned when there is a skeleton. A built person is
## faceted: every triangle gets its own flat normal, the low-poly look of ADR-0024.
func _commit() -> void:
	if _parts.is_empty():
		return
	var mesh := ArrayMesh.new()
	for m: Material in _parts:
		var part: Dictionary = _parts[m]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		if built:
			var v: PackedVector3Array = part["v"]
			var b: PackedInt32Array = part["b"]
			var idx: PackedInt32Array = part["i"]
			var fv := PackedVector3Array()
			var fn := PackedVector3Array()
			var u: PackedVector2Array = part["u"]
			var fu := PackedVector2Array()
			var fb := PackedInt32Array()
			var fw := PackedFloat32Array()
			for t in range(0, idx.size(), 3):
				var p0 := v[idx[t]]
				var p1 := v[idx[t + 1]]
				var p2 := v[idx[t + 2]]
				var n := (p2 - p0).cross(p1 - p0).normalized()
				if n.dot((part["n"] as PackedVector3Array)[idx[t]]) < 0.0:
					n = -n
				for j in 3:
					fv.append(v[idx[t + j]])
					fn.append(n)
					fu.append(u[idx[t + j]])
					fb.append_array(PackedInt32Array([b[idx[t + j] * 4], 0, 0, 0]))
					fw.append_array(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
			arrays[Mesh.ARRAY_VERTEX] = fv
			arrays[Mesh.ARRAY_NORMAL] = fn
			arrays[Mesh.ARRAY_TEX_UV] = fu
			if sk != null:
				arrays[Mesh.ARRAY_BONES] = fb
				arrays[Mesh.ARRAY_WEIGHTS] = fw
		else:
			arrays[Mesh.ARRAY_VERTEX] = part["v"]
			arrays[Mesh.ARRAY_NORMAL] = part["n"]
			arrays[Mesh.ARRAY_TEX_UV] = part["u"]
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

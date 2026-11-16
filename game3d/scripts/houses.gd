## Pattern: Builder — a half-timbered house put together from modules: stone plinth, plastered walls in a timber
## frame, windows with shutters, a door with steps, a tiled gable roof with eaves, a chimney, a hanging sign, grime
## decals at the base, and colliders that follow the walls and the steps. Our own procedural meshes (CC0) with
## Poly Haven PBR materials when downloaded. The door faces +z. See docs/adr/0019-game3d-pbr-assets.md
class_name Houses
extends RefCounted

const PLINTH := 0.55
const FOUNDATION := 1.4  ## how deep the stone goes below the door level
const STOREY := 2.7
const EAVE := 0.45
const VERGE := 0.35
const SHUTTERS: Array[Color] = [Color("3f6f8f"), Color("5a7d4a"), Color("8a3b32"), Color("b0803a"), Color("4d4a7a")]

static var _glass: StandardMaterial3D
static var _mats: Dictionary = {}


## `roof` tints the tiles; `storeys` 1 or 2; `sign` hangs a signboard by the door.
static func house(rng: RandomNumberGenerator, roof: Color, storeys: int = 0, with_sign: bool = false) -> Node3D:
	var hs := Node3D.new()
	hs.name = "House"
	if storeys == 0:
		storeys = 2 if rng.randf() < 0.4 else 1
	var w := snappedf(rng.randf_range(5.0, 6.4), 0.1)
	var d := snappedf(rng.randf_range(4.2, 5.0), 0.1)
	var h := STOREY * storeys + (0.3 if storeys == 1 else 0.0)
	var top := PLINTH + h
	var pitch := deg_to_rad(rng.randf_range(40.0, 46.0))
	var ridge := top + tan(pitch) * d * 0.5
	var plaster := _plaster(rng.randf() * 0.08)
	var timber := Proc.mat(Proc.TIMBER_DARK)
	var stone := _stone()
	var shutter := _paint(SHUTTERS[rng.randi() % SHUTTERS.size()])
	var k := Kit.new()

	# plinth (with a foundation that goes into the ground, for a house on a slope) and walls
	k.box(stone, Vector3(w + 0.3, PLINTH + FOUNDATION, d + 0.3), Vector3(0, (PLINTH - FOUNDATION) * 0.5, 0))
	k.box(plaster, Vector3(w, h, d), Vector3(0, PLINTH + h * 0.5, 0))
	for sx: float in [-1.0, 1.0]:  # gables
		var x := sx * w * 0.5
		var a := Vector3(x, top, -d * 0.5)
		var b := Vector3(x, top, d * 0.5)
		var c := Vector3(x, ridge, 0)
		if sx > 0:
			k.tri(plaster, a, b, c)
		else:
			k.tri(plaster, a, c, b)

	# timber frame, 5 cm proud of the plaster
	var t := 0.2
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.box(timber, Vector3(t + 0.06, h, t + 0.06), Vector3(sx * (w - t) * 0.5, PLINTH + h * 0.5, sz * (d - t) * 0.5))
	var levels: Array[float] = [PLINTH + t * 0.5, top - t * 0.5]
	if storeys == 2:
		levels.append(PLINTH + STOREY)
	for y in levels:
		k.box(timber, Vector3(w + 0.1, t, d + 0.1), Vector3(0, y, 0))
	var studs := int(round(w / 1.5))
	for i in range(1, studs):
		var x := -w * 0.5 + w * i / studs
		for s in storeys:
			if s == 0 and absf(x) < 0.9:
				continue  # the door
			k.box(timber, Vector3(0.14, STOREY, d + 0.08), Vector3(x, PLINTH + STOREY * (s + 0.5), 0))
	for sx: float in [-1.0, 1.0]:  # gable ends: king post, collar, braces
		var x := sx * (w * 0.5 + 0.02)
		k.box(timber, Vector3(0.08, ridge - top, 0.16), Vector3(x, (ridge + top) * 0.5, 0))
		k.box(timber, Vector3(0.08, h, 0.16), Vector3(x, PLINTH + h * 0.5, 0))
		for sz: float in [-1.0, 1.0]:
			var len := d * 0.5 / cos(pitch)
			k.box(timber, Vector3(0.08, 0.16, len), Vector3(x, (ridge + top) * 0.5 - 0.08, sz * d * 0.25), Vector3(sz * pitch, 0, 0))
			k.box(timber, Vector3(0.08, 0.14, 1.9), Vector3(x, PLINTH + 0.95, sz * (d * 0.5 - 0.85)), Vector3(sz * 0.9, 0, 0))

	# roof: two tiled slopes with eaves and verges, boards under them, a ridge
	var tiles := _tiles(roof)
	var hw := w * 0.5 + VERGE
	for sz: float in [-1.0, 1.0]:
		var eave := Vector3(0, top - tan(pitch) * EAVE + 0.12, sz * (d * 0.5 + EAVE))
		var peak := Vector3(0, ridge + 0.12, 0)
		var a := eave + Vector3(-hw, 0, 0)
		var b := eave + Vector3(hw, 0, 0)
		var c := peak + Vector3(hw, 0, 0)
		var e := peak + Vector3(-hw, 0, 0)
		if sz > 0:
			k.quad(tiles, a, b, c, e, 0.45)
		else:
			k.quad(tiles, b, a, e, c, 0.45)
		var mid := (eave + peak) * 0.5 - Vector3(0, 0.07, 0)
		k.box(timber, Vector3(hw * 2.0, 0.1, eave.distance_to(peak)), mid, Vector3(sz * pitch, 0, 0))
	k.box(_paint(roof.darkened(0.35)), Vector3(hw * 2.0 + 0.1, 0.16, 0.3), Vector3(0, ridge + 0.14, 0))

	# chimney through the roof
	var cx := (w * 0.28) * (1.0 if rng.randf() < 0.5 else -1.0)
	k.box(stone, Vector3(0.7, ridge - top + 0.9, 0.7), Vector3(cx, top + (ridge - top + 0.9) * 0.5, -d * 0.18))
	k.box(stone, Vector3(0.9, 0.14, 0.9), Vector3(cx, ridge + 0.95, -d * 0.18))

	# door (front), windows with shutters on the front and the back
	var front := d * 0.5
	k.box(timber, Vector3(1.3, 2.25, 0.16), Vector3(0, PLINTH + 1.12, front + 0.02))
	k.box(_paint(Color("4a2f20")), Vector3(1.02, 2.0, 0.1), Vector3(0, PLINTH + 1.0, front + 0.08))
	for i in 3:
		k.box(timber, Vector3(1.02, 0.05, 0.02), Vector3(0, PLINTH + 0.45 + i * 0.6, front + 0.135))
	k.box(Proc.mat(Proc.BRASS), Vector3(0.07, 0.07, 0.07), Vector3(0.36, PLINTH + 1.0, front + 0.16))
	var per_side := 1 if w < 5.6 else 2
	for s in storeys:
		var y := PLINTH + STOREY * s + 1.5
		var xs: Array[float] = []
		for i in per_side:
			var off := 1.55 + i * 1.25
			if off + 0.8 < w * 0.5:
				xs.append(off)
				xs.append(-off)
		if s == 1:
			xs.append(0.0)
		for x in xs:
			_window(k, timber, shutter, Vector3(x, y, front), 1.0)
			_window(k, timber, shutter, Vector3(x, y, -front), -1.0)
	var body := k.commit("Walls")
	hs.add_child(body)

	# steps to the door: a separate mesh, with its own colliders
	var sk := Kit.new()
	var low := Vector3(1.9, PLINTH * 0.5 + FOUNDATION, 1.0)
	sk.box(stone, low, Vector3(0, PLINTH * 0.5 - low.y * 0.5, front + 0.5))
	sk.box(stone, Vector3(1.6, PLINTH * 0.5, 0.55), Vector3(0, PLINTH * 0.75, front + 0.275))
	hs.add_child(sk.commit("Steps"))
	Solid.box(hs, low, Vector3(0, PLINTH * 0.5 - low.y * 0.5, front + 0.5))
	Solid.box(hs, Vector3(1.6, PLINTH * 0.5, 0.55), Vector3(0, PLINTH * 0.75, front + 0.275))
	# walls and plinth
	Solid.box(hs, Vector3(w + 0.3, PLINTH + FOUNDATION, d + 0.3), Vector3(0, (PLINTH - FOUNDATION) * 0.5, 0))
	Solid.box(hs, Vector3(w + 0.06, h, d + 0.06), Vector3(0, PLINTH + h * 0.5, 0))

	if with_sign:
		hs.add_child(_sign(rng, timber, Vector3(w * 0.5 - 0.3, PLINTH + 2.55, front)))
	var lantern := Assets.model("street_lamp_02")  # a bracket lantern by the door
	if lantern != null:
		lantern.position = Vector3(-1.05, PLINTH + 1.75, front + 0.04)
		lantern.scale = Vector3.ONE * 0.8
		hs.add_child(lantern)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(-1.05, PLINTH + 2.2, front + 0.7)
	lamp.light_color = Color("ffc37a")
	lamp.light_energy = 0.5
	lamp.omni_range = 4.5
	lamp.distance_fade_enabled = true
	lamp.distance_fade_begin = 30.0
	lamp.distance_fade_length = 10.0
	hs.add_child(lamp)
	Decals.grime_house(hs, w + 0.3, d + 0.3)
	hs.set_meta("size", Vector3(w + 0.3, top, d + 0.3))
	return hs


static func _window(k: Kit, timber: Material, shutter: Material, at: Vector3, face: float) -> void:
	var z := at.z + face * 0.03
	var ww := 0.8
	var wh := 1.05
	if _glass == null:
		_glass = StandardMaterial3D.new()
		_glass.albedo_color = Color("ffd89a")
		_glass.emission_enabled = true
		_glass.emission = Color("ffc56e")
		_glass.emission_energy_multiplier = 1.1
		_glass.roughness = 0.2
	k.box(_glass, Vector3(ww, wh, 0.06), Vector3(at.x, at.y, z))
	for sx: float in [-1.0, 1.0]:  # frame, mullions
		k.box(timber, Vector3(0.09, wh + 0.18, 0.12), Vector3(at.x + sx * (ww * 0.5 + 0.045), at.y, z + face * 0.02))
	for sy: float in [-1.0, 1.0]:
		k.box(timber, Vector3(ww + 0.18, 0.09, 0.12), Vector3(at.x, at.y + sy * (wh * 0.5 + 0.045), z + face * 0.02))
	k.box(timber, Vector3(0.05, wh, 0.09), Vector3(at.x, at.y, z + face * 0.02))
	k.box(timber, Vector3(ww, 0.05, 0.09), Vector3(at.x, at.y + 0.1, z + face * 0.02))
	k.box(timber, Vector3(ww + 0.4, 0.07, 0.24), Vector3(at.x, at.y - wh * 0.5 - 0.12, z + face * 0.08))  # sill
	for sx: float in [-1.0, 1.0]:  # shutters, folded open against the wall, with two battens
		var x := at.x + sx * (ww * 0.5 + 0.09 + 0.21)
		k.box(shutter, Vector3(0.42, wh + 0.1, 0.05), Vector3(x, at.y, z + face * 0.04))
		for sy: float in [-0.32, 0.32]:
			k.box(timber, Vector3(0.42, 0.06, 0.02), Vector3(x, at.y + sy, z + face * 0.075))


## A signboard on an iron bracket: a painted board with a brass emblem (no words — the world has no literals).
static func _sign(rng: RandomNumberGenerator, timber: Material, at: Vector3) -> Node3D:
	var k := Kit.new()
	var iron := _paint(Color("2a2a2e"))
	k.box(iron, Vector3(0.06, 0.06, 1.1), Vector3(0, 0.35, 0.55))
	k.box(iron, Vector3(0.04, 0.04, 0.75), Vector3(0, 0.1, 0.32), Vector3(0.75, 0, 0))
	for z: float in [0.45, 0.95]:
		k.box(iron, Vector3(0.025, 0.2, 0.025), Vector3(0, 0.23, z))
	k.box(timber, Vector3(0.07, 0.62, 0.8), Vector3(0, -0.18, 0.7))
	k.box(_paint(SHUTTERS[rng.randi() % SHUTTERS.size()].lightened(0.15)), Vector3(0.09, 0.5, 0.68), Vector3(0, -0.18, 0.7))
	var emblem := SphereMesh.new()
	emblem.radius = 0.14
	emblem.height = 0.28
	emblem.radial_segments = 12
	emblem.rings = 6
	k.mesh(Proc.mat(Proc.BRASS), emblem, Transform3D(Basis().scaled(Vector3(0.5, 1, 1)), Vector3(0, -0.18, 0.7)))
	var mi := k.commit("Sign")
	mi.position = at
	return mi


static func _plaster(dark: float) -> Material:
	return Proc.mat(Proc.PLASTER.darkened(snappedf(dark, 0.02)))


static func _stone() -> Material:
	return Assets.pbr("cobblestone_floor_04", Color("b9b0a0"), 0.5) if Assets.available() else Proc.mat(Proc.ROCK_DARK)


static func _paint(c: Color) -> Material:
	var key := c.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.8
		if Assets.available():  # painted wood: the grain of the planks shows through
			m.normal_enabled = true
			m.normal_texture = Assets.tex("weathered_planks", "nor_gl")
			m.uv1_triplanar = true
			m.uv1_world_triplanar = true
			m.uv1_scale = Vector3.ONE * 0.8
		_mats[key] = m
	return _mats[key]


## Clay tiles laid by UV (rows run along the ridge), tinted by the roof colour.
static func _tiles(roof: Color) -> Material:
	var key := "tiles/" + roof.to_html()
	if _mats.has(key):
		return _mats[key]
	var m := ORMMaterial3D.new()
	m.albedo_color = roof
	m.roughness = 0.9
	if Assets.available():
		m.albedo_color = Color.WHITE.lerp(roof, 0.55).lightened(0.15)
		m.albedo_texture = Assets.tex("clay_roof_tiles_02", "diff")
		m.normal_enabled = true
		m.normal_texture = Assets.tex("clay_roof_tiles_02", "nor_gl")
		m.normal_scale = 1.4
		m.orm_texture = Assets.tex("clay_roof_tiles_02", "arm")
		m.roughness = 1.0
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[key] = m
	return m

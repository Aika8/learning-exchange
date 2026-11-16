## Pattern: Builder — the interior of the Exchange hall inside the mill: plank floor with a carpet and the brokers'
## rostrum, panelled wall with pillars, a gallery with a balustrade and guild banners, the beams and the great gear,
## desks, lanterns, framed windows and the door. Split from the hall scene so the world audit and the tests can
## build it without the trading HUD. Everything you could bump into has a collider.
class_name HallRoom
extends RefCounted

const RADIUS := 13.0
const GALLERY_Y := 5.4


static func build(root: Node3D) -> void:
	var hd := Assets.available()
	var floor_mesh := Proc._cyl_mesh(14.0, 14.0, 0.4, 48)
	var floor_node := Proc.mesh_node(floor_mesh, Assets.pbr("old_wooden_floor_02", Color.WHITE, 0.4) if hd else Proc.mat(Color("6b4a33")), Vector3(0, -0.2, 0))
	floor_node.name = "Floor"
	floor_node.set_meta("flat", true)
	root.add_child(floor_node)
	var slab := CylinderShape3D.new()
	slab.radius = 14.0
	slab.height = 0.4
	Solid._shape(Solid._body(root, Vector3(0, -0.2, 0), 0.0), slab)
	for i in (0 if hd else 12):  # floor planks ring (fallback look)
		var a := TAU * i / 12.0
		var plank := Proc.box(Vector3(0.12, 0.02, 13.0), Color("4e3424"), Vector3(sin(a) * 6.5, 0.01, cos(a) * 6.5))
		plank.rotation.y = a
		plank.set_meta("flat", true)
		root.add_child(plank)
	var wall := Proc._cyl_mesh(13.0, 14.0, 16.0, 48)
	wall.cap_top = false
	wall.cap_bottom = false
	var wall_mat := (Assets.pbr("plastered_wall_02", Color("e8d6b8"), 0.35) if hd else Proc.mat(Color("d8c4a2"))).duplicate() as BaseMaterial3D
	wall_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	var wall_node := Proc.mesh_node(wall, wall_mat, Vector3(0, 8.0, 0))
	wall_node.name = "Wall"
	wall_node.set_meta("flat", true)
	root.add_child(wall_node)
	Solid.trimesh(root, wall, Vector3(0, 8.0, 0))
	var ceiling := Proc.cyl(13.0, 13.0, 0.4, 24, Color("5e3b28"), Vector3(0, 16.2, 0))
	ceiling.set_meta("flat", true)
	root.add_child(ceiling)

	var k := Kit.new()
	var dark := Proc.mat(Proc.TIMBER_DARK)
	var wood := Proc.mat(Proc.TIMBER)
	var brass := Proc.mat(Proc.BRASS)
	var marble := Assets.pbr("marble_01", Color.WHITE, 0.6) if hd else dark
	# wainscot: dark panels to shoulder height with a rail on top, a plinth below
	var panel_mat := dark.duplicate() as BaseMaterial3D
	panel_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	var panel := Proc._cyl_mesh(13.76, 13.88, 1.9, 48)
	panel.cap_top = false
	panel.cap_bottom = false
	k.mesh(panel_mat, panel, Transform3D(Basis(), Vector3(0, 0.95, 0)))
	for i in 48:
		var a := TAU * (i + 0.5) / 48.0
		k.box(dark, Vector3(0.12, 1.9, 0.1), Vector3(sin(a) * 13.74, 0.95, cos(a) * 13.74), Vector3(0, a, 0))
		k.box(wood, Vector3(1.86, 0.1, 0.16), Vector3(sin(a) * 13.7, 1.93, cos(a) * 13.7), Vector3(0, a, 0))
		k.box(wood, Vector3(1.86, 0.22, 0.12), Vector3(sin(a) * 13.8, 0.11, cos(a) * 13.8), Vector3(0, a, 0))
	# pillars with bases and capitals, beams meeting at a boss under the gear
	var shaft := Proc._cyl_mesh(0.36, 0.42, 16.0, 16)
	var drum := Proc._cyl_mesh(0.56, 0.6, 0.5, 16)
	for i in 12:
		var a := TAU * i / 12.0
		var p := Vector3(sin(a) * 12.6, 0, cos(a) * 12.6)
		k.mesh(marble, shaft, Transform3D(Basis(), p + Vector3(0, 8.0, 0)))
		k.mesh(marble, drum, Transform3D(Basis(), p + Vector3(0, 0.25, 0)))
		k.mesh(brass, drum, Transform3D(Basis().scaled(Vector3(0.9, 0.5, 0.9)), p + Vector3(0, 15.2, 0)))
		Solid.post(root, 0.58, 6.0, p)
		k.box(dark, Vector3(0.4, 0.5, 11.2), Vector3(sin(a) * 7.0, 15.6, cos(a) * 7.0), Vector3(0, a, 0))
	k.mesh(dark, Proc._cyl_mesh(1.5, 1.5, 0.7, 16), Transform3D(Basis(), Vector3(0, 15.6, 0)))
	k.mesh(brass, Proc._cyl_mesh(0.5, 0.9, 0.5, 16), Transform3D(Basis(), Vector3(0, 15.05, 0)))
	_gallery(k, dark, wood, brass)
	_rostrum(root, k, wood, dark, brass)
	_door(k, dark, wood, brass)
	# windows with frames, glowing with the light outside
	var glow := Proc.mat(Color("ffe6b8"), 3.0)
	for i in 3:
		var a := PI + (i - 1) * 0.6
		var at := Vector3(sin(a) * 13.2, 10.0, cos(a) * 13.2)
		var rot := Vector3(0, a, 0)
		k.box(glow, Vector3(1.4, 2.6, 0.2), at, rot)
		k.box(dark, Vector3(1.7, 0.14, 0.34), at + Vector3(0, 1.37, 0), rot)
		k.box(dark, Vector3(1.9, 0.14, 0.5), at + Vector3(0, -1.37, 0), rot)
		k.box(dark, Vector3(0.07, 2.6, 0.26), at, rot)
		for y: float in [-0.45, 0.45]:
			k.box(dark, Vector3(1.4, 0.07, 0.26), at + Vector3(0, y, 0), rot)
		for sx: float in [-1.0, 1.0]:
			k.box(dark, Vector3(0.14, 2.88, 0.34), at + Vector3(cos(a), 0, -sin(a)) * sx * 0.77, rot)
	var deco := k.commit("Interior")
	deco.set_meta("flat", true)
	root.add_child(deco)

	# the central gear of the mill: turns slowly over the trading floor
	var gear := Node3D.new()
	gear.name = "Gear"
	gear.set_meta("hung", true)
	gear.position = Vector3(0, 13.5, -2)
	gear.add_child(Proc.cyl(2.4, 2.4, 0.5, 24, Proc.BRASS))
	gear.add_child(Proc.cyl(0.3, 0.3, 3.4, 12, Proc.TIMBER_DARK, Vector3(0, 1.4, 0)))
	for i in 12:
		var t := Proc.box(Vector3(0.5, 0.5, 0.6), Proc.BRASS.darkened(0.2), Vector3(sin(TAU * i / 12.0) * 2.6, 0, cos(TAU * i / 12.0) * 2.6))
		t.rotation.y = TAU * i / 12.0
		gear.add_child(t)
	for i in 3:  # spokes of different depth, so their tops do not flicker where they cross
		var spoke := Proc.box(Vector3(0.16, 0.52 + i * 0.03, 4.6), Proc.TIMBER_DARK)
		spoke.rotation.y = TAU * i / 6.0
		gear.add_child(spoke)
	root.add_child(gear)
	# trading desks and figures of the Money-changers' guild (market makers stand on both sides of the spread)
	for side: float in [-1.0, 1.0]:
		for i in 2:
			var dpos := Vector3(side * (4.9 + i * 3.5), 0, -3.0 + i * 2.5)
			if Assets.put(root, "WoodenTable_01", dpos, side * 0.4, 1.4) == null:
				var desk := Proc.box(Vector3(3.0, 1.0, 1.2), Proc.TIMBER, dpos + Vector3(0, 0.5, 0))
				desk.rotation.y = side * 0.4
				root.add_child(desk)
				desk.set_meta("solid", Solid.box(root, Vector3(3.0, 1.0, 1.2), dpos + Vector3(0, 0.5, 0), side * 0.4))
			else:
				Assets.put(root, "book_encyclopedia_set_01", dpos + Vector3(0.3, 0.77, 0), 0.3)
				Assets.put(root, "seadogs_compass", dpos + Vector3(-0.4, 0.77, 0.1), 1.0, 2.0)
			var f := Proc.figure(Hud.BID.darkened(0.3) if side < 0 else Hud.ASK.darkened(0.3), Color("2a3550"),
				"sailor" if (i + int(side > 0)) % 2 == 0 else "trader")
			f.name = "Broker"
			f.position = Vector3(side * (4.9 + i * 3.5), 0, -4.3 + i * 2.5)
			root.add_child(f)
			f.set_meta("solid", Solid.person(root, f.position))
	# warm lanterns on chains
	for i in 6:
		var a := TAU * (i + 0.5) / 6.0
		var pos := Vector3(sin(a) * 9.6, 9.0, cos(a) * 9.6)
		var chain := Proc.cyl(0.03, 0.03, 6.2, 6, Proc.TIMBER_DARK, pos + Vector3(0, 3.9, 0))
		chain.set_meta("hung", true)
		root.add_child(chain)
		var lamp := Assets.put(root, "lantern_chandelier_01", pos + Vector3(0, 0.2, 0), a, 1.6)
		if lamp == null:
			lamp = Proc.ball(0.35, Color("ffcf6e"), pos, 5.0)
			root.add_child(lamp)
		lamp.set_meta("hung", true)
		var l := OmniLight3D.new()
		l.position = pos
		l.light_color = Color("ffbe6e")
		l.light_energy = 2.2
		l.omni_range = 12.0
		l.light_volumetric_fog_energy = 1.0
		root.add_child(l)
	for at: Vector3 in [Vector3(-5, 3.2, 1.5), Vector3(5, 3.2, 1.5), Vector3(0, 3.4, 8.5)]:  # the floor, the carpet and the rostrum are lit too
		var fill := OmniLight3D.new()
		fill.position = at
		fill.light_color = Color("ffd9a8")
		fill.light_energy = 1.1
		fill.omni_range = 9.5
		fill.light_specular = 0.2
		root.add_child(fill)
	var board_light := SpotLight3D.new()
	board_light.position = Vector3(0, 12, -1)
	board_light.rotation_degrees = Vector3(-50, 0, 0)
	board_light.light_color = Color("ffe1b0")
	board_light.light_energy = 3.0
	board_light.spot_range = 20.0
	board_light.spot_angle = 30.0
	board_light.shadow_enabled = true
	root.add_child(board_light)
	_furnish(root)


## The gallery: a ring of planks on brackets at the pillars, a balustrade, guild banners hanging under it.
static func _gallery(k: Kit, dark: Material, wood: Material, brass: Material) -> void:
	var cloth: Array[Material] = [Houses._paint(Hud.BID.darkened(0.25)), Houses._paint(Hud.ASK.darkened(0.25)), Houses._paint(Color("8a6a2a"))]
	if Assets.available():
		cloth = [Assets.pbr("quatrefoil_jacquard_fabric", Hud.BID.darkened(0.1), 1.5), Assets.pbr("quatrefoil_jacquard_fabric", Hud.ASK.darkened(0.1), 1.5),
			Assets.pbr("quatrefoil_jacquard_fabric", Hud.BRASS, 1.5)]
	for i in 24:
		var a := TAU * (i + 0.5) / 24.0
		var out := Vector3(sin(a), 0, cos(a))
		var rot := Vector3(0, a, 0)
		k.box(wood, Vector3(3.5, 0.16, 1.9), out * 12.5 + Vector3(0, GALLERY_Y, 0), rot)
		k.box(dark, Vector3(3.2, 0.3, 0.2), out * 11.62 + Vector3(0, GALLERY_Y - 0.16, 0), rot)
		k.box(dark, Vector3(3.06, 0.1, 0.14), out * 11.62 + Vector3(0, GALLERY_Y + 1.05, 0), rot)
		for j in 5:
			var along := Vector3(cos(a), 0, -sin(a)) * (j - 2) * 0.62
			k.box(brass if j == 2 else dark, Vector3(0.07, 0.95, 0.07), out * 11.62 + along + Vector3(0, GALLERY_Y + 0.55, 0), rot)
		if i % 2 == 0 and absf(angle_difference(a, PI)) > 0.6 and absf(angle_difference(a, 0.0)) > 0.5:  # banners, but not over the board or the door
			k.box(cloth[(i / 2) % 3], Vector3(1.5, 2.6, 0.05), out * 11.5 + Vector3(0, GALLERY_Y - 1.75, 0), rot)
			k.box(brass, Vector3(1.7, 0.07, 0.07), out * 11.5 + Vector3(0, GALLERY_Y - 0.42, 0), rot)
	for i in 12:  # brackets
		var a := TAU * i / 12.0
		k.box(dark, Vector3(0.22, 0.22, 1.7), Vector3(sin(a), 0, cos(a)) * 11.9 + Vector3(0, GALLERY_Y - 0.75, 0), Vector3(0.75, a, 0))


## The brokers' rostrum in front of the board: a low two-step platform with a brass rail, and the long carpet to it.
static func _rostrum(root: Node3D, k: Kit, wood: Material, dark: Material, brass: Material) -> void:
	var centre := Vector3(0, 0, -5.2)
	k.mesh(dark, Proc._cyl_mesh(3.6, 3.6, 0.18, 8), Transform3D(Basis(), centre + Vector3(0, 0.09, 0)))
	k.mesh(wood, Proc._cyl_mesh(3.0, 3.0, 0.18, 8), Transform3D(Basis(), centre + Vector3(0, 0.27, 0)))
	for step: Array in [[3.6, 0.18, 0.09], [3.0, 0.18, 0.27]]:
		var s := CylinderShape3D.new()
		s.radius = float(step[0]) * 0.96
		s.height = step[1]
		Solid._shape(Solid._body(root, centre + Vector3(0, step[2], 0), 0.0), s)
	for i in 8:  # rail on the board side only: the floor side is open
		var a := PI + (i - 3.5) * 0.3
		var p := centre + Vector3(sin(a), 0, cos(a)) * 2.8
		k.box(brass, Vector3(0.06, 1.0, 0.06), p + Vector3(0, 0.86, 0))
		if i < 7:
			var b := PI + (i - 3.0) * 0.3
			k.box(brass, Vector3(0.88, 0.06, 0.06), centre + Vector3(sin(b), 0, cos(b)) * 2.76 + Vector3(0, 1.36, 0), Vector3(0, b, 0))
		Solid.post(root, 0.08, 1.4, p + Vector3(0, 0.36, 0))
	var carpet := Assets.pbr("quatrefoil_jacquard_fabric", Color("9a3a34"), 1.2) if Assets.available() else Houses._paint(Color("8a3b32"))
	k.box(carpet, Vector3(2.6, 0.03, 13.4), Vector3(0, 0.015, 5.2))
	k.box(brass, Vector3(2.8, 0.02, 0.12), Vector3(0, 0.01, -1.5))


## The way out, opposite the board: a double door in an arch with a lantern over it.
static func _door(k: Kit, dark: Material, wood: Material, brass: Material) -> void:
	var z := 13.6
	k.box(dark, Vector3(3.6, 4.4, 0.3), Vector3(0, 2.2, z))
	for sx: float in [-1.0, 1.0]:
		k.box(wood, Vector3(1.5, 3.8, 0.12), Vector3(sx * 0.78, 1.9, z - 0.16))
		k.box(brass, Vector3(0.08, 0.3, 0.08), Vector3(sx * 0.16, 1.9, z - 0.26))
		for y: float in [0.6, 1.9, 3.2]:
			k.box(dark, Vector3(1.5, 0.12, 0.04), Vector3(sx * 0.78, y, z - 0.23))
	k.box(brass, Vector3(3.9, 0.3, 0.5), Vector3(0, 4.5, z - 0.05))


## Real props from Poly Haven along the wall (ADR-0019); skipped without `make assets`.
static func _furnish(root: Node3D) -> void:
	if not Assets.available():
		return
	Assets.put(root, "vintage_grandfather_clock_01", Vector3(-9.3, 0, -8.3), 0.85, 1.3)
	for i in 4:
		var a := PI * 0.62 + i * 0.22
		Assets.put(root, "wooden_display_shelves_01", Vector3(sin(a) * 12.1, 0, cos(a) * 12.1), a - PI / 2, 1.4)
		var b := -PI * 0.62 - i * 0.22
		Assets.put(root, "wooden_display_shelves_01", Vector3(sin(b) * 12.1, 0, cos(b) * 12.1), b - PI / 2, 1.4)
	for p: Vector3 in [Vector3(9.5, 0, 6), Vector3(10.2, 0, 4.6), Vector3(-10, 0, 5.5)]:
		Assets.put(root, "wine_barrel_01", p, p.x, 1.1)
	Assets.put(root, "wooden_crate_02", Vector3(-8.8, 0, 7.2), 0.5, 1.2)
	Assets.put(root, "treasure_chest", Vector3(8.4, 0, -7.6), -0.9, 1.1)
	for side: float in [-1.0, 1.0]:
		for i in 2:
			Assets.put(root, "WoodenChair_01", Vector3(side * (4.9 + i * 3.5) + side * 0.4, 0, -1.9 + i * 2.5), PI + side * 0.4, 0.45)

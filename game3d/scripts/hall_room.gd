## Pattern: Builder — the interior of the Exchange hall (floor, wall, pillars, the mill gear, desks, lanterns),
## split from the hall scene so the world audit and the tests can build it without the trading HUD.
class_name HallRoom
extends RefCounted

const RADIUS := 13.0


static func build(root: Node3D) -> void:
	var floor_mesh := CylinderMesh.new()
	floor_mesh.top_radius = 14.0
	floor_mesh.bottom_radius = 14.0
	floor_mesh.height = 0.4
	floor_mesh.radial_segments = 24
	root.add_child(Proc.mesh_node(floor_mesh, Assets.pbr("old_wooden_floor_02", Color.WHITE, 0.4) if Assets.available() else Proc.mat(Color("6b4a33")), Vector3(0, -0.2, 0)))
	for i in (0 if Assets.available() else 12):  # floor planks ring (fallback look)
		var a := TAU * i / 12.0
		var plank := Proc.box(Vector3(0.12, 0.02, 13.0), Color("4e3424"), Vector3(sin(a) * 6.5, 0.01, cos(a) * 6.5))
		plank.rotation.y = a
		root.add_child(plank)
	var wall := CylinderMesh.new()
	wall.top_radius = 13.0
	wall.bottom_radius = 14.0
	wall.height = 16.0
	wall.radial_segments = 24
	wall.cap_top = false
	wall.cap_bottom = false
	var wall_mat := (Assets.pbr("plastered_wall_02", Color("e8d6b8"), 0.35) if Assets.available() else Proc.mat(Color("d8c4a2"))).duplicate() as BaseMaterial3D
	wall_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	root.add_child(Proc.mesh_node(wall, wall_mat, Vector3(0, 8.0, 0)))
	var ceiling := Proc.cyl(13.0, 13.0, 0.4, 24, Color("5e3b28"), Vector3(0, 16.0, 0))
	root.add_child(ceiling)
	for i in 12:  # beams and pillars
		var a := TAU * i / 12.0
		var p := Vector3(sin(a) * 12.6, 8.0, cos(a) * 12.6)
		var pillar := Proc.cyl(0.38, 0.45, 16.0, 16, Proc.TIMBER_DARK, p)
		if Assets.available():
			pillar.material_override = Assets.pbr("marble_01", Color.WHITE, 0.6)
		root.add_child(pillar)
		var beam := Proc.box(Vector3(0.4, 0.5, 12.6), Proc.TIMBER_DARK, Vector3(sin(a) * 6.3, 15.6, cos(a) * 6.3))
		beam.rotation.y = a
		root.add_child(beam)
	# the central gear of the mill: turns slowly over the trading floor
	var gear := Node3D.new()
	gear.name = "Gear"
	gear.position = Vector3(0, 13.5, -2)
	gear.add_child(Proc.cyl(2.4, 2.4, 0.5, 16, Proc.BRASS))
	for k in 12:
		var t := Proc.box(Vector3(0.5, 0.5, 0.6), Proc.BRASS.darkened(0.2), Vector3(sin(TAU * k / 12.0) * 2.6, 0, cos(TAU * k / 12.0) * 2.6))
		t.rotation.y = TAU * k / 12.0
		gear.add_child(t)
	root.add_child(gear)
	# trading desks and figures of the Money-changers' guild (market makers stand on both sides of the spread)
	for side in [-1.0, 1.0]:
		for k in 2:
			var dpos := Vector3(side * (4.5 + k * 3.5), 0, -3.0 + k * 2.5)
			var desk := Assets.put(root, "WoodenTable_01", dpos, side * 0.4, 1.4)
			if desk == null:
				desk = Proc.box(Vector3(3.0, 1.0, 1.2), Proc.TIMBER, dpos + Vector3(0, 0.5, 0))
				desk.rotation.y = side * 0.4
				root.add_child(desk)
			else:
				Assets.put(root, "book_encyclopedia_set_01", dpos + Vector3(0.3, 0.77, 0), 0.3)
				Assets.put(root, "seadogs_compass", dpos + Vector3(-0.4, 0.77, 0.1), 1.0, 2.0)
			var f := Proc.figure(Hud.BID.darkened(0.3) if side < 0 else Hud.ASK.darkened(0.3), Color("2a3550"),
				"sailor" if (k + int(side > 0)) % 2 == 0 else "trader")
			f.position = Vector3(side * (4.5 + k * 3.5), 0, -4.2 + k * 2.5)
			root.add_child(f)
	# warm lanterns
	for i in 6:
		var a := TAU * (i + 0.5) / 6.0
		var pos := Vector3(sin(a) * 10.5, 9.0, cos(a) * 10.5)
		if Assets.put(root, "lantern_chandelier_01", pos + Vector3(0, 0.2, 0), a, 1.6) == null:
			root.add_child(Proc.ball(0.35, Color("ffcf6e"), pos, 5.0))
		var l := OmniLight3D.new()
		l.position = pos
		l.light_color = Color("ffbe6e")
		l.light_energy = 2.2
		l.omni_range = 12.0
		l.light_volumetric_fog_energy = 1.0
		root.add_child(l)
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
	# windows with outside light shafts
	for i in 3:
		var a := PI + (i - 1) * 0.6
		var w := Proc.box(Vector3(1.4, 2.6, 0.2), Color("ffe6b8"), Vector3(sin(a + PI) * -13.2, 10.0, cos(a + PI) * -13.2))
		w.material_override = Proc.mat(Color("ffe6b8"), 3.0)
		w.rotation.y = a
		root.add_child(w)


## Real props from Poly Haven along the wall (ADR-0019); skipped without `make assets`.
static func _furnish(root: Node3D) -> void:
	if not Assets.available():
		return
	Assets.put(root, "vintage_grandfather_clock_01", Vector3(-9.5, 0, -8.5), 0.85, 1.3)
	for i in 4:
		var a := PI * 0.62 + i * 0.22
		Assets.put(root, "wooden_display_shelves_01", Vector3(sin(a) * 12.3, 0, cos(a) * 12.3), a - PI / 2, 1.4)
		var b := -PI * 0.62 - i * 0.22
		Assets.put(root, "wooden_display_shelves_01", Vector3(sin(b) * 12.3, 0, cos(b) * 12.3), b - PI / 2, 1.4)
	for p: Vector3 in [Vector3(9.5, 0, 6), Vector3(10.2, 0, 4.6), Vector3(-10, 0, 5.5)]:
		Assets.put(root, "wine_barrel_01", p, p.x, 1.1)
	Assets.put(root, "wooden_crate_02", Vector3(-8.8, 0, 7.2), 0.5, 1.2)
	Assets.put(root, "treasure_chest", Vector3(8.4, 0, -7.6), -0.9, 1.1)
	for side in [-1.0, 1.0]:
		for k in 2:
			Assets.put(root, "WoodenChair_01", Vector3(side * (4.5 + k * 3.5) + side * 0.4, 0, -1.9 + k * 2.5), PI + side * 0.4, 0.45)

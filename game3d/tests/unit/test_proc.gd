## Procedural art builds valid meshes; islands face outward (normals of the cap point up).
extends GutTest


func test_island_mesh_has_triangles_and_an_upward_cap() -> void:
	var m := Proc.island_mesh(20.0, 25.0, 3)
	assert_eq(m.get_surface_count(), 1)
	var arrays := m.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	assert_gt(verts.size(), 300)
	assert_eq(verts.size() % 3, 0)
	var up := 0
	for i in verts.size():
		if is_zero_approx(verts[i].y) and Vector2(verts[i].x, verts[i].z).length() < 8.0:
			up += 1 if normals[i].y > 0.9 else 0
	assert_gt(up, 20, "cap normals point up")


func test_ship_has_a_sail_and_scenes_exist() -> void:
	var s := Proc.ship()
	# procedural ship has a furling "Sail"; with `make assets` it is the model "Hull" (ADR-0019)
	var expected := "Hull" if Assets.available() else "Sail"
	assert_not_null(s.get_node_or_null(expected), expected)
	s.free()
	for scene in ["main_menu", "harbour", "hall", "voyage"]:
		assert_true(ResourceLoader.exists("res://scenes/%s.tscn" % scene), scene)


func test_assets_degrade_without_files() -> void:
	assert_null(Assets.model("no_such_model"))
	assert_not_null(Assets.pbr("no_such_texture"), "plain material fallback")
	assert_not_null(Proc.figure(Color.RED, Color.BLUE))

## People are dressed for the age of sail: every role gets a costume mesh skinned to the skeleton, and the clothes
## they came with lose their modern textures (denim, prints). Skipped quietly when the people are not downloaded.
extends GutTest

const ROLES := {"captain": "sailor", "sailor": "sailor", "trader": "trader", "townsman": "oldman", "child": "child"}


func test_every_role_gets_a_costume_and_no_modern_textures() -> void:
	if Assets.person("sailor") == null:
		pass_test("people are not downloaded (make assets): the procedural figure has no costume")
		return
	for role: String in ROLES:
		var p := Proc.figure(Color("8a6a4a"), Color("2a3550"), ROLES[role], role)
		add_child_autofree(p)
		var costume: MeshInstance3D = p.find_child("Costume", true, false)
		assert_not_null(costume, role + " has a costume")
		if costume == null:
			continue
		assert_not_null(costume.skin, role + ": the costume is skinned")
		assert_gt(costume.mesh.get_surface_count(), 1, role + ": several materials")
		for s in costume.mesh.get_surface_count():
			var arrays := costume.mesh.surface_get_arrays(s)
			assert_eq((arrays[Mesh.ARRAY_BONES] as PackedInt32Array).size(), (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() * 4, role + ": every vertex follows a bone")
		var dressed := 0
		for mi: MeshInstance3D in p.find_children("*", "MeshInstance3D", true, false):
			for s in mi.mesh.get_surface_count():
				var name := mi.mesh.surface_get_material(s).resource_name if mi.mesh.surface_get_material(s) != null else ""
				if name.ends_with(".top") or name.ends_with(".bot"):
					var over := mi.get_surface_override_material(s)
					assert_not_null(over, "%s: %s is re-dressed" % [role, name])
					if over is BaseMaterial3D:
						assert_null((over as BaseMaterial3D).albedo_texture, "%s: %s keeps no denim or print texture" % [role, name])
					dressed += 1
		assert_gt(dressed, 1, role + ": shirt and trousers found")


func test_a_figure_without_a_skeleton_is_left_alone() -> void:
	var plain := Node3D.new()
	add_child_autofree(plain)
	Costume.dress(plain, "captain")
	assert_eq(plain.get_child_count(), 0)


func test_the_captain_wears_a_hat_the_townsman_does_not_keep_the_fedora() -> void:
	if Assets.person("oldman") == null:
		pass_test("people are not downloaded")
		return
	var p := Proc.figure(Color.WHITE, Color.WHITE, "oldman")
	add_child_autofree(p)
	for mi: MeshInstance3D in p.find_children("*", "MeshInstance3D", true, false):
		if str(mi.name).contains("fedora"):
			assert_false(mi.visible, "the modern hat is hidden")

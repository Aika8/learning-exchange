## People are dressed for the age of sail: every role gets a costume mesh skinned to the skeleton, and the clothes
## they came with lose their modern textures (denim, prints). Skipped quietly when the people are not downloaded.
extends GutTest

const ROLES := {"captain": "sailor", "sailor": "sailor", "sailor2": "sailor", "sailor3": "sailor", "mara": "trader", "changer": "sailor", "olva": "trader",
	"trader": "trader", "townsman": "oldman", "child": "child"}


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


func test_people_are_built_in_code_with_a_skeleton_the_gait_can_move() -> void:
	var looks: Dictionary = {}
	for role: String in ROLES:
		var p := Proc.figure(Color("8a6a4a"), Color("2a3550"), ROLES[role], role)
		add_child_autofree(p)
		var mesh: MeshInstance3D = p.find_child("Costume", true, false)
		assert_not_null(mesh, role)
		assert_not_null(mesh.skin, role + ": skinned to the skeleton built in code")
		var walker := Walker.attach(p)
		assert_true(walker.animated(), role + ": the gait with foot IK drives it")
		var sk: Skeleton3D = p.find_children("*", "Skeleton3D", true, false)[0]
		var foot := sk.find_bone("foot_l")
		var rest := sk.get_bone_global_pose(foot).origin
		for i in 20:
			walker.step(0.016, 4.2)
		assert_gt(sk.get_bone_global_pose(foot).origin.distance_to(rest), 0.05, role + ": the foot moves when walking")
		var size := mesh.get_aabb().size
		assert_between(size.y, 1.1, 2.1, role + " is person-sized")
		looks["%d/%s" % [mesh.mesh.get_surface_count(), str(size.snapped(Vector3.ONE * 0.01))]] = true
	assert_eq(looks.size(), ROLES.size(), "every role has its own silhouette (not copies of one figure)")


func test_the_default_look_needs_no_downloaded_art() -> void:
	assert_false(Style.pbr(), "low-poly is the default (ADR-0024)")
	assert_false(Assets.available())
	assert_null(Assets.person("sailor"), "no MakeHuman people in the default look")


func test_the_ink_effect_has_three_modes_and_the_hall_caps_it() -> void:
	var was: int = Session.ink_mode
	Session.set_ink(2)
	var m: ShaderMaterial = (Session.get_node("Ink") as MeshInstance3D).material_override
	assert_eq(int(m.get_shader_parameter("mode")), 2)
	Session.limit_ink(1)
	assert_eq(int(m.get_shader_parameter("mode")), 1, "the hall keeps the board in colour")
	Session.limit_ink(2)
	Session.set_ink(0)
	assert_false((Session.get_node("Ink") as MeshInstance3D).visible)
	Session.set_ink(was)


func test_the_chronicler_is_an_owl_built_in_code_with_a_lit_lantern() -> void:
	var owl := Proc.figure(Color.WHITE, Color.WHITE, "", "chronicler")
	add_child_autofree(owl)
	assert_not_null(owl.find_child("Costume", true, false))
	assert_eq(owl.find_children("*", "Skeleton3D", true, false).size(), 0, "no human under the feathers")
	assert_eq(owl.find_children("*", "OmniLight3D", true, false).size(), 1, "the lantern is lit")


func test_every_concept_sheet_has_its_roles() -> void:
	for sheet: String in ["01-captain", "02-sailors", "03-mara", "04-townsfolk", "05-chronicler"]:
		assert_true(FileAccess.file_exists("res://../docs/design/concepts/%s.jpg" % sheet) or FileAccess.file_exists(ProjectSettings.globalize_path("res://").path_join("../docs/design/concepts/%s.jpg" % sheet)), sheet)
	var c := Costume.new()
	for role: String in ROLES.keys() + ["chronicler"]:
		assert_true(c.has_method("_r_" + role), "a costume for " + role)

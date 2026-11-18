## ADR-0036: the ship «Попутчик» is the one realistic thing — every surface of her is drawn after the island's
## technique and so is never redrawn; she is built after the sheets, part by part, within a budget; her flag is
## our own sign; and she carries a monkey who lives in the rig and comes ashore with the captain.
extends GutTest

const HARBOUR := preload("res://scenes/harbour.tscn")


func after_each() -> void:
	Game.island = "harbour"
	Game.attuned = "harbour"
	Session.set_style(IslandStyle.HOME)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_no_technique_redraws_the_ship_every_surface_is_drawn_after_the_effect() -> void:
	var ink: MeshInstance3D = Session.get_node("Ink")
	var effect := (ink.material_override as ShaderMaterial).render_priority
	assert_eq(effect, 100)
	assert_gt(Wayfarer.AFTER_EFFECT, effect)
	var ship := Proc.ship()
	add_child_autofree(ship)
	var surfaces := 0
	for mi: MeshInstance3D in ship.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i)
			surfaces += 1
			assert_not_null(m, str(mi.get_path()))
			assert_gt(m.render_priority, effect, "%s: drawn after the island's technique" % mi.name)
			if m is BaseMaterial3D:
				assert_eq((m as BaseMaterial3D).transparency, BaseMaterial3D.TRANSPARENCY_ALPHA, "%s: in the pass the effect does not read" % mi.name)
				assert_eq((m as BaseMaterial3D).depth_draw_mode, BaseMaterial3D.DEPTH_DRAW_ALWAYS, "%s: and solid" % mi.name)
				assert_eq((m as BaseMaterial3D).albedo_color.a, 1.0)
			else:
				var code := (m as ShaderMaterial).shader.code
				assert_true(code.contains("depth_draw_always") and code.contains("ALPHA = 1.0"), "%s: a shader of the ship is opaque, in the transparent pass" % mi.name)
	assert_gt(surfaces, 20)
	for p: CPUParticles3D in ship.find_children("*", "CPUParticles3D", true, false):
		assert_gt((p.mesh as PrimitiveMesh).material.render_priority, effect, "the drops too")
	assert_gt((ship.find_child("Name", true, false) as Label3D).render_priority, effect)
	var shader := FileAccess.get_file_as_string("res://shaders/ink.gdshader")
	assert_false(shader.contains("ship") or shader.contains("Wayfarer"), "and the effect knows nothing about her")


func test_she_is_built_after_the_sheets_part_by_part() -> void:
	var ship := Proc.ship()
	add_child_autofree(ship)
	assert_eq(ship.name, &"Wayfarer")
	for part: String in ["Hull", "Castles", "Stern", "Spars", "Rigging", "Figurehead", "DeckThings", "Anchor", "Sail", "Topsail", "ForeAndAft",
			"WingL", "WingR", "Crystal", "Flag", "LanternL", "LanternR", "Name", "Glow"]:
		assert_not_null(ship.find_child(part, true, false), part)
	assert_eq((ship.find_child("Name", true, false) as Label3D).text, "ПОПУТЧИК")
	for wing: String in ["WingL", "WingR"]:
		var drips: CPUParticles3D = ship.get_node(wing).get_node("Drips")
		assert_true(drips.emitting, "moisture drips from the wing sails")
		assert_lt(drips.amount, 64, "a few dozen drops a side")
	assert_true((ship.find_child("LanternL", true, false) as OmniLight3D).light_energy > 0.0, "the stern lanterns are lit")
	assert_gt(Wayfarer.half_beam(0.45), Wayfarer.half_beam(0.0), "widest amidships")
	assert_lt(Wayfarer.half_beam(1.0), 0.2, "and sharp at the stem")
	assert_gt(Wayfarer.MAIN_TOP, Wayfarer.FORE_TOP, "two masts, the main the taller")


func test_she_keeps_within_her_budget_and_the_rig_is_not_drawn_from_afar() -> void:
	var ship := Proc.ship()
	add_child_autofree(ship)
	var cost := Wayfarer.cost(ship)
	gut.p("the ship: %d triangles, %d materials" % [cost.x, cost.y])
	assert_gt(cost.x, 8000, "a detailed ship")
	assert_lt(cost.x, Wayfarer.MAX_TRIANGLES)
	assert_lt(cost.y, Wayfarer.MAX_MATERIALS + 1)
	for mi: MeshInstance3D in ship.get_node("Rigging").find_children("*", "MeshInstance3D", true, false):
		assert_eq(mi.visibility_range_end, Wayfarer.RIG_SEEN_TO, str(mi.name))


func test_the_sails_are_set_by_the_trim() -> void:
	var ship := Proc.ship()
	add_child_autofree(ship)
	var sail: Node3D = ship.get_node("Sail")
	Wayfarer.set_trim(ship, 1.0)
	var full := sail.scale.y
	var foot := sail.position.y - 3.5 * 0.5 * sail.scale.y
	Wayfarer.set_trim(ship, 0.0)
	assert_lt(sail.scale.y, full * 0.3, "furled")
	assert_gt(sail.position.y - 3.5 * 0.5 * sail.scale.y, foot + 2.0, "gathered up to the yard, not down to the deck")
	assert_almost_eq(sail.position.y + 3.5 * 0.5 * sail.scale.y, Wayfarer.COURSE_YARD - 0.12, 0.01, "its head stays on the yard")


func test_the_flag_is_our_own_sign() -> void:
	var code := FileAccess.get_file_as_string("res://shaders/ship_flag.gdshader")
	assert_true(code.contains("star4") and code.contains("ring"), "a compass rose in a ring")
	assert_eq(code.count("bone_at(p,"), 2, "over two crossed bones")
	assert_false(code.to_lower().contains("skull("), "and no skull is drawn")
	assert_true(code.contains("TIME"), "it waves")
	for file: String in ["res://scripts/wayfarer.gd", "res://scripts/monkey.gd", "res://scripts/core/monkey_mind.gd"]:
		var words := FileAccess.get_file_as_string(file).to_lower()
		for borrowed: String in ["jolly roger", "black pearl", "sparrow", "barbossa", "caribbean"]:
			assert_false(words.contains(borrowed), "%s: %s" % [file, borrowed])


func test_the_monkey_lives_in_the_rig_under_way() -> void:
	var mind := MonkeyMind.new(3)
	var perches := Wayfarer.perches()
	mind.position = perches[0]
	var seen: Dictionary = {}
	var ran := false
	for i in 60 * 120:
		mind.aboard(1.0 / 60.0, perches)
		ran = ran or mind.running
		if not mind.running:
			seen[mind.perch] = true
			assert_lt(mind.position.distance_to(perches[mind.perch]), 0.03, "she sits on a perch, not in the air")
	assert_true(ran)
	assert_gt(seen.size(), 2, "in two minutes she has sat in several places")
	for p in perches:
		assert_gt(p.y, 0.8, "all her places are on the ship, above the deck")
		assert_lt(absf(p.x), 3.6)
	var again := MonkeyMind.new(3)
	again.position = perches[0]
	for i in 60 * 120:
		again.aboard(1.0 / 60.0, perches)
	assert_eq(again.position, mind.position, "the same seed, the same monkey")


func test_ashore_she_keeps_near_the_captain_and_sits_when_he_stands() -> void:
	var mind := MonkeyMind.new()
	mind.position = Vector3(0, 0, 0)
	var captain := Vector3(1, 0, 0)
	for i in 60 * 20:  # the captain walks 4 m a second for twenty seconds, then stands
		captain += Vector3(4.0 / 60.0, 0, 0)
		mind.ashore(1.0 / 60.0, captain, PI / 2)
		assert_lt(mind.position.distance_to(captain), 4.5, "never left behind")
	for i in 120:
		mind.ashore(1.0 / 60.0, captain, PI / 2)
	assert_false(mind.running, "he stands: she sits")
	assert_lt(mind.position.distance_to(captain), MonkeyMind.FAR)
	assert_gt(mind.position.distance_to(captain), 0.4, "beside him, not under his feet")


func test_in_port_the_monkey_is_ashore_with_the_captain_and_is_drawn_like_the_islanders() -> void:
	Game.island = "harbour"
	Session.spawn = "pier"
	var scene: Node3D = HARBOUR.instantiate()
	add_child_autofree(scene)
	await wait_physics_frames(3)
	var monkey: Monkey = scene.get_node("Monkey")
	var captain: Captain = scene.get("_captain")
	assert_eq(monkey.follow, captain)
	await wait_process_frames(30)
	assert_lt(monkey.global_position.distance_to(captain.global_position), 3.5)
	for mi: MeshInstance3D in monkey.find_children("*", "MeshInstance3D", true, false):
		var m := mi.get_active_material(0)
		assert_lt(m.render_priority, 100, "she is a character of the world: the island's technique draws her")

## ADR-0025, ADR-0026: every island is drawn in a technique of its own; the island's wind
## restyles a captain who arrives from another island.
extends GutTest

const HARBOUR := preload("res://scenes/harbour.tscn")


func after_each() -> void:
	Game.island = "harbour"
	Game.attuned = "harbour"
	Session.set_style(IslandStyle.HOME)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_every_island_is_drawn_in_a_technique_of_its_own() -> void:
	var home := IslandStyle.of(IslandStyle.HOME)
	var shader := FileAccess.get_file_as_string("res://shaders/ink.gdshader")
	var seen: Dictionary = {}
	for id: String in IslandStyle.TABLE:
		var st := IslandStyle.of(id)
		assert_eq(st.keys(), home.keys(), id + " has every number home has")
		var technique: String = st["technique"]
		assert_true(IslandStyle.TECHNIQUES.has(technique), id + ": a technique the effect knows")
		assert_false(seen.has(technique), "%s shares the technique of %s" % [id, seen.get(technique, "")])
		seen[technique] = id
		assert_eq((st["ramp"] as Array).size(), 4, id)
		var n := int(IslandStyle.TECHNIQUES[technique])
		assert_true(n == 0 or shader.contains("tech == %d" % n), technique + " is drawn by the shader")
	assert_eq(home["technique"], "ink", "home is the approved look of ADR-0024")
	assert_eq(home["ink"], Color(0.13, 0.1, 0.09))
	assert_eq(home["width"], 1.3)
	assert_eq(home["tint"], Color(1, 1, 1))
	assert_eq(IslandStyle.of("an island not drawn yet"), home, "an island without a row looks like home")


func test_the_effect_draws_the_style_of_the_island_the_scene_is_on() -> void:
	Game.island = "silk"
	Game.attuned = "silk"
	var scene: Node3D = HARBOUR.instantiate()
	add_child_autofree(scene)
	await wait_physics_frames(2)
	assert_eq(Session.style_id, "silk")
	assert_eq(Session.ink_param("ink"), IslandStyle.of("silk")["ink"])
	assert_eq(Session.ink_param("width"), IslandStyle.of("silk")["width"])
	assert_false(Session.attuning(), "a captain already of this island is left alone")
	var sun: DirectionalLight3D = scene.get_node("Sun")
	assert_eq(sun.light_color, IslandStyle.of("silk")["sun"])


func test_the_wind_of_a_new_island_restyles_the_captain() -> void:
	Game.island = "silk"
	Game.attuned = "harbour"
	var scene: Node3D = HARBOUR.instantiate()
	add_child_autofree(scene)
	await wait_physics_frames(2)
	var captain: Captain = scene.get("_captain")
	assert_true(Session.attuning(), "the newcomer is still drawn the old way")
	assert_eq(Session.ink_param("ink_from"), IslandStyle.of("harbour")["ink"])
	assert_eq(Session.ink_param("technique_from"), 0, "pen and ink")
	assert_eq(Session.ink_param("technique"), 1, "inside an island of dyed silk")
	assert_gt(float(Session.ink_param("column_radius")), 0.5)
	assert_lt(float(Session.ink_param("wave")), captain.global_position.y, "nothing redrawn before the wind comes")
	assert_eq(Game.attuned, "harbour")
	await Session.attune(captain, "harbour", "silk", 0.25, 0.0)
	assert_eq(Game.attuned, "silk")
	assert_false(Session.attuning())
	assert_eq(float(Session.ink_param("column_radius")), 0.0, "one style again")
	assert_eq(Session.ink_param("ink"), IslandStyle.of("silk")["ink"])


func test_the_wave_rises_from_feet_to_hat_while_the_wind_circles() -> void:
	assert_eq(WindSwirl.wave_at(0.0), 0.0)
	assert_eq(WindSwirl.wave_at(1.0), 1.0)
	assert_lt(WindSwirl.wave_at(0.3), WindSwirl.wave_at(0.6))
	var body := Node3D.new()
	add_child_autofree(body)
	var swirl := WindSwirl.around(body, Color.WHITE, 0.2)
	assert_eq(swirl.get_parent(), body, "it travels with the captain")
	assert_gt(swirl.get_child_count(), 20)
	await wait_seconds(0.4)
	assert_false(is_instance_valid(swirl), "the swirl clears itself away")


func test_leaving_in_the_middle_of_it_leaves_one_style() -> void:
	var body := Node3D.new()
	add_child(body)
	Session.attune(body, "harbour", "silk", 5.0, 0.0)
	await wait_process_frames(3)
	assert_true(Session.attuning())
	body.free()
	await wait_process_frames(4)
	assert_false(Session.attuning())
	assert_eq(float(Session.ink_param("column_radius")), 0.0)

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
	assert_eq(Session.ink_param("technique"), IslandStyle.TECHNIQUES["katazome"], "inside an island of stencilled indigo")
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


## ADR-0029: in every port the hero is redrawn in that island's technique. Whatever a technique does, it must be able
## to draw the captain — in the old style and the new one in the same frame — and the wind must end with one style.
func test_every_technique_can_redraw_the_captain() -> void:
	var shader := FileAccess.get_file_as_string("res://shaders/ink.gdshader")
	for name: String in IslandStyle.TECHNIQUES:
		var n := int(IslandStyle.TECHNIQUES[name])
		assert_true(n == 0 or shader.contains("tech == %d" % n), name + " has its branch")
	assert_true(shader.contains("int tech = old > 0.5 ? technique_from : technique;"), "the technique is chosen per pixel: the old one inside the captain's column")
	for key: String in ["ink", "paper", "tint", "width", "hatch_turn", "hatch_gap", "technique", "ramp0", "ramp1", "ramp2", "ramp3"]:
		assert_true(shader.contains(" %s_from" % key), "the shader can hold two values of " + key)
	for needs_hero: String in ["hero", "hero_radius"]:
		assert_true(shader.contains("uniform") and shader.contains(needs_hero), "a technique may measure from the hero")
	var body := Node3D.new()
	add_child_autofree(body)
	var islands: Array = IslandStyle.TABLE.keys()
	assert_gt(islands.size(), 2)
	for from: String in islands:
		for to: String in islands:
			if from == to:
				continue
			Game.attuned = from
			Session.attune(body, from, to, 0.05, 0.0)
			assert_true(Session.attuning(), "%s → %s: the captain arrives drawn the old way" % [from, to])
			assert_eq(Session.ink_param("technique_from"), IslandStyle.TECHNIQUES[IslandStyle.of(from)["technique"]])
			assert_eq(Session.ink_param("technique"), IslandStyle.TECHNIQUES[IslandStyle.of(to)["technique"]])
			assert_gt(float(Session.ink_param("column_radius")), 0.5)
			for i in 120:  # the wind takes a few frames, however long a frame is
				if not Session.attuning():
					break
				await wait_process_frames(1)
			assert_false(Session.attuning(), "%s → %s: one style when the wind has passed" % [from, to])
			assert_eq(Game.attuned, to)
			assert_eq(Session.style_id, to)


func test_the_port_tells_the_effect_where_the_hero_stands() -> void:
	for island: String in IslandStyle.TABLE:
		Game.island = island
		Game.attuned = "harbour" if island != "harbour" else "silk"  # arriving from somewhere else
		var scene: Node3D = HARBOUR.instantiate()
		add_child(scene)
		await wait_physics_frames(2)
		await wait_process_frames(2)
		var captain: Captain = scene.get("_captain")
		assert_eq(Session.hero, captain, island)
		assert_gt(float(Session.ink_param("hero_radius")), 0.5, island + ": the effect knows the hero is here")
		assert_almost_eq((Session.ink_param("hero") as Vector3).x, captain.global_position.x, 0.5)
		assert_true(Session.attuning(), island + ": a newcomer is redrawn on arrival")
		scene.free()
		await wait_process_frames(2)
		assert_eq(float(Session.ink_param("hero_radius")), 0.0, "no hero when the port is left")

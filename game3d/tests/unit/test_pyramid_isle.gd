## ADR-0038: the pyramid island is a place to look at — a pastel fairground under a glass dome whose every front is
## a facade on props, decaying a stage per visit; nothing takes or pays money there, and no sign promises a return.
extends GutTest

const HARBOUR := preload("res://scenes/harbour.tscn")


func after_each() -> void:
	Game.island = "harbour"
	Game.attuned = "harbour"
	Game.visits = {}
	Session.set_style(IslandStyle.HOME)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_the_stage_follows_the_visits_and_ends_at_four() -> void:
	assert_eq([0, 1, 2, 3, 4, 5, 9].map(func(v: int) -> int: return PyramidIsle.stage(v)), [1, 1, 2, 3, 4, 4, 4])
	var last := 99
	for s in range(1, PyramidIsle.STAGES + 1):
		var lk := PyramidIsle.look(s)
		assert_lt(int(lk["crowd"]), last, "fewer people every stage")
		last = int(lk["crowd"])
	assert_false(PyramidIsle.look(2)["cracks"])
	assert_true(PyramidIsle.look(3)["cracks"])
	assert_true(PyramidIsle.look(4)["broken"])


func test_each_stage_builds_and_shows_its_decay() -> void:
	var glass := {}
	for s in range(1, PyramidIsle.STAGES + 1):
		var isl := PyramidIsle.build(true, s)
		add_child_autofree(isl)
		assert_eq(isl.get_meta("stage"), s)
		var g: MeshInstance3D = isl.find_child("Glass", true, false)
		glass[s] = g.mesh.get_faces().size()
		assert_eq(isl.find_child("Cracks", true, false) != null, s >= 3, "cracks from stage 3")
		assert_eq(isl.find_child("Shards", true, false) != null, s == 4, "shards on the ground at stage 4")
		var bare := 0
		for i in 4:
			bare += 1 if isl.get_node("Facade%d" % (i + 1)).get_meta("bare") else 0
		assert_eq(bare, (PyramidIsle.look(s)["bare"] as Array).size())
	assert_eq(glass[1], glass[3], "the dome is whole until stage 4")
	assert_lt(glass[4], glass[3] * 0.8, "at stage 4 panes are missing")


func test_every_front_has_props_behind_it() -> void:
	var isl := PyramidIsle.build(true, 1)
	add_child_autofree(isl)
	var fronts := 0
	for n in isl.get_children():
		if n.name.begins_with("Facade"):
			fronts += 1
			assert_not_null(n.find_child("Scaffold", true, false), str(n.name) + ": scaffolding behind")
	assert_eq(fronts, 4)


func test_the_island_is_a_toy_and_the_captain_is_redrawn_on_landing() -> void:
	assert_eq(IslandStyle.of("pyramid")["technique"], "toy")
	Game.island = PyramidIsle.ID
	Game.attuned = "harbour"
	var scene: Node3D = HARBOUR.instantiate()
	add_child_autofree(scene)
	await wait_physics_frames(3)
	var captain: Captain = scene.get("_captain")
	assert_lt(captain.global_position.distance_to(PyramidIsle.SPAWN), 2.0)
	assert_eq(Session.ink_param("technique"), IslandStyle.TECHNIQUES["toy"])
	await Session.attune(captain, "harbour", "pyramid", 0.2, 0.0)
	assert_eq(Game.attuned, "pyramid")


func test_its_people_talk_and_nobody_sells_a_percentage() -> void:
	var s := ComicScript.read()
	var talks: Array[String] = []
	for id: String in s.talks:
		if id.begins_with("pyramid_"):
			talks.append(id)
	talks.sort()
	assert_eq(talks, ["pyramid_booth", "pyramid_crowd", "pyramid_happy", "pyramid_stairs", "pyramid_sweeper", "pyramid_worried"] as Array[String])
	for role: String in ["pyr_host", "pyr_barker", "pyr_happy", "pyr_worried", "pyr_sweeper"]:
		assert_true(Costume.BUILDS.has(role))
		assert_true(Costume.new().has_method("_r_" + role))
		assert_true(ComicFaces.has(role))
	var words := FileAccess.get_file_as_string("res://scripts/pyramid_isle.gd")
	for row: String in FileAccess.get_file_as_string("res://i18n/talk.csv").split("\n"):
		if row.begins_with("PYR_"):
			words += row
	assert_null(RegEx.create_from_string("\\d+\\s*%").search(words), "no promised percentage anywhere")
	assert_false(FileAccess.get_file_as_string("res://scripts/pyramid_isle.gd").contains("Label3D"), "no words on its signs: pictograms only")


func test_landings_age_the_fair() -> void:
	Game.visits = {}
	Game.island = PyramidIsle.ID
	Game.attuned = PyramidIsle.ID
	for want: int in [1, 2]:
		var scene: Node3D = HARBOUR.instantiate()
		add_child_autofree(scene)
		await wait_physics_frames(2)
		assert_eq(int(Game.visits["pyramid"]), want)
		assert_eq(scene.find_child("PyramidIsle", true, false).get_meta("stage"), want)
		scene.queue_free()
		await wait_physics_frames(1)


func test_the_island_is_on_the_flight_chart() -> void:
	assert_true(Ports.has("pyramid"))
	var ship := Ports.cast_off("pyramid")
	assert_eq(Ports.mooring(ship), "pyramid")
	assert_gt(Vector2(PyramidIsle.DOCK.x - PyramidIsle.AT.x, PyramidIsle.DOCK.z - PyramidIsle.AT.z).length(), PyramidIsle.RADIUS + FlightModel.HULL, "the berth is clear of the rock")
	assert_lt(Vector2(PyramidIsle.AT.x, PyramidIsle.AT.z).length() + PyramidIsle.RADIUS + 30.0, Ports.WORLD_RADIUS)
	for other: String in Ports.ORDER:
		if other != "pyramid":
			assert_gt(Vector2(PyramidIsle.AT.x, PyramidIsle.AT.z).distance_to(Vector2(Ports.all()[other]["centre"].x, Ports.all()[other]["centre"].z)),
				PyramidIsle.RADIUS + float(Ports.all()[other]["radius"]) + 60.0, "well clear of " + other)

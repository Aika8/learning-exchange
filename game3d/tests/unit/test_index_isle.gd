## ADR-0033: the index island is a place and a style — a symmetrical toy town reached by ship, with a fountain that
## drops a coin and five islanders who talk; nothing is bought there, and no real fund is named.
extends GutTest

const HARBOUR := preload("res://scenes/harbour.tscn")


func after_each() -> void:
	Game.island = "harbour"
	Game.attuned = "harbour"
	Session.set_style(IslandStyle.HOME)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _there() -> Node3D:
	Game.island = IndexIsle.ID
	Game.attuned = IndexIsle.ID
	Session.spawn = "pier"
	var scene: Node3D = HARBOUR.instantiate()
	add_child_autofree(scene)
	await wait_physics_frames(3)
	return scene


func test_the_island_is_a_toy_town_and_the_captain_is_redrawn_on_landing() -> void:
	assert_eq(IslandStyle.of("index")["technique"], "toy")
	var shader := FileAccess.get_file_as_string("res://shaders/ink.gdshader")
	var from := shader.find("tech == 5")
	var branch := shader.substr(from, shader.find("tech == 4") - from)
	assert_gt(from, 0)
	assert_false(branch.contains("TIME"), "nothing in the technique is animated")
	assert_true(branch.contains("smoothstep(0.5, 1.0, off_centre)"), "tilt-shift leaves the middle half of the screen exactly sharp")
	assert_false(branch.contains("depth") and branch.contains("blur = ") and branch.contains("blur *= d"), "the blur looks at the screen height only")
	Game.island = IndexIsle.ID
	Game.attuned = "harbour"
	var scene: Node3D = HARBOUR.instantiate()
	add_child_autofree(scene)
	await wait_physics_frames(3)
	var captain: Captain = scene.get("_captain")
	assert_lt(captain.global_position.distance_to(IndexIsle.SPAWN), 2.0)
	assert_eq(Session.ink_param("technique"), IslandStyle.TECHNIQUES["toy"])
	assert_true(Session.attuning(), "still drawn in pen and ink until the wind comes")
	await Session.attune(captain, "harbour", "index", 0.2, 0.0)
	assert_eq(Game.attuned, "index")


func test_the_town_is_mirror_symmetrical_about_its_avenue() -> void:
	var isl := IndexIsle.build(true)
	add_child_autofree(isl)
	var left: Dictionary = {}
	var right: Dictionary = {}
	for n in isl.get_children():
		if not n.has_meta("mirror"):
			continue
		var p: Vector3 = (n as Node3D).position
		var key := "%s %.1f,%.1f" % ["Mansion" if n.has_meta("size") else "thing", p.x, absf(p.z)]  # a thing is known by where it stands
		if float(n.get_meta("mirror")) > 0.0:
			left[key] = p.z
		else:
			right[key] = p.z
	assert_gt(left.size(), 15, "mansions, trees, hedges, yachts, lamps")
	assert_eq(left.keys(), right.keys(), "everything on one side has its twin on the other")
	for key: String in left:
		assert_almost_eq(float(left[key]), -float(right[key]), 0.001, key)
	var sizes: Dictionary = {}
	for n in isl.get_children():
		if n.has_meta("size"):
			sizes[n.get_meta("size")] = true
	assert_eq(sizes.size(), 1, "every mansion is the same mansion")
	assert_almost_eq(IndexIsle.PALACE.z, 0.0, 0.001, "the palace stands on the axis")
	assert_almost_eq(IndexIsle.FOUNTAIN.z, 0.0, 0.001)


func test_the_fountain_drops_a_coin_every_few_seconds() -> void:
	assert_eq(IndexIsle.coin_height(0.0), 0.0)
	assert_almost_eq(IndexIsle.coin_height(0.6), 2.4, 0.01, "at the top of its throw")
	assert_eq(IndexIsle.coin_height(2.0), -1.0, "then under water, waiting")
	assert_almost_eq(IndexIsle.coin_height(IndexIsle.COIN_EVERY + 0.6), 2.4, 0.01, "and again")
	var scene := await _there()
	var coin: Node3D = scene.find_child("Coin", true, false)
	assert_not_null(coin)
	await wait_process_frames(3)
	assert_eq(coin.visible, IndexIsle.coin_height(Time.get_ticks_msec() * 0.001) >= 0.0, "the scene moves it")


func test_five_islanders_talk_and_nothing_is_bought_and_no_real_fund_is_named() -> void:
	var s := ComicScript.read()
	var scene := await _there()
	assert_eq((scene.call("_spots") as Dictionary).keys(), ["ship", "palace"])
	assert_null(scene.find_child("Ladder", true, false), "no trading floor on this island")
	assert_not_null(scene.find_child("Keeper_palace", true, false))
	var talks: Array[String] = ["index_palace"]
	for v: Villager in scene.get("_villagers"):
		talks.append(str(v.get_meta("talk", "")))
	talks.sort()
	assert_eq(talks, ["index_child", "index_grandpa", "index_granny", "index_lady", "index_palace"] as Array[String])
	for id in talks:
		assert_true(s.has(id), id)
	for role: String in ["toy_gentleman", "toy_lady", "toy_grandpa", "toy_granny", "toy_child"]:
		assert_true(Costume.BUILDS.has(role))
		assert_true(Costume.new().has_method("_r_" + role))
		assert_true(ComicFaces.has(role))
	var words := FileAccess.get_file_as_string("res://i18n/talk.csv") + FileAccess.get_file_as_string("res://scripts/index_isle.gd")
	for name: String in ["SPY", "BIL", "S&P", "Vanguard", "BlackRock"]:
		assert_null(RegEx.create_from_string("(?<![A-Za-z_])" + name.replace("&", "\\&") + "(?![A-Za-z_])").search(words), "names a real fund: " + name)


func test_the_island_is_on_the_flight_chart() -> void:
	assert_true(Ports.has("index"))
	assert_eq(Ports.all()["index"]["centre"], IndexIsle.AT)
	var ship := Ports.cast_off("index")
	assert_eq(Ports.mooring(ship), "index")
	for other: String in Ports.ORDER:
		if other != "index":
			assert_gt(Vector2(IndexIsle.AT.x, IndexIsle.AT.z).distance_to(Vector2(Ports.all()[other]["centre"].x, Ports.all()[other]["centre"].z)),
				IndexIsle.RADIUS + float(Ports.all()[other]["radius"]) + 60.0, "well clear of " + other)

## ADR-0030: the short sellers' island is a place and a style — reached by the packet boat, drawn as noir, peopled by
## four islanders who talk; nothing is traded there yet.
extends GutTest

const HARBOUR := preload("res://scenes/harbour.tscn")


func after_each() -> void:
	Game.island = "harbour"
	Game.attuned = "harbour"
	Session.set_style(IslandStyle.HOME)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_the_island_is_drawn_as_noir_and_the_captain_is_redrawn_on_landing() -> void:
	assert_eq(IslandStyle.of("shorts")["technique"], "noir")
	assert_eq(IslandStyle.of("shorts")["ramp"][2], Color("c4302b"), "the one signal red")
	assert_true(FileAccess.get_file_as_string("res://shaders/ink.gdshader").contains("tech == %d" % IslandStyle.TECHNIQUES["noir"]))
	Game.island = ShortIsle.ID
	Game.attuned = "harbour"  # arriving from Spark Harbour
	Session.spawn = "pier"
	var scene: Node3D = HARBOUR.instantiate()
	add_child_autofree(scene)
	await wait_physics_frames(3)
	var captain: Captain = scene.get("_captain")
	assert_lt(captain.global_position.distance_to(ShortIsle.SPAWN), 2.0, "the captain lands on the pier")
	assert_eq(Session.style_id, "shorts")
	assert_eq(Session.ink_param("technique"), IslandStyle.TECHNIQUES["noir"])
	assert_true(Session.attuning(), "still drawn in pen and ink: the wind has not come yet")
	assert_eq(Session.ink_param("technique_from"), IslandStyle.TECHNIQUES["ink"])
	await Session.attune(captain, "harbour", "shorts", 0.2, 0.0)
	assert_eq(Game.attuned, "shorts")
	assert_false(Session.attuning())


func test_the_packet_boat_goes_there_and_back_and_nothing_is_traded() -> void:
	var harbour: Dictionary = load("res://scripts/harbour.gd").HARBOUR_SPOTS
	assert_has(harbour, "ferry_shorts")
	assert_gt((harbour["ferry_shorts"][0] as Vector3).distance_to(harbour["ferry"][0]), 4.0, "the two posts do not share a spot")
	Game.island = ShortIsle.ID
	Game.attuned = ShortIsle.ID
	var scene: Node3D = HARBOUR.instantiate()
	add_child_autofree(scene)
	await wait_physics_frames(3)
	var spots: Dictionary = scene.call("_spots")
	assert_eq(spots.keys(), ["ship", "exchange"], "a way home and a door that only talks")
	assert_null(scene.find_child("Ladder", true, false), "no trading floor on this island")


func test_four_islanders_live_there_and_each_has_something_to_say() -> void:
	var s := ComicScript.read()
	Game.island = ShortIsle.ID
	Game.attuned = ShortIsle.ID
	var scene: Node3D = HARBOUR.instantiate()
	add_child_autofree(scene)
	await wait_physics_frames(3)
	assert_not_null(scene.find_child("Keeper_exchange", true, false), "the broker by the door")
	var talks: Array[String] = ["shorts_exchange"]
	for v: Villager in scene.get("_villagers"):
		talks.append(str(v.get_meta("talk", "")))
		assert_true(v.role.begins_with("noir_"), "dressed by sheet 36")
	talks.sort()
	assert_eq(talks, ["shorts_exchange", "shorts_lady", "shorts_tramp", "shorts_youth"] as Array[String])
	for id in talks:
		assert_true(s.has(id), id)
	for role: String in ["noir_broker", "noir_tramp", "noir_youth", "noir_lady"]:
		assert_true(Costume.BUILDS.has(role), role + " has a build of its own")
		assert_true(Costume.new().has_method("_r_" + role), role + " has a costume")
		assert_true(ComicFaces.has(str(s.cast[role]["face"])))


func test_the_town_leans_but_not_too_far() -> void:
	var isl := ShortIsle.build(true)
	add_child_autofree(isl)
	var leaning := 0
	for house in isl.get_children():
		if not house.has_meta("size"):  # only the houses and towers carry their size
			continue
		var body: Node3D = house.get_node("Body")
		assert_lte(absf(body.rotation.z), ShortIsle.MAX_LEAN + 0.001)
		assert_lte(absf(body.rotation.x), ShortIsle.MAX_LEAN + 0.001)
		leaning += 1 if absf(body.rotation.z) > 0.03 else 0
		assert_gt(body.find_children("*", "CollisionShape3D", true, false).size(), 0, "the collider leans with the house")
	assert_gt(leaning, 10, "a crooked town")
	assert_not_null(isl.find_child("FallingExchange", false, false))
	assert_not_null(isl.find_child("Slab", false, false), "the tilt is a great slab behind the town")
	assert_eq(Archipelago.walk_areas("shorts")[0]["centre"], ShortIsle.AT, "people stand on a flat cap")

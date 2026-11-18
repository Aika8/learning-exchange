## ADR-0034: the race island is a place and a style — the Grand Prix of the Winds drawn as an art-deco poster: a
## track in the air round the rock, pits, a timing tower, five islanders who talk; nothing is raced or repaired
## there, and no real racing brand is named.
extends GutTest

const HARBOUR := preload("res://scenes/harbour.tscn")


func after_each() -> void:
	Game.island = "harbour"
	Game.attuned = "harbour"
	Session.set_style(IslandStyle.HOME)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _there() -> Node3D:
	Game.island = RaceIsle.ID
	Game.attuned = RaceIsle.ID
	Session.spawn = "pier"
	var scene: Node3D = HARBOUR.instantiate()
	add_child_autofree(scene)
	await wait_physics_frames(3)
	return scene


func test_the_island_is_an_art_deco_poster_and_the_captain_is_redrawn_on_landing() -> void:
	assert_eq(IslandStyle.of("race")["technique"], "deco")
	var shader := FileAccess.get_file_as_string("res://shaders/ink.gdshader")
	var from := shader.find("tech == 6")
	var branch := shader.substr(from, shader.find("tech == 4") - from)
	assert_gt(from, 0)
	assert_false(branch.contains("TIME"), "nothing in the technique is animated")
	assert_false(branch.contains("FRAGCOORD") or branch.contains("SCREEN_UV"), "no pattern is laid out on the screen: stripes follow the normal, rays the world")
	Game.island = RaceIsle.ID
	Game.attuned = "harbour"
	var scene: Node3D = HARBOUR.instantiate()
	add_child_autofree(scene)
	await wait_physics_frames(3)
	var captain: Captain = scene.get("_captain")
	assert_lt(captain.global_position.distance_to(RaceIsle.SPAWN), 2.0)
	assert_eq(Session.ink_param("technique"), IslandStyle.TECHNIQUES["deco"])
	assert_true(Session.attuning(), "still drawn in pen and ink until the wind comes")
	await Session.attune(captain, "harbour", "race", 0.2, 0.0)
	assert_eq(Game.attuned, "race")


func test_the_track_is_in_the_air_round_the_island_above_every_head() -> void:
	var inner := RaceIsle.TRACK_R - RaceIsle.TRACK_W * 0.5
	assert_gt(inner, RaceIsle.RADIUS, "the whole ribbon is beyond the island's edge")
	assert_gt(RaceIsle.bank(inner) - 0.7, 3.0, "and its underside is above every hat")
	assert_gt(RaceIsle.bank(inner + RaceIsle.TRACK_W), RaceIsle.bank(inner), "it is banked: the outer edge is higher")
	assert_lt(RaceIsle.TRACK_R + RaceIsle.TRACK_W * 0.5, RaceIsle.REACH, "the ship's solid for this island holds the track")
	assert_eq(float(Ports.all()["race"]["radius"]), RaceIsle.REACH)
	var isl := RaceIsle.build(true)
	add_child_autofree(isl)
	var track: Node3D = isl.get_node("Track")
	assert_true(track.has_meta("flat"), "scenery: nobody reaches it")
	assert_eq(track.find_children("*", "StaticBody3D", true, false).size(), 0)
	var count := {"BracketFoot": 0, "PitBox": 0}
	for c in isl.get_children():
		for kind: String in count:
			if str(c.name).contains(kind):
				count[kind] += 1
	assert_eq(count["BracketFoot"], RaceIsle.BRACKETS, "it stands on brackets from the rim")
	assert_eq(count["PitBox"], 4)
	for name: String in ["TimingTower", "PitSkiff", "Grandstand", "Pier"]:
		assert_not_null(isl.get_node_or_null(name), name)


func test_four_skiffs_stand_as_decoration_and_do_not_move() -> void:
	assert_eq(RaceIsle.SKIFFS.keys(), ["star", "storm", "phoenix", "admiral"])
	var scene := await _there()
	var boats: Array[Node] = scene.find_children("Skiff_*", "Node3D", true, false)
	assert_eq(boats.size(), 4)
	var before: Array[Vector3] = []
	for b in boats:
		before.append((b as Node3D).global_position)
	await wait_process_frames(10)
	for i in boats.size():
		assert_eq((boats[i] as Node3D).global_position, before[i], str(boats[i].name))


func test_five_islanders_talk_and_nothing_is_raced_and_no_real_brand_is_named() -> void:
	var s := ComicScript.read()
	var scene := await _there()
	assert_eq((scene.call("_spots") as Dictionary).keys(), ["ship", "tower", "pit"])
	assert_null(scene.find_child("Ladder", true, false), "no trading floor on this island")
	var talks: Array[String] = []
	for spot: String in ["tower", "pit"]:
		assert_not_null(scene.find_child("Keeper_" + spot, true, false), spot)
		talks.append("race_" + spot)
	for v: Villager in scene.get("_villagers"):
		talks.append(str(v.get_meta("talk", "")))
	talks.sort()
	assert_eq(talks, ["race_aviator", "race_crew", "race_lady", "race_pit", "race_tower"] as Array[String])
	for id in talks:
		assert_true(s.has(id), id)
	for role: String in ["deco_aviator", "deco_mechanic", "deco_crew", "deco_marshal", "deco_lady"]:
		assert_true(Costume.BUILDS.has(role))
		assert_true(Costume.new().has_method("_r_" + role))
		assert_true(ComicFaces.has(role))
	var words := FileAccess.get_file_as_string("res://scripts/race_isle.gd").to_lower()
	for file: String in ["res://i18n/talk.csv", "res://i18n/strings.csv"]:
		for row: String in FileAccess.get_file_as_string(file).split("\n"):
			if row.contains("RACE") or row.contains("DECO") or row.contains("PIT_LANE") or row.contains("TIMING"):  # this island's words
				words += row.to_lower()
	for name: String in ["formula", "формула", "f1", "ferrari", "mclaren", "mercedes", "red bull", "monaco", "монако", "nascar", "indycar"]:
		assert_null(RegEx.create_from_string("(?<![a-zа-я_0-9])" + name + "(?![a-zа-я_0-9])").search(words), "names a real racing brand: " + name)


func test_the_island_is_on_the_flight_chart() -> void:
	assert_true(Ports.has("race"))
	assert_eq(Ports.all()["race"]["centre"], RaceIsle.AT)
	var ship := Ports.cast_off("race")
	assert_eq(Ports.mooring(ship), "race")
	assert_gt(Vector2(RaceIsle.DOCK.x - RaceIsle.AT.x, RaceIsle.DOCK.z - RaceIsle.AT.z).length(), RaceIsle.REACH + FlightModel.HULL, "the berth is clear of the track")
	assert_lt(Vector2(RaceIsle.AT.x, RaceIsle.AT.z).length() + RaceIsle.REACH + 30.0, Ports.WORLD_RADIUS, "inside the world's edge")
	for other: String in Ports.ORDER:
		if other != "race":
			assert_gt(Vector2(RaceIsle.AT.x, RaceIsle.AT.z).distance_to(Vector2(Ports.all()[other]["centre"].x, Ports.all()[other]["centre"].z)),
				RaceIsle.REACH + float(Ports.all()[other]["radius"]) + 60.0, "well clear of " + other)

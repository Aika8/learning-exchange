## ADR-0035 (supersedes 0033): the index island is a canal town painted in oil — a place and a style reached by
## ship, with a fountain that drops a coin and people of every age who talk, its costs told as plainly as its
## method; nothing is bought there, and no real fund is named. The toy technique is kept, on no island.
extends GutTest

const HARBOUR := preload("res://scenes/harbour.tscn")
const ROLES: Array[String] = ["oil_merchant", "oil_lady", "oil_market", "oil_father", "oil_child", "oil_grandpa", "oil_granny"]


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


func test_the_island_is_painted_in_oil_and_the_captain_is_redrawn_on_landing() -> void:
	assert_eq(IslandStyle.of("index")["technique"], "oil")
	var shader := FileAccess.get_file_as_string("res://shaders/ink.gdshader")
	var from := shader.find("tech == 7")
	var branch := shader.substr(from, shader.find("tech == 6") - from)
	assert_gt(from, 0)
	assert_false(branch.contains("TIME"), "nothing in the technique is animated")
	assert_true(branch.contains("anchored.xz"), "the brush strokes are laid out in the world, not on the screen")
	assert_eq(branch.count("FRAGCOORD"), 1, "one layer only lies on the screen: the canvas")
	assert_true(branch.contains("0.975 + 0.025"), "and it is faint")
	Game.island = IndexIsle.ID
	Game.attuned = "harbour"
	var scene: Node3D = HARBOUR.instantiate()
	add_child_autofree(scene)
	await wait_physics_frames(3)
	var captain: Captain = scene.get("_captain")
	assert_lt(captain.global_position.distance_to(IndexIsle.SPAWN), 2.0)
	assert_eq(Session.ink_param("technique"), IslandStyle.TECHNIQUES["oil"])
	assert_true(Session.attuning(), "still drawn in pen and ink until the wind comes")
	await Session.attune(captain, "harbour", "index", 0.2, 0.0)
	assert_eq(Game.attuned, "index")
	var sun: DirectionalLight3D = scene.find_child("Sun", true, false)
	assert_almost_eq(sun.rotation_degrees.x, -16.0, 0.01, "a low sun: long shadows")


func test_the_toy_technique_is_kept_for_another_island() -> void:
	assert_eq(IslandStyle.TECHNIQUES["toy"], 5)
	assert_gt(FileAccess.get_file_as_string("res://shaders/ink.gdshader").find("tech == 5"), 0)
	for id: String in IslandStyle.TABLE:
		assert_ne(IslandStyle.TABLE[id]["technique"], "toy", id + ": no island is a toy town until Aika places it")
	for role: String in ["toy_gentleman", "toy_lady", "toy_grandpa", "toy_granny", "toy_child"]:
		assert_true(Costume.new().has_method("_r_" + role), role)
		assert_true(FileAccess.file_exists(ComicFaces.path(role, "neutral")), role)


func test_it_is_a_canal_town_with_bridges_and_no_two_neighbours_alike() -> void:
	var isl := IndexIsle.build(true)
	add_child_autofree(isl)
	var count := {"House": 0, "Bridge": 0, "QuayWall": 0, "Linden": 0}
	for c in isl.get_children():
		for kind: String in count:
			if str(c.name).begins_with(kind):
				count[kind] += 1
	assert_eq(count["House"], IndexIsle.houses().size())
	assert_gt(count["House"], 15)
	assert_eq(count["Bridge"], IndexIsle.BRIDGES.size())
	assert_gt(count["QuayWall"], 8, "the canal is walled on both sides and at its ends")
	assert_eq(count["Linden"], IndexIsle.lindens().size())
	for name: String in ["Exchange", "Canal", "CoinFountain", "MarketStall", "Pier"]:
		assert_not_null(isl.get_node_or_null(name), name)
	var rows := IndexIsle.houses()
	for i in rows.size():
		for j in range(i + 1, rows.size()):
			if (rows[i][0] as Vector3).distance_to(rows[j][0]) < 5.2:
				assert_ne(rows[i][2], rows[j][2], "neighbours %d and %d have the same front" % [i, j])
	for b: Array in IndexIsle.BRIDGES:
		assert_lt(absf(float(b[0])) + float(b[1]) * 0.5, IndexIsle.CANAL_END, "a bridge crosses the canal, not its end")


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


func test_people_of_every_age_talk_and_tell_the_costs_and_no_real_fund_is_named() -> void:
	var s := ComicScript.read()
	var scene := await _there()
	assert_eq((scene.call("_spots") as Dictionary).keys(), ["ship", "exchange", "stall"])
	assert_null(scene.find_child("Ladder", true, false), "no trading floor on this island")
	var talks: Array[String] = []
	for spot: String in ["exchange", "stall"]:
		assert_not_null(scene.find_child("Keeper_" + spot, true, false), spot)
		talks.append("index_" + spot)
	for v: Villager in scene.get("_villagers"):
		talks.append(str(v.get_meta("talk", "")))
	talks.sort()
	assert_eq(talks, ["index_child", "index_exchange", "index_father", "index_grandpa", "index_granny", "index_lady", "index_stall"] as Array[String])
	for id in talks:
		assert_true(s.has(id), id)
	for role in ROLES:
		assert_true(Costume.BUILDS.has(role))
		assert_true(Costume.new().has_method("_r_" + role))
		assert_true(ComicFaces.has(role))
	var heights: Array[float] = []
	for role in ROLES:
		heights.append(float(Costume.BUILDS[role][0]))
	assert_lt(heights.min(), 0.7, "a child")
	assert_gt(heights.max(), 1.0, "and grown people")
	var words := ""
	for row: String in FileAccess.get_file_as_string("res://i18n/talk.csv").split("\n"):
		if row.begins_with("TALK_INDEX_"):
			words += row + "\n"
	for cost: String in ["половину", "годами", "скука", "Быстро здесь не бывает"]:  # intent 03: the island is not "the right answer"
		assert_true(words.contains(cost), "the island tells its cost: " + cost)
	words += FileAccess.get_file_as_string("res://scripts/index_isle.gd")
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

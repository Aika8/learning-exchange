## ADR-0031: the crypto island is a place and a style — reached by the packet boat, drawn as synthwave pixel art,
## peopled by four islanders and three robots who talk; nothing is traded there, and no real coin is named or shown.
extends GutTest

const HARBOUR := preload("res://scenes/harbour.tscn")


func after_each() -> void:
	Game.island = "harbour"
	Game.attuned = "harbour"
	Session.set_style(IslandStyle.HOME)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _there() -> Node3D:
	Game.island = CryptoIsle.ID
	Game.attuned = CryptoIsle.ID
	Session.spawn = "pier"
	var scene: Node3D = HARBOUR.instantiate()
	add_child_autofree(scene)
	await wait_physics_frames(3)
	return scene


func test_the_island_is_pixel_art_and_the_captain_is_redrawn_on_landing() -> void:
	assert_eq(IslandStyle.of("crypto")["technique"], "pixel")
	var shader := FileAccess.get_file_as_string("res://shaders/ink.gdshader")
	assert_true(shader.contains("tech == %d" % IslandStyle.TECHNIQUES["pixel"]))
	var branch := shader.substr(shader.find("tech == 4"), shader.find("tech == 3") - shader.find("tech == 4"))
	assert_false(branch.contains("TIME"), "nothing in the pixel technique is animated: no blinking neon")
	assert_false(branch.contains("FRAGCOORD"), "nothing is laid out on a screen grid: texels belong to the world and do not crawl")
	assert_false(branch.contains("bayer("), "no dithering over the picture")
	assert_true(branch.contains("floor(local / TEXEL)"), "the paint is snapped to texels in world space")
	Game.island = CryptoIsle.ID
	Game.attuned = "harbour"
	var scene: Node3D = HARBOUR.instantiate()
	add_child_autofree(scene)
	await wait_physics_frames(3)
	var captain: Captain = scene.get("_captain")
	assert_lt(captain.global_position.distance_to(CryptoIsle.SPAWN), 2.0)
	assert_eq(Session.ink_param("technique"), IslandStyle.TECHNIQUES["pixel"])
	assert_true(Session.attuning(), "still drawn in pen and ink until the wind comes")
	await Session.attune(captain, "harbour", "crypto", 0.2, 0.0)
	assert_eq(Game.attuned, "crypto")


func test_the_packet_boat_goes_there_and_back_and_nothing_is_traded() -> void:
	var harbour: Dictionary = load("res://scripts/harbour.gd").HARBOUR_SPOTS
	assert_has(harbour, "ferry_crypto")
	for other: String in ["ferry", "ferry_shorts"]:
		assert_gt((harbour["ferry_crypto"][0] as Vector3).distance_to(harbour[other][0]), 3.5, "the posts do not share a spot")
	var scene := await _there()
	var spots: Dictionary = scene.call("_spots")
	assert_eq(spots.keys(), ["ship", "bot_trader", "bot_miner", "bot_info"])
	assert_null(scene.find_child("Ladder", true, false), "no trading floor on this island")


func test_islanders_and_bots_live_there_and_each_has_something_to_say() -> void:
	var s := ComicScript.read()
	var scene := await _there()
	assert_not_null(scene.find_child("Miner", true, false))
	var talks: Array[String] = ["crypto_miner"]
	for v: Villager in scene.get("_villagers"):
		talks.append(str(v.get_meta("talk", "")))
	for bot: String in CryptoIsle.BOTS:
		talks.append(bot)
		assert_not_null(scene.find_child("Bot_" + bot, true, false), bot + " stands on the island")
	talks.sort()
	assert_eq(talks, ["bot_info", "bot_miner", "bot_trader", "crypto_analyst", "crypto_dreamer", "crypto_miner", "crypto_trader"] as Array[String])
	for id in talks:
		assert_true(s.has(id) or id == "crypto_miner", id)  # the miner stands still: nobody walks up to a stroller's talk for him yet
		assert_true(ComicFaces.has(str(s.cast[id]["face"])), id + " has a portrait")
	for role: String in ["crypto_trader", "crypto_miner", "crypto_dreamer", "crypto_analyst"]:
		assert_true(Costume.BUILDS.has(role))
		assert_true(Costume.new().has_method("_r_" + role))


func test_no_real_coin_is_named_or_shown_and_our_own_stands_on_the_square() -> void:
	var isl := CryptoIsle.build(true)
	add_child_autofree(isl)
	assert_not_null(isl.find_child("WindCoin", false, false), "the wind coin, on its plinth")
	var forbidden := ["₿", "BTC", "ETH", "bitcoin", "Bitcoin", "биткоин", "Биткоин", "ethereum", "Ethereum", "эфириум"]
	for path: String in ["res://data/talks.json", "res://i18n/talk.csv", "res://i18n/strings.csv", "res://scripts/crypto_isle.gd", "res://scripts/harbour.gd"]:
		var text := FileAccess.get_file_as_string(path)
		assert_ne(text, "", path)
		for word: String in forbidden:
			var whole := RegEx.create_from_string("(?<![A-Za-z_])" + word + "(?![A-Za-z_])")  # METHOD_GET is not a coin
			assert_null(whole.search(text), "%s names a real coin: %s" % [path, word])

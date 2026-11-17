## ADR-0028: Amber Cliff speaks French whatever the game's language is; the gloss is the game's language.
extends GutTest

const HARBOUR := preload("res://scenes/harbour.tscn")


func after_each() -> void:
	Game.island = "harbour"
	Game.attuned = "harbour"
	Session.set_style(IslandStyle.HOME)
	Locale.set_locale("ru")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _amber() -> Node3D:
	Game.island = AmberCliff.ID
	Game.attuned = AmberCliff.ID
	Session.spawn = "pier"
	var scene: Node3D = HARBOUR.instantiate()
	add_child_autofree(scene)
	await wait_physics_frames(3)
	return scene


func test_the_island_has_a_tongue_and_every_word_in_three_languages() -> void:
	assert_eq(IslandTongue.of("amber"), "fr")
	assert_eq(IslandTongue.of("harbour"), "", "home speaks the game's language")
	var words: Dictionary = IslandTongue.catalogues()[IslandTongue.WORDS["fr"]]
	for locale: String in ["fr", "ru", "en"]:
		assert_has(words, locale)
	var fr: Translation = words["fr"]
	assert_gt(fr.get_message_count(), 70)
	for key: StringName in fr.get_message_list():
		for locale: String in words:
			assert_ne(str((words[locale] as Translation).get_message(key)), "", "%s: no %s" % [key, locale])
	assert_eq(IslandTongue.say("AMB_SIGN_BAKERY", "fr"), "BOULANGERIE")
	assert_eq(IslandTongue.say("HARBOUR_TITLE", "fr"), "", "the game's own words have no French")
	assert_false("fr" in Locale.LOCALES, "French is not a game language")


func test_signs_and_prompts_are_french_in_either_game_language() -> void:
	for code: String in ["ru", "en"]:
		Locale.set_locale(code)
		var scene := await _amber()
		assert_eq(Session.style_id, "amber")
		assert_eq(Session.ink_param("technique"), IslandStyle.TECHNIQUES["aquarelle"])
		var signs: Array = scene.get("_signs")
		assert_gt(signs.size(), 10, "the town is full of words")
		var read: Array[String] = []
		for l: Label3D in signs:
			read.append(l.text)
			assert_eq(l.text, IslandTongue.say(str(l.get_meta("key")), "fr"))
		for word: String in ["BOULANGERIE", "BANQUE D'AMBRE", "BUREAU DE CHANGE", "LIBRAIRIE"]:
			assert_has(read, word)
		assert_eq((scene.get("_title") as Label).text, "La Falaise d'Ambre")
		assert_eq(scene.call("_shown", "AMB_PROMPT_BANK"), "E — la banque")
		scene.set("_glossing", true)  # T held
		assert_eq(scene.call("_shown", "AMB_PROMPT_BANK"), "E — банк" if code == "ru" else "E — the bank")
		(scene.get("_captain") as Captain).global_position = AmberCliff.AT + Vector3(-12, 0.5, 0)  # at the corner of the square
		assert_string_contains(scene.call("_read_sign"), " — ")
		scene.free()


func test_every_keeper_and_stroller_talks_in_french_with_a_gloss() -> void:
	var s := ComicScript.read()
	var scene := await _amber()
	var page: ComicPage = scene.call("comic")
	var spots: Dictionary = scene.call("_spots")
	for id: String in spots:
		if id != "ship":
			assert_true(s.has("amber_" + id), id + " has a talk")
			assert_eq(s.tongue("amber_" + id), "fr")
	for v: Villager in scene.get("_villagers"):
		assert_true(s.has(str(v.get_meta("talk", ""))), "a stroller with nothing to say")
	Locale.set_locale("en")
	assert_true(page.open("amber_bakery"))
	await wait_process_frames(3)
	assert_eq(page.speak, "fr")
	var b: Dictionary = page.frames()[0].balloons[0]
	assert_string_contains(str(b["text"]), "baguette")
	assert_string_contains(str(b["gloss"]), "sparks", "the gloss is the game's language")
	assert_string_contains(str(b["name"]), "boulangère")
	page.close()


func test_the_packet_boat_goes_there_and_back() -> void:
	assert_true(Archipelago.walk_areas("amber").size() == 2)
	var harbour: Dictionary = load("res://scripts/harbour.gd").HARBOUR_SPOTS
	assert_has(harbour, "ferry")
	var scene := await _amber()
	assert_has(scene.call("_spots"), "ship")
	var captain: Captain = scene.get("_captain")
	assert_lt(captain.global_position.distance_to(AmberCliff.SPAWN), 2.0, "the captain lands on the quay")
	assert_gt(AmberCliff.RADIUS, Archipelago.HARBOUR_RADIUS, "a big island")

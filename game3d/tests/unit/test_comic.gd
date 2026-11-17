## ADR-0027: a talk is data; the reader walks it balloon by balloon; the page shows what the reader says.
extends GutTest

const HARBOUR := preload("res://scenes/harbour.tscn")


func after_each() -> void:
	Game.island = "harbour"
	Game.attuned = "harbour"
	Game.met = {}
	Session.set_style(IslandStyle.HOME)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_the_talk_data_is_whole() -> void:
	var s := ComicScript.read()
	assert_gt(s.talks.size(), 8)
	var words := Locale.load_catalogue(ComicScript.WORDS)
	assert_has(words, "ru")
	assert_has(words, "en")
	assert_eq(s.problems(ComicScript.catalogues()), [] as Array[String])
	for role: String in ["sailor", "sailor2", "sailor3", "child", "townsman", "trader"]:
		assert_true(s.has("stroll_" + role), "every stroller has something to say: " + role)


func test_slots_are_the_same_in_every_language() -> void:
	var re := RegEx.create_from_string("\\{[a-z]+\\}")
	for words: Dictionary in ComicScript.catalogues():
		for key: StringName in (words["ru"] as Translation).get_message_list():
			var found: Array = []
			for locale: String in words:
				var slots: Array = []
				for m in re.search_all(str((words[locale] as Translation).get_message(key))):
					slots.append(m.get_string())
				slots.sort()
				found.append(slots)
			for other: Array in found:
				assert_eq(other, found[0], "slots differ in " + key)


func test_bad_data_is_reported() -> void:
	var s := ComicScript.new()
	s.cast = {"a": {"name": "WHO_A"}}
	s.backdrops = {}
	s.talks = {"t": {"backdrop": "nowhere", "pages": [{"panels": [
		{"shot": "sideways", "cast": ["a", "b"], "lines": [["c", "K1"], ["a", "K2", "bored"], ["a", "K3"]]}, {"shot": "close", "cast": ["a"]}]}]}}
	var long := Translation.new()
	long.add_message("K1", "x".repeat(ComicScript.MAX_CHARS + 1))
	var found := "\n".join(s.problems([{"ru": long}]))
	for part: String in ["unknown backdrop", "unknown shot", "b is not in the cast", "speaker c", "more than 2 balloons", "silent panel", "unknown emotion bored", "a: neither a sheet nor a look",
			"K2: no text", "K1: ru text is"]:
		assert_string_contains(found, part)


func test_the_reader_shows_a_balloon_a_step() -> void:
	var r := ComicReader.new({"pages": [
		{"panels": [{"caption": "C"}, {"lines": [["a", "1"], ["b", "2"]]}]},
		{"panels": [{"lines": [["a", "3"]]}]}]})
	assert_eq(r.pages(), 2)
	assert_eq([r.shown(0), r.shown(1)], [0, -1], "a silent panel is a beat of its own")
	assert_true(r.step())
	assert_eq([r.shown(0), r.shown(1)], [0, 1])
	assert_false(r.page_full())
	assert_true(r.step())
	assert_eq(r.shown(1), 2)
	assert_true(r.page_full())
	assert_true(r.step())
	assert_eq(r.page(), 1)
	assert_eq(r.shown(0), 1)
	assert_true(r.last())
	assert_false(r.step(), "the talk is over")


func test_every_hero_with_a_sheet_has_every_face() -> void:
	assert_eq(ComicScript.EMOTIONS, ComicFaces.EMOTIONS)
	assert_eq(ComicScript.FACES, ComicFaces.FACES)
	for face: String in ComicFaces.FACES:
		for emotion: String in ComicFaces.EMOTIONS:
			assert_true(FileAccess.file_exists(ComicFaces.path(face, emotion)), "%s %s" % [face, emotion])
			assert_not_null(ComicFaces.texture(face, emotion), "%s %s loads" % [face, emotion])
	assert_null(ComicFaces.texture("captain", "bored"))
	for emotion: String in ComicFaces.EMOTIONS:
		assert_true(ComicDoodle.FEEL.has(emotion), "the stand-in can feel " + emotion)
	var s := ComicScript.read()
	for hero: String in ["captain", "mara", "olva", "sailor3", "trader", "changeur"]:
		assert_true(ComicFaces.has(str(s.cast[hero].get("face", ""))), hero + " is drawn from a sheet")


func test_the_face_changes_with_the_line() -> void:
	var page := ComicPage.new()
	add_child_autofree(page)
	assert_true(page.open("mara_first"))
	await wait_process_frames(2)
	var frames := page.frames()
	assert_eq(frames[1].shown(), -1, "the second frame is not drawn yet")
	page.step()  # Mara's first line, cross
	assert_eq(frames[1].feeling["mara"], "angry")
	assert_eq((frames[1].actors["mara"]["node"] as TextureRect).texture, ComicFaces.texture("mara", "angry"))
	page.step()  # the captain asks, surprised; Mara has not answered yet
	assert_eq(frames[2].feeling["captain"], "surprised")
	assert_eq(frames[2].speaker(), "captain")
	var before: String = frames[2].feeling["mara"]
	page.step()  # she answers
	assert_eq(frames[2].speaker(), "mara")
	assert_eq(frames[2].feeling["mara"], "neutral")
	assert_ne(before, "", "a listener has a face too")
	assert_true((frames[2].actors["captain"]["node"] as TextureRect).flip_h, "the two look at each other")
	assert_true(frames[2].balloons[1].has("emotion"))


func test_people_without_a_sheet_get_a_drawn_stand_in() -> void:
	var page := ComicPage.new()
	add_child_autofree(page)
	assert_true(page.open("chronicler_day"))
	await wait_process_frames(2)
	page.step()
	var frame := page.frames()[1]
	var owl: ComicDoodle = frame.actors["chronicler"]["node"]
	assert_eq(owl.look.get("kind"), "owl")
	assert_eq(owl.emotion, "neutral")
	page.step()
	page.step()
	assert_eq((page.frames()[2].actors["chronicler"]["node"] as ComicDoodle).emotion, "sly")


func test_talking_to_a_stroller_opens_a_page_and_gives_the_captain_back() -> void:
	var scene: Node3D = HARBOUR.instantiate()
	add_child_autofree(scene)
	await wait_physics_frames(3)
	var captain: Captain = scene.get("_captain")
	var folk: Array = scene.get("_villagers")
	var who: Villager = folk[0]
	captain.global_position = who.global_position + Vector3(1.2, 0, 0)
	await wait_process_frames(2)
	assert_string_starts_with(str(scene.get("_target")), "talk:")
	scene.call("interact")
	await wait_process_frames(8)
	var page: ComicPage = scene.call("comic")
	assert_true(page.is_open())
	assert_false(captain.controlled, "the captain listens")
	assert_false(who.is_physics_processing(), "and so does the stroller")
	assert_eq(scene.get("_target"), "", "nothing else can be started under an open page")
	var frames := page.frames()
	assert_gt(frames.size(), 0)
	assert_eq(frames[0].shown(), 1, "the first balloon is up")
	assert_gt(frames[0].balloons.size(), 0)
	var b: Dictionary = frames[0].balloons[0]
	assert_true(Rect2(Vector2.ZERO, frames[0].size).encloses(b["rect"]), "the balloon is inside its frame")
	assert_ne(str(b["text"]), "", "with words in it")
	assert_false(str(b["text"]).begins_with("TALK_"), "translated")
	var guard := 0
	while page.is_open() and guard < 20:
		page.step()
		guard += 1
	assert_false(page.is_open())
	assert_true(captain.controlled)
	assert_true(who.is_physics_processing())


func test_mara_talks_once_and_then_gets_to_the_plan() -> void:
	var scene: Node3D = HARBOUR.instantiate()
	add_child_autofree(scene)
	await wait_physics_frames(3)
	var page: ComicPage = scene.call("comic")
	scene.call("_meet", "mara_first")
	await wait_process_frames(3)
	assert_true(page.is_open())
	assert_eq(page.reader().pages(), 2)
	page.close()
	await wait_process_frames(2)
	scene.call("_meet", "mara_first")
	await wait_process_frames(3)
	assert_false(page.is_open(), "the second time she gets straight to the plan")


func test_olva_says_the_numbers_of_the_day() -> void:
	var page := ComicPage.new()
	add_child_autofree(page)
	assert_true(page.open("olva_consensus", {"eps": "1,25", "revenue": "48 000,00"}))
	await wait_process_frames(2)
	assert_string_contains(page.say("TALK_OLVA_CONSENSUS_2"), "1,25")
	assert_false(page.open("no such talk"))

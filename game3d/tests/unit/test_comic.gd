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
	for face: String in ComicFaces.ONE_FACE:
		assert_true(FileAccess.file_exists(ComicFaces.path(face, "neutral")), face)
		assert_eq(ComicFaces.texture(face, "angry"), ComicFaces.texture(face, "neutral"), face + " has one face for every emotion")
	for face: String in ComicFaces.FACES:
		if face in ComicFaces.ONE_FACE:
			continue
		for emotion: String in ComicFaces.EMOTIONS:
			assert_true(FileAccess.file_exists(ComicFaces.path(face, emotion)), "%s %s" % [face, emotion])
			assert_not_null(ComicFaces.texture(face, emotion), "%s %s loads" % [face, emotion])
	assert_null(ComicFaces.texture("captain", "bored"))
	for emotion: String in ComicFaces.EMOTIONS:
		assert_true(ComicDoodle.FEEL.has(emotion), "the stand-in can feel " + emotion)
	var s := ComicScript.read()
	for hero: String in ["captain", "mara", "olva", "sailor", "sailor2", "sailor3", "trader", "changeur", "chronicler", "keeper", "child", "townsman", "libraire"]:
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
	var s := ComicScript.read()
	var without: Array[String] = []
	for id: String in s.cast:
		if not s.cast[id].has("face"):
			without.append(id)
	without.sort()
	assert_eq(without, ["enfant", "etudiante", "fleuriste", "marin", "monsieur"] as Array[String], "only the strollers of Amber Cliff wait for a sheet")
	var page := ComicPage.new()
	add_child_autofree(page)
	assert_true(page.open("amber_enfant"))
	await wait_process_frames(2)
	var frame := page.frames()[0]
	var boy: ComicDoodle = frame.actors["enfant"]["node"]
	assert_eq(boy.emotion, "happy", "the stand-in feels what the line says")
	assert_true(frame.actors["amb_captain"]["node"] is TextureRect)


func test_a_portrait_keeps_the_proportions_of_its_sheet() -> void:
	var page := ComicPage.new()
	add_child_autofree(page)
	assert_true(page.open("chronicler_day"))
	await wait_process_frames(2)
	page.step()
	var frame := page.frames()[1]
	var owl: Dictionary = frame.actors["chronicler"]
	assert_true(owl["node"] is TextureRect, "the Chronicler is drawn from a sheet now")
	var rect: Rect2 = owl["rect"]
	assert_almost_eq(rect.size.x / rect.size.y, ComicFaces.aspect("chronicler"), 0.01)
	assert_ne(ComicFaces.aspect("chronicler"), ComicFaces.aspect("sailor2"), "sheets are cut to their own shape")


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


## ADR-0037: the second pass over the page.
func test_every_portrait_is_cut_out_of_its_paper() -> void:
	var cut := 0
	for face: String in ComicFaces.FACES:
		assert_true(ComicFaces.kind(face) in ["cut", "oval", "card"], face)
		for emotion: String in (["neutral"] if face in ComicFaces.ONE_FACE else ComicFaces.EMOTIONS):
			assert_true(FileAccess.file_exists("%s/%s_%s.jpg" % [ComicFaces.SHEETS, face, emotion]), "%s %s: the cut from the sheet is kept" % [face, emotion])
			var img := ComicFaces.texture(face, emotion).get_image()
			if ComicFaces.kind(face) == "card":
				continue  # a picture with its own drawn background: shown whole, as a card
			cut += 1
			assert_lt(img.get_pixel(1, 1).a, 0.3, "%s %s: nothing in the corner" % [face, emotion])
			assert_lt(img.get_pixel(img.get_width() - 2, 1).a, 0.3, "%s %s: nor in the other" % [face, emotion])
			assert_gt(img.get_pixel(img.get_width() / 2, img.get_height() * 2 / 3).a, 0.9, "%s %s: and somebody in the middle" % [face, emotion])
		assert_between(ComicFaces.mouth(face), 0.15, 0.7, face + ": where the mouth is")
	assert_gt(cut, 100)
	assert_eq(ComicFaces.kind("captain"), "cut")
	assert_eq(ComicFaces.kind("oil_grandpa"), "oval")
	assert_eq(ComicFaces.kind("noir_broker"), "card")


func test_a_figure_stands_on_the_frames_edge_and_a_close_shot_is_larger() -> void:
	var page := ComicPage.new()
	add_child_autofree(page)
	assert_true(page.open("mara_first"))
	await wait_process_frames(2)
	var frames := page.frames()
	var wide: Rect2 = frames[0].actors["mara"]["rect"]
	var close: Rect2 = frames[1].actors["mara"]["rect"]
	assert_gt(wide.end.y, frames[0].size.y, "the frame cuts the bust: nothing hangs in the air")
	assert_gt(close.size.y, frames[1].size.y, "a close shot is taller than its frame")
	assert_gt(close.size.y / frames[1].size.y, wide.size.y / frames[0].size.y * 1.5, "faces are not all one size")
	var two := frames[2]
	assert_ne((two.actors["mara"]["rect"] as Rect2).size.y, (two.actors["captain"]["rect"] as Rect2).size.y, "of two, the one who listens stands a little back")
	assert_null(page.place(), "without a screen there is no picture of the place: the frame draws sky over ground")
	assert_true(frames[1].position.x > frames[0].position.x, "the first page: the large frame on the left")


func test_a_name_is_on_a_plate_once_and_never_in_a_balloon() -> void:
	var page := ComicPage.new()
	add_child_autofree(page)
	assert_true(page.open("mara_first"))
	await wait_process_frames(2)
	var named: Dictionary = {}
	var guard := 0
	while page.is_open() and guard < 60:
		guard += 1
		for f in page.frames():
			for p in f.plates:
				named[f.get_instance_id()] = true
			for b in f.balloons:
				assert_false(str(b["text"]).begins_with(str(b["name"])), "the name is not part of the words")
		page.step()
	var s := ComicScript.read()
	var plates: Dictionary = {}  # who → how many plates over the whole talk
	var met: Dictionary = {}
	for pg: Dictionary in s.talks["mara_first"]["pages"]:
		for panel: Dictionary in pg["panels"]:
			for who: String in panel["cast"]:
				if not met.has(who):
					met[who] = true
					plates[who] = 1
	assert_eq(plates.size(), 2, "Mara and the captain")
	page = ComicPage.new()
	add_child_autofree(page)
	page.open("mara_first")
	await wait_process_frames(2)
	var first := page.frames()[0]
	assert_eq(first.plates.size(), 2, "both are introduced where they are first seen")
	assert_eq(page.frames()[1].plates.size(), 0, "and not again")
	assert_eq(page.frames()[2].plates.size(), 0)
	var source := FileAccess.get_file_as_string("res://scripts/ui/comic_frame.gd")
	assert_false(source.contains("b[\"name\"]).to_upper()"), "the frame no longer letters a name into a balloon")


func test_a_balloon_is_an_oval_whose_short_tail_points_at_the_mouth() -> void:
	var page := ComicPage.new()
	add_child_autofree(page)
	assert_true(page.open("mara_first"))
	await wait_process_frames(2)
	for f in page.frames():
		for b in f.balloons:
			var rect: Rect2 = b["rect"]
			var mouth: Vector2 = f.actors[b["who"]]["mouth"]
			var base: Vector2 = b["base"]
			var tip: Vector2 = b["tip"]
			var u := (base - rect.get_center()) / (rect.size * 0.5)
			assert_almost_eq(u.length(), 1.0, 0.02, "the tail leaves the oval's edge")
			assert_gt((tip - base).normalized().dot((mouth - base).normalized()), 0.99, "towards the speaker's mouth")
			assert_lt(tip.distance_to(base), 45.0, "and is short: it does not cross a face")
			assert_gt(rect.size.x, f._text_size(str(b["text"]), rect.size.x).x * 0.9, "the words have room")
			assert_true(Rect2(Vector2.ZERO, f.size).grow(1.0).encloses(rect), "the balloon is inside its frame")
	assert_eq(page.frames()[1].balloons[0]["voice"], "shout", "Mara's first line is said in anger: the balloon bristles")
	assert_eq(page.frames()[2].balloons[0]["voice"], "say")
	assert_eq(ComicScript.VOICES, ["say", "shout", "thought"] as Array[String])
	var bad := ComicScript.new()
	bad.cast = {"a": {"face": "captain"}}
	bad.backdrops = {"x": {}}
	bad.talks = {"t": {"backdrop": "x", "pages": [{"panels": [{"shot": "close", "cast": ["a"], "lines": [["a", "K", "neutral", "sung"]]}]}]}}
	assert_true(", ".join(bad.problems([])).contains("unknown voice sung"))
	assert_gt(ComicFrame._cloud(Rect2(0, 0, 200, 100)).size(), 40, "a thought is a cloud")
	assert_gt(ComicFrame.FONT_SIZE, 18, "the lettering is larger than it was")


func test_the_second_page_is_laid_out_the_other_way_round() -> void:
	var page := ComicPage.new()
	add_child_autofree(page)
	assert_true(page.open("mara_first"))
	await wait_process_frames(2)
	var first_x := page.frames()[0].position.x
	var guard := 0
	while page.reader().page() == 0 and guard < 30:
		guard += 1
		page.step()
	if page.is_open() and page.frames().size() > 1:
		var xs: Array[float] = []
		for f in page.frames():
			xs.append(f.position.x)
		assert_true(page.frames()[0].position.x >= xs.min(), "frames are still inside the sheet")
		if page.frames().size() == 3:
			assert_gt(page.frames()[0].position.x, first_x, "the large frame has moved to the right")


func test_the_pages_are_lettered_in_the_projects_own_font() -> void:
	assert_true(FileAccess.file_exists(ComicPage.FONT_FILE))
	assert_true(FileAccess.get_file_as_string("res://fonts/OFL.txt").contains("SIL OPEN FONT LICENSE Version 1.1"), "its licence travels with it")
	var f := ComicPage.font()
	assert_true(f is FontFile, "not a system face: the same letters on every machine")
	assert_eq(f.get_font_name(), "Comic Relief")
	for letter: String in ["Я", "ж", "ё", "é", "Q", "—", "«"]:
		assert_true(f.has_char(letter.unicode_at(0)), "it has " + letter)

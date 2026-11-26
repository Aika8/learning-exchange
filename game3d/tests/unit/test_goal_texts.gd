## intent/04-guide-the-player.md invariant 4: every goal of Goals has a hint text in ru and en.
extends GutTest


func test_every_goal_has_ru_and_en_text() -> void:
	var cat := Locale.load_catalogue(Locale.CATALOGUE)
	var ru: Translation = cat["ru"]
	var en: Translation = cat["en"]
	assert_gt(Goals.IDS.size(), 0)
	for id: String in Goals.IDS:
		var key := "GOAL_" + id
		assert_ne(str(ru.get_message(key)), "", "ru missing " + key)
		assert_ne(str(en.get_message(key)), "", "en missing " + key)
		assert_ne(str(ru.get_message(key)), key, "ru text is the key itself: " + key)
		assert_ne(str(en.get_message(key)), key, "en text is the key itself: " + key)


func test_goal_hint_key_has_text() -> void:
	var en: Translation = Locale.load_catalogue(Locale.CATALOGUE)["en"]
	var g := Goals.next(GameFlow.State.PORT, {})
	assert_ne(str(en.get_message(g["hint_key"])), "", "hint_key of a fresh game has no text")

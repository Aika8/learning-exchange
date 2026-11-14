## ADR-0014: every key exists in ru and en, every key used in code is in the catalogue, every Problem code is translated.
extends GutTest

const CODE_DIRS := ["res://scripts"]
const KEY_RE := "\"((?:GAME|MENU|LANG|HARBOUR|LADDER|BALANCES?|FORM|FEE|ORDERS|TAPE|SIDE|TYPE|STATUS|ERR)_[A-Z0-9_]*)\""


func _catalogue() -> Dictionary:
	return Locale.load_catalogue(Locale.CATALOGUE)


func _keys() -> PackedStringArray:
	var t: Translation = _catalogue()["ru"]
	var out := PackedStringArray()
	for k: StringName in t.get_message_list():
		out.append(str(k))
	return out


func test_both_locales_have_every_key() -> void:
	var cat := _catalogue()
	assert_has(cat, "ru")
	assert_has(cat, "en")
	var ru: Translation = cat["ru"]
	var en: Translation = cat["en"]
	assert_gt(ru.get_message_count(), 50)
	for k in _keys():
		assert_ne(str(ru.get_message(k)), "", "ru missing " + k)
		assert_ne(str(en.get_message(k)), "", "en missing " + k)
	assert_eq(ru.get_message_count(), en.get_message_count())


func test_format_placeholders_match() -> void:
	var cat := _catalogue()
	for k in _keys():
		var ru := str((cat["ru"] as Translation).get_message(k))
		var en := str((cat["en"] as Translation).get_message(k))
		assert_eq(ru.count("%s"), en.count("%s"), "placeholders differ in " + k)


func test_keys_used_in_code_exist() -> void:
	var keys := _keys()
	var re := RegEx.create_from_string(KEY_RE)
	var used := 0
	for dir: String in CODE_DIRS:
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".gd"):
				continue
			var src := FileAccess.get_file_as_string(dir.path_join(f))
			for m in re.search_all(src):
				var k := m.get_string(1)
				if k.ends_with("_"):
					continue  # prefix built at runtime, e.g. "STATUS_" + status — covered below
				used += 1
				assert_has(keys, k, "%s uses unknown key %s" % [f, k])
	assert_gt(used, 30)


func test_contract_enums_are_translated() -> void:
	var keys := _keys()
	var spec := FileAccess.get_file_as_string("res://../api/openapi.yaml")
	if spec.is_empty():
		spec = FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("../api/openapi.yaml"))
	assert_ne(spec, "", "api/openapi.yaml must be readable from the game folder")
	for code in ["UNAUTHORIZED", "BAD_REQUEST", "INVALID_NAME", "INVALID_ORDER", "INVALID_AMOUNT", "INSUFFICIENT_FUNDS",
			"NO_LIQUIDITY", "UNKNOWN_INSTRUMENT", "UNKNOWN_ORDER", "UNKNOWN_ACCOUNT", "NOT_OWNER", "NOT_OPEN", "ACCOUNT_EXISTS"]:
		assert_true(spec.contains(code), "contract lost " + code)
		assert_has(keys, "ERR_" + code)
	for s in ["NEW", "PARTIALLY_FILLED", "FILLED", "CANCELLED", "EXPIRED"]:
		assert_has(keys, "STATUS_" + s)
	assert_has(keys, "ERR_NETWORK")


func test_switching_locale_notifies_and_translates() -> void:
	watch_signals(Locale)
	Locale.set_locale("en")
	assert_signal_emitted_with_parameters(Locale, "locale_changed", ["en"])
	assert_eq(tr("FORM_BUY"), "Buy")
	Locale.set_locale("ru")
	assert_eq(tr("FORM_BUY"), "Купить")
	Locale.set_locale("xx")
	assert_eq(Locale.current(), "ru", "unknown locale falls back to ru")

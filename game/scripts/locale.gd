## Pattern: Message catalogue + Observer — UI knows only keys; switching language is an event scenes observe.
## See docs/adr/0014-i18n-runtime-switch.md
extends Node

signal locale_changed(code: String)

const CATALOGUE := "res://i18n/strings.csv"
const LOCALES: Array[String] = ["ru", "en"]
const FALLBACK := "ru"


func _ready() -> void:
	for t: Translation in load_catalogue(CATALOGUE).values():
		TranslationServer.add_translation(t)
	set_locale(FALLBACK)


## Reads the CSV catalogue (keys,ru,en) into one Translation per locale.
static func load_catalogue(path: String) -> Dictionary:
	var result: Dictionary = {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("i18n catalogue not found: %s" % path)
		return result
	var header := file.get_csv_line()
	for i in range(1, header.size()):
		var t := Translation.new()
		t.locale = header[i]
		result[header[i]] = t
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() < header.size() or row[0].is_empty():
			continue
		for i in range(1, header.size()):
			(result[header[i]] as Translation).add_message(row[0], row[i])
	return result


func set_locale(code: String) -> void:
	TranslationServer.set_locale(code if code in LOCALES else FALLBACK)
	locale_changed.emit(current())


func current() -> String:
	return TranslationServer.get_locale().substr(0, 2)


func toggle() -> void:
	set_locale("en" if current() == "ru" else "ru")

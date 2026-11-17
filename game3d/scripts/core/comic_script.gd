## Pattern: Data-driven script — a talk is data (pages → panels → balloons), loaded and checked here; the words are
## i18n keys. See docs/adr/0027-game3d-talk-as-comic-pages.md
class_name ComicScript
extends RefCounted

const PATH := "res://data/talks.json"
const WORDS := "res://i18n/talk.csv"
const SHOTS: Array[String] = ["close", "two", "wide", "low"]
const POSES: Array[String] = ["stand", "talk", "point", "think", "shrug", "bow"]
const MAX_PANELS := 4
const MAX_LINES := 2
const MAX_CHARS := 150  ## a balloon longer than this covers the picture

var cast: Dictionary = {}
var backdrops: Dictionary = {}
var talks: Dictionary = {}


static func read(path: String = PATH) -> ComicScript:
	var s := ComicScript.new()
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Dictionary:
		s.cast = data.get("cast", {})
		s.backdrops = data.get("backdrops", {})
		s.talks = data.get("talks", {})
	return s


func has(id: String) -> bool:
	return talks.has(id)


func reader(id: String) -> ComicReader:
	return ComicReader.new(talks[id])


## Every i18n key the data uses.
func keys() -> PackedStringArray:
	var out := PackedStringArray()
	for c: Dictionary in cast.values():
		out.append(str(c.get("name", "")))
	for t: Dictionary in talks.values():
		for page: Dictionary in t.get("pages", []):
			for panel: Dictionary in page.get("panels", []):
				if panel.has("caption"):
					out.append(str(panel["caption"]))
				for line: Array in panel.get("lines", []):
					out.append(str(line[1]))
	return out


## What is wrong with the data; `words` is locale → Translation (every key must have text in each).
func problems(words: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if talks.is_empty():
		out.append("no talks")
	for id: String in talks:
		var t: Dictionary = talks[id]
		if not backdrops.has(t.get("backdrop", "")):
			out.append("%s: unknown backdrop" % id)
		var pages: Array = t.get("pages", [])
		if pages.is_empty():
			out.append("%s: no pages" % id)
		for page: Dictionary in pages:
			var panels: Array = page.get("panels", [])
			if panels.is_empty() or panels.size() > MAX_PANELS:
				out.append("%s: a page has %d panels" % [id, panels.size()])
			for panel: Dictionary in panels:
				if not panel.get("shot", "") in SHOTS:
					out.append("%s: unknown shot %s" % [id, panel.get("shot", "")])
				var who: Array = panel.get("cast", [])
				if who.is_empty() or who.size() > 2:
					out.append("%s: a panel shows one or two people" % id)
				for w: String in who:
					if not cast.has(w):
						out.append("%s: %s is not in the cast" % [id, w])
				for w: String in panel.get("pose", {}):
					if not w in who or not panel["pose"][w] in POSES:
						out.append("%s: pose for %s" % [id, w])
				var lines: Array = panel.get("lines", [])
				if lines.size() > MAX_LINES:
					out.append("%s: more than %d balloons in a panel" % [id, MAX_LINES])
				if lines.is_empty() and not panel.has("caption"):
					out.append("%s: a silent panel needs a caption" % id)
				for line: Array in lines:
					if not cast.has(line[0]):
						out.append("%s: speaker %s is not in the cast" % [id, line[0]])
	for key in keys():
		for locale: String in words:
			var text := str((words[locale] as Translation).get_message(key))
			if text.is_empty():
				out.append("%s: no %s text" % [key, locale])
			elif text.length() > MAX_CHARS:
				out.append("%s: %s text is %d characters" % [key, locale, text.length()])
	return out

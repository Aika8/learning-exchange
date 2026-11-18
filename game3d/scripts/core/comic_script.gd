## Pattern: Data-driven script — a talk is data (pages → panels → balloons, each with the face it is said with), loaded and checked here; the words are
## i18n keys. See docs/adr/0027-game3d-talk-as-comic-pages.md
class_name ComicScript
extends RefCounted

const PATH := "res://data/talks.json"
const WORDS := "res://i18n/talk.csv"
const SHOTS: Array[String] = ["close", "two", "wide", "low"]
const EMOTIONS: Array[String] = ["neutral", "happy", "surprised", "sly", "worried", "angry"]  ## the faces of the expression sheets
const FACES: Array[String] = ["captain", "mara", "vetla", "olva", "oldsailor", "merchant", "chronicler", "keeper", "sailor", "sailor2", "child", "townsman",
	"banquiere", "boulangere", "garcon", "libraire", "gardienne", "noir_broker", "noir_tramp", "noir_youth", "noir_lady",
	"crypto_trader", "crypto_miner", "crypto_dreamer", "crypto_analyst", "bot_trader", "bot_miner", "bot_info",
	"toy_gentleman", "toy_lady", "toy_grandpa", "toy_granny", "toy_child", "pyr_host", "pyr_barker", "pyr_happy", "pyr_worried", "pyr_sweeper",
	"deco_aviator", "deco_mechanic", "deco_crew", "deco_marshal", "deco_lady",
	"oil_merchant", "oil_lady", "oil_market", "oil_father", "oil_child", "oil_grandpa", "oil_granny"]  ## heroes who have a sheet
const VOICES: Array[String] = ["say", "shout", "thought"]  ## a line's optional fourth word: the shape of its balloon
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


## The locale talk `id` is spoken in ("" = the game's language).
func tongue(id: String) -> String:
	return str(talks.get(id, {}).get("speak", ""))


## The catalogues the talks take their words from.
static func catalogues() -> Array:
	var out: Array = [Locale.load_catalogue(WORDS)]
	out.append_array(IslandTongue.catalogues().values())
	return out


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


## What is wrong with the data. `catalogues`: each a {locale → Translation}; a key must have text in every locale
## of the catalogue it lives in, and a talk spoken in an island's tongue needs that tongue's column.
func problems(catalogues: Array) -> Array[String]:
	var out: Array[String] = []
	if talks.is_empty():
		out.append("no talks")
	for c: String in cast:
		var face := str(cast[c].get("face", ""))
		if not face.is_empty() and not face in FACES:
			out.append("%s: no expression sheet called %s" % [c, face])
		elif face.is_empty() and not cast[c].has("look"):
			out.append("%s: neither a sheet nor a look to draw" % c)
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
				for w: String in panel.get("mood", {}):
					if not w in who or not panel["mood"][w] in EMOTIONS:
						out.append("%s: mood of %s" % [id, w])
				var lines: Array = panel.get("lines", [])
				if lines.size() > MAX_LINES:
					out.append("%s: more than %d balloons in a panel" % [id, MAX_LINES])
				if lines.is_empty() and not panel.has("caption"):
					out.append("%s: a silent panel needs a caption" % id)
				for line: Array in lines:
					if not cast.has(line[0]):
						out.append("%s: speaker %s is not in the cast" % [id, line[0]])
					elif not line[0] in who:
						out.append("%s: %s speaks but is not in the frame" % [id, line[0]])
					if line.size() > 2 and not line[2] in EMOTIONS:
						out.append("%s: unknown emotion %s" % [id, line[2]])
					if line.size() > 3 and not line[3] in VOICES:
						out.append("%s: unknown voice %s" % [id, line[3]])
	var spoken: Dictionary = {}  # key → the tongue of the talk it is said in
	for id: String in talks:
		var tongue := str(talks[id].get("speak", ""))
		for page: Dictionary in talks[id].get("pages", []):
			for panel: Dictionary in page.get("panels", []):
				for line: Array in panel.get("lines", []):
					spoken[str(line[1])] = tongue
				if panel.has("caption"):
					spoken[str(panel["caption"])] = tongue
	for key in keys():
		var home: Dictionary = {}
		for cat: Dictionary in catalogues:
			for locale: String in cat:
				if not str((cat[locale] as Translation).get_message(key)).is_empty():
					home = cat
		if home.is_empty():
			out.append("%s: no text" % key)
			continue
		var tongue := str(spoken.get(key, ""))
		if not tongue.is_empty() and not home.has(tongue):
			out.append("%s: no %s text" % [key, tongue])
		for locale: String in home:
			var text := str((home[locale] as Translation).get_message(key))
			if text.is_empty():
				out.append("%s: no %s text" % [key, locale])
			elif text.length() > MAX_CHARS:
				out.append("%s: %s text is %d characters" % [key, locale, text.length()])
	return out

## Pattern: Message catalogue per island — the key is the same, the island you stand on picks the language it is
## shown in, the game's language is the gloss. See docs/adr/0028-game3d-amber-cliff-speaks-french.md
class_name IslandTongue
extends RefCounted

const TONGUES := {"amber": "fr"}  ## island id → the locale its people speak and write
const WORDS := {"fr": "res://i18n/amber.csv"}  ## locale → the catalogue that has that column

static var _catalogues: Dictionary = {}


## The locale spoken on an island; "" = the game's own language.
static func of(island_id: String) -> String:
	return TONGUES.get(island_id, "")


## Every catalogue an island tongue needs: path → {locale → Translation}.
static func catalogues() -> Dictionary:
	for locale: String in WORDS:
		if not _catalogues.has(WORDS[locale]):
			_catalogues[WORDS[locale]] = Locale.load_catalogue(WORDS[locale])
	return _catalogues


## `key` in `locale`, or "" when that tongue has no such word.
static func say(key: String, locale: String) -> String:
	if not WORDS.has(locale):
		return ""
	var t: Translation = (catalogues()[WORDS[locale]] as Dictionary).get(locale)
	return str(t.get_message(key)) if t != null else ""


## What to show for `key` on island `island_id`: the island's words when it has them, else the game's.
static func shown(key: String, island_id: String) -> String:
	var text := say(key, of(island_id))
	return text if not text.is_empty() else TranslationServer.translate(key)

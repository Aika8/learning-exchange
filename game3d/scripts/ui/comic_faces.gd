## The drawn portraits of the comic pages: Aika's expression sheets (docs/design/concepts/07…23) cut into one picture
## per hero and emotion, `art/portraits/<face>_<emotion>.jpg`. Loaded straight from the file, so nothing has to be
## imported. See docs/adr/0027-game3d-talk-as-comic-pages.md
class_name ComicFaces
extends RefCounted

const DIR := "res://art/cutouts"  ## the portraits cut out of their paper (`tools/cut_portraits.gd`, ADR-0037)
const SHEETS := "res://art/portraits"  ## as they were cut from the sheets, paper and all: what the cut-outs are made from
const RULES := "res://data/cutouts.json"
const MOUTH := 0.47  ## how far down a bust the mouth is, when the rules do not say
const EMOTIONS: Array[String] = ["neutral", "happy", "surprised", "sly", "worried", "angry"]
const FACES: Array[String] = ["captain", "mara", "vetla", "olva", "oldsailor", "merchant", "chronicler", "keeper", "sailor", "sailor2", "child", "townsman",
	"banquiere", "boulangere", "garcon", "libraire", "gardienne", "noir_broker", "noir_tramp", "noir_youth", "noir_lady",
	"crypto_trader", "crypto_miner", "crypto_dreamer", "crypto_analyst", "bot_trader", "bot_miner", "bot_info",
	"toy_gentleman", "toy_lady", "toy_grandpa", "toy_granny", "toy_child", "pyr_host", "pyr_barker", "pyr_happy", "pyr_worried", "pyr_sweeper",
	"deco_aviator", "deco_mechanic", "deco_crew", "deco_marshal", "deco_lady",
	"oil_merchant", "oil_lady", "oil_market", "oil_father", "oil_child", "oil_grandpa", "oil_granny"]  ## heroes with a sheet
## Heroes drawn once, with no expression sheet yet: their one picture stands for every emotion.
const ONE_FACE: Array[String] = ["noir_broker", "noir_tramp", "noir_youth", "noir_lady",
	"crypto_trader", "crypto_miner", "crypto_dreamer", "crypto_analyst", "bot_trader", "bot_miner", "bot_info",
	"toy_gentleman", "toy_lady", "toy_grandpa", "toy_granny", "toy_child", "pyr_host", "pyr_barker", "pyr_happy", "pyr_worried", "pyr_sweeper",
	"deco_aviator", "deco_mechanic", "deco_crew", "deco_marshal", "deco_lady",
	"oil_merchant", "oil_lady", "oil_market", "oil_father", "oil_child", "oil_grandpa", "oil_granny"]
const ASPECT := 0.55  ## width / height of a portrait when nothing better is known (the stand-in)

static var _cache: Dictionary = {}
static var _rules: Dictionary = {}


static func has(face: String) -> bool:
	return face in FACES


static func path(face: String, emotion: String) -> String:
	return "%s/%s_%s.webp" % [DIR, face, emotion]


static func rule(face: String) -> Dictionary:
	if _rules.is_empty():
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(RULES))
		_rules = data if data is Dictionary else {"": {}}
	return _rules.get(face, {})


## "cut" — a figure with nothing round it; "oval" — a painted bust in an oval; "card" — a picture with a drawn
## background of its own, shown with a border.
static func kind(face: String) -> String:
	var r := rule(face)
	return "card" if r.get("card", false) else ("oval" if r.get("oval", false) else "cut")


## How far down `face`'s pictures the mouth is (0 top … 1 bottom): where the tail of a balloon points.
static func mouth(face: String) -> float:
	return float(rule(face).get("mouth", MOUTH))


## The portrait of `face` feeling `emotion`; null when there is no such picture.
static func texture(face: String, emotion: String) -> Texture2D:
	if face in ONE_FACE:
		emotion = "neutral"
	var key := face + "/" + emotion
	if not _cache.has(key):
		var img := Image.new()
		var found := FileAccess.file_exists(path(face, emotion)) and img.load(ProjectSettings.globalize_path(path(face, emotion))) == OK
		_cache[key] = ImageTexture.create_from_image(img) if found else null
	return _cache[key]


## Width / height of `face`'s portraits: every sheet is cut to its own proportions.
static func aspect(face: String) -> float:
	var t := texture(face, "neutral")
	return float(t.get_width()) / float(t.get_height()) if t != null else ASPECT

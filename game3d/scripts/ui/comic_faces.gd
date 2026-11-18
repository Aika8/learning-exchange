## The drawn portraits of the comic pages: Aika's expression sheets (docs/design/concepts/07…23) cut into one picture
## per hero and emotion, `art/portraits/<face>_<emotion>.jpg`. Loaded straight from the file, so nothing has to be
## imported. See docs/adr/0027-game3d-talk-as-comic-pages.md
class_name ComicFaces
extends RefCounted

const DIR := "res://art/portraits"
const EMOTIONS: Array[String] = ["neutral", "happy", "surprised", "sly", "worried", "angry"]
const FACES: Array[String] = ["captain", "mara", "vetla", "olva", "oldsailor", "merchant", "chronicler", "keeper", "sailor", "sailor2", "child", "townsman",
	"banquiere", "boulangere", "garcon", "libraire", "gardienne", "noir_broker", "noir_tramp", "noir_youth", "noir_lady",
	"crypto_trader", "crypto_miner", "crypto_dreamer", "crypto_analyst", "bot_trader", "bot_miner", "bot_info",
	"toy_gentleman", "toy_lady", "toy_grandpa", "toy_granny", "toy_child"]  ## heroes with a sheet
## Heroes drawn once, with no expression sheet yet: their one picture stands for every emotion.
const ONE_FACE: Array[String] = ["noir_broker", "noir_tramp", "noir_youth", "noir_lady",
	"crypto_trader", "crypto_miner", "crypto_dreamer", "crypto_analyst", "bot_trader", "bot_miner", "bot_info",
	"toy_gentleman", "toy_lady", "toy_grandpa", "toy_granny", "toy_child"]
const ASPECT := 0.55  ## width / height of a portrait when nothing better is known (the stand-in)

static var _cache: Dictionary = {}


static func has(face: String) -> bool:
	return face in FACES


static func path(face: String, emotion: String) -> String:
	return "%s/%s_%s.jpg" % [DIR, face, emotion]


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

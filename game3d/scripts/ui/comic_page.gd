## A talk shown as a comic page: a paper sheet with one to four frames; behind the speakers the place they stand
## in (a softened picture of the scene, taken as the page opens); oval balloons with tails to the mouth; a name
## plate the first time somebody is seen; captions. ADR-0037 redrew the page of ADR-0027. E / Enter / click — next, Esc — close. The page only draws what `ComicReader`
## says is visible. See docs/adr/0027-game3d-talk-as-comic-pages.md
class_name ComicPage
extends Control

signal finished(id: String)

const PAPER := Color("f6edd9")
const INK := Color("1b1a1f")
const CAPTION := Color("f2cf7a")
const TAG := Color("9c3524")
const GUTTER := 14.0
## frames of a page by count, in shares of the sheet: x, y, w, h
const LAYOUTS := {
	1: [Rect2(0, 0, 1, 1)],
	2: [Rect2(0, 0, 0.5, 1), Rect2(0.5, 0, 0.5, 1)],
	3: [Rect2(0, 0, 0.42, 1), Rect2(0.42, 0, 0.58, 0.5), Rect2(0.42, 0.5, 0.58, 0.5)],
	4: [Rect2(0, 0, 0.56, 0.5), Rect2(0.56, 0, 0.44, 0.5), Rect2(0, 0.5, 0.44, 0.5), Rect2(0.44, 0.5, 0.56, 0.5)],
}

var script_data: ComicScript
var speak := ""  ## the locale this talk is spoken in ("" = the game's language); the game's language is then the gloss
var id := ""
var _reader: ComicReader
var _vars: Dictionary = {}
var _sheet: Panel
var _frames: Array[ComicFrame] = []
var _hint: Label
var _count: Label
var _page := -1
var _place: Texture2D  ## the scene as it was when the talk began, softened: what the frames show behind the people
var _met: Dictionary = {}  ## who has had a name plate in this talk already

const FONT_FILE := "res://fonts/comic.ttf"  ## the lettering: Comic Relief Regular (SIL OFL 1.1, `fonts/OFL.txt`), Latin and Cyrillic (ADR-0037)
static var _lettering: Font
const ART_DIR := "res://art/comic"
static var _art: Dictionary = {}  ## "talk/page-panel" → the picture, or null when there is none


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.05, 0.08, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_sheet = Panel.new()
	_sheet.name = "Sheet"
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paper := Hud.box(PAPER, INK, 3, 4)
	paper.shadow_size = 18
	_sheet.add_theme_stylebox_override("panel", paper)
	add_child(_sheet)
	_hint = Hud.text("COMIC_NEXT", 15, Hud.TEXT)
	add_child(_hint)
	_count = Hud.text("", 15, Hud.MUTED)
	_count.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	add_child(_count)


## The lettering of the pages: the project's own comic font when it has one, else a rounded system face.
static func font() -> Font:
	if _lettering == null:
		if FileAccess.file_exists(FONT_FILE):
			var file := FontFile.new()
			if file.load_dynamic_font(FONT_FILE) == OK:
				_lettering = file
		if _lettering == null:
			var f := SystemFont.new()
			f.font_names = PackedStringArray(["Avenir Next Rounded", "Arial Rounded MT Bold", "Avenir Next", "Helvetica Neue", "Noto Sans", "DejaVu Sans", "Arial"])
			f.font_weight = 600
			_lettering = f
	return _lettering


## The place of the talk: the picture on screen as the page opens (the island in its own technique, where the
## captain stands), made small and soft so that it is a backdrop and not a second picture. Null without a screen.
## Panel `panel` of page `page` (both from 0) of talk `talk` drawn as a picture — `art/comic/<talk>/<page>-<panel>.jpg`,
## counted from 1, as docs/design/comic-script.md names them — or null when there is none: the frame is then put
## together from the place and the figures, as before.
static func art(talk: String, page: int, panel: int) -> Texture2D:
	var key := "%s/%d-%d" % [talk, page + 1, panel + 1]
	if not _art.has(key):
		_art[key] = null
		for ext in ["jpg", "png"]:
			var file := "%s/%s.%s" % [ART_DIR, key, ext]
			var img := Image.new()
			if FileAccess.file_exists(file) and img.load(ProjectSettings.globalize_path(file)) == OK:
				_art[key] = ImageTexture.create_from_image(img)
				break
	return _art[key]


func place() -> Texture2D:
	return _place


func _take_place() -> void:
	_place = null
	if DisplayServer.get_name() == "headless" or not is_inside_tree():
		return
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		return
	var w := img.get_width()
	var h := img.get_height()
	img = img.get_region(Rect2i(int(w * 0.08), int(h * 0.16), int(w * 0.84), int(h * 0.68)))  # without the HUD's edges
	img.resize(96, 44, Image.INTERPOLATE_LANCZOS)  # small…
	img.resize(384, 176, Image.INTERPOLATE_CUBIC)  # …and soft
	_place = ImageTexture.create_from_image(img)


func is_open() -> bool:
	return visible


## Opens talk `talk_id`; `vars` fill the `{name}` slots of its words.
func open(talk_id: String, vars: Dictionary = {}) -> bool:
	if script_data == null:
		script_data = ComicScript.read()
	if not script_data.has(talk_id):
		return false
	id = talk_id
	speak = script_data.tongue(talk_id)
	_vars = vars
	_reader = script_data.reader(talk_id)
	_page = -1
	_met = {}
	_take_place()
	visible = true
	_paint()
	return true


func close() -> void:
	if not visible:
		return
	visible = false
	_clear()
	finished.emit(id)


func step() -> void:
	if _reader == null or not _reader.step():
		close()
	else:
		_paint()


## The words of `key` as they are spoken in this talk, with the slots filled.
func say(key: String) -> String:
	var text := IslandTongue.say(key, speak)
	return (text if not text.is_empty() else tr(key)).format(_vars)


## The same words in the game's language, when the island speaks another one.
func gloss(key: String) -> String:
	return tr(key).format(_vars) if not speak.is_empty() else ""


func reader() -> ComicReader:
	return _reader


func frames() -> Array[ComicFrame]:
	return _frames


func _clear() -> void:
	for f in _frames:
		f.queue_free()
	_frames.clear()


func _paint() -> void:
	var area := get_viewport_rect().size
	var size_px := Vector2(minf(1240.0, area.x - 120.0), minf(780.0, area.y - 130.0))
	_sheet.size = size_px
	_sheet.position = ((area - size_px) / 2.0 - Vector2(0, 14)).round()
	_hint.position = _sheet.position + Vector2(0, size_px.y + 12)
	_count.position = _sheet.position + Vector2(size_px.x - 150, size_px.y + 12)
	_count.text = tr("COMIC_PAGE").format({"page": _reader.page() + 1, "pages": _reader.pages()})
	_count.visible = _reader.pages() > 1
	var panels := _reader.panels()
	if _reader.page() != _page:
		_page = _reader.page()
		_clear()
		var talk: Dictionary = script_data.talks[id]
		var backdrop: Dictionary = script_data.backdrops.get(talk.get("backdrop", ""), {})
		var inner := size_px - Vector2(GUTTER, GUTTER)
		var layout: Array = LAYOUTS[clampi(panels.size(), 1, 4)]
		var mirrored := _page % 2 == 1  # the next page is laid out the other way round: pages do not all look alike
		for i in mini(panels.size(), 4):
			var r: Rect2 = layout[i]
			if mirrored:
				r.position.x = 1.0 - r.position.x - r.size.x
			var f := ComicFrame.new()
			f.position = (Vector2(GUTTER, GUTTER) + r.position * inner).round()
			f.size = (r.size * inner - Vector2(GUTTER, GUTTER)).round()
			_sheet.add_child(f)
			var newcomers: Array = []
			for who: String in panels[i].get("cast", []):
				if not _met.has(who):
					_met[who] = true
					newcomers.append(who)
			f.setup(self, panels[i], script_data.cast, backdrop, i + _page, newcomers, art(id, _page, i))
			_frames.append(f)
	for i in _frames.size():
		_frames[i].show_lines(_reader.shown(i))


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		get_viewport().set_input_as_handled()
		step()
	elif event is InputEventKey:
		if (event as InputEventKey).keycode == KEY_T:  # hold T: the words in the game's language
			for f in _frames:
				f.show_gloss(event.pressed)
		get_viewport().set_input_as_handled()  # the world does not hear keys while a page is open

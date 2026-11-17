## A talk shown as a comic page: a paper sheet with one to four frames, the speakers in them, speech balloons with
## tails and name tags, captions. E / Enter / click — next, Esc — close. The page only draws what `ComicReader`
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


static func font() -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Avenir Next", "Helvetica Neue", "Noto Sans", "DejaVu Sans", "Arial"])
	f.font_weight = 600
	return f


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
		for i in mini(panels.size(), 4):
			var r: Rect2 = layout[i]
			var f := ComicFrame.new()
			f.position = (Vector2(GUTTER, GUTTER) + r.position * inner).round()
			f.size = (r.size * inner - Vector2(GUTTER, GUTTER)).round()
			_sheet.add_child(f)
			f.setup(self, panels[i], script_data.cast, backdrop)
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

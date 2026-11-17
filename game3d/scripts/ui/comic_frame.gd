## One frame of a comic page: the picture (ComicShot), a black border, a caption box, balloons with tails.
## See docs/adr/0027-game3d-talk-as-comic-pages.md
class_name ComicFrame
extends Control

const FONT_SIZE := 17
const PAD := Vector2(14, 9)

var shot: ComicShot
var balloons: Array[Dictionary] = []  ## {who, rect, tip, text, gloss, name}
var caption := ""
var caption_gloss := ""
var _shown := -1
var _gloss := false
var _font: Font
var _picture: TextureRect
var _settle := 4


func setup(page: ComicPage, panel: Dictionary, cast: Dictionary, backdrop: Dictionary) -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ComicPage.font()
	shot = ComicShot.build(panel, cast, backdrop, Vector2i(size))
	add_child(shot.viewport)
	_picture = TextureRect.new()
	_picture.texture = shot.viewport.get_texture()
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_SCALE
	_picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_picture.set_anchors_preset(Control.PRESET_FULL_RECT)
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picture.show_behind_parent = true
	add_child(_picture)
	if panel.has("caption"):
		caption = page.say(panel["caption"])
		caption_gloss = page.gloss(panel["caption"])
	var top := 12.0 + (_text_size(caption, size.x - 60).y + 2 * PAD.y + 10 if not caption.is_empty() else 0.0)
	var lines: Array = panel.get("lines", [])
	var alone := (panel.get("cast", []) as Array).size() == 1
	var taken: Dictionary = {}  # side (−1 left, 1 right) → the y below the balloons already there
	for n in lines.size():
		var who: String = lines[n][0]
		var text := page.say(lines[n][1])
		var name := page.say(str(cast[who].get("name", "")))
		var head := shot.head(who) * size
		var width := clampf(size.x * (0.6 if lines.size() == 1 else 0.47), 170.0, 360.0)
		var body := _text_size(text, width - 2 * PAD.x)
		var w := maxf(body.x, _font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE - 4).x) + 2 * PAD.x
		var h := body.y + 2 * PAD.y + FONT_SIZE
		var side := -1 if head.x < size.x * 0.5 else 1
		if alone:  # alone in the frame: the first balloon goes to the emptier side, a second one opposite
			side = (1 if head.x < size.x * 0.55 else -1) * (1 if n == 0 else -1)
		var y: float = taken.get(side, top + (0.0 if n == 0 else 22.0))  # the answer hangs a little lower
		var rect := Rect2(Vector2(12.0 if side < 0 else size.x - w - 12.0, y), Vector2(w, h))
		balloons.append({"who": who, "rect": rect, "tip": rect.end, "base": rect.end, "text": text, "gloss": page.gloss(lines[n][1]), "name": name})
		taken[side] = rect.end.y + 24
	_place_tails()
	modulate.a = 0.0


func _text_size(text: String, width: float) -> Vector2:
	return _font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, FONT_SIZE)


func _process(_delta: float) -> void:
	if _settle > 0:  # the picture is drawn for a few frames (skinned people need one to take their pose), then kept
		_settle -= 1
		if _settle == 0:
			shot.freeze()
			_place_tails()
			queue_redraw()


func _place_tails() -> void:
	for b in balloons:
		var head := shot.head(b["who"]) * size
		var rect: Rect2 = b["rect"]
		var base := Vector2(clampf(head.x, rect.position.x + 26, rect.end.x - 26), rect.end.y)
		var tip := base.lerp(head, 0.6)
		tip.y = maxf(minf(tip.y, head.y - 14), base.y + 10)
		b["base"] = base
		b["tip"] = tip


## Shows the frame with its first `count` balloons; −1 hides the frame.
func show_lines(count: int) -> void:
	if count == _shown:
		return
	if _shown < 0 and count >= 0:
		create_tween().tween_property(self, "modulate:a", 1.0, 0.22)
	elif count < 0:
		modulate.a = 0.0
	_shown = count
	queue_redraw()


func show_gloss(on: bool) -> void:
	if on != _gloss:
		_gloss = on
		queue_redraw()


func shown() -> int:
	return _shown


func _draw() -> void:
	if not caption.is_empty():
		var text := caption_gloss if _gloss and not caption_gloss.is_empty() else caption
		var body := _text_size(text, size.x - 60)
		var box := Rect2(Vector2(10, 10), body + 2 * PAD)
		draw_rect(box, ComicPage.CAPTION)
		draw_rect(box, ComicPage.INK, false, 2.0)
		draw_multiline_string(_font, box.position + PAD + Vector2(0, FONT_SIZE), text, HORIZONTAL_ALIGNMENT_LEFT, body.x + 1, FONT_SIZE, -1, ComicPage.INK)
	for i in mini(maxi(_shown, 0), balloons.size()):
		var b := balloons[i]
		var rect: Rect2 = b["rect"]
		var style := Hud.box(Color.WHITE, ComicPage.INK, 2, 16)
		style.shadow_size = 0
		draw_style_box(style, rect)
		var base: Vector2 = b["base"]
		var tail := PackedVector2Array([base + Vector2(-11, -3), base + Vector2(11, -3), b["tip"]])
		draw_colored_polygon(tail, Color.WHITE)
		draw_line(tail[0] + Vector2(0, 3), tail[2], ComicPage.INK, 2.0, true)
		draw_line(tail[1] + Vector2(0, 3), tail[2], ComicPage.INK, 2.0, true)
		var at := rect.position + PAD
		draw_string(_font, at + Vector2(0, FONT_SIZE - 4), str(b["name"]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE - 5, ComicPage.TAG)
		var text: String = b["gloss"] if _gloss and not str(b["gloss"]).is_empty() else b["text"]
		draw_multiline_string(_font, at + Vector2(0, FONT_SIZE * 2), text, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 2 * PAD.x, FONT_SIZE, -1,
			Color("3a4a6a") if _gloss and not str(b["gloss"]).is_empty() else ComicPage.INK)
	draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)), ComicPage.INK, false, 3.0)

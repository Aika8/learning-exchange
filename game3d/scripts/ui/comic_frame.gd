## One frame of a comic page (ADR-0027, redrawn by ADR-0037): the place of the talk behind — a softened picture of
## the scene, each frame its own cut of it — the speakers as figures cut out of their sheets and standing on the
## frame's lower edge, oval balloons whose tails point at the mouth, a name plate the first time somebody is seen,
## a caption box, the marks comics put round a head, a clean black border.
class_name ComicFrame
extends Control

const FONT_SIZE := 19
const PLATE_SIZE := 15
const PAD := Vector2(16, 10)
## How tall a figure is, in frame heights, by shot. A close shot is taller than its frame: the frame cuts the bust.
const HEIGHT := {"close": 1.22, "low": 1.08, "two": 0.72, "wide": 0.58}  # two: room over the heads for what they say
## The part of the place seen behind, by shot: [how much of the picture's width, where its middle is, 0…1].
const VIEW := {"wide": [1.0, 0.5], "two": [0.66, 0.5], "close": [0.4, 0.42], "low": [0.5, 0.6]}
const SINK := 0.05  ## a figure's lower end is this far below the frame's edge: the frame cuts it, nothing hangs
const TINT := "shader_type canvas_item;
uniform float dim = 1.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	COLOR = vec4(c.rgb * dim, c.a);
}"

var actors: Dictionary = {}  ## cast id → {node, rect, head, mouth, face, side, kind}
var balloons: Array[Dictionary] = []  ## {who, rect, tip, base, text, gloss, name, emotion, voice}
var plates: Array[Dictionary] = []  ## name plates of the people first seen in this frame: {who, text, rect}
var mood: Dictionary = {}  ## cast id → the face they wear in this frame when they are not speaking
var caption := ""
var caption_gloss := ""
var feeling: Dictionary = {}  ## cast id → the emotion shown right now
var _shown := -1
var _gloss := false
var _font: Font
var _back: Back

static var _tint: Shader


## The place behind the people: a cut of the softened scene, or — when there is no picture of it — sky over
## ground in the backdrop's two colours; a wash of paper over it, and halftone dots only as a shade in one corner.
class Back:
	extends Control
	var place: Texture2D
	var view: Array = [1.0, 0.5]
	var sky := Color("f0dcb4")
	var ground := Color("7fb069")
	var corner := Vector2.ZERO
	var shift := 0.0  ## each frame of a page looks at a slightly different part of the place
	var art: Texture2D  ## a drawn panel (docs/design/comic-script.md): fills the frame, cut to it, nothing over it

	func _draw() -> void:
		var box := Rect2(Vector2.ZERO, size)
		if art != null:
			var full := art.get_size()
			var k := maxf(size.x / full.x, size.y / full.y)  # cover: the picture fills the frame, its middle kept
			var part := size / k
			draw_texture_rect_region(art, box, Rect2((full - part) * 0.5, part))
			return
		if place != null:
			var full := place.get_size()
			var w := full.x * float(view[0])
			var h := minf(w * size.y / size.x, full.y)
			w = h * size.x / size.y
			var cx := clampf(full.x * (float(view[1]) + shift), w * 0.5, full.x - w * 0.5)
			draw_texture_rect_region(place, box, Rect2(cx - w * 0.5, (full.y - h) * 0.45, w, h))
			draw_rect(box, Color(ComicPage.PAPER, 0.3))
		else:
			var horizon := size.y * 0.62
			draw_rect(Rect2(0, 0, size.x, horizon), sky.lerp(ComicPage.PAPER, 0.45))
			draw_rect(Rect2(0, horizon, size.x, size.y - horizon), ground.lerp(ComicPage.PAPER, 0.35))
			draw_rect(Rect2(0, horizon - 3, size.x, 6), ground.lerp(sky, 0.5).lerp(ComicPage.PAPER, 0.4))
		var reach := minf(size.x, size.y) * 0.62  # the shade of dots: one corner, fading out
		var y := 5.0
		while y < reach:
			var x := 5.0 + (7.0 if int(y / 12.0) % 2 == 1 else 0.0)
			while x < reach:
				var at := Vector2(x if corner.x < 1.0 else size.x - x, y)
				var k := 1.0 - Vector2(x, y).length() / reach
				if k > 0.08:
					draw_circle(at, 3.6 * k, Color(ComicPage.INK, 0.16))
				x += 14.0
			y += 12.0


## What a picture that is not a cut-out stands on: a white card with an ink border, or a dark oval.
class Mount:
	extends Control
	var oval := false

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if oval:
			draw_colored_polygon(ComicFrame._oval(r.grow_individual(4.0, 4.0, 4.0, 0.0), 40, true), Color("3a2a1c"))
		else:
			draw_rect(r.grow(5.0), Color.WHITE)
			draw_rect(r.grow(5.0), ComicPage.INK, false, 2.5)


## `art` is the panel drawn as a picture, or null: then the place and the figures are put together here.
func setup(page: ComicPage, panel: Dictionary, cast: Dictionary, backdrop: Dictionary, index: int = 0, introduce: Array = [], art: Texture2D = null) -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ComicPage.font()
	mood = panel.get("mood", {})
	var who_list: Array = panel.get("cast", [])
	var shot := str(panel.get("shot", "two"))
	_back = Back.new()
	_back.place = page.place()
	_back.view = VIEW.get(shot, VIEW["two"])
	_back.shift = (index % 3 - 1) * 0.12
	_back.sky = Color(str(backdrop.get("sky", "f0dcb4")))
	_back.ground = Color(str(backdrop.get("ground", "7fb069")))
	_back.corner = Vector2(1, 0) if who_list.size() == 1 else Vector2(0, 0)
	_back.size = size
	_back.show_behind_parent = true
	_back.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_back)
	_back.art = art
	var tails: Dictionary = panel.get("tail", {})  ## cast id → [x, y], shares of the frame: where that one's mouth is
	var lines: Array = panel.get("lines", [])
	var first_voice := str(lines[0][0]) if not lines.is_empty() else ""
	var tall := size.y * float(HEIGHT.get(shot, 0.86))
	for i in who_list.size():
		var who: String = who_list[i]
		var c: Dictionary = cast[who]
		if art != null:  # the picture has the people in it already: only where each mouth is, for the tails
			var at := Vector2(0.27 if who_list.size() == 1 else (0.25 if i == 0 else 0.75), 0.42)
			if tails.has(who):
				at = Vector2(float(tails[who][0]), float(tails[who][1]))
			var m := at * size
			actors[who] = {"node": null, "rect": Rect2(m - Vector2(60, 50), Vector2(120, 260)), "head": m, "mouth": m, "face": str(c.get("face", "")),
				"side": -1.0 if i == 0 and who_list.size() > 1 else 1.0, "kind": "art"}
			feeling[who] = str(mood.get(who, "neutral"))
			if who in introduce:
				_plate(page, who, c, m.x)
			continue
		var face := str(c.get("face", ""))
		var drawn := ComicFaces.has(face)
		var kind := ComicFaces.kind(face) if drawn else "cut"
		var shape := ComicFaces.aspect(face) if drawn else ComicFaces.ASPECT
		var h := tall * (1.0 if who_list.size() == 1 or who == first_voice or first_voice.is_empty() else 0.9)  # who listens stands a little back
		if kind != "cut":
			h = minf(h, size.y * 0.8)  # a card or an oval is a picture in the frame: it is never cut by it
		var w := h * shape
		if who_list.size() == 2 and w > size.x * 0.5:
			w = size.x * 0.5
			h = w / shape
		var cx := size.x * (0.27 if who_list.size() == 1 else (0.25 if i == 0 else 0.75))
		cx = clampf(cx, w * 0.5 + 6.0, size.x - w * 0.5 - 6.0)
		var bottom := size.y + h * SINK if kind == "cut" else size.y - 14.0
		var rect := Rect2(Vector2(cx - w * 0.5, bottom - h), Vector2(w, h))
		var node: Control
		if drawn:
			var t := TextureRect.new()
			t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			t.stretch_mode = TextureRect.STRETCH_SCALE
			t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			t.flip_h = i == 1  # the sheets look to the right: the second speaker is turned to face the first
			if _tint == null:
				_tint = Shader.new()
				_tint.code = TINT
			var m := ShaderMaterial.new()
			m.shader = _tint
			t.material = m
			node = t
		else:
			var d := ComicDoodle.new()
			d.look = c.get("look", {})
			if not d.look.has("coat"):
				d.look = d.look.merged({"coat": str(c.get("coat", "8a6a4a"))})
			d.flip = i == 1
			node = d
		if kind != "cut":  # a card and an oval are pictures in the frame: each gets its mount, behind it
			var mount := Mount.new()
			mount.oval = kind == "oval"
			mount.position = rect.position
			mount.size = rect.size
			mount.show_behind_parent = true
			mount.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(mount)
		node.position = rect.position
		node.size = rect.size
		node.show_behind_parent = true
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(node)
		var mouth_at := ComicFaces.mouth(face) if drawn else 0.34
		var mouth := Vector2(cx, rect.position.y + h * mouth_at)
		if tails.has(who):
			mouth = Vector2(float(tails[who][0]), float(tails[who][1])) * size
		actors[who] = {"node": node, "rect": rect, "head": Vector2(cx, rect.position.y + h * maxf(mouth_at - 0.2, 0.08)), "mouth": mouth, "face": face,
			"side": -1.0 if i == 0 and who_list.size() > 1 else 1.0, "kind": kind}
		_feel(who, str(mood.get(who, "neutral")), 1.0)
		if who in introduce:
			_plate(page, who, c, cx)
	if panel.has("caption"):
		caption = page.say(panel["caption"])
		caption_gloss = page.gloss(panel["caption"])
	var top := 12.0 + (_text_size(caption, size.x - 60).y + 2 * PAD.y + 10 if not caption.is_empty() else 0.0)
	var taken: Dictionary = {}  # side (−1 left, 1 right) → the y below the balloons already there
	for n in lines.size():
		var who: String = lines[n][0]
		var text := page.say(lines[n][1])
		var a: Dictionary = actors.get(who, {})
		var mouth: Vector2 = a.get("mouth", size * 0.5)
		var width := clampf(size.x * (0.5 if lines.size() == 1 else 0.37), 140.0, 340.0)  # Comic Relief is a wide face: wider balloons, not taller ones
		var face_edge := 0.0  # alone and large in the frame: the balloon keeps to the side of the face, if there is room
		if who_list.size() == 1 and not a.is_empty():
			var ar: Rect2 = a["rect"]
			var room := (size.x - (ar.get_center().x + ar.size.x * 0.27) - 14.0 - 2 * PAD.x) / 1.3
			if room >= 190.0:
				face_edge = ar.get_center().x + ar.size.x * 0.27
				width = minf(room, width)
		var body := _text_size(text, width)
		var oval := Vector2(body.x * 1.3 + 2 * PAD.x, body.y * 1.42 + 2 * PAD.y)  # the text's box fits inside the oval
		oval.x = minf(oval.x, size.x - 20.0)
		var side := -1 if mouth.x < size.x * 0.5 else 1
		if who_list.size() == 1:  # alone in the frame: the balloon goes to the emptier side
			side = 1 if mouth.x < size.x * 0.55 else -1
		var y: float = taken.get(side, top + (0.0 if n == 0 else float(balloons[0]["rect"].size.y) * 0.55))  # the answer hangs lower, clear of the question
		var rect := Rect2(Vector2(10.0 if side < 0 else size.x - oval.x - 10.0, y), oval)
		if face_edge > 0.0 and side > 0:
			rect.position.x = maxf(rect.position.x, minf(face_edge, size.x - oval.x - 6.0))
		rect.position.y = minf(rect.position.y, maxf(size.y - oval.y - 44.0, 8.0))
		var reach := mouth - rect.get_center()
		var base := _on_oval(rect, reach)  # where the tail leaves the balloon: on its edge, towards the mouth
		# the tail points at the mouth and is short: it says whose words these are without crossing a face
		var far := maxf((mouth - base).length() - maxf(float(a.get("rect", Rect2(0, 0, 0, 120)).size.y) * 0.16, 18.0), 14.0)
		var tip := base + (mouth - base).normalized() * minf(far, 44.0)
		balloons.append({"who": who, "rect": rect, "tip": tip, "base": base, "text": text, "gloss": page.gloss(lines[n][1]),
			"name": page.say(str(cast[who].get("name", ""))), "emotion": str(lines[n][2]) if (lines[n] as Array).size() > 2 else "neutral",
			"voice": str(lines[n][3]) if (lines[n] as Array).size() > 3 else ("shout" if (lines[n] as Array).size() > 2 and lines[n][2] == "angry" else "say")})
		taken[side] = rect.end.y + 14.0
	modulate.a = 0.0


## The point of the oval `rect`'s edge that lies in direction `way` from its middle.
static func _on_oval(rect: Rect2, way: Vector2) -> Vector2:
	var half := rect.size * 0.5
	if way.length() < 0.001:
		return rect.get_center() + Vector2(0, half.y)
	var u := way / half
	return rect.get_center() + way / u.length()


func _plate(page: ComicPage, who: String, c: Dictionary, cx: float) -> void:
	var text := page.say(str(c.get("name", "")))
	var pw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, PLATE_SIZE).x + 20.0
	var px := clampf(cx - pw * 0.5, 8.0, size.x - pw - 8.0)
	plates.append({"who": who, "text": text, "rect": Rect2(px, size.y - 34.0, pw, 24.0)})


func _text_size(text: String, width: float) -> Vector2:
	return _font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, width, FONT_SIZE)


## Puts emotion `e` on `who`'s face; `light` < 1 steps a listener back a little.
func _feel(who: String, e: String, light: float) -> void:
	feeling[who] = e
	var a: Dictionary = actors[who]
	if a["node"] == null:  # a drawn panel: the face is the picture's
		return
	if a["node"] is TextureRect:
		(a["node"] as TextureRect).texture = ComicFaces.texture(a["face"], e)
		((a["node"] as TextureRect).material as ShaderMaterial).set_shader_parameter("dim", light)
	else:
		(a["node"] as ComicDoodle).emotion = e
		(a["node"] as ComicDoodle).dim = light


## Who said the last balloon that is up ("" before anybody speaks).
func speaker() -> String:
	return str(balloons[mini(_shown, balloons.size()) - 1]["who"]) if _shown > 0 and not balloons.is_empty() else ""


## Shows the frame with its first `count` balloons; −1 hides the frame. Faces follow what has been said so far.
func show_lines(count: int) -> void:
	if count == _shown:
		return
	if _shown < 0 and count >= 0:
		create_tween().tween_property(self, "modulate:a", 1.0, 0.22)
	elif count < 0:
		modulate.a = 0.0
	_shown = count
	var now: Dictionary = {}
	for who: String in actors:
		now[who] = str(mood.get(who, "neutral"))
	for i in mini(maxi(count, 0), balloons.size()):
		if actors.has(balloons[i]["who"]):
			now[balloons[i]["who"]] = balloons[i]["emotion"]
	var talking := speaker()
	for who: String in actors:
		_feel(who, now[who], 0.86 if not talking.is_empty() and who != talking and actors.size() > 1 else 1.0)
	queue_redraw()


func show_gloss(on: bool) -> void:
	if on != _gloss:
		_gloss = on
		queue_redraw()


func shown() -> int:
	return _shown


func _draw() -> void:
	var talking := speaker()
	if actors.has(talking) and actors[talking]["node"] != null:
		_marks(actors[talking], str(feeling.get(talking, "neutral")))
	if not caption.is_empty():
		var text := caption_gloss if _gloss and not caption_gloss.is_empty() else caption
		var body := _font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, size.x - 60, FONT_SIZE - 2)
		var box := Rect2(Vector2(10, 10), body + 2 * PAD)
		draw_rect(box, ComicPage.CAPTION)
		draw_rect(box, ComicPage.INK, false, 2.0)
		draw_multiline_string(_font, box.position + PAD + Vector2(0, FONT_SIZE - 3), text, HORIZONTAL_ALIGNMENT_LEFT, body.x + 1, FONT_SIZE - 2, -1, ComicPage.INK)
	for p in plates:  # who this is: said once, on a plate, the first time they are seen
		var r: Rect2 = p["rect"]
		draw_rect(r, ComicPage.CAPTION)
		draw_rect(r, ComicPage.INK, false, 2.0)
		draw_string(_font, r.position + Vector2(10, 17), str(p["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, PLATE_SIZE, ComicPage.INK)
	for i in mini(maxi(_shown, 0), balloons.size()):
		_balloon(balloons[i])
	draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)), ComicPage.INK, false, 3.0)


func _balloon(b: Dictionary) -> void:
	var rect: Rect2 = b["rect"]
	var voice := str(b["voice"])
	var centre := rect.get_center()
	var base: Vector2 = b["base"]
	var tip: Vector2 = b["tip"]
	var shape: PackedVector2Array
	match voice:
		"shout":
			shape = _burst(rect)
		"thought":
			shape = _cloud(rect)
		_:
			shape = _oval(rect, 48)
	if voice == "thought":  # a thought has no tail: three bubbles lead to the head
		for k in 3:
			var at := base.lerp(tip, 0.25 + k * 0.3)
			draw_circle(at, 8.0 - k * 2.2, Color.WHITE)
			draw_arc(at, 8.0 - k * 2.2, 0, TAU, 16, ComicPage.INK, 2.0, true)
	else:
		var across := (base - centre).normalized().rotated(PI / 2) * 11.0
		var inside := base.lerp(centre, 0.12)  # the tail starts inside the balloon, so the outline has no gap
		var tail := PackedVector2Array([inside - across, inside + across, tip])
		draw_colored_polygon(tail, Color.WHITE)
		draw_polyline(PackedVector2Array([base - across, tip, base + across]), ComicPage.INK, 2.5, true)
	draw_colored_polygon(shape, Color.WHITE)
	var outline := shape.duplicate()
	outline.append(outline[0])
	if voice == "thought" or voice == "shout":
		draw_polyline(outline, ComicPage.INK, 2.5, true)
	else:  # the outline, open where the tail joins
		var across := (base - centre).normalized().rotated(PI / 2) * 11.0
		for k in outline.size() - 1:
			var mid := (outline[k] + outline[k + 1]) * 0.5
			if mid.distance_to(base) > across.length() + 1.0:
				draw_line(outline[k], outline[k + 1], ComicPage.INK, 2.5, true)
	var text: String = b["gloss"] if _gloss and not str(b["gloss"]).is_empty() else b["text"]
	var width := rect.size.x - 2 * PAD.x - rect.size.x * 0.16
	var body := _font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, width, FONT_SIZE)
	var at := Vector2(centre.x - width * 0.5, centre.y - body.y * 0.5 + _font.get_ascent(FONT_SIZE))
	draw_multiline_string(_font, at, text, HORIZONTAL_ALIGNMENT_CENTER, width, FONT_SIZE, -1,
		Color("3a4a6a") if _gloss and not str(b["gloss"]).is_empty() else ComicPage.INK)


## An ellipse in `rect`; `bust` = flat along the lower edge (a painted oval portrait that stands on the frame).
static func _oval(rect: Rect2, points: int, bust: bool = false) -> PackedVector2Array:
	var out := PackedVector2Array()
	var c := rect.get_center()
	var half := rect.size * 0.5
	if bust:
		c.y = rect.position.y + rect.size.y * 0.625
		half.y = rect.size.y * 0.625
	for i in points:
		var a := TAU * i / points
		var p := c + Vector2(cos(a) * half.x, sin(a) * half.y)
		p.y = minf(p.y, rect.end.y)
		out.append(p)
	return out


## A shout: an oval with a zigzag edge.
static func _burst(rect: Rect2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var c := rect.get_center()
	var half := rect.size * 0.5
	var teeth := maxi(14, int((rect.size.x + rect.size.y) / 22.0))
	for i in teeth * 2:
		var a := TAU * i / (teeth * 2)
		var k := 1.07 if i % 2 == 0 else 0.93
		out.append(c + Vector2(cos(a) * half.x, sin(a) * half.y) * k)
	return out


## A thought: an oval with a scalloped edge.
static func _cloud(rect: Rect2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var c := rect.get_center()
	var half := rect.size * 0.5
	var puffs := maxi(9, int((rect.size.x + rect.size.y) / 34.0))
	for i in puffs * 6:
		var a := TAU * i / (puffs * 6)
		var k := 0.95 + 0.07 * absf(sin(a * puffs * 0.5))
		out.append(c + Vector2(cos(a) * half.x, sin(a) * half.y) * k)
	return out


static func _star(c: Vector2, outer: float, inner: float, points: int, turn: float = 0.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in points * 2:
		var a := turn + PI * i / points
		out.append(c + Vector2(cos(a), sin(a)) * (outer if i % 2 == 0 else inner))
	return out


## What comics draw round a head: a burst with "!" for surprise, a red one for anger, drops for worry, a sparkle
## for a sly thought, little stars for joy. Our own shapes and letters.
func _marks(a: Dictionary, e: String) -> void:
	var rect: Rect2 = a["rect"]
	var head: Vector2 = a["head"]
	var at := Vector2(head.x + float(a["side"]) * rect.size.x * 0.42, head.y - rect.size.y * 0.08)
	at = at.clamp(Vector2(34, 34), size - Vector2(34, 34))
	var k := clampf(rect.size.y / 340.0, 0.6, 1.4)
	match e:
		"surprised", "angry":
			var burst := _star(at, 30.0 * k, 17.0 * k, 9, 0.3)
			draw_colored_polygon(burst, Color("ffd23f") if e == "surprised" else Color("e5483a"))
			burst.append(burst[0])
			draw_polyline(burst, ComicPage.INK, 2.5, true)
			var word := "!" if e == "surprised" else "!!"
			var fs := int(30 * k)
			var ws := _font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			draw_string(_font, at + Vector2(-ws.x * 0.5, fs * 0.36), word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ComicPage.INK if e == "surprised" else Color.WHITE)
		"worried":
			for i in 3:
				var p := at + Vector2((i - 1) * 15.0 * k, absf(i - 1) * 9.0 * k)
				var drop := PackedVector2Array([p + Vector2(0, -11 * k), p + Vector2(6 * k, 3 * k), p + Vector2(0, 8 * k), p + Vector2(-6 * k, 3 * k)])
				draw_colored_polygon(drop, Color("8fd0e8"))
				drop.append(drop[0])
				draw_polyline(drop, ComicPage.INK, 2.0, true)
		"sly", "happy":
			for i in (2 if e == "sly" else 3):
				var p := at + Vector2((i - 1) * 20.0 * k, (i % 2) * 14.0 * k)
				var spark := _star(p, (13.0 - i * 2.5) * k, 4.0 * k, 4)
				draw_colored_polygon(spark, Color("ffd23f") if e == "happy" else Color("fff3b0"))
				spark.append(spark[0])
				draw_polyline(spark, ComicPage.INK, 1.8, true)

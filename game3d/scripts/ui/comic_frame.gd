## One frame of a comic page: paper with halftone dots, the speakers as drawn portraits whose faces change with every
## line (Aika's expression sheets, or a code-drawn stand-in for people without a sheet), balloons with tails, a
## caption box, the marks comics put round a head (a burst, sweat drops, a sparkle), a black border.
## See docs/adr/0027-game3d-talk-as-comic-pages.md
class_name ComicFrame
extends Control

const FONT_SIZE := 17
const PAD := Vector2(14, 9)
const HEIGHT := {"close": 1.0, "low": 1.1, "two": 0.8, "wide": 0.62}  ## portrait height in frame heights, by shot
const FADE := "shader_type canvas_item;
uniform float dim = 1.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = smoothstep(0.0, 0.14, UV.x) * smoothstep(1.0, 0.86, UV.x) * smoothstep(0.0, 0.07, UV.y);
	COLOR = vec4(c.rgb * dim, a);
}"

var actors: Dictionary = {}  ## cast id → {node, rect, head, face, side}
var balloons: Array[Dictionary] = []  ## {who, rect, tip, base, text, gloss, name, emotion}
var mood: Dictionary = {}  ## cast id → the face they wear in this frame when they are not speaking
var caption := ""
var caption_gloss := ""
var feeling: Dictionary = {}  ## cast id → the emotion shown right now
var _shown := -1
var _gloss := false
var _font: Font
var _sky := Color("f0dcb4")

static var _fade: Shader


## The paper and the dots behind the people.
class Back:
	extends Control
	var tone := Color.WHITE
	var corner := Vector2.ZERO

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), ComicPage.PAPER)
		var reach := size.length() * 0.8
		var y := 6.0
		while y < size.y:
			var x := 6.0 + (8.0 if int(y / 14.0) % 2 == 1 else 0.0)
			while x < size.x:
				var k := 1.0 - Vector2(x, y).distance_to(corner) / reach
				if k > 0.12:
					draw_circle(Vector2(x, y), 5.2 * k, tone)
				x += 16.0
			y += 14.0


func setup(page: ComicPage, panel: Dictionary, cast: Dictionary, backdrop: Dictionary) -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ComicPage.font()
	_sky = Color(str(backdrop.get("sky", "f0dcb4")))
	mood = panel.get("mood", {})
	var who_list: Array = panel.get("cast", [])
	var back := Back.new()
	back.tone = _sky
	back.corner = Vector2(0, 0) if who_list.size() > 1 else Vector2(size.x, 0)
	back.size = size
	back.show_behind_parent = true
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	var h := size.y * float(HEIGHT.get(panel.get("shot", "two"), 0.8))
	var w := h * ComicFaces.ASPECT
	if who_list.size() == 2 and w > size.x * 0.48:
		w = size.x * 0.48
		h = w / ComicFaces.ASPECT
	for i in who_list.size():
		var who: String = who_list[i]
		var c: Dictionary = cast[who]
		var cx := size.x * (0.3 if who_list.size() == 1 else (0.25 if i == 0 else 0.75))
		cx = clampf(cx, w * 0.5 + 4.0, size.x - w * 0.5 - 4.0)
		var rect := Rect2(Vector2(cx - w * 0.5, size.y - h + (h * 0.07 if panel.get("shot", "") == "low" else 0.0)), Vector2(w, h))
		var face := str(c.get("face", ""))
		var node: Control
		if ComicFaces.has(face):
			var t := TextureRect.new()
			t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			t.stretch_mode = TextureRect.STRETCH_SCALE
			t.flip_h = i == 1  # the sheets look to the right: the second speaker is turned to face the first
			if _fade == null:
				_fade = Shader.new()
				_fade.code = FADE
			var m := ShaderMaterial.new()
			m.shader = _fade
			t.material = m
			node = t
		else:
			var d := ComicDoodle.new()
			d.look = c.get("look", {})
			if not d.look.has("coat"):
				d.look = d.look.merged({"coat": str(c.get("coat", "8a6a4a"))})
			d.flip = i == 1
			node = d
		node.position = rect.position
		node.size = rect.size
		node.show_behind_parent = true
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(node)
		actors[who] = {"node": node, "rect": rect, "head": Vector2(cx, rect.position.y + h * 0.2), "face": face, "side": -1.0 if i == 0 and who_list.size() > 1 else 1.0}
		_feel(who, str(mood.get(who, "neutral")), 1.0)
	if panel.has("caption"):
		caption = page.say(panel["caption"])
		caption_gloss = page.gloss(panel["caption"])
	var top := 12.0 + (_text_size(caption, size.x - 60).y + 2 * PAD.y + 10 if not caption.is_empty() else 0.0)
	var lines: Array = panel.get("lines", [])
	var taken: Dictionary = {}  # side (−1 left, 1 right) → the y below the balloons already there
	for n in lines.size():
		var who: String = lines[n][0]
		var text := page.say(lines[n][1])
		var name := page.say(str(cast[who].get("name", "")))
		var head: Vector2 = actors[who]["head"] if actors.has(who) else size * 0.5
		var width := clampf(size.x * (0.6 if lines.size() == 1 else 0.47), 170.0, 360.0)
		var body := _text_size(text, width - 2 * PAD.x)
		var bw := maxf(body.x, _font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE - 4).x) + 2 * PAD.x
		var bh := body.y + 2 * PAD.y + FONT_SIZE
		var side := -1 if head.x < size.x * 0.5 else 1
		if who_list.size() == 1:  # alone in the frame: the first balloon goes to the emptier side, a second one under it
			side = 1 if head.x < size.x * 0.55 else -1
		var y: float = taken.get(side, top + (0.0 if n == 0 else 22.0))  # the answer hangs a little lower
		var rect := Rect2(Vector2(12.0 if side < 0 else size.x - bw - 12.0, y), Vector2(bw, bh))
		var base := Vector2(clampf(head.x, rect.position.x + 26, rect.end.x - 26), rect.end.y)
		if who_list.size() == 1:
			base.x = rect.position.x + 30 if side > 0 else rect.end.x - 30
		var to_mouth := head + Vector2(0, h * 0.22) - base
		var tip := base + to_mouth.normalized() * minf(to_mouth.length() * 0.5, 38.0)  # a short tail: it points, it does not cross a face
		tip.y = maxf(tip.y, base.y + 12)
		balloons.append({"who": who, "rect": rect, "tip": tip, "base": base, "text": text, "gloss": page.gloss(lines[n][1]), "name": name,
			"emotion": str(lines[n][2]) if (lines[n] as Array).size() > 2 else "neutral"})
		taken[side] = rect.end.y + 24
	modulate.a = 0.0


func _text_size(text: String, width: float) -> Vector2:
	return _font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, FONT_SIZE)


## Puts emotion `e` on `who`'s face; `light` < 1 steps a listener back a little.
func _feel(who: String, e: String, light: float) -> void:
	feeling[who] = e
	var a: Dictionary = actors[who]
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
		_feel(who, now[who], 0.84 if not talking.is_empty() and who != talking and actors.size() > 1 else 1.0)
	queue_redraw()


func show_gloss(on: bool) -> void:
	if on != _gloss:
		_gloss = on
		queue_redraw()


func shown() -> int:
	return _shown


func _draw() -> void:
	var talking := speaker()
	if actors.has(talking):
		_marks(actors[talking], str(feeling.get(talking, "neutral")))
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
		var loud: bool = b["emotion"] in ["surprised", "angry"]
		if loud:  # a shout: the balloon bristles
			var spikes := _bristle(rect.grow(3.0))
			draw_colored_polygon(spikes, Color.WHITE)
			spikes.append(spikes[0])
			draw_polyline(spikes, ComicPage.INK, 2.5, true)
		else:
			var style := Hud.box(Color.WHITE, ComicPage.INK, 2, 16)
			style.shadow_size = 0
			draw_style_box(style, rect)
		var base: Vector2 = b["base"]
		var tail := PackedVector2Array([base + Vector2(-11, -4), base + Vector2(11, -4), b["tip"]])
		draw_colored_polygon(tail, Color.WHITE)
		draw_line(tail[0] + Vector2(0, 4), tail[2], ComicPage.INK, 2.0, true)
		draw_line(tail[1] + Vector2(0, 4), tail[2], ComicPage.INK, 2.0, true)
		var at := rect.position + PAD
		draw_string(_font, at + Vector2(0, FONT_SIZE - 4), str(b["name"]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE - 5, ComicPage.TAG)
		var text: String = b["gloss"] if _gloss and not str(b["gloss"]).is_empty() else b["text"]
		draw_multiline_string(_font, at + Vector2(0, FONT_SIZE * 2), text, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 2 * PAD.x, FONT_SIZE, -1,
			Color("3a4a6a") if _gloss and not str(b["gloss"]).is_empty() else ComicPage.INK)
	draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)), ComicPage.INK, false, 3.0)


## A rectangle with a zigzag edge.
static func _bristle(r: Rect2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for s in 4:
		var a: Vector2 = corners[s]
		var b: Vector2 = corners[(s + 1) % 4]
		var n := maxi(2, int(a.distance_to(b) / 20.0))
		var outward := (b - a).normalized().rotated(-PI / 2)
		for i in n:
			out.append(a.lerp(b, float(i) / n))
			out.append(a.lerp(b, (i + 0.5) / n) + outward * 7.0)
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
	var at := Vector2(rect.get_center().x + float(a["side"]) * rect.size.x * 0.4, rect.position.y + rect.size.y * 0.16)
	at = at.clamp(Vector2(34, 34), size - Vector2(34, 34))
	var k := clampf(rect.size.y / 300.0, 0.6, 1.5)
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

## A stand-in portrait drawn in code for people who have no expression sheet yet: a simple comic bust — ink outline,
## flat colour, brows, eyes and mouth that change with the emotion. Replaced by a sheet as soon as Aika draws one
## (then the cast entry gets a "face"). See docs/adr/0027-game3d-talk-as-comic-pages.md
class_name ComicDoodle
extends Control

const INK := Color("1b1a1f")
const LINE := 3.0
## emotion → [brow inner dy, brow outer dy, eye opening, pupil size, mouth]
const FEEL := {
	"neutral": [0.0, 0.0, 1.0, 1.0, "smile"],
	"happy": [-0.05, -0.05, 0.85, 1.0, "grin"],
	"surprised": [-0.16, -0.16, 1.4, 0.65, "o"],
	"sly": [0.07, -0.1, 0.5, 0.9, "smirk"],
	"worried": [-0.13, 0.04, 1.15, 0.85, "wavy"],
	"angry": [0.13, -0.08, 0.75, 0.9, "teeth"],
}

var look: Dictionary = {}
var emotion := "neutral":
	set(v):
		emotion = v
		queue_redraw()
var flip := false
var dim := 1.0:
	set(v):
		dim = v
		modulate = Color(v, v, v)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _c(key: String, fallback: String) -> Color:
	return Color(str(look.get(key, fallback)))


static func _oval(c: Vector2, rx: float, ry: float, n: int = 22, from: float = 0.0, to: float = TAU) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n + 1:
		var a := lerpf(from, to, float(i) / n)
		out.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return out


func _shape(pts: PackedVector2Array, fill: Color, closed: bool = true) -> void:
	draw_colored_polygon(pts, fill)
	if closed:
		pts.append(pts[0])
	draw_polyline(pts, INK, LINE, true)


func _draw() -> void:
	var r := size.y * 0.2  # head radius
	var f := -1.0 if flip else 1.0
	var head := Vector2(size.x * 0.5, size.y * 0.43)
	var skin := _c("skin", "f1c9a5")
	var hair := _c("hair", "5e3b28")
	var coat := _c("coat", "8a6a4a")
	if str(look.get("kind", "")) == "owl":
		_owl(head, r, f)
		return
	var kid := str(look.get("kind", "")) == "child"
	if kid:
		r *= 0.92
		head.y += r * 0.5
	# shoulders and chest
	var sh := head.y + r * 1.25
	var body := PackedVector2Array([Vector2(head.x - r * 0.45, sh - r * 0.1), Vector2(head.x + r * 0.45, sh - r * 0.1),
		Vector2(head.x + r * (1.25 if kid else 1.7), sh + r * 0.55), Vector2(head.x + r * (1.4 if kid else 1.95), size.y + 4),
		Vector2(head.x - r * (1.4 if kid else 1.95), size.y + 4), Vector2(head.x - r * (1.25 if kid else 1.7), sh + r * 0.55)])
	_shape(body, coat)
	match str(look.get("outfit", "coat")):
		"stripes":
			for i in 7:
				var y := sh + r * (0.45 + i * 0.42)
				var half := r * (1.2 + i * 0.1)
				draw_line(Vector2(head.x - half, y), Vector2(head.x + half, y), _c("trim", "3b5a8c"), r * 0.16)
			draw_polyline(_oval(Vector2(head.x, sh - r * 0.05), r * 0.5, r * 0.35, 10, 0.0, PI), INK, LINE, true)
		"apron":
			_shape(PackedVector2Array([Vector2(head.x - r * 0.7, sh + r * 0.5), Vector2(head.x + r * 0.7, sh + r * 0.5),
				Vector2(head.x + r * 0.95, size.y + 4), Vector2(head.x - r * 0.95, size.y + 4)]), Color("f6efdc"))
			draw_polyline(PackedVector2Array([Vector2(head.x - r * 1.5, sh + r * 0.4), Vector2(head.x, sh + r * 1.1), Vector2(head.x + r * 1.5, sh + r * 0.4)]),
				INK, LINE, true)
		_:
			_shape(PackedVector2Array([Vector2(head.x - r * 0.42, sh), Vector2(head.x + r * 0.42, sh), Vector2(head.x, sh + r * 1.5)]), Color("f6efdc"))
			for side: float in [-1.0, 1.0]:
				_shape(PackedVector2Array([Vector2(head.x + side * r * 0.42, sh - r * 0.05), Vector2(head.x + side * r * 1.0, sh + r * 0.5),
					Vector2(head.x + side * r * 0.25, sh + r * 1.9), Vector2(head.x, sh + r * 1.5)]), coat.darkened(0.18))
	_shape(PackedVector2Array([Vector2(head.x - r * 0.3, head.y + r * 0.6), Vector2(head.x + r * 0.3, head.y + r * 0.6),
		Vector2(head.x + r * 0.34, sh + r * 0.12), Vector2(head.x - r * 0.34, sh + r * 0.12)]), skin.darkened(0.08))
	var hat := str(look.get("hat", "none"))
	var style := str(look.get("hairstyle", "short"))
	if style == "long" or hat == "scarf":
		_shape(_oval(head + Vector2(0, r * 0.25), r * 1.02, r * 1.25), _c("hat_colour", "f6efdc") if hat == "scarf" else hair)
	if style == "bun":
		_shape(_oval(head + Vector2(-f * r * 0.35, -r * 1.05), r * 0.42, r * 0.38), hair)
	# the head, turned a little to where the person looks
	_shape(_oval(head + Vector2(-f * r * 0.86, r * 0.08), r * 0.16, r * 0.24), skin.darkened(0.06))
	var face := PackedVector2Array()
	for p in _oval(head, r * 0.86, r, 26):
		var t := (p.y - head.y) / r
		face.append(Vector2(head.x + (p.x - head.x) * (1.0 - 0.16 * maxf(t, 0.0)), p.y))  # a narrower chin
	_shape(face, skin)
	if bool(look.get("beard", false)):
		var beard := PackedVector2Array()
		for p in _oval(head + Vector2(0, r * 0.3), r * 0.8, r * 0.95, 14, 0.12, PI - 0.12):
			beard.append(p)
		beard.append(head + Vector2(-r * 0.45, r * 0.42))
		beard.append(head + Vector2(0, r * 0.3))
		beard.append(head + Vector2(r * 0.45, r * 0.42))
		_shape(beard, hair)
	if hat != "scarf" and style != "bald":  # hair over the forehead
		var top := _oval(head + Vector2(0, -r * 0.12), r * 0.9, r * 0.95, 16, PI, TAU)
		top.append(head + Vector2(r * 0.55, -r * 0.42))
		top.append(head + Vector2(f * r * 0.1, -r * 0.6))
		top.append(head + Vector2(-r * 0.6, -r * 0.4))
		_shape(top, hair)
	_face(head, r, f, skin)
	_hat(hat, head, r, f)
	if bool(look.get("glasses", false)):
		for sx: float in [-0.33, 0.33]:
			draw_arc(head + Vector2(f * r * 0.12 + sx * r, -r * 0.05), r * 0.24, 0, TAU, 20, INK, LINE * 0.8, true)
		draw_line(head + Vector2(f * r * 0.12 - r * 0.09, -r * 0.05), head + Vector2(f * r * 0.12 + r * 0.09, -r * 0.05), INK, LINE * 0.8)


func _face(head: Vector2, r: float, f: float, skin: Color) -> void:
	var feel: Array = FEEL.get(emotion, FEEL["neutral"])
	var mid := head.x + f * r * 0.12
	for sx: float in [-1.0, 1.0]:
		var eye := Vector2(mid + sx * r * 0.33, head.y - r * 0.05)
		var open := float(feel[2])
		if emotion == "sly" and sx * f > 0:
			open *= 0.6  # one eye narrower: the look of somebody who knows something
		_shape(_oval(eye, r * 0.17, r * 0.19 * open, 14), Color.WHITE)
		draw_circle(eye + Vector2(f * r * 0.05, 0.0), r * 0.085 * float(feel[3]), INK)
		var inner := Vector2(eye.x - sx * r * 0.2, eye.y - r * 0.36 + float(feel[0]) * r)
		var outer := Vector2(eye.x + sx * r * 0.24, eye.y - r * 0.36 + float(feel[1]) * r)
		draw_line(inner, outer, INK, LINE * 1.8, true)
	draw_polyline(PackedVector2Array([Vector2(mid + f * r * 0.02, head.y + r * 0.05), Vector2(mid + f * r * 0.2, head.y + r * 0.32),
		Vector2(mid, head.y + r * 0.36)]), INK, LINE, true)
	var m := Vector2(mid, head.y + r * 0.62)
	match str(feel[4]):
		"grin":
			var lips := _oval(m, r * 0.36, r * 0.24, 12, 0.0, PI)
			_shape(lips, Color("7a2a2a"))
			draw_line(m + Vector2(-r * 0.3, r * 0.03), m + Vector2(r * 0.3, r * 0.03), Color.WHITE, r * 0.08)
		"o":
			_shape(_oval(m + Vector2(0, r * 0.04), r * 0.15, r * 0.2, 12), Color("5a1f1f"))
		"smirk":
			draw_polyline(PackedVector2Array([m + Vector2(-f * r * 0.25, r * 0.04), m + Vector2(0, r * 0.07), m + Vector2(f * r * 0.3, -r * 0.1)]), INK, LINE * 1.2, true)
		"wavy":
			draw_polyline(PackedVector2Array([m + Vector2(-r * 0.27, r * 0.05), m + Vector2(-r * 0.1, -r * 0.03), m + Vector2(r * 0.08, r * 0.06),
				m + Vector2(r * 0.27, -r * 0.02)]), INK, LINE * 1.2, true)
		"teeth":
			var box := PackedVector2Array([m + Vector2(-r * 0.3, -r * 0.06), m + Vector2(r * 0.3, -r * 0.1), m + Vector2(r * 0.26, r * 0.14), m + Vector2(-r * 0.27, r * 0.16)])
			_shape(box, Color.WHITE)
			for k in 3:
				draw_line(m + Vector2(-r * 0.15 + k * r * 0.15, -r * 0.08), m + Vector2(-r * 0.15 + k * r * 0.15, r * 0.14), INK, LINE * 0.6)
		_:
			draw_polyline(_oval(m + Vector2(0, -r * 0.08), r * 0.26, r * 0.14, 8, 0.25, PI - 0.25), INK, LINE * 1.2, true)
	if emotion == "worried":
		_shape(PackedVector2Array([head + Vector2(-f * r * 0.62, -r * 0.55), head + Vector2(-f * r * 0.5, -r * 0.28), head + Vector2(-f * r * 0.74, -r * 0.28)]), Color("9fd3e6"))


func _hat(hat: String, head: Vector2, r: float, f: float) -> void:
	var colour := _c("hat_colour", "a8322a")
	head.y -= r * 0.2  # worn high enough for the brows to show
	match hat:
		"bandana":
			var cap := _oval(head + Vector2(0, -r * 0.3), r * 0.92, r * 0.78, 16, PI, TAU)
			_shape(cap, colour)
			_shape(PackedVector2Array([head + Vector2(-f * r * 0.9, -r * 0.3), head + Vector2(-f * r * 1.5, -r * 0.05), head + Vector2(-f * r * 1.35, -r * 0.5)]), colour)
		"knit":
			_shape(_oval(head + Vector2(0, -r * 0.42), r * 0.9, r * 0.85, 16, PI, TAU), colour)
			_shape(PackedVector2Array([head + Vector2(-r * 0.95, -r * 0.62), head + Vector2(r * 0.95, -r * 0.62), head + Vector2(r * 0.95, -r * 0.34), head + Vector2(-r * 0.95, -r * 0.34)]),
				colour.lightened(0.2))
			_shape(_oval(head + Vector2(0, -r * 1.32), r * 0.18, r * 0.18, 10), colour.lightened(0.3))
		"cap":
			_shape(_oval(head + Vector2(0, -r * 0.45), r * 0.92, r * 0.7, 16, PI, TAU), colour)
			_shape(PackedVector2Array([head + Vector2(f * r * 0.2, -r * 0.5), head + Vector2(f * r * 1.35, -r * 0.42), head + Vector2(f * r * 0.9, -r * 0.28), head + Vector2(f * r * 0.2, -r * 0.34)]),
				colour.darkened(0.25))
		"brim":
			_shape(_oval(head + Vector2(0, -r * 0.95), r * 0.72, r * 0.6, 14, PI, TAU), colour)
			_shape(_oval(head + Vector2(0, -r * 0.62), r * 1.45, r * 0.24, 20), colour)
		"beret":
			_shape(_oval(head + Vector2(-f * r * 0.2, -r * 0.78), r * 1.05, r * 0.42, 18), colour)
			draw_line(head + Vector2(-f * r * 0.2, -r * 1.2), head + Vector2(-f * r * 0.1, -r * 1.36), INK, LINE)
		"scarf":
			_shape(PackedVector2Array([head + Vector2(-r * 0.2, r * 1.0), head + Vector2(r * 0.2, r * 1.0), head + Vector2(r * 0.34, r * 1.5), head + Vector2(-r * 0.3, r * 1.45)]), colour)
			var front := _oval(head + Vector2(0, -r * 0.25), r * 0.95, r * 0.85, 16, PI, TAU)
			front.append(head + Vector2(r * 0.7, -r * 0.42))
			front.append(head + Vector2(-r * 0.7, -r * 0.42))
			_shape(front, colour)


## The Chronicler: an owl scholar in round glasses and a blue cape (sheet 05), with eyelids that speak.
func _owl(head: Vector2, r: float, f: float) -> void:
	var brown := Color("8a5a3c")
	var cream := Color("f3e3c4")
	var feel: Array = FEEL.get(emotion, FEEL["neutral"])
	var sh := head.y + r * 0.7
	_shape(PackedVector2Array([Vector2(head.x - r * 1.0, sh), Vector2(head.x + r * 1.0, sh), Vector2(head.x + r * 1.9, size.y + 4), Vector2(head.x - r * 1.9, size.y + 4)]),
		Color("3d6ea8"))
	_shape(PackedVector2Array([Vector2(head.x - r * 0.5, sh), Vector2(head.x + r * 0.5, sh), Vector2(head.x + r * 0.7, size.y + 4), Vector2(head.x - r * 0.7, size.y + 4)]), cream)
	for sx: float in [-1.0, 1.0]:
		var lift := -float(feel[1]) * r * 1.5
		_shape(PackedVector2Array([head + Vector2(sx * r * 0.45, -r * 0.8), head + Vector2(sx * r * 1.1, -r * 1.45 - lift), head + Vector2(sx * r * 0.95, -r * 0.45)]), brown)
	_shape(_oval(head, r * 1.05, r * 0.98, 26), brown)
	for sx: float in [-1.0, 1.0]:
		var eye := head + Vector2(f * r * 0.08 + sx * r * 0.42, -r * 0.08)
		_shape(_oval(eye, r * 0.46, r * 0.5, 18), cream)
		_shape(_oval(eye, r * 0.3, r * 0.3, 16), Color("f2c14a"))
		draw_circle(eye + Vector2(f * r * 0.05, 0), r * 0.13 * float(feel[3]), INK)
		var lid := 1.0 - clampf(float(feel[2]), 0.3, 1.0)
		if lid > 0.05 or float(feel[0]) > 0.05:  # a heavy lid for a sly or cross owl
			var cover := _oval(eye, r * 0.31, r * 0.31, 12, PI + 0.0, TAU)
			cover.append(eye + Vector2(r * 0.31, -r * 0.3 + (lid + maxf(float(feel[0]), 0.0)) * r * 0.75 * (1.0 if sx * f < 0 or emotion != "sly" else 1.4)))
			cover.append(eye + Vector2(-r * 0.31, -r * 0.3 + (lid + maxf(float(feel[0]), 0.0)) * r * 0.75))
			draw_colored_polygon(cover, brown.lightened(0.15))
		draw_arc(eye, r * 0.36, 0, TAU, 22, Color("d9a441"), LINE, true)
	var open := r * (0.22 if str(feel[4]) in ["o", "grin", "teeth"] else 0.0)
	_shape(PackedVector2Array([head + Vector2(f * r * 0.08 - r * 0.16, r * 0.2), head + Vector2(f * r * 0.08 + r * 0.16, r * 0.2), head + Vector2(f * r * 0.08, r * 0.55 + open)]),
		Color("d98a3a"))
	if emotion == "worried":
		_shape(PackedVector2Array([head + Vector2(-f * r * 0.8, -r * 0.7), head + Vector2(-f * r * 0.68, -r * 0.42), head + Vector2(-f * r * 0.92, -r * 0.42)]), Color("9fd3e6"))

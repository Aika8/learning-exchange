## Cuts the comic portraits out of their paper (ADR-0037): `art/portraits/<face>_<emotion>.jpg` →
## `art/cutouts/<face>_<emotion>.webp` with an alpha channel. No outside tool: Godot's own `Image`.
##   godot --headless --path game3d -s tools/cut_portraits.gd [-- --only=<face>]
## The paper is found from the picture's top and side edges and flooded inwards from every edge; what is not
## paper at an edge (a shoulder, the bust's lower end) stops the flood there. `data/cutouts.json` holds the hand corrections, per face or per picture:
##   "threshold": how far from the paper's colour a pixel may be and still be paper (default 0.13);
##   "drift": how far it may be from its already-flooded neighbour (default 0.05) — for shaded backgrounds;
##   "seeds": extra places to flood from, as [x, y] in 0…1 (a gap of paper closed in by hair or an arm);
##   "keep": rectangles [x, y, w, h] in 0…1 that are never cut (a white collar at the edge);
##   "fade": over how many pixels a figure that is cut by the picture's left or right edge fades out there
##     (default 12): on the sheets neighbouring faces overlap, so a hat's brim or a shoulder ends in a straight cut;
##   "oval": true — no flood: an oval bust with a clean edge (a painted portrait with no paper round it).
##   "card": true — not cut at all: the picture has a drawn background of its own (rain, a neon grid) and is shown
##     as a card with a border.
## The game reads the same file for "oval", "card" and "mouth" (how far down the picture the mouth is, 0…1: where
## a balloon's tail points).
extends SceneTree

const SRC := "res://art/portraits"
const OUT := "res://art/cutouts"


func _init() -> void:
	var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/cutouts.json"))
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var done := 0
	for file in DirAccess.get_files_at(SRC):
		if not file.ends_with(".jpg") or (not only.is_empty() and not file.begins_with(only)):
			continue
		var name := file.trim_suffix(".jpg")
		var face := name.substr(0, name.rfind("_"))
		var rule: Dictionary = (rules.get(face, {}) as Dictionary).merged(rules.get(name, {}), true)
		var img := Image.new()
		img.load(ProjectSettings.globalize_path(SRC.path_join(file)))
		img.convert(Image.FORMAT_RGBA8)
		var cut := img
		if rule.get("oval", false):
			cut = _oval(img)
		elif not rule.get("card", false):
			cut = _flood(img, rule)
			cut = cut.get_region(cut.get_used_rect())  # tight: the frame places a portrait by its real edges
		cut.save_webp(ProjectSettings.globalize_path(OUT.path_join(name + ".webp")), true, 0.86)  # lossy with alpha: a tenth of a PNG
		done += 1
	print("cut %d portraits into %s" % [done, OUT])
	quit()


static func _far(a: Color, b: Color) -> float:
	return maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))


func _flood(img: Image, rule: Dictionary) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var threshold := float(rule.get("threshold", 0.13))
	var drift := float(rule.get("drift", 0.05))
	var samples: Array[Color] = []
	for x in range(0, w, 3):
		samples.append(img.get_pixel(x, 0))
	for y in range(0, int(h * 0.5), 3):
		samples.append(img.get_pixel(0, y))
		samples.append(img.get_pixel(w - 1, y))
	var paper := Color(_median(samples, 0), _median(samples, 1), _median(samples, 2))
	var kept := PackedByteArray()
	kept.resize(w * h)
	for k: Array in rule.get("keep", []):
		for y in range(int(float(k[1]) * h), mini(int((float(k[1]) + float(k[3])) * h), h)):
			for x in range(int(float(k[0]) * w), mini(int((float(k[0]) + float(k[2])) * w), w)):
				kept[y * w + x] = 1
	var gone := PackedByteArray()
	gone.resize(w * h)
	var stack: Array[Vector2i] = []
	for x in w:
		stack.append(Vector2i(x, 0))
	for y in h:
		stack.append(Vector2i(0, y))
		stack.append(Vector2i(w - 1, y))
	for x in w:  # and from below: where the bust ends above the picture's edge there is paper under it
		stack.append(Vector2i(x, h - 1))
	for s: Array in rule.get("seeds", []):
		stack.append(Vector2i(int(float(s[0]) * (w - 1)), int(float(s[1]) * (h - 1))))
	var first := stack.size()
	var from: Array[Color] = []
	from.resize(first)
	from.fill(paper)
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		var parent: Color = from.pop_back()
		var i := p.y * w + p.x
		if gone[i] == 1 or kept[i] == 1:
			continue
		var c := img.get_pixel(p.x, p.y)
		if _far(c, paper) > threshold or _far(c, parent) > drift + (threshold if parent == paper else 0.0):
			continue
		gone[i] = 1
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q := p + d
			if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h and gone[q.y * w + q.x] == 0:
				stack.append(q)
				from.append(c)
	_drop_specks(gone, w, h)
	var fade := float(rule.get("fade", 12.0))
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			if gone[y * w + x] == 1:
				c.a = 0.0
			else:  # the edge: a pixel that touches paper is half there, and loses the paper's tint
				var near := 0
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var q := Vector2i(x, y) + d
					if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h and gone[q.y * w + q.x] == 1:
						near += 1
				if near > 0:
					c.a = 1.0 - 0.3 * near
					c = Color(c.r * 0.8, c.g * 0.8, c.b * 0.8, c.a)
				if fade > 0.0:  # a straight cut at the side edge becomes a soft end
					c.a *= clampf(minf(x + 0.5, w - x - 0.5) / fade, 0.0, 1.0)
			out.set_pixel(x, y, c)
	return out


## Small islands of ink left in the paper — a mark of the sheet, the tip of a neighbour's sleeve — go too: every
## piece of what was kept that is under 1.5 % of the picture.
func _drop_specks(gone: PackedByteArray, w: int, h: int) -> void:
	var label := PackedInt32Array()
	label.resize(w * h)
	var sizes: Array[int] = [0]
	for start in w * h:
		if gone[start] == 1 or label[start] != 0:
			continue
		var id := sizes.size()
		sizes.append(0)
		var stack: Array[int] = [start]
		label[start] = id
		while not stack.is_empty():
			var i: int = stack.pop_back()
			sizes[id] += 1
			var x := i % w
			for j: int in [i - 1 if x > 0 else -1, i + 1 if x < w - 1 else -1, i - w, i + w]:
				if j >= 0 and j < w * h and gone[j] == 0 and label[j] == 0:
					label[j] = id
					stack.append(j)
	for i in w * h:
		if gone[i] == 0 and sizes[label[i]] < w * h * 0.015:
			gone[i] = 1


func _oval(img: Image) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			var u := (x + 0.5) / w * 2.0 - 1.0
			var v := (y + 0.5) / (h * 1.25) * 2.0 - 1.0  # the oval is cut by the lower edge: a bust
			c.a = clampf((1.0 - sqrt(u * u + v * v)) * w * 0.5, 0.0, 1.0)
			out.set_pixel(x, y, c)
	return out


static func _median(colours: Array[Color], channel: int) -> float:
	var v: Array[float] = []
	for c in colours:
		v.append(c[channel])
	v.sort()
	return v[v.size() / 2]

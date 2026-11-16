## Grime and wear: Decal nodes with textures painted in code (noise, our own work, CC0) — damp dirt creeping up the
## base of a wall, trodden earth round a doorstep. They fade out with distance, so they cost nothing far away.
class_name Decals
extends RefCounted

static var _wall: Texture2D
static var _ground: Texture2D


static func _noise_image(size: int, seed_value: int, shade: Callable) -> ImageTexture:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.frequency = 0.035
	n.fractal_octaves = 4
	var img := Image.create(size, size, true, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var v := n.get_noise_2d(x, y) * 0.5 + 0.5
			img.set_pixel(x, y, shade.call(float(x) / size, float(y) / size, v))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Dirt that is dense at the bottom edge (v = 1) and breaks up towards the top.
static func wall_texture() -> Texture2D:
	if _wall == null:
		_wall = _noise_image(128, 5, func(_u: float, v: float, n: float) -> Color:
			var a := clampf((v - 0.25) * 1.5 + (n - 0.5) * 0.9, 0.0, 1.0)
			return Color(0.2 + n * 0.08, 0.16 + n * 0.07, 0.1 + n * 0.04, a * a * 0.85))
	return _wall


## A worn, earthy patch: dense in the middle, ragged at the rim.
static func ground_texture() -> Texture2D:
	if _ground == null:
		_ground = _noise_image(128, 9, func(u: float, v: float, n: float) -> Color:
			var r := Vector2(u - 0.5, v - 0.5).length() * 2.0
			var a := clampf((1.0 - r) * 1.6 + (n - 0.5) * 0.8, 0.0, 1.0)
			return Color(0.3 + n * 0.1, 0.24 + n * 0.08, 0.16 + n * 0.05, a * 0.7))
	return _ground


static func _decal(parent: Node3D, tex: Texture2D, size: Vector3, xform: Transform3D) -> Decal:
	var d := Decal.new()
	d.texture_albedo = tex
	d.size = size
	d.transform = xform
	d.normal_fade = 0.4
	d.upper_fade = 0.01
	d.lower_fade = 0.01
	d.distance_fade_enabled = true
	d.distance_fade_begin = 28.0
	d.distance_fade_length = 8.0
	d.set_meta("flat", true)
	parent.add_child(d)
	return d


## Grime on the four walls of a `w` × `d` footprint and trodden earth around it.
static func grime_house(parent: Node3D, w: float, d: float, height: float = 1.3) -> void:
	# a decal projects along its −y; turn it so −y looks at the wall and the texture's bottom edge is at the ground
	for k in 4:
		var yaw := k * PI * 0.5
		var out := Vector3(sin(yaw), 0, cos(yaw))  # outward normal of that wall
		var half := (d if k % 2 == 0 else w) * 0.5
		var width := w if k % 2 == 0 else d
		var basis := Basis(out.cross(Vector3.DOWN), out, Vector3.DOWN)  # x along the wall, y out of it, z down
		_decal(parent, wall_texture(), Vector3(width, 0.24, height), Transform3D(basis, out * half + Vector3(0, height * 0.5, 0)))
	ground(parent, Vector3.ZERO, maxf(w, d) + 3.0)


## Worn earth on the ground, `size` metres across.
static func ground(parent: Node3D, at: Vector3, size: float) -> void:
	_decal(parent, ground_texture(), Vector3(size, 0.3, size), Transform3D(Basis(), at))

## The island's wind taking the captain in (ADR-0025): thin bright streaks circle the body, rise with the wave that
## restyles it and close in. Our own code, no particle assets. A child of the body it circles; frees itself.
class_name WindSwirl
extends Node3D

const STREAKS := 28
const HEIGHT := 2.3

var seconds := 2.0
var _t := 0.0
var _streaks: Array[MeshInstance3D] = []
var _seed: Array[Vector4] = []  ## per streak: start angle, height 0..1, radius, speed


static func around(body: Node3D, colour: Color, duration: float) -> WindSwirl:
	var s := WindSwirl.new()
	s.name = "WindSwirl"
	s.seconds = duration
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = colour
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.render_priority = 110  # after the ink quad, or the quad would paint over it
	var streak := BoxMesh.new()
	streak.size = Vector3(0.018, 0.018, 0.5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in STREAKS:
		var mi := MeshInstance3D.new()
		mi.mesh = streak
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.transparency = 1.0
		s.add_child(mi)
		s._streaks.append(mi)
		s._seed.append(Vector4(rng.randf() * TAU, rng.randf(), rng.randf_range(0.45, 0.9), rng.randf_range(4.0, 7.5)))
	body.add_child(s)
	return s


## Where the wave is, 0 (feet) .. 1 (above the hat), at `t` of the swirl's life 0..1: the wind gathers first.
static func wave_at(t: float) -> float:
	return smoothstep(0.2, 0.85, t)


func _process(delta: float) -> void:
	_t += delta / seconds
	if _t >= 1.0:
		queue_free()
		return
	var wave := wave_at(_t)
	for i in _streaks.size():
		var s := _seed[i]
		var angle := s.x + _t * seconds * s.w
		var radius := s.z * lerpf(1.0, 0.55, _t)
		var y := s.y * HEIGHT
		var mi := _streaks[i]
		mi.position = Vector3(cos(angle) * radius, y, sin(angle) * radius)
		mi.rotation = Vector3(0.1, -angle, 0)  # along the circle, climbing a little
		# a streak lights up as the wave reaches its height, and the whole swirl fades in and out
		var near := exp(-pow((s.y - wave) / 0.28, 2.0))
		mi.transparency = 1.0 - clampf(sin(PI * _t) * (0.3 + 0.7 * near), 0.0, 1.0)

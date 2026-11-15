## Pure model of a voyage between two islands: a quadratic Bézier route, progress driven by sail and wind.
## Scenes only read positions from it, so the route and arrival rule are testable without a 3D scene.
class_name VoyageModel
extends RefCounted

const BASE_SPEED := 9.0  ## world units per second with the sail up and no wind
const MIN_FACTOR := 0.25  ## sail down still drifts

var from: Vector3
var control: Vector3
var to: Vector3
var travelled := 0.0
var length := 0.0


func _init(a: Vector3, c: Vector3, b: Vector3) -> void:
	from = a
	control = c
	to = b
	length = _measure()


func _measure() -> float:
	var total := 0.0
	var prev := from
	for i in range(1, 65):
		var p := point(i / 64.0)
		total += prev.distance_to(p)
		prev = p
	return total


func point(t: float) -> Vector3:
	var u := clampf(t, 0.0, 1.0)
	return from.lerp(control, u).lerp(control.lerp(to, u), u)


func heading(t: float) -> Vector3:
	var u := clampf(t, 0.0, 0.999)
	return (point(u + 0.001) - point(u)).normalized()


func progress() -> float:
	return clampf(travelled / length, 0.0, 1.0) if length > 0.0 else 1.0


## Wind help in [-1, 1]: 1 when the wind blows along the course.
func wind_help(wind: Vector3) -> float:
	var w := Vector3(wind.x, 0, wind.z)
	if w.length() < 0.001:
		return 0.0
	var h := heading(progress())
	return w.normalized().dot(Vector3(h.x, 0, h.z).normalized())


## Advances the ship; returns the speed used. Sail up + fair wind → up to 1.5× base speed.
func advance(delta: float, sail_up: bool, wind: Vector3) -> float:
	var factor := 1.0 + 0.5 * wind_help(wind) if sail_up else MIN_FACTOR
	var speed := BASE_SPEED * maxf(factor, MIN_FACTOR)
	travelled = minf(length, travelled + speed * delta)
	return speed


func arrived() -> bool:
	return progress() >= 1.0

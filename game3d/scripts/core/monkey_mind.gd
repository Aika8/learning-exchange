## Pattern: pure model — what the ship's monkey does, with no scene and no clock of its own (ADR-0036). Under way
## she lives in the rig: sits on a perch, then runs to a neighbouring one. In port she keeps near the captain:
## runs after him when he walks off, sits down when she has caught up. Deterministic for a seed.
class_name MonkeyMind
extends RefCounted

const RUN := 6.5  ## metres a second: faster than the captain, so she always catches up
const CLIMB := 2.4  ## in the rig
const NEAR := 1.7  ## ashore she sits down this close to the captain…
const FAR := 2.8  ## …and gets up when he is this far
const SIDE := 0.9  ## she stops a little to one side of him, not under his feet

var position := Vector3.ZERO  ## aboard: in the ship's own space; ashore: in the world
var yaw := 0.0
var running := false
var perch := 0  ## aboard: the perch she sits on or runs to
var _wait := 2.0
var _rng := RandomNumberGenerator.new()


func _init(seed_value: int = 7) -> void:
	_rng.seed = seed_value


## A step of her life in the rig. `perches` are places in the ship's own space; neighbours in the list are
## neighbours in the rig.
func aboard(delta: float, perches: Array[Vector3]) -> void:
	if perches.is_empty():
		return
	perch = clampi(perch, 0, perches.size() - 1)
	var goal := perches[perch]
	if position.distance_to(goal) > 0.02:
		running = true
		_face(goal - position)
		position = position.move_toward(goal, CLIMB * delta)
		return
	running = false
	_wait -= delta
	if _wait <= 0.0:
		_wait = _rng.randf_range(3.0, 7.0)
		var step := 1 if _rng.randf() < 0.5 else -1
		perch = clampi(perch + step, 0, perches.size() - 1) if perches.size() > 1 else 0
		if perches[perch].distance_to(position) < 0.02 and perches.size() > 1:
			perch = clampi(perch - step, 0, perches.size() - 1)  # at the end of the list she turns back
		running = perches[perch].distance_to(position) > 0.02  # she is off at once


## A step ashore: `captain` is where the captain stands, `heading` the way he faces (radians round y).
func ashore(delta: float, captain: Vector3, heading: float) -> void:
	var beside := captain + Vector3(cos(heading), 0, -sin(heading)) * SIDE - Vector3(sin(heading), 0, cos(heading)) * 0.6
	var away := Vector2(position.x - captain.x, position.z - captain.z).length()
	if running and away < NEAR:
		running = false
	elif not running and away > FAR:
		running = true
	if running:
		var to := Vector3(beside.x, captain.y, beside.z)
		_face(to - position)
		position = position.move_toward(to, RUN * delta)
		if position.distance_to(to) < 0.05:
			running = false
	else:
		position.y = lerpf(position.y, captain.y, minf(8.0 * delta, 1.0))
		_face(captain - position)  # sitting, she watches him


func _face(way: Vector3) -> void:
	if Vector2(way.x, way.z).length() > 0.001:
		yaw = atan2(way.x, way.z)

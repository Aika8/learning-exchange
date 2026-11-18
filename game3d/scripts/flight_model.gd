## Pattern: pure model — the ship in free flight: wheel, sail, height, wind; islands are solid, the world has an
## edge, a berth can be moored at. No scene, no input, no clock: the voyage scene steps it and draws what it says.
## See docs/adr/0032-game3d-free-flight-between-islands.md
class_name FlightModel
extends RefCounted

const BASE_SPEED := 14.0  ## metres a second with the sail full and no wind
const DRIFT := 0.25  ## share of base speed with no sail at all
const TURN := 0.75  ## radians a second with the wheel hard over, at full speed
const CLIMB := 6.0  ## metres a second
const TRIM_RATE := 0.6  ## how fast the sail is taken in or let out, per second
const PICK_UP := 0.8  ## how quickly speed follows what sail and wind allow, per second
const HULL := 5.0  ## the ship's own radius, metres
const MOOR_REACH := 16.0  ## how near the berth
const MOOR_SPEED := 9.0  ## and how slow, to moor
const EDGE_SOFT := 80.0  ## the Current begins to push back this far inside the edge

var position := Vector3.ZERO
var yaw := 0.0  ## heading: 0 looks along −z, growing to the left (as Godot's rotation.y)
var speed := 0.0
var trim := 1.0  ## 0 = sail down, 1 = full
var flown := 0.0  ## metres covered since leaving
var bumped := false  ## true on a step that ran into an island
var floor_y := -30.0  ## never lower: the cloud sea
var ceiling_y := 90.0
var centre := Vector3.ZERO  ## the world's middle and how far from it the ship may go
var world_radius := 600.0
var islands: Array[Dictionary] = []  ## {centre: Vector3 (its top), radius, depth}: solid cylinders


func heading() -> Vector3:
	return Vector3(-sin(yaw), 0, -cos(yaw))


## Wind help in [−1, 1]: 1 when the wind blows along the course.
func wind_help(wind: Vector3) -> float:
	var w := Vector3(wind.x, 0, wind.z)
	return w.normalized().dot(heading()) if w.length() > 0.001 else 0.0


## The speed the ship settles at with this sail and wind.
func cruising(wind: Vector3, slowed: float = 1.0) -> float:
	return BASE_SPEED * maxf(DRIFT, trim * (1.0 + 0.5 * wind_help(wind))) * slowed


## One step. `rudder` −1 (right) … 1 (left), `sail` −1 (take in) … 1 (let out), `climb` −1 … 1.
## `slowed` < 1 in a storm; `gust` is a sideways push in metres a second.
func step(delta: float, rudder: float, sail: float, climb: float, wind: Vector3, slowed: float = 1.0, gust: Vector3 = Vector3.ZERO) -> void:
	trim = clampf(trim + sail * TRIM_RATE * delta, 0.0, 1.0)
	speed = move_toward(speed, cruising(wind, slowed), BASE_SPEED * PICK_UP * delta)
	yaw += clampf(rudder, -1.0, 1.0) * TURN * delta * clampf(speed / BASE_SPEED + 0.25, 0.25, 1.0)  # a slow ship answers the wheel slowly
	var before := position
	position += (heading() * speed + gust) * delta
	position.y = clampf(position.y + clampf(climb, -1.0, 1.0) * CLIMB * delta, floor_y, ceiling_y)
	_keep_inside(delta)
	bumped = _keep_out()
	flown += Vector2(position.x - before.x, position.z - before.z).length()


## The edge of the world: the Current pushes back, harder the nearer; the ship never crosses.
func _keep_inside(delta: float) -> void:
	var out := Vector2(position.x - centre.x, position.z - centre.z)
	var r := out.length()
	if r <= world_radius - EDGE_SOFT:
		return
	var push := clampf((r - (world_radius - EDGE_SOFT)) / EDGE_SOFT, 0.0, 1.0)
	var inward := -out.normalized()
	position.x += inward.x * push * BASE_SPEED * 1.2 * delta
	position.z += inward.y * push * BASE_SPEED * 1.2 * delta
	out = Vector2(position.x - centre.x, position.z - centre.z)
	if out.length() > world_radius:
		out = out.normalized() * world_radius
		position.x = centre.x + out.x
		position.z = centre.z + out.y


## How strongly the edge pushes here: 0 well inside, 1 at the edge. For the HUD.
func edge_push() -> float:
	var r := Vector2(position.x - centre.x, position.z - centre.z).length()
	return clampf((r - (world_radius - EDGE_SOFT)) / EDGE_SOFT, 0.0, 1.0)


## Islands are solid: pushes the ship out of any it has entered. True when it had to.
func _keep_out() -> bool:
	var hit := false
	for isl in islands:
		var c: Vector3 = isl["centre"]
		var reach := float(isl["radius"]) + HULL
		var clear_top := c.y + 3.0  # the keel clears the grass by this much to pass over
		var bottom := c.y - float(isl["depth"])
		if position.y > clear_top + 6.0 or position.y < bottom - 4.0:
			continue
		var out := Vector2(position.x - c.x, position.z - c.z)
		# the rock narrows downwards: at the bottom it is a third as wide
		var depth_share := clampf((c.y - position.y) / maxf(float(isl["depth"]), 0.001), 0.0, 1.0)
		var r_here := lerpf(reach, reach * 0.35, depth_share)
		if out.length() >= r_here:
			continue
		var side := r_here - out.length()  # how far to the cliff face
		var up := clear_top + 6.0 - position.y  # how far to clear the top
		if position.y > c.y and up < side:  # skimming over the top: lifted, not stopped
			position.y += up
		else:
			var away := out.normalized() if out.length() > 0.001 else Vector2(-heading().x, -heading().z)
			position.x = c.x + away.x * r_here
			position.z = c.z + away.y * r_here
			var into := maxf(0.0, -Vector2(heading().x, heading().z).dot(away))
			speed *= 1.0 - into  # what was driven into the rock is lost
		hit = true
	return hit


func distance_to(point: Vector3) -> float:
	return Vector2(point.x - position.x, point.z - position.z).length()


## Where `point` lies from the bow: 0 dead ahead, positive to the left, in radians (−π … π].
func bearing_to(point: Vector3) -> float:
	var to := Vector2(point.x - position.x, point.z - position.z)
	if to.length() < 0.001:
		return 0.0
	var h := heading()
	return atan2(h.x * to.y - h.z * to.x, h.x * to.x + h.z * to.y) * -1.0


func can_moor(berth: Vector3) -> bool:
	return distance_to(berth) <= MOOR_REACH and absf(position.y - berth.y) <= 8.0 and speed <= MOOR_SPEED

## Walking for everybody on foot (the captain, villagers, the audit probe): one place for speed, acceleration,
## gravity and how a body follows the ground — slopes, kerbs and stairs — so the world audit walks exactly like the
## player does. Bodies are CharacterBody3D with the capsule from `capsule()`.
class_name Mover
extends RefCounted

const WALK := 4.2  ## the captain's easy pace, m/s
const RUN := 7.0  ## with Shift
const ACCEL := 22.0  ## m/s² when pushing off
const DECEL := 30.0  ## m/s² when letting go
const GRAVITY := 22.0
const RADIUS := 0.4
const HEIGHT := 1.9
const STEP := 0.45  ## the tallest stair a walker climbs without a jump
const SLOPE := 46.0  ## degrees; steeper ground is a wall


## The capsule every walker uses, feet at the body's origin.
static func capsule(body: CollisionObject3D, radius: float = RADIUS, height: float = HEIGHT) -> CollisionShape3D:
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = radius
	cap.height = height
	shape.shape = cap
	shape.position.y = height * 0.5
	body.add_child(shape)
	return shape


## Floor settings shared by every walker.
static func setup(body: CharacterBody3D) -> void:
	body.floor_max_angle = deg_to_rad(SLOPE)
	body.floor_snap_length = 0.4  # stays on the ground down stairs and over the brow of a hill
	body.floor_stop_on_slope = true
	body.floor_constant_speed = true
	body.floor_block_on_wall = true
	body.max_slides = 5


## One physics step towards `wish` (a flat direction, length 0..1) at up to `speed` m/s. Speeds up and slows down
## instead of snapping; climbs a stair up to STEP high. Returns how far the body was lifted onto a stair this step
## (callers smooth their camera and model by it).
static func step(body: CharacterBody3D, wish: Vector3, delta: float, speed: float = WALK) -> float:
	var flat := Vector3(body.velocity.x, 0, body.velocity.z)
	var target := Vector3(wish.x, 0, wish.z) * speed
	flat = flat.move_toward(target, (ACCEL if target.length() > 0.05 else DECEL) * delta)
	var floored := body.is_on_floor()
	body.velocity = Vector3(flat.x, 0.0 if floored else body.velocity.y - GRAVITY * delta, flat.z)
	var lifted := _climb(body, flat, delta) if floored and flat.length() > 0.3 else 0.0
	body.move_and_slide()
	return lifted


## Stairs: when something low blocks the way, try the same move from STEP higher and land on what is there.
static func _climb(body: CharacterBody3D, flat: Vector3, delta: float) -> float:
	var from := body.global_transform
	# far enough ahead that the round foot of the capsule lands on the tread, not on its edge, one step before
	# the body would hit the riser and lose its speed
	var ahead := flat.normalized() * maxf(flat.length() * delta, 0.2)
	var hit := KinematicCollision3D.new()
	if not body.test_move(from, ahead, hit) or hit.get_normal().y > 0.7:
		return 0.0  # nothing in the way, or a slope the slide handles
	if body.test_move(from, Vector3.UP * STEP):
		return 0.0  # no headroom
	var raised := from.translated(Vector3.UP * STEP)
	if body.test_move(raised, ahead):
		return 0.0  # a wall, not a stair
	var down := KinematicCollision3D.new()
	if not body.test_move(raised.translated(ahead), Vector3.DOWN * STEP, down):
		return 0.0
	if down.get_normal().y < cos(deg_to_rad(SLOPE)):
		return 0.0
	var rise := STEP - down.get_travel().length()
	if rise < 0.02 or rise > STEP - 0.03:
		return 0.0  # level ground, or the probe started inside something: not a stair
	body.global_position += Vector3.UP * (rise + 0.01) + ahead
	return rise

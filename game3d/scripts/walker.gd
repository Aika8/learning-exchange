## Procedural gait with foot IK for the MakeHuman people (game-engine rig: pelvis, thigh_l, calf_l, foot_l,
## upperarm_l, …). No downloaded animation: the cycle is computed — each foot is planted while it carries the body
## (it moves back exactly as fast as the body moves forward, so it does not slide), swings forward in an arc, and
## is put on the ground it finds under it (stairs, slopes). A two-bone IK bends the knee; the pelvis drops and
## sways, the spine leans into a run, the arms swing against the legs. Standing still it breathes and shifts weight.
## Walk, run and idle are one cycle blended by speed. Our own code (game3d/ASSETS.md).
## Without a skeleton (the procedural figure) it does nothing and `bob()` stands in.
class_name Walker
extends RefCounted

const LEGS: Array[String] = ["l", "r"]

var skeleton: Skeleton3D
var figure: Node3D
var ground: Callable  ## optional: func(world: Vector3) -> float, the ground height under a point
var _b: Dictionary = {}  ## bone name → index
var _rest: Dictionary = {}  ## bone name → global rest Transform3D (skeleton space)
var _side: Dictionary = {}  ## bone name → the model's side axis in that bone's frame
var _to_body := Transform3D()  ## skeleton space → figure space
var _up := Vector3.UP  ## figure axes in skeleton space
var _fwd := Vector3.BACK
var _right := Vector3.RIGHT
var _unit := 1.0  ## skeleton units per metre
var _phase := 0.0  ## 0..1, one full cycle = two steps
var _amount := 0.0  ## 0 standing .. 1 moving
var _speed := 0.0
var _time := 0.0
var _feet: Dictionary = {"l": 0.0, "r": 0.0}  ## smoothed ground offset under each foot, metres


static func attach(person: Node3D) -> Walker:
	var w := Walker.new()
	w.figure = person
	var found := person.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		return w
	w.skeleton = found[0]
	var sk := w.skeleton
	for n: String in ["pelvis", "spine_01", "spine_02", "neck_01", "thigh_l", "thigh_r", "calf_l", "calf_r", "foot_l", "foot_r",
			"upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r"]:
		var i := sk.find_bone(n)
		if i < 0:
			continue
		w._b[n] = i
		w._rest[n] = sk.get_bone_global_rest(i)
		w._side[n] = ((w._rest[n] as Transform3D).basis.orthonormalized().inverse() * Vector3.RIGHT).normalized()
	w._to_body = Solid._relative(person, sk)
	var inv := w._to_body.basis.orthonormalized().inverse()
	w._up = inv * Vector3.UP
	w._fwd = inv * Vector3.BACK  # the people face +z
	w._right = inv * Vector3.RIGHT
	w._unit = 1.0 / maxf(0.001, w._to_body.basis.get_scale().y)
	return w


## A ground probe for `walker.ground`: a ray straight down through the world, ignoring `body` itself.
static func ground_under(body: CollisionObject3D) -> Callable:
	return func(world: Vector3) -> float:
		var q := PhysicsRayQueryParameters3D.create(world + Vector3(0, 0.7, 0), world + Vector3(0, -0.9, 0))
		q.exclude = [body.get_rid()]
		var hit := body.get_world_3d().direct_space_state.intersect_ray(q)
		return (hit["position"] as Vector3).y if not hit.is_empty() else body.global_position.y


func animated() -> bool:
	return skeleton != null and _b.has("thigh_l") and _b.has("calf_l") and _b.has("foot_l") and _b.has("pelvis")


## Advances the cycle. `speed` in m/s (0 = stand); call every frame.
func step(delta: float, speed: float) -> void:
	_time += delta
	_speed = lerpf(_speed, speed, minf(1.0, 10.0 * delta))
	_amount = lerpf(_amount, 1.0 if speed > 0.25 else 0.0, minf(1.0, 7.0 * delta))
	if _speed > 0.1:
		_phase = fposmod(_phase + delta / period(_speed), 1.0)
	if animated():
		_pose(delta)


## Seconds per full cycle (two steps) at a speed: a stroll is slow and long, a run is quick.
static func period(speed: float) -> float:
	return lerpf(1.15, 0.56, clampf((speed - 1.0) / 6.0, 0.0, 1.0))


## Share of the cycle a foot spends on the ground: more than half walking (double support), less running (flight).
static func stance(speed: float) -> float:
	return lerpf(0.62, 0.4, smoothstep(2.6, 5.6, speed))


## Where a foot is in its cycle at phase `p` (0 = heel strike): [forward offset −1..1 of the half stride, lift 0..1].
static func foot_cycle(p: float, stance_share: float) -> Vector2:
	if p < stance_share:
		return Vector2(1.0 - 2.0 * p / stance_share, 0.0)
	var u := (p - stance_share) / (1.0 - stance_share)
	return Vector2(-1.0 + 2.0 * smoothstep(0.0, 1.0, u), sin(PI * u))


func _pose(delta: float) -> void:
	var sk := skeleton
	for n: String in _b:
		sk.reset_bone_pose(_b[n])
	var a := _amount
	var run := smoothstep(2.6, 5.6, _speed)
	var share := stance(_speed)
	var leg_len := ((_rest["thigh_l"] as Transform3D).origin.distance_to((_rest["foot_l"] as Transform3D).origin)) / _unit
	var half := minf(_speed * share * period(_speed) * 0.5, 0.62 * leg_len) * a
	var breath := sin(_time * 1.7)
	# the ground under each foot, relative to the body's feet
	var lowest := 0.0
	for s in LEGS:
		var want := 0.0
		if ground.is_valid():
			var cyc := foot_cycle(fposmod(_phase + (0.0 if s == "l" else 0.5), 1.0), share)
			var rest_s: Vector3 = (_rest["foot_" + s] as Transform3D).origin + _fwd * cyc.x * half * _unit
			var world := figure.global_transform * (_to_body * rest_s)
			want = clampf(float(ground.call(world)) - figure.global_position.y, -0.5, 0.5)
		_feet[s] = lerpf(_feet[s], want, minf(1.0, 14.0 * delta))
		lowest = minf(lowest, _feet[s])
	# pelvis: sinks at heel strike, rises over the standing leg, sways to it; drops to let the lower foot reach
	var bob := -cos(_phase * 2.0 * TAU) * lerpf(0.018, 0.045, run) * a - lerpf(0.02, 0.1, run) * a
	var sway := sin(_phase * TAU) * lerpf(0.025, 0.01, run) * a + sin(_time * 0.45) * 0.012 * (1.0 - a)
	var offset := (_up * (bob + breath * 0.004 + lowest) + _right * sway) * _unit
	var pelvis: int = _b["pelvis"]
	var parent := sk.get_bone_parent(pelvis)
	var parent_basis := sk.get_bone_global_rest(parent).basis if parent >= 0 else Basis()
	sk.set_bone_pose_position(pelvis, sk.get_bone_rest(pelvis).origin + parent_basis.inverse() * offset)
	_turn_about("pelvis", _up, sin(_phase * TAU) * 0.09 * a)
	_turn("spine_01", lerpf(0.05, 0.2, run) * a + breath * 0.012)
	_turn_about("spine_02", _up, -sin(_phase * TAU) * 0.12 * a)
	_turn("neck_01", -lerpf(0.02, 0.1, run) * a)
	# legs
	for s in LEGS:
		var cyc := foot_cycle(fposmod(_phase + (0.0 if s == "l" else 0.5), 1.0), share)
		var rest: Vector3 = (_rest["foot_" + s] as Transform3D).origin
		var side := rest.dot(_right)
		var target := rest - _right * side * 0.3 * run * a  # a runner's feet land nearer the middle line
		target += _fwd * cyc.x * half * _unit
		target += _up * (cyc.y * lerpf(0.1, 0.3, run) * a + float(_feet[s])) * _unit
		var pitch := 0.0  # toes down as the foot pushes off and trails, up for the heel strike
		if cyc.y > 0.0:
			pitch = lerpf(0.55, -0.3, smoothstep(0.0, 1.0, (cyc.x + 1.0) * 0.5)) * a * lerpf(0.6, 1.0, run)
		elif cyc.x < -0.5:
			pitch = (-cyc.x - 0.5) * 0.8 * a
		_leg(s, target, pitch)
	# arms swing against the legs; a runner bends the elbows
	var swing := cos(_phase * TAU) * lerpf(0.3, 0.75, run) * a
	_turn("upperarm_l", swing + sin(_time * 0.8) * 0.02)
	_turn("upperarm_r", -swing - sin(_time * 0.8) * 0.02)
	_turn("lowerarm_l", -lerpf(0.2, 1.25, run) * a - 0.12 * maxf(0.0, -swing))
	_turn("lowerarm_r", -lerpf(0.2, 1.25, run) * a - 0.12 * maxf(0.0, swing))


## Two-bone IK: puts the ankle of leg `s` at `target` (skeleton space), the knee bending forward.
func _leg(s: String, target: Vector3, pitch: float) -> void:
	var sk := skeleton
	var thigh: int = _b["thigh_" + s]
	var calf: int = _b["calf_" + s]
	var foot: int = _b["foot_" + s]
	var r_hip: Transform3D = _rest["thigh_" + s]
	var r_knee: Transform3D = _rest["calf_" + s]
	var r_ankle: Transform3D = _rest["foot_" + s]
	var l1 := r_hip.origin.distance_to(r_knee.origin)
	var l2 := r_knee.origin.distance_to(r_ankle.origin)
	var hip := sk.get_bone_global_pose(thigh).origin
	var to := target - hip
	var reach := clampf(to.length(), 0.05 * (l1 + l2), 0.999 * (l1 + l2))
	var dir := to.normalized()
	var bend := acos(clampf((l1 * l1 + reach * reach - l2 * l2) / (2.0 * l1 * reach), -1.0, 1.0))
	var axis := dir.cross(_fwd)
	axis = _right if axis.length() < 0.001 else axis.normalized()
	var knee_dir := dir.rotated(axis, bend)
	if dir.rotated(axis, -bend).dot(_fwd) > knee_dir.dot(_fwd):
		knee_dir = dir.rotated(axis, -bend)
	var hip_pose := sk.get_bone_global_pose(thigh)
	var q1 := Quaternion((r_knee.origin - r_hip.origin).normalized(), knee_dir)
	sk.set_bone_global_pose(thigh, Transform3D(Basis(q1) * r_hip.basis, hip_pose.origin))
	var knee_pose := sk.get_bone_global_pose(calf)
	var ankle_now := sk.get_bone_global_pose(foot).origin
	var q2 := Quaternion((ankle_now - knee_pose.origin).normalized(), (hip + dir * reach - knee_pose.origin).normalized())
	sk.set_bone_global_pose(calf, Transform3D(Basis(q2) * knee_pose.basis, knee_pose.origin))
	var ankle_pose := sk.get_bone_global_pose(foot)
	sk.set_bone_global_pose(foot, Transform3D(Basis(_right, pitch) * r_ankle.basis, ankle_pose.origin))


## Turns a bone about the model's side axis (positive = the hanging limb goes back).
func _turn(bone: String, angle: float) -> void:
	if _b.has(bone):
		skeleton.set_bone_pose_rotation(_b[bone], skeleton.get_bone_pose_rotation(_b[bone]) * Quaternion(_side[bone], angle))


## Turns a bone about an axis given in skeleton space.
func _turn_about(bone: String, axis: Vector3, angle: float) -> void:
	if _b.has(bone):
		var local := ((_rest[bone] as Transform3D).basis.orthonormalized().inverse() * axis).normalized()
		skeleton.set_bone_pose_rotation(_b[bone], skeleton.get_bone_pose_rotation(_b[bone]) * Quaternion(local, angle))


## Vertical bob of the body for the procedural figure (no skeleton).
func bob() -> float:
	return absf(sin(_phase * TAU)) * 0.06 * _amount

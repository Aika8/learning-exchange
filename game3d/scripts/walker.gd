## A procedural walk cycle for the MakeHuman people (game-engine rig: thigh_l, calf_l, upperarm_l, …): legs and arms
## swing about the body's side axis, knees bend on the forward swing, the pelvis bobs. Our own code, no downloaded
## animation (game3d/ASSETS.md). Without a skeleton (procedural figure) it does nothing and `bob()` stands in.
class_name Walker
extends RefCounted

const SWING := 0.42  ## thigh swing, radians at full stride
const KNEE := 0.65
const ARM := 0.32

var skeleton: Skeleton3D
var _bones: Dictionary = {}  ## name → [index, rest rotation, side axis in bone space]
var _phase := 0.0
var _amount := 0.0


static func attach(person: Node3D) -> Walker:
	var w := Walker.new()
	var found := person.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		return w
	w.skeleton = found[0]
	for n: String in ["pelvis", "spine_01", "thigh_l", "thigh_r", "calf_l", "calf_r", "foot_l", "foot_r", "upperarm_l",
			"upperarm_r", "lowerarm_l", "lowerarm_r"]:
		var i := w.skeleton.find_bone(n)
		if i < 0:
			continue
		var g := w.skeleton.get_bone_global_rest(i).basis.orthonormalized()
		var axis := (g.inverse() * Vector3.RIGHT).normalized()  # the model's side axis (x) in this bone's frame
		w._bones[n] = [i, w.skeleton.get_bone_rest(i).basis.get_rotation_quaternion(), axis]
	return w


func animated() -> bool:
	return skeleton != null and not _bones.is_empty()


## Advances the cycle. `speed` in m/s (0 = stand); call every frame.
func step(delta: float, speed: float) -> void:
	_amount = lerpf(_amount, clampf(speed / 5.0, 0.0, 1.0), minf(1.0, 8.0 * delta))
	_phase = fmod(_phase + delta * (2.2 + speed * 0.9), TAU)
	if animated():
		_pose()


func _pose() -> void:
	var s := sin(_phase) * _amount
	var c := cos(_phase) * _amount
	_turn("thigh_l", -SWING * s)
	_turn("thigh_r", SWING * s)
	_turn("calf_l", KNEE * maxf(0.0, c))  # the knee folds while that leg swings forward
	_turn("calf_r", KNEE * maxf(0.0, -c))
	_turn("foot_l", -0.25 * maxf(0.0, c))
	_turn("foot_r", -0.25 * maxf(0.0, -c))
	_turn("upperarm_l", ARM * s)
	_turn("upperarm_r", -ARM * s)
	_turn("lowerarm_l", -0.25 * _amount - 0.15 * maxf(0.0, s))
	_turn("lowerarm_r", -0.25 * _amount - 0.15 * maxf(0.0, -s))
	_turn("spine_01", 0.05 * _amount)


func _turn(bone: String, angle: float) -> void:
	if not _bones.has(bone):
		return
	var b: Array = _bones[bone]
	skeleton.set_bone_pose_rotation(b[0], (b[1] as Quaternion) * Quaternion(b[2], angle))


## Vertical bob of the body for the procedural figure (no skeleton) or as extra life.
func bob() -> float:
	return absf(sin(_phase)) * 0.06 * _amount

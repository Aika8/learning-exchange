## The ship's monkey (docs/design/concepts/72-ship-monkey.jpg; ADR-0036): our own small capuchin in a red waistcoat
## with a brass earring. A character of the world — drawn in each island's technique like the captain — not a part
## of the ship. Give her `ship` (she lives in its rig) or `follow` (she keeps near that body ashore).
## Her decisions are `MonkeyMind`; this node is the body and its two poses, sitting and running.
class_name Monkey
extends CharacterBody3D  # a creature, like the captain and the islanders — though she has no shape and stops nobody

const FUR := Color("4a2c11")
const FACE := Color("ebdcc3")
const VEST := Color("a82a2a")
const BRASS := Color("d4a23e")

var mind := MonkeyMind.new()
var ship: Node3D  ## under way: the ship whose rig she lives in
var follow: Node3D  ## in port: whom she keeps near
var _trunk: Node3D
var _limbs: Array[Node3D] = []
var _tail: Array[Node3D] = []
var _t := 0.0


func _ready() -> void:
	name = "Monkey"
	collision_layer = 0  # she walks where she likes and is in nobody's way
	collision_mask = 0
	_build()
	if ship != null:
		mind.position = Wayfarer.perches()[0]
	elif follow != null:
		mind.position = follow.global_position + Vector3(0.9, 0, 0.6)
	_place()


func _process(delta: float) -> void:
	_t += delta
	if ship != null and is_instance_valid(ship):
		mind.aboard(delta, Wayfarer.perches())
	elif follow != null and is_instance_valid(follow):
		var heading: Variant = follow.get("yaw")
		mind.ashore(delta, follow.global_position, float(heading) if heading != null else follow.rotation.y)
	_place()
	_pose(delta)


func _place() -> void:
	if ship != null and is_instance_valid(ship):
		global_transform = ship.global_transform * Transform3D(Basis(Vector3.UP, mind.yaw), mind.position)
	else:
		global_position = mind.position
		rotation = Vector3(0, mind.yaw, 0)


## Sitting: upright, tail curled on the ground. Running: on all fours, limbs swinging, tail out behind.
func _pose(delta: float) -> void:
	var lean := 1.25 if mind.running else 0.15
	_trunk.rotation.x = lerp_angle(_trunk.rotation.x, lean, minf(10.0 * delta, 1.0))
	_trunk.position.y = lerpf(_trunk.position.y, 0.2 if mind.running else 0.17, minf(10.0 * delta, 1.0))
	for i in _limbs.size():
		var swing := sin(_t * 16.0 + (PI if i % 2 == 0 else 0.0)) * 0.7 if mind.running else (0.9 if i >= 2 else -0.3)
		_limbs[i].rotation.x = lerp_angle(_limbs[i].rotation.x, swing - lean * (0.0 if mind.running else 0.0), minf(14.0 * delta, 1.0))
	for i in _tail.size():
		var curl := 0.25 + 0.1 * sin(_t * 3.0 + i) if mind.running else 0.75
		_tail[i].rotation.x = lerp_angle(_tail[i].rotation.x, -curl, minf(6.0 * delta, 1.0))


func _build() -> void:
	_trunk = Node3D.new()
	_trunk.name = "Trunk"
	_trunk.position = Vector3(0, 0.17, 0)
	add_child(_trunk)
	_trunk.add_child(Proc.mesh_node(Proc._capsule(0.075, 0.26), Proc.mat(FUR), Vector3(0, 0.1, 0)))
	_trunk.add_child(Proc.cyl(0.082, 0.086, 0.15, 10, VEST, Vector3(0, 0.12, 0)))  # the waistcoat
	for y: float in [0.08, 0.14]:
		_trunk.add_child(Proc.ball(0.012, BRASS, Vector3(0, y, 0.085)))
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.29, 0.02)
	_trunk.add_child(head)
	head.add_child(Proc.ball(0.075, FUR))
	var face := Proc.ball(0.058, FACE, Vector3(0, -0.008, 0.032))
	face.scale = Vector3(1.0, 1.0, 0.7)
	head.add_child(face)
	head.add_child(Proc.ball(0.03, FACE.darkened(0.25), Vector3(0, -0.03, 0.062)))  # the muzzle
	for sx: float in [-1.0, 1.0]:
		head.add_child(Proc.ball(0.011, Color("1a120c"), Vector3(sx * 0.026, 0.008, 0.068)))  # eyes
		head.add_child(Proc.ball(0.024, FACE.darkened(0.15), Vector3(sx * 0.072, 0.0, 0.0)))  # ears
	head.add_child(Proc.ball(0.012, BRASS, Vector3(0.078, -0.03, 0.0)))  # the earring
	for i in 4:  # two arms, two legs: thin, long-handed
		var limb := Node3D.new()
		limb.position = Vector3((-0.07 if i % 2 == 0 else 0.07), 0.2 if i < 2 else 0.02, 0.02)
		limb.add_child(Proc.cyl(0.018, 0.024, 0.2, 6, FUR, Vector3(0, -0.1, 0)))
		limb.add_child(Proc.ball(0.024, FACE.darkened(0.3), Vector3(0, -0.2, 0.01)))
		_trunk.add_child(limb)
		_limbs.append(limb)
	var joint: Node3D = _trunk  # the tail: five short pieces, each bent on the one before
	for i in 5:
		var piece := Node3D.new()
		piece.position = Vector3(0, -0.02, -0.06) if i == 0 else Vector3(0, 0, -0.085)
		piece.add_child(Proc.cyl(0.012, 0.016, 0.09, 5, FUR, Vector3(0, 0, -0.045)).duplicate())
		(piece.get_child(0) as Node3D).rotation.x = PI / 2
		joint.add_child(piece)
		_tail.append(piece)
		joint = piece

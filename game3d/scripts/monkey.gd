## The ship's monkey (docs/design/concepts/72-ship-monkey.jpg; ADR-0036): our own small capuchin — a dark cap of
## fur over a pale face, a red waistcoat with brass buttons, a brass earring, a long curled tail. A character of the
## world — drawn in each island's technique like the captain — not a part of the ship. Give her `ship` (she lives
## in its rig) or `follow` (she keeps near that body ashore). Her decisions are `MonkeyMind`; this node is the
## body and its four poses: sitting, sitting with the spyglass to her eye, climbing, running.
class_name Monkey
extends CharacterBody3D  # a creature, like the captain and the islanders — though she has no shape and stops nobody

const FUR := Color("4a2c11")
const DARK_FUR := Color("2a180b")
const FACE := Color("ebdcc3")
const SKIN := Color("6b4a36")
const VEST := Color("a82a2a")
const BRASS := Color("d4a23e")
const POSES: Array[String] = ["sit", "scope", "climb", "run"]

var mind := MonkeyMind.new()
var ship: Node3D  ## under way: the ship whose rig she lives in
var follow: Node3D  ## in port: whom she keeps near
var _trunk: Node3D
var _head: Node3D
var _glass: Node3D
var _limbs: Array[Node3D] = []  ## left arm, right arm, left leg, right leg
var _tail: Array[Node3D] = []
var _t := 0.0


func _ready() -> void:
	name = "Monkey"
	collision_layer = 0  # she walks where she likes and is in nobody's way
	collision_mask = 0
	_build()
	if ship != null:
		mind.position = Wayfarer.perches(ship.has_meta("model"))[0]
	elif follow != null:
		mind.position = follow.global_position + Vector3(0.9, 0, 0.6)
	_place()


func _process(delta: float) -> void:
	_t += delta
	if ship != null and is_instance_valid(ship):
		mind.aboard(delta, Wayfarer.perches(ship.has_meta("model")))
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


## The angles of a pose: how far the trunk leans forward, each limb's swing (arms, then legs), how the head is
## held, how tightly the tail curls, whether the spyglass is up.
func _pose(delta: float) -> void:
	var pose := mind.pose
	var lean := 0.12
	var limbs := [-0.35, -0.35, -1.3, -1.3]  # sitting: hands on the knees, legs folded forward
	var head := 0.0
	var curl := 0.72
	match pose:
		"scope":
			limbs = [-2.05, -1.75, -1.3, -1.3]  # both hands up to the glass
			head = -0.12
		"run":
			lean = 1.3  # on all fours
			var s := sin(_t * 16.0) * 0.75
			limbs = [-1.3 + s, -1.3 - s, -1.3 - s, -1.3 + s]
			head = -1.0  # she looks where she runs, not at the ground
			curl = 0.22 + 0.08 * sin(_t * 5.0)
		"climb":
			lean = -0.1
			var s := sin(_t * 9.0) * 0.8
			limbs = [-2.3 + s, -2.3 - s, -0.6 - s, -0.6 + s]  # hand over hand
			head = -0.5
			curl = 0.12
	var quick := minf(12.0 * delta, 1.0)
	_trunk.rotation.x = lerp_angle(_trunk.rotation.x, lean, quick)
	_trunk.position.y = lerpf(_trunk.position.y, 0.21 if pose == "run" else 0.17, quick)
	_head.rotation.x = lerp_angle(_head.rotation.x, head, quick)
	for i in _limbs.size():
		_limbs[i].rotation.x = lerp_angle(_limbs[i].rotation.x, limbs[i], minf(16.0 * delta, 1.0))
	for i in _tail.size():
		_tail[i].rotation.x = lerp_angle(_tail[i].rotation.x, curl * (0.5 + 0.12 * i), minf(6.0 * delta, 1.0))  # it curls up and over, never into the ground
	_glass.visible = pose == "scope"


func _build() -> void:
	_trunk = Node3D.new()
	_trunk.name = "Trunk"
	_trunk.position = Vector3(0, 0.17, 0)
	add_child(_trunk)
	_trunk.add_child(Proc.mesh_node(Proc._capsule(0.07, 0.27), Proc.mat(FUR), Vector3(0, 0.1, 0)))
	var chest := Proc.ball(0.062, FACE.darkened(0.12), Vector3(0, 0.17, 0.035))  # the pale chest under the open waistcoat
	chest.scale = Vector3(0.8, 1.3, 0.6)
	_trunk.add_child(chest)
	for sx: float in [-1.0, 1.0]:  # the waistcoat: two red fronts and a back, a brass edge, two buttons
		var front := Proc.cyl(0.08, 0.084, 0.17, 10, VEST, Vector3(sx * 0.012, 0.115, 0))
		front.scale = Vector3(0.62, 1.0, 1.0)
		front.position.x = sx * 0.034
		_trunk.add_child(front)
		_trunk.add_child(Proc.box(Vector3(0.008, 0.17, 0.008), BRASS, Vector3(sx * 0.03, 0.115, 0.08)))
		_trunk.add_child(Proc.ball(0.011, BRASS, Vector3(sx * 0.045, 0.09 + (0.05 if sx > 0 else 0.0), 0.078)))
	_head = Node3D.new()
	_head.name = "Head"
	_head.position = Vector3(0, 0.3, 0.015)
	_trunk.add_child(_head)
	_head.add_child(Proc.ball(0.074, FUR))
	var cap := Proc.ball(0.066, DARK_FUR, Vector3(0, 0.03, -0.012))  # the dark cap of a capuchin
	cap.scale = Vector3(1.05, 0.8, 1.05)
	_head.add_child(cap)
	var face := Proc.ball(0.058, FACE, Vector3(0, -0.006, 0.03))
	face.scale = Vector3(1.0, 1.05, 0.7)
	_head.add_child(face)
	var muzzle := Proc.ball(0.032, SKIN.lightened(0.25), Vector3(0, -0.032, 0.06))
	muzzle.scale = Vector3(1.1, 0.8, 0.9)
	_head.add_child(muzzle)
	_head.add_child(Proc.ball(0.007, DARK_FUR, Vector3(0, -0.026, 0.088)))  # the nose
	for sx: float in [-1.0, 1.0]:
		_head.add_child(Proc.ball(0.011, Color("1a120c"), Vector3(sx * 0.026, 0.008, 0.066)))  # eyes
		_head.add_child(Proc.box(Vector3(0.03, 0.007, 0.01), DARK_FUR, Vector3(sx * 0.026, 0.026, 0.066)))  # brows
		var ear := Proc.ball(0.024, SKIN, Vector3(sx * 0.072, 0.0, 0.0))
		ear.scale = Vector3(0.5, 1.0, 0.8)
		_head.add_child(ear)
	var ring := TorusMesh.new()  # the earring
	ring.inner_radius = 0.008
	ring.outer_radius = 0.013
	ring.rings = 10
	ring.ring_segments = 5
	var earring := Proc.mesh_node(ring, Proc.mat(BRASS), Vector3(0.076, -0.03, 0.0))
	earring.rotation.z = PI / 2
	_head.add_child(earring)
	_glass = Node3D.new()  # the spyglass, held to the right eye when she looks about
	_glass.name = "Spyglass"
	_glass.position = Vector3(0.026, 0.008, 0.075)
	for part: Array in [[0.016, 0.07, 0.035], [0.02, 0.07, 0.1], [0.024, 0.05, 0.158]]:
		var tube := Proc.cyl(part[0], part[0], part[1], 8, BRASS, Vector3(0, 0, part[2]))
		tube.rotation.x = PI / 2
		_glass.add_child(tube)
	_glass.visible = false
	_head.add_child(_glass)
	for i in 4:  # two arms, two legs: thin, long-handed
		var limb := Node3D.new()
		limb.position = Vector3((-0.068 if i % 2 == 0 else 0.068), 0.2 if i < 2 else 0.02, 0.02)
		limb.add_child(Proc.cyl(0.017, 0.022, 0.21, 6, FUR, Vector3(0, -0.105, 0)))
		limb.add_child(Proc.ball(0.023, SKIN, Vector3(0, -0.21, 0.008)))
		_trunk.add_child(limb)
		_limbs.append(limb)
	var joint: Node3D = _trunk  # the tail: nine short pieces, each bent on the one before — long, and curled at the end
	for i in 9:
		var piece := Node3D.new()
		piece.position = Vector3(0, -0.02, -0.055) if i == 0 else Vector3(0, 0, -0.07)
		var link := Proc.cyl(0.009 + 0.0008 * (9 - i), 0.011 + 0.0008 * (9 - i), 0.075, 5, FUR.darkened(0.04 * i), Vector3(0, 0, -0.035))
		link.rotation.x = PI / 2
		piece.add_child(link)
		joint.add_child(piece)
		_tail.append(piece)
		joint = piece

## Walking for everybody on foot (the captain, villagers, the audit probe): one place for speed, gravity and how a
## body follows the ground, so the world audit walks exactly like the player does.
class_name Mover
extends RefCounted

const SPEED := 7.0
const GRAVITY := 22.0
const RADIUS := 0.45
const HEIGHT := 2.0


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
static func setup(_body: CharacterBody3D) -> void:
	pass


## One physics step towards `wish` (a flat direction, length 0..1).
static func step(body: CharacterBody3D, wish: Vector3, delta: float) -> void:
	body.velocity.x = wish.x * SPEED
	body.velocity.z = wish.z * SPEED
	body.velocity.y = 0.0 if body.is_on_floor() else body.velocity.y - GRAVITY * delta
	body.move_and_slide()

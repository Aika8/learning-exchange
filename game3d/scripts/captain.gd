## The player's captain: third-person walking with an orbit camera on a spring arm (mouse to look, wheel to zoom).
class_name Captain
extends CharacterBody3D

const SPEED := 7.0
const GRAVITY := 22.0

var yaw := 0.0
var pitch := -0.32
var arm: SpringArm3D
var camera: Camera3D
var body: Node3D
var controlled := true
var _walk := 0.0


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45
	cap.height = 2.0
	shape.shape = cap
	shape.position.y = 1.0
	add_child(shape)
	body = Proc.figure(Color("2f5d8a"), Color("8a5a3c"))
	add_child(body)
	var scarf := Proc.box(Vector3(0.75, 0.16, 0.75), Hud.BRASS, Vector3(0, 1.38, 0))
	if Assets.available():  # a knitted brass scarf on the realistic figure (ADR-0019)
		var ring := TorusMesh.new()
		ring.inner_radius = 0.1
		ring.outer_radius = 0.2
		scarf = Proc.mesh_node(ring, Assets.pbr("quatrefoil_jacquard_fabric", Hud.BRASS, 3.0), Vector3(0, 1.47, 0))
	body.add_child(scarf)
	arm = SpringArm3D.new()
	arm.spring_length = 9.0
	arm.position.y = 2.0
	arm.margin = 0.3
	add_child(arm)
	camera = Camera3D.new()
	camera.fov = 60
	arm.add_child(camera)
	arm.add_excluded_object(get_rid())


func _unhandled_input(event: InputEvent) -> void:
	if not controlled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var m := event as InputEventMouseMotion
		yaw -= m.relative.x * 0.004
		pitch = clampf(pitch - m.relative.y * 0.003, -1.2, 0.25)
	elif event is InputEventMouseButton and event.pressed:
		var b := event as InputEventMouseButton
		if b.button_index == MOUSE_BUTTON_WHEEL_UP:
			arm.spring_length = maxf(3.5, arm.spring_length - 0.8)
		elif b.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			arm.spring_length = minf(22.0, arm.spring_length + 0.8)


func _physics_process(delta: float) -> void:
	arm.rotation = Vector3(pitch, yaw, 0)
	var input := Vector2.ZERO
	if controlled:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (Basis(Vector3.UP, yaw) * Vector3(input.x, 0, input.y)).normalized()
	velocity.x = dir.x * SPEED
	velocity.z = dir.z * SPEED
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	if position.y < -30.0:  # fell off the island: back to the square
		position = Vector3(0, 2, 0)
		velocity = Vector3.ZERO
	if dir.length() > 0.1:
		body.rotation.y = lerp_angle(body.rotation.y, atan2(dir.x, dir.z), 10.0 * delta)
		_walk += delta * 11.0
		body.position.y = absf(sin(_walk)) * 0.12
	else:
		body.position.y = lerpf(body.position.y, 0.0, 10.0 * delta)

## The player's captain: a MakeHuman character (CC0, «sailor») that walks with the shared Mover (acceleration,
## slopes, stairs), turns its body the way it goes, and is animated by the Walker (gait with foot IK). Third-person
## orbit camera on a spring arm that a wall pushes in, so it never looks through one (mouse to look, wheel to zoom,
## Shift to run). Without the downloaded people the procedural figure stands in and bobs.
class_name Captain
extends CharacterBody3D

const TURN := 11.0  ## how fast the body turns to the way it walks, 1/s

var yaw := 0.0
var pitch := -0.32
var arm: SpringArm3D
var camera: Camera3D
var body: Node3D
var controlled := true
var walker: Walker
var respawn := Vector3(0, 2, 0)  ## where a captain who somehow left the world comes back
var _zoom := 9.0
var _rise := 0.0  ## a stair just climbed, eased out so the model and the camera do not jump


func _ready() -> void:
	Mover.capsule(self)
	Mover.setup(self)
	body = Proc.figure(Color("2f5d8a"), Color("8a5a3c"), "sailor", "captain")
	add_child(body)
	walker = Walker.attach(body)
	walker.ground = Walker.ground_under(self)
	if not walker.animated() and not body.has_meta("stand_in"):  # procedural figure: the old brass scarf marks the captain
		var scarf := Proc.box(Vector3(0.75, 0.16, 0.75), Hud.BRASS, Vector3(0, 1.38, 0))
		if Assets.available():
			var ring := TorusMesh.new()
			ring.inner_radius = 0.1
			ring.outer_radius = 0.2
			scarf = Proc.mesh_node(ring, Assets.pbr("quatrefoil_jacquard_fabric", Hud.BRASS, 3.0), Vector3(0, 1.47, 0))
		body.add_child(scarf)
	arm = SpringArm3D.new()
	arm.spring_length = _zoom
	arm.position.y = 1.7
	var ball := SphereShape3D.new()  # a ball, not a ray: the camera keeps clear of corners and roof edges
	ball.radius = 0.3
	arm.shape = ball
	arm.margin = 0.15
	add_child(arm)
	camera = Camera3D.new()
	camera.fov = 60
	camera.near = 0.15
	arm.add_child(camera)
	arm.add_excluded_object(get_rid())
	var around := NavigationObstacle3D.new()  # villagers steer round the captain
	around.radius = 0.6
	around.avoidance_enabled = true
	add_child(around)


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
			_zoom = maxf(3.0, _zoom - 0.8)
		elif b.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = minf(16.0, _zoom + 0.8)


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	var speed := Mover.WALK
	if controlled:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if Input.is_action_pressed("run"):
			speed = Mover.RUN
	var dir := (Basis(Vector3.UP, yaw) * Vector3(input.x, 0, input.y)).limit_length(1.0)
	_rise += Mover.step(self, dir, delta, speed)
	_rise = lerpf(_rise, 0.0, minf(1.0, 12.0 * delta))
	if position.y < respawn.y - 30.0:  # left the world: back to where this island lets you in
		position = respawn
		velocity = Vector3.ZERO
	var flat := Vector3(velocity.x, 0, velocity.z)
	if dir.length() > 0.1:
		body.rotation.y = lerp_angle(body.rotation.y, atan2(dir.x, dir.z), minf(1.0, TURN * delta))
	walker.step(delta, flat.length())
	body.position.y = -_rise + (0.0 if walker.animated() else walker.bob() * 2.0)
	arm.rotation = Vector3(pitch, yaw, 0)
	arm.position.y = 1.7 - _rise
	arm.spring_length = lerpf(arm.spring_length, _zoom, minf(1.0, 8.0 * delta))

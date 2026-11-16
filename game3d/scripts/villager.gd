## A villager on a stroll: picks a spot near home, walks there over the navmesh, stands a while, picks another.
## Steers round other people (avoidance) and never through walls: it is a body like the captain (Mover).
class_name Villager
extends CharacterBody3D

const PACE := 1.5

var home := Vector3.ZERO
var roam := 6.0
var who := ""
var role := ""  ## the costume (Costume role); empty = the one that fits `who`
var coat := Color.WHITE
var agent: NavigationAgent3D
var body: Node3D
var walker: Walker
var _rng := RandomNumberGenerator.new()
var _pause := 0.5
var _placed := false
var _safe := Vector3.ZERO
var _mark := Vector3.ZERO
var _mark_time := 0.0


func setup(character: String, colour: Color, at: Vector3, radius: float) -> void:
	who = character
	coat = colour
	home = at
	roam = radius
	position = at
	_rng.seed = hash(at)


func _ready() -> void:
	Mover.capsule(self, 0.32, 1.8)
	Mover.setup(self)
	body = Proc.figure(coat, Color("2a3550"), who, role)
	add_child(body)
	walker = Walker.attach(body)
	walker.ground = Walker.ground_under(self)
	agent = NavigationAgent3D.new()
	agent.radius = 0.5
	agent.height = 1.8
	agent.max_speed = PACE
	agent.path_desired_distance = 0.6
	agent.target_desired_distance = 0.8
	agent.avoidance_enabled = true
	agent.neighbor_distance = 6.0
	agent.time_horizon_agents = 1.5
	add_child(agent)
	agent.velocity_computed.connect(func(v: Vector3) -> void: _safe = v)


func _physics_process(delta: float) -> void:
	if not _placed:
		if not Nav.ready(self):
			return
		var near := NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, home)
		if Vector2(near.x - home.x, near.z - home.z).length() > 3.0:
			return  # the navmesh is not in the map yet: wait where we stand
		_placed = true
		_mark = global_position
	var wish := Vector3.ZERO
	if _pause > 0.0:
		_pause -= delta
		if _pause <= 0.0:
			agent.target_position = Nav.wander(self, home, roam, _rng)
	elif agent.is_navigation_finished():
		_pause = _rng.randf_range(1.5, 5.0)
	else:
		var to := agent.get_next_path_position() - global_position
		to.y = 0.0
		agent.velocity = to.normalized() * PACE
		wish = _safe / PACE if _safe.length() > 0.05 else Vector3.ZERO
		_mark_time += delta
		if _mark_time > 3.0:  # made no headway (somebody stands in the way): choose another spot
			if global_position.distance_to(_mark) < 0.5:
				_pause = 0.3
			_mark = global_position
			_mark_time = 0.0
	Mover.step(self, wish.limit_length(1.0), delta, PACE)
	var flat := Vector3(velocity.x, 0, velocity.z)
	if flat.length() > 0.2:
		body.rotation.y = lerp_angle(body.rotation.y, atan2(flat.x, flat.z), minf(1.0, 6.0 * delta))
	walker.step(delta, flat.length())
	if not walker.animated():
		body.position.y = walker.bob() * 2.0

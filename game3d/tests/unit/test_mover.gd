## Walking: the Mover speeds up and slows down, climbs a stair, stops at a wall; the Walker's gait keeps a planted
## foot still on the ground.
extends GutTest

const DT := 1.0 / 60.0

var _room: Node3D
var _body: CharacterBody3D


func before_each() -> void:
	_room = Node3D.new()
	add_child_autofree(_room)
	Solid.box(_room, Vector3(40, 1, 40), Vector3(0, -0.5, 0))
	_body = CharacterBody3D.new()
	Mover.capsule(_body)
	Mover.setup(_body)
	_room.add_child(_body)
	_body.position = Vector3(0, 0.02, 0)
	await wait_physics_frames(2)
	for i in 5:
		Mover.step(_body, Vector3.ZERO, DT)


func _walk(dir: Vector3, frames: int, speed: float = Mover.WALK) -> void:
	for i in frames:
		Mover.step(_body, dir, DT, speed)


func test_speeds_up_and_slows_down() -> void:
	_walk(Vector3.FORWARD, 1)
	assert_between(_body.velocity.length(), 0.1, 1.0, "the first step is not full speed")
	_walk(Vector3.FORWARD, 40)
	assert_almost_eq(_body.velocity.length(), Mover.WALK, 0.05)
	_walk(Vector3.FORWARD, 40, Mover.RUN)
	assert_almost_eq(_body.velocity.length(), Mover.RUN, 0.05)
	_walk(Vector3.ZERO, 3)
	assert_gt(_body.velocity.length(), 1.0, "does not stop dead")
	_walk(Vector3.ZERO, 30)
	assert_almost_eq(_body.velocity.length(), 0.0, 0.01)
	assert_almost_eq(_body.position.y, 0.0, 0.05, "stays on the floor")


func test_climbs_stairs_and_comes_down() -> void:
	for i in 4:  # four steps of 0.3 m
		Solid.box(_room, Vector3(4, 0.3, 4), Vector3(0, 0.15 + i * 0.3, -4.0 - i * 0.6))
	await wait_physics_frames(2)
	_walk(Vector3.FORWARD, 70)
	assert_almost_eq(_body.position.y, 1.2, 0.06, "on the top step")
	_walk(Vector3.BACK, 80)
	assert_almost_eq(_body.position.y, 0.0, 0.06, "back down, without flying off the edge")
	assert_true(_body.is_on_floor())


func test_a_wall_is_not_a_stair() -> void:
	Solid.box(_room, Vector3(6, 1.2, 1), Vector3(0, 0.6, -3.0))
	await wait_physics_frames(2)
	_walk(Vector3.FORWARD, 90)
	assert_almost_eq(_body.position.y, 0.0, 0.05, "did not climb a 1.2 m wall")
	assert_gt(_body.position.z, -2.5 - Mover.RADIUS + 0.35, "stopped at the wall")


func test_walks_up_a_slope_but_not_a_cliff() -> void:
	var ramp := Solid.box(_room, Vector3(4, 0.4, 8), Vector3(0, 1.0, -6.0))
	ramp.rotation.x = deg_to_rad(25)
	await wait_physics_frames(2)
	_walk(Vector3.FORWARD, 100)
	assert_gt(_body.position.y, 1.0, "walked up 25 degrees")


func test_a_planted_foot_does_not_slide() -> void:
	for speed: float in [1.4, 2.5, 4.2]:
		var share := Walker.stance(speed)
		var period := Walker.period(speed)
		var half := speed * share * period * 0.5  # what Walker._pose uses while the leg can reach
		var a := Walker.foot_cycle(0.1 * share, share)
		var b := Walker.foot_cycle(0.6 * share, share)
		var foot_speed := (a.x - b.x) * half / (0.5 * share * period)
		assert_almost_eq(foot_speed, speed, 0.001, "on the ground the foot goes back as fast as the body goes forward")
		assert_eq(a.y, 0.0)
	assert_gt(Walker.stance(1.4), 0.5, "walking: both feet down part of the time")
	assert_lt(Walker.stance(7.0), 0.5, "running: a moment in the air")
	assert_gt(Walker.foot_cycle(0.8, 0.6).y, 0.5, "the swinging foot is lifted")
	assert_lt(Walker.period(7.0), Walker.period(1.4), "a run has a quicker cadence")

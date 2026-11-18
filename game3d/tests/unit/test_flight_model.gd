## ADR-0032: the rules of free flight, with no scene.
extends GutTest

var m: FlightModel


func before_each() -> void:
	m = FlightModel.new()
	m.position = Vector3(0, 10, 0)
	m.trim = 1.0


func _fly(seconds: float, rudder: float = 0.0, sail: float = 0.0, climb: float = 0.0, wind: Vector3 = Vector3.ZERO) -> void:
	for i in int(seconds * 60.0):
		m.step(1.0 / 60.0, rudder, sail, climb, wind)


func test_fair_wind_is_faster_than_head_wind_and_no_sail_only_drifts() -> void:
	var ahead := m.heading()
	assert_almost_eq(m.cruising(ahead), FlightModel.BASE_SPEED * 1.5, 0.01)
	assert_almost_eq(m.cruising(-ahead), FlightModel.BASE_SPEED * 0.5, 0.01)
	assert_almost_eq(m.cruising(Vector3.ZERO), FlightModel.BASE_SPEED, 0.01)
	m.trim = 0.0
	assert_almost_eq(m.cruising(ahead), FlightModel.BASE_SPEED * FlightModel.DRIFT, 0.01, "no sail: the ship only drifts")
	m.trim = 1.0
	assert_almost_eq(m.cruising(ahead, 0.6), FlightModel.BASE_SPEED * 0.9, 0.01, "a storm slows it")


func test_the_ship_picks_up_speed_and_goes_where_the_bow_points() -> void:
	_fly(4.0)
	assert_almost_eq(m.speed, FlightModel.BASE_SPEED, 0.2)
	assert_lt(m.position.z, -30.0, "heading 0 is −z")
	assert_almost_eq(m.position.x, 0.0, 0.01)
	assert_almost_eq(m.flown, -m.position.z, 0.5)


func test_the_wheel_turns_the_ship_and_the_sail_is_trimmed() -> void:
	_fly(3.0)
	_fly(2.0, 1.0)
	assert_gt(m.yaw, 1.0, "wheel to port: the heading grows")
	assert_lt(m.heading().x, -0.5, "…and the bow swings to −x")
	_fly(3.0, 0.0, -1.0)
	assert_eq(m.trim, 0.0)
	_fly(4.0)
	assert_almost_eq(m.speed, FlightModel.BASE_SPEED * FlightModel.DRIFT, 0.3)


func test_height_stays_between_the_clouds_and_the_ceiling() -> void:
	_fly(40.0, 0.0, 0.0, 1.0)
	assert_eq(m.position.y, m.ceiling_y)
	_fly(60.0, 0.0, 0.0, -1.0)
	assert_eq(m.position.y, m.floor_y)


func test_the_edge_of_the_world_cannot_be_crossed() -> void:
	m.world_radius = 200.0
	_fly(120.0)
	var r := Vector2(m.position.x, m.position.z).length()
	assert_lte(r, 200.001, "still inside")
	assert_gt(r, 200.0 - FlightModel.EDGE_SOFT, "it did get near")
	assert_gt(m.edge_push(), 0.0)
	_fly(1.0, 1.0)  # turn round and it lets go
	m.yaw = PI  # bow to the middle
	_fly(20.0)
	assert_eq(m.edge_push(), 0.0)


func test_an_island_is_solid() -> void:
	m.islands = [{"centre": Vector3(0, 12, -80), "radius": 30.0, "depth": 40.0}]
	m.position.y = 12.0  # level with the island's top, where the rock is widest
	_fly(30.0)
	var gap := Vector2(m.position.x, m.position.z - -80.0).length()
	assert_gte(gap, 30.0 + FlightModel.HULL - 0.01, "the hull never enters the rock")
	assert_lt(m.speed, 1.0, "driven straight at the cliff, the ship has stopped")
	assert_true(m.bumped)


func test_an_island_can_be_flown_over_and_under() -> void:
	m.islands = [{"centre": Vector3(0, 12, -80), "radius": 30.0, "depth": 40.0}]
	m.position.y = 30.0
	_fly(12.0)
	assert_lt(m.position.z, -130.0, "over the top")
	m.islands = [{"centre": Vector3(0, 12, -80), "radius": 30.0, "depth": 30.0}]  # a shallower rock: its root ends above the clouds
	m.position = Vector3(0, -30, 0)
	m.speed = 0.0
	_fly(14.0)
	assert_lt(m.position.z, -130.0, "and under the rock")


func test_bearing_tells_left_from_right() -> void:
	assert_almost_eq(m.bearing_to(Vector3(0, 0, -50)), 0.0, 0.001, "dead ahead")
	assert_gt(m.bearing_to(Vector3(-50, 0, -50)), 0.5, "to port")
	assert_lt(m.bearing_to(Vector3(50, 0, -50)), -0.5, "to starboard")
	assert_almost_eq(absf(m.bearing_to(Vector3(0, 0, 50))), PI, 0.001, "astern")
	assert_almost_eq(m.distance_to(Vector3(30, 99, -40)), 50.0, 0.001, "distance is over the ground")


func test_mooring_needs_to_be_near_and_slow() -> void:
	var berth := Vector3(0, 10, -10)
	assert_true(m.can_moor(berth))
	m.speed = FlightModel.MOOR_SPEED + 1.0
	assert_false(m.can_moor(berth), "too fast")
	m.speed = 2.0
	assert_false(m.can_moor(Vector3(0, 10, -40)), "too far")
	assert_false(m.can_moor(Vector3(0, 40, -10)), "far too high above the pier")


func test_every_port_can_be_left_and_reached() -> void:
	var ports := Ports.all()
	assert_eq(ports.keys(), Ports.ORDER as Array)
	for id: String in Ports.ORDER:
		var p: Dictionary = ports[id]
		var berth: Vector3 = p["berth"]
		assert_lt(Vector2(berth.x, berth.z).length(), Ports.WORLD_RADIUS - FlightModel.EDGE_SOFT, id + " lies well inside the world")
		assert_gt(Vector2(berth.x - p["centre"].x, berth.z - p["centre"].z).length(), float(p["radius"]) + FlightModel.HULL, id + ": the berth is clear of the rock")
		var ship := Ports.cast_off(id)
		assert_eq(Ports.mooring(ship), id, "moored where it starts")
		for i in 600:
			ship.step(1.0 / 60.0, 0.0, 1.0, 0.0, Vector3.ZERO)
		assert_false(ship.bumped, id + ": casting off straight ahead meets no rock")
		assert_gt(ship.distance_to(berth), 60.0, id + ": ten seconds out, well away")
		assert_eq(Ports.mooring(ship), "")


func test_a_ship_can_fly_from_any_island_to_any_other_in_any_wind() -> void:
	for wind: Vector3 in [Vector3.ZERO, Vector3(1, 0, -0.6), Vector3(-0.8, 0, 0.9)]:
		for from: String in Ports.ORDER:
			for to: String in Ports.ORDER:
				if from == to:
					continue
				var ship := Ports.cast_off(from)
				var arrived := false
				for i in 60 * 300:  # five minutes at most, a helmsman steering by the compass alone
					var ask := Ports.steer(ship, to)
					ship.step(1.0 / 60.0, ask.x, ask.y, ask.z, wind)
					if Ports.mooring(ship) == to:
						arrived = true
						break
				assert_true(arrived, "%s → %s, wind %s" % [from, to, wind])

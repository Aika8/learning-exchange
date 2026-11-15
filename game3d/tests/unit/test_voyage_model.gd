extends GutTest

var v: VoyageModel


func before_each() -> void:
	v = VoyageModel.new(Vector3.ZERO, Vector3(50, 0, 0), Vector3(100, 0, 0))


func test_route_ends_at_both_islands() -> void:
	assert_eq(v.point(0.0), Vector3.ZERO)
	assert_eq(v.point(1.0), Vector3(100, 0, 0))
	assert_almost_eq(v.length, 100.0, 0.5)


func test_fair_wind_is_faster_than_head_wind_and_sail_down_is_slowest() -> void:
	var fair := v.advance(1.0, true, Vector3(1, 0, 0))
	v.travelled = 0.0
	var head := v.advance(1.0, true, Vector3(-1, 0, 0))
	v.travelled = 0.0
	var down := v.advance(1.0, false, Vector3(1, 0, 0))
	assert_gt(fair, head)
	assert_gt(head, down - 0.001)
	assert_almost_eq(fair, VoyageModel.BASE_SPEED * 1.5, 0.01)


func test_arrives_and_does_not_overshoot() -> void:
	for i in 100:
		v.advance(1.0, true, Vector3.ZERO)
	assert_true(v.arrived())
	assert_eq(v.progress(), 1.0)
	assert_almost_eq(v.travelled, v.length, 0.001)


func test_wind_help_is_zero_without_wind() -> void:
	assert_eq(v.wind_help(Vector3.ZERO), 0.0)

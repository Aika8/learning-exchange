extends GutTest


func test_extrapolates_by_speed() -> void:
	var c := SimClock.from_dict({"now": 1_000_000.0, "paused": false, "speed": 10.0}, 500)
	assert_eq(c.at(500), 1_000_000)
	assert_eq(c.at(1500), 1_010_000, "1 s real × speed 10 = 10 s sim")


func test_paused_clock_stands_still() -> void:
	var c := SimClock.from_dict({"now": 42_000, "paused": true, "speed": 5}, 0)
	assert_eq(c.at(99_999), 42_000)


func test_speed_is_clamped_to_contract_range() -> void:
	assert_eq(SimClock.from_dict({"now": 0, "paused": false, "speed": 500}, 0).speed, 60)
	assert_eq(SimClock.from_dict({"now": 0, "paused": false, "speed": 0}, 0).speed, 1)


func test_never_goes_back_before_receipt() -> void:
	var c := SimClock.from_dict({"now": 10_000, "paused": false, "speed": 1}, 1000)
	assert_eq(c.at(0), 10_000)


func test_formats() -> void:
	assert_eq(SimClock.format_time(((7 * 60 + 39) * 60 + 35) * 1000), "07:39:35")
	assert_eq(SimClock.format_duration(125_000), "02:05")
	assert_eq(SimClock.format_duration(3_725_000), "1:02:05")
	assert_eq(SimClock.format_duration(-5), "00:00")

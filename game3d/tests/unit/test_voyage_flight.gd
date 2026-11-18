## ADR-0032: the voyage scene flies the model, keeps the day loop's SAILING state, and moors at any island.
extends GutTest

const VOYAGE := preload("res://scenes/voyage.tscn")
const HARBOUR := preload("res://scenes/harbour.tscn")


func before_each() -> void:
	Game.flow = GameFlow.new()
	Game.island = "harbour"
	Game.attuned = "harbour"
	Game.destination = ""


func after_each() -> void:
	Game.flow = GameFlow.new()
	Game.island = "harbour"
	Game.attuned = "harbour"
	Game.destination = ""
	Session.set_style(IslandStyle.HOME)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _sail(from: String, to: String) -> Node3D:
	Game.island = from
	Game.destination = to
	Game.flow.state = GameFlow.State.SAILING
	var scene: Node3D = VOYAGE.instantiate()
	add_child_autofree(scene)
	await wait_process_frames(3)
	return scene


func test_the_ship_starts_at_the_berth_of_the_island_left_with_the_bow_away() -> void:
	var scene := await _sail("silk", "crypto")
	var m: FlightModel = scene.get("model")
	assert_lt(m.distance_to(Ports.berth("silk")), 8.0)
	assert_eq(scene.get("_to"), "crypto")
	assert_eq(scene.get("_at"), "", "just cast off: not asked to moor where she lay")
	assert_false(scene.call("moor"), "nothing to moor at yet")
	assert_eq(Game.daylog.last_of("VOYAGE_START").get("data", {}).get("to"), "crypto")


func test_the_player_may_moor_at_another_island_than_the_one_marked() -> void:
	var scene := await _sail("harbour", "silk")
	var m: FlightModel = scene.get("model")
	var moored := false  # marked Silk Reach, flew to Amber Cliff: the mark is only a mark
	for i in 60 * 300:
		var ask := Ports.steer(m, "amber")
		scene.call("fly", 1.0 / 60.0, ask.x, ask.y, ask.z)
		if scene.get("_at") == "amber":
			moored = scene.call("moor")
			break
	assert_true(moored)
	assert_true(scene.call("arrived"))
	assert_eq(Game.island, "amber", "the port scene will open on the island moored at")
	assert_eq(Game.destination, "")
	assert_eq(Game.daylog.last_of("VOYAGE_END").get("data", {}).get("at"), "amber")
	assert_gt(m.flown, 300.0)


func test_flying_free_has_no_mark_and_a_storm_slows_the_ship() -> void:
	var scene := await _sail("harbour", "")
	assert_eq(scene.get("_to"), "")
	assert_eq(Game.daylog.last_of("VOYAGE_START").get("data", {}).get("to"), "free")
	var m: FlightModel = scene.get("model")
	m.trim = 1.0
	for i in 240:
		scene.call("fly", 1.0 / 60.0, 0.0, 0.0, 0.0)
	var calm := m.speed
	scene.call("demo_storm", 1.0)
	for i in 240:
		scene.call("fly", 1.0 / 60.0, 0.0, 0.0, 0.0)
	assert_lt(m.speed, calm * 0.8, "in the storm she is slower")


func test_the_compass_and_the_chart_put_things_where_they_are() -> void:
	assert_almost_eq(FlightCompass.place(0.0), 0.5, 0.001, "dead ahead is the middle of the strip")
	assert_lt(FlightCompass.place(0.6), 0.5, "to port is to the left")
	assert_gt(FlightCompass.place(-0.6), 0.5)
	assert_eq(FlightCompass.place(PI), 0.0, "astern is pinned to an end")
	var middle := FlightChart.place(Ports.WORLD_CENTRE, 200.0)
	assert_eq(middle, Vector2(100, 100))
	var north := FlightChart.place(Ports.WORLD_CENTRE + Vector3(0, 0, -Ports.WORLD_RADIUS), 200.0)
	assert_lt(north.y, 10.0, "−z is up, and the edge of the world is the rim")
	for id: String in Ports.ORDER:
		assert_lt(FlightChart.place(Ports.berth(id), 200.0).distance_to(middle), 94.0, id + " is on the chart")


func test_the_chart_at_the_pier_offers_every_other_island_and_the_day_loop_still_decides() -> void:
	Game.island = "harbour"
	var scene: Node3D = HARBOUR.instantiate()
	add_child_autofree(scene)
	await wait_physics_frames(3)
	var chart: FlightChartPanel = scene.call("chart")
	chart.offer("harbour")
	await wait_process_frames(2)
	var offered: Array[String] = []
	for b in chart.find_children("To_*", "Button", true, false):
		offered.append(str(b.name).trim_prefix("To_"))
	assert_eq(offered, ["silk", "amber", "shorts", "crypto", "index", "race"] as Array[String])
	assert_not_null(chart.find_child("Free", true, false))
	assert_not_null(chart.find_child("Stay", true, false))
	# the guard of the day loop is asked exactly as before: SAILING from PORT is allowed, from PLAN it is not
	assert_true(Game.flow.can(GameFlow.State.SAILING, Game.ctx()))
	Game.flow.state = GameFlow.State.PLAN
	assert_false(scene.call("cast_off", "silk"), "Mara's check cannot be sailed away from")
	assert_eq(Game.destination, "", "refused: no course was set")
	assert_eq(Game.flow.state, GameFlow.State.PLAN)

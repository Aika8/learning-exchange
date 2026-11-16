## The world holds: the audit probe (WorldProbe) walks a grid over both islands and the Exchange hall and nobody
## falls, tunnels or gets trapped; every spawn point and interaction spot has ground and room; everything solid has a
## collider that follows its shape; villagers stay on the ground. Runs on the real harbour scene, headless.
extends GutTest

const HARBOUR := preload("res://scenes/harbour.tscn")


func _place(island: String) -> Node3D:
	Game.island = island
	Session.spawn = "start"
	var scene: Node3D = HARBOUR.instantiate()
	add_child_autofree(scene)
	await wait_physics_frames(4)
	return scene


func _probe(scene: Node3D, areas: Array[Dictionary]) -> WorldProbe:
	var probe := WorldProbe.new(scene, areas)
	probe.spacing = 3.0
	await probe.prepare()
	return probe


func _assert_clean(probe: WorldProbe, kinds: Array[String]) -> void:
	for kind in kinds:
		var where := ""
		for i in probe.issues:
			if i["kind"] == kind:
				where += " %s@%s" % [i["what"], str((i["at"] as Vector3).snapped(Vector3.ONE * 0.1))]
		assert_eq(probe.count(kind), 0, kind + where.left(300))


func after_each() -> void:
	Game.island = "harbour"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_nobody_falls_on_spark_harbour() -> void:
	var scene := await _place("harbour")
	var probe := await _probe(scene, Archipelago.walk_areas("harbour"))
	probe.walk_grid()
	assert_gt(probe.points, 250, "grid covers the island, the wharf and the pier")
	assert_gt(probe.walks, 1500)
	_assert_clean(probe, ["hole", "fall", "tunnel", "stuck"])
	probe.done()


func test_nobody_falls_on_silk_reach() -> void:
	var scene := await _place("silk")
	var probe := await _probe(scene, Archipelago.walk_areas("silk"))
	probe.walk_grid()
	assert_gt(probe.points, 150)
	_assert_clean(probe, ["hole", "fall", "tunnel", "stuck"])
	probe.done()


func test_nobody_falls_in_the_exchange_hall() -> void:
	var room := Node3D.new()
	add_child_autofree(room)
	HallRoom.build(room)
	var board := Board.new()
	board.position = Vector3(0, 0.6, -9.0)
	room.add_child(board)
	await wait_physics_frames(3)
	var probe := await _probe(room, Audit.areas("hall"))
	probe.spacing = 2.0
	probe.walk_grid()
	probe.scan_objects()
	assert_gt(probe.free_points, 80)
	_assert_clean(probe, ["hole", "fall", "tunnel", "stuck", "no-collision", "loose-collider", "floating"])
	probe.done()


func test_spawn_points_and_spots_are_free() -> void:
	for island: String in ["harbour", "silk"]:
		var scene := await _place(island)
		var probe := await _probe(scene, Archipelago.walk_areas(island))
		for spawn: String in ["start", "pier", "exchange"]:
			var at: Vector3 = Archipelago.spawn_point(island, spawn)[0]
			assert_true(probe.check_spawn(spawn, at), "%s spawn %s has ground and is not inside a collider" % [island, spawn])
			assert_true(probe.in_any(at, 0.5), "%s spawn %s is on the walkable ground" % [island, spawn])
		var spots: Dictionary = scene.call("_spots")
		for id: String in spots:
			assert_true(probe.check_spot(id, spots[id][0], spots[id][2]), "%s spot %s can be reached" % [island, id])
		probe.done()
		scene.free()


func test_everything_solid_has_a_collider_that_follows_its_shape() -> void:
	for island: String in ["harbour", "silk"]:
		var scene := await _place(island)
		var probe := await _probe(scene, Archipelago.walk_areas(island))
		probe.scan_objects()
		probe.scan_zfight()
		assert_gt(probe.units, 20, island)
		_assert_clean(probe, ["no-collision", "loose-collider", "floating", "gap", "z-fight"])
		probe.done()
		scene.free()


func test_villagers_keep_to_the_ground_and_walk() -> void:
	var scene := await _place("harbour")
	var villagers: Array[Villager] = []
	for c in scene.get_children():
		if c is Villager:
			villagers.append(c)
	assert_gt(villagers.size(), 3)
	var start: Array[Vector3] = []
	for v in villagers:
		start.append(v.global_position)
	await wait_physics_frames(420)
	var areas := Archipelago.walk_areas("harbour")
	var moved := 0
	for i in villagers.size():
		var p := villagers[i].global_position
		var on_ground := false
		for a in areas:
			on_ground = on_ground or WorldProbe.inside(a, p)
		assert_true(on_ground, "villager %d is on the walkable ground at %s" % [i, str(p)])
		assert_almost_eq(p.y, 0.0, 0.6, "villager %d stands on the ground, not on a roof" % i)
		moved += 1 if p.distance_to(start[i]) > 1.0 else 0
		for j in range(i + 1, villagers.size()):
			assert_gt(p.distance_to(villagers[j].global_position), 0.5, "villagers do not stand inside each other")
	assert_gt(moved, 1, "villagers walk")


func test_the_ground_of_silk_reach_is_where_the_builder_thinks() -> void:
	var scene := await _place("silk")
	var space := scene.get_world_3d().direct_space_state
	for local: Vector3 in [Vector3(0, 0, 0), Vector3(8, 0, 13), Vector3(-8, 0, -10), Vector3(15, 0, 2), Vector3(-12, 0, 8)]:
		var p := Archipelago.SILK + local
		var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 30, 0), p + Vector3(0, -5, 0))
		q.collision_mask = 1
		var island_only: Dictionary = {}
		for attempt in 8:  # skip roofs and props: the last thing hit from above is the ground
			var hit := space.intersect_ray(q)
			if hit.is_empty():
				break
			island_only = hit
			q.exclude = q.exclude + [hit["rid"]]
		assert_false(island_only.is_empty(), str(local))
		if not island_only.is_empty():
			assert_almost_eq((island_only["position"] as Vector3).y - Archipelago.SILK.y, Archipelago.silk_ground(local), 0.35, str(local))

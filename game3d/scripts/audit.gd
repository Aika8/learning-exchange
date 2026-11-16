## The audit run: `godot --path game3d -- --audit=<dir>` builds each place (Spark Harbour, Silk Reach, the Exchange
## hall), runs WorldProbe over it, saves a screenshot of every cluster of issues and writes <dir>/audit.json.
## The result is the table of docs/demo/G3D-polish.md. Not used in normal play.
class_name Audit
extends RefCounted

const PLACES := ["harbour", "silk", "hall"]
const SHOTS_PER_KIND := 3


## Fixed camera views of each place, for the before/after pictures: [file, camera position, look-at].
const VIEWS := {
	"harbour": [["view-square", Vector3(3, 7, 24), Vector3(-2, 1.5, 0)], ["view-houses", Vector3(-4, 3.2, 3), Vector3(-15, 2.2, 3)],
		["view-house-close", Vector3(-8.5, 2.4, 1.5), Vector3(-14, 2.2, -2)], ["view-wharf", Vector3(27, 8, 27), Vector3(34, 0.5, 3)],
		["view-pier", Vector3(52, 5, -3), Vector3(40, 0.5, 4)], ["view-exchange", Vector3(7, 3, -1), Vector3(0, 5, -15)],
		["view-top", Vector3(12, 62, 6), Vector3(12, 0, 4)]],
	"silk": [["view-silk", Archipelago.SILK + Vector3(-22, 9, 24), Archipelago.SILK + Vector3(2, 1, -2)],
		["view-silk-houses", Archipelago.SILK + Vector3(3, 3, 10), Archipelago.SILK + Vector3(14, 2, 2)],
		["view-silk-pier", Archipelago.SILK + Vector3(-24, 5, 26), Archipelago.SILK + Vector3(-28, 0.5, 14)]],
	"hall": [["view-hall", Vector3(0, 3.4, 10.4), Vector3(0, 5, -9)], ["view-hall-side", Vector3(10, 4, 6), Vector3(-6, 2.5, -6)],
		["view-hall-up", Vector3(0, 1.6, 9), Vector3(0, 12, -4)]],
}


## `--views=<dir>`: only the fixed views, no probe.
static func views(tree: SceneTree) -> void:
	var dir := Session.arg("views")
	DirAccess.make_dir_recursive_absolute(dir)
	for place: String in PLACES:
		Game.island = "silk" if place == "silk" else "harbour"
		tree.change_scene_to_file("res://scenes/%s.tscn" % ("hall" if place == "hall" else "harbour"))
		await Session.wait(2.5)
		var scene := tree.current_scene as Node3D
		for v: Array in VIEWS[place]:
			await shot(scene, v[2], dir.path_join(str(v[0]) + ".png"), v[1])
			print("view: ", v[0], " fps=", Engine.get_frames_per_second())
	tree.quit()


## `--fps=<file>`: frame rate in the harbour — the captain's own camera, then every fixed view right after the camera
## jumps there (the first second) and settled (the next two). Writes a JSON table; run at 1920x1080.
static func fps(tree: SceneTree) -> void:
	var rows: Array = []
	for place: String in ["harbour", "silk"]:
		Game.island = place
		tree.change_scene_to_file("res://scenes/harbour.tscn")
		await Session.wait(3.0)
		await _await_drawn(tree)
		await Session.wait(1.0)
		var scene := tree.current_scene as Node3D
		rows.append(await _measure(tree, place + " captain", 0.0, 3.0))
		var cam := Camera3D.new()
		cam.fov = 60
		scene.add_child(cam)
		cam.current = true
		for v: Array in VIEWS[place]:
			await _await_drawn(tree)
			cam.position = v[1]
			cam.look_at(v[2])
			rows.append(await _measure(tree, str(v[0]) + " jump", 0.0, 1.0))
			rows.append(await _measure(tree, str(v[0]) + " settled", 0.0, 2.0))
	for r: Dictionary in rows:
		print("fps: %-28s avg %5.1f  low %5.1f  (worst frame %4.1f ms)  drawn %d of %d" % [r["view"], r["avg"], r["low"], r["worst_ms"], r["drawn"], r["frames"]])
	var f := FileAccess.open(Session.arg("fps"), FileAccess.WRITE)
	f.store_string(JSON.stringify(rows, "  "))
	f.close()
	tree.quit()


## Waits (up to a minute) until the window is really drawn: macOS stops drawing a covered window, and then a
## frame-time measurement only measures the idle loop.
static func _await_drawn(tree: SceneTree) -> void:
	for attempt in 60:
		var drawn := [0]
		var count := func() -> void: drawn[0] += 1
		RenderingServer.frame_post_draw.connect(count)
		await Session.wait(0.3)
		RenderingServer.frame_post_draw.disconnect(count)
		if drawn[0] > 3:
			return
		await Session.wait(0.7)


static func _measure(tree: SceneTree, view: String, skip: float, seconds: float) -> Dictionary:
	if skip > 0.0:
		await Session.wait(skip)
	var times: Array[float] = []
	var drawn := [0]
	var count := func() -> void: drawn[0] += 1
	RenderingServer.frame_post_draw.connect(count)
	var start := Time.get_ticks_usec()
	var last := start
	while Time.get_ticks_usec() - start < seconds * 1e6:
		await tree.process_frame
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
	RenderingServer.frame_post_draw.disconnect(count)
	if drawn[0] < times.size() / 2:
		push_warning("fps: the window is hidden, frames are not drawn — the numbers for '%s' mean nothing" % view)
	times.sort()
	var total := 0.0
	for t in times:
		total += t
	var p99 := times[mini(times.size() - 1, int(times.size() * 0.99))]
	return {"view": view, "avg": snappedf(1000.0 * times.size() / total, 0.1), "low": snappedf(1000.0 / p99, 0.1), "worst_ms": snappedf(times[-1], 0.1), "frames": times.size(), "drawn": drawn[0]}


## `--people=<dir>`: a line-up of every role on the wharf, front and back (add `--plain` for the people as downloaded).
static func people(tree: SceneTree) -> void:
	var dir := Session.arg("people")
	DirAccess.make_dir_recursive_absolute(dir)
	Game.island = "harbour"
	tree.change_scene_to_file("res://scenes/harbour.tscn")
	await Session.wait(2.0)
	var scene := tree.current_scene as Node3D
	for v in scene.find_children("*", "Villager", true, false):
		(v as Node3D).visible = false
	(scene.get("_captain") as Node3D).visible = false
	var cast := [["sailor", "captain"], ["sailor", "sailor"], ["sailor", "sailor2"], ["sailor", "sailor3"], ["trader", "mara"], ["sailor", "changer"],
		["trader", "olva"], ["trader", "trader"], ["oldman", "townsman"], ["child", "child"], ["", "chronicler"]]
	var walkers: Array[Walker] = []
	for i in cast.size():
		var f := Proc.figure(Color("8a6a4a"), Color("2a3550"), cast[i][0], cast[i][1])
		f.position = Vector3(27.6 + i * 1.12, Archipelago.DECK_Y, -2.6)
		scene.add_child(f)
		var w := Walker.attach(f)
		w.step(0.016, 0.0)
		walkers.append(w)
	var mid := Vector3(33.2, 1.0, -2.6)
	var tag := "plain" if not Session.arg("plain").is_empty() else "dressed"
	await shot(scene, mid, dir.path_join("people-%s-front.png" % tag), mid + Vector3(0.2, 0.3, 4.4))
	for part: Array in [["a", -4.0], ["b", 0.0], ["c", 4.0]]:
		await shot(scene, mid + Vector3(part[1], 0, 0), dir.path_join("people-%s-front-%s.png" % [tag, part[0]]), mid + Vector3(part[1], 0.25, 4.0))
	await shot(scene, mid, dir.path_join("people-%s-back.png" % tag), mid + Vector3(-1.6, 0.6, -8.5))
	await shot(scene, Vector3(27.6, 1.0, -2.6), dir.path_join("people-%s-captain.png" % tag), Vector3(28.5, 1.25, 0.6))
	tree.quit()


## `--gait=<dir>`: the captain idles, walks, runs and climbs a doorstep; a side camera takes a picture of each.
static func gait(tree: SceneTree) -> void:
	var dir := Session.arg("gait")
	DirAccess.make_dir_recursive_absolute(dir)
	Game.island = "harbour"
	tree.change_scene_to_file("res://scenes/harbour.tscn")
	await Session.wait(2.0)
	var scene := tree.current_scene as Node3D
	var captain: Captain = scene.get("_captain")
	captain.global_position = Vector3(20, 0.1, -3)
	captain.yaw = PI / 2  # W walks towards −x
	for step: Array in [["gait-idle", "", 1.2], ["gait-walk", "move_forward", 1.13], ["gait-walk-2", "move_forward", 0.27], ["gait-run", "run", 1.2], ["gait-run-2", "run", 0.14]]:
		if step[1] != "":
			Input.action_press("move_forward")
		if step[1] == "run":
			Input.action_press("run")
		await Session.wait(step[2])
		var at := captain.global_position
		await shot(scene, at + Vector3(0, 0.95, 0), dir.path_join(str(step[0]) + ".png"), at + Vector3(0.6, 1.2, 3.4), 0.0)
		print("gait: ", step[0], " speed=", snappedf(captain.velocity.length(), 0.01), " at ", at.snapped(Vector3.ONE * 0.01))
	Input.action_release("move_forward")
	Input.action_release("run")
	# up the doorstep of the first house
	var house: Node3D = scene.find_child("House", true, false)
	var door := house.global_transform * Vector3(0, 0, (house.get_meta("size") as Vector3).z * 0.5 + 2.4)
	captain.global_position = door
	captain.velocity = Vector3.ZERO
	var to := house.global_position - door
	captain.yaw = atan2(-to.x, -to.z)
	await Session.wait(0.5)
	Input.action_press("move_forward")
	await Session.wait(0.78)
	var on := captain.global_position
	await shot(scene, on + Vector3(0, 0.8, 0), dir.path_join("gait-steps.png"), on - to.normalized() * 2.6 + to.normalized().cross(Vector3.UP) * 2.4 + Vector3(0, 0.9, 0), 0.0)
	print("gait: steps y=", snappedf(on.y, 0.01))
	Input.action_release("move_forward")
	# the camera with its back to a wall
	captain.global_position = house.global_transform * Vector3(0, 0.6, (house.get_meta("size") as Vector3).z * 0.5 + 1.6)
	captain.yaw = house.rotation.y + PI  # the camera arm points into the house
	captain.pitch = -0.2
	await Session.wait(0.6)
	captain.camera.current = true
	for c in scene.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	await Session.wait(0.4)
	scene.get_viewport().get_texture().get_image().save_png(dir.path_join("camera-at-wall.png"))
	print("gait: camera arm ", snappedf(captain.arm.get_hit_length(), 0.01), " of ", captain.arm.spring_length)
	tree.quit()


static func run(tree: SceneTree) -> void:
	var dir := Session.arg("audit")
	DirAccess.make_dir_recursive_absolute(dir)
	var report: Dictionary = {}
	for place: String in PLACES:
		Game.island = "silk" if place == "silk" else "harbour"
		Session.spawn = "start"
		tree.change_scene_to_file("res://scenes/%s.tscn" % ("hall" if place == "hall" else "harbour"))
		for i in 30:
			await tree.physics_frame
		var scene := tree.current_scene as Node3D
		var probe := WorldProbe.new(scene, areas(place))
		await probe.run_all()
		spots(probe, place)
		probe.done()
		var clusters := probe.clusters()
		var counts: Dictionary = {}
		for i in probe.issues:
			counts[i["kind"]] = int(counts.get(i["kind"], 0)) + 1
		var listed: Array = []
		var shown: Dictionary = {}
		clusters.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["n"]) > int(b["n"]))
		for c in clusters:
			var file := ""
			shown[c["kind"]] = int(shown.get(c["kind"], 0)) + 1
			if int(shown[c["kind"]]) <= SHOTS_PER_KIND:
				file = "%s-%s-%d" % [place, c["kind"], shown[c["kind"]]]
				await shot(scene, c["at"], dir.path_join(file + ".png"))
			var at: Vector3 = c["at"]
			listed.append({"kind": c["kind"], "what": c["what"], "n": c["n"], "at": [snappedf(at.x, 0.1), snappedf(at.y, 0.1), snappedf(at.z, 0.1)], "shot": file})
		report[place] = {"points": probe.points, "free_points": probe.free_points, "walks": probe.walks, "objects": probe.units,
			"issues": probe.issues.size(), "by_kind": counts, "clusters": listed}
		print("audit: %s points=%d free=%d walks=%d objects=%d issues=%d %s" % [place, probe.points, probe.free_points, probe.walks, probe.units, probe.issues.size(), counts])
	var f := FileAccess.open(dir.path_join("audit.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "  "))
	f.close()
	tree.quit()


static func areas(place: String) -> Array[Dictionary]:
	if place == "hall":
		return [{"name": "hall", "kind": "circle", "centre": Vector3.ZERO, "radius": HallRoom.RADIUS}]
	return Archipelago.walk_areas(place)


## Spawn points and interaction spots of the place.
static func spots(probe: WorldProbe, place: String) -> void:
	if place == "hall":
		return
	for s: String in ["start", "pier", "exchange"]:
		probe.check_spawn("spawn " + s, Archipelago.spawn_point(place, s)[0])
	var table: Dictionary = probe.world.call("_spots")
	for id: String in table:
		probe.check_spot("spot " + id, table[id][0], table[id][2])


static func shot(scene: Node3D, at: Vector3, path: String, from: Variant = null, settle: float = 0.25) -> void:
	var cam := Camera3D.new()
	cam.fov = 55
	scene.add_child(cam)
	var marker := Proc.mesh_node(CylinderMesh.new(), Proc.mat(Color("ff2a2a"), 3.0), at + Vector3(0, 4.0, 0))
	(marker.mesh as CylinderMesh).top_radius = 0.25
	(marker.mesh as CylinderMesh).bottom_radius = 0.0
	(marker.mesh as CylinderMesh).height = 2.4
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.visible = from == null
	scene.add_child(marker)
	var inward := Vector3(-at.x, 0, -at.z).normalized() if scene.scene_file_path.contains("hall") else Vector3(0.6, 0, 0.8)
	cam.position = at + inward * 9.0 + Vector3(0, 5.5, 0) if from == null else from
	cam.look_at(at + (Vector3(0, 1.0, 0) if from == null else Vector3.ZERO))
	cam.current = true
	for c in scene.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	if settle > 0.0:
		await Session.wait(settle)
	var drawn := [false]  # wait for a drawn frame, but never hang if the OS stops drawing a hidden window
	RenderingServer.frame_post_draw.connect(func() -> void: drawn[0] = true, CONNECT_ONE_SHOT)
	for i in 600:  # up to half a minute: a covered window is not drawn, and the picture would be a stale one
		if drawn[0]:
			break
		await Session.wait(0.05)
	scene.get_viewport().get_texture().get_image().save_png(path)
	cam.queue_free()
	marker.queue_free()


## `--profile=1`: what each effect costs in the harbour — turns one thing off at a time and measures.
static func profile(tree: SceneTree) -> void:
	Game.island = "harbour"
	tree.change_scene_to_file("res://scenes/harbour.tscn")
	await Session.wait(4.0)
	var scene := tree.current_scene as Node3D
	var env: Environment = (scene.find_child("WorldEnvironment", true, false) as WorldEnvironment).environment
	var sun: DirectionalLight3D = scene.get_node("Sun")
	var vp := scene.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var base: Dictionary = await _measure(tree, "base", 0.0, 2.5)
	print("profile: script process %.2f ms, physics %.2f ms, render cpu %.2f ms, render gpu %.2f ms, frame setup cpu %.2f ms" % [
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		RenderingServer.viewport_get_measured_render_time_cpu(vp), RenderingServer.viewport_get_measured_render_time_gpu(vp),
		RenderingServer.get_frame_setup_time_cpu()])
	print("profile: base %.1f fps (%.2f ms)" % [base["avg"], 1000.0 / base["avg"]])
	var toggles := {
		"sdfgi": [func() -> void: env.sdfgi_enabled = false, func() -> void: env.sdfgi_enabled = true],
		"ssao": [func() -> void: env.ssao_enabled = false, func() -> void: env.ssao_enabled = true],
		"volumetric fog": [func() -> void: env.volumetric_fog_enabled = false, func() -> void: env.volumetric_fog_enabled = true],
		"glow": [func() -> void: env.glow_enabled = false, func() -> void: env.glow_enabled = true],
		"sun shadow": [func() -> void: sun.shadow_enabled = false, func() -> void: sun.shadow_enabled = true],
		"decals": [func() -> void: _show(scene, "Decal", false), func() -> void: _show(scene, "Decal", true)],
		"omni lights": [func() -> void: _show(scene, "OmniLight3D", false), func() -> void: _show(scene, "OmniLight3D", true)],
		"villagers": [func() -> void: _show(scene, "Villager", false), func() -> void: _show(scene, "Villager", true)],
		"houses": [func() -> void: _named(scene, "House", false), func() -> void: _named(scene, "House", true)],
		"trees": [func() -> void: _named(scene, "island_tree_02", false), func() -> void: _named(scene, "island_tree_02", true)],
		"tree shadows": [func() -> void: _tree_shadows(scene, false), func() -> void: _tree_shadows(scene, true)],
		"cloud sea": [func() -> void: _named(scene, "CloudSea", false), func() -> void: _named(scene, "CloudSea", true)],
		"far islands + silk": [func() -> void: _far(scene, false), func() -> void: _far(scene, true)],
		"harbour island rock dress": [func() -> void: _dress(scene, false), func() -> void: _dress(scene, true)],
		"ship": [func() -> void: _named(scene, "Wayfarer", false), func() -> void: _named(scene, "Wayfarer", true)],
		"scale 3d 0.8→fsr off": [func() -> void: scene.get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR, func() -> void: scene.get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2],
	}
	for name: String in toggles:
		(toggles[name][0] as Callable).call()
		await Session.wait(0.8)
		var r: Dictionary = await _measure(tree, name, 0.0, 2.0)
		print("profile: without %-22s %.1f fps  saves %.2f ms" % [name, r["avg"], 1000.0 / base["avg"] - 1000.0 / r["avg"]])
		(toggles[name][1] as Callable).call()
	print("profile: draw calls ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		" primitives ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		" objects ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
	tree.quit()


static func _show(scene: Node, type: String, on: bool) -> void:
	for n in scene.find_children("*", type, true, false):
		n.set("visible", on)


static func _named(scene: Node, name: String, on: bool) -> void:
	for n in scene.find_children("*", "Node3D", true, false):
		if WorldProbe.label(n) == name:
			(n as Node3D).visible = on


static func _far(scene: Node, on: bool) -> void:
	for n in scene.get_children():
		if n is Node3D and (n as Node3D).position.length() > 100.0:
			(n as Node3D).visible = on


static func _dress(scene: Node, on: bool) -> void:
	var island := scene.get_node("SparkHarbour").get_child(0)
	for n in island.get_children():
		if not n is MeshInstance3D and not n is StaticBody3D:
			(n as Node3D).visible = on


static func _tree_shadows(scene: Node, on: bool) -> void:
	var tris := 0
	for n in scene.find_children("*", "Node3D", true, false):
		if WorldProbe.label(n) == "island_tree_02":
			for m: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
				m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				tris += WorldProbe.triangles(m.mesh)
	print("profile: tree triangles in total ", tris)

## The audit run: `godot --path game3d -- --audit=<dir>` builds each place (Spark Harbour, Silk Reach, the Exchange
## hall), runs WorldProbe over it, saves a screenshot of every cluster of issues and writes <dir>/audit.json.
## The result is the table of docs/demo/G3D-polish.md. Not used in normal play.
class_name Audit
extends RefCounted

const PLACES := ["harbour", "silk", "hall"]
const SHOTS_PER_KIND := 3


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
		probe.run_all()
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


static func shot(scene: Node3D, at: Vector3, path: String) -> void:
	var cam := Camera3D.new()
	cam.fov = 55
	scene.add_child(cam)
	var marker := Proc.mesh_node(CylinderMesh.new(), Proc.mat(Color("ff2a2a"), 3.0), at + Vector3(0, 4.0, 0))
	(marker.mesh as CylinderMesh).top_radius = 0.25
	(marker.mesh as CylinderMesh).bottom_radius = 0.0
	(marker.mesh as CylinderMesh).height = 2.4
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene.add_child(marker)
	var inward := Vector3(-at.x, 0, -at.z).normalized() if scene.scene_file_path.contains("hall") else Vector3(0.6, 0, 0.8)
	cam.position = at + inward * 9.0 + Vector3(0, 5.5, 0)
	cam.look_at(at + Vector3(0, 1.0, 0))
	cam.current = true
	for c in scene.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	await Session.wait(0.25)
	var drawn := [false]  # wait for a drawn frame, but never hang if the OS stops drawing a hidden window
	RenderingServer.frame_post_draw.connect(func() -> void: drawn[0] = true, CONNECT_ONE_SHOT)
	for i in 40:
		if drawn[0]:
			break
		await Session.wait(0.05)
	scene.get_viewport().get_texture().get_image().save_png(path)
	cam.queue_free()
	marker.queue_free()

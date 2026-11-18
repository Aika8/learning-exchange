## The audit run: `godot --path game3d -- --audit=<dir>` builds each place (Spark Harbour, Silk Reach, the Exchange
## hall), runs WorldProbe over it, saves a screenshot of every cluster of issues and writes <dir>/audit.json.
## The result is the table of docs/demo/G3D-polish.md. Not used in normal play.
class_name Audit
extends RefCounted

const PLACES := ["harbour", "silk", "amber", "shorts", "crypto", "index", "race", "hall"]
const SHOTS_PER_KIND := 3


## Fixed camera views of each place, for the before/after pictures: [file, camera position, look-at].
const VIEWS := {
	"harbour": [["view-ship", Archipelago.PIER_END + Vector3(-9, 5.5, 21), Archipelago.PIER_END + Vector3(0, 5.2, 5.5)],
		["view-ship-stern", Archipelago.PIER_END + Vector3(13.5, 3.4, 9.5), Archipelago.PIER_END + Vector3(5, 2.6, 5.5)],
		["view-ship-bow", Archipelago.PIER_END + Vector3(-11.5, 2.6, 9.5), Archipelago.PIER_END + Vector3(-5, 2.2, 5.5)],
		["view-ship-deck", Archipelago.PIER_END + Vector3(3.5, 11.5, 9.0), Archipelago.PIER_END + Vector3(0, 1.6, 5.5)],
		["view-ship-wing", Archipelago.PIER_END + Vector3(2, -1.5, 17), Archipelago.PIER_END + Vector3(0, 0.6, 5.5)],
		["view-square", Vector3(3, 7, 24), Vector3(-2, 1.5, 0)], ["view-houses", Vector3(-4, 3.2, 3), Vector3(-15, 2.2, 3)],
		["view-house-close", Vector3(-8.5, 2.4, 1.5), Vector3(-14, 2.2, -2)], ["view-wharf", Vector3(27, 8, 27), Vector3(34, 0.5, 3)],
		["view-pier", Vector3(52, 5, -3), Vector3(40, 0.5, 4)], ["view-exchange", Vector3(7, 3, -1), Vector3(0, 5, -15)],
		["view-top", Vector3(12, 62, 6), Vector3(12, 0, 4)], ["view-wharf-gate", Vector3(15, 4.5, 11), Vector3(24, 0.6, 4)]],
	"silk": [["view-silk", Archipelago.SILK + Vector3(-22, 9, 24), Archipelago.SILK + Vector3(2, 1, -2)],
		["view-silk-houses", Archipelago.SILK + Vector3(3, 3, 10), Archipelago.SILK + Vector3(14, 2, 2)],
		["view-silk-pier", Archipelago.SILK + Vector3(-24, 5, 26), Archipelago.SILK + Vector3(-28, 0.5, 14)],
		["view-silk-landing", Archipelago.SILK + Vector3(-9, 6, 25), Archipelago.SILK + Vector3(-16, 0.4, 14)]],
	"amber": [["view-amber", AmberCliff.AT + Vector3(-44, 16, 30), AmberCliff.AT + Vector3(-2, 2, -2)],
		["view-amber-square", AmberCliff.AT + Vector3(-3, 3.2, 12.5), AmberCliff.AT + Vector3(4, 4.5, -19)],
		["view-amber-street", AmberCliff.AT + Vector3(-41, 2.6, 0.6), AmberCliff.AT + Vector3(0, 4, 0)],
		["view-amber-shops", AmberCliff.AT + Vector3(2, 2.4, 2), AmberCliff.AT + Vector3(17, 3.2, -11)],
		["view-amber-cafe", AmberCliff.AT + Vector3(3, 2.6, 1), AmberCliff.AT + Vector3(17, 2.6, 11)],
		["view-amber-lighthouse", AmberCliff.AT + Vector3(12, 5, 5), AmberCliff.AT + Vector3(36, 9, 0)]],
	"shorts": [["view-shorts", ShortIsle.AT + Vector3(-46, 15, 30), ShortIsle.AT + Vector3(0, 3, -6)],
		["view-shorts-street", ShortIsle.AT + Vector3(-27, 2.4, 0.5), ShortIsle.AT + Vector3(20, 6, 0)],
		["view-shorts-exchange", ShortIsle.AT + Vector3(8, 2.6, 5), ShortIsle.AT + Vector3(21, 6.5, 0)],
		["view-shorts-houses", ShortIsle.AT + Vector3(-12, 2.2, 1.5), ShortIsle.AT + Vector3(-2, 4.5, -9)],
		["view-shorts-slab", ShortIsle.AT + Vector3(-30, 6, 22), ShortIsle.AT + Vector3(-8, 12, -60)]],
	"crypto": [["view-crypto", CryptoIsle.AT + Vector3(-44, 13, 26), CryptoIsle.AT + Vector3(2, 4, -4)],
		["view-crypto-street", CryptoIsle.AT + Vector3(-25, 2.4, 0.6), CryptoIsle.AT + Vector3(20, 6, 0)],
		["view-crypto-exchange", CryptoIsle.AT + Vector3(7, 2.6, 5.5), CryptoIsle.AT + Vector3(20, 6.5, 0)],
		["view-crypto-towers", CryptoIsle.AT + Vector3(-11, 2.2, 1.8), CryptoIsle.AT + Vector3(-2, 6, -9)],
		["view-crypto-coin", CryptoIsle.AT + Vector3(-1.5, 2.0, 0.5), CryptoIsle.AT + Vector3(5, 2.4, 4.5)]],
	"index": [["view-index", IndexIsle.AT + Vector3(-56, 26, 14), IndexIsle.AT + Vector3(4, 3, 0)],
		["view-index-street", IndexIsle.AT + Vector3(-27, 2.4, 0.4), IndexIsle.AT + Vector3(25, 8, 0)],
		["view-index-canal", IndexIsle.AT + Vector3(-8.6, 2.2, -2.2), IndexIsle.AT + Vector3(-10, 3.2, 24)],
		["view-index-quay", IndexIsle.AT + Vector3(-13.6, 2.2, 22), IndexIsle.AT + Vector3(-14, 4.2, 0)],
		["view-index-exchange", IndexIsle.AT + Vector3(4.6, 2.4, 3.6), IndexIsle.AT + Vector3(25, 9, 0)],
		["view-index-square", IndexIsle.AT + Vector3(17, 2.6, -6), IndexIsle.AT + Vector3(6, 3.6, 12)],
		["view-index-pier", IndexIsle.AT + Vector3(-58, 6, 16), IndexIsle.AT + Vector3(-40, 1.5, 0)]],
	"race": [["view-race", RaceIsle.AT + Vector3(-78, 30, 24), RaceIsle.AT + Vector3(4, 4, 0)],
		["view-race-avenue", RaceIsle.AT + Vector3(-31, 2.4, 0), RaceIsle.AT + Vector3(6, 9, 0)],
		["view-race-tower", RaceIsle.AT + Vector3(-14, 2.2, 5), RaceIsle.AT + Vector3(6, 11, 0)],
		["view-race-pits", RaceIsle.AT + Vector3(-18, 2.6, 8), RaceIsle.AT + Vector3(-2, 2, 18)],
		["view-race-stand", RaceIsle.AT + Vector3(-12, 2.6, -6), RaceIsle.AT + Vector3(2, 4, -24)],
		["view-race-track", RaceIsle.AT + Vector3(20, 3.0, 20), RaceIsle.AT + Vector3(36, 8, 32)],
		["view-race-pier", RaceIsle.AT + Vector3(-70, 6, 16), RaceIsle.AT + Vector3(-44, 3, 0)]],
	"hall": [["view-hall", Vector3(0, 3.4, 10.4), Vector3(0, 5, -9)], ["view-hall-side", Vector3(10, 4, 6), Vector3(-6, 2.5, -6)],
		["view-hall-up", Vector3(0, 1.6, 9), Vector3(0, 12, -4)]],
}


## `--views=<dir>`: only the fixed views, no probe.
static func views(tree: SceneTree) -> void:
	var dir := Session.arg("views")
	DirAccess.make_dir_recursive_absolute(dir)
	for place: String in PLACES:
		if not Session.arg("only").is_empty() and place != Session.arg("only"):
			continue
		Game.island = "harbour" if place == "hall" else place
		Game.attuned = Game.island
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
	for place: String in ["harbour", "silk", "amber", "shorts", "crypto", "index", "race"]:
		if not Session.arg("only").is_empty() and place != Session.arg("only"):
			continue
		Game.island = place
		Game.attuned = place
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


## `--talk=<dir>`: every talk as it is read, one picture per full page (ADR-0027). `--only=<talk id>` for one,
## `--island=silk` for the pages as Silk Reach draws them, `--lang=en`.
static func talk(tree: SceneTree) -> void:
	var dir := Session.arg("talk")
	DirAccess.make_dir_recursive_absolute(dir)
	if not Session.arg("island").is_empty():
		Game.island = Session.arg("island")
		Game.attuned = Game.island
	if not Session.arg("lang").is_empty():
		Locale.set_locale(Session.arg("lang"))
	tree.change_scene_to_file("res://scenes/harbour.tscn")
	await Session.wait(2.0)
	var scene := tree.current_scene as Node3D
	var page: ComicPage = scene.call("comic")
	var sample := {"eps": "1,25", "revenue": "48 000,00", "season": "3", "consensus": "1,10"}
	for id: String in ComicScript.read().talks:
		if not Session.arg("only").is_empty() and id != Session.arg("only"):
			continue
		page.open(id, sample)
		var n := 1
		while page.is_open():
			await Session.wait(0.35)
			if page.reader().page_full():
				for f in page.frames():
					f.show_gloss(not Session.arg("gloss").is_empty())  # as with T held
				await Session.wait(0.3)
				scene.get_viewport().get_texture().get_image().save_png(dir.path_join("%s-%d.png" % [id, n]))
				print("talk: ", id, " page ", n, " fps=", Engine.get_frames_per_second())
				n += 1
			page.step()
	tree.quit()


## `--read=<dir>`: Amber Cliff as the player meets it (ADR-0028) — the captain at a shop door with the prompt in
## French, then with T held (the prompt and the nearest sign in the game's language). `--lang=en` for English.
static func read(tree: SceneTree) -> void:
	var dir := Session.arg("read")
	DirAccess.make_dir_recursive_absolute(dir)
	if not Session.arg("lang").is_empty():
		Locale.set_locale(Session.arg("lang"))
	Game.island = AmberCliff.ID
	Game.attuned = AmberCliff.ID
	tree.change_scene_to_file("res://scenes/harbour.tscn")
	await Session.wait(2.0)
	var scene := tree.current_scene as Node3D
	var captain: Captain = scene.get("_captain")
	for shop: String in ["bakery", "change", "bank"]:
		var at := AmberCliff.door(shop)
		captain.global_position = at[1] + Vector3(0, 0.3, 0)
		captain.velocity = Vector3.ZERO
		var away := (at[1] - at[0]).normalized()
		captain.yaw = atan2(away.x, away.z)  # the camera behind the captain, looking at the door
		captain.pitch = -0.12
		captain.body.rotation.y = captain.yaw + PI
		await Session.wait(1.0)
		scene.get_viewport().get_texture().get_image().save_png(dir.path_join(shop + "-fr.png"))
		var key := InputEventKey.new()
		key.keycode = KEY_T
		key.physical_keycode = KEY_T
		key.pressed = true
		Input.parse_input_event(key)
		await Session.wait(0.5)
		scene.get_viewport().get_texture().get_image().save_png(dir.path_join(shop + "-gloss.png"))
		key = key.duplicate()
		key.pressed = false
		Input.parse_input_event(key)
		print("read: ", shop, " prompt=", (scene.get("_prompt") as Label).text)
	tree.quit()


## `--stroll=<dir>`: the picture on the move — the camera walks 12 m across an island at walking pace and a frame is
## saved every 0.1 s (frame-NN.png), to look for patterns that shimmer. `--island=silk` (default) or another;
## `--still` keeps the camera in place, `--turn` keeps it in place and turns it.
static func stroll(tree: SceneTree) -> void:
	var dir := Session.arg("stroll")
	DirAccess.make_dir_recursive_absolute(dir)
	var place := "silk" if Session.arg("island").is_empty() else Session.arg("island")
	Game.island = place
	Game.attuned = place
	tree.change_scene_to_file("res://scenes/harbour.tscn")
	await Session.wait(2.0)
	var scene := tree.current_scene as Node3D
	var centre: Vector3 = Archipelago.walk_areas(place)[0]["centre"]
	var cam := Camera3D.new()
	cam.fov = 60
	scene.add_child(cam)
	cam.current = true
	for c in scene.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	var from := centre + Vector3(-19, 1.9, 17)
	var to := centre + Vector3(-9, 1.9, 9)
	var look := centre + Vector3(4, 1.6, -4)
	if place == ShortIsle.ID or place == AmberCliff.ID or place == CryptoIsle.ID or place == IndexIsle.ID or place == RaceIsle.ID:  # these two have a street: walk along it
		from = centre + Vector3(-22, 1.9, 0.8)
		to = centre + Vector3(-10, 1.9, 0.4)
		look = centre + Vector3(21, 5, 0)
	if not Session.arg("still").is_empty():  # `--still`: the camera stands; whatever changes then is the picture itself
		to = from
	var turning := not Session.arg("turn").is_empty()  # `--turn`: the camera stands and looks round, 2° a frame
	if turning:
		to = from
	for i in 30:
		cam.position = from.lerp(to, i / 29.0)
		cam.look_at(look)
		if turning:
			cam.rotate_y(deg_to_rad(-30.0 + i * 2.0))
		await _await_drawn(tree)
		await tree.process_frame
		scene.get_viewport().get_texture().get_image().save_png(dir.path_join("frame-%02d.png" % i))
	print("stroll: ", place, " 30 frames")
	tree.quit()


## `--flight=<dir>`: a voyage with the compass at the wheel (ADR-0032) — from `--island` (default harbour) to `--to`
## (default amber); a frame every 0.5 s as frame-NNN.png until moored (at most 150), with the HUD. `--storm` flies it in
## a storm; `--measure` prints the frame rate under way instead.
static func flight(tree: SceneTree) -> void:
	var dir := Session.arg("flight")
	DirAccess.make_dir_recursive_absolute(dir)
	Game.island = "harbour" if Session.arg("island").is_empty() else Session.arg("island")
	Game.attuned = Game.island
	Game.destination = "amber" if Session.arg("to").is_empty() else Session.arg("to")
	if not Session.arg("chart").is_empty():  # `--chart`: only the "where to?" chart at the pier
		Session.spawn = "pier"
		tree.change_scene_to_file("res://scenes/harbour.tscn")
		await Session.wait(2.0)
		(tree.current_scene.call("chart") as FlightChartPanel).offer(Game.island)
		await Session.wait(0.6)
		tree.current_scene.get_viewport().get_texture().get_image().save_png(dir.path_join("chart.png"))
		tree.quit()
		return
	tree.change_scene_to_file("res://scenes/voyage.tscn")
	await Session.wait(1.5)
	var scene := tree.current_scene as Node3D
	scene.set("_auto", true)
	if not Session.arg("storm").is_empty():
		scene.call("demo_storm", 0.9)
	if not Session.arg("measure").is_empty():  # frame rate under way, nothing being saved
		await Session.wait(2.0)
		var r: Dictionary = await _measure(tree, "voyage", 0.0, 6.0)
		print("flight fps: avg %.0f  1%%-low %.0f  worst frame %.1f ms" % [r["avg"], r["low"], r["worst_ms"]])
		tree.quit()
		return
	var n := 0
	while n < 150 and not scene.call("arrived"):
		await Session.wait(0.5)
		scene.get_viewport().get_texture().get_image().save_png(dir.path_join("frame-%03d.png" % n))
		n += 1
		if str(scene.get("_at")) == Game.destination:
			scene.call("moor")
	await Session.wait(0.6)
	scene.get_viewport().get_texture().get_image().save_png(dir.path_join("frame-%03d.png" % n))
	var m: FlightModel = scene.get("model")
	print("flight: %s → %s in %d frames, flown %d m, moored at %s, fps=%d" % [Session.arg("island"), Game.destination, n, int(m.flown), Game.island, int(Engine.get_frames_per_second())])
	tree.quit()


## `--attune=<dir>`: the captain lands on Silk Reach still drawn the Spark Harbour way and the island's wind
## restyles them (ADR-0025). Saves a frame every 0.1 s as frame-NN.png; add `--ink=2` for the engraving.
static func attune(tree: SceneTree) -> void:
	var dir := Session.arg("attune")
	DirAccess.make_dir_recursive_absolute(dir)
	var to := "silk" if Session.arg("island").is_empty() else Session.arg("island")
	Game.island = to
	Game.attuned = "harbour"
	tree.change_scene_to_file("res://scenes/harbour.tscn")
	await Session.wait(2.0)
	var scene := tree.current_scene as Node3D
	var captain: Captain = scene.get("_captain")
	captain.body.rotation.y = atan2(3.6, 0.7)  # facing the camera, which looks along the pier
	var cam := Camera3D.new()
	cam.fov = 40
	scene.add_child(cam)
	cam.position = captain.global_position + Vector3(3.6, 1.5, 0.7)
	cam.look_at(captain.global_position + Vector3(0, 1.05, 0))
	cam.current = true
	for c in scene.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	await _await_drawn(tree)
	Session.attune(captain, "harbour", to, 2.0, 0.5)
	for i in 32:
		await Session.wait(0.1)
		scene.get_viewport().get_texture().get_image().save_png(dir.path_join("frame-%02d.png" % i))
	print("attune: attuned=", Game.attuned, " style=", Session.style_id)
	tree.quit()


static func run(tree: SceneTree) -> void:
	var dir := Session.arg("audit")
	DirAccess.make_dir_recursive_absolute(dir)
	var report: Dictionary = {}
	for place: String in PLACES:
		if not Session.arg("only").is_empty() and Session.arg("only") != place:
			continue
		Game.island = "harbour" if place == "hall" else place
		Game.attuned = Game.island
		Session.spawn = "start"
		tree.change_scene_to_file("res://scenes/%s.tscn" % ("hall" if place == "hall" else "harbour"))
		for i in 30:
			await tree.physics_frame
		var scene := tree.current_scene as Node3D
		var probe := WorldProbe.new(scene, areas(place))
		await probe.run_all()
		spots(probe, place)
		if place != "hall":  # nobody walks in the hall: the camera orbits there
			var spawns: Array[Vector3] = []
			for sp: String in ["start", "pier", "exchange"]:
				spawns.append(Archipelago.spawn_point(place, sp)[0])
			var t0 := Time.get_ticks_msec()
			probe.scan_routes(spawns)
			probe.fuzz(spawns, 40000)
			probe.scan_villagers()
			print("audit: %s routes: cells=%d main=%d unreachable=%d villager routes=%d (%d s)" % [place, probe.nodes.size(), probe.main.size(), probe.unreachable, probe.routes, (Time.get_ticks_msec() - t0) / 1000])
		if OS.has_environment("PROBE_DEBUG"):
			for i in probe.issues:
				print("issue ", i["kind"], " ", (i["at"] as Vector3).snapped(Vector3.ONE * 0.01), " ", i["what"])
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

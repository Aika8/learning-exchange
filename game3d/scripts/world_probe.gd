## The world audit: walks a probe body over a grid of every place people can stand and looks at every object there.
## It reports holes in the floor, falls, tunnelling, traps, solid-looking things without collision, colliders that do
## not follow the shape, floating props, detached parts, z-fighting and heavy meshes without LODs.
## Used by `--audit=<dir>` (scripts/audit.gd, screenshots for docs/demo/G3D-polish.md) and by the GUT tests.
class_name WorldProbe
extends RefCounted

const STEP := 2.0  ## grid spacing, metres
const FRAMES := 45  ## physics steps per walk
const DT := 1.0 / 60.0
const SOFT: Array[String] = ["fern", "grass", "shrub", "root"]  ## plants you walk through by design
const HEAVY_TRIS := 4000  ## a mesh above this needs LODs

var world: Node3D
var areas: Array[Dictionary]
var space: PhysicsDirectSpaceState3D
var body: CharacterBody3D
var issues: Array[Dictionary] = []  ## {kind, at: Vector3, what: String}
var points := 0
var free_points := 0
var walks := 0
var units := 0


func _init(root: Node3D, walk_areas: Array[Dictionary]) -> void:
	world = root
	areas = walk_areas
	space = root.get_world_3d().direct_space_state
	body = CharacterBody3D.new()
	body.name = "Probe"
	Mover.capsule(body)
	Mover.setup(body)
	root.add_child(body)


func done() -> void:
	body.queue_free()


func run_all() -> void:
	walk_grid()
	scan_objects()
	scan_zfight()
	scan_lods()


func count(kind: String) -> int:
	var n := 0
	for i in issues:
		n += 1 if i["kind"] == kind else 0
	return n


## Issues folded by kind and place (object name, or a 6 m cell), so one broken pier is one line, not forty.
func clusters() -> Array[Dictionary]:
	var by: Dictionary = {}
	for i in issues:
		var at: Vector3 = i["at"]
		var key := "%s|%s" % [i["kind"], i["what"] if not str(i["what"]).is_empty() else "%d,%d" % [int(floor(at.x / 6.0)), int(floor(at.z / 6.0))]]
		if not by.has(key):
			by[key] = {"kind": i["kind"], "what": i["what"], "at": at, "n": 0}
		by[key]["n"] += 1
	var out: Array[Dictionary] = []
	out.assign(by.values())
	return out


func _add(kind: String, at: Vector3, what: String = "") -> void:
	issues.append({"kind": kind, "at": at, "what": what})


# ---------------------------------------------------------------- areas

static func inside(area: Dictionary, p: Vector3, margin: float = 0.0) -> bool:
	match area["kind"]:
		"disc":
			var c: Vector3 = area["centre"]
			var d := Vector2(p.x - c.x, p.z - c.z)
			return d.length() < Proc.cap_radius(area["radius"], area["seed"], atan2(d.y, d.x)) - margin
		"circle":
			var c: Vector3 = area["centre"]
			return Vector2(p.x - c.x, p.z - c.z).length() < float(area["radius"]) - margin
	var a: Vector3 = area["from"]
	var b: Vector3 = area["to"]
	return p.x > a.x + margin and p.x < b.x - margin and p.z > a.z + margin and p.z < b.z - margin


func in_any(p: Vector3, margin: float = 0.0) -> bool:
	for a in areas:
		if inside(a, p, margin):
			return true
	return false


static func base_y(area: Dictionary) -> float:
	return (area["centre"] as Vector3).y if area.has("centre") else (area["from"] as Vector3).y


## Grid points of an area, `margin` metres inside its edge.
static func grid(area: Dictionary, margin: float = 0.6, step: float = STEP) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var lo: Vector3
	var hi: Vector3
	if area.has("centre"):
		var r := float(area["radius"]) * 1.2
		lo = (area["centre"] as Vector3) - Vector3(r, 0, r)
		hi = (area["centre"] as Vector3) + Vector3(r, 0, r)
	else:
		lo = area["from"]
		hi = area["to"]
	var x := lo.x + margin
	while x <= hi.x - margin + 0.001:
		var z := lo.z + margin
		while z <= hi.z - margin + 0.001:
			var p := Vector3(x, base_y(area), z)
			if inside(area, p, margin - 0.001):
				out.append(p)
			z += step
		x += step
	return out


# ---------------------------------------------------------------- physics helpers

## The ground under `p`: looks from 2.6 m above the area's level (above any hill, under any roof) down 4 m.
func floor_at(p: Vector3, exclude: Array[RID] = []) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 2.6, 0), p + Vector3(0, -4.0, 0))
	q.exclude = exclude + [body.get_rid()]
	return space.intersect_ray(q)


## True when a walker's capsule fits at `feet` (lifted a little, so touching the ground does not count).
func fits(feet: Vector3) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = Mover.RADIUS - 0.03
	cap.height = Mover.HEIGHT - 0.3
	q.shape = cap
	q.transform = Transform3D(Basis(), feet + Vector3(0, Mover.HEIGHT * 0.5 + 0.2, 0))
	q.exclude = [body.get_rid()]
	return space.intersect_shape(q, 1).is_empty()


# ---------------------------------------------------------------- 1. the walk

func walk_grid() -> void:
	for area in areas:
		for p in grid(area):
			points += 1
			var hit := floor_at(p)
			if hit.is_empty():
				_add("hole", p, area["name"])
				continue
			var feet: Vector3 = hit["position"]
			if not fits(feet):
				continue  # a building or a prop stands here
			free_points += 1
			var moved := 0.0
			for k in 8:
				var dir := Vector3(cos(TAU * k / 8.0), 0, sin(TAU * k / 8.0))
				moved = maxf(moved, _walk(feet, dir, area["name"]))
			if moved < 0.3:
				_add("stuck", feet, area["name"])


## Walks from `feet` along `dir`; returns the distance covered. Reports a fall or a tunnel on the way.
func _walk(feet: Vector3, dir: Vector3, where: String) -> float:
	walks += 1
	body.global_position = feet + Vector3(0, 0.05, 0)
	body.velocity = Vector3.ZERO
	var ground := feet.y
	for f in FRAMES:
		var before := body.global_position
		Mover.step(body, dir, DT)
		var now := body.global_position
		if now.y < ground - 1.5:
			_add("fall", Vector3(before.x, ground, before.z), where)
			break
		if body.is_on_floor():
			ground = now.y
		var q := PhysicsRayQueryParameters3D.create(before + Vector3(0, 1.0, 0), now + Vector3(0, 1.0, 0))
		q.exclude = [body.get_rid()]
		if not space.intersect_ray(q).is_empty():
			_add("tunnel", now, where)
			break
	var d := body.global_position - feet
	return Vector2(d.x, d.z).length()


## A spot the game puts somebody on: needs ground under it and room for the capsule.
func check_spawn(name: String, p: Vector3) -> bool:
	var hit := floor_at(Vector3(p.x, p.y - 0.5, p.z))
	if hit.is_empty():
		_add("spawn", p, name + ": no ground")
		return false
	if not fits(hit["position"]):
		_add("spawn", p, name + ": inside a collider")
		return false
	return true


## An interaction spot must be reachable: some free standing point within its radius.
func check_spot(name: String, p: Vector3, radius: float) -> bool:
	for k in 17:
		var off := Vector3.ZERO if k == 0 else Vector3(cos(TAU * k / 8.0), 0, sin(TAU * k / 8.0)) * radius * (0.45 if k <= 8 else 0.8)
		var hit := floor_at(p + off)
		if not hit.is_empty() and in_any(p + off, 0.5) and fits(hit["position"]):
			return true
	_add("spot", p, name + ": nowhere to stand")
	return false


# ---------------------------------------------------------------- 2. objects

## Top-level things of the world: children of the scene and of the two island nodes.
func _units() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for c in world.get_children():
		if c.name in [&"SparkHarbour", &"SilkReach"]:
			for g in c.get_children():
				if g is Node3D:
					out.append(g)
		elif c is Node3D and c != body and not c is CharacterBody3D:
			out.append(c)
	return out


static func _meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null and (n as MeshInstance3D).visible:
		out.append(n)
	for m in n.find_children("*", "MeshInstance3D", true, false):
		if (m as MeshInstance3D).mesh != null and (m as MeshInstance3D).is_visible_in_tree():
			out.append(m)
	return out


static func _bounds(meshes: Array[MeshInstance3D], frame: Transform3D = Transform3D()) -> AABB:
	var box := AABB()
	var first := true
	for m in meshes:
		var b := (frame.affine_inverse() * m.global_transform) * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


static func _own_bodies(n: Node) -> Array[RID]:
	var out: Array[RID] = []
	if n is CollisionObject3D:
		out.append((n as CollisionObject3D).get_rid())
	for b in n.find_children("*", "CollisionObject3D", true, false):
		out.append((b as CollisionObject3D).get_rid())
	return out


static func label(n: Node) -> String:
	if n.has_meta("asset"):
		return str(n.get_meta("asset"))
	var s := str(n.name)
	return "unnamed" if s.begins_with("@") else s.rstrip("0123456789")


func scan_objects() -> void:
	for u in _units():
		var meshes := _meshes(u)
		if meshes.is_empty() or u.name == &"CloudSea":
			continue
		var box := _bounds(meshes)
		var c := box.get_center()
		if not in_any(c):
			continue
		var name := label(u)
		var hit := floor_at(Vector3(c.x, _area_y(c), c.z), _own_bodies(u))
		if hit.is_empty():
			continue  # over a hole: the walk reports that
		var ground: float = hit["position"].y
		units += 1
		var soft := false
		for s in SOFT:
			soft = soft or name.contains(s)
		var hung := u.has_meta("hung") or u.has_meta("flat")
		# floating: the lowest point hangs above the ground (or above whatever is under it)
		if not hung and box.position.y - ground > 0.25 and box.position.y - ground < 6.0:
			_add("floating", Vector3(c.x, box.position.y, c.z), name)
		# solid-looking but no collision
		var tall := box.end.y > ground + 0.6 and box.position.y < ground + 1.0
		if tall and not soft and not u.has_meta("flat"):
			var solid := _hits(u, meshes, ground)
			if solid == 0:
				_add("no-collision", Vector3(c.x, ground, c.z), name)
			elif solid == 1:
				_add("loose-collider", Vector3(c.x, ground, c.z), name)
		# detached parts of a built thing
		if not u.has_meta("asset") and meshes.size() > 1:
			for m in meshes:
				var mine := (m.global_transform * m.get_aabb()).grow(0.04)
				var touches := mine.position.y <= ground + 0.05
				for o in meshes:
					if o != m and mine.intersects(o.global_transform * o.get_aabb()):
						touches = true
						break
				if not touches:
					_add("gap", mine.get_center(), name)
					break


func _area_y(p: Vector3) -> float:
	for a in areas:
		if inside(a, p):
			return base_y(a)
	return p.y


## 0 = nothing solid, 1 = a collider that misses the shape by more than 0.6 m, 2 = a collider that follows it.
## Rays go through the object in its own frame at knee and chest height, three per side.
func _hits(u: Node3D, meshes: Array[MeshInstance3D], ground: float) -> int:
	var frame := u.global_transform.orthonormalized()
	var band: Array[MeshInstance3D] = []
	for m in meshes:  # only what stands in a walker's way (not the roof, not the canopy)
		var g := m.global_transform * m.get_aabb()
		if g.position.y < ground + 1.6 and g.end.y > ground + 0.3 and g.size.y > 0.4:
			band.append(m)
	if band.is_empty():
		band = meshes
	var box := _bounds(band, frame)
	var any := false
	var loose := false
	var composite := not u.has_meta("asset") and band.size() > 1
	var world_box := (frame * box).grow(0.3)
	for axis: int in [0, 2]:
		var other := 2 - axis
		for side: float in [-1.0, 1.0]:
			for t: float in [-0.38, 0.0, 0.38]:
				for h: float in [0.5, 1.1]:
					var from := box.get_center()
					from[axis] += side * (box.size[axis] * 0.5 + 0.6)
					from[other] += t * box.size[other]
					var to := from
					to[axis] -= side * (box.size[axis] + 1.2)
					var a := frame * from
					var b := frame * to
					a.y = ground + minf(h, maxf(0.15, (frame * box).end.y - ground - 0.1))
					b.y = a.y
					var exclude: Array[RID] = [body.get_rid()]
					for attempt in 4:
						var q := PhysicsRayQueryParameters3D.create(a, b)
						q.exclude = exclude
						var r := space.intersect_ray(q)
						if r.is_empty():
							break
						if not world_box.has_point(r["position"]):
							exclude.append(r["rid"])
							continue
						any = true
						if composite and t != 0.0 and absf((r["position"] as Vector3).distance_to(a) - 0.6) > 0.6:
							loose = true
						break
					if composite and t != 0.0 and any and space.intersect_ray(PhysicsRayQueryParameters3D.create(a, b, 0xFFFFFFFF, exclude)).is_empty():
						loose = true  # the corner of the thing sticks out of its collider
	return 0 if not any else (1 if loose else 2)


# ---------------------------------------------------------------- 3. z-fighting

## Flat boxes whose tops lie in the same plane and overlap: the two surfaces flicker.
func scan_zfight() -> void:
	var tops: Array[Array] = []  # [top y, corners: PackedVector2Array, node]
	for u in _units():
		for m in _meshes(u):
			if not m.mesh is BoxMesh or m.global_basis.y.normalized().dot(Vector3.UP) < 0.999:
				continue
			var g := m.global_transform * m.get_aabb()
			if not in_any(g.get_center()):
				continue
			var s := (m.mesh as BoxMesh).size * 0.5
			var corners := PackedVector2Array()
			for k: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var w := m.global_transform * Vector3(k.x * s.x, 0, k.y * s.z)
				corners.append(Vector2(w.x, w.z))
			tops.append([g.end.y, corners, u])
	for i in tops.size():
		for j in range(i + 1, tops.size()):
			if absf(float(tops[i][0]) - float(tops[j][0])) > 0.004:
				continue
			var clip := Geometry2D.intersect_polygons(tops[i][1], tops[j][1])
			if clip.is_empty() or _area(clip[0]) < 0.05:
				continue
			var mid := Vector2.ZERO
			for v: Vector2 in clip[0]:
				mid += v / clip[0].size()
			_add("z-fight", Vector3(mid.x, tops[i][0], mid.y), label(tops[i][2]) + " / " + label(tops[j][2]))


static func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		a += poly[i].cross(poly[(i + 1) % poly.size()])
	return absf(a) * 0.5


# ---------------------------------------------------------------- 4. LODs

static func triangles(mesh: Mesh) -> int:
	var n := 0
	for s in mesh.get_surface_count():
		if mesh is ArrayMesh:
			var am := mesh as ArrayMesh
			var idx := am.surface_get_array_index_len(s)
			n += (idx if idx > 0 else am.surface_get_array_len(s)) / 3
		else:
			var arr := mesh.surface_get_arrays(s)
			n += (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3 if arr[Mesh.ARRAY_INDEX] != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return n


static func has_lods(mesh: Mesh) -> bool:
	for s in mesh.get_surface_count():
		var d := RenderingServer.mesh_get_surface(mesh.get_rid(), s)
		if d.has("lods") and not (d["lods"] as Array).is_empty():
			return true
	return false


## Heavy meshes near the walkable world without LODs (and with no distance cut-off either).
func scan_lods() -> void:
	var seen: Dictionary = {}
	for m in _meshes(world):
		if seen.has(m.mesh) or m == null:
			continue
		seen[m.mesh] = true
		var c := (m.global_transform * m.get_aabb()).get_center()
		var near := false
		for a in areas:
			var centre: Vector3 = a["centre"] if a.has("centre") else a["from"]
			near = near or c.distance_to(centre) < 90.0
		var tris := triangles(m.mesh)
		if near and tris > HEAVY_TRIS and not has_lods(m.mesh) and m.visibility_range_end == 0.0:
			var owner_unit: Node = m
			while owner_unit.get_parent() != null and not owner_unit.has_meta("asset") and owner_unit.get_parent() != world \
					and not owner_unit.get_parent().name in [&"SparkHarbour", &"SilkReach"]:
				owner_unit = owner_unit.get_parent()
			_add("no-lod", c, "%s (%d tris)" % [label(owner_unit), tris])

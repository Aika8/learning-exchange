## The world audit: walks a probe body over a grid of every place people can stand and looks at every object there.
## It reports holes in the floor, falls, tunnelling, traps, solid-looking things without collision, colliders that do
## not follow the shape, floating props, detached parts, z-fighting and heavy meshes without LODs.
## The route scans (section 5) add: places the captain can walk into and not out of, walls and fences that are
## drawn but let a body through, and villager strolls that the villager's body cannot finish.
## Used by `--audit=<dir>` (scripts/audit.gd, screenshots for docs/demo/G3D-polish.md) and by the GUT tests.
class_name WorldProbe
extends RefCounted

const STEP := 2.0  ## grid spacing, metres
const FRAMES := 45  ## physics steps per walk
const DT := 1.0 / 60.0
const SOFT: Array[String] = ["fern", "grass", "shrub", "root"]  ## plants you walk through by design
const HEAVY_TRIS := 4000  ## a mesh above this needs LODs
const PROXY_LAYER := 1 << 19  ## physics layer of the "what you see" copies used to check colliders against shape
const PROXY_TRIS := 30000  ## heavier things (tree crowns) are not copied
const SHAPE_SLACK := 0.45  ## how far inside the surface you see a collider may sit (you would walk into the thing)
const HULL_SLACK := 0.8  ## how far in front of it (an open shelf is a solid box; more is an invisible wall)

var world: Node3D
var areas: Array[Dictionary]
var space: PhysicsDirectSpaceState3D
var body: CharacterBody3D
var issues: Array[Dictionary] = []  ## {kind, at: Vector3, what: String}
var points := 0
var free_points := 0
var walks := 0
var units := 0
var spacing := STEP  ## the tests walk a coarser grid
var lattice := 0.5  ## spacing of the route lattice, metres (the tests use a coarser one)
var nodes: Dictionary = {}  ## lattice cell (Vector2i) → where a walker's feet stand there (Vector3)
var main: Dictionary = {}  ## cells the captain can reach from a spawn point and come back from
var unreachable := 0  ## free cells nobody can get to (behind a wall): not a fault, only a count
var routes := 0  ## villager routes walked
var _next: Dictionary = {}  ## cell → cells one walk away
var _crossed: Dictionary = {}  ## walk-through already reported, by thing and metre
var _trace := false
var _people: Array[RID] = []  ## villagers and the captain: they move, the audit is about the world
var _proxies: Dictionary = {}  ## unit → StaticBody3D with the unit's real triangles, on PROXY_LAYER


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
	for u: Node in _proxies:
		(_proxies[u] as Node).queue_free()


## Before the scans: ignore walking people, and put a triangle-exact copy of every object on its own physics layer
## so colliders can be compared with what the eye sees. Await it.
func prepare() -> void:
	for c in world.find_children("*", "CharacterBody3D", true, false):
		if c != body:
			body.add_collision_exception_with(c)
			_people.append((c as CharacterBody3D).get_rid())
	for u in _units():
		var meshes := _meshes(u)
		var tris := 0
		for m in meshes:
			tris += triangles(m.mesh)
		if meshes.is_empty() or tris > PROXY_TRIS:
			continue
		var proxy := StaticBody3D.new()
		proxy.set_meta("unit", u)
		proxy.collision_layer = PROXY_LAYER
		proxy.collision_mask = 0
		for m in meshes:
			var faces := m.mesh.get_faces()
			if faces.is_empty():
				continue
			var shape := ConcavePolygonShape3D.new()
			shape.backface_collision = true
			shape.set_faces(m.global_transform * faces)
			var cs := CollisionShape3D.new()
			cs.shape = shape
			proxy.add_child(cs)
		world.add_child(proxy)
		_proxies[u] = proxy
	await world.get_tree().physics_frame
	await world.get_tree().physics_frame


func run_all() -> void:
	await prepare()
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

## What every query ignores: the probe itself and the people, plus `more`.
func _skip(more: Array[RID] = []) -> Array[RID]:
	var out: Array[RID] = [body.get_rid()]
	out.append_array(_people)
	out.append_array(more)
	return out


## The ground under `p`: looks from 2.6 m above the area's level (above any hill, under any roof) down 4 m.
func floor_at(p: Vector3, exclude: Array[RID] = []) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 2.6, 0), p + Vector3(0, -4.0, 0), 1)
	q.exclude = _skip(exclude)
	return space.intersect_ray(q)


## True when the thing hit by `floor_at` is an object standing on the ground (a crate, a desk), not the ground.
func on_top_of_something(hit: Dictionary) -> bool:
	var n: Node = hit["collider"]
	while n != null and n != world:
		if n.has_meta("flat"):
			return false  # a deck or a terrace is ground, however high it stands over the grass
		n = n.get_parent()
	var from: Vector3 = hit["position"]
	var q := PhysicsRayQueryParameters3D.create(from + Vector3(0, -0.02, 0), from + Vector3(0, -2.6, 0), 1)
	q.exclude = _skip([hit["rid"]])
	var under := space.intersect_ray(q)
	return not under.is_empty() and from.y - (under["position"] as Vector3).y > 0.5


## True when a walker's capsule fits at `feet` (lifted a little, so touching the ground does not count).
func fits(feet: Vector3) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = Mover.RADIUS - 0.03
	cap.height = Mover.HEIGHT - 0.3
	q.shape = cap
	q.transform = Transform3D(Basis(), feet + Vector3(0, Mover.HEIGHT * 0.5 + 0.2, 0))
	q.collision_mask = 1
	q.exclude = _skip()
	return space.intersect_shape(q, 1).is_empty()


# ---------------------------------------------------------------- 1. the walk

func walk_grid() -> void:
	for area in areas:
		for p in grid(area, 0.6, spacing):
			points += 1
			var hit := floor_at(p)
			if hit.is_empty():
				_add("hole", p, area["name"])
				continue
			var feet: Vector3 = hit["position"]
			if on_top_of_something(hit) or not fits(feet):
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
		var q := PhysicsRayQueryParameters3D.create(before + Vector3(0, 1.0, 0), now + Vector3(0, 1.0, 0), 1)
		q.exclude = _skip()
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
	if on_top_of_something(hit) or not fits(hit["position"]):
		_add("spawn", p, name + ": inside a collider")
		return false
	return true


## An interaction spot must be reachable: some free standing point within its radius.
func check_spot(name: String, p: Vector3, radius: float) -> bool:
	for k in 17:
		var off := Vector3.ZERO if k == 0 else Vector3(cos(TAU * k / 8.0), 0, sin(TAU * k / 8.0)) * radius * (0.45 if k <= 8 else 0.8)
		var hit := floor_at(p + off)
		if not hit.is_empty() and in_any(p + off, 0.5) and not on_top_of_something(hit) and fits(hit["position"]):
			return true
	_add("spot", p, name + ": nowhere to stand")
	return false


# ---------------------------------------------------------------- 2. objects

## Top-level things of the world: children of the scene and of the two island nodes.
func _units() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for c in world.get_children():
		if c.name in [&"SparkHarbour", &"SilkReach", &"AmberCliff", &"ShortIsle", &"CryptoIsle", &"IndexIsle"]:
			for g in c.get_children():
				if g is Node3D:
					out.append(g)
		elif c is StaticBody3D or c is Decal:
			continue
		elif c is Node3D and c != body and not c is CharacterBody3D and not c is NavigationRegion3D:
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
	if n.has_meta("solid") and n.get_meta("solid") != null:
		out.append((n.get_meta("solid") as CollisionObject3D).get_rid())
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


## 0 = nothing solid, 1 = a collider that does not follow the shape, 2 = a collider that follows it.
## Rays go through the object in its own frame at knee and chest height, three per side. Each ray is cast twice:
## at the triangles you see (the proxy) and at the colliders. Where the eye sees a surface there must be a collider
## within SHAPE_SLACK of it.
func _hits(u: Node3D, meshes: Array[MeshInstance3D], ground: float) -> int:
	var frame := u.global_transform.orthonormalized()
	var low: Array[MeshInstance3D] = []  # only what a walker can touch lays out the rays: mill blades turn overhead
	for m in meshes:
		if (m.global_transform * m.get_aabb()).position.y < ground + 2.2:
			low.append(m)
	var box := _bounds(low if not low.is_empty() else meshes, frame)
	var world_box := (frame * box).grow(0.3)
	var proxy: StaticBody3D = _proxies.get(u)
	var own := _own_bodies(u)  # its own colliders; a thing without any may lean on a shared one
	var seen := 0
	var missed := 0
	var off := 0
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
					var solid := _ray_in(a, b, 1, world_box, null, own)
					if proxy == null:  # too heavy to copy (a tree): any collider in its place will do
						seen += 1
						missed += 1 if solid.is_empty() else 0
						continue
					var visual := _ray_in(a, b, PROXY_LAYER, world_box, proxy)
					if visual.is_empty():
						continue
					seen += 1
					if solid.is_empty() and _collider_near(visual["position"], own):
						continue  # the ray grazed the rim of something round: its collider is right there
					if solid.is_empty():
						missed += 1
						if OS.has_environment("PROBE_DEBUG"):
							print("miss ", label(u), " ray ", a, "→", b, " sees ", visual["position"])
					else:
						var sunk := (solid["position"] as Vector3).distance_to(a) - (visual["position"] as Vector3).distance_to(a)
						if sunk > SHAPE_SLACK or sunk < -HULL_SLACK:
							off += 1
							if OS.has_environment("PROBE_DEBUG"):
								print("loose ", label(u), " ray ", a, "→", b, " collider behind surface by ", sunk)
	if proxy == null:
		return 0 if missed == seen else 2
	if seen == 0:
		return 2
	if missed == seen:
		return 0
	return 1 if missed + off > 0 else 2


## True when one of the object's own colliders (any collider, if it has none of its own) is within SHAPE_SLACK
## of a point on its visible surface.
func _collider_near(at: Vector3, own: Array[RID]) -> bool:
	var ball := SphereShape3D.new()
	ball.radius = SHAPE_SLACK
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = ball
	q.transform = Transform3D(Basis(), at)
	q.collision_mask = 1
	q.exclude = _skip()
	for hit in space.intersect_shape(q, 16):
		if own.is_empty() or hit["rid"] in own:
			return true
	return false


## First hit of a ray on `mask` that lies inside `inside` (and, when given, on `only`); other things are skipped.
func _ray_in(a: Vector3, b: Vector3, mask: int, inside: AABB, only: CollisionObject3D, own: Array[RID] = []) -> Dictionary:
	var exclude := _skip()
	for attempt in 12:
		var q := PhysicsRayQueryParameters3D.create(a, b, mask)
		q.exclude = exclude
		var r := space.intersect_ray(q)
		if r.is_empty():
			return {}
		if inside.has_point(r["position"]) and (only == null or r["collider"] == only) and (own.is_empty() or r["rid"] in own):
			return r
		exclude.append(r["rid"])
	return {}


# ---------------------------------------------------------------- 5. routes: traps, walking through, villagers

const SINK := 0.22  ## how deep a walker's body may sink into what you see (a shutter, a beam proud of its wall is fine)
const CHEST: Array[float] = [0.55, 1.0, 1.55]  ## heights above the feet where a walker must not cross what the eye sees


## One step of a walk is checked twice: the body's middle line must not cross a collider (tunnelling) and must not
## cross a visible surface of anything solid-looking (a wall or a fence that is drawn but lets you through).
## Returns true when it did.
func _check_step(who: CharacterBody3D, before: Vector3, now: Vector3, where: String, wish: Vector3 = Vector3.ZERO) -> bool:
	var q := PhysicsRayQueryParameters3D.create(before + Vector3(0, 1.0, 0), now + Vector3(0, 1.0, 0), 1)
	q.exclude = _skip([who.get_rid()])
	if not space.intersect_ray(q).is_empty():
		_add("tunnel", now, where)
		return true
	# the ray runs from where the middle of the body was to SINK short of its front: what the eye sees must stop
	# the body before it is more than a hand deep in it, also when it only pushes against the thing
	var front := now + wish.normalized() * (Mover.RADIUS - SINK) if wish.length() > 0.1 else now
	if Vector2(front.x - before.x, front.z - before.z).length() < 0.001:
		return false
	for h in CHEST:
		var v := PhysicsRayQueryParameters3D.create(before + Vector3(0, h, 0), front + Vector3(0, h, 0), PROXY_LAYER)
		v.hit_back_faces = true
		var hit := space.intersect_ray(v)
		if hit.is_empty():
			continue
		if (hit["normal"] as Vector3).y > 0.5:
			continue  # a surface that faces up is ground or a tread under the feet, not a wall
		var unit: Node = (hit["collider"] as Node).get_meta("unit")
		var name := label(unit)
		var soft := false
		for s in SOFT:
			soft = soft or name.contains(s)
		if soft or unit.has_meta("walk_through"):
			continue
		var at: Vector3 = hit["position"]
		var key := "%s|%d,%d" % [name, int(floor(at.x)), int(floor(at.z))]
		if not _crossed.has(key):
			_crossed[key] = true
			if OS.has_environment("PROBE_DEBUG"):
				print("walk-through ", unit.get_path(), " at ", at, " normal ", hit["normal"], " height over feet ", h, " feet ", now, " kids ", unit.get_children().slice(0, 5))
			_add("walk-through", at, name)
		return true
	return false


func _cell(p: Vector3) -> Vector2i:
	return Vector2i(roundi(p.x / lattice), roundi(p.z / lattice))


## Walks `who` from where it stands at `from` to `to`, steering at it all the way. True when it arrives.
func _reach(who: CharacterBody3D, from: Vector3, to: Vector3, where: String, speed: float = Mover.WALK, near: float = 0.12) -> bool:
	who.global_position = from + Vector3(0, 0.05, 0)
	who.velocity = Vector3.ZERO
	var frames := int(Vector2(to.x - from.x, to.z - from.z).length() / speed / DT * 2.0) + 30
	for f in frames:
		var d := to - who.global_position
		d.y = 0.0
		if d.length() < near:
			return absf(who.global_position.y - to.y) < 0.7
		var before := who.global_position
		Mover.step(who, d.normalized(), DT, speed)
		if _check_step(who, before, who.global_position, where, d):
			if _trace:
				print("fail ", from, " -> ", to, " crossed something at ", who.global_position)
			return false
		if who.global_position.y < to.y - 3.0:
			return false
	if _trace:
		print("fail ", from, " -> ", to, " ended ", who.global_position, " floor ", who.is_on_floor(), " wall ", who.is_on_wall())
	return false


## The route lattice: every free standing place `lattice` metres apart, and which neighbours a walk reaches.
## Then: what the captain reaches from `spawns` and cannot come back from is a trap.
func scan_routes(spawns: Array[Vector3]) -> void:
	var lo := Vector3(INF, 0, INF)
	var hi := Vector3(-INF, 0, -INF)
	for a in areas:
		var r := float(a.get("radius", 0.0)) * 1.2
		var from: Vector3 = (a["centre"] as Vector3) - Vector3(r, 0, r) if a.has("centre") else a["from"]
		var to: Vector3 = (a["centre"] as Vector3) + Vector3(r, 0, r) if a.has("centre") else a["to"]
		lo = Vector3(minf(lo.x, from.x), 0, minf(lo.z, from.z))
		hi = Vector3(maxf(hi.x, to.x), 0, maxf(hi.z, to.z))
	for ix in range(int(ceil(lo.x / lattice)), int(floor(hi.x / lattice)) + 1):
		for iz in range(int(ceil(lo.z / lattice)), int(floor(hi.z / lattice)) + 1):
			var p := Vector3(ix * lattice, 0, iz * lattice)
			for a in areas:
				if not inside(a, p, 0.45):
					continue
				p.y = base_y(a)
				var hit := floor_at(p)
				if not hit.is_empty() and not on_top_of_something(hit) and fits(hit["position"]):
					nodes[Vector2i(ix, iz)] = hit["position"]
				break
	var back: Dictionary = {}
	for c: Vector2i in nodes:
		var out: Array[Vector2i] = []
		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				var n := c + Vector2i(dx, dz)
				if n == c or not nodes.has(n):
					continue
				walks += 1
				if _reach(body, nodes[c], nodes[n], ""):
					out.append(n)
					if not back.has(n):
						back[n] = []
					(back[n] as Array).append(c)
		_next[c] = out
	var starts: Array[Vector2i] = []
	for s in spawns:
		var c := _nearest(s, 2.0, nodes)
		if c != Vector2i.MAX:
			starts.append(c)
	var there := _flood(starts, _next)
	var home := _flood(starts, back)
	for c: Vector2i in there:
		if home.has(c):
			main[c] = true
		else:
			_add("trap", nodes[c], _area_name(nodes[c]))
	unreachable = nodes.size() - there.size()
	if OS.has_environment("PROBE_DEBUG"):
		print("routes: starts ", starts, " there ", there.size(), " home ", home.size())
		var shown := 0
		_trace = true
		for c: Vector2i in there:
			for dx in [-1, 0, 1]:
				for dz in [-1, 0, 1]:
					var n: Vector2i = c + Vector2i(dx, dz)
					if nodes.has(n) and not there.has(n) and shown < 6:
						shown += 1
						_reach(body, nodes[c], nodes[n], "")
		_trace = false


static func _flood(starts: Array[Vector2i], links: Dictionary) -> Dictionary:
	var seen: Dictionary = {}
	var todo: Array[Vector2i] = []
	for s in starts:
		seen[s] = true
		todo.append(s)
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for n: Vector2i in links.get(c, []):
			if not seen.has(n):
				seen[n] = true
				todo.append(n)
	return seen


## The lattice cell of `among` nearest to `p` within `radius`, or Vector2i.MAX.
func _nearest(p: Vector3, radius: float, among: Dictionary) -> Vector2i:
	var best := Vector2i.MAX
	var best_d := radius
	var c := _cell(p)
	var span := int(ceil(radius / lattice))
	for dx in range(-span, span + 1):
		for dz in range(-span, span + 1):
			var n := c + Vector2i(dx, dz)
			if among.has(n) and nodes.has(n):
				var d := Vector2(nodes[n].x - p.x, nodes[n].z - p.z).length()
				if d < best_d and absf(nodes[n].y - p.y) < 1.2:
					best_d = d
					best = n
	return best


func _area_name(p: Vector3) -> String:
	for a in areas:
		if inside(a, p):
			return a["name"]
	return ""


## The captain as a player drives it: `steps` physics steps of walking and running in random directions from a spawn
## point, pushing into every corner on the way. Wherever it ends up it must be able to walk back to the lattice
## (`scan_routes` first) — a place it cannot leave is a trap, even between two lattice cells.
func fuzz(spawns: Array[Vector3], steps: int = 20000, seed_value: int = 7) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var dir := Vector3.ZERO
	var speed := Mover.WALK
	var fresh := true
	for s in steps:
		if fresh:
			var c := _nearest(spawns[rng.randi() % spawns.size()], 2.0, main)
			if c == Vector2i.MAX:
				return
			body.global_position = (nodes[c] as Vector3) + Vector3(0, 0.05, 0)
			body.velocity = Vector3.ZERO
			fresh = false
		if s % 45 == 0:
			var a := rng.randf() * TAU
			dir = Vector3(cos(a), 0, sin(a))
			speed = Mover.RUN if rng.randf() < 0.35 else Mover.WALK
		var before := body.global_position
		Mover.step(body, dir, DT, speed)
		var now := body.global_position
		if _check_step(body, before, now, _area_name(now), dir):
			fresh = true
		elif now.y < _area_y(now) - 1.5 or not in_any(now, -1.5):  # off the edge: fell, or far past the fence
			_add("escape", before, _area_name(before))
			fresh = true
		elif s % 90 == 89 and body.is_on_floor():
			var velocity := body.velocity
			var out := false
			var tried := 0
			for near in _around(now, 1.6):
				tried += 1
				if _reach(body, now, nodes[near], "", Mover.WALK, 0.2):
					out = true
					break
				if tried >= 10:
					break
			if out:
				body.global_position = now
				body.velocity = velocity
			else:
				_add("trap", now, _area_name(now))
				fresh = true


## Cells of the main part within `radius` of `p`, nearest first.
func _around(p: Vector3, radius: float) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var c := _cell(p)
	var span := int(ceil(radius / lattice))
	for dx in range(-span, span + 1):
		for dz in range(-span, span + 1):
			var n := c + Vector2i(dx, dz)
			if main.has(n) and Vector2(nodes[n].x - p.x, nodes[n].z - p.z).length() < radius:
				out.append(n)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return (nodes[a] as Vector3).distance_squared_to(p) < (nodes[b] as Vector3).distance_squared_to(p))
	return out


## Every villager's strolls, walked ahead of time: `rounds` wander targets each, along the navmesh path with the
## villager's own capsule and pace. A path the body cannot follow is where a villager gets stuck.
func scan_villagers(rounds: int = 12) -> void:
	var map := world.get_world_3d().navigation_map
	var npc := CharacterBody3D.new()
	Mover.capsule(npc, 0.32, 1.8)
	Mover.setup(npc)
	world.add_child(npc)
	for c in world.find_children("*", "CharacterBody3D", true, false):
		if c != npc:
			npc.add_collision_exception_with(c)
	for v: Villager in world.find_children("*", "Villager", true, false):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(v.home) + 1
		var at := NavigationServer3D.map_get_closest_point(map, v.home)
		var name := "villager %s near %s" % [v.role if v.role != "" else v.who, str(v.home.snapped(Vector3.ONE))]
		if Vector2(at.x - v.home.x, at.z - v.home.z).length() > 3.0:
			_add("npc-stuck", v.home, name + ": home is off the navmesh")
			continue
		var hit := floor_at(at)
		if not hit.is_empty():
			at = hit["position"]
		for i in rounds:
			var target := Nav.wander(v, v.home, v.roam, rng)
			var path := NavigationServer3D.map_get_path(map, at, target, true)
			if path.size() < 2:
				continue
			routes += 1
			var ok := true
			var from := at
			for k in range(1, path.size()):
				if not _reach(npc, from, path[k], "", Villager.PACE, 0.6 if k < path.size() - 1 else 0.8):
					ok = false
					break
				from = npc.global_position
			if not ok:
				_add("npc-stuck", npc.global_position, name)
				break
			at = npc.global_position
	npc.queue_free()


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

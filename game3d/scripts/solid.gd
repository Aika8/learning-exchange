## Pattern: Factory (collision) — every collider of the world is made here, shaped like the thing it stands for:
## boxes for walls, cylinders for posts and trunks, a convex hull for a downloaded model, thin walls for fences.
## Bodies are never scaled (the shape is), so physics stays exact.
class_name Solid
extends RefCounted

const SOFT: Array[String] = ["fern", "grass", "shrub", "root"]  ## plants you walk through by design
const FENCE_H := 3.0

static var _hulls: Dictionary = {}  ## Mesh → PackedVector3Array (hull points, mesh space)
static var _banded: Dictionary = {}  ## [Mesh, scale] → outlines of its 0.6 m bands


static func _body(parent: Node3D, pos: Vector3, yaw: float) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = "Solid"
	b.position = pos
	b.rotation.y = yaw
	parent.add_child(b)
	return b


static func _shape(b: StaticBody3D, s: Shape3D, at: Vector3 = Vector3.ZERO) -> StaticBody3D:
	var cs := CollisionShape3D.new()
	cs.shape = s
	cs.position = at
	b.add_child(cs)
	return b


## A box whose centre is at `pos`.
static func box(parent: Node3D, size: Vector3, pos: Vector3, yaw: float = 0.0) -> StaticBody3D:
	var s := BoxShape3D.new()
	s.size = size
	return _shape(_body(parent, pos, yaw), s)


## An upright cylinder standing on `foot`.
static func post(parent: Node3D, radius: float, height: float, foot: Vector3) -> StaticBody3D:
	var s := CylinderShape3D.new()
	s.radius = radius
	s.height = height
	return _shape(_body(parent, foot + Vector3(0, height * 0.5, 0), 0.0), s)


## A person standing still.
static func person(parent: Node3D, foot: Vector3) -> StaticBody3D:
	var s := CapsuleShape3D.new()
	s.radius = 0.32
	s.height = 1.8
	return _shape(_body(parent, foot + Vector3(0, 0.9, 0), 0.0), s)


## A convex solid from points given in the parent's space (a tower, a tapering base).
static func convex(parent: Node3D, points: PackedVector3Array) -> StaticBody3D:
	var s := ConvexPolygonShape3D.new()
	s.points = points
	return _shape(_body(parent, Vector3.ZERO, 0.0), s)


## The exact triangles of a mesh (floors, the inside of the hall wall).
static func trimesh(parent: Node3D, mesh: Mesh, pos: Vector3 = Vector3.ZERO) -> StaticBody3D:
	var s := mesh.create_trimesh_shape()
	s.backface_collision = true
	return _shape(_body(parent, pos, 0.0), s)


## Collider for a downloaded model already placed under `parent`: one convex hull per mesh, with the model's
## position, turn and scale baked into the points. Trees and lamp posts get a trunk instead of a hull of the crown.
static func model(parent: Node3D, node: Node3D, name: String) -> StaticBody3D:
	for soft in SOFT:
		if name.contains(soft):
			return null
	var b := _body(parent, Vector3.ZERO, 0.0)
	var slender := name.contains("tree") or name.contains("street_lamp")  # a trunk or a post, not a hull of the crown
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		var to_parent := node.transform * _relative(node, mi)
		if slender:
			_bands(b, mi.mesh, _relative(node, mi), node)
			continue
		if not _hulls.has(mi.mesh):
			var hull := mi.mesh.create_convex_shape(true, false)
			_hulls[mi.mesh] = hull.points if hull != null else PackedVector3Array()
		var pts: PackedVector3Array = _hulls[mi.mesh]
		if pts.size() < 4:
			continue
		var s := ConvexPolygonShape3D.new()
		s.points = to_parent * pts
		_shape(b, s)
	node.set_meta("solid", b)
	return b


## Collider for a tall thin model (a tree, a lamp post with a bracket): the mesh is cut into 0.6 m bands up to
## 3 m above its foot and each band gets a prism over the outline of its own vertices, so the trunk is thin and a
## bracket sticks out only where it really is. Leaves are skipped.
static func _bands(b: StaticBody3D, mesh: Mesh, in_model: Transform3D, node: Node3D) -> void:
	var key := [mesh, snappedf(node.scale.y, 0.01)]
	if not _banded.has(key):
		var rows: Array[PackedVector2Array] = [PackedVector2Array(), PackedVector2Array(), PackedVector2Array(), PackedVector2Array(), PackedVector2Array()]
		for s in mesh.get_surface_count():
			var m := mesh.surface_get_material(s)
			if m != null and m.resource_name.contains("leaves"):
				continue
			var verts: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			for v in verts:
				var p := (in_model * v) * node.scale.y  # model space, metres
				var row := int(floor(p.y / 0.6))
				if p.y >= 0.0 and row < rows.size():
					rows[row].append(Vector2(p.x, p.z))
		for i in rows.size():
			rows[i] = Geometry2D.convex_hull(rows[i]) if rows[i].size() >= 3 else PackedVector2Array()
		_banded[key] = rows
	var bands: Array[PackedVector2Array] = _banded[key]
	var place := Transform3D(Basis(Vector3.UP, node.rotation.y), node.position)
	for i in bands.size():
		if bands[i].size() < 4:
			continue
		var pts := PackedVector3Array()
		for v in bands[i]:
			pts.append(place * Vector3(v.x, i * 0.6, v.y))
			pts.append(place * Vector3(v.x, (i + 1) * 0.6, v.y))
		var s := ConvexPolygonShape3D.new()
		s.points = pts
		_shape(b, s)


static func _relative(root: Node3D, child: Node3D) -> Transform3D:
	var t := Transform3D()
	var n: Node = child
	while n != root and n != null:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


## An invisible wall from `a` to `b` (feet level), so nobody walks off an edge.
static func fence(parent: Node3D, a: Vector3, b: Vector3, height: float = FENCE_H) -> StaticBody3D:
	var mid := (a + b) * 0.5
	var d := b - a
	var body := box(parent, Vector3(Vector2(d.x, d.z).length() + 0.2, height, 0.2), mid + Vector3(0, height * 0.5 - 0.5, 0), atan2(-d.z, d.x))
	body.name = "Fence"
	return body


## Fences round a set of walk areas (WorldProbe area dictionaries): the outline of their union, so the place where
## a pier meets the island stays open.
static func fence_areas(parent: Node3D, areas: Array[Dictionary], origin: Vector3 = Vector3.ZERO) -> int:
	var n := 0
	for area in areas:
		var ring := outline(area)
		for i in ring.size():
			var a := ring[i]
			var b := ring[(i + 1) % ring.size()]
			var open := false
			for other in areas:
				if other != area and WorldProbe.inside(other, (a + b) * 0.5, 0.25):
					open = true
			if not open:
				fence(parent, a - origin, b - origin)
				n += 1
	return n


## The edge of a walk area as a closed ring of points.
static func outline(area: Dictionary) -> PackedVector3Array:
	var ring := PackedVector3Array()
	if area["kind"] == "rect":
		var a: Vector3 = area["from"]
		var b: Vector3 = area["to"]
		var corners := [Vector3(a.x, a.y, a.z), Vector3(b.x, a.y, a.z), Vector3(b.x, a.y, b.z), Vector3(a.x, a.y, b.z)]
		for i in 4:
			var from: Vector3 = corners[i]
			var to: Vector3 = corners[(i + 1) % 4]
			var parts := int(ceil(from.distance_to(to) / 2.0))
			for k in parts:
				ring.append(from.lerp(to, float(k) / parts))
		return ring
	var c: Vector3 = area["centre"]
	var count := 96
	for i in count:
		var ang := TAU * i / count
		var r: float = float(area["radius"]) if area["kind"] == "circle" else Proc.cap_radius(area["radius"], area["seed"], ang)
		ring.append(c + Vector3(cos(ang), 0, sin(ang)) * r)
	return ring

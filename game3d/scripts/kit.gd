## Pattern: Builder — collects the parts of a building (boxes, quads, triangles) per material and commits them as
## one mesh with a surface per material, so a house of a hundred beams is a handful of draw calls, with LODs.
class_name Kit
extends RefCounted

var _tools: Dictionary = {}  ## Material → SurfaceTool
var _order: Array[Material] = []
static var _unit_box: BoxMesh


func _tool(m: Material) -> SurfaceTool:
	if not _tools.has(m):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[m] = st
		_order.append(m)
	return _tools[m]


## A box of `size` centred at `pos`, turned by `rot` (Euler, radians).
func box(m: Material, size: Vector3, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> void:
	if _unit_box == null:
		_unit_box = BoxMesh.new()
	_tool(m).append_from(_unit_box, 0, Transform3D(Basis.from_euler(rot).scaled_local(size), pos))


## Any ready mesh (a cylinder, a sphere).
func mesh(m: Material, src: Mesh, xform: Transform3D) -> void:
	_tool(m).append_from(src, 0, xform)


## A quad a→b→c→d (counter-clockwise seen from the front) with UVs in metres times `uv_scale`.
func quad(m: Material, a: Vector3, b: Vector3, c: Vector3, d: Vector3, uv_scale: float = 1.0) -> void:
	var st := _tool(m)
	var n := (b - a).cross(d - a).normalized()
	var w := a.distance_to(b) * uv_scale
	var h := a.distance_to(d) * uv_scale
	var t := (b - a).normalized()
	for v: Array in [[a, Vector2(0, h)], [c, Vector2(w, 0)], [b, Vector2(w, h)], [a, Vector2(0, h)], [d, Vector2(0, 0)], [c, Vector2(w, 0)]]:  # Godot fronts are clockwise
		st.set_normal(n)
		st.set_tangent(Plane(t, 1.0))
		st.set_uv(v[1])
		st.add_vertex(v[0])


func tri(m: Material, a: Vector3, b: Vector3, c: Vector3) -> void:
	var st := _tool(m)
	var n := (b - a).cross(c - a).normalized() * -1.0
	for v: Vector3 in [a, b, c]:
		st.set_normal(n)
		st.set_uv(Vector2(v.z, -v.y))
		st.add_vertex(v)


func commit(name: String = "Mesh") -> MeshInstance3D:
	var im := ImporterMesh.new()
	for m in _order:
		var st: SurfaceTool = _tools[m]
		st.index()
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, st.commit_to_arrays(), [], {}, m)
	im.generate_lods(25.0, 60.0, [])
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = im.get_mesh()
	return mi

## Pattern: Builder — the picture inside one comic frame: the game's own people in their costumes, posed, in a small
## world of their own with a camera for the shot and the island's ink effect. Drawn for a few frames, then frozen.
## See docs/adr/0027-game3d-talk-as-comic-pages.md
class_name ComicShot
extends RefCounted

## pose → bone → turn in radians round the body's x (forward/back), y, z (sideways); people built in code only
const POSE := {
	"stand": {},
	"talk": {"upperarm_r": Vector3(-0.55, 0, 0), "lowerarm_r": Vector3(-1.35, 0, 0), "head": Vector3(0.06, 0, 0)},
	"point": {"upperarm_r": Vector3(-1.35, 0, -0.1), "spine_02": Vector3(0.08, 0, 0)},
	"think": {"upperarm_r": Vector3(-0.5, 0, 0.25), "lowerarm_r": Vector3(-2.2, 0, 0), "head": Vector3(0.12, 0, 0.14)},
	"shrug": {"upperarm_r": Vector3(0, 0, 0.45), "lowerarm_r": Vector3(-1.2, 0, 0), "upperarm_l": Vector3(0, 0, -0.45),
		"lowerarm_l": Vector3(-1.2, 0, 0), "head": Vector3(0, 0, -0.12)},
	"bow": {"spine_01": Vector3(0.3, 0, 0), "head": Vector3(0.2, 0, 0)},
}

var viewport: SubViewport
var camera: Camera3D
var heads: Dictionary = {}  ## cast id → Vector3, the head in the shot's world


static func build(panel: Dictionary, cast: Dictionary, backdrop: Dictionary, size: Vector2i) -> ComicShot:
	var s := ComicShot.new()
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.size = size * 2  # drawn twice as large and shown smaller: smooth edges without MSAA
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	s.viewport = vp
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(str(backdrop.get("sky", "f0dcb4")))
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.75
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.7, 0.6, 0)
	sun.light_energy = 1.1
	vp.add_child(sun)
	var ground := PlaneMesh.new()
	ground.size = Vector2(80, 80)
	vp.add_child(Proc.mesh_node(ground, Proc.mat(Color(str(backdrop.get("ground", "7fb069"))))))
	var wall := QuadMesh.new()  # a backdrop with depth, so the ink line finds every silhouette
	wall.size = Vector2(400, 200)
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.albedo_color = env.background_color
	vp.add_child(Proc.mesh_node(wall, paint, Vector3(0, 60, -5)))
	var who: Array = panel.get("cast", [])
	var shot: String = panel.get("shot", "two")
	for i in who.size():
		var c: Dictionary = cast[who[i]]
		var f := Proc.figure(Color(str(c.get("coat", "8a6a4a"))), Color("2a3550"), str(c.get("who", "")), str(c.get("role", "")))
		var side := -1.0 if i == 0 else 1.0
		if who.size() == 1:
			f.rotation.y = 0.35
		else:
			f.position.x = side * (0.62 if shot != "wide" else 0.9)
			f.rotation.y = -side * 1.05  # turned to each other and a little to the reader
		vp.add_child(f)
		pose(f, str(panel.get("pose", {}).get(who[i], "stand")))
		s.heads[who[i]] = f.position + Vector3(0, head_height(f), 0)
	var cam := Camera3D.new()
	var top := 0.0
	var mid := Vector3.ZERO
	for h: Vector3 in s.heads.values():
		top = maxf(top, h.y)
		mid += h / s.heads.size()
	var aspect := float(size.x) / float(size.y)
	match shot:
		"close":
			cam.fov = 30
			cam.position = mid + Vector3(0.35, 0.02, maxf(2.0, 0.42 / (tan(deg_to_rad(15.0)) * aspect)))
			cam.look_at_from_position(cam.position, mid + Vector3(0, 0.1, 0))
		"low":
			cam.fov = 42
			cam.position = Vector3(0.7, 0.5, maxf(2.1, 0.75 / (tan(deg_to_rad(21.0)) * aspect)))
			cam.look_at_from_position(cam.position, mid + Vector3(0, 0.15, 0))
		"wide":
			cam.fov = 38
			cam.position = Vector3(0.6, 1.7, maxf(5.4, 1.9 / (tan(deg_to_rad(19.0)) * aspect)))
			cam.look_at_from_position(cam.position, Vector3(0, 1.45, 0))
		_:
			cam.fov = 34
			cam.position = Vector3(0.2, top * 0.9, maxf(3.3, 1.3 / (tan(deg_to_rad(17.0)) * aspect)))
			cam.look_at_from_position(cam.position, Vector3(0, top * 0.98, 0))
	vp.add_child(cam)
	s.camera = cam
	vp.add_child(Session.ink_copy(4.0))
	return s


## Where `who`'s head is in the frame, 0..1 from the top left.
func head(who: String) -> Vector2:
	if not heads.has(who) or not camera.is_inside_tree():
		return Vector2(0.5, 0.5)
	return camera.unproject_position(heads[who]) / Vector2(viewport.size)


func freeze() -> void:
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


static func head_height(figure: Node3D) -> float:
	var found := figure.find_children("*", "Skeleton3D", true, false)
	if not found.is_empty():
		var sk: Skeleton3D = found[0]
		var i := sk.find_bone("head")
		if i >= 0 and figure.has_meta("stand_in"):
			return sk.get_bone_global_rest(i).origin.y + 0.1
	return 1.62 if not figure.has_meta("stand_in") else 1.5


## Turns a few bones of a person built in code (their rest rotations are zero); other figures stand as they are.
static func pose(figure: Node3D, name: String) -> bool:
	var found := figure.find_children("*", "Skeleton3D", true, false)
	if found.is_empty() or not figure.has_meta("stand_in"):
		return false
	var sk: Skeleton3D = found[0]
	for bone: String in POSE.get(name, {}):
		var i := sk.find_bone(bone)
		if i >= 0:
			sk.set_bone_pose_rotation(i, Quaternion.from_euler(POSE[name][bone]))
	return true

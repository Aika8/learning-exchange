## Navigation for the villagers: bakes a navmesh from the static colliders of a place (ground, decks, walls,
## fences, props), so people walk round buildings and each other instead of through them.
class_name Nav
extends RefCounted


## Bakes the walkable ground of `areas` under `root` and adds the region to `root`.
static func bake(root: Node3D, areas: Array[Dictionary]) -> NavigationRegion3D:
	var nm := NavigationMesh.new()
	nm.agent_radius = 0.5
	nm.agent_height = 1.75
	nm.agent_max_climb = 0.5
	nm.agent_max_slope = 40.0
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	nm.region_min_size = 40.0
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	var box := AABB()
	for i in areas.size():
		var a := areas[i]
		var part: AABB
		if a.has("centre"):
			var r := float(a["radius"]) * 1.2
			part = AABB((a["centre"] as Vector3) - Vector3(r, 0, r), Vector3(r * 2, 0, r * 2))
		else:
			part = AABB(a["from"], (a["to"] as Vector3) - (a["from"] as Vector3)).abs()
		box = part if i == 0 else box.merge(part)
	box.position.y -= 1.0  # rooftops and the cliffs under the cap are not for walking
	box.size.y = 3.4
	nm.filter_baking_aabb = box
	var src := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, root)
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	var region := NavigationRegion3D.new()
	region.name = "Nav"
	region.navigation_mesh = nm
	root.add_child(region)
	return region


## A reachable point on the navmesh within `roam` metres of `home`.
static func wander(body: Node3D, home: Vector3, roam: float, rng: RandomNumberGenerator) -> Vector3:
	var map := body.get_world_3d().navigation_map
	var a := rng.randf() * TAU
	var want := home + Vector3(cos(a), 0, sin(a)) * roam * sqrt(rng.randf())
	return NavigationServer3D.map_get_closest_point(map, want)


static func ready(body: Node3D) -> bool:
	return NavigationServer3D.map_get_iteration_id(body.get_world_3d().navigation_map) > 0

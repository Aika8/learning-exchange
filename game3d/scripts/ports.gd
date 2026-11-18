## Pattern: Registry — every island as the ship sees it: where the berth is, how big the rock, which way the bow
## points on leaving, and the name on the chart. A new island is a row here.
## See docs/adr/0032-game3d-free-flight-between-islands.md
class_name Ports
extends RefCounted

const WORLD_CENTRE := Vector3(0, 0, 0)
const WORLD_RADIUS := 620.0  ## the farthest berth lies about 420 m out
const ORDER: Array[String] = ["harbour", "silk", "amber", "shorts", "crypto", "index"]


## id → {name: i18n key, berth: where the ship lies moored, centre: the island's top, radius, depth, away: heading
## (radians) that leaves the island behind}.
static func all() -> Dictionary:
	return {
		"harbour": {"name": "HARBOUR_TITLE", "berth": Archipelago.PIER_END + Vector3(4, 1.2, 5.5), "centre": Archipelago.HARBOUR,
			"radius": Archipelago.HARBOUR_RADIUS, "depth": 42.0},
		"silk": {"name": "SILK_TITLE", "berth": Archipelago.SILK_DOCK + Vector3(-4, 1.2, 4), "centre": Archipelago.SILK,
			"radius": Archipelago.SILK_RADIUS, "depth": 34.0},
		"amber": {"name": "AMB_TITLE", "berth": AmberCliff.DOCK + Vector3(0, 1.2, 0), "centre": AmberCliff.AT, "radius": AmberCliff.RADIUS, "depth": 58.0},
		"shorts": {"name": "SHORTS_TITLE", "berth": ShortIsle.DOCK + Vector3(0, 1.2, 0), "centre": ShortIsle.AT, "radius": ShortIsle.RADIUS, "depth": 46.0},
		"crypto": {"name": "CRYPTO_TITLE", "berth": CryptoIsle.DOCK + Vector3(0, 1.2, 0), "centre": CryptoIsle.AT, "radius": CryptoIsle.RADIUS, "depth": 44.0},
		"index": {"name": "INDEX_TITLE", "berth": IndexIsle.DOCK + Vector3(0, 1.2, 0), "centre": IndexIsle.AT, "radius": IndexIsle.RADIUS, "depth": 40.0},
	}


static func has(id: String) -> bool:
	return id in ORDER


static func berth(id: String) -> Vector3:
	return all()[id]["berth"]


## The heading that takes a ship at `id`'s berth straight away from the island.
static func away(id: String) -> float:
	var p: Dictionary = all()[id]
	var out: Vector3 = (p["berth"] as Vector3) - (p["centre"] as Vector3)
	return atan2(-out.x, -out.z)


## The islands as solid cylinders for `FlightModel`.
static func rocks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Dictionary in all().values():
		out.append({"centre": p["centre"], "radius": p["radius"], "depth": p["depth"]})
	return out


## A model at the berth of `from`, bow pointing away, sail half up, with every island in its way.
static func cast_off(from: String) -> FlightModel:
	var m := FlightModel.new()
	m.position = berth(from)
	m.yaw = away(from)
	m.trim = 0.5
	m.centre = WORLD_CENTRE
	m.world_radius = WORLD_RADIUS
	m.islands = rocks()
	return m


## The port whose berth the ship can moor at now, or "".
static func mooring(m: FlightModel) -> String:
	for id: String in ORDER:
		if m.can_moor(berth(id)):
			return id
	return ""


## A helmsman who steers by the compass alone, for the screenshot run and the tests: wheel, sail and climb (as
## `FlightModel.step` takes them) that bring `m` to the berth of `to`. He flies high to a point off the pier on its
## seaward side, and only there comes down and takes in sail — never over the island that lies in the way.
static func steer(m: FlightModel, to: String) -> Vector3:
	var p: Dictionary = all()[to]
	var goal: Vector3 = p["berth"]
	var centre: Vector3 = p["centre"]
	var out := Vector3(goal.x - centre.x, 0, goal.z - centre.z).normalized()
	var seaward := Vector3(m.position.x - centre.x, 0, m.position.z - centre.z).dot(out) > float(p["radius"]) + FlightModel.HULL + 4.0
	var aside := (Vector3(m.position.x - goal.x, 0, m.position.z - goal.z) - out * Vector3(m.position.x - goal.x, 0, m.position.z - goal.z).dot(out)).length()
	var landing := seaward and aside < 45.0 and m.distance_to(goal) < 170.0
	var aim := goal if landing else goal + out * 110.0
	var near := landing and m.distance_to(goal) < 70.0
	var sail := 1.0
	if near:
		sail = -1.0 if m.trim > 0.3 else 0.0
	elif landing or m.distance_to(aim) < 60.0:
		sail = -1.0 if m.trim > 0.6 else 0.0
	var height := goal.y + (0.0 if landing else 55.0)
	return Vector3(clampf(m.bearing_to(aim) * 2.0, -1.0, 1.0), sail, clampf((height - m.position.y) * 0.3, -1.0, 1.0))

## The little round chart of the voyage HUD: the world from above, north (−z) up — every island as a dot the size of
## its rock, the marked one ringed in brass, the ship as an arrow, the edge of the world as the rim.
## See docs/adr/0032-game3d-free-flight-between-islands.md
class_name FlightChart
extends Control

var _ship := Vector2.ZERO
var _yaw := 0.0
var _to := ""


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## A place in the world as a point on a chart of `side` pixels.
static func place(world: Vector3, side: float) -> Vector2:
	var r := side * 0.5 - 6.0
	return Vector2(side * 0.5, side * 0.5) + Vector2(world.x - Ports.WORLD_CENTRE.x, world.z - Ports.WORLD_CENTRE.z) / Ports.WORLD_RADIUS * r


func show_from(m: FlightModel, destination: String) -> void:
	_ship = place(m.position, size.x)
	_yaw = m.yaw
	_to = destination
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	draw_circle(c, size.x * 0.5, Hud.PANEL)
	draw_arc(c, size.x * 0.5 - 6.0, 0, TAU, 64, Hud.LINE, 2.0, true)
	var ports := Ports.all()
	for id: String in Ports.ORDER:
		var p: Dictionary = ports[id]
		var at := place(p["centre"], size.x)
		draw_circle(at, maxf(4.0, float(p["radius"]) / Ports.WORLD_RADIUS * (size.x * 0.5 - 6.0)), Hud.BRASS if id == _to else Hud.TEXT)
		if id == _to:
			draw_arc(at, 11.0, 0, TAU, 24, Hud.BRASS, 2.0, true)
			draw_dashed_line(_ship, at, Hud.BRASS, 1.0, 5.0)
	var fwd := Vector2(-sin(_yaw), -cos(_yaw))
	var side := Vector2(fwd.y, -fwd.x)
	draw_colored_polygon(PackedVector2Array([_ship + fwd * 9.0, _ship - fwd * 5.0 + side * 5.0, _ship - fwd * 5.0 - side * 5.0]), Color("9fd3e6"))

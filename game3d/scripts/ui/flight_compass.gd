## The compass strip of the voyage HUD: a mark for every island where it lies from the bow (the middle of the strip
## is dead ahead, the ends are abeam), the marked destination in brass with its distance, and an arrow for the wind.
## See docs/adr/0032-game3d-free-flight-between-islands.md
class_name FlightCompass
extends Control

const SPAN := PI * 0.75  ## the strip shows this far to either side of the bow

var _marks: Array = []  ## [x 0..1, name, distance, is the destination, astern]
var _wind_x := 0.5
var _font: Font


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = Hud.serif()


## Where on the strip a bearing falls: 0.5 dead ahead, 0 hard to port… clamped at the ends when astern.
static func place(bearing: float) -> float:
	return clampf(0.5 - bearing / (2.0 * SPAN), 0.0, 1.0)


func show_from(m: FlightModel, destination: String, wind: Vector3) -> void:
	_marks.clear()
	var ports := Ports.all()
	for id: String in Ports.ORDER:
		var berth: Vector3 = ports[id]["berth"]
		var b := m.bearing_to(berth)
		_marks.append([place(b), tr(ports[id]["name"]), m.distance_to(berth), id == destination, absf(b) > SPAN])
	_wind_x = place(m.bearing_to(m.position + Vector3(wind.x, 0, wind.z) * 100.0))
	queue_redraw()


func _draw() -> void:
	draw_style_box(Hud.box(Hud.PANEL, Hud.LINE, 1, 8), Rect2(Vector2.ZERO, size))
	for i in 13:  # ticks every 22.5°
		var x := size.x * i / 12.0
		draw_line(Vector2(x, size.y - (12.0 if i % 2 == 0 else 7.0)), Vector2(x, size.y - 2), Hud.MUTED, 1.0)
	draw_line(Vector2(size.x * 0.5, 2), Vector2(size.x * 0.5, 12), Hud.TEXT, 2.0)
	var wx := 8.0 + (size.x - 16.0) * _wind_x  # the wind: a little pennant where it blows to
	draw_colored_polygon(PackedVector2Array([Vector2(wx - 6, size.y - 14), Vector2(wx + 6, size.y - 14), Vector2(wx, size.y - 4)]), Color("9fd3e6"))
	for mark: Array in _marks:
		var x := 8.0 + (size.x - 16.0) * float(mark[0])
		var colour := Hud.BRASS if mark[3] else (Hud.MUTED if mark[4] else Hud.TEXT)
		draw_circle(Vector2(x, 22), 6.0 if mark[3] else 4.0, colour)
		if mark[3] or (float(mark[2]) < 150.0 and not mark[4]):  # the destination always; others only near and not astern
			var text := "%s · %d" % [mark[1], int(mark[2])]
			var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			draw_string(_font, Vector2(clampf(x - w * 0.5, 4, size.x - w - 4), 46), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, colour)

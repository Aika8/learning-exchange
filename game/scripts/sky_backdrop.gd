## Placeholder art: dusk sky, floating islands and the Wind Exchange windmill, drawn from simple shapes.
class_name SkyBackdrop
extends Control

var show_exchange := true
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var s := size
	var bands := 24
	for i in bands:
		var c := UI.SKY_TOP.lerp(UI.SKY_LOW, float(i) / bands)
		draw_rect(Rect2(0, s.y * i / bands, s.x, s.y / bands + 1), c)
	for k in 5:
		var x := fmod(k * 290.0 + _t * (8 + k * 3), s.x + 200) - 100
		draw_circle(Vector2(x, 90 + k * 37), 26 + k * 4, Color(1, 1, 1, 0.12))
	_island(Vector2(s.x * 0.18, s.y * 0.62), 120, sin(_t * 0.7) * 4)
	_island(Vector2(s.x * 0.82, s.y * 0.48), 90, sin(_t * 0.9 + 1) * 4)
	var main := Vector2(s.x * 0.5, s.y * 0.72 + sin(_t * 0.5) * 3)
	_island(main, 220, 0)
	if show_exchange:
		_windmill(main + Vector2(0, -40))


func _island(c: Vector2, w: float, dy: float) -> void:
	var p := c + Vector2(0, dy)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-w, 0), p + Vector2(w, 0), p + Vector2(w * 0.3, w * 0.55),
		p + Vector2(-w * 0.2, w * 0.7)]), UI.ROCK)
	draw_rect(Rect2(p + Vector2(-w, -10), Vector2(w * 2, 12)), UI.ISLAND)
	draw_circle(p + Vector2(-w * 0.1, w * 0.75), 7, Color("7fd6e0"))


func _windmill(base: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([base + Vector2(-38, 30), base + Vector2(38, 30), base + Vector2(22, -110),
		base + Vector2(-22, -110)]), Color("e8dcc0"))
	draw_rect(Rect2(base + Vector2(-10, 0), Vector2(20, 30)), UI.BG)
	var hub := base + Vector2(0, -110)
	for i in 4:
		var a := _t * 0.8 + i * PI / 2
		var tip := hub + Vector2(cos(a), sin(a)) * 95
		var side := Vector2(-sin(a), cos(a)) * 12
		draw_colored_polygon(PackedVector2Array([hub, tip + side, tip - side * 0.2]), UI.BRASS)
	draw_circle(hub, 8, UI.BG)

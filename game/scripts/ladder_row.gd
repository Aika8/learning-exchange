## One price level of the Ladder: depth bar + price / quantity / orders. Drawn, not composed, to stay cheap at 10 Hz.
class_name LadderRow
extends Control

const H := 22.0

var price_text := ""
var qty_text := ""
var orders_text := ""
var fill := 0.0  ## 0..1 of the widest level shown
var color := UI.BID


func _init() -> void:
	custom_minimum_size = Vector2(0, H)


func set_level(p: String, q: String, o: String, f: float, c: Color) -> void:
	price_text = p
	qty_text = q
	orders_text = o
	fill = f
	color = c
	queue_redraw()


func _draw() -> void:
	var w := size.x
	draw_rect(Rect2(w * (1.0 - fill), 2, w * fill, H - 4), Color(color, 0.22))
	if price_text.is_empty():
		return
	var font := get_theme_default_font()
	var fs := 16
	draw_string(font, Vector2(8, 16), price_text, HORIZONTAL_ALIGNMENT_LEFT, w * 0.4, fs, color)
	draw_string(font, Vector2(w * 0.40, 16), qty_text, HORIZONTAL_ALIGNMENT_RIGHT, w * 0.3, fs, UI.TEXT)
	draw_string(font, Vector2(w * 0.72, 16), orders_text, HORIZONTAL_ALIGNMENT_RIGHT, w * 0.25, fs, UI.MUTED)

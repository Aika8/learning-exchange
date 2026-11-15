## HUD palette and widget helpers (docs/design/game3d-style.md). Labels hold translation keys (ADR-0014).
class_name Hud
extends RefCounted

const INK := Color("141a28")
const PANEL := Color(0.106, 0.133, 0.196, 0.86)
const LINE := Color("3a4766")
const BRASS := Color("d9a441")
const TEXT := Color("f5ecd8")
const MUTED := Color("a9b3c7")
const BID := Color("5fb98a")
const ASK := Color("e0705f")


static func theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 18
	for c: String in ["Label", "Button", "LineEdit", "CheckBox"]:
		t.set_color("font_color", c, TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_stylebox("normal", "Button", box(Color(0.15, 0.19, 0.28, 0.9), BRASS, 1, 10))
	t.set_stylebox("hover", "Button", box(Color(0.22, 0.27, 0.38, 0.95), BRASS, 2, 10))
	t.set_stylebox("pressed", "Button", box(BRASS, BRASS, 2, 10))
	t.set_stylebox("disabled", "Button", box(Color(0.15, 0.19, 0.28, 0.5), LINE, 1, 10))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), BRASS.lightened(0.3), 2, 10))
	t.set_stylebox("normal", "LineEdit", box(Color(0.08, 0.1, 0.16, 0.9), LINE, 1, 8))
	t.set_stylebox("focus", "LineEdit", box(Color(0, 0, 0, 0), BRASS, 1, 8))
	t.set_stylebox("panel", "PanelContainer", box(PANEL, LINE, 1, 14))
	return t


static func box(bg: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(10)
	s.shadow_color = Color(0, 0, 0, 0.25)
	s.shadow_size = 6
	return s


static func text(key: String, size: int = 18, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = key
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l


## Lore caption: small and muted, always under the real term (ADR-0012).
static func lore(key: String) -> Label:
	var l := text(key, 13, MUTED)
	return l


static func button(key: String) -> Button:
	var b := Button.new()
	b.text = key
	return b


static func panel(child: Control) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_child(child)
	return p


static func lang_switch() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_child(text("LANG_LABEL", 15, MUTED))
	for code: String in ["ru", "en"]:
		var b := LangButton.new(code)
		h.add_child(b)
	return h


## Display serif for titles (system Georgia / Times / Noto Serif; falls back to the default font).
static func serif() -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Georgia", "Times New Roman", "Noto Serif", "DejaVu Serif"])
	f.font_weight = 600
	return f


## Monospace digits for the board so columns line up.
static func mono() -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Menlo", "SF Mono", "Consolas", "DejaVu Sans Mono", "monospace"])
	return f

## One palette and small widget helpers so every scene looks the same (placeholder art, ADR-0011).
class_name UI
extends RefCounted

const BG := Color("1b2232")
const PANEL := Color("263049")
const PANEL_LINE := Color("3a4766")
const BRASS := Color("d9a441")
const TEXT := Color("efe6d2")
const MUTED := Color("97a1b6")
const BID := Color("5fb98a")
const ASK := Color("e0705f")
const SKY_TOP := Color("2b3a5c")
const SKY_LOW := Color("c98b5a")
const ISLAND := Color("4a5a46")
const ROCK := Color("6b5a4a")


static func theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 17
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_stylebox("normal", "Button", box(PANEL, BRASS, 1))
	t.set_stylebox("hover", "Button", box(PANEL_LINE, BRASS, 1))
	t.set_stylebox("pressed", "Button", box(BRASS.darkened(0.35), BRASS, 2))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), BRASS, 2))
	t.set_stylebox("normal", "LineEdit", box(BG, PANEL_LINE, 1))
	t.set_stylebox("panel", "PanelContainer", box(PANEL, PANEL_LINE, 1))
	return t


static func box(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(6)
	s.set_content_margin_all(8)
	return s


## Label whose text is a translation key (Godot re-translates it on locale change by itself).
static func label(key: String, size: int = 17, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = key
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## Secondary lore caption: smaller and muted (ADR-0012 — the real term always leads).
static func lore(key: String) -> Label:
	var l := label(key, 13, MUTED)
	l.add_theme_font_size_override("font_size", 13)
	return l


static func button(key: String) -> Button:
	var b := Button.new()
	b.text = key
	return b


static func panel(child: Control) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_child(child)
	return p


## Language switch shown on every screen: «Русский | English», switches without restart.
static func lang_switch() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_child(label("LANG_LABEL", 15, MUTED))
	for code: String in ["ru", "en"]:
		h.add_child(LangButton.new(code))
	return h

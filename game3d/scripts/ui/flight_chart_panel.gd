## The chart at the ship: where to? A button for every other island with its distance, "fly free", "stay".
## Choosing only marks the island for the compass: the player may moor anywhere.
## See docs/adr/0032-game3d-free-flight-between-islands.md
class_name FlightChartPanel
extends PanelContainer

signal chosen(destination: String)  ## an island id, "" for flying free, STAY for not sailing

const STAY := "-"

var _list: VBoxContainer


func _init() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(460, 0)
	var title := Hud.text("VOYAGE_CHART_TITLE", 28, Hud.BRASS)
	title.add_theme_font_override("font", Hud.serif())
	box.add_child(title)
	box.add_child(Hud.lore("VOYAGE_CHART_LORE"))
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	box.add_child(_list)
	var note := Hud.text("VOYAGE_CHART_NOTE", 14, Hud.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(note)
	add_child(box)


## Shows the chart for a ship lying at `from`.
func offer(from: String) -> void:
	for c in _list.get_children():
		c.queue_free()
	var ports := Ports.all()
	var here := Ports.berth(from) if Ports.has(from) else Vector3.ZERO
	for id: String in Ports.ORDER:
		if id == from:
			continue
		var b := Button.new()
		b.name = "To_" + id
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.text = tr("VOYAGE_CHART_ROW") % [tr(ports[id]["name"]), str(int(Vector2(here.x, here.z).distance_to(Vector2(ports[id]["berth"].x, ports[id]["berth"].z))))]
		b.pressed.connect(func() -> void: chosen.emit(id))
		_list.add_child(b)
	var free := Hud.button("VOYAGE_CHART_FREE")
	free.name = "Free"
	free.pressed.connect(func() -> void: chosen.emit(""))
	_list.add_child(free)
	var stay := Hud.button("VOYAGE_CHART_STAY")
	stay.name = "Stay"
	stay.pressed.connect(func() -> void: chosen.emit(STAY))
	_list.add_child(stay)
	visible = true

## Pattern: value objects in a table — the look of an island is data: one small set of numbers per island, read by the
## ink post-effect, the sun and the wind that restyles the captain. See docs/adr/0025-…md and docs/adr/0026-game3d-island-techniques.md
class_name IslandStyle
extends RefCounted

const HOME := "harbour"

## How the picture is made (ADR-0026); the number is what `shaders/ink.gdshader` branches on.
const TECHNIQUES := {"ink": 0, "dye": 1}
const INK_RAMP: Array[Color] = [Color("12162e"), Color("2a6b8c"), Color("db8590"), Color("f7edd6")]

## Spark Harbour is the look of ADR-0024 as approved. Every other island has a technique of its own.
const TABLE := {
	"harbour": {
		"technique": "ink",  # a dark pen line over flat colour
		"ramp": INK_RAMP,  # unused by ink
		"ink": Color(0.13, 0.1, 0.09),  # warm sepia-black, a brass town
		"width": 1.3,  # line width in pixels at 1080p
		"tint": Color(1.0, 1.0, 1.0),  # multiplies the colours under the line
		"paper": Color(0.93, 0.87, 0.75),  # the sheet of the engraving
		"hatch_turn": 0.0,  # radians the hatching is turned by
		"hatch_gap": 9.0,  # pixels between strokes at 1080p
		"sun": Color("ffe1b0"),
		"sun_energy": 1.35,
		"accent": Color("ffcf6e"),  # the colour of this island's wind
	},
	"silk": {
		"technique": "dye",  # printed silk: four dye baths, a light resist line, a weave
		"ramp": [Color("1b2057"), Color("2f7f96"), Color("e58f9c"), Color("fbf1dc")],  # indigo, teal, rose, cream
		"ink": Color("fff6e6"),  # the wax line stays the colour of the cloth
		"width": 1.7,
		"tint": Color(1.0, 1.0, 1.0),
		"paper": Color("f6ecd8"),
		"hatch_turn": 0.0,
		"hatch_gap": 9.0,
		"sun": Color("ffeede"),
		"sun_energy": 1.25,
		"accent": Color("c9a4ff"),
	},
}


## The style of an island; an island without a row is drawn like home.
static func of(island_id: String) -> Dictionary:
	return TABLE.get(island_id, TABLE[HOME])

## Pattern: value objects in a table — the look of an island is data: one small set of numbers per island, read by the
## ink post-effect, the sun and the wind that restyles the captain. See docs/adr/0025-…md and docs/adr/0026-game3d-island-techniques.md
class_name IslandStyle
extends RefCounted

const HOME := "harbour"

## How the picture is made (ADR-0026); the number is what `shaders/ink.gdshader` branches on.
const TECHNIQUES := {"ink": 0, "katazome": 1, "aquarelle": 2}
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
		"technique": "katazome",  # a Japanese stencil-resist print (sheets 27, 28; ADR-0029)
		"ramp": [Color("1f2f5a"), Color("1f2f5a"), Color("b5523b"), Color("efe6d2")],  # indigo, —, the rust accent, cream
		"ink": Color("efe6d2"),  # the line is light; on cream the effect turns it indigo
		"width": 1.6,
		"tint": Color(1.0, 1.0, 1.0),
		"paper": Color("efe6d2"),
		"hatch_turn": 0.0,
		"hatch_gap": 9.0,
		"sun": Color("ffeede"),
		"sun_energy": 1.25,
		"accent": Color("e58a6a"),  # the wind of the dye works: rust
	},
	"amber": {
		"technique": "aquarelle",  # pen and watercolour, a French travel sketchbook (sheets 29–34; ADR-0029)
		"ramp": [Color("5f6282"), Color("ffffff"), Color("ffffff"), Color("a8ded9")],  # the shade wash, —, —, the sky's azure
		"ink": Color("3a332e"),  # a warm grey pen
		"width": 1.15,
		"tint": Color(1.0, 1.0, 1.0),
		"paper": Color("fbf7ee"),
		"hatch_turn": 0.0,
		"hatch_gap": 6.0,
		"sun": Color("fff3d6"),
		"sun_energy": 1.5,
		"accent": Color("ffb347"),
	},
}


## The style of an island; an island without a row is drawn like home.
static func of(island_id: String) -> Dictionary:
	return TABLE.get(island_id, TABLE[HOME])

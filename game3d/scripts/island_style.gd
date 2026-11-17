## Pattern: value objects in a table — the look of an island is data: one small set of numbers per island, read by the
## ink post-effect, the sun and the wind that restyles the captain. See docs/adr/0025-game3d-island-style-variants-and-attunement.md
class_name IslandStyle
extends RefCounted

const HOME := "harbour"

## Spark Harbour is the look of ADR-0024 as approved. The others differ from it only a little (a test bounds it).
const TABLE := {
	"harbour": {
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
		"ink": Color(0.11, 0.09, 0.2),  # indigo, the dye of the silk racks
		"width": 1.05,  # a finer line, like thread
		"tint": Color(0.96, 0.97, 1.04),  # a little cooler
		"paper": Color(0.92, 0.88, 0.84),
		"hatch_turn": 0.35,  # strokes lean the other way
		"hatch_gap": 7.0,  # and lie closer, like a weave
		"sun": Color("ffeede"),
		"sun_energy": 1.25,
		"accent": Color("c9a4ff"),
	},
}


## The style of an island; an island without a row is drawn like home.
static func of(island_id: String) -> Dictionary:
	return TABLE.get(island_id, TABLE[HOME])

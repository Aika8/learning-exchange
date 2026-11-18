## Pattern: value objects in a table — the look of an island is data: one small set of numbers per island, read by the
## ink post-effect, the sun and the wind that restyles the captain. See docs/adr/0025-…md and docs/adr/0026-game3d-island-techniques.md
class_name IslandStyle
extends RefCounted

const HOME := "harbour"

## How the picture is made (ADR-0026); the number is what `shaders/ink.gdshader` branches on.
const TECHNIQUES := {"ink": 0, "katazome": 1, "aquarelle": 2, "noir": 3, "pixel": 4, "toy": 5, "deco": 6}
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
		"technique": "katazome",  # a Japanese stencil-resist print, in the looser manner of sheet 28 (ADR-0029)
		"ramp": [Color("4f6a94"), Color("a9bcd2"), Color("b5523b"), Color("c79a63")],  # mid blue, pale blue, rust, ochre
		"ink": Color("1f2f5a"),  # the deep indigo: the darkest tone and the line
		"width": 1.2,
		"tint": Color(1.0, 1.0, 1.0),
		"paper": Color("efe6d2"),  # cream: the lightest tone and the sky
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
	"shorts": {
		"technique": "noir",  # black, white and one red; fog and slanted rain (sheets 35–40; ADR-0030)
		"ramp": [Color("000000"), Color("000000"), Color("c4302b"), Color("000000")],  # —, —, the signal red, —
		"ink": Color("0d0d10"),
		"width": 1.4,
		"tint": Color(1.0, 1.0, 1.0),
		"paper": Color("f4efe6"),
		"hatch_turn": 0.0,
		"hatch_gap": 9.0,
		"sun": Color("ffffff"),  # hard light
		"sun_energy": 1.7,
		"accent": Color("e0453f"),
	},
	"crypto": {
		"technique": "pixel",  # synthwave pixel art: big pixels, twelve colours, a striped sun, a ground grid (sheets 41–46; ADR-0031)
		"ramp": [Color("1b1035"), Color("5b2a86"), Color("ff2e88"), Color("00f0ff")],  # night, violet, neon pink, neon cyan — the whole palette is in the shader
		"ink": Color("1b1035"),
		"width": 1.0,
		"tint": Color(1.0, 1.0, 1.0),
		"paper": Color("1b1035"),
		"hatch_turn": 0.0,
		"hatch_gap": 9.0,
		"sun": Color("b9a6ff"),  # a violet dusk
		"sun_energy": 0.85,
		"accent": Color("00f0ff"),
	},
	"index": {
		"technique": "toy",  # a pastel toy town: gloss, soft seams, tilt-shift at the rims (sheets 47–51; ADR-0033)
		"ramp": [Color("c9b8e8"), Color("1a5b5c"), Color("fff3e0"), Color("bfe3ea")],  # the shade's lavender, the seam's teal, sky low, sky high
		"ink": Color("1a5b5c"),
		"width": 1.2,
		"tint": Color(1.0, 1.0, 1.0),
		"paper": Color("fdf5e6"),
		"hatch_turn": 0.0,
		"hatch_gap": 9.0,
		"sun": Color("fff4e0"),  # even, soft
		"sun_energy": 1.1,
		"accent": Color("f4d03f"),
	},
	"race": {
		"technique": "deco",  # a streamline art-deco poster: flat tones, metal in bands, a sunburst sky (sheets 52–58; ADR-0034)
		"ramp": [Color("1a2f4c"), Color("e0aa3e"), Color("f6c8a4"), Color("f8e6cf")],  # the shade's navy, brass, sky low (peach), sky high
		"ink": Color("15233b"),  # the navy line
		"width": 1.2,
		"tint": Color(1.0, 1.0, 1.0),
		"paper": Color("f4efe2"),  # ivory
		"hatch_turn": 0.0,
		"hatch_gap": 9.0,
		"sun": Color("ffe2c2"),  # a low warm sun
		"sun_energy": 1.35,
		"accent": Color("e0aa3e"),
	},
}


## The style of an island; an island without a row is drawn like home.
static func of(island_id: String) -> Dictionary:
	return TABLE.get(island_id, TABLE[HOME])

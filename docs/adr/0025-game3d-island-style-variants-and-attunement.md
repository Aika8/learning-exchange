# 0025. Give every island its own variant of the ink style, and let the island's wind restyle the captain

- Status: Accepted (2026-11-17); the bounds of decision 1 are amended by ADR-0026
- Date: 2026-11-17
- Pattern(s): Flyweight-like table of value objects (`IslandStyle`: one small immutable set of numbers per island, shared
  by everything that draws), Strategy stays where ADR-0024 put it (`Style`)

## Context
ADR-0024 gave the game one look: low-poly, an ink outline, an engraving mode. Aika likes it and wants the islands to
differ, "only a little": palette, the thickness and colour of the line, the hatching, the light. And when the captain
steps onto a new island, the island should act on them: a short piece of magic, after which the captain is drawn the
way this island is drawn.

The world bible already has the reason: islands drift on Currents, rivers of wind, and each island has its own wind.
So the magic is the island's wind taking the newcomer in. No new lore is needed.

Forces:
- The differences must stay small. Two islands must still read as one game, and the Exchange board must keep its
  colours (ADR-0024 caps the hall at the outline for that).
- The look lives in one post-effect quad (`shaders/ink.gdshader`). A second mechanism for "style" would have to be
  kept in step with it.
- The captain is built from the same meshes and materials as everybody else; a second set of captain materials per
  island would multiply with every new island.

## Decision
1. **`IslandStyle`** (`game3d/scripts/island_style.gd`) is a table: island id → line colour, line width, a colour
   tint, the hatch angle and spacing, the paper colour of the engraving, the sun's colour and strength, and an accent
   colour for the wind. An island not in the table gets the home style (Spark Harbour). The variants are bounded by a
   test: tint within 10% of white, line width within 30% of the home one.
2. **The post-effect takes two styles at once.** `ink.gdshader` gets the current island's numbers and a second set,
   "from". It rebuilds each pixel's place in the world from the depth buffer; pixels inside a small column round the
   captain and above a moving height (`wave`) are drawn with the "from" style, all others with the island's. So the
   captain can stand in a new island still drawn the old way, and a wave rising from feet to hat redraws them. No
   captain materials change.
3. **Attunement** (`Session.attune`, `scripts/wind_swirl.gd`): `Game.attuned` remembers which island's style the
   captain wears. When the harbour scene opens on another island, the captain arrives in the old style; after a
   moment the island's wind swirls round them (thin streaks in the island's accent colour, our own code), the
   wave runs up, the line along the wave glows, and `Game.attuned` becomes this island. About two seconds, the
   captain keeps control. The Exchange hall and the voyage use the style of the island the ship is at.
4. Light is set where the sun is made (`Archipelago.sky`), from the same table.

## Why this and not the alternatives
| Alternative | Why not (now) |
|---|---|
| A separate set of costume materials for the captain per island | Grows with islands × garments; cannot change the line or the hatching, which are the style |
| Per-object outline (inverted hull or stencil) so the captain has their own line | A second outline technique next to the post-effect; two looks to keep equal; costs a pass per person |
| A full-screen cross-fade of the whole island on arrival | It is the captain who changes, not the island; and a fade hides the idea |
| Big differences (another palette, another technique per island) | Aika asked for "only a little"; the board and the lessons must read the same everywhere |
| Particles from an asset pack | No new asset sources without Aika's yes; a few dozen streaks in code are enough |

## Pros
- One place per concern: numbers in `IslandStyle`, drawing in the one shader, timing in `Session`.
- A new island is one row in the table.
- The captain's restyle is real: line colour, width, tint and hatching all change, in both ink modes.

## Risks and costs
- The post-effect reads the depth buffer twice more per pixel only where the column is; outside it the cost is one
  branch. We notice a cost in `--fps` (the number to hold is 60).
- Anything else standing inside the column (a crate at arm's length) is drawn in the old style for those two
  seconds. Accepted: it reads as the wind's reach.
- With the ink switched off (V) only the light and the swirl remain; the restyle needs the effect.
- Small differences may be too small to notice on some screens. We notice by showing Aika the side-by-side pictures
  (`docs/demo/G3D-islands.md`).

## How to explain it (teaching note)
The style of an island is data, not code: a small value object per island, and one renderer that can draw with two
of them at once and blend by position. That is why adding an island costs a table row, and why the captain can be
"between" two styles without owning any style of their own.

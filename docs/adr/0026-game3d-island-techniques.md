# 0026. Every island is drawn in its own technique, not a variant of one

- Status: Accepted (2026-11-17)
- Date: 2026-11-17
- Pattern(s): Strategy chosen by data (`IslandStyle` names a technique; the one post-effect implements them)
- Amends: ADR-0025, decision 1 only (the bounds "tint within 10%, line within 30%" are dropped)

## Context
ADR-0025 gave each island a slight variant of the ink style. Aika looked at the two islands and said they still look
the same: she wants every island to have a style that is really its own, not a shade of the home one. The wind that
restyles the captain stays.

Forces:
- Spark Harbour is the look Aika approved in ADR-0024. It must not change.
- The geometry, the people and the concept sheets are shared by all islands. A separate set of models or materials
  per island multiplies with every island.
- ADR-0025 already made the look of an island data read by one post-effect, and made that effect able to draw two
  styles at once (the captain's column). A stronger difference should use that, not a second mechanism.
- The lessons must read the same everywhere: the HUD is not touched by the effect, and the Exchange hall keeps the
  home style.

## Decision
1. An island's row in `IslandStyle` gets a **technique**: the way the picture is made, not only its numbers.
   - `ink` — Spark Harbour: a dark pen line over flat colour, hatching in the engraving mode (ADR-0024, unchanged).
   - `dye` — Silk Reach: printed silk. Colours are sorted by brightness into four dye baths (indigo, teal, rose,
     cream) with a little of the object's own colour left; the line is light, like the wax line of resist dyeing;
     a fine weave lies over everything. Mode 2 is a two-colour print: indigo on cream.
   - later islands add their own technique the same way (ADR-0028 adds one).
2. The technique is a branch inside `shaders/ink.gdshader`, selected by a uniform; the row also gives the technique
   its colours (`ramp`). The effect keeps drawing two styles at once, so the captain still arrives drawn the old
   way and is redrawn by the wave — now from one technique into another.
3. The test that bounded the differences is replaced by one that asks for the opposite: no two islands share a
   technique, home has exactly the ADR-0024 numbers, and the shader knows every technique in the table.

## Why this and not the alternatives
| Alternative | Why not (now) |
|---|---|
| Stronger numbers in the same technique (bluer line, more tint) | That is what ADR-0025 did; still reads as the same picture |
| Different models, textures and materials per island | Multiplies the art by the number of islands; breaks "people follow the sheets" |
| One shader file per island, swapped on arrival | The captain's restyle needs both styles in one pass |
| Change the home style too, to push the islands apart | It is the approved look |

## Pros
- An island is recognised from one screenshot.
- Still one row per island and one renderer; a new technique is one function in the shader.
- The restyle of the captain is far easier to see: dark line and flat colour turn into dyed cloth.

## Risks and costs
- Sorting colours into four baths merges things of equal brightness; the light line keeps shapes apart. We notice
  on the pictures in `docs/demo/G3D-looks.md` and by asking Aika whether the trading post still reads.
- A technique is shader code, so "a new island is one table row" is true only for islands that reuse a technique.
- With the effect off (V) all islands look alike again, as before.
- The shader grows a branch per technique; cost is watched with `--fps` (60 is the number to hold).

## How to explain it (teaching note)
Strategy: the picture has one place where "how to draw" is decided, and the island chooses the strategy by a name
in its data. The strategies share their input (colour, depth, edges), so the caller — the captain's wave — can ask
for two of them in the same frame.

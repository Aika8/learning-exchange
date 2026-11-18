# 0034. The race island: the Grand Prix of the Winds as a streamline art-deco poster; a place and a style, no mechanics yet

- Status: Proposed
- Date: 2026-11-18
- Pattern(s): Strategy chosen by data (a seventh technique, ADR-0026/0029), Builder (`RaceIsle`), Registry row (`Ports`, ADR-0032)

## Context
Aika's notes (intent 03) have a side-job island after a race she watched: change wheels as an engineer, or drive;
a place in the race is paid. The real series is a registered brand and the project forbids real brands, so the
island is **our own sky race, the Grand Prix of the Winds** («Гран-при Ветров»): sky skiffs with sails and air
screws on a track in the air. She has drawn it (seven sheets, `docs/design/concepts/52…58`) in the manner of
**art deco, the "streamline" posters of the 1930s**: streamlined shapes, sunburst rays, stepped silhouettes, flat
poster colour, metal as clean stripes; palette navy `#1a2f4c`, midnight teal `#103c42`, ivory `#f4efe2`, brass
`#e0aa3e`, copper `#b25329`, signal red `#c83e3c`, a peach sky `#f6c8a4`.

Limits from outside:
- **No race and no pit-stop mechanics** (they wait for intent 03, question 13). A place and a style for now.
- **No real brand, team, logo, livery or circuit** of any racing series.
- **Eyes** (the lessons of katazome, noir and the first pixel version): no pattern laid out on the screen, no
  dither, nothing that swarms on the move or on a turn; the contrast of navy and ivory must stay in big flat areas.

Forces:
- "Metal as clean stripes" and "sunburst rays" are patterns, and patterns on the screen are what hurt before.
- The post-effect has only colour, depth and normals; the materials do not say "this is brass".
- Every technique must redraw the captain (ADR-0029); every island must be on the flight chart (ADR-0032).

## Decision
1. **A seventh technique, `deco`** (technique 6), row `race` in `IslandStyle`:
   - **flat poster colour**: each surface keeps its own hue and is printed in three flat tones — shade, colour,
     light — with narrow soft steps between them; the shade leans to navy, the light to ivory;
   - **metal as clean stripes**: where a surface is brass or copper (warm and saturated), the tone is chosen from
     the **normal**, in a few bands — a curved hull gets the bright and dark stripes of a poster's chrome, a flat
     plate stays one flat tone. The bands belong to the surface, so they do not crawl when the camera moves;
   - **a thin navy line** on edges;
   - **the sky is the poster's**: peach low, ivory high, with a low sun and wide brass rays fanning from it. The
     rays are fixed to the **world** (to a direction, like a real sun), not to the screen: turning the head moves
     them as the horizon moves. Twelve wide rays, low contrast against the sky;
   - the cloud sea is dusk navy with peach where the light falls;
   - anything truly red is the one signal red;
   - nothing is animated by the effect. V gives the plain version: paper and navy, no stripes, no rays.
2. **The island `race`** («Остров гонок», working name), built by `RaceIsle`, after sheet 52:
   - the **track**: a banked ivory-and-brass ribbon on pylons, **in the air round the island**, above head height,
     with brass **rails** along both edges and red signal gates across it;
   - the **timing tower** in the middle: stepped, navy and ivory, a clock face, red lights, a mast (sheet 53);
   - **pit garages** along the pit lane: rounded navy boxes with copper bands and a shutter (sheet 53), a skiff on
     a stand in front of one, fuel barrels, a stack of wheels, spare air screws, a tool trolley (sheets 54, 57);
   - a **grandstand** with a sunburst canopy and flags; ceremonial **gates** with stepped ivory pylons at the pier;
   - **four sky skiffs** after sheet 55 — «Быстрая звезда», «Буря», «Феникс», «Адмирал» — as decoration: two on
     the track, one in the pit, one moored. They do not move.
3. **Islanders** after sheet 56 — the aviator, the chief mechanic, the crew member, the marshal with flags, the
   spectator: five costume roles from the existing garments; in comic pages their figures from the sheet (one face
   each). They talk about what a race teaches a trader without naming a strategy to follow: the pit stop as a
   planned cost, the marshal's flag as a rule decided before the start (a stop order's cousin), the timing tower
   as measurement, the prize as small pay for work. Nobody recommends anything; nothing can be driven or repaired.
4. **On the flight chart**: a row in `Ports`. The ship's solid for this island is wide enough to hold the track.
5. **The captain is redrawn in art deco on landing**; the contract test covers the technique, a port test the island.
6. **Not built**: the second islet with hangars and the suspension bridge of sheet 52 (one island for now); the
   inside of a pit box (sheet 54, right) — it belongs with the pit-stop mechanics.

## Why this and not the alternatives
| Alternative | Why not (now) |
|---|---|
| Stripes and rays laid out on the screen | Exactly what swarmed in katazome and the first pixel version |
| Real metallic materials with reflections | Only this island would have them; the captain, redrawn, has none; reflections shimmer |
| Rays as geometry in the sky | Seen from the island they would need to be kilometres long; a direction in the shader is the same picture for nothing |
| Skiffs racing round the track | That is the mechanics' first step and waits for question 13; moving things also need the audit's rules |
| The second islet and bridge now | Twice the walkable ground to audit for a place with nothing to do yet |
| Use the real series' words (team names, "Formula") | Forbidden: real brand |

## Pros
- The island is told apart at a glance: the only one with a warm sky and metal.
- Seventh technique, same contract; seventh port, one row.

## Risks and costs
- "Is this brass?" is guessed from colour: a warm saturated cloth is striped as metal on a curve. The costumes avoid
  such colours except where metal is meant.
- Navy against ivory is a strong contrast; it is kept to large shapes and thin lines. Watched with `--stroll`.
- The track is scenery the captain cannot reach; a mechanic's job will need a way up.
- The island's name and its place in the world bible are open.

## How to explain it (teaching note)
A pattern can be tied to three things: the screen, the world, or the surface. Tied to the screen it slides over
everything that moves. The rays here are tied to the world and the stripes to the surface's own normal — so both
behave like things, and the eye lets them be.

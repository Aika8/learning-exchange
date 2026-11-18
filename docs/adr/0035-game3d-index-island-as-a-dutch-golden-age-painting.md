# 0035. The index island becomes a canal town painted in oil (the Dutch Golden Age); supersedes 0033

- Status: Proposed
- Date: 2026-11-18
- Supersedes: [0033](0033-game3d-index-island-as-a-toy-town.md) for the island's look and layout
- Pattern(s): Strategy chosen by data (an eighth technique, ADR-0026/0029), Builder (`IndexIsle` rebuilt), Registry row (`Ports`, unchanged)

## Context
ADR-0033 drew the index island as a pastel toy town. Aika saw it built and judged it: **"childish, and the
approach is a grown-up one"**. Index investing is the method of adults of every age who waited for decades
(intent 03, "The index island: Aika's ideas"); a candy town says the opposite.

She has drawn the island again (eight sheets, `docs/design/concepts/59…66`) as a town of the **Dutch Golden Age
in soft oil paint**: warm low side light, long soft shadows, a golden haze, a muted palette — brick `#9a3b26`,
dark ochre `#a0781c`, olive `#5a5632`, Delft blue `#214375`, cream plaster `#eae2ca`, soft gold `#cbb45e`, soot
`#1c1c1c` — light brush strokes and the tooth of canvas, with silhouettes kept clear. A canal town: narrow brick
houses with stepped gables, canals and bridges, an exchange with a courtyard under arcades, people of every age in
dark clothes with white collars. One sheet shows the same town on an **overcast day** — for the falling phase
("the storm passes over it too").

Limits from outside:
- **No index mechanics** still (intent 03, question 9); the growing garden, the storm and the album wait for phases.
- **The pastel technique is not thrown away**: Aika wants it on another island. Its sheets (47–51), its shader
  branch and its number stay.
- **Eyes**: brush strokes and canvas are textures, and textures laid on the screen swarm when the camera moves.

Forces:
- "Oil paint" in post-processing usually means a Kuwahara filter: many reads per pixel, and its regions jump
  between frames — it boils.
- Long soft shadows are a matter of where the sun stands, which until now was the same on every island.
- A canal needs ground lower than the street; the islands' ground is one flat cap.

## Decision
1. **An eighth technique, `oil`** (technique 7); the row `index` in `IslandStyle` now names it. The technique
   `toy` (5) keeps its number and its shader branch and belongs to no island until Aika places it.
   - **muted, warm colour**: a little less saturation, everything leaning to ochre; darks go to warm umber, never
     to black; lights to cream;
   - **melted shading**: a very small blur (1.5 pixels at 1080p) takes the facets out of the low-poly shading;
     silhouettes stay clear, and a soft umber edge marks them instead of an ink line;
   - **brush strokes that belong to the world**: slow noise laid out in world space along each surface (on the
     hero: in the hero's own space, as katazome does) varies the paint's tone by a few percent in long strokes.
     It stays on the wall when the camera moves. No Kuwahara filter;
   - **canvas**: a faint weave on the screen, 2.5 % — the one screen-space layer, at the strength the cotton
     weave of katazome already has;
   - **golden haze**: distance fades to warm gold; the sky is gold low and grey-blue high with big soft clouds
     fixed to the world; the cloud sea is gold-cream;
   - nothing is animated. V gives the plain version: umber and cream, no strokes.
2. **Light per island**: every `IslandStyle` row gives `sun_height` (degrees above the horizon) and `sun_soft`;
   the index island has a low sun (16°) and soft shadows. The other rows carry the values they always had.
3. **The island is rebuilt** by `IndexIsle` as a canal town after sheets 59–62 and 65, on the same rock, with the
   same pier and berth (so `Ports` does not change):
   - a **canal** across the town between brick quay walls, with two stone **bridges**;
   - **narrow brick houses with stepped gables** (and some bell gables) in rows along the canal — brick, ochre and
     olive fronts, cream trim, black shutters, tiled roofs in red and slate blue; no two neighbours the same colour;
   - the **Exchange** at the end of the street: a cream classical front with an open **arcade**, and a brick clock
     tower with a spire behind it. Its courtyard is seen through the arches; the inside waits for the mechanics;
   - a **stone fountain** on the square that still drops a coin every four seconds (the regular contribution);
   - lindens along the quay, lanterns, a market stall, barrels and crates, benches, canal boats, sky ships at the pier.
   The canal is water at street level between parapets, and the bridges are level crossings with arched sides:
   the islands' ground is one flat cap, and a real trench is a change to the island mesh that this look does not need.
4. **Islanders of every age** after sheet 63 — the merchant, the young woman, the market woman, the young father
   and his child, the old couple: seven costume roles in dark cloth with white collars; in comic pages their
   figures from the sheet (one face each). Their talks keep the island honest (intent 03): the method and its
   real terms, and also the drawdowns, the years of waiting and the boredom. Nobody recommends anything.
5. **The captain is redrawn in oil on landing**; the contract test covers the technique, a port test the island.
6. **Not built**: the overcast day of sheet 65 (it belongs with the phases), the inside of the Exchange, the
   windmill of sheet 61, the growing garden and the family album as a thing to open.

## Why this and not the alternatives
| Alternative | Why not (now) |
|---|---|
| Keep the toy town and tune it | The objection is to what it says, not to how well it is drawn |
| A Kuwahara (oil) filter | Tens of reads per pixel and regions that jump from frame to frame: it boils |
| Brush strokes on the screen | The lesson of katazome and the first pixel version |
| Delete the toy technique | Aika will reuse it |
| Edit ADR-0033 in place | Decisions are superseded, not rewritten; 0033 stays as the record of the first look |
| A sunken canal (cut the island mesh) | A new kind of ground for every tool that walks it; parapets hide the water level from the street |
| The overcast variant now, on a debug switch | Without phases it is a second look nobody reaches; it is drawn and waits |

## Pros
- The island looks like what it teaches: old money, patience, nothing to click.
- The low sun is one number in a table; any island may now have its own hour of the day.

## Risks and costs
- Muted colour in warm light can turn to brown soup; the Delft blue of roofs, shutters and water is what keeps it apart.
- The symmetry test of ADR-0033 goes with the toy town.
- Water at street level reads as a full canal, not a deep one, from above.
- A second rebuild of the same island within a day: its demo page and screenshots are replaced.

## How to explain it (teaching note)
The same rule as on the race island decides where each layer lives: strokes are tied to the world, the weave to
the screen — and only the faintest layer is allowed on the screen. The second lesson is about decisions: the toy
town was not a bug to fix but a decision to replace, so it gets a new record rather than an edited old one.

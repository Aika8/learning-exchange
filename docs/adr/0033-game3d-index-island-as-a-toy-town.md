# 0033. The index island: a symmetrical pastel toy town; a place and a style, no mechanics yet

- Status: Proposed
- Date: 2026-11-18
- Pattern(s): Strategy chosen by data (a sixth technique, ADR-0026/0029), Builder (`IndexIsle`), Registry row (`Ports`, ADR-0032)

## Context
Aika's notes (intent 03) describe an island of index investors: **very rich and very boring** — every few seconds
money goes into the index, nothing can be clicked, one can only walk the streets. She has now drawn it (five
sheets, `docs/design/concepts/47…51`): a strictly symmetrical town under a glass dome — identical mansions, a
straight avenue to a bank that is a palace, a fountain, sky yachts at the pier — in the manner of a **toy town**:
glossy "plastic and painted wood", rounded edges, lollipop trees, people like figurines, tilt-shift blur at the top
and bottom, even soft light, low contrast; palette pink `#ffb7b2`, mint `#b5e2b8`, butter `#ffeb99`, powder blue
`#a8dadc`, lavender `#e2cee2`, teal `#1a5b5c`, gold `#d9a441`.

Limits from outside:
- **No index mechanics** (they wait for intent 03, question 9). A place and a style for now.
- **Eyes** (the lessons of katazome, noir and the first pixel version): tilt-shift must not smear the middle of the
  picture or the HUD; nothing may shimmer.
- No real fund names: whether "SPY" and "BIL" may appear is intent 03's question 7, unanswered.

Forces:
- Blur is the one thing the earlier techniques never did; it costs texture reads and can make a moving picture
  swim if it depends on what is in it.
- "Glossy" needs highlights, and the effect has only colour, depth and normals.
- Every technique must redraw the captain (ADR-0029); every island must be on the flight chart (ADR-0032).

## Decision
1. **A sixth technique, `toy`** (technique 5), row `index` in `IslandStyle`:
   - **pastel, low contrast**: colours are lifted towards cream and their shade is a soft lavender, never dark;
   - **gloss**: a small white highlight where a surface faces a fixed "lamp" above the viewer — computed from the
     normal alone, so it sits still on a still thing — and a paler rim where a surface turns away;
   - **no ink line**: edges are a soft, slightly darker teal seam, as between two painted parts;
   - **tilt-shift**: the top and bottom of the screen are blurred, the middle half is left exactly sharp. The blur
     depends only on the height on screen, not on depth or content, so it does not swim; its radius is small
     (5 pixels at 1080p at the very edge). The HUD is drawn after the effect and is never blurred;
   - the sky is a pale wash from cream to powder blue; the cloud sea is lavender-white;
   - nothing is animated by the effect. V gives the plain version: pastel, no gloss, no blur.
2. **The island `index`** («Остров индексов», working name), built by `IndexIsle`, **mirror-symmetrical** about
   its avenue: a pier with sky yachts, a straight avenue, a round square with a fountain, identical mansions in
   mirrored pairs, clipped hedges and lollipop trees, and at the end the **Bank Palace** with a dome. Symmetry is a
   test: every building and tree has its mirror twin.
3. **The fountain drops a coin** every four seconds — the picture of a regular contribution. It is the island's
   only motion, and it is geometry (one small coin), not an effect.
4. **Islanders** after sheet 50 — the calm rich gentleman, the elegant lady, the retired couple, the child in a
   sailor suit: five costume roles from the existing garments; in comic pages their figures from the sheet (one face
   each). They explain the index fund (the real term beside «Корзина Ветлы»), diversification, low fees, regular
   contributions, compounding and patience — and that boring is the point. Nobody recommends anything; nothing
   can be bought.
5. **On the flight chart**: a row in `Ports`, so the island can be flown to and moored at like the others.
6. **The captain is redrawn as a toy on landing**; the contract test covers the technique, a port test the island.
7. **Not built**: the glass dome and its wooden base. A transparent shell round the whole island fights the
   post-effect (it is drawn before it and would be outlined and blurred with everything else) and the ship would
   have to pass through it. The tilt-shift carries the "miniature under glass" feeling instead.

## Why this and not the alternatives
| Alternative | Why not (now) |
|---|---|
| Depth-of-field by distance (the engine's own, or from depth) | Changes with every step and with what is in view: it swims; and it would blur the middle |
| A strong blur, as in miniature photographs | Tiring in play; the request is "carefully" |
| Real glossy materials (metallic/roughness, reflections) on the island's meshes | Only this island would need them; the look must also be applied to the captain, who has none |
| Rounded meshes (bevels on every box) | Many times the triangles for a softness the soft seam and the blur already give |
| Index mechanics with the island | Waits for Aika (intent 03, question 9) |
| Name the funds SPY and BIL | Intent 03, question 7 is open; generic real terms teach the same |

## Pros
- The island says its lesson by its look: order, sameness, calm, one coin at a time.
- Sixth technique, same contract; sixth port, one row.

## Risks and costs
- Low contrast can read as washed out on a bright screen. One number (how far colours are lifted) tunes it.
- The blur is the most expensive thing any technique does (eight extra reads in the blurred bands, none in the
  middle). Watched with `--fps`.
- Highlights from normals are the same on every material: wood shines like plastic.
- Without the dome the sheet's main image is missing.
- The island's name and its place in the world bible are open (the Quiet Pier — gardens, deposits, "very slow" — fits).

## How to explain it (teaching note)
Tilt-shift here is a function of one number — how far up the screen a pixel is. Because it ignores the scene, it
cannot react to it, and so cannot flicker with it: the cheapest way to make an effect calm is to give it less to
look at.

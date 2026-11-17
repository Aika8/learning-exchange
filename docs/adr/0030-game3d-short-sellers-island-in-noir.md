# 0030. The short sellers' island: a tilted town drawn as film noir; a place and a style, no mechanics yet

- Status: Proposed
- Date: 2026-11-17
- Pattern(s): Strategy chosen by data (a fourth technique, ADR-0026/0029), Builder (`ShortIsle`)

## Context
Aika's notes (intent 03) want trading islands that each stand for a real approach; the first she drew is the island
of **short sellers**: six sheets (`docs/design/concepts/35…40`) — a rock slab tilted like a sinking ship, towers
that lean as if falling, a windmill exchange "of falling prices" on the cliff edge, people in trench coats; drawn
as **noir**: ink black and paper white, almost nothing between, **one signal red `#c4302b`** (etherite crystals,
a door, a window, a scarf, a lantern), slanted rain, fog, hard light.

Two limits are set from outside:
- **No shorting mechanics.** How a short works in the game waits for Aika's answers to intent 03 (question 11).
  For now the island is a place and a style.
- **The lesson of katazome** (ADR-0029, revised): a picture of two extreme tones hurt her eyes. Noir must not be a
  black screen, and nothing in it may shimmer — not rain, not hatching.

Forces:
- The post-effect sees only colour, depth and normals; "one red" has to survive a two-tone picture.
- A really tilted walkable ground would break what the walkers, the fences and the world audit assume (a flat cap
  at one height). A town that only *looks* tilted does not.
- Every technique must redraw the captain (the contract of ADR-0029).

## Decision
1. **A fourth technique, `noir`** (technique 3) in `shaders/ink.gdshader`, row `shorts` in `IslandStyle`:
   - **hard light**: lit surfaces are paper white, shade is ink black, with one flat grey between them for the
     half-shade (a wash, not hatching: hatching in screen space crawls when the camera moves);
   - **the signal red**: anything truly red as the eye sees it is drawn flat `#c4302b`, lit or not. The island's
     own materials use red only where the sheets do;
   - **fog**: distance fades everything to pale paper, so far towers are grey shapes and the sky is light. With
     the lit ground this keeps most of the screen light: black is for shade and silhouettes;
   - **slanted rain**: thin grey streaks in screen space that travel steadily along their slant — sparse, low in
     contrast, no per-frame randomness;
   - the line is the opposite of what it lies on. Mode 2 (V) is the strict print: black, white and red, no grey,
     no rain.
2. **The island `shorts`** («Остров шортистов», working name) is built by `ShortIsle` and reached by the packet
   boat like Amber Cliff. The walkable town is a **flat** cap (so walking, fences and the audit hold); the tilt is
   drawn: a great slab of rock rising behind the town, crooked houses and towers that lean (the picture leans, the
   collider stands), red etherite under the rock. On the cliff edge stands the **Exchange of Falling Prices**: a
   leaning mill with broken blades and a red board whose line goes down. Its door is a talk, not a trading hall.
3. **Islanders** follow sheet 36: the broker in a trench coat and hat with a red tie, the old man with a red
   armband, the pale youth with a red shirt, the woman with a red scarf — four costume roles built from the
   existing garments. In comic pages they are shown by their figure on sheet 36 (one face each: there is no
   expression sheet for them yet). They talk about what a short sale is — the real term beside the lore — and
   about its costs and dangers; nobody recommends it and nothing can be traded there.
4. **The captain is redrawn in noir on landing**, by the same wind and wave; the contract test of ADR-0029 covers
   the new technique automatically, and a port test covers the new island.
5. **Easy on the eyes is checked, roughly, by numbers**: the share of the screen that is dark in the fixed views,
   and the mean change between frames of a walking camera (`--stroll`), written in `docs/demo/G3D-shorts.md`.

## Why this and not the alternatives
| Alternative | Why not (now) |
|---|---|
| Really tilt the ground | Walkers, fences, nav mesh and the audit assume a flat cap; a tilt that only costs risk |
| Night: black sky, lit windows | The strict sheet looks like that, and it is what hurt with katazome; fog and a pale sky keep the mood |
| Hatching for half-tones | Screen-space hatching crawls under a moving camera; world-space hatching shimmers far away |
| Rain as particles in the world | Costs fill rate and cannot be kept calm; three lines of shader can |
| Build the shorting mechanics with the island | Waits for Aika (intent 03, question 11) |
| A new set of people models | The four roles are the existing garments in black, grey and one red |

## Pros
- The first "method island" exists as a place before its mechanics are argued out.
- One more technique under the same contract; the captain's change needed no new code.

## Risks and costs
- Two tones hide what differs only in colour: a thing must read by silhouette. The sheets are drawn that way; the
  game's props may not be. We notice on the pictures.
- "Leaning" is a rotated picture over an upright collider: lean too far and you walk into air or stop before a
  wall. Kept under 8°, where the difference at body height stays inside what the audit allows.
- The island has a name only as a job title. If it is one of the bible's islands (the Etherite Mines fit the red
  crystals), the bible should say so. Question for Aika.
- Rain is in screen space: it does not fall *between* things. Accepted for a drawing.

## How to explain it (teaching note)
The fourth strategy cost a branch and a table row because the third change had already written down what every
strategy owes its caller. And the island shows a design habit worth copying: when a wish ("it is tilted") fights
an invariant ("people stand on a flat cap"), keep the invariant and draw the wish.

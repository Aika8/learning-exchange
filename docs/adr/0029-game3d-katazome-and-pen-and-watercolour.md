# 0029. Silk Reach is drawn as katazome, Amber Cliff in pen and watercolour; every technique redraws the captain

- Status: Proposed
- Date: 2026-11-17
- Pattern(s): Strategy chosen by data (as ADR-0026); a contract every strategy must meet (it can draw the hero)
- Supersedes: the technique `dye` of ADR-0026 (decision 1) and the technique `claire` of ADR-0028 (decision 5).
  Everything else in those two ADRs stands.

## Context
ADR-0026 made the technique of an island a row of data and a branch of one post-effect, and I picked the first two
myself: "printed silk" for Silk Reach, a ligne-claire album page for Amber Cliff. Aika has now chosen the
techniques and drawn the sheets (`docs/design/concepts/27…34`):
- **Silk Reach — katazome**, the Japanese stencil-resist print: indigo `#1f2f5a` and cream `#efe6d2`, a rare rust
  accent `#b5523b`; silhouettes as if cut from a stencil; a light line, not a black one; small repeating patterns
  (waves, clouds, diamonds) inside the big shapes, **tied to the objects, not to the screen**; the grain of cotton.
- **Amber Cliff — pen and watercolour**, a French travel sketchbook: a thin, lively, slightly trembling line;
  transparent washes that run past the line; a lot of white paper; soft edges; paper grain. Sheet 34 gives samples
  of the technique and its palette.
- A third, for an island of short sellers (noir, crooked expressionist houses, one red accent), will come later.

And a rule for all of them: **in every port the hero is redrawn in that island's technique**, by the wind and the
wave of ADR-0025 — for these two and for every island to come.

Forces:
- The post-effect sees only the finished picture, the depth and the normals. A pattern "tied to the object" needs
  a place on the object, and a moving person has none in screen space.
- The effect draws two styles in one frame (the captain's column). Whatever a technique needs, it needs for both.
- 60 fps.

## Decision
1. **`katazome`** replaces `dye` (technique 1). Brightness sorts the picture into cream and indigo, with nothing
   in between; a strongly warm, saturated colour becomes the rust accent; the sky is indigo and the cloud sea cream.
   In the middle brightnesses a small pattern is cut into the shape: waves (seigaiha) on what faces up, diamonds
   on walls, dots elsewhere. **The pattern is laid out in world space**, on the plane the surface faces (found
   from the depth and the normal), so it stays on the thing when the camera moves. The line is the opposite colour
   of what it lies on: light on indigo, indigo on cream. A cotton weave lies over all. Mode 2 is the bare stencil:
   two colours, no patterns.
2. **`aquarelle`** replaces `claire` (technique 2). The colour is taken from a point nudged by slow noise, so the
   wash runs past the line; it is thinned towards the paper, most of all in the light and far away, so much of the
   sheet stays white; shade is a violet-grey wash, not black; pigment gathers unevenly; the paper has grain. The
   line is a thin warm grey whose position trembles and whose strength comes and goes. Mode 2 is the pen alone.
3. **The hero has a place of their own.** The effect is told where the captain stands (`hero`, `hero_radius`).
   Inside that column a technique that needs object space measures from the captain, so the pattern on the coat
   travels with the captain and does not swim. This is separate from the column of the wave (ADR-0025), which
   still chooses *which* technique draws the captain during the change.
4. **A contract, held by a test:** every technique in `IslandStyle.TECHNIQUES` has its branch in the shader; every
   number a style has, the shader also has as `…_from`; and for every ordered pair of islands the wind can take
   the captain from one technique to the other and ends with one style. A new island cannot be added without it.
5. The geometry of the two islands is not changed by this ADR, except the colours of Amber Cliff's houses, which
   follow sheet 30 (geranium doors, sea-teal shutters, slate roofs). What the sheets show beyond that (the village
   of Silk Reach, the lighthouse with the keeper's house, the kiosk, the carousel, bicycles) is listed as not built.

## Why this and not the alternatives
| Alternative | Why not (now) |
|---|---|
| Patterns in screen space | Aika asked for them on the objects; in screen space they slide over everything as the camera turns |
| Patterns as textures on the meshes | Only Silk Reach would need them and only in this technique; every mesh would need UVs and a second material set |
| A separate renderer per island | The captain's change needs two techniques in one pass (ADR-0025) |
| Keep `dye` and `claire` as options | They were my guesses; the sheets are the source of truth |
| World-space patterns on people too | They swim across anybody who walks; the hero is the one person the effect can follow |

## Pros
- The islands now follow sheets Aika drew.
- "Every technique draws the captain" is a test, not a habit.
- Still one effect, one row per island.

## Risks and costs
- Villagers on Silk Reach walk through the world-space pattern (it slides over them). The hero does not. We
  notice in play; the cure would be a per-person anchor.
- World position from depth loses precision far away; the pattern is faded out with distance to hide it.
- A two-colour picture hides anything that is told apart only by hue. The trading post must still read: checked on
  the pictures in `docs/demo/G3D-techniques.md`.
- The watercolour takes four more samples of the picture per pixel; watched with `--fps`.
- The line of the watercolour is still an edge filter, not a hand: it trembles, it does not draw.

## How to explain it (teaching note)
A family of strategies is only useful if the caller can rely on all of them. Here the reliance is written down:
whatever else a technique does, it must draw the hero, in the old style and the new one in the same frame. The
test of that contract is what lets the next island be added without rereading the others.

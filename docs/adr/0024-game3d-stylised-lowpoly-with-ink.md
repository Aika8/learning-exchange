# 0024. Draw the 3D game as stylised low-poly with an ink outline and an engraving mode

- Status: Accepted (2026-11-17: Aika approved the style; the code landed in PR #23)
- Date: 2026-11-16
- Pattern(s): Strategy (the art style is chosen in one place, `Style`; the world builders ask it), Builder (people are
  built in code by `Costume`)

## Context
ADR-0019 moved `game3d/` to painterly realism: Poly Haven PBR textures and models, MakeHuman people. A year of small
passes showed what that costs here:
- The realistic people are the weakest thing on screen. Their faces sit in the uncanny valley, the clothes are modern
  and had to be painted over and covered with simple shapes (`Costume`), and the result is a realistic head on a toy
  costume. Aika: the characters got *simpler*, not better.
- The people are not downloadable. They are a Blender + MPFB build outside `assets.lock`; a fresh `make assets` has
  none and the game falls back to stand-ins (PR #20).
- The harbour barely holds 60 fps on her laptop with 3 M triangles of scanned rocks and trees (G3D polish pass).
- Our own content (houses, decks, the windmill, costumes, the Chronicler) is already flat-coloured geometry built in
  code. It clashes with photographic textures next to it.
- Aika's concept sheets (`docs/design/concepts/`) are ink-and-watercolour drawings with strong silhouettes. A flat,
  outlined look is much closer to them than PBR.

Aika decided (2026-11-16) to try a stylised low-poly look where characters read by silhouette, with an ink outline,
and a second mode that looks like an old sea chart or engraving.

## Decision
The default look of `game3d/` becomes **stylised low-poly**:
- **World**: flat colours from the one palette (`docs/design/game3d-style.md`), faceted meshes built in code, soft
  light. The Poly Haven PBR look stays in the code as an option (`--pbr`), not the default; nothing is deleted.
- **People**: built whole in code by `Costume` on a small skeleton made in code, so the same gait with foot IK
  (`Walker`) drives them. No faces: a head, a hat, a coat, a sash — the silhouette says who it is. The roles and
  their dress follow the concept sheets. MakeHuman people are no longer used by default (they remain reachable with
  `--pbr`), so the game no longer depends on a Blender build.
- **Ink**: a full-screen post-effect (`shaders/ink.gdshader`) with three modes switched by a key and kept between
  scenes: off, **outline** (dark lines on depth and normal edges over the flat colours), **engraving** (two-tone
  paper and ink with hatching by brightness, plus the outline). It is one quad and one shader pass.
- `Style` (autoload-free static class) is the one place that says which look is on; `Assets.available()` asks it.

PR #22 (characters from the sheets on MakeHuman bodies) is not merged as such: its design documents, the sheets and the
role-per-sheet structure of `Costume` are carried into this work; the MakeHuman-specific dressing stays only for `--pbr`.

This supersedes the art direction of ADR-0019 once Accepted. The shared kernel, scenes, collision, walking and the
audit are untouched.

### Reference, and what we take from it
Aika named the illustrated "sky pirates" books of her childhood (The Edge Chronicles) as the feeling to aim for:
characters you never confuse with one another. We take **principles**, never the characters, creatures, ships or
drawings themselves (copyright, and the "don't copy" rule of `CLAUDE.md`):
- **Exaggerated silhouettes and proportions**: lanky and portly figures, tall and short, long noses, hats too big for
  the head. In the code: `Costume.BUILDS` — height, girth, head-and-hat size and nose length per role.
- **Layers and things that hang on a person**: coat over waistcoat over shirt, sash under belt, pouch, flask, spyglass,
  a coil of rope, a rolled chart, a badge on a chain.
- **A pen line with hatching**: our ink outline and the engraving mode stand for it.
- **More than one kind of folk**: the world bible has one non-human so far, the Chronicler (an owl here). New kinds are
  a lore decision for Aika, not something the art invents.
The people themselves are ours, from the world bible and Aika's concept sheets (`docs/design/README.md`).

## Why this and not the alternatives
| Alternative | Why not (now) |
|---|---|
| Keep PBR and get better people (rebuild MakeHuman with period clothes, or buy/download characters) | Needs Blender and a new asset source; still realistic faces; still clashes with our code-built content; fps stays tight. |
| Keep PBR world, low-poly people only | Flat people in a photographic world look pasted in. One style for everything is the point. |
| Hand-model low-poly characters in Blender | No Blender on the machine, and code-built people are reviewable, diffable teaching material like the rest. |
| Toon shading with ramp materials on everything | More shader work per material; the post-effect outline gives most of the look in one pass and can be switched. |
| Engraving as the only look | Hard to read the trading board and colours of bid/ask; kept as a mode. |

## Pros
- One coherent look, close to the concept sheets; characters read at a distance.
- No dependency on a Blender build or on 200 MB of downloads for the default look; a fresh clone looks right.
- Much cheaper to draw: frame rate head-room on the laptop.
- Everything visible is code we own (CC0), consistent with the project as teaching material.

## Risks and costs
- Low-poly made in code can look crude rather than stylised. We notice in the screenshots of `docs/demo/G3D-style.md`;
  the remedy is better shapes and palette, not textures.
- Two looks in the code (`--pbr` and default) is a maintenance cost; the audit and the GUT walk tests run on the
  default look. If `--pbr` rots, we delete it by a later ADR.
- The post-effect reads depth and normals: it costs a pass and can alias on thin geometry; it is off-switchable.
- Earlier demo screenshots (M3, M4, G3D polish) show the old look.

## How to explain it (teaching note)
"The art style is a Strategy: the world builders ask one object which look is on and build flat-coloured low-poly or PBR
accordingly, and a post-process shader adds the ink line. We chose low-poly because our own content is code-built and
because realistic people were the weakest and most fragile part; the trade-off is that we keep two looks alive for a while."

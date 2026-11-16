# G3D style — stylised low-poly, ink outline, engraving

Aika's decision (2026-11-16): drop the realistic look and try stylised low-poly where characters read by silhouette,
with an ink outline and an "old sea chart" mode. ADR-0024 (Proposed). All pictures below are from the running game.

**V** switches the look while you play: colour → ink outline → engraving. The game starts in ink outline.

## The four states

| | The square | The wharf | The captain's camera |
|---|---|---|---|
| **Was** (PBR, MakeHuman people; `--pbr`) | ![](g3d-style/1-was-square.jpg) | ![](g3d-style/1-was-wharf.jpg) | ![](g3d-style/1-was-captain-view.jpg) |
| **Low-poly** | ![](g3d-style/2-lowpoly-square.jpg) | ![](g3d-style/2-lowpoly-wharf.jpg) | ![](g3d-style/2-lowpoly-captain-view.jpg) |
| **Low-poly + outline** (default) | ![](g3d-style/3-outline-square.jpg) | ![](g3d-style/3-outline-wharf.jpg) | ![](g3d-style/3-outline-captain-view.jpg) |
| **Engraving** | ![](g3d-style/4-engraving-square.jpg) | ![](g3d-style/4-engraving-wharf.jpg) | ![](g3d-style/4-engraving-captain-view.jpg) |

| | The Exchange | Silk Reach | The hall |
|---|---|---|---|
| **Was** | ![](g3d-style/1-was-exchange.jpg) | ![](g3d-style/1-was-silk.jpg) | ![](g3d-style/1-was-hall.jpg) |
| **Low-poly** | ![](g3d-style/2-lowpoly-exchange.jpg) | ![](g3d-style/2-lowpoly-silk.jpg) | ![](g3d-style/2-lowpoly-hall.jpg) |
| **Outline** | ![](g3d-style/3-outline-exchange.jpg) | ![](g3d-style/3-outline-silk.jpg) | ![](g3d-style/3-outline-hall.jpg) |
| **Engraving** | ![](g3d-style/4-engraving-exchange.jpg) | ![](g3d-style/4-engraving-silk.jpg) | ![](g3d-style/4-engraving-hall.jpg) (the hall stays in outline: the board needs its colours) |

## People

| | | | |
|---|---|---|---|
| **Was** | ![](g3d-style/1-was-people-a.jpg) | ![](g3d-style/1-was-people-b.jpg) | ![](g3d-style/1-was-people-c.jpg) |
| **Low-poly** | ![](g3d-style/2-lowpoly-people-a.jpg) | ![](g3d-style/2-lowpoly-people-b.jpg) | ![](g3d-style/2-lowpoly-people-c.jpg) |
| **Outline** | ![](g3d-style/3-outline-people-a.jpg) | ![](g3d-style/3-outline-people-b.jpg) | ![](g3d-style/3-outline-people-c.jpg) |
| **Engraving** | ![](g3d-style/4-engraving-people-a.jpg) | ![](g3d-style/4-engraving-people-b.jpg) | ![](g3d-style/4-engraving-people-c.jpg) |

Walking (the gait with foot IK drives the built people too):

| Was | Low-poly | Outline | Engraving |
|---|---|---|---|
| ![](g3d-style/1-was-walk.jpg) | ![](g3d-style/2-lowpoly-walk.jpg) | ![](g3d-style/3-outline-walk.jpg) | ![](g3d-style/4-engraving-walk.jpg) |

## What was done
- `Style` (`game3d/scripts/style.gd`): one place decides the look. Default is low-poly: flat colours of the palette,
  meshes built in code. `godot --path game3d -- --pbr` gives the old Poly Haven look back; nothing was deleted.
- **People are built whole in code** (`Costume.stand_in`): a 19-bone skeleton made in code at fixed joints, a faceted
  body and the costume of the role skinned to it, no face. Eleven silhouettes from the concept sheets (captain, three
  sailors, Mara, money-changer, Olva, market woman, old man, child) and the Chronicler as an owl. The same `Walker`
  (computed gait, foot IK) moves them. The MakeHuman people are not used any more in the default look, so the game no
  longer depends on a Blender build or on `make assets`.
- **Exaggerated builds** (`Costume.BUILDS`): a lanky sailor with a coil of rope, a short stocky one with a flask, a
  wiry old one with a long nose and a spyglass, a portly money-changer under a big tricorn, a broad market woman, a
  thin tall analyst, a child with a big head. Noses are part of the outline; there are still no eyes or mouths.
- **Ink** (`game3d/shaders/ink.gdshader`, one full-screen quad owned by `Session`): outline on depth and normal edges;
  engraving = paper and ink only, three layers of hatching by brightness, the sky kept clean. Text on the board and on
  the notice board is drawn after the effect so it stays readable; the hall caps the effect at outline.
- The world needed no rebuilding: houses, decks, the windmill and the hall were already flat-coloured code-built meshes.

## Numbers
- GUT 77 → 79, green. The world audit in the new look: 0 problems on 1237 grid points, 8360 walks.
- Frame rate at 1920×1080 on the laptop (Apple M5), average / 1%-low fps, ink outline on. The display caps at 120.

| View | PBR (after the polish pass) | Low-poly + outline |
|---|---|---|
| harbour captain | 75 / 61 | 118 / 71 |
| view-square settled | 65 / 54 | 118 / 63 |
| view-houses settled | 73 / 57 | 118 / 68 |
| view-house-close settled | 96 / 66 | 117 / 59 |
| view-wharf settled | 101 / 74 | 118 / 72 |
| view-pier settled | 68 / 56 | 117 / 59 |
| view-exchange settled | 91 / 67 | 118 / 67 |
| view-top settled | 110 / 89 | 118 / 68 |
| silk captain | 120 / 101 | 119 / 73 |
| view-silk settled | 85 / 76 | 118 / 70 |
| view-silk-houses settled | 120 / 104 | 118 / 68 |
| view-silk-pier settled | 120 / 98 | 118 / 61 |

  Engraving costs the same (harbour captain 118, the square 118). The 1%-low of 58–82 is single 17 ms frames.

## Limits (honest)
- It is low-poly made in code, not modelled by an artist: shapes are tubes, boxes and domes. Good at a distance and in
  motion, plain up close. Trees are balls and cones, the ship is the old simple one, the ground is one flat green.
- The grass and the light were not re-tuned for the new look; the ground reads pale.
- No faces, by decision (a nose only). Builds vary by height, girth, head and nose; there is still one body plan.
- Engraving is uniform screen-space hatching: it does not follow the forms, and it shimmers a little when the camera moves.
- Checked on still pictures and by tests; not watched in play.
- The older demo pages (M3, M4, G3D polish, G3D characters) show the previous looks.

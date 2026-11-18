# 0037. Comic pages, second pass: cut-out figures, the place behind them, oval balloons with tails to the mouth

- Status: Proposed
- Date: 2026-11-18
- Amends: [0027](0027-game3d-talk-as-comic-pages.md) — how a page is drawn. What a talk is (data: pages → panels → lines, words as i18n keys, `ComicReader`) does not change.
- Pattern(s): Data-driven script (unchanged), a build step for assets (`tools/cut_portraits.gd`)

## Context
ADR-0027 turned talks into comic pages with Aika's drawn faces. Aika, looking at them: **"cut lines, a strange
background, text in strange balloons"**. Looked at closely:
1. **Portraits** were rectangles cut from the sheets with their paper, faded at the sides: a pale box behind each
   face, hats and shoulders ending in mid-air, the bust hanging over nothing.
2. **The background** was the same halftone dots on empty paper in every frame of every talk.
3. **Balloons** were rounded rectangles with the speaker's name inside, small tails that pointed nowhere.
4. **Composition**: every face about the same size, every page the same layout.

Limits from outside: no new outside tools and no new asset sources without Aika's yes; a comic lettering font must
be under a free licence (OFL or CC0) and must have Cyrillic.

## Decision
1. **Figures are cut out of their paper.** A tool in the project, written for Godot itself
   (`tools/cut_portraits.gd`, no outside program), finds the paper's colour at a picture's edges and floods it
   away, drops small leftover marks, and softens the straight cut where a neighbouring face on the sheet overlapped
   a hat's brim or a shoulder. It writes `art/cutouts/<face>_<emotion>.webp` (lossy, with alpha: 13 MB for 130
   pictures; PNG was 71 MB). **Hand corrections are data**, `data/cutouts.json`, per face or per picture:
   threshold, extra flood points, rectangles to keep. Three kinds of picture:
   - **cut** — a figure with nothing round it (the paper sheets);
   - **oval** — a painted bust in an oval on a dark mount (the oil portraits of the index island have no paper);
   - **card** — a picture with a drawn background of its own (noir rain, the neon grid, the robots), shown as a
     card with a white edge and an ink border. Cutting those would destroy the drawing.
   A cut figure **stands on the frame's lower edge** and goes a little below it, so the frame cuts the bust and
   nothing hangs. A close shot is taller than its frame.
2. **The background is the place of the talk**: as a page opens, the picture on screen — the island in its own
   technique, where the captain stands — is taken, made small and soft, and each frame shows its own cut of it
   (a wide shot the whole view, a close shot a part). No art to draw, and it is right for every talk on every
   island, including ones added later. A wash of paper keeps it behind the people. Halftone dots are only a shade
   in one corner. Without a screen (tests, CI) a frame falls back to sky over ground in the backdrop's two colours.
3. **Balloons** are ovals with centred text and room round it. **No name inside**: the first time somebody is
   seen in a talk their name is on a plate at the foot of the frame, once. The **tail** leaves the balloon's edge
   towards the speaker's mouth (where the mouth is on each sheet is data, `"mouth"` in `data/cutouts.json`) and is
   short: it says whose words these are and does not cross a face. A line said in anger is a **shout** — an oval
   with a zigzag edge; a line may also be marked `"shout"` or `"thought"` (a scalloped cloud and three bubbles) as
   an optional fourth word in the data.
4. **Lettering**: larger (20 px, was 17), centred. The page uses `res://fonts/comic.ttf` when the project has
   one, and a rounded system face until then. **No font is added by this ADR**: the candidates with Cyrillic and
   an OFL licence are named for Aika's yes (see the PR).
5. **Composition**: the height of a figure depends on the shot (close 1.22 of the frame, low 1.08, two 0.86, wide
   0.58), and in a frame of two the one who listens is a little smaller; every second page is laid out mirrored;
   gutters and borders as before.

## Why this and not the alternatives
| Alternative | Why not (now) |
|---|---|
| Cut the portraits by hand in an image editor, or with a background-removal model | New outside tools; and 130 pictures to redo each time a sheet is replaced |
| Python with an image library | Not installed here; Godot's `Image` does it, and the project already needs Godot |
| Flood-cut the noir, neon and oil pictures too | Their backgrounds are ink, glow and paint of the same colours as the figures: the flood eats coats and hair |
| Drawn backdrops per place (a pier, a shop, an exchange) | Nobody has drawn them; 46 talks on 7 islands; and the scene itself is already the place, in the island's technique |
| A live blurred view behind each frame | A second render of the scene for a still picture |
| Keep the name in the balloon | Aika: comics do not do that |
| Download a comic font now | A new asset source: Aika's yes first |

## Pros
- Sheets can be replaced: `godot --headless -s tools/cut_portraits.gd` cuts them again with the same corrections.
- Every talk gets the right background for free.

## Risks and costs
- On the sheets the faces stand close and overlap (the captain's hat): a brim that was behind a neighbour is not
  on the sheet at all. It is faded, not restored. Sheets with the faces apart would cut clean.
- The backdrop is whatever the camera saw as the talk began: sometimes a wall.
- Two representations of each portrait in the repository (the cut from the sheet, and the cut-out made from it).
- Mouth positions are one number per sheet, set by eye.

## How to explain it (teaching note)
The portraits show a build step: a source (the sheet's cut), a tool, a product (the cut-out), and the corrections
kept as data beside the tool instead of as edits to the product — so the product can always be made again.

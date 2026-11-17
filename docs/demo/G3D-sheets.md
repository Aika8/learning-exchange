# G3D sheets — Aika's second batch: eleven more faces, the props, the harbour view, a new Chronicler

Fourteen new files (no duplicates by md5) are in `docs/design/concepts/13…26` with rows in `docs/design/README.md`.

## Faces: the stand-ins are gone (all but five)
Eleven expression sheets were cut into 66 portraits. Before: a plain face drawn in code. After: Aika's drawing.

| Before | After |
|---|---|
| ![](g3d-sheets/before-child.jpg) | ![](g3d-sheets/after-child.jpg) |
| ![](g3d-sheets/before-chronicler.jpg) | ![](g3d-sheets/after-chronicler.jpg) |
| ![](g3d-sheets/before-bakery.jpg) | ![](g3d-sheets/after-bakery.jpg) |

More of the new faces:

| The boatswain | The post keeper |
|---|---|
| ![](g3d-sheets/after-sailor2.jpg) | ![](g3d-sheets/after-keeper.jpg) |

| La gardienne | Le libraire |
|---|---|
| ![](g3d-sheets/after-lighthouse.jpg) | ![](g3d-sheets/after-books.jpg) |

Still a stand-in (no sheet): the five strollers of Amber Cliff.

![](g3d-sheets/still-stand-in.jpg)

A portrait now keeps the proportions of its own sheet (before, every face was squeezed to one shape).

## Props rebuilt from "Sheet 10 — Props" (`game3d/scripts/props.gd`)
Built in code, one mesh each, with colliders: the street lamp (turned post, scroll bracket, brass lantern), the market
stall (plank counter, striped awning with scallops), crate, barrel, grandfather's chest (rounded lid, brass bands,
padlock), rope coil, mooring bollards, an anchor by Mara, papers and a little roof on the notice board, brass scales
and a ledger on the first stall, picture signboards on the houses (anchor, quill, coin, sail, loaf).

| Before | After |
|---|---|
| ![](g3d-sheets/before-square.jpg) | ![](g3d-sheets/after-square.jpg) |
| ![](g3d-sheets/before-wharf.jpg) | ![](g3d-sheets/after-wharf.jpg) |
| ![](g3d-sheets/before-pier.jpg) | ![](g3d-sheets/after-pier.jpg) |

## The Chronicler in the world, after the new "Sheet 5"
The old sheet (05) had a cream feather cloak, a blue cape and a red sash; the new one (26) has a layered slate-blue
feather robe, leather belts and an ink bottle. The figure was recoloured and given the bottle.

| Before | After |
|---|---|
| ![](g3d-sheets/before-people.jpg) | ![](g3d-sheets/after-people.jpg) |

## Covered by a sheet but not rebuilt
- "Sheet 9 — Spark Harbour": rope bridges to islets, the waterfall, the mill's wide stepped stone terrace, houses
  packed in a tight cluster. The island was left as it is: moving houses and adding islets changes where people
  walk, and deserves its own change with the audit.
- Sheet 10: the spyglass (the captain already carries one), the silk drying rack (the game's rack was left), the
  rope railing (left).
- The Chronicler's shape (feathered wings as sleeves, the cowl) is the old one in new colours.
- Silk Reach and Amber Cliff still use their old props.

## Checked
- GUT 103 green. `make check-game3d-data`: 102 portraits present.
- World audit of Spark Harbour with the new props: no traps, walk-throughs or stuck villagers. It reported one
  "escape" at the north rim (17.4, −29.5). Looked at: the fence there is whole; the island's outline has a narrow
  tooth and a walker can stand in that nook, 1.8 m past the neighbouring edge, and walk back. It is not from this
  change (no prop is near) — the random walk found it this time. Not fixed here.
- Not played by hand. Frame rate not re-measured with `--fps` after the props (about 20 small meshes were added).

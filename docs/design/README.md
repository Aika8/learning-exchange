# Design — the source of truth for how the world looks

Read this before changing the look of anything in `game3d/` (people, buildings, ships, props). The concept sheets in
`docs/design/concepts/` are Aika's approved designs: **the game follows the sheets, not the other way round.**
Palette, light and world notes: `docs/design/game3d-style.md`. Lore: `docs/lore/world-bible.md`.

> Islands: each island is drawn in a technique of its own — Spark Harbour in pen and ink (the style below), Silk
> Reach as printed silk, Amber Cliff as a French-Belgian album page (one even line, flat colour, a watercolour sky).
> The technique and its colours are a row in `game3d/scripts/island_style.gd` (ADR-0025, 0026, 0028); people and
> the sheets are the same everywhere. Pictures: `docs/demo/G3D-looks.md`, `docs/demo/G3D-amber.md`.
>
> Amber Cliff has **no concept sheet yet**: its town houses (pale plaster, shutters, slate mansard roofs, striped
> awnings), lighthouse and layout were built from the brief in ADR-0028, and its people wear the harbour costumes.
> When sheets arrive, rebuild to match. It is also the one place where **signs carry words** (French): reading them
> is the point of the island.

## Art style (ADR-0024)
Stylised low-poly: flat colours of the palette, meshes built in code, soft light; people read by **silhouette** (hat,
coat, sash), no faces; an ink outline by default and an engraving mode on **V** (`game3d/shaders/ink.gdshader`).
`Style` (`game3d/scripts/style.gd`) is the switch; `--pbr` is the old realistic look. The concept sheets give the
silhouettes and the colours; their pen line is what the ink outline stands for. Pictures: `docs/demo/G3D-style.md`.

**Characters are told apart by outline.** Reference for the feeling, by Aika: the illustrated sky-pirate books of
The Edge Chronicles — principles only (exaggerated proportions, big hats, long noses, layers of clothes and gear, a
pen line), never their characters or drawings. Builds are in `Costume.BUILDS`; give every new role its own.

## Concept sheets (`docs/design/concepts/`)
Ink-and-watercolour sheets drawn by an image model from our own brief (the brief is at the end of this file). Original
world; nothing is copied from a book, film or game. The palette row at the bottom of each sheet is the game palette.

| Sheet | Who | In the game | Code |
|---|---|---|---|
| `01-captain.jpg` | The young captain | the player | `Costume._r_captain` |
| `02-sailors.jpg` | Tall, stocky and old sailor | strollers on the wharf and on Silk Reach | `_r_sailor`, `_r_sailor2`, `_r_sailor3` |
| `03-mara.jpg` | Mara of the Anchor Order | Mara on the wharf (plans the voyage) | `_r_mara` |
| `04-townsfolk.jpg` | Money-changer, Olva, market woman, old man, child | brokers in the hall, Ольва Перо, the post keeper and strollers | `_r_changer`, `_r_olva`, `_r_trader`, `_r_townsman`, `_r_child` |
| `05-chronicler.jpg` | The Chronicler, an owl scholar | the Chronicler on the square (evening chronicle) | `_r_chronicler` |

Not drawn yet (the game still uses designs made without a sheet): the houses kit, the Wind Exchange inside and out,
the ship «Попутчик», the establishing view of Spark Harbour, props. When sheets for these arrive, put them here as
`06-…jpg` and so on, add a row above, and rebuild the thing to match.

## How a sheet becomes a character (`game3d/scripts/costume.gd`)
- A role is one function `_r_<role>` that reads like the sheet: recolour the person's own clothes, then put garments on.
- Garments are simple shapes skinned to one bone each, all one mesh per person: `_open_coat`, `_coat_sleeves`,
  `_waistcoat`, `_sash`, `_breeches`, `_slops`, `_boots`, `_stockings`, `_long_skirt`, `_apron`, `_shawl`, hats
  (`_tricorn`, `_wide_hat`, `_bandana`, `_knit_cap`, `_beret`, `_kerchief`, `_headscarf`), accessories (`_pouch`,
  `_spyglass`, `_medallion`, `_chart`, `_satchel`, `_buckles`).
- People are built whole in code on a small skeleton (`Costume.stand_in`), faceted and faceless; the same role
  function also dresses a MakeHuman person in the `--pbr` look. The Chronicler is an owl with no human under the feathers.
- Check your work against the sheet: `godot --path game3d --resolution 1600x900 -- --people=<dir>` makes the line-up.

## Rules
- Keep to the sheet's silhouette first (hat, coat length, sash, boots), colours second, small detail last.
- Colours come from the palette row on the sheets; no new hues without a reason written in `DECISIONS.md`.
- No user-visible words on clothes or signs (pictograms only), no modern garments, no logos.
- Do not copy characters, ships or towns from existing games, films or books. The sheets are ours; inspiration from the
  age of sail and from old illustrated travel journals is fine.
- A design change that the sheets do not cover is a question for Aika, not a guess.

## The brief the sheets were drawn from
World: people lifted islands into the sky on glowing crystals of etherite and live above a sea of clouds; ships carry
an etherite crystal in a brass cage under the keel and sails of wind silk; Spark Harbour is a small trading town round
the Wind Exchange, a windmill with a glowing price board; age of sail, cosy and a little shabby, never grim.
Style: pen-and-ink line with cross-hatching over flat watercolour, like an antique illustrated travel journal; chunky
readable silhouettes, slightly exaggerated proportions, everything patched and lived-in.
Sheet rules: one sheet per image, 16:9, off-white paper, neutral pose, orthographic front / side / back, hand-written
labels, palette swatches with hex codes. The full prompt (ten sheets) is in `docs/design/concept-prompt.md`.

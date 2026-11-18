# G3D — comic pages, second pass (ADR-0037): before and after, every talk

Aika on the pages of ADR-0027: "cut lines, a strange background, text in strange balloons". Each picture below is one
page: **before on the left, after on the right**. All 46 talks, 53 pages, each taken on the island where it happens.

![](g3d-comic/mara_first-1.jpg)

## What changed
- **Figures are cut out of their paper** by a tool in the project (`game3d/tools/cut_portraits.gd`, Godot's own
  `Image`; hand corrections in `game3d/data/cutouts.json`) and **stand on the frame's lower edge**: no pale box
  behind a face, no bust hanging in the air. The oil portraits of the index island are ovals on a dark mount; the
  noir, neon and robot pictures keep their drawn backgrounds and are shown as cards with a border.
- **The background is the place of the talk**: the scene as it was when the page opened — the island in its own
  technique — made small and soft; each frame shows its own cut. Halftone dots are only a shade in a corner.
- **Balloons are ovals**, the words centred with room round them. **No name inside**: a plate at the foot of
  the frame names somebody once, the first time they are seen. **The tail points at the speaker's mouth** and is
  short. A line said in anger is a zigzag shout. A thought can be a cloud (in the data: a fourth word `"thought"`).
- **Lettering** is larger (20 px, was 17).
- **Composition**: a close shot is taller than its frame, a wide one small with the place round it; of two
  people the listener is a little smaller; every second page is mirrored.

## The lettering: Comic Relief (added after Aika's choice)
`game3d/fonts/comic.ttf` — Comic Relief Regular by Jeff Davis, SIL Open Font License 1.1 (`game3d/fonts/OFL.txt`),
Latin and Cyrillic, from the Google Fonts repository. Left: the system face; right: Comic Relief. It is a wide
face, so balloons of a frame with two speakers are wider, the size is 19 px, and two people in a frame stand a
little lower to leave room over their heads.

![](g3d-comic-font/mara_first-1.jpg)
![](g3d-comic-font/amber_bakery-1.jpg)
![](g3d-comic-font/index_grandpa-1.jpg)

## What is still not right
- **The captain's hat** (and a few shoulders) end in a soft fade at the side where, on the sheet, the next face
  overlaps them: that part of the drawing does not exist. A sheet with the faces apart would cut clean.
- **Islanders with one picture** (noir, crypto, index, race) do not change face; the five strollers of Amber
  Cliff are still stand-ins drawn in code.
- The backdrop is whatever the camera saw: at a door it can be mostly wall.
- No talk uses a thought balloon yet: the shape is there, the words have not been marked.

## Spark Harbour and Silk Reach
`chronicler_day-1`

![](g3d-comic/chronicler_day-1.jpg)

`keeper_first-1`

![](g3d-comic/keeper_first-1.jpg)

`mara_first-1`

![](g3d-comic/mara_first-1.jpg)

`mara_first-2`

![](g3d-comic/mara_first-2.jpg)

`olva_consensus-1`

![](g3d-comic/olva_consensus-1.jpg)

`olva_last-1`

![](g3d-comic/olva_last-1.jpg)

`olva_wait-1`

![](g3d-comic/olva_wait-1.jpg)

`stroll_child-1`

![](g3d-comic/stroll_child-1.jpg)

`stroll_sailor-1`

![](g3d-comic/stroll_sailor-1.jpg)

`stroll_sailor2-1`

![](g3d-comic/stroll_sailor2-1.jpg)

`stroll_sailor3-1`

![](g3d-comic/stroll_sailor3-1.jpg)

`stroll_townsman-1`

![](g3d-comic/stroll_townsman-1.jpg)

`stroll_trader-1`

![](g3d-comic/stroll_trader-1.jpg)

## Amber Cliff (spoken in French)
`amber_bakery-1`

![](g3d-comic/amber_bakery-1.jpg)

`amber_bank-1`

![](g3d-comic/amber_bank-1.jpg)

`amber_bank-2`

![](g3d-comic/amber_bank-2.jpg)

`amber_books-1`

![](g3d-comic/amber_books-1.jpg)

`amber_cafe-1`

![](g3d-comic/amber_cafe-1.jpg)

`amber_change-1`

![](g3d-comic/amber_change-1.jpg)

`amber_change-2`

![](g3d-comic/amber_change-2.jpg)

`amber_enfant-1`

![](g3d-comic/amber_enfant-1.jpg)

`amber_etudiante-1`

![](g3d-comic/amber_etudiante-1.jpg)

`amber_fleuriste-1`

![](g3d-comic/amber_fleuriste-1.jpg)

`amber_lighthouse-1`

![](g3d-comic/amber_lighthouse-1.jpg)

`amber_lighthouse-2`

![](g3d-comic/amber_lighthouse-2.jpg)

`amber_marin-1`

![](g3d-comic/amber_marin-1.jpg)

`amber_monsieur-1`

![](g3d-comic/amber_monsieur-1.jpg)

## The short sellers' island
`shorts_exchange-1`

![](g3d-comic/shorts_exchange-1.jpg)

`shorts_exchange-2`

![](g3d-comic/shorts_exchange-2.jpg)

`shorts_lady-1`

![](g3d-comic/shorts_lady-1.jpg)

`shorts_tramp-1`

![](g3d-comic/shorts_tramp-1.jpg)

`shorts_youth-1`

![](g3d-comic/shorts_youth-1.jpg)

## The crypto island
`bot_info-1`

![](g3d-comic/bot_info-1.jpg)

`bot_miner-1`

![](g3d-comic/bot_miner-1.jpg)

`bot_trader-1`

![](g3d-comic/bot_trader-1.jpg)

`crypto_analyst-1`

![](g3d-comic/crypto_analyst-1.jpg)

`crypto_dreamer-1`

![](g3d-comic/crypto_dreamer-1.jpg)

`crypto_miner-1`

![](g3d-comic/crypto_miner-1.jpg)

`crypto_trader-1`

![](g3d-comic/crypto_trader-1.jpg)

## The index island
`index_child-1`

![](g3d-comic/index_child-1.jpg)

`index_exchange-1`

![](g3d-comic/index_exchange-1.jpg)

`index_exchange-2`

![](g3d-comic/index_exchange-2.jpg)

`index_father-1`

![](g3d-comic/index_father-1.jpg)

`index_grandpa-1`

![](g3d-comic/index_grandpa-1.jpg)

`index_granny-1`

![](g3d-comic/index_granny-1.jpg)

`index_lady-1`

![](g3d-comic/index_lady-1.jpg)

`index_stall-1`

![](g3d-comic/index_stall-1.jpg)

## The race island
`race_aviator-1`

![](g3d-comic/race_aviator-1.jpg)

`race_crew-1`

![](g3d-comic/race_crew-1.jpg)

`race_lady-1`

![](g3d-comic/race_lady-1.jpg)

`race_pit-1`

![](g3d-comic/race_pit-1.jpg)

`race_tower-1`

![](g3d-comic/race_tower-1.jpg)

`race_tower-2`

![](g3d-comic/race_tower-2.jpg)

## Numbers
- GUT: 149 tests, all green (5 new for the page; the old ones still hold).
- 130 cut-outs, 13 MB as lossy WebP with alpha (71 MB as PNG); cutting them all takes about 40 s.
- `make check-game3d-data` now also checks that every portrait has its cut-out.

## How to see it
`godot --path game3d -- --talk=<dir> --island=<island>` saves every page of the talks of that island;
`--only=<talk>` one talk; `--gloss` with T held (the game's language on Amber Cliff).
Cut the portraits again after replacing a sheet: `godot --headless --path game3d -s tools/cut_portraits.gd`.

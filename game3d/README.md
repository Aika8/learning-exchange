# game3d/ — «Летопись Ветров» 3D (Chronicle of Winds 3D)

Second game client: Godot 4.7, 3D, Forward+, typed GDScript (ADR-0017). Same world and rules as `game/`;
style guide: `docs/design/game3d-style.md`; **the look follows the concept sheets: `docs/design/README.md`**. Demo with screenshots: `docs/demo/G3D.md`.

M3 vertical slice (`docs/demo/M3.md`, ADR-0023): one game day — Port → Plan voyage with Mara (risk ≤ 1%, the Anchor =
stop-loss) → Trading on the Ladder → Sailing (the clock runs ×60, a storm) → Evening chronicle with replay. Act I
(debt, provisions, garden, fog), spread/fees/liquidity, the Anchor and a gap, the Forge report season, the captain's
glossary (G), the «Реальный мир» board. Islands: Spark Harbour, Silk Reach, the short sellers' island (a noir town; a place and a style for now, ADR-0030), the crypto island (a neon town in pixel art; likewise, ADR-0031), the index island (a canal town of the Dutch Golden Age in oil paint; likewise, ADR-0035), the race island (the Grand Prix of the Winds as an art-deco poster; likewise, ADR-0034), and Amber Cliff — «La Falaise d'Ambre», where
everything is in French (hold T for the translation; `docs/demo/G3D-amber.md`, ADR-0028).

## Run
1. Godot 4.7 on PATH (`brew install --cask godot`). 2. `make dev`. 3. `make game3d`.
The default look is stylised low-poly built in code (ADR-0024) and needs no downloads. The old PBR look: `make assets`
(once, ~170 MB of CC0 art from Poly Haven; ADR-0019), then `godot --path game3d -- --pbr`.
Without `make assets` the game still runs with the old procedural look.
The MakeHuman people are **not** part of `make assets`: build them with `game3d/tools/people/build.sh` (Blender + MPFB) or
copy `game3d/assets/models/people/` from a checkout that has them; without them dressed stand-in figures are shown.
Other server: `godot --path game3d -- --server=http://localhost:8090`. Keys: WASD, Shift (run), mouse, Tab (fly camera), E (interact),
in flight W/S (sail), A/D (wheel), Space/Shift (up/down), E (moor), G (glossary), T (hold on Amber Cliff: translation), V (look: colour / ink outline / engraving), Enter (close a lesson card), F3 (fps), Esc (release the mouse / leave the hall).

## Tests
`make test-game3d` — GUT headless. `tests/unit/test_world_walk.gd` walks a grid over both islands and the hall: nobody
falls, spawns and spots are free, colliders follow the shapes, villagers stay on the ground; the captain is never
trapped and walks through nothing he can see, villagers can finish their strolls (`docs/demo/G3D-walk.md`).
3D physics is Jolt (`project.godot`): Godot Physics froze walkers on wide flat floors.

## World audit and measurements (`docs/demo/G3D-polish.md`)
`godot --path game3d -- --audit=<dir>` (every problem with a picture, `audit.json`; about a minute, `--only=harbour|silk|hall` for one place), `--views=<dir>` (fixed views),
`--gait=<dir>` (idle, walk, run, a doorstep), `--talk=<dir>` (every talk as comic pages; ADR-0027), `--flight=<dir>` (a voyage steered by the compass; ADR-0032), `--stroll=<dir>` (a walking camera, to look for shimmer), `--read=<dir>` (Amber Cliff's prompts and signs, then with T), `--attune=<dir>` (the island's wind restyling the captain, a frame every 0.1 s; ADR-0025), `--people=<dir>` (line-up of the costumes; `--plain` = as downloaded), `--fps=<file.json>` (run at 1920x1080), `--profile=1` (cost of each
effect). `--sdfgi` turns SDFGI on (off by default: it cost ~9 fps and a long frame after every camera jump).

## Layout
| Path | What |
|---|---|
| `shared/` | Symlinks to `game/scripts/` (locale, exchange_api, market_stream, money, book_model, order_draft) — one implementation for both games |
| `scripts/market_stream_3d.gd` | Autoload: extends the shared stream with the `clock` channel |
| `scripts/session.gd` | Autoload: `--server=`, scene fades, fps overlay, `--demo=` screenshots |
| `scripts/sim_clock.gd`, `flight_model.gd`, `ports.gd`, `board_layout.gd` | Pure logic, covered by GUT: the clock, the rules of free flight (ADR-0032), the islands as the ship sees them |
| `scripts/proc.gd`, `archipelago.gd`, `shaders/` | Procedural art: meshes, sky, light, fog, cloud sea |
| `scripts/core/` | M3 pure logic, covered by GUT: `GameFlow` (state machine), `VoyagePlan` (Mara's check), `DayLog` (day events), `SessionFacts` (fold), `Chronicler` (port + template adapter), `Lessons`, `ReportSeason`, `CaptainGlossary` |
| `scripts/game.gd` | Autoload `Game`: the day, its log, plan, Anchor, sync with the exchange, report-season watch |
| `scripts/ui/` | `GameHud` (flow bar, lesson cards, glossary, report banner), `PlanPanel` |
| `scripts/mover.gd`, `walker.gd`, `captain.gd` | Walking for everybody: acceleration, slopes, stairs (`Mover`); computed gait with foot IK — idle, walk, run (`Walker`); the captain with a spring-arm camera |
| `scripts/island_style.gd` | The technique of each island as data: pen and ink, katazome, pen and watercolour (ADR-0026, 0029) |
| `scripts/style.gd`, `shaders/ink.gdshader` | The art style switch (low-poly by default, `--pbr`) and the ink post-effect (`--ink=0|1|2`, key V) |
| `scripts/costume.gd` | Period dress for the MakeHuman people: re-materials their clothes and adds skinned pieces (roles: captain, sailor, trader, townsman, child) |
| `scripts/nav.gd`, `villager.gd` | Navmesh baked from the colliders; villagers who walk it and steer round each other |
| `scripts/solid.gd`, `kit.gd`, `houses.gd`, `decals.gd`, `hall_room.gd` | Colliders that follow shapes; one mesh per building; modular half-timbered houses; grime decals; the hall interior |
| `scripts/world_probe.gd`, `audit.gd` | The world audit (`WorldProbe`) and its runs |
| `data/talks.json`, `i18n/talk.csv`, `art/portraits/`, `scripts/core/comic_script.gd`, `comic_reader.gd`, `scripts/ui/comic_page.gd`, `comic_frame.gd`, `comic_faces.gd`, `comic_doodle.gd` | Talks as comic pages (ADR-0027): the data and words, the drawn faces (one per hero and emotion), the reader, the page, the stand-in for people without a sheet |
| `scripts/amber_cliff.gd`, `scripts/core/island_tongue.gd`, `i18n/amber.csv` | Amber Cliff, the French-speaking island (ADR-0028): the town, the island's tongue, its words (`fr,ru,en`) |
| `scripts/index_isle.gd` | The index island (ADR-0035): a canal town — gabled brick houses, a canal with bridges, the Exchange, the coin fountain, sky ships |
| `scripts/race_isle.gd` | The race island (ADR-0034): a banked track in the air on brackets, the timing tower, pit boxes, a grandstand, four sky skiffs as decoration |
| `scripts/wayfarer.gd` | The hero's ship «Попутчик» (ADR-0036): the one realistic thing, drawn after the island's technique; hull, rig, stern, figurehead, wing sails, crystal, flag |
| `tools/cut_portraits.gd`, `data/cutouts.json` | Cuts the comic portraits out of their paper into `art/cutouts/` (ADR-0037); the corrections and each sheet's mouth |
| `scripts/monkey.gd`, `scripts/core/monkey_mind.gd` | The ship's monkey: her body, and her decisions as a pure model (in the rig under way, near the captain ashore) |
| `scripts/crypto_isle.gd` | The crypto island (ADR-0031): neon towers, palms, the Exchange That Never Closes, the wind coin, the three robots |
| `scripts/short_isle.gd` | The short sellers' island (ADR-0030): the slab, crooked houses and towers, the Exchange of Falling Prices, its props |
| `scripts/props.gd` | The props of the props sheet built in code: lamp, stall, crate, barrel, chest, rope coil, bollard, anchor, signboards |
| `scripts/chronicle.gd`, `scripts/demo.gd` | Evening chronicle scene; the self-run demo for screenshots |
| `scripts/main_menu.gd`, `harbour.gd`, `captain.gd`, `hall.gd`, `board.gd`, `voyage.gd` | Scenes (`scenes/*.tscn` are a root node + script) |

## Rules
Same as `game/`: no user-visible literals (keys in `i18n/strings.csv`, ru + en together); scenes never touch HTTP or the
socket, only the autoloads do; money is integer minor units. Windows: clone with `git config core.symlinks true`.

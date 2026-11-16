# game3d/ — «Летопись Ветров» 3D (Chronicle of Winds 3D)

Second game client: Godot 4.7, 3D, Forward+, typed GDScript (ADR-0017). Same world and rules as `game/`;
style guide: `docs/design/game3d-style.md`. Demo with screenshots: `docs/demo/G3D.md`.

M3 vertical slice (`docs/demo/M3.md`, ADR-0023): one game day — Port → Plan voyage with Mara (risk ≤ 1%, the Anchor =
stop-loss) → Trading on the Ladder → Sailing (the clock runs ×60, a storm) → Evening chronicle with replay. Act I
(debt, provisions, garden, fog), spread/fees/liquidity, the Anchor and a gap, the Forge report season, the captain's
glossary (G), the «Реальный мир» board. Two islands: Spark Harbour and Silk Reach.

## Run
1. Godot 4.7 on PATH (`brew install --cask godot`). 2. `make dev`. 3. `make assets` (once, ~170 MB of CC0 art from Poly Haven, MD5-checked; ADR-0019). 4. `make game3d`.
Without `make assets` the game still runs with the old procedural look.
The MakeHuman people are **not** part of `make assets`: build them with `game3d/tools/people/build.sh` (Blender + MPFB) or
copy `game3d/assets/models/people/` from a checkout that has them; without them dressed stand-in figures are shown.
Other server: `godot --path game3d -- --server=http://localhost:8090`. Keys: WASD, Shift (run), mouse, Tab (fly camera), E (interact),
Space (sail during the voyage), G (glossary), Enter (close a lesson card), F3 (fps), Esc (release the mouse / leave the hall).

## Tests
`make test-game3d` — GUT headless. `tests/unit/test_world_walk.gd` walks a grid over both islands and the hall: nobody
falls, spawns and spots are free, colliders follow the shapes, villagers stay on the ground.

## World audit and measurements (`docs/demo/G3D-polish.md`)
`godot --path game3d -- --audit=<dir>` (every problem with a picture, `audit.json`), `--views=<dir>` (fixed views),
`--gait=<dir>` (idle, walk, run, a doorstep), `--people=<dir>` (line-up of the costumes; `--plain` = as downloaded), `--fps=<file.json>` (run at 1920x1080), `--profile=1` (cost of each
effect). `--sdfgi` turns SDFGI on (off by default: it cost ~9 fps and a long frame after every camera jump).

## Layout
| Path | What |
|---|---|
| `shared/` | Symlinks to `game/scripts/` (locale, exchange_api, market_stream, money, book_model, order_draft) — one implementation for both games |
| `scripts/market_stream_3d.gd` | Autoload: extends the shared stream with the `clock` channel |
| `scripts/session.gd` | Autoload: `--server=`, scene fades, fps overlay, `--demo=` screenshots |
| `scripts/sim_clock.gd`, `voyage_model.gd`, `board_layout.gd` | Pure logic, covered by GUT |
| `scripts/proc.gd`, `archipelago.gd`, `shaders/` | Procedural art: meshes, sky, light, fog, cloud sea |
| `scripts/core/` | M3 pure logic, covered by GUT: `GameFlow` (state machine), `VoyagePlan` (Mara's check), `DayLog` (day events), `SessionFacts` (fold), `Chronicler` (port + template adapter), `Lessons`, `ReportSeason`, `CaptainGlossary` |
| `scripts/game.gd` | Autoload `Game`: the day, its log, plan, Anchor, sync with the exchange, report-season watch |
| `scripts/ui/` | `GameHud` (flow bar, lesson cards, glossary, report banner), `PlanPanel` |
| `scripts/mover.gd`, `walker.gd`, `captain.gd` | Walking for everybody: acceleration, slopes, stairs (`Mover`); computed gait with foot IK — idle, walk, run (`Walker`); the captain with a spring-arm camera |
| `scripts/costume.gd` | Period dress for the MakeHuman people: re-materials their clothes and adds skinned pieces (roles: captain, sailor, trader, townsman, child) |
| `scripts/nav.gd`, `villager.gd` | Navmesh baked from the colliders; villagers who walk it and steer round each other |
| `scripts/solid.gd`, `kit.gd`, `houses.gd`, `decals.gd`, `hall_room.gd` | Colliders that follow shapes; one mesh per building; modular half-timbered houses; grime decals; the hall interior |
| `scripts/world_probe.gd`, `audit.gd` | The world audit (`WorldProbe`) and its runs |
| `scripts/chronicle.gd`, `scripts/demo.gd` | Evening chronicle scene; the self-run demo for screenshots |
| `scripts/main_menu.gd`, `harbour.gd`, `captain.gd`, `hall.gd`, `board.gd`, `voyage.gd` | Scenes (`scenes/*.tscn` are a root node + script) |

## Rules
Same as `game/`: no user-visible literals (keys in `i18n/strings.csv`, ru + en together); scenes never touch HTTP or the
socket, only the autoloads do; money is integer minor units. Windows: clone with `git config core.symlinks true`.

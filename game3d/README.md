# game3d/ — «Летопись Ветров» 3D (Chronicle of Winds 3D)

Second game client: Godot 4.7, 3D, Forward+, typed GDScript (ADR-0017). Same world and rules as `game/`;
style guide: `docs/design/game3d-style.md`. Demo with screenshots: `docs/demo/G3D.md`.

Vertical slice: main menu (ru/en) → Spark Harbour (walk or fly) → Exchange hall (live order book on a 3D board,
limit and market orders) → voyage to Silk Reach while the exchange's simulation clock runs.

## Run
1. Godot 4.7 on PATH (`brew install --cask godot`). 2. `make dev`. 3. `make assets` (once, ~170 MB of CC0 art from Poly Haven, MD5-checked; ADR-0019). 4. `make game3d`.
Without `make assets` the game still runs with the old procedural look.
Other server: `godot --path game3d -- --server=http://localhost:8090`. Keys: WASD, mouse, Tab (fly camera), E (interact),
Space (sail during the voyage), F3 (fps), Esc (release the mouse / leave the hall).

## Tests
`make test-game3d` — GUT headless.

## Layout
| Path | What |
|---|---|
| `shared/` | Symlinks to `game/scripts/` (locale, exchange_api, market_stream, money, book_model, order_draft) — one implementation for both games |
| `scripts/market_stream_3d.gd` | Autoload: extends the shared stream with the `clock` channel |
| `scripts/session.gd` | Autoload: `--server=`, scene fades, fps overlay, `--demo=` screenshots |
| `scripts/sim_clock.gd`, `voyage_model.gd`, `board_layout.gd` | Pure logic, covered by GUT |
| `scripts/proc.gd`, `archipelago.gd`, `shaders/` | Procedural art: meshes, sky, light, fog, cloud sea |
| `scripts/main_menu.gd`, `harbour.gd`, `captain.gd`, `hall.gd`, `board.gd`, `voyage.gd` | Scenes (`scenes/*.tscn` are a root node + script) |

## Rules
Same as `game/`: no user-visible literals (keys in `i18n/strings.csv`, ru + en together); scenes never touch HTTP or the
socket, only the autoloads do; money is integer minor units. Windows: clone with `git config core.symlinks true`.

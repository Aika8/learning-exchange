# game/ — «Летопись Ветров» (Chronicle of Winds)

Godot 4.7 project, typed GDScript (ADR-0011). M1 slice: main menu (ru/en on the fly) → Spark Harbour → the Ladder:
the live order book of the exchange, limit and market orders, fills. Placeholder art, one palette (`scripts/ui.gd`).
Lore: `docs/lore/`. Real finance terms lead every label; lore names are small captions (ADR-0012).

## Run
1. Godot 4 (latest stable) on PATH: `brew install --cask godot`.
2. `make dev` in the repo root (exchange + bots on http://localhost:8080).
3. `make game` — or open `game/project.godot` in the Godot editor and press F5.

After adding a script with `class_name`, run `godot --headless --path . --import` once (the make targets do it).

## Tests
`make test-game` — GUT 9.7.1 headless (`addons/gut`, vendored): money, book model, order form, stream/REST parsing,
i18n (every key in ru and en, every key used in code exists, every contract error code is translated).

## Layout
| Path | What |
|---|---|
| `scripts/exchange_api.gd` | Autoload: REST gateway to `api/openapi.yaml` |
| `scripts/market_stream.gd` | Autoload: WebSocket, channels of `api/asyncapi.yaml`, signals for scenes |
| `scripts/locale.gd` | Autoload: message catalogue `i18n/strings.csv`, `locale_changed` signal (ADR-0014) |
| `scripts/money.gd`, `book_model.gd`, `order_draft.gd` | Pure logic, covered by GUT; money is integer minor units |
| `scripts/main_menu.gd`, `harbour.gd`, `ladder.gd` | Scenes (`scenes/*.tscn` are a root node + script; UI is built in code) |
| `scripts/demo.gd` | `godot --path . -- --demo=<dir> [--name=Captain]`: self-run with screenshots |

## Rules
- No user-visible literals in scripts: keys from `i18n/strings.csv`, both languages in the same commit.
- Scenes never touch the socket or HTTP: only the two autoloads do.

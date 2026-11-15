Learning exchange: a simulated market where a person learns trading by doing.
Bots make the market move; an AI assistant explains the consequences of each decision.
Never connected to a real market. Built as a one-year learning project.

## Layout (ADR-0009)

| Folder | What | Status |
|---|---|---|
| `backend/engine` | Framework-free engine: order book, accounts, reservation, fees, events, stops, leverage, deposits | M2a |
| `backend/application` | Use cases and ports: sequencer, simulation clock, journal port | M1 |
| `backend/bots` | Market maker and noise bots from `bots.yaml` | M1 |
| `backend/app` | Spring Boot: REST, WebSocket, JSON-lines journal | M1 |
| `backend/repl` | Console REPL over the bare order book | M0 |
| `api/` | OpenAPI 3.1 / AsyncAPI 3 contract | M1 |
| `clients/web/` | React debug client | M1 |
| `clients/mobile/` | Expo app «Ветрило» | M1 |
| `game/` | Godot 4 game «Летопись Ветров» | M1 slice: menu → harbour → Ladder (`make game`) |
| `game3d/` | Godot 4 game «Летопись Ветров» in 3D (ADR-0017) | Slice: menu → harbour → hall with the live book → voyage (`make game3d`) |
| `docs/`, `intent/` | ADRs, lore, design, prompts, intents | — |

## How to run each part

Requires Java 25 and Node 22+. Gradle finds an installed JDK 25; if there is none it downloads one (foojay toolchain resolver).

- Backend with bots: `make dev` → http://localhost:8080 (`/api/v1`, WebSocket `/ws`). `make reset` deletes the journal.
- Web client: `make web` → http://localhost:5173 (see `clients/web/README.md`).
- Mobile: `make mobile` (Expo; `i` for iOS simulator) or `make mobile-web` → http://localhost:8081 (see `clients/mobile/README.md`).
- All tests: `make test`; backend only `./gradlew test`; web E2E `make e2e` (with `make dev` running).
- Order-book REPL from increment 1: `make repl`.
- Bots: edit `bots.yaml`. Contract: `api/README.md`.

Demo script for the current milestone: `docs/demo/M2a.md` (earlier: `M1.md`). State of things: `docs/STATUS.md`.

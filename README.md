Learning exchange: a simulated market where a person learns trading by doing.
Bots make the market move; an AI assistant explains the consequences of each decision.
Never connected to a real market. Built as a one-year learning project.

## Layout (ADR-0009)

| Folder | What | Status |
|---|---|---|
| `backend/engine` | Framework-free matching engine (order book) | M0 |
| `backend/repl` | Console REPL over the engine | M0 |
| `api/` | OpenAPI / AsyncAPI contract | M1 |
| `clients/web/` | React debug client | M1 |
| `clients/mobile/` | Expo app «Ветрило» | M1 |
| `game/` | Godot 4 game «Летопись Ветров» | M1 |
| `docs/`, `intent/` | ADRs, lore, design, prompts, intents | — |

## How to run each part

Requires Java 25. Gradle finds an installed JDK 25; if there is none it downloads one (foojay toolchain resolver).

- All tests: `make test` (or `./gradlew test`).
- Engine tests only: `./gradlew :backend:engine:test`.
- REPL: `make dev` — commands `buy|sell <qty>[@<price>]`, `cancel <id>`, `book`, `quit`.
- Clients and game: not yet; see each folder's README.

Demo script for the current milestone: `docs/demo/M0.md`.

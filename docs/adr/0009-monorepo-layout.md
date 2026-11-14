# 0009. Monorepo with one folder per deployable, walking skeleton first

- Status: Accepted
- Date: 2026-11-12
- Pattern(s): Monorepo, Walking Skeleton (Alistair Cockburn), Vertical slices

## Context
The contract, backend and three clients change together during early development. Aika wants something working end-to-end immediately.

## Decision
```
api/            openapi.yaml, asyncapi.yaml (ADR-0003)
backend/        Gradle multi-module: engine, application, adapters, bff-mobile, bff-game, bots, app (Spring Boot)
clients/web/    React + Vite + TypeScript debug client
clients/mobile/ Expo (React Native) app «Ветрило»
game/           Godot 4 project «Летопись Ветров»
docs/           adr/, lore/, design/ (tokens from Gemini), prompts/
intent/         intents per increment
```
- First milestone is a **walking skeleton**: one instrument, place/see orders from web, mobile and game against a running backend with bots.
  Every later milestone deepens all layers instead of finishing one layer at a time.
- `make dev` (or `./dev.sh`) starts the backend with bots; each client has its own run command in the README.

## Why this and not the alternatives
| Alternative | Why not |
|---|---|
| Repo per client | Contract changes need coordinated PRs across repos |
| Backend first, clients later | Nothing to touch for weeks; integration problems discovered late |

## Pros
- One change can update contract + server + clients atomically.
- Always-demoable product.

## Risks and costs
- Mixed toolchains (Gradle, npm, Godot) in one repo; CI must run them selectively by path.
- Skeleton code is thin and tempting to leave thin — each milestone has acceptance tests per layer.

## How to explain it
"We built a thin end-to-end path through every layer first, then thickened it. Integration risks show up on day one."

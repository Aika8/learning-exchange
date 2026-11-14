# 0011. Game engine: Godot 4

- Status: Accepted
- Date: 2026-11-12
- Pattern(s): inside the game — Scene composition, Signals (Observer), State machine for game flow, Autoload singletons for services

## Context
A 2D/isometric trading RPG for PC (`docs/lore/world-bible.md`) connected to the exchange over HTTP + WebSocket.
It is written by an AI agent, so files must be text and diff-friendly; it must run on macOS and Windows.

## Decision
- Godot 4 (latest stable), GDScript with static typing. Desktop exports for macOS/Windows/Linux.
- Network layer as autoloads: `ExchangeApi` (HTTPRequest over the game BFF), `MarketStream` (WebSocketPeer).
- Game flow as a state machine (Port → Plan voyage → Trading → Sailing → Evening chronicle).
- The Ladder (order book) is a scene driven only by server data.
- Placeholder art first (simple shapes + one palette), art pass later.
- Tests: GUT (Godot Unit Test) for game logic; headless run in CI.

## Why this and not the alternatives
| Alternative | Why not |
|---|---|
| Unity | Binary-ish scenes/metadata, licensing history, heavier for a 2D game |
| Unreal | 3D-first, C++; far more than we need |
| Web game (Phaser/PixiJS) + Electron/Tauri | Viable and shares TS; less of a "real PC game" feel and weaker tooling for maps/animation |

## Pros
- Free and open source, small, fast to start.
- `.tscn`/`.gd` are plain text — reviewable diffs, AI-friendly.
- Built-in WebSocket and HTTP.

## Risks and costs
- GDScript is yet another language; static typing and small scripts keep it readable.
- Asset pipeline (art, music) is the real bottleneck, not code.

## How to explain it
"Godot because the game is 2D, the scene files are text that agents can edit and review, and it has networking built in."

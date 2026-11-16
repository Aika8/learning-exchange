# 0023. game3d M3: the day as a client-side state machine and an append-only day log; SessionFacts are a fold over it

- Status: Accepted (M3)
- Date: 2026-11-16
- Pattern(s): State machine, Event Sourcing (client-side day log), Projection, Port & Adapter + Fallback (ADR-0013)

## Context
M3 turns the 3D client into a game: Port → Plan voyage → Trading → Sailing → Evening chronicle (ADR-0011), an evening
review from computed `SessionFacts` (ADR-0013) and «Перечитать летопись» — replay the day. The exchange already keeps
the money truth (journal, statement, conditional orders). What it does not know is the *game*: which trade was which
voyage, what risk Mara approved, which lessons the player met, where the storm and the report night happened.
ADR-0013 left open where `SessionFacts` are computed. The contract should not grow for a single client unless needed.

## Decision
- `GameFlow` (`game3d/scripts/core/game_flow.gd`) is the state machine of the day. Guards live in it, not in scenes:
  no plan without provisions (Act I cushion), no trading without Mara's approval (risk ≤ 1% of the trading capital,
  stop below entry), no leaving port with cargo and no Anchor (stop-loss).
- `DayLog` (`core/day_log.gd`) is an append-only list of game events for one game day, saved in `user://`.
  Money facts come from the exchange and are *copied* into it: statement lines become `FILL` events (keyed by
  `ts`/`refId`, so a re-sync adds nothing twice), fired stops become `STOP_FIRED`, prices become `MARK`.
- `SessionFacts` (`core/session_facts.gd`) is a pure fold over the log: R per voyage, expectancy, fees and spread paid,
  gaps through the stop, the day's return against Бабушка Ветла's basket (the index fund `IDX-SPARK`), lessons met.
  The same fold over the first *n* events is the replay, so replay and review can't disagree.
- `Chronicler` (`core/chronicler.gd`) is the port; `TemplateChronicler` is the only adapter in M3. It returns
  message keys with typed numbers, never computed text, so the language switches on the fly. The LLM adapter is M4.
- No contract change. Seven glossary terms were added to `docs/lore/glossary.yaml` (data, same schema).

## Why this and not the alternatives
| Alternative | Why not (now) |
|---|---|
| `SessionFacts` on the server (`/session-review` grows) | The server would need game notions (voyage, approved risk, lessons); the contract grows for one client. Kept as an option for M4 when the LLM adapter lives server-side. |
| Replay by re-running the exchange journal | Correct but heavy: needs a second exchange instance; the player wants to re-read *their* day, not the whole market. |
| State as booleans in each scene | Guards duplicated and skippable; impossible to test without scenes. |

## Pros
- The loop, the facts and the replay are unit-tested headless (GUT) without a server.
- One source of truth per concern: money on the exchange, the story of the day in the log.

## Risks and costs
- The log can drift from the exchange if a sync is missed; facts show only what was synced. The chronicle syncs once
  more before it renders, and fills are idempotent by key.
- `user://` is per machine: the day log does not follow the account to another computer (fine for a learning slice).

## How to explain it (teaching note)
"The exchange is the bank's ledger; the game keeps a diary of the day. The review is a fold over the diary — the same
fold, stopped half-way, is the replay. The rules of the day are a state machine, so no scene can skip Mara's check."

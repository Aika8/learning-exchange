# 0005. Event-sourced journal as the source of truth

- Status: Proposed
- Date: 2026-11-12
- Pattern(s): Event Sourcing, CQRS (light), Snapshot, Append-only log

## Context
Increment 1 promised "journal comes in the next increment". Financial systems need an audit trail.
The game wants "re-read the Chronicle" (replay a day), and the assistant needs the full history to explain what happened.

## Decision
- Every accepted command produces domain events (`OrderAccepted`, `TradeExecuted`, `OrderCancelled`, `FundsTransferred`,
  `StopTriggered`, `PositionLiquidated`, `InterestAccrued`, `ClockAdvanced`…).
- Events are appended to a journal (port `Journal`; adapter: append-only JSON-lines file per run; later Postgres).
- State is rebuilt by replaying events; snapshots every N events speed up start.
- Read models (statements, candles, leaderboards) are projections built from events — separate from the write model.
- Engine stays deterministic: same events in → same state out (Invariant 4 of intent 02).

## Why this and not the alternatives
| Alternative | Why not |
|---|---|
| CRUD tables with current state only | No history, no replay, audit added later and incomplete |
| Event sourcing with Kafka/EventStoreDB | Infrastructure before need; file journal teaches the same idea |

## Pros
- Full audit trail, replay, time travel for the game, data for the assistant.
- Projections can be added later without migrations.

## Risks and costs
- Event schema evolution: old events must still replay. Events are versioned; upcasters when needed.
- Eventual consistency of read models; acceptable for statements, not for balances used in risk checks (those live in the write model).
- More concepts to learn — that is also the point.

## How to explain it
"We don't store balances, we store what happened. Balances are a fold over events.
That gives us an audit trail and replay for free, at the cost of schema versioning."

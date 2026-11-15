# 0017. One writer for the whole exchange, not one per instrument (amends 0006)

- Status: Accepted (M2a)
- Date: 2026-11-15
- Pattern(s): Single Writer

## Context
ADR-0006 planned one sequencer thread per instrument. M1 had one instrument, so one sequencer for the whole `Exchange`
was the same thing. M2a adds a second instrument (`AMBER-SPARK`) and rules that cross instruments and accounts: one
SPARK balance pays for both markets, leveraged positions borrow from a shared bank account, a fired stop or a stop-out
must act inside the same step as the trade that caused it (ADR-0008).

## Decision
Keep **one** `Sequencer` owning the whole `Exchange` (ledger, both books, conditional orders, positions, deposits).
Every command, on any instrument, is processed in one global order. The per-instrument part of ADR-0006 is superseded;
the rest (single writer, injected clock) stands.

## Why this and not the alternatives
| Alternative | Why not (now) |
|---|---|
| One sequencer per instrument + a ledger actor for balances | Needs a reservation protocol between threads (a two-step "reserve then match"), and cascades across instruments become asynchronous. Real exchanges do this, but the load here is a few hundred commands a second |
| Locks per account | Brings back the races ADR-0006 removed |

## Pros
- Deterministic replay stays trivial: the journal order is the processing order.
- Cross-instrument money and stop-out need no distributed protocol.

## Risks and costs
- Throughput is one core. We notice it when command latency grows under bots; then split per instrument with a ledger actor.

## How to explain it
"One thread owns all the state, so nothing needs a lock and replay is exact. We'd split it per instrument only when one
core is not enough — and then balances need their own owner and a reservation protocol."

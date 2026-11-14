# 0006. Single writer per instrument and a simulation clock

- Status: Accepted
- Date: 2026-11-12
- Pattern(s): Single Writer Principle (LMAX), Actor-like command queue, Clock abstraction (testable time)

## Context
Intent 01 left open how the engine is protected from concurrent access. Now humans, bots, stop triggers and
liquidations all submit orders at once. Locks around the book are error-prone and make matching nondeterministic.
The game needs pause and speed-up; tests need controlled time.

## Decision
- Each instrument has one sequencer thread that owns its book; commands go through a queue and are processed one at a time.
  Callers get a `CompletableFuture` with the result. Java 25 virtual threads for I/O around it.
- Cross-instrument operations (balances) go through an account ledger that reserves funds before an order reaches the book.
- Time comes only from a `Clock` port: `SystemClock` in prod demo, `SimulationClock` with pause/speed in the game world,
  `ManualClock` in tests. The engine never calls `Instant.now()`.
- First, a test that demonstrates the race on the current `OrderBook` (as intent 01 required), then the sequencer.

## Why this and not the alternatives
| Alternative | Why not |
|---|---|
| `synchronized` / locks on the book | Easy to get wrong, hard to reason about fairness |
| Disruptor (LMAX) library | Excellent, but overkill until we measure a need |
| Actor framework (Akka/Pekko) | Big dependency for one idea |

## Pros
- Matching stays single-threaded and deterministic, exactly as in increment 1.
- Real exchanges work this way — good teaching point.

## Risks and costs
- One slow command blocks its instrument. Commands must be pure in-memory; I/O (journal) is batched after.
- Funds reservation across instruments is the tricky part — covered by property-based tests.

## How to explain it
"Only one thread ever touches an order book; everybody else sends it messages. That removes locking from matching.
Time is injected, so the game can pause and tests are deterministic."

# Intent: in-memory order book and matching engine
Author: Aika. Status: draft.

## Problem
A beginner's first trade is blind: they pick a familiar, cheap stock, never
look at the market, and have no plan after buying. To make those mistakes
visible, the platform needs a market where an order has a consequence.
Nothing else in the product can be built or tested without it.

## Proposed outcome
One instrument. Limit and market orders on both sides, price-time priority,
partial fills, cancel by id. Trades are produced with the resting order's
price. Deterministic, single-threaded, no persistence, no API.

## Affected users and systems
None yet. Consumers later: account/positions, bots, REST, assistant.

## Constraints
Java 25, Gradle, JUnit 5. Engine and tests are written by the agent from
this intent; Aika reviews DECISIONS.md and tests behaviour via the REPL.
In-memory only by design
(journal comes in the next increment).

## Out of scope
Accounts, positions, money, bots, REST, persistence, multiple instruments,
news, assistant, UI.

## Open questions
What "learned to trade" means for a user — unknown, to be discovered by
building. How the engine will be protected from concurrent access (a test
proving the race comes first, then the decision).

## Invariants
1. At the same price, the earlier order executes first.
2. A limit order never executes at a price worse than its limit.
3. The book is never crossed: best bid is always strictly lower than best ask.
4. Only priced orders rest in the book; an unfilled market-order remainder is cancelled.
5. A cancelled order is not in the book and never executes again.
6. An empty price level is removed; the best price is always backed by real quantity.
7. Filled quantity never exceeds order quantity; remaining = quantity − filled.

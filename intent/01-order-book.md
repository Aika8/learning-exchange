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
Java 25, Gradle, JUnit 5. Package `engine` and its tests are written by
Aika; the agent does not create or edit them. In-memory only by design
(journal comes in the next increment).

## Out of scope
Accounts, positions, money, bots, REST, persistence, multiple instruments,
news, assistant, UI.

## Open questions
What "learned to trade" means for a user — unknown, to be discovered by
building. How the engine will be protected from concurrent access (a test
proving the race comes first, then the decision).

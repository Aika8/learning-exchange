# 0008. Stop orders and stop-out live outside the book

- Status: Accepted (M2a)
- Date: 2026-11-12, accepted 2026-11-15
- Pattern(s): Observer (trade prices), State machine (conditional order lifecycle), Command (generated orders)

## Context
In QUIK (vault: `finance/stop-loss-take-profit.md`) conditional orders are kept by the broker server, not by the exchange.
They trigger on the **last trade price**, then submit an ordinary order that may not fill (gap). Stop-out for leveraged
positions is the same idea: an outside component that submits a closing order.

## Decision
- Conditional orders (`engine.Conditional`) are kept **outside the order book**: the book still holds only priced orders.
  Kinds: stop-limit, stop-market, trailing take-profit (QUIK style: arms at the TP level, follows the best price, fires on a
  pull-back larger than the offset, limit price = break price ∓ protective spread), and TP+SL (OCO: once the TP armed,
  the stop is no longer checked).
- Each conditional order is a state machine: `WAITING → ARMED (trailing) → TRIGGERED`, or `CANCELLED`. After the trigger
  the visible state follows the generated order: `SUBMITTED | PARTIALLY_FILLED | FILLED | UNFILLED | REJECTED`.
  "Triggered" never means "closed" — the UI shows both.
- The margin monitor (stop-out) does the same for leveraged positions: when equity, valued at the last trade price,
  falls to 50% of the collateral it closes the position with a market order and repays the bank.
- **Where they run (decided at implementation):** both live inside `engine.Exchange` and run on the same single writer,
  not as separate services calling `TradingService`. Every trade price goes into a queue; after each command the queue is
  drained, each price is shown in order to the conditional orders and the margin monitor, and the orders they generate go
  through the same risk check, reservation and fees as a person's order (`placeInto`). Generated orders, triggers and
  stop-outs are journalled as *consequences* of the command that caused them, so replay reproduces the cascade exactly.

## Why this and not the alternatives
| Alternative | Why not |
|---|---|
| Stops inside the order book | Breaks engine invariants (only priced orders rest), unrealistic |
| Trigger on best bid/ask | Not how QUIK works; loses the "why didn't my stop fire" lesson |
| A separate service listening to events and calling `TradingService` | The stop would act one command later, other orders could slip in between, and stop-out could no longer guarantee "before 50%". Replay would need to know which orders were generated. Same pattern, but asynchronous; it can come back if stops ever move to their own process |

## Pros
- The book stays small and its invariants intact.
- Realistic failure modes (gaps, unfilled stop-limit, rejected stop without money) become teachable moments.
- Deterministic cascades: same journal → same stops fired → same state (property-tested).

## Risks and costs
- Ordering: a trade can trigger stops that create trades that trigger more stops (cascade). It runs inside one command;
  a guard stops a runaway loop (`CASCADE_LIMIT`). `ConditionalOrdersTest.stopsCascadeWithinOneCommand` covers it.
- A big cascade blocks the writer for its duration — acceptable at learning scale.
- Stop-out sells at market: in a thin book the fill can be far below the trigger (gap), and the loan may not be fully
  repaid (`badDebt`, carried by the bank). That is the real-world risk, shown in the statement.

## How to explain it
"A stop is a rule watching the trade tape, not an order in the book. When it fires it sends a normal order — which may still not fill."

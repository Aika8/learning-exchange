# 0008. Stop orders and stop-out live outside the book

- Status: Proposed
- Date: 2026-11-12
- Pattern(s): Observer (trade stream), State machine (order lifecycle), Command (generated orders)

## Context
In QUIK (vault: `finance/stop-loss-take-profit.md`) conditional orders are kept by the broker server, not by the exchange.
They trigger on the **last trade price**, then submit an ordinary order that may not fill (gap). Stop-out for leveraged
positions is the same idea: an outside component that submits a closing order.

## Decision
- `ConditionalOrderService` subscribes to `TradeExecuted` events per instrument and keeps stop-limit, stop-market,
  trailing take-profit and TP+SL (OCO) orders.
- Each conditional order is a state machine: `WAITING → ARMED (trailing) → TRIGGERED → SUBMITTED → FILLED | PARTIALLY_FILLED | UNFILLED`.
  "Triggered" never means "closed" — the UI shows both.
- `MarginMonitor` checks leveraged positions on every trade and force-closes at 50% collateral loss with a market order.
- Both submit through the same `TradingService` port (they are clients too).

## Why this and not the alternatives
| Alternative | Why not |
|---|---|
| Stops inside the order book | Breaks engine invariants (only priced orders rest), unrealistic |
| Trigger on best bid/ask | Not how QUIK works; loses the "why didn't my stop fire" lesson |

## Pros
- Engine stays small and its invariants intact.
- Realistic failure modes (gaps, unfilled stop-limit) become teachable moments.

## Risks and costs
- Ordering: a trade can trigger stops that create trades that trigger more stops (cascade). Processed in sequence on the
  instrument's single writer; a test covers a cascade.

## How to explain it
"A stop is a rule watching the trade tape, not an order in the book. When it fires it sends a normal order — which may still not fill."

# 0015. Real market data as a read-only feed, with paper trading

- Status: Proposed
- Date: 2026-11-12
- Pattern(s): Adapter (behind a `RealMarketData` port), Cache-aside, Circuit breaker / graceful degradation, Anti-corruption layer

## Context
Aika: "where possible, show real data everywhere so a person who starts trading for real isn't confused".
The simulated markets (bots) stay the place for consequences; real quotes show what the actual market looks like.
Free real-time exchange data is often licensed; official daily rates are usually public.

## Decision
- Port `RealMarketData` with `quotes(instruments)` and `history(instrument, period)`; adapters chosen at implementation time
  after checking each source's terms of use:
  - National Bank of Kazakhstan official rates (daily, public) — expected baseline for USD/KZT, EUR/KZT, RUB/KZT, CNY/KZT;
  - National Bank of Kazakhstan base rate and its published decision calendar (economic calendar, world bible §5b);
  - KASE public data (delayed/end-of-day) if its terms allow programmatic use;
  - a `StaticSampleData` adapter (recorded data in the repo) for offline demos and tests.
- Real instruments are marked `source: REAL` in the catalogue and are **read-only**: no orders into the engine.
  Users can open **paper positions** on them (tracked in a separate projection, P&L at real prices, clearly labelled «Учебная позиция»).
- Data is cached server-side; on source failure, the circuit breaker opens and clients see "data as of <time>".
- Every screen with real data shows source and timestamp.

## Why this and not the alternatives
| Alternative | Why not |
|---|---|
| Scrape a bank's website | Terms of use, brittle, impersonation risk |
| Paid real-time feed | Cost and licence for a learning project |
| Feed real prices into the simulated book | Bots would trade "real" prices with fake liquidity — misleading |

## Pros
- Real-world anchoring without real-money risk.
- Clear separation: simulated market = consequences, real market = reference.

## Risks and costs
- Source terms may forbid redistribution — then only the official NBK rate and recorded samples are shown.
- Delayed data mistaken for live — always show timestamp and "delayed" badge.

## How to explain it
"Real data comes through a port with swappable adapters, cached and protected by a circuit breaker.
It's read-only — we never mix real prices into the simulated order book."

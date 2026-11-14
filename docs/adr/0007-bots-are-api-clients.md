# 0007. Bots are ordinary clients with pluggable strategies

- Status: Accepted
- Date: 2026-11-12
- Pattern(s): Strategy, Observer (market data subscription), Template Method (bot lifecycle), Factory (from config)

## Context
The market must be alive without humans. Bots also teach: the market maker earns the spread, the index bot beats most
active traders, the momentum bot shows the leverage trap. Invariant: bots have no privileges.

## Decision
- A `TradingBot` runs a loop: observe market data → `Strategy.decide(view)` → submit commands through the same
  `TradingService` port a human uses. Each bot has its own account and pays fees.
- Strategies: `MarketMaker` (quotes around fair value with a spread), `Momentum`, `MeanReversion`, `IndexInvestor`
  (buys a basket on a schedule, never sells), `Noise`, `NewsReactor` (reacts to world events), `Fundamentalist` (values a company from its published reports, buys below / sells above its estimate).
- A `CorporateEvents` generator publishes, per company per season, a consensus estimate and then a report (revenue, profit, EPS, debt, cash flow, dividend, guidance)
  derived from hidden company fundamentals; the report surprise drives an opening gap. Reports are published while the market is closed.
  It also publishes dividend record/ex-dates (price adjusts by the dividend at the open of the ex-date) and insider trade disclosures
  (insiders buy more often before good hidden news; sales are mostly noise — mirroring research).
- A `MacroEvents` generator runs the central bank («Совет Казначеев»): a published calendar of 8 rate decisions a year with consensus,
  an inflation series, and effects on deposit rates, bond prices (via duration) and the FX pair.
- Strategies also include `ActiveFund` (high-fee active manager, for the TER comparison) and `BondInvestor`.
- A `WorldEvents` generator (storms = volatility regimes, news) drives fair value; it uses the simulation clock and a seed.
- Bots are configured in `bots.yaml` (count, strategy, parameters, seed) and built by a factory.
- In-process at first (calling the application port), later optionally over WebSocket as a separate process.

## Why this and not the alternatives
| Alternative | Why not |
|---|---|
| Fake prices generated directly (no bots) | No real order book, spread or liquidity — the lesson disappears |
| Bots with direct book access | Violates "no privileges", hides fees and risk checks |

## Pros
- Each strategy is a small, testable class — a textbook Strategy pattern.
- Seeded randomness → reproducible markets for tests and replays.

## Risks and costs
- Toy dynamics can teach wrong intuitions. Mitigation: market maker inventory limits, realistic fees, documented assumptions.
- Runaway bots (infinite loops of orders) — per-account rate limits apply to bots too.

## How to explain it
"Every bot is a client like a human, with its own wallet, fees and limits; only the decision logic differs — that's the Strategy pattern."

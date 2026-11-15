# 0021. A seeded economy schedule, journalled as decisions; halts, payouts and default in the engine

- Status: Accepted (M2b)
- Date: 2026-11-15
- Pattern(s): Generator driven by the simulation clock, Event Sourcing (disclosures are decisions), Observer (bots read news)

## Context
M2b needs company reports (consensus first, report "at night", gap at the open by the surprise), 8 rate decisions a year,
dividends, insider trades, bond coupons, maturity and default, and storms (ADR-0007 `CorporateEvents`, `MacroEvents`,
`WorldEvents`). Replay must stay deterministic (intent 02, invariant 4) and money must still only move (invariant 1).

## Decision
- `application.economy.EconomySchedule` is a pure function of (seed, start time, bank day): seasons of 91 bank days,
  each season and each storm block generated from its own seeded `Random`, so any window gives the same items.
- A timer asks the service every second for items due by simulation time; each is executed **at its scheduled time**
  (`ts = at`) and journalled. Replay never re-runs the generator: the journalled disclosure is the decision.
  The restart cursor is the latest economy event in the journal; the start time is the first regime event.
- Engine (framework-free): `Publish(Disclosure)` journals information as given (moves no money);
  `SetTradingStatus` halts/reopens an instrument (new orders, stops and margin opens refused with `MARKET_CLOSED`,
  cancels allowed); `Payout` moves `perUnit × units held` from the issuer to every holder (dividend, coupon, redemption —
  all or nothing); `DeclareDefault` stops coupons. If an issuer cannot pay a coupon the service declares default; at
  maturity a defaulted bond is redeemed with whatever cash is left.
- Read models: `EconomyProjection` (reports, consensus, rates, regime, bonds), `CandleProjection`, `PaperBook`.
  The public calendar shows future dates of rate decisions, reports, coupons and maturities, never their results,
  insider trades or storms.
- Bots get no new privileges: `bots.WorldFeed` subscribes to the same events and moves fair values (surprise → gap,
  rate surprise → FX, dividend → ex-date drop, storm → volatility, bonds anchored to policy rate + credit spread).

## Why this and not the alternatives
| Alternative | Why not |
|---|---|
| Generate news inside the engine | The engine stays a small money machine; the generator is policy, not ledger |
| Re-run the generator on replay | Any change to the generator would rewrite history |
| Scripted fixed news file | Not endless; no seeds to vary markets |

## Risks and costs
- Economy events carry their scheduled time, so the journal is not strictly time-ordered with people's events
  (by under a second). Nothing reads it as ordered by `ts` except the clock restore, which takes the maximum.
- Toy fundamentals: surprise ×0.5 = gap, no post-earnings drift yet.

## How to explain it
"A seeded almanac says what happens when; the exchange writes each page into the journal as it happens, and replay
reads the journal, not the almanac."

# 0022. Dividend dates with tax at source, funds with TER, trade-journal notes — new event types, same line format

- Status: Accepted (M2c)
- Date: 2026-11-15
- Pattern(s): Event Sourcing (new decisions + consequences), Upcaster-free evolution (ADR-0020), Event Sourcing projections, Observer

## Context
M2c adds three things the journal must carry: a person's "why" for an order (trade journal), dividends with the real
sequence of dates (declaration → ex-date → record date → pay date) and tax withheld at source, and funds whose TER is
charged by the simulation clock. M2b journals must still replay (ADR-0020), money must only move (intent 02,
invariant 1) and replay must give the same state (invariant 4).

## Decision
- **Only new event types**, no change to existing ones: the line format stays v2 and old journals need no upcaster.
  New decisions: `OrderAnnotated`, `DividendExDate`, `DividendPaymentStarted`, `FundFeeCharged`; new consequences:
  `DividendEntitled`, `ReferencePriceAdjusted`, `DividendPaid`; new disclosure `DividendDeclared`.
- **Trade journal.** `AnnotateOrder` is its own command journalled right after the order (once per order, owner only).
  `SessionReviewProjection` measures every order's fills against the last price (fees included) and groups by mood and
  market state, in money and in R (planned risk from the position-size helper).
- **Dividends.** Ex-date = open of report day + 10; record date = next day (settlement T+1, so who holds at the ex-date
  open is who is in the register); pay date = record + 4 days. At the ex-date the engine fixes the entitlements and
  lowers the *reference* price (used for valuation, margin and display) by the dividend; the next trade replaces it,
  and stops still fire on trades only (invariant 5). On the pay date the issuer pays `units × perShare`, of which 10%
  goes to `exchange-tax`, all or nothing. M2b `DividendAnnounced`/`Payout(DIVIDEND)` stay readable.
- **Funds.** `IDX-SPARK` (index: both companies by capitalisation, TER 0.20%) and `ACT-SPARK` (active: manager's
  FORGE-heavy picks, TER 2%). A custody account holds the basket and some cash (journalled deposits at first start);
  units are ordinary base assets traded on the exchange; a dealer bot quotes them around NAV per unit (fair value
  anchored to NAV — the bot reads the public fund card, no privileges). Each bank day the service charges
  `NAV × TER × days / 365` (rounded down) from custody cash to the manager; the amount is decided from prices and
  journalled, so replay just re-applies it. The fund card compares the fund's NAV with the same basket held without the fee.
- **ATR** is a pure read-model function over daily candles (Wilder, 14), not journalled.

## Why this and not the alternatives
| Alternative | Why not |
|---|---|
| Add note fields to `OrderAccepted` (v3 + upcaster) | Notes are optional and private; a separate event keeps the hot order event and the engine's matching unchanged |
| Pay dividends to holders on the record date by re-reading balances | With instant settlement that is "who held at the record date", not "who bought before the ex-date"; fixing entitlements at the ex-date open models T+1 honestly |
| Adjust resting orders by the dividend (as NYSE does) | Changes reservations of other people's orders; deferred — the reference price and bots' fair value carry the lesson |
| Funds as a product like savings (subscribe/redeem at NAV without real shares) | NAV moves with prices; paying out at a higher NAV than was paid in would create money. A custody holding real shares keeps invariant 1 |
| Rebalancing the active fund by trading | Needs a trading fund manager; the fixed basket shows the TER lesson already. Later milestone |

## Consequences
- Pros: old journals replay untouched; every money move is a journalled transfer; jqwik property covers dividends and
  fund fees (`engine.M2cTest`).
- Risks: an M2b journal with a dividend announced but not yet paid at upgrade gets the new schedule's dates (the old
  ex-date payout never runs); fund units have no creation/redemption, so the price can drift from NAV if the dealer runs
  out of inventory.

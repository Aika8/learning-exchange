# Intent: one exchange, many faces — platform, bots, mobile app and game
Author: Aika. Status: draft.

## Problem
The order book from increment 1 works, but nobody can touch it except through
the REPL. Learning finance needs consequences that feel real: a stop that did
not fire, a spread that ate the profit, a leveraged position cut at 50% loss.
Two very different audiences need the same honest market:
- someone who wants a realistic banking/brokerage experience on their phone;
- someone who would never open a trading terminal but would play a game.

## Proposed outcome
One backend (the exchange) with a stable contract, and three clients on top:
1. **Mobile super-app** «Ветрило» (working name) — accounts, transfers, deposits,
   FX exchange, brokerage with order book and stop orders, statement with fees
   and tax. A plain learning bank for people who skip the game: real-world terms
   only, it knows nothing about the game.
2. **PC game** «Летопись Ветров» / *Chronicle of Winds* — trading RPG in a sky
   archipelago (`docs/lore/world-bible.md`). Same accounts and markets; controls
   and numbers use real-world terms, lore names add flavour (world bible §6). The game knows the app:
   it uses the app's words and sometimes its navigation, to prepare the player
   for using the app.
3. **Web debug client** — thin, for developers and demos.

The market is alive without humans: bots (market maker, momentum, index,
noise) trade through the same contract as people. An assistant («Летописец»)
explains what happened after each session.

Everything works end to end from the first milestone (walking skeleton), then
each milestone deepens it.

## Affected users and systems
Aika (learning patterns and finance from this code), future players.
Existing `engine` package becomes the core domain of the backend.

## Constraints
- Every architectural choice is recorded as an ADR in `docs/adr/` with
  context, decision, pros, risks and alternatives — this code is teaching material.
- Code that implements a named pattern says so in its type-level Javadoc/doc
  comment and links the ADR.
- Engine invariants from `intent/01-order-book.md` stay true and stay tested.
- No real money, no real credentials, no copying of existing games or bank brands.
- One command starts the backend with bots; the README says how to run each client.
- Russian and English from day one in every client, switchable at runtime (ADR-0014).
- Real-world terms everywhere a player acts or reads numbers, so real trading later
  is not confusing (ADR-0012). Real market data (USD/KZT at least) is shown where a
  legal free source exists, read-only plus paper trading (ADR-0015).
- Product names and bundle/package ids live in one config place; names are
  checked for conflicts before any store release (world bible §9).

## Out of scope (for now)
Real payments, KYC, real broker integration, multiplayer networking beyond
"several clients on one server", app-store publishing, monetisation.

## Open questions
- What "learned to trade" means — still to be discovered; the assistant's
  session review (in R, vs buy-and-hold) is the first measurement.
- Persistence beyond the event journal (Postgres) — decide when the journal hurts.
- Which real-market data source is legal and free enough (KASE, National Bank
  official rate, other) — decided in ADR-0015 at implementation time.

## Invariants (in addition to increment 1)
1. Money is never created or destroyed by a trade: sum of balances changes only by fees, deposits, withdrawals and interest, each journalled.
2. A trade is visible to every client within one market-data tick.
3. Bots have no privileges a human client does not have.
4. Replaying the journal from the start produces exactly the same state.
5. A stop order fires on the last trade price, never on book quotes.
6. A position with leverage is force-closed before the owner loses more than 50% of its collateral (stop-out).

# Intent: islands that argue with each other — methods, phases, debts and side jobs
Author: Aika (raw notes of 2026-11-17, Notion «Игра «Воздушные пираты» — идея»). Written up by the implementer.
Status: **draft for discussion. Nothing here is decided and no code follows from it until Aika answers the questions.**

## Problem
The game teaches one way of trading: Mara's plan, the 1% rule, the Anchor. The player never meets people who
trade differently and are sometimes right. Real markets are full of them: the short seller, the crypto crowd with
its bots, the investor who buys the index and goes for a walk. Each is right for a while, and the expensive lesson
is noticing when a method has stopped working. Today a player who loses simply has less money; there is no way to
lose everything, borrow, work one's way back, and feel what a debt is.

## What Aika wants (her words, shortened)
1. **Sky pirates.** Everything is in the clouds. The hero is a ship's captain who **found a treasure: that is the
   starting capital.** They sail from island to island; the islands are all different.
2. **Trading islands.** Each is a real financial approach. Local enthusiasts explain their method; the player may
   try it or not. Each has an exchange "with realistic mechanics". **The market is one for all islands. It has
   phases, and each island is right at some time.** The player must notice when an island is wrong now. They can
   win or lose a little, decide when to stop, and **can lose everything**. Examples: an island of short sellers;
   an island of crypto, with bots; an island of indices (SPY, BIL) — very rich (houses, clothes) and very boring:
   every 5 seconds they invest in SPY, nothing can be clicked, you can only walk the streets.
3. **Debts.** People met on the way lend money. If it is not returned there is a punishment: you have to run.
4. **Side-job islands.** A French island: a woman speaks French to the hero and pays for answers; it teaches
   French and helps to recover after losses. A Formula 1 island: change wheels as an engineer, or drive; a place
   in the race is paid. The earnings are small and temporary.
5. **Style.** Not realism. The manners of different indie games; some islands may be 2D. Arriving on an island,
   the hero changes to its style.
6. Her open question: **how does the player see the current phase of the market** — a chart at the exchange, news
   in the ports, the behaviour of the islanders?

## What already exists and fits
| Wish | Already there |
|---|---|
| Islands differ, the hero restyles on arrival | ADR-0025, 0026: a technique per island, the island's wind |
| A French island | Amber Cliff (ADR-0028): French signs and talks, gloss on T. Nobody pays the hero yet |
| Islanders with methods | Bots are ordinary clients with strategies (ADR-0007): market maker, momentum, mean reversion, index investor, noise, news reactor, fundamentalist, active fund, bond investor |
| An index to buy and hold | The fund `IDX-SPARK` («Корзина Ветлы») with a TER; Бабушка Ветла already talks about it |
| Selling short | Leveraged positions, `side = SELL` is a short (M2a), with stop-out |
| Phases | Storms are volatility regimes; `EconomyProjection` has a `regime`; all of it seeded and journalled (ADR-0021) |
| Money from outside the market | `POST /me/deposits`, a journalled deposit (today a dev top-up) |
| A debt | Act I: grandfather's debt at the chest — a lesson card only, not money |
| Talks | Comic pages with drawn faces (ADR-0027) |

## Proposed outcome (to be confirmed)
**One honest market, many opinions about it.** The exchange stays one. A trading island is a *place where one
method lives*: its people are bots running one strategy with their own money, its exchange is a window onto the
same order books, and its talk explains the method with the real term beside the lore name. The world's economy
moves through **phases**; a method earns in some and bleeds in others. The player carries one account everywhere.

**The loop of a life, not only of a day.** Treasure → try a method → win or lose → (lost it all) work on a side-job
island or borrow → come back wiser. Nothing protects the player from a loss, and nothing leaves them with no move.

## Invariants (each must be a test before the feature counts as done)
1. **One market.** Every island trades the same instruments on the same books through the public contract. The
   price of an instrument at a moment of simulation time is the same on every island.
2. **No privileges.** Islanders are bots with accounts; they pay fees and pass the same risk checks (ADR-0007).
   A method's result comes from the market, never from a script that pays the island's fans.
3. **Phases are generated, not narrated.** A phase is a state of the seeded economy on the simulation clock,
   journalled; a replay of the journal gives the same phases (ADR-0005, 0021). The matching engine does not know
   about phases: they live where storms and rate decisions live (the engine stays framework-free and deterministic).
4. **Every method has a bad phase.** For each trading island a seeded test shows a phase where its strategy makes
   money and one where it loses. Nobody in the game is told the next phase in advance.
5. **Money is conserved.** The treasure, a loan, a wage, a fine are transfers between accounts or journalled
   deposits with a stated reason; integer minor units; the engine's invariants of intent 01 and 02 hold.
6. **The player can lose everything, and is never stuck.** The game does not block, soften or refund a loss.
   With nothing left, a side job is always available.
7. **A debt is honest.** Lender, principal, rate, due date and what happens on default are shown before the
   player agrees. Running away does not erase the debt.
8. **Side jobs are small.** Income per game day is bounded and cannot out-earn a careful trader.
9. **Words.** Every method, instrument and operation is named by its real term with the lore name beside it
   (ADR-0012); ru and en together (ADR-0014); on the French island also French (ADR-0028).
10. **No advice from the game.** An islander's pitch is that person's opinion and is shown as such; each island's
    glossary card says when the method fails. The Chronicler describes what happened and never recommends.
11. **The mobile app still knows nothing about the game** (intent 02): it sees a deposit, a loan, a trade.
12. **Nothing is copied**: no existing game's look, no real brand (see question 13 on Formula 1 and question 7 on
    SPY, BIL and bitcoin). 60 fps in the game, as before.

## How it would sit on the exchange (for discussion, not a design)
- **Island = strategy.** Short sellers, crypto traders and index buyers are strategies behind the `Strategy`
  interface of ADR-0007; "they have bots" on the crypto island is literally true. "Try the method" could mean:
  trade by hand on that island's Ladder, or lend the island's bot a stake that it trades for you — a question.
- **Phases** extend the scheduled economy (ADR-0021): besides calm and storm, something like rising, falling and
  sideways markets, each a block generated from its own seed. That is a costly-to-reverse change: an ADR first.
- **Index island.** "Every 5 seconds they invest" is a standing order on the simulation clock (a new, small
  application-level feature beside stop orders, ADR-0008), buying the index fund; the player only walks.
- **Loans and wages** are new journal event types only (the way dividends and funds were added in ADR-0022).
  A lender is an account; default has a consequence in the game, and the ledger keeps the debt.
- **Shorts** exist as leveraged positions; a whole island of them may need borrow costs — a question.

## Questions for Aika
**The world**
1. The name: «Воздушные пираты» or «Летопись Ветров»? Are the captain and crew pirates, or traders among pirates?
2. The treasure and Act I: today the hero inherits grandfather's **debt**. Does the treasure replace it, or do
   both stay (a chest with coins and an IOU)? How big is the treasure, and is it the same for everybody?
3. Which islands of the world bible become which idea? A suggestion: Тихий Причал = the index island; Окраина
   Бурь (unregulated) = crypto; Копи Эфирита (volatile) = short sellers; Гавань Искр = Mara's school of risk.
4. Does the day loop (plan → trade → sail → evening review) remain the spine of the game, or does it become
   the method of one island among others?
5. "Вокруг летает куча всего", monsters from the book: are there dangers and fights, or is it scenery?

**Market and methods**
6. **Your question — how the phase is seen.** A proposal to react to: never a label "phase: falling". Three
   layers instead: (a) honest instruments at every exchange — the chart of the Seven Islands index and the
   Barometer; (b) soft signs in the ports — the news board, what islanders say today, how busy the stalls are;
   (c) the name of the phase only **after** it ended, in the Chronicler's evening review. Too hard, too easy?
7. Phases: how many, how long in game days, in a cycle or at random? Real names (SPY, BIL, bitcoin) inside the
   game, or generic ones ("S&P 500 index fund", "T-bill fund", an invented coin) with the real ones in the glossary?
8. Trying a method: by hand, or by giving the island's people a stake to trade for you, or both? Any limit on
   the stake, or may the player put everything in?
9. The index island: is the player's money also invested every 5 seconds, automatically? Does time run faster
   there? What makes a visit worth it if nothing can be clicked — the houses, the talks, the result on return?
10. The crypto island: are the bots visible characters (machines in the streets)? Trading day and night?
11. The short sellers: do we want the real costs (borrow fee, margin call), or the simple version first?
12. Losing everything: what does the player see at zero, and is there a "start again"?

**Debts and work**
13. Formula 1 is a registered brand and the project forbids real brands: may it be our own sky race (pit stop
    for skiffs, a Grand Prix of the Winds)? What from your trip must be recognisable — the pit stop, the paddock,
    the noise? Wheel changing, driving, or both?
14. Lenders: who are they (a friend, a guild, a shark), at what rates and terms? The punishment: a chase as a
    mini-game? What happens if they catch the captain — a fine, the cargo, the ship? Can a debt be repaid from any port?
15. The French woman: is she on Amber Cliff (which now teaches finance in French) or on another island? What
    kind of questions — fixed ones with known answers (testable), or free speech judged by the assistant?
    At what level, and should it follow your TCF preparation?
16. How much does a side job pay compared with the treasure — a day's provisions, a tenth of the treasure?

**Look**
17. Which indie manners do you have in mind, island by island (as principles, not copies)? Which islands are 2D,
    and what does the captain do there — walk a side-on street?
18. Islands "from what we watched and discussed": which ones are on your list?

## Proposed order, in small steps (each ends in something that runs; ADR first where marked)
0. **Answers.** Then ADRs for the three costly decisions: market phases in the scheduled economy; loans and wages
   as journal events; an island as the presentation of one strategy.
1. **The treasure — the smallest working step.** On the first start the captain opens a chest and receives the
   starting capital: one journalled deposit with the reason "treasure", using the deposit operation that exists.
   The HUD and the mobile app show it; the Chronicler mentions it. No new market mechanics.
2. **The phase, visible and read-only.** Show what the economy already has (calm/storm regime, rate decisions):
   the Barometer and the index chart in port, the phase named in the evening review. Tests Aika's question 6 on
   real players before any new phase exists.
3. **The index island.** Rich, boring, walk-only; a standing order buys the index fund on the simulation clock.
   Uses the fund and the index bot that exist. First island whose method can be compared with the player's own.
4. **Phases proper** (ADR): rising, falling, sideways blocks in the economy generator, with the property test of
   invariant 4 for the index method.
5. **A second method that is right at another time** (short sellers or momentum). From here "each island is right
   sometimes" can be seen, and each island gets its "when this fails" card.
6. **A paid job on Amber Cliff**: French questions for a small, bounded wage — the way back after a loss.
7. **Loans**: one lender, loan events, a due date, a first consequence of default (ports closed to the captain);
   the chase comes later as its own step.
8. Later, each on its own: the crypto island with visible bots; the race island; a 2D island; the chase.

## Out of scope (for now)
Multiplayer, real money or real market orders, real brands, fights and monsters (until question 5 is answered),
any change to the matching engine's rules.

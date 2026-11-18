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
7. **The index island, in more detail** (added 2026-11-18; see "The index island: Aika's ideas" below): time is
   seen with the eyes, the storm passes over it, it is quiet inside, its people are of every age — and it is
   **not** "the right answer".

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

## The index island: Aika's ideas (2026-11-18)
The island exists as a place and a style only: a canal town painted in oil (ADR-0035, which replaced the pastel
toy town of ADR-0033). Its sheet 65, the overcast day, is drawn for idea 2 below and waits for phases. These are ideas for what the place *does*; nothing here is built.

1. **Time is seen with the eyes.** Trees and houses grow slowly from visit to visit: compound interest shown as
   a garden, not as a number. A visitor who comes back after a long voyage sees the difference at once; one who
   stands and waits sees nothing.
2. **The storm passes over it too.** When the whole market is in a falling phase there is a thunderstorm above
   the island as well, and the fountain drops fewer coins — but the islanders walk as calmly as before and nobody
   panics. The lesson is to sit through a drawdown.
3. **Shelter from noise.** Outside: news, the short sellers shouting, the neon of the crypto island. Inside:
   silence. A metaphor for "do not react to noise".
4. **Adults of every age.** Families, people in their middle years and the old — not only the old. Their wealth
   was earned by patience; somebody keeps a photo album "30 years ago".

**The island does not say "this is the right answer".** Its costs must be as visible as its wealth:
- drawdowns of 30–50 %;
- years before the value comes back;
- boredom — the main difficulty;
- no quick result.

How it could sit on what exists (for discussion):
- **Growth** is a pure function of the island's own holding in the index fund on the simulation clock (ADR-0021),
  so a replay grows the same garden. It follows invariant 2: the trees grow because the fund did, never by a
  script — which means that in a long falling phase they must also stop, thin out or lose leaves. A garden that
  only ever grows would be the "right answer" Aika does not want.
- **The storm and the fountain** read the same phase as every other island (invariants 1 and 3); the fountain's
  rate could be the fund's distributions or the islanders' standing orders, whichever question 9 settles.
  The calm is behaviour of the islanders, not protection: their accounts fall with the market like anyone's.
- **Silence** is presentation only: the news board and the criers stop at the pier, sound and motion drop.
  The news still exists and the player may read it elsewhere; the island hides nothing from the ledger.
- **The minuses** belong where the player cannot miss them: the album also has the bad years (the page where the
  garden was half its size and how long it took to return), an islander who sold at the bottom and tells it,
  the island's "when this fails" card (invariant 10), and the Chronicler's review comparing the player's own
  years with the island's, without a verdict.
- The figures (30–50 %, years) are of the order known from real index history; inside the game the numbers come
  from the seeded economy, so a test must show that a falling phase can really cost the island that much
  (invariant 4) — otherwise the talk would promise a risk the market never delivers.

## The pyramid island (2026-11-18)
Aika's idea: an island that is **too good to be true** — a scheme that promises easy money and lives on newcomers.
Seven sheets (`docs/design/concepts/73…79`). A pastel fairground under a glass dome; every front is plywood on
scaffolding from behind; four stages of decay, one per visit (ADR-0038). **No Ponzi mechanics**: nothing is paid
from newcomers' money, nothing can be invested; it is a place to look at and talk in. Signs carry pictograms, never
promised percentages.

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

**The index island (to the ideas of 2026-11-18)**
19. Growth "from visit to visit": measured in game days since the captain's last landing, or in the fund's value?
    How long must an absence be before a difference is seen — and does the player's own stake grow a tree of
    its own (ties in with question 9)?
20. In a long falling phase, may the garden visibly shrink (bare trees, a closed shutter), or does it only stop?
21. Silence: is it literal (no news board, no music, muted sound on the island), and may the player still open
    the chart and the Barometer there, or only outside?
22. The islanders today are five by the sheet: a gentleman, a lady, an elderly couple, a boy. For "every age" we
    need families and people in their middle years — will there be a sheet for them? Who owns the photo album,
    and is it a comic page (drawn "then" and "now") or an object on a table?
23. Who tells the minuses in person — somebody who sold at the bottom and left, somebody who stayed and is
    simply bored? Is there an islander who regrets being here?

**Look**
17. Which indie manners do you have in mind, island by island (as principles, not copies)? Which islands are 2D,
    and what does the captain do there — walk a side-on street?
18. Islands "from what we watched and discussed": which ones are on your list?

**The pyramid island (ADR-0038)**
24. Stages follow the number of visits for now (1, 2, 3, 4 and on). Later: game days, the market's phase, or
    the visits of the player only? Does it ever come back — a new fair opens somewhere else?
25. Does the player lose anything here, or is it only seen? If something: a ticket bought at stage 1 that is
    worthless at stage 4 (with no market money involved)?
26. Its people (sheet 76): the host, the barker, the happy ticket holder, the worried coin counter, the sweeper.
    Who of them knows what it is? Does the happy one become the worried one at a later stage?
27. Which real schemes should its talks echo (pyramids, "guaranteed" returns, referral bonuses), and in which
    words — the real term beside the lore name, as elsewhere?

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
   The place stands already (ADR-0035). After phases exist (step 4): the growing garden, the storm overhead,
   the quiet, the album with its bad years — see "The index island: Aika's ideas".
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

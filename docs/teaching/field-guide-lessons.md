# Lessons for the game from a colleague's trader's field guide

Status: **proposal for Aika** (2026-11-25), not an ADR. Source: a colleague's illustrated guide to his own
short-term trading app (edition of 20.11.2026, 40 pages), read as data. Nothing from it is copied here: no text, no
names of its characters or screens, no numbers from his measurements — they are his app's findings, not ours. What
is kept are the ideas, in our words, mapped to places in «Летопись Ветров».

Rules this keeps: no investment advice (the game never says what to buy); every term is shown by its real name
with the lore name beside it (world bible §6); the game shows consequences in the evening review instead of
forbidding (intent 03, invariant 6: the player can lose everything).

What the guide teaches best is not a trading method but **honesty about evidence** and **behaviour**: most of what
traders watch tells "where we are", not "where we go"; rules exist to keep each mistake small, decided before the
trade; and most losses come from the trader, not the market. That is exactly what a game can let a player feel.

## A. Ideas of theory

| # | Idea (in our words) | Where the player meets it | What the evening review shows |
|---|---|---|---|
| A1 | **Price is the last deal**, the order book is the queue of offers, the spread is the cost of hurrying, a thin book moves on small orders | Already the Ladder of Spark Harbour (lessons SPREAD, LIQUIDITY) | Spread paid today, in coins and as a share of the result |
| A2 | **The day has phases**: a thin book before the open with wide spreads, a violent first hour, a quiet middle, a calmer close | The Ladder at dawn: bots quote wide, few sellers; a crowd at the opening bell | "You bought at dawn and paid N in spread more than at noon" |
| A3 | **Range is not direction.** A security's typical daily move (ATR) says how far, never which way | Mara's school of risk; Ether Mines (wild prices) | "Your Anchor was closer than one ordinary day's move — the noise took it" |
| A4 | **A stop measured in the security's own units** (a multiple of its daily range), not a round percent | Setting the Anchor (lesson ANCHOR) | Anchor distance in ranges; how often it was hit by noise |
| A5 | **The market's state decides how much risk to take, not what will happen** (share of securities above their long average; trend; days of central-bank decisions) | The Barometer and the island's mood (intent 03, phase layer a); Council of Treasurers' decision days | Trades opened while the Barometer said "stay out", and how they went |
| A6 | **"Why not" before "why yes"**: red checks (report within two days, an illiquid security, a price pinned by a pending takeover), then yellow ones (parabolic rise, falling knife, lottery-like volatility) | The Forge before a report season; a guild buying a workshop; the crypto island's rockets | Which checks a trade failed before it was opened |
| A7 | **There is no "approved"**: passing the checks means "no known reason not to", not "a good investment" | Mara's plan approval wording | — (a wording rule for all texts) |
| A8 | **One bet per theme**: three funds on the same goods are one bet, not three | Silk Reach: several silk workshops move together in the season | "Your three positions were one bet on silk" |
| A9 | **Exit rules are equal on average; their job is to make losses small and to be decided before entry** (stop, trailing stop from the peak, time limit, sell before a report) | Mara asks for the exit plan with the trade plan | Exits that followed the plan vs exits that changed it mid-trade |
| A10 | **Gaps jump over stops**, especially on report days | The Forge report season (lessons GAP, SURPRISE — exist) | Anchor filled worse than set: by how much and why |
| A11 | **"Already happened" vs new information**: a fall everybody has seen is priced; a workshop master buying his own shares is news | Forge rumours vs the journal of insider records (STATUS: quest not started) | Trades taken on "it already fell" vs on a new fact |
| A12 | **Storms widen the range both ways; nothing announces a crisis early; buying the panic is a bet, not a rule** | Storms (exist), the short sellers' island | Range on storm days vs calm days; trades opened in panic |
| A13 | **Losses compound like gains**: −10% then +10% is not zero; fees compound too; a daily target forces bad trades; streaks happen to coins | Mara's sums; the Chronicler | The series' result as a product of multipliers; fees as a share of the gross |
| A14 | **How sure are we?** Every claim has a label: tested and works / tested, no edge / a candidate / range only / reference / a discipline rule. Ask "how many cases?" | Islanders' pitches (intent 03, invariant 10: an opinion shown as such) | The Chronicler labels its own claims the same way |

## B. The author's own mistakes, and where the player can make them

Each becomes a **detector** over the trade journal (logic with tests) and **one line** in the evening review. The
game never blocks the trade.

| # | Mistake | How the game sees it | Where it is tempting | Review line (idea) |
|---|---|---|---|---|
| B1 | Fear of missing out | Buy after a large move of the same day | Crypto island rockets; the race island's favourite | "Bought after +N% today: the move was someone else's" |
| B2 | Buying before a report | Entry within two sim days of a scheduled report | The Forge in report season | "The report gapped through your Anchor" |
| B3 | Buying on a tip, no analysis | Order placed within seconds of a rumour talk, with no plan note | Tavern rumours | "No reason written, no exit planned" |
| B4 | Ignoring liquidity | Entry when the spread is several times the usual | Remote islands, dawn | "The spread ate your target" |
| B5 | Chasing an early rise | Buy before the open after a pre-open rise | The Ladder at dawn | "Early risers often give back the day" |
| B6 | Averaging down | Adding to a losing position | Anywhere after a loss | "A small mistake became a big position" |
| B7 | No exit plan | Position held without an Anchor or a time limit | Leaving port (the Anchor guard exists only for sailing) | "No exit was decided before the entry" |
| B8 | Trading on emotion | Size grows right after a loss or a win streak | Any island | "Size rose by N× after the loss" |
| B9 | Ignoring the market state | Entries while the Barometer says "stay out" | Long falling phases | "Opened while the market said stay out" |
| B10 | Revenge trading | A new entry within minutes of closing a loss, same instrument | Any island | "Trying to win it back" |

## C. Proposed order (for Aika; the queue takes only logic under tests)

1. Detectors B6, B7, B8, B10 and B2 in the backend over the trade journal — logic and tests only (queued).
2. Detectors B1, B4, B5, B9 — need "move of the day", "usual spread" and the Barometer as inputs (queued; B9
   waits for the phases ADR of intent 03).
3. Compounding sums of A13 in the game's lesson maths (queued).
4. **For Aika:** showing the detectors in the review (contract change, texts, the look of the review page); the
   evidence labels of A14 on islanders' talks (copy and data of the comic pages); which island teaches A2, A5, A8;
   whether the colleague's guide may be named as a source anywhere public.

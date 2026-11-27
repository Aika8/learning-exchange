# Intake log

Written by `scripts/backlog/backlog.py intake` (GitHub Actions, daily): which proposals entered the queue and why the others wait for Aika.

## 2026-11-25
- accepted: AUTO-20261125-1 ← docs/backlog/proposals/2026-11-25-analyst.md#1 «Property: every trade is at the resting order's price»
- accepted: AUTO-20261125-2 ← docs/backlog/proposals/2026-11-25-analyst.md#2 «ArchUnit: bots never reach the ledger, the accounts or the clock control»
- accepted: AUTO-20261125-3 ← docs/backlog/proposals/2026-11-25-analyst.md#3 «Property: the bare order book is deterministic»
- accepted: AUTO-20261125-4 ← docs/backlog/proposals/2026-11-25-analyst.md#4 «Market data: a trade queued before a tick goes out in that tick»
- accepted: AUTO-20261125-5 ← docs/backlog/proposals/2026-11-25-user.md#1 «Mobile: a readable message for every refusal code, and a test that keeps it so»
- left for Aika: docs/backlog/proposals/2026-11-25-user.md#2 «Web: a readable message for every refusal code, and a test that keeps it so»: daily cap of 5 reached
- left for Aika: docs/backlog/proposals/2026-11-25-user.md#3 «Assistant: say what "spread" and "result against the last price" mean the first time they appear»: daily cap of 5 reached
- left for Aika: docs/backlog/proposals/2026-11-25-user.md#4 «Assistant: when asked "what is X?", say plainly that it explains your numbers, not words»: daily cap of 5 reached
- left for Aika: docs/backlog/proposals/2026-11-25-user.md#5 «Game: refusals and Mara's lines say where to go, not only what is missing»: daily cap of 5 reached
- left for Aika: docs/backlog/proposals/2026-11-25-user.md#6 «Glossary: the terms the app and game already use but never define»: daily cap of 5 reached

## 2026-11-26
- accepted: AUTO-20261126-1 ← docs/backlog/proposals/2026-11-26-analyst.md#1 «Assistant: «explain why…» and «what is my result?» are not questions about a word»
- accepted: AUTO-20261126-2 ← docs/backlog/proposals/2026-11-26-analyst.md#2 «Glossary: every name finds its own term, and no definition reads as advice»
- accepted: AUTO-20261126-3 ← docs/backlog/proposals/2026-11-26-analyst.md#3 «The game's Python tests run in CI through the data check»
- accepted: AUTO-20261126-4 ← docs/backlog/proposals/2026-11-26-user.md#1 «Game: Mara's first lines say «financial cushion» and «capital» next to «provisions» and «treasury»»
- accepted: AUTO-20261126-5 ← docs/backlog/proposals/2026-11-26-user.md#2 «Game: the goals say what «cargo» and «sailing» mean in real words»
- accepted: AUTO-20261126-6 ← docs/backlog/proposals/2026-11-26-user.md#3 «Game: the old sailor's spread lesson matches what the app counts»
- accepted: AUTO-20261126-7 ← docs/backlog/proposals/2026-11-26-user.md#4 «Game: Olva's lines give the real word for «Counters» and «ledger», and en says «Quiet Mooring» everywhere»
- accepted: AUTO-20261126-8 ← docs/backlog/proposals/2026-11-26-user.md#5 «Mobile: a limit order says what it does, like the market order already does»
- accepted: AUTO-20261126-9 ← docs/backlog/proposals/2026-11-26-user.md#6 «Mobile: ru and en name the same thing, and the currency tab is not called «Exchange»»
- accepted: AUTO-20261126-10 ← issue#113#1 «Session review and its mistakes come from one sequencer call»
- accepted: AUTO-20261126-11 ← docs/backlog/tech-debt/2026-11-27-LE-405-1.md#1 «Make the session review use the one-bank-day "after a loss" window»

## 2026-11-27
- accepted: AUTO-20261127-1 ← docs/backlog/proposals/2026-11-27-analyst.md#1 «Assistant: «А что такое спред?» and «Can you explain spread?» are term questions again»
- accepted: AUTO-20261127-2 ← docs/backlog/proposals/2026-11-27-analyst.md#2 «ArchUnit: the engine also never reads ZonedDateTime/OffsetDateTime/LocalTime now, Math.random, ThreadLocalRandom, SecureRandom or UUID.randomUUID»
- accepted: AUTO-20261127-3 ← docs/backlog/proposals/2026-11-27-analyst.md#3 «ArchUnit: money is never a double in the API DTOs and the bots either»
- accepted: AUTO-20261127-4 ← docs/backlog/proposals/2026-11-27-analyst.md#4 «ArchUnit: production code never calls the five-sim-minute overloads of TradingMistakes.find»
- accepted: AUTO-20261127-5 ← docs/backlog/proposals/2026-11-27-analyst.md#5 «Assistant cache: an answer the template gave because Claude failed is not kept»
- accepted: AUTO-20261127-6 ← docs/backlog/proposals/2026-11-27-analyst.md#6 «Assistant cache: two identical questions at the same moment reach the delegate once»
- accepted: AUTO-20261127-7 ← docs/backlog/proposals/2026-11-27-user.md#1 «Login with a Cyrillic name works: the dev token is ASCII»
- accepted: AUTO-20261127-8 ← docs/backlog/proposals/2026-11-27-user.md#2 «Depositing an asset nobody trades is refused»
- accepted: AUTO-20261127-9 ← docs/backlog/proposals/2026-11-27-user.md#3 «Mobile: the order ticket shows what you have, and an old refusal goes away when you change the order»
- accepted: AUTO-20261127-10 ← docs/backlog/proposals/2026-11-27-user.md#4 «Mobile: a filled order says how much was bought and where its price is»
- accepted: AUTO-20261127-11 ← docs/backlog/proposals/2026-11-27-user.md#5 «Game: while sailing, the goal says how to come back, not «sail out» again»
- accepted: AUTO-20261127-12 ← docs/backlog/proposals/2026-11-27-user.md#6 «Game: the first-order goal says what an order is»
- accepted: AUTO-20261127-13 ← docs/backlog/proposals/2026-11-27-user.md#7 «Mobile: the currency account is not counted in «шт.»»
- accepted: AUTO-20261127-14 ← docs/backlog/proposals/2026-11-27-user.md#8 «Mobile: the trade-journal example is not trader jargon»

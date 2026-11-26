# Backlog queue

The work of the cloud agents, one task per run, in file order (`scripts/backlog/backlog.py next` picks the first
ready one). How the run works: `docs/backlog/README.md`. Only Aika edits this file by hand; the intake script
appends to the end.

Format of a task (the script parses it; `backlog.py lint` checks it):

- `### ID — title`, then fields, a blank line, the description (at most ~1500 tokens).
- `status`: `todo` | `waiting` (needs Aika; `waits` says what) | `done` | `dropped`. A task is *done* when the
  PR from its branch `claude/<id in lower case>` is merged; nobody edits the status for that.
- `depends`: ids that must be done first. `needs`: `godot` or `docker` when the cloud image may lack them.
- `paths`: the only files the PR may change (plus `DECISIONS.md`). Globs: `*` within a folder, `**` across folders.
- `verify`: the command that proves the task; `expect`: what it prints or what must be true.

Rules for every task (the executor prompt repeats them): existing tests are never changed or deleted, new tests
are new files; money is integer minor units; the engine stays framework-free and deterministic; contract changes go
to `api/*.yaml` first; nothing changes the look of `game3d`; `make test` stays green.

## Aika's answers of 2026-11-26 and the proposals of 2026-11-25

### LE-090 — Intent 01: agents may add engine tests; the engine's main code stays Aika's
- status: todo
- size: S
- paths: `intent/01-order-book.md`
- verify: `grep -n "add test files" intent/01-order-book.md`
- expect: one line in the Constraints section says agents may add new test files for `engine`, never edit existing ones or the main code

Aika's answer (2026-11-26, analyst's option A): the rule in `intent/01-order-book.md` (section "Constraints",
"Package `engine` and its tests are written by Aika; the agent does not create or edit them") covers the **main**
code of `engine`. Agents may **add** new test files; existing tests are never edited (the merge gate enforces it).
Rewrite only that sentence, keeping the rest of the section. Add a bullet to `DECISIONS.md` under
"Backlog run (December 2026)": "LE-090: intent 01 amended on Aika's answer of 2026-11-26."

### LE-089 — Assistant: say what "spread" and "result against the last price" mean the first time
- status: todo
- source: docs/backlog/proposals/2026-11-25-user.md#3
- size: S
- paths: `backend/application/src/main/java/application/assistant/TemplateAssistant.java`, `backend/application/src/test/java/application/assistant/TemplateWordsExplainedTest.java`
- verify: `./gradlew :backend:application:test --tests 'application.assistant.*'`
- expect: green, the old `TemplateAndFallbackTest` unchanged; the new test shows the costs answer explains spread and the summary says what the result is measured against, in ru and en

From the user run of 2026-11-25 (`docs/backlog/proposals/2026-11-25-user.md`, third proposal — read it, it has
the exact sentences). In `costs(...)` keep every sentence and number and add one: ru «Спред — разница между лучшей
ценой покупки и продажи; здесь — сколько вы отдали против середины между ними.» / en «The spread is the gap between
the best buy and sell prices; here, how much you gave up against the middle between them.» In `summary(...)` change
only the words between the counts and the number to ru «результат, если бы всё закрыть по последней цене, » / en
«the result if everything were closed at the last price is ». Keep «N заявок, M в плюсе» untouched here (LE-092
fixes the plural). The new test also asserts `new AdviceGuard().isAdvice(text)` is false. Log the copy in
`DECISIONS.md` as "copy draft, Aika reviews".

### LE-092 — Assistant: correct Russian plural for orders («1 заявка, 3 заявки, 5 заявок»)
- status: todo
- depends: LE-089
- size: S
- edits-tests: `backend/application/src/test/java/application/assistant/TemplateAndFallbackTest.java`, `backend/app/src/test/java/app/M4ContractTest.java`
- paths: `backend/application/src/main/java/application/assistant/**`, `backend/application/src/test/java/application/assistant/RuPluralTest.java`, `backend/application/src/test/java/application/assistant/TemplateAndFallbackTest.java`, `backend/app/src/test/java/app/M4ContractTest.java`
- verify: `./gradlew :backend:application:test --tests 'application.assistant.*' && ./gradlew :backend:app:test --tests 'app.M4ContractTest'`
- expect: green; the summary says «3 заявки», «1 заявка», «5 заявок», «21 заявка»; the two old asserts now expect the correct forms

Aika's answer (2026-11-26): a one-time exception — this task may change exactly two existing asserts that pin the
wrong plural: `TemplateAndFallbackTest.java:43` («3 заявок» → «3 заявки») and `M4ContractTest.java:34`
(«1 заявок» → «1 заявка»). Change nothing else in those two files. Add a small `RuPlural.of(n, one, few, many)`
in `application.assistant` (rules: n%10==1 && n%100!=11 → one; n%10 in 2..4 && n%100 not in 12..14 → few; else many),
use it in `TemplateAssistant.summary(...)` for «заявка» and anywhere else the template prints a Russian count
(search the class). English stays «N orders» / «1 order». New `RuPluralTest`: 0, 1, 2, 4, 5, 11, 12, 14, 21, 22, 25,
101, 111. Note in `DECISIONS.md` that the two asserts were edited on Aika's exception of 2026-11-26.

### LE-093 — «the Chasm» is the English lore name of the spread everywhere
- status: todo
- size: S
- paths: `docs/lore/glossary.yaml`, `game3d/i18n/strings.csv`, `game3d/i18n/talk.csv`, `docs/design/comic-script.md`, `backend/app/src/test/java/app/ChasmNameTest.java`
- verify: `! git grep -n "the Gap\|The Gap\|Jump the Gap" -- docs/lore/glossary.yaml game3d/i18n docs/design/comic-script.md && python3 game3d/tools/check_data.py && ./gradlew :backend:app:test --tests 'app.CatalogueTest' --tests 'app.ChasmNameTest'`
- expect: no «the Gap» as the spread's lore name is left; data checks and the catalogue test are green

Aika's answer (2026-11-26): the English lore name of «Пропасть» (spread) is «the Chasm», as `LADDER_SPREAD_LORE`
and `FORM_MARKET_LORE` («leap over the Chasm») already say. Change: `docs/lore/glossary.yaml` spread lore en «the Gap»
→ «the Chasm» and the market order's «Jump the Gap» → «Leap over the Chasm»; `game3d/i18n/strings.csv`
`LESSON_SPREAD` en «The Gap» → «The Chasm»; `game3d/i18n/talk.csv` `TALK_SAILOR3_1/2` «the Gap» → «the Chasm» (and
the same two lines in `docs/design/comic-script.md`, which mirrors the talks). The **real** term «gap» (price gap,
`CHR_GAP_THROUGH`, `LESSON_GAP`, «the gap to what was expected») stays — only the spread's lore name changes.
Do not touch `game3d/tests/` (a fixture there uses «the Gap» as sample data). New test `ChasmNameTest` (load the
glossary as `CatalogueTest` does): the spread's lore en is «the Chasm».

### LE-094 — Mara's English name is «Mara Anchor» everywhere
- status: todo
- size: S
- paths: `game3d/i18n/talk.csv`, `game3d/tools/test_mara_name.py`
- verify: `python3 game3d/tools/check_data.py && python3 -m unittest game3d/tools/test_mara_name.py`
- expect: green; every English mention of Mara's full name in `game3d/i18n/*.csv` and `game/i18n/strings.csv` is «Mara Anchor»

«Mara Anchor» is used in two places of three (`HARBOUR_MARA`, `PLAN_LORE`); `talk.csv` `WHO_MARA` says «Mara of the
Anchor». Change `WHO_MARA` en to «Mara Anchor». Leave the concept sheet title in `docs/design/` alone (it is the
sheet's name). Write in `DECISIONS.md` under the backlog heading: "LE-094: Mara's English name «Mara Anchor» (2 of 3
places already); easy to undo — one CSV cell." New `game3d/tools/test_mara_name.py` (unittest, stdlib csv): no
English cell in `game3d/i18n/*.csv` or `game/i18n/strings.csv` contains «Mara of the Anchor».

### LE-095 — Day one: Mara and the hints name provisions on the pier as the first step
- status: todo
- source: docs/backlog/proposals/2026-11-25-user.md#5
- size: S
- needs: godot
- paths: `game3d/i18n/strings.csv`, `game3d/tests/unit/test_flow_way_back.gd`
- verify: `make test-game3d && python3 game3d/tools/check_data.py`
- expect: all GUT tests pass; the new test shows every state except PORT may go to PORT with an empty context, and from PORT no move is refused with `FLOW_NO_EDGE`

Aika's answer (2026-11-26, the user run's option (c)): Mara's greeting and the goal line both name provisions as the
first step, and no hint sends the player "to the market" — the provisions are the crates on the pier
(`game3d/scripts/harbour.gd`, `PROMPT_PROVISIONS`). Change only these values in `game3d/i18n/strings.csv` (keys stay):
`HARBOUR_MARA` — keep the sentence and append ru «Но сначала — провизия на шесть лун: ящики на причале. Потом план
со мной.» / en «But first — provisions for six moons: the crates on the pier. Then a plan with me.»;
`GOAL_BUY_PROVISIONS` ru «Купи провизию на шесть лун (финансовая подушка) — ящики на причале.» / en «Buy provisions for
six moons (emergency fund) — the crates on the pier.»; `MARA_PROVISIONS_FIRST`, `FLOW_NEED_PROVISIONS` and
`FLOW_NO_EDGE` exactly as in the fifth proposal of `docs/backlog/proposals/2026-11-25-user.md`. Keep the CSV quoting
of neighbouring rows. New GUT test `test_flow_way_back.gd` as that proposal describes. Log every text in
`DECISIONS.md` as "copy draft — Aika may rewrite".

### LE-096 — Assistant answers «what is X?» from the glossary (application side)
- status: todo
- source: docs/backlog/proposals/2026-11-25-user.md#4
- size: S
- paths: `backend/application/src/main/java/application/assistant/**`, `backend/application/src/test/java/application/assistant/TemplateDefinitionTest.java`
- verify: `./gradlew :backend:application:test --tests 'application.assistant.*'`
- expect: green; «Что такое спред?», «What is a stop-loss?» get the term's real name and definition (lore name too for the Chronicler persona); an unknown term gets «I don't know that word yet — here are your numbers»; «Как прошла сессия?» is unchanged

Aika's answer (2026-11-26): the assistant answers a term question from the glossary (option a; a mobile glossary
screen is LE-098). Add a port `GlossaryTerms` in `application.assistant` (find a term by a word in ru or en: id,
real name, lore name, definition) and pass it to `TemplateAssistant` (constructor; keep the old constructor working
with an empty glossary so existing tests stay untouched). When the lower-cased question matches
`(что такое|что значит|что означает|объясни|what is|what's|what does|explain|meaning of)` and a term matches, answer
with real name — definition (Chronicler: «lore name (real name) — definition»). The advice guard still runs first.
Test with an in-memory glossary of three terms. Do not wire it into `backend/app` (LE-097).

### LE-097 — Wire the glossary into the assistant in the app
- status: todo
- depends: LE-096
- size: S
- paths: `backend/app/src/main/java/app/**`, `backend/app/src/test/java/app/AssistantGlossaryContractTest.java`
- verify: `./gradlew :backend:app:test --tests 'app.AssistantGlossaryContractTest' --tests 'app.M4ContractTest'`
- expect: green; `POST /assistant/ask` with «Что такое спред?» answers with the glossary's definition of spread and validates against the contract

Implement `GlossaryTerms` from LE-096 in `backend/app` over the catalogue that already loads `docs/lore/glossary.yaml`
(read `bff` / `Catalogue`; reuse the loaded data — do not parse the YAML a second time) and pass it to the
`TemplateAssistant` bean. New contract test in the style of `M4ContractTest`. No contract change.

### LE-098 — Mobile: a glossary screen from /bff/mobile/glossary (logic and test)
- status: todo
- size: S
- paths: `clients/mobile/src/app/glossary.tsx`, `clients/mobile/src/glossary.ts`, `clients/mobile/test/glossary.test.mjs`, `clients/mobile/src/i18n/ru.json`, `clients/mobile/src/i18n/en.json`
- verify: `cd clients/mobile && npm ci && npm test`
- expect: green; the new test covers search (ru/en, case-insensitive), sorting and the real-name-first rule

Aika's answer (2026-11-26, option b after a): the mobile app gets a «Словарь» screen. The design canvas is
`docs/design/canvas/S10-Glossary.dc.html` — follow its layout with the existing components and theme tokens; no new
styles. The endpoint `/bff/mobile/glossary` exists (`api/openapi.yaml`). Put the logic (filter by query, sort by real
name in the current language) in `src/glossary.ts` with `node --test` tests; the screen only renders. In the mobile
app only real terms are shown (intent 02: the app knows nothing of the game), so ignore lore names. i18n keys for the
title and the search placeholder in ru and en. Do not add a tab or change navigation beyond one entry from settings.

### LE-099 — Web: a readable message for every refusal code
- status: todo
- source: docs/backlog/proposals/2026-11-25-user.md#2
- size: S
- paths: `clients/web/src/i18n/ru.json`, `clients/web/src/i18n/en.json`, `clients/web/src/i18n/errors.test.ts`
- verify: `cd clients/web && npm ci && npx vitest run src/i18n`
- expect: green; the new test finds `errors.<CODE>` in ru and en for every constant of `backend/engine/src/main/java/engine/Rejection.java`

From the user run of 2026-11-25 — the second proposal of `docs/backlog/proposals/2026-11-25-user.md` has the full
text; follow it. Copy the wording of the mobile task AUTO-20261125-5 when it is merged (same codes, same sentences in
both clients); if it is not merged yet, write the four missing keys yourself and log them as "copy draft".

### LE-088 — Glossary: four terms the app and game use but never define
- status: todo
- source: docs/backlog/proposals/2026-11-25-user.md#6
- size: S
- paths: `docs/lore/glossary.yaml`, `backend/app/src/test/java/app/GlossaryHasToolTermsTest.java`
- verify: `./gradlew :backend:app:test --tests 'app.CatalogueTest' --tests 'app.GlossaryHasToolTermsTest'`
- expect: green; the new test finds the ids `trailing-take-profit`, `atr`, `fund-ter`, `price-level`

From the user run of 2026-11-25 — the sixth proposal of `docs/backlog/proposals/2026-11-25-user.md` has the full
text (real terms, ru lore names from world bible §6, English lore drafts). Follow it. English lore names are drafts:
log each in `DECISIONS.md` as "lore draft, Aika reviews".

## Engine: model-based testing (intent 01 and 02 as properties)

### LE-001 — A generator of random valid order-book actions
- status: todo
- size: S
- paths: `backend/engine/src/test/java/engine/model/**`
- verify: `./gradlew :backend:engine:test --tests 'engine.model.*'`
- expect: green; the new tests show that the same seed gives the same action list and that every action is valid

Model-based testing needs a source of random but valid actions. Create, in test sources only, package
`engine.model` with:

- `Action`: a sealed interface with records `SubmitLimit(side, price, qty)`, `SubmitMarket(side, qty)`,
  `Cancel(int pickIndex)` (cancel the n-th order that is still resting, modulo their count; a no-op when none).
- `ActionGen`: builds a `List<Action>` from a `long seed` and a length with `java.util.Random(seed)` (no jqwik
  arbitraries needed, so a failing seed can be replayed by hand). Prices in a narrow band (e.g. 95–105) so orders
  cross often; quantities 1–20; roughly 45% limit, 20% market, 35% cancel.
- `Runner`: applies a list of actions to a fresh `engine.OrderBook` and returns one `Step` record per action with
  everything later properties need, because after this task the file is a test of an earlier task and can never
  be edited again: the action; the order id the book assigned (submits) or the real id a `Cancel` resolved to (or
  none); the `SubmitResult` / cancel boolean; the trades of that step; the book's depth view after it; and, per
  live order id, its original and remaining quantity and arrival index. Later tasks only read these.

Tests in `engine/model/ActionGenTest.java`: the same seed gives the same list; no generated limit price ≤ 0 or
quantity ≤ 0; `Runner` survives 10 000 actions for seeds 1..20 without an exception. Read
`backend/engine/src/main/java/engine/OrderBook.java` and `OrderBookInvariantsTest.java` first; reuse their
vocabulary. Add a class doc comment `Pattern: Model-based testing — …` only on `Runner`.

### LE-002 — Property: at the same price the earlier order executes first (intent 01, invariant 1)
- status: todo
- depends: LE-001
- size: S
- paths: `backend/engine/src/test/java/engine/model/**`
- verify: `./gradlew :backend:engine:test --tests 'engine.model.TimePriorityPropertyTest'`
- expect: green over 200 seeds × 500 actions

New test class `TimePriorityPropertyTest` (jqwik `@Property(tries = 200)` over `@ForAll long seed`, or a JUnit
loop over seeds if simpler). Using `ActionGen` and `Runner` from LE-001, keep a model of every resting order's
arrival order per price level. After every submit that trades, check: within one price level of the opposite side,
the trades consumed resting orders strictly in arrival order (an order is never filled while an earlier order at
the same price still rests with quantity). Fail with the seed and the step index in the message.

### LE-003 — Property: a market-order remainder never rests (intent 01, invariant 4)
- status: todo
- depends: LE-001
- size: S
- paths: `backend/engine/src/test/java/engine/model/**`
- verify: `./gradlew :backend:engine:test --tests 'engine.model.MarketRemainderPropertyTest'`
- expect: green over 200 seeds × 500 actions

New test class `MarketRemainderPropertyTest`. After every `SubmitMarket`, the id the book assigned to that market
order never appears among resting orders (`bids(depth)`/`asks(depth)` levels, or whatever read API exists), and a
later `cancel` of that id returns false. Also: the book's total resting quantity after a market order equals the
quantity before minus the market order's filled quantity. Seed and step index in failure messages.

### LE-004 — Property: a cancelled order never executes again (intent 01, invariant 5)
- status: todo
- depends: LE-001
- size: S
- paths: `backend/engine/src/test/java/engine/model/**`
- verify: `./gradlew :backend:engine:test --tests 'engine.model.CancelPropertyTest'`
- expect: green over 200 seeds × 500 actions

New test class `CancelPropertyTest`. Track every id for which `cancel` returned true. Check after every later step
that no `Trade` names a cancelled id (buy or sell side) and that cancelling it again returns false. Also check:
`cancel` of an id that was fully filled returns false.

### LE-005 — Property: no empty price level, best price backed by quantity (intent 01, invariant 6)
- status: todo
- depends: LE-001
- size: S
- paths: `backend/engine/src/test/java/engine/model/**`
- verify: `./gradlew :backend:engine:test --tests 'engine.model.LevelsPropertyTest'`
- expect: green over 200 seeds × 500 actions

New test class `LevelsPropertyTest`. After every step: every level returned by the book's depth view has quantity
> 0 and at least one order; best bid < best ask whenever both exist (invariant 3, re-checked here under the richer
generator); the sum of quantities in the depth view equals the model's sum of remaining quantities of resting
orders.

### LE-006 — Property: filled never exceeds quantity; remaining = quantity − filled (intent 01, invariant 7)
- status: todo
- depends: LE-001
- size: S
- paths: `backend/engine/src/test/java/engine/model/**`
- verify: `./gradlew :backend:engine:test --tests 'engine.model.FillAccountingPropertyTest'`
- expect: green over 200 seeds × 500 actions

New test class `FillAccountingPropertyTest`. Keep, per order id, its original quantity and the sum of traded
quantity from every `Trade` naming it. Check after every step: filled ≤ original; for resting orders the book's
remaining quantity (via depth view aggregation or an existing accessor) equals original − filled; every trade
quantity > 0 and its price lies within both orders' limits.

### LE-007 — A failing seed becomes a REPL script
- status: todo
- depends: LE-001
- size: S
- paths: `backend/engine/src/test/java/engine/model/**`
- verify: `./gradlew :backend:engine:test --tests 'engine.model.ReplScriptTest'`
- expect: green; the test shows a 3-action list rendered as REPL commands that the REPL grammar accepts

For teaching: when a property fails, Aika should be able to paste the actions into the REPL (`make repl`). Add
`engine.model.ReplScript.render(List<Action>)` returning the REPL commands (read `backend/repl` for the exact
syntax: buy/sell/market/cancel). Cancels by pick index must be resolved to the real id the book assigned, so
`render` takes the `Runner` result too. Test it on a hand-written 3-action list and compare with the expected
text. Do not edit the property tests of LE-002…LE-006 to call it (existing tests are never changed); add a short
note in `DECISIONS.md` on how to use `ReplScript` when a property fails, so later tests use it from the start.

### LE-051 — A reference order book: small, slow and obviously right
- status: todo
- size: S
- paths: `backend/engine/src/test/java/engine/ref/**`
- verify: `./gradlew :backend:engine:test --tests 'engine.ref.*'`
- expect: green; `ReferenceBook.java` is at most ~150 lines and its own example tests cover every rule of intent 01

The model for differential testing (LE-008…010): a second order book written from `intent/01-order-book.md` alone,
so plainly that a reader can check it line by line. In test sources only, package `engine.ref`:

- `ReferenceBook` with `long submitLimit(Side side, long price, long qty)`, `long submitMarket(Side side, long qty)`,
  `boolean cancel(long id)`, `List<RefTrade> lastTrades()` and `List<RefLevel> bids(int depth)` / `asks(int depth)`.
  Its own records (`RefTrade(buyId, sellId, price, qty, aggressor)`, `RefLevel(price, qty, orders)`); it may reuse
  only the `Side` enum of the engine — **never** the engine's book, matching code or helpers, or the comparison
  proves nothing.
- Data structure: one plain `ArrayList` of resting orders per side; matching by a linear scan for the best price,
  then the earliest arrival; ids from a counter starting at 1, assigned to every submitted order (market orders
  too), exactly as `DECISIONS.md` (increment 1) says the engine does — read those bullets and follow them.
- No optimisation, no streams that hide the order of operations; a short comment on each rule naming the invariant
  of intent 01 it implements.

`ReferenceBookTest` (new file): one example per invariant 1–7 of intent 01, plus a market order on an empty side and
a cancel of an unknown id. Do not compare with the engine here — that is LE-008.

### LE-008 — Differential test: the engine trades exactly like the reference book
- status: todo
- depends: LE-001, LE-051
- size: S
- paths: `backend/engine/src/test/java/engine/model/**`
- verify: `./gradlew :backend:engine:test --tests 'engine.model.DifferentialTest'`
- expect: green over 500 seeds × 1000 actions

The reference book (`engine.ref.ReferenceBook`, LE-051) is a deliberately naive implementation (lists, linear scans). Run the same action list
through `engine.OrderBook` and `ReferenceBook` and compare the trade list after every step (buyer id, seller id,
price, quantity, aggressor side). On the first difference fail with the seed, the step and the REPL script of
the prefix (LE-007). Do not change `ReferenceBook`; if the two books disagree, decide from `intent/01-order-book.md` and `DECISIONS.md` which one is wrong;
a bug in the engine is fixed in a new task (park this one with the counterexample), never by editing the reference.

### LE-009 — Differential test: same depth view after every step
- status: todo
- depends: LE-008
- size: S
- paths: `backend/engine/src/test/java/engine/model/**`
- verify: `./gradlew :backend:engine:test --tests 'engine.model.DifferentialDepthTest'`
- expect: green over 500 seeds × 1000 actions

Like LE-008, but compare the top-10 aggregated levels on both sides and the result of every cancel.

### LE-010 — A regression corpus from shrunk counterexamples
- status: todo
- depends: LE-008
- size: S
- paths: `backend/engine/src/test/java/engine/model/**`, `backend/engine/src/test/resources/regressions/**`
- verify: `./gradlew :backend:engine:test --tests 'engine.model.RegressionCorpusTest'`
- expect: green; the corpus folder has a README and at least one hand-made example

A failing seed is fragile (the generator may change). Add a shrinker (drop actions one by one while the
difference persists) and a test that replays every file in `src/test/resources/regressions/*.txt` (one action
per line) through both books. Seed it with one hand-written scenario of time priority.

## Game: lead the player (intent 04, draft) — logic and words only

### LE-052 — Goals: the one next thing to do, from the game's state
- status: todo
- size: S
- needs: godot
- paths: `game3d/scripts/core/goals.gd`, `game3d/tests/unit/test_goals.gd`
- verify: `make test-game3d`
- expect: all GUT tests pass, including the exhaustive "never stuck" test

Read `intent/04-guide-the-player.md` and `game3d/scripts/core/game_flow.gd` first. Write `class_name Goals`
(`extends RefCounted`, pure logic, no nodes, no scenes) with `static func next(state: int, ctx: Dictionary) -> Dictionary`
returning `{id, hint_key, place, action}`: `id` a short upper-case name (`BUY_PROVISIONS`, `PLAN_WITH_MARA`,
`FIRST_ORDER`, `SET_ANCHOR`, `SAIL_OR_STAY`, `READ_CHRONICLE`, `NEW_DAY`, `EXPLORE`), `hint_key` = `GOAL_<ID>`,
`place` a stable id of a person or building (take them from the scripts that build Spark Harbour; if none exists, use
`"mara"`, `"market"`, `"ladder"`, `"pier"`, `"chronicler"` and list them in a `PLACES` constant), `action` the
`GameFlow.State` the goal leads to (or -1 for an action inside a state). `ctx` carries the guard facts of
`GameFlow.refusal` plus `day` and `traded_today`. Doc comment `Pattern: …` only if you use a named pattern.

`test_goals.gd`: for every state × every combination of cushion/approved/holding/anchored × day 1 and day 2, `next`
returns a goal; when `action` is a state, `GameFlow` allows that move in that context (the "never stuck" invariant).

### LE-053 — Hint texts for every goal, ru and en
- status: todo
- depends: LE-052
- size: S
- needs: godot
- paths: `game3d/i18n/strings.csv`, `game3d/tests/unit/test_goal_texts.gd`
- verify: `make test-game3d`
- expect: all GUT tests pass

Add a row `GOAL_<ID>,<ru>,<en>` to `game3d/i18n/strings.csv` for every goal id of `Goals`. One short sentence, the
action and the place ("Купи провизию на шесть лун на рынке." / "Buy provisions for six moons at the market."), the
real term in brackets the first time it appears, as the existing `FLOW_NEED_*` rows do. No advice to buy or sell
any instrument. New test: every goal id has a non-empty ru and en text. These are drafts: mark each decision in
`DECISIONS.md` under the backlog heading as "copy draft, Aika reviews".

### LE-054 — The first day by the hand, as a test
- status: todo
- depends: LE-052
- size: S
- needs: godot
- paths: `game3d/tests/unit/test_first_day.gd`
- verify: `make test-game3d`
- expect: all GUT tests pass

New test only: start from `GameFlow` in PORT with an empty context on day 1; repeatedly take `Goals.next`, apply its
effect to the context (provisions bought, plan approved, order placed, Anchor set) or move `GameFlow` to its
`action`; assert the evening CHRONICLE is reached in at most ten steps and that no goal repeats more than twice. If
`Goals` cannot pass it, park with the trace — do not change `goals.gd` in this task.

### LE-055 — Every refusal names the goal that removes it
- status: todo
- depends: LE-052
- size: S
- needs: godot
- paths: `game3d/scripts/core/goals.gd`, `game3d/tests/unit/test_goal_refusals.gd`
- verify: `make test-game3d`
- expect: all GUT tests pass

Add `Goals.for_refusal(key: String) -> Dictionary` mapping every refusal key `GameFlow.refusal` can return
(`FLOW_NEED_PROVISIONS`, `FLOW_NEED_PLAN`, `FLOW_NEED_ANCHOR`, `FLOW_NO_EDGE`, `FLOW_NO_SAME`) to a goal. Test: the
map covers every key found in `game_flow.gd` (read the file in the test and collect `"FLOW_…"` strings), and doing
the goal's effect on the context makes the refused move allowed (where that applies).

## Lessons from the field guide (docs/teaching/field-guide-lessons.md) — logic only

### LE-056 — Trading mistakes, first batch: averaging down, no exit plan, size after a loss, revenge, before a report
- status: todo
- size: S
- paths: `backend/application/src/main/java/application/review/**`, `backend/application/src/test/java/application/review/**`
- verify: `./gradlew :backend:application:test --tests 'application.review.*'`
- expect: green; one example test per detector and one "clean session" test with no findings

Read `docs/teaching/field-guide-lessons.md` (table B) and `SessionReviewProjection.java` (how a session's orders,
fills and notes are folded). Write `application.review.TradingMistakes`: a pure function over the same journal
events for one account and one session that returns `List<Mistake(code, instrument, at, detail)>` for B6 (adding to
a losing position), B7 (a filled position with no stop/conditional order covering it at the end of the session),
B8 (order size at least 2× the median of earlier orders, placed within N sim minutes after a closed loss), B10 (a new
entry in the same instrument within N sim minutes after closing a loss) and B2 (an entry within two sim days before
a scheduled company report — read how `economy` schedules reports). Thresholds are constants with a one-line reason;
write them in `DECISIONS.md` (cheap to undo). No wall clock, money in minor units. Do not wire it into REST or
clients (that waits for Aika: LE-058).

### LE-057 — Trading mistakes, second batch: chasing a move, illiquid entry, early-riser chase
- status: todo
- depends: LE-056
- size: S
- paths: `backend/application/src/main/java/application/review/**`, `backend/application/src/test/java/application/review/TradingMistakesSecondBatchTest.java`
- verify: `./gradlew :backend:application:test --tests 'application.review.*'`
- expect: green

Extend `TradingMistakes` (same class — one rule in one place) with B1 (a buy after the instrument rose at least X%
since the session's first trade), B4 (an entry while the spread is at least K× its session median, from book
snapshots) and B5 (a buy in the first sim hour after a rise before the open, if the simulation has an open; if it
has no such phase, skip B5 and say so in `DECISIONS.md`). New test file only; the first batch's tests stay untouched.

### LE-058 — Show the mistakes in the session review (API and clients)
- status: todo
- depends: LE-056
- size: S
- paths: `api/openapi.yaml`, `backend/app/src/main/java/**`, `backend/app/src/test/java/app/MistakesContractTest.java`, `clients/web/src/api/schema.d.ts`, `clients/mobile/src/api/schema.d.ts`
- verify: `./gradlew :backend:app:test --tests 'app.MistakesContractTest' --tests 'app.ContractTest'`
- expect: green

Aika said yes on 2026-11-26 to the contract change and the review texts. Add `mistakes` to the `/session-review` response (contract first), filled from `TradingMistakes`; regenerate client
types. The screens that show them are a separate decision.

### LE-059 — Losses compound too: series sums for the lessons
- status: todo
- size: S
- needs: godot
- paths: `game3d/scripts/core/lessons.gd`, `game3d/tests/unit/test_lessons_series.gd`
- verify: `make test-game3d`
- expect: all GUT tests pass

Idea A13 of `docs/teaching/field-guide-lessons.md`. Add to `Lessons` (integer minor units, basis points, no floats):
`series_after(start: int, moves_bps: Array, fee_bps: int) -> int` (each move applied to the running balance, fee
charged per round trip) and `needed_to_recover_bps(loss_bps: int) -> int`. Tests: −10% then +10% leaves less than
the start; −50% needs +100%; a fee per round trip makes a winning series smaller than without it; rounding is down
and stated in the doc comment.

## Backend: flaky tests and structure

### LE-011 — Is WebSocketTest still flaky? Run it 20 times
- status: todo
- size: S
- paths: `backend/app/src/main/**`, `backend/app/src/test/java/app/support/**`, `docs/backlog/reports/websocket-flake.md`
- verify: `for i in $(seq 20); do ./gradlew -q :backend:app:test --tests 'app.WebSocketTest' --rerun || echo FAIL; done | grep -c FAIL || true`
- expect: prints 0 (grep's own exit code is ignored)

`WebSocketTest` was fixed once (DECISIONS.md, M2c: wait for every subscribe to be answered before trading); the
plan still lists it as unstable. Run the verify loop. If it prints 0, write
`docs/backlog/reports/websocket-flake.md` with the numbers (runs, failures, time) and stop. If it fails: find the
cause from the failing reports (`backend/app/build/reports/tests`). The test file itself must not be changed. If
the cause is in production code (a race in the WebSocket adapter, the sequencer or the throttle), fix it there with
a new test that shows the race. If the only fix is in the test, park the task with the diagnosis — Aika decides.

### LE-012 — Flake census of the whole backend
- status: todo
- size: S
- paths: `docs/backlog/reports/flake-census.md`
- verify: `test -s docs/backlog/reports/flake-census.md && grep -q 'runs:' docs/backlog/reports/flake-census.md`
- expect: the report exists with a line `runs: 5` and a table of tests that failed at least once (or "none")

Run `./gradlew test --rerun` five times (stop at 40 minutes total). Collect failures from the JUnit XML reports in
`backend/*/build/test-results/test/`. Write the report: runs, duration of each run, every test that failed with how
many times and the first line of the failure. No code changes. If something failed, the summary run turns it into
a proposal.

### LE-013 — ArchUnit: the engine is deterministic
- status: todo
- size: S
- paths: `backend/app/src/test/java/app/arch/**`
- verify: `./gradlew :backend:app:test --tests 'app.arch.EngineDeterminismTest'`
- expect: green

CLAUDE.md: the engine has no Spring, no I/O, no `Instant.now()`. Make it a test (ArchUnit is already on the test
classpath of `backend/app`; read `ArchitectureTest.java` for the style). New class `app.arch.EngineDeterminismTest`:
classes in package `engine..` do not call `Instant.now`, `LocalDate.now`, `LocalDateTime.now`, `Clock.system*`,
`System.currentTimeMillis`, `System.nanoTime`, `new java.util.Random()` without a seed (if ArchUnit cannot tell the
constructor apart, forbid `java.util.Random` entirely and check it passes today), and do not depend on `java.io..`,
`java.nio.file..`, `java.net..`, `org.springframework..`. If today's engine breaks a rule, do not weaken it: park.

### LE-014 — ArchUnit: money is never a double
- status: todo
- size: S
- paths: `backend/app/src/test/java/app/arch/**`
- verify: `./gradlew :backend:app:test --tests 'app.arch.MoneyTypesTest'`
- expect: green

CLAUDE.md: money and prices are integer minor units (`long`). New test `app.arch.MoneyTypesTest`: no field or
record component of type `double`, `float`, `Double`, `Float` or `BigDecimal` in packages `engine..` and
`application..` whose name contains `price`, `amount`, `balance`, `fee`, `cash`, `qty`, `money` (case-insensitive).
If an existing field legitimately is a ratio (e.g. a percentage as double), list it in an explicit allow-list in the
test with a one-line reason, and write the list in `DECISIONS.md`.

### LE-015 — Assistant: cache answers per (account, facts hash)
- status: todo
- size: S
- paths: `backend/application/src/main/java/application/assistant/**`, `backend/application/src/test/java/application/assistant/CachingAssistantTest.java`
- verify: `./gradlew :backend:application:test --tests 'application.assistant.*'`
- expect: green; the new test shows the second identical question does not reach the delegate

docs/STATUS.md (M4 risks): no per-session cache, ADR-0013 suggests one. Add a decorator `CachingAssistant`
implementing the `Assistant` port: key = (account id, question normalised by trim + lower case, a hash of the facts
passed to the assistant); bounded size (e.g. 256 entries, LRU via `LinkedHashMap`); no time-based expiry (the
engine side has no wall clock — facts change, so the key changes). Do not wire it into Spring here (that is
`backend/app`, another task); doc comment `Pattern: Decorator — …. See docs/adr/0013-…`. Tests: same key → one
delegate call; different facts → two; eviction after the bound; guarded answers (`guarded=true`) are cached too.

### LE-016 — A health endpoint, contract first
- status: todo
- size: S
- paths: `api/openapi.yaml`, `backend/app/src/main/java/**`, `backend/app/src/test/java/app/HealthContractTest.java`, `clients/web/src/api/schema.d.ts`, `clients/mobile/src/api/schema.d.ts`
- verify: `./gradlew :backend:app:test --tests 'app.HealthContractTest' --tests 'app.ContractTest' && cd clients/web && npm ci && npm test`
- expect: green; `GET /api/v1/health` answers 200 `{"status":"UP","journalEvents":<long>}` and is in the contract

The Docker image (LE-024) and a later deploy need a health check. Add `GET /health` to `api/openapi.yaml` first
(no auth; schema `Health {status: enum [UP], journalEvents: integer int64}`), then a controller in `backend/app` (no
Spring Actuator — one more dependency for one endpoint is not worth it; write the choice in `DECISIONS.md`). Test
in a new class `HealthContractTest` that validates the response against the contract the way `ContractTest` does.
Regenerate client types with `make gen-api`; commit the generated files unchanged by hand.

## Mutation testing (a threshold that can only go up)

### LE-017 — PIT for the engine, with a threshold that can only rise
- status: todo
- size: S
- paths: `backend/engine/build.gradle`, `build.gradle`, `backend/quality-gates/**`, `docs/backlog/reports/mutation-engine.md`
- verify: `./gradlew :backend:engine:pitest`
- expect: green; the report says the mutation score and the threshold equal to it (rounded down)

Add the Gradle plugin `info.solidsoft.pitest` (latest version on the Gradle plugin portal that supports Gradle 9
and Java 25; with the JUnit 5 plugin `pitest-junit5-plugin`). Put the shared part — plugin version, JUnit 5
plugin, the code that reads the threshold files — in the root `build.gradle` as a small helper any module can
apply, and apply it in `backend/engine` only. Target `engine.*`, all
engine tests; if the jqwik properties make it too slow (> 10 min), exclude classes named `*PropertiesTest` /
`*PropertyTest` from the mutation run only and write that down.

The threshold: files `backend/quality-gates/mutation-engine/*.txt`, each holding one integer; the build reads the
**maximum** of all of them as `mutationThreshold`. Raising it means adding a new file with a higher number; files
in `quality-gates` are append-only for agents (the merge gate refuses edits), so it can never go down. First file:
`backend/quality-gates/mutation-engine/001.txt` = today's score rounded down. Do not add pitest to `make test`
(Aika decides; `Makefile` is hers). Report: score, survived mutants by class, run time.

### LE-018 — PIT for the application module
- status: todo
- depends: LE-017
- size: S
- paths: `backend/application/build.gradle`, `build.gradle`, `backend/quality-gates/**`, `docs/backlog/reports/mutation-application.md`
- verify: `./gradlew :backend:application:pitest`
- expect: green; threshold file `backend/quality-gates/mutation-application/001.txt` = today's score rounded down

Same scheme as LE-017 for `backend/application` (target `application.*`, exclude `application.assistant.Claude*`
if it needs the network). Reuse the plugin setup from LE-017 — if LE-017 put it in a shared block, use that; do not
write a second copy of the threshold-reading code.

### LE-019 — Kill engine mutants and raise the bar
- status: todo
- depends: LE-017
- size: S
- paths: `backend/engine/src/test/java/engine/mutation/**`, `backend/quality-gates/mutation-engine/**`, `docs/backlog/reports/mutation-engine.md`
- verify: `./gradlew :backend:engine:pitest`
- expect: green; a new threshold file with a higher number than every earlier one

Read the surviving mutants of the engine (`backend/engine/build/reports/pitest`). Write new tests in package
`engine.mutation` that kill at least ten of them — each test named after the behaviour it pins, not after the
mutant. Equivalent mutants (no test can tell) go to the report with a one-line reason. Add a new threshold file
`00N.txt` with the new score rounded down. Update the report.

### LE-020 — Kill application mutants and raise the bar
- status: todo
- depends: LE-018
- size: S
- paths: `backend/application/src/test/java/application/mutation/**`, `backend/quality-gates/mutation-application/**`, `docs/backlog/reports/mutation-application.md`
- verify: `./gradlew :backend:application:pitest`
- expect: green; a new threshold file with a higher number than every earlier one

As LE-019, for `backend/application`. Priority: `Sequencer`, `StatementProjection`, `Atr`, `AchievementsProjection`.

### LE-021 — A CI job for mutation testing, proposed (Aika moves it into .github)
- status: todo
- depends: LE-018
- size: S
- paths: `docs/ci/proposed/**`
- verify: `ruby -ryaml -e 'YAML.load_file(ARGV[0])' docs/ci/proposed/mutation.yml && docker run --rm -v "$PWD:/repo" -w /repo rhysd/actionlint:latest docs/ci/proposed/mutation.yml`
- expect: both commands exit 0
- needs: docker

Agents never change `.github/`. Write `docs/ci/proposed/mutation.yml`: a weekly (and `workflow_dispatch`) job that
sets up Java 25 like `.github/workflows/ci.yml` and runs `./gradlew :backend:engine:pitest :backend:application:pitest`,
uploading the HTML reports as an artifact. Estimate its minutes per month in a comment at the top (free plan: 2000
minutes). Add `docs/ci/proposed/README.md`: what each file is and the one command to install it.

## CI/CD plan, steps 1–2 (no cloud stand, no secrets)

### LE-022 — Where CI time goes, and a proposed faster ci.yml
- status: todo
- size: S
- paths: `docs/ci/**`
- verify: `test -s docs/ci/ci-timing.md && ruby -ryaml -e 'YAML.load_file(ARGV[0])' docs/ci/proposed/ci.yml`
- expect: the report has a table of the last 20 runs (total and per step) and the proposal parses

Use `gh api repos/{owner}/{repo}/actions/runs?per_page=20` and the jobs endpoint of each run to get step durations
of `ci`. Write `docs/ci/ci-timing.md`: a table, the median, which steps dominate, and what caching already exists
(setup-gradle, npm cache). Then write `docs/ci/proposed/ci.yml`: the same job with improvements you can justify
from the numbers (e.g. Gradle configuration cache, `npm ci` only when locks changed, splitting backend and clients
into parallel jobs if that shortens wall time without doubling minutes). Each change gets a comment with the
expected saving. Do not touch `.github/`.

### LE-023 — ADR draft: CI/CD and the test stand
- status: todo
- size: S
- paths: `docs/adr/0039-ci-cd-and-test-stand.md`, `docs/adr/README.md`
- verify: `grep -q '^- Status: Proposed' docs/adr/0039-ci-cd-and-test-stand.md`
- expect: a Proposed ADR in the template's shape, listed in the ADR index

Step 0 of Aika's CI/CD plan. Copy the shape of `docs/adr/0000-template.md`. Context: the stages of the plan (gate,
image to GHCR, stand, client distribution, game builds on a self-hosted Mac, notifications). Options for the stand:
Oracle Cloud Always Free ARM, Hetzner CAX11 (~€4/month), none for now. Decision: written as a proposal with the
plan's order (image first, stand later); **Status: Proposed** — Aika accepts it, not an agent. Consequences: what
stays manual (secrets, the VM, the $99 iOS decision). If 0039 is already taken, taking another
number is impossible here (the merge gate allows only the listed paths): park the task and say so.

### LE-024 — Dockerfile for backend and bots
- status: todo
- depends: LE-016
- size: S
- paths: `Dockerfile`, `.dockerignore`, `docs/ci/docker.md`
- verify: `docker build -t le-backend:test . && docker run -d --name le-test -p 8091:8080 le-backend:test && for i in $(seq 60); do curl -fs localhost:8091/api/v1/health && break; sleep 2; done; docker rm -f le-test`
- expect: the curl prints `{"status":"UP",…}` before the loop ends; the container is removed
- needs: docker

Multi-stage: build with a JDK 25 image (`eclipse-temurin:25-jdk`) running `./gradlew :backend:app:bootJar`, run on
`eclipse-temurin:25-jre` as a non-root user; `bots.yaml` and `docs/lore/*.yaml` copied where `bootRun` finds them
(working dir = repo root layout); journal in `/data` (a volume), default `--exchange.journal=/data/journal.jsonl`;
`HEALTHCHECK` on `/api/v1/health`. `.dockerignore` keeps `node_modules`, `game3d/assets`, `build`, `.gradle`,
`data` out. `docs/ci/docker.md`: build, run, image size, start time. Never use port 8080 on the host.

### LE-025 — compose.yaml for a local stand
- status: todo
- depends: LE-024
- size: S
- paths: `compose.yaml`, `docs/ci/docker.md`
- verify: `PORT=8091 docker compose up -d --build && for i in $(seq 60); do curl -fs localhost:8091/api/v1/health && break; sleep 2; done; docker compose down -v`
- expect: the health JSON is printed, then everything is stopped

One service `exchange` from the Dockerfile, host port `${PORT:-8091}` → 8080, named volume for `/data`, the health
check, `restart: unless-stopped`. Document in `docs/ci/docker.md`. No secrets, no `ANTHROPIC_API_KEY` (the assistant
falls back to templates without it).

### LE-026 — Smoke test script: one order through the engine
- status: todo
- depends: LE-016
- size: S
- paths: `scripts/smoke/**`
- verify: `scripts/smoke/run-local.sh`
- expect: prints `smoke: ok` and leaves no process on port 8091 (`make ps` shows nothing of it)

`scripts/smoke/smoke.sh BASE_URL`: health → dev-login as a new user → deposit → place a limit buy that crosses a
resting sell placed by a second user → the statement of the first shows the trade → `smoke: ok`, exit 0; any step
fails → message and exit 1. Only `curl` and `jq`. `scripts/smoke/run-local.sh`: starts `make dev PORT=8091
JOURNAL=memory` in the background, waits for health, runs `smoke.sh`, always stops it with `make stop PORT=8091`
(trap). Read `api/openapi.yaml` for the exact requests.

### LE-027 — Proposed workflow: build the image and push it to GHCR on merge
- status: todo
- depends: LE-024
- size: S
- paths: `docs/ci/proposed/**`
- verify: `docker run --rm -v "$PWD:/repo" -w /repo rhysd/actionlint:latest docs/ci/proposed/image.yml`
- expect: exit 0
- needs: docker

`docs/ci/proposed/image.yml`: on push to `main` (and `workflow_dispatch`), build the Dockerfile with
`docker/build-push-action`, tag `ghcr.io/<owner>/learning-exchange:<short sha>` and `:main`, push with
`GITHUB_TOKEN` (`packages: write`), then run the smoke script against the image in the job. Comment at the top:
minutes per run, GHCR storage for a private repo, how to roll back (previous tag). Add it to
`docs/ci/proposed/README.md`.

## Mobile client «Ветрило»: tests without a screen

### LE-028 — i18n: the same placeholders in ru and en (mobile)
- status: todo
- size: S
- paths: `clients/mobile/test/i18n-placeholders.test.mjs`
- verify: `cd clients/mobile && node --test test/i18n-placeholders.test.mjs`
- expect: green, or a list of keys whose `{{…}}` placeholders differ — then fix those values in a separate task

New test: for every key, the set of `{{name}}` placeholders in `src/i18n/ru.json` equals the one in `en.json`, and
i18next plural suffixes (`_one`, `_few`, `_many`, `_other`) are complete for ru (one/few/many/other) and en
(one/other) wherever a key has any of them. If today's files break it, do not weaken the test: put the offending
keys in the PR description and park — fixing copy is another task (`clients/mobile/src/i18n/**`).

### LE-029 — i18n: English has no Cyrillic, Russian is not left in English (mobile)
- status: todo
- size: S
- paths: `clients/mobile/test/i18n-script.test.mjs`, `clients/mobile/src/i18n/en.json`
- verify: `cd clients/mobile && npm test`
- expect: green

New test: no value in `en.json` contains a Cyrillic letter; a value in `ru.json` identical to its en value is allowed
only for an explicit list (tickers, numbers, brand-free terms like "ATR") kept in the test. If en values contain
Cyrillic today, translate them (plain English, short — see `docs/prompts/claude-design-mobile.md` for tone) in the
same PR.

### LE-030 — Statement screen: logic out of the component, with tests
- status: todo
- size: S
- paths: `clients/mobile/src/app/statement.tsx`, `clients/mobile/src/statement.ts`, `clients/mobile/test/statement.test.mjs`
- verify: `cd clients/mobile && npm test`
- expect: green; the screen renders the same values (tsc passes; no JSX changes besides calls)

Read `src/app/statement.tsx`. Move every computation that is not JSX (grouping rows by day, sums of fees, sign
and colour choice as a string token, filters) into pure functions in `src/statement.ts`, called from the screen.
Test them with `node --test` like `test/finance.test.mjs` (money in minor units, edge cases: empty statement,
only fees, a negative balance). Do not change what the screen shows, its layout or styles.

### LE-031 — Deposits and FX screens: logic out, with tests
- status: todo
- size: S
- paths: `clients/mobile/src/app/deposits.tsx`, `clients/mobile/src/app/fx.tsx`, `clients/mobile/src/deposits.ts`, `clients/mobile/src/fx.ts`, `clients/mobile/test/deposits.test.mjs`, `clients/mobile/test/fx.test.mjs`
- verify: `cd clients/mobile && npm test`
- expect: green

As LE-030 for `deposits.tsx` (interest to date, term left, early-close preview) and `fx.tsx` (quote, spread, amount
conversions). Reuse `src/finance.ts` / `src/money.ts` when a function already exists there — never a second copy.

### LE-032 — Bonds and funds screens: logic out, with tests
- status: todo
- size: S
- paths: `clients/mobile/src/app/bonds.tsx`, `clients/mobile/src/app/funds.tsx`, `clients/mobile/src/bonds.ts`, `clients/mobile/src/funds.ts`, `clients/mobile/test/bonds.test.mjs`, `clients/mobile/test/funds.test.mjs`
- verify: `cd clients/mobile && npm test`
- expect: green

As LE-030 for `bonds.tsx` (YTM/duration display, coupon schedule, default badge) and `funds.tsx` (TER cost over a
holding period, index vs active comparison). If a formula duplicates server logic, keep the client one only for
display and say so in a comment; do not invent finance — check the numbers against the server tests in
`backend/engine/src/test/java/engine/M2bTest.java` / `M2cTest.java`.

### LE-033 — Calendar and company screens: logic out, with tests
- status: todo
- size: S
- paths: `clients/mobile/src/app/calendar.tsx`, `clients/mobile/src/app/company.tsx`, `clients/mobile/src/calendar.ts`, `clients/mobile/src/company.ts`, `clients/mobile/test/calendar.test.mjs`, `clients/mobile/test/company.test.mjs`
- verify: `cd clients/mobile && npm test`
- expect: green

As LE-030 for `calendar.tsx` (grouping events by simulation day, next event) and `company.tsx` (report surprise
sign, quarter labels).

### LE-034 — Review and achievements screens: logic out, with tests
- status: todo
- size: S
- paths: `clients/mobile/src/app/review.tsx`, `clients/mobile/src/app/achievements.tsx`, `clients/mobile/src/review.ts`, `clients/mobile/src/achievements.ts`, `clients/mobile/test/review.test.mjs`, `clients/mobile/test/achievements.test.mjs`
- verify: `cd clients/mobile && npm test`
- expect: green

As LE-030 for `review.tsx` (session review: win rate, R multiples) and `achievements.tsx` (sorting, progress).

### LE-035 — English design canvases S05–S08, with a check
- status: todo
- size: S
- paths: `docs/design/canvas/S05-Orders.en.dc.html`, `docs/design/canvas/S06-Leverage.en.dc.html`, `docs/design/canvas/S07-Deposit.en.dc.html`, `docs/design/canvas/S08-Statement.en.dc.html`, `clients/mobile/test/canvas-en.test.mjs`
- verify: `cd clients/mobile && node --test test/canvas-en.test.mjs`
- expect: green

The mobile design canvases in `docs/design/canvas/` have English only for screens 1–4 (the brief in
`docs/prompts/claude-design-mobile.md` asked for both languages). For S05–S08 make an English copy next to each
original: same markup and styles, `lang="en"`, every visible Russian string translated — prefer the exact English
string from `clients/mobile/src/i18n/en.json` for the same element. Do not change the Russian originals. New test
`canvas-en.test.mjs`: for every `*.en.dc.html` that exists, its Russian original exists, the en file has no
Cyrillic letters, and both have the same number of HTML elements (a crude structural check: count `<` tags).

### LE-036 — English design canvases S09–S12
- status: todo
- depends: LE-035
- size: S
- paths: `docs/design/canvas/S09-Assistant.en.dc.html`, `docs/design/canvas/S10-Glossary.en.dc.html`, `docs/design/canvas/S11-Onboarding.en.dc.html`, `docs/design/canvas/S12-RealWorld.en.dc.html`
- verify: `cd clients/mobile && node --test test/canvas-en.test.mjs`
- expect: green

As LE-035 for S09–S12 (S10b-Settings already has both languages).

### LE-037 — English design canvases S13–S17
- status: todo
- depends: LE-035
- size: S
- paths: `docs/design/canvas/S13-Company.en.dc.html`, `docs/design/canvas/S14-Calendar.en.dc.html`, `docs/design/canvas/S15-Bond.en.dc.html`, `docs/design/canvas/S16-Fund.en.dc.html`, `docs/design/canvas/S17-TicketJournal.en.dc.html`
- verify: `cd clients/mobile && node --test test/canvas-en.test.mjs`
- expect: green

As LE-035 for S13–S17.

## Web debug client

### LE-038 — i18n: the same placeholders in ru and en (web)
- status: todo
- size: S
- paths: `clients/web/src/i18n/placeholders.test.ts`
- verify: `cd clients/web && npx vitest run src/i18n/placeholders.test.ts`
- expect: green, or park with the offending keys (as LE-028)

As LE-028 for the web client's resources (read `src/i18n/i18n.ts` and `keys.test.ts` for where they live).

### LE-039 — E2E in the cloud on another port
- status: todo
- size: S
- paths: `clients/web/playwright.config.ts`, `docs/backlog/reports/e2e-cloud.md`
- verify: `(make dev PORT=8091 JOURNAL=memory >/tmp/dev.log 2>&1 &) ; for i in $(seq 90); do curl -fs localhost:8091/api/v1/instruments >/dev/null && break; sleep 2; done; cd clients/web && npm ci && E2E_API_URL=http://localhost:8091 npx playwright test; r=$?; cd ../.. && make stop PORT=8091; exit $r`
- expect: Playwright passes; nothing is left on port 8091

`make e2e` assumes the backend on 8080. Make the Playwright config read the API URL from `E2E_API_URL`
(default unchanged), passing it to the dev server as `VITE_API_URL`, and use the cloud's Chrome
(`CHROME_PATH`) when set, so no browser download is needed. Write the report: how to run E2E in a cloud session,
time taken, anything that failed. If Playwright cannot start a browser in the cloud, write that down and park.

## Games: logic only, under GUT (no change to how anything looks)

### LE-040 — check_data: every talk line is complete in both languages
- status: todo
- size: S
- paths: `game3d/tools/check_data.py`, `game3d/tools/test_check_data.py`
- verify: `python3 game3d/tools/check_data.py && python3 -m unittest game3d/tools/test_check_data.py`
- expect: both green

Extend `check_data.py` (it runs in CI via `make check-game3d-data`): every key used in `game3d/data/talks.json`
exists in `game3d/i18n/talk.csv` with non-empty `ru` and `en`; every `emotion` in `talks.json` is one of the
emotions that have portraits (read `docs/design/README.md` and `data/cutouts.json` for the list); every Amber Cliff
line has its French text and a gloss (ADR-0028). New unit tests for each new check on small inline fixtures.
If today's data fails a new check, list the failures in the PR and park (data fixes may need Aika).

### LE-041 — game/ (2D client): protocol parsing edge cases
- status: todo
- size: S
- needs: godot
- paths: `game/tests/unit/test_protocol_edges.gd`, `game/scripts/market_stream.gd`, `game/scripts/exchange_api.gd`
- verify: `make test-game`
- expect: all GUT tests pass, including the new file

New GUT test file: malformed JSON, an unknown message type, a book snapshot with an empty side, a trade with
quantity 0 or a negative price (rejected, logged, not crashing), numbers bigger than 2^31 (minor units are 64-bit).
If parsing crashes on one of them, fix the parser minimally.

### LE-042 — game/ (2D client): book model and order draft edge cases
- status: todo
- size: S
- needs: godot
- paths: `game/tests/unit/test_book_edges.gd`, `game/scripts/book_model.gd`, `game/scripts/order_draft.gd`
- verify: `make test-game`
- expect: all GUT tests pass

New tests: spread with one side empty; a level update to quantity 0 removes the level; an order draft with
quantity above the balance is invalid with a reason; money formatting of 0, negative and very large values matches
`clients/web/src/money.ts` (copy the expected strings from `money.test.ts`).

### LE-043 — game3d: SessionFacts edge cases
- status: todo
- size: S
- needs: godot
- paths: `game3d/tests/unit/test_session_facts_edges.gd`, `game3d/scripts/core/session_facts.gd`
- verify: `make test-game3d`
- expect: all GUT tests pass

`SessionFacts` is a fold over the day log (ADR-0023). New tests: an empty day; a day of only losses; a day with
only cancelled orders; folding the log in two halves and continuing gives the same facts as folding it at once
(if the API allows it — otherwise test that the fold is deterministic: same log, same facts); 64-bit money values.

### LE-044 — game3d: voyage plan and the simulation clock, edge cases
- status: todo
- size: S
- needs: godot
- paths: `game3d/tests/unit/test_voyage_clock_edges.gd`, `game3d/scripts/core/voyage_plan.gd`, `game3d/scripts/sim_clock.gd`
- verify: `make test-game3d`
- expect: all GUT tests pass

New tests: a voyage to the island the captain is on; a plan across a day boundary; the ×60 clock paused and
resumed; very long sessions (a year of simulated days) do not drift; time never goes backwards.

### LE-045 — game3d: every glossary term a lesson names exists
- status: todo
- size: S
- needs: godot
- paths: `game3d/tests/unit/test_lessons_glossary.gd`
- verify: `make test-game3d`
- expect: all GUT tests pass, or park with the list of missing terms

New test: every term referenced by `Lessons` and by `CaptainGlossary` exists in the game's glossary source (read
how `captain_glossary.gd` loads it — `docs/lore/glossary.yaml` via the BFF or a local copy) in both ru and en.

### LE-046 — game3d: every translation key used in scripts exists
- status: todo
- size: S
- needs: godot
- paths: `game3d/tests/unit/test_i18n_used_keys.gd`
- verify: `make test-game3d`
- expect: all GUT tests pass, or park with the missing keys

Like the mobile test "every t('…') key used in the code exists": scan `game3d/scripts/**/*.gd` for `tr("KEY")` and
`tr('KEY')`, and check that each key is in `game3d/i18n/strings.csv` (or `talk.csv` / `amber.csv`) with non-empty ru
and en columns.

## Docs and helpers for the other roles

### LE-047 — docs/STATUS.md: the ADR list matches the files
- status: todo
- size: S
- paths: `docs/STATUS.md`, `docs/adr/README.md`, `scripts/docs/check_adr_index.py`
- verify: `python3 scripts/docs/check_adr_index.py`
- expect: exit 0

`docs/STATUS.md` says "Proposed: none" while ADR 0029–0038 are Proposed. Write `scripts/docs/check_adr_index.py`:
reads every `docs/adr/NNNN-*.md` status line and checks that `docs/adr/README.md` lists each ADR with its status
and that the "ADRs (all)" line of `docs/STATUS.md` names the same sets. Fix `docs/STATUS.md` (and the ADR README if
it is behind). Only facts from the files; no new claims about the project.

### LE-048 — Teaching notes point at files that exist
- status: todo
- size: S
- paths: `scripts/docs/check_teaching_links.py`, `docs/teaching/README.md`
- verify: `python3 scripts/docs/check_teaching_links.py`
- expect: exit 0

`docs/teaching/README.md` lists 19 patterns with where they live and an exercise each. Write
`scripts/docs/check_teaching_links.py`: every repo path and every class name in it exists (`git ls-files`, grep).
Fix broken references in the README only if the new location is unambiguous; otherwise list them in the PR and
leave them.

### LE-049 — "Pattern:" comments: a report of the gaps
- status: todo
- size: S
- paths: `scripts/docs/pattern_comments.py`, `docs/backlog/reports/pattern-comments.md`
- verify: `python3 scripts/docs/pattern_comments.py > /dev/null && test -s docs/backlog/reports/pattern-comments.md`
- expect: exit 0 and the report exists

CLAUDE.md: a class implementing a named pattern starts with `Pattern: <name> — …. See docs/adr/…`. Write
`scripts/docs/pattern_comments.py`: for every pattern in `docs/teaching/README.md`, find the classes it names and
report whether their doc comment has the `Pattern:` line and whether the ADR it cites exists. Output a Markdown
table into the report. Do not add the comments in this task (that touches many files; the summary run may propose
it in pieces).

### LE-050 — A newcomer's scenario through the API, for the «user» role
- status: todo
- depends: LE-026
- size: S
- paths: `scripts/scenarios/**`
- verify: `scripts/scenarios/run-local.sh`
- expect: prints `scenario: newcomer ok` and a short transcript; nothing left on port 8091

The daily «user» run walks the product as a newcomer without a screen. Give it a script:
`scripts/scenarios/newcomer.sh BASE_URL` — log in, look at balances, read the glossary entry for "spread" via the
mobile BFF, place a too-large order and print the rejection message as the user would see it, deposit, buy, look
at the statement, ask the assistant "what is a stop order?" (template answer without a key). Print each response's
user-visible text (not raw JSON) so the run can judge clarity. `run-local.sh` starts and always stops `make dev
PORT=8091 JOURNAL=memory`, like `scripts/smoke/run-local.sh` (reuse it if LE-026 made it reusable; do not copy).

## Added by intake

Appended by `scripts/backlog/backlog.py intake`, at most 5 a day.

### AUTO-20261125-1 — Property: every trade is at the resting order's price
- status: todo
- size: S
- paths: `backend/engine/src/test/java/engine/model/MakerPricePropertyTest.java`
- verify: `./gradlew :backend:engine:test --tests 'engine.model.MakerPricePropertyTest'`
- expect: green over 200 seeds × 500 actions; the test also asserts it met at least one trade where the taker's limit was strictly better than the maker's price (so "maker price" and "taker limit" were told apart)
- source: docs/backlog/proposals/2026-11-25-analyst.md#1
- added: 2026-11-25

Why: intent/01-order-book.md:13 promises "Trades are produced with the resting order's price", but no test checks it. `OrderBookInvariantsTest.java:72-75` only checks the taker's limit is not crossed, and queued LE-006 checks only that the price "lies within both orders' limits" — a book that traded at the taker's limit would pass both.

New test class in package `engine.model`, test sources only. Read `Runner.java` and `TimePriorityPropertyTest.java`
in the same folder first and reuse their style (JUnit loop over seeds 1..200, `ActionGen.generate(seed, 500)`,
`Runner.run(...)`, seed and step index in every failure message).

For each step with trades, take the Runner's live-order map of the step *before* (`Step.live()` of the previous
step; empty before step 0). For each `Trade t`: the maker id is `t.sellOrderId()` when `t.aggressorSide()` is BUY,
else `t.buyOrderId()`. Assert the maker is in that previous live map and `t.price() == maker.price()`. Also assert
that the taker id (the other side of the trade) equals `step.orderId()`. Count trades where the taker was a
`SubmitLimit` whose limit differs from `t.price()`, and assert that count > 0 at the end (non-vacuous).
Do not edit any existing file (existing tests are append-only). No `Pattern:` comment needed.

### AUTO-20261125-2 — ArchUnit: bots never reach the ledger, the accounts or the clock control
- status: todo
- size: S
- paths: `backend/app/src/test/java/app/arch/BotsHaveNoPrivilegesTest.java`
- verify: `./gradlew :backend:app:test --tests 'app.arch.BotsHaveNoPrivilegesTest'`
- expect: green; the rules fail if a class in `bots..` is made to use one of the forbidden types or methods (check by hand once, do not commit the breaking change)
- source: docs/backlog/proposals/2026-11-25-analyst.md#2
- added: 2026-11-25

Why: intent/02-platform.md invariant 3 ("Bots have no privileges a human client does not have") and docs/adr/0007-bots-are-api-clients.md:9,31. `backend/app/src/test/java/app/ArchitectureTest.java:29-32` forbids only `engine.Exchange`, `engine.OrderBook` and `application.ExchangeService`; `engine.Accounts`, `engine.Ledger` and `engine.Command` (state changes outside the port's checks) and `TradingService.setClock` (moves time for every client) are not covered, while `backend/bots/build.gradle:5` puts all of `application` and `engine` on the bots' classpath.

New ArchUnit test class `app.arch.BotsHaveNoPrivilegesTest` (ArchUnit is already on the test classpath of
`backend/app`; copy the annotations of `ArchitectureTest.java`: `@AnalyzeClasses(packages = {"engine",
"application", "bots", "app"}, importOptions = ImportOption.DoNotIncludeTests.class)`). Rules on classes in
`bots..`: no dependency on `engine.Accounts`, `engine.Ledger`, `engine.Command` (and its nested types); no call to
`application.TradingService.setClock` (any overload). Today's bots only import `engine.Order`, `engine.Event`,
`engine.OrderView`, `engine.Balance` and the port, so it should pass as is. If today's code breaks a rule, do not
weaken the rule: park the task with the class and line. Do not edit `ArchitectureTest.java`. Coordinate nothing
with LE-013/LE-014: they add other files in the same folder.

### AUTO-20261125-3 — Property: the bare order book is deterministic
- status: todo
- size: S
- paths: `backend/engine/src/test/java/engine/model/OrderBookDeterminismPropertyTest.java`
- verify: `./gradlew :backend:engine:test --tests 'engine.model.OrderBookDeterminismPropertyTest'`
- expect: green over 200 seeds × 500 actions; two runs of one action list give equal step lists, two different seeds give different ones
- source: docs/backlog/proposals/2026-11-25-analyst.md#3
- added: 2026-11-25

Why: CLAUDE.md "Engine … is framework-free and deterministic" and intent/02-platform.md invariant 4 (replay gives the same state) are tested only at the `Exchange`/journal level (`ExchangePropertiesTest.java:44`, `M2aPropertiesTest.java:50`); nothing shows the `OrderBook` itself returns the same ids, trades and depth for the same input — the replay checks in `MarketRemainderPropertyTest`/`CancelPropertyTest` compare only ids and depth, not trades.

New test class in package `engine.model`. For seeds 1..200: `List<Action> a = ActionGen.generate(seed, 500)`;
assert `Runner.run(a).equals(Runner.run(a))` (all types in `Runner.Step` are records or unmodifiable collections,
so `equals` compares values); on failure, find and print the first differing step index with both steps. Also
assert that seed 1 and seed 2 give different step lists (non-vacuous). Read `Runner.java` first; do not edit it.

### AUTO-20261125-4 — Market data: a trade queued before a tick goes out in that tick
- status: todo
- size: S
- paths: `backend/app/src/test/java/app/ws/TradeWithinOneTickTest.java`
- verify: `./gradlew :backend:app:test --tests 'app.ws.TradeWithinOneTickTest'`
- expect: green and deterministic (no sleeps, no real clock): after `onEvents([TradeExecuted])` and one call of `tick()`, the subscribed session has received a `trades` message for that instrument
- source: docs/backlog/proposals/2026-11-25-analyst.md#4
- added: 2026-11-25

Why: intent/02-platform.md invariant 2 says "within one market-data tick" (`MarketDataHub.java:45`, 100 ms), but the only test, `WebSocketTest.java:97`, allows 1 000 ms ("a tick or so", i.e. ten ticks) through real sockets and timing. A unit test of `MarketDataHub.tick()` (package-private, `MarketDataHub.java:149`) can check the invariant exactly.

New test in package `app.ws` (same package as `MarketDataHub`, so `tick()` is reachable). Read `MarketDataHub.java`
(constructor, `onEvents`, `handleTextMessage`, `tick`) and `WebSocketTest.java` (how a client subscribes; message
shapes) first. Build the hub with a real `application.ExchangeService` in memory if it is cheap to construct (look
at how `backend/app` tests or `app.config` build it), else a `java.lang.reflect.Proxy` of `TradingService`
returning empty lists/defaults; `new DevAuth(market)`; a `JsonMapper` as the app builds it. Subscribe a fake
`WebSocketSession` (a `Proxy` recording `sendMessage` calls) to the instrument's trades channel through
`handleTextMessage`, call `onEvents(List.of(<a TradeExecuted>))`, then `tick()` once, and assert a trades message
was sent. Stop the hub's scheduler at the end (`stop()` is package-private) — and if its background ticker can
race your direct `tick()` call, assert "sent by the time `tick()` returns" rather than "sent by this call".
If the hub cannot be built without Spring or without changing main code, park the task and say why; do not
change main code.

### AUTO-20261125-5 — Mobile: a readable message for every refusal code, and a test that keeps it so
- status: todo
- size: S
- paths: `clients/mobile/src/i18n/ru.json`, `clients/mobile/src/i18n/en.json`, `clients/mobile/test/errors.test.mjs`
- verify: `cd clients/mobile && npm ci && npm test`
- expect: green; the new test reads every constant of `backend/engine/src/main/java/engine/Rejection.java` and finds `errors.<CODE>` in both `ru.json` and `en.json`; it fails if a constant is added there without a message
- source: docs/backlog/proposals/2026-11-25-user.md#1
- added: 2026-11-25

Why: the engine can refuse with 18 codes (`Rejection.java`), the mobile catalogue `errors` has only 14 of them — `MARKET_CLOSED`, `DEFAULTED`, `ALREADY_ANNOTATED`, `NOTHING_TO_PAY` are missing. `clients/mobile/src/components/OrderTicket.tsx:77` calls `t(\`errors.${e.code}\`)` with no `defaultValue`, so an order on a halted market (`Exchange.java:367-368`, `MARKET_CLOSED`) shows the raw key «errors.MARKET_CLOSED» to the person. Also «Недостаточно средств» / «Insufficient funds» (`errors.INSUFFICIENT_FUNDS`) leaves a newcomer guessing: I had 100 000 SPARK and did not know a limit buy reserves price × quantity + fee, or that money in my open orders is already taken.

Add four keys under `errors` in both files (one short sentence, real terms only — the app knows no lore):
`MARKET_CLOSED` «Торги по этому инструменту сейчас остановлены» / «Trading in this instrument is halted right now»;
`DEFAULTED` «Эмитент объявил дефолт — операция недоступна» / «The issuer has defaulted — not available»;
`ALREADY_ANNOTATED` «У этой заявки уже есть запись в журнале сделок» / «This order already has a trade-journal note»;
`NOTHING_TO_PAY` «Платить нечего» / «Nothing to pay». Reword `INSUFFICIENT_FUNDS` to say why:
«Недостаточно свободных средств: покупка резервирует цену × количество + комиссию, деньги в открытых заявках заняты» /
«Not enough free funds: a buy reserves price × quantity + fee, and money in open orders is taken». Keep every other
value as it is. New test `clients/mobile/test/errors.test.mjs` in the style of `test/i18n.test.mjs` (node:test,
`readFileSync`): collect the enum constants with a regex over `Rejection.java` (lines that are only `NAME,` or `NAME`)
and assert each is a key of `errors` in ru and en. Do not edit `test/i18n.test.mjs` or any component. Log the copy
in `DECISIONS.md` as "copy draft, Aika reviews".

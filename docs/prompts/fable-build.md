# Prompt for Fable: build the platform end to end

> Paste everything below the line into a new Claude Code session opened in
> `~/my projects/learning-exchange`, model Fable. Run it on a new branch from `feat/order-book`.
> Before running: the Gemini design tokens are saved to `docs/design/` (the build can start without them:
> use placeholder tokens and swap later). Lore decisions are already in `docs/lore/world-bible.md`.

---

You are building **learning-exchange**: a small but real exchange with trading bots, one backend, and three clients —
a web debug client, a mobile super-app «Ветрило» (Vetrilo), and a PC trading-RPG «Летопись Ветров» (Chronicle of Winds). This is Aika's learning project:
she is a Java backend developer at a bank and will study **design patterns and finance from this code**. Code quality,
explicit patterns and written decisions matter as much as features.

## Read first (in this order)
1. `CLAUDE.md` — rules for this repo.
2. `intent/01-order-book.md`, `DECISIONS.md`, and the existing code in `src/` — increment 1, the order book. Keep its invariants.
3. `intent/02-platform.md` — what we are building and the new invariants.
4. `docs/adr/` — 15 ADRs. 0001 is Accepted; the rest are **Proposed**: implement them, and when you deviate, write a superseding ADR saying why.
5. `docs/lore/world-bible.md` — the game world, characters, acts, glossary mapping lore ↔ real finance terms.
6. `docs/design/` — design tokens and screen designs for the mobile app, if present.

Finance background is in Aika's vault: `~/obsidian/pet-projects/finance/` (`must-know.md`, `stop-loss-take-profit.md`,
`fx-market-kz.md`). Use it for domain rules (stop triggers on last trade price, stop-out at 50% collateral, 10% income tax, spread).

## Goal of this run
**Everything works end to end**, and is pleasant to touch. Aika must be able to:
1. Run one command and see a live market (bots trading) in the web client.
2. Open the mobile app in a simulator, log in as a dev user, see balances, exchange currency with a visible spread,
   place limit/market orders and a stop-loss, and see the statement with fees.
3. Open the game in Godot, start Act I/II vertical slice, trade on the Ladder against the same bots, see the same
   account change in the mobile app.
4. Read an ADR for every architectural pattern used, and find the pattern named in the code.

## Stack (from the ADRs — use latest stable versions, check docs with context7 before pinning)
- Backend: Java 25, Gradle multi-module, Spring Boot (latest), WebSocket, ArchUnit, JUnit 5, jqwik for property tests.
- Contract: OpenAPI 3.1 + AsyncAPI 3 in `api/`; generate the TypeScript client (`openapi-typescript` or `orval`, record the choice).
- Web: React + Vite + TypeScript + TanStack Query.
- Mobile: Expo (latest SDK) + React Native + TypeScript strict, Expo Router, TanStack Query, Zustand, React Hook Form + Zod.
- Game: Godot 4 (latest stable), typed GDScript, GUT for tests.
- Assistant: Anthropic API behind a port; default model `claude-haiku-5-5`, configurable; template fallback without a key.

## Milestones — each ends with everything runnable and a short demo script in `docs/demo/MN.md`

**M0. Repo reshape.** Move increment-1 code into `backend/engine` without changing behaviour (all tests pass).
Monorepo layout per ADR-0009. `make dev`, `make test`. README "how to run each part". Repo-level CI config optional.

**M1. Walking skeleton (all layers, thin).**
- Engine: accounts and balances with funds reservation; one instrument `SILK/SPARK`; fees.
- Sequencer per instrument (ADR-0006) — first a test showing the race on the old book, then the fix.
- Event journal to a JSON-lines file + replay on start (ADR-0005). Simulation clock with pause/speed.
- API: dev login (name → token, no passwords), get accounts, place/cancel order, book snapshot, trades; WebSocket book/trades.
- Bots: market maker + noise, seeded, from `bots.yaml`.
- Web client: book (ladder view), trades tape, order form, my orders, balances.
- Mobile: login, home with balances, instrument screen with book and order form, language switch ru/en.
- Game: main menu (language switch ru/en) → harbour scene → Ladder scene showing the live book with real-term labels, place limit/market order, see fill.
- i18n set up in all three clients with a test that every key exists in `ru` and `en`.
**Demo:** start backend, open all three, place an order in the game, see it in web and mobile.

**M2. Real finance mechanics.**
- Second instrument `AMBER/SPARK` (FX) and catalogue with real/lore names in ru/en (ADR-0012), `docs/lore/glossary.yaml` served by BFFs (ADR-0004).
- Real market data port + first adapter (ADR-0015): «Реальный мир» tab in mobile and web with USD/KZT, paper positions.
- Conditional orders service (ADR-0008): stop-limit, stop-market, trailing TP, TP+SL OCO; trigger on last trade price;
  state machine visible in UI ("triggered" ≠ "filled").
- Leverage ×4 on FX with margin monitor and stop-out at 50% collateral.
- Statement projection: every operation with fee, spread paid (vs mid), tax 10% on realised profit for the period.
- Deposits with compound interest accrued by the simulation clock.
- Bots: momentum, mean-reversion, index investor, fundamentalist; world events (storms = volatility regimes) driving fair value.
- Company stocks with **quarterly reports** (world bible §5a, ADR-0007): `CorporateEvents` publishes consensus, then a report while the market
  is closed; the open gaps by the surprise (fact − consensus), not by the profit itself; optional short post-report drift.
  Report = revenue, net profit, EPS, debt, operating cash flow, dividend, guidance; derived P/E, debt/profit, dividend yield.
  Earnings calendar endpoint; reports are journalled events, so the assistant can explain "what changed vs expectations".
- **Economic calendar and central bank** (world bible §5b, ADR-0007 `MacroEvents`): 8 rate decisions a year with consensus and inflation;
  rate drives new deposit rates, bond prices and the FX pair. Real NBK base rate and decision dates shown in «Реальный мир» (ADR-0015).
- **Bonds**: face value, coupon, maturity, credit rating; **yield to maturity always shown**, duration; coupon payments and default as journalled events.
- **ATR**: computed per instrument (14 periods, Wilder smoothing); position sizing helper gets a "stop = k × ATR" mode; still risk in R.
- **Trading journal**: every order can carry "why", market conditions and mood; the session review uses them.
- **Dividends**: record/ex-dates, price adjusted at the ex-date open, statement shows dividend and tax.
- Mobile: FX exchange screen (buy/sell rates and spread shown explicitly), brokerage with stop orders and position sizing helper
  (`qty = capital × risk% / (entry − stop)`), deposits with a rule-of-72 hint, statement, glossary toggle «Словарь мира».
- Mobile: company card (key metrics, last report vs consensus, earnings calendar, warning "report tonight — gap risk for your stop",
  insider trades list, dividend ex-date on the chart).
- Mobile: economic calendar screen, bond screen (YTM, rating, duration), fund card with TER, journal fields in the order ticket.
- Real-world reports (ADR-0015): links to/short metrics from public reports of KASE issuers only if the source's terms allow; otherwise skip and note in STATUS.md.

**M3. The game vertical slice.**
- Two islands (Гавань Искр, Шёлковый Плёс), sailing between them advances the simulation clock.
- Game flow state machine: Port → Plan voyage (Mara checks risk ≤1% and the Anchor = stop) → Trading on the Ladder → Sailing (events, storm) → Evening chronicle.
- Act I (debt, provisions = cushion, garden = compound interest, fog = inflation) shortened; first half of Act II (spread, fees, liquidity); the first storm and the Anchor lesson including a gap through the stop.
- Evening chronicle: assistant review from computed `SessionFacts` (R per voyage, expectancy, fees and spread paid, vs Бабушка Ветла's basket); shows the real-world name of each lesson.
- "Re-read the chronicle": replay the day from the journal.
- Placeholder art in one coherent palette; UI readable at 1080p.
- «Словарь капитана» (in-game glossary) filling up as terms are introduced; «Реальный мир» board on the Exchange with USD/KZT.
- One Кузня workshop stock and one report season: consensus from Ольва Перо → report at night → gap at open; quest «Рекорд, а акция упала»
  and the Anchor-through-gap scene on report night.

**M4. Assistant and polish.**
- Assistant port with Claude and template adapters (ADR-0013); in-app «Помощник» Q&A grounded in the user's facts; disclaimer.
- Achievements shared between game and app (same account events).
- Performance pass: book updates throttled to clients, memoised rows on mobile.
- A short `docs/teaching/` index: for each pattern — where in code, which ADR, a 5-minute exercise for Aika.
- Game quests from world bible §4 and §5b if time allows, in this order: rate decision of Совет Казначеев, «Наследство деда» (lump sum vs DCA),
  «Золотой Парус» vs Корзина Ветлы (fees), «Корзина уплыла» (rebalancing), «Щедрая гильдия» (bond default), insider records, dividend day.
- Rebalancing reminder in the app (twice a year, when a share drifts more than 5 percentage points) and a lump-sum vs DCA calculator with honest historical statistics.

Do the milestones in order. Do not start M(n+1) until M(n)'s demo works. If time runs out, a fully working M2 beats a half-done M4.

## Product rules (Aika's decisions)
- **Russian and English everywhere from M1**, switchable at runtime without restart (ADR-0014). No hard-coded UI strings.
- **Real finance terms on every control and number**, in the game too; lore names are secondary labels and dialogue flavour (ADR-0012, world bible §6).
- **Real market data** where a legal free source exists: at least USD/KZT; read-only + paper positions, source and timestamp shown (ADR-0015).
  Check each source's terms of use before writing an adapter; if unsure, ship the `StaticSampleData` adapter and note it in STATUS.md.
- Product names and bundle/package ids in one config place per client (renaming must be a one-line change).
- Hero: a young captain who inherited grandfather's ship «Попутчик» and his debt (world bible §3).

## Engineering rules
- ADR before code for anything costly to reverse; accept Proposed ADRs as you implement them.
- Name patterns in doc comments: `Pattern: Strategy — bots differ only in decision logic. See docs/adr/0007-….md`.
  Expected patterns at least: Ports & Adapters, Repository/Journal, Event Sourcing + projections, Single Writer, Strategy, Observer,
  State machine, Factory, Command, BFF, Anti-corruption layer, Template Method, Idempotency key, Fallback.
  Don't force patterns where plain code is clearer — say so in `DECISIONS.md` instead.
- Tests: engine and money logic by example + property tests (invariants of intents 01 and 02); contract test validating responses
  against `api/openapi.yaml`; one E2E per client for the skeleton (Maestro for mobile, GUT headless for the game, Playwright for web).
- Money: `long` minor units everywhere; no floating point for money in any language (use integers/strings on clients).
- Determinism: seeded randomness, injected clock; replay test proves invariant 4 of intent 02.
- Security for a learning app: dev tokens only, CORS for local clients, no secrets in the repo (`.env.example`).
- No copying of existing games or bank brands. No investment advice in assistant output.
- Commits: small, imperative messages, one concern per commit, **no AI attribution trailers**. Don't push or open PRs; Aika does that.

## When you're done (or out of budget)
Write `docs/STATUS.md`: what works (with demo commands), what doesn't, which ADRs are Accepted/Proposed/Superseded,
known risks, next steps. Update `DECISIONS.md` for every small behaviour choice you made.

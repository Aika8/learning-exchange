# Status

Updated: 2026-11-17, G3D looks, talk, Amber Cliff. Demos: `docs/demo/M4.md`, `docs/demo/G3D-polish.md`, `docs/demo/G3D-walk.md`,
`docs/demo/G3D-looks.md`, `docs/demo/G3D-talk.md`, `docs/demo/G3D-amber.md`.

## G3D crypto island (ADR-0031, Proposed) — `docs/demo/G3D-crypto.md`
- A fifth island: a night town of neon towers with the Exchange That Never Closes, drawn as synthwave pixel art
  (twelve colours in flat tones, texels fixed to the world, sharp edges, a striped sun, a ground grid, nothing animated; reworked after Aika found screen pixels hard on the eyes). A place and a style: no
  crypto mechanics (they wait for intent 03). Four islanders and three robots; the game's own wind coin, no real
  coin's mark or name (a test guards it). Audit 0, GUT 113, 118 fps average at 1080p (1 %-low 57–69).

## G3D short sellers' island (ADR-0030, Proposed) — `docs/demo/G3D-shorts.md`
- A fourth island: a tilted town of crooked houses and leaning towers with the Exchange of Falling Prices, drawn as
  noir (black, white, one red; fog, slanted rain). A place and a style: no shorting mechanics (they wait for intent
  03). Four islanders talk; the captain is redrawn in noir on landing. Audit 0, GUT 109, 118 fps average at 1080p.

## G3D techniques (ADR-0029, Proposed) — `docs/demo/G3D-techniques.md`
- Silk Reach is drawn as katazome (indigo, cream, a rare rust; patterns in world space), Amber Cliff in pen and
  watercolour, from Aika's sheets 27–34. The captain is redrawn in the technique of every port; a test holds every
  technique to it. GUT 105. Open: the islands' shapes do not follow those sheets yet.

## G3D sheets, second batch — `docs/demo/G3D-sheets.md`
- Eleven more expression sheets: every speaker but the five strollers of Amber Cliff has drawn faces (102 portraits).
- Props of Spark Harbour rebuilt in code from the props sheet (`scripts/props.gd`); the Chronicler recoloured to
  the new sheet. GUT 103. Open: the harbour's layout from sheet 24 (rope bridges, islets, waterfall) is not built;
  the audit reports a harmless nook at the north rim.

## G3D Amber Cliff (ADR-0028, Accepted) — `docs/demo/G3D-amber.md`
- A third, bigger island, «La Falaise d'Ambre»: a French town (quay, square, bank, bureau de change, bakery, café,
  bookshop, lighthouse). Signs, prompts and talks are French in either game language; hold T for the gloss.
  Drawn as a ligne-claire album page. Reached by the packet boat from the wharf. Each place teaches one finance idea.
- Audit 0 findings on the island, GUT 100, 117–119 fps average at 1080p (1 %-low 59–97 across the islands).
- Open: the French needs a reader; no concept sheets for the town and its people; the bible does not yet say that
  Amber Cliff has its own language.

## G3D talk (ADR-0027, Accepted) — `docs/demo/G3D-talk.md`
- Talking opens a comic page: frames with drawn portraits from Aika's expression sheets (six heroes × six
  emotions, `docs/design/concepts/06…12`); the face changes with the line (`emotion` in `game3d/data/talks.json`).
  Words are `game3d/i18n/talk.csv` (ru, en). People without a sheet get a plain drawn stand-in. GUT 102.

## G3D looks (ADR-0026, Accepted) — `docs/demo/G3D-looks.md`
- Every island is drawn in its own technique: Spark Harbour in pen and ink as before, Silk Reach as printed silk
  (four dye baths, a light line, a weave). The wind restyles the captain from one technique into the other. GUT 88.

## G3D island styles (ADR-0025, Accepted) — `docs/demo/G3D-islands.md`
- Each island draws a slight variant of the ink style (`IslandStyle`: line, tint, paper, hatching, sun). A captain
  who arrives from another island is restyled by the island's wind: a swirl and a wave from boots to hat. GUT 88.

## G3D walk fixes — `docs/demo/G3D-walk.md`
- The audit now finds traps, walls and rails you can walk through, and villager strolls that cannot be finished.
  Found and fixed: rails without colliders (the wharf was entered through one), a pier at Silk Reach that did not
  reach the walkable ground (the captain could not leave it), frozen patches on the wharf deck (physics is Jolt now),
  the ship's vane over the pier. Audit 0 findings, GUT 83, 120 fps at 1080p.

## G3D style (ADR-0024, Accepted) — `docs/demo/G3D-style.md`
- Default look is stylised low-poly built in code; people are faceless silhouettes from the concept sheets on a
  code-made skeleton with the same gait; ink outline by default, engraving on V; `--pbr` keeps the old look.
- 118 fps average at 1080p on the laptop (display cap 120), GUT 79, world audit 0 problems.

## G3D polish (after M4) — `docs/demo/G3D-polish.md`
- World audit (`WorldProbe`, `--audit`): 451 problems before → 0 after on 1270 grid points, 8384 walks, 172 objects
  (holes, falls, walk-through buildings and props, floating props, z-fighting, missing LODs). GUT 59 → 74.
- Every building and prop has a collider that follows its shape; wharf and pier decks with floors; invisible fences
  round the islands and decks; spring-arm camera stops at walls.
- Modular half-timbered houses, windmill and hall interior rebuilt; grime decals. No new assets.
- People dressed for the age of sail in code (`Costume`): captain in tricorn, coat, sash and boots; sailors in stripes,
  bandana and slops; traders and townsfolk in period dress. No jeans, T-shirts, fedora.
- Walking: acceleration, run (Shift), stairs and slopes; computed gait with foot IK (idle/walk/run); villagers on a
  navmesh with avoidance.
- Harbour fps at 1080p (Apple M5): average 65–109 (was 55–118 with 45–65 ms frames after a camera jump); the long
  frame is gone (SDFGI off by default). 1%-low is 53–57 fps in the three heaviest views — a hard 60 floor not reached.
- Not done: real animation clips (needs a source decision); M3 `--demo` not re-run against a live exchange.

## M4 — what works
- Assistant (ADR-0013, now Accepted): port `Assistant`, `TemplateAssistant`, `ClaudeAssistant` (Messages API, model from
  `assistant.model`, default `claude-haiku-5-5`, key only from env `ANTHROPIC_API_KEY`, `.env.example`), `FallbackAssistant`
  + `AdviceGuard` (ru/en buy/sell advice → template, `guarded=true`; advice questions never reach the model). Facts from
  statement, balances, margin positions, journal review, last rate decision, report surprises, game SessionFacts.
  `POST /assistant/ask`. Clients: mobile screen, web panel, game3d chronicle (`Chronicler.Remote`, template fallback).
- Achievements shared by app and game: `AchievementsProjection` over the account's events, `GET /achievements`; mobile
  screen and web list. Rebuilt from any readable journal on start.
- Performance: book snapshots throttled to ≤ 1 per 250 ms per instrument with trailing edge, no repeats
  (`BookThrottle`); mobile book rows actually memoised (stable formatter), home and achievement rows memoised.
- `docs/teaching/README.md`: 19 patterns — where, which ADR, a 5-minute exercise each.
- Mobile «Мой план»: rebalancing reminder (twice a year in simulation time, drift > 5 p.p.) and lump sum vs DCA over
  every start in the last 180 closes (win share, average edge, worst of each).

## M4 — not done
- game3d harbour fps (45–68 after a camera teleport) — was not fixed in M4; done in the G3D polish pass above.
- Quests from world bible §4/§5b — none started: Совет Казначеев rate decision, «Наследство деда», «Золотой Парус» vs
  Корзина Ветлы, «Корзина уплыла», «Щедрая гильдия», insider records, dividend day.
- The real Claude API was never called (no key); only the fake-HTTP test covers the adapter.
- Lump sum vs DCA was shown only with too little history on a fresh exchange; the maths is unit-tested.
- iOS simulator / Maestro still not run (no Xcode); mobile checked in Expo web at 375×812.

## ADRs (all)
Accepted: 0001–0012, 0013 (M4), 0014, 0015, 0016, 0018–0028. Superseded: 0017 (by 0019). Proposed: none.

## Risks (M4)
- The advice guard is regex-based: strict, may also drop harmless model text (template answers instead).
- Prompt injection: facts and the question are passed as tagged data; the guard still checks the output.
- API cost with a key: no per-session cache yet (ADR-0013 suggests one).

## Next steps
- Fix the harbour fps with a proper in-game probe; then the quests in `fable-build.md` order.
- Cache assistant answers per (account, facts hash); add a live data adapter per ADR-0015.

---

Updated: 2026-11-16, end of M3 (game vertical slice in `game3d/`: the day loop as a state machine, Act I in short,
spread/fees/liquidity, the first storm and the Anchor with a gap, the Forge report season and the record-but-fell
quest, the evening chronicle from SessionFacts with replay, the captain's glossary, walking people). Demo:
`docs/demo/M3.md`. Next: review №5, then M4 (LLM chronicler, polish).

Earlier: 2026-11-15, end of M2c (ATR and position size by volatility, trade journal and session review, dividends
with ex/record/pay dates and tax withheld at source, index and active funds with TER; WebSocketTest flake fixed).
Demo: `docs/demo/M2c.md`. M2 is complete; next is M3.

Earlier: end of M2b (companies and quarterly reports, central bank and economic calendar, bonds with
YTM/duration/default, four new bot strategies and storms, catalogue + glossary via BFFs, «Реальный мир» with paper
positions; journal versioning and idempotency keys). Demo: `docs/demo/M2b.md`.

Earlier: end of M2a (stops, leverage ×4 on FX, statement, deposits). Demo: `docs/demo/M2a.md`.

Earlier: end of M1 (walking skeleton) with all three clients.

## What works
| Part | State | How to see it |
|---|---|---|
| Engine (`backend/engine`) | Order book (increment 1) + accounts, funds reservation, fees, replayable events | `./gradlew :backend:engine:test` |
| Application (`backend/application`) | Sequencer (single writer), simulation clock with pause/speed, journal port, exchange service | `./gradlew :backend:application:test` |
| Bots (`backend/bots`) | Market maker + 4 noise traders from `bots.yaml`, seeded, through the port only | `make dev` |
| App (`backend/app`) | Spring Boot 4.1: REST `/api/v1`, WebSocket `/ws`, JSON-lines journal + replay on start | `make dev` |
| Contract (`api/`) | OpenAPI 3.1 + AsyncAPI 3; contract test validates every REST response and WS message | `ContractTest`, `WebSocketTest` |
| Web (`clients/web`) | Ladder, trades tape, order form, my orders, balances, clock control, ru/en | `make web`, `make e2e` |
| Mobile (`clients/mobile`) | Login, home with balances, instrument with book + order ticket, settings with ru/en | `make mobile` / `make mobile-web` |
| Game (`game/`) | Godot 4.7: main menu with ru/en switch → harbour → Ladder with the live book over WebSocket, limit/market order, fills, balances | `make game` |

Demo: `docs/demo/M1.md`.

## Tests
- Backend: 43 (`./gradlew test`) — engine examples, jqwik properties (money conservation, reservations = open orders, replay
  gives the same state), the race test, sequencer, bots determinism, contract (REST + WS), journal round-trip, ArchUnit.
- Web: 4 vitest (money, i18n keys) + `tsc`; Playwright E2E 1 (login → live book → limit order → cancel → market fill → ru).
- Game: 20 GUT tests headless (`make test-game`) — money, book model, order draft, protocol parsing, i18n keys ru/en.
- Mobile: 5 `node --test` (i18n keys incl. keys used in code, tokens = design, money = web) + `tsc`; `expo-doctor` 20/20.

## ADRs
Accepted: 0001, 0002, 0003 (server part amended by 0016), 0005, 0006, 0008, 0018, 0007, 0009, 0010, 0011, 0014, 0016.
M2a: 0008 Accepted, 0018 Accepted (amends 0006).
M2b: 0004, 0012, 0015 Accepted; 0020 (journal versioning) and 0021 (scheduled economy) Accepted; 0017 Superseded by 0019.
M2c: 0022 (dividend dates, funds, trade journal) Accepted.
M3: 0023 (game3d day loop, day log, SessionFacts as a fold) Accepted. 0013 stays Proposed until the LLM adapter (M4).
Proposed: 0013 (assistant, M4).

## Real-world data (ADR-0015)
Only `StaticSampleData` is shipped: the terms of use of the National Bank of Kazakhstan rates/base-rate pages and of KASE
data were not verified in M2b, so no live adapter was written. The sample's numbers (USD/KZT, EUR/KZT, base rate and
decision dates) are **illustrative, not official**, and every screen shows the source and a "sample" badge.
Next step: read the sources' terms, then add a live adapter with cache and circuit breaker.

## Not verified / known gaps
- iOS simulator: Xcode is not installed on this Mac (only Command Line Tools), so the mobile app was checked in the browser
  via Expo web (react-native-web) at 375×812, not in a simulator. Maestro flow `clients/mobile/.maestro/skeleton.yaml` is written but not run.
- No charts on the instrument screen yet (ADR-0010 leaves the library choice to the implementer; deferred to M2).
- BFFs (ADR-0004) not started: the core API is enough for M1 screens.

- Game: no automated test against the live backend (GUT covers pure logic); the live path was checked by the `--demo` run and screenshots.
  Desktop exports (macOS/Windows) are not configured yet. `make test` now needs Godot on PATH.

## Risks
- M2c: funds have no unit creation/redemption and no rebalancing; resting orders are not adjusted at the ex-date
  (only the reference price). An M2b journal with a dividend announced but unpaid at upgrade gets the new dates.
- Journal growth: ~30 MB/hour with bots (market maker re-quotes every step). Replay is still sub-second at 32 k events;
  add snapshots or requote-on-change when start-up slows down. `make reset` clears it.
- Dev auth is name-only by design; never expose the backend beyond localhost.
- Money as JSON numbers: exact in TypeScript up to 2^53 minor units; fine for practice balances.

## Next steps
- M2 per `docs/prompts/fable-build.md`: second instrument and catalogue, conditional orders, statement, deposits, more bots.

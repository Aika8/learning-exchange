# Teaching index — patterns in this repo

For Aika's teaching sessions. For each pattern: where it lives, which ADR explains *why*, and a 5-minute exercise
(read, predict, then check with a test). Paths are clickable from the repo root. Run all backend tests with
`./gradlew test`; a single one with `./gradlew :backend:<module>:test --tests '<Class>'`.

| # | Pattern | Where in code | ADR |
|---|---|---|---|
| 1 | Ports & Adapters (hexagon) | `backend/application/.../TradingService.java` (port), `app/web/ApiController.java`, `app/journal/FileJournal.java` (adapters) | 0002 |
| 2 | Repository / Journal | `application/Journal.java`, `InMemoryJournal`, `app/journal/FileJournal.java` | 0005 |
| 3 | Event Sourcing (write side) | `engine/Exchange.java` — every change is an `Event`; `Exchange.replay` | 0005 |
| 4 | Projections / CQRS read models | `StatementProjection`, `SessionReviewProjection`, `AchievementsProjection`, `CandleProjection`; game: `core/session_facts.gd` | 0005, 0022, 0023 |
| 5 | Event versioning (upcasters) | `app/journal/Upcasters.java` | 0020 |
| 6 | Single Writer | `application/Sequencer.java` | 0006, 0018 |
| 7 | Injected clock | `SimulationClock`, `ManualClock` | 0006 |
| 8 | Strategy | `bots/Strategy.java` and its implementations | 0007 |
| 9 | Template Method | `bots/TradingBot.java`; `game3d/scripts/market_stream_3d.gd` | 0007 |
| 10 | Factory | `bots/BotFactory.java`, `app/assistant/AssistantConfig.java`, `game3d/scripts/proc.gd` | 0007, 0013 |
| 11 | Observer | `application/MarketListener.java`, `app/ws/MarketDataHub.java` | 0003, 0006 |
| 12 | State machine | `engine/Conditional.java` (stops); `game3d/scripts/core/game_flow.gd` (the day) | 0008, 0023 |
| 13 | Command | `engine/Command.java` | 0006 |
| 14 | BFF | `app/bff/BffController.java` | 0004 |
| 15 | Anti-corruption layer | `app/realworld/StaticSampleData.java`, `app/assistant/ClaudeAssistant.java` | 0015, 0013 |
| 16 | Idempotency key | `Idempotency-Key` in `ApiController.place`, `PaperBook`, game `day_log.gd` keys | 0020, 0023 |
| 17 | Fallback / graceful degradation | `application/assistant/FallbackAssistant.java`; game `core/chronicler.gd` (`Remote` → `Template`) | 0013 |
| 18 | Throttle | `app/ws/BookThrottle.java` | — (DECISIONS.md, M4) |
| 19 | Contract first | `api/openapi.yaml`, `ContractTest`, generated `schema.d.ts` | 0003, 0016 |

## Five-minute exercises

1. **Ports & Adapters.** Open `TradingService`. Find two adapters that *call* it and one it *calls through* (`Journal`).
   Question: what would change to swap REST for gRPC? (Answer: one new driving adapter; nothing in `engine/`.)
2. **Journal.** In `ExchangeServiceTest.restartReplaysTheJournalAndObserversSeeEvents`, predict the state after restart,
   then run it. Delete one line of the replay call in your head: which test breaks?
3. **Event Sourcing.** Pick `Event.TradeExecuted`. List three read models that react to it (grep `TradeExecuted`).
4. **Projections.** Add a fake achievement `TEN_TRADES` to `AchievementsProjection` on paper: which event, which counter,
   and why does an *old* journal immediately give the right answer after deploy? (It is rebuilt on start.)
5. **Upcasters.** Read one step in `Upcasters`. Why never edit the old event class instead? (Old journals must still read.)
6. **Single Writer.** In `Sequencer`, find where commands queue. Explain why there are no locks in `engine/`.
7. **Injected clock.** Why is `Instant.now()` forbidden in the engine? Run `ManualClock`-based tests twice — same result.
8. **Strategy.** Compare `Momentum` and `MeanReversion`: only `decide` differs. Sketch a third bot in 5 lines.
9. **Template Method.** In `TradingBot`, which step is fixed and which is the hook?
10. **Factory.** `AssistantConfig` picks Claude or template once. What happens with an empty `ANTHROPIC_API_KEY`?
11. **Observer.** `MarketDataHub.onEvents` only enqueues. Why is the I/O on another thread?
12. **State machine.** Draw the states of a stop (`Conditional`): PENDING → ARMED → TRIGGERED / CANCELLED. Which
    transition is a gap risk? Then draw `GameFlow` and find the guard that needs Mara's approval.
13. **Command.** Why is a command an object, not a method call? (Queueable, journal-able, replayable.)
14. **BFF.** Compare `/bff/mobile/catalogue` and `/bff/game/catalogue`: same core codes, different words.
15. **Anti-corruption layer.** Find where Anthropic's JSON stops in `ClaudeAssistant`. Nothing outside sees `content[]`.
16. **Idempotency key.** Send the same `POST /orders` twice with one `Idempotency-Key`: how many orders? Why do mobile
    networks need this?
17. **Fallback.** Read `TemplateAndFallbackTest`: four ways the model fails or misbehaves and what the user gets.
    Why does a question asking for advice never reach the model?
18. **Throttle.** `BookThrottleTest`: why must the *last* change still be sent after the pause (trailing edge)?
19. **Contract first.** Add a field to a schema in `api/openapi.yaml` on paper: which test fails first, and which files
    are regenerated (`npm run gen:api`)?

## Finance tie-ins
Each pattern carries a finance idea: projections → statement and taxes; state machine → stops and gaps; fallback →
the assistant explains numbers but never advises; throttle → why a screen's book is a sample, not every tick.

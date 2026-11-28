# Mutation testing of the application module (LE-018, LE-020)

Run: `./gradlew :backend:application:pitest` — the same shared helper as the engine (LE-017,
`rootProject.ext.applyMutationGate` in the root `build.gradle`): PIT 1.30.2, `pitest-junit5-plugin` 1.2.3, Gradle
plugin `info.solidsoft.pitest` 1.19.0; Java 25, Gradle 9.5.1. HTML report: `backend/application/build/reports/pitest/index.html`.

- **Mutation score: 49 %** — 603 of 1223 mutations killed, 49.3 % (2026-11-28, LE-020, `main` at 3455854 plus the
  tests in `application.mutation`). Before: 545 of 1223, 44.6 % (LE-018, 2026-11-27).
- **Threshold: 49** — `backend/quality-gates/mutation-application/002.txt` (the score rounded down; `001.txt` = 44 stays).
  The build reads the maximum of every `*.txt` in that folder; to raise it, add a new file with a higher number.
- Line coverage of mutated classes: 1147/1500 (76 %); test strength (killed among covered): 65 %.
- 111 tests examined, 2328 test runs (1.9 per mutation).
- **Run time:** 1 min 54 s for PIT itself (1 min 51 s of mutation analysis), about 2 min 30 s for the Gradle task,
  all cores. Target `application.*`, all application tests; nothing is excluded — there is no
  `application.assistant.Claude*` class, and the jqwik properties are fast (slowest test 0.4 s).
- Not part of `make test` (the `Makefile` is Aika's).

## LE-020: mutants killed

New tests in `backend/application/src/test/java/application/mutation/` feed the read models events directly
(`StatementProjectionMutationTest`, `AchievementsAndAtrMutationTest`), each named after the behaviour it pins.
They kill 57 mutants in the priority classes, which now have no surviving and no uncovered mutant (58 in all, see below):

| Class | Killed before | Killed now | What the new tests pin |
|---|---:|---:|---|
| `application.StatementProjection` | 59 / 104 | 104 / 104 | margin open/close/stop-out lines, savings lines, dividend tax line and withheld tax, coupons, redemption price and realised profit, basis of deposited base assets (before and after the first trade), margin trades outside the basis, average cost across partial sales, empty basis, period bounds, the 20 000-line cap, the quote looked up per instrument |
| `application.AchievementsProjection` | 11 / 22 | 22 / 22 | stop placed / fired, five notes, three instruments, savings and dividend, sub-accounts count for nobody, a locked achievement shows no progress |
| `application.Atr` | 24 / 25 | 25 / 25 | period 2 is allowed |
| `application.Sequencer` | 6 / 6 | 6 / 6 | nothing left to kill |

Equivalent mutants: none found in these four classes — every survivor there had a test that tells it apart.
One extra kill (`EconomySchedule`, 61 → 62) comes from the new tests passing through it, not from a test aimed at it.

## Mutations by class (LE-018 baseline, 2026-11-27)

"Killed" includes timed-out mutants. "No coverage" means no test executes the mutated line.

| Class | Mutations | Killed | Survived | No coverage |
|---|---:|---:|---:|---:|
| `application.economy.EconomySchedule` | 190 | 61 | 129 | 0 |
| `application.economy.EconomyQueries` | 86 | 23 | 61 | 2 |
| `application.StatementProjection` | 104 | 59 | 35 | 10 |
| `application.ExchangeService` | 228 | 56 | 25 | 147 |
| `application.economy.EconomyProjection` | 50 | 18 | 25 | 7 |
| `application.review.TradingMistakes` | 128 | 100 | 25 | 3 |
| `application.assistant.TemplateAssistant` | 100 | 74 | 15 | 11 |
| `application.economy.BondMath` | 46 | 31 | 14 | 1 |
| `application.SessionReviewProjection` | 58 | 2 | 9 | 47 |
| `application.CandleProjection` | 13 | 4 | 6 | 3 |
| `application.AchievementsProjection` | 22 | 11 | 5 | 6 |
| `application.economy.FundProjection` | 6 | 0 | 3 | 3 |
| `application.assistant.Facts$Builder` | 6 | 2 | 2 | 2 |
| `application.TradingService` | 3 | 0 | 2 | 1 |
| `application.assistant.CachingAssistant` | 10 | 7 | 2 | 1 |
| `application.economy.EconomySchedule$Maturity` | 2 | 0 | 2 | 0 |
| `application.economy.EconomySchedule$TradingStatus` | 2 | 0 | 2 | 0 |
| `application.SimulationClock` | 13 | 9 | 1 | 3 |
| `application.Atr` | 25 | 24 | 1 | 0 |
| `application.assistant.Facts` | 12 | 11 | 1 | 0 |
| `application.economy.EconomySchedule$Coupon` | 2 | 1 | 1 | 0 |
| `application.economy.EconomySchedule$Dividend` | 1 | 0 | 1 | 0 |
| `application.economy.EconomySchedule$DividendPay` | 1 | 0 | 1 | 0 |
| `application.economy.EconomySchedule$DividendRecord` | 1 | 0 | 1 | 0 |
| `application.economy.EconomySchedule$Insider` | 1 | 0 | 1 | 0 |
| `application.economy.Securities$Bond` | 4 | 3 | 1 | 0 |
| `application.assistant.FactsCollector` | 19 | 0 | 0 | 19 |
| `application.realworld.PaperBook` | 13 | 2 | 0 | 11 |
| `application.economy.Securities` | 13 | 3 | 0 | 10 |
| `application.economy.Funds` | 8 | 0 | 0 | 8 |
| `application.realworld.PaperBook$Position` | 7 | 0 | 0 | 7 |
| `application.realworld.RealMarketData` | 3 | 0 | 0 | 3 |
| `application.Clock` | 2 | 0 | 0 | 2 |
| `application.Atr$Result` | 2 | 2 | 0 | 0 |
| `application.CommandRejected` | 1 | 1 | 0 | 0 |
| `application.InMemoryJournal` | 1 | 1 | 0 | 0 |
| `application.ManualClock` | 2 | 2 | 0 | 0 |
| `application.Sequencer` | 6 | 6 | 0 | 0 |
| `application.assistant.AdviceGuard` | 6 | 6 | 0 | 0 |
| `application.assistant.Assistant` | 2 | 2 | 0 | 0 |
| `application.assistant.Assistant$Question` | 4 | 4 | 0 | 0 |
| `application.assistant.CachingAssistant$1` | 3 | 3 | 0 | 0 |
| `application.assistant.CachingAssistant$Key` | 5 | 5 | 0 | 0 |
| `application.assistant.FallbackAssistant` | 10 | 10 | 0 | 0 |
| `application.assistant.GlossaryTerms` | 1 | 1 | 0 | 0 |
| `application.economy.EconomyProjection$Dividend` | 1 | 1 | 0 | 0 |
| **Total** | **1223** | **545** | **371** | **307** |

After LE-018, most survivors sat in the economy calendar: `application.economy.EconomySchedule` (129 of 190 survive) and
`application.economy.EconomyQueries` (61). Most mutations with no coverage are in `application.ExchangeService`
(147) and `application.SessionReviewProjection` (47); `application.assistant.FactsCollector`,
`application.economy.Funds` and `application.realworld.*` are not exercised by any application test at all. By
mutator, `NegateConditionalsMutator` leaves 72 survivors of 372.

# Mutation testing of the engine (LE-017)

Run: `./gradlew :backend:engine:pitest` (PIT 1.30.2, `pitest-junit5-plugin` 1.2.3, Gradle plugin
`info.solidsoft.pitest` 1.19.0; Java 25, Gradle 9.5.1). HTML report: `backend/engine/build/reports/pitest/index.html`.

- **Mutation score: 72 %** — 545 of 754 mutations killed (2026-11-27, `main` at 2848d77).
- **Threshold: 72** — `backend/quality-gates/mutation-engine/001.txt` (the score rounded down). The build reads the
  maximum of every `*.txt` in that folder; to raise it, add a new file with a higher number.
- Line coverage of mutated classes: 930/1029 (90 %); test strength (killed among covered): 79 %.
- 136 tests examined, 2314 test runs (3.07 per mutation).
- **Run time:** 2 min 42 s for PIT itself (2 min 35 s of mutation analysis), about 2 min 45 s for the Gradle task
  on a warm daemon, all cores. Nothing is excluded: the jqwik property tests (`*PropertiesTest`, `*PropertyTest`)
  stay in the run, since it is far below the 10-minute limit.
- Not part of `make test` (the `Makefile` is Aika's).

## Mutations by class

"Killed" includes timed-out mutants. "No coverage" means no test executes the mutated line.

| Class | Mutations | Killed | Survived | No coverage |
|---|---:|---:|---:|---:|
| `engine.Exchange` | 537 | 393 | 94 | 50 |
| `engine.Conditional` | 74 | 49 | 23 | 2 |
| `engine.Instrument` | 14 | 2 | 12 | 0 |
| `engine.Ledger` | 48 | 39 | 9 | 0 |
| `engine.Accounts` | 8 | 4 | 1 | 3 |
| `engine.OrderView` | 5 | 1 | 1 | 3 |
| `engine.Order$Market` | 3 | 0 | 1 | 2 |
| `engine.Order` | 5 | 4 | 1 | 0 |
| `engine.Trade` | 1 | 0 | 1 | 0 |
| `engine.Order$Limit` | 5 | 3 | 0 | 2 |
| `engine.SavingsView` | 2 | 0 | 0 | 2 |
| `engine.Balance` | 2 | 0 | 0 | 2 |
| `engine.OrderBook` | 40 | 40 | 0 | 0 |
| `engine.Exchange$OrderState` | 5 | 5 | 0 | 0 |
| `engine.Outcome` | 4 | 4 | 0 | 0 |
| `engine.SubmitResult` | 1 | 1 | 0 | 0 |
| **Total** | **754** | **545** | **143** | **66** |

Most survivors sit in `engine.Exchange` (94; the largest class) and `engine.Conditional` (23); by mutator,
`NegateConditionalsMutator` leaves 27 survivors of 313. `engine.OrderBook` is fully killed.

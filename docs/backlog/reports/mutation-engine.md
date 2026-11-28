# Mutation testing of the engine (LE-017, LE-019)

Run: `./gradlew :backend:engine:pitest` (PIT 1.30.2, `pitest-junit5-plugin` 1.2.3, Gradle plugin
`info.solidsoft.pitest` 1.19.0; Java 25, Gradle 9.5.1). HTML report: `backend/engine/build/reports/pitest/index.html`.

- **Mutation score: 76 %** — 580 of 754 mutations killed (LE-019, 2026-11-27, on `main` at aa49396).
  Before LE-019: 72 % — 545 of 754 (LE-017, `main` at 2848d77).
- **Threshold: 76** — `backend/quality-gates/mutation-engine/002.txt` (the score rounded down; `001.txt` = 72 stays). The build reads the
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
| `engine.Ledger` | 48 | 48 | 0 | 0 |
| `engine.OrderBook` | 40 | 40 | 0 | 0 |
| `engine.Instrument` | 14 | 14 | 0 | 0 |
| `engine.Accounts` | 8 | 6 | 2 | 0 |
| `engine.OrderView` | 5 | 5 | 0 | 0 |
| `engine.Order` | 5 | 5 | 0 | 0 |
| `engine.Exchange$OrderState` | 5 | 5 | 0 | 0 |
| `engine.Order$Limit` | 5 | 4 | 0 | 1 |
| `engine.Outcome` | 4 | 4 | 0 | 0 |
| `engine.Order$Market` | 3 | 2 | 0 | 1 |
| `engine.SavingsView` | 2 | 2 | 0 | 0 |
| `engine.Balance` | 2 | 2 | 0 | 0 |
| `engine.SubmitResult` | 1 | 1 | 0 | 0 |
| `engine.Trade` | 1 | 0 | 1 | 0 |
| **Total** | **754** | **580** | **120** | **54** |

Most survivors sit in `engine.Exchange` (94; the largest class) and `engine.Conditional` (23, package-private, so
tests in `engine.mutation` reach it only through `Exchange`). `engine.OrderBook`, `engine.Ledger` and
`engine.Instrument` are fully killed.

## LE-019: what the new tests pin

Tests in `backend/engine/src/test/java/engine/mutation/` killed 35 mutants:

- `InstrumentValidationTest` (12): ids and both assets required, base ≠ quote, fee in 0…9 999 bp, leverage 1…10.
- `LedgerAmountsTest` (9): every movement refuses a zero or negative amount; `balances` lists every asset.
- `ViewArithmeticTest` (14): `Balance.total`, `SavingsView.interest`, `OrderView.remainingQty`/`open`,
  `Accounts.owner`, market and limit orders need a side and a positive quantity.

## Equivalent mutants (left alive on purpose)

- `Accounts.owner` line 26, `i < 0` → `i <= 0`: differs only for an account that *starts* with `~`; login names
  are non-empty and cannot contain `~`, so no real account can tell.
- `Accounts.isSubAccount` line 30, `>= 0` → `> 0`: same — only an account starting with `~` tells them apart.
- `Trade.toString`, `Order$Limit.toString`, `Order$Market.toString` → `""`: debug text only; no behaviour, journal
  or API reads it, and a test on it would pin wording, not behaviour.

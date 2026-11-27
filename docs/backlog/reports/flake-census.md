# Flake census of the whole backend (LE-012)

Date: 2026-11-26, cloud run, 4 CPUs, JDK 25, branch `claude/le-012` from `main` at `e6a6548`.

Command, five times in a row (`--continue` so one red module does not hide the others):

```bash
./gradlew test --rerun --continue -q
```

Failures were read from the JUnit XML in `backend/*/build/test-results/test/` (copied out after each run).
Before run 1 a `./gradlew testClasses` warm-up was needed: the first attempt died on HTTP 429 from Maven Central
while downloading build plugins (issue #82) — no tests ran, so it is not counted.

runs: 5

| Run | Gradle result | Wall time | Tests | Failed |
|---:|---|---:|---:|---:|
| 1 | FAILED | 27 s | 240 | 1 |
| 2 | ok | 18 s | 240 | 0 |
| 3 | ok | 19 s | 240 | 0 |
| 4 | ok | 17 s | 240 | 0 |
| 5 | ok | 17 s | 240 | 0 |

Tests per module (every run): app 51, application 79, bots 9, engine 101. Total wall time ≈ 98 s.

## Tests that failed at least once

| Module | Test | Failed | First line of the failure |
|---|---|---:|---|
| app | `app.WebSocketTest.subscriberGetsSnapshotThenTradeAndBookUpdates()` | 1 of 5 (run 1) | `org.opentest4j.AssertionFailedError: trade message ==> expected: <true> but was: <false>` |

Observations (no code changed, as the task says):

- The failure came on the first, coldest run (fresh Gradle daemon and JIT, all four modules testing in parallel on
  4 CPUs); runs 2–5 were green. The test took 3.18 s — just past its 3 s window
  (`WebSocketTest.java:81`) for the trade message at price 10200 after the orders are placed.
- This is not the old subscribe race that LE-011 checked (`docs/backlog/reports/websocket-flake.md`: 0 of 20 when the
  test runs alone): the subscribe wait passed (`every subscribe is answered` held), the trade itself did not arrive
  within 3 s. It points at timing under load, not at ordering.
- Everything else (239 tests) passed in all five runs.

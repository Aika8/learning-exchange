# WebSocketTest flake check (LE-011)

Date: 2026-11-26, cloud run, 4 CPUs, JDK 25, branch `claude/le-011` from `main` at `c46c8c4`.

Command (the task's verify):

```bash
for i in $(seq 20); do ./gradlew -q :backend:app:test --tests 'app.WebSocketTest' --rerun || echo FAIL; done | grep -c FAIL || true
```

| Runs | Failures | Wall time, all 20 runs | Test time, one run (JUnit XML) |
|---:|---:|---:|---:|
| 20 | 0 | 159 s (≈ 8 s per Gradle run) | 3.1 s |

The suite has one test, `subscriberGetsSnapshotThenTradeAndBookUpdates()`; the JUnit XML of the last run shows
`tests="1" failures="0" errors="0"`, so the test did run each time (`--rerun` defeats the up-to-date check).

Conclusion: no flake reproduced. The earlier fix (DECISIONS.md, M2c: the test waits until every subscribe is
answered — snapshot or error — before placing orders) holds. No production or test code changed.
Twenty runs on one machine bound the failure rate only loosely (zero in 20 is consistent with a rate up to
about 14 % at 95 % confidence); if the test fails again in CI, its report in `backend/app/build/reports/tests`
is the place to start.

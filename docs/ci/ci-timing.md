# Where CI time goes (`ci` workflow, LE-022)

Measured on 2026-11-28 from the GitHub REST API: `actions/workflows/ci.yml/runs?status=completed`, then
`actions/runs/<id>/jobs` for step times and `actions/jobs/<id>/logs` for what happens inside `make test`. Runs with
the result `action_required` (fork-style PR runs waiting for approval) started no job and are left out; the table is
the **last 20 runs that ran**, newest first (2026-11-27 16:56 → 2026-11-28 00:28 UTC). All times in seconds.

`ci.yml` today has two parallel jobs: **test** (`make test`: backlog rules, `./gradlew test`, web and mobile
`npm ci` + tests, game3d data check; the Godot targets skip because the job has no Godot) and **game** (download
Godot 4.7.2, `make test-game`, `make test-game3d`). *Wall* is run start → last job done.

| run | started (UTC) | event | branch | result | wall s | job test s | job game s | set up | checkout | setup-java | setup-gradle | setup-node | make test | post setup-gradle | godot dl | test-game | test-game3d |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 46088087791 | 11-28 00:28 | dispatch | claude/le-019 | success | 275 | 88 | 272 | 1 | 4 | 0 | 3 | 2 | 74 | 0 | 2 | 7 | 254 |
| 46087726121 | 11-28 00:24 | pr | claude/le-020 | success | 225 | 83 | 223 | 2 | 4 | 0 | 5 | 3 | 65 | 0 | 2 | 9 | 205 |
| 46083927563 | 11-27 23:41 | dispatch | main | success | 195 | 90 | 192 | 2 | 4 | 0 | 5 | 4 | 57 | 14 | 1 | 7 | 175 |
| 46082518899 | 11-27 23:26 | pr | claude/le-019 | success | 220 | 63 | 217 | 1 | 4 | 1 | 2 | 1 | 50 | 1 | 2 | 8 | 196 |
| 46075882764 | 11-27 22:19 | pr | claude/le-018 | success | 273 | 88 | 270 | 2 | 5 | 0 | 6 | 5 | 65 | 0 | 1 | 6 | 257 |
| 46065209728 | 11-27 20:40 | dispatch | main | failure | 223 | 49 | 220 | 2 | 5 | 1 | 3 | 5 | 28 | 1 | 1 | 7 | 206 |
| 46056882406 | 11-27 19:28 | dispatch | claude/auto-20261127-8 | failure | 193 | 60 | 190 | 2 | 5 | 0 | 8 | 3 | 37 | 0 | 2 | 7 | 173 |
| 46056402428 | 11-27 19:23 | pr | claude/auto-20261127-8 | success | 226 | 74 | 224 | 2 | 8 | 0 | 4 | 6 | 50 | 0 | 2 | 8 | 208 |
| 46055137886 | 11-27 19:13 | dispatch | claude/auto-20261127-7 | success | 281 | 61 | 278 | 2 | 6 | 0 | 2 | 4 | 43 | 0 | 1 | 11 | 254 |
| 46055119571 | 11-27 19:13 | dispatch | claude/auto-20261127-1 | failure | 221 | 47 | 218 | 3 | 4 | 0 | 4 | 2 | 29 | 0 | 1 | 6 | 205 |
| 46054605621 | 11-27 19:08 | push | main | success | 229 | 92 | 226 | 3 | 8 | 0 | 8 | 9 | 47 | 12 | 1 | 6 | 205 |
| 46051799195 | 11-27 18:45 | dispatch | main | success | 234 | 87 | 230 | 3 | 5 | 0 | 5 | 3 | 57 | 11 | 2 | 6 | 212 |
| 46048942001 | 11-27 18:22 | dispatch | claude/auto-20261127-1 | success | 286 | 110 | 283 | 2 | 5 | 0 | 4 | 3 | 91 | 0 | 2 | 10 | 261 |
| 46048921877 | 11-27 18:22 | dispatch | claude/le-410 | success | 194 | 66 | 191 | 2 | 5 | 0 | 3 | 2 | 51 | 1 | 1 | 5 | 174 |
| 46048279574 | 11-27 18:16 | pr | claude/auto-20261127-7 | success | 281 | 98 | 278 | 3 | 7 | 1 | 9 | 4 | 68 | 0 | 2 | 7 | 261 |
| 46043597861 | 11-27 17:39 | dispatch | main | success | 230 | 123 | 226 | 2 | 5 | 0 | 3 | 3 | 90 | 17 | 1 | 6 | 209 |
| 46043084553 | 11-27 17:35 | pr | claude/proposals-user-2026-11-27 | success | 220 | 96 | 218 | 3 | 6 | 0 | 3 | 2 | 78 | 0 | 2 | 9 | 196 |
| 46041800774 | 11-27 17:26 | dispatch | claude/le-410 | success | 234 | 83 | 230 | 3 | 7 | 0 | 4 | 5 | 61 | 0 | 1 | 7 | 212 |
| 46041115019 | 11-27 17:20 | pr | claude/auto-20261127-1 | success | 283 | 99 | 280 | 3 | 9 | 0 | 9 | 9 | 63 | 0 | 2 | 7 | 259 |
| 46037748468 | 11-27 16:56 | dispatch | main | success | 294 | 124 | 291 | 4 | 6 | 0 | 6 | 3 | 79 | 23 | 2 | 8 | 262 |
| **median** | | | | | 229 | 87 | 226 | 2 | 5 | 0 | 4 | 3 | 59 | 0 | 2 | 7 | 208 |

(The `setup-java` step is 0–1 s because Temurin 25 is in the runner's tool cache. "post setup-gradle" is the
cache save; it costs 11–23 s only on `main`, the one branch allowed to write the Gradle cache.)

## Medians

| | median | range |
|---|---|---|
| wall time of a run | **229** | 193–294 |
| job `test` | 87 | 47–124 |
| job `game` | **226** | 190–291 |
| of which `make test-game3d` | **208** | 173–262 |
| of which `make test` (in job `test`) | 59 | 28–91 |
| runner time per run (both jobs added) | 315 | |

## What dominates

**The `game` job is the critical path in all 20 runs**: it ends 100–170 s after `test`. Making `test` faster does not
make a run shorter; only the `game` job does.

Inside `game`, `make test-game3d` is ~92 % of the job, and inside it one test script carries most of the time.
Per-script times of GUT in run 46088087791 (247 s of GUT time):

| script | s | share |
|---|---|---|
| `test_world_walk.gd` | 184 | 74 % |
| — of it `test_the_captain_is_never_trapped_and_walks_through_nothing` (fuzz on 8 islands) | ~148 | 60 % |
| `test_flight_model.gd` (`test_a_ship_can_fly_from_any_island_to_any_other_in_any_wind`) | 41 | 17 % |
| `test_island_style.gd` | 8 | 3 % |
| the other 28 scripts | 14 | 6 % |

The Godot download (1–2 s), `--import` (~4 s) and `make test-game` (5–11 s) are small.

Inside `make test` of the same run (job `test`, 74 s): `./gradlew test` 51 s (daemon start + 19 tasks, all executed,
none from a cache), web `npm ci` 2 s + tests/typecheck 4 s, mobile `npm ci` 11 s + tests 4 s, backlog rules and game3d
data check < 1 s each.

## Caching that already exists

- `gradle/actions/setup-gradle@v4`: restores the Gradle user home (wrapper, dependencies, transforms, ~200 MB) in
  ~2 s; read-only on branches, written on `main`. It does **not** give task-output reuse: the Gradle build cache is
  not enabled (no `org.gradle.caching`), so every run executes all 19 tasks; Gradle's own log says "Consider enabling
  configuration cache".
- `actions/setup-node@v4` with `cache: npm` on both lock files: restores `~/.npm`, so `npm ci` installs offline (2 s
  web, 11 s mobile — the mobile time is unpacking 543 packages, not downloading). `node_modules` itself is not cached.
- `gradle.properties` raises Gradle's retry for HTTP 429 from Maven Central (issue #82); not a cache, but it is why a
  cold dependency fetch does not fail.
- `game`: nothing is cached (Godot is downloaded each run, 1–2 s; `.godot/` import is rebuilt, ~4 s). Not worth a cache.

## What the proposal changes, and why

See `docs/ci/proposed/ci.yml` (each change has a comment with its expected saving). In short:

1. **Shard the game3d GUT run** into two parallel jobs: `test_world_walk.gd` alone, and every other script (plus
   `make test-game`). Expected wall time ≈ 165–175 s instead of 229 s (−55…60 s, about −25 %). Runner time grows by
   one job's set-up, ~+15 s per run (minutes are free for this public repository on standard runners, and the sum is
   far from doubling). Checked locally on 2026-11-28: the "everything but world_walk" command ran 30 scripts, 178
   tests (177 passed, 1 pending) in 71 s; with `test_world_walk.gd`'s 11 tests that is CI's 31 scripts / 189 tests.
   The GUT command exits 0 when all pass and 1 when a test fails (checked with a throw-away failing script), so a
   red shard fails its job.
2. **Enable the Gradle build cache** in the `test` job: on a PR that does not touch `backend/` the test tasks come
   `FROM-CACHE` from `main`'s entry, ~51 s → ~15 s. This is runner time, not wall time (job `test` is not on the
   critical path), so it is listed second.

Considered and **not** proposed:

- *Splitting backend and clients into parallel jobs*: job `test` already finishes 100+ s before `game`; a split
  would only add a job's set-up to the runner time.
- *Configuration cache*: `setup-gradle` only saves it with a `cache-encryption-key` secret (a key — out of scope for
  an agent), and configuration of this 4-module build is a few seconds at most.
- *`npm ci` only when the lock files changed* (cache `node_modules`): saves ≤ 10 s on a job that is not the critical
  path, and the Makefile's `.ci-stamp` rule compares mtimes, which a cache restore after checkout gets wrong.
- *Caching Godot or `.godot/`*: 2 s and 4 s.

The biggest lever is outside CI: `test_the_captain_is_never_trapped_and_walks_through_nothing` costs ~18 s per
island and grows with every new island (recorded as tech debt `docs/backlog/tech-debt/2026-11-28-LE-022-1.md`).

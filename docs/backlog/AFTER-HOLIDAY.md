# After the holiday (not queued, not waiting)

Things the cloud agents do not do at all, because they change how `game3d` looks, need money, keys, sign-ups or
outside accounts, or touch a protected path. Nothing in the queue waits for any of them.

- **Goals in the running game**: `Game.ctx()` in `game3d/scripts/game.gd` does not give the goals model day, island,
  visits or done marks, and the HUD has no "What next?" line (`game.gd`, `harbour.gd`, `hud.gd`).
- **The chronicle scene calls `/session-review`** for mistakes and measures (`game3d/scripts/chronicle.gd`, one call).
- **An Anchor away from Spark Harbour**: cargo without an Anchor on another island cannot sail; decide whether the
  ship's chart may set one (LE-204's tests show whether the state is reachable).
- **Game3d ADRs 0029…0032, 0034…0037**: still Proposed while their code has landed — accept after looking at each island.
- **Quest cards** for the M4 quests (giver, place, trigger, lesson) — then agents build them as state machines.
- **The dev server's interface**: `make dev` listens on every interface; localhost-only changes how the phone connects.
- **Mara's provisions as a drawn panel** (today only the text of her last balloon says it).
- **Screenshot checks in CI**: a `make screenshots` target and a CI job, once they have been stable for a week.
- **Gradle against Maven Central 429** at the root: retries are in `gradle.properties` now; removing the cause needs
  the Gradle dependency cache to survive between cloud sessions. That is only possible through the environment's
  Setup script (claude.ai → Code → environment `Default` → Setup script): its result is snapshotted, so a script that
  also downloads the three repositories' dependencies once would keep `~/.gradle`. Not verified that a setup script
  can reach the private repositories; it is an environment setting, so Aika's.
- **Mara's first talk split into smaller lessons, and the captain's answer to the child's chest line**: both need new
  comic panels in `game3d/data/talks.json` (the user run of 2026-11-26).
- **Live market data (ADR-0015)**: needs the terms of use of the data sources checked.

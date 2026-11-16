# learning-exchange — rules for any agent working here

## What this is
An exchange with bots and three clients (web debug, mobile app «Ветрило», PC game «Летопись Ветров»).
It is Aika's learning project: the code is teaching material for design patterns and finance.
Start with `intent/02-platform.md`, `docs/adr/README.md`, `docs/lore/world-bible.md`.

## Design (how the world looks)
- `docs/design/README.md` is the source of truth for the look of `game3d/`. Read it before touching people, buildings,
  ships or props. The concept sheets in `docs/design/concepts/` are Aika's approved designs: the game follows them.
- New sketches from Aika go into `docs/design/concepts/` with a row in that README; then rebuild the thing to match and
  show before/after with `--people` / `--views`.
- What the sheets do not cover is a question for Aika, not a guess.

## Workflow
- Intent → ADR → contract (`api/`) → code + tests → `DECISIONS.md` for small behaviour choices.
- Costly-to-reverse decisions get an ADR (`docs/adr/0000-template.md`) **before** the code. Never edit an Accepted ADR; supersede it.
- Accept a Proposed ADR by changing its status when the code implementing it lands.

## Code conventions
- A class/module implementing a named pattern starts with a doc comment:
  `Pattern: <name> — <one line why>. See docs/adr/NNNN-….md`. Don't annotate trivial code.
- Engine (`backend/engine`) is framework-free and deterministic: no Spring, no I/O, no `Instant.now()`.
- Money and prices are integer minor units (`long`); never `double` for money.
- Engine invariants (intent 01 and intent 02) are covered by tests; a change that breaks one is wrong.
- Contract changes go to `api/*.yaml` first; clients are generated, never hand-edit generated code.

## Running
- Backend + bots: see README (`make dev`).
- Each client: its folder's README.

## Don'ts
- No real money, credentials, KYC, or real bank/brand look (not BCC, not Kaspi).
- Don't copy existing games (names, art, maps, mechanics presentation).
- No investment advice in assistant output.
- No AI-attribution lines in commits or PR descriptions.

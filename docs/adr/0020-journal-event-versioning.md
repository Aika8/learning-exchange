# 0020. Journal lines carry a format version; upcasters lift old lines on read

- Status: Accepted (M2b)
- Date: 2026-11-15
- Pattern(s): Upcaster (event versioning), Chain of Responsibility

## Context
The journal is the source of truth (ADR-0005). M2a changed event fields and asked everyone to `make reset` — review №2
called that out: a real event-sourced system can never delete its history. M2b changes events again (idempotency keys
on stops, positions and deposits) and adds new ones.

## Decision
- Every journal line gets `"v": <format version>`; a line without it is version 1 (M1/M2a).
- On read, `app.journal.Upcasters` lifts a line step by step (`v1 → v2 → …`) by editing its JSON, then Jackson maps it
  to the current event record. The engine never sees old shapes.
- Old lines are not rewritten; new lines are written in the current version. A line from a newer build fails loudly.
- Only additive changes go into upcasters. A change in meaning (a field whose units change, an event that splits)
  gets a new event type instead.
- Test: `JournalVersionsTest` replays a journal recorded by the M2a build (`src/test/resources/journal/m2a.jsonl`).

## Why this and not the alternatives
| Alternative | Why not |
|---|---|
| `make reset` on every format change | Loses history; impossible in a real system |
| Rewrite the file on upgrade (migration) | The journal is append-only; a failed rewrite loses data |
| Version per event type in the class name (`SavingsOpenedV2`) | Engine code fills up with old shapes it never acts on |

## Pros
- Old journals replay; each format change is one small, tested step.

## Risks and costs
- Upcasters run on every start for old lines (cheap: a few JSON edits per line).
- A step that guesses a missing value wrongly changes history; only add fields whose old value is obvious (`null`).

## How to explain it
"Old letters are read with a translator: every line says which version it was written in, and small translators bring
it up to today's version before the engine reads it."

# 0001. Record architecture decisions as ADRs

- Status: Accepted
- Date: 2026-11-12
- Pattern(s): Architecture Decision Record (Michael Nygard, 2011)

## Context
The code is written mostly by AI agents and is meant to teach Aika design patterns and finance.
Without a record, nobody remembers why a choice was made, and different agents drift apart.
`DECISIONS.md` already captures small behavioural choices of increment 1; it does not fit architectural trade-offs.

## Decision
Each architectural decision gets a numbered file in `docs/adr/` using the template.
`DECISIONS.md` stays for small per-increment behaviour choices. Code implementing a pattern links its ADR.

## Why this and not the alternatives
| Alternative | Why not |
|---|---|
| Only commit messages | Not discoverable, no alternatives or risks |
| Confluence/Notion page | Drifts away from code, not reviewed with the change |
| Single big design doc | Becomes stale, hard to supersede one part |

## Pros
- Decisions are reviewed in the same change as the code.
- Superseding is explicit: history of thinking is kept.
- Ready-made teaching material: "pattern, why, pros, risks".

## Risks and costs
- Ritual without content: ADRs written after the fact to justify code. Mitigation: ADR first, then code.
- Too many trivial ADRs. Rule: only decisions that are costly to reverse.

## How to explain it
"We keep ADRs next to the code: each one says what we chose, which alternatives we rejected and what it costs us.
New people — and AI agents — read them instead of reverse-engineering intent."

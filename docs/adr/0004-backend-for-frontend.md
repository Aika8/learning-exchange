# 0004. One Backend-for-Frontend per client type

- Status: Proposed
- Date: 2026-11-12
- Pattern(s): Backend for Frontend (Sam Newman / SoundCloud), API Gateway (simplified)

## Context
The mobile app needs screens like "home: balances, recent operations, deposit interest"; the game needs
"island state: lore names, ladder view, events, quests". Putting both into one general API makes it bloated
and couples both clients to each other's needs.

## Decision
- Core exchange API (ADR-0003) is generic and stable.
- `bff-mobile` and `bff-game` are thin modules in the same Spring Boot application at first (`/mobile/**`, `/game/**`),
  each composing core use cases into screen-shaped responses and mapping names (ADR-0012).
- They become separate deployables only if they need to scale or release separately.

## Why this and not the alternatives
| Alternative | Why not |
|---|---|
| One general API for all | Over-fetching on mobile, game logic leaking into core |
| BFF as separate services from day one | More moving parts than value now |
| GraphQL as the single BFF | Possible later for mobile; not needed to start |

## Pros
- Each client team (agent) owns its BFF and can change it without touching the core.
- Lore vocabulary stays out of the core domain.

## Risks and costs
- Duplicated logic between BFFs. Rule: anything that is a business rule goes to the core; BFF only composes and maps.
- Starting as modules in one app blurs the boundary — ArchUnit forbids BFF → BFF dependencies.

## How to explain it
"Each frontend gets its own thin backend that speaks its language. The core stays generic;
the game BFF calls the order book 'the Ladder', the mobile BFF calls it 'стакан'."

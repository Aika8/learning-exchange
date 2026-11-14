# Architecture Decision Records

One file per decision: `NNNN-short-title.md`, from [`0000-template.md`](0000-template.md).
An ADR is never rewritten after it is Accepted: a new ADR supersedes it.

Statuses: Proposed → Accepted → (Superseded by NNNN | Deprecated).

The ADRs marked *Proposed* below were written during the design discussion
(2026-11-12) before any code. The implementer accepts them, or writes a
superseding ADR explaining why reality differed.

| # | Decision | Pattern / topic | Status |
|---|---|---|---|
| [0001](0001-record-architecture-decisions.md) | Record decisions as ADRs | ADR | Accepted |
| [0002](0002-hexagonal-architecture.md) | Hexagonal core, framework-free engine | Ports & Adapters | Proposed |
| [0003](0003-contract-first-api.md) | Contract first: OpenAPI + AsyncAPI | Contract-first, generated clients | Proposed |
| [0004](0004-backend-for-frontend.md) | One BFF per client type | BFF | Proposed |
| [0005](0005-event-sourcing-journal.md) | Event-sourced journal as source of truth | Event Sourcing, CQRS-lite | Proposed |
| [0006](0006-single-writer-and-sim-clock.md) | Single writer per instrument, simulation clock | Single Writer, Actor-like, Clock abstraction | Proposed |
| [0007](0007-bots-are-api-clients.md) | Bots are ordinary clients with strategies | Strategy, Observer | Proposed |
| [0008](0008-conditional-orders-outside-book.md) | Stop orders and stop-out outside the book | Observer, State machine | Proposed |
| [0009](0009-monorepo-layout.md) | Monorepo with one folder per deployable | Monorepo, walking skeleton | Accepted |
| [0010](0010-mobile-stack-expo.md) | Mobile: React Native + Expo + TypeScript | — | Proposed |
| [0011](0011-game-engine-godot.md) | Game: Godot 4 | — | Proposed |
| [0012](0012-dual-naming-catalogue.md) | Real names everywhere, lore names as flavour | Anti-corruption via BFF mapping | Proposed |
| [0013](0013-assistant-llm-with-fallback.md) | Assistant: LLM behind a port, rules fallback | Port, Fallback / Graceful degradation | Proposed |
| [0014](0014-i18n-runtime-switch.md) | Russian + English, switchable at runtime | Message catalogues, Observer | Proposed |
| [0015](0015-real-market-data-feed.md) | Real market data as a read-only feed + paper trading | Adapter, Circuit breaker, Cache | Proposed |

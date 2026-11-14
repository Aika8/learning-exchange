# 0003. Contract first: OpenAPI for commands, AsyncAPI for streams

- Status: Proposed
- Date: 2026-11-12
- Pattern(s): Contract-first API design, Code generation, Consumer-driven contracts (later)

## Context
Different agents/models build different clients in parallel (Java backend, TypeScript mobile/web, GDScript game).
They must agree on messages before code exists. Market data is a stream (trades, book updates, clock ticks); commands are request/response.

## Decision
- `api/openapi.yaml` (OpenAPI 3.1): commands and queries — auth (dev), accounts, orders, transfers, deposits, statements.
- `api/asyncapi.yaml` (AsyncAPI 3): WebSocket channels — `market.{instrument}.book`, `market.{instrument}.trades`, `account.{id}.events`, `clock`.
- The contract is changed first, in its own commit; server stubs and TypeScript clients are generated from it.
- Money and prices are integers in minor units (consistent with the engine's `long` ticks), with the instrument's scale in the catalogue.
- Commands carry an `Idempotency-Key` header.

## Why this and not the alternatives
| Alternative | Why not |
|---|---|
| Code-first (annotations → spec) | Spec is a by-product; clients built in parallel would chase it |
| GraphQL | Great for mobile BFF queries, but subscriptions/streaming and tooling for Godot are weaker; can be added in a BFF later |
| gRPC | Poor fit for the browser and Godot without proxies |

## Pros
- Clients can be generated and mocked from day one.
- Breaking changes are visible in review (diff of YAML).

## Risks and costs
- Generated code style may be awkward; wrap it, don't edit it.
- Spec and implementation can drift — mitigated by a contract test that validates responses against the spec.

## How to explain it
"We write the API contract before the code, then generate clients. Mobile, game and backend can be built at the same time
because they all depend on the contract, not on each other."

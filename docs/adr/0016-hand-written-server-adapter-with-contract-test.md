# 0016. Hand-written server adapter, kept honest by a contract test

- Status: Accepted
- Date: 2026-11-14
- Pattern(s): Contract-first API (ADR-0003), Adapter, Contract test
- Amends: 0003 (only the "server stubs are generated" part; the rest of 0003 stands)

## Context
ADR-0003 says server stubs and TypeScript clients are generated from `api/openapi.yaml`. For the TypeScript clients that
works well (`openapi-typescript` + `openapi-fetch`, types only, no runtime code). For the Java server, OpenAPI Generator's
Spring templates produce interfaces, model classes and annotations for Spring Boot 3 / Jackson 2; Spring Boot 4 uses
Jackson 3 and the generated models would duplicate the DTO records we want Aika to read. The WebSocket side (AsyncAPI) has no
mature Java server generator at all.

## Decision
- The REST and WebSocket adapters in `backend/app` are hand-written: small DTO records (`app.web.Dto`) and controllers.
- `ContractTest` and `WebSocketTest` call the running app over real HTTP / WebSocket and validate **every** response and
  stream message against the schemas in `api/openapi.yaml` (networknt json-schema-validator, OpenAPI 3.1 dialect).
  The test classpath reads `api/` directly, so changing the contract without the server (or the other way round) fails the build.
- WebSocket message payloads are described as `Ws*Message` schemas in `openapi.yaml` and referenced from `asyncapi.yaml`,
  so the generated TypeScript types cover both REST and stream messages.
- Clients stay generated: `npm run gen:api` in `clients/web` and `clients/mobile`.

## Why this and not the alternatives
| Alternative | Why not (now) |
|---|---|
| OpenAPI Generator `spring` server stubs | Templates lag Spring Boot 4 / Jackson 3; generated models hide the mapping we want visible |
| springdoc (code-first spec) | Turns the contract into a by-product — the opposite of ADR-0003 |
| No contract test | Spec and server drift silently — the risk ADR-0003 already named |

## Pros
- DTOs are short records Aika can read; the contract is still the single source of truth.
- Drift is caught by the build, including for WebSocket messages.

## Risks and costs
- A new endpoint can be added to the server and forgotten in the spec: the test only checks what it calls.
  Mitigation: every new endpoint gets a line in `ContractTest`; review the YAML diff first (contract commits come first).

## How to explain it (teaching note)
"We write the contract first and generate the clients. The server is hand-written but can't drift: a contract test calls it
and validates every response against the same YAML the clients are generated from."

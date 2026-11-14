# 0002. Hexagonal core with a framework-free engine

- Status: Proposed
- Date: 2026-11-12
- Pattern(s): Hexagonal architecture / Ports & Adapters (Alistair Cockburn), Dependency Inversion

## Context
Three different clients (mobile, game, web), bots and an LLM assistant all use the same market.
The engine from increment 1 is pure Java and well tested. Frameworks, transports and storage will change; the matching rules must not.

## Decision
- `engine` (domain): order book, matching, accounts, positions, conditional orders. No Spring, no I/O, no clock calls.
- `application`: use cases (`PlaceOrder`, `CancelOrder`, `Transfer`, `OpenDeposit`…) and **ports** — interfaces the core needs
  (`Journal`, `Clock`, `MarketDataPublisher`, `Assistant`) and interfaces it offers (`TradingService`, `AccountService`).
- `adapters`: Spring Boot REST/WebSocket (driving), file journal, LLM client, scheduler (driven).
- Dependencies point inward only. Enforced with ArchUnit tests.

## Why this and not the alternatives
| Alternative | Why not |
|---|---|
| Classic layered (controller → service → repository) with Spring everywhere | Domain becomes coupled to Spring and JPA; harder to test the engine deterministically |
| Clean Architecture with many layers | More ceremony than value at this size |
| Microservices per domain | Distributed consistency for money before we even have users |

## Pros
- Engine tests stay fast and deterministic.
- A new client or transport is a new adapter, not a change in the core.
- Same shape as `signal-bot` — one pattern to learn twice.

## Risks and costs
- Mapping between domain objects and DTOs is extra code.
- Port explosion: one interface per tiny need. Rule: a port exists only when there are, or will soon be, two implementations (prod + test).

## How to explain it
"The exchange core knows nothing about HTTP or Spring. It talks to the outside world through ports;
REST, WebSocket, the journal file and the LLM are adapters. That's why the mobile app, the game and the bots can share it."

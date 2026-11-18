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
| [0002](0002-hexagonal-architecture.md) | Hexagonal core, framework-free engine | Ports & Adapters | Accepted (M1) |
| [0003](0003-contract-first-api.md) | Contract first: OpenAPI + AsyncAPI | Contract-first, generated clients | Accepted (M1) |
| [0004](0004-backend-for-frontend.md) | One BFF per client type | BFF | Accepted (M2b) |
| [0005](0005-event-sourcing-journal.md) | Event-sourced journal as source of truth | Event Sourcing, CQRS-lite | Accepted (M1) |
| [0006](0006-single-writer-and-sim-clock.md) | Single writer per instrument, simulation clock | Single Writer, Actor-like, Clock abstraction | Accepted (M1); per-instrument part superseded by 0018 |
| [0007](0007-bots-are-api-clients.md) | Bots are ordinary clients with strategies | Strategy, Observer | Accepted (M1) |
| [0008](0008-conditional-orders-outside-book.md) | Stop orders and stop-out outside the book | Observer, State machine | Accepted (M2a) |
| [0009](0009-monorepo-layout.md) | Monorepo with one folder per deployable | Monorepo, walking skeleton | Accepted |
| [0010](0010-mobile-stack-expo.md) | Mobile: React Native + Expo + TypeScript | — | Accepted (M1) |
| [0011](0011-game-engine-godot.md) | Game: Godot 4 | — | Accepted |
| [0012](0012-dual-naming-catalogue.md) | Real names everywhere, lore names as flavour | Anti-corruption via BFF mapping | Accepted (M2b) |
| [0013](0013-assistant-llm-with-fallback.md) | Assistant: LLM behind a port, rules fallback | Port, Fallback / Graceful degradation | Proposed |
| [0014](0014-i18n-runtime-switch.md) | Russian + English, switchable at runtime | Message catalogues, Observer | Accepted (M1) |
| [0015](0015-real-market-data-feed.md) | Real market data as a read-only feed + paper trading | Adapter, Circuit breaker, Cache | Accepted (M2b) |
| [0016](0016-hand-written-server-adapter-with-contract-test.md) | Hand-written server adapter checked by a contract test (amends 0003) | Adapter, Contract test | Accepted |
| [0017](0017-game3d-stylised-lowpoly-godot.md) | Second game client in 3D: stylised low-poly, Godot Forward+ | Shared kernel, Procedural generation | Superseded by 0019 (art) |
| [0018](0018-one-writer-for-the-whole-exchange.md) | One writer for the whole exchange (amends 0006) | Single Writer | Accepted (M2a) |
| [0019](0019-game3d-pbr-assets.md) | game3d: painterly realism with CC0 PBR assets fetched by `make assets` | Facade, Graceful degradation | Accepted |
| [0020](0020-journal-event-versioning.md) | Journal lines carry a format version; upcasters lift old lines | Upcaster | Accepted |
| [0021](0021-scheduled-economy.md) | Seeded economy schedule journalled as decisions; halts, payouts, default | Generator, Event Sourcing, Observer | Accepted |
| [0022](0022-dividend-dates-funds-and-trade-journal.md) | Dividend dates with tax at source, funds with TER, trade-journal notes — new event types only | Event Sourcing, Projection | Accepted (M2c) |
| [0023](0023-game3d-day-loop-and-client-session-facts.md) | game3d M3: day loop as a state machine, client day log, SessionFacts as a fold | State machine, Event Sourcing, Projection | Accepted (M3) |
| [0024](0024-game3d-stylised-lowpoly-with-ink.md) | game3d look: stylised low-poly built in code, faceless silhouettes, ink outline and engraving post-effect; PBR behind `--pbr` | Strategy, Builder | Accepted (G3D style) |
| [0025](0025-game3d-island-style-variants-and-attunement.md) | game3d: each island a slight variant of the ink style (`IslandStyle`); the island's wind restyles the captain on arrival | Value objects in a table | Accepted; bounds amended by 0026 |
| [0026](0026-game3d-island-techniques.md) | game3d: every island drawn in its own technique (ink, dyed silk, …), chosen by its `IslandStyle` row | Strategy chosen by data | Accepted; technique `dye` superseded by 0029 |
| [0027](0027-game3d-talk-as-comic-pages.md) | game3d: talking opens a comic page — frames, drawn portraits whose face changes with the line (Aika's expression sheets), balloons; pages and words are data | Data-driven script, Iterator, Flyweight | Accepted |
| [0028](0028-game3d-amber-cliff-speaks-french.md) | game3d: Amber Cliff — a French-speaking island (catalogue per island, gloss on T), drawn in a ligne-claire technique | Message catalogue per island, Strategy by data | Accepted; technique `claire` superseded by 0029 |
| [0029](0029-game3d-katazome-and-pen-and-watercolour.md) | game3d: Silk Reach as katazome, Amber Cliff in pen and watercolour (Aika's sheets); every technique must redraw the captain | Strategy by data, a contract for strategies | Proposed |
| [0030](0030-game3d-short-sellers-island-in-noir.md) | game3d: the short sellers' island — a tilted town drawn as noir (black, white, one red; rain, fog); a place and a style, no mechanics yet | Strategy by data, Builder | Proposed |
| [0031](0031-game3d-crypto-island-in-pixel-synthwave.md) | game3d: the crypto island — a neon town in synthwave pixel art (big pixels, 12 colours, striped sun, ground grid); our own wind coin; a place and a style, no mechanics yet | Strategy by data, Builder | Proposed |
| [0032](0032-game3d-free-flight-between-islands.md) | game3d: the player flies the ship between all islands (steering, height, wind, solid islands, a world edge, mooring; a chart and compass); the day loop's SAILING state and the ×60 clock are kept | Pure model + thin scene, Registry | Proposed |
| [0033](0033-game3d-index-island-as-a-toy-town.md) | game3d: the index island — a symmetrical pastel toy town (gloss, soft seams, careful tilt-shift); a coin fountain; a place and a style, no mechanics yet | Strategy by data, Builder, Registry row | Superseded by 0035 |
| [0034](0034-game3d-race-island-in-art-deco.md) | game3d: the race island — the Grand Prix of the Winds as a streamline art-deco poster (flat colour, metal in stripes from the normal, a world-fixed sunburst); a track in the air, pits, a timing tower; a place and a style, no mechanics yet | Strategy by data, Builder, Registry row | Proposed |
| [0035](0035-game3d-index-island-as-a-dutch-golden-age-painting.md) | game3d: the index island becomes a canal town painted in oil (the Dutch Golden Age) — world-anchored strokes, golden haze, a low soft sun per island; the toy technique is kept for another island; supersedes 0033 | Strategy by data, Builder | Proposed |
| [0036](0036-game3d-the-ship-is-the-one-realistic-thing.md) | game3d: the ship «Попутчик» is the one realistic thing — PBR, drawn after the island's technique by render order and never redrawn; built in code after Aika's sheets within 60k triangles; our own flag; a monkey who lives in the rig and comes ashore | Builder, exception by draw order, pure model + thin node | Proposed |
| [0037](0037-game3d-comic-pages-second-pass.md) | game3d: comic pages, second pass — figures cut out of their paper by a tool in the project (corrections as data), the softened scene as each frame's background, oval balloons with tails to the mouth and a name plate once, varied shots; amends 0027 | Data-driven script, a build step for assets | Proposed |

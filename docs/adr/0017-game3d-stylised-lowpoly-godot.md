# 0017. Second game client in 3D: stylised low-poly in Godot 4 (Forward+)

- Status: Superseded by 0019 (art direction; the shared kernel and scenes stay)
- Date: 2026-11-15
- Pattern(s): Shared kernel (network + i18n reused from `game/` by symlink), Template method (3D stream extends the 2D one), Procedural generation for art

## Context
«Летопись Ветров» has a 2D client (`game/`, ADR-0011) with placeholder art. Aika wants a second, much prettier client
in 3D, in the same genre (trading RPG in a sky archipelago) and the same world (`docs/lore/world-bible.md`).
Constraints: one agent builds a vertical slice in one session, no artist, assets must be our own or CC0,
60 fps at 1080p on a MacBook, ru/en everywhere, the exchange contract (`api/`) stays as it is,
and nothing may copy an existing game (names, art, maps, presentation of mechanics).

Three styles were considered:

| Style | Look | Cost for us |
|---|---|---|
| A. **Cosy stylised low-poly**, soft toon shading | flat-shaded islands, cloud sea, volumetric light, warm fog | every mesh can be generated in code; reads well at low poly counts; cheap to render |
| B. Painterly / hand-drawn textures on simple meshes | richest look | needs painted textures — the asset bottleneck ADR-0011 warned about |
| C. Semi-realistic PBR (scanned rocks, real water) | "AAA" look | huge asset volume, heavy GPU, not our genre; rejected by the brief |

## Decision
Style **A**. Engine: **Godot 4.7, 3D, Forward+**, project in `game3d/`.
- Every mesh (islands, ship, harbour buildings, the windmill exchange, the 3D order-book board) is built procedurally
  in GDScript from primitives and `SurfaceTool`; no imported art. The look comes from light, not texture detail:
  `ProceduralSkyMaterial`, volumetric + depth fog, SSAO, glow, ACES tonemap, a two-band toon shader on islands.
- Network and i18n are **reused, not copied**: `game3d/shared/` holds symlinks to `game/scripts/{locale,exchange_api,
  market_stream,money,book_model,order_draft}.gd`. The 2D project is not modified.
  The 3D `MarketStream` autoload *extends* the shared one to add the `clock` channel the 2D client ignores.
- Same message-catalogue rule as ADR-0014: `game3d/i18n/strings.csv`, keys in code, ru + en in the same commit.
- Same naming rule as ADR-0012: the real term leads, the lore name is a small caption.

## Why this and not the alternatives
| Alternative | Why not (now) |
|---|---|
| Three.js / Babylon.js web client | Would share TypeScript with `clients/web`, and WebGL2 lighting is fine; but we would rebuild scene tree, input, UI, i18n and the network layer from zero and lose GUT tests and the `game/` code. Godot gives the same look with less code and stays a "real PC game". |
| Godot Compatibility renderer (as `game/`) | No volumetric fog, SSAO or SDFGI — the very things that make the 3D look cosy. |
| Godot Mobile renderer | Same limits as above, aimed at phones. |
| Shared code as a Godot addon copied into both projects | Two copies drift. A symlink keeps one source until the 2D client is retired or a real package format is needed. |

## Pros
- No asset pipeline: the whole world is text, diff-able and reviewable, licence is ours.
- One network/i18n implementation for both game clients; tests in `game/` keep covering it.
- Lighting carries the style, so adding a new island is a few lines of code.

## Risks and costs
- Forward+ needs Metal/Vulkan; very old GPUs can't run it. We notice by the fps label (`F3`) and fall back to fewer effects.
- Symlinks: Git on Windows needs `core.symlinks=true`. If that hurts, move `shared/` to a real folder both projects import.
- Procedural art has a ceiling; an art pass with CC0 or own models can replace individual builders later without touching scenes.

## How to explain it (teaching note)
"For the 3D client I chose a stylised low-poly look because the beauty comes from light and fog rather than from
textures, so everything can be generated in code without an artist. I kept Godot so the network and i18n layer is
shared with the 2D client — a shared kernel — and the new client extends the old stream instead of copying it."

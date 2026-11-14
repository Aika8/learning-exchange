# 0012. Real names everywhere, lore names as flavour

- Status: Proposed
- Date: 2026-11-12 (revised the same day after Aika's decision: real terms visible everywhere)
- Pattern(s): Anti-Corruption Layer (in the BFF), Reference data catalogue, Ubiquitous language per bounded context (DDD)

## Context
The same market is "the Ladder" in the game and "стакан" in the mobile app. The teaching value is the bridge between the two.
Aika's rule: a player who later trades for real must not be confused — so **real terms are always visible**;
lore names are the world's flavour, never a replacement (world bible §6).

## Decision
- The core uses neutral codes (`SILK`, `AMBER`, `SPARK`) and a catalogue with scale, tick size, fees and
  `names: { real: {ru,en}, lore: {ru,en} }`.
- Concept glossary (stop-loss ↔ Якорь, spread ↔ Пропасть, order book ↔ Лестница…) lives in `docs/lore/glossary.yaml`
  (ids + ru/en for both names + one-line definition) and is served by both BFFs.
- `bff-game`: every control, column and number label uses the **real** term; the lore name goes as a secondary label/tooltip
  ("Стоп-лосс · Якорь"); dialogue uses lore words and introduces the real one on first use.
- `bff-mobile`: real terms only; it never serves lore names (the app knows nothing about the game).
- The dependency goes one way: the game knows the app and may use its screen names and navigation to prepare the player.
- Number formats are real-world (ticker-style codes, price steps, R, P&L) in both clients.

## Why this and not the alternatives
| Alternative | Why not |
|---|---|
| Lore names only in the game | Players learn words that don't exist outside the game — confusion when trading for real |
| Lore names in the core | Domain polluted by one client's language |
| Separate markets for game and app | Loses "one account, two faces" |

## Pros
- Each bounded context keeps its own language; the core stays neutral.
- Real vocabulary is reinforced on every screen; the glossary is a learning artefact.

## Risks and costs
- Visual noise from double labels — the lore name is always secondary (smaller, muted) and can be hidden in settings.
- Two names × two languages = four strings per concept; the glossary file is the single source, checked by a test for completeness.

## How to explain it
"The core speaks neutral codes; each frontend's BFF translates into its own language — a small anti-corruption layer.
We still show real finance terms everywhere so knowledge transfers to real trading."

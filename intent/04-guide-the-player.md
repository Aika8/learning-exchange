# Intent (draft): the game leads the player — what to do next and where to go

Status: **draft for Aika** (2026-11-25), written from her words: "the game must lead the player to do different
things — when I last looked it was not clear at once what to do and where to go". Becomes an ADR only after her
review. Nothing here changes how the game looks; the look items are listed at the end for after the holiday.

## Problem

The day loop exists (`GameFlow`: port → plan → trading → sailing → evening chronicle, ADR-0023) and refuses wrong
moves with a reason ("first provisions", "first a plan with Mara", "no Anchor, no sailing"). But a refusal tells
what is missing only after the player tried; nothing says what to do *first*, and nothing points at *where* — which
person, which building, which island.

## What we want

1. **A chain of near goals.** At any moment the game knows the one next goal: a short sentence ("Buy provisions
   for six moons at the market"), the place it happens (a person or a building on an island) and why (the lesson).
   Goals come from the game's state, not from a script that can break.
2. **"What next?" on demand.** One key / button shows the current goal again, with the way to it.
3. **The first day by the hand.** From a new game: meet Mara → buy provisions → make a plan with Mara → place the
   first order on the Ladder → set the Anchor → sail or stay → read the evening chronicle. Each step names its place.
4. **Never stuck.** From every reachable state there is a next goal the player can actually do (a goal whose
   precondition cannot be met is a bug). After the first day, goals widen into choices ("visit an island you have
   not seen", "the Forge reports in two days").
5. **Refusals turn into goals.** Every refusal of `GameFlow` names the goal that removes it.
6. **Words.** Goals use the real term with the lore name beside it, like everything else; no advice ("buy X").

## Invariants (each becomes a test)

1. For every `GameFlow` state × every combination of its guard facts (cushion, approved, holding, anchored) ×
   day 1 / later: `Goals.next(...)` returns a goal, and the goal's action is allowed in that state.
2. Following the goals from a fresh game reaches the evening chronicle of day 1 in at most ten steps.
3. Every refusal key maps to exactly one goal, and doing that goal removes the refusal.
4. Every goal has a hint text in ru and en, and a place id that exists in the world.

## Without a screen (queued)

The goals model (`game3d/scripts/core/goals.gd`) and its tests; the hint texts in `game3d/i18n/strings.csv`; the
refusal → goal map; the first-day walk as a test.

## For Aika after the holiday (the look)

Where the goal is shown (HUD line, Chronicler's notebook, Mara saying it), the arrow or marker to the place,
whether the first day is skippable, how loud the hint is after day one, the sound. The daily «user» run checks the
words of the goals and reports where a newcomer would still be lost.

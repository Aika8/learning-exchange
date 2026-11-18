# 0038. The pyramid island: a pastel fairground under a glass dome that is a facade on props, and decays visit by visit; a place and a style, no mechanics

- Status: Proposed
- Date: 2026-11-18
- Pattern(s): Strategy chosen by data (the kept `toy` technique, ADR-0026/0029/0035), Builder (`PyramidIsle`), State by a counter (`PyramidIsle.stage(visits)`), Registry row (`Ports`, ADR-0032)

## Context
Aika wants an island that is **"too good to be true"**: a scheme that promises easy money and lives on newcomers.
She has drawn it (seven sheets, `docs/design/concepts/73…79`): a pastel fairground under a gold-ribbed glass dome on
a rock with crystals (73); every building is a glossy pastel front, and from behind it is raw plywood on grey
scaffolding, sandbags and clutter (74); a carousel, a big wheel, a wheel of fortune, ticket booths and a
staircase **pyramid of booths with a golden pavilion on top** (75); the people — a host in a top hat with a cane, a
barker with a megaphone, a happy man with fanned tickets, a worried man counting coins, a grey old sweeper (76);
**four stages** (77): full and shining → fewer people → cracks in the dome, bare plywood, stalls closed → the dome
broken, bare props, tickets on the ground; props (78): a golden ticket, a megaphone, a tiered coin fountain on
scaffolding, balloons, a confetti cannon, plywood boards on sandbags, glass shards; the technique (79): glossy
pastel, raw plywood and grey scaffolding, translucent glass, cracks, soft even light.

The toy technique (`tech == 5`) exists and is kept on purpose (ADR-0035) for exactly this.

Limits from outside:
- **No Ponzi mechanics.** No loan, deposit or payout funded by newcomers' money, no "invest here" button. A place
  that shows what such a scheme looks like and how it ends; its talks name the warning signs, recommend nothing.
- **No words on signs**, and no "+30 %" anywhere: pictograms only (a ticket, a coin, an arrow up). The sheets'
  lettering ("TICKETS", "golden ticket") is not built.
- Eyes: no pattern laid out on the screen; the glass must not shimmer on the move.

## Decision
1. **The island `pyramid`** («Остров пирамиды», working name), built by `PyramidIsle`, in the **toy** technique
   (row `pyramid` in `IslandStyle`): a disc of rock with pastel crystals round the rim, a **glass dome** with gold
   ribs over the fair, and inside — the carousel, the big wheel, the wheel of fortune, ticket booths, the pyramid of
   booths with the golden pavilion, the coin fountain, balloons and bunting, a pier outside the dome's door.
2. **Facades on props.** Every building is a front only: seen from behind, plywood on grey scaffolding with sandbags
   (sheet 74). The captain can walk round and see it.
3. **Four stages by the number of visits**, a pure function `PyramidIsle.stage(visits)` → 1…4 (1st visit = 1, 2nd =
   2, 3rd = 3, 4th and later = 4), the counter in `Game` and saved with it. What each stage changes (sheet 77):
   1 — everything shines, many people, rides turn; 2 — half the people, rides slower, fewer balloons;
   3 — cracks drawn on the dome, some fronts gone to bare plywood, booths shut, rides stopped but the carousel;
   4 — dome panels missing and shards on the ground, nearly all fronts bare, tickets on the ground, only the
   sweeper and one barker left. Stages are data on the builder, not a separate model.
   The counter is a stand-in until the market's phases exist (intent 03): then the stage may follow time instead.
4. **Islanders** after sheet 76 — the host, the barker, the happy ticket holder, the worried coin counter, the
   sweeper: new costume roles `pyr_*` in the toy look; their figures from the sheet in comic pages (one face each).
   They speak as people inside the scheme: the barker promises, the happy one recruits, the worried one cannot get
   his coins out, the sweeper has seen it before. Nothing they say is advice.
5. **On the flight chart**: a row in `Ports` with a pier; the captain is redrawn as a pastel toy on landing (test).
6. **Not built now**: rides that carry people, the inside of booths, any game of chance, the hot-air balloons and
   the airship of sheet 73 (moving things in the sky need the audit's rules).

## Why this and not the alternatives
| Alternative | Why not (now) |
|---|---|
| A working scheme (deposit, promised return, collapse) | Forbidden by the brief: no Ponzi mechanics; it would also teach by doing the wrong thing |
| Stages from game days or the market | No phases yet (intent 03 step 4); visits are what the player controls and sees change |
| Stages as four separate island scenes | Four times the content to keep in step; a stage is a few switches on one builder |
| Signs with promised percentages | Forbidden by the brief; pictograms carry the lure without words to translate |
| A new technique for the island | The toy one was built for this look and kept for it |

## Pros
- Teaches by looking: the same place, visit after visit, shows how such a scheme ends; the back of the facades is
  the lesson before anybody speaks.
- Reuses the toy technique and costume parts; the stage is a pure, tested function.

## Risks and costs
- Glass over the whole fair: transparency costs frames and can shimmer — one dome mesh, no refraction, measured
  with `--fps` (60 fps or the island waits).
- A visit counter can feel arbitrary; it is a stand-in, said so in intent 03.

## How to explain it (teaching note)
A state machine with a pure transition function: the stage is computed from one counter, and the builder reads it
like any other data, so a test can ask "what does the fourth visit look like" without running the game. The island
shows a Ponzi scheme without implementing one — the game's rules forbid money from newcomers paying old players.

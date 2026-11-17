# 0028. Amber Cliff is a French-speaking island: its own language, its own technique, a gloss on demand

- Status: Accepted (2026-11-17)
- Date: 2026-11-17
- Pattern(s): Message catalogue per island (`IslandTongue`), Strategy by data (a third technique in `IslandStyle`)

## Context
Aika learns French and wants it in the game: a new big island where every sign and every person speaks French,
whatever the language of the game, with a way to see the translation. She wants the island in "a very recognisable
French game style"; CLAUDE.md forbids copying an existing game. The island must still teach finance, with real
terms next to lore names (ADR-0012).

The world bible has seven islands, three at the start. The third, **Amber Cliff** (Янтарный Утёс: gold and amber,
the reserve currency, a slow and steady market — the lesson is the exchange rate), is not built yet. A reserve
currency island is a natural home for a bank and a bureau de change, the two places where everyday French money
words live.

Forces:
- ADR-0014: ru and en switch at runtime through one catalogue; the 2D game shares `Locale`. A third game language
  would touch every screen and every test; that is not what is asked.
- A learner must be able to read the French first and ask for help second. Two languages at once on screen is
  subtitles, not reading.
- The look of an island is a row and a technique (ADR-0026).
- `docs/design/README.md`: no words on signs. Here reading the signs is the point.

## Decision
1. **Amber Cliff (`amber`, «La Falaise d'Ambre») is built** as a walkable town, larger than Spark Harbour: a
   quay, a market square with a fountain, the Banque d'Ambre, a bureau de change, a bakery, a café, a bookshop,
   a lighthouse, streets of town houses. It is reached by the packet boat from the Spark Harbour wharf (a signpost;
   no trading day is needed to go there and back).
2. **The island has a tongue.** `IslandTongue` maps an island to a locale (`amber → fr`). Its words live in their
   own catalogue, `game3d/i18n/amber.csv` (`keys,fr,ru,en`). On the island, signs, prompts, the island's title and
   every talk are shown in `fr`; the game's own HUD (flow bar, help line, glossary) stays in the game's language.
   The game language switch does not gain French.
3. **A gloss on demand.** Hold **T**: the prompt, the nearest sign and every balloon of an open comic page show
   the same words in the game's language. Release, and it is French again.
4. **Finance in French.** Each place teaches one idea, with the real term and the lore name side by side in French
   (le taux de change — « le cours de l'ambre »): exchange rate and spread at the bureau de change, savings and
   compound interest at the bank, inflation at the bakery, the safety cushion at the café, the trade journal at the
   bookshop, volatility and the stop at the lighthouse. Talks are comic pages (ADR-0027) marked `"speak": "fr"`.
5. **Its technique is `claire`**, from the French-Belgian bande dessinée tradition, as principles only: one even
   black line for everything (ligne claire), flat colour with a single soft shade instead of gradients, a
   watercolour wash for the sky and far things, paper grain. Mode 2 is a black-and-white album page: the line and
   fine one-way hatching in the shade. No character, town or drawing of any existing album or game is used.
6. **Signs carry words on this island only** (an exception to the pictogram rule, recorded in the design README).
   The town houses (pale plaster, tall shuttered windows, slate mansard roofs, striped awnings) are built in code;
   the people wear the existing costumes until Aika draws sheets for them.

## Why this and not the alternatives
| Alternative | Why not (now) |
|---|---|
| French as a third game language | Not the request; triples every string and test; the island would stop being special |
| Always show French with a subtitle | The eye goes to the subtitle; the learner stops reading French |
| Voice the lines | No voice assets, no new sources; text is what TCF reading needs |
| Turn Silk Reach French | It has its own lesson and look; the bible has a free island that fits |
| Imitate one well-known French game or album | Forbidden, and unnecessary: the tradition's principles are enough to be recognised |
| A new costume set drawn in code without sheets | "What the sheets do not cover is a question for Aika" |

## Pros
- French is met in context: the same finance ideas the player already knows from the harbour.
- One mechanism (a catalogue per island) would serve any other tongue later.
- The comic page of ADR-0027 does the talking; the gloss was already in its design.

## Risks and costs
- The French is a first draft by the implementer, at about A2–B1. Aika or her tutor should read it; it lives in one CSV.
- A third technique grows the shader; watched with `--fps`.
- The lore gains a fact: people of Amber Cliff speak their own language. It should go into the world bible if kept.
- The town houses and the island's layout have no concept sheet; they may be redrawn when one arrives.
- Reaching the island by a signpost skips the voyage scene; a real passage can replace it later.

## How to explain it (teaching note)
A message catalogue does not have to be global. Here the key stays the same and the question "which language?" is
answered by where you stand: the island picks the catalogue column, the game language picks the gloss.

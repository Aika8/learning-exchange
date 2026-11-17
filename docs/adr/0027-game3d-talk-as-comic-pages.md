# 0027. Talking to people opens a comic page; the page is data

- Status: Proposed
- Date: 2026-11-17
- Pattern(s): Data-driven script + Iterator (`ComicScript`, `ComicReader`), Builder (`ComicShot` builds a panel picture)

## Context
"Talk" in `game3d` was one line of text in a box at the bottom of the screen (`harbour.gd::_say`). Aika wants talks
in the manner of a visual novel: a comic page opens, with frames, portraits of the speakers and speech balloons.
The words are a first draft (from the world bible, ru + en); Aika will rewrite them, so they must not live in code.

Forces:
- People are faceless figures built in code from the concept sheets (ADR-0024). Drawn portraits would be a new art
  source and would not match the figures; no new asset sources without Aika's yes.
- Some lines carry live numbers (Olva's consensus).
- The page must not cost frame rate while the world is still drawn behind it.
- A French-speaking island is planned (ADR-0028): a balloon must be able to show a gloss in the game's language.

## Decision
1. **A talk is data.** `game3d/data/talks.json` holds the cast (who they are, their costume role), backdrops, and
   talks: pages → panels → a shot (`close`, `two`, `wide`, `low`), who is in it, poses, an optional caption and
   up to two balloons. The words are keys in `game3d/i18n/talk.csv` (`keys,ru,en`), with `{name}` slots for numbers.
2. **`ComicScript`** (pure, `scripts/core/`) loads and checks the data (`problems()`: unknown speakers, missing
   keys, too many panels or balloons, text too long for a balloon). **`ComicReader`** is a cursor: each step shows
   the next balloon, then the next panel, then the next page.
3. **Portraits are the game's own people.** `ComicShot` builds a small scene per panel in its own `SubViewport`:
   the same `Proc.figure` in the same costume, posed by a few bone turns, a camera for the shot, the island's ink
   effect. It is drawn for a few frames and then frozen, so an open page costs nothing per frame.
4. **`ComicPage`** (`scripts/ui/`) lays out one to four frames on a paper sheet, draws balloons with tails that
   point at the speaker's head, name tags and captions. E / Enter / click — next; Esc — close.
5. The harbour opens talks for Mara (first meeting), Olva, the Chronicler by day, the post keeper, and for every
   stroller ("E — talk"). Refusals and one-line notes keep the old box. Tool runs (`--demo`, audit) skip pages.

## Why this and not the alternatives
| Alternative | Why not (now) |
|---|---|
| Drawn 2D portraits (image model or an asset pack) | A new art source; faces where the style has none; a set per costume |
| A dialogue add-on (Dialogic and the like) | A big dependency for linear pages; its own data format and UI to restyle |
| Branching dialogue with choices | Nothing in the slice needs a choice; a talk here teaches one idea. The data leaves room (`next`) |
| Words inside the JSON (`{"ru": …, "en": …}`) | Two i18n mechanisms; the CSV is what the rest of the game and the tests use |
| Live, animated panels | Costs frames for every open panel; a comic frame is still |

## Pros
- Aika edits words in one CSV and staging in one JSON; no code.
- Portraits always match the people in the world, on every island and in every technique.
- The reader and the checks are plain code under GUT.

## Risks and costs
- Faceless people act only by pose and framing; there are six poses. We notice if pages read flat.
- Balloon placement is a rule, not a hand layout: long text can cover a head. `problems()` caps the length;
  `--talk=<dir>` prints every page for a look.
- A panel is a viewport: four per page at most, frozen after a few frames.

## How to explain it (teaching note)
The script is data and the reader is an iterator over it: the UI asks "what is visible now?" and "step", and never
knows how pages are stored. The picture in a frame is built by a builder from the same parts the world uses, so
there is one source of truth for how a person looks.

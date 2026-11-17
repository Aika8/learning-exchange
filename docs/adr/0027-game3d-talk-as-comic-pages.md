# 0027. Talking to people opens a comic page; the page is data

- Status: Accepted (2026-11-17)
- Date: 2026-11-17
- Pattern(s): Data-driven script + Iterator (`ComicScript`, `ComicReader`), Flyweight (`ComicFaces`: one picture per hero and emotion, shared by every frame)
- Revised 2026-11-17 while still Proposed: portraits are drawn 2D faces from Aika's expression sheets, not the 3D figures

## Context
"Talk" in `game3d` was one line of text in a box at the bottom of the screen (`harbour.gd::_say`). Aika wants talks
in the manner of a visual novel: a comic page opens, with frames, portraits of the speakers and speech balloons.
The words are a first draft (from the world bible, ru + en); Aika will rewrite them, so they must not live in code.

Forces:
- People in the 3D world are faceless figures (ADR-0024). Aika asked for real comic panels: heroes drawn in 2D with
  faces whose expression changes with the line, and sent the art herself — a style sheet and an expression sheet per
  hero (`docs/design/concepts/06…12`): six heroes, six emotions each.
- Not every speaker has a sheet yet.
- Some lines carry live numbers (Olva's consensus).
- The page must not cost frame rate while the world is still drawn behind it.
- A French-speaking island is planned (ADR-0028): a balloon must be able to show a gloss in the game's language.

## Decision
1. **A talk is data.** `game3d/data/talks.json` holds the cast (who they are, their costume role), backdrops, and
   talks: pages → panels → a shot (`close`, `two`, `wide`, `low`), who is in it, an optional caption and up to
   two balloons, **each with the emotion it is said with** (`neutral happy surprised sly worried angry`); `mood`
   gives the face of somebody who only listens. The words are keys in `game3d/i18n/talk.csv` (`keys,ru,en`), with `{name}` slots for numbers.
2. **`ComicScript`** (pure, `scripts/core/`) loads and checks the data (`problems()`: unknown speakers, missing
   keys, too many panels or balloons, text too long for a balloon). **`ComicReader`** is a cursor: each step shows
   the next balloon, then the next panel, then the next page.
3. **Portraits are drawn faces.** `ComicFaces` serves one picture per hero and emotion, cut from Aika's
   expression sheets (`game3d/art/portraits/<face>_<emotion>.jpg`). A cast entry names its sheet (`"face"`). A
   frame shows the speakers as portraits on paper with halftone dots; when a balloon appears, its speaker's face
   changes to that line's emotion, the listener steps back a little, and the marks comics use appear by the head
   (a burst with "!", sweat drops, a sparkle) — shapes and letters of our own. A shouted line gets a bristling
   balloon. A speaker without a sheet gets a simple stand-in drawn in code (`ComicDoodle`, a `"look"` in the
   data) with the same six emotions, until a sheet arrives.
4. **`ComicPage`** (`scripts/ui/`) lays out one to four frames on a paper sheet, draws balloons with tails that
   point at the speaker's head, name tags and captions. E / Enter / click — next; Esc — close.
5. The harbour opens talks for Mara (first meeting), Olva, the Chronicler by day, the post keeper, and for every
   stroller ("E — talk"). Refusals and one-line notes keep the old box. Tool runs (`--demo`, audit) skip pages.

## Why this and not the alternatives
| Alternative | Why not (now) |
|---|---|
| The 3D figures posed in a small viewport per frame (the first version of this ADR) | Faceless: no expression to change with the line; Aika asked for drawn faces |
| Faces drawn entirely in code for everybody | Far from the quality of the sheets; kept only as the stand-in |
| Cut-out portraits with the paper keyed away, over painted backgrounds | Keying eats white collars and eyes; the sheets' own paper is the page's paper, with soft edges |
| A dialogue add-on (Dialogic and the like) | A big dependency for linear pages; its own data format and UI to restyle |
| Branching dialogue with choices | Nothing in the slice needs a choice; a talk here teaches one idea. The data leaves room (`next`) |
| Words inside the JSON (`{"ru": …, "en": …}`) | Two i18n mechanisms; the CSV is what the rest of the game and the tests use |
| Live, animated panels | Costs frames for every open panel; a comic frame is still |

## Pros
- Aika edits words in one CSV and staging in one JSON; no code.
- The faces are Aika's own approved art; adding a hero is a sheet and one word in the data.
- The reader and the checks are plain code under GUT.

## Risks and costs
- Sixteen speakers have no sheet and are stand-ins; next to the sheets they look plain. We notice on every page
  where one appears; the cure is a sheet.
- The comic heroes and the 3D figures no longer look alike (Mara, Olva): two looks for one person until one follows
  the other. That is Aika's call.
- Portraits are busts facing one way; a frame cannot show an action, only a face and words.
- Balloon placement is a rule, not a hand layout: long text can cover a head. `problems()` caps the length;
  `--talk=<dir>` prints every page for a look.
- 36 pictures, 3.5 MB, loaded on first use and kept.

## How to explain it (teaching note)
The script is data and the reader is an iterator over it: the UI asks "what is visible now?" and "step", and never
knows how pages are stored. The faces are flyweights: 36 pictures shared by every frame that needs them, chosen by
two words in the data — who, and how they feel.

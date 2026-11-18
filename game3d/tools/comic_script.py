#!/usr/bin/env python3
"""Writes docs/design/comic-script.md from data/talks.json: for every talk, page and panel the layout, the place, who is
in frame and how they feel, the shot, where the balloons go, and a ready English prompt for an image model that draws
the panel WITHOUT any text (ADR-0037 amendment, DECISIONS.md «G3D drawn comic panels»). The words stay the game's.

Run after talks change:  python3 game3d/tools/comic_script.py
"""
import csv
import json
from pathlib import Path

GAME = Path(__file__).resolve().parent.parent
OUT = GAME.parent / "docs" / "design" / "comic-script.md"

# ComicPage.LAYOUTS (shares of the sheet) and the sheet's size on a 1920×1080 screen (ComicPage._paint).
LAYOUTS = {
    1: [(0, 0, 1, 1)],
    2: [(0, 0, 0.5, 1), (0.5, 0, 0.5, 1)],
    3: [(0, 0, 0.42, 1), (0.42, 0, 0.58, 0.5), (0.42, 0.5, 0.58, 0.5)],
    4: [(0, 0, 0.56, 0.5), (0.56, 0, 0.44, 0.5), (0, 0.5, 0.44, 0.5), (0.44, 0.5, 0.56, 0.5)],
}
SHEET = (1240 - 14, 780 - 14)
GUTTER = 14

STYLE = ("Comic book panel in the style of the attached sheet 06-comic-style: confident black ink outlines, light "
         "hatching in the shadows, bright flat colour, a little halftone shade; warm, friendly, for all ages")
NO_TEXT = ("No text of any kind: no speech balloons, no captions, no letters, no numbers, no signs with writing, "
           "no logos, no sound words, no frame border")

# place: what the island looks like, its technique as a hint for the background, the sheets to attach.
PLACES = {
    "wharf": ("Spark Harbour, a timber wharf on a flying island: planks, bollards, rope coils, barrels, a moored "
              "sailing ship behind, warm afternoon sky", "pen and ink with warm washes", ["24-spark-harbour", "25-props"]),
    "square": ("Spark Harbour's market square: half-timbered houses, market stalls with awnings, a windmill on a terrace "
               "above, warm light", "pen and ink with warm washes", ["24-spark-harbour", "25-props"]),
    "silk": ("Silk Reach, a flying island of a trading post: timber halls, silk racks drying in the wind, wave and "
             "diamond patterns on cloth", "katazome stencil print feel: several blues, sand, ochre, rust, cream paper",
             ["28-silk-katazome-loose"]),
    "dusk": ("Spark Harbour at dusk, lanterns lit", "pen and ink with dusk washes", ["24-spark-harbour"]),
    "amber": ("Amber Cliff, a French seaside town on a flying cliff: plaster town houses with mansard roofs, teal "
              "shutters, red doors, iron balconies, a lighthouse with amber bands", "pen and watercolour, a travel "
              "sketchbook", ["29-amber-view", "30-amber-houses", "34-amber-technique"]),
    "amber_in": ("inside a shop or bank on Amber Cliff: wooden counters, shelves, tall windows with light coming in",
                 "pen and watercolour, a travel sketchbook", ["31-amber-street", "34-amber-technique"]),
    "noir": ("the short sellers' island: a tilted stone slab, crooked leaning houses with red doors, wet street "
             "under a street lamp with a red lantern, slanted rain, fog", "film noir: black, white and one red "
             "(#c4302b) only", ["35-shorts-view", "38-shorts-houses", "37-shorts-technique"]),
    "neon": ("the crypto island at night: neon towers, a glowing perspective grid on the ground, a striped setting "
             "sun, a neon palm", "synthwave colours (violet, magenta, cyan) — but as comic ink and flat colour, "
             "not pixels", ["41-crypto-view", "42-crypto-houses", "46-crypto-technique"]),
    "pastel": ("a pastel toy town under a glass dome", "glossy pastel toy", ["47-index-view", "51-index-technique"]),
    "deco": ("the race island: a banked track round a rock, a streamlined tower, grandstands with flags, red gates, "
             "small racing sky-skiffs, sunburst sky", "art-deco poster: aerodynamic shapes, metal stripes, sun rays",
             ["52-race-view", "53-race-buildings", "58-race-technique"]),
    "oil": ("the index island, a Dutch Golden Age canal town: stepped brick gables, a canal with an arched bridge, "
            "lindens, the exchange with a clock tower", "soft oil painting light, warm evening",
            ["59-dutch-view", "60-dutch-houses", "62-dutch-canal", "66-dutch-technique"]),
}

# who: their look as drawn on their sheets (the face sheets win over the older full-figure ones), for the prompt, and the sheet(s) to attach as the face/figure reference.
PEOPLE = {
    "captain": ("the young sky captain: wavy chestnut hair, navy gold-trimmed long coat, cream shirt, red sash, brass spyglass, navy gold-edged tricorn hat", ["07-faces-captain", "01-captain"]),
    "mara": ("Mara: a young woman with tousled short dark-brown hair, a khaki cloth headband tied at the side, a brown leather high-collared vest over a cream open-necked shirt", ["08-faces-mara", "03-mara"]),
    "olva": ("Olva Quill: a young man with shaggy brown hair, tall purple top hat with a red band and purple-green-yellow feathers, purple gold-trimmed coat, white cravat, red waistcoat", ["10-faces-olva"]),
    "chronicler": ("the Chronicler, an owl scholar: round wire spectacles, tufted ear feathers, slate-blue layered feather robe, leather belts with an ink bottle, a small lantern and a chained book", ["13-faces-chronicler", "26-chronicler"]),
    "keeper": ("the post keeper: a middle-aged woman, brown hair under a cream headscarf knotted at the nape, dark grey blouse, purple apron", ["14-faces-keeper"]),
    "sailor": ("the tall sailor: lanky and young, messy dark hair, red bandana tied at the side, worn brown vest over a cream open-neck shirt", ["15-faces-sailor", "02-sailors"]),
    "sailor2": ("the boatswain: stocky, full dark-brown beard, navy knitted watch cap, navy pea jacket, grey wool scarf", ["16-faces-second-sailor", "02-sailors"]),
    "sailor3": ("the old sailor: burly, weathered, nearly bald with grey stubble, blue bandana tied at the side, small gold hoop earring, blue-and-white striped sleeveless top", ["11-faces-old-sailor", "02-sailors"]),
    "child": ("the ship's boy: freckled, shaggy auburn hair, grey-brown flat cap, faded light-blue jacket over a navy-and-white striped shirt", ["17-faces-ship-boy"]),
    "townsman": ("the old townsman: thin, grey hair, battered brown brimmed felt hat, worn brown overcoat, a curved wooden cane", ["18-faces-townsman"]),
    "trader": ("Grandma Vetla: silver hair in a bun, small round wire spectacles, gold drop earrings, teal buttoned blouse, thick knitted rust-orange shawl", ["09-faces-vetla"]),
    "amb_captain": ("the young sky captain: wavy chestnut hair, navy gold-trimmed long coat, cream shirt, red sash, brass spyglass, navy gold-edged tricorn hat", ["07-faces-captain", "01-captain"]),
    "changeur": ("M. Lenoir, the money-changer: lean, long hooked nose, swept-back dark hair, pointed dark goatee, brown coat with a thick pale fur collar", ["12-faces-merchant"]),
    "banquiere": ("Mme Sorel, the banker: light-brown hair in a tight high bun, thin oval spectacles, pearl earrings, plum high-collared buttoned jacket", ["19-faces-banquiere"]),
    "boulangere": ("Colette, the baker: plump and rosy-cheeked, short ginger hair, patterned headscarf, dark grey blouse, flour-dusted cream apron", ["20-faces-boulangere"]),
    "garcon": ("Lucien, the waiter: slim, slicked-back black hair, long face, white shirt, black waistcoat, dark bow tie, white napkin over the arm", ["21-faces-garcon"]),
    "libraire": ("Anatole, the bookseller: elderly, grey hair and short grey goatee, navy beret, small round spectacles, green cardigan over an olive vest", ["22-faces-libraire"]),
    "gardienne": ("Maëlle, the lighthouse keeper: long straight auburn hair, dark grey knitted beanie, red work jacket with a brown collar", ["23-faces-gardienne"]),
    "marin": ("a young sailor in a striped shirt and a navy beret, fair hair", []),
    "fleuriste": ("the flower seller, red hair, a straw hat, an apron, a bucket of flowers", []),
    "enfant": ("a small boy in a cream shirt and a mustard cap", []),
    "monsieur": ("an elderly gentleman with white hair, glasses, a dark brimmed hat, a brown coat", []),
    "etudiante": ("a student with dark hair in a bun, glasses, a teal coat, books under her arm", []),
    "noir_broker": ("the broker: tall, black fedora, long black double-breasted overcoat, white shirt, red tie, pinstriped trousers", ["36-shorts-people"]),
    "noir_tramp": ("the old man with the armband: stooped, white beard, battered hat, torn grey overcoat with a red armband, a closed black umbrella as a cane", ["36-shorts-people"]),
    "noir_youth": ("the pale youth: thin, wide-eyed, messy dark hair, dark jacket over a red shirt, clutching a book", ["36-shorts-people"]),
    "noir_lady": ("the woman in the red scarf: dark bobbed hair, black brimmed hat, belted black coat, long red scarf, red lips", ["36-shorts-people"]),
    "crypto_trader": ("the crypto trader: a young man with a quiff, green sunglasses, glowing cyan puffer jacket, chains, purple trousers, a holographic tablet", ["44-crypto-people"]),
    "crypto_miner": ("the miner: grey-haired, hard hat with a headlamp, gas mask, olive parka, kneepads, a drill and a pickaxe", ["44-crypto-people"]),
    "crypto_dreamer": ("the dreamer: a cheerful young man with shoulder-length brown hair, magenta hoodie, magenta sneakers, confetti around", ["44-crypto-people"]),
    "crypto_analyst": ("the analyst: a woman with brown hair, cyan visor glasses, dark high-collared jacket with cyan trim, cargo pants, reading a tablet", ["44-crypto-people"]),
    "bot_trader": ("the trading bot: a floating round grey robot with a smiling cyan face screen, a chart display on its body, small jet thrusters", ["44-crypto-people"]),
    "bot_miner": ("the mining bot: a squat grey-and-gold robot on tank treads, round cyan face screen, small head lamp, claw hands", ["44-crypto-people"]),
    "bot_info": ("the news bot: a round grey robot with a winking cyan face screen, many antennae, spindly spider legs, small floating panels", ["44-crypto-people"]),
    "deco_aviator": ("the aviator: leather flying helmet and goggles, white silk scarf, brown fur-collared leather jacket, tan jodhpurs, laced boots", ["56-race-people"]),
    "deco_mechanic": ("the chief mechanic: burly, flat cap, dark rolled-sleeve shirt, grease-stained canvas overalls, a big brass wrench", ["56-race-people"]),
    "deco_crew": ("the crew member: young, teal cap and teal striped coverall, a pressure gauge and a clipboard", ["56-race-people"]),
    "deco_marshal": ("the marshal: combed fair hair, navy jacket and tie, red-and-white armband, tan breeches, black riding boots, red and yellow flags", ["56-race-people"]),
    "deco_lady": ("the spectator: a blonde woman in a peach cloche hat, peach long coat with navy panels, silk neck scarf, binoculars", ["56-race-people"]),
    "oil_merchant": ("the merchant: greying goatee, black wide-brimmed hat, large white ruff, black doublet and cape, a ledger", ["63-dutch-people"]),
    "oil_lady": ("the young woman: lace cap, wide white lace collar and cuffs, dark velvet bodice, red skirt, a fan", ["63-dutch-people"]),
    "oil_market": ("the market woman: weathered, white cap, olive shawl, grey-green bodice, grey apron and skirt", ["63-dutch-people"]),
    "oil_father": ("the young father: shoulder-length brown hair, short beard, white collar, dark grey doublet and breeches", ["63-dutch-people"]),
    "oil_child": ("the little one: a small blonde girl in a grey cap, white collar, dark blue-grey dotted dress with an apron", ["63-dutch-people"]),
    "oil_grandpa": ("the old man: thin, black skullcap, white collar, olive doublet, worn brown cloak, a wooden staff", ["63-dutch-people"]),
    "oil_granny": ("the old woman: white cap and white collar, black shawl over a dark dress, grey apron", ["63-dutch-people"]),
}

FEEL = {
    "neutral": "calm, attentive",
    "happy": "smiling warmly, open posture",
    "angry": "frowning, leaning in, a pointing hand",
    "surprised": "eyebrows up, eyes wide, leaning back a little",
    "worried": "worried brow, a hand at the chin or the collar",
    "sly": "a sly half-smile, one eyebrow raised",
}
SHOT = {
    "close": "Close-up: head and shoulders filling the frame",
    "two": "Two-shot: both from the waist up, facing each other across the frame",
    "wide": "Wide establishing shot: the whole place, the people small and full-figure",
    "low": "Low-angle shot from below, the figure looming, from the knees up",
}


def words():
    table = {}
    for name, en in (("talk.csv", "en"), ("amber.csv", "en")):
        rows = list(csv.reader((GAME / "i18n" / name).open(encoding="utf-8")))
        col = rows[0].index(en)
        for r in rows[1:]:
            if len(r) > col:
                table[r[0]] = r[col]
    return table


def ratio(n, i, mirrored):
    x, y, w, h = LAYOUTS[min(max(n, 1), 4)][i]
    pw, ph = w * SHEET[0] - GUTTER, h * SHEET[1] - GUTTER
    r = pw / ph
    best = min(["1:1", "4:3", "3:4", "16:9", "9:16", "3:2", "2:3"], key=lambda s: abs(eval(s.replace(":", "/")) - r))
    side = "left" if (x < 0.25) != mirrored else "right"
    pos = "full page" if n == 1 else f"{'top' if y == 0 else 'bottom'}-{side}" if n == 4 or (n == 3 and i > 0) else side
    return f"{best} (≈{pw:.0f}×{ph:.0f})", pos


def main():
    data = json.loads((GAME / "data" / "talks.json").read_text(encoding="utf-8"))
    text = words()
    cast = data["cast"]
    out = []
    pages_total = panels_total = 0
    for tid, talk in data["talks"].items():
        place, technique, place_refs = PLACES[talk["backdrop"]]
        pages_total += len(talk["pages"])
        out.append(f"\n## `{tid}` — {place.split(',')[0].split(':')[0]}\n")
        out.append(f"Place: {place}. Background hint: {technique}. "
                   f"Language spoken: {'French' if talk.get('speak') == 'fr' else 'the game language'}.\n")
        for p, page in enumerate(talk["pages"]):
            panels = page["panels"]
            n = min(len(panels), 4)
            mirrored = p % 2 == 1
            out.append(f"\n### Page {p + 1} — {n} panel{'s' if n > 1 else ''}"
                       f"{', mirrored (the big panel on the right)' if mirrored and n == 3 else ''}\n")
            for i, panel in enumerate(panels[:4]):
                panels_total += 1
                who = panel.get("cast", [])
                lines = panel.get("lines", [])
                mood = dict(panel.get("mood", {}))
                for line in lines:
                    mood.setdefault(line[0], line[2] if len(line) > 2 else "neutral")
                shape, pos = ratio(n, i, mirrored)
                speakers = [line[0] for line in lines]
                file = f"game3d/art/comic/{tid}/{p + 1}-{i + 1}.jpg"
                # where the game puts the figures and the balloons (ComicFrame.setup)
                if len(who) == 1:
                    stage = f"{PEOPLE[who[0]][0]} on the LEFT third of the frame, turned slightly right"
                    room = "the RIGHT half and the top"
                else:
                    stage = (f"{PEOPLE[who[0]][0]} on the LEFT, {PEOPLE[who[1]][0]} on the RIGHT"
                             if len(who) == 2 else ", ".join(PEOPLE[w][0] for w in who))
                    sides = sorted({"left" if who.index(s) == 0 else "right" for s in speakers if s in who})
                    room = "the top third" + (f", most over the {' and '.join(sides)}" if sides else "")
                caption = " Keep the top-left corner plain too, for a caption box." if "caption" in panel else ""
                feelings = "; ".join(
                    f"{PEOPLE[w][0].split(':')[0]}: {FEEL.get(mood.get(w, 'neutral'), 'calm')}"
                    + (" — speaking, mouth open" if w in speakers else " — listening") for w in who)
                refs = []
                for w in who:
                    refs += PEOPLE[w][1]
                refs = ["06-comic-style"] + list(dict.fromkeys(refs)) + place_refs[:2]
                prompt = (f"{STYLE}. {SHOT.get(panel.get('shot'), SHOT['two'])}. Setting: {place}; the background "
                          f"loosely in {technique}, softer and less detailed than the people. In frame: {stage}. "
                          f"Expressions and poses: {feelings}. Leave {room} as quiet, plain background for speech "
                          f"balloons added later (no faces or hands there).{caption} Aspect ratio {shape.split(' ')[0]}. "
                          f"{NO_TEXT}.")
                out.append(f"\n**Panel {i + 1}** — `{file}` — {pos}, {shape}, shot `{panel.get('shot')}`\n")
                for line in lines:
                    out.append(f"- {line[0]} ({line[2] if len(line) > 2 else 'neutral'}): «{text.get(line[1], line[1])}»")
                if "caption" in panel:
                    out.append(f"- caption: «{text.get(panel['caption'], panel['caption'])}»")
                out.append(f"- attach: {', '.join(f'`{r}.jpg`' for r in refs)}")
                out.append(f"\n```text\n{prompt}\n```")
    head = f"""# Comic script — panels for an image model

Generated by `game3d/tools/comic_script.py` from `game3d/data/talks.json`; do not edit by hand, run it again after
the talks change. {len(data['talks'])} talks, {pages_total} pages, {panels_total} panels.

**How it works.** The image model draws each panel **without any words** — the scene, the people in pose and
emotion, and empty room where the balloons go. The game lays the balloons, captions and name plates over the picture,
in Russian, English or French, so translations and rewrites never need redrawing.

**How to use.**
1. Per talk, attach `docs/design/concepts/06-comic-style.jpg` and the sheets named under each panel, paste the prompt.
2. Save the picture as the file named there: `game3d/art/comic/<talk>/<page>-<panel>.jpg` (from 1). JPEG, at least
   the size given (twice that is better); the game cuts it to the frame from the middle (cover), so keep the people
   away from the edges.
3. A missing picture is fine: that panel is put together as before (the scene and the cut-out figures).
4. If a balloon's tail misses the mouth, add to that panel in `talks.json`: `"tail": {{"<who>": [x, y]}}` — where
   the mouth is, as shares of the frame (0…1 from the top-left). `make check-game3d-data` checks the files' names and
   the tails.

**Where the game puts things.** One person: on the left third, the balloon on the right. Two: the first on the left,
the second on the right, balloons along the top over each speaker. Every second page is mirrored, so its panel
shapes are the other way round; the sizes below already say so. The words are listed for context only — they must
not be in the picture.
"""
    OUT.write_text(head + "\n".join(out) + "\n", encoding="utf-8")
    print(f"{OUT.relative_to(GAME.parent)}: {len(data['talks'])} talks, {pages_total} pages, {panels_total} panels")


if __name__ == "__main__":
    main()

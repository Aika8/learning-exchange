# Design — the source of truth for how the world looks

Read this before changing the look of anything in `game3d/` (people, buildings, ships, props). The concept sheets in
`docs/design/concepts/` are Aika's approved designs: **the game follows the sheets, not the other way round.**
Palette, light and world notes: `docs/design/game3d-style.md`. Lore: `docs/lore/world-bible.md`.

> Islands: each island is drawn in a technique of its own, chosen by Aika (ADR-0026, 0029) — Spark Harbour in pen
> and ink (the style below), Silk Reach as **katazome**, a Japanese stencil-resist print in several blues, ochre and rust (sheet 28; 27 for the motifs), Amber Cliff
> in **pen and watercolour**, a French travel sketchbook (sheets 29–34), the short sellers' island as **noir** —
> black, white and one red (sheets 35–40; ADR-0030), the index island as a **pastel toy town** (sheets 47–51; ADR-0033), the crypto island as **synthwave pixel art, softened** — sharp edges, texels fixed to the world, no dithering (sheets 41–46;
> ADR-0031). **No real brands**: where a sheet showed a real coin's mark or ticker, the copy here has it covered and
> the game uses its own wind coin. The technique and its colours are a row in
> `game3d/scripts/island_style.gd`. **The captain is redrawn in the technique of every port** by the island's wind
> (ADR-0025); a test holds every technique to that. Pictures: `docs/demo/G3D-techniques.md`.
>
> Amber Cliff is also the one place where **signs carry words** (French): reading them is the point of the island.
> Its sheets (29–33) show more than is built: see the rows below.

## Art style (ADR-0024)
Stylised low-poly: flat colours of the palette, meshes built in code, soft light; people read by **silhouette** (hat,
coat, sash), no faces; an ink outline by default and an engraving mode on **V** (`game3d/shaders/ink.gdshader`).
`Style` (`game3d/scripts/style.gd`) is the switch; `--pbr` is the old realistic look. The concept sheets give the
silhouettes and the colours; their pen line is what the ink outline stands for. Pictures: `docs/demo/G3D-style.md`.

**Characters are told apart by outline.** Reference for the feeling, by Aika: the illustrated sky-pirate books of
The Edge Chronicles — principles only (exaggerated proportions, big hats, long noses, layers of clothes and gear, a
pen line), never their characters or drawings. Builds are in `Costume.BUILDS`; give every new role its own.

## Concept sheets (`docs/design/concepts/`)
Ink-and-watercolour sheets drawn by an image model from our own brief (the brief is at the end of this file). Original
world; nothing is copied from a book, film or game. The palette row at the bottom of each sheet is the game palette.

| Sheet | Who | In the game | Code |
|---|---|---|---|
| `01-captain.jpg` | The young captain | the player | `Costume._r_captain` |
| `02-sailors.jpg` | Tall, stocky and old sailor | strollers on the wharf and on Silk Reach | `_r_sailor`, `_r_sailor2`, `_r_sailor3` |
| `03-mara.jpg` | Mara of the Anchor Order | Mara on the wharf (plans the voyage) | `_r_mara` |
| `04-townsfolk.jpg` | Money-changer, Olva, market woman, old man, child | brokers in the hall, Ольва Перо, the post keeper and strollers | `_r_changer`, `_r_olva`, `_r_trader`, `_r_townsman`, `_r_child` |
| `05-chronicler.jpg` | The Chronicler, an owl scholar — **superseded by `26-chronicler.jpg`**, kept for history | — | — |
| `06-comic-style.jpg` | **The approved style of the dialogue panels** and the look of six heroes there: ink outline, hatching, bright flat colour, sound words, balloons | every talk page (ADR-0027) | `scripts/ui/comic_page.gd`, `comic_frame.gd` |
| `07-faces-captain.jpg` | The young captain, six faces | the player in every talk | `game3d/art/portraits/captain_*.jpg` |
| `08-faces-mara.jpg` | Mara, six faces | Mara's talk | `…/mara_*.jpg` |
| `09-faces-vetla.jpg` | Бабушка Ветла, six faces | the market woman who strolls the square (talk about her basket = an index fund) | `…/vetla_*.jpg` |
| `10-faces-olva.jpg` | Олва Перо, six faces | Olva's talks | `…/olva_*.jpg` |
| `11-faces-old-sailor.jpg` | The old sailor, six faces | the old sailor on the wharf | `…/oldsailor_*.jpg` |
| `12-faces-merchant.jpg` | The merchant, six faces | M. Lenoir at the bureau de change on Amber Cliff | `…/merchant_*.jpg` |
| `13-faces-chronicler.jpg` | Хронист (the Chronicler), six faces | the Chronicler's talks | `…/chronicler_*.jpg` |
| `14-faces-keeper.jpg` | Хранительница лавки, six faces | the post keeper on Silk Reach | `…/keeper_*.jpg` |
| `15-faces-sailor.jpg` | Матрос, six faces | the tall sailor on the wharf | `…/sailor_*.jpg` |
| `16-faces-second-sailor.jpg` | Второй матрос, six faces | the stocky sailor (boatswain) on Silk Reach | `…/sailor2_*.jpg` |
| `17-faces-ship-boy.jpg` | Юнга, six faces | the boy on the square | `…/child_*.jpg` |
| `18-faces-townsman.jpg` | Горожанин, six faces | the old man on the square | `…/townsman_*.jpg` |
| `19-faces-banquiere.jpg` | La banquière, six faces | Mme Sorel, Banque d'Ambre | `…/banquiere_*.jpg` |
| `20-faces-boulangere.jpg` | La boulangère, six faces | Colette, the bakery | `…/boulangere_*.jpg` |
| `21-faces-garcon.jpg` | Le garçon, six faces | Lucien, Café du Phare | `…/garcon_*.jpg` |
| `22-faces-libraire.jpg` | Le libraire, six faces | Anatole, the bookshop | `…/libraire_*.jpg` |
| `23-faces-gardienne.jpg` | La gardienne, six faces | Maëlle, the lighthouse | `…/gardienne_*.jpg` |
| `24-spark-harbour.jpg` | "Sheet 9 — Spark Harbour": the establishing view (mill on a stepped terrace, houses, market square, timber wharf, moored ship, rope bridges to islets, waterfall, crystals) | Spark Harbour; **not all built**: no rope bridges, islets or waterfall yet | `scripts/archipelago.gd` |
| `25-props.jpg` | "Sheet 10 — Props": street lamp, market stall, crate, barrel, rope coil, notice board, chest, scales, ledger, spyglass, anchor, bollard, rope railing, silk rack, five picture signboards | the props of Spark Harbour (low-poly look) | `scripts/props.gd` |
| `26-chronicler.jpg` | "Sheet 5 — The Chronicler", a **new** version: a layered slate-blue feather robe, belts, ink bottle, chained book, lantern. **Replaces `05-chronicler.jpg`** (cream cloak, blue cape) | the Chronicler in the world | `Costume._r_chronicler` |
| `27-silk-katazome.jpg` | Silk Reach, strict **katazome** (Japanese stencil-resist print): indigo `#1f2f5a` and cream `#efe6d2` only, patterns everywhere. **Secondary now**: Aika found it too harsh on the eyes | reference for the motifs (waves, diamonds) | — |
| `28-silk-katazome-loose.jpg` | Silk Reach, **the main sheet**: katazome in a looser manner — several blues (deep indigo, middle, pale), sand and ochre for rock and timber, rust for cloth and accents, cream paper, soft half-tones; patterns only on big things | the technique of Silk Reach (ADR-0029) | `shaders/ink.gdshader` (`tech == 1`), `island_style.gd` row `silk` |
| `29-amber-view.jpg` | Amber Cliff, the establishing view, in **pen and watercolour** (a French travel sketchbook) | the technique of Amber Cliff (ADR-0029); the island's shape is **not rebuilt** to it yet | `shaders/ink.gdshader` (`tech == 2`), row `amber` |
| `30-amber-houses.jpg` | Amber Cliff, the town-house kit: mansard roof, stone base, plaster front, geranium-red door, sea-teal shutters, iron balcony | colours of `AmberCliff.townhouse`; the kit's small house and outside stairs are not built | `scripts/amber_cliff.gd` |
| `31-amber-street.jpg` | Amber Cliff, the street of shops | reference; the game's street is wider and plainer | — |
| `32-amber-lighthouse.jpg` | Amber Cliff, the lighthouse with the keeper's quarters | **not rebuilt**: the game's lighthouse has amber bands and no house | — |
| `33-amber-props.jpg` | Amber Cliff, props: café table and chairs, flower stand, newspaper kiosk, bicycle, lamp, fountain, carousel, market parasol | **not rebuilt** | — |
| `34-amber-technique.jpg` | Amber Cliff, **samples of the technique** with its palette: wall, slate roof, foliage, water, sky, shade | what the watercolour shader is tuned by | `shaders/ink.gdshader` (`tech == 2`) |
| `35-shorts-view.jpg` | The short sellers' island, the establishing view: a tilted slab, leaning towers, red etherite, a pier; **noir** — ink black, paper white, one red `#c4302b` | the island and its technique (ADR-0030) | `scripts/short_isle.gd`, `shaders/ink.gdshader` (`tech == 3`), row `shorts` |
| `36-shorts-people.jpg` | Its people: the broker in a trench coat, the old man with a red armband, the pale youth, the woman with a red scarf | the four islanders; their busts are also their comic portraits (one face each, no expression sheet yet) | `Costume._r_noir_*`, `game3d/art/portraits/noir_*_neutral.jpg` |
| `37-shorts-technique.jpg` | Samples of the technique: hard light, deep shade, slanted rain, fog, the signal red, contrast | what the noir shader is tuned by | `shaders/ink.gdshader` (`tech == 3`) |
| `38-shorts-houses.jpg` | The crooked house kit: skewed plinth and walls, sagging roof, bent chimney, hanging balcony, broken stairs, red doors and windows; small, mansard and tall houses | the island's houses and towers | `ShortIsle.crooked_house` |
| `39-shorts-exchange.jpg` | The Exchange of Falling Prices: a leaning mill with broken blades outside; inside, crooked beams, a gallery and a great red board | the exchange outside; **the inside is not built** (no trading there yet) | `ShortIsle._exchange` |
| `40-shorts-props.jpg` | Props: street lamp with a red lantern, umbrella stand, card table, ticker machine, crooked signpost, lopsided scales, black ship's lantern | lamp, signpost, ship's lantern, umbrella stand and ticker are built; the card table and scales are not | `ShortIsle` |
| `41-crypto-view.jpg` | The crypto island, the establishing view: a night town of neon towers, a ground grid, a striped sun, a pier; **synthwave pixel art**. *Two real coin marks on the original are covered in this copy* | the island and its technique (ADR-0031) | `scripts/crypto_isle.gd`, `shaders/ink.gdshader` (`tech == 4`), row `crypto` |
| `42-crypto-houses.jpg` | The building kit: tower blocks, neon bands and signs, glass walls, antennas, stairs; small house, tall tower, office | the island's towers; outside stairs are not built | `CryptoIsle.tower` |
| `43-crypto-exchange.jpg` | The exchange: outside, a tower "always open" with neon blades; inside, a wall of charts, glowing gears, holograms | the exchange outside; **the inside is not built** (no trading there yet) | `CryptoIsle._exchange` |
| `44-crypto-people.jpg` | People and bots: trader, miner, dreamer, analyst; trading bot, mining bot, news bot. *A real coin mark is covered in this copy* | the islanders and the three robots; their figures are also their comic portraits (one face each) | `Costume._r_crypto_*`, `CryptoIsle.bot`, `game3d/art/portraits/crypto_*`, `bot_*` |
| `45-crypto-props.jpg` | Props: mining machine, ticker board, vending machine, wallet chest, neon palm, **the coin monument — our own wind coin**, a broken neon sign. *Real tickers on the board are covered in this copy* | palm, monument, mining machine, vending machine, ticker board (a chart, no letters) are built; the chest and the neon sign are not | `CryptoIsle` |
| `46-crypto-technique.jpg` | Samples of the technique: how pixels are drawn, dithered glow, the perspective grid, the striped sun, water, pixel shadows | what the pixel shader is tuned by | `shaders/ink.gdshader` (`tech == 4`) |
| `47-index-view.jpg` | The index island, the establishing view: a symmetrical town under a glass dome — palace bank, identical mansions, round square with a fountain, hedges, sky yachts; **a pastel toy town** | the island and its technique (ADR-0033); **the glass dome and wooden base are not built** | `scripts/index_isle.gd`, `shaders/ink.gdshader` (`tech == 5`), row `index` |
| `48-index-houses.jpg` | The mansion kit: pink walls with mint trim, arched windows, lavender or blue roofs with gold finials, balcony, picket fence, hedges | the identical mansions and hedges; the picket fences are not built | `IndexIsle.mansion` |
| `49-index-bank.jpg` | The bank palace: outside, a round palace with domes and a pastel mill; inside, a round hall with a smoothly rising chart | the palace outside (dome and columns, after sheet 47 rather than the mill of this sheet); **the inside is not built** | `IndexIsle._palace` |
| `50-index-people.jpg` | Its people: the calm rich gentleman, the elegant lady, the retired couple, the child in a sailor suit | the five islanders; their figures are also their comic portraits (one face each) | `Costume._r_toy_*`, `game3d/art/portraits/toy_*_neutral.jpg` |
| `51-index-technique.jpg` | Samples of the technique: glossy plastic and wood, tilt-shift blur, pastel light, soft shadows, gold accents, water and clouds | what the toy shader is tuned by | `shaders/ink.gdshader` (`tech == 5`) |

**Dialogue panels (sheets 06–23).** The faces on a page are these drawings, one per emotion, left to right on each
sheet: neutral, happy, surprised, sly, worried, angry. The emotion is chosen per line in `game3d/data/talks.json`.
`game3d/art/portraits/` holds the cut-outs (recut them with the boxes in `docs/demo/G3D-talk.md` if a sheet is
replaced). Lettering and the marks round a head are our own. Sheets 06–12 came later than 01–05 and differ from them
(Mara is younger with a headband, Olva wears a top hat): the 3D figures still follow 01–05 — which one wins is Aika's
call. Speakers **without** an expression sheet are drawn by a plain stand-in (`ComicDoodle`): only the five strollers
of Amber Cliff now — Yann the sailor, Rose the florist, the boy Léo, M. Hector and Inès the student.

Sheets 24 and 25 cover the establishing view and the props. Still not drawn (the brief's sheets 6–8): the houses
kit, the Wind Exchange inside and out, the ship «Попутчик»; and nothing yet for Silk Reach, Amber Cliff's town or its
five strollers. When sheets arrive, put them here with the next number, add a row above, and rebuild to match.

## How a sheet becomes a character (`game3d/scripts/costume.gd`)
- A role is one function `_r_<role>` that reads like the sheet: recolour the person's own clothes, then put garments on.
- Garments are simple shapes skinned to one bone each, all one mesh per person: `_open_coat`, `_coat_sleeves`,
  `_waistcoat`, `_sash`, `_breeches`, `_slops`, `_boots`, `_stockings`, `_long_skirt`, `_apron`, `_shawl`, hats
  (`_tricorn`, `_wide_hat`, `_bandana`, `_knit_cap`, `_beret`, `_kerchief`, `_headscarf`), accessories (`_pouch`,
  `_spyglass`, `_medallion`, `_chart`, `_satchel`, `_buckles`).
- People are built whole in code on a small skeleton (`Costume.stand_in`), faceted and faceless; the same role
  function also dresses a MakeHuman person in the `--pbr` look. The Chronicler is an owl with no human under the feathers.
- Check your work against the sheet: `godot --path game3d --resolution 1600x900 -- --people=<dir>` makes the line-up.

## Rules
- Keep to the sheet's silhouette first (hat, coat length, sash, boots), colours second, small detail last.
- Colours come from the palette row on the sheets; no new hues without a reason written in `DECISIONS.md`.
- No user-visible words on clothes or signs (pictograms only), no modern garments, no logos.
- Do not copy characters, ships or towns from existing games, films or books. The sheets are ours; inspiration from the
  age of sail and from old illustrated travel journals is fine.
- A design change that the sheets do not cover is a question for Aika, not a guess.

## The brief the sheets were drawn from
World: people lifted islands into the sky on glowing crystals of etherite and live above a sea of clouds; ships carry
an etherite crystal in a brass cage under the keel and sails of wind silk; Spark Harbour is a small trading town round
the Wind Exchange, a windmill with a glowing price board; age of sail, cosy and a little shabby, never grim.
Style: pen-and-ink line with cross-hatching over flat watercolour, like an antique illustrated travel journal; chunky
readable silhouettes, slightly exaggerated proportions, everything patched and lived-in.
Sheet rules: one sheet per image, 16:9, off-white paper, neutral pose, orthographic front / side / back, hand-written
labels, palette swatches with hex codes. The full prompt (ten sheets) is in `docs/design/concept-prompt.md`.

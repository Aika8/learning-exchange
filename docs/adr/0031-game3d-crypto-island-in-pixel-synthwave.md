# 0031. The crypto island: a neon town drawn as synthwave pixel art; a place and a style, no mechanics yet

- Status: Proposed
- Date: 2026-11-17
- Pattern(s): Strategy chosen by data (a fifth technique, ADR-0026/0029), Builder (`CryptoIsle`)

## Context
The second "method island" of intent 03 that Aika has drawn is the island of **crypto**: six sheets
(`docs/design/concepts/41…46`) — a night town of neon towers on a rock with glowing crystals, a pier, people in
bright jackets and three kinds of robots ("they have bots"), an exchange that never closes with a wall of charts.
The technique is **pixel art in a synthwave palette**: big pixels (about 320×180), about twelve colours (night
`#1b1035`, violets, magenta, neon pink, sunset orange, gold, neon cyan, teal), a striped setting sun, a glowing
perspective grid on the ground, glow made by dithering.

Limits set from outside:
- **No crypto mechanics.** They wait for Aika's answers to intent 03 (question 10). A place and a style for now.
- **No real brands.** The sheets show ₿, the Ethereum mark and the tickers BTC and ETH. CLAUDE.md forbids real
  brand looks. The game has its own invented coin with a wind sign (the "coin monument" on the props sheet).
- **Eyes** (the lesson of katazome and noir): no blinking neon, glow only round a few sources, pixels that do not
  swarm when the camera moves.

Forces:
- Pixelating a moving 3D picture in screen space makes edges jump from cell to cell; that cannot be removed.
- The effect can hold only a few colours per island as data (four `ramp` slots), and this technique wants twelve.
- Every technique must redraw the captain (ADR-0029).

## Decision
1. **A fifth technique, `pixel`** (technique 4), row `crypto` in `IslandStyle`. *(Revised while still Proposed.
   The first version cut the whole screen into big pixels, 180 rows high, with ordered dithering between tones.
   Aika: "too pixelated, hard to look at, it swarms in the eyes". Screen-space pixels step and crawl whenever the
   camera moves; that cannot be tuned away, so the pixels left the screen.)*
   - **texels that belong to the world**: the edges of things are drawn at full sharpness; what is chunky is the
     paint on surfaces — squares 14 cm wide, found by snapping each pixel's place in the world to a grid on the
     plane its surface faces and reading the picture at that square's centre. They stay on the wall when the
     camera walks or turns. On the hero they are measured from the hero;
   - **twelve colours in flat tones**: five steps by brightness, cool or warm, with hard edges and **no
     dithering**. Anything bright and saturated is a neon — pink, orange, gold or cyan — judged at the pixel
     itself, so neon has clean edges;
   - the **sky** in cells of direction (a quarter of a degree; they turn with the world, not with the screen):
     bands from night to magenta, a few stars, the **striped sun**;
   - the **grid**: lines every two metres on the ground in world space, at least a pixel wide, fading out
     smoothly before they crowd;
   - **glow**: a small checkerboard halo round neon only — the one place with dithering; its squares are world
     texels too;
   - a thin dark outline as on the other islands; **nothing is animated**. V gives the plain version: no grid,
     no halo, no outline.
   The twelve colours are constants of the technique in the shader. That bends "the look is a row of data"; a
   palette is the technique.
2. **The island `crypto`** («Остров крипты», working name), built by `CryptoIsle`, reached by a third packet-boat
   post: a pier, a street of block towers with neon bands, glass walls and antennas, neon palms, and at its end the
   **Exchange That Never Closes**, a tower with four neon blades. Its door is a talk, not a trading hall.
3. **Islanders and bots** after sheet 44: the trader, the miner, the dreamer, the analyst (four costume roles from
   existing garments) and three robots built in code — the trading bot, the mining bot, the news bot. In comic
   pages each is shown by its figure from the sheet (one face each). They explain round-the-clock trading, high
   volatility and leverage, mining and a fixed supply, the fear of missing out, why a coin has no report to value
   it by, the network fee. Nobody recommends anything; nothing can be traded.
4. **Our own coin.** «Монета ветра» / the wind coin: a gold coin with a wind curl, as on the props sheet. No ₿, no
   other real mark, no real ticker anywhere in the game. In the repository's copies of the sheets the real marks
   are covered (sheets 41, 44, 45); the README says so.
5. **The captain is redrawn in pixels on landing** by the same wind and wave; the contract test covers it.
6. **Eyes, by numbers** in `docs/demo/G3D-crypto.md`: change between frames with a standing camera (must be only
   the people), with a walking camera, and the share of the screen that is neon.

## Why this and not the alternatives
| Alternative | Why not (now) |
|---|---|
| Render the whole game at 320×180 for this island | The HUD and comic pages would be pixelated too; switching the render size on arrival is a bigger change |
| Big pixels over the whole screen (320×180, the first version; or 640×360) | They step and crawl with every camera move at any size; tried, and it hurt |
| Pixelated textures on the meshes | The meshes have no textures or UVs; the effect can do the same from depth |
| Bloom for the glow | Not pixel art; a soft blur over hard pixels; costs a pass |
| Animated neon (flicker, scrolling grid) | The sheets' "broken neon" is charming and exactly what tires the eyes |
| Palette as twelve uniforms from the table | Twelve more uniforms twice over (the captain's column) for one island |
| Keep the real coin marks "as a parody" | CLAUDE.md is plain: no real brand look |

## Pros
- A fifth island needed a branch, a row and a builder; the contract test did the rest.
- The pixel portraits from the sheet fit the comic pages as they are.

## Risks and costs
- A texel whose centre is hidden behind something keeps its own pixel's colour: a thin seam at some edges.
- With clean edges and flat tones the look is closer to a neon poster than to strict pixel art. Aika judges it.
- Night: most of the screen is dark violet. It is not black, and neon is rare by construction; still, a long stay
  may tire. One number (the ramp's floor) lifts it.
- The islanders' costumes are approximations in the old garments (no puffer jacket, no gas mask).
- The island's name and its place in the world bible are open (the Outskirts of Storms fit "unregulated").

## How to explain it (teaching note)
A post-effect is a function from one picture to another, and "pixel art" is two small functions composed: sample
coarsely, then choose from a short list. The order matters — choose first and the average of two colours is a
third that is not on the list.

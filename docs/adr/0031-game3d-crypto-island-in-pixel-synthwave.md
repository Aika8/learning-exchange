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
- Pixelating a moving 3D picture in screen space makes edges jump from cell to cell; that cannot be removed, only
  kept calm.
- The effect can hold only a few colours per island as data (four `ramp` slots), and this technique wants twelve.
- Every technique must redraw the captain (ADR-0029).

## Decision
1. **A fifth technique, `pixel`** (technique 4), row `crypto` in `IslandStyle`:
   - the picture is cut into **big pixels**, 180 rows high whatever the window; each takes the average of four
     samples of its cell, not one (a single sample sparkles when the camera moves);
   - **twelve colours**. Bodies are sorted by brightness into a five-step ramp — cool (night, deep violet, violet,
     lavender, pale) or warm (night, plum, magenta, lavender, pale) — with **ordered dithering** between
     neighbouring steps, on a pattern fixed to the big pixels. Anything bright *and* saturated is a **neon**: pink,
     orange, gold or cyan, whichever is nearest;
   - the **sky** is drawn by the effect from the direction of each pixel: bands from night down to magenta at the
     horizon, a few fixed stars, and a **striped sun** low in the east, gold to pink, with gaps that widen downward;
   - the **grid**: glowing lines every two metres on ground that faces up, laid out in world space, cyan near and
     magenta far, faded out before a cell is smaller than a few big pixels;
   - **glow by dithering**: a checkerboard halo two big pixels wide round neon things only;
   - **nothing is animated by the effect**: no flicker, no pulsing. V gives the plain version: no dithering, no
     grid, no halo.
   The twelve colours are constants of the technique in the shader (the row gives the four the other code needs:
   the night, the line, the wind's accent). That bends "the look is a row of data"; a palette is the technique.
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
| One sample per big pixel | Cheapest, and sparkles on every thin edge when the camera moves |
| Bloom for the glow | Not pixel art; a soft blur over hard pixels; costs a pass |
| Animated neon (flicker, scrolling grid) | The sheets' "broken neon" is charming and exactly what tires the eyes |
| Palette as twelve uniforms from the table | Twelve more uniforms twice over (the captain's column) for one island |
| Keep the real coin marks "as a parody" | CLAUDE.md is plain: no real brand look |

## Pros
- A fifth island needed a branch, a row and a builder; the contract test did the rest.
- The pixel portraits from the sheet fit the comic pages as they are.

## Risks and costs
- Edges of big pixels still step as the camera moves. We measure it and Aika judges it.
- Night: most of the screen is dark violet. It is not black, and neon is rare by construction; still, a long stay
  may tire. One number (the ramp's floor) lifts it.
- Dithered surfaces crawl a little when their brightness changes under a moving camera.
- The islanders' costumes are approximations in the old garments (no puffer jacket, no gas mask).
- The island's name and its place in the world bible are open (the Outskirts of Storms fit "unregulated").

## How to explain it (teaching note)
A post-effect is a function from one picture to another, and "pixel art" is two small functions composed: sample
coarsely, then choose from a short list. The order matters — choose first and the average of two colours is a
third that is not on the list.

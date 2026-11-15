# game3d — style guide (ADR-0017)

**One sentence:** a cosy late-afternoon sky archipelago — soft low-poly islands floating over a sea of clouds,
warm sun, cool shadows, brass and canvas, and a glowing order-book board in a windmill hall.

## Palette
| Role | Hex | Where |
|---|---|---|
| Sky top | `#3d6ea8` | zenith |
| Sky horizon | `#f2c58a` | warm haze band |
| Cloud sea | `#f4ece4` → shadow `#a9b4cf` | the floor of the world |
| Grass top | `#7fb069` | island caps |
| Grass shadow band | `#4f7f52` | toon second band |
| Cliff rock | `#b07a57` / dark `#6e4a3b` | island undersides |
| Ether crystal | `#7fe3ff` emissive | glowing roots of islands (lore: эфирит) |
| Timber | `#8a5a3c` | hulls, piers |
| Sail canvas | `#f3e9d2` | sails, awnings |
| Brass | `#d9a441` | trims, UI accents (shared with 2D `UI.BRASS`) |
| Bid / ask | `#5fb98a` / `#e0705f` | board, same as 2D client |
| UI panel | `#1b2232` at 85 % | HUD panels |

## Light
- Sun: low warm directional light (≈ 35° elevation, `#ffe1b0`, energy 1.3) with soft shadows.
- Sky: `ProceduralSkyMaterial`, ambient from sky at 0.6, ACES tonemap, exposure ≈ 1.
- Fog: depth fog tinted to the horizon colour + light volumetric fog so sun shafts show between islands.
- Glow on emissive (crystals, board digits, lanterns), SSAO for contact shadows.
- Hall interior: dim warm lanterns, the board is the brightest thing in the room.

## Shapes
- Islands: inverted cones of jittered rings — a flat grassy top, a long craggy underside ending in ether crystals.
- Flat shading (per-face normals) everywhere; no textures; 2-band toon shader on terrain.
- Buildings: boxes and prisms with pitched roofs; the Exchange is a round-towered windmill with four canvas blades.
- The ship «Попутчик»: a short hull, one mast, a big square sail, a small brass lantern.

## References in words (not copies)
- Paper-model dioramas and wooden toy boats: chunky, readable silhouettes.
- Late-afternoon plein-air painting: warm light, blue shadows, hazy distance.
- Old harbour trading boards with brass frames and flip numbers — our board glows instead of flipping.
- Explicitly **not**: any existing sky-pirate or island game's look, ships, maps, logos or UI.

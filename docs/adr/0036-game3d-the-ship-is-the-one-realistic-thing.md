# 0036. The ship «Попутчик» is the one realistic thing: PBR, drawn after the island's technique, never redrawn; and she carries a monkey

- Status: Proposed
- Date: 2026-11-18
- Pattern(s): Builder (`Wayfarer`), an exception by draw order (not by a mask), pure model + thin node (`MonkeyMind` / `Monkey`)

## Context
Every island is drawn in its own technique by one post-effect (ADR-0024…0035), and the captain is redrawn on
landing. Aika wants one thing to stay itself everywhere: **the hero's ship**. She is to look *real* — physically
based materials, every small detail — among the drawn islands, and no island's technique may redraw her. Aika has
drawn her (six sheets, `docs/design/concepts/67…72`): a two-masted pirate ship with square sails on the foremast
and a gaff sail on the main, jibs, a carved stern with a gallery, two stern lanterns and the wind spirit's face, a
bird figurehead, bat-like **wing sails** low on the sides that drip cloud moisture, an etherite crystal in a brass
cage under the keel, gun ports, a wheel, an anchor, barrels; a ragged black flag; and a small tame **monkey** in a
red waistcoat with an earring.

Limits from outside:
- **No borrowed characters or symbols.** The flag is ours: a compass rose over crossed bones, no skull. The
  monkey is ours by Aika's sheet — her own looks, clothes and habits; not the monkey of any film.
- **Sources**: code, or CC0 from the allowed three (Poly Haven, ambientCG, Quaternius). Nothing new without Aika's yes.
- **60 fps** in flight, where the ship fills the screen, and in every port.
- The effect is one full-screen pass over the finished picture; it has no idea what a ship is.

Forces:
- "Do not redraw this object" needs the effect to know where the object is — or the object must not be in the
  picture the effect reads.
- A detailed ship is thousands of small parts; a draw call each would cost more than the triangles.
- The Poly Haven model used under `--pbr` (ADR-0019) is a different ship from the one on the sheets.

## Decision
1. **The exception is made by draw order, not by a mask.** The effect is a quad in the transparent pass with
   render priority 100, reading the screen and depth as they were after the opaque pass. Every material of the
   ship is put in the **transparent pass with a higher priority (101–104), fully opaque, writing and testing
   depth**. So the ship is not in the picture the effect reads — the island behind her is drawn in its technique —
   and then she is drawn over it, hidden correctly by whatever stands in front. No uniform, no mask, no branch in
   the shader; any technique added later leaves her alone for free. A test checks every surface of the ship for
   this.
   What it costs: she takes no part in what the effect does on purpose — no ink line round her, no fog of noir,
   no haze of the oil island. That is the brief ("real among the drawn").
2. **Built in code by `Wayfarer`**, after the sheets, from the same `Kit` that builds houses: a handful of meshes,
   one surface per material. Materials are physically based: Poly Haven wood, plank and cloth textures when they
   are downloaded (`make assets`; CC0, an allowed source), laid out in the ship's own space so they travel with
   her; plain PBR colours with the right roughness and metal when they are not. The model `dutch_ship_medium` and
   the old stand-in hull are no longer used for the hero's ship.
3. **What is on her** (each is checked by name in a test): hull with wales, bulwarks and gun ports with lids;
   forecastle and quarterdeck; two masts with tops; yards, a gaff and a boom; two square sails that billow and are
   furled by the sail trim, a gaff sail, a staysail, two jibs; shrouds with ratlines and deadeyes, stays and
   backstays; bowsprit; the bird figurehead; the carved stern with gallery windows, the wind spirit's face, the
   name «ПОПУТЧИК», two stern lanterns that are lit; wheel, capstan, grating, four guns, barrels, a rope coil, an
   anchor; the etherite crystal in its brass cage under the keel, glowing.
4. **The flag** is a shader, not a picture: black cloth that waves, a ragged fly, and our sign drawn from
   distances — an eight-pointed compass rose in a ring over two crossed bones. No skull; nobody else's emblem.
5. **Wing sails** low on both sides, ribbed like a bat's wing, of wet canvas; small drops fall from their trailing
   edges (particles: a few dozen a side, no collision).
6. **Budget**: at most **60 000 triangles** for the whole ship at full detail and at most **24 materials**
   (wood, planks, dark timber, gilt, iron, paint, rope, lit glass, etherite — most of them twice, for boxes and
   for flat panels — and the cloth, sail and flag shaders); textures only the 1k sets already in the project. The rigging — the largest count of small parts — is one mesh that is hidden beyond
   150 m; the other meshes carry generated LODs. The test counts triangles and materials. Frame rate is measured
   in flight and in port.
7. **The monkey** is a character of the world, not a part of the ship: she is drawn in each island's technique
   like the captain and the islanders. Under way she lives in the rig — sits on a yard, runs along it, climbs to
   the top. In port she comes ashore and keeps near the captain, sitting down when he stands. Her decisions are a
   pure model (`MonkeyMind`), her body a small figure built in code after sheet 72. She has no part in any
   mechanic and nothing can be done with her yet.

## Why this and not the alternatives
| Alternative | Why not (now) |
|---|---|
| A mask: the ship writes an id (stencil, or a flag in roughness) and every technique skips those pixels | Every technique, present and future, must remember the branch; lines and blurs near her edge still bleed in |
| A world-space box round the ship that the effect leaves alone | Whatever else is inside the box — the pier, the captain — is left alone too |
| A second viewport for the ship, composited on top | A second render of the scene's depth to hide her correctly; twice the cost of the thing we are trying to keep cheap |
| Keep the Poly Haven model | It is not the ship on the sheets, and it exists only where assets are downloaded |
| Model her in Blender | No hand-modelling here; the sheets are followed part by part in code, and every part can be named and tested |
| A classic skull and crossbones | Not ours |
| The monkey realistic like the ship | Then she could not walk the islands with the captain as one of their people; one exception is the point |

## Pros
- One rule, enforced by a test, and no technique has to know about it.
- The ship is the same on every machine: textures improve her, nothing depends on them.

## Risks and costs
- Transparent-pass objects are sorted by object, not by pixel. With depth written this is right for opaque
  surfaces; anything truly see-through on the ship (there is none: glass is emissive, not clear) would not be.
- No screen-space effects on her (ambient occlusion, reflections): she is lit by the sun, the sky and her lanterns only.
- A realistic ship beside a flat world may look pasted on. It is the request; the judge is Aika's eye.
- Built from boxes, cylinders and lofted strips, the carving is suggested, not sculpted.
- The monkey ashore steers straight for the captain and does not know walls.

## How to explain it (teaching note)
There are two ways to make an exception to a rule that runs over everything: teach the rule about the exception,
or keep the exception out of the rule's sight. The second needs no `if` anywhere — it uses an order that was
already there. It is the Open–Closed Principle in a renderer: new techniques are added without touching the ship,
and the ship without touching them.

## Amendment, 2026-11-18: the hull is Poly Haven's pinnace
Aika looked at the ship built in code and at the CC0 models there are, and chose: **"yes, the pinnace"** —
Poly Haven's `ship_pinnace` (CC0; already in `make assets`, an allowed source). Decisions 2, 3 and 6 change; the
rest stands, and above all decision 1: the exception by draw order.

- **2′. The ship is the pinnace when it is downloaded**, scaled to twelve metres (×0.36), turned bow to −z, her
  waist deck at y = 0 — so the berths, the flight model and the chart are untouched. Every material of the model
  is copied into the pass after the island's technique (the same rule, the same test); what is inside the hull is
  not drawn. **Where the model is not downloaded the ship built in code stands in**, whole, as before: the game
  and its tests work on any machine.
- **3′. Added to the model after the sheets**: the wing sails with their drops, the etherite crystal in its cage
  under the keel, our flag at the main mast's head, the bird under the bowsprit, two lanterns that give light and
  the wind spirit's face on her own carved stern, the name «ПОПУТЧИК». The model's sails keep their texture and
  cut-out shape and **ripple** a little (a shader). They are not furled by the sail trim: they are part of the
  model. She has three masts; the sheets show two.
- **6′. Budget.** The model is 162 000 triangles in full (the rigging alone two fifths). The budget of 60 000 is
  now for **what is drawn from where she is flown and seen in port**; close to she is all there. Three things
  keep it: the LODs the import generates, taken early (`lod_bias` 0.15); the rigging not drawn beyond 150 m and
  casting no shadow; the interior not drawn. Measured from the helmsman's camera: about 30 000 triangles in the
  view, about 74 000 with her shadows in all four cascades; 120 frames a second. The ship built in code keeps
  her own limit of 60 000 in full.
- **7′. The monkey** is still ours and built in code, now nearer her sheet: a dark cap of fur over a pale face,
  a muzzle and brows, a waistcoat in two fronts with a brass edge and buttons, a ring in her ear, a long tail of
  nine pieces that curls up; and four poses — sitting, sitting with the spyglass to her eye, climbing hand over
  hand, running on all fours. No ready CC0 capuchin exists on the allowed sources.

| Alternative | Why not |
|---|---|
| Decimate the model once in Blender and keep a lighter copy in the repository | A second copy of a downloaded asset to keep in step; the importer's LODs do it per distance for nothing |
| Keep the built ship | Aika prefers the model's hull, carving and rigging; the built one stays as the stand-in |
| Remove the third mast to match the sheets | The masts, rigging and sails are single meshes: cutting one out is modelling work outside the engine |


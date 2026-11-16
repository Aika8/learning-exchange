# G3D polish — the world holds, the houses are houses, people walk

Aika played the 3D client and found small things that break the world: the captain fell through the floor, walked
through walls, the houses were boxes and the walk was a bob. This pass: an automatic **audit** that walks the whole
world and lists every such problem with a picture, then the fixes, then the same audit again.

**Result: 451 problems before → 0 after**, on 1270 grid points and 8384 walks (before: 1204 points, 8000 walks).
GUT: 59 → 74 tests, all green. No contract change, the 2D game is untouched, the M3 game flow is untouched.

## 1. The audit

`scripts/world_probe.gd` (`WorldProbe`) + `scripts/audit.gd`. Run it yourself:
```
godot --path game3d --resolution 1600x900 -- --audit=/tmp/audit     # audit.json + a picture per problem
godot --path game3d --resolution 1600x900 -- --views=/tmp/views     # the fixed views used below
godot --path game3d --resolution 1600x900 -- --gait=/tmp/gait       # idle, walk, run, a doorstep, camera at a wall
godot --path game3d --resolution 1920x1080 -- --fps=/tmp/fps.json   # frame rate, also right after a camera jump
```
How it looks for problems:
- **The walk.** A grid of points 2 m apart over every place people can stand (both islands, the wharf and the piers, the
  hall). At each free point a probe body — the same capsule and the same `Mover` as the captain — walks 0.75 s in 8
  directions. It reports: no floor under the point (`hole`), ending 1.5 m lower (`fall`), passing through a collider
  (`tunnel`), not being able to move at all (`stuck`).
- **Spawns and spots.** Every spawn point must have ground and room for the capsule; every interaction spot must have
  a free place to stand within its radius.
- **Objects.** Every top-level thing on the walkable ground: rays at knee and chest height, three per side, are cast
  twice — at the triangles you see (a copy of the mesh on its own physics layer) and at the colliders. Where the eye
  sees a surface there must be a collider within 0.45 m behind it (else you walk into the thing) and 0.8 m in front
  (else it is an invisible wall): `no-collision`, `loose-collider`. Lowest point hanging over the ground: `floating`.
  A part touching nothing: `gap`.
- **Z-fighting.** Flat boxes whose tops lie in one plane and overlap.
- **LODs.** Meshes over 4000 triangles without LODs.

Plants (fern, grass, shrub, roots) are walk-through by design and are not reported.

Honest note on the two runs: the "before" run used the first version of the probe (collider compared with the bounding
box) and a 0.45 m capsule; the "after" run uses the stricter final probe (collider compared with the real triangles)
and the 0.4 m capsule. The stricter check only adds findings, so the old world is not flattered.

## 2. What it found, and what was done

| Problem | Meaning | Spark Harbour before → after | Silk Reach before → after | Exchange hall before → after |
|---|---|---|---|---|
| `hole` | no floor under a walkable point | 22 → 0 | 14 → 0 | 120 → 0 |
| `fall` | a walk from a grid point ended more than 1.5 m below the ground | 92 → 0 | 87 → 0 | 0 → 0 |
| `spawn` | a spawn point without ground or inside a collider | 1 → 0 | 0 → 0 | 0 → 0 |
| `spot` | an interaction spot with nowhere to stand | 3 → 0 | 1 → 0 | 0 → 0 |
| `no-collision` | a solid-looking object you walk through | 33 → 0 | 22 → 0 | 0 → 0 |
| `loose-collider` | a collider that does not follow the shape | 2 → 0 | 1 → 0 | 0 → 0 |
| `floating` | a prop hanging in the air | 2 → 0 | 0 → 0 | 0 → 0 |
| `z-fight` | two flat surfaces in the same plane (flicker) | 17 → 0 | 5 → 0 | 24 → 0 |
| `no-lod` | a heavy mesh without LODs | 2 → 0 | 3 → 0 | 0 → 0 |
| **all** | | **174 → 0** | **133 → 0** | **144 → 0** |
| grid points / walks / objects checked | | 686 / 4928 / 76 → 746 / 4776 / 90 | 398 / 3072 / 29 → 404 / 2776 / 30 | 120 / 0 / 0 → 120 / 832 / 52 |

Full lists: `docs/demo/g3d-polish/before/audit.json`, `docs/demo/g3d-polish/after/audit.json`.

### Every problem found (before), with a picture
The red cone marks the place. `n` = how many findings fold into this one (same kind, same object or same 6 m cell).

**Spark Harbour**

| Problem | n | Where | Picture | Fix |
|---|---|---|---|---|
| `fall` | 92 | harbour at (-33.7, -0.1, -10.7) | [picture](g3d-polish/before/harbour-fall-1.jpg) | No edge on the island: 92 walks from the rim ended in the clouds (and the fall teleported you to (0, 2, 0) — on Silk Reach that is the *other* island). Now an invisible fence runs round the outline of the cap and the decks; the respawn is the island's own spawn point. |
| `hole` | 22 | pier at (28.8, 0.1, 2.6) | [picture](g3d-polish/before/harbour-hole-1.jpg) | The pier was 9 planks without a collider, and it began 2.5 m past the cliff edge. Now one timber deck (wharf + pier) with a collider, piles, braces and rope rails, starting on the island. |
| `z-fight` | 17 | unnamed / unnamed at (1.5, 0.1, -7.5) | [picture](g3d-polish/before/harbour-z-fight-1.jpg) | The road was 12 overlapping slabs with their tops in one plane. Now one ribbon mesh. |
| `no-collision` | 12 | unnamed at (0.0, 0.0, -15.0) | [picture](g3d-polish/before/harbour-no-collision-1.jpg) | The windmill (the Exchange!), the terrace, stalls, lamps, barrels, crates, rocks, trees, the notice board and every person had no collider. Now each has one that follows its shape (`Solid`). |
| `no-collision` | 4 | street_lamp_02 at (4.6, 0.0, -5.8) | [picture](g3d-polish/before/harbour-no-collision-2.jpg) | same as above |
| `no-collision` | 3 | wine_barrel_01 at (-6.0, 0.0, 7.5) | [picture](g3d-polish/before/harbour-no-collision-3.jpg) | same as above |
| `no-lod` | 2 | unnamed (6120 tris) at (-0.1, -21.2, -1.3) | [picture](g3d-polish/before/harbour-no-lod-1.jpg) | The dense island mesh had no LODs. Now generated. |
| `floating` | 2 | unnamed at (15.0, 0.9, -5.4) | [picture](g3d-polish/before/harbour-floating-1.jpg) | The notice board hung over its legs as separate objects; now one object standing on two legs. |
| `no-collision` | 2 | boulder_01 at (-13.0, 0.0, 21.4) | — | same as above |
| `no-collision` | 2 | rock_moss_set_01 at (14.1, 0.0, -20.6) | — | same as above |
| `no-collision` | 2 | child at (-9.0, 0.0, 8.0) | — | same as above |
| `no-collision` | 2 | oldman at (8.9, 0.0, 4.0) | — | same as above |
| `loose-collider` | 2 | unnamed at (-14.0, 0.0, -2.0) | [picture](g3d-polish/before/harbour-loose-collider-1.jpg) | A house was a 2.2 m cylinder inside a 4.6 m box: corners were walk-through. Now a box for the walls, a box for the plinth, boxes for the steps. |
| `no-collision` | 1 | treasure_chest at (2.6, 0.0, -7.5) | — | same as above |
| `no-collision` | 1 | Mara at (29.9, 0.0, 8.0) | — | same as above |
| `no-collision` | 1 | Olva at (10.0, 0.0, 9.0) | — | same as above |
| `no-collision` | 1 | Chronicler at (-7.0, 0.0, -4.0) | — | same as above |
| `no-collision` | 1 | sailor at (-2.0, 0.0, 1.9) | — | same as above |
| `no-collision` | 1 | island_tree_02_1k at (12.6, 0.0, -20.2) | — | same as above |
| `spawn` | 1 | spawn pier: no ground at (42.0, 0.5, 4.0) | [picture](g3d-polish/before/harbour-spawn-1.jpg) | The "pier" spawn was over the void. It is on the deck now. |
| `spot` | 1 | spot ship: nowhere to stand at (48.0, 0.0, 4.0) | [picture](g3d-polish/before/harbour-spot-1.jpg) | Grandfather's chest, the provisions and the ship's gangway were over the void, 10 m past the cliff. They stand on the wharf now. |
| `spot` | 1 | spot debt: nowhere to stand at (38.0, 0.0, -1.5) | [picture](g3d-polish/before/harbour-spot-2.jpg) | same as above |
| `spot` | 1 | spot provisions: nowhere to stand at (37.0, 0.0, 10.0) | [picture](g3d-polish/before/harbour-spot-3.jpg) | same as above |

**Silk Reach**

| Problem | n | Where | Picture | Fix |
|---|---|---|---|---|
| `fall` | 87 | silk at (304.7, -6.1, -253.9) | [picture](g3d-polish/before/silk-fall-1.jpg) | Same: no edge. Fenced. |
| `no-collision` | 19 | unnamed at (322.0, -6.0, -270.0) | [picture](g3d-polish/before/silk-no-collision-1.jpg) | Twelve silk racks, three houses, crates, trees and people without colliders. All solid now. |
| `hole` | 14 | silk-pier at (293.8, -5.9, -247.4) | [picture](g3d-polish/before/silk-hole-1.jpg) | The pier had no collider. One deck with a collider now. |
| `z-fight` | 5 | unnamed / unnamed at (304.9, -5.9, -246.0) | [picture](g3d-polish/before/silk-z-fight-1.jpg) | Overlapping pier planks in one plane. One deck now. |
| `no-lod` | 3 | unnamed (6120 tris) at (330.3, -22.7, -258.6) | [picture](g3d-polish/before/silk-no-lod-1.jpg) | Island meshes without LODs. Generated. |
| `loose-collider` | 1 | unnamed at (335.0, -5.6, -270.0) | [picture](g3d-polish/before/silk-loose-collider-1.jpg) | A house on the hill with the wrong collider. Houses now have a foundation that goes into the slope, and box colliders. |
| `no-collision` | 1 | island_tree_02_1k at (322.7, -6.0, -242.3) | [picture](g3d-polish/before/silk-no-collision-2.jpg) | same as above |
| `no-collision` | 1 | PostKeeper at (318.0, -6.0, -253.5) | [picture](g3d-polish/before/silk-no-collision-3.jpg) | same as above |
| `no-collision` | 1 | child at (337.0, -6.0, -257.6) | — | same as above |
| `spot` | 1 | spot ship: nowhere to stand at (296.0, -6.0, -246.0) | [picture](g3d-polish/before/silk-spot-1.jpg) | The ship's spot was off the deck. On the deck now. |

**Exchange hall**

| Problem | n | Where | Picture | Fix |
|---|---|---|---|---|
| `hole` | 120 | hall at (-11.0, 0.0, -5.0) | [picture](g3d-polish/before/hall-hole-1.jpg) | The hall had no floor collider at all (the camera orbits, nobody walked). Floor, wall, pillars, desks, the board and the props are solid now. |
| `z-fight` | 24 | unnamed / unnamed at (0.1, 15.9, 0.2) | [picture](g3d-polish/before/hall-z-fight-1.jpg) | Twelve ceiling beams crossed at the centre in one plane. They now end at a boss under the gear. |

A few of them:

| Hole: the pier has no floor and starts in the air | A spot nobody can reach: the chest hangs past the cliff |
|---|---|
| ![](g3d-polish/before/harbour-hole-1.jpg) | ![](g3d-polish/before/harbour-spot-2.jpg) |
| The Exchange itself is walk-through | Silk racks and houses without colliders |
| ![](g3d-polish/before/harbour-no-collision-1.jpg) | ![](g3d-polish/before/silk-no-collision-1.jpg) |

## 3. Before / after

Same camera, same place (`--views`).

| Before | After |
|---|---|
| The square ![](g3d-polish/before/view-square.jpg) | ![](g3d-polish/after/view-square.jpg) |
| Houses ![](g3d-polish/before/view-houses.jpg) | ![](g3d-polish/after/view-houses.jpg) |
| A house up close ![](g3d-polish/before/view-house-close.jpg) | ![](g3d-polish/after/view-house-close.jpg) |
| The wharf ![](g3d-polish/before/view-wharf.jpg) | ![](g3d-polish/after/view-wharf.jpg) |
| The pier ![](g3d-polish/before/view-pier.jpg) | ![](g3d-polish/after/view-pier.jpg) |
| The Exchange ![](g3d-polish/before/view-exchange.jpg) | ![](g3d-polish/after/view-exchange.jpg) |
| From above ![](g3d-polish/before/view-top.jpg) | ![](g3d-polish/after/view-top.jpg) |
| Silk Reach ![](g3d-polish/before/view-silk.jpg) | ![](g3d-polish/after/view-silk.jpg) |
| Silk Reach houses ![](g3d-polish/before/view-silk-houses.jpg) | ![](g3d-polish/after/view-silk-houses.jpg) |
| Silk Reach pier ![](g3d-polish/before/view-silk-pier.jpg) | ![](g3d-polish/after/view-silk-pier.jpg) |
| The hall ![](g3d-polish/before/view-hall.jpg) | ![](g3d-polish/after/view-hall.jpg) |
| The hall from the side ![](g3d-polish/before/view-hall-side.jpg) | ![](g3d-polish/after/view-hall-side.jpg) |
| The hall, looking up ![](g3d-polish/before/view-hall-up.jpg) | ![](g3d-polish/after/view-hall-up.jpg) |

(The "before" wharf camera stands inside a later house; the old picture shows what was there: a pier in the air.)
The hall "after" camera stands lower than the "before" one: the old spot is now on the gallery, behind the balustrade.

### Buildings (`scripts/houses.gd`, `scripts/kit.gd`, `scripts/decals.gd`)
A house is built from modules: stone plinth with a foundation that goes into a slope, plastered walls in a timber
frame (corner posts, sills, studs, gable braces), windows with frames, mullions, sills and shutters, a plank door with
stone steps, a tiled gable roof with eaves and verges, a chimney, a bracket lantern by the door, some with a hanging
sign, grime decals at the foot of the walls and trodden earth around. One or two storeys, sizes, shutter and roof
colours vary. `Kit` merges all the parts into one mesh with a surface per material and LODs, so a house of ~150 parts is
a handful of draw calls. Materials are the Poly Haven PBR sets already in `assets.lock`; the decal textures are painted
in code. Nothing new is downloaded.

The windmill got a round 32-sided tower, timber bands, a gallery, framed windows with shutters, a stone porch with a
double door and blades with a lattice. The street lamp model turned out to be a *wall* lantern lying on the ground; it
now hangs on a timber post and by house doors.

The hall: panelled wall with a rail, pillars with bases and capitals, a gallery with a balustrade on brackets, guild
banners (bid green, ask red, brass), the brokers' rostrum (two steps, brass rail) with a carpet from the door, framed
windows, the door, the gear with spokes on a shaft, lanterns on chains.

### Collisions (`scripts/solid.gd`)
- Walls and plinths are boxes, the mill is two tapering convex solids, posts are cylinders, people are capsules.
- A downloaded model gets a convex hull per mesh, with its position, turn and scale baked into the points (bodies are
  never scaled). Trees get prisms over 0.6 m bands of the trunk, not a hull of the crown.
- The islands, the wharf and the piers are fenced by invisible walls along the outline of the walkable ground
  (`Archipelago.walk_areas`); the decks also have visible rope rails.
- The camera sits on a spring arm with a ball shape: a wall pushes it in, it does not look through.

| The camera with a wall behind it (arm 1.4 m of 9) | The captain on a doorstep |
|---|---|
| ![](g3d-polish/after/camera-at-wall.jpg) | ![](g3d-polish/after/gait-steps.jpg) |

### Walking (`scripts/mover.gd`, `scripts/walker.gd`, `scripts/captain.gd`, `scripts/villager.gd`, `scripts/nav.gd`)
- `Mover`: acceleration 22 m/s², braking 30 m/s², walk 4.2 m/s, run 7 m/s with **Shift**; slopes up to 46°; stairs up
  to 0.45 m are climbed (and walked down without flying off, floor snap). No jump.
- The body turns to the way it walks.
- `Walker`: there are **no walk/run/idle clips in the allowed sources**, so the gait is computed (the fallback the task
  allowed): each foot is planted while it carries the body (it moves back exactly as fast as the body moves forward —
  a unit test checks this), swings forward in an arc and is put on the ground it finds under it (stairs, slopes); a
  two-bone IK bends the knee; the pelvis drops and sways, the spine leans into a run, the arms swing against the legs;
  standing still it breathes and shifts weight. One cycle blended by speed gives idle, walk and run.
- Villagers are bodies like the captain; they walk a navmesh baked from the colliders of the island, steer round each
  other and the captain (avoidance) and choose another spot when blocked. Standing people (Mara, Ольва, the Chronicler,
  the post keeper, the brokers) are solid.

| Idle | Walk | Run |
|---|---|---|
| ![](g3d-polish/after/gait-idle.jpg) | ![](g3d-polish/after/gait-walk.jpg) | ![](g3d-polish/after/gait-run-2.jpg) |

## 4. Frame rate

Apple M5, 1920×1080, `--fps`. Each cell: average fps / 1%-low fps / worst frame in ms. "jump" is the first second
after the camera teleports to the view, "settled" the next two.

| View | Before | After |
|---|---|---|
| harbour captain | 63.9 / 59.5 / 17.1 | 74.8 / 61.4 / 17.5 |
| view-square jump | 55.6 / 22.1 / 45.3 | 64.8 / 53.5 / 18.7 |
| view-square settled | 57.4 / 53.8 / 18.8 | 64.8 / 53.7 / 18.7 |
| view-houses jump | 82.6 / 16.9 / 59.2 | 72.9 / 57.4 / 17.4 |
| view-houses settled | 88.0 / 67.6 / 15.4 | 73.4 / 56.8 / 18.0 |
| view-house-close jump | 115.3 / 69.5 / 31.4 | 96.9 / 66.0 / 15.1 |
| view-house-close settled | 118.2 / 74.8 / 16.8 | 95.6 / 65.6 / 16.6 |
| view-wharf jump | 73.5 / 16.4 / 61.1 | 109.0 / 73.0 / 36.6 |
| view-wharf settled | 78.2 / 72.1 / 15.6 | 101.3 / 73.5 / 14.0 |
| view-pier jump | 59.5 / 18.5 / 54.0 | 68.8 / 59.7 / 16.7 |
| view-pier settled | 61.3 / 58.0 / 17.5 | 67.5 / 55.6 / 18.1 |
| view-exchange jump | 63.3 / 15.8 / 63.2 | 94.0 / 67.2 / 14.9 |
| view-exchange settled | 66.8 / 60.9 / 17.3 | 91.2 / 67.4 / 16.5 |
| view-top jump | 94.3 / 25.6 / 39.1 | 108.6 / 90.6 / 11.7 |
| view-top settled | 99.6 / 61.4 / 16.6 | 109.5 / 89.0 / 11.6 |
| silk captain | 59.0 / 56.0 / 18.1 | 120.0 / 101.2 / 9.9 |
| view-silk jump | 46.3 / 15.3 / 65.4 | 85.2 / 74.6 / 13.4 |
| view-silk settled | 50.3 / 48.2 / 21.2 | 85.1 / 75.5 / 13.5 |
| view-silk-houses jump | 100.5 / 47.5 / 54.5 | 120.4 / 100.0 / 12.3 |
| view-silk-houses settled | 109.2 / 81.3 / 14.7 | 119.9 / 103.5 / 9.9 |
| view-silk-pier jump | 71.6 / 17.1 / 58.3 | 120.0 / 100.5 / 11.6 |
| view-silk-pier settled | 76.9 / 71.4 / 14.5 | 120.1 / 98.4 / 10.6 |

What it took (`--profile=1` turns one thing off at a time):
- **The long frame after a teleport was SDFGI** rebuilding its cascades: 45–65 ms once per jump, plus ~9 fps all the
  time. SDFGI is now off by default outdoors (the sky lights the scene, SSAO a little stronger); `--sdfgi` turns it on.
- **Tree crowns in the shadow maps**: the crown you see no longer casts a shadow; a five times sparser copy is drawn
  into the shadow maps only. Trees went from 3.9 ms to 0.7 ms per frame.
- Sun shadow distance 160 → 120 m.

Where it stands: the average is 65 fps or more in every view; after a jump the worst frame is 12–19 ms in all views
but one (37 ms once at the wharf). The 1%-low in the three heaviest harbour views (the square, the houses, the pier) is
53–57 fps, so "never under 60" is **not** reached there. The houses view is slower than before (88 → 73) because
there is now something to draw.

## 5. People: dressed for the age of sail (`scripts/costume.gd`)

The MakeHuman people came in T-shirts, jeans and a fedora. Blender is not on this machine, so the models were not
rebuilt; `Costume` dresses them when they are created:
- their own clothes lose the denim and print textures and get plain period cloth (the folds of the normal map stay);
  the sailor's shirt gets stripes from a small shader; the fedora is hidden;
- our own meshes go on top, each piece rigidly skinned to one bone and all of them one mesh per person, so tails,
  sleeves and boots follow the gait and a costume costs a draw call per material.

| Role | Wears |
|---|---|
| Captain | tricorn with a brass edge, long navy coat with tails and brass buttons, turned-back cuffs with the shirt showing, red sash under a belt with a buckle, pale breeches, sea boots with folded tops |
| Sailor | striped shirt with wide sleeves, bandana knotted at the back, sash, canvas slops to mid calf |
| Trader (Mara, the post keeper, brokers) | long gown and skirt, linen apron and sleeves, shawl, kerchief |
| Townsman (the Chronicler, strollers) | brown coat with tails, breeches with stockings and garters, soft felt hat |
| Child | linen shirt, brown breeches, sash and bandana |

No jeans, T-shirts or logos; no new assets; generic period dress, not a character from a game or a film.
`godot --path game3d -- --people=<dir>` makes the line-up (`--plain` shows the people as downloaded).

| Before | After |
|---|---|
| ![](g3d-polish/before/people-plain-front.jpg) | ![](g3d-polish/after/people-dressed-front.jpg) |
| ![](g3d-polish/before/people-plain-back.jpg) | ![](g3d-polish/after/people-dressed-back.jpg) |
| ![](g3d-polish/before/people-plain-captain.jpg) | ![](g3d-polish/after/people-dressed-captain.jpg) |

The gait pictures in section 3 show the captain in the costume, walking and running. Frame rate with the costumes on
is the same within noise (harbour captain 73 fps, the square 64–65).

Limits: the pieces are simple shapes (tubes, boxes, domes) on a T-shirt-and-trousers body, so up close a coat is a
coat-coloured shirt with tails, the bandana reads as a cap, and a boot top can clip a trouser leg. Real period clothes
from MakeHuman would need Blender + MPFB and a rebuild of the four models.

## 6. Not verified, and what needs Aika
- The gait was checked on still frames and by a unit test, not by eye in motion. Play it.
- The M3 self-run demo (`--demo`) was not re-run against a live exchange (ports busy): its screenshots in
  `docs/demo/M3.md` show the old harbour. The Act I spots moved onto the wharf; `demo_go` uses the same spot table.
- The hall is audited (floor, walls, props) but still an orbit camera with the trading HUD; the captain does not walk
  in it.
- Frame rate was measured on one machine. While the game window is covered macOS stops drawing it; `--fps` waits for
  a drawn frame and says so if there is none.
- The costumes were checked on still pictures (line-up, walk, run), not in play.
- **Animation source**: real walk/run/idle clips would look better than a computed gait. Poly Haven and ambientCG
  have none; MakeHuman gives the rig, not clips. Quaternius (an allowed source) publishes CC0 animation packs, but I
  did not download or check one: Quaternius has no stable direct URLs for `make assets` (see `game3d/ASSETS.md`) and the
  clips would have to be retargeted to the MakeHuman rig in Blender. Mixamo was mentioned too; it is a new source and
  its licence forbids redistributing raw files (they would stay out of git like the rest). Say which way to go;
  `Walker` is the one place to swap.

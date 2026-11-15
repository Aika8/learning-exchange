# game3d — assets and licences

## Downloaded CC0 art (ADR-0019)

Not in git. `make assets` downloads every file listed in `game3d/assets.lock` (source URL, size, MD5 published by
Poly Haven) into `game3d/assets/` and checks each MD5. Total 198 MB, 248 files.
To change the list: edit `game3d/tools/assets_resolve.py`, run it to regenerate the lock, run `make assets`.

All Poly Haven assets are CC0 1.0 — public domain, no attribution required (https://polyhaven.com/license).
We credit them anyway. No assets from ambientCG, Quaternius or Kenney ended up in use: Poly Haven covered every need
with one licence and stable direct URLs (Quaternius has no stable direct URLs; Kenney/Quaternius are stylised and
clash with PBR).

| Asset | Kind | Source | Licence | Size |
|---|---|---|---|---|
| `qwantani_late_afternoon_puresky` | HDRI sky | [polyhaven.com/a/qwantani_late_afternoon_puresky](https://polyhaven.com/a/qwantani_late_afternoon_puresky) | CC0 | 4.4 MB |
| `Lantern_01` | glTF model (1k textures) | [polyhaven.com/a/Lantern_01](https://polyhaven.com/a/Lantern_01) | CC0 | 1.4 MB |
| `WoodenChair_01` | glTF model (1k textures) | [polyhaven.com/a/WoodenChair_01](https://polyhaven.com/a/WoodenChair_01) | CC0 | 1.1 MB |
| `WoodenTable_01` | glTF model (1k textures) | [polyhaven.com/a/WoodenTable_01](https://polyhaven.com/a/WoodenTable_01) | CC0 | 0.6 MB |
| `book_encyclopedia_set_01` | glTF model (1k textures) | [polyhaven.com/a/book_encyclopedia_set_01](https://polyhaven.com/a/book_encyclopedia_set_01) | CC0 | 3.3 MB |
| `boulder_01` | glTF model (1k textures) | [polyhaven.com/a/boulder_01](https://polyhaven.com/a/boulder_01) | CC0 | 5.8 MB |
| `dutch_ship_medium` | glTF model (1k textures) | [polyhaven.com/a/dutch_ship_medium](https://polyhaven.com/a/dutch_ship_medium) | CC0 | 8.7 MB |
| `fern_02` | glTF model (1k textures) | [polyhaven.com/a/fern_02](https://polyhaven.com/a/fern_02) | CC0 | 1.1 MB |
| `fishermans_hat` | glTF model (1k textures) | [polyhaven.com/a/fishermans_hat](https://polyhaven.com/a/fishermans_hat) | CC0 | 2.3 MB |
| `grass_medium_01` | glTF model (1k textures) | [polyhaven.com/a/grass_medium_01](https://polyhaven.com/a/grass_medium_01) | CC0 | 3.1 MB |
| `island_tree_02` | glTF model (1k textures) | [polyhaven.com/a/island_tree_02](https://polyhaven.com/a/island_tree_02) | CC0 | 46.2 MB |
| `lantern_chandelier_01` | glTF model (1k textures) | [polyhaven.com/a/lantern_chandelier_01](https://polyhaven.com/a/lantern_chandelier_01) | CC0 | 1.5 MB |
| `lifebuoy` | glTF model (1k textures) | [polyhaven.com/a/lifebuoy](https://polyhaven.com/a/lifebuoy) | CC0 | 2.6 MB |
| `rock_moss_set_01` | glTF model (1k textures) | [polyhaven.com/a/rock_moss_set_01](https://polyhaven.com/a/rock_moss_set_01) | CC0 | 1.9 MB |
| `seadogs_compass` | glTF model (1k textures) | [polyhaven.com/a/seadogs_compass](https://polyhaven.com/a/seadogs_compass) | CC0 | 2.7 MB |
| `ship_pinnace` | glTF model (1k textures) | [polyhaven.com/a/ship_pinnace](https://polyhaven.com/a/ship_pinnace) | CC0 | 21.1 MB |
| `shrub_01` | glTF model (1k textures) | [polyhaven.com/a/shrub_01](https://polyhaven.com/a/shrub_01) | CC0 | 6.9 MB |
| `street_lamp_02` | glTF model (1k textures) | [polyhaven.com/a/street_lamp_02](https://polyhaven.com/a/street_lamp_02) | CC0 | 1.9 MB |
| `treasure_chest` | glTF model (1k textures) | [polyhaven.com/a/treasure_chest](https://polyhaven.com/a/treasure_chest) | CC0 | 5.5 MB |
| `vintage_grandfather_clock_01` | glTF model (1k textures) | [polyhaven.com/a/vintage_grandfather_clock_01](https://polyhaven.com/a/vintage_grandfather_clock_01) | CC0 | 2.4 MB |
| `wine_barrel_01` | glTF model (1k textures) | [polyhaven.com/a/wine_barrel_01](https://polyhaven.com/a/wine_barrel_01) | CC0 | 0.9 MB |
| `wooden_barrels_01` | glTF model (1k textures) | [polyhaven.com/a/wooden_barrels_01](https://polyhaven.com/a/wooden_barrels_01) | CC0 | 7.5 MB |
| `wooden_bucket_01` | glTF model (1k textures) | [polyhaven.com/a/wooden_bucket_01](https://polyhaven.com/a/wooden_bucket_01) | CC0 | 2.3 MB |
| `wooden_crate_01` | glTF model (1k textures) | [polyhaven.com/a/wooden_crate_01](https://polyhaven.com/a/wooden_crate_01) | CC0 | 2.3 MB |
| `wooden_crate_02` | glTF model (1k textures) | [polyhaven.com/a/wooden_crate_02](https://polyhaven.com/a/wooden_crate_02) | CC0 | 2.2 MB |
| `wooden_display_shelves_01` | glTF model (1k textures) | [polyhaven.com/a/wooden_display_shelves_01](https://polyhaven.com/a/wooden_display_shelves_01) | CC0 | 0.5 MB |
| `wooden_lantern_01` | glTF model (1k textures) | [polyhaven.com/a/wooden_lantern_01](https://polyhaven.com/a/wooden_lantern_01) | CC0 | 3.8 MB |
| `clay_roof_tiles_02` | PBR texture set (diff, nor_gl, arm, 1k) | [polyhaven.com/a/clay_roof_tiles_02](https://polyhaven.com/a/clay_roof_tiles_02) | CC0 | 2.5 MB |
| `cobblestone_floor_04` | PBR texture set (diff, nor_gl, arm, 1k) | [polyhaven.com/a/cobblestone_floor_04](https://polyhaven.com/a/cobblestone_floor_04) | CC0 | 1.6 MB |
| `dark_wood` | PBR texture set (diff, nor_gl, arm, 1k) | [polyhaven.com/a/dark_wood](https://polyhaven.com/a/dark_wood) | CC0 | 1.7 MB |
| `denim_fabric` | PBR texture set (diff, nor_gl, arm, 1k) | [polyhaven.com/a/denim_fabric](https://polyhaven.com/a/denim_fabric) | CC0 | 1.6 MB |
| `leafy_grass` | PBR texture set (diff, nor_gl, arm, 1k) | [polyhaven.com/a/leafy_grass](https://polyhaven.com/a/leafy_grass) | CC0 | 3.7 MB |
| `marble_01` | PBR texture set (diff, nor_gl, arm, 1k) | [polyhaven.com/a/marble_01](https://polyhaven.com/a/marble_01) | CC0 | 0.5 MB |
| `mossy_rock` | PBR texture set (diff, nor_gl, arm, 1k) | [polyhaven.com/a/mossy_rock](https://polyhaven.com/a/mossy_rock) | CC0 | 3.0 MB |
| `old_wooden_floor_02` | PBR texture set (diff, nor_gl, arm, 1k) | [polyhaven.com/a/old_wooden_floor_02](https://polyhaven.com/a/old_wooden_floor_02) | CC0 | 1.8 MB |
| `plastered_wall_02` | PBR texture set (diff, nor_gl, arm, 1k) | [polyhaven.com/a/plastered_wall_02](https://polyhaven.com/a/plastered_wall_02) | CC0 | 1.9 MB |
| `quatrefoil_jacquard_fabric` | PBR texture set (diff, nor_gl, arm, 1k) | [polyhaven.com/a/quatrefoil_jacquard_fabric](https://polyhaven.com/a/quatrefoil_jacquard_fabric) | CC0 | 2.6 MB |
| `rock_face_03` | PBR texture set (diff, nor_gl, arm, 1k) | [polyhaven.com/a/rock_face_03](https://polyhaven.com/a/rock_face_03) | CC0 | 2.9 MB |
| `weathered_planks` | PBR texture set (diff, nor_gl, arm, 1k) | [polyhaven.com/a/weathered_planks](https://polyhaven.com/a/weathered_planks) | CC0 | 1.8 MB |
| `namaqualand_cliff_01` | glTF model (1k textures) | [polyhaven.com/a/namaqualand_cliff_01](https://polyhaven.com/a/namaqualand_cliff_01) | CC0 | 4.5 MB |
| `rock_07` | glTF model (1k textures) | [polyhaven.com/a/rock_07](https://polyhaven.com/a/rock_07) | CC0 | 2.2 MB |
| `rock_09` | glTF model (1k textures) | [polyhaven.com/a/rock_09](https://polyhaven.com/a/rock_09) | CC0 | 2.0 MB |
| `rock_face_01` | glTF model (1k textures) | [polyhaven.com/a/rock_face_01](https://polyhaven.com/a/rock_face_01) | CC0 | 3.0 MB |
| `rock_face_02` | glTF model (1k textures) | [polyhaven.com/a/rock_face_02](https://polyhaven.com/a/rock_face_02) | CC0 | 3.5 MB |
| `root_cluster_01` | glTF model (1k textures) | [polyhaven.com/a/root_cluster_01](https://polyhaven.com/a/root_cluster_01) | CC0 | 9.5 MB |
| `single_root` | glTF model (1k textures) | [polyhaven.com/a/single_root](https://polyhaven.com/a/single_root) | CC0 | 3.8 MB |

How they are used: `scripts/assets.gd` (paths, fallbacks), `scripts/proc.gd` (`_pbr_for` palette → texture set,
`_real_ship`, `_person`), `scripts/archipelago.gd` (sky, harbour props, trees), `scripts/hall.gd` (interior).

## Our own work

| What | Source | Licence |
|---|---|---|
| Island, house, windmill, pier and figure meshes; fallback look of everything | Generated in code: `scripts/proc.gd`, `scripts/archipelago.gd`, `scripts/board.gd`, `scripts/hall.gd` | Our own work, CC0 |
| Cloud sea, sail, terrain shaders | `shaders/cloud_sea.gdshader`, `shaders/sail.gdshader`, `shaders/terrain.gdshader` | Our own work, CC0 |
| Noise textures | Generated at runtime by Godot `FastNoiseLite` / `NoiseTexture2D` | Engine feature (MIT), output ours |
| Fallback sky | Godot `ProceduralSkyMaterial` | Engine feature (MIT) |
| Fonts | Godot default font (Noto Sans, OFL) for UI; system Georgia/Times and Menlo/Consolas via `SystemFont` (not shipped) | OFL / OS fonts, not redistributed |
| GUT test framework | `addons/gut` → symlink to `game/addons/gut` (GUT 9.7.1) | MIT |
| Network, i18n, money, book logic | `shared/` → symlinks to `game/scripts/*.gd` | This repo |

No sounds or music. Nothing is taken from existing games: the Poly Haven models are generic real-world objects
(a 17th-century Dutch ship, barrels, lamps), and the world, names and layout are ours.

## MakeHuman villagers (generated, not downloaded)

`sailor`, `trader`, `oldman`, `child` in `assets/models/people/*.glb` are built by `game3d/tools/people/build.sh`
(Blender 4.5 + MPFB 2 add-on + MakeHuman CC0 system assets, makehumancommunity.org). The base mesh, rig and every
clothes, hair, eye and skin asset used are CC0; the clothes are recoloured and the pose set as rest pose by
`restyle.py`. MPFB itself is GPL, its output is not. The files are git-ignored like the rest; without them the
procedural person stands in.

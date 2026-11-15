# game3d — assets and licences

| What | Source | Licence |
|---|---|---|
| All meshes: islands, ether crystals, trees, houses, the windmill Exchange, pier, ship «Попутчик», figures, silk racks, the order-book board, the hall | Generated in code: `scripts/proc.gd`, `scripts/archipelago.gd`, `scripts/board.gd`, `scripts/hall.gd` | Our own work, CC0 |
| Cloud sea, sail | Shaders written here: `shaders/cloud_sea.gdshader`, `shaders/sail.gdshader` | Our own work, CC0 |
| Noise textures | Generated at runtime by Godot `FastNoiseLite` / `NoiseTexture2D` | Engine feature (MIT), output ours |
| Sky | Godot `ProceduralSkyMaterial` | Engine feature (MIT) |
| Fonts | Godot default font (Noto Sans, OFL) for UI; system Georgia/Times and Menlo/Consolas loaded via `SystemFont` (not shipped — the OS's own fonts, with fallbacks) | OFL / OS fonts, not redistributed |
| GUT test framework | `addons/gut` → symlink to `game/addons/gut` (GUT 9.7.1) | MIT |
| Network, i18n, money, book logic | `shared/` → symlinks to `game/scripts/*.gd` | This repo |

No third-party models, textures, sounds or music are used. Nothing is taken from existing games.

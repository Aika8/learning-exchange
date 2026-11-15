# 0019. game3d: painterly realism with CC0 PBR assets fetched by `make assets`

- Status: Accepted
- Date: 2026-11-15
- Pattern(s): Facade (`game3d/scripts/assets.gd` over the downloaded files), Graceful degradation (procedural art stays as the fallback)
- Supersedes: 0017 (art direction and "no imported art"; the shared kernel, scenes and tests of 0017 stay)

## Context
Aika looked at the 0017 slice and said it is "too simple, just geometric shapes". She wants the level of detail of a
modern PBR demo: real materials, detailed models, proper light, small props. Constraints stay: CC0 only, no copying of
existing games, ru/en, the contract unchanged, 60 fps target on a MacBook. New constraint: the repo must not grow by
hundreds of megabytes of binaries, and agents must still be able to review everything that is in git.

## Decision
- Art moves from "stylised low-poly from primitives" to painterly realism: Poly Haven CC0 HDRI sky, PBR texture sets
  (diffuse / normal / ARM) and glTF models (Dutch ship, barrels, crates, lamps, trees, rocks, furniture, chandeliers).
- The files are **not in git**. `game3d/assets.lock` lists every file with its source URL, size and the MD5 that
  Poly Haven publishes; `make assets` (`game3d/tools/fetch_assets.sh`) downloads them into `game3d/assets/`
  (git-ignored) and checks each MD5. `game3d/tools/assets_resolve.py` regenerates the lock from the Poly Haven API
  when the list changes.
- `Assets` (Facade) is the only code that knows paths. Every call degrades: no files → `Proc` keeps the old procedural
  look, so a fresh clone, CI and GUT tests run without the download.
- `Proc.mat()` maps palette colours to PBR texture sets with world triplanar UVs, so procedural meshes (houses,
  windmill, pier) get real materials without UV work. Islands use `shaders/terrain.gdshader` (grass on tops, rock on
  the sides). People are procedural with human proportions, fabric PBR and a Poly Haven hat.
- Render: HDRI panorama sky, SDFGI outdoors, SSAO everywhere, SSIL + SSR indoors, volumetric fog, ACES, 4-split
  PCF soft shadows, FSR 2 upscaling at 0.8 to pay for it.

## Why this and not the alternatives
| Alternative | Why not (now) |
|---|---|
| Commit the assets | 160 MB of binaries in history for ever; clones get slow |
| Git LFS | Needs LFS on every machine and on GitHub quota; agents can't diff the files anyway |
| Unreal / Unity | More photoreal, but binary project files agents can't review, tens of GB, and we lose the shared network/i18n layer and GUT tests |
| Kenney / Quaternius packs | Stylised; they would clash with the realistic materials. Quaternius downloads also have no stable direct URLs for a lock file |
| Keep procedural art and only tune light | Tried in 0017; Aika's verdict is that it reads as primitives |

## Pros
- The picture has real wood, stone, plaster, cloth and a detailed ship; the HDRI gives believable sky light.
- Repo stays small and reviewable; the lock file is a text diff with checksums.
- Everything still runs (procedurally) without the download.

## Risks and costs
- Two looks to keep working (with and without assets). GUT runs in both modes (`test_proc.gd`).
- Poly Haven URLs could change: `make assets` fails loudly on a bad download or MD5; re-run `assets_resolve.py`.
- Performance: the harbour is the heaviest scene (dense models + SDFGI). Measured on Apple M5: ~56–66 fps in the
  harbour, 90–120 elsewhere. Some harbour views dip to ~41–49 fps; the levers are fewer trees, SDFGI off, lower FSR scale.
- Characters are still our own simple figures: there is no realistic CC0 human with a stable download URL.

## How to explain it (teaching note)
A Facade hides where assets come from and what to do when they are missing, so scenes just ask for "a barrel".
Binaries live outside git behind a checksummed lock file — like a package lock for art. The trade-off is a download
step and two code paths, in exchange for a small, reviewable repo.

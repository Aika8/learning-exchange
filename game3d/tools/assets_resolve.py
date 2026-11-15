#!/usr/bin/env python3
"""Resolve the Poly Haven asset list into game3d/assets.lock.

Run only when the asset list changes; `make assets` reads the lock, not the API.
Every Poly Haven asset is CC0 (https://polyhaven.com/license).
Lock line: <md5> <size> <relative path under game3d/assets> <url>
"""
import json, sys, urllib.request

HDRIS = ["qwantani_late_afternoon_puresky"]
TEXTURES = ["rock_face_03", "leafy_grass", "cobblestone_floor_04", "weathered_planks",
            "old_wooden_floor_02", "plastered_wall_02", "clay_roof_tiles_02",
            "marble_01", "dark_wood", "mossy_rock", "quatrefoil_jacquard_fabric", "denim_fabric"]
TEX_MAPS = ["Diffuse", "nor_gl", "arm"]
MODELS = ["dutch_ship_medium", "ship_pinnace", "wine_barrel_01", "wooden_barrels_01",
          "wooden_crate_01", "wooden_crate_02", "Lantern_01", "wooden_lantern_01",
          "street_lamp_02", 
          "rock_moss_set_01", "boulder_01", "fern_02", "shrub_01", "grass_medium_01",
          "wooden_bucket_01", "lifebuoy", "treasure_chest", "WoodenTable_01",
          "WoodenChair_01", "lantern_chandelier_01", "wooden_display_shelves_01",
          "vintage_grandfather_clock_01", "book_encyclopedia_set_01", "seadogs_compass", "island_tree_02", "fishermans_hat", "rock_face_01", "rock_face_02", "namaqualand_cliff_01", "root_cluster_01", "single_root", "rock_07", "rock_09"]

def api(asset):
    req = urllib.request.Request(f"https://api.polyhaven.com/files/{asset}",
                                 headers={"User-Agent": "learning-exchange-assets"})
    return json.load(urllib.request.urlopen(req))

def line(md5, size, path, url):
    return f"{md5} {size} {path} {url}"

out = []
for h in HDRIS:
    f = api(h)["hdri"]["2k"]["hdr"]
    out.append(line(f["md5"], f["size"], f"hdri/{h}_2k.hdr", f["url"]))
for t in TEXTURES:
    d = api(t)
    for m in TEX_MAPS:
        f = d[m]["1k"]["jpg"]
        name = f["url"].rsplit("/", 1)[1]
        out.append(line(f["md5"], f["size"], f"textures/{t}/{name}", f["url"]))
for mo in MODELS:
    g = api(mo)["gltf"]["1k"]["gltf"]
    base = f"models/{mo}"
    out.append(line(g["md5"], g["size"], f"{base}/{mo}_1k.gltf", g["url"]))
    for rel, f in sorted(g["include"].items()):
        out.append(line(f["md5"], f["size"], f"{base}/{rel}", f["url"]))
sys.stdout.write("\n".join(out) + "\n")

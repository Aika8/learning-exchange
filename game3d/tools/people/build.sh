#!/usr/bin/env bash
# Rebuilds the MakeHuman villagers into game3d/assets/models/people (git-ignored). Needs Blender 4.5 with the
# MPFB 2 add-on and the MakeHuman CC0 system asset pack (makehumancommunity.org). The output is CC0.
#   BLENDER=/path/to/Blender MH_ASSETS=/path/to/makehuman_system_assets game3d/tools/people/build.sh
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
out="$here/../../assets/models/people"
mkdir -p "$out"
: "${BLENDER:?set BLENDER to the Blender executable}"
: "${MH_ASSETS:?set MH_ASSETS to the unpacked MakeHuman system assets}"
for who in sailor trader oldman child; do
  "$BLENDER" -b --python "$here/make.py" -- "$who" "$out/$who.glb"
done

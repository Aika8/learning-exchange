#!/bin/sh
# Download the CC0 assets listed in game3d/assets.lock into game3d/assets/ and
# check each file's MD5. Files already present with the right MD5 are skipped.
set -eu
cd "$(dirname "$0")/.."
md5of() { if command -v md5 >/dev/null; then md5 -q "$1"; else md5sum "$1" | cut -d' ' -f1; fi; }
fail=0
while read -r sum size path url; do
  [ -z "$sum" ] && continue
  dest="assets/$path"
  if [ -f "$dest" ] && [ "$(md5of "$dest")" = "$sum" ]; then continue; fi
  mkdir -p "$(dirname "$dest")"
  curl -fsSL --retry 3 -o "$dest.part" "$url"
  if [ "$(md5of "$dest.part")" = "$sum" ]; then mv "$dest.part" "$dest"; echo "ok   $path"
  else rm -f "$dest.part"; echo "BAD  $path" >&2; fail=1; fi
done < assets.lock
exit $fail

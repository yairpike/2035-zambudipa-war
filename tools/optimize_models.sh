#!/usr/bin/env bash
# Rebuild the shipped Tripo models from the full-detail originals.
# Simplifies each mesh to about 30% of its triangles within a 5% shape error, keeping UV seams,
# named nodes (Body, Trim, Turret, Barrel, Rotor, Wake, bones), materials, skins, and clips,
# then caps every texture at 512 px. The stand-ins in game/models/*.glb are left alone.
#
# bash tools/optimize_models.sh            # originals from git at SOURCE_REV
# SOURCE_DIR=/path/to/models bash tools/optimize_models.sh
#
# Needs node/npx (gltfpack, @gltf-transform/cli). Run from the repo root.
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_REV="${SOURCE_REV:-20332a0}"
RATIO="${RATIO:-0.3}"
ERROR="${ERROR:-0.05}"
TEXTURE="${TEXTURE:-512}"
WORK="$(mktemp -d)"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

SRC="${SOURCE_DIR:-}"
if [ -z "$SRC" ]; then
  SRC="$WORK/src"
  mkdir -p "$SRC"
  git -C "$ROOT" archive "$SOURCE_REV" game/models/tripo game/models/env game/models/rigged | tar -x -C "$SRC"
  SRC="$SRC/game/models"
fi

count=0
for folder in tripo env rigged; do
  for src in "$SRC/$folder"/*.glb; do
    [ -f "$src" ] || continue
    name="$(basename "$src")"
    packed="$WORK/packed.glb"
    npx --yes gltfpack -i "$src" -o "$packed" -si "$RATIO" -se "$ERROR" -kn -km -ke -noq > /dev/null
    npx --yes @gltf-transform/cli resize "$packed" "$ROOT/game/models/$folder/$name" --width "$TEXTURE" --height "$TEXTURE" > /dev/null
    count=$((count + 1))
  done
done
echo "optimize_models: wrote $count models"

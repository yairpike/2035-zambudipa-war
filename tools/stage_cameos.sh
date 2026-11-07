#!/usr/bin/env bash
# Flattens the model-rendered cameos into the served cameo folder the game reads.
#   tools/stage_cameos.sh NEW_ROOT DEST [BASE]
# NEW_ROOT holds <faction>/<id>.webp (for example media/cameos/gtfc/militia.webp).
# Shared structures (airfield, naval_yard, war_factory) become DEST/<faction>_<id>.webp;
# everything else becomes DEST/<id>.webp, and a stale DEST/<faction>_<id>.webp is
# removed so it cannot shadow the new file.
# BASE (default DEST) is copied in first, so cameos with no render (river_drone) stay.
# DEST can then be passed to finish_web_export.sh --cameos.
set -euo pipefail
NEW_ROOT="${1:?usage: stage_cameos.sh NEW_ROOT DEST [BASE]}"
DEST="${2:?usage: stage_cameos.sh NEW_ROOT DEST [BASE]}"
BASE="${3:-$DEST}"
mkdir -p "$DEST"
if [ "$BASE" != "$DEST" ] && [ -d "$BASE" ]; then
  find "$BASE" -maxdepth 1 -type f -name '*.webp' -exec cp {} "$DEST/" \;
fi
count=0
for dir in "$NEW_ROOT"/*/; do
  faction="$(basename "$dir")"
  case "$faction" in gtfc|nmrf|mvd|black_market|neutral) ;; *) continue ;; esac
  for file in "$dir"*.webp; do
    [ -f "$file" ] || continue
    id="$(basename "$file" .webp)"
    case "$id" in
      airfield|naval_yard|war_factory) cp "$file" "$DEST/${faction}_${id}.webp" ;;
      *)
        cp "$file" "$DEST/${id}.webp"
        rm -f "$DEST/${faction}_${id}.webp"
        ;;
    esac
    count=$((count + 1))
  done
done
find "$DEST" -maxdepth 1 -type f -name '*.webp' -printf '%f\n' | sort > "$DEST/index.txt"
echo "stage_cameos: $count cameos staged into $DEST"

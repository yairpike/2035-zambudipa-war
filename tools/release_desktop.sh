#!/usr/bin/env bash
# Build both installer sets with pack_installers.sh and publish them as a GitHub Release.
#
#   tools/release_desktop.sh <asset_root> <pages_ref> <tag>
#
# The small installers fetch audio, models, and menu art on first launch. The -Offline ones
# carry everything. Needs the desktop exports in build/desktop and gh with release write access.
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ASSETS="${1:?release_desktop: need the served asset root}"
REF="${2:?release_desktop: need the gh-pages commit that serves the asset root}"
TAG="${3:?release_desktop: need a tag, for example v1.0.0}"
OUT="$ROOT/build/installers"
rm -rf "$OUT"
bash "$ROOT/tools/pack_installers.sh" "$ASSETS" "$OUT" "$REF"
bash "$ROOT/tools/pack_installers.sh" "$ASSETS" "$OUT" "$REF" --full
(cd "$OUT" && sha256sum ASEAN-2031-* > SHA256SUMS.txt)
gh release create "$TAG" --repo yairpike/2035-zambudipa-war --target "$(git -C "$ROOT" rev-parse HEAD)" \
  --title "2035 - Zambudipa War $TAG" \
  --notes "macOS: open the .dmg and drag 2035 - Zambudipa War to Applications. Windows: run the .exe installer. Linux: make the .AppImage executable and run it. The -Offline files carry every asset; the others download audio, models, and menu art on first launch." \
  "$OUT"/ASEAN-2031-* "$OUT/SHA256SUMS.txt"

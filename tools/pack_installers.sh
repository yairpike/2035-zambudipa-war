#!/usr/bin/env bash
# One-file desktop installers from the exports in build/desktop (see pack_desktop.sh).
#
#   tools/pack_installers.sh <asset_root> <dest> <pages_ref> [--full]
#
# Default: ASEAN-2031-macOS.dmg, ASEAN-2031-Windows.exe, ASEAN-2031-Linux-x86_64.AppImage.
#   Audio, models, and menu art stay out. asset_pack.json beside the executable lists them, and
#   the game fetches them from GitHub Pages on first launch (game/asset_download.gd), falling
#   back to raw.githubusercontent.com at <pages_ref>, the gh-pages commit that serves the asset
#   root. A file Pages serves differently must match a blob in SOURCE_REF (default: the
#   merge-base with origin/cursor/web-playtest) and is fetched from there instead.
# --full: the same three with -Offline in the name, every sidecar inside, nothing to download.
# --mobile: only <dest>/asset_pack.json, listing every sidecar, for the Android and iOS .pck
#   (tools/pack_mobile.sh), which have no folder beside the executable to ship files in.
#
# Needs git, makensis (NSIS), mkfs.hfsplus (hfsprogs), hfsplus (planetbeing/libdmg-hfsplus),
# dmg (fanquake/libdmg-hfsplus), appimagetool, and rcodesign.
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ASSETS="$(cd "${1:?pack_installers: need the served asset root}" && pwd)"
DEST="${2:?pack_installers: need the output directory}"
REF="${3:?pack_installers: need the gh-pages commit that serves the asset root}"
FULL=0
MOBILE=0
case "${4:-}" in
  --full) FULL=1 ;;
  --mobile) MOBILE=1 ;;
esac
git -C "$ROOT" cat-file -e "$REF^{commit}" 2>/dev/null || git -C "$ROOT" fetch -q origin gh-pages
REF="$(git -C "$ROOT" rev-parse "$REF^{commit}")"
PAGES_URL="${PAGES_URL:-https://yairpike.github.io/asean-2031/}"
RAW_URL="${RAW_URL:-https://raw.githubusercontent.com/yairpike/asean-2031/$REF/}"
SOURCE_REF="${SOURCE_REF:-$(git -C "$ROOT" merge-base HEAD origin/cursor/web-playtest)}"
SOURCE_URL="${SOURCE_URL:-https://raw.githubusercontent.com/yairpike/asean-2031/$SOURCE_REF/}"
RCODESIGN="${RCODESIGN:-rcodesign}"
EXPORT="$ROOT/build/desktop"
STAGE="$(mktemp -d)"
cleanup() { rm -rf "$STAGE"; }
trap cleanup EXIT
mkdir -p "$DEST"
DEST="$(cd "$DEST" && pwd)"
SUFFIX=""
if [ "$FULL" = 1 ]; then
  SUFFIX="-Offline"
fi

tools="git makensis mkfs.hfsplus hfsplus dmg appimagetool $RCODESIGN"
if [ "$MOBILE" = 1 ]; then
  tools="git"
fi
for tool in $tools; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "pack_installers: missing $tool"
    exit 1
  fi
done

# skip: never shipped on desktop. fetch: left to the first-launch download. ship: always inside.
classify() {
  local rel="$1"
  case "$rel" in
    *.import | .gdignore | */.gdignore | _retired/* | */_retired/*) echo skip; return ;;
    ui/menu/video/*.webm | ui/menu/video/*.mp4) echo skip; return ;;
  esac
  if [[ "$rel" == audio/barks/*.ogg && "${rel#audio/barks/}" != */* ]]; then
    echo skip
    return
  fi
  case "$rel" in
    audio/*.ogg) echo fetch ;;
    models/*.txt | models/*.json) echo ship ;;
    models/*) echo fetch ;;
    ui/menu/cinematic/* | ui/menu/video/*) echo fetch ;;
    *) echo ship ;;
  esac
}

side="$STAGE/side"
mkdir -p "$side"
: > "$STAGE/fetch.txt"
(cd "$ASSETS" && find audio cameos terrain ui models splash wordmark briefings -type f 2>/dev/null | LC_ALL=C sort) > "$STAGE/all.txt"
for need in audio cameos terrain ui models; do
  if ! grep -q "^$need/" "$STAGE/all.txt"; then
    echo "pack_installers: missing $need"
    exit 1
  fi
done
while IFS= read -r rel; do
  kind="$(classify "$rel")"
  if [ "$kind" = skip ]; then
    continue
  fi
  if [ "$MOBILE" = 1 ]; then
    kind=fetch
  fi
  if [ "$kind" = fetch ]; then
    echo "$rel" >> "$STAGE/fetch.txt"
    if [ "$FULL" = 0 ]; then
      continue
    fi
  fi
  mkdir -p "$side/$(dirname "$rel")"
  ln "$ASSETS/$rel" "$side/$rel" 2>/dev/null || cp "$ASSETS/$rel" "$side/$rel"
done < "$STAGE/all.txt"
if [ -f "$ROOT/icon.png" ]; then
  cp "$ROOT/icon.png" "$side/icon.png"
fi

if [ "$FULL" = 0 ]; then
  git -C "$ROOT" ls-tree -r -l "$REF" | awk -F'\t' '{split($1, m, " "); print $2 "\t" m[3] "\t" m[4]}' | LC_ALL=C sort > "$STAGE/pages.tsv"
  sed "s|^|$ASSETS/|" "$STAGE/fetch.txt" | git hash-object --no-filters --stdin-paths > "$STAGE/sha.txt"
  : > "$STAGE/local.tsv"
  while IFS= read -r rel && IFS= read -r sha <&3; do
    printf '%s\t%s\t%s\n' "$rel" "$sha" "$(stat -c %s "$ASSETS/$rel")" >> "$STAGE/local.tsv"
  done < "$STAGE/fetch.txt" 3< "$STAGE/sha.txt"
  LC_ALL=C sort -o "$STAGE/local.tsv" "$STAGE/local.tsv"
  # Files Pages serves differently (the Tripo models) come from the source tree at SOURCE_REF.
  LC_ALL=C comm -23 "$STAGE/local.tsv" "$STAGE/pages.tsv" > "$STAGE/drift.tsv"
  git -C "$ROOT" ls-tree -r "$SOURCE_REF" | awk -F'\t' '{split($1, m, " "); print m[3] "\t" $2}' > "$STAGE/source.tsv"
  awk -F'\t' -v raw="$SOURCE_URL" '
    NR == FNR { if (!($1 in at)) at[$1] = $2; next }
    { if ($2 in at) print $1 "\t" raw at[$2]; else { print "unmatched " $1 > "/dev/stderr"; bad = 1 } }
    END { exit bad }
  ' "$STAGE/source.tsv" "$STAGE/drift.tsv" > "$STAGE/direct.tsv" || {
    echo "pack_installers: some files match neither gh-pages $REF nor $SOURCE_REF"
    exit 1
  }
  awk -F'\t' -v ref="$REF" -v pages="$PAGES_URL" -v raw="$RAW_URL" '
    function q(s) { gsub(/\\/, "\\\\", s); gsub(/"/, "\\\"", s); return "\"" s "\"" }
    NR == FNR { direct[$1] = $2; next }
    FNR == 1 { printf "{\n\"ref\": %s,\n\"urls\": [%s, %s],\n\"files\": [", q(ref), q(pages), q(raw) }
    {
      extra = ($1 in direct) ? ", " q(direct[$1]) : ""
      printf "%s\n[%s, %d, %s%s]", (FNR > 1 ? "," : ""), q($1), $3, q($2), extra
      total += $3
    }
    END { printf "\n],\n\"bytes\": %d\n}\n", total }
  ' "$STAGE/direct.tsv" "$STAGE/local.tsv" > "$side/asset_pack.json"
  echo "pack_installers: $(wc -l < "$STAGE/direct.tsv") files come from $SOURCE_REF instead of Pages"
  echo "pack_installers: first launch fetches $(wc -l < "$STAGE/local.tsv") files, $(( $(awk -F'\t' '{s+=$3} END {print s}' "$STAGE/local.tsv") / 1048576 )) MiB"
fi
if [ "$MOBILE" = 1 ]; then
  cp "$side/asset_pack.json" "$DEST/asset_pack.json"
  exit 0
fi

# macOS: signed universal app plus an /Applications link in a zlib-compressed (UDZO) image.
if [ ! -f "$EXPORT/macos/ASEAN2031.zip" ]; then
  echo "pack_installers: macOS export is missing"
  exit 1
fi
mac="$STAGE/mac"
mkdir -p "$mac"
unzip -q "$EXPORT/macos/ASEAN2031.zip" -d "$mac"
app="$(find "$mac" -maxdepth 2 -type d -name '*.app' | head -n 1)"
if [ -z "$app" ] || [ ! -d "$app/Contents/MacOS" ]; then
  echo "pack_installers: macOS app bundle is missing"
  exit 1
fi
mkdir -p "$app/Contents/Resources"
cp -a "$side/." "$app/Contents/Resources/"
"$RCODESIGN" sign "$app" >/dev/null
appname="$(basename "$app")"
img="$STAGE/mac.img"
megs=$(( $(du -sm "$app" | cut -f1) * 115 / 100 + 16 ))
truncate -s "${megs}M" "$img"
mkfs.hfsplus -v "2035 - Zambudipa War" "$img" >/dev/null
mkdir -p "$STAGE/dmgroot"
mv "$app" "$STAGE/dmgroot/"
(cd "$STAGE/dmgroot" && hfsplus "$img" addall . / >/dev/null)
for bin in "$STAGE/dmgroot/$appname/Contents/MacOS/"*; do
  hfsplus "$img" chmod 755 "/$appname/Contents/MacOS/$(basename "$bin")" >/dev/null
done
hfsplus "$img" symlink /Applications /Applications >/dev/null
rm -f "$DEST/ASEAN-2031-macOS$SUFFIX.dmg"
dmg "$img" "$DEST/ASEAN-2031-macOS$SUFFIX.dmg" >/dev/null
rm -f "$img"

# Windows: per-user NSIS installer with Start menu and desktop shortcuts and an uninstaller.
if [ ! -f "$EXPORT/windows/ASEAN2031.exe" ] || [ ! -f "$EXPORT/windows/ASEAN2031.pck" ]; then
  echo "pack_installers: windows export is missing"
  exit 1
fi
win="$STAGE/win"
mkdir -p "$win"
cp "$EXPORT/windows/ASEAN2031.exe" "$EXPORT/windows/ASEAN2031.pck" "$win/"
cp -a "$side/." "$win/"
cat > "$STAGE/installer.nsi" <<NSI
Unicode true
!include "MUI2.nsh"
Name "2035 - Zambudipa War"
OutFile "$DEST/ASEAN-2031-Windows$SUFFIX.exe"
InstallDir "\$LOCALAPPDATA\\Programs\\2035 - Zambudipa War"
RequestExecutionLevel user
SetCompressor /SOLID lzma
BrandingText "2035 - Zambudipa War"
!define MUI_ICON "$ROOT/brand/icon.ico"
!define MUI_UNICON "$ROOT/brand/icon.ico"
!define MUI_FINISHPAGE_RUN "\$INSTDIR\\ASEAN2031.exe"
!define MUI_FINISHPAGE_RUN_TEXT "Play 2035 - Zambudipa War"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"
Section
  ; Replaces an install made before the game was renamed from ASEAN 2031.
  Delete "\$SMPROGRAMS\\ASEAN 2031.lnk"
  Delete "\$DESKTOP\\ASEAN 2031.lnk"
  StrCmp "\$INSTDIR" "\$LOCALAPPDATA\\Programs\\ASEAN 2031" +2
  RMDir /r "\$LOCALAPPDATA\\Programs\\ASEAN 2031"
  SetOutPath "\$INSTDIR"
  File /r "$win/*"
  WriteUninstaller "\$INSTDIR\\Uninstall.exe"
  CreateShortcut "\$SMPROGRAMS\\2035 - Zambudipa War.lnk" "\$INSTDIR\\ASEAN2031.exe"
  CreateShortcut "\$DESKTOP\\2035 - Zambudipa War.lnk" "\$INSTDIR\\ASEAN2031.exe"
  WriteRegStr HKCU "Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\ASEAN2031" "DisplayName" "2035 - Zambudipa War"
  WriteRegStr HKCU "Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\ASEAN2031" "DisplayIcon" "\$INSTDIR\\ASEAN2031.exe"
  WriteRegStr HKCU "Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\ASEAN2031" "UninstallString" '"\$INSTDIR\\Uninstall.exe"'
  WriteRegDWORD HKCU "Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\ASEAN2031" "NoModify" 1
  WriteRegDWORD HKCU "Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\ASEAN2031" "NoRepair" 1
SectionEnd
Section "Uninstall"
  Delete "\$SMPROGRAMS\\2035 - Zambudipa War.lnk"
  Delete "\$DESKTOP\\2035 - Zambudipa War.lnk"
  RMDir /r "\$INSTDIR"
  DeleteRegKey HKCU "Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\ASEAN2031"
SectionEnd
NSI
rm -f "$DEST/ASEAN-2031-Windows$SUFFIX.exe"
makensis -V2 "$STAGE/installer.nsi" >/dev/null

# Linux: AppImage. Sidecars sit beside the binary inside the image, where the loaders look.
if [ ! -f "$EXPORT/linux/ASEAN2031.x86_64" ] || [ ! -f "$EXPORT/linux/ASEAN2031.pck" ]; then
  echo "pack_installers: linux export is missing"
  exit 1
fi
appdir="$STAGE/ASEAN2031.AppDir"
mkdir -p "$appdir/usr/bin"
cp "$EXPORT/linux/ASEAN2031.x86_64" "$EXPORT/linux/ASEAN2031.pck" "$appdir/usr/bin/"
chmod +x "$appdir/usr/bin/ASEAN2031.x86_64"
cp -a "$side/." "$appdir/usr/bin/"
cat > "$appdir/AppRun" <<'RUN'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
exec "$HERE/usr/bin/ASEAN2031.x86_64" "$@"
RUN
chmod +x "$appdir/AppRun"
cat > "$appdir/asean2031.desktop" <<'DESK'
[Desktop Entry]
Type=Application
Name=2035 - Zambudipa War
Comment=Real-time strategy across Southeast Asia
Exec=ASEAN2031.x86_64
Icon=asean2031
Categories=Game;StrategyGame;
Terminal=false
DESK
cp "$ROOT/icon.png" "$appdir/asean2031.png"
rm -f "$DEST/ASEAN-2031-Linux-x86_64$SUFFIX.AppImage"
ARCH=x86_64 APPIMAGE_EXTRACT_AND_RUN=1 appimagetool --no-appstream "$appdir" "$DEST/ASEAN-2031-Linux-x86_64$SUFFIX.AppImage" >/dev/null 2>&1

ls -l "$DEST"/ASEAN-2031-*"$SUFFIX".*

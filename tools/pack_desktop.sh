#!/usr/bin/env bash
# Zip the desktop exports with the side assets the game reads next to the
# executable. Pass the served asset root (audio, cameos, terrain, ui, models)
# and the directory that should receive the three zips.
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ASSETS="${1:?pack_desktop: need the served asset root}"
DEST="${2:?pack_desktop: need the zip directory}"
EXPORT="$ROOT/build/desktop"
STAGE="$(mktemp -d)"
cleanup() { rm -rf "$STAGE"; }
trap cleanup EXIT
mkdir -p "$DEST"

copy_assets() {
  local into="$1"
  local folder
  for folder in audio cameos terrain ui models; do
    if [ ! -d "$ASSETS/$folder" ]; then
      echo "pack_desktop: missing $folder"
      exit 1
    fi
    rm -rf "$into/$folder"
    cp -a "$ASSETS/$folder" "$into/$folder"
  done
  for folder in splash wordmark briefings; do
    if [ -d "$ASSETS/$folder" ]; then
      rm -rf "$into/$folder"
      cp -a "$ASSETS/$folder" "$into/$folder"
    fi
  done
  if [ -f "$ROOT/icon.png" ]; then
    cp "$ROOT/icon.png" "$into/icon.png"
  fi
  find "$into" -type d -name '_retired' -prune -exec rm -rf {} +
  find "$into/audio/barks" -maxdepth 1 -type f -name '*.ogg' -delete 2>/dev/null || true
}

if [ ! -f "$EXPORT/linux/ASEAN2031.x86_64" ] || [ ! -f "$EXPORT/linux/ASEAN2031.pck" ]; then
  echo "pack_desktop: linux export is missing"
  exit 1
fi
linux_dir="$STAGE/ASEAN2031-linux-x86_64"
mkdir -p "$linux_dir"
cp "$EXPORT/linux/ASEAN2031.x86_64" "$EXPORT/linux/ASEAN2031.pck" "$linux_dir/"
chmod +x "$linux_dir/ASEAN2031.x86_64"
copy_assets "$linux_dir"
rm -f "$DEST/ASEAN2031-linux-x86_64.zip"
(cd "$STAGE" && zip -qr "$DEST/ASEAN2031-linux-x86_64.zip" ASEAN2031-linux-x86_64)

if [ ! -f "$EXPORT/windows/ASEAN2031.exe" ] || [ ! -f "$EXPORT/windows/ASEAN2031.pck" ]; then
  echo "pack_desktop: windows export is missing"
  exit 1
fi
win_dir="$STAGE/ASEAN2031-windows-x86_64"
mkdir -p "$win_dir"
cp "$EXPORT/windows/ASEAN2031.exe" "$EXPORT/windows/ASEAN2031.pck" "$win_dir/"
if [ -f "$EXPORT/windows/ASEAN2031.console.exe" ]; then
  cp "$EXPORT/windows/ASEAN2031.console.exe" "$win_dir/"
fi
copy_assets "$win_dir"
rm -f "$DEST/ASEAN2031-windows-x86_64.zip"
(cd "$STAGE" && zip -qr "$DEST/ASEAN2031-windows-x86_64.zip" ASEAN2031-windows-x86_64)

if [ ! -f "$EXPORT/macos/ASEAN2031.zip" ]; then
  echo "pack_desktop: macOS export is missing"
  exit 1
fi
mac_dir="$STAGE/mac"
mkdir -p "$mac_dir"
unzip -q "$EXPORT/macos/ASEAN2031.zip" -d "$mac_dir"
app="$(find "$mac_dir" -maxdepth 2 -type d -name '*.app' | head -n 1)"
if [ -z "$app" ] || [ ! -d "$app/Contents/MacOS" ]; then
  echo "pack_desktop: macOS app bundle is missing"
  exit 1
fi
mkdir -p "$app/Contents/Resources"
copy_assets "$app/Contents/Resources"
# The side folders land after Godot signed the bundle, so re-sign ad hoc or the
# seal no longer matches and Gatekeeper reports the app as damaged.
RCODESIGN="${RCODESIGN:-rcodesign}"
if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$app"
elif command -v "$RCODESIGN" >/dev/null 2>&1; then
  "$RCODESIGN" sign "$app" >/dev/null
else
  echo "pack_desktop: no codesign or rcodesign; the macOS seal does not cover the side folders"
fi
rm -f "$DEST/ASEAN2031-macos-universal.zip"
(cd "$mac_dir" && zip -qry "$DEST/ASEAN2031-macos-universal.zip" "$(basename "$app")")
echo "pack_desktop: wrote zips in $DEST"

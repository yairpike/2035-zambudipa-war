#!/usr/bin/env bash
# One-file Android and iOS sideload installers.
#
#   tools/pack_mobile.sh <asset_root> <dest> <pages_ref>
#
# Writes ASEAN-2031-Android.apk and ASEAN-2031-iOS.ipa. Both carry only the engine and the .pck;
# the .pck holds build/mobile/asset_pack.json (pack_installers.sh --mobile), which lists every
# sidecar, and the game fetches them into user://assets on first launch (game/asset_download.gd).
#
# Android: Godot's prebuilt release template for arm64-v8a and x86_64, aligned with zipalign
#   (16 KB pages) and signed with apksigner (v1, v2, v3). Needs ANDROID_KEYSTORE,
#   ANDROID_KEY_ALIAS, and ANDROID_KEYSTORE_PASS. Updates only install over an APK signed with the
#   same key.
# iOS: Godot ships the iOS engine as a static library for Xcode. Without Xcode or an Apple SDK, it
#   is linked here with ld64.lld against stub libraries that only name each system framework, so
#   every system symbol is looked up by name when the app starts and frameworks missing from an
#   older iOS are skipped. The app is ad-hoc signed with rcodesign; AltStore, SideStore, and
#   Sideloadly re-sign it with the installing Apple ID.
#
# Needs godot (GODOT), git, ffmpeg, zip, rcodesign, clang, LLVM 18 (ld64.lld, llvm-nm, llvm-objdump),
# Android build-tools (ANDROID_HOME), and Godot 4.7.2 export templates.
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ASSETS="$(cd "${1:?pack_mobile: need the served asset root}" && pwd)"
DEST="${2:?pack_mobile: need the output directory}"
REF="${3:?pack_mobile: need the gh-pages commit that serves the asset root}"
GODOT="${GODOT:-godot}"
RCODESIGN="${RCODESIGN:-rcodesign}"
LLVM="${LLVM:-/usr/lib/llvm-18/bin}"
ANDROID_HOME="${ANDROID_HOME:-$HOME/android-sdk}"
BUILD_TOOLS="${BUILD_TOOLS:-$(ls -d "$ANDROID_HOME"/build-tools/* 2>/dev/null | sort -V | tail -n 1)}"
TEMPLATES="${TEMPLATES:-$HOME/.local/share/godot/export_templates/4.7.2.stable}"
BUNDLE_ID="com.asean2031.game"
TITLE="2035 - Zambudipa War"
VERSION="2035.1"
BUILD="20351"
MIN_IOS="16.0"
: "${ANDROID_KEYSTORE:?pack_mobile: set ANDROID_KEYSTORE}"
: "${ANDROID_KEY_ALIAS:?pack_mobile: set ANDROID_KEY_ALIAS}"
: "${ANDROID_KEYSTORE_PASS:?pack_mobile: set ANDROID_KEYSTORE_PASS}"
for tool in git ffmpeg zip clang "$GODOT" "$RCODESIGN" "$LLVM/ld64.lld" "$LLVM/llvm-nm" "$LLVM/llvm-objdump" "$BUILD_TOOLS/zipalign" "$BUILD_TOOLS/apksigner"; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "pack_mobile: missing $tool"
    exit 1
  fi
done
if [ ! -f "$TEMPLATES/android_release.apk" ] || [ ! -f "$TEMPLATES/ios.zip" ]; then
  echo "pack_mobile: Android or iOS export template is missing from $TEMPLATES"
  exit 1
fi
mkdir -p "$DEST"
DEST="$(cd "$DEST" && pwd)"
OUT="$ROOT/build/mobile"
STAGE="$(mktemp -d)"
cleanup() { rm -rf "$STAGE"; }
trap cleanup EXIT

rm -rf "$OUT"
mkdir -p "$OUT/android" "$OUT/ios"
bash "$ROOT/tools/pack_installers.sh" "$ASSETS" "$OUT" "$REF" --mobile

# Android
GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$ANDROID_KEYSTORE" GODOT_ANDROID_KEYSTORE_RELEASE_USER="$ANDROID_KEY_ALIAS" \
  GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$ANDROID_KEYSTORE_PASS" \
  "$GODOT" --headless --path "$ROOT" --export-release "Android" "$OUT/android/ASEAN2031.apk" > "$OUT/android/export.log" 2>&1
"$BUILD_TOOLS/zipalign" -f -P 16 4 "$OUT/android/ASEAN2031.apk" "$STAGE/aligned.apk"
rm -f "$DEST/ASEAN-2031-Android.apk"
ANDROID_KEYSTORE_PASS="$ANDROID_KEYSTORE_PASS" "$BUILD_TOOLS/apksigner" sign --ks "$ANDROID_KEYSTORE" \
  --ks-key-alias "$ANDROID_KEY_ALIAS" --ks-pass env:ANDROID_KEYSTORE_PASS --key-pass env:ANDROID_KEYSTORE_PASS \
  --v1-signing-enabled true --v2-signing-enabled true --v3-signing-enabled true --v4-signing-enabled false \
  --out "$DEST/ASEAN-2031-Android.apk" "$STAGE/aligned.apk"
"$BUILD_TOOLS/zipalign" -c -P 16 4 "$DEST/ASEAN-2031-Android.apk"
"$BUILD_TOOLS/apksigner" verify --min-sdk-version 21 "$DEST/ASEAN-2031-Android.apk"

# iOS: the export writes the Xcode project and ASEAN2031.pck; only the .pck and plist are used.
"$GODOT" --headless --path "$ROOT" --export-release "iOS" "$OUT/ios/ASEAN2031.ipa" > "$OUT/ios/export.log" 2>&1
if [ ! -f "$OUT/ios/ASEAN2031.pck" ] || [ ! -f "$OUT/ios/ASEAN2031/ASEAN2031-Info.plist" ]; then
  echo "pack_mobile: iOS export did not write the .pck and Info.plist"
  exit 1
fi
lib="$STAGE/lib"
mkdir -p "$lib"
unzip -q "$TEMPLATES/ios.zip" 'libgodot.ios.release.xcframework/ios-arm64/*' \
  'libgodot_camera.ios.release.xcframework/ios-arm64/*' 'MoltenVK.xcframework/ios-arm64/*' 'PrivacyInfo.xcprivacy' -d "$lib"
archives=("$lib/libgodot.ios.release.xcframework/ios-arm64/libgodot.a"
  "$lib/libgodot_camera.ios.release.xcframework/ios-arm64/libgodot_camera.a"
  "$lib/MoltenVK.xcframework/ios-arm64/libMoltenVK.a")
for a in "${archives[@]}"; do
  "$LLVM/llvm-objdump" --macho --private-headers "$a" 2>/dev/null | grep -A8 "LC_LINKER_OPTION" | awk '/string #/ {print $3}'
done > "$STAGE/autolink.txt"
"$LLVM/llvm-nm" -g -u "${archives[@]}" 2>/dev/null | awk '{print $NF}' | grep '^__swift_FORCE_LOAD_\$_' | sort -u > "$STAGE/force_load.txt"
sdk="$STAGE/sdk"
mkdir -p "$sdk/usr/lib/swift" "$sdk/System/Library/Frameworks"
tbd() {
  printf -- "--- !tapi-tbd\ntbd-version: 4\ntargets: [ arm64-ios ]\ninstall-name: '%s'\ncurrent-version: 1\ncompatibility-version: 1\n...\n" "$2" > "$1"
}
tbd "$sdk/usr/lib/libSystem.tbd" /usr/lib/libSystem.B.dylib
tbd "$sdk/usr/lib/libobjc.tbd" /usr/lib/libobjc.A.dylib
tbd "$sdk/usr/lib/libc++.tbd" /usr/lib/libc++.1.dylib
links=()
# The Swift back-deployment libraries are static and only matter below iOS 16; their markers are stubbed.
while read -r flag name; do
  case "$flag" in
    -framework)
      mkdir -p "$sdk/System/Library/Frameworks/$name.framework"
      tbd "$sdk/System/Library/Frameworks/$name.framework/$name.tbd" "/System/Library/Frameworks/$name.framework/$name"
      links+=(-weak_framework "$name")
      ;;
    -l)
      case "$name" in
        c++ | objc | swiftCompatibility* | swiftCxx | swiftCxxStdlib) ;;
        *)
          tbd "$sdk/usr/lib/swift/lib$name.tbd" "/usr/lib/swift/lib$name.dylib"
          links+=("-weak-l$name")
          ;;
      esac
      ;;
  esac
done < <(awk '{ if ($1 == "-framework") { getline n; print "-framework " n } else if ($1 ~ /^-l/) print "-l " substr($1, 3) }' "$STAGE/autolink.txt" | sort -u)
{
  echo 'typedef unsigned int uint32_t;'
  echo 'typedef struct { uint32_t platform; uint32_t version; } dyld_build_version_t;'
  echo 'typedef int (*avail_fn)(uint32_t, const dyld_build_version_t *);'
  echo 'extern void *dlsym(void *, const char *);'
  echo '/* Normally from the static compiler runtime, which only Xcode ships. */'
  echo 'int __isPlatformVersionAtLeast(uint32_t platform, uint32_t major, uint32_t minor, uint32_t subminor) {'
  echo '  static avail_fn check = 0;'
  echo '  static int looked = 0;'
  echo '  if (!looked) { check = (avail_fn)dlsym((void *)-2, "_availability_version_check"); looked = 1; }'
  echo '  if (!check) return 1;'
  echo '  dyld_build_version_t v = { platform, (major << 16) | ((minor & 0xff) << 8) | (subminor & 0xff) };'
  echo '  return check(1, &v);'
  echo '}'
  n=0
  while read -r sym; do
    echo "__attribute__((used, visibility(\"hidden\"))) char force_load_$n __asm__(\"$sym\") = 0;"
    n=$((n + 1))
  done < "$STAGE/force_load.txt"
} > "$STAGE/stubs.c"
clang --target="arm64-apple-ios$MIN_IOS" -O2 -c "$STAGE/stubs.c" -o "$STAGE/stubs.o"
app="$STAGE/Payload/$TITLE.app"
mkdir -p "$app"
"$LLVM/ld64.lld" -arch arm64 -platform_version ios "$MIN_IOS" 18.0 -syslibroot "$sdk" -L/usr/lib/swift \
  -o "$app/ASEAN2031" "$STAGE/stubs.o" "${archives[@]}" -lSystem -lobjc -lc++ "${links[@]}" \
  -undefined dynamic_lookup -ignore_auto_link -rpath /usr/lib/swift -rpath @executable_path/Frameworks -dead_strip
cp "$OUT/ios/ASEAN2031.pck" "$app/ASEAN2031.pck"
cp "$lib/PrivacyInfo.xcprivacy" "$app/"
for size in 120 152 167 180; do
  ffmpeg -loglevel error -i "$ROOT/brand/icon-maskable-512.png" -vf "scale=$size:$size:flags=lanczos,format=rgb24" -y "$STAGE/icon-$size.png"
done
cp "$STAGE/icon-120.png" "$app/AppIcon60x60@2x.png"
cp "$STAGE/icon-180.png" "$app/AppIcon60x60@3x.png"
cp "$STAGE/icon-152.png" "$app/AppIcon76x76@2x~ipad.png"
cp "$STAGE/icon-167.png" "$app/AppIcon83.5x83.5@2x~ipad.png"
python3 - "$OUT/ios/ASEAN2031/ASEAN2031-Info.plist" "$app/Info.plist" "$TITLE" "$BUNDLE_ID" "$VERSION" "$BUILD" "$MIN_IOS" <<'PY'
import plistlib, re, sys
src, dst, title, bundle_id, version, build, min_ios = sys.argv[1:8]
text = open(src, encoding="utf-8").read()
text = text.replace("<string>$(INFOPLIST_KEY_CFBundleDisplayName)</string>", "<string></string>")
text = re.sub(r"<string>\$\([A-Z_]+\)</string>", "<string></string>", text)
info = plistlib.loads(text.encode("utf-8"))
info.pop("UILaunchStoryboardName", None)
info.update({
    "CFBundleDisplayName": title,
    "CFBundleName": title,
    "CFBundleExecutable": "ASEAN2031",
    "CFBundleIdentifier": bundle_id,
    "CFBundleShortVersionString": version,
    "CFBundleVersion": build,
    "CFBundleSignature": "????",
    "CFBundleSupportedPlatforms": ["iPhoneOS"],
    "DTPlatformName": "iphoneos",
    "MinimumOSVersion": min_ios,
    "UIDeviceFamily": [1, 2],
    "UIRequiredDeviceCapabilities": ["arm64"],
    "UILaunchScreen": {},
    "CFBundleIcons": {"CFBundlePrimaryIcon": {"CFBundleIconFiles": ["AppIcon60x60"]}},
    "CFBundleIcons~ipad": {"CFBundlePrimaryIcon": {"CFBundleIconFiles": ["AppIcon60x60", "AppIcon76x76", "AppIcon83.5x83.5"]}},
    "NSLocalNetworkUsageDescription": "Finds and joins LAN matches on your network.",
    "NSAppTransportSecurity": {
        "NSAllowsArbitraryLoads": False,
        "NSExceptionDomains": {
            "yairpike.github.io": {"NSIncludesSubdomains": False, "NSExceptionMinimumTLSVersion": "TLSv1.2"},
            "raw.githubusercontent.com": {"NSIncludesSubdomains": False, "NSExceptionMinimumTLSVersion": "TLSv1.2"},
        },
    },
})
for key in ("NSCameraUsageDescription", "NSPhotoLibraryUsageDescription", "NSMicrophoneUsageDescription"):
    if not info.get(key):
        info.pop(key, None)
with open(dst, "wb") as out:
    plistlib.dump(info, out, fmt=plistlib.FMT_XML)
PY
printf 'APPL????' > "$app/PkgInfo"
"$RCODESIGN" sign "$app" >/dev/null
rm -f "$DEST/ASEAN-2031-iOS.ipa"
(cd "$STAGE" && zip -q -r -y -9 "$DEST/ASEAN-2031-iOS.ipa" Payload)

ls -l "$DEST/ASEAN-2031-Android.apk" "$DEST/ASEAN-2031-iOS.ipa"

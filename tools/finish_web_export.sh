#!/usr/bin/env bash
# Copy the service worker next to a single-threaded Compatibility export and
# register it. Does not add cross-origin isolation headers.
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/build/web"
# Optional trees. Set AUDIO_SRC, CAMEO_SRC, and MENU_SRC in the environment, or pass
# --audio DIR, --cameos DIR, --menu DIR, and --briefings DIR. Without them, folders already
# next to the export are left in place.
if [ $# -gt 0 ] && [ "${1#-}" = "$1" ]; then
  DEST="$1"
  shift
fi
while [ $# -gt 0 ]; do
  case "$1" in
    --audio)
      if [ $# -lt 2 ]; then
        echo "finish_web_export: --audio needs a directory"
        exit 1
      fi
      AUDIO_SRC="$2"
      shift 2
      ;;
    --cameos)
      if [ $# -lt 2 ]; then
        echo "finish_web_export: --cameos needs a directory"
        exit 1
      fi
      CAMEO_SRC="$2"
      shift 2
      ;;
    --menu)
      if [ $# -lt 2 ]; then
        echo "finish_web_export: --menu needs a directory"
        exit 1
      fi
      MENU_SRC="$2"
      shift 2
      ;;
    --terrain)
      if [ $# -lt 2 ]; then
        echo "finish_web_export: --terrain needs a directory"
        exit 1
      fi
      TERRAIN_SRC="$2"
      shift 2
      ;;
    --ui)
      if [ $# -lt 2 ]; then
        echo "finish_web_export: --ui needs a directory"
        exit 1
      fi
      UI_SRC="$2"
      shift 2
      ;;
    --video)
      if [ $# -lt 2 ]; then
        echo "finish_web_export: --video needs a directory"
        exit 1
      fi
      VIDEO_SRC="$2"
      shift 2
      ;;
    --briefings)
      if [ $# -lt 2 ]; then
        echo "finish_web_export: --briefings needs a directory"
        exit 1
      fi
      BRIEFINGS_SRC="$2"
      shift 2
      ;;
    --models)
      if [ $# -lt 2 ]; then
        echo "finish_web_export: --models needs a directory"
        exit 1
      fi
      MODEL_SRC="$2"
      shift 2
      ;;
    --tripo)
      if [ $# -lt 2 ]; then
        echo "finish_web_export: --tripo needs a directory"
        exit 1
      fi
      TRIPO_SRC="$2"
      shift 2
      ;;
    --key-art)
      if [ $# -lt 2 ]; then
        echo "finish_web_export: --key-art needs a directory"
        exit 1
      fi
      KEY_ART_SRC="$2"
      shift 2
      ;;
    *)
      echo "finish_web_export: unknown argument $1"
      exit 1
      ;;
  esac
done
AUDIO_SRC="${AUDIO_SRC:-}"
CAMEO_SRC="${CAMEO_SRC:-}"
MENU_SRC="${MENU_SRC:-}"
TERRAIN_SRC="${TERRAIN_SRC:-}"
UI_SRC="${UI_SRC:-}"
VIDEO_SRC="${VIDEO_SRC:-}"
MODEL_SRC="${MODEL_SRC:-}"
BRIEFINGS_SRC="${BRIEFINGS_SRC:-}"
TRIPO_SRC="${TRIPO_SRC:-}"
KEY_ART_SRC="${KEY_ART_SRC:-}"
# Keep the project worker. Godot's exported worker reloads every open client
# when it receives "update", which boots a match back to the menu.
cp "$ROOT/web/sw.js" "$DEST/sw.js"
if [ -f "$DEST/index.service.worker.js" ]; then
  python3 - "$DEST/index.service.worker.js" << 'PY'
import sys
path = sys.argv[1]
text = open(path, encoding="utf-8").read()
old = "self.skipWaiting().then(() => self.clients.claim()).then(() => self.clients.matchAll()).then((all) => all.forEach((c) => c.navigate(c.url)));"
new = "self.skipWaiting().then(() => self.clients.claim());"
if old in text:
    text = text.replace(old, new, 1)
elif "c.navigate(c.url)" in text:
    raise SystemExit("finish_web_export: service worker navigate hook moved")
open(path, "w", encoding="utf-8").write(text)
PY
fi
if [ -f "$DEST/index.html" ]; then
  python3 - "$DEST/index.html" << 'PY'
import sys
path = sys.argv[1]
html = open(path, encoding="utf-8").read()
old = '"serviceWorker":"index.service.worker.js"'
new = '"serviceWorker":""'
if old in html:
    html = html.replace(old, new, 1)
elif '"serviceWorker":""' not in html:
    raise SystemExit("finish_web_export: serviceWorker config moved")
open(path, "w", encoding="utf-8").write(html)
PY
fi
if [ -f "$DEST/index.manifest.json" ]; then
  python3 - "$DEST/index.manifest.json" << 'PY'
import json
import sys
path = sys.argv[1]
data = json.loads(open(path, encoding="utf-8").read())
data["name"] = "ASEAN 2031"
data["short_name"] = "ASEAN 2031"
data["start_url"] = "./index.html"
data["scope"] = "./"
icons = data.get("icons", [])
if isinstance(icons, list):
    for icon in icons:
        src = str(icon.get("src", ""))
        if src.startswith("/"):
            icon["src"] = src.lstrip("/")
with open(path, "w", encoding="utf-8") as handle:
    json.dump(data, handle, separators=(",", ":"))
    handle.write("\n")
PY
  cp "$DEST/index.manifest.json" "$DEST/manifest.webmanifest"
fi
if [ -f "$DEST/index.html" ] && ! grep -q 'id="status-title"' "$DEST/index.html"; then
  python3 - "$DEST/index.html" << 'PY'
import sys
path = sys.argv[1]
html = open(path, encoding="utf-8").read()
needle = '<div id="status">'
title = needle + '\n\t\t\t<p id="status-title" style="font-family: sans-serif; font-size: 28px; letter-spacing: 0.08em; margin: 0 0 16px;">ASEAN 2031</p>'
if needle in html:
    html = html.replace(needle, title, 1)
    open(path, "w", encoding="utf-8").write(html)
PY
fi
if ! grep -q 'serviceWorker.register("sw.js")' "$DEST/index.html"; then
  sed -i 's#</body>#<script>if("serviceWorker" in navigator){navigator.serviceWorker.register("sw.js");}</script></body>#' "$DEST/index.html"
fi
cp "$ROOT/web/audio_unlock.js" "$DEST/audio_unlock.js"
if [ -f "$ROOT/web/favicon.ico" ]; then
  cp "$ROOT/web/favicon.ico" "$DEST/favicon.ico"
  if [ -f "$DEST/index.html" ] && ! grep -q 'href="favicon.ico"' "$DEST/index.html"; then
    sed -i 's#</head>#<link rel="icon" href="favicon.ico" sizes="16x16 32x32 48x48"></head>#' "$DEST/index.html"
  fi
fi
# The page that shipped at 97433c3 uses these exact files: index.icon.png as the tab icon,
# the apple touch icon, and the three PWA sizes named in the manifest.
if [ -f "$ROOT/brand/favicon.png" ]; then
  cp "$ROOT/brand/favicon.png" "$DEST/index.icon.png"
fi
if [ -f "$ROOT/brand/apple_touch_icon.png" ]; then
  cp "$ROOT/brand/apple_touch_icon.png" "$DEST/index.apple-touch-icon.png"
fi
if [ -f "$ROOT/brand/pwa_144.png" ]; then
  cp "$ROOT/brand/pwa_144.png" "$DEST/index.144x144.png"
fi
if [ -f "$ROOT/brand/pwa_180.png" ]; then
  cp "$ROOT/brand/pwa_180.png" "$DEST/index.180x180.png"
fi
if [ -f "$ROOT/brand/pwa_512.png" ]; then
  cp "$ROOT/brand/pwa_512.png" "$DEST/index.512x512.png"
fi
if [ -f "$ROOT/brand/boot_splash.png" ]; then
  cp "$ROOT/brand/boot_splash.png" "$DEST/index.png"
fi
if [ -f "$ROOT/brand/boot_splash.webp" ]; then
  mkdir -p "$DEST/splash"
  cp "$ROOT/brand/boot_splash.webp" "$DEST/splash/splash-four-fronts.webp"
  : > "$DEST/splash/.gdignore"
  if [ -f "$DEST/index.html" ]; then
    sed -i 's#src="index\.png"#src="splash/splash-four-fronts.webp"#' "$DEST/index.html"
  fi
fi
if [ -f "$ROOT/brand/wordmark-vanguard-1024.png" ]; then
  mkdir -p "$DEST/wordmark"
  cp "$ROOT/brand/wordmark-vanguard-1024.png" "$DEST/wordmark/wordmark-vanguard-1024.png"
  if [ -f "$ROOT/brand/wordmark-vanguard.svg" ]; then
    cp "$ROOT/brand/wordmark-vanguard.svg" "$DEST/wordmark/wordmark-vanguard.svg"
  fi
  : > "$DEST/wordmark/.gdignore"
fi
if [ -f "$DEST/index.html" ] && ! grep -q 'href="index.icon.png"' "$DEST/index.html"; then
  sed -i 's#</head>#<link id="-gd-engine-icon" rel="icon" type="image/png" href="index.icon.png"></head>#' "$DEST/index.html"
fi
if [ -f "$DEST/index.html" ] && ! grep -q 'audio_unlock.js' "$DEST/index.html"; then
  python3 - "$DEST/index.html" << 'PY'
import sys
path = sys.argv[1]
html = open(path, encoding="utf-8").read()
needle = "<head>"
tag = '<head>\n\t\t<script src="audio_unlock.js"></script>'
if needle not in html:
    raise SystemExit("finish_web_export: index.html has no head")
open(path, "w", encoding="utf-8").write(html.replace(needle, tag, 1))
PY
fi
cp "$ROOT/tools/brotli_host.conf" "$DEST/brotli_host.conf"
if [ -n "$AUDIO_SRC" ]; then
  if [ ! -d "$AUDIO_SRC/music" ] && [ ! -d "$AUDIO_SRC/barks" ]; then
    echo "finish_web_export: audio source has no music or barks"
    exit 1
  fi
  mkdir -p "$DEST/audio"
  if [ -d "$AUDIO_SRC/music" ]; then
    rm -rf "$DEST/audio/music"
    cp -R "$AUDIO_SRC/music" "$DEST/audio/music"
  fi
  if [ -d "$AUDIO_SRC/barks" ]; then
    rm -rf "$DEST/audio/barks"
    cp -R "$AUDIO_SRC/barks" "$DEST/audio/barks"
  fi
  if [ -f "$AUDIO_SRC/manifest.json" ]; then
    cp "$AUDIO_SRC/manifest.json" "$DEST/audio/manifest.json"
  fi
  if [ -d "$AUDIO_SRC/announcer" ]; then
    rm -rf "$DEST/audio/announcer"
    cp -R "$AUDIO_SRC/announcer" "$DEST/audio/announcer"
  fi
  if [ -d "$AUDIO_SRC/sfx" ]; then
    rm -rf "$DEST/audio/sfx"
    mkdir -p "$DEST/audio/sfx"
    find "$AUDIO_SRC/sfx" -maxdepth 1 -type f -name '*.ogg' ! -name '*.conflict.ogg' -exec cp {} "$DEST/audio/sfx/" \;
    find "$DEST/audio/sfx" -maxdepth 1 -type f -name '*.ogg' -printf '%f\n' | sort > "$DEST/audio/sfx/index.txt"
  fi
  if [ -d "$AUDIO_SRC/dialogue" ]; then
    rm -rf "$DEST/audio/dialogue"
    cp -R "$AUDIO_SRC/dialogue" "$DEST/audio/dialogue"
  fi
  # The retired European takes and the old flat clips stay off the page.
  rm -rf "$DEST/audio/_retired"
  if [ -d "$DEST/audio" ]; then
    find "$DEST/audio" -type d -name '_retired' -prune -exec rm -rf {} +
  fi
  if [ -d "$DEST/audio/barks" ]; then
    find "$DEST/audio/barks" -maxdepth 1 -type f -name '*.ogg' -delete
  fi
  for fac in gtfc nmrf mvd; do
    rm -rf "$DEST/audio/announcer/$fac"
  done
  # music/user/ and voice-language folders are fetched when a clip plays.
  find "$DEST/audio/music" "$DEST/audio/barks" -type f -name '*.ogg' ! -path '*/music/user/*' ! -path '*/barks/*/*' 2>/dev/null \
    | sed "s#^$DEST/audio/##" \
    | sort > "$DEST/audio/clips.txt"
  python3 - "$DEST" << 'PY'
import json, os, sys
from collections import defaultdict
dest = sys.argv[1]
audio = os.path.join(dest, "audio")

def playable(take):
    if not isinstance(take, dict):
        return False
    if take.get("accent_fail") is True:
        return False
    if take.get("status") == "removed":
        return False
    file_name = take.get("file") or ""
    if not file_name or "_retired" in file_name:
        return False
    return True

bark_path = os.path.join(audio, "barks", "manifest.json")
line_path = os.path.join(audio, "announcer", "manifest.json")
if not os.path.isfile(bark_path) or not os.path.isfile(line_path):
    raise SystemExit("finish_web_export: voice manifests were not copied")
barks = json.load(open(bark_path, encoding="utf-8"))
names = defaultdict(set)
for units in barks.get("clips", {}).values():
    if not isinstance(units, dict):
        continue
    for events in units.values():
        if not isinstance(events, dict):
            continue
        for takes in events.values():
            if not isinstance(takes, list):
                continue
            for take in takes:
                if not playable(take):
                    continue
                parts = take["file"].split("/")
                if len(parts) != 3 or parts[0] != "barks":
                    continue
                if os.path.isfile(os.path.join(audio, *parts)):
                    names[parts[1]].add(parts[2])
for lang, files in names.items():
    folder = os.path.join(audio, "barks", lang)
    os.makedirs(folder, exist_ok=True)
    with open(os.path.join(folder, "index.txt"), "w", encoding="utf-8") as out:
        for name in sorted(files):
            out.write(name + "\n")
lines = json.load(open(line_path, encoding="utf-8"))
spoken = defaultdict(set)
for factions in lines.get("clips", {}).values():
    if not isinstance(factions, dict):
        continue
    for keys in factions.values():
        if not isinstance(keys, dict):
            continue
        for take in keys.values():
            if not playable(take):
                continue
            file_name = take["file"]
            if file_name.startswith("announcer/"):
                file_name = file_name[len("announcer/"):]
            parts = file_name.split("/")
            if len(parts) != 3:
                continue
            if os.path.isfile(os.path.join(audio, "announcer", file_name)):
                spoken[parts[0]].add(parts[1] + "/" + parts[2])
for lang, files in spoken.items():
    folder = os.path.join(audio, "announcer", lang)
    os.makedirs(folder, exist_ok=True)
    with open(os.path.join(folder, "index.txt"), "w", encoding="utf-8") as out:
        for name in sorted(files):
            out.write(name + "\n")
print("voice indexes", {lang: len(files) for lang, files in sorted(names.items())})
print("line indexes", {lang: len(files) for lang, files in sorted(spoken.items())})
dialogue_path = os.path.join(audio, "dialogue", "manifest.json")
spoken_lines = defaultdict(set)
if os.path.isfile(dialogue_path):
    dialogue = json.load(open(dialogue_path, encoding="utf-8"))
    for missions in dialogue.get("clips", {}).values():
        if not isinstance(missions, dict):
            continue
        for beats in missions.values():
            if not isinstance(beats, dict):
                continue
            for take in beats.values():
                if not playable(take):
                    continue
                parts = (take.get("file") or "").split("/")
                if len(parts) != 4 or parts[0] != "dialogue" or not parts[3].endswith(".ogg"):
                    continue
                if os.path.isfile(os.path.join(audio, *parts)):
                    spoken_lines[parts[1]].add(parts[2] + "/" + parts[3])
    for lang, files in spoken_lines.items():
        folder = os.path.join(audio, "dialogue", lang)
        os.makedirs(folder, exist_ok=True)
        with open(os.path.join(folder, "index.txt"), "w", encoding="utf-8") as out:
            for name in sorted(files):
                out.write(name + "\n")
print("dialogue indexes", {lang: len(files) for lang, files in sorted(spoken_lines.items())})
PY
  if ! grep -q "music/menu.ogg" "$DEST/audio/clips.txt"; then
    echo "finish_web_export: clips.txt missing menu"
    exit 1
  fi
  if grep -q "barks/crimson_sapper_select_2.ogg" "$DEST/audio/clips.txt"; then
    echo "finish_web_export: the flat sapper line is still in the startup download"
    exit 1
  fi
  if [ ! -f "$DEST/audio/barks/my/crimson_sapper_select_1.ogg" ]; then
    echo "finish_web_export: missing the Burmese sapper select line"
    exit 1
  fi
  if [ ! -f "$DEST/audio/barks/manifest.json" ] || [ ! -f "$DEST/audio/announcer/manifest.json" ]; then
    echo "finish_web_export: voice manifests were not copied"
    exit 1
  fi
  if find "$DEST/audio" -type d -name '_retired' | grep -q .; then
    echo "finish_web_export: retired voices were copied"
    exit 1
  fi
  if grep -qx "militia_move_1.ogg" "$DEST/audio/barks/en/index.txt"; then
    echo "finish_web_export: a failed English bark is in the index"
    exit 1
  fi
  if ! grep -qx "militia_select_1.ogg" "$DEST/audio/barks/en/index.txt"; then
    echo "finish_web_export: the passing militia select line is missing from the index"
    exit 1
  fi
  if grep -qx "gtfc/unit_lost.ogg" "$DEST/audio/announcer/en/index.txt"; then
    echo "finish_web_export: a failed English announcer line is in the index"
    exit 1
  fi
  if ! grep -qx "gtfc/low_power.ogg" "$DEST/audio/announcer/en/index.txt"; then
    echo "finish_web_export: the passing low power line is missing from the index"
    exit 1
  fi
  if grep -q "^dialogue/" "$DEST/audio/clips.txt"; then
    echo "finish_web_export: dialogue is in the startup download"
    exit 1
  fi
  if [ -f "$DEST/audio/dialogue/manifest.json" ]; then
    if grep -qx "kokang/open.ogg" "$DEST/audio/dialogue/en/index.txt"; then
      echo "finish_web_export: a failed English dialogue line is in the index"
      exit 1
    fi
    if ! grep -qx "tachileik/open.ogg" "$DEST/audio/dialogue/my/index.txt"; then
      echo "finish_web_export: the passing Tachileik line is missing from the index"
      exit 1
    fi
  fi
  : > "$DEST/audio/.gdignore"
fi
if [ -n "$CAMEO_SRC" ]; then
  if [ ! -d "$CAMEO_SRC" ]; then
    echo "finish_web_export: cameo source is not a directory"
    exit 1
  fi
  rm -rf "$DEST/cameos"
  mkdir -p "$DEST/cameos"
  find "$CAMEO_SRC" -maxdepth 1 -type f -name '*.webp' -exec cp {} "$DEST/cameos/" \;
  find "$DEST/cameos" -maxdepth 1 -type f -name '*.webp' -printf '%f\n' | sort > "$DEST/cameos/index.txt"
  : > "$DEST/cameos/.gdignore"
  if ! grep -q "militia.webp" "$DEST/cameos/index.txt"; then
    echo "finish_web_export: cameo index is missing militia"
    exit 1
  fi
fi
if [ -n "$MENU_SRC" ]; then
  if [ ! -d "$MENU_SRC" ]; then
    echo "finish_web_export: menu source is not a directory"
    exit 1
  fi
  MENU_DIR="$MENU_SRC"
  if [ -d "$MENU_SRC/cinematic" ]; then
    MENU_DIR="$MENU_SRC/cinematic"
  elif [ -d "$MENU_SRC/backgrounds" ]; then
    MENU_DIR="$MENU_SRC/backgrounds"
  fi
  rm -rf "$DEST/ui/menu/cinematic"
  mkdir -p "$DEST/ui/menu/cinematic"
  find "$MENU_DIR" -maxdepth 1 -type f \( -name '*.webp' -o -name '*.png' -o -name '*.jpg' \) -exec cp {} "$DEST/ui/menu/cinematic/" \;
  find "$DEST/ui/menu/cinematic" -maxdepth 1 -type f \( -name '*.webp' -o -name '*.png' -o -name '*.jpg' \) -printf 'cinematic/%f\n' | sort > "$DEST/ui/menu/index.txt"
  : > "$DEST/ui/menu/.gdignore"
  : > "$DEST/ui/menu/cinematic/.gdignore"
fi
if [ -n "$VIDEO_SRC" ]; then
  if [ ! -d "$VIDEO_SRC" ]; then
    echo "finish_web_export: video source is not a directory"
    exit 1
  fi
  mkdir -p "$DEST/ui/menu/video/bed"
  find "$VIDEO_SRC" -maxdepth 1 -type f \( -name '*.ogv' -o -name '*.webm' -o -name '*.mp4' -o -name '*.webp' \) -exec cp {} "$DEST/ui/menu/video/" \;
  if [ -d "$VIDEO_SRC/bed" ]; then
    find "$VIDEO_SRC/bed" -maxdepth 1 -type f -name '*.ogg' -exec cp {} "$DEST/ui/menu/video/bed/" \;
  fi
  : > "$DEST/ui/menu/video/.gdignore"
  if [ ! -f "$DEST/ui/menu/video/main-menu-loop.ogv" ] && [ ! -f "$DEST/ui/menu/video/main-menu-loop.webm" ] && [ ! -f "$DEST/ui/menu/video/gtfc.ogv" ]; then
    echo "finish_web_export: video folder has no menu loop"
    exit 1
  fi
fi
if [ -n "$KEY_ART_SRC" ]; then
  if [ ! -d "$KEY_ART_SRC" ]; then
    echo "finish_web_export: key-art source is not a directory"
    exit 1
  fi
  if [ -d "$KEY_ART_SRC/backgrounds" ]; then
    mkdir -p "$DEST/ui/menu/cinematic"
    find "$KEY_ART_SRC/backgrounds" -maxdepth 1 -type f \( -name '*.webp' -o -name '*.png' -o -name '*.jpg' \) -exec cp {} "$DEST/ui/menu/cinematic/" \;
    find "$DEST/ui/menu/cinematic" -maxdepth 1 -type f \( -name '*.webp' -o -name '*.png' -o -name '*.jpg' \) -printf 'cinematic/%f\n' | sort > "$DEST/ui/menu/index.txt"
    : > "$DEST/ui/menu/.gdignore"
    : > "$DEST/ui/menu/cinematic/.gdignore"
  fi
  if [ -d "$KEY_ART_SRC/video" ]; then
    mkdir -p "$DEST/ui/menu/video"
    find "$KEY_ART_SRC/video" -maxdepth 1 -type f \( -name '*.ogv' -o -name '*.webm' -o -name '*.mp4' -o -name '*.webp' \) -exec cp {} "$DEST/ui/menu/video/" \;
    : > "$DEST/ui/menu/video/.gdignore"
  fi
  if [ -d "$KEY_ART_SRC/splash" ]; then
    mkdir -p "$DEST/splash"
    find "$KEY_ART_SRC/splash" -maxdepth 1 -type f \( -name '*.webp' -o -name '*.png' \) -exec cp {} "$DEST/splash/" \;
    : > "$DEST/splash/.gdignore"
  fi
  if [ -d "$KEY_ART_SRC/wordmark" ]; then
    mkdir -p "$DEST/wordmark"
    find "$KEY_ART_SRC/wordmark" -maxdepth 1 -type f \( -name '*.png' -o -name '*.svg' \) -exec cp {} "$DEST/wordmark/" \;
    : > "$DEST/wordmark/.gdignore"
  fi
fi
if [ -n "$MODEL_SRC" ]; then
  if [ ! -d "$MODEL_SRC" ]; then
    echo "finish_web_export: model source is not a directory"
    exit 1
  fi
  mkdir -p "$DEST/models"
  find "$MODEL_SRC" -maxdepth 1 -type f \( -name '*.glb' -o -name '*.gltf' \) -exec cp {} "$DEST/models/" \;
  if [ -n "$TRIPO_SRC" ]; then
    if [ ! -d "$TRIPO_SRC" ]; then
      echo "finish_web_export: tripo source is not a directory"
      exit 1
    fi
    find "$TRIPO_SRC" -maxdepth 1 -type f -name '*.glb' -exec cp {} "$DEST/models/" \;
  fi
  # Rigged units (idle, walk, run, shoot, die, flinch, ability clips) are listed as rigged/<id>.glb.
  RIGGED_SRC="${RIGGED_SRC:-$MODEL_SRC/rigged}"
  if [ ! -d "$RIGGED_SRC" ] && [ -d "$ROOT/game/models/rigged" ]; then
    RIGGED_SRC="$ROOT/game/models/rigged"
  fi
  if [ -d "$RIGGED_SRC" ]; then
    mkdir -p "$DEST/models/rigged"
    find "$RIGGED_SRC" -maxdepth 1 -type f -name '*.glb' -exec cp {} "$DEST/models/rigged/" \;
  fi
  {
    find "$DEST/models" -maxdepth 1 -type f \( -name '*.glb' -o -name '*.gltf' \) -printf '%f\n'
    if [ -d "$DEST/models/rigged" ]; then
      find "$DEST/models/rigged" -maxdepth 1 -type f -name '*.glb' -printf 'rigged/%f\n'
    fi
  } | sort > "$DEST/models/index.txt"
  if [ -d "$ROOT/game/models/rigged" ] && ! grep -qx "rigged/militia.glb" "$DEST/models/index.txt"; then
    echo "finish_web_export: rigged models are missing from models/index.txt"
    exit 1
  fi
  : > "$DEST/models/.gdignore"
  if [ -f "$MODEL_SRC/CREDITS.md" ]; then
    cp "$MODEL_SRC/CREDITS.md" "$DEST/models/CREDITS.md"
  fi
fi
if [ -d "$ROOT/game/models/env" ]; then
  mkdir -p "$DEST/models/env"
  find "$ROOT/game/models/env" -maxdepth 1 -type f -name '*.glb' -exec cp {} "$DEST/models/env/" \;
  find "$DEST/models/env" -maxdepth 1 -type f -name '*.glb' -printf '%f\n' | sort > "$DEST/models/env/index.txt"
  : > "$DEST/models/env/.gdignore"
fi
if [ -n "$BRIEFINGS_SRC" ]; then
  if [ ! -d "$BRIEFINGS_SRC" ]; then
    echo "finish_web_export: briefings source is not a directory"
    exit 1
  fi
  mkdir -p "$DEST/briefings"
  find "$BRIEFINGS_SRC" -maxdepth 1 -type f -name '*.webp' -exec cp {} "$DEST/briefings/" \;
  : > "$DEST/briefings/.gdignore"
fi
if [ -n "$TERRAIN_SRC" ]; then
  if [ ! -d "$TERRAIN_SRC" ]; then
    echo "finish_web_export: terrain source is not a directory"
    exit 1
  fi
  mkdir -p "$DEST/terrain"
  find "$TERRAIN_SRC" -maxdepth 1 -type f -name '*.webp' -exec cp {} "$DEST/terrain/" \;
  : > "$DEST/terrain/.gdignore"
fi
if [ -n "$UI_SRC" ]; then
  if [ ! -d "$UI_SRC/frames" ] || [ ! -d "$UI_SRC/icons" ]; then
    echo "finish_web_export: ui source needs frames and icons"
    exit 1
  fi
  mkdir -p "$DEST/ui/frames" "$DEST/ui/icons"
  find "$UI_SRC/frames" -maxdepth 1 -type f -name '*.webp' -exec cp {} "$DEST/ui/frames/" \;
  find "$UI_SRC/icons" -maxdepth 1 -type f -name '*.webp' -exec cp {} "$DEST/ui/icons/" \;
  : > "$DEST/ui/frames/.gdignore"
  : > "$DEST/ui/icons/.gdignore"
fi
if ! grep -q "brotli" "$DEST/brotli_host.conf" || ! grep -q "wasm" "$DEST/brotli_host.conf"; then
  echo "finish_web_export: brotli host config is missing"
  exit 1
fi
if ! grep -q "GODOT_THREADS_ENABLED = false" "$DEST/index.html"; then
  echo "finish_web_export: export is not single-threaded"
  exit 1
fi
for f in index.html index.wasm index.pck index.manifest.json sw.js manifest.webmanifest brotli_host.conf audio_unlock.js; do
  if [ ! -f "$DEST/$f" ]; then
    echo "finish_web_export: missing $f"
    exit 1
  fi
done
echo "web export files:"
ls -la "$DEST"

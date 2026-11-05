#!/usr/bin/env bash
# Rebuild the Noto fallback subsets in localization/fonts/ from the upstream fonts.
# Burmese and Thai keep their whole script block. Chinese keeps only the
# characters zh.po uses, plus CJK punctuation. Needs fonttools (pip install fonttools).
set -eu
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CACHE="${NOTO_CACHE:-$ROOT/build/noto}"
OUT="$ROOT/localization/fonts"
mkdir -p "$CACHE" "$OUT"
fetch() {
  [ -f "$CACHE/$2" ] || curl -sSL -o "$CACHE/$2" "$1"
}
fetch "https://github.com/notofonts/notofonts.github.io/raw/main/fonts/NotoSansMyanmar/hinted/ttf/NotoSansMyanmar-Regular.ttf" NotoSansMyanmar-Regular.ttf
fetch "https://github.com/notofonts/notofonts.github.io/raw/main/fonts/NotoSansThai/hinted/ttf/NotoSansThai-Regular.ttf" NotoSansThai-Regular.ttf
fetch "https://github.com/google/fonts/raw/main/ofl/notosanssc/NotoSansSC%5Bwght%5D.ttf" NotoSansSC-Variable.ttf
COMMON="U+0020-007E,U+00A0,U+00B7,U+200B-200D,U+2018-201D,U+2026,U+25CC"
pyftsubset "$CACHE/NotoSansMyanmar-Regular.ttf" --unicodes="$COMMON,U+1000-109F,U+AA60-AA7F,U+A9E0-A9FF" \
  --layout-features='*' --no-hinting --desubroutinize --output-file="$OUT/NotoSansMyanmar-Subset.ttf"
pyftsubset "$CACHE/NotoSansThai-Regular.ttf" --unicodes="$COMMON,U+0E00-0E7F" \
  --layout-features='*' --no-hinting --output-file="$OUT/NotoSansThai-Subset.ttf"
python3 - "$CACHE" "$OUT" "$ROOT/localization/game/zh.po" <<'PY'
import sys
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer
from fontTools import subset
cache, out, po = sys.argv[1:4]
chars = set(open(po, encoding="utf-8").read())
chars |= set(chr(c) for c in range(0x3000, 0x3040)) | set(chr(c) for c in range(0xFF01, 0xFF5F))
chars |= set("中文")
keep = "".join(sorted(c for c in chars if ord(c) >= 0x2E80))
font = instancer.instantiateVariableFont(TTFont(cache + "/NotoSansSC-Variable.ttf"), {"wght": 500})
opts = subset.Options()
opts.layout_features = ["*"]
opts.hinting = False
opts.desubroutinize = True
sub = subset.Subsetter(opts)
sub.populate(text=keep + "".join(chr(c) for c in range(0x20, 0x7F)))
sub.subset(font)
font.flavor = None
font.save(out + "/NotoSansSC-Subset.otf")
print("NotoSansSC-Subset.otf: %d CJK characters" % len(keep))
PY
ls -la "$OUT"

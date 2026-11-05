#!/usr/bin/env python3
"""Collect player-facing English strings into localization/game/en.po.

Sources: string literals in game/*.gd and the SM*/RTS* scripts, plus the
faction JSON display names. Node names, JS snippets, and debug-only scenes
are skipped. Existing en.po glosses (msgstr != msgid) are kept.

    python3 tools/loc/extract.py            # rewrite en.po
    python3 tools/loc/extract.py --check    # exit 1 when en.po is stale
"""
import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import po  # noqa: E402

SKIP_FILES = {
    "anim_pilot.gd", "anim_rollout.gd", "cameo_sweep.gd", "sm_bot.gd", "sm_save.gd",
    "model_registry.gd", "model_catalog.gd", "unit_motion.gd", "motion_fx.gd",
    "building_debris.gd", "building_fx.gd", "death_fx.gd", "env_dress.gd", "fx_view.gd",
    "off_hand_ik.gd", "unit_meshes.gd", "faction_mark.gd", "camera_fit.gd", "glass.gd",
    "hud_skin.gd", "menu_scrim.gd", "served_art.gd", "match_cameos.gd", "sm_web.gd",
    "rts_loc.gd", "sm_lang.gd", "font_faces.gd", "rts_bindings.gd",
}
CODE_MARKERS = ("(function", "window.", "console.log", "indexedDB", "res://", "user://", "audio context")
# Literal arguments of these calls are node names, metas, or ids, never shown.
ID_CALLS = re.compile(
    r"(?:get_node(?:_or_null)?|find_child|find_children|has_node|get_meta|set_meta|has_meta|remove_meta|"
    r"has_method|call|connect|is_action|get_bus_index|load|preload|begins_with|ends_with|contains|"
    r"has|find|get|erase|emit_signal|add_to_group|is_in_group|StringName|NodePath)\(\s*$"
)
STRING = re.compile(r'"((?:[^"\\]|\\.)*)"')
NAME_ASSIGN = re.compile(r"\.name\s*=\s*$|\bname\s*=\s*$|==\s*$|!=\s*$|\bin\s*$|^\s*(?:if|elif)\b.*\b(?:==|!=)\s*$")
FIRST_ARG_IS_NAME = re.compile(r"(?:_caption|_choice|_section|_page_tab|_slider|_button|_label|_chip|_card_line|_page_tab|_row|_cell)\(\s*$")


def unescape(s: str) -> str:
    out = []
    i = 0
    while i < len(s):
        c = s[i]
        if c == "\\" and i + 1 < len(s):
            n = s[i + 1]
            out.append({"n": "\n", "t": "\t", '"': '"', "\\": "\\", "'": "'"}.get(n, "\\" + n))
            i += 2
            continue
        out.append(c)
        i += 1
    return "".join(out)


def looks_like_text(v: str) -> bool:
    if not re.search(r"[A-Za-z]{2,}", v):
        return False
    if any(m in v for m in CODE_MARKERS):
        return False
    if re.fullmatch(r"[A-Za-z0-9_%*/.]+", v):
        # Single tokens: node names (CamelCase, snake_case, paths) are ids.
        if "_" in v or "/" in v or "." in v or "*" in v:
            return False
        if re.search(r"[a-z][A-Z]", v) or re.search(r"[A-Z]{2,}[a-z]", v):
            return False
        if v.islower() and len(v) > 1:
            return False
        return v[0].isupper()
    if re.fullmatch(r"[a-z0-9_]+:[a-z0-9_:]+", v) or re.fullmatch(r"#[0-9A-Fa-f]{6,8}", v):
        return False
    if v.startswith("%s_") or v.endswith("_"):
        return False
    return True


def from_scripts() -> dict:
    found: dict = {}
    files = sorted(glob.glob(os.path.join(ROOT, "game", "*.gd")) + glob.glob(os.path.join(ROOT, "addons", "rts_advanced", "*.gd")))
    for path in files:
        base = os.path.basename(path)
        if base in SKIP_FILES:
            continue
        rel = os.path.relpath(path, ROOT)
        for no, line in enumerate(open(path, encoding="utf-8"), 1):
            stripped = line.strip()
            if stripped.startswith("#") or stripped.startswith("##"):
                continue
            for m in STRING.finditer(line):
                head = line[: m.start()]
                if head.rstrip().endswith("&") or head.rstrip().endswith("^") or head.endswith("&") or head.endswith("^"):
                    continue
                if ID_CALLS.search(head) or NAME_ASSIGN.search(head) or FIRST_ARG_IS_NAME.search(head):
                    continue
                v = unescape(m.group(1))
                if not looks_like_text(v):
                    continue
                found.setdefault(v, []).append("%s:%d" % (rel, no))
    return found


def from_factions() -> dict:
    found: dict = {}
    for path in sorted(glob.glob(os.path.join(ROOT, "data", "factions", "*", "faction.json"))):
        rel = os.path.relpath(path, ROOT)
        data = json.load(open(path, encoding="utf-8"))

        def add(v):
            if isinstance(v, str) and looks_like_text(v):
                found.setdefault(v, []).append(rel)

        add(data.get("display_name"))
        for row in data.get("buildings", []) + data.get("units", []):
            add(row.get("display_name"))
            add(row.get("ability"))
        if isinstance(data.get("superweapon"), dict):
            add(data["superweapon"].get("display_name"))
        for res in data.get("storefront_resources", []):
            add(res if isinstance(res, str) else res.get("display_name") if isinstance(res, dict) else None)
    return found


def extra() -> dict:
    path = os.path.join(ROOT, "localization", "game", "extra.txt")
    found: dict = {}
    if os.path.exists(path):
        for line in open(path, encoding="utf-8"):
            line = line.rstrip("\n")
            if line and not line.startswith("#"):
                found.setdefault(unescape(line), []).append("localization/game/extra.txt")
    return found


def collect() -> dict:
    merged: dict = {}
    for src in (from_scripts(), from_factions(), extra()):
        for k, v in src.items():
            merged.setdefault(k, []).extend(v)
    ignore_path = os.path.join(ROOT, "localization", "game", "ignore.txt")
    if os.path.exists(ignore_path):
        for line in open(ignore_path, encoding="utf-8"):
            line = line.rstrip("\n")
            if line and not line.startswith("#"):
                merged.pop(unescape(line), None)
    return merged


def main() -> int:
    found = collect()
    en_path = os.path.join(ROOT, "localization", "game", "en.po")
    old = po.read(en_path) if os.path.exists(en_path) else {}
    entries = []
    for msgid in sorted(found, key=lambda s: (s.lower(), s)):
        gloss = old.get(msgid, {}).get("msgstr", "") or msgid
        entries.append({"msgid": msgid, "msgstr": gloss, "refs": found[msgid][:1]})
    if "--check" in sys.argv:
        stale = set(found) ^ set(old)
        if stale:
            for s in sorted(stale)[:40]:
                print("stale:", repr(s)[:120])
            return 1
        return 0
    po.write(en_path, "en", entries)
    print("en.po: %d messages" % len(entries))
    return 0


if __name__ == "__main__":
    sys.exit(main())

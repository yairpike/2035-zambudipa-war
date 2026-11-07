#!/usr/bin/env python3
"""Fill localization/game/{my,zh,th,ms}.po from en.po with Gemini.

Needs GEMINI_API_KEY. Only missing or placeholder-broken entries are sent,
so hand fixes in a .po file survive a rerun.

    python3 tools/loc/translate.py [--lang my] [--model gemini-3.1-pro-preview]
"""
import concurrent.futures
import json
import os
import re
import sys
import time
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import po  # noqa: E402

LANGS = {
    "my": "Burmese (Myanmar script, Unicode, not Zawgyi)",
    "zh": "Mandarin Chinese (Simplified characters)",
    "th": "Thai",
    "ms": "Malay (Bahasa Melayu, Malaysia)",
}
# Thai and Burmese do not put spaces between words. The model marks word
# boundaries with "|", which becomes U+200B so long lines can wrap.
ZWSP_LANGS = {"my", "th"}
PLACEHOLDER = re.compile(r"%(?:\.\d+)?[sdf]|%%")
BATCH = 50

RULES = """You translate the user interface of ASEAN 2031, a near-future real-time strategy game
set in Southeast Asia (Myanmar, Thailand, Laos, Malaysia, Indonesia, Vietnam, Cambodia, the Philippines).
Tone: terse military radio and RTS interface text, like Red Alert 3. Keep labels short.

Rules:
- Translate into {lang}. Every output must be in that language's own script.
- Keep printf placeholders exactly: %s, %d, %ds, %.1f and so on. Keep the same placeholders in the
  same order. You may move words around them, but never drop, add, or reorder placeholders.
- Keep line breaks (\\n) where the source has them, and keep leading or trailing spaces.
- Keep these as written, in Latin letters: faction codes GTFC, NMRF, MVD; ASEAN 2031; aircraft and
  drone models (CH-4, Su-30, Orlan-10, FLH7, FPV, UAV); acronyms EW, GPS, HP, IFV, EMP, RPG, C4, LAN,
  CC0, MIT, WebRTC, SFX, HUD; keyboard keys (Q, X, Z, F, H, P, E, R, N, Ctrl, Shift, Tab, Esc, Space,
  Enter, 1-9); URLs and file paths; IP addresses.
- Song titles by the artist BlackBloc stay exactly as written: Yangonite, Supayarlat, Ready To Rage
  Against The Abnormalities, Past Cracks, Machinesfuture, Humanfuture, Night, Love Drunk, Changes,
  Not Needed Anymore, Poison, Time. A message that is only one of these titles stays unchanged.
- Place names (Kokang, Mogok, Tachileik, Shwe Kokko, Andaman, Patani, Pakbeng, Keng Tung, Plain of Jars,
  Tonle Sap, Mekong, Salween, Irrawaddy, Chiang Rai, Sop Ruak, Mae Sai, Burma Road, Phillips Channel,
  Malacca, Johor, Sulu, Aceh, Sumatra, Riau, Mindanao, Krakatoa, Saigon, Cu Chi, Ha Long, Tonkin...)
  use the usual exonym or transliteration in the target script.
- Character names (Bo Mya, Colonel Nguyen, Siti, Iskandar, Tran) are transliterated into the target script.
- Invented unit, building and ability names are translated by meaning, not transliterated, so a player
  who reads only {lang} understands them.
- Status lines in lower case (for example "low power", "build blocked") are short alerts. Translate them
  as short alerts.
{zwsp}
Return JSON only: an object mapping each input id to its translation."""

ZWSP_RULE = "- Put a '|' between words (word boundaries only, never inside a word) so the game can wrap lines.\n  Do not put '|' next to placeholders or around Latin words."


def call(model: str, lang: str, batch: dict) -> dict:
    key = os.environ["GEMINI_API_KEY"]
    url = "https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent?key=%s" % (model, key)
    prompt = RULES.format(lang=LANGS[lang], zwsp=ZWSP_RULE if lang in ZWSP_LANGS else "")
    body = {
        "systemInstruction": {"parts": [{"text": prompt}]},
        "contents": [{"role": "user", "parts": [{"text": json.dumps(batch, ensure_ascii=False, indent=0)}]}],
        "generationConfig": {"responseMimeType": "application/json", "temperature": 0.2},
    }
    data = json.dumps(body).encode("utf-8")
    for attempt in range(5):
        try:
            req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})
            with urllib.request.urlopen(req, timeout=300) as resp:
                out = json.loads(resp.read().decode("utf-8"))
            text = "".join(p.get("text", "") for p in out["candidates"][0]["content"]["parts"])
            return json.loads(text)
        except Exception as exc:  # noqa: BLE001
            print("  %s retry %d: %s" % (lang, attempt + 1, str(exc)[:160]), flush=True)
            time.sleep(4 * (2 ** attempt))
    return {}


def placeholders(s: str) -> list:
    return PLACEHOLDER.findall(s)


def clean(lang: str, src: str, out: str) -> str:
    out = out.replace("\u200b", "|") if lang in ZWSP_LANGS else out
    if lang in ZWSP_LANGS:
        out = re.sub(r"\s*\|\s*", lambda m: " " if " " in m.group(0) else "\u200b", out)
        out = out.strip("\u200b")
    lead = src[: len(src) - len(src.lstrip(" "))]
    tail = src[len(src.rstrip(" ")):]
    return lead + out.strip(" ") + tail


def good(src: str, out: str) -> bool:
    return bool(out.strip()) and placeholders(src) == placeholders(out) and src.count("\n") == out.count("\n")


def run_lang(lang: str, model: str, en: dict) -> None:
    path = os.path.join(ROOT, "localization", "game", "%s.po" % lang)
    have = po.read(path) if os.path.exists(path) else {}
    keep = {k: v["msgstr"] for k, v in have.items() if k in en and good(k, v["msgstr"])}
    todo = [k for k in en if k not in keep]
    print("%s: %d kept, %d to translate" % (lang, len(keep), len(todo)), flush=True)
    for round_no in range(3):
        if not todo:
            break
        batches = [todo[i:i + BATCH] for i in range(0, len(todo), BATCH)]
        with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
            jobs = {pool.submit(call, model, lang, {str(i): en[s] for i, s in enumerate(b)}): b for b in batches}
            for job in concurrent.futures.as_completed(jobs):
                b = jobs[job]
                got = job.result()
                for i, src in enumerate(b):
                    raw = got.get(str(i))
                    if isinstance(raw, str):
                        out = clean(lang, en[src], raw)
                        if good(src, out):
                            keep[src] = out
        todo = [k for k in en if k not in keep]
        print("%s: round %d left %d" % (lang, round_no + 1, len(todo)), flush=True)
    entries = [{"msgid": k, "msgstr": keep.get(k, ""), "refs": []} for k in en]
    po.write(path, lang, entries)
    if todo:
        print("%s: %d still missing" % (lang, len(todo)))


def main() -> int:
    model = "gemini-3.1-pro-preview"
    langs = list(LANGS)
    args = sys.argv[1:]
    if "--model" in args:
        model = args[args.index("--model") + 1]
    if "--lang" in args:
        langs = [args[args.index("--lang") + 1]]
    en_all = po.read(os.path.join(ROOT, "localization", "game", "en.po"))
    # Translate the English the player sees, so glossed lines carry the gloss.
    en = {k: (v["msgstr"] or k) for k, v in en_all.items()}
    with concurrent.futures.ThreadPoolExecutor(max_workers=len(langs)) as pool:
        list(pool.map(lambda l: run_lang(l, model, en), langs))
    return 0


if __name__ == "__main__":
    sys.exit(main())

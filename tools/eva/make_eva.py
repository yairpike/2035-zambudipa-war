#!/usr/bin/env python3
"""Synthesize the EVA command-AI voice clips into assets/voices/eva/<lang>/<key>.ogg.

Voices are Microsoft Edge neural TTS (pip install edge-tts): Singapore English for EVA, and the native
Burmese, Mandarin, Thai and Malay voices for the localized takes. Each take is band-limited and compressed
into a radio-net voice, then encoded as mono Ogg Vorbis. Mission openers say "Mission objective received."
followed by that mission's stage-one goal, read from the translated catalogs in localization/game/.

    python3 tools/eva/make_eva.py            # build every missing clip and rewrite manifest.json
    python3 tools/eva/make_eva.py --force    # rebuild every clip
"""
import asyncio
import json
import os
import re
import subprocess
import sys
import tempfile
import time

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "voices", "eva")
sys.path.insert(0, os.path.join(ROOT, "tools", "loc"))
import po  # noqa: E402

VOICES = {
    "en": "en-SG-LunaNeural",
    "my": "my-MM-NilarNeural",
    "zh": "zh-CN-XiaoxiaoNeural",
    "th": "th-TH-NiwatNeural",
    "ms": "ms-MY-YasminNeural",
}
FALLBACK = {
    "en": "en-SG-WayneNeural",
    "my": "my-MM-ThihaNeural",
    "zh": "zh-CN-YunyangNeural",
    "th": "th-TH-PremwadeeNeural",
    "ms": "ms-MY-OsmanNeural",
}
RADIO = "highpass=f=170,lowpass=f=6200,equalizer=f=2600:t=q:w=1.2:g=3,acompressor=threshold=-20dB:ratio=3:attack=5:release=80,loudnorm=I=-15:TP=-1.5:LRA=7,apad=pad_dur=0.08"

LINES = {
    "cannot_deploy": ["Cannot deploy here.", "ဒီနေရာမှာ မချထားနိုင်ပါ။", "此处无法部署。", "ไม่สามารถวางกำลังที่นี่ได้", "Tidak boleh dikerahkan di sini."],
    "naval_on_water": ["Naval structure must be placed on water.", "ရေတပ်အဆောက်အအုံကို ရေပြင်ပေါ်မှာသာ ထားရပါမယ်။", "海军建筑必须建在水上。", "สิ่งก่อสร้างทางเรือต้องวางบนน้ำ", "Struktur tentera laut mesti diletakkan di atas air."],
    "build_near_allied": ["Must build near an allied structure.", "မဟာမိတ်အဆောက်အအုံအနီးမှာသာ ဆောက်ရပါမယ်။", "必须在友军建筑附近建造。", "ต้องสร้างใกล้สิ่งก่อสร้างฝ่ายเดียวกัน", "Mesti membina berhampiran struktur sekutu."],
    "blocked_road_terrain": ["Blocked by road or terrain.", "လမ်း သို့မဟုတ် မြေပြင်ကြောင့် ပိတ်နေပါတယ်။", "被道路或地形阻挡。", "ถูกถนนหรือภูมิประเทศขวางไว้", "Dihalang oleh jalan atau rupa bumi."],
    "building": ["Building.", "တည်ဆောက်နေသည်။", "正在建造。", "กำลังก่อสร้าง", "Sedang membina."],
    "construction_complete": ["Construction complete.", "တည်ဆောက်မှု ပြီးဆုံးပါပြီ။", "建造完成。", "ก่อสร้างเสร็จสิ้น", "Pembinaan selesai."],
    "unit_ready": ["Unit ready.", "တပ်ဖွဲ့ အသင့်ဖြစ်ပါပြီ။", "部队就绪。", "หน่วยพร้อมแล้ว", "Unit sedia."],
    "training": ["Training.", "လေ့ကျင့်နေသည်။", "正在训练。", "กำลังฝึก", "Sedang melatih."],
    "insufficient_funds": ["Insufficient resources.", "အရင်းအမြစ် မလုံလောက်ပါ။", "资源不足。", "ทรัพยากรไม่เพียงพอ", "Sumber tidak mencukupi."],
    "base_under_attack": ["Base under attack!", "စခန်း တိုက်ခိုက်ခံနေရသည်!", "基地遭到攻击！", "ฐานกำลังถูกโจมตี!", "Pangkalan diserang!"],
    "ally_under_attack": ["Ally under attack!", "မဟာမိတ်တပ် တိုက်ခိုက်ခံနေရသည်!", "友军遭到攻击！", "พันธมิตรกำลังถูกโจมตี!", "Sekutu diserang!"],
    "structure_garrisoned": ["Structure garrisoned.", "အဆောက်အအုံထဲ တပ်နေရာယူပြီးပါပြီ။", "建筑已驻军。", "เข้าประจำการในอาคารแล้ว", "Struktur telah dikawal."],
    "secondary_weapon": ["Secondary weapon engaged.", "ဒုတိယ လက်နက် အသုံးပြုနေပါပြီ။", "副武器已启用。", "ใช้อาวุธรองแล้ว", "Senjata sekunder diaktifkan."],
    "primary_weapon": ["Primary weapon engaged.", "ပထမ လက်နက် အသုံးပြုနေပါပြီ။", "主武器已启用。", "ใช้อาวุธหลักแล้ว", "Senjata utama diaktifkan."],
    "objective_received": ["Mission objective received.", "တာဝန် ရည်မှန်းချက် ရရှိပါပြီ။", "已收到任务目标。", "ได้รับเป้าหมายภารกิจแล้ว", "Objektif misi diterima."],
    "new_objective": ["New objective received. Check your tactical map.", "ရည်မှန်းချက်အသစ် ရရှိပါပြီ။ စစ်ဆင်ရေးမြေပုံကို စစ်ဆေးပါ။", "收到新目标。请查看战术地图。", "ได้รับเป้าหมายใหม่ ตรวจสอบแผนที่ยุทธวิธี", "Objektif baharu diterima. Semak peta taktikal anda."],
    "primary_complete": ["Primary objective complete.", "အဓိက ရည်မှန်းချက် ပြီးမြောက်ပါပြီ။", "主要目标已完成。", "เป้าหมายหลักสำเร็จแล้ว", "Objektif utama selesai."],
    "bonus_reinforcements": ["Bonus objective achieved. Reinforcements inbound.", "ဆုလာဘ် ရည်မှန်းချက် အောင်မြင်ပါပြီ။ အကူအညီတပ် လာနေပါပြီ။", "奖励目标达成。增援正在赶来。", "ทำเป้าหมายโบนัสสำเร็จ กำลังเสริมกำลังมา", "Objektif bonus dicapai. Bala bantuan dalam perjalanan."],
    "bonus_achieved": ["Bonus objective achieved.", "ဆုလာဘ် ရည်မှန်းချက် အောင်မြင်ပါပြီ။", "奖励目标达成。", "ทำเป้าหมายโบนัสสำเร็จ", "Objektif bonus dicapai."],
    "bonus_lost": ["Bonus objective lost.", "ဆုလာဘ် ရည်မှန်းချက် လွတ်သွားပါပြီ။", "奖励目标失败。", "เป้าหมายโบนัสล้มเหลว", "Objektif bonus gagal."],
    "counter_attack": ["Warning: enemy counter-attack detected.", "သတိပေးချက်။ ရန်သူ့ တန်ပြန်တိုက်ခိုက်မှု တွေ့ရှိရသည်။", "警告：侦测到敌军反击。", "คำเตือน ตรวจพบการตีโต้ของศัตรู", "Amaran: serangan balas musuh dikesan."],
    "stage_two": ["Stage two: escalation underway.", "အဆင့် နှစ်။ တိုက်ပွဲ ပြင်းထန်လာနေပြီ။", "第二阶段：战事升级。", "ขั้นที่สอง การสู้รบทวีความรุนแรง", "Peringkat dua: pertempuran semakin memuncak."],
    "stage_three": ["Stage three: enemy command target located.", "အဆင့် သုံး။ ရန်သူ့ ကွပ်ကဲရေး ပစ်မှတ်ကို တွေ့ရှိပြီ။", "第三阶段：已定位敌军指挥目标。", "ขั้นที่สาม พบเป้าหมายกองบัญชาการศัตรูแล้ว", "Peringkat tiga: sasaran pemerintahan musuh dikesan."],
    "reinforcements_arrived": ["Allied reinforcements have arrived.", "မဟာမိတ် အကူအညီတပ် ရောက်ရှိလာပါပြီ။", "友军增援已抵达。", "กำลังเสริมฝ่ายพันธมิตรมาถึงแล้ว", "Bala bantuan sekutu telah tiba."],
    "wave_incoming": ["Warning: enemy assault wave approaching.", "သတိပေးချက်။ ရန်သူ့ တိုက်ခိုက်ရေးလှိုင်း ချဉ်းကပ်လာနေသည်။", "警告：敌军突击波次正在逼近。", "คำเตือน คลื่นจู่โจมของศัตรูกำลังเข้าใกล้", "Amaran: gelombang serangan musuh menghampiri."],
    "mission_accomplished": ["Mission accomplished.", "တာဝန် ပြီးမြောက်ပါပြီ။", "任务完成。", "ภารกิจสำเร็จ", "Misi berjaya."],
    "mission_failed": ["Mission failed.", "တာဝန် မအောင်မြင်ပါ။", "任务失败。", "ภารกิจล้มเหลว", "Misi gagal."],
    "unit_lost": ["Unit lost.", "တပ်ဖွဲ့ ဆုံးရှုံးသွားပြီ။", "部队阵亡。", "สูญเสียหน่วย", "Unit hilang."],
    "low_power": ["Low power.", "ဓာတ်အား နည်းနေသည်။", "电力不足。", "พลังงานต่ำ", "Kuasa rendah."],
    "building_captured": ["Building captured.", "အဆောက်အအုံ သိမ်းပိုက်ပြီးပါပြီ။", "建筑已占领。", "ยึดอาคารได้แล้ว", "Bangunan ditawan."],
    "superweapon_ready": ["Superweapon ready.", "စူပါလက်နက် အသင့်ဖြစ်ပြီ။", "超级武器就绪。", "อาวุธพิเศษพร้อมแล้ว", "Senjata super sedia."],
    "superweapon_launched": ["Superweapon launched.", "စူပါလက်နက် ပစ်လွှတ်ပြီ။", "超级武器已发射。", "ยิงอาวุธพิเศษแล้ว", "Senjata super dilancarkan."],
    "enemy_superweapon_detected": ["Warning: enemy superweapon detected.", "သတိပေးချက်။ ရန်သူ့ စူပါလက်နက် တွေ့ရှိရသည်။", "警告：侦测到敌方超级武器。", "คำเตือน ตรวจพบอาวุธพิเศษของศัตรู", "Amaran: senjata super musuh dikesan."],
}
LANGS = ["en", "my", "zh", "th", "ms"]


USED: dict = {}


def remember_voices() -> None:
    path = os.path.join(OUT, "manifest.json")
    if not os.path.exists(path):
        return
    old = json.load(open(path, encoding="utf-8"))
    for lang, rows in old.get("clips", {}).items():
        for key, row in rows.items():
            USED[(lang, key)] = row.get("voice", VOICES.get(lang, ""))


def mission_goals() -> dict:
    src = open(os.path.join(ROOT, "addons", "rts_advanced", "sm_stages.gd"), encoding="utf-8").read()
    found = re.findall(r'if id == "(\w+)":\n\s*(?:var arc: Dictionary = )?return _plan\("([^"]+)"|if id == "(\w+)":\n\s*var arc: Dictionary = _plan\("([^"]+)"', src)
    out = {}
    for a, b, c, d in found:
        out[a or c] = b or d
    return out


def mission_lines() -> dict:
    catalogs = {lang: po.read(os.path.join(ROOT, "localization", "game", "%s.po" % lang)) for lang in LANGS if lang != "en"}
    out = {}
    for mission, goal in mission_goals().items():
        row = []
        for i, lang in enumerate(LANGS):
            lead = LINES["objective_received"][i]
            text = goal
            if lang != "en":
                text = catalogs[lang].get(goal, {}).get("msgstr", "") or goal
            text = text.replace("\u200b", "")
            stop = "" if lang in ("th",) else ("。" if lang == "zh" else ("။" if lang == "my" else "."))
            row.append("%s %s%s" % (lead, text, stop))
        out["mission_" + mission] = row
    return out


async def speak(text: str, voice: str, mp3: str) -> None:
    import edge_tts
    await edge_tts.Communicate(text, voice, rate="+4%", pitch="-3Hz").save(mp3)


def build(key: str, lang: str, text: str, force: bool) -> dict:
    folder = os.path.join(OUT, lang)
    os.makedirs(folder, exist_ok=True)
    ogg = os.path.join(folder, key + ".ogg")
    used = VOICES[lang]
    if force or not os.path.exists(ogg):
        with tempfile.TemporaryDirectory() as tmp:
            mp3 = os.path.join(tmp, "take.mp3")
            for attempt in range(6):
                used = VOICES[lang] if attempt < 2 else FALLBACK[lang]
                try:
                    asyncio.run(speak(text, used, mp3))
                    break
                except Exception:
                    if attempt == 5:
                        raise
                    time.sleep(2.0 * (attempt + 1))
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", mp3, "-af", RADIO, "-ac", "1", "-ar", "24000",
                            "-c:a", "libvorbis", "-q:a", "2", ogg], check=True)
        USED[(lang, key)] = used
    seconds = float(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", ogg],
                                   capture_output=True, text=True).stdout.strip() or 0.0)
    used = USED.get((lang, key), used)
    return {"file": "%s/%s.ogg" % (lang, key), "text": text, "voice": used, "seconds": round(seconds, 2)}


def main() -> None:
    force = "--force" in sys.argv
    if not force:
        remember_voices()
    table = dict(LINES)
    table.update(mission_lines())
    clips = {lang: {} for lang in LANGS}
    for key, row in table.items():
        for i, lang in enumerate(LANGS):
            clips[lang][key] = build(key, lang, row[i], force)
        print(key)
    manifest = {
        "kind": "eva",
        "path_pattern": "assets/voices/eva/<lang>/<key>.ogg",
        "source": "Microsoft Edge neural text-to-speech via edge-tts, radio-net processed with ffmpeg (tools/eva/make_eva.py)",
        "voices": VOICES,
        "keys": {k: v[0] for k, v in table.items()},
        "clips": clips,
    }
    with open(os.path.join(OUT, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=1)
        f.write("\n")


if __name__ == "__main__":
    main()

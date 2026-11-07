"""Regenerate the three briefing stills with Gemini, using model-rendered cutouts as unit references.

python3 tools/brand/gen_briefing_stills.py <briefings_dir> <cameos_dir> <out_dir> [mission ...]
  briefings_dir: the current stills (<mission>.webp), sent as the composition reference
  cameos_dir:    media/cameos (uses <faction>/cutout/<id>.png)
Needs GEMINI_API_KEY. Writes <out_dir>/<mission>.webp (1280x720), <mission>.png and log.json.
"""
import base64, io, json, os, sys, urllib.request
from PIL import Image

API = "https://generativelanguage.googleapis.com/v1beta"
MODELS = ["gemini-3-pro-image", "gemini-3-pro-image-preview"]

RULES = ("Live-action cinematic RTS mission briefing still, 16:9, 35mm lens, painted-photoreal look, two officers looking "
         "into the camera as if addressing a field commander over a video link. "
         "Every person is Southeast Asian, with natural, dignified, realistic faces, no caricature. "
         "No text, letters, numbers, logos, flags, insignia, patches or emblems anywhere, including on screens and maps. "
         "No drug imagery. Any vehicle, drone or boat that appears must copy the reference model images exactly: same "
         "shape, colours and panel layout. The reference models are shown on transparent backgrounds; place them naturally in the scene. ")

MISSIONS = {
    "kokang": dict(faction="gtfc", refs=[("gtfc", "ruby_mortar"), ("gtfc", "fpv_kamikaze"), ("gtfc", "amber_welder")], prompt=(
        "Image 1 is the old frame: keep its setting, camera framing and warm lighting, but recast the people and replace the drones. "
        "Setting: a Shan State karst mountain bunker with timber beams, a glowing amber holographic terrain map of the Mekong river "
        "and mountain roads on the table, crates of gold bullion bars and raw green jade stones. "
        "Cast: a battle-hardened 55-year-old Shan Burmese general, Southeast Asian man, leaning over the table; his uniform copies "
        "image 2: olive field jacket with large crimson panels and amber-gold trim, a crimson scarf. Beside him a 30-year-old Kachin "
        "intelligence officer, Southeast Asian woman, in an olive shirt with a crimson scarf, holding a rugged tablet. "
        "On the workbenches behind them: two FPV strike drones exactly like image 3 and one hexacopter exactly like image 4. "
        "The holographic map is pure terrain with glowing lines only: no labels, no words, no place names. "
        "Warm tungsten light with a crimson rim.")),
    "ghosts_of_patani": dict(faction="nmrf", refs=[("nmrf", "river_rifle"), ("nmrf", "emerald_gunboat"), ("nmrf", "emerald_ferry")], prompt=(
        "Image 1 is the old frame: keep its setting, camera framing and dusk lighting, but recast the people and replace the ships outside. "
        "Setting: the glass bridge of a stealth command trimaran in the Strait of Malacca at dusk, rain-streaked windows, lightning, "
        "a floating emerald holographic map of a mangrove coastline between the officers. "
        "Cast: an intense 45-year-old Malay naval admiral, Southeast Asian man, in a dark naval-grey coat with emerald panels and a thin "
        "gold songket trim band, a folded tengkolok head cloth; beside him a 30-year-old Bugis liaison officer, Southeast Asian woman, in "
        "an olive tactical vest over an emerald shirt, matching the kit colours of image 2. "
        "Through the windows on the dark sea: the armoured warship exactly like image 3 and the trimaran exactly like image 4, "
        "lit by lightning. Cool dusk light with an emerald rim.")),
    "fog_over_pakbeng": dict(faction="mvd", use_old=False, refs=[("mvd", "clearance_engineer"), ("mvd", "mekong_uav"), ("mvd", "cyan_ifv")], prompt=(
        "Image 1 is only a placeholder; ignore it. Medium shot, the director centred behind a glass console, the major standing at his "
        "right, both looking into the camera. "
        "Setting: a subterranean command centre with brutalist concrete arches, cyan satellite screens showing fog-shrouded Mekong "
        "river gorges in northern Laos. "
        "Cast, both clearly Vietnamese with East and Southeast Asian features, black hair: a razor-sharp 50-year-old Vietnamese director, man, seated at a glass console, in a charcoal uniform "
        "with electric-cyan piping and angular armour tabs like image 2; beside him a 35-year-old Vietnamese major, "
        "woman with her black hair tied back, in the same charcoal and cyan uniform with a tactical comms headset. No patches or badges. "
        "One wall screen shows the drone exactly like image 3 flying over the fog; a small glowing holographic model of the tank exactly "
        "like image 4 stands on the console. The console glass shows only abstract glowing terrain lines, no characters. Cool cyan light with a warm lacquer-red accent lamp.")),
}


def b64(img, fmt="PNG"):
    buf = io.BytesIO(); img.save(buf, fmt); return base64.b64encode(buf.getvalue()).decode()


def call(model, parts):
    body = {"contents": [{"parts": parts}],
            "generationConfig": {"responseModalities": ["IMAGE"], "imageConfig": {"aspectRatio": "16:9"}}}
    req = urllib.request.Request(f"{API}/models/{model}:generateContent", data=json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json", "x-goog-api-key": os.environ["GEMINI_API_KEY"]})
    r = json.load(urllib.request.urlopen(req, timeout=300))
    for p in r["candidates"][0]["content"]["parts"]:
        if "inlineData" in p:
            return Image.open(io.BytesIO(base64.b64decode(p["inlineData"]["data"]))), r.get("usageMetadata", {})
    raise RuntimeError("no image in response")


def main():
    brief, cameos, out = sys.argv[1:4]
    only = sys.argv[4:] or list(MISSIONS)
    os.makedirs(out, exist_ok=True)
    log_path = os.path.join(out, "log.json")
    log = json.load(open(log_path)) if os.path.exists(log_path) else {}
    for mid in only:
        m = MISSIONS[mid]
        old = Image.open(os.path.join(brief, mid + ".webp")).convert("RGB")
        if not m.get("use_old", True):
            old = Image.new("RGB", (640, 360), (20, 26, 30))
        parts = [{"text": RULES + m["prompt"]}, {"inlineData": {"mimeType": "image/jpeg", "data": b64(old, "JPEG")}}]
        for fac, uid in m["refs"]:
            cut = Image.open(os.path.join(cameos, fac, "cutout", uid + ".png")).convert("RGBA")
            plate = Image.new("RGBA", cut.size, (128, 128, 128, 255)); plate.alpha_composite(cut)
            parts.append({"inlineData": {"mimeType": "image/png", "data": b64(plate.convert("RGB"))}})
        for model in MODELS:
            try:
                img, usage = call(model, parts)
                break
            except Exception as e:
                print(mid, model, "failed", repr(e)[:200], flush=True)
        else:
            continue
        img = img.convert("RGB").resize((1280, 720), Image.LANCZOS)
        img.save(os.path.join(out, mid + ".webp"), quality=88, method=6)
        img.save(os.path.join(out, mid + ".png"), optimize=True)
        log.setdefault(mid, []).append({"model": model, "prompt": RULES + m["prompt"], "refs": m["refs"], "usage": usage})
        json.dump(log, open(log_path, "w"), indent=1)
        print(mid, model, "ok", usage, flush=True)


if __name__ == "__main__":
    main()

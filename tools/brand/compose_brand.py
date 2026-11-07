"""Build the app icon set, favicon and boot splash from Blender renders of the models and the faction logos.

python3 tools/brand/compose_brand.py <icon_render.png> <small_mark_cutout.png> <splash_render.png> <preview_dir>
  icon_render:   render_scene.py output, 1024 square, transparent (three hero units)
  small_mark:    a single cameo cutout (media/cameos/gtfc/cutout/amber_tank.png) used for 48 px and below
  splash_render: render_scene.py output, 1920x1080, transparent
Writes brand/*.png, brand/icon.ico, web/favicon.ico and icon.png in the repo, plus previews.
"""
import os, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BRAND = os.path.join(ROOT, "brand")
FONT = os.path.join(ROOT, "assets/fonts/OperationNapalm-Regular.ttf")
LOGOS = os.path.join(ROOT, "ui/logos")
BG = (18, 20, 24)
CRIMSON, EMERALD, CYAN, AMBER = (184, 30, 45), (31, 158, 102), (38, 191, 209), (224, 161, 6)


def glow(size, color, centre, radius, alpha):
    layer = Image.new("RGBA", size, color + (0,))
    m = Image.new("L", size, 0)
    x, y = centre
    ImageDraw.Draw(m).ellipse((x - radius, y - radius, x + radius, y + radius), fill=alpha)
    layer.putalpha(m.filter(ImageFilter.GaussianBlur(radius * 0.6)))
    return layer


def plate(n):
    """Rounded square in charcoal with crimson, emerald and cyan glows and a three-colour rim."""
    im = Image.new("RGBA", (n, n), BG + (255,))
    im.alpha_composite(glow((n, n), CRIMSON, (n * 0.5, n * 0.95), n * 0.55, 150))
    im.alpha_composite(glow((n, n), EMERALD, (n * 0.05, n * 0.15), n * 0.45, 110))
    im.alpha_composite(glow((n, n), CYAN, (n * 0.98, n * 0.2), n * 0.45, 110))
    vign = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    ImageDraw.Draw(vign).rectangle((0, 0, n, n), outline=(0, 0, 0, 160), width=int(n * 0.12))
    im.alpha_composite(vign.filter(ImageFilter.GaussianBlur(n * 0.08)))
    return im


def rim(n, width):
    lay = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    r = int(n * 0.2); w = max(1, int(width)); h = w // 2
    box = (h, h, n - 1 - h, n - 1 - h)
    d.rounded_rectangle(box, r, outline=AMBER + (255,), width=w)
    # Tint the rim: emerald top-left, cyan top-right, crimson bottom.
    tint = Image.new("RGBA", (n, n))
    td = ImageDraw.Draw(tint)
    td.rectangle((0, 0, n // 2, n * 0.55), fill=EMERALD + (255,))
    td.rectangle((n // 2, 0, n, n * 0.55), fill=CYAN + (255,))
    td.rectangle((0, n * 0.55, n, n), fill=CRIMSON + (255,))
    tint.putalpha(lay.getchannel("A"))
    return tint


def round_mask(n):
    m = Image.new("L", (n * 4, n * 4), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, n * 4 - 1, n * 4 - 1), int(n * 0.8), fill=255)
    return m.resize((n, n), Image.LANCZOS)


def icon(render, n, scale, lift):
    im = plate(n)
    l, t, r, b = render.getchannel("A").point(lambda a: 255 if a > 160 else 0).getbbox()
    pad = int(0.08 * max(r - l, b - t))
    sub = Image.new("RGBA", (r - l + 2 * pad, b - t + 2 * pad), (0, 0, 0, 0))
    sub.alpha_composite(render.crop((max(0, l - pad), max(0, t - pad), min(render.width, r + pad), min(render.height, b + pad))),
                        (max(0, pad - l), max(0, pad - t)))
    k = n * scale / max(sub.width, sub.height)
    sub = sub.resize((int(sub.width * k), int(sub.height * k)), Image.LANCZOS)
    sh = Image.new("RGBA", sub.size, (0, 0, 0, 0)); sh.putalpha(sub.getchannel("A").point(lambda a: a * 0.6))
    x = (n - sub.width) // 2; y = (n - sub.height) // 2 - int(n * lift)
    im.alpha_composite(sh.filter(ImageFilter.GaussianBlur(n * 0.012)), (x, y + int(n * 0.01)))
    im.alpha_composite(sub, (x, y))
    im.alpha_composite(rim(n, n * 0.035))
    im.putalpha(round_mask(n))
    return im


def sharpen(im):
    rgb = im.convert("RGB").filter(ImageFilter.UnsharpMask(radius=0.6, percent=70, threshold=1))
    rgb.putalpha(im.getchannel("A")); return rgb


def splash(render):
    W, H = 1920, 1080
    im = Image.new("RGBA", (W, H), BG + (255,))
    im.alpha_composite(glow((W, H), CRIMSON, (W * 0.62, H * 0.9), H * 0.55, 120))
    im.alpha_composite(glow((W, H), EMERALD, (W * 0.95, H * 0.25), H * 0.45, 80))
    im.alpha_composite(glow((W, H), CYAN, (W * 0.35, H * 0.2), H * 0.45, 70))
    haze = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(haze).rectangle((0, int(H * 0.70), W, int(H * 0.76)), fill=(150, 160, 170, 40))
    im.alpha_composite(haze.filter(ImageFilter.GaussianBlur(40)))
    im.alpha_composite(render.resize((W, H), Image.LANCZOS))
    shade = Image.new("L", (W, H), 0)
    sd = ImageDraw.Draw(shade)
    for x in range(int(W * 0.55)):
        sd.line([(x, 0), (x, H)], fill=int(200 * (1 - x / (W * 0.55)) ** 1.5))
    dark = Image.new("RGBA", (W, H), BG + (255,)); dark.putalpha(shade)
    im.alpha_composite(dark)
    d = ImageDraw.Draw(im)
    title = ImageFont.truetype(FONT, 150)
    d.text((112, 330), "ASEAN 2031", font=title, fill=(242, 238, 228))
    d.rectangle((116, 505, 116 + 520, 511), fill=AMBER)
    sub = ImageFont.truetype(FONT, 34)
    d.text((116, 540), "THREE FRONTS. ONE MONSOON.", font=sub, fill=(200, 204, 210))
    x = 116
    for fid in ("gtfc", "nmrf", "mvd"):
        lg = Image.open(os.path.join(LOGOS, fid + ".webp")).convert("RGBA").resize((112, 112), Image.LANCZOS)
        im.alpha_composite(lg, (x, 640)); x += 140
    return im


def main():
    icon_render, mark_render, splash_render, preview = sys.argv[1:5]
    os.makedirs(BRAND, exist_ok=True); os.makedirs(preview, exist_ok=True)
    big = Image.open(icon_render).convert("RGBA")
    mark = Image.open(mark_render).convert("RGBA")
    master = icon(big, 1024, 0.90, -0.02)
    small = icon(mark, 256, 1.0, -0.02)
    master.save(os.path.join(BRAND, "app_icon.png"), optimize=True)
    out = {}
    for n in (512, 256, 180, 144, 128, 64):
        out[n] = sharpen(master.resize((n, n), Image.LANCZOS))
    for n in (48, 32, 24, 16):
        out[n] = sharpen(small.resize((n, n), Image.LANCZOS))
    out[512].save(os.path.join(BRAND, "pwa_512.png"), optimize=True)
    out[180].save(os.path.join(BRAND, "pwa_180.png"), optimize=True)
    out[144].save(os.path.join(BRAND, "pwa_144.png"), optimize=True)
    out[256].save(os.path.join(ROOT, "icon.png"), optimize=True)
    ico_sizes = [16, 24, 32, 48, 64, 128, 256]
    out[256].save(os.path.join(BRAND, "icon.ico"), sizes=[(n, n) for n in ico_sizes],
                  append_images=[out[n] for n in ico_sizes if n != 256])
    out[48].save(os.path.join(ROOT, "web", "favicon.ico"), sizes=[(16, 16), (32, 32), (48, 48)],
                 append_images=[out[16], out[32]])
    sp = splash(Image.open(splash_render).convert("RGBA")).convert("RGB")
    sp.save(os.path.join(BRAND, "boot_splash.png"), optimize=True)
    # Previews: every size on one sheet, plus the splash.
    sheet = Image.new("RGBA", (1760, 600), (40, 42, 46, 255))
    sheet.alpha_composite(master.resize((512, 512), Image.LANCZOS), (24, 44))
    x = 560
    for n in (256, 180, 144, 128, 64, 48, 32, 24, 16):
        sheet.alpha_composite(out[n], (x, 300 - n // 2 if n > 128 else 420 - n // 2))
        x += n + 16 if n > 64 else n + 24
    ImageDraw.Draw(sheet).text((24, 12), "App icon 1024 (left), then 256, 180, 144, 128, 64, 48, 32, 24, 16. 48 px and below use the Behemoth mark.",
                               font=ImageFont.truetype(FONT, 18), fill=(230, 230, 230))
    sheet.convert("RGB").save(os.path.join(preview, "app-icons.png"))
    sp.save(os.path.join(preview, "boot-splash.png"))
    print("brand written")


if __name__ == "__main__":
    main()

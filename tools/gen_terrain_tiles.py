#!/usr/bin/env python3
"""Tileable RTS ground tiles. Fine grain at isometric zoom; no giant clovers or shells."""
from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image

OUT = Path("game/terrain")
SIZE = 512


def wrap_hash(ix: np.ndarray, iy: np.ndarray, period: int) -> np.ndarray:
    ix = np.mod(ix, period)
    iy = np.mod(iy, period)
    n = ix.astype(np.int64) * 374761393 + iy.astype(np.int64) * 668265263
    n = np.bitwise_xor(n, np.right_shift(n, 13)) * 1274126177
    return (n & 2147483647).astype(np.float64) / 2147483647.0


def value_noise(x: np.ndarray, y: np.ndarray, period: int) -> np.ndarray:
    x0 = np.floor(x)
    y0 = np.floor(y)
    fx = x - x0
    fy = y - y0
    fx = fx * fx * (3.0 - 2.0 * fx)
    fy = fy * fy * (3.0 - 2.0 * fy)
    n00 = wrap_hash(x0, y0, period)
    n10 = wrap_hash(x0 + 1, y0, period)
    n01 = wrap_hash(x0, y0 + 1, period)
    n11 = wrap_hash(x0 + 1, y0 + 1, period)
    nx0 = n00 * (1.0 - fx) + n10 * fx
    nx1 = n01 * (1.0 - fx) + n11 * fx
    return nx0 * (1.0 - fy) + nx1 * fy


def fbm(size: int, scale: float, octaves: int = 5, seed: float = 0.0) -> np.ndarray:
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float64)
    total = np.zeros((size, size), dtype=np.float64)
    amp = 1.0
    freq = float(scale)
    norm = 0.0
    for octave in range(octaves):
        period = max(1, int(round(freq)))
        sx = (xx + seed * 19.0 + float(octave) * 13.0) * freq / float(size)
        sy = (yy + seed * 37.0 + float(octave) * 17.0) * freq / float(size)
        total += amp * value_noise(sx, sy, period)
        norm += amp
        amp *= 0.55
        freq *= 2.0
    return total / max(norm, 1e-6)


def grain(size: int, seed: float) -> np.ndarray:
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float64)
    return wrap_hash(xx + seed * 11.0, yy + seed * 23.0, size)


def lerp(a: np.ndarray, b: np.ndarray, t: np.ndarray) -> np.ndarray:
    t = np.clip(t, 0.0, 1.0)[..., None]
    return a * (1.0 - t) + b * t


def rgb(h: str) -> np.ndarray:
    h = h.lstrip("#")
    return np.array([int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)], dtype=np.float64)


def shade(base: np.ndarray, n: np.ndarray, lo: float, hi: float) -> np.ndarray:
    t = lo + n * (hi - lo)
    return np.clip(base[None, None, :] * t[..., None], 0, 255)


def save(name: str, pix: np.ndarray) -> None:
    img = Image.fromarray(np.clip(pix, 0, 255).astype(np.uint8), "RGB")
    path = OUT / f"{name}.webp"
    img.save(path, "WEBP", quality=86, method=6)
    print(f"wrote {path} {img.size}")


def grass() -> np.ndarray:
    n = fbm(SIZE, 18.0, 6, 1.1)
    clump = fbm(SIZE, 8.0, 4, 4.2)
    dirt = fbm(SIZE, 6.0, 4, 8.8)
    speckle = grain(SIZE, 3.3)
    green = rgb("3A5A2C")
    moss = rgb("5E7A3A")
    earth = rgb("6B5330")
    pix = shade(green, n, 0.72, 1.22)
    pix = lerp(pix, shade(moss, clump, 0.88, 1.12), clump * 0.45)
    pix = lerp(pix, shade(earth, dirt, 0.82, 1.08), np.clip(dirt - 0.58, 0, 1) * 0.6)
    pix = pix * (0.9 + speckle[..., None] * 0.2)
    return pix


def mud() -> np.ndarray:
    n = fbm(SIZE, 14.0, 5, 2.4)
    wet = fbm(SIZE, 22.0, 4, 9.1)
    speckle = grain(SIZE, 5.0)
    base = rgb("5A3C24")
    dark = rgb("3A2618")
    pix = shade(base, n, 0.7, 1.18)
    pix = lerp(pix, shade(dark, wet, 0.88, 1.08), np.clip(wet - 0.42, 0, 1) * 0.55)
    pix = pix * (0.9 + speckle[..., None] * 0.18)
    return pix


def road() -> np.ndarray:
    n = fbm(SIZE, 16.0, 5, 3.3)
    grit = fbm(SIZE, 48.0, 3, 12.0)
    speckle = grain(SIZE, 8.1)
    laterite = rgb("A4553A")
    worn = rgb("7A4A32")
    dust = rgb("C4926A")
    pix = shade(laterite, n, 0.78, 1.16)
    pix = lerp(pix, shade(worn, grit, 0.88, 1.08), grit * 0.45)
    pix = lerp(pix, shade(dust, n, 0.92, 1.1), np.clip(n - 0.62, 0, 1) * 0.4)
    pix = pix * (0.88 + speckle[..., None] * 0.24)
    return pix


def sand() -> np.ndarray:
    n = fbm(SIZE, 16.0, 5, 5.5)
    rip = fbm(SIZE, 28.0, 4, 1.7)
    speckle = grain(SIZE, 2.2)
    base = rgb("C2A56A")
    shadow = rgb("9C7A4E")
    pix = shade(base, n, 0.84, 1.14)
    pix = lerp(pix, shade(shadow, rip, 0.9, 1.06), rip * 0.35)
    pix = pix * (0.92 + speckle[..., None] * 0.16)
    return pix


def paddy() -> np.ndarray:
    n = fbm(SIZE, 14.0, 4, 6.6)
    yy, xx = np.mgrid[0:SIZE, 0:SIZE].astype(np.float64)
    rows = 0.5 + 0.5 * np.sin((yy / float(SIZE)) * math.pi * 16.0)
    speckle = grain(SIZE, 7.7)
    green = rgb("7FA650")
    water = rgb("5E8A62")
    pix = shade(green, n, 0.8, 1.16)
    pix = lerp(pix, shade(water, n, 0.88, 1.06), np.abs(rows - 0.5) * 0.7)
    pix = pix * (0.9 + speckle[..., None] * 0.18)
    return pix


def shallow() -> np.ndarray:
    n = fbm(SIZE, 14.0, 5, 7.2)
    caustic = fbm(SIZE, 32.0, 4, 2.8)
    speckle = grain(SIZE, 1.4)
    teal = rgb("2E8C9A")
    light = rgb("5AA8A0")
    pix = shade(teal, n, 0.7, 1.2)
    pix = lerp(pix, shade(light, caustic, 0.92, 1.16), caustic * 0.42)
    pix = pix * (0.9 + speckle[..., None] * 0.16)
    return pix


def deep() -> np.ndarray:
    n = fbm(SIZE, 12.0, 5, 11.0)
    swell = fbm(SIZE, 20.0, 4, 3.9)
    speckle = grain(SIZE, 9.9)
    ink = rgb("0C2438")
    sea = rgb("163A48")
    pix = shade(ink, n, 0.8, 1.2)
    pix = lerp(pix, shade(sea, swell, 0.88, 1.12), swell * 0.45)
    pix = pix * (0.9 + speckle[..., None] * 0.14)
    return pix


def pad() -> np.ndarray:
    n = fbm(SIZE, 18.0, 5, 14.5)
    grit = fbm(SIZE, 40.0, 3, 0.9)
    speckle = grain(SIZE, 4.4)
    packed = rgb("8A6A48")
    dust = rgb("B08958")
    pix = shade(packed, n, 0.82, 1.14)
    pix = lerp(pix, shade(dust, grit, 0.9, 1.08), grit * 0.35)
    pix = pix * (0.9 + speckle[..., None] * 0.2)
    return pix


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    save("grass", grass())
    save("mud", mud())
    save("road", road())
    save("sand", sand())
    save("paddy", paddy())
    save("shallow_water", shallow())
    save("deep_water", deep())
    save("pad", pad())


if __name__ == "__main__":
    main()

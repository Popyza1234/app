#!/usr/bin/env python3
"""Regenerate the dekpop app icon (opaque 1024x1024 PNG).

Requires Pillow:  python -m pip install Pillow
Run:              python scripts/generate-app-icon.py

The icon is a diagonal indigo -> violet -> pink gradient with a bold white
lowercase "d" monogram and a small pink "pop" dot. iOS app icons must not
contain an alpha channel, so the output is forced to RGB.
"""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

SIZE = 1024
SMALL = 256
ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "ThreeOneOSFive" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon-1024.png"

START = (38, 23, 107)      # deep indigo
MIDDLE = (110, 64, 240)    # violet
END = (250, 82, 150)       # hot pink
PINK = (255, 79, 139)

FONT_CANDIDATES = [
    "C:/Windows/Fonts/segoeuib.ttf",
    "C:/Windows/Fonts/arialbd.ttf",
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
]


def mix(a, b, t: float) -> tuple[int, int, int]:
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def background() -> Image.Image:
    small = Image.new("RGB", (SMALL, SMALL))
    px = small.load()
    for y in range(SMALL):
        for x in range(SMALL):
            t = 0.55 * (x / (SMALL - 1)) + 0.45 * (y / (SMALL - 1))
            if t < 0.5:
                color = mix(START, MIDDLE, t / 0.5)
            else:
                color = mix(MIDDLE, END, (t - 0.5) / 0.5)
            px[x, y] = color
    return small.resize((SIZE, SIZE), Image.Resampling.BICUBIC)


def glow_mask(cx: float, cy: float, radius: float, strength: int) -> Image.Image:
    """Soft radial alpha mask, computed small then upscaled for speed."""
    mask = Image.new("L", (SMALL, SMALL), 0)
    px = mask.load()
    scale = SIZE / SMALL
    for y in range(SMALL):
        for x in range(SMALL):
            d = math.hypot(x * scale - cx, y * scale - cy) / radius
            if d < 1.0:
                px[x, y] = round(strength * (1.0 - d) ** 2)
    return mask.resize((SIZE, SIZE), Image.Resampling.BICUBIC).filter(
        ImageFilter.GaussianBlur(28)
    )


def load_font(size: int):
    for candidate in FONT_CANDIDATES:
        if Path(candidate).exists():
            return ImageFont.truetype(candidate, size)
    return ImageFont.load_default(size=size)


def add_pop_dot(layer: Image.Image) -> None:
    draw = ImageDraw.Draw(layer)
    cx, cy, r = 762, 252, 78
    draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=PINK, outline="white", width=16)
    # small sparkle at the lower-left for a playful "pop" accent
    sx, sy, s = 236, 748, 46
    points = [
        (sx, sy - s), (sx + s * 0.22, sy - s * 0.22),
        (sx + s, sy), (sx + s * 0.22, sy + s * 0.22),
        (sx, sy + s), (sx - s * 0.22, sy + s * 0.22),
        (sx - s, sy), (sx - s * 0.22, sy - s * 0.22),
    ]
    draw.polygon(points, fill=(255, 255, 255, 190))


def main() -> None:
    base = background().convert("RGBA")

    for cx, cy, radius, strength, color in (
        (860, -40, 620, 120, (255, 255, 255, 255)),
        (80, 980, 560, 90, (130, 235, 255, 255)),
    ):
        glow = Image.new("RGBA", (SIZE, SIZE), color)
        base.paste(glow, (0, 0), glow_mask(cx, cy, radius, strength))

    # Soft drop shadow behind the monogram.
    shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_font = load_font(700)
    shadow_draw.text((SIZE / 2 + 8, SIZE / 2 - 8), "d", font=shadow_font,
                     fill=(20, 8, 60, 150), anchor="mm")
    base.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(26)))

    layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw.text((SIZE / 2, SIZE / 2 - 18), "d", font=shadow_font,
              fill=(255, 255, 255, 255), anchor="mm")
    add_pop_dot(layer)
    base.alpha_composite(layer)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    base.convert("RGB").save(OUT, "PNG", optimize=True)
    print("Wrote %s (%d bytes, RGB, no alpha)" % (OUT, OUT.stat().st_size))


if __name__ == "__main__":
    main()

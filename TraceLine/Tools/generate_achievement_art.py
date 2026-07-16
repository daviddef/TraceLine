#!/usr/bin/env python3
"""Generates the Game Center achievement artwork.

Apple requires one 512x512 image per achievement. Like the app icon, these are drawn
from the game's Neon palette rather than hand-authored — each is the achievement stated
as a path the DrawingEngine would accept: one stroke, never crossing itself.

    python3 Tools/generate_achievement_art.py [outdir]

Defaults to build/achievement_art/ (gitignored — the script is the source of truth).
"""

import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

BACKGROUND = (13, 13, 26)
LINE = (99, 102, 241)
TIP = (236, 72, 153)
GOLD = (250, 204, 21)

SIZE = 512
SS = 4
S = SIZE * SS
STROKE = 0.055

# Each path is one continuous, non-self-crossing stroke, in 0..1 space.
ART = {
    "firstclear": {
        # A single confident stroke — the first line ever drawn.
        "path": [(0.18, 0.70), (0.38, 0.70), (0.38, 0.32), (0.82, 0.32)],
        "tip": TIP,
    },
    "nolift10": {
        # A long serpentine held without ever lifting.
        "path": [(0.16, 0.20), (0.84, 0.20), (0.84, 0.40), (0.16, 0.40),
                 (0.16, 0.60), (0.84, 0.60), (0.84, 0.80), (0.16, 0.80)],
        "tip": TIP,
    },
    "speedrun": {
        # A fast diagonal dash, drawn in gold for the speed bonus.
        "path": [(0.16, 0.78), (0.44, 0.78), (0.44, 0.50), (0.72, 0.50), (0.72, 0.22), (0.86, 0.22)],
        "tip": GOLD,
        "colour": GOLD,
    },
}


def draw_line(layer, points, colour, width):
    d = ImageDraw.Draw(layer)
    d.line(points, fill=colour, width=int(width), joint="curve")
    r = width / 2
    for x, y in points:
        d.ellipse([x - r, y - r, x + r, y + r], fill=colour)


def render(spec):
    points = [(x * S, y * S) for x, y in spec["path"]]
    stroke = STROKE * S
    colour = spec.get("colour", LINE)
    base = Image.new("RGB", (S, S), BACKGROUND)

    def add_glow(fn, blur, strength):
        layer = Image.new("RGB", (S, S), (0, 0, 0))
        fn(layer)
        layer = layer.filter(ImageFilter.GaussianBlur(radius=blur))
        layer = layer.point(lambda v: int(v * strength))
        return ImageChops.add(base, layer)

    base = add_glow(lambda l: draw_line(l, points, colour, stroke * 2.4),
                    blur=stroke * 0.85, strength=0.55)
    draw_line(base, points, colour, stroke)

    tx, ty = points[-1]
    r = stroke * 0.7
    base = add_glow(
        lambda l: ImageDraw.Draw(l).ellipse(
            [tx - r * 2.2, ty - r * 2.2, tx + r * 2.2, ty + r * 2.2], fill=spec["tip"]),
        blur=stroke * 0.75, strength=0.85)
    ImageDraw.Draw(base).ellipse([tx - r, ty - r, tx + r, ty + r], fill=spec["tip"])

    # Opaque RGB: Game Center artwork is rejected with an alpha channel, same as the icon.
    return base.resize((SIZE, SIZE), Image.LANCZOS).convert("RGB")


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else \
        Path(__file__).resolve().parent.parent / "build/achievement_art"
    out.mkdir(parents=True, exist_ok=True)
    for name, spec in ART.items():
        dest = out / f"{name}.png"
        render(spec).save(dest, optimize=True)
        print(f"wrote {dest} ({dest.stat().st_size // 1024}K)")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Generates the TraceLine app icon.

The game has no image assets — everything is drawn in code — so the icon is
generated too, from the Neon theme's own palette. Re-run after changing the design:

    python3 Tools/generate_icon.py

Writes TraceLine/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png
"""

from PIL import Image, ImageChops, ImageDraw, ImageFilter
from pathlib import Path

# Neon theme, matching Core/Theme.swift.
BACKGROUND = (13, 13, 26)
LINE = (99, 102, 241)
GLOW = (99, 102, 241)
TIP = (236, 72, 153)

SIZE = 1024
SS = 4                      # supersample factor, for antialiasing
S = SIZE * SS

# One continuous, non-crossing inward spiral — the game's two rules stated as a shape.
PATH = [
    (0.16, 0.84), (0.16, 0.20), (0.84, 0.20),
    (0.84, 0.80), (0.36, 0.80), (0.36, 0.40),
    (0.64, 0.40), (0.64, 0.60),
]

STROKE = 0.072              # fraction of icon size


def to_px(points):
    return [(x * S, y * S) for x, y in points]


def draw_line(layer, points, colour, width):
    d = ImageDraw.Draw(layer)
    d.line(points, fill=colour, width=int(width), joint="curve")
    # Round the caps and joins — SpriteKit's lineCap/lineJoin are both .round.
    r = width / 2
    for x, y in points:
        d.ellipse([x - r, y - r, x + r, y + r], fill=colour)


def main():
    points = to_px(PATH)
    stroke = STROKE * S

    base = Image.new("RGB", (S, S), BACKGROUND)

    def add_glow(draw_fn, blur, strength):
        """Additive glow: draw onto black, blur, then add to the base.

        Blending toward these layers would drag the whole icon to black, since
        they are mostly black — light has to be *added*, the way a bloom works.
        """
        layer = Image.new("RGB", (S, S), (0, 0, 0))
        draw_fn(layer)
        layer = layer.filter(ImageFilter.GaussianBlur(radius=blur))
        layer = layer.point(lambda v: int(v * strength))
        return ImageChops.add(base, layer)

    base = add_glow(lambda l: draw_line(l, points, GLOW, stroke * 2.4),
                    blur=stroke * 0.85, strength=0.55)

    draw_line(base, points, LINE, stroke)

    # The drawing tip, where the player's finger would be.
    tx, ty = points[-1]
    r = stroke * 0.62
    base = add_glow(
        lambda l: ImageDraw.Draw(l).ellipse(
            [tx - r * 2.2, ty - r * 2.2, tx + r * 2.2, ty + r * 2.2], fill=TIP),
        blur=stroke * 0.75, strength=0.85)
    ImageDraw.Draw(base).ellipse([tx - r, ty - r, tx + r, ty + r], fill=TIP)

    icon = base.resize((SIZE, SIZE), Image.LANCZOS)

    out = Path(__file__).resolve().parent.parent / "TraceLine/Resources/Assets.xcassets/AppIcon.appiconset"
    out.mkdir(parents=True, exist_ok=True)
    # App Store icons must be opaque RGB — an alpha channel is rejected at upload.
    icon.convert("RGB").save(out / "icon-1024.png")
    print(f"wrote {out / 'icon-1024.png'}")


if __name__ == "__main__":
    main()

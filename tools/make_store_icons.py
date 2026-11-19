"""Icônes provisoires des produits Robux (512 x 512, sans texte) : assets/export/icons/.
À remplacer par de vraies icônes dans le Creator Hub quand elles existeront.
Lancer : py -3 tools/make_store_icons.py
"""

import math
import os

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "export", "icons")
SIZE = 512


def base(top, bottom):
    img = Image.new("RGBA", (SIZE, SIZE))
    d = ImageDraw.Draw(img)
    for y in range(SIZE):
        t = y / SIZE
        d.line([(0, y), (SIZE, y)], fill=tuple(int(a + (b - a) * t) for a, b in zip(top, bottom)))
    mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, SIZE - 1, SIZE - 1], 96, fill=255)
    img.putalpha(mask)
    return img, ImageDraw.Draw(img)


def star(cx, cy, r1, r2, n=5, rot=-90):
    pts = []
    for i in range(n * 2):
        r = r1 if i % 2 == 0 else r2
        a = math.radians(rot + i * 180 / n)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def coins(d, count):
    for i in range(count):
        y = 340 - i * 46
        d.ellipse([136, y - 30, 376, y + 50], fill=(150, 110, 10), outline=(90, 60, 0), width=8)
        d.ellipse([136, y - 46, 376, y + 34], fill=(255, 205, 40), outline=(90, 60, 0), width=8)


def flex(d, scale):
    # biceps stylisé : bras plié + boule du muscle
    c = (255, 200, 150)
    o = (90, 40, 20)
    s = scale
    d.rounded_rectangle([256 - 150 * s, 330 - 40 * s, 256 + 60 * s, 330 + 40 * s], int(40 * s), fill=c, outline=o, width=8)
    d.rounded_rectangle([256 + 20 * s, 150 - 10 * s, 256 + 100 * s, 360 * 1.0], int(40 * s), fill=c, outline=o, width=8)
    d.ellipse([256 - 110 * s, 230 - 70 * s, 256 + 40 * s, 230 + 80 * s], fill=c, outline=o, width=8)


def bolt(d):
    d.polygon([(290, 60), (140, 290), (245, 290), (205, 455), (375, 210), (265, 210)], fill=(255, 235, 60), outline=(120, 80, 0), width=8)


def crown(d):
    d.polygon([(110, 380), (90, 170), (180, 270), (256, 130), (332, 270), (422, 170), (402, 380)], fill=(255, 210, 40), outline=(110, 70, 0), width=10)
    for x in (90, 256, 422):
        y = 170 if x != 256 else 130
        d.ellipse([x - 22, y - 22, x + 22, y + 22], fill=(255, 80, 80), outline=(110, 70, 0), width=6)


ICONS = {
    "CashSmall": ((40, 160, 70), (10, 80, 30), lambda d: coins(d, 2)),
    "CashMedium": ((40, 160, 70), (10, 80, 30), lambda d: coins(d, 4)),
    "CashLarge": ((240, 190, 40), (150, 90, 0), lambda d: coins(d, 6)),
    "MogSmall": ((255, 140, 60), (170, 50, 20), lambda d: flex(d, 0.8)),
    "MogMedium": ((255, 110, 40), (150, 30, 10), lambda d: flex(d, 1.0)),
    "MogLarge": ((230, 50, 40), (110, 10, 10), lambda d: flex(d, 1.15)),
    "MogBoostShort": ((60, 150, 255), (20, 40, 140), bolt),
    "MogBoostLong": ((150, 70, 255), (50, 10, 130), bolt),
    "BossWin": ((200, 40, 60), (60, 0, 20), crown),
}
PASS_COLORS = {
    "CosmicEmperor": ((60, 20, 140), (10, 0, 40)),
    "GoldenTitan": ((250, 200, 60), (150, 90, 0)),
    "NeonPhantom": ((30, 230, 200), (20, 30, 90)),
    "GymDragon": ((60, 170, 70), (20, 60, 20)),
    "EternalSun": ((255, 170, 30), (200, 60, 0)),
    "MechaMogger": ((150, 160, 180), (40, 50, 70)),
    "MarbleStatue": ((240, 240, 235), (150, 150, 145)),
    "InfernalDemon": ((240, 70, 20), (80, 0, 0)),
}

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, (top, bottom, draw) in ICONS.items():
        img, d = base(top, bottom)
        draw(d)
        img.save(os.path.join(OUT, f"{name}.png"))
    for name, (top, bottom) in PASS_COLORS.items():
        img, d = base(top, bottom)
        d.polygon(star(256, 270, 190, 80), fill=(255, 255, 255, 230), outline=(30, 30, 30), width=8)
        img.save(os.path.join(OUT, f"Pass_{name}.png"))
    print("ok", len(ICONS) + len(PASS_COLORS))

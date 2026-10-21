"""Add readable outfit names to the 5-by-4 Blender contact sheet."""

import ast
from pathlib import Path
import sys

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "tools" / "blender" / "outfit_looks.py"
EXPORT = ROOT / "assets" / "export" / "characters"
BACK = "--back" in sys.argv
INPUT = EXPORT / ("outfits_all_back.png" if BACK else "outfits_all.png")
OUTPUT = EXPORT / ("outfits_catalogue_back.png" if BACK else "outfits_catalogue.png")

module = ast.parse(SOURCE.read_text(encoding="utf-8"))
assignment = next(node for node in module.body if isinstance(node, ast.Assign)
                  and any(isinstance(target, ast.Name) and target.id == "LOOKS" for target in node.targets))
names = [entry[0] for entry in ast.literal_eval(assignment.value)]
assert len(names) == 20

sheet = Image.open(INPUT).convert("RGBA")
assert sheet.size == (3000, 3000)
overlay = Image.new("RGBA", sheet.size, (0, 0, 0, 0))
draw = ImageDraw.Draw(overlay)
font_path = Path("C:/Windows/Fonts/arialbd.ttf")
font = ImageFont.truetype(str(font_path), 38) if font_path.exists() else ImageFont.load_default()

for index in range(20):
    col, row = index % 5, index // 5
    name = names[row * 5 + (4 - col if BACK else col)]
    x = 446 + 527 * col
    y = (560, 1210, 1860, 2510)[row]
    draw.rounded_rectangle((x - 245, y, x + 245, y + 68), radius=15,
                           fill=(17, 16, 26, 212), outline=(188, 151, 68, 240), width=2)
    bbox = draw.textbbox((0, 0), name, font=font)
    draw.text((x - (bbox[2] - bbox[0]) / 2, y + 12), name, font=font,
              fill=(250, 247, 237, 255))

Image.alpha_composite(sheet, overlay).convert("RGB").save(OUTPUT)
print(OUTPUT)

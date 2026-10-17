"""
Position de repos de chaque partie R15, par stade (centre de la pièce, depuis le sol, face vers -Z), à partir de
assets/export/bodies/skeletons.json (relevé dans Studio). Sert à monter des mannequins et des bustes sans
personnage (DisplayService). Usage : py -3 tools/gen_skeleton.py
Sortie : src/shared/Config/BodySkeleton.luau (fichier généré, ne pas modifier à la main).
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "assets", "export", "bodies", "skeletons.json")
OUT = os.path.join(ROOT, "src", "shared", "Config", "BodySkeleton.luau")
ORDER = ["Normie", "GymRat", "Bro", "Alpha", "Chad", "Gigachad", "GodMogger"]
ORDER += [name + "F" for name in ORDER]  # corps féminins (D55), squelettes à part

data = json.load(open(SOURCE, encoding="utf-8"))
lines = [
    "-- Fichier généré par tools/gen_skeleton.py : ne pas modifier à la main.",
    "-- Centre de chaque partie R15 au repos, par stade, depuis le sol sous le personnage (face vers -Z).",
    "",
    "return {",
]
for stage in ORDER:
    lines.append(f"\t{stage} = {{")
    for part in sorted(data[stage]["parts"]):
        x, y, z = data[stage]["parts"][part]["center"]
        lines.append(f"\t\t{part} = Vector3.new({x:g}, {y:g}, {z:g}),")
    lines.append("\t},")
lines.append("}")
with open(OUT, "w", encoding="utf-8", newline="\n") as f:
    f.write("\n".join(lines) + "\n")
print(OUT)

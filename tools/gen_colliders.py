"""
Collisions exactes des murs des bâtiments (sans Blender) : py -3 tools/gen_colliders.py

Roblox calcule la collision d'un MeshPart en le découpant en morceaux convexes, et ce découpage rebouche
parfois les ouvertures (la porte garage → maison était un mur invisible). On génère donc, à partir des mêmes
formules que tools/blender/props_building.py, la liste des blocs de chaque *_Walls ; PropService les pose en
blocs invisibles et désactive la collision du mesh.

Sortie : src/server/PropColliders.luau (fichier généré, ne pas modifier à la main).
Repère : celui du MeshPart importé (centre de sa boîte) = repère de conception recentré : X largeur, Y hauteur,
Z = profondeur de conception (la façade est du côté -Z), comme dans build_map.py (piece).
"""

import ast
import json
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "tools", "blender", "props_building.py")
MANIFEST = os.path.join(ROOT, "assets", "export", "props", "buildings_manifest.json")
OUT = os.path.join(ROOT, "src", "server", "PropColliders.luau")


class Recorder:
    """Remplace Props : garde les blocs des pièces *_Walls, et les vitres de *_Trim (la façade n'a pas de
    collision, mais on ne doit pas passer par les fenêtres). Tout est rangé sous le nom des murs du bâtiment."""

    def __init__(self):
        self.pieces = {}

    def prop(self, name, parts, ground=True):
        if name.endswith("_Walls"):
            boxes = [p[0] for p in parts if isinstance(p[0], tuple) and p[0][0] == "box"]
        elif name.endswith("_Trim"):
            boxes = [glass_box(p[0]) for p in parts if p[1] == "glass" and p[0][0] == "box"]
            name = name[: -len("_Trim")] + "_Walls"
        else:
            return
        self.pieces.setdefault(name, []).extend(boxes)


def glass_box(b):
    """Vitre épaissie à 0,4 stud : une plaque trop fine laisse passer un personnage qui court."""
    _, center, size = b
    return ("box", center, tuple(max(v, 0.4) if v < 0.2 else v for v in size))


def load_building_module():
    with open(SOURCE, encoding="utf-8") as f:
        source = f.read()
    tree = ast.parse(source)
    defined = {"math"}
    for node in ast.walk(tree):
        if isinstance(node, (ast.FunctionDef, ast.ClassDef)):
            defined.add(node.name)
        elif isinstance(node, ast.Name) and isinstance(node.ctx, ast.Store):
            defined.add(node.id)
        elif isinstance(node, ast.arg):
            defined.add(node.arg)
    used = {n.id for n in ast.walk(tree) if isinstance(n, ast.Name) and isinstance(n.ctx, ast.Load)}
    namespace = {"math": math, "__builtins__": __builtins__}
    # Toutes les formes de props_lib deviennent des marqueurs ; seule box garde ses dimensions
    for name in used - defined - set(dir(__builtins__ if isinstance(__builtins__, dict) else __builtins__)):
        namespace[name] = lambda *a, **k: ("other",)
    namespace["box"] = lambda center, size, *a, **k: ("box", tuple(center), tuple(size))
    exec(compile(source, SOURCE, "exec"), namespace)
    return namespace


def main():
    ns = load_building_module()
    rec = Recorder()
    ns["build_buildings"](rec)
    with open(MANIFEST, encoding="utf-8") as f:
        manifest = json.load(f)

    lines = [
        "-- Fichier généré par tools/gen_colliders.py : ne pas modifier à la main.",
        "-- Blocs de collision des murs des bâtiments, dans le repère du MeshPart importé :",
        "-- { centre X, Y, Z, taille X, Y, Z } (en studs, avant mise à l'échelle).",
        "",
        "return {",
    ]
    for name in sorted(rec.pieces):
        meta = manifest[name]
        cx, cy = meta["center"]
        mid_z = meta["bottom"] + meta["size"][2] / 2
        lines.append(f"\t{name} = {{")
        for _, (x, y, z), (sx, sy, sz) in rec.pieces[name]:
            vals = (x - cx, z - mid_z, y - cy, sx, sz, sy)
            lines.append("\t\t{ " + ", ".join(f"{round(v, 3):g}" for v in vals) + " },")
        lines.append("\t},")
    lines.append("}")
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    print(f"{OUT}: " + ", ".join(f"{n} {len(b)}" for n, b in sorted(rec.pieces.items())))


if __name__ == "__main__":
    main()

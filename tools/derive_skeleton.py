"""
Calcule le squelette R15 d'un corps à partir d'un squelette relevé dans Studio et de nouvelles proportions
(Bodies.luau : width, height, depth, head). Le squelette R15 est linéaire dans ces proportions : recalculer Gigachad
et Normie depuis GodMogger redonne les relevés de Studio à 0,001 stud près (vérifié le 06/11/2026, D116).

Usage : py -3 tools/derive_skeleton.py Corps=largeur,hauteur,profondeur,tête [...]
  ex. py -3 tools/derive_skeleton.py GodMogger=2.05,1.55,1.7,0.85 Normie=0.35,1.1,0.5,1.15
Met à jour assets/export/bodies/skeletons.json (le corps garde son nom, "derivedFrom" note la source).
À vérifier dans Studio quand c'est possible ; puis relancer build_bodies.py / build_style.py et gen_skeleton.py.
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PATH = os.path.join(ROOT, "assets", "export", "bodies", "skeletons.json")


def derive(source, scale):
    w0, h0, d0, k0 = source["scale"]
    w1, h1, d1, k1 = scale
    neck0 = source["joints"]["Neck"][1]
    neck1 = neck0 * h1 / h0
    out = {
        "scale": [w1, h1, d1, k1],
        "groundFromRoot": source["groundFromRoot"] * h1 / h0,
        "hipHeight": source["hipHeight"] * h1 / h0,
        "rootSize": [source["rootSize"][0] * w1 / w0, source["rootSize"][1] * h1 / h0, source["rootSize"][2] * d1 / d0],
        "joints": {j: [v[0] * w1 / w0, v[1] * h1 / h0, v[2] * d1 / d0] for j, v in source["joints"].items()},
        "parts": {},
    }
    for part, v in source["parts"].items():
        c, s = v["center"], v["size"]
        if part == "Head":
            out["parts"][part] = {"center": [c[0], neck1 + (c[1] - neck0) * k1 / k0, c[2]],
                                  "size": [x * k1 / k0 for x in s]}
        else:
            out["parts"][part] = {"center": [c[0] * w1 / w0, c[1] * h1 / h0, c[2] * d1 / d0],
                                  "size": [s[0] * w1 / w0, s[1] * h1 / h0, s[2] * d1 / d0]}
    return out


data = json.load(open(PATH, encoding="utf-8"))
for arg in sys.argv[1:]:
    name, values = arg.split("=")
    scale = [float(x) for x in values.split(",")]
    # Source : le relevé Studio d'origine si le corps a déjà été recalculé
    source_name = data[name].get("derivedFrom", {}).get("body", name)
    source = data[name]["derivedFrom"]["measured"] if "derivedFrom" in data[name] else data[name]
    new = derive(source, scale)
    new["derivedFrom"] = {"body": source_name, "measured": source}
    data[name] = new
    print(name, "->", scale)
with open(PATH, "w", encoding="utf-8", newline="\n") as f:
    json.dump(data, f, indent=1)

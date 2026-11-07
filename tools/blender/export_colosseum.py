"""
Construit le Colisée du Pump (D89) et l'exporte pour Roblox Studio :
- assets/export/props/Props_Colosseum.fbx      : un objet = un MeshPart
- assets/export/props/colosseum_manifest.json  : position de chaque pièce dans son repère de conception et les cotes
  de l'arène (LAYOUT), lus par tools/build_map.py (pose des pièces, collisions, points de départ)
Dans Blender : exec(open(r"...\\tools\\blender\\export_colosseum.py", encoding="utf-8").read())
Import dans Studio : Accueil -> Importer 3D -> Props_Colosseum.fbx, puis tools/install_props.luau.
"""
import bpy, bmesh, json, os

D = r"C:\Users\antoi\Documents\MogLife\tools\blender"
OUT = r"C:\Users\antoi\Documents\MogLife\assets\export\props"

ns = {}
exec(open(os.path.join(D, "props_lib.py"), encoding="utf-8").read(), ns)
exec(open(os.path.join(D, "props_colosseum.py"), encoding="utf-8").read(), ns)

pal = ns["build_palette"]()
ns["colosseum_palette"](pal)
# mirror_x : l'import de Roblox inverse gauche et droite (comme pour les bâtiments)
P = ns["Props"](pal, "Props_Colosseum", spacing=200, columns=4, mirror_x=True)
P.clear()
ns["build_colosseum"](P)

# D121 : faces superposées (deux surfaces au même endroit qui clignotent) séparées avant l'export
exec(open(os.path.join(D, "coplanar_fix.py"), encoding="utf-8").read(), ns)
print("faces superposées séparées :", ns["separate_coplanar"](list(P.col.objects)))

# Les arches sont des faces concaves : on triangule nous-mêmes (oreilles) pour que l'import ne les déforme pas
for obj in P.col.objects:
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.triangulate(bm, faces=bm.faces, quad_method="BEAUTY", ngon_method="EAR_CLIP")
    bm.to_mesh(obj.data)
    bm.free()

with open(os.path.join(OUT, "colosseum_manifest.json"), "w", encoding="utf-8") as f:
    json.dump({"pieces": P.meta, "layout": ns["LAYOUT"]}, f, indent=1, sort_keys=True)

if not os.environ.get("MOG_NO_EXPORT"):
    path = os.path.join(OUT, "Props_Colosseum.fbx")
    count = ns["export_fbx"](["Props_Colosseum"], path)
    print(f"{count} pièces exportées dans {path} ({os.path.getsize(path) // 1024} Ko)")
print("\n".join(P.report))

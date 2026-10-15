"""
Reconstruit les bâtiments (maison, garage, magasins, salle, portes) et les exporte pour Roblox Studio :
- assets/export/props/MogLife_Buildings.fbx   : un objet = un MeshPart
- assets/export/props/buildings_manifest.json : position de chaque pièce dans son repère de conception
  (lu par tools/build_map.py et tools/gen_colliders.py)
Dans Blender : exec(open(r"...\\tools\\blender\\export_buildings.py", encoding="utf-8").read())
Import dans Studio : Accueil -> Importer 3D -> MogLife_Buildings.fbx, puis tools/install_props.luau.
"""
import bpy, json, os

D = r"C:\Users\antoi\Documents\MogLife\tools\blender"
OUT = r"C:\Users\antoi\Documents\MogLife\assets\export\props"

ns = {}
exec(open(os.path.join(D, "props_lib.py"), encoding="utf-8").read(), ns)
exec(open(os.path.join(D, "props_building.py"), encoding="utf-8").read(), ns)

pal = ns["build_palette"]()
# mirror_x : l'import de Roblox inverse gauche et droite, les portes doivent rester du bon côté
P = ns["Props"](pal, "Props_Buildings", spacing=70, columns=6, mirror_x=True)
P.clear()
ns["build_buildings"](P)

with open(os.path.join(OUT, "buildings_manifest.json"), "w", encoding="utf-8") as f:
    json.dump(P.meta, f, indent=1, sort_keys=True)

path = os.path.join(OUT, "MogLife_Buildings.fbx")
count = ns["export_fbx"](["Props_Buildings"], path)
print(f"{count} pièces exportées dans {path} ({os.path.getsize(path) // 1024} Ko)")
print("\n".join(P.report))

"""
Meubles v3 (D133) : construit les 21 meubles et les exporte dans assets/export/props/Props_Furniture.fbx.
Un objet = une MeshPart nommée Furniture_<Id>__<Matière>_<rrggbb> (ou __Tex : palette partagée).
Dans Blender : exec(open(r"...\tools\blender\export_furniture_v3.py", encoding="utf-8").read())
Dans Studio : Accueil > Importer 3D > Props_Furniture.fbx, puis coller tools/install_furniture.luau dans la barre de
commande (ou laisser Claude le faire via le MCP).
"""
import bpy, os

D = r"C:\Users\antoi\Documents\MogLife\tools\blender"
OUT = r"C:\Users\antoi\Documents\MogLife\assets\export\props"
ns = {}
exec(open(os.path.join(D, "props_lib.py"), encoding="utf-8").read(), ns)
for m in ["props_home.py", "props_furniture_v2.py", "props_furniture_v3.py"]:
    exec(open(os.path.join(D, m), encoding="utf-8").read(), ns)
pal = ns["build_palette"]()
P = ns["Props"](pal, "Props_Furniture", spacing=10, columns=7)
P.clear()
ns["furniture_v3"](P)
objs = [o for o in P.col.objects if o.type == "MESH"]
for o in bpy.context.view_layer.objects:
    o.select_set(False)
for o in objs:
    o.select_set(True)
bpy.context.view_layer.objects.active = objs[0]
path = os.path.join(OUT, "Props_Furniture.fbx")
# Normales exportées telles quelles (faces lissées, arêtes vives au-delà de 35°) : pas de groupes de lissage
bpy.ops.export_scene.fbx(
    filepath=path, use_selection=True, object_types={"MESH"},
    axis_forward="-Z", axis_up="Y", apply_unit_scale=True, apply_scale_options="FBX_SCALE_ALL",
    mesh_smooth_type="OFF", path_mode="RELATIVE", embed_textures=False,
)
for line in P.report:
    print(line)
print(f"{len(objs)} pièces, {os.path.getsize(path) // 1024} Ko -> {path}")

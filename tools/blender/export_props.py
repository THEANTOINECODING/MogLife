"""
Reconstruit TOUS les décors (avec la palette définitive) et les exporte pour Roblox Studio :
- assets/export/props/Props_<Catégorie>.fbx : un fichier par catégorie, un objet = un MeshPart
- assets/export/props/MogProps_Palette.png   : la texture partagée par tous les décors
Dans Blender : exec(open(r"...\\tools\\blender\\export_props.py", encoding="utf-8").read())
Import dans Studio : Accueil -> Importer 3D -> choisir le FBX (la texture PNG est à côté).
"""
import bpy, os

D = r"C:\Users\antoi\Documents\MogLife\tools\blender"
OUT = r"C:\Users\antoi\Documents\MogLife\assets\export\props"
os.makedirs(OUT, exist_ok=True)

CATEGORIES = [
    ("props_street.py", "build_street", "Props_Street"),
    ("props_nature.py", "build_nature", "Props_Nature"),
    ("props_gym.py", "build_gym", "Props_Gym"),
    ("props_home.py", "build_home", "Props_Home"),
    ("props_town.py", "build_town", "Props_Town"),
    ("props_zones.py", "build_zones", "Props_Zones"),
    ("props_kit.py", "build_kit", "Props_Kit"),
    ("props_events.py", "build_events", "Props_Events"),
    # D121 : chargé en dernier, remplace furniture() et bleachers() (meubles refaits, tribunes de stade) et ajoute les
    # décors des secrets
    ("props_furniture_v2.py", "build_v2_extras", "Props_Secrets"),
]

ns = {}
exec(open(os.path.join(D, "props_lib.py"), encoding="utf-8").read(), ns)
for module, _, _ in CATEGORIES:
    exec(open(os.path.join(D, module), encoding="utf-8").read(), ns)

pal = ns["build_palette"]()
summary = []
for row, (module, build, collection) in enumerate(CATEGORIES):
    P = ns["Props"](pal, collection, spacing=16, columns=8)
    P.clear()
    ns[build](P)
    for o in P.col.objects:
        o.location.y -= row * 140
    summary.append((collection, len(P.report), P.report))

# D121 : faces superposées (deux surfaces au même endroit qui clignotent) séparées avant l'export
exec(open(os.path.join(D, "coplanar_fix.py"), encoding="utf-8").read(), ns)
print("faces superposées séparées :",
      ns["separate_coplanar"]([o for _, _, col in CATEGORIES for o in bpy.data.collections[col].objects if o.type == "MESH"]))

# Texture partagée en PNG à côté des FBX
mat = pal.material()
img = next(n.image for n in mat.node_tree.nodes if n.type == "TEX_IMAGE")
png = os.path.join(OUT, "MogProps_Palette.png")
img.filepath_raw = png
img.file_format = "PNG"
img.save()

for collection, count, report in summary:
    path = os.path.join(OUT, f"{collection}.fbx")
    objs = [o for o in bpy.data.collections[collection].objects if o.type == "MESH"]
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(
        filepath=path, use_selection=True, object_types={"MESH"},
        axis_forward="-Z", axis_up="Y", apply_unit_scale=True, apply_scale_options="FBX_SCALE_ALL",
        mesh_smooth_type="FACE", path_mode="RELATIVE", embed_textures=False,
    )
    tris = sum(int(r.split(": ")[1].split(" ")[0]) for r in report)
    print(f"{collection}: {count} décors, {tris} triangles, {os.path.getsize(path) // 1024} Ko")
# Fichier unique avec tous les décors : un seul import dans Studio
everything = [o for _, _, col in CATEGORIES for o in bpy.data.collections[col].objects if o.type == "MESH"]
for o in bpy.context.view_layer.objects:
    o.select_set(False)
for o in everything:
    o.select_set(True)
bpy.context.view_layer.objects.active = everything[0]
all_path = os.path.join(OUT, "MogLife_AllProps.fbx")
bpy.ops.export_scene.fbx(
    filepath=all_path, use_selection=True, object_types={"MESH"},
    axis_forward="-Z", axis_up="Y", apply_unit_scale=True, apply_scale_options="FBX_SCALE_ALL",
    mesh_smooth_type="FACE", path_mode="RELATIVE", embed_textures=False,
)
print(f"tout : {len(everything)} décors dans {all_path} ({os.path.getsize(all_path) // 1024} Ko)")
print("texture :", png)

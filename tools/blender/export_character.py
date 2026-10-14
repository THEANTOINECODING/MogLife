"""
Exporte un personnage low poly pour Roblox : copie fusionnée de toutes les pièces d'une collection
(un seul MeshPart, une seule texture), origine au sol, FBX + texture PNG à côté.
Usage dans Blender : définir NAME (nom de la collection) puis exécuter ce fichier.
"""
import bpy, os

NAME = globals().get("NAME", "Kevin")
PREFIX = globals().get("PREFIX", "Boss_")
OUT_DIR = r"C:\Users\antoi\Documents\MogLife\assets\export"

col = bpy.data.collections[NAME]
export_name = f"{NAME}_Export"
old = bpy.data.objects.get(export_name)
if old:
    bpy.data.objects.remove(old, do_unlink=True)

# Copie fusionnée (les pièces d'origine restent éditables)
bpy.ops.object.select_all(action="DESELECT")
copies = []
for o in col.objects:
    if o.type != "MESH":
        continue
    c = o.copy()
    c.data = o.data.copy()
    col.objects.link(c)
    copies.append(c)
for c in copies:
    c.select_set(True)
bpy.context.view_layer.objects.active = copies[0]
bpy.ops.object.join()
merged = bpy.context.view_layer.objects.active
merged.name = export_name
merged.data.name = NAME

# Origine au sol, au centre
bpy.context.scene.cursor.location = (0, 0, 0)
bpy.ops.object.origin_set(type="ORIGIN_CURSOR")

# Texture enregistrée à côté du FBX (référencée par chemin, sans incorporation)
os.makedirs(OUT_DIR, exist_ok=True)
for slot in merged.material_slots:
    for node in slot.material.node_tree.nodes:
        if node.type == "TEX_IMAGE" and node.image:
            node.image.filepath_raw = os.path.join(OUT_DIR, f"{PREFIX}{NAME}_texture.png")
            node.image.file_format = "PNG"
            node.image.save()

out = os.path.join(OUT_DIR, f"{PREFIX}{NAME}.fbx")
bpy.ops.object.select_all(action="DESELECT")
merged.select_set(True)
bpy.ops.export_scene.fbx(
    filepath=out, use_selection=True, object_types={"MESH"},
    axis_forward="-Z", axis_up="Y", apply_unit_scale=True, apply_scale_options="FBX_SCALE_ALL",
    mesh_smooth_type="FACE", path_mode="RELATIVE",
)
merged.hide_set(True)
tris = sum(len(p.vertices) - 2 for p in merged.data.polygons)
print("exporté :", out, os.path.getsize(out), "octets,", tris, "triangles")

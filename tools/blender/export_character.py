"""
Exporte un personnage low poly pour Roblox : toutes les pièces d'une collection fusionnées en un seul mesh
(un seul MeshPart, une seule texture), FBX + texture PNG à côté.
Usage dans Blender : définir NAME (nom de la collection) et PREFIX, puis exécuter ce fichier.

Méthode volontairement simple (fusion bmesh, pas d'opérateur « join », texture non incorporée) :
l'ancienne version avec texture incorporée a figé Blender.
Les pièces doivent avoir une transformation identité (sommets en coordonnées monde), comme dans build_*.py.
"""
import bpy, bmesh, os

NAME = globals().get("NAME", "Kevin")
PREFIX = globals().get("PREFIX", "Boss_")
OUT_DIR = r"C:\Users\antoi\Documents\MogLife\assets\export"
os.makedirs(OUT_DIR, exist_ok=True)

col = bpy.data.collections[NAME]
material = None

# 1. Fusion de toutes les pièces dans un seul mesh
merged = bmesh.new()
for o in col.objects:
    if o.type == "MESH":
        merged.from_mesh(o.data)
        if material is None and o.data.materials:
            material = o.data.materials[0]
mesh = bpy.data.meshes.new(NAME)
merged.to_mesh(mesh)
merged.free()
if material:
    mesh.materials.append(material)
for p in mesh.polygons:
    p.use_smooth = False

export_name = f"{NAME}_Export"
old = bpy.data.objects.get(export_name)
if old:
    bpy.data.objects.remove(old, do_unlink=True)
obj = bpy.data.objects.new(export_name, mesh)
bpy.context.scene.collection.objects.link(obj)

# 2. Texture enregistrée en PNG à côté du FBX
texture_path = os.path.join(OUT_DIR, f"{PREFIX}{NAME}_texture.png")
if material:
    for node in material.node_tree.nodes:
        if node.type == "TEX_IMAGE" and node.image:
            node.image.save(filepath=texture_path)
            node.image.filepath = texture_path

# 3. Export FBX de ce seul objet
for o in bpy.context.view_layer.objects:
    o.select_set(False)
obj.select_set(True)
bpy.context.view_layer.objects.active = obj
out = os.path.join(OUT_DIR, f"{PREFIX}{NAME}.fbx")
bpy.ops.export_scene.fbx(
    filepath=out, use_selection=True, object_types={"MESH"},
    axis_forward="-Z", axis_up="Y", apply_unit_scale=True, apply_scale_options="FBX_SCALE_ALL",
    mesh_smooth_type="FACE", path_mode="RELATIVE", embed_textures=False,
)
obj.hide_set(True)
print("exporté :", out, os.path.getsize(out), "octets,", sum(len(p.vertices) - 2 for p in mesh.polygons), "triangles")

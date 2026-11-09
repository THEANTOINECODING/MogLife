"""Aperçu rapide des coupes et barbes (D126), sans exporter ni enregistrer le .blend.

    blender -b assets/blender/wardrobe.blend --python tools/blender/preview_hair.py

Variables d'environnement :
- MOG_ITEMS : objets à montrer, séparés par des virgules (défaut : toutes les coupes et barbes)
- MOG_BODIES : corps (défaut : Normie,Bro,GodMogger,AlphaF)
- MOG_VIEW : front, back, side ou three (défaut : three)
- MOG_OUT : fichier PNG (défaut : assets/export/characters/hair_preview.png)
Les pièces _Hair sont peintes d'une couleur unie, _HairShade de la même couleur assombrie (comme dans le jeu).
"""
import bpy, os, math
from mathutils import Vector

ROOT = r"C:\Users\antoi\Documents\MogLife"
D = os.path.join(ROOT, "tools", "blender")

source = open(os.path.join(D, "build_style.py"), encoding="utf-8").read()
head = source.split("\natlas = paint_style_atlas()\n")[0]
exec(compile(head, "build_style.py", "exec"), globals())

HAIRS = ["Banana", "Mullet", "Mohawk", "ShinyBald", "Pompadour", "Curly", "LongHair", "Bun", "Bob"]
BEARDS = ["LumberBeard", "Goatee", "Handlebar", "ChinStrap"]
items = [s for s in os.environ.get("MOG_ITEMS", ",".join(HAIRS + BEARDS)).split(",") if s]
bodies = [s for s in os.environ.get("MOG_BODIES", "Normie,Bro,GodMogger,AlphaF").split(",") if s]
view = os.environ.get("MOG_VIEW", "three")
out = os.environ.get("MOG_OUT", os.path.join(ROOT, "assets", "export", "characters", "hair_preview.png"))
HAIR_RGB = tuple(float(v) for v in os.environ.get("MOG_RGB", "0.36,0.2,0.09").split(","))

atlas = paint_style_atlas()
sources = {}
centers = {}
for stage in bodies:
    g = geometry(stage)
    g["stage"] = stage
    centers[stage] = Vector((0, g["hy"], g["head_z"]))
    builder = Builder("Preview_" + stage, atlas)
    w = Wardrobe(builder)
    build_hair(w, g)
    build_beards(w, g)
    for item, parts in w.items.items():
        if item not in items:
            continue
        for part, obj in merge_item(stage, item, parts, builder.mat, builder.col).items():
            sources[obj.name] = obj
    for o in bpy.data.collections["Body_" + stage].objects:
        if o.type == "MESH":
            sources[o.name] = o

keep = set(sources.values())
for obj in list(bpy.context.scene.objects):
    if obj not in keep:
        bpy.data.objects.remove(obj, do_unlink=True)
for lc in bpy.context.view_layer.layer_collection.children:
    lc.exclude = False
    lc.hide_viewport = False


def flat(name, rgb):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1)
    bsdf.inputs["Roughness"].default_value = 0.55
    return m


hair_mat = flat("PreviewHair", HAIR_RGB)
shade_mat = flat("PreviewShade", tuple(v * 0.55 for v in HAIR_RGB))
skin_mat = flat("PreviewSkin", (0.8, 0.52, 0.32))

cols = len(items)
direction = {"front": Vector((0, -1, 0.1)), "back": Vector((0, 1, 0.15)), "side": Vector((1, 0, 0.1)),
             "three": Vector((0.7, -1, 0.25))}[view]
right = direction.cross(Vector((0, 0, 1))).normalized()
SPACE = float(os.environ.get("MOG_SPACE", "2.6"))
for bi, stage in enumerate(bodies):
    for li, item in enumerate(items):
        x = (li - (cols - 1) / 2) * SPACE
        z = -bi * SPACE
        for name, src in sources.items():
            if name.startswith(stage + "__"):
                if name.split("__")[1] != item:
                    continue
            elif name.startswith(stage + "_Head"):
                if "_Hair" in name and item in HAIRS:
                    continue
                if any(t in name for t in ("_Top", "_Shorts")):
                    continue
            else:
                continue
            o = src.copy()
            o.data = src.data.copy()
            bpy.context.scene.collection.objects.link(o)
            o.location = right * x + Vector((0, 0, z)) - centers[stage]
            if name.endswith("_HairShade"):
                o.data.materials[0] = shade_mat
            elif name.endswith("_Hair"):
                o.data.materials[0] = hair_mat
            elif name.endswith("_Skin") or not name.startswith(stage + "__"):
                o.data.materials[0] = skin_mat if not name.endswith(("_Eyes",)) else o.data.materials[0]
for o in keep:
    o.hide_render = True
    o.hide_set(True)

cam_data = bpy.data.cameras.new("PreviewCam")
cam_data.type = "ORTHO"
cam = bpy.data.objects.new("PreviewCam", cam_data)
bpy.context.scene.collection.objects.link(cam)
target = Vector((0, 0, -(len(bodies) - 1) * SPACE / 2 + 0.2))
cam.location = target + direction.normalized() * 60
cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
bpy.context.scene.camera = cam
for loc, energy in (((-15, -18, 25), 5000), ((18, -4, 18), 3000), ((0, 20, 15), 2500)):
    ld = bpy.data.lights.new("PreviewLight", "AREA")
    ld.energy = energy
    ld.size = 20
    lo = bpy.data.objects.new("PreviewLight", ld)
    lo.location = loc
    lo.rotation_euler = (Vector((0, 0, 0)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.collection.objects.link(lo)
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
px = int(os.environ.get("MOG_PX", "220"))
scene.render.resolution_x = px * cols
scene.render.resolution_y = px * len(bodies)
cam_data.ortho_scale = max(cols, len(bodies)) * SPACE
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = out
scene.world.color = (0.16, 0.15, 0.2)
scene.view_settings.view_transform = "AgX"
bpy.ops.render.render(write_still=True)
print("Hair preview:", out)

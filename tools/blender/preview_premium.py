"""Aperçu rapide des tenues Robux, sans exporter ni enregistrer le .blend (D125).

    blender -b assets/blender/wardrobe.blend --python tools/blender/preview_premium.py

Variables d'environnement :
- MOG_LOOKS : tenues à montrer, séparées par des virgules (défaut : toutes les tenues Robux)
- MOG_BODIES : corps, séparés par des virgules (défaut : Bro,GodMogger,AlphaF)
- MOG_VIEW : front, back ou three (défaut : three, trois quarts face)
- MOG_OUT : fichier PNG (défaut : assets/export/characters/premium_preview.png)
Les pièces lumineuses (_Glow, _GlowDeco) sont rendues en émission, comme le Néon de Roblox.
"""
import bpy, os, math
from mathutils import Vector

ROOT = r"C:\Users\antoi\Documents\MogLife"
D = os.path.join(ROOT, "tools", "blender")

# Définitions de build_style.py, sans la construction complète ni l'export
source = open(os.path.join(D, "build_style.py"), encoding="utf-8").read()
head = source.split("\natlas = paint_style_atlas()\n")[0]
exec(compile(head, "build_style.py", "exec"), globals())

looks = [s for s in os.environ.get("MOG_LOOKS", ",".join(PREMIUM_LOOKS)).split(",") if s]
bodies = [s for s in os.environ.get("MOG_BODIES", "Bro,GodMogger,AlphaF").split(",") if s]
view = os.environ.get("MOG_VIEW", "three")
out = os.environ.get("MOG_OUT", os.path.join(ROOT, "assets", "export", "characters", "premium_preview.png"))
ONLY_LOOKS = set(looks)

atlas = paint_style_atlas()
sources = {}
for stage in bodies:
    g = geometry(stage)
    g["stage"] = stage
    builder = Builder("Preview_" + stage, atlas)
    w = Wardrobe(builder)
    build_looks(w, stage, g)
    for item, parts in w.items.items():
        for part, obj in merge_item(stage, item, parts, builder.mat, builder.col).items():
            sources[obj.name] = obj
    for o in bpy.data.collections["Body_" + stage].objects:
        if o.type == "MESH":
            sources[o.name] = o

keep = set(sources.values())
for obj in list(bpy.context.scene.objects):
    if obj not in keep:
        bpy.data.objects.remove(obj, do_unlink=True)
for o in keep:
    o.hide_set(False)
    o.hide_render = False
    o.hide_viewport = False
for lc in bpy.context.view_layer.layer_collection.children:
    lc.exclude = False
    lc.hide_viewport = False

skin_mat = bpy.data.materials.new("PreviewSkin")
skin_mat.diffuse_color = (0.8, 0.52, 0.32, 1)
skin_mat.use_nodes = True
next(n for n in skin_mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (0.8, 0.52, 0.32, 1)
glow_mats = {}


def glow_material(color):
    key = tuple(round(c, 3) for c in color)
    if key not in glow_mats:
        m = bpy.data.materials.new("PreviewGlow")
        m.use_nodes = True
        nodes = m.node_tree.nodes
        for n in list(nodes):
            if n.type == "BSDF_PRINCIPLED":
                nodes.remove(n)
        em = nodes.new("ShaderNodeEmission")
        em.inputs["Color"].default_value = (*color, 1)
        em.inputs["Strength"].default_value = 4.0
        outn = next(n for n in nodes if n.type == "OUTPUT_MATERIAL")
        m.node_tree.links.new(em.outputs[0], outn.inputs[0])
        glow_mats[key] = m
    return glow_mats[key]



cols = len(looks)
for bi, stage in enumerate(bodies):
    for li, look in enumerate(looks):
        x = (li - (cols - 1) / 2) * 9.0
        z = -bi * 10.5
        for name, src in sources.items():
            if name.startswith(stage + "__"):
                item = name.split("__")[1]
                if item not in (look + "Top", look + "Bottom"):
                    continue
            elif name.startswith(stage + "_"):
                if any(t in name for t in ("_Top", "_Shorts", "_Hair")):
                    continue
            else:
                continue
            o = src.copy()
            o.data = src.data.copy()
            bpy.context.scene.collection.objects.link(o)
            o.location = (x, 0, z)
            if name.endswith(("_Glow", "_GlowDeco")):
                o.data.materials[0] = glow_material(GLOW_COLORS.get(look, (1, 0.6, 0.2)))
            elif name.endswith(("_GlowB", "_GlowBDeco")):
                o.data.materials[0] = glow_material(GLOW_COLORS_B.get(look, (1, 0.9, 0.6)))
for o in keep:
    o.hide_render = True
    o.hide_set(True)

direction = {"front": Vector((0, -1, 0.12)), "back": Vector((0, 1, 0.12)), "three": Vector((0.55, -1, 0.2))}[view]
cam_data = bpy.data.cameras.new("PreviewCam")
cam_data.type = "ORTHO"
cam = bpy.data.objects.new("PreviewCam", cam_data)
bpy.context.scene.collection.objects.link(cam)
target = Vector((0, 0, 4.2 - (len(bodies) - 1) * 10.5 / 2))
cam.location = target + direction.normalized() * 60
cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
bpy.context.scene.camera = cam
for loc, energy in (((-15, -18, 25), 5000), ((18, -4, 18), 3000), ((0, 20, 15), 2500)):
    ld = bpy.data.lights.new("PreviewLight", "AREA")
    ld.energy = energy
    ld.size = 20
    lo = bpy.data.objects.new("PreviewLight", ld)
    lo.location = loc
    lo.rotation_euler = (Vector((0, 0, 3)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.collection.objects.link(lo)
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
try:
    scene.eevee.use_bloom = True
except AttributeError:
    pass
px = int(os.environ.get("MOG_PX", "300"))
scene.render.resolution_x = px * cols
scene.render.resolution_y = int(px * 1.31) * len(bodies)
cam_data.ortho_scale = max(cols * 9.0, len(bodies) * 10.5) + 0.3
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = out
scene.world.color = (0.12, 0.1, 0.16)
scene.view_settings.view_transform = "AgX"
bpy.ops.render.render(write_still=True)
print("Premium preview:", out)

"""Render a small, repeatable wardrobe contact sheet without changing the saved .blend.

Run from the project root with Blender in background mode:
    blender -b assets/blender/wardrobe.blend --python tools/blender/preview_wardrobe.py

The preview is written to assets/export/characters/wardrobe_preview.png.
"""

import os
import bpy
from mathutils import Vector


ROOT = r"C:\Users\antoi\Documents\MogLife"
OUTPUT = ROOT + r"\assets\export\characters\wardrobe_preview.png"

# Existing combinations cover both body shapes and every clothing silhouette.
LOOKS = (
    ("Bro", "TightTank", "FluoShorts", "Banana", "GoldChain"),
    ("BroF", "Hawaiian", "LeatherPants", "Bob", "DumbbellShades"),
    ("Bro", "BoxerRobe", "VelvetJoggers", "Mohawk", "Sweatbands"),
    ("BroF", "CircuitAceTop", "CircuitAceBottom", None, None),
    ("Bro", "FrostFlexTop", "FrostFlexBottom", None, None),
    ("BroF", "PaperCrownTop", "PaperCrownBottom", None, None),
)
if os.environ.get("MOG_PREVIEW_EXTREMES") == "1":
    OUTPUT = ROOT + r"\assets\export\characters\wardrobe_extremes.png"
    LOOKS = (
        ("Normie", "CircuitAceTop", "CircuitAceBottom", None, None),
        ("NormieF", "FrostFlexTop", "FrostFlexBottom", None, None),
        ("Normie", "PaperCrownTop", "PaperCrownBottom", None, None),
        ("GodMogger", "CircuitAceTop", "CircuitAceBottom", None, None),
        ("GodMoggerF", "FrostFlexTop", "FrostFlexBottom", None, None),
        ("GodMoggerF", "PaperCrownTop", "PaperCrownBottom", None, None),
    )
if os.environ.get("MOG_PREVIEW_LOOKS") == "1":
    OUTPUT = ROOT + r"\assets\export\characters\outfits_preview.png"
    LOOKS = (
        ("Bro", "CircuitAceTop", "CircuitAceBottom", None, None),
        ("BroF", "BoardwalkBoltTop", "BoardwalkBoltBottom", None, None),
        ("Bro", "VelvetVillainTop", "VelvetVillainBottom", None, None),
        ("BroF", "MoonMechanicTop", "MoonMechanicBottom", None, None),
        ("Normie", "FrostFlexTop", "FrostFlexBottom", None, None),
        ("GodMoggerF", "PaperCrownTop", "PaperCrownBottom", None, None),
    )
if os.environ.get("MOG_PREVIEW_ALL_LOOKS") == "1":
    OUTPUT = ROOT + r"\assets\export\characters\outfits_all.png"
    names = ("CircuitAce", "BoardwalkBolt", "VelvetVillain", "MoonMechanic", "GoldenHour",
             "BubblegumBlitz", "BrickhouseBrawler", "ThunderArcade", "RoyalRumble", "MidnightExpress",
             "JungleJolt", "FrostFlex", "TurboTaxi", "DiscoDynamo", "CometCoach",
             "SunsetStunt", "GarageGremlin", "CloudCruiser", "IronMeteor", "PaperCrown")
    LOOKS = tuple((("BroF" if i % 2 else "Bro"), name + "Top", name + "Bottom", None, None)
                  for i, name in enumerate(names))

sources = {obj.name: obj.copy() for obj in bpy.data.objects if obj.type == "MESH"}
for obj in list(bpy.context.scene.objects):
    bpy.data.objects.remove(obj, do_unlink=True)

materials = {}

def tinted_material(source, tint):
    base = source.data.materials[0]
    key = (base.name, tint)
    if key not in materials:
        mat = base.copy()
        mat.name = base.name + "_Preview_" + tint
        nodes = mat.node_tree.nodes
        links = mat.node_tree.links
        tex = next(node for node in nodes if node.type == "TEX_IMAGE")
        shader = next(node for node in nodes if node.type == "BSDF_PRINCIPLED")
        mix = nodes.new("ShaderNodeMixRGB")
        mix.blend_type = "MIX"
        mix.inputs[1].default_value = {
            "Skin": (0.8, 0.52, 0.32, 1),
            "Hair": (0.24, 0.11, 0.045, 1),
            "Eyes": (0.1, 0.55, 0.8, 1),
        }[tint]
        links.new(tex.outputs["Alpha"], mix.inputs[0])
        links.new(tex.outputs["Color"], mix.inputs[2])
        links.new(mix.outputs["Color"], shader.inputs["Base Color"])
        materials[key] = mat
    return materials[key]

def clone(source, offset):
    obj = source.copy()
    obj.data = source.data.copy()
    name = source.name
    if "__" in name:
        tint = name.rsplit("_", 1)[-1] if name.endswith(("_Hair", "_Skin")) else None
    else:
        tint = "Hair" if name.endswith(("_Hair", "_BrowConfident", "_BrowNervous", "_BrowDetermined")) else "Eyes" if name.endswith("_Eyes") else "Skin"
    if tint in ("Skin", "Hair", "Eyes"):
        obj.data.materials[0] = tinted_material(source, tint)
    bpy.context.collection.objects.link(obj)
    obj.location = Vector(offset)
    obj.hide_render = False
    obj.hide_set(False)
    return obj


all_looks = os.environ.get("MOG_PREVIEW_ALL_LOOKS") == "1"
for index, (body, top, bottom, hair, accessory) in enumerate(LOOKS):
    x = ((index % 5) - 2) * 6.5 if all_looks else (index - 2.5) * 6.5
    y = 0
    z = (1.5 - index // 5) * 8 if all_looks else 0
    wanted = {top, bottom, hair, accessory}
    for name, source in sources.items():
        if name.startswith(body + "__"):
            if name.split("__")[1] in wanted:
                clone(source, (x, y, z))
        elif name.startswith(body + "_") and "__" not in name:
            if ("_Top" in name and top) or ("_Shorts" in name and bottom) or ("_Hair" in name and hair):
                continue
            clone(source, (x, y, z))

bpy.ops.object.camera_add(location=(0, -35, 11))
camera = bpy.context.object
direction = Vector((0, 0, 6.8)) - camera.location
camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
camera.data.type = "ORTHO"
camera.data.ortho_scale = 44
if os.environ.get("MOG_PREVIEW_BACK") == "1":
    OUTPUT = ROOT + r"\assets\export\characters\outfits_extremes_back.png"
    camera.location = (0, 35, 11)
    camera.rotation_euler = (Vector((0, 0, 6.8)) - camera.location).to_track_quat("-Z", "Y").to_euler()
if all_looks:
    camera.location = (0, -60, 6)
    camera.rotation_euler = (Vector((0, 0, 6)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.ortho_scale = 37
bpy.context.scene.camera = camera

for location, energy, size in (((-12, -15, 25), 4200, 18), ((14, 2, 20), 3200, 16)):
    bpy.ops.object.light_add(type="AREA", location=location)
    light = bpy.context.object
    light.data.energy = energy
    light.data.shape = "DISK"
    light.data.size = size

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 2400
scene.render.resolution_y = 750
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = OUTPUT
if os.environ.get("MOG_PREVIEW_LOOKS") == "1":
    scene.render.resolution_x = 3000
    scene.render.resolution_y = 900
if all_looks:
    scene.render.resolution_x = 3000
    scene.render.resolution_y = 3000
scene.world.color = (0.16, 0.12, 0.2)
scene.view_settings.view_transform = "AgX"
bpy.ops.render.render(write_still=True)
print("Wardrobe preview:", OUTPUT)

"""
Construit le portail du Colisée (D105) et l'exporte pour Roblox Studio :
- assets/export/props/Props_Colosseum_Portal.fbx : un seul MeshPart, aux couleurs de la palette du Colisée
Hors de Blender : blender -b --python tools/blender/export_portal.py (MOG_PREVIEW=chemin.png pour une image de contrôle)
Import dans Studio : Accueil -> Importer 3D -> Props_Colosseum_Portal.fbx, puis tools/install_props.luau.
"""
import bpy, bmesh, math, os

D = r"C:\Users\antoi\Documents\MogLife\tools\blender"
OUT = r"C:\Users\antoi\Documents\MogLife\assets\export\props"

ns = {}
exec(open(os.path.join(D, "props_lib.py"), encoding="utf-8").read(), ns)
exec(open(os.path.join(D, "props_colosseum.py"), encoding="utf-8").read(), ns)
exec(open(os.path.join(D, "props_portal.py"), encoding="utf-8").read(), ns)

pal = ns["build_palette"]()
ns["colosseum_palette"](pal)
P = ns["Props"](pal, "Props_Colosseum_Portal", spacing=40, columns=1, mirror_x=True)
P.clear()
ns["build_portal"](P)

# Ogive et claveaux : on triangule nous-mêmes (oreilles), comme pour le Colisée
for obj in P.col.objects:
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.triangulate(bm, faces=bm.faces, quad_method="BEAUTY", ngon_method="EAR_CLIP")
    bm.to_mesh(obj.data)
    bm.free()

if not os.environ.get("MOG_NO_EXPORT"):
    path = os.path.join(OUT, "Props_Colosseum_Portal.fbx")
    count = ns["export_fbx"](["Props_Colosseum_Portal"], path)
    print(f"{count} pièce exportée dans {path} ({os.path.getsize(path) // 1024} Ko)")
print("\n".join(P.report))

preview = os.environ.get("MOG_PREVIEW")
if preview:
    scene = bpy.context.scene
    for o in list(scene.objects):
        if o.name not in P.col.objects:
            o.hide_render = True
    target = P.col.objects[0]
    cam = bpy.data.cameras.new("PreviewCam")
    cam_obj = bpy.data.objects.new("PreviewCam", cam)
    scene.collection.objects.link(cam_obj)
    angle = math.radians(float(os.environ.get("MOG_PREVIEW_YAW", "-30")))
    dist = 40
    h = target.dimensions.z
    cam_obj.location = (math.sin(angle) * dist, -math.cos(angle) * dist, h * 0.6)
    from mathutils import Vector
    direction = Vector((0, 0, h * 0.45)) + target.location - cam_obj.location
    cam_obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    cam.lens = 45
    scene.camera = cam_obj
    try:
        scene.render.engine = "BLENDER_WORKBENCH"
    except TypeError:
        pass
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"
    scene.display.shading.show_shadows = True
    scene.render.resolution_x, scene.render.resolution_y = 900, 900
    scene.render.filepath = preview
    bpy.ops.render.render(write_still=True)
    print("aperçu :", preview)

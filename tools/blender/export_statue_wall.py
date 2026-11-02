"""
Construit le Mur des Colosses (D107) et l'exporte pour Roblox Studio :
- assets/export/props/Props_StatueWall.fbx : modules, pilier, 4 colosses (+ or + lueurs), un objet = un MeshPart
- assets/export/props/statue_wall_manifest.json : tailles, centres et points d'effet (lu par tools/build_map.py)
Hors de Blender : blender -b --factory-startup --python tools/blender/export_statue_wall.py
  MOG_PREVIEW=chemin.png : image de contrôle (MOG_PREVIEW_POSE=Atlas|Torch|Scepter|Flex|all, MOG_PREVIEW_YAW=-25,
  MOG_PREVIEW_DIST=90, MOG_PREVIEW_Z=0.55 : hauteur visée, en part de la hauteur du module)
  MOG_ONLY=Atlas,Flex : ne sculpte que ces poses (essais rapides ; l'export est alors désactivé)
Import dans Studio : Accueil -> Importer 3D -> Props_StatueWall.fbx, puis tools/install_props.luau.
"""
import bpy, json, math, os
from mathutils import Vector

D = r"C:\Users\antoi\Documents\MogLife\tools\blender"
OUT = r"C:\Users\antoi\Documents\MogLife\assets\export\props"

for o in list(bpy.data.objects):
    bpy.data.objects.remove(o)

ns = {}
exec(open(os.path.join(D, "props_statue_wall.py"), encoding="utf-8").read(), ns)
only = [p for p in os.environ.get("MOG_ONLY", "").split(",") if p]
pieces, manifest = ns["build_all"](only or None)

col = bpy.data.collections.new("Props_StatueWall")
bpy.context.scene.collection.children.link(col)
for o in pieces:
    for c in o.users_collection:
        c.objects.unlink(o)
    col.objects.link(o)

for name, m in manifest["pieces"].items():
    print(f"{name}: {m['tris']} tris, {m['size'][0]:.1f} x {m['size'][1]:.1f} x {m['size'][2]:.1f}")

if not only and not os.environ.get("MOG_NO_EXPORT"):
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    for o in pieces:
        o.select_set(True)
    bpy.context.view_layer.objects.active = pieces[0]
    path = os.path.join(OUT, "Props_StatueWall.fbx")
    bpy.ops.export_scene.fbx(
        filepath=path, use_selection=True, object_types={"MESH"},
        axis_forward="-Z", axis_up="Y", apply_unit_scale=True, apply_scale_options="FBX_SCALE_ALL",
        mesh_smooth_type="OFF", path_mode="RELATIVE", embed_textures=False,
    )
    with open(os.path.join(OUT, "statue_wall_manifest.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=1, sort_keys=True)
    print(f"{len(pieces)} pièces exportées dans {path} ({os.path.getsize(path) // 1024} Ko)")

preview = os.environ.get("MOG_PREVIEW")
if preview:
    scene = bpy.context.scene
    pose = os.environ.get("MOG_PREVIEW_POSE", "all")
    colors = {"": (0.86, 0.84, 0.8, 1), "_Gold": (0.85, 0.62, 0.15, 1), "_Glow": (1.0, 0.85, 0.3, 1)}
    W = manifest["module"]["width"]
    shown = []
    poses = list(manifest["statues"])
    if pose != "all":
        poses = [pose]
    for k, p in enumerate(poses):
        dx = (k - (len(poses) - 1) / 2) * W
        for o in pieces:
            if o.name.startswith(f"Colossus_{p}"):
                o.location.x = dx
                suffix = o.name[len(f"Colossus_{p}"):]
                o.color = colors.get(suffix, colors[""])
                shown.append(o)
        if k > 0:
            for base in ("StatueWall_Module",):
                src = bpy.data.objects[base]
                dup = src.copy()
                col.objects.link(dup)
                dup.location.x = dx
                shown.append(dup)
    for o in pieces:
        if o.name.startswith("StatueWall_"):
            o.location.x = -(len(poses) - 1) / 2 * W if o.name == "StatueWall_Module" else -(len(poses)) / 2 * W
            o.color = (0.8, 0.78, 0.74, 1)
            shown.append(o)
    for o in list(col.objects):
        o.hide_render = o not in shown
        if o.name.startswith("StatueWall_"):
            o.color = (0.8, 0.78, 0.74, 1)
    cam = bpy.data.cameras.new("PreviewCam")
    cam_obj = bpy.data.objects.new("PreviewCam", cam)
    scene.collection.objects.link(cam_obj)
    angle = math.radians(float(os.environ.get("MOG_PREVIEW_YAW", "-25")))
    dist = float(os.environ.get("MOG_PREVIEW_DIST", str(40 + 32 * len(poses))))
    h = manifest["module"]["height"]
    aim = Vector((0, 0, h * float(os.environ.get("MOG_PREVIEW_Z", "0.5"))))
    cam_obj.location = aim + Vector((math.sin(angle) * dist, -math.cos(angle) * dist, float(os.environ.get("MOG_PREVIEW_UP", "-10"))))
    cam_obj.rotation_euler = (aim - cam_obj.location).to_track_quat("-Z", "Y").to_euler()
    cam.lens = float(os.environ.get("MOG_PREVIEW_LENS", "40"))
    cam.clip_end = 2000
    scene.camera = cam_obj
    try:
        scene.render.engine = "BLENDER_WORKBENCH"
    except TypeError:
        pass
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "OBJECT"
    scene.display.shading.show_shadows = True
    scene.display.shading.show_cavity = True
    scene.display.shading.cavity_type = "BOTH"
    scene.render.resolution_x = int(os.environ.get("MOG_PREVIEW_W", "1100"))
    scene.render.resolution_y = int(os.environ.get("MOG_PREVIEW_H", "900"))
    scene.render.filepath = preview
    bpy.ops.render.render(write_still=True)
    print("aperçu :", preview)

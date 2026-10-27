"""
Squelette des boss (D85) : reconstruit chaque boss (build_bosses.py, build_kevin.py), attache chacune de ses pièces
entièrement à un os (la cuisse à l'os de la cuisse, l'avant-bras à celui de l'avant-bras : mouvements nets, aucune
déformation molle), fusionne le tout en un seul mesh relié au squelette, puis exporte un FBX par boss :
assets/export/Boss_<Id>_Rig.fbx (+ texture PNG). À importer dans Studio en « rig » (MeshPart avec ses Bones).

Os (mêmes noms que les pièces R15 de Roblox, animés par le code de src/client/BossFights/) :
  Root > LowerTorso > UpperTorso > Head
                    > UpperTorso > (Left|Right)UpperArm > (Left|Right)LowerArm > (Left|Right)Hand
                    > (Left|Right)UpperLeg > (Left|Right)LowerLeg > (Left|Right)Foot
Repère des modèles dans Blender : Z en haut, le personnage regarde vers -Y ; sa gauche est donc +X.
Variable optionnelle ONLY = ["CoachTurbo", ...] pour ne traiter que certains boss.
À exécuter dans Blender (MCP) : exec(open(r"...\\rig_bosses.py", encoding="utf-8").read())
"""
import bpy, bmesh, os
from mathutils import Vector

ROOT = r"C:\Users\antoi\Documents\MogLife\tools\blender"
OUT_DIR = r"C:\Users\antoi\Documents\MogLife\assets\export"
os.makedirs(OUT_DIR, exist_ok=True)


def run(path, extra=None):
    g = dict(globals())
    g.update(extra or {})
    exec(compile(open(path, encoding="utf-8").read(), path, "exec"), g)
    return g


# ------------------------------------------------------------------ articulations de chaque boss
def bro_joints(geo, scale):
    """Os (tête, queue, parent) d'un boss de build_bosses.py, à partir de ses articulations."""
    V = lambda *c: Vector(c) * scale
    hip, bottom, top = geo["hip_z"], geo["torso_bottom"], geo["top"]
    j = {
        "Root": (V(0, 0, 0), V(0, 0, hip * 0.5), None),
        "LowerTorso": (V(0, 0, hip), V(0, 0, bottom), "Root"),
        "UpperTorso": (V(0, 0, bottom), V(0, 0, top), "LowerTorso"),
        "Head": (V(0, geo["hy"] * 0.5, top), V(0, geo["hy"], geo["head_z"] + geo["head_r"]), "UpperTorso"),
    }
    for s, side in ((1, "Left"), (-1, "Right")):
        sh, el, wr = geo["arms"][s]
        tip = wr + (wr - el).normalized() * 0.3
        j[side + "UpperArm"] = (sh * scale, el * scale, "UpperTorso")
        j[side + "LowerArm"] = (el * scale, wr * scale, side + "UpperArm")
        j[side + "Hand"] = (wr * scale, tip * scale, side + "LowerArm")
        x = geo["leg_x"] * s
        j[side + "UpperLeg"] = (V(x * 1.05, 0, hip), V(x, 0, geo["knee_z"]), "LowerTorso")
        j[side + "LowerLeg"] = (V(x, 0, geo["knee_z"]), V(x, 0, geo["foot_h"]), side + "UpperLeg")
        j[side + "Foot"] = (V(x, 0, geo["foot_h"]), V(x, -0.45, 0.02), side + "LowerLeg")
    zones = dict(top=top * scale, hip=hip * scale, bottom=bottom * scale, half_shoulder=geo["shoulder_w"] * 0.45 * scale)
    return j, zones


def kevin_joints():
    """Os de Kevin (build_kevin.py : sa gauche est +X ; jambe d'un seul tenant)."""
    V = Vector
    j = {
        "Root": (V((0, 0, 0)), V((0, 0, 1.6)), None),
        "LowerTorso": (V((0, 0.05, 3.1)), V((0, 0.0, 3.6)), "Root"),
        "UpperTorso": (V((0, 0.0, 3.6)), V((0, -0.2, 4.95)), "LowerTorso"),
        "Head": (V((0, -0.3, 4.95)), V((0, -0.66, 6.7)), "UpperTorso"),
    }
    for s, side in ((1, "Left"), (-1, "Right")):
        sh, el, wr = V((0.42 * s, -0.22, 4.85)), V((0.66 * s, -0.28, 3.95)), V((0.84 * s, -0.34, 3.08))
        j[side + "UpperArm"] = (sh, el, "UpperTorso")
        j[side + "LowerArm"] = (el, wr, side + "UpperArm")
        j[side + "Hand"] = (wr, V((0.88 * s, -0.36, 2.71)), side + "LowerArm")
        j[side + "UpperLeg"] = (V((0.27 * s, 0.05, 3.2)), V((0.29 * s, 0.02, 1.75)), "LowerTorso")
        j[side + "LowerLeg"] = (V((0.29 * s, 0.02, 1.75)), V((0.3 * s, 0.0, 0.3)), side + "UpperLeg")
        j[side + "Foot"] = (V((0.33 * s, 0.0, 0.3)), V((0.33 * s, -0.5, 0.05)), side + "LowerLeg")
    zones = dict(top=4.95, hip=3.1, bottom=3.6, half_shoulder=0.38)
    # Pièces d'un seul tenant qu'on rattache à la main : la jambe entière suit la cuisse
    overrides = {"LegL": "RightUpperLeg", "LegR": "LeftUpperLeg"}  # Kevin : L = -X = sa droite
    return j, zones, overrides


# ------------------------------------------------------------------ pièce -> os
def seg_distance(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (a + ab * t - p).length


def centroid(o):
    vs = o.data.vertices
    c = Vector((0, 0, 0))
    for v in vs:
        c += o.matrix_world @ v.co
    return c / max(len(vs), 1)


def bone_for(o, joints, zones):
    c = centroid(o)
    # Le tronc (abdos, pectoraux, dorsaux, trapèzes, short) reste au tronc, même près des bras
    if zones["hip"] <= c.z <= zones["top"] + 0.05 and abs(c.x) < zones["half_shoulder"]:
        return "LowerTorso" if c.z < zones["bottom"] + (zones["top"] - zones["bottom"]) * 0.25 else "UpperTorso"
    best, best_d = None, 1e9
    for name, (a, b, _) in joints.items():
        if name == "Root":
            continue
        d = seg_distance(c, a, b)
        if d < best_d:
            best, best_d = name, d
    return best


# ------------------------------------------------------------------ fusion, squelette, export
def rig_and_export(name, joints, zones, overrides=None):
    col = bpy.data.collections[name]
    pieces = [o for o in col.objects if o.type == "MESH" and not o.name.endswith("_Rigged")]
    merged = bmesh.new()
    groups = {}  # os -> indices de sommets
    material = None
    counts = {}
    for o in pieces:
        start = len(merged.verts)
        m = o.data.copy()
        m.transform(o.matrix_world)
        merged.from_mesh(m)
        bpy.data.meshes.remove(m)
        merged.verts.ensure_lookup_table()
        bone = (overrides or {}).get(o.name.split(".")[0]) or bone_for(o, joints, zones)
        counts[bone] = counts.get(bone, 0) + 1
        groups.setdefault(bone, []).extend(range(start, len(merged.verts)))
        if material is None and o.data.materials:
            material = o.data.materials[0]
    mesh = bpy.data.meshes.new(name + "_Rigged")
    merged.to_mesh(mesh)
    merged.free()
    if material:
        mesh.materials.append(material)
    for p in mesh.polygons:
        p.use_smooth = False

    for old in (name + "_Rigged", name + "_Armature"):
        if bpy.data.objects.get(old):
            bpy.data.objects.remove(bpy.data.objects[old], do_unlink=True)
    obj = bpy.data.objects.new(name + "_Rigged", mesh)
    col.objects.link(obj)
    for bone, indices in groups.items():
        vg = obj.vertex_groups.new(name=bone)
        vg.add(indices, 1.0, "REPLACE")

    arm_data = bpy.data.armatures.new(name + "_Armature")
    arm = bpy.data.objects.new(name + "_Armature", arm_data)
    col.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for bone_name, (head, tail, _) in joints.items():
        eb = arm_data.edit_bones.new(bone_name)
        eb.head, eb.tail = head, tail
        if (tail - head).length < 0.05:
            eb.tail = head + Vector((0, 0, 0.1))
    for bone_name, (_, _, parent) in joints.items():
        if parent:
            arm_data.edit_bones[bone_name].parent = arm_data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    obj.parent = arm
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = arm

    # Texture PNG à côté (même atlas que l'ancien modèle : les UV sont identiques)
    if material:
        for node in material.node_tree.nodes:
            if node.type == "TEX_IMAGE" and node.image:
                path = os.path.join(OUT_DIR, f"Boss_{name}_texture.png")
                node.image.save(filepath=path)
                node.image.filepath = path

    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    arm.select_set(True)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = arm
    out = os.path.join(OUT_DIR, f"Boss_{name}_Rig.fbx")
    bpy.ops.export_scene.fbx(
        filepath=out, use_selection=True, object_types={"ARMATURE", "MESH"},
        axis_forward="-Z", axis_up="Y", apply_unit_scale=True, apply_scale_options="FBX_SCALE_ALL",
        mesh_smooth_type="FACE", path_mode="RELATIVE", embed_textures=False,
        add_leaf_bones=False, bake_anim=False, use_armature_deform_only=True,
    )
    tris = sum(len(p.vertices) - 2 for p in mesh.polygons)
    print(f"{name}: {len(pieces)} pièces, {tris} triangles, os {sorted(counts.items())} -> {out}")
    return obj, arm


ONLY = globals().get("ONLY") or ["Kevin", "Brayan", "CoachTurbo", "NoLegs", "BlockKing"]
lib = run(os.path.join(ROOT, "build_bosses.py"), {"BOSSES_LIBRARY": True})
offset = 0.0
for name in ONLY:
    if name == "Kevin":
        run(os.path.join(ROOT, "build_kevin.py"))
        joints, zones, overrides = kevin_joints()
    else:
        cfg = lib["BOSSES"][name]
        b = lib["build_bro"](name, cfg)
        joints, zones = bro_joints(b.geo, cfg.get("scale", 1.0))
        overrides = None
    obj, arm = rig_and_export(name, joints, zones, overrides)
    # Aperçu côte à côte (sans effet sur l'export, déjà fait)
    for o in bpy.data.collections[name].objects:
        o.hide_set(o not in (obj, arm))
    arm.location.x = offset
    offset += 8

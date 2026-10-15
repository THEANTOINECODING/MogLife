"""
Corps du joueur, un par stade (Normie -> GOD MOGGER), dans le style des boss (décision D39) :
low poly PS1, anatomie réaliste mais exagérée, texture à éclairage cuit.

Chaque corps est sculpté autour du VRAI squelette R15 du stade (assets/export/bodies/skeletons.json, relevé
dans Roblox avec les proportions de src/shared/Config/Bodies.luau) et découpé en 15 pièces, une par partie
du squelette (+ les cheveux à part, que la boutique remplacera) : chaque pièce suit son articulation pendant
les animations (D28, D37).

Écrit :
- assets/export/bodies/MogLife_Bodies.fbx + une texture PNG par stade (import : Accueil -> Importer 3D,
  puis tools/install_bodies.luau)
- src/shared/Config/BodyPieces.luau : décalage de chaque pièce par rapport à sa partie (BodyService)
Dans Blender : exec(open(r"...\\tools\\blender\\build_bodies.py", encoding="utf-8").read())
Variable optionnelle ONLY = ["Normie", ...] pour ne reconstruire que certains stades (l'export prend tout).
"""
import bpy, bmesh, json, math, os, random
from mathutils import Vector

D = r"C:\Users\antoi\Documents\MogLife\tools\blender"
ROOT = r"C:\Users\antoi\Documents\MogLife"
OUT = os.path.join(ROOT, "assets", "export", "bodies")
for lib in ("lowpoly_lib.py", "bro_atlas.py"):
    path = os.path.join(D, lib)
    exec(compile(open(path, encoding="utf-8").read(), path, "exec"), globals())

SKELETONS = json.load(open(os.path.join(OUT, "skeletons.json"), encoding="utf-8"))
ORDER = ["Normie", "GymRat", "Bro", "Alpha", "Chad", "Gigachad", "GodMogger"]

SKIN = (0.93, 0.72, 0.56)
# Muscles en studs (rayons), de plus en plus exagérés ; vêtements par défaut (la boutique les changera)
STAGES = {
    "Normie": dict(top="tee", top_color=(0.55, 0.57, 0.6), shorts=(0.2, 0.3, 0.62), shoe=(0.95, 0.95, 0.95),
                   hair=(0.25, 0.16, 0.09), mouth="nervous", belly=0.08,
                   delt=0.2, bicep=0.17, forearm=0.15, fist=0.28, chest_w=1.25, depth=0.62, pec=0.0, lat=0.0, trap=0.05,
                   neck=0.17, thigh=0.24, calf=0.17, head_r=0.72, jaw_w=0.55, jaw_h=0.36, jaw_fwd=0.02, eye_r=0.16),
    "GymRat": dict(top="tank", top_color=(0.86, 0.22, 0.22), shorts=(0.15, 0.15, 0.2), shoe=(0.95, 0.95, 0.95),
                   hair=(0.25, 0.16, 0.09), mouth="grin",
                   delt=0.28, bicep=0.25, forearm=0.19, fist=0.31, chest_w=1.6, depth=0.75, pec=0.2, lat=0.16, trap=0.15,
                   neck=0.21, thigh=0.3, calf=0.2, head_r=0.68, jaw_w=0.6, jaw_h=0.4, jaw_fwd=0.05, eye_r=0.16),
    "Bro": dict(top="tank", top_color=(0.2, 0.62, 0.66), shorts=(0.15, 0.15, 0.2), shoe=(0.95, 0.95, 0.95),
                hair=(0.2, 0.13, 0.07), mouth="grin", stubble=True,
                delt=0.37, bicep=0.34, forearm=0.24, fist=0.34, chest_w=2.0, depth=0.9, pec=0.3, lat=0.28, trap=0.3,
                neck=0.26, thigh=0.37, calf=0.24, head_r=0.64, jaw_w=0.68, jaw_h=0.45, jaw_fwd=0.1, eye_r=0.16),
    "Alpha": dict(top="none", shorts=(0.12, 0.12, 0.16), shoe=(0.15, 0.15, 0.17), hair=(0.15, 0.1, 0.06),
                  mouth="smug", stubble=True,
                  delt=0.48, bicep=0.45, forearm=0.3, fist=0.38, chest_w=2.4, depth=1.05, pec=0.42, lat=0.4, trap=0.5,
                  neck=0.33, thigh=0.45, calf=0.28, head_r=0.62, jaw_w=0.78, jaw_h=0.5, jaw_fwd=0.15, eye_r=0.16),
    "Chad": dict(top="none", shorts=(0.1, 0.1, 0.12), shoe=(0.15, 0.15, 0.17), hair=(0.95, 0.8, 0.4),
                 mouth="smug", stubble=True, cleft=True,
                 delt=0.6, bicep=0.56, forearm=0.36, fist=0.42, chest_w=2.85, depth=1.2, pec=0.52, lat=0.55, trap=0.75,
                 neck=0.4, thigh=0.52, calf=0.31, head_r=0.6, jaw_w=0.9, jaw_h=0.56, jaw_fwd=0.22, eye_r=0.15),
    "Gigachad": dict(top="none", shorts=(0.1, 0.1, 0.12), shoe=(0.15, 0.15, 0.17), hair=(0.12, 0.08, 0.05),
                     mouth="smug", stubble=True, cleft=True, veins=True,
                     delt=0.72, bicep=0.68, forearm=0.42, fist=0.46, chest_w=3.3, depth=1.35, pec=0.62, lat=0.7,
                     trap=1.0, neck=0.48, thigh=0.6, calf=0.35, head_r=0.58, jaw_w=1.02, jaw_h=0.62, jaw_fwd=0.3,
                     eye_r=0.15),
    "GodMogger": dict(top="none", shorts=(0.95, 0.95, 0.93), shoe=(0.85, 0.68, 0.18), hair=(0.95, 0.85, 0.5),
                      iris=(0.75, 0.6, 0.1), mouth="smug", stubble=True, cleft=True, veins=True, glow=True,
                      delt=0.9, bicep=0.85, forearm=0.52, fist=0.52, chest_w=3.9, depth=1.55, pec=0.75, lat=0.9,
                      trap=1.35, neck=0.58, thigh=0.7, calf=0.4, head_r=0.56, jaw_w=1.18, jaw_h=0.7, jaw_fwd=0.4,
                      eye_r=0.15),
}


def B(v):
    """Coordonnées Roblox (X, Y haut, Z arrière) -> Blender (l'import FBX de Roblox inverse X)."""
    return Vector((-v[0], v[2], v[1]))


class Body:
    """Pièces d'un corps, rangées par partie du squelette."""

    def __init__(self, name, cfg):
        self.name = name
        self.atlas = paint_bro_atlas("Body" + name, dict(cfg, skin=cfg.get("skin", SKIN)))
        self.b = Builder("Body_" + name, self.atlas)
        self.parts = {}

    def make(self, part, bm, cell, front_cell=None):
        obj = self.b.make(bm, cell, front_cell)
        self.parts.setdefault(part, []).append(obj)
        return obj


def build_body(name):
    cfg = STAGES[name]
    sk = SKELETONS[name]
    J = {k: B(v) for k, v in sk["joints"].items()}
    PC = {k: B(v["center"]) for k, v in sk["parts"].items()}
    body = Body(name, cfg)
    top = cfg.get("top", "none")
    clothed = top in ("tee", "tank")
    trunk = "top" if clothed else "skin"
    random.seed(len(name))

    # ---------------------------------------------------------------- jambes et pieds
    thigh, calf = cfg["thigh"], cfg["calf"]
    for side in ("Left", "Right"):
        hip, knee, ankle = J[side + "Hip"], J[side + "Knee"], J[side + "Ankle"]
        x = hip.x
        foot_h = ankle.z + 0.08
        body.make(side + "Foot", block((x, ankle.y - 0.12 - calf * 0.3, foot_h / 2),
                                       (0.32 + calf * 0.7, 0.62 + calf * 1.1, foot_h), taper_top=0.85), "shoe")
        body.make(side + "LowerLeg", limb((x, 0, ankle.z), (x, 0, knee.z), calf * 0.55, calf, calf * 0.75, mid_t=0.62,
                                          bulge_dir=(0, 1, 0), bulge=calf * 0.25), "skin")
        body.make(side + "LowerLeg", lowsphere((x, -0.03, knee.z), (calf * 0.78, calf * 0.75, calf * 0.72), 6, 4), "skin")
        body.make(side + "UpperLeg", limb((x, 0, knee.z), (x, 0, hip.z), calf * 0.8, thigh, thigh * 0.95,
                                          bulge_dir=(0, -1, 0), bulge=thigh * 0.15), "skin")
        body.make(side + "UpperLeg", limb((x, 0, hip.z + 0.05), (x, 0, hip.z - (hip.z - knee.z) * 0.45),
                                          thigh * 1.08, thigh * 1.14, thigh * 1.1), "shorts")

    # ---------------------------------------------------------------- bassin (short)
    root = J["Root"]
    hip_w = abs(J["LeftHip"].x - J["RightHip"].x) + thigh * 2
    depth = cfg["depth"]
    body.make("LowerTorso", lowsphere((0, 0.02, root.z + 0.1), (hip_w * 0.5, depth * 0.45, 0.38)), "shorts")

    # ---------------------------------------------------------------- torse
    waist, neck = J["Waist"], J["Neck"]
    h = neck.z - waist.z
    # Le torse va toujours jusqu'aux épaules du squelette (sinon les bras flottent)
    shoulder_x = abs(J["LeftShoulder"].x)
    chest_w = max(cfg["chest_w"], shoulder_x * 2.1)
    waist_w = max(hip_w * 0.95, chest_w * 0.62)
    belly = cfg.get("belly", 0)
    body.make("UpperTorso", lowsphere((0, -belly, waist.z + h * 0.32), (waist_w / 2, depth * 0.45 + belly, h * 0.42)),
              trunk, front_cell="top_front" if clothed else "abs")
    body.make("UpperTorso", lowsphere((0, 0.02, neck.z - h * 0.36), (chest_w / 2, depth * 0.55, h * 0.44), 10, 8),
              trunk, front_cell="top_front" if clothed else "chest")
    for sx in (-1, 1):
        if cfg["lat"] > 0:
            body.make("UpperTorso", lowsphere((chest_w * 0.38 * sx, 0.1, neck.z - h * 0.45),
                                              (cfg["lat"], depth * 0.38, h * 0.32)), trunk)
        if cfg["pec"] > 0 and top != "tee":
            pec = cfg["pec"]
            body.make("UpperTorso", lowsphere((chest_w * 0.2 * sx, -depth * 0.47, neck.z - h * 0.24),
                                              (pec, pec * 0.42, pec * 0.62)), "top" if top == "tank" else "chest")
    # Trapèzes : de la nuque vers les épaules (ils grossissent beaucoup)
    trap, neck_r = cfg["trap"], cfg["neck"]
    for side in ("Left", "Right"):
        sh = J[side + "Shoulder"]
        body.make("UpperTorso", limb((sh.x * 0.25, 0.08, neck.z + 0.05 + trap * 0.12), (sh.x, 0.04, sh.z + 0.02),
                                     neck_r * 0.7 + trap * 0.1, 0.12 + trap * 0.32, cfg["delt"] * 0.6), "skin")
    if trap > 0.6:
        body.make("UpperTorso", lowsphere((0, 0.25, neck.z), (neck_r + trap * 0.3, 0.2 + trap * 0.2, 0.15 + trap * 0.22)),
                  "skin")
    # Cou (avec le torse : il ne se décroche pas quand la tête tourne)
    body.make("UpperTorso", limb((0, 0.03, neck.z - 0.3), (0, -0.02, neck.z + 0.3), neck_r * 1.1, neck_r, neck_r * 0.92),
              "skin")

    # ---------------------------------------------------------------- bras et mains
    delt, bicep, forearm, fist = cfg["delt"], cfg["bicep"], cfg["forearm"], cfg["fist"]
    sleeve = "top" if top == "tee" else ("veiny" if cfg.get("veins") else "skin")
    for side in ("Left", "Right"):
        sh, el, wr = J[side + "Shoulder"], J[side + "Elbow"], J[side + "Wrist"]
        arm_top = Vector((el.x, el.y, sh.z - 0.05))
        # Deltoïde : fait le pont entre le torse et le bras, quelle que soit la largeur du squelette
        delt_r = max(delt, abs(el.x - sh.x) * 0.75)
        body.make(side + "UpperArm", lowsphere((sh.x * 0.4 + el.x * 0.6, 0, sh.z - 0.08), (delt_r, delt * 0.95, delt * 0.9)),
                  "top" if top == "tee" else "skin")
        body.make(side + "UpperArm", limb(tuple(arm_top), tuple(el), delt * 0.62, bicep, forearm * 0.95,
                                          bulge_dir=(0, -1, 0), bulge=bicep * 0.25), "veiny" if cfg.get("veins") else "skin")
        if top == "tee":
            body.make(side + "UpperArm", limb(tuple(arm_top), tuple(arm_top.lerp(el, 0.45)), delt * 0.7,
                                              bicep * 1.12, bicep * 1.1), sleeve)
        body.make(side + "LowerArm", limb(tuple(el), tuple(wr), forearm * 0.85, forearm, forearm * 0.6, mid_t=0.3),
                  "veiny" if cfg.get("veins") else "skin")
        down = Vector((0, 0, -1))
        front = Vector((0, -1, 0))
        body.make(side + "Hand", prism(tuple(wr + down * 0.05), tuple(wr + down * fist * 1.7), fist * 0.62, fist * 0.52, sides=4),
                  "skin")
        thumb = front * fist * 0.55
        body.make(side + "Hand", prism(tuple(wr + down * fist * 0.35 + thumb), tuple(wr + down * fist * 1.05 + thumb * 1.15),
                                       fist * 0.2, fist * 0.15, sides=4), "skin")

    # ---------------------------------------------------------------- tête
    hc = PC["Head"]
    head_r = cfg["head_r"]
    hy = hc.y - 0.05 - trap * 0.1
    head_z = hc.z + 0.05
    body.make("Head", lowsphere((0, hy, head_z), (head_r * 0.82, head_r * 0.95, head_r), 10, 8), "skin", front_cell="face")
    jaw_w, jaw_h, jaw_fwd = cfg["jaw_w"], cfg["jaw_h"], cfg["jaw_fwd"]
    jaw_depth = head_r * 1.15 + jaw_fwd
    jaw_y = hy - head_r * 0.15 - jaw_fwd * 0.5
    jaw_z = head_z - head_r * 0.6 - jaw_h * 0.25
    jaw_front = jaw_y - jaw_depth / 2
    jaw_top = jaw_z + jaw_h / 2
    body.make("Head", block((0, jaw_y, jaw_z), (jaw_w, jaw_depth, jaw_h), taper_top=0.85), "skin", front_cell="face")
    body.make("Head", block((0, hy - head_r * 0.86, head_z + head_r * 0.3), (head_r * 1.35, 0.14, 0.12)), "brow")
    nose_y = min(hy - head_r * 0.88, jaw_front)
    body.make("Head", pyramid((0, nose_y, head_z - head_r * 0.05), (0, nose_y - head_r * 0.3, head_z - head_r * 0.22),
                              head_r * 0.15, head_r * 0.2), "skin")
    for sx in (-1, 1):
        body.make("Head", block((head_r * 0.82 * sx, hy + 0.02, head_z), (0.09, head_r * 0.35, head_r * 0.45)), "skin")
    mouth = cfg.get("mouth", "grin")
    lips_h = jaw_h * 0.2
    if mouth == "nervous":
        body.make("Head", block((jaw_w * 0.05, jaw_front - 0.03, jaw_z + jaw_h * 0.08), (jaw_w * 0.4, 0.07, lips_h * 0.7)),
                  "lips")
    else:
        body.make("Head", block((0, jaw_front - 0.03, jaw_z + jaw_h * 0.1), (jaw_w * 0.5, 0.07, lips_h)), "lips")
        teeth_w = jaw_w * (0.42 if mouth == "grin" else 0.22)
        body.make("Head", block((jaw_w * (0 if mouth == "grin" else 0.1), jaw_front - 0.07, jaw_z + jaw_h * 0.11),
                                (teeth_w, 0.04, jaw_h * 0.08)), "teeth")
    r = cfg["eye_r"]
    for sx in (-1, 1):
        ey = Vector((head_r * 0.36 * sx, min(hy - head_r * 0.78, jaw_front + r * 0.8),
                     max(head_z + head_r * 0.12, jaw_top + r * 0.7)))
        body.make("Head", lowsphere(tuple(ey), (r, r * 0.85, r)), "white")
        body.make("Head", lowsphere((ey.x, ey.y - r * 0.78, ey.z - r * 0.05), (r * 0.5, r * 0.14, r * 0.5), 8, 4), "iris")
        body.make("Head", lowsphere((ey.x, ey.y - r * 0.88, ey.z - r * 0.05), (r * 0.22, r * 0.08, r * 0.22), 6, 4), "black")
        body.make("Head", half_sphere((ey.x, ey.y, ey.z + r * 0.18), (r * 1.06, r * 0.95, r * 0.95)), "skin")
    # Coupe de base (pièce à part : la boutique du coiffeur la remplacera)
    body.make("Head_Hair", half_sphere((0, hy + 0.03, head_z + head_r * 0.15), (head_r * 0.88, head_r * 1.02, head_r * 0.92)),
              "hair")
    body.make("Head_Hair", lowsphere((0, hy - head_r * 0.45, head_z + head_r * 0.78),
                                     (head_r * 0.62, head_r * 0.5, head_r * 0.28), 8, 5), "hair")
    return body


def merge(body):
    """Fusionne les formes de chaque partie en une pièce <Stade>_<Partie> (sommets en coordonnées monde)."""
    pieces = {}
    for part, objs in body.parts.items():
        bm = bmesh.new()
        for o in objs:
            bm.from_mesh(o.data)
        name = f"{body.name}_{part}"
        old = bpy.data.objects.get(name)
        if old:
            bpy.data.objects.remove(old, do_unlink=True)
        me = bpy.data.meshes.get(name)
        if me:
            bpy.data.meshes.remove(me)
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        me.materials.append(body.b.mat)
        for p in me.polygons:
            p.use_smooth = False
        obj = bpy.data.objects.new(name, me)
        for o in objs:
            m = o.data
            bpy.data.objects.remove(o, do_unlink=True)
            if m.users == 0:
                bpy.data.meshes.remove(m)
        body.b.col.objects.link(obj)
        pieces[part] = obj
    return pieces


def offsets(name, pieces):
    """Centre de chaque pièce (centre de sa boîte, comme un MeshPart) par rapport au centre de sa partie R15."""
    sk = SKELETONS[name]["parts"]
    out = {}
    for part, obj in pieces.items():
        xs = [v.co.x for v in obj.data.vertices]
        ys = [v.co.y for v in obj.data.vertices]
        zs = [v.co.z for v in obj.data.vertices]
        c = ((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, (min(zs) + max(zs)) / 2)
        roblox = (-c[0], c[2], c[1])
        owner = part.split("_")[0]
        pc = sk[owner]["center"]
        out[part] = [round(roblox[i] - pc[i], 3) for i in range(3)]
    return out


ONLY = globals().get("ONLY") or ORDER
manifest = {}
for i, name in enumerate(ORDER):
    if name in ONLY:
        body = build_body(name)
        pieces = merge(body)
        # Aperçu côte à côte dans Blender (la position d'objet est ignorée à l'export)
        for obj in pieces.values():
            obj.location.x = i * 7
        img = body.atlas and bpy.data.images.get(f"Body{name}_Atlas")
        png = os.path.join(OUT, f"Body_{name}.png")
        img.filepath_raw = png
        img.file_format = "PNG"
        img.save()
        tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in pieces.values())
        print(f"{name}: {len(pieces)} pièces, {tris} triangles")
    col = bpy.data.collections.get("Body_" + name)
    manifest[name] = offsets(name, {o.name.split("_", 1)[1]: o for o in col.objects if o.type == "MESH"})

# Export : toutes les pièces de tous les stades, positions remises à zéro
objs = [o for name in ORDER for o in bpy.data.collections["Body_" + name].objects if o.type == "MESH"]
saved = {o: o.location.copy() for o in objs}
for o in bpy.context.view_layer.objects:
    o.select_set(False)
for o in objs:
    o.location = (0, 0, 0)
    o.select_set(True)
bpy.context.view_layer.objects.active = objs[0]
fbx = os.path.join(OUT, "MogLife_Bodies.fbx")
bpy.ops.export_scene.fbx(
    filepath=fbx, use_selection=True, object_types={"MESH"},
    axis_forward="-Z", axis_up="Y", apply_unit_scale=True, apply_scale_options="FBX_SCALE_ALL",
    mesh_smooth_type="FACE", path_mode="RELATIVE", embed_textures=False,
)
for o, loc in saved.items():
    o.location = loc
print(f"{len(objs)} pièces exportées dans {fbx}")

# Décalages pour BodyService
lines = [
    "-- Fichier généré par tools/blender/build_bodies.py : ne pas modifier à la main.",
    "-- Décalage (studs) du centre de chaque pièce de corps par rapport au centre de sa partie R15, au repos.",
    "",
    "return {",
]
for name in ORDER:
    lines.append(f"\t{name} = {{")
    for part in sorted(manifest[name]):
        x, y, z = manifest[name][part]
        lines.append(f"\t\t{part} = Vector3.new({x:g}, {y:g}, {z:g}),")
    lines.append("\t},")
lines.append("}")
with open(os.path.join(ROOT, "src", "shared", "Config", "BodyPieces.luau"), "w", encoding="utf-8", newline="\n") as f:
    f.write("\n".join(lines) + "\n")
print("BodyPieces.luau écrit")

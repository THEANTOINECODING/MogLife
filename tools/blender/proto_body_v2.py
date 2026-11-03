"""
Prototype « Bro v2 » (proposition, 2026-11-03) : un nouveau personnage du joueur, du spaghetti au GOD MOGGER absurde.
N'exporte rien vers le jeu : ce script ne sert qu'à juger le style sur des images (design/PROPOSITION_CORPS_V2.md).

Principes :
- un seul personnage paramétré par muscle m (0 = spaghetti, 1 = GOD MOGGER) : chaque trait a sa courbe, certains
  n'apparaissent qu'à partir d'un stade (trapèzes, dorsaux en ailes, veines, muscles sur les muscles) ;
- sculpté en metaballs (formes rondes qui se fondent, comme les colosses du mur) puis lissé : fini les facettes ;
- la tête garde la même taille : sur un corps qui gonfle, elle paraît de plus en plus petite (le gag gym bro) ;
- couleurs unies par matière (peau, short, baskets, cheveux, yeux) : le jeu les teinte comme aujourd'hui.

Hors de Blender : blender -b --factory-startup --python tools/blender/proto_body_v2.py
  MOG_OUT=dossier (images), MOG_STAGES=Normie,Bro,GodMogger (sinon les 7), MOG_YAW=0, MOG_W / MOG_H (taille)
"""
import bpy, math, os, random
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

K = 0.575  # rayon de surface d'une metaball isolée / rayon de l'élément (seuil 0.6, raideur 2)

# Muscle de chaque stade (0 -> 1, au-delà : encore plus absurde)
STAGES = {"Normie": 0.0, "GymRat": 0.18, "Bro": 0.3, "Alpha": 0.46, "Chad": 0.62, "Gigachad": 0.8, "GodMogger": 1.0}

COLORS = {
    "Skin": (0.93, 0.68, 0.5),
    "Shorts": (0.16, 0.32, 0.85),
    "Band": (0.95, 0.95, 0.97),
    "Shoes": (0.97, 0.97, 0.97),
    "Sole": (0.9, 0.25, 0.2),
    "Hair": (0.32, 0.18, 0.08),
    "EyeWhite": (0.98, 0.98, 0.98),
    "Pupil": (0.07, 0.06, 0.08),
    "Brow": (0.25, 0.14, 0.06),
    "Mouth": (0.45, 0.12, 0.12),
    "Teeth": (0.98, 0.97, 0.92),
    "Vein": (0.8, 0.52, 0.45),
}


def lerp(a, b, t):
    return a + (b - a) * t


def ramp(m, start, end=1.0):
    """0 avant `start`, 1 à `end`, adouci entre les deux (un trait qui n'apparaît qu'à partir d'un stade)."""
    if m <= start:
        return 0.0
    t = min(1.0, (m - start) / (end - start))
    return t * t * (3 - 2 * t)


class Sculpt:
    def __init__(self, name, res=0.022):
        mb = bpy.data.metaballs.new(name)
        mb.resolution = res
        mb.render_resolution = res
        mb.threshold = 0.6
        self.mb = mb
        self.obj = bpy.data.objects.new(name, mb)
        bpy.context.scene.collection.objects.link(self.obj)

    def ball(self, c, radii, axis=None, stiff=2.0):
        e = self.mb.elements.new(type="ELLIPSOID")
        big = max(radii)
        e.radius = big / K
        e.size_x, e.size_y, e.size_z = radii[0] / big, radii[1] / big, radii[2] / big
        e.stiffness = stiff
        e.co = Vector(c)
        if axis is not None:
            e.rotation = Vector((0, 0, 1)).rotation_difference(Vector(axis).normalized())
        return e

    def limb(self, p0, p1, r0, r1, flat=1.0, steps=None, stiff=2.0):
        p0, p1 = Vector(p0), Vector(p1)
        d = p1 - p0
        n = max(steps or 0, int(d.length / (min(r0, r1) * 0.35)) + 2)
        for i in range(n):
            t = i / (n - 1)
            r = r0 + (r1 - r0) * t
            self.ball(p0 + d * t, (r, r * flat, r), axis=d, stiff=stiff)

    def to_mesh(self, color):
        dg = bpy.context.evaluated_depsgraph_get()
        me = bpy.data.meshes.new_from_object(self.obj.evaluated_get(dg))
        name = self.obj.name
        bpy.data.objects.remove(self.obj)
        obj = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(obj)
        # MOG_TRIS : budget du jeu (triangles de peau par personnage) pour juger le rendu allégé
        budget = int(os.environ.get("MOG_TRIS", "0"))
        now = sum(len(p.vertices) - 2 for p in me.polygons)
        if budget and now > 0:
            share = budget if color == "Skin" else max(150, budget // 12)
            if now > share:
                mod = obj.modifiers.new("dec", "DECIMATE")
                mod.ratio = share / now
                mod.use_collapse_triangulate = True
                dg2 = bpy.context.evaluated_depsgraph_get()
                me2 = bpy.data.meshes.new_from_object(obj.evaluated_get(dg2))
                obj.modifiers.clear()
                obj.data = me2
                me = me2
        for p in me.polygons:
            p.use_smooth = True
        obj.data.materials.append(material(color))
        return obj


_mats = {}


def material(key):
    if key in _mats:
        return _mats[key]
    mat = bpy.data.materials.new(key)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*COLORS[key], 1)
    bsdf.inputs["Roughness"].default_value = 0.55
    mat.diffuse_color = (*COLORS[key], 1)  # rendu Workbench (MOG_LOOK=baked)
    _mats[key] = mat
    return mat


def tri_count(objs):
    return sum(len(p.vertices) - 2 for o in objs for p in o.data.polygons)


# ------------------------------------------------------------------ le personnage
def build(name, m, x=0.0):
    """Construit le personnage au muscle m, debout, regardant vers -Y, pieds à z = 0, centré en x."""
    rnd = random.Random(7)
    big = ramp(m, 0.0)  # croissance générale
    late = ramp(m, 0.55)  # traits de fin de jeu
    god = ramp(m, 0.85)  # l'absurde final

    # --- squelette : hauteurs (studs)
    height = lerp(5.5, 7.6, big ** 1.3)
    hip_z = lerp(2.55, 2.85, big)  # les jambes grandissent moins que le haut : torse de plus en plus massif
    shoulder_z = height - lerp(1.05, 1.0, big) - lerp(0.0, 0.25, late)
    head_r = 0.56  # même tête du début à la fin
    head_z = shoulder_z + lerp(0.68, 0.62, late) + head_r * 0.85  # le cou disparaît dans les trapèzes
    slouch = lerp(0.16, -0.06, ramp(m, 0.0, 0.4))  # dos voûté du Normie (épaules en avant), poitrine bombée ensuite

    shoulder_x = lerp(0.48, 2.25, big ** 1.1)
    waist = lerp(0.3, 0.78, big)  # demi-largeur de la taille : le V se creuse
    chest_w = lerp(0.36, 1.95, big ** 1.05)
    chest_d = lerp(0.26, 0.95, big)
    arm_out = lerp(0.04, 1.6, big ** 1.2) + god * 0.6  # les dorsaux écartent les bras

    S = Sculpt(name + "_Skin")
    # --- tête : crâne rond, mâchoire qui s'élargit jusqu'à dépasser le crâne
    hc = Vector((x, slouch * 1.4 - late * 0.55 - god * 0.35, head_z))  # la tête avance devant les trapèzes
    S.ball(hc, (head_r * 0.92, head_r * 0.95, head_r))
    jaw_w = lerp(0.36, 0.66, ramp(m, 0.15))
    jaw = hc + Vector((0, -head_r * 0.18, -head_r * 0.55))
    S.ball(jaw, (jaw_w, head_r * 0.7, lerp(0.28, 0.36, big)), stiff=3.0)
    S.ball(jaw + Vector((0, -head_r * 0.5, -0.12)), (lerp(0.13, 0.3, big), 0.18, lerp(0.12, 0.2, big)))  # menton
    S.ball(hc + Vector((0, -head_r * 0.98, -0.02)), (0.09, 0.14, 0.13))  # nez
    for s in (-1, 1):
        S.ball(hc + Vector((s * head_r * 0.92, 0.02, -0.02)), (0.07, 0.11, 0.16))  # oreilles

    # --- cou
    neck_r = lerp(0.12, 0.62, big ** 1.2)
    S.limb(hc + Vector((0, 0.05, -head_r * 0.6)), (x, slouch, shoulder_z - 0.1), neck_r * 0.9, neck_r)
    if not late:
        S.ball((x, slouch - 0.12, shoulder_z + 0.05), (0.05, 0.05, 0.05))  # pomme d'Adam du spaghetti

    # --- torse : cage, pectoraux, abdos, taille fine
    top = Vector((x, slouch, shoulder_z - 0.25))
    S.ball(top + Vector((0, 0.1, -0.35)), (chest_w * 0.92, chest_d, lerp(0.6, 0.95, big)))
    # colonne du ventre : relie la cage au bassin (taille fine, le V se lit)
    S.limb((x, slouch * 0.4, hip_z + 0.3), top + Vector((0, 0.05, -0.4)), waist, lerp(chest_w * 0.75, chest_w * 0.8, big),
           flat=lerp(0.85, 0.75, big))
    belly = lerp(0.12, 0.0, ramp(m, 0.0, 0.25))  # petit ventre mou du Normie
    S.ball((x, slouch * 0.3 - belly, hip_z + 0.65), (waist * 1.05, lerp(0.26, 0.62, big) + belly, 0.55))
    S.ball((x, 0, hip_z + 0.1), (waist * 1.1, lerp(0.25, 0.55, big), 0.32))  # bassin
    pec = ramp(m, 0.1)
    for s in (-1, 1):
        if pec:
            S.ball(top + Vector((s * chest_w * 0.44, -chest_d * 0.8, -0.32)),
                   (chest_w * 0.5, lerp(0.1, 0.55, pec), lerp(0.2, 0.62, pec)), axis=(s * 0.25, 0, 1), stiff=5.0)
        # dorsaux en ailes
        lat = ramp(m, 0.3)
        if lat:
            S.ball(top + Vector((s * (chest_w * 0.8 + lat * 0.25), 0.15, -0.6)),
                   (lerp(0.2, 0.75, lat), lerp(0.25, 0.55, lat), lerp(0.4, 1.0, lat)), axis=(s * 0.4, 0, 1))
    abs_ = ramp(m, 0.12, 0.5)
    if abs_:
        for row in range(3):
            for s in (-1, 1):
                zrow = hip_z + 0.55 + row * (shoulder_z - hip_z - 1.6) / 3.2
                S.ball((x + s * waist * 0.34, slouch * 0.35 - waist * 0.78, zrow),
                       (waist * 0.3, 0.22 * abs_, lerp(0.13, 0.24, big)), stiff=5.0)
    # trapèzes : montent jusqu'aux oreilles, puis les avalent
    trap = ramp(m, 0.35)
    if trap:
        for s in (-1, 1):
            S.ball((x + s * lerp(0.38, 1.0, trap), slouch + 0.2, shoulder_z + lerp(0.0, 0.3, trap) + god * 0.12),
                   (lerp(0.25, 0.75, trap), lerp(0.25, 0.55, trap), lerp(0.18, 0.55, trap)), axis=(s * 0.8, 0, 1))

    # --- bras
    hands = []
    for s in (-1, 1):
        sh = Vector((x + s * shoulder_x, slouch * 0.8, shoulder_z - 0.2))
        el = sh + Vector((s * arm_out * 0.55, lerp(0.05, 0.1, big), -lerp(1.1, 1.35, big)))
        wr = el + Vector((s * arm_out * 0.25, lerp(-0.12, -0.3, big), -lerp(1.0, 1.05, big)))
        delt = lerp(0.12, 0.95, big ** 1.1) + god * 0.2
        S.ball(sh, (delt, delt * 0.95, delt * 0.9), stiff=lerp(2.0, 4.0, big))
        bi = lerp(0.075, 0.82, big ** 1.15) + god * 0.25
        fo = lerp(0.07, 0.58, big ** 1.1)
        S.limb(sh, el, bi * 0.8, fo * 0.85, steps=4)
        mid = sh.lerp(el, 0.5)
        S.ball(mid + Vector((0, -bi * 0.45, 0.05)), (bi * 0.85, bi, bi * 1.2), axis=el - sh, stiff=lerp(3.0, 5.0, big))  # biceps
        S.ball(mid + Vector((0, bi * 0.4, 0)), (bi * 0.8, bi * 0.75, bi * 1.2), axis=el - sh)  # triceps
        if god:  # le biceps a son propre biceps
            S.ball(mid + Vector((s * bi * 0.3, -bi * 1.05, bi * 0.25)), (bi * 0.5, bi * 0.5, bi * 0.55), stiff=3.0)
        if not late:
            S.ball(el, (fo * 1.15, fo * 1.15, fo * 1.15))  # coude noueux
        S.limb(el, wr, fo, fo * 0.62, steps=4)
        S.ball(el.lerp(wr, 0.3) + Vector((0, -fo * 0.2, 0)), (fo * 1.05, fo, fo * 1.3), axis=wr - el)
        hand = lerp(0.17, 0.62, big)
        hp = wr + Vector((s * hand * 0.1, -hand * 0.1, -hand * 0.75))
        S.ball(hp, (hand * 0.85, hand * 0.95, hand))  # poing
        S.ball(hp + Vector((-s * hand * 0.35, -hand * 0.55, hand * 0.25)), (hand * 0.3, hand * 0.3, hand * 0.35))
        hands.append((s, sh, el, wr, bi, fo))

    # --- jambes : grandissent moins (les « jambes de poulet » du gym bro restent un gag de fin)
    legs = []
    for s in (-1, 1):
        hip = Vector((x + s * lerp(0.2, 0.55, big), 0, hip_z))
        kn = Vector((x + s * lerp(0.22, 0.62, big), -0.05, hip_z * 0.5))
        an = Vector((x + s * lerp(0.22, 0.6, big), 0.05, 0.32))
        th = lerp(0.12, 0.62, big ** 1.2)
        ca = lerp(0.085, 0.42, big ** 1.2)
        S.limb(hip, kn, th, th * 0.65, steps=5)
        S.ball(hip.lerp(kn, 0.45) + Vector((0, -th * 0.25, 0)), (th * 0.95, th, th * 1.6), axis=kn - hip,
               stiff=lerp(2.0, 4.0, big))  # quadriceps
        if not late:
            S.ball(kn, (0.13, 0.13, 0.13) if m < 0.2 else (th * 0.7,) * 3)  # genou noueux
        S.limb(kn, an, ca * 0.8, ca * 0.5, steps=4)
        S.ball(kn.lerp(an, 0.3) + Vector((0, ca * 0.3, 0)), (ca, ca, ca * 1.5), axis=an - kn)  # mollet
        legs.append((s, hip, kn, an, th))
    skin = S.to_mesh("Skin")
    out = [skin]

    # --- short : trop large au début, tendu à la fin
    Sh = Sculpt(name + "_Shorts", res=0.04)
    baggy = lerp(1.7, 1.04, big)
    Sh.limb((x - waist * 0.55, 0, hip_z + 0.12), (x + waist * 0.55, 0, hip_z + 0.12), lerp(0.26, 0.5, big) + 0.04,
            lerp(0.26, 0.5, big) + 0.04, flat=lerp(1.1, 1.05, big), stiff=4.0)
    for s, hip, kn, an, th in legs:
        Sh.limb(hip, hip.lerp(kn, 0.4), th * baggy + 0.03, th * baggy + 0.04, steps=4, stiff=5.0)
    out.append(Sh.to_mesh("Shorts"))

    # --- baskets : énormes au début (pieds de clown du spaghetti)
    Fo = Sculpt(name + "_Shoes", res=0.03)
    shoe = lerp(0.36, 0.62, big)
    for s, hip, kn, an, th in legs:
        Fo.ball(an + Vector((0, -shoe * 0.55, -0.12)), (shoe * 0.75, shoe * 1.45, shoe * 0.55))
    out.append(Fo.to_mesh("Shoes"))

    # --- visage : grands yeux expressifs, sourcils, bouche
    # Visage posé sur la surface réelle de la peau (rayon tiré de face) : rien ne s'enfonce dans la mâchoire
    dg = bpy.context.evaluated_depsgraph_get()
    bvh = BVHTree.FromObject(skin, dg)

    def surf(dx, dz):
        hit = bvh.ray_cast(Vector((hc.x + dx, hc.y - 20, hc.z + dz)), Vector((0, 1, 0)))[0]
        return hit if hit is not None else hc + Vector((dx, -head_r, dz))

    ex = head_r * 0.36
    eye_r = 0.17
    Ey = Sculpt(name + "_Eyes", res=0.012)
    Pu = Sculpt(name + "_Pupils", res=0.008)
    Br = Sculpt(name + "_Brows", res=0.015)
    # sourcils : inquiets (relevés au centre) au début, froncés et sûrs d'eux à la fin
    tilt = lerp(-0.35, 0.45, big)
    for s in (-1, 1):
        ec = surf(s * ex, head_r * 0.14) + Vector((0, eye_r * 0.15, 0))
        Ey.ball(ec, (eye_r, eye_r * 0.6, eye_r * 1.15))
        Pu.ball(ec + Vector((-s * 0.02, -eye_r * 0.52, -0.01)), (eye_r * 0.52, eye_r * 0.2, eye_r * 0.6))
        for k in range(4):
            u = (k - 1.5) * 0.065
            bz = head_r * 0.14 + eye_r * 1.08 + (u * s) * -tilt * 0.6
            Br.ball(surf(s * ex + s * u, bz) + Vector((0, -0.01, 0)), (0.055, 0.04, lerp(0.032, 0.05, big)))
    out += [Ey.to_mesh("EyeWhite"), Pu.to_mesh("Pupil"), Br.to_mesh("Brow")]

    Mo = Sculpt(name + "_Mouth", res=0.012)
    mz = -head_r * 0.5
    if m < 0.25:  # sourire nerveux en vague
        for k in range(9):
            u = (k - 4) * 0.035
            Mo.ball(surf(u, mz + 0.02 * math.sin(k * 1.6)), (0.032, 0.03, 0.028), stiff=3.0)
    else:  # grand sourire en coin, sûr de lui
        wide = lerp(1.0, 1.4, big)
        for k in range(11):
            u = (k - 5) * 0.034 * wide
            Mo.ball(surf(u, mz + u * u * 2.0 + u * 0.3), (0.034, 0.03, 0.03), stiff=3.0)
    out.append(Mo.to_mesh("Mouth"))
    if m < 0.25:  # dents du lapin
        Te = Sculpt(name + "_Teeth", res=0.01)
        for s in (-1, 1):
            Te.ball(surf(s * 0.035, mz - 0.055), (0.03, 0.02, 0.045))
        out.append(Te.to_mesh("Teeth"))

    # --- cheveux : calotte + mèche avant qui balaie sur le côté (coupe de base, teintée par le jeu)
    Ha = Sculpt(name + "_Hair", res=0.02)
    Ha.ball(hc + Vector((0, 0.08, head_r * 0.42)), (head_r * 0.97, head_r * 0.96, head_r * 0.62))
    Ha.ball(hc + Vector((0, 0.2, head_r * 0.1)), (head_r * 0.93, head_r * 0.8, head_r * 0.6))  # arrière du crâne
    for k in range(5):
        u = k / 4
        Ha.ball(hc + Vector((lerp(0.28, -0.3, u), -head_r * lerp(0.62, 0.72, u), head_r * lerp(0.78, 0.6, u))),
                (0.17, 0.14, 0.12 - u * 0.03))
    out.append(Ha.to_mesh("Hair"))

    # --- veines (fin de jeu) : petits tubes sur les bras
    if late:
        Ve = Sculpt(name + "_Veins", res=0.02)
        for s, sh, el, wr, bi, fo in hands:
            for v in range(2):
                p = el.lerp(sh, 0.15 + v * 0.3)
                for k in range(7):
                    t = k / 6
                    q = p.lerp(el.lerp(wr, 0.7), t)
                    off = Vector((s * 0.0, -(fo + (bi - fo) * (1 - t)) * 0.92, (rnd.random() - 0.5) * 0.08 + v * 0.1))
                    Ve.ball(q + off, (0.035 * late, 0.035 * late, 0.09))
        out.append(Ve.to_mesh("Vein"))
    return out, height


def render(path, names, yaw=0.0, w=2200, h=900):
    scene = bpy.context.scene
    objs, x, top = [], 0.0, 0.0
    widths = {n: lerp(2.0, 7.4, ramp(STAGES[n], 0.0) ** 1.1) for n in names}
    for n in names:
        x += widths[n] / 2
        o, height = build(n, STAGES[n], x)
        objs += o
        top = max(top, height)
        x += widths[n] / 2 + 0.6
    for o in objs:
        o.location.x -= x / 2
    print("triangles:", {n: tri_count([o for o in objs if o.name.startswith(n + "_")]) for n in names})
    # MOG_LOOK=baked : ombrage « cuit » (creux assombris), ce que donnerait une texture d'ombres dans Roblox
    engines = ("BLENDER_WORKBENCH",) if os.environ.get("MOG_LOOK") == "baked" else ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE")
    for eng in engines:
        try:
            scene.render.engine = eng
            break
        except TypeError:
            pass
    sh = scene.display.shading
    sh.light = "STUDIO"
    sh.color_type = "MATERIAL"
    sh.show_cavity = True
    sh.cavity_type = "BOTH"
    sh.cavity_ridge_factor = 0.6
    sh.cavity_valley_factor = 2.2
    sh.curvature_valley_factor = 2.0
    sh.show_shadows = True
    sh.shadow_intensity = 0.35
    sh.background_type = "VIEWPORT"
    sh.background_color = (0.62, 0.7, 0.8)
    world = bpy.data.worlds.new("W")
    scene.world = world
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs[0].default_value = (0.62, 0.7, 0.8, 1)
    bg.inputs[1].default_value = 0.9
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.2
    sun.rotation_euler = (math.radians(55), 0, math.radians(-35))
    scene.collection.objects.link(sun)
    ground = bpy.data.meshes.new("Ground")
    ground.from_pydata([(-200, -200, 0), (200, -200, 0), (200, 200, 0), (-200, 200, 0)], [], [(0, 1, 2, 3)])
    g = bpy.data.objects.new("Ground", ground)
    COLORS["Ground"] = (0.55, 0.6, 0.55)
    g.data.materials.append(material("Ground"))
    scene.collection.objects.link(g)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scene.collection.objects.link(cam)
    aim = Vector((0, 0, top * float(os.environ.get("MOG_AIM", "0.5"))))
    a = math.radians(yaw)
    dist = max(x * float(os.environ.get("MOG_DIST", "1.55")), top * 2.6)
    cam.location = aim + Vector((math.sin(a) * dist, -math.cos(a) * dist, top * 0.15))
    cam.rotation_euler = (aim - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = 50
    scene.camera = cam
    scene.view_settings.view_transform = "Standard"
    scene.render.resolution_x = w
    scene.render.resolution_y = h
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("image :", path)


if __name__ == "__main__":
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o)
    out = os.environ.get("MOG_OUT", r"C:\Users\antoi\Documents\MogLife\assets\concepts")
    names = [n for n in os.environ.get("MOG_STAGES", ",".join(STAGES)).split(",") if n]
    render(os.path.join(out, os.environ.get("MOG_FILE", "body_v2_lineup.png")), names,
           float(os.environ.get("MOG_YAW", "0")), int(os.environ.get("MOG_W", "2200")), int(os.environ.get("MOG_H", "900")))

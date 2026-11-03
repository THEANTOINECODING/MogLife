"""
Mur des Colosses (D107) : le monde est fermé par un mur continu de statues géantes de dieux « gym bro » en marbre,
qui portent une corniche sur leurs mains (atlantes). Choix d'Antoine (QCM) : colosses porteurs, dieux gym bro,
effets : yeux lumineux, flammes des torches, sceptres lumineux, veines d'or. Toutes les statues portent un drapé.

Les corps sont sculptés en metaballs (les muscles se fondent comme dans la pierre), convertis en maillage, allégés
(Decimate) puis lissés. Pièces exportées (une pièce = un MeshPart, sans texture : le jeu applique couleur et matériau
Roblox selon le suffixe du nom, voir tools/install_props.luau) :
  StatueWall_Module   : socle, mur de fond à bossages, pilastres, entablement (le tout fait MODULE["width"] de large)
  StatueWall_Pier     : pilier de jonction (cache les raccords entre modules, porte un brasero)
  Colossus_<Pose>     : la statue (corps + drapé), marbre
  Colossus_<Pose>_Gold: couronne, bracelets, ceinture, torche, sceptre-haltère (or)
  Colossus_<Pose>_Glow: yeux, veines d'or, tête du sceptre (néon ; posée seulement sur certaines statues)
Repère : Z vers le haut, 1 unité = 1 stud, la statue regarde vers -Y. Le bas du socle est à z = 0, le centre du
module à x = y = 0. Les points d'effet (yeux, flamme, sceptre, brasero) vont dans statue_wall_manifest.json.
"""
import bpy, bmesh, math, random
from mathutils import Vector, Quaternion, Matrix
from mathutils.bvhtree import BVHTree

K = 0.575  # rayon de surface d'une metaball isolée / rayon de l'élément (seuil 0.6, raideur 2 : mesuré)

MODULE = {
    "width": 32.0,  # largeur d'un module (un colosse)
    "depth": 22.0,
    "plinth": 2.0,  # marche au sol
    "pedestal": 9.0,  # dessus du piédestal de la statue
    "wall_back": 11.0,  # face arrière du mur (y)
    "wall_front": 4.0,  # face avant du mur de fond (y)
    "beam": 63.5,  # dessous de l'entablement (les mains des colosses le touchent)
    "top": 74.0,  # haut de la corniche
}
STATUE_SCALE = 26.0  # une statue fait 2 unités « corps » de haut -> 52 studs
PIER = {"size": 7.5, "height": 80.0}
STATUE_TRIS = 4000  # D108 : allégé pour les iPhone (91 statues visibles en même temps)
GOLD_TRIS = 1800


# ------------------------------------------------------------------ sculpture en metaballs
class Sculpt:
    """Accumule des metaballs dans un repère courant (pile de matrices) ; unités « corps » (statue = 2 de haut)."""

    def __init__(self, name, res=0.0095):
        mb = bpy.data.metaballs.new(name)
        mb.resolution = res
        mb.render_resolution = res
        mb.threshold = 0.6
        self.mb = mb
        self.obj = bpy.data.objects.new(name, mb)
        bpy.context.scene.collection.objects.link(self.obj)
        self.stack = [Matrix.Identity(4)]

    @property
    def m(self):
        return self.stack[-1]

    def push(self, matrix):
        self.stack.append(self.m @ matrix)

    def pop(self):
        self.stack.pop()

    def ball(self, c, radii, axis=None, neg=False, stiff=2.0):
        """Ellipsoïde de demi-axes `radii` (surface d'un élément isolé). axis : direction de l'axe Z local."""
        e = self.mb.elements.new(type="ELLIPSOID")
        big = max(radii)
        e.radius = big / K
        e.size_x, e.size_y, e.size_z = radii[0] / big, radii[1] / big, radii[2] / big
        e.stiffness = stiff
        e.use_negative = neg
        loc, rot, _ = self.m.decompose()
        q = rot
        if axis is not None:
            q = rot @ Vector((0, 0, 1)).rotation_difference(Vector(axis).normalized())
        e.co = self.m @ Vector(c)
        e.rotation = q
        return e

    def limb(self, p0, p1, r0, r1, flat=1.0, steps=None, front=None):
        """Membre effilé de p0 à p1 (chapelet d'ellipsoïdes allongés). flat : aplatissement avant/arrière."""
        p0, p1 = Vector(p0), Vector(p1)
        d = p1 - p0
        n = steps or max(2, int(d.length / (min(r0, r1) * 0.9)) + 1)
        for i in range(n):
            t = i / (n - 1)
            r = r0 + (r1 - r0) * t
            self.ball(p0 + d * t, (r, r * flat, max(r, d.length / n * 0.9)), axis=d)

    def to_object(self, name, tris):
        dg = bpy.context.evaluated_depsgraph_get()
        me = bpy.data.meshes.new_from_object(self.obj.evaluated_get(dg))
        bpy.data.objects.remove(self.obj)
        obj = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(obj)
        decimate(obj, tris)
        return obj


def decimate(obj, tris):
    me = obj.data
    now = sum(len(p.vertices) - 2 for p in me.polygons)
    if now > tris:
        mod = obj.modifiers.new("dec", "DECIMATE")
        mod.ratio = tris / now
        mod.use_collapse_triangulate = True
        apply_modifiers(obj)
    for p in obj.data.polygons:
        p.use_smooth = True


def apply_modifiers(obj):
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(obj.evaluated_get(dg))
    old = obj.data
    obj.modifiers.clear()
    obj.data = me
    bpy.data.meshes.remove(old)


def tri_count(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


# ------------------------------------------------------------------ maillages simples (bmesh)
def bm_box(bm, center, size, bevel=0.0):
    geom = bmesh.ops.create_cube(bm, size=1.0)
    verts = geom["verts"]
    for v in verts:
        v.co = Vector((center[0] + v.co.x * size[0], center[1] + v.co.y * size[1], center[2] + v.co.z * size[2]))
    if bevel > 0:
        edges = list({e for v in verts for e in v.link_edges})
        bmesh.ops.bevel(bm, geom=edges, offset=bevel, segments=1, affect="EDGES", profile=0.5)
    return verts


def bm_cyl(bm, p0, p1, r0, r1=None, sides=10, cap=True):
    p0, p1 = Vector(p0), Vector(p1)
    r1 = r0 if r1 is None else r1
    d = p1 - p0
    q = Vector((0, 0, 1)).rotation_difference(d.normalized())
    rings = []
    for z, r in ((0, r0), (1, r1)):
        ring = []
        for i in range(sides):
            a = 2 * math.pi * i / sides
            ring.append(bm.verts.new(p0 + d * z + q @ Vector((math.cos(a) * r, math.sin(a) * r, 0))))
        rings.append(ring)
    for i in range(sides):
        j = (i + 1) % sides
        bm.faces.new((rings[0][i], rings[0][j], rings[1][j], rings[1][i]))
    if cap:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[1])


def bm_sphere(bm, center, radii, u=8, v=6):
    geom = bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=1.0)
    for vert in geom["verts"]:
        vert.co = Vector((center[0] + vert.co.x * radii[0], center[1] + vert.co.y * radii[1],
                          center[2] + vert.co.z * radii[2]))
    return geom["verts"]


def bm_object(name, bm, smooth=False):
    me = bpy.data.meshes.new(name)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    for p in me.polygons:
        p.use_smooth = smooth
    return obj


# ------------------------------------------------------------------ anatomie
SIDES = (-1, 1)  # -1 : côté droit du colosse (il regarde vers -Y), 1 : côté gauche


def head(S, look, hair, mood):
    """Tête dans le repère du cou (origine en haut du cou, z vers le haut). look : (lacet, tangage) en degrés."""
    yaw, pitch = look
    S.push(Matrix.Translation((0, -0.005, 1.74)) @ Matrix.Rotation(math.radians(yaw), 4, "Z")
           @ Matrix.Rotation(math.radians(-pitch), 4, "X"))
    S.ball((0, 0.012, 0.155), (0.088, 0.104, 0.104))  # crâne
    S.ball((0, -0.035, 0.085), (0.074, 0.08, 0.07))  # visage
    S.ball((0, -0.03, 0.04), (0.068, 0.075, 0.045))  # mâchoire carrée
    for s in SIDES:
        S.ball((s * 0.058, -0.02, 0.045), (0.022, 0.04, 0.03))  # angle de la mâchoire
        S.ball((s * 0.05, -0.085, 0.11), (0.024, 0.018, 0.016))  # pommette
        S.ball((s * 0.088, 0.005, 0.11), (0.011, 0.022, 0.032))  # oreille
        S.ball((s * 0.034, -0.086, 0.121), (0.016, 0.012, 0.011))  # œil (globe, enfoncé sous l'arcade)
        S.ball((s * 0.03, -0.1, 0.098), (0.02, 0.01, 0.008))  # paupière inférieure / joue
    S.ball((0, -0.098, 0.146), (0.07, 0.022, 0.016))  # arcade sourcilière
    S.ball((0, -0.104, 0.1), (0.014, 0.02, 0.034), axis=(0, -0.3, 1))  # nez
    S.ball((0, -0.109, 0.073), (0.018, 0.011, 0.012))  # bout du nez
    S.ball((0, -0.104, 0.052), (0.026, 0.012, 0.008))  # lèvre du haut
    S.ball((0, -0.102, 0.036), (0.022, 0.012, 0.008))  # lèvre du bas
    S.ball((0, -0.096, 0.012), (0.03, 0.022, 0.02))  # menton
    if mood == "smirk":
        S.ball((0.018, -0.104, 0.05), (0.01, 0.008, 0.006))
    rng = random.Random(len(hair) * 7 + 3)
    if hair == "curls":  # boucles antiques
        for i in range(70):
            a = rng.uniform(0, 2 * math.pi)
            b = rng.uniform(-0.15, 1.0) * math.pi / 2
            x, y, z = math.cos(a) * math.cos(b), math.sin(a) * math.cos(b), math.sin(b)
            if y < -0.55 and z < 0.55:
                continue  # pas sur le front ni le visage
            S.ball((x * 0.092, 0.012 + y * 0.106, 0.165 + z * 0.1), (0.024, 0.024, 0.02))
    elif hair == "braid":  # tresse sur le dessus (image 1 d'Antoine), côtés rasés
        for i in range(9):
            t = i / 8
            a = math.radians(-60 + 200 * t)
            y, z = -math.cos(a) * 0.105, 0.165 + math.sin(a) * 0.105
            S.ball((0, 0.012 + y, z), (0.03, 0.026, 0.026))
            S.ball((0, 0.012 + y * 1.06, z + 0.012), (0.018, 0.022, 0.02))
    elif hair == "short":
        S.ball((0, 0.02, 0.178), (0.094, 0.104, 0.09))
    S.pop()
    return S


def eye_points(look):
    """Centres des yeux (unités corps), pour la lueur et les rayons."""
    yaw, pitch = look
    m = (Matrix.Translation((0, -0.005, 1.74)) @ Matrix.Rotation(math.radians(yaw), 4, "Z")
         @ Matrix.Rotation(math.radians(-pitch), 4, "X"))
    forward = (m.to_3x3() @ Vector((0, -1, 0))).normalized()
    return [m @ Vector((s * 0.034, -0.1, 0.121)) for s in SIDES], forward, m


def torso(S, P):
    lean = P.get("lean", 0)
    S.push(Matrix.Translation((0, 0, 1.0)) @ Matrix.Rotation(math.radians(lean), 4, "Y") @ Matrix.Translation((0, 0, -1.0)))
    S.ball((0, 0.01, 1.0), (0.165, 0.115, 0.115))  # bassin
    S.ball((0, -0.005, 1.15), (0.145, 0.105, 0.12))  # taille
    S.ball((0, 0.005, 1.38), (0.19, 0.125, 0.16))  # cage thoracique
    S.ball((0, 0.03, 1.52), (0.215, 0.11, 0.1))  # haut du dos
    for s in SIDES:
        S.ball((s * 0.088, -0.07, 1.47), (0.1, 0.06, 0.075), axis=(s * 0.5, 0, 1))  # pectoral
        S.ball((s * 0.06, -0.09, 1.43), (0.06, 0.035, 0.04))  # bas du pectoral (bord net)
        S.ball((s * 0.15, -0.05, 1.5), (0.05, 0.045, 0.06))  # attache pectoral / épaule
        S.ball((s * 0.155, 0.05, 1.36), (0.07, 0.07, 0.15), axis=(s * 0.35, 0, 1))  # grand dorsal (le V)
        S.ball((s * 0.085, 0.035, 1.64), (0.095, 0.06, 0.055), axis=(s, 0, 0.5))  # trapèze
        S.ball((s * 0.13, -0.035, 1.12), (0.045, 0.065, 0.085))  # oblique
        S.ball((s * 0.08, 0.09, 0.985), (0.085, 0.065, 0.085))  # fessier
        for k, z in enumerate((1.33, 1.255, 1.18)):
            S.ball((s * 0.043, -0.083, z), (0.036, 0.03, 0.03))  # abdos
        S.ball((s * 0.038, -0.08, 1.1), (0.034, 0.026, 0.038))  # bas des abdos
        for k in range(3):
            S.ball((s * 0.15, -0.045 + k * 0.015, 1.37 - k * 0.045), (0.016, 0.02, 0.014))  # dentelé
        S.ball((s * 0.12, -0.09, 1.0), (0.025, 0.02, 0.09), axis=(s * 0.6, 0, 1))  # pli de l'aine (Apollon)
    S.limb((0, 0.0, 1.58), (0, -0.01, 1.75), 0.074, 0.066)  # cou (épais)
    for s in SIDES:
        S.ball((s * 0.035, -0.035, 1.68), (0.018, 0.016, 0.075), axis=(s * -0.5, -0.4, 1))  # sterno-cléido
    S.pop()


def arm(S, s, sh, el, wr, hand):
    sh, el, wr = Vector(sh), Vector(el), Vector(wr)
    up = el - sh
    fore = wr - el
    S.ball(sh + Vector((s * 0.03, 0, 0.0)), (0.1, 0.1, 0.095), axis=up)  # deltoïde
    S.ball(sh + up * 0.18 + Vector((s * 0.02, 0, 0)), (0.075, 0.08, 0.07), axis=up)  # bas du deltoïde
    S.limb(sh, el, 0.07, 0.052)
    side = Vector((0, -1, 0)).cross(up).normalized() * s
    front = up.cross(side).normalized() * -1
    if front.y > 0:
        front = -front
    bend = (-up.normalized()).dot(fore.normalized())  # 1 : bras plié serré
    S.ball(sh + up * 0.56 + front * 0.035, (0.06 + 0.016 * max(bend, 0), 0.056 + 0.02 * max(bend, 0), up.length * 0.3),
           axis=up)  # biceps (gonfle quand on plie)
    S.ball(sh + up * 0.45 - front * 0.04, (0.058, 0.052, up.length * 0.34), axis=up)  # triceps
    S.ball(el, (0.045, 0.045, 0.045))  # coude
    S.limb(el, wr, 0.056, 0.034, flat=0.8)
    S.ball(el + fore * 0.25 + front * 0.015, (0.056, 0.048, fore.length * 0.28), axis=fore)  # avant-bras
    d = fore.normalized()
    if hand == "fist":
        S.ball(wr + d * 0.055, (0.043, 0.038, 0.05), axis=fore)
        S.ball(wr + d * 0.07 + front * 0.03, (0.04, 0.02, 0.025), axis=fore)  # doigts repliés
    elif hand == "palm":  # paume ouverte vers le haut (porte la corniche)
        S.ball(wr + d * 0.06, (0.05, 0.022, 0.06), axis=fore)
        for k in range(4):
            off = (k - 1.5) * 0.02
            S.ball(wr + d * 0.115 + side * off, (0.01, 0.01, 0.03), axis=d)
    elif hand == "grip":  # tient un manche (le manche passe dans le poing)
        S.ball(wr + d * 0.05, (0.045, 0.04, 0.045), axis=fore)
    elif hand == "hip":  # main posée sur la hanche
        S.ball(wr + d * 0.04, (0.04, 0.05, 0.03), axis=fore)
    return wr + d * 0.06


def leg(S, s, hip, knee, ankle, toe_dir=(0, -1, 0)):
    hip, knee, ankle = Vector(hip), Vector(knee), Vector(ankle)
    thigh = knee - hip
    S.limb(hip, knee, 0.112, 0.064)
    S.ball(hip + thigh * 0.42 + Vector((0, -0.04, 0)), (0.08, 0.068, thigh.length * 0.36), axis=thigh)  # quadriceps
    S.ball(hip + thigh * 0.78 + Vector((-s * 0.04, -0.035, 0)), (0.058, 0.05, 0.075), axis=thigh)  # vaste interne
    S.ball(hip + thigh * 0.52 + Vector((s * 0.055, 0, 0)), (0.055, 0.066, thigh.length * 0.32), axis=thigh)  # vaste ext.
    S.ball(hip + thigh * 0.48 + Vector((0, 0.045, 0)), (0.07, 0.058, thigh.length * 0.34), axis=thigh)  # ischios
    S.ball(knee + Vector((0, -0.05, 0)), (0.034, 0.024, 0.032))  # rotule
    shin = ankle - knee
    S.limb(knee, ankle, 0.06, 0.036)
    S.ball(knee + shin * 0.3 + Vector((0, 0.045, 0)), (0.06, 0.058, shin.length * 0.25), axis=shin)  # mollet
    S.ball(knee + shin * 0.32 + Vector((-s * 0.03, 0.04, 0)), (0.042, 0.046, shin.length * 0.2), axis=shin)
    S.ball(knee + shin * 0.35 + Vector((0, -0.03, 0)), (0.03, 0.025, shin.length * 0.3), axis=shin)  # tibia
    t = Vector(toe_dir).normalized()
    S.ball(ankle + Vector((0, 0.035, -0.05)), (0.042, 0.045, 0.04))  # talon
    S.ball(ankle + t * 0.08 + Vector((0, 0, -0.055)), (0.055, 0.12, 0.035), axis=t.cross(Vector((0, 0, 1))))  # pied
    S.ball(ankle + t * 0.19 + Vector((0, 0, -0.07)), (0.058, 0.03, 0.022))  # orteils


# ------------------------------------------------------------------ poses (unités corps, statue de 2 de haut)
POSES = {
    # Développé militaire : il soulève la corniche, tête un peu baissée sous l'effort
    "Atlas": {
        "legs": {-1: ((-0.1, 0, 0.97), (-0.19, -0.06, 0.53), (-0.24, 0, 0.1)),
                 1: ((0.1, 0, 0.97), (0.19, -0.06, 0.53), (0.24, 0, 0.1))},
        "arms": {-1: ((-0.21, 0, 1.6), (-0.42, 0.02, 1.8), (-0.37, 0.0, 2.03), "palm"),
                 1: ((0.21, 0, 1.6), (0.42, 0.02, 1.8), (0.37, 0.0, 2.03), "palm")},
        "look": (0, 14), "hair": "curls", "crown": True, "mood": "calm",
    },
    # Porte-flambeau : torche levée devant lui, l'autre main sur la hanche, déhanché
    "Torch": {
        "legs": {-1: ((-0.1, 0, 0.96), (-0.15, -0.1, 0.52), (-0.2, 0.06, 0.1)),
                 1: ((0.1, 0, 0.98), (0.12, -0.02, 0.54), (0.11, 0, 0.1))},
        "arms": {-1: ((-0.21, 0, 1.6), (-0.4, -0.08, 1.48), (-0.4, -0.25, 1.64), "grip"),
                 1: ((0.21, 0, 1.6), (0.35, 0.07, 1.3), (0.19, -0.02, 1.1), "hip")},
        "look": (-18, 4), "hair": "curls", "mood": "smirk", "lean": 4, "torch": True,
    },
    # Roi de l'haltère : sceptre-haltère planté au sol, l'autre bras en flexion du biceps
    "Scepter": {
        "legs": {-1: ((-0.1, 0, 0.97), (-0.17, -0.05, 0.53), (-0.2, 0, 0.1)),
                 1: ((0.1, 0, 0.97), (0.16, -0.08, 0.53), (0.2, -0.03, 0.1))},
        "arms": {-1: ((-0.21, 0, 1.6), (-0.38, 0.0, 1.36), (-0.38, -0.13, 1.5), "grip"),
                 1: ((0.21, 0, 1.6), (0.43, 0.02, 1.62), (0.4, -0.05, 1.87), "fist")},
        "look": (22, 0), "hair": "curls", "crown": True, "mood": "smirk", "scepter": True,
    },
    # Double biceps de face, tresse sur le crâne (yeux lumineux)
    "Flex": {
        "legs": {-1: ((-0.1, 0, 0.97), (-0.21, -0.05, 0.53), (-0.27, 0, 0.1)),
                 1: ((0.1, 0, 0.97), (0.21, -0.05, 0.53), (0.27, 0, 0.1))},
        "arms": {-1: ((-0.21, 0, 1.6), (-0.43, 0.02, 1.62), (-0.39, -0.05, 1.88), "fist"),
                 1: ((0.21, 0, 1.6), (0.43, 0.02, 1.62), (0.39, -0.05, 1.88), "fist")},
        "look": (0, -4), "hair": "braid", "mood": "calm",
    },
}


def build_body(name, P):
    S = Sculpt(name)
    torso(S, P)
    for s in SIDES:
        hip, knee, ankle = P["legs"][s]
        leg(S, s, hip, knee, ankle)
    hands = {}
    for s in SIDES:
        sh, el, wr, hand = P["arms"][s]
        hands[s] = (arm(S, s, sh, el, wr, hand), Vector(wr) - Vector(el))
    head(S, P["look"], P["hair"], P["mood"])
    return S.to_object(name, STATUE_TRIS - 1200), hands


# ------------------------------------------------------------------ drapé (pagne noué, plis), en unités corps
def drape(bm, P, seed):
    rng = random.Random(seed)
    nu, nv = 40, 9
    z_top = 1.06
    folds = [rng.uniform(0.6, 1.4) for _ in range(9)]
    rows = []
    for j in range(nv):
        v = j / (nv - 1)
        ring = []
        for i in range(nu):
            a = 2 * math.pi * i / nu
            front = max(0.0, -math.sin(a))  # 1 devant (-Y)
            side = abs(math.cos(a))
            # le pan avant descend plus bas que les côtés ; le tissu s'évase sur les cuisses
            depth = 0.13 + 0.17 * front ** 1.5 + 0.03 * (1 - side)
            z = z_top - v * depth - 0.02 * math.sin(a * 3 + seed)
            fold = sum(f * math.sin(a * (k + 4) + k) for k, f in enumerate(folds)) / len(folds)
            rx = 0.178 + v * (0.05 + 0.04 * side) + 0.026 * fold * v
            ry = 0.128 + v * (0.035 + 0.02 * front) + 0.026 * fold * v
            ring.append(bm.verts.new((math.cos(a) * rx, math.sin(a) * ry + 0.01, z)))
        rows.append(ring)
    for j in range(nv - 1):
        for i in range(nu):
            k = (i + 1) % nu
            bm.faces.new((rows[j][i], rows[j][k], rows[j + 1][k], rows[j + 1][i]))
    # nœud et pan qui retombe sur la hanche gauche


# ------------------------------------------------------------------ pièces en or et lueurs (unités corps)
def laurel(bm, look):
    _, _, m = eye_points(look)
    for i in range(22):
        a = math.radians(-160 + i * (320 / 21))
        if abs(math.degrees(a)) > 150:
            continue
        c = m @ Vector((math.sin(a) * 0.112, -math.cos(a) * 0.124 + 0.012, 0.18 + 0.012 * math.cos(a * 2)))
        tangent = (m.to_3x3() @ Vector((math.cos(a), math.sin(a), 0.35))).normalized()
        verts = bm_sphere(bm, (0, 0, 0), (0.012, 0.007, 0.03), 6, 4)
        q = Vector((0, 0, 1)).rotation_difference(tangent)
        for v in verts:
            v.co = c + q @ v.co


def cuffs(bm, P):
    for s in SIDES:
        sh, el, wr, hand = P["arms"][s]
        el, wr = Vector(el), Vector(wr)
        d = (wr - el).normalized()
        bm_cyl(bm, wr - d * 0.07, wr - d * 0.025, 0.044, 0.042, sides=12)


def belt(bm):
    rows = []
    for z in (1.035, 1.075):
        ring = []
        for i in range(36):
            a = 2 * math.pi * i / 36
            ring.append(bm.verts.new((math.cos(a) * 0.184, math.sin(a) * 0.132 + 0.01, z)))
        rows.append(ring)
    for i in range(36):
        k = (i + 1) % 36
        bm.faces.new((rows[0][i], rows[0][k], rows[1][k], rows[1][i]))
    bm_box(bm, (0, -0.14, 1.055), (0.06, 0.02, 0.055), bevel=0.006)  # boucle


def dumbbell(bm, center, axis, length, plate_r, bar_r=0.012):
    c, d = Vector(center), Vector(axis).normalized()
    bm_cyl(bm, c - d * length / 2, c + d * length / 2, bar_r, sides=10)
    for s in (-1, 1):
        for k in range(3):
            r = plate_r * (1 - 0.18 * k)
            at = c + d * s * (length / 2 - 0.02 - k * 0.028)
            bm_cyl(bm, at - d * 0.012, at + d * 0.012, r, sides=16)


def torch_parts(bm, hand):
    top = Vector((hand.x, hand.y, 1.92))
    bm_cyl(bm, (hand.x, hand.y, 1.42), top, 0.018, 0.026, sides=10)
    bm_cyl(bm, top, top + Vector((0, 0, 0.08)), 0.03, 0.07, sides=14)  # coupe
    for k in range(3):
        z = 1.48 + k * 0.14
        bm_cyl(bm, (hand.x, hand.y, z), (hand.x, hand.y, z + 0.02), 0.03, sides=10)
    return top + Vector((0, 0, 0.1))


def scepter_parts(bm, hand):
    base = Vector((hand.x, hand.y, 0.02))
    top = Vector((hand.x, hand.y, 2.0))
    bm_cyl(bm, base, top, 0.016, 0.02, sides=10)
    for z in (0.4, 1.0, 1.9):
        bm_cyl(bm, (hand.x, hand.y, z), (hand.x, hand.y, z + 0.03), 0.028, sides=10)
    head_at = top + Vector((0, 0, 0.05))
    dumbbell(bm, head_at, (1, 0, 0), 0.32, 0.075)
    return head_at


def veins(bm, body, seed, count=7):
    """Fissures dorées sur le marbre : marches au hasard le long de la surface (BVH), en tubes fins."""
    rng = random.Random(seed)
    tree = BVHTree.FromObject(body, bpy.context.evaluated_depsgraph_get())
    verts = [v.co.copy() for v in body.data.vertices]
    starts = [v for v in verts if 1.2 < v.z < 1.65 and v.y < 0.0 and abs(v.x) < 0.24]
    for n in range(count):
        p = rng.choice(starts)
        heading = Vector((rng.uniform(-1, 1), 0, rng.uniform(-1, 1))).normalized()
        branch = []
        for step in range(rng.randint(7, 12)):
            heading = (heading + Vector((rng.uniform(-0.7, 0.7), 0, rng.uniform(-0.7, 0.7)))).normalized()
            q = p + heading * 0.035
            loc, normal, _, _ = tree.find_nearest(q)
            if loc is None:
                break
            q = loc + normal * 0.003
            if q.z < 1.1:
                break
            bm_cyl(bm, p, q, 0.0055, 0.0045, sides=5, cap=False)
            branch.append(q)
            p = q
        if len(branch) > 4 and rng.random() < 0.7:  # une branche secondaire
            p = branch[len(branch) // 2]
            h2 = Vector((rng.uniform(-1, 1), 0, rng.uniform(-1, 1))).normalized()
            for step in range(4):
                q = p + h2 * 0.03
                loc, normal, _, _ = tree.find_nearest(q)
                if loc is None:
                    break
                q = loc + normal * 0.003
                bm_cyl(bm, p, q, 0.004, 0.003, sides=5, cap=False)
                p = q


# ------------------------------------------------------------------ une statue complète
def to_studs(obj, y_offset):
    """Passe des unités corps aux studs, posée sur le piédestal du module."""
    mat = Matrix.Translation((0, y_offset, MODULE["pedestal"])) @ Matrix.Scale(STATUE_SCALE, 4)
    obj.data.transform(mat)


def build_statue(pose, y_offset=-2.0):
    P = POSES[pose]
    body, hands = build_body(f"Colossus_{pose}", P)
    # drapé, joint au corps (même matière)
    bm = bmesh.new()
    drape(bm, P, seed=len(pose))
    cloth = bm_object("cloth", bm, smooth=True)
    mod = cloth.modifiers.new("solid", "SOLIDIFY")
    mod.thickness = 0.012
    apply_modifiers(cloth)
    for p in cloth.data.polygons:
        p.use_smooth = True
    join(body, [cloth])

    fx = {}
    gold = bmesh.new()
    belt(gold)
    cuffs(gold, P)
    if P.get("crown"):
        laurel(gold, P["look"])
    if P.get("torch"):
        fx["Flame"] = torch_parts(gold, hands[-1][0])
    if P.get("scepter"):
        fx["Scepter"] = scepter_parts(gold, hands[-1][0])
    gold_obj = bm_object(f"Colossus_{pose}_Gold", gold, smooth=True)

    glow = bmesh.new()
    eyes, forward, _ = eye_points(P["look"])
    for e in eyes:
        bm_sphere(glow, e + forward * 0.012, (0.0125, 0.0125, 0.0125), 8, 6)
    if P.get("scepter"):
        bm_sphere(glow, fx["Scepter"], (0.045, 0.045, 0.045), 12, 8)
    veins(glow, body, seed=len(pose) * 13)
    glow_obj = bm_object(f"Colossus_{pose}_Glow", glow, smooth=True)

    for o in (body, gold_obj, glow_obj):
        to_studs(o, y_offset)
    to_stud = lambda v: [round(v.x * STATUE_SCALE, 3), round(v.y * STATUE_SCALE + y_offset, 3),
                         round(v.z * STATUE_SCALE + MODULE["pedestal"], 3)]
    anchors = {"Eyes": [to_stud(e) for e in eyes],
               "Gaze": [round(forward.x, 3), round(forward.y, 3), round(forward.z, 3)]}
    for k, v in fx.items():
        anchors[k] = to_stud(v)
    return [body, gold_obj, glow_obj], anchors


def join(target, others):
    bm = bmesh.new()
    bm.from_mesh(target.data)
    for o in others:
        o.data.transform(o.matrix_world)
        bm.from_mesh(o.data)
        bpy.data.objects.remove(o)
    bm.to_mesh(target.data)
    bm.free()


# ------------------------------------------------------------------ architecture (studs)
def build_module():
    G = MODULE
    W, half = G["width"], G["width"] / 2
    bm = bmesh.new()
    yb, yf = G["wall_back"], G["wall_front"]
    front = -G["depth"] / 2
    # marche au sol et piédestal mouluré
    bm_box(bm, (0, (front + yb) / 2, G["plinth"] / 2), (W, yb - front, G["plinth"]), bevel=0.15)
    ped = (20.0, 15.0)
    ped_y = -2.0
    bm_box(bm, (0, ped_y, G["plinth"] + 0.6), (ped[0] + 1.6, ped[1] + 1.6, 1.2), bevel=0.2)
    bm_box(bm, (0, ped_y, (G["plinth"] + G["pedestal"]) / 2 + 0.4), (ped[0], ped[1], G["pedestal"] - G["plinth"] - 2.0))
    bm_box(bm, (0, ped_y, G["pedestal"] - 0.6), (ped[0] + 1.4, ped[1] + 1.4, 1.2), bevel=0.2)
    # relief sur la face avant du piédestal : un haltère en bas-relief dans un cadre
    fy = ped_y - ped[1] / 2
    bm_box(bm, (0, fy - 0.1, 5.4), (14.0, 0.4, 0.4))
    bm_box(bm, (0, fy - 0.1, 3.0), (14.0, 0.4, 0.4))
    for s in (-1, 1):
        bm_box(bm, (s * 7.0, fy - 0.1, 4.2), (0.4, 0.4, 2.8))
    bm_cyl(bm, (-4.2, fy - 0.15, 4.2), (4.2, fy - 0.15, 4.2), 0.25, sides=8)
    for s in (-1, 1):
        for k, r in enumerate((1.0, 0.8)):
            x = s * (3.3 - k * 0.55)
            bm_cyl(bm, (x - 0.2, fy - 0.15, 4.2), (x + 0.2, fy - 0.15, 4.2), r, sides=14)
    # mur de fond à bossages (assises décalées), de la marche au dessous de l'entablement
    course = 4.5
    z = G["plinth"]
    row = 0
    while z < G["beam"] - 0.01:
        h = min(course, G["beam"] - z)
        offset = (row % 2) * 4.0
        x = -half
        cut = [-half] + [k * 8.0 - half + offset for k in range(1, 5) if -half < k * 8.0 - half + offset < half] + [half]
        for a, b in zip(cut, cut[1:]):
            bm_box(bm, ((a + b) / 2, (yf + yb) / 2, z + h / 2), (b - a - 0.25, yb - yf, h - 0.25), bevel=0.12)
        bm_box(bm, (0, (yf + yb) / 2 + 0.3, z + h / 2), (W, yb - yf - 0.8, h))  # joints (en retrait)
        z += h
        row += 1
    # pilastres aux deux bords (à moitié : deux modules voisins en font un entier)
    for s in (-1, 1):
        x = s * (half - 1.5)
        bm_box(bm, (x, yf - 0.6, (G["plinth"] + G["beam"]) / 2), (3.0, 1.2, G["beam"] - G["plinth"]))
        bm_box(bm, (x, yf - 0.9, G["beam"] - 1.0), (3.6, 1.8, 2.0), bevel=0.15)  # chapiteau
    # niche peu profonde derrière la statue (ombre qui détache la silhouette)
    bm_box(bm, (0, yf - 0.2, 36.0), (19.0, 0.4, 50.0))
    # entablement : architrave, frise, corniche à denticules, couronnement
    beam = G["beam"]
    ef = -5.5  # l'architrave avance au-dessus des mains
    bm_box(bm, (0, (ef + yb) / 2, beam + 1.5), (W, yb - ef, 3.0), bevel=0.12)
    bm_box(bm, (0, (ef + yb) / 2 - 0.4, beam + 3.3), (W, yb - ef + 0.8, 0.6), bevel=0.1)
    fz0, fz1 = beam + 3.6, beam + 7.2
    bm_box(bm, (0, (ef + 0.6 + yb) / 2, (fz0 + fz1) / 2), (W, yb - ef - 0.6, fz1 - fz0))  # frise
    for k in range(4):  # triglyphes
        x = -half + 4.0 + k * 8.0
        for g in (-0.7, 0.0, 0.7):
            bm_box(bm, (x + g, ef + 0.1, (fz0 + fz1) / 2), (0.45, 0.6, fz1 - fz0 - 0.4))
    for k in range(4):  # métopes : petits disques (médaillons) entre les triglyphes
        x = -half + 8.0 + k * 8.0
        if x >= half:
            continue
        bm_cyl(bm, (x, ef + 0.5, (fz0 + fz1) / 2), (x, ef - 0.05, (fz0 + fz1) / 2), 1.2, sides=14)
    cz = fz1
    for k in range(16):  # denticules
        x = -half + 1.0 + k * 2.0
        bm_box(bm, (x, ef - 0.7, cz + 0.4), (1.1, 1.4, 0.8))
    bm_box(bm, (0, (ef - 1.6 + yb) / 2, cz + 1.3), (W, yb - ef + 1.6, 1.0), bevel=0.15)
    bm_box(bm, (0, (ef - 2.4 + yb) / 2, cz + 2.1), (W, yb - ef + 2.4, 0.6), bevel=0.1)
    bm_box(bm, (0, (ef - 1.8 + yb) / 2, cz + 2.7), (W, yb - ef + 1.0, 0.6), bevel=0.1)
    top = cz + 3.0
    # couronnement : blocs de parapet
    for k in range(8):
        x = -half + 2.0 + k * 4.0
        bm_box(bm, (x, (ef + yb) / 2, top + 0.9), (3.0, yb - ef - 2.0, 1.8), bevel=0.15)
    obj = bm_object("StatueWall_Module", bm)
    return obj, top + 1.8


def build_pier():
    G = PIER
    s, h = G["size"], G["height"]
    bm = bmesh.new()
    bm_box(bm, (0, 0, 1.0), (s + 2.4, s + 2.4, 2.0), bevel=0.2)
    bm_box(bm, (0, 0, 3.0), (s + 1.2, s + 1.2, 2.0), bevel=0.2)
    bm_box(bm, (0, 0, (4.0 + h - 8) / 2), (s, s, h - 12.0))
    # cannelures (stries verticales) sur les 4 faces
    for face in range(4):
        q = Matrix.Rotation(math.radians(90 * face), 3, "Z")
        for k in range(5):
            x = -s / 2 + 0.9 + k * (s - 1.8) / 4
            c = q @ Vector((x, -s / 2 - 0.05, (4.0 + h - 8) / 2))
            dims = q @ Vector((0.45, 0.3, h - 14.0))
            bm_box(bm, c, (abs(dims.x), abs(dims.y), dims.z))
    # chapiteau, abaque et vasque du brasero
    bm_box(bm, (0, 0, h - 7.0), (s + 1.4, s + 1.4, 2.0), bevel=0.25)
    bm_box(bm, (0, 0, h - 5.2), (s + 2.6, s + 2.6, 1.6), bevel=0.25)
    bm_box(bm, (0, 0, h - 3.6), (s + 0.6, s + 0.6, 1.6), bevel=0.2)
    bm_cyl(bm, (0, 0, h - 2.8), (0, 0, h - 1.2), 1.4, 1.4, sides=14)
    bm_cyl(bm, (0, 0, h - 1.2), (0, 0, h + 0.8), 1.6, 3.4, sides=16)
    obj = bm_object("StatueWall_Pier", bm)
    return obj, [0.0, 0.0, h + 1.6]


def build_all(only=None):
    pieces, manifest = [], {"module": dict(MODULE), "pier": dict(PIER), "statues": {}}
    mod, top = build_module()
    manifest["module"]["height"] = round(top, 3)
    pier, fire = build_pier()
    manifest["pier"]["fire"] = fire
    pieces += [mod, pier]
    for pose in POSES:
        if only and pose not in only:
            continue
        objs, anchors = build_statue(pose)
        manifest["statues"][pose] = anchors
        pieces += objs
    bpy.context.view_layer.update()
    for o in pieces:
        o.data.update()
        bb = [o.matrix_world @ Vector(c) for c in o.bound_box]
        lo = Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
        hi = Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
        manifest.setdefault("pieces", {})[o.name] = {
            "center": [round((lo.x + hi.x) / 2, 3), round((lo.y + hi.y) / 2, 3)],
            "bottom": round(lo.z, 3),
            "size": [round(hi.x - lo.x, 3), round(hi.y - lo.y, 3), round(hi.z - lo.z, 3)],
            "tris": tri_count(o),
        }
    return pieces, manifest

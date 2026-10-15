"""
Objets de style de MOG LIFE (étape 3) : coupes, barbes, hauts et accessoires, sculptés POUR CHAQUE CORPS DE STADE
à partir des mêmes mesures que le corps (build_bodies.geometry) : un débardeur épouse un Normie comme un
GOD MOGGER. Même style que les corps (low poly PS1, texture à éclairage cuit), une seule texture partagée.

Chaque objet = une pièce par partie du squelette qu'il recouvre, nommée <Stade>__<Objet>__<Partie>
(ex. Bro__Hawaiian__UpperTorso) : soudée à cette partie par BodyService, elle suit animations, pump et croissance.

Écrit :
- assets/export/characters/MogLife_Characters.fbx : les 7 corps (build_bodies.py, à lancer avant) ET tous les objets
  de style, avec leurs textures à côté : UN SEUL import dans Studio (Accueil -> Importer 3D), puis
  tools/install_characters.luau
- src/shared/Config/StylePieces.luau : pièces de chaque objet et leur décalage par rapport à leur partie
Dans Blender : exec(open(r"...\\tools\\blender\\build_style.py", encoding="utf-8").read())
"""
import bpy, bmesh, math, os, random
from mathutils import Vector

D = r"C:\Users\antoi\Documents\MogLife\tools\blender"
ROOT = r"C:\Users\antoi\Documents\MogLife"
BODIES_LIBRARY = True
path = os.path.join(D, "build_bodies.py")
exec(compile(open(path, encoding="utf-8").read(), path, "exec"), globals())
STYLE_OUT = os.path.join(ROOT, "assets", "export", "characters")
os.makedirs(STYLE_OUT, exist_ok=True)


# ------------------------------------------------------------------ texture partagée
def paint_style_atlas():
    random.seed(7)
    a = Atlas("Style", ATLAS_SIZE)

    def plain(rgb, amt=0.025, light=0.2):
        return lambda x, y: lit(noise(rgb, amt), y, light)

    a.cell("white", 0, 0, plain((0.95, 0.94, 0.9)))
    a.cell("black", 1, 0, plain((0.1, 0.1, 0.11)))
    a.cell("gold", 2, 0, lambda x, y: lit(noise((0.95, 0.74, 0.2), 0.05), y) if (x + y) % 7 else (1.0, 0.92, 0.55))

    def hawaiian(x, y):                               # fleurs blanches et feuilles sur fond orange
        c = noise((0.98, 0.45, 0.18), 0.03)
        for fx, fy in ((7, 7), (23, 9), (14, 21), (28, 26), (4, 27)):
            d = (x - fx) ** 2 + (y - fy) ** 2
            if d < 5:
                c = (1.0, 0.95, 0.8) if d > 1 else (1.0, 0.8, 0.1)
            elif d < 9 and (x + y) % 2:
                c = (0.15, 0.55, 0.25)
        return lit(c, y, 0.12)
    a.cell("hawaiian", 3, 0, hawaiian)

    def track(x, y):                                  # survêtement bleu, deux bandes blanches
        c = (0.95, 0.95, 0.95) if x in (3, 4, 7, 8, 23, 24, 27, 28) else noise((0.16, 0.3, 0.78), 0.025)
        return lit(c, y)
    a.cell("track", 4, 0, track)

    def track_front(x, y):                            # fermeture éclair au milieu
        if x in (15, 16):
            return (0.88, 0.88, 0.9)
        return track(x, y)
    a.cell("track_front", 5, 0, track_front)

    def satin(x, y):                                  # peignoir de boxe : reflets
        c = (0.78, 0.07, 0.12)
        k = 0.85 + 0.3 * max(0.0, math.sin((x + y * 0.6) * 0.35))
        return tuple(min(1, v * k) for v in c)
    a.cell("satin", 6, 0, satin)

    def pajama(x, y):                                 # pyjama bleu ciel à rayures blanches
        c = (0.96, 0.96, 1.0) if x % 8 in (0, 1) else noise((0.45, 0.62, 0.92), 0.02)
        return lit(c, y, 0.12)
    a.cell("pajama", 7, 0, pajama)

    a.cell("hair_yellow", 0, 1, lambda x, y: noise((0.98, 0.84, 0.2), 0.06))
    a.cell("hair_brown", 1, 1, lambda x, y: noise((0.36, 0.2, 0.09), 0.05))
    a.cell("hair_pink", 2, 1, lambda x, y: noise((1.0, 0.3, 0.62), 0.05))
    a.cell("hair_black", 3, 1, lambda x, y: noise((0.07, 0.06, 0.07), 0.04) if (x * 3 + y) % 9 else (0.25, 0.25, 0.3))
    a.cell("beard_brown", 4, 1, lambda x, y: noise((0.3, 0.17, 0.08), 0.07))
    a.cell("beard_ginger", 5, 1, lambda x, y: noise((0.78, 0.36, 0.12), 0.07))
    a.cell("beard_black", 6, 1, lambda x, y: noise((0.08, 0.07, 0.07), 0.05))
    a.cell("lens", 7, 1, lambda x, y: (0.55, 0.65, 0.8) if x + y < 12 and x + y > 8 else (0.05, 0.06, 0.09))

    a.cell("red", 0, 2, plain((0.86, 0.12, 0.14)))
    a.cell("terry", 1, 2, lambda x, y: lit((0.97, 0.97, 0.95) if (x + y) % 3 else (0.86, 0.86, 0.84), y, 0.1))
    a.cell("shaker", 2, 2, lambda x, y: lit(noise((0.5, 0.78, 0.98), 0.02), y, 0.3))
    a.cell("bronze", 3, 2, lambda x, y: lit(noise((0.75, 0.45, 0.2), 0.05), y))
    a.cell("purple", 4, 2, plain((0.48, 0.16, 0.66)))

    def mog_front(x, y):                              # débardeur noir, haltère doré sur la poitrine (sans texte)
        c = noise((0.1, 0.1, 0.11), 0.02)
        if 18 <= y <= 21 and 8 <= x <= 23:
            c = (0.95, 0.74, 0.2)
        if 15 <= y <= 24 and (8 <= x <= 10 or 21 <= x <= 23):
            c = (0.95, 0.74, 0.2)
        return lit(c, y, 0.15)
    a.cell("mog_front", 5, 2, mog_front)

    def bald(x, y):                                   # crâne lustré : reflet blanc
        c = noise((0.93, 0.72, 0.56), 0.015)
        if (x - 11) ** 2 + (y - 22) ** 2 < 14:
            c = (1.0, 0.98, 0.92)
        return lit(c, y, 0.15)
    a.cell("bald", 6, 2, bald)

    def sock(x, y):                                   # chaussette blanche à deux rayures rouges
        c = (0.85, 0.12, 0.15) if y in (24, 25, 28, 29) else noise((0.97, 0.97, 0.95), 0.015)
        return lit(c, y, 0.1)
    a.cell("sock", 7, 2, sock)

    a.cell("chrome", 0, 3, lambda x, y: lit(noise((0.8, 0.82, 0.86), 0.06), y, 0.35))
    a.cell("strap", 1, 3, plain((0.2, 0.2, 0.22)))
    a.cell("ribbon", 2, 3, lambda x, y: (0.15, 0.3, 0.75) if x < 16 else (0.85, 0.15, 0.18))
    a.cell("pajama_front", 3, 3, lambda x, y: (0.96, 0.96, 1.0) if x in (15, 16) and y % 8 < 3 else pajama(x, y))
    a.cell("hawaiian_front", 4, 3, lambda x, y: (0.93, 0.72, 0.56) if abs(x - 15.5) < (y - 14) * 0.6 else hawaiian(x, y))
    a.cell("fluo", 5, 3, lambda x, y: lit((0.95, 0.95, 0.95) if x in (2, 3) else noise((0.55, 1.0, 0.15), 0.03), y, 0.15))

    def velvet(x, y):                                 # velours violet : côtes verticales
        c = (0.42, 0.14, 0.55) if x % 4 else (0.32, 0.1, 0.42)
        return lit(noise(c, 0.02), y, 0.2)
    a.cell("velvet", 6, 3, velvet)

    def leather(x, y):                                # cuir noir brillant : reflet en bande
        k = 0.12 + 0.35 * max(0.0, math.sin((x * 0.5 + y * 0.15)))
        return (k * 0.6, k * 0.55, k * 0.5)
    a.cell("leather", 7, 3, leather)

    a.cell("skin", 0, 4, lambda x, y: lit(noise((0.93, 0.72, 0.56), 0.02), y, 0.15))
    a.cell("brow_dark", 1, 4, lambda x, y: noise((0.12, 0.08, 0.05), 0.04))

    def teeth(x, y):                                  # dents éclatantes, avec une étincelle
        c = (0.82, 0.8, 0.76) if x % 6 == 0 else (1.0, 1.0, 0.97)
        if (x - 25) ** 2 + (y - 22) ** 2 < 6:
            c = (1.0, 1.0, 1.0)
        return c
    a.cell("teeth_white", 2, 4, teeth)
    a.cell("lips", 3, 4, lambda x, y: noise((0.62, 0.36, 0.32), 0.02))
    return a


# ------------------------------------------------------------------ outils
class Wardrobe:
    """Formes d'un objet de style, rangées par partie du squelette."""

    def __init__(self, builder):
        self.b = builder
        self.items = {}

    def start(self, item):
        self.current = self.items.setdefault(item, {})

    def make(self, part, bm, cell, front_cell=None):
        obj = self.b.make(bm, cell, front_cell)
        self.current.setdefault(part, []).append(obj)


def ring_upright(center, radius, thickness, height, n=16):
    """Anneau vertical (axe avant-arrière), ex. la grille du ventilateur."""
    from mathutils import Matrix
    bm = ring((0, 0, 0), radius, thickness, height, n)
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "X"))
    for v in bm.verts:
        v.co += Vector(center)
    return bm


def sides():
    return (("Left", 1), ("Right", -1))  # en Blender, la gauche du personnage est vers +X


# ------------------------------------------------------------------ hauts (recouvrent le torse, et les bras selon le haut)
def torso_cover(w, g, cell, front, t, crop=False, sleeves=None, robe=False, emblem=None):
    """Recouvre le torse (mêmes formes que le corps, gonflées de t). sleeves : None, "short" ou "long"."""
    J, cfg = g["J"], g["cfg"]
    waist, neck = J["Waist"], J["Neck"]
    h, depth, chest_w, waist_w, belly = g["h"], g["depth"], g["chest_w"], g["waist_w"], g["belly"]
    if not crop:
        w.make("UpperTorso", lowsphere((0, -belly, waist.z + h * 0.32), (waist_w / 2 + t, depth * 0.45 + belly + t, h * 0.42 + t)),
               cell, front_cell=front)
    chest_z = neck.z - h * (0.4 if crop else 0.36)
    # Une seule poitrine large et bombée qui recouvre les pectoraux (deux sphères sous un tissu se liraient
    # comme une poitrine : jamais pour un jeu tous publics)
    pec = cfg["pec"]
    w.make("UpperTorso", lowsphere((0, 0.02 - pec * 0.2, chest_z), (chest_w / 2 + t, depth * 0.55 + pec * 0.45 + t,
                                                                    h * (0.36 if crop else 0.44) + t), 10, 8),
           cell, front_cell=front)
    for sx in (-1, 1):
        if cfg["lat"] > 0:
            w.make("UpperTorso", lowsphere((chest_w * 0.38 * sx, 0.1, neck.z - h * 0.45),
                                           (cfg["lat"] + t, depth * 0.38 + t, h * 0.32 + t)), cell)
    if emblem:
        # Emblème posé devant la poitrine (devant les pectoraux s'il y en a)
        front_y = 0.02 - pec * 0.2 - (depth * 0.55 + pec * 0.45 + t) - 0.02
        size = g["chest_w"] * 0.3
        w.make("UpperTorso", block((0, front_y, neck.z - h * 0.3), (size, 0.05, size * 0.7)), emblem)
    if sleeves:
        delt, bicep, forearm = cfg["delt"], cfg["bicep"], cfg["forearm"]
        for side, _ in sides():
            sh, el, wr = J[side + "Shoulder"], J[side + "Elbow"], J[side + "Wrist"]
            arm_top = Vector((el.x, el.y, sh.z - 0.05))
            delt_r = max(delt, abs(el.x - sh.x) * 0.75)
            w.make(side + "UpperArm", lowsphere((sh.x * 0.4 + el.x * 0.6, 0, sh.z - 0.08), (delt_r + t, delt * 0.95 + t, delt * 0.9 + t)),
                   cell)
            end = arm_top.lerp(el, 0.5) if sleeves == "short" else el
            w.make(side + "UpperArm", limb(tuple(arm_top), tuple(end), delt * 0.62 + t, bicep + t * 1.4, bicep * 0.95 + t * 1.4),
                   cell)
            if sleeves == "long":
                w.make(side + "LowerArm", limb(tuple(el), tuple(el.lerp(wr, 0.85)), forearm * 0.9 + t, forearm + t,
                                               forearm * 0.75 + t, mid_t=0.3), cell)
                w.make(side + "LowerArm", limb(tuple(el.lerp(wr, 0.78)), tuple(el.lerp(wr, 0.92)), forearm * 0.82 + t * 1.6,
                                               forearm * 0.82 + t * 1.6, forearm * 0.8 + t * 1.6), "white" if cell == "track" else cell)
    if robe:
        root = J["Root"]
        hip_w = g["hip_w"]
        w.make("LowerTorso", lowsphere((0, 0.02, root.z + 0.1), (hip_w * 0.5 + t * 1.5, depth * 0.47 + t * 1.5, 0.4)), cell)
        # Revers blancs croisés sur la poitrine : c'est un peignoir de boxeur, pas une robe
        for sx in (-1, 1):
            w.make("UpperTorso", prism((sx * g["chest_w"] * 0.18, -depth * 0.55 - pec * 0.6 - t, neck.z + 0.05),
                                       (-sx * g["chest_w"] * 0.05, -depth * 0.5 - pec * 0.55 - t, neck.z - h * 0.7),
                                       0.09, 0.09, sides=4), "white")
        # Ceinture nouée
        w.make("LowerTorso", ring((0, 0.02, root.z + 0.35), max(hip_w * 0.5, depth * 0.5) + t * 2.5, 0.08, 0.16, 10), "white")
        # Pans du peignoir sur les cuisses (suivent les jambes)
        for side, _ in sides():
            hip, knee = J[side + "Hip"], J[side + "Knee"]
            thigh = cfg["thigh"]
            w.make(side + "UpperLeg", prism((hip.x, 0.02, hip.z), (hip.x * 1.04, 0.02, hip.z - (hip.z - knee.z) * 0.8),
                                            thigh * 1.2 + t * 1.5, thigh * 1.25 + t * 1.5, sides=8), cell)


def build_tops(w, g):
    t = 0.05 + g["cfg"]["bicep"] * 0.04
    w.start("TightTank")         # trop petit : s'arrête au-dessus du nombril
    torso_cover(w, g, "white", "white", t, crop=True)
    w.start("MogTank")
    torso_cover(w, g, "black", None, t, emblem="mog_front")
    w.start("Hawaiian")
    torso_cover(w, g, "hawaiian", "hawaiian_front", t * 1.4, sleeves="short")
    w.start("TrackJacket")
    torso_cover(w, g, "track", "track_front", t * 1.6, sleeves="long")
    w.start("BoxerRobe")
    torso_cover(w, g, "satin", None, t * 2.2, sleeves="short", robe=True)
    w.start("PajamaTop")
    torso_cover(w, g, "pajama", "pajama_front", t * 1.4, sleeves="long")


# ------------------------------------------------------------------ bas (recouvrent le short de base)
def legs_cover(w, g, cell, t, length):
    """length : "short" (mi-cuisse), "long" (jusqu'aux chevilles)."""
    J, cfg = g["J"], g["cfg"]
    root = J["Root"]
    thigh, calf = cfg["thigh"], cfg["calf"]
    w.make("LowerTorso", lowsphere((0, 0.02, root.z + 0.1), (g["hip_w"] * 0.5 + t, g["depth"] * 0.45 + t, 0.38 + t)), cell)
    for side, _ in sides():
        hip, knee, ankle = J[side + "Hip"], J[side + "Knee"], J[side + "Ankle"]
        x = hip.x
        if length == "short":
            w.make(side + "UpperLeg", limb((x, 0, hip.z + 0.05), (x, 0, hip.z - (hip.z - knee.z) * 0.55),
                                           thigh * 1.08 + t, thigh * 1.14 + t, thigh * 1.12 + t), cell)
        else:
            w.make(side + "UpperLeg", limb((x, 0, knee.z), (x, 0, hip.z + 0.05), calf * 0.8 + t, thigh + t, thigh * 1.08 + t,
                                           bulge_dir=(0, -1, 0), bulge=thigh * 0.15), cell)
            w.make(side + "LowerLeg", limb((x, 0, ankle.z + 0.12), (x, 0, knee.z), calf * 0.6 + t, calf + t, calf * 0.8 + t,
                                           mid_t=0.62, bulge_dir=(0, 1, 0), bulge=calf * 0.25), cell)
            w.make(side + "LowerLeg", lowsphere((x, -0.03, knee.z), (calf * 0.8 + t, calf * 0.78 + t, calf * 0.75 + t), 6, 4),
                   cell)


def build_bottoms(w, g):
    t = 0.05 + g["cfg"]["thigh"] * 0.05
    w.start("FluoShorts")        # short de sport fluo, liseré blanc
    legs_cover(w, g, "fluo", t, "short")
    w.start("VelvetJoggers")     # jogging en velours violet
    legs_cover(w, g, "velvet", t, "long")
    w.start("LeatherPants")      # pantalon de cuir (qui grince)
    legs_cover(w, g, "leather", t * 0.8, "long")


# ------------------------------------------------------------------ coupes (remplacent la coupe de base)
def build_hair(w, g):
    r, hy, z = g["head_r"], g["hy"], g["head_z"]
    front = hy - r * 0.9

    w.start("Banana")            # banane géante qui s'avance au-dessus du visage
    w.make("Head", half_sphere((0, hy + 0.03, z + r * 0.18), (r * 0.9, r * 1.04, r * 0.85)), "hair_yellow")
    for k in range(7):
        a = k / 6
        c = (0, hy + r * 0.3 - a * r * 1.9, z + r * (0.85 + 0.55 * math.sin(a * math.pi * 0.9)))
        rr = r * (0.42 - 0.2 * a)
        w.make("Head", lowsphere(c, (rr * 1.25, rr * 1.1, rr), 8, 5), "hair_yellow")

    w.start("Mullet")            # court devant, long derrière (business devant, party derrière)
    w.make("Head", half_sphere((0, hy + 0.04, z + r * 0.22), (r * 0.88, r * 1.0, r * 0.78)), "hair_brown")
    w.make("Head", block((0, hy + r * 0.82, z - r * 0.55), (r * 1.35, r * 0.35, r * 1.4), taper_top=1.15), "hair_brown")
    w.make("Head", block((0, hy + r * 0.88, z - r * 1.25), (r * 1.2, r * 0.3, r * 0.3), taper_top=1.1), "hair_brown")

    w.start("Mohawk")            # crête rose sur un crâne rasé
    w.make("Head", half_sphere((0, hy + 0.02, z + r * 0.2), (r * 0.86, r * 0.99, r * 0.8)), "bald")
    for k in range(6):
        y = hy - r * 0.75 + k * r * 0.33
        w.make("Head", pyramid((0, y, z + r * 0.85), (0, y - r * 0.1, z + r * (1.75 - abs(k - 2.2) * 0.12)), r * 0.09, r * 0.2),
               "hair_pink")

    w.start("ShinyBald")         # crâne rasé et lustré
    w.make("Head", half_sphere((0, hy + 0.02, z + r * 0.12), (r * 0.86, r * 0.99, r * 0.9)), "bald")

    w.start("Pompadour")         # un mètre de banane noire gominée
    w.make("Head", half_sphere((0, hy + 0.03, z + r * 0.2), (r * 0.89, r * 1.02, r * 0.82)), "hair_black")
    w.make("Head", lowsphere((0, hy - r * 0.25, z + r * 1.45), (r * 0.75, r * 0.95, r * 0.95), 10, 7), "hair_black")
    w.make("Head", lowsphere((0, front, z + r * 1.6), (r * 0.6, r * 0.6, r * 0.65), 8, 6), "hair_black")


# ------------------------------------------------------------------ visage (chez le coiffeur)
def build_faces(w, g):
    cfg = g["cfg"]
    r, hy, z = g["head_r"], g["hy"], g["head_z"]
    jw, jh = cfg["jaw_w"], cfg["jaw_h"]
    jf, jz, jy, jd = g["jaw_front"], g["jaw_z"], g["jaw_y"], g["jaw_depth"]
    brow_y = hy - r * 0.86 - 0.08
    brow_z = z + r * 0.3

    w.start("FrownBrows")        # sourcils froncés : deux barres épaisses en V
    for sx in (-1, 1):
        inner = Vector((sx * r * 0.1, brow_y, brow_z - r * 0.08))
        outer = Vector((sx * r * 0.62, brow_y + 0.02, brow_z + r * 0.12))
        w.make("Head", prism(tuple(inner), tuple(outer), 0.07 + r * 0.05, 0.06 + r * 0.04, sides=4), "brow_dark")

    w.start("SparkleSmile")      # sourire éclatant : une rangée de dents immense
    w.make("Head", block((0, jf - 0.05, jz + jh * 0.12), (jw * 0.72, 0.08, jh * 0.22)), "teeth_white")
    for sx in (-1, 1):
        w.make("Head", block((sx * jw * 0.38, jf - 0.04, jz + jh * 0.2), (jw * 0.08, 0.08, jh * 0.14)), "teeth_white")

    w.start("MegaJaw")           # mâchoire encore plus carrée : un bloc qui déborde de partout
    w.make("Head", block((0, jy - jd * 0.08, jz - jh * 0.12), (jw * 1.28, jd * 1.12, jh * 1.05), taper_top=0.9), "skin")
    w.make("Head", block((0, jf - jd * 0.2, jz + jh * 0.1), (jw * 0.5, 0.06, jh * 0.18)), "lips")
    w.make("Head", block((0, jf - jd * 0.22, jz + jh * 0.11), (jw * 0.4, 0.04, jh * 0.08)), "teeth_white")


# ------------------------------------------------------------------ barbes (nouvelle catégorie, chez le coiffeur)
def build_beards(w, g):
    cfg = g["cfg"]
    jw, jh = cfg["jaw_w"], cfg["jaw_h"]
    jf, jz, jy, jd = g["jaw_front"], g["jaw_z"], g["jaw_y"], g["jaw_depth"]
    r = g["head_r"]

    w.start("LumberBeard")       # grosse barbe de bûcheron + moustache
    w.make("Head", block((0, jy - 0.02, jz - jh * 0.35), (jw * 1.12, jd * 1.05, jh * 0.9), taper_top=1.05), "beard_brown")
    w.make("Head", block((0, jf - 0.1, jz - jh * 0.75), (jw * 0.9, 0.3, jh * 0.9), taper_top=1.2), "beard_brown")
    w.make("Head", block((0, jf - 0.06, jz + jh * 0.3), (jw * 0.62, 0.12, jh * 0.18)), "beard_brown")

    w.start("Goatee")            # bouc pointu
    w.make("Head", pyramid((0, jf - 0.04, jz - jh * 0.35), (0, jf - 0.18, jz - jh * 0.95), jw * 0.14, 0.08), "beard_black")
    w.make("Head", block((0, jf - 0.05, jz + jh * 0.3), (jw * 0.45, 0.1, jh * 0.14)), "beard_black")

    w.start("Handlebar")         # moustache en guidon, pointes relevées
    w.make("Head", block((0, jf - 0.06, jz + jh * 0.32), (jw * 0.55, 0.12, jh * 0.18)), "beard_ginger")
    for sx in (-1, 1):
        base = Vector((sx * jw * 0.27, jf - 0.06, jz + jh * 0.32))
        tip = base + Vector((sx * jw * 0.3, 0.02, jh * 0.45))
        w.make("Head", prism(tuple(base), tuple(tip), jh * 0.1, jh * 0.03, sides=5), "beard_ginger")

    w.start("ChinStrap")         # collier fin qui suit la mâchoire
    for sx in (-1, 1):
        w.make("Head", block((sx * jw * 0.5, jy, jz), (0.08, jd * 0.8, jh * 0.95)), "beard_black")
    w.make("Head", block((0, jy, jz - jh * 0.5), (jw * 1.04, jd * 0.95, 0.08)), "beard_black")
    w.make("Head", block((0, jf - 0.02, jz - jh * 0.42), (jw * 0.9, 0.08, jh * 0.16)), "beard_black")
    _ = r


# ------------------------------------------------------------------ accessoires
def build_accessories(w, g):
    J, cfg = g["J"], g["cfg"]
    r, hy, z = g["head_r"], g["hy"], g["head_z"]
    neck, depth, h = J["Neck"], g["depth"], g["h"]
    chest_front = -depth * 0.55 - (cfg["pec"] * 0.2 if cfg["pec"] else 0)
    # Taille des accessoires proportionnelle au gabarit (un shaker de Normie serait invisible sur un God Mogger)
    k = max(1.0, g["chest_w"] / 1.6)
    back = depth * 0.55 + cfg["lat"] * 0.35 + 0.15

    w.start("Headband")
    w.make("Head", ring((0, hy, z + r * 0.35), r * 0.98, 0.1, r * 0.3, 10), "red")

    w.start("Sweatbands")
    for side, _ in sides():
        el, wr = J[side + "Elbow"], J[side + "Wrist"]
        c = el.lerp(wr, 0.82)
        rad = cfg["forearm"] * 0.75 + 0.07
        w.make(side + "LowerArm", prism((c.x, c.y, c.z + 0.12), (c.x, c.y, c.z - 0.12), rad, rad, sides=8), "terry")

    w.start("DumbbellShades")    # lunettes : deux disques comme des poids, barre chromée
    ey_z = max(z + r * 0.12, g["jaw_top"] + cfg["eye_r"] * 0.7)
    ey_y = min(hy - r * 0.78, g["jaw_front"] + cfg["eye_r"] * 0.8) - cfg["eye_r"] * 0.9
    w.make("Head", prism((-r * 0.85, ey_y, ey_z), (r * 0.85, ey_y, ey_z), 0.03, 0.03, sides=6), "chrome")
    for sx in (-1, 1):
        w.make("Head", prism((sx * r * 0.36, ey_y + 0.04, ey_z), (sx * r * 0.36, ey_y - 0.04, ey_z), r * 0.26, r * 0.26, sides=10),
               "lens")
        w.make("Head", prism((sx * r * 0.88, ey_y + 0.1, ey_z), (sx * r * 0.88, ey_y + r * 0.9, ey_z), 0.03, 0.03, sides=5),
               "chrome")

    w.start("ShakerBackpack")    # un shaker géant sur le dos, avec ses bretelles
    sz = neck.z - h * 0.45
    sr = 0.38 * k
    w.make("UpperTorso", prism((0, back + sr, sz - h * 0.4), (0, back + sr, sz + h * 0.35), sr, sr * 0.87, sides=10), "shaker")
    w.make("UpperTorso", prism((0, back + sr, sz + h * 0.35), (0, back + sr, sz + h * 0.5), sr * 0.95, sr * 0.8, sides=10), "black")
    for sx in (-1, 1):
        w.make("UpperTorso", block((sx * g["chest_w"] * 0.22, 0, neck.z - h * 0.3), (0.14, depth * 1.15, 0.12)), "strap")

    w.start("GoldChain")         # chaîne en or démesurée et son haltère
    w.make("UpperTorso", ring((0, -0.02, neck.z - 0.12), cfg["neck"] * 1.6 + 0.12, 0.08, 0.1, 12), "gold")
    pend = Vector((0, chest_front - 0.08 * k, neck.z - h * 0.32))
    w.make("UpperTorso", prism(tuple(pend + Vector((-0.22 * k, 0, 0))), tuple(pend + Vector((0.22 * k, 0, 0))), 0.05 * k, 0.05 * k,
                               sides=6), "gold")
    for sx in (-1, 1):
        w.make("UpperTorso", prism(tuple(pend + Vector((sx * 0.18 * k, 0, 0))), tuple(pend + Vector((sx * 0.3 * k, 0, 0))),
                                   0.14 * k, 0.14 * k, sides=8), "gold")
    w.make("UpperTorso", prism((0, chest_front * 0.6, neck.z - 0.15), tuple(pend), 0.03, 0.03, sides=4), "gold")

    w.start("BronzeMedal")       # médaille sur ruban
    med = Vector((0, chest_front - 0.06 * k, neck.z - h * 0.35))
    w.make("UpperTorso", block((0, chest_front * 0.7, neck.z - h * 0.16), (0.28 * k, 0.05, h * 0.36)), "ribbon")
    w.make("UpperTorso", prism(tuple(med + Vector((0, 0.03, 0))), tuple(med - Vector((0, 0.05 * k, 0))), 0.22 * k, 0.22 * k,
                               sides=10), "bronze")

    w.start("CoachWhistle")      # cordon autour du cou, sifflet sur la poitrine
    w.make("UpperTorso", ring((0, -0.02, neck.z - 0.18), cfg["neck"] * 1.5 + 0.1, 0.03, 0.05, 10), "black")
    whistle = Vector((0.12 * k, chest_front - 0.08 * k, neck.z - h * 0.3))
    w.make("UpperTorso", prism(tuple(whistle), tuple(whistle + Vector((0.28 * k, 0, 0))), 0.09 * k, 0.07 * k, sides=8), "chrome")
    w.make("UpperTorso", prism(tuple(whistle + Vector((0.05 * k, 0, 0.05 * k))), tuple(whistle + Vector((0.05 * k, 0, 0.14 * k))),
                               0.04 * k, 0.04 * k, sides=6), "chrome")

    w.start("TinySocks")         # les chaussettes géantes de M. Pas-Les-Jambes
    for side, _ in sides():
        knee, ankle = J[side + "Knee"], J[side + "Ankle"]
        rad = cfg["calf"] * 1.15 + 0.08
        w.make(side + "LowerLeg", prism((ankle.x, 0, ankle.z - 0.05), (knee.x, 0, knee.z - 0.12), rad, rad * 1.1, sides=8),
               "sock")

    w.start("RoyalFan")          # le ventilateur royal, fixé dans le dos (il souffle sur la nuque)
    hub = Vector((0, back + 0.5 * k, neck.z + 0.2 + 0.4 * k))
    w.make("UpperTorso", prism((0, back - 0.05, neck.z - h * 0.4), tuple(hub - Vector((0, 0, 0.2))), 0.06 * k, 0.06 * k, sides=6), "gold")
    w.make("UpperTorso", prism(tuple(hub - Vector((0, 0.1, 0))), tuple(hub + Vector((0, 0.1, 0))), 0.16 * k, 0.16 * k, sides=8), "gold")
    for blade in range(5):
        a = 2 * math.pi * blade / 5
        tip = hub + Vector((math.cos(a) * 1.1 * k, 0.02, math.sin(a) * 1.1 * k))
        w.make("UpperTorso", pyramid(tuple(hub + Vector((math.cos(a) * 0.15 * k, 0, math.sin(a) * 0.15 * k))), tuple(tip),
                                     0.28 * k, 0.04), "purple")
    w.make("UpperTorso", ring_upright(tuple(hub), 1.2 * k, 0.06 * k, 0.08), "gold")


# ------------------------------------------------------------------ assemblage et export
def merge_item(stage, item, parts, mat, col):
    pieces = {}
    for part, objs in parts.items():
        bm = bmesh.new()
        for o in objs:
            bm.from_mesh(o.data)
        name = f"{stage}__{item}__{part}"
        old = bpy.data.objects.get(name)
        if old:
            bpy.data.objects.remove(old, do_unlink=True)
        me = bpy.data.meshes.get(name)
        if me:
            bpy.data.meshes.remove(me)
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        me.materials.append(mat)
        for p in me.polygons:
            p.use_smooth = False
        obj = bpy.data.objects.new(name, me)
        for o in objs:
            m = o.data
            bpy.data.objects.remove(o, do_unlink=True)
            if m.users == 0:
                bpy.data.meshes.remove(m)
        col.objects.link(obj)
        pieces[part] = obj
    return pieces


atlas = paint_style_atlas()
manifest = {}
all_objs = []
for i, stage in enumerate(ORDER):
    g = geometry(stage)
    builder = Builder("Style_" + stage, atlas)
    w = Wardrobe(builder)
    build_tops(w, g)
    build_bottoms(w, g)
    build_hair(w, g)
    build_beards(w, g)
    build_faces(w, g)
    build_accessories(w, g)
    sk = SKELETONS[stage]["parts"]
    manifest[stage] = {}
    for item, parts in w.items.items():
        pieces = merge_item(stage, item, parts, builder.mat, builder.col)
        manifest[stage][item] = {}
        for part, obj in pieces.items():
            xs = [v.co.x for v in obj.data.vertices]
            ys = [v.co.y for v in obj.data.vertices]
            zs = [v.co.z for v in obj.data.vertices]
            c = ((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, (min(zs) + max(zs)) / 2)
            roblox = (-c[0], c[2], c[1])
            pc = sk[part]["center"]
            manifest[stage][item][part] = [round(roblox[k] - pc[k], 3) for k in range(3)]
            obj.location.x = i * 7
            all_objs.append(obj)
    print(f"{stage}: {len(w.items)} objets, {sum(len(p) for p in manifest[stage].values())} pièces, {builder.tris()} triangles")

# Textures (style + une par corps), à côté du FBX pour que Studio les trouve
for image_name, file_name in [("Style_Atlas", "MogLife_Style.png")] + [(f"Body{s}_Atlas", f"Body_{s}.png") for s in ORDER]:
    img = bpy.data.images.get(image_name)
    img.filepath_raw = os.path.join(STYLE_OUT, file_name)
    img.file_format = "PNG"
    img.save()
# Les corps partent dans le même fichier
for stage in ORDER:
    all_objs += [o for o in bpy.data.collections["Body_" + stage].objects if o.type == "MESH"]

# Export (positions remises à zéro)
# Les objets masqués (aperçus) ne seraient pas exportés : tout est réaffiché avant l'export
for lc in bpy.context.view_layer.layer_collection.children:
    lc.hide_viewport = False
    lc.exclude = False
saved = {o: o.location.copy() for o in all_objs}
for o in bpy.context.view_layer.objects:
    o.select_set(False)
for o in all_objs:
    o.location = (0, 0, 0)
    o.hide_set(False)
    o.select_set(True)
bpy.context.view_layer.objects.active = all_objs[0]
fbx = os.path.join(STYLE_OUT, "MogLife_Characters.fbx")
bpy.ops.export_scene.fbx(
    filepath=fbx, use_selection=True, object_types={"MESH"},
    axis_forward="-Z", axis_up="Y", apply_unit_scale=True, apply_scale_options="FBX_SCALE_ALL",
    mesh_smooth_type="FACE", path_mode="RELATIVE", embed_textures=False,
)
for o, loc in saved.items():
    o.location = loc
print(f"{len(all_objs)} pièces exportées dans {fbx}")

lines = [
    "-- Fichier généré par tools/blender/build_style.py : ne pas modifier à la main.",
    "-- Pièces de chaque objet de style, par stade : partie du squelette -> décalage (studs) du centre de la pièce",
    "-- par rapport au centre de cette partie, au repos. Modèle : ReplicatedStorage.Style.<Stade>__<Objet>__<Partie>.",
    "",
    "return {",
]
for stage in ORDER:
    lines.append(f"\t{stage} = {{")
    for item in sorted(manifest[stage]):
        lines.append(f"\t\t{item} = {{")
        for part in sorted(manifest[stage][item]):
            x, y, z = manifest[stage][item][part]
            lines.append(f"\t\t\t{part} = Vector3.new({x:g}, {y:g}, {z:g}),")
        lines.append("\t\t},")
    lines.append("\t},")
lines.append("}")
with open(os.path.join(ROOT, "src", "shared", "Config", "StylePieces.luau"), "w", encoding="utf-8", newline="\n") as f:
    f.write("\n".join(lines) + "\n")
print("StylePieces.luau écrit")

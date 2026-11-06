"""
Corps du joueur, un par stade (Normie -> GOD MOGGER), dans le style des boss (décision D39) :
low poly PS1, anatomie réaliste mais exagérée, texture à éclairage cuit.

Chaque corps est sculpté autour du VRAI squelette R15 du stade (assets/export/bodies/skeletons.json, relevé
dans Roblox avec les proportions de src/shared/Config/Bodies.luau) et découpé en pièces, une ou plusieurs par
partie du squelette : chaque pièce suit son articulation pendant les animations (D28, D37).

Création de personnage (D55) :
- deux corps par stade : masculin (<Stade>) et féminin (<Stade>F), même squelette, même progression absurde ;
- la peau, les cheveux, les yeux, le haut et le short sont des voiles semi-transparents (bro_atlas.paint_tint_cells) :
  le jeu leur donne la couleur choisie par le joueur. Pièces nommées <Partie>[_<Groupe>] :
  (sans groupe) peau, _Hair coupe de base, _Eyes iris, _Top haut de départ, _Shorts short de départ,
  _Mouth<Expression> et _Brow<Expression> : bouche et sourcils de chaque expression (une seule est affichée).

Écrit :
- assets/export/bodies/MogLife_Bodies.fbx + une texture PNG par stade (corps seuls ; pour le jeu, lancer ensuite
  build_style.py qui exporte corps + style dans assets/export/characters/MogLife_Characters.fbx, un seul import,
  puis tools/install_characters.luau)
- assets/export/characters/BodyPieces.pending.luau : décalage de chaque pièce par rapport à sa partie (BodyService),
  à copier dans src/shared/Config/BodyPieces.luau seulement après l'import des nouveaux corps dans Studio
  (sinon les anciens modèles seraient décalés)
Dans Blender : exec(open(r"...\\tools\\blender\\build_bodies.py", encoding="utf-8").read())
Variable optionnelle ONLY = ["Normie", ...] pour ne reconstruire que certains stades (l'export prend tout).
"""
import bpy, bmesh, json, math, os, random
from mathutils import Vector
from mathutils.bvhtree import BVHTree

D = r"C:\Users\antoi\Documents\MogLife\tools\blender"
ROOT = r"C:\Users\antoi\Documents\MogLife"
OUT = os.path.join(ROOT, "assets", "export", "bodies")
for lib in ("lowpoly_lib.py", "bro_atlas.py"):
    path = os.path.join(D, lib)
    exec(compile(open(path, encoding="utf-8").read(), path, "exec"), globals())
LIT_AMT = 0.08      # corps lissés (D115) : la lumière de Roblox fait le modelé, le dégradé cuit reste léger
SMOOTH_ANGLE = 50   # degrés : arêtes plus vives que ça gardées nettes (bord des lèvres, semelle, paupière)

SKELETONS = json.load(open(os.path.join(OUT, "skeletons.json"), encoding="utf-8"))
ORDER = ["Normie", "GymRat", "Bro", "Alpha", "Chad", "Gigachad", "GodMogger"]
EXPRESSIONS = ["Confident", "Nervous", "Determined"]

SKIN = (0.93, 0.72, 0.56)
# Muscles en studs (rayons), de plus en plus exagérés ; vêtements par défaut (la boutique les changera)
STAGES = {
    # Normie « spaghetti » (D55, affiné D115 et D116) : maigre à l'extrême, torse lofté bien plus étroit que la
    # tête, épaules en cintre, bras et jambes comme des spaghettis, coudes et genoux noueux, tee et short trop
    # larges, grosses baskets ; un petit ventre mou. Squelette très étroit et un peu plus grand (Bodies.luau).
    "Normie": dict(top="tee", top_color=(0.55, 0.57, 0.6), shorts=(0.2, 0.3, 0.62), shoe=(0.95, 0.95, 0.95),
                   hair=(0.25, 0.16, 0.09), mouth="nervous", belly=0.05, knobby=True, baggy=True, spaghetti=True,
                   delt_bridge=0.5, delt=0.062, bicep=0.044, forearm=0.04, fist=0.17, chest_w=0.4, depth=0.27,
                   pec=0.0, lat=0.0, trap=0.0, neck=0.06, thigh=0.064, calf=0.05, head_r=0.72, jaw_w=0.52, jaw_h=0.34,
                   jaw_fwd=0.0, eye_r=0.16),
    "GymRat": dict(top="tank", top_color=(0.86, 0.22, 0.22), shorts=(0.15, 0.15, 0.2), shoe=(0.95, 0.95, 0.95),
                   hair=(0.25, 0.16, 0.09), mouth="grin",
                   delt=0.28, bicep=0.25, forearm=0.19, fist=0.31, chest_w=1.6, depth=0.75, pec=0.2, lat=0.16, trap=0.15,
                   neck=0.21, thigh=0.3, calf=0.2, head_r=0.68, jaw_w=0.6, jaw_h=0.4, jaw_fwd=0.05, eye_r=0.16),
    "Bro": dict(top="tank", top_color=(0.2, 0.62, 0.66), shorts=(0.15, 0.15, 0.2), shoe=(0.95, 0.95, 0.95),
                hair=(0.2, 0.13, 0.07), mouth="grin", stubble=True,
                delt=0.33, bicep=0.29, forearm=0.22, fist=0.33, chest_w=1.8, depth=0.84, pec=0.24, lat=0.2, trap=0.22,
                neck=0.24, thigh=0.34, calf=0.23, head_r=0.64, jaw_w=0.68, jaw_h=0.45, jaw_fwd=0.1, eye_r=0.16),
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
                      # Démesuré (D116) : squelette plus grand et plus large, muscles qui débordent de partout,
                      # petite tête perchée sur des trapèzes énormes
                      delt=1.3, bicep=1.15, forearm=0.75, fist=0.66, chest_w=5.0, depth=2.0, pec=1.05, lat=1.3,
                      trap=1.9, neck=0.8, thigh=0.98, calf=0.6, head_r=0.5, jaw_w=1.3, jaw_h=0.74, jaw_fwd=0.45,
                      eye_r=0.14),
}


for _cfg in STAGES.values():
    _cfg["tint"] = True
# Définition musculaire (D117) : 0 = aucun relief ; les reliefs (abdos, biceps, triceps, quadriceps, mollets) n'arrivent
# qu'au Bro, encore doux, et se creusent jusqu'au GOD MOGGER
for _name, _defn in (("Normie", 0.0), ("GymRat", 0.3), ("Bro", 0.5), ("Alpha", 0.75), ("Chad", 0.9),
                     ("Gigachad", 1.0), ("GodMogger", 1.15)):
    STAGES[_name]["defn"] = _defn


def feminine(cfg):
    """Corps féminin du même stade (refait le 17/10, le premier jet ressemblait trop au masculin). Squelette à part,
    plus étroit (Bodies.luau). Silhouette en sablier : taille fine, hanches larges, jambes fortes ; épaules, trapèzes,
    cou et bras plus fins ; une poitrine ronde et modeste d'une seule pièce sous le haut, jamais suggestive (tous
    publics). Visage : grands yeux à longs cils, sourcils fins et arqués, mâchoire ronde, lèvres pleines, joues
    roses. Toujours un haut (brassière de sport aux stades torse nu). La progression reste aussi absurde."""
    f = dict(cfg)
    f.update(
        fem=True, stubble=False, cleft=False,
        hips=1.12, waist=0.7, glutes=True,
        delt=cfg["delt"] * 0.85, bicep=cfg["bicep"] * 0.8, forearm=cfg["forearm"] * 0.78, fist=cfg["fist"] * 0.8,
        thigh=cfg["thigh"] * 1.15, calf=cfg["calf"] * 1.02,
        trap=cfg["trap"] * 0.35, neck=cfg["neck"] * 0.72, lat=0.0, pec=cfg["pec"] * 0.4,
        chest_w=cfg["chest_w"] * 0.8, depth=cfg["depth"] * 0.9, belly=cfg.get("belly", 0) * 0.5,
        jaw_w=cfg["jaw_w"] * 0.7, jaw_h=cfg["jaw_h"] * 0.78, jaw_fwd=cfg["jaw_fwd"] * 0.6,
        eye_r=cfg["eye_r"] * 1.28, accent=(1.0, 0.38, 0.62),
    )
    f["bust"] = 0.07 + f["depth"] * 0.07
    if cfg.get("top", "none") == "none":
        f["top"] = "sports"
    return f


BODY_KEYS = []
BASE = {}
for _name in ORDER:
    for _key, _cfg in ((_name, STAGES[_name]), (_name + "F", feminine(STAGES[_name]))):
        BODY_KEYS.append(_key)
        BASE[_key] = _name
        STAGES[_key] = _cfg

def skeleton(name):
    """Squelette relevé du corps (les corps féminins ont le leur ; à défaut, celui du stade)."""
    return SKELETONS.get(name) or SKELETONS[BASE[name]]


# Groupe de chaque case : une pièce par partie ET par groupe (chaque groupe prend sa couleur dans le jeu)
CELL_GROUP = {"top": "Top", "top_front": "Top", "shorts": "Shorts", "hair": "Hair", "iris": "Eyes"}


def B(v):
    """Coordonnées Roblox (X, Y haut, Z arrière) -> Blender (l'import FBX de Roblox inverse X)."""
    return Vector((-v[0], v[2], v[1]))


# ------------------------------------------------------------------ formes lisses (corps v3, D115)
# Les formes d'avant (fuseaux à bouts plats, 8 côtés, blocs) laissaient des marches aux coudes, aux genoux et aux
# poignets, et des boîtes à la place des mains, des pieds et de la mâchoire. Ces formes-ci se terminent en dôme (deux
# membres qui se touchent se fondent l'un dans l'autre, même quand l'articulation plie) et sont lissées à l'export.
def _frame(axis):
    side = axis.cross(Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((1, 0, 0))).normalized()
    return side, axis.cross(side)


def spindle(p0, p1, r0, rm, r1, sides=12, mid_t=0.5, bulge_dir=None, bulge=0.0, squash=None, rings=6, cap=0.8):
    """Membre lisse : rayon r0 -> rm (à mid_t) -> r1 en courbe douce, bouts arrondis (dômes écrasés de `cap`).
    bulge_dir/bulge : renflement (biceps devant, mollet derrière). squash = (direction, facteur) : section ovale."""
    p0, p1 = Vector(p0), Vector(p1)
    axis = (p1 - p0)
    length = axis.length
    axis = axis.normalized()
    side, up = _frame(axis)
    sq_dir, sq_k = (Vector(squash[0]).normalized(), squash[1]) if squash else (None, 1.0)
    bdir = Vector(bulge_dir).normalized() if bulge_dir else Vector()

    def radius(t):
        if t <= mid_t:
            return r0 + (rm - r0) * math.sin(math.pi / 2 * t / max(mid_t, 1e-4))
        return rm + (r1 - rm) * (1 - math.cos(math.pi / 2 * (t - mid_t) / max(1 - mid_t, 1e-4)))

    # Profil : dôme du bas, corps, dôme du haut (t hors de [0, 1] = dans les dômes)
    profile = []
    for k in range(3, 0, -1):
        a = math.pi / 2 * k / 3
        profile.append((-math.sin(a) * cap * r0 / max(length, 1e-4), r0 * math.cos(a)))
    for i in range(rings + 1):
        t = i / rings
        profile.append((t, radius(t)))
    for k in range(1, 4):
        a = math.pi / 2 * k / 3
        profile.append((1 + math.sin(a) * cap * r1 / max(length, 1e-4), r1 * math.cos(a)))
    bm = bmesh.new()
    loops = []
    for t, r in profile:
        c = p0 + axis * (length * t) + bdir * (bulge * math.sin(math.pi * min(1, max(0, t))))
        ring_v = []
        for i in range(sides):
            a = 2 * math.pi * i / sides
            off = (side * math.cos(a) + up * math.sin(a)) * max(r, 1e-4)
            if sq_dir is not None:
                along = off.dot(sq_dir)
                off += sq_dir * along * (sq_k - 1)
            ring_v.append(bm.verts.new(c + off))
        loops.append(ring_v)
    for lo, hi in zip(loops, loops[1:]):
        for i in range(sides):
            j = (i + 1) % sides
            bm.faces.new((lo[i], lo[j], hi[j], hi[i]))
    bottom = bm.verts.new(p0 - axis * cap * r0)
    top = bm.verts.new(p1 + axis * cap * r1)
    for i in range(sides):
        j = (i + 1) % sides
        bm.faces.new((loops[0][j], loops[0][i], bottom))
        bm.faces.new((loops[-1][i], loops[-1][j], top))
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def ball(center, radii, u=14, v=10):
    """Sphère plus fine que lowsphere (les grosses masses lissées gardent un contour rond)."""
    return lowsphere(center, radii, u, v)


def rounded_box(center, size, bevel=0.3, taper_top=1.0, taper_depth=1.0, segments=2):
    """Boîte aux arêtes arrondies (mâchoire, semelle, sourcils) : `bevel` = part de la plus petite dimension."""
    bm = block(center, size, taper_top=taper_top, taper_depth=taper_depth)
    off = min(size) * bevel * 0.5
    bmesh.ops.bevel(bm, geom=list(bm.edges) + list(bm.verts), offset=off, segments=segments, profile=0.5,
                    affect="EDGES", clamp_overlap=True)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def loft(sections, sides=16):
    """Tronc lofté : sections [(z, cx, cy, rx, ry)] de bas en haut, fermé aux deux bouts. Pour un torse fin dont on
    règle la silhouette tranche par tranche (le Normie « spaghetti »)."""
    bm = bmesh.new()
    loops = []
    for z, cx, cy, rx, ry in sections:
        loops.append([bm.verts.new((cx + math.cos(2 * math.pi * i / sides) * rx, cy + math.sin(2 * math.pi * i / sides) * ry, z))
                      for i in range(sides)])
    for lo, hi in zip(loops, loops[1:]):
        for i in range(sides):
            j = (i + 1) % sides
            bm.faces.new((lo[i], lo[j], hi[j], hi[i]))
    z0, cx0, cy0, rx0, ry0 = sections[0]
    z1, cx1, cy1, rx1, ry1 = sections[-1]
    bottom = bm.verts.new((cx0, cy0, z0 - min(rx0, ry0) * 0.4))
    top = bm.verts.new((cx1, cy1, z1 + min(rx1, ry1) * 0.4))
    for i in range(sides):
        j = (i + 1) % sides
        bm.faces.new((loops[0][j], loops[0][i], bottom))
        bm.faces.new((loops[-1][i], loops[-1][j], top))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def loft2(sections, sides=20):
    """Tronc à sections ovales asymétriques : [(z, rx, ry_avant, ry_arrière)] de bas en haut (avant = -y). Pour un
    torse en V : poitrine bombée devant, dos large, taille fine."""
    bm = bmesh.new()
    loops = []
    for z, rx, ryf, ryb in sections:
        ring_v = []
        for i in range(sides):
            a = 2 * math.pi * i / sides
            s = math.sin(a)
            ring_v.append(bm.verts.new((math.cos(a) * rx, s * (ryb if s > 0 else ryf), z)))
        loops.append(ring_v)
    for lo, hi in zip(loops, loops[1:]):
        for i in range(sides):
            j = (i + 1) % sides
            bm.faces.new((lo[i], lo[j], hi[j], hi[i]))
    z0, rx0, f0, b0 = sections[0]
    z1, rx1, f1, b1 = sections[-1]
    bottom = bm.verts.new((0, (b0 - f0) / 2, z0 - min(rx0, f0, b0) * 0.35))
    top = bm.verts.new((0, (b1 - f1) / 2, z1 + min(rx1, f1, b1) * 0.35))
    for i in range(sides):
        j = (i + 1) % sides
        bm.faces.new((loops[0][j], loops[0][i], bottom))
        bm.faces.new((loops[-1][i], loops[-1][j], top))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def trap_profile(t, z0, zs, r0, r1, depth, trap):
    """Trapèzes (D118) : coupe de la nappe à t = |x| / épaule (0 au cou, 1 à l'épaule). Renvoie (z du dessus, y du
    centre, demi-épaisseur avant, demi-épaisseur arrière, demi-hauteur). Le dessus descend du cou vers l'épaule en
    pente douce, légèrement bombée (le muscle), sans bosse au milieu."""
    top = zs + (z0 - zs) * (1 - t ** 1.7)
    rz = r0 * (1 - t) + r1 * t
    ryb = (depth * 0.3 + trap * 0.1) * (1 - 0.35 * t)
    return top, 0.1 * (1 - t) + 0.04 * t, ryb * 0.62, ryb, rz


def trap_mantle(shx, z0, zs, r0, r1, depth, trap, sides=22, half_rings=12):
    """Une seule nappe de muscle qui va d'une épaule à l'autre en passant derrière le cou : continue au milieu (pas
    de pli entre deux formes) ; ses bouts finissent dans les deltoïdes. Coupe ovale, plus épaisse dans le dos."""
    bm = bmesh.new()
    loops = []
    n = half_rings
    for k in range(-n, n + 1):
        t = abs(k) / n
        x = shx * (k / n)
        top, yc, ryf, ryb, rz = trap_profile(t, z0, zs, r0, r1, depth, trap)
        shrink = 1 - 0.35 * max(0.0, (t - 0.85) / 0.15)    # le bout s'amincit dans le deltoïde
        zc = top - rz
        ring_v = []
        for i in range(sides):
            a = 2 * math.pi * i / sides
            c, sn = math.cos(a), math.sin(a)
            y = yc + c * (ryb if c > 0 else ryf) * shrink
            up = sn * rz * shrink
            if c < 0 and sn > 0:                        # l'avant descend plus bas : il dégage le menton
                up *= 1 + 0.45 * c
            ring_v.append(bm.verts.new((x, y, zc + up)))
        loops.append(ring_v)
    for lo, hi in zip(loops, loops[1:]):
        for i in range(sides):
            j = (i + 1) % sides
            bm.faces.new((lo[i], lo[j], hi[j], hi[i]))
    for ring, sx in ((loops[0], -1), (loops[-1], 1)):
        cen = sum((v.co for v in ring), Vector()) / sides
        tip = bm.verts.new(cen + Vector((sx * r1 * 0.3, 0, 0)))
        for i in range(sides):
            j = (i + 1) % sides
            bm.faces.new((ring[i], ring[j], tip))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def section_at(sections, z):
    """(rx, ry_avant, ry_arrière) du tronc loft2 à la hauteur z (interpolation entre deux tranches)."""
    if z <= sections[0][0]:
        return sections[0][1:]
    for lo, hi in zip(sections, sections[1:]):
        if lo[0] <= z <= hi[0]:
            t = (z - lo[0]) / max(hi[0] - lo[0], 1e-6)
            return tuple(a + (b - a) * t for a, b in zip(lo[1:], hi[1:]))
    return sections[-1][1:]


def front_y(sections, x, z):
    """Surface avant du tronc (y, négatif) à la position x, hauteur z."""
    rx, ryf, _ = section_at(sections, z)
    return -ryf * math.sqrt(max(0.0, 1 - (x / rx) ** 2)) if rx > 0 else 0.0


def pec_slab(center, width, height, thick, sx):
    """Pectoral anatomique : plaque épaisse posée sur la cage, bord inférieur net et bombé, qui s'amincit vers la
    clavicule et remonte vers l'aisselle (pas une boule)."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=18, v_segments=12, radius=1.0)
    for v in bm.verts:
        x, y, z = v.co
        if y > 0:
            y *= 0.25                                # dos plat, collé à la cage
        else:
            y *= 0.55 + 0.5 * max(0.0, -z) + 0.25 * (1 - abs(z))   # plus épais en bas : la masse tombe
        z = z * (0.75 if z < 0 else 1.25)             # bord bas court et rond, haut qui s'étire vers la clavicule
        out = x * sx                                  # côté aisselle : remonte et s'affine
        z += max(0.0, out) * 0.35
        if out > 0:
            y *= 1 - out * 0.75
        v.co = Vector((center[0] + x * width, center[1] + y * thick, center[2] + z * height))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def jaw_shape(center, w, h, d, square, chin, taper):
    """Mâchoire sculptée qui évolue avec le stade (D117), dans la même boîte que l'ancienne (barbes et visages du
    coiffeur s'y appuient). square 0 -> 1 : menton rond et fuyant -> enclume carrée ; chin : menton qui avance
    (négatif = fuyant) ; taper : rétrécit vers le menton."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=28, v_segments=18, radius=1.0)
    p = 2 + square * 5
    for v in bm.verts:
        x, y, z = v.co
        r = math.hypot(x, y)
        if r > 1e-6:
            a = math.atan2(y, x)
            k = 1 / (abs(math.cos(a)) ** p + abs(math.sin(a)) ** p) ** (1 / p)
            x, y = x * k, y * k
        if z < 0:
            x *= 1 - taper * (-z) ** 1.5
            if y < 0:
                y -= chin * (-z) * (-y)            # le bas de l'avant (menton) avance ou recule
        else:
            x *= 1 - 0.18 * z                       # le haut rentre et se fond dans le crâne (pas de rebord)
            y *= 1 - 0.4 * z
            z *= 0.75
        v.co = Vector((center[0] + x * w / 2, center[1] + y * d / 2, center[2] + z * h / 2))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def sweep(points, radii, sides=10, squash=1.0):
    """Tube qui suit une courbe (lèvres, rangée de dents) ; squash < 1 l'aplatit verticalement. Bouts en pointe
    douce."""
    pts = [Vector(q) for q in points]
    bm = bmesh.new()
    loops = []
    for i, c in enumerate(pts):
        t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        up = Vector((0, 0, 1))
        side = t.cross(up).normalized()
        up = side.cross(t).normalized()
        r = max(radii[i], 1e-4)
        loops.append([bm.verts.new(c + (side * math.cos(2 * math.pi * k / sides) +
                                         up * math.sin(2 * math.pi * k / sides) * squash) * r)
                      for k in range(sides)])
    for lo, hi in zip(loops, loops[1:]):
        for k in range(sides):
            j = (k + 1) % sides
            bm.faces.new((lo[k], lo[j], hi[j], hi[k]))
    t0 = (pts[1] - pts[0]).normalized()
    t1 = (pts[-1] - pts[-2]).normalized()
    a = bm.verts.new(pts[0] - t0 * radii[0] * 0.8)
    b = bm.verts.new(pts[-1] + t1 * radii[-1] * 0.8)
    for k in range(sides):
        j = (k + 1) % sides
        bm.faces.new((loops[0][j], loops[0][k], a))
        bm.faces.new((loops[-1][k], loops[-1][j], b))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def face_curve(tree, x0, x1, z_of, y_fallback, n=11, inset=0.0):
    """Points posés sur la surface avant du visage (lancer de rayons sur les volumes de tree, le plus en avant gagne), de x0 à x1, hauteur z_of(u)
    avec u de -1 à 1."""
    out = []
    for i in range(n):
        u = -1 + 2 * i / (n - 1)
        x = x0 + (x1 - x0) * (u + 1) / 2
        z = z_of(u)
        hits = [t.ray_cast(Vector((x, -20, z)), Vector((0, 1, 0)), 40)[0] for t in tree]
        hits = [h.y for h in hits if h is not None]
        y = min(hits) if hits else y_fallback
        out.append((x, y + inset, z))
    return out


class Body:
    """Pièces d'un corps, rangées par partie du squelette."""

    def __init__(self, name, cfg):
        self.name = name
        self.atlas = paint_bro_atlas("Body" + name, dict(cfg, skin=cfg.get("skin", SKIN)))
        self.b = Builder("Body_" + name, self.atlas)
        self.parts = {}

    def make(self, part, bm, cell, front_cell=None, group=None):
        """Range la forme dans la pièce <part>[_<groupe>] (groupe déduit de la case si non précisé)."""
        obj = self.b.make(bm, cell, front_cell)
        group = CELL_GROUP.get(cell, "") if group is None else group
        self.parts.setdefault(part + ("_" + group if group else ""), []).append(obj)
        return obj


def geometry(name):
    """Mesures du corps d'un stade (coordonnées Blender), partagées avec les vêtements (build_style.py)."""
    cfg = STAGES[name]
    sk = skeleton(name)
    g = dict(cfg=cfg, J={k: B(v) for k, v in sk["joints"].items()}, PC={k: B(v["center"]) for k, v in sk["parts"].items()})
    J = g["J"]
    hipspan = abs(J["LeftHip"].x - J["RightHip"].x)
    g["hip_w"] = (hipspan + cfg["thigh"] * 2) * cfg.get("hips", 1.0)
    if cfg.get("baggy"):
        g["hip_w"] = max(g["hip_w"], hipspan + 0.3)
    g["depth"] = cfg["depth"]
    g["h"] = J["Neck"].z - J["Waist"].z
    # Le torse spaghetti ne s'élargit pas jusqu'aux épaules du squelette : les épaules tombent en pente (cintre)
    g["chest_w"] = cfg["chest_w"] if cfg.get("spaghetti") else max(cfg["chest_w"], abs(J["LeftShoulder"].x) * 2.1)
    g["waist_w"] = max(g["hip_w"] * 0.95, g["chest_w"] * 0.62) * cfg.get("waist", 1.0)
    if cfg.get("fem"):
        # Sablier : la taille se règle sur la poitrine (pas sur les hanches élargies)
        g["waist_w"] = g["chest_w"] * 0.6
    g["belly"] = cfg.get("belly", 0)
    head_r = cfg["head_r"]
    g["head_r"] = head_r
    g["hy"] = g["PC"]["Head"].y - 0.05 - cfg["trap"] * 0.1
    g["head_z"] = g["PC"]["Head"].z + 0.05
    jaw_depth = head_r * 1.15 + cfg["jaw_fwd"]
    g["jaw_y"] = g["hy"] - head_r * 0.15 - cfg["jaw_fwd"] * 0.5
    g["jaw_z"] = g["head_z"] - head_r * 0.6 - cfg["jaw_h"] * 0.25
    g["jaw_depth"] = jaw_depth
    g["jaw_front"] = g["jaw_y"] - jaw_depth / 2
    g["jaw_top"] = g["jaw_z"] + cfg["jaw_h"] / 2
    return g


def spaghetti_sections(g, J):
    """Tranches du torse spaghetti (tee du Normie) : poitrine plus étroite que la tête, épaules en cintre qui
    descendent vers les bras, un petit ventre mou devant."""
    cfg = g["cfg"]
    fem = cfg.get("fem", False)
    w, n = J["Waist"].z, J["Neck"].z
    sh = J["LeftShoulder"]
    h = n - w
    cw, d = g["chest_w"] / 2, cfg["depth"] / 2
    belly = g["belly"]
    bust = cfg.get("bust", 0) * 0.6 if fem else 0.0   # poitrine modeste fondue dans le haut (tous publics)
    sh_rx = cw * 1.1 + (abs(sh.x) - cw) * 0.5
    return [
        (w - 0.15, 0, 0.0, cw * 1.06, d * 1.1),
        (w + h * 0.12, 0, -belly * 0.5, cw * (0.8 if fem else 0.98), d * 1.04 + belly * 0.5),
        (w + h * 0.32, 0, -belly * 0.2, cw * (0.82 if fem else 0.95), d + belly * 0.2),
        (w + h * 0.55, 0, -bust * 0.5, cw, d * 0.98 + bust * 0.5),
        (sh.z - 0.18, 0, 0.01, cw * 1.12, d * 0.92),
        (sh.z, 0, 0.01, sh_rx, d * 0.8),
        (sh.z + (n - sh.z) * 0.55, 0, 0.01, (sh_rx + cfg["neck"] * 1.6) / 2, d * 0.68),
        (n - 0.03, 0, 0.01, cfg["neck"] * 1.6, cfg["neck"] * 1.35),
    ]


def build_body(name):
    cfg = STAGES[name]
    sk = skeleton(name)
    J = {k: B(v) for k, v in sk["joints"].items()}
    PC = {k: B(v["center"]) for k, v in sk["parts"].items()}
    body = Body(name, cfg)
    top = cfg.get("top", "none")
    clothed = top in ("tee", "tank", "sports")
    trunk = "top" if clothed else "skin"
    fem = cfg.get("fem", False)
    veiny = "veiny" if cfg.get("veins") else "skin"
    random.seed(len(name))
    g = geometry(name)

    # ---------------------------------------------------------------- jambes et baskets
    thigh, calf = cfg["thigh"], cfg["calf"]
    for side in ("Left", "Right"):
        hip, knee, ankle = J[side + "Hip"], J[side + "Knee"], J[side + "Ankle"]
        x = hip.x
        # Basket : semelle blanche arrondie, empeigne en fuseau couchée, col autour de la cheville, languette
        k = 0.82 if fem else 1.0
        W, L, H = (0.32 + calf * 0.7) * k, (0.62 + calf * 1.1) * k, ankle.z + 0.08
        fy = ankle.y - 0.12 - calf * 0.3
        # Semelle : galet aplati (bouts ronds vus de dessus, bord bombé), pas une planche
        sole_h = H * 0.4
        sole_r = W * 0.52
        sole_span = max(L - 2 * 0.8 * sole_r, 0.05)
        body.make(side + "Foot", spindle((x, fy + sole_span / 2, sole_h / 2), (x, fy - sole_span / 2, sole_h / 2),
                                         sole_r * 0.96, sole_r, sole_r * 0.98, sides=16, rings=4,
                                         squash=((0, 0, 1), sole_h / (2 * sole_r))), "white")
        # L'empeigne descend jusqu'au milieu de la semelle : la semelle n'en dépasse qu'en bourrelet
        r_up = W * 0.5
        cz = sole_h * 0.5 + r_up * 0.72
        span = max(L - 0.8 * r_up * 1.9, 0.05)
        body.make(side + "Foot", spindle((x, fy + span / 2, cz + r_up * 0.12), (x, fy - span / 2, cz - r_up * 0.08),
                                         r_up * 0.98, r_up, r_up * 0.9, sides=14, squash=((0, 0, 1), 0.72), rings=4),
                  "shoe")
        heel_y = fy + L * 0.28
        collar_r = calf * 0.62 + 0.065
        body.make(side + "Foot", spindle((x, heel_y, sole_h + 0.02), (x, heel_y - 0.02, ankle.z + 0.06),
                                         collar_r + 0.005, collar_r, collar_r + 0.005, sides=14, rings=2, cap=0.25), "shoe")
        body.make(side + "Foot", rounded_box((x, heel_y - collar_r, H * 0.72), (W * 0.42, 0.06, H * 0.4), bevel=0.9),
                  "white")
        # Mollet (renflé derrière), genou, cuisse : les bouts en dôme se fondent l'un dans l'autre
        body.make(side + "LowerLeg", spindle((x, 0, ankle.z), (x, 0, knee.z), calf * 0.58, calf, calf * 0.78, mid_t=0.62,
                                             bulge_dir=(0, 1, 0), bulge=calf * 0.25), "skin")
        knee_r = max(calf * 0.8, 0.068) if cfg.get("knobby") else calf * 0.8    # genoux noueux du Normie
        body.make(side + "LowerLeg", ball((x, -0.02, knee.z), (knee_r, knee_r * 0.96, knee_r * 0.92), 12, 8), "skin")
        body.make(side + "UpperLeg", spindle((x, 0, knee.z), (x, 0, hip.z), calf * 0.8, thigh, thigh * 0.95,
                                             bulge_dir=(0, -1, 0), bulge=thigh * 0.15, cap=0.3), "skin")
        lx = 1 if x > 0 else -1
        defn = cfg.get("defn", 1.0)
        m = 0.55 + 0.45 * defn
        if defn >= 0.5:
            tl = hip.z - knee.z
            body.make(side + "UpperLeg", ball((x - lx * thigh * 0.42, -thigh * 0.22, knee.z + tl * 0.22),
                                              (thigh * 0.5 * m, thigh * 0.5 * m, tl * 0.2), 12, 10), "skin")
            body.make(side + "UpperLeg", ball((x + lx * thigh * 0.36, -thigh * 0.08, knee.z + tl * 0.52),
                                              (thigh * 0.6 * m, thigh * 0.62 * m, tl * 0.36), 12, 10), "skin")
        if defn >= 0.5:
            ll = knee.z - ankle.z
            for k in (-1, 1):
                body.make(side + "LowerLeg", ball((x + k * calf * 0.3, calf * 0.32, ankle.z + ll * (0.68 if k > 0 else 0.64)),
                                                  (calf * 0.56 * m, calf * 0.58 * m, ll * 0.2), 12, 10), "skin")
        # Jambe de short : tube un peu évasé, ourlet net (la jambe passe dedans)
        sh_r = max(thigh * 1.14, 0.15) if cfg.get("baggy") else thigh * (1.3 if fem else 1.14)
        body.make(side + "UpperLeg", spindle((x, 0, hip.z - (hip.z - knee.z) * 0.45), (x, 0, hip.z + 0.08),
                                             sh_r * 1.06, sh_r, sh_r * 0.95, sides=14, rings=3, cap=0.12), "shorts")

    # ---------------------------------------------------------------- bassin (short)
    root = J["Root"]
    hip_w = g["hip_w"]
    depth = cfg["depth"]
    # Corps féminins : bassin plus haut qui descend dans les cuisses (sinon les hanches larges font un tutu)
    pz, prz = (root.z + 0.06, 0.42 + thigh * 0.12) if fem else (root.z + 0.1, 0.38)
    body.make("LowerTorso", ball((0, 0.02, pz), (hip_w * 0.5, max(depth * 0.45, 0.2), prz)), "shorts")
    if cfg.get("glutes"):
        body.make("LowerTorso", ball((0, max(depth * 0.18, 0.07), root.z), (hip_w * 0.46, max(depth * 0.4, 0.18), 0.36)),
                  "shorts")

    # ---------------------------------------------------------------- torse
    waist, neck = J["Waist"], J["Neck"]
    h = neck.z - waist.z
    chest_w = g["chest_w"]
    trap, neck_r = cfg["trap"], cfg["neck"]
    if cfg.get("spaghetti"):
        # Normie : un seul tronc lofté, fin comme un spaghetti, dans un tee trop grand
        body.make("UpperTorso", loft(spaghetti_sections(g, J), 18), trunk, front_cell="top_front" if clothed else "abs")
        # Épaules en pente : du col vers le haut du bras (le bras pend loin du torse sur ce squelette)
        for side in ("Left", "Right"):
            sh, el = J[side + "Shoulder"], J[side + "Elbow"]
            sx = 1 if sh.x > 0 else -1
            # Part de l'intérieur du torse (pas du cou) : le torse s'évase doucement en épaules qui tombent ; il
            # s'arrête à l'épaule du squelette, le bras prend la suite (les habits couvrent chaque partie à part)
            start_r = cfg["depth"] * 0.36
            body.make("UpperTorso", spindle((sx * g["chest_w"] * 0.3, 0.01, sh.z - 0.02), (sh.x, 0.0, sh.z - 0.05),
                                            start_r, start_r * 0.95, start_r * 0.9, sides=14, rings=3, cap=0.3),
                      trunk)
    else:
        # Torse en V sculpté (D116) : taille fine, dorsaux qui s'évasent, cage large ; pectoraux, abdos et trapèzes
        # posés dessus comme de vrais muscles (fini les boules empilées)
        cw = chest_w / 2
        d = depth
        lat = cfg["lat"]
        hipx = abs(J["LeftHip"].x)
        waist_half = max(hipx + thigh * (0.3 if fem else 0.55), cw * (0.42 if fem else 0.5))
        rib = cw * (0.88 if fem else 1.0)
        S = [
            (waist.z - 0.15, waist_half * 1.03, d * 0.4, d * 0.42),
            (waist.z + h * 0.12, waist_half * 0.97, d * 0.39, d * 0.4),
            (waist.z + h * 0.32, waist_half + (rib - waist_half) * 0.35, d * 0.42, d * 0.43),
            (waist.z + h * 0.52, rib * 0.9 + lat * 0.12, d * 0.45, d * 0.47),
            (waist.z + h * 0.7, rib + lat * 0.06, d * 0.47, d * 0.49),
            # Haut des épaules arrondi en plusieurs tranches (un coude net se verrait et percerait les hauts)
            (neck.z - h * 0.18, rib * 0.96, d * 0.45, d * 0.47),
            (neck.z - h * 0.1, rib * 0.86, d * 0.4, d * 0.45),
            (neck.z - h * 0.04, rib * 0.7, d * 0.33, d * 0.42),
            (neck.z, rib * 0.5, d * 0.26, d * 0.36),
            (neck.z + 0.05, neck_r * 1.5, neck_r * 1.15, neck_r * 1.35),
        ]
        body.make("UpperTorso", loft2(S, 22), "skin")
        # Abdos en relief (6 plaquettes) et pectoraux, quand ils se voient
        defn = cfg.get("defn", 1.0)
        abs_on = top in ("none", "sports") and defn >= 0.5
        if abs_on:
            ab_d = (0.035 + cfg["pec"] * 0.06) * defn
            for row in range(3):
                z = waist.z + h * (0.1 + row * 0.15)
                for sx in (-1, 1):
                    x = sx * (waist_half * 0.17 + 0.01)
                    pw = waist_half * 0.19
                    body.make("UpperTorso", ball((x, front_y(S, x, z) + ab_d * 0.45, z), (pw, ab_d, h * 0.068), 12, 8),
                              "skin")
        pec = cfg["pec"]
        if not fem and not clothed and pec > 0:
            for sx in (-1, 1):
                x = sx * cw * 0.43
                z = neck.z - h * 0.3
                thick = (pec * 0.7 + 0.06) * min(1.0, 0.4 + 0.6 * defn)
                body.make("UpperTorso", pec_slab((x, front_y(S, x, z) + thick * 0.12, z), cw * 0.44, h * 0.17 + pec * 0.07,
                                                 thick, sx), "skin")
        shx = abs(J["LeftShoulder"].x)
        tp = (neck.z + 0.05 + trap * 0.12 + neck_r * 0.7 + trap * 0.1,      # dessus au cou
              J["LeftShoulder"].z + 0.02 + cfg["delt"] * 0.45 * 0.8,         # dessus à l'épaule
              neck_r * 0.7 + trap * 0.1, cfg["delt"] * 0.45, depth, trap)
        # Haut de départ : coque juste au-dessus de la peau (débardeur ou brassière), avec bretelles
        if clothed:
            ease = 0.03
            strap_pad = 0.01
            bust = cfg.get("bust", 0) if fem else 0.0
            z_lo = waist.z - 0.17 if top == "tank" else neck.z - h * 0.52
            # Le bord du haut reste sous le menton (la tête des gros stades s'enfonce dans les trapèzes)
            z_hi = min(neck.z - h * 0.12, g["jaw_z"] - cfg["jaw_h"] * 0.6)
            n = 12 if top == "tank" else 8
            shell = []
            for i in range(n):
                z = z_lo + (z_hi - z_lo) * i / (n - 1)
                rx, ryf, ryb = section_at(S, z)
                shell.append((z, rx + ease, ryf + ease, ryb + ease))
            shell_bm = loft2(shell, 28)
            if fem:
                # Poitrine modeste sculptée dans le tissu même : un galbe doux d'une seule forme, sans raccord
                # (tous publics : jamais deux formes séparées)
                zb, wx, wz = neck.z - h * 0.36, cw * 0.62, h * 0.17
                lift = bust * 0.9 + 0.03
                for v in shell_bm.verts:
                    if v.co.y < 0:
                        v.co.y -= lift * math.exp(-(v.co.x / wx) ** 2 - ((v.co.z - zb) / wz) ** 2)
                shell_bm.normal_update()
            body.make("UpperTorso", shell_bm, "top", front_cell="top_front")
            # Sous le tissu du débardeur : les pectoraux
            for sx in (-1, 1):
                if not fem and pec > 0:
                    x, z = sx * cw * 0.43, neck.z - h * 0.3
                    thick = pec * 0.5 + 0.05
                    body.make("UpperTorso", pec_slab((x, front_y(shell, x, z) + thick * 0.15, z), cw * 0.48,
                                                     h * 0.17 + pec * 0.06, thick, sx), "top", front_cell="top_front")
            for sx in (-1, 1):                        # bretelles qui passent sur l'épaule
                x = sx * cw * (0.36 if top == "tank" else 0.3)
                zf = z_hi - 0.02
                a = Vector((x, front_y(S, x, zf) - ease, zf))
                # Le haut de la bretelle se pose sur le trapèze (au lieu de flotter en anse au-dessus)
                top_z, yc_t = trap_profile(min(1.0, abs(x) / shx), *tp)[:2]
                b = Vector((x * 1.02, yc_t, top_z + strap_pad))
                rx_f, _, ryb_f = section_at(S, zf)
                c = Vector((x, ryb_f * math.sqrt(max(0.0, 1 - (x / rx_f) ** 2)) + ease, zf))
                strap_r = 0.035 + cw * (0.04 if top == "tank" else 0.03)
                body.make("UpperTorso", spindle(tuple(a), tuple(b), strap_r, strap_r, strap_r, sides=10, rings=2, cap=0.5),
                          "top")
                body.make("UpperTorso", spindle(tuple(b), tuple(c), strap_r, strap_r, strap_r, sides=10, rings=2, cap=0.5),
                          "top")
        # Trapèzes (D118) : une seule nappe de la nuque aux épaules, qui grossit énormément mais reste dans le corps
        body.make("UpperTorso", trap_mantle(shx, *tp), "skin")
    # Cou (avec le torse : il ne se décroche pas quand la tête tourne)
    body.make("UpperTorso", spindle((0, 0.03, neck.z - 0.3), (0, -0.02, neck.z + 0.3), neck_r * 1.1, neck_r, neck_r * 0.92),
              "skin")

    # ---------------------------------------------------------------- bras et mains
    delt, bicep, forearm, fist = cfg["delt"], cfg["bicep"], cfg["forearm"], cfg["fist"]
    tee = top == "tee"
    for side in ("Left", "Right"):
        sh, el, wr = J[side + "Shoulder"], J[side + "Elbow"], J[side + "Wrist"]
        sx = 1 if sh.x > 0 else -1
        arm_top = Vector((el.x, el.y, sh.z - 0.05))
        if tee:
            # Manche de tee trop large : le bras spaghetti flotte dedans ; le haut de la manche rejoint l'épaule
            sleeve_r = max(bicep * 1.25, bicep + 0.05)
            body.make(side + "UpperArm", spindle(tuple(arm_top.lerp(el, 0.45)), tuple(arm_top + Vector((0, 0, 0.02))),
                                                 sleeve_r * 1.08, sleeve_r, sleeve_r * 0.95, sides=14, rings=3, cap=0.6),
                      "top")
            start_r = cfg["depth"] * 0.36 * 0.9
            body.make(side + "UpperArm", spindle((sh.x, 0.0, sh.z - 0.05), tuple(arm_top + Vector((0, 0, -0.04))),
                                                 start_r, (start_r + sleeve_r) / 2, sleeve_r * 0.97, sides=14, rings=3,
                                                 cap=0.4), "top")
        else:
            # Deltoïde : fait le pont entre le torse et le bras, quelle que soit la largeur du squelette
            delt_r = max(delt, abs(el.x - sh.x) * cfg.get("delt_bridge", 0.75))
            arm_len = sh.z - el.z
            top_p = Vector((sh.x * 0.45 + el.x * 0.55, 0, sh.z - delt * 0.1))
            tip = Vector((el.x + sx * delt * 0.12, -0.01, sh.z - arm_len * 0.58))
            body.make(side + "UpperArm", spindle(tuple(tip), tuple(top_p), delt_r * 0.42, delt_r * 0.98, delt_r * 0.9,
                                                 sides=16, rings=6, mid_t=0.62, cap=0.75), "skin")
        body.make(side + "UpperArm", spindle(tuple(arm_top), tuple(el), delt * 0.62, bicep, forearm * 0.95,
                                             bulge_dir=(0, -1, 0), bulge=bicep * 0.25), veiny)
        body.make(side + "LowerArm", spindle(tuple(el), tuple(wr), forearm * 0.88, forearm, forearm * 0.62, mid_t=0.3),
                  veiny)
        defn = cfg.get("defn", 1.0)
        m = 0.55 + 0.45 * defn
        if defn >= 0.5:
            arm_len = arm_top.z - el.z
            body.make(side + "UpperArm", ball(tuple(arm_top.lerp(el, 0.56) + Vector((0, -bicep * 0.42, 0))),
                                              (bicep * 0.8 * m, bicep * 0.72 * m, arm_len * 0.3), 14, 10), veiny)
            body.make(side + "UpperArm", ball(tuple(arm_top.lerp(el, 0.38) + Vector((sx * bicep * 0.12, bicep * 0.4, 0))),
                                              (bicep * 0.82 * m, bicep * 0.68 * m, arm_len * 0.36), 14, 10), veiny)
        if defn >= 0.5:
            fa_len = el.z - wr.z
            body.make(side + "LowerArm", ball(tuple(el.lerp(wr, 0.24) + Vector((sx * forearm * 0.28, -forearm * 0.18, 0))),
                                              (forearm * 0.74 * m, forearm * 0.74 * m, fa_len * 0.26), 12, 10), veiny)
        if cfg.get("knobby"):                         # coudes noueux
            body.make(side + "LowerArm", ball(tuple(el + Vector((0, 0.01, 0))), (forearm * 1.18, forearm * 1.15, forearm * 1.1),
                                              12, 8), "skin")
        # Main en moufle, paume tournée vers la cuisse : paume, doigts repliés, pouce devant
        down, front, inward = Vector((0, 0, -1)), Vector((0, -1, 0)), Vector((-sx, 0, 0))
        palm = wr + down * fist * 0.75
        body.make(side + "Hand", ball(tuple(palm), (fist * 0.3, fist * 0.5, fist * 0.62), 12, 8), "skin")
        body.make(side + "Hand", ball(tuple(wr + down * fist * 1.35 + inward * fist * 0.06),
                                      (fist * 0.3, fist * 0.47, fist * 0.38), 12, 8), "skin")
        body.make(side + "Hand", spindle(tuple(wr + down * fist * 0.45 + front * fist * 0.3 + inward * fist * 0.05),
                                         tuple(wr + down * fist * 1.05 + front * fist * 0.52 + inward * fist * 0.12),
                                         fist * 0.15, fist * 0.14, fist * 0.12, sides=10, rings=3), "skin")

    # ---------------------------------------------------------------- tête
    hc = PC["Head"]
    head_r = cfg["head_r"]
    hy = hc.y - 0.05 - trap * 0.1
    head_z = hc.z + 0.05
    cran_bm = ball((0, hy, head_z), (head_r * 0.82, head_r * 0.95, head_r), 18, 14)
    cran_tree = BVHTree.FromBMesh(cran_bm)
    body.make("Head", cran_bm, "skin", front_cell="face")
    jaw_w, jaw_h = cfg["jaw_w"], cfg["jaw_h"]
    jaw_depth, jaw_y, jaw_z = g["jaw_depth"], g["jaw_y"], g["jaw_z"]
    jaw_front, jaw_top = g["jaw_front"], g["jaw_top"]
    # Progression du visage (D117) : 0 au Normie, 1 au GOD MOGGER
    grade = ORDER.index(BASE[name]) / (len(ORDER) - 1)
    if fem:                                           # mâchoire ronde et fine qui s'affirme un peu au fil des stades
        jaw_bm = jaw_shape((0, jaw_y, jaw_z), jaw_w * 1.12, jaw_h * 1.24, jaw_depth, 0.05 + 0.2 * grade,
                           -0.05 + 0.15 * grade, 0.45)
    else:                                             # menton fuyant et rond -> enclume carrée qui avance
        jaw_bm = jaw_shape((0, jaw_y, jaw_z), jaw_w, jaw_h, jaw_depth, 0.1 + 0.85 * grade, -0.15 + 0.5 * grade,
                           0.45 - 0.35 * grade)
    face_tree = (BVHTree.FromBMesh(jaw_bm), cran_tree)    # surface du visage = mâchoire + crâne
    body.make("Head", jaw_bm, "skin", front_cell="face")
    if not fem and grade >= 0.5:                      # gros stades : arcade sourcilière de brute
        body.make("Head", ball((0, hy - head_r * 0.8, head_z + head_r * 0.27),
                               (head_r * 0.66, head_r * 0.12 * grade, head_r * 0.09), 16, 8), "skin")
    ridge = head_r * 0.12 * grade if (not fem and grade >= 0.5) else 0.0
    # Nez arrondi : arête et bout
    nose_y = min(hy - head_r * 0.88, jaw_front)
    nose_s = head_r * (0.8 if fem else 1.0)
    body.make("Head", spindle((0, nose_y + 0.03, head_z - head_r * 0.02), (0, nose_y - nose_s * 0.2, head_z - head_r * 0.18),
                              nose_s * 0.06, nose_s * 0.08, nose_s * 0.1, sides=10, rings=3), "skin")
    body.make("Head", ball((0, nose_y - nose_s * 0.2, head_z - head_r * 0.2), (nose_s * 0.13, nose_s * 0.11, nose_s * 0.1),
                           10, 8), "skin")
    for sx in (-1, 1):                                # oreilles ovales, un peu décollées
        body.make("Head", ball((head_r * 0.8 * sx, hy + 0.04, head_z - head_r * 0.02), (0.07, head_r * 0.2, head_r * 0.27),
                               10, 8), "skin")

    # Bouche : deux lèvres en courbe posées sur la mâchoire, les dents entre elles ; une par expression. Elle évolue :
    # petite bouche molle et dents de lapin au Normie, grand sourire carré (et une dent en or) au GOD MOGGER.
    brow_t = 0.042 if fem else 0.055 + 0.05 * grade   # sourcils de plus en plus épais (fins et arqués au féminin)
    brow_y = hy - head_r * 0.86 - ridge * 0.6
    brow_z = head_z + head_r * 0.3
    lip_r = max(0.03, jaw_h * (0.11 if fem else 0.065 + 0.02 * grade))
    mz = jaw_z + jaw_h * (0.14 if fem else 0.08)     # bouche féminine un peu plus haute (mâchoire ronde)
    mh = jaw_h * 0.16

    def stroke(a, b, t0, t1):                         # trait de sourcil : bâtonnet aplati aux bouts ronds
        return spindle(tuple(a), tuple(b), t0, (t0 + t1) / 2, t1, sides=8, rings=2, cap=0.7,
                       squash=((0, 1, 0), 0.6))

    def mouth(group, width, curve, gap, teeth=True, gold=False):
        half = jaw_w * (0.58 if fem else 0.5 + 0.08 * grade) * width / 2
        mid = face_curve(face_tree, -half, half, lambda u: mz + curve(u) * mh, jaw_front, 13)
        n = len(mid)
        us = [-1 + 2 * i / (n - 1) for i in range(n)]
        r = [lip_r * (0.35 + 0.65 * math.sqrt(max(0.0, 1 - u * u))) for u in us]
        upper = [(x, y + r[i] * 0.3, z + gap(us[i]) / 2 + r[i] * 0.55) for i, (x, y, z) in enumerate(mid)]
        lower = [(x, y + r[i] * 0.25, z - gap(us[i]) / 2 - r[i] * 0.6) for i, (x, y, z) in enumerate(mid)]
        body.make("Head", sweep(upper, [q * 0.95 for q in r], 10, 0.7), "lips", group=group)
        body.make("Head", sweep(lower, [q * 1.12 for q in r], 10, 0.75), "lips", group=group)
        if teeth:
            tr = [max(0.012, gap(u) * 0.5 + lip_r * 0.25) * (0.5 + 0.5 * math.sqrt(max(0.0, 1 - u * u))) for u in us]
            row = [(x, y + tr[i] * 0.55, z) for i, (x, y, z) in enumerate(mid)]
            body.make("Head", sweep(row[1:-1], tr[1:-1], 10, 0.8), "teeth", group=group)
            if gold:
                x, y, z = row[n * 2 // 3]
                body.make("Head", ball((x, y - tr[n * 2 // 3] * 0.5, z), (half * 0.09, 0.02, tr[n * 2 // 3] * 0.8), 8, 6),
                          "gold", group=group)
        if not fem and grade == 0:                    # Normie : deux dents de lapin sous la lèvre du haut
            x, y, z = mid[n // 2]
            for sx in (-1, 1):
                body.make("Head", rounded_box((sx * lip_r * 0.75, y - 0.005, z - lip_r * 0.6),
                                              (lip_r * 1.35, lip_r * 0.9, lip_r * 2.2), bevel=0.6), "teeth", group=group)

    for expr in EXPRESSIONS:
        brow = "Brow" + expr
        if expr == "Nervous":                         # petite bouche molle et ondulée, coins vers le bas
            mouth("Mouth" + expr, 0.62, lambda u: -0.35 * u * u + 0.07 * math.sin(2 * math.pi * u), lambda u: lip_r * 0.25,
                  teeth=False)
            for sx in (-1, 1):
                inner = Vector((sx * head_r * 0.12, brow_y, brow_z + head_r * 0.1))
                outer = Vector((sx * head_r * 0.62, brow_y + 0.02, brow_z - head_r * 0.06))
                body.make("Head", stroke(inner, outer, brow_t, brow_t * 0.8), "brow", group=brow)
        elif expr == "Confident":                     # sourire en coin : un côté remonte et montre les dents
            mouth("Mouth" + expr, 0.85, lambda u: 0.12 * u * u + 0.6 * max(0.0, u) ** 2,
                  lambda u: lip_r * (0.2 + 1.3 * max(0.0, u) ** 1.5))
            for sx in (-1, 1):
                lift = head_r * (0.12 if sx > 0 else 0.0)
                if fem:                               # arc : monte du nez vers le milieu, redescend vers la tempe
                    inner = Vector((sx * head_r * 0.12, brow_y, brow_z + lift - head_r * 0.02))
                    top_p = Vector((sx * head_r * 0.4, brow_y - 0.01, brow_z + lift + head_r * 0.08))
                    outer = Vector((sx * head_r * 0.66, brow_y + 0.03, brow_z + lift - head_r * 0.02))
                    body.make("Head", stroke(inner, top_p, brow_t, brow_t), "brow", group=brow)
                    body.make("Head", stroke(top_p, outer, brow_t, brow_t * 0.6), "brow", group=brow)
                else:
                    a = Vector((head_r * 0.1 * sx, brow_y, brow_z + lift))
                    b = Vector((head_r * 0.62 * sx, brow_y + 0.02, brow_z + lift))
                    body.make("Head", stroke(a, b, brow_t, brow_t * 0.8), "brow", group=brow)
        else:                                         # Determined : grand sourire serré, toutes les dents
            mouth("Mouth" + expr, 1.0, lambda u: 0.5 * u * u, lambda u: lip_r * (1.5 + 0.8 * grade) * (1 - 0.6 * u * u),
                  gold=(grade == 1 and not fem))
            for sx in (-1, 1):
                inner = Vector((sx * head_r * 0.1, brow_y, brow_z - head_r * 0.06))
                outer = Vector((sx * head_r * 0.62, brow_y + 0.02, brow_z + head_r * 0.1))
                body.make("Head", stroke(inner, outer, brow_t * 1.07, brow_t * 0.86), "brow", group=brow)

    # Yeux : blanc et paupière avec la peau, iris (couleur choisie) et pupille à part
    r = cfg["eye_r"]
    for sx in (-1, 1):
        ey = Vector((head_r * 0.36 * sx, min(hy - head_r * 0.78, jaw_front + r * 0.8),
                     max(head_z + head_r * 0.12, jaw_top + r * 0.7)))
        body.make("Head", ball(tuple(ey), (r, r * 0.85, r), 14, 10), "white")
        body.make("Head", ball((ey.x, ey.y - r * 0.78, ey.z - r * 0.05), (r * 0.5, r * 0.14, r * 0.5), 12, 6), "iris")
        body.make("Head", ball((ey.x, ey.y - r * 0.88, ey.z - r * 0.05), (r * 0.22, r * 0.08, r * 0.22), 10, 6), "black",
                  group="Eyes")
        body.make("Head", half_sphere((ey.x, ey.y, ey.z + r * 0.18), (r * 1.06, r * 0.95, r * 0.95), 14, 8), "skin")
        if fem:
            # Cils : un trait noir sur le bord de la paupière et quatre longs cils recourbés vers l'extérieur
            body.make("Head", rounded_box((ey.x, ey.y - r * 0.62, ey.z + r * 0.62), (r * 2.1, r * 0.22, r * 0.2), bevel=0.8),
                      "lash")
            for k in range(4):
                along = -0.5 + k * 0.45
                base = Vector((ey.x + sx * r * along, ey.y - r * 0.68, ey.z + r * 0.68))
                tip = base + Vector((sx * r * (0.25 + k * 0.14), -r * 0.22, r * (0.42 + k * 0.05)))
                body.make("Head", pyramid(tuple(base), tuple(tip), r * 0.09, r * 0.06), "lash")

    # Coupe de base (pièce à part : le coiffeur et le menu de création la remplacent)
    if fem:                                           # queue de cheval haute, sportive (lisible de loin)
        body.make("Head", half_sphere((0, hy + 0.03, head_z + head_r * 0.12), (head_r * 0.9, head_r * 1.03, head_r * 0.95),
                                      18, 10), "hair")
        body.make("Head", ball((0, hy - head_r * 0.48, head_z + head_r * 0.7), (head_r * 0.66, head_r * 0.42, head_r * 0.28),
                               14, 8), "hair")
        # Frange balayée sur le côté : le visage se lit tout de suite comme féminin
        body.make("Head", ball((head_r * 0.18, hy - head_r * 0.62, head_z + head_r * 0.62),
                               (head_r * 0.62, head_r * 0.3, head_r * 0.3), 14, 8), "hair")
        knot = Vector((0, hy + head_r * 0.62, head_z + head_r * 0.92))
        body.make("Head", ball(tuple(knot), (head_r * 0.27, head_r * 0.27, head_r * 0.27), 12, 8), "hair")
        tail = [knot + Vector((0, head_r * 0.2, head_r * 0.12)),
                knot + Vector((0, head_r * 0.8, -head_r * 0.35)),
                knot + Vector((0, head_r * 0.9, -head_r * 1.15)),
                knot + Vector((0, head_r * 0.75, -head_r * 1.6))]
        for k, (a, b) in enumerate(zip(tail[:-1], tail[1:])):
            body.make("Head", spindle(tuple(a), tuple(b), head_r * (0.26 - k * 0.05), head_r * (0.33 - k * 0.07),
                                      head_r * (0.22 - k * 0.06), rings=4), "hair")
        # Chouchou (couleur fixe, rose vif) autour de l'attache
        body.make("Head", ring(tuple(knot + Vector((0, head_r * 0.12, head_r * 0.04))), head_r * 0.25, head_r * 0.08,
                               head_r * 0.14, 14), "accent")
    else:
        body.make("Head", half_sphere((0, hy + 0.03, head_z + head_r * 0.15), (head_r * 0.88, head_r * 1.02, head_r * 0.92),
                                      18, 10), "hair")
        body.make("Head", ball((0, hy - head_r * 0.45, head_z + head_r * 0.78),
                               (head_r * 0.62, head_r * 0.5, head_r * 0.28), 14, 8), "hair")
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
        # Lissé (D115) : les formes arrondies se lisent comme des volumes propres, plus comme des facettes
        for p in me.polygons:
            p.use_smooth = True
        me.set_sharp_from_angle(angle=math.radians(SMOOTH_ANGLE))
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
    sk = skeleton(name)["parts"]
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


# Exécuté avec BODIES_LIBRARY = True (ex. par build_style.py) : on ne fait que charger les définitions
if not globals().get("BODIES_LIBRARY"):
    ONLY = globals().get("ONLY") or BODY_KEYS
    manifest = {}
    for i, name in enumerate(BODY_KEYS):
        if name in ONLY:
            body = build_body(name)
            pieces = merge(body)
            # Aperçu côte à côte dans Blender (la position d'objet est ignorée à l'export)
            for obj in pieces.values():
                obj.location.x = (i // 2) * 7
                obj.location.y = (i % 2) * 7
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
    objs = [o for name in BODY_KEYS for o in bpy.data.collections["Body_" + name].objects if o.type == "MESH"]
    # Les objets masqués (aperçus) ne seraient pas exportés : tout est réaffiché avant l'export
    for lc in bpy.context.view_layer.layer_collection.children:
        lc.hide_viewport = False
        lc.exclude = False
    saved = {o: o.location.copy() for o in objs}
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    for o in objs:
        o.location = (0, 0, 0)
        o.hide_set(False)
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
    for name in BODY_KEYS:
        lines.append(f"\t{name} = {{")
        for part in sorted(manifest[name]):
            x, y, z = manifest[name][part]
            lines.append(f"\t\t{part} = Vector3.new({x:g}, {y:g}, {z:g}),")
        lines.append("\t},")
    lines.append("}")
    pending = os.path.join(ROOT, "assets", "export", "characters", "BodyPieces.pending.luau")
    os.makedirs(os.path.dirname(pending), exist_ok=True)
    with open(pending, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    print(f"BodyPieces en attente écrit dans {pending}")

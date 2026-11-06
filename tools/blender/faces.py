"""Barbes et visages du coiffeur posés sur la vraie mâchoire (D119).

Exécuté par build_style.py après clothes.py : remplace build_beards et build_faces. Les anciennes versions étaient
des blocs dans la boîte de la mâchoire ; depuis la mâchoire sculptée de D117 (ronde, puis en enclume), elles
flottaient devant le visage. Ici tout part de face_params (build_bodies.py), la même mesure que le corps :
- la barbe est une coque de la mâchoire gonflée, coupée sous la bouche et remontant jusqu'aux oreilles ;
- moustaches, bouc, collier et sourire suivent la surface du visage par lancer de rayons.
Mêmes cases (donc mêmes pièces) qu'avant : les objets déjà achetés et la croissance entre stades marchent toujours.
"""
import math

import bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree


def face_frame(g):
    """Mâchoire et crâne du corps (mêmes formes que build_bodies), et leurs arbres de lancer de rayons."""
    fp = face_params(g["stage"], g)
    jaw_bm = jaw_shape(*fp["jaw"])
    r = g["head_r"]
    cran_bm = ball((0, g["hy"], g["head_z"]), (r * 0.82, r * 0.95, r), 18, 14)
    cheek_bm = cheek_bridge(g, fp["jaw"])             # joues de D120 : la barbe et les sourires s'y posent aussi
    trees = (BVHTree.FromBMesh(jaw_bm), BVHTree.FromBMesh(cran_bm), BVHTree.FromBMesh(cheek_bm))
    jaw_bm.free()
    cran_bm.free()
    cheek_bm.free()
    return fp, trees


def on_face(trees, origin, direction, lift=0.0):
    """Point le plus proche touché par un rayon (origin -> direction) sur les volumes, relevé de lift le long de la
    normale ; None si rien n'est touché."""
    best = None
    for tree in trees:
        hit, normal, _, dist = tree.ray_cast(Vector(origin), Vector(direction).normalized(), 40)
        if hit is not None and (best is None or dist < best[2]):
            best = (hit, normal, dist)
    if best is None:
        return None
    return best[0] + best[1] * lift


def front_line(trees, xs, z_of, lift):
    """Points sur l'avant du visage pour chaque x de xs, à la hauteur z_of(i)."""
    pts = []
    for i, x in enumerate(xs):
        p = on_face(trees, (x, -20, z_of(i)), (0, 1, 0), lift)
        if p is not None:
            pts.append(tuple(p))
    return pts


def wrap_jaw(trees, center, w, h, thetas, lift, rise=0.5):
    """Contour du bas de la mâchoire, d'une oreille à l'autre en passant sous le menton : thetas en degrés,
    0 = sous le menton, ±90 = sur les côtés (rise : remonte vers la tempe)."""
    cx, cy, cz = center
    pts = []
    for t in thetas:
        a = math.radians(t)
        d = Vector((math.sin(a) * w, -0.55 * h, -math.cos(a) * h + rise * h * (abs(t) / 90) ** 2))
        p = on_face(trees, Vector((cx, cy, cz)) + d.normalized() * 12, -d, lift)
        if p is not None:
            pts.append(tuple(p))
    return pts


def mustache_pts(trees, fp, width, lift, droop=0.15, curl=0.0):
    """Ligne de moustache au-dessus de la lèvre du haut ; curl > 0 : pointes relevées en guidon."""
    half = fp["mouth_half"] * width
    z0 = fp["mz"] + fp["mh"] * 0.5 + fp["lip_r"] * 1.7
    n = 11
    xs = [-half + 2 * half * i / (n - 1) for i in range(n)]
    pts = front_line(trees, xs, lambda i: z0 - droop * fp["mh"] * 4 * ((i / (n - 1)) * 2 - 1) ** 2, lift)
    if curl > 0 and len(pts) >= 2:
        jh = fp["jaw"][2]
        for end, sx in ((pts[-1], 1), (pts[0], -1)):
            e = Vector(end)
            tips = [e + Vector((sx * jh * 0.18, 0.02, jh * 0.08 * curl)), e + Vector((sx * jh * 0.26, 0.04, jh * 0.32 * curl))]
            if sx > 0:
                pts = pts + [tuple(t) for t in tips]
            else:
                pts = [tuple(t) for t in reversed(tips)] + pts
    return pts


def taper(n, r0, r_mid, r_end=None):
    """Rayons le long d'une courbe : r0 aux bouts, r_mid au milieu."""
    r_end = r0 if r_end is None else r_end
    out = []
    for i in range(n):
        u = i / (n - 1) * 2 - 1
        edge = r0 if u < 0 else r_end
        out.append(edge + (r_mid - edge) * (1 - u * u))
    return out


def beard_shell(fp, grow, cut_front, cut_back):
    """Coque de barbe : la mâchoire gonflée de grow, coupée par un plan qui passe sous la bouche à l'avant et
    remonte vers les oreilles à l'arrière."""
    center, w, h, d, square, chin, tap = fp["jaw"]
    cx, cy, cz = center
    bm = jaw_shape((cx, cy + d * 0.02, cz - h * 0.06), w * (1 + grow), h * (1 + grow * 1.6), d * (1 + grow * 1.2),
                   square, chin + 0.08, tap * 0.85)
    y_front = cy - d / 2
    k = (cut_back - cut_front) / (d * 0.9)
    bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, y_front, cut_front),
                           plane_no=Vector((0, -k, 1)).normalized(), clear_outer=True)
    filled = bmesh.ops.holes_fill(bm, edges=[e for e in bm.edges if e.is_boundary], sides=0)  # volume fermé
    bmesh.ops.triangulate(bm, faces=filled["faces"])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


# ------------------------------------------------------------------ col des hauts (D120)
def clear_chin(w, g):
    """Les hauts montent avec les trapèzes, qui dépassent le menton chez les gros stades (D118) : le tissu passait
    devant le visage, entre le crâne et la mâchoire (visage coupé en deux). Tout ce qui est porté sur le torse
    descend devant, sous le menton. Le dos et les côtés restent hauts sur les trapèzes. C'est une déformation
    continue de l'espace : les boutons, cols et motifs posés sur le tissu suivent."""
    fp = face_params(g["stage"], g)
    jaw_bm = jaw_shape(*fp["jaw"])
    cap = min(v.co.z for v in jaw_bm.verts) - 0.03     # sous le menton
    jaw_bm.free()
    center, jw = fp["jaw"][:2]
    half = max(jw / 2, g["head_r"] * 0.82) + 0.12     # largeur du visage (mâchoire ou crâne) et un peu d'air
    for parts in w.items.values():
        for part, objs in parts.items():
            if not part.startswith("UpperTorso"):
                continue
            for obj in objs:
                for v in obj.data.vertices:
                    x, y, z = v.co
                    r = math.hypot(x, y)
                    if z <= cap or y >= 0:
                        continue
                    # encolure ronde : 1 devant le visage, 0 au-delà de sa largeur (le tissu reste sur les trapèzes)
                    # et vers l'arrière (la nuque reste couverte)
                    tx = max(0.0, min(1.0, (half - abs(x)) / (half * 0.45)))
                    ty = max(0.0, min(1.0, y / (center[1] * 0.6)))
                    k = tx * tx * (3 - 2 * tx) * ty * ty * (3 - 2 * ty)
                    v.co.z = cap + (z - cap) * (1 - 0.92 * k)


# ------------------------------------------------------------------ barbes
def build_beards(w, g):
    fp, trees = face_frame(g)
    center, jw, jh, jd = fp["jaw"][:4]
    lip_r, mz, mh = fp["lip_r"], fp["mz"], fp["mh"]
    under_lip = mz - mh * 0.5 - lip_r * 2.0
    jaw_top = center[2] + jh * 0.5

    w.start("LumberBeard")       # grosse barbe de bûcheron : coque jusqu'aux oreilles, touffe sous le menton, moustache
    w.make("Head", beard_shell(fp, 0.12, under_lip, jaw_top + jh * 0.15), "beard_brown")
    chin = on_face(trees, (0, -20, center[2] - jh * 0.3), (0, 1, 0), 0.0)
    cy = chin.y if chin else center[1] - jd / 2
    w.make("Head", ball((0, cy + jd * 0.12, center[2] - jh * 0.62), (jw * 0.4, jd * 0.32, jh * 0.4), 14, 10), "beard_brown")
    pts = mustache_pts(trees, fp, 1.15, lip_r * 0.4, droop=0.3)
    w.make("Head", sweep(pts, taper(len(pts), lip_r * 0.8, lip_r * 1.6), 10, 0.75), "beard_brown")

    w.start("Goatee")            # bouc pointu sous la lèvre + fine moustache
    n = 7
    zs = [under_lip - (jh * 0.75) * i / (n - 1) for i in range(n)]
    col = front_line(trees, [0.0] * n, lambda i: zs[i], lip_r * 0.3)
    if col:
        tip = Vector(col[-1]) + Vector((0, -jh * 0.12, -jh * 0.35))
        col = col + [tuple(tip)]
        radii = [jw * 0.1 * (1 - 0.85 * (i / (len(col) - 1)) ** 1.5) for i in range(len(col))]
        w.make("Head", sweep(col, radii, 10, 1.0), "beard_black")
    pts = mustache_pts(trees, fp, 0.95, lip_r * 0.3)
    w.make("Head", sweep(pts, taper(len(pts), lip_r * 0.35, lip_r * 0.8), 10, 0.7), "beard_black")

    w.start("Handlebar")         # moustache en guidon, pointes relevées
    pts = mustache_pts(trees, fp, 1.1, lip_r * 0.4, droop=0.1, curl=1.0)
    w.make("Head", sweep(pts, taper(len(pts), lip_r * 0.25, lip_r * 1.5), 10, 0.75), "beard_ginger")

    w.start("ChinStrap")         # collier fin qui suit le bas de la mâchoire, d'une oreille à l'autre
    thetas = [-95 + 190 * i / 16 for i in range(17)]
    pts = wrap_jaw(trees, center, jw * 0.5, jh * 0.5, thetas, 0.015, rise=0.9)
    if len(pts) >= 2:
        w.make("Head", sweep(pts, [0.035 + jw * 0.02] * len(pts), 10, 0.8), "beard_black")
    pts = mustache_pts(trees, fp, 0.8, lip_r * 0.2)
    w.make("Head", sweep(pts, taper(len(pts), lip_r * 0.3, lip_r * 0.6), 10, 0.7), "beard_black")


# ------------------------------------------------------------------ visages
def grin(w, trees, fp, width, curve, tooth_r, lips=True, gold=False, lift=0.01):
    """Sourire posé sur le visage : rangée de dents, lèvres autour, une dent en or."""
    half = fp["mouth_half"] * width
    n = 13
    xs = [-half + 2 * half * i / (n - 1) for i in range(n)]
    us = [x / half for x in xs]
    row = front_line(trees, xs, lambda i: fp["mz"] + curve * fp["mh"] * us[i] ** 2, lift + tooth_r * 0.3)
    if len(row) < 3:
        return
    radii = [tooth_r * (0.45 + 0.55 * math.sqrt(max(0.0, 1 - u * u))) for u in us[: len(row)]]
    w.make("Head", sweep(row[1:-1], radii[1:-1], 10, 1.0), "teeth_white")
    if lips:
        lr = fp["lip_r"]
        up = [(x, y + lr * 0.2, z + radii[i] + lr * 0.5) for i, (x, y, z) in enumerate(row)]
        lo = [(x, y + lr * 0.2, z - radii[i] - lr * 0.55) for i, (x, y, z) in enumerate(row)]
        w.make("Head", sweep(up, taper(len(up), lr * 0.4, lr), 10, 0.7), "lips")
        w.make("Head", sweep(lo, taper(len(lo), lr * 0.45, lr * 1.12), 10, 0.75), "lips")
    if gold:
        x, y, z = row[n * 2 // 3]
        w.make("Head", ball((x, y - tooth_r * 0.55, z), (half * 0.1, 0.03, tooth_r * 0.85), 8, 6), "gold")


def build_faces(w, g):
    cfg = g["cfg"]
    r, hy, z = g["head_r"], g["hy"], g["head_z"]
    fp, trees = face_frame(g)
    center, jw, jh, jd = fp["jaw"][:4]
    grade = fp["grade"]
    fem = cfg.get("fem")
    ridge = r * 0.12 * grade if (not fem and grade >= 0.5) else 0.0
    brow_y = hy - r * 0.86 - ridge * 0.6 - 0.06       # devant les sourcils du corps
    brow_z = z + r * 0.3

    w.start("FrownBrows")        # sourcils froncés : deux gros traits en V, arrondis
    t = 0.07 + r * 0.06
    for sx in (-1, 1):
        inner = (sx * r * 0.08, brow_y, brow_z - r * 0.1)
        outer = (sx * r * 0.64, brow_y + 0.03, brow_z + r * 0.13)
        w.make("Head", spindle(inner, outer, t * 1.1, t, t * 0.75, sides=10, rings=3, cap=0.7,
                               squash=((0, 1, 0), 0.6)), "brow_dark")

    w.start("SparkleSmile")      # sourire éclatant : une rangée de dents immense et une dent en or
    grin(w, trees, fp, 1.35, 0.9, jh * 0.09, lips=False, gold=True, lift=0.02)

    w.start("MegaJaw")           # mâchoire encore plus carrée : une enclume qui déborde, avec sa propre bouche
    cx, cy, cz = center
    mega = jaw_shape((cx, cy - jd * 0.08, cz - jh * 0.12), jw * 1.3, jh * 1.12, jd * 1.15, 1.0, 0.45, 0.05)
    mega_tree = (BVHTree.FromBMesh(mega), trees[1])
    w.make("Head", mega, "skin")
    grin(w, mega_tree, fp, 1.1, 0.4, jh * 0.06, lips=True)

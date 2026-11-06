"""
Accessoires de MOG LIFE, refaits au complet (D114) : chargé par build_style.py (exec), qui fournit le Wardrobe,
les formes low poly (prism, ring, lowsphere, block, pyramid...), geometry() et les couleurs de lit/noise.

Principes :
- Gros, lisibles de loin et sur un téléphone : une silhouette forte et 2 à 3 couleurs franches par objet.
- Posés sur la VRAIE surface du corps : chaînes, rubans et bretelles sont projetés sur le torse du corps de stade
  (BVHTree sur ses pièces), puis décollés de l'épaisseur du haut le plus épais. Ils épousent un Normie comme un
  God Mogger, au lieu de flotter ou de traverser la poitrine.
- Mêmes objets, mêmes parties du squelette qu'avant (les achats et l'installation dans Studio ne changent pas).
- Rien d'écrit, aucun logo existant.
"""
import math
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree


# ------------------------------------------------------------------ couleurs (colonnes 8 à 15 de l'atlas, libres)
def paint_accessory_cells(a):
    def plain(rgb, amt=0.02, light=0.22):
        return lambda x, y: lit(noise(rgb, amt), y, light)

    def terry(rgb):                                   # éponge : petites bouclettes
        return lambda x, y: lit(noise(rgb if (x + y) % 3 else tuple(c * 0.86 for c in rgb), 0.015), y, 0.12)

    a.cell("acc_red", 8, 0, terry((0.88, 0.12, 0.14)))
    a.cell("acc_white", 9, 0, terry((0.97, 0.97, 0.95)))
    a.cell("acc_blue", 10, 0, terry((0.12, 0.35, 0.85)))
    a.cell("acc_black", 11, 0, plain((0.07, 0.07, 0.08), 0.01, 0.3))
    # Verre fumé : reflet en diagonale
    a.cell("acc_lens", 12, 0, lambda x, y: (0.6, 0.72, 0.9) if 10 < x + y < 15 or 19 < x + y < 21
           else lit((0.05, 0.06, 0.1), y, 0.35))
    a.cell("acc_chrome", 13, 0, lambda x, y: lit(noise((0.82, 0.84, 0.88) if (x // 4 + y // 8) % 2 else (0.95, 0.96, 0.98),
                                                       0.02), y, 0.4))
    a.cell("acc_gold", 14, 0, lambda x, y: (1.0, 0.93, 0.55) if (x + 2 * y) % 13 == 0
           else lit(noise((0.98, 0.72, 0.14), 0.03), y, 0.35))
    a.cell("acc_gold_dark", 15, 0, plain((0.72, 0.45, 0.06), 0.03, 0.3))

    a.cell("acc_bronze", 8, 1, lambda x, y: (0.98, 0.72, 0.48) if (x + 2 * y) % 11 == 0
           else lit(noise((0.78, 0.45, 0.2), 0.03), y, 0.35))
    a.cell("acc_bronze_dark", 9, 1, plain((0.5, 0.27, 0.1), 0.02, 0.25))
    # Ruban de médaille : bleu, bande rouge au milieu
    a.cell("acc_ribbon", 10, 1, lambda x, y: lit((0.85, 0.12, 0.16) if 12 <= x <= 19 else (0.1, 0.25, 0.75), y, 0.12))
    a.cell("acc_cord", 11, 1, lambda x, y: lit((0.95, 0.25, 0.15) if (x + y) % 4 < 2 else (0.75, 0.12, 0.08), y, 0.1))
    a.cell("acc_clear", 12, 1, lambda x, y: (0.95, 0.98, 1.0) if x in (5, 6) else lit((0.72, 0.86, 0.95), y, 0.25))
    a.cell("acc_pink", 13, 1, lambda x, y: (1.0, 0.82, 0.92) if x in (5, 6) else lit(noise((0.96, 0.5, 0.72), 0.02), y, 0.2))
    a.cell("acc_strap", 14, 1, lambda x, y: lit((0.28, 0.28, 0.32) if y % 8 else (0.4, 0.4, 0.45), y, 0.15))
    a.cell("acc_purple", 15, 1, lambda x, y: lit(noise((0.5, 0.18, 0.75), 0.02), y, 0.35))
    a.cell("acc_gem", 8, 2, lambda x, y: (1.0, 0.7, 0.75) if x + y < 14 else lit((0.85, 0.08, 0.2), y, 0.4))
    a.cell("acc_sock", 9, 2, lambda x, y: lit(noise((0.98, 0.98, 0.96), 0.012), y, 0.1))


# ------------------------------------------------------------------ outils
_BVH = {}


def body_bvh(stage, parts):
    """Surface des pièces du corps de stade (coordonnées du personnage), pour y poser les accessoires."""
    key = (stage, parts)
    if key not in _BVH:
        verts, polys = [], []
        col = bpy.data.collections.get("Body_" + stage)
        for o in (col.objects if col else []):
            name = o.name.split(".")[0]
            if o.type != "MESH" or not any(name == f"{stage}_{p}" or name.startswith(f"{stage}_{p}_") for p in parts):
                continue
            base = len(verts)
            verts += [v.co.copy() for v in o.data.vertices]
            polys += [[base + i for i in p.vertices] for p in o.data.polygons]
        _BVH[key] = BVHTree.FromPolygons(verts, polys) if polys else None
    return _BVH[key]


def hit_body(g, point, direction, lift, parts=("UpperTorso",)):
    """Point de la surface du corps touché en venant de `direction` (vers l'intérieur), décollé de `lift` ;
    None si le rayon ne touche rien."""
    tree = body_bvh(g["stage"], parts)
    d = Vector(direction).normalized()
    if tree:
        hit, normal, _, _ = tree.ray_cast(Vector(point) - d * 12, d, 30)
        if hit is not None:
            n = normal.normalized()
            if n.dot(d) > 0:                           # face vue de dos : la normale pointe vers nous
                n = -n
            return hit + n * lift, n
    return None


def onto(g, point, direction, lift, parts=("UpperTorso",)):
    """Comme hit_body ; sans impact, le point est rendu tel quel."""
    found = hit_body(g, point, direction, lift, parts)
    return found if found else (Vector(point), -Vector(direction).normalized())


def frame_box(center, x_axis, y_axis, size):
    """Boîte orientée : x_axis et y_axis (z en découle), size = (sx, sy, sz)."""
    x = Vector(x_axis).normalized()
    z = x.cross(Vector(y_axis)).normalized()
    y = z.cross(x)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    m = Matrix((x, y, z)).transposed()
    for v in bm.verts:
        v.co = Vector(center) + m @ Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    return bm


def disc(center, normal, radius, thickness, sides=12):
    """Disque (pièce de monnaie, verre, plaque) dont la face regarde `normal`."""
    n = Vector(normal).normalized() * thickness / 2
    return prism(tuple(Vector(center) - n), tuple(Vector(center) + n), radius, radius, sides)


def star(center, normal, up, radius, thickness, points=5):
    """Étoile pleine (embossage de médaille), à plat sur la face `normal`."""
    n = Vector(normal).normalized()
    u = Vector(up).normalized()
    r = n.cross(u).normalized()
    bm = bmesh.new()
    front, back = [], []
    for i in range(points * 2):
        a = math.pi * i / points
        rad = radius if i % 2 == 0 else radius * 0.45
        p = Vector(center) + (u * math.cos(a) + r * math.sin(a)) * rad
        front.append(bm.verts.new(p + n * thickness))
        back.append(bm.verts.new(p))
    cf = bm.verts.new(Vector(center) + n * thickness)
    cb = bm.verts.new(Vector(center))
    m = len(front)
    for i in range(m):
        j = (i + 1) % m
        bm.faces.new((cf, front[i], front[j]))
        bm.faces.new((cb, back[j], back[i]))
        bm.faces.new((front[i], back[i], back[j], front[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def paddle(root, tip, w0, w1, normal, thick):
    """Pale de ventilateur : trapèze épais, étroit au moyeu, large au bout, à plat sur `normal`."""
    root, tip, n = Vector(root), Vector(tip), Vector(normal).normalized()
    along = (tip - root).normalized()
    side = along.cross(n).normalized()
    bm = bmesh.new()
    corners = [root - side * w0, root + side * w0, tip + side * w1, tip - side * w1]
    top = [bm.verts.new(c + n * thick / 2) for c in corners]
    bot = [bm.verts.new(c - n * thick / 2) for c in corners]
    bm.faces.new(top)
    bm.faces.new(list(reversed(bot)))
    for i in range(4):
        j = (i + 1) % 4
        bm.faces.new((top[i], bot[i], bot[j], top[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def drape(g, z0, drop, rx, ry, lift, count, front_only=False):
    """Collier qui fait le tour du cou et tombe en V sur la poitrine : points posés sur le torse.
    Autour du cou, il repose sur le haut des trapèzes (posé d'en haut) ; devant, il pend sur la poitrine (posé de
    face). Renvoie [(point, normale)], en partant du dos."""
    pts = []
    start, end = (math.pi * 0.5, math.pi * 2.5) if not front_only else (math.pi * 1.1, math.pi * 1.9)
    steps = count if not front_only else count - 1
    for i in range(count):
        a = start + (end - start) * i / steps
        s = max(0.0, -math.sin(a))                    # 1 devant (-Y), 0 sur les côtés et dans le dos
        x, y = math.cos(a) * rx, math.sin(a) * ry
        found = hit_body(g, (x, y, z0 + 3.0), (0, 0, -1), lift)
        if not found or found[0].z > z0 + 0.6:         # rien sous le collier (épaules tombantes) : posé de côté
            found = onto(g, (x, y, z0), (-math.cos(a), -math.sin(a), 0), lift)
        top, ntop = found
        if s < 0.35:
            pts.append((top, ntop))
            continue
        # Devant : de face, plus bas à mesure qu'on s'approche du milieu
        z = min(top.z, z0) - drop * ((s - 0.35) / 0.65) ** 1.4
        front, nfront = onto(g, (x * (1 - 0.2 * s), -3.0, z), (0, 1, 0), lift)
        blend = min(1.0, (s - 0.35) / 0.25)
        pts.append((top.lerp(front, blend), ntop.lerp(nfront, blend).normalized()))
    return pts


def chain(w, part, pts, size, cells, closed=True):
    """Maillons plats alternés (posés à plat, puis de chant) entre les points."""
    n = len(pts)
    for i in range(n if closed else n - 1):
        p0, n0 = pts[i]
        p1, n1 = pts[(i + 1) % n]
        c = (p0 + p1) / 2
        t = p1 - p0
        if t.length < 1e-4:
            continue
        normal = (n0 + n1).normalized()
        flat = i % 2 == 0
        w.make(part, frame_box(c, t, normal if flat else t.cross(normal),
                               (t.length * 1.15, size * (0.5 if flat else 0.36), size)),
               cells[i % len(cells)])


def band(w, part, pts, width, thick, cell, closed=False):
    """Ruban ou bretelle plat qui suit les points, à plat sur la surface."""
    n = len(pts)
    for i in range(n if closed else n - 1):
        p0, n0 = pts[i]
        p1, n1 = pts[(i + 1) % n]
        t = p1 - p0
        if t.length < 1e-4:
            continue
        normal = (n0 + n1).normalized()
        side = t.cross(normal).normalized()
        w.make(part, frame_box((p0 + p1) / 2, t, side, (t.length * 1.08, width, thick)), cell)


def eyes(g):
    cfg = g["cfg"]
    r, hy, z = g["head_r"], g["hy"], g["head_z"]
    er = cfg["eye_r"] * (1.28 if cfg.get("fem") else 1.0)
    y = min(hy - r * 0.78, g["jaw_front"] + cfg["eye_r"] * 0.8)
    ez = max(z + r * 0.12, g["jaw_top"] + cfg["eye_r"] * 0.7)
    return [Vector((sx * r * 0.36, y, ez)) for sx in (-1, 1)], er


# ------------------------------------------------------------------ accessoires
def build_accessories(w, g):
    J, cfg = g["J"], g["cfg"]
    r, hy, z = g["head_r"], g["hy"], g["head_z"]
    neck, h = J["Neck"], g["h"]
    k = max(1.0, g["chest_w"] / 1.6) ** 0.8          # gabarit : un accessoire de Normie serait perdu sur un God Mogger
    t_top = 0.05 + cfg["bicep"] * 0.04                # épaisseur d'un haut (build_tops)
    lift = t_top * 2.3 + 0.04                         # au-dessus du haut le plus épais
    neck_r = max(cfg["neck"] * 1.25 + 0.12, r * 0.55)
    # Tour du cou : jamais plus large que le haut du torse (un Normie a un cou et des épaules très étroits)
    ring_x = min(neck_r, g["chest_w"] * 0.3)
    ring_y = min(neck_r * 0.95, g["depth"] * 0.5)

    def below(point, drop, extra):
        """Pendentif : posé sur la poitrine sous `point` ; s'il n'y a rien dessous, il pend simplement."""
        found = hit_body(g, (point.x, -3.0, point.z - drop), (0, 1, 0), extra)
        return found[0] if found else point + Vector((0, -extra, -drop))

    # -------- Bandeau : éponge rouge épaisse, bande blanche, nœud sur le côté et deux pans qui volent
    w.start("Headband")
    bz = z + r * 0.42
    w.make("Head", waist_band((0, hy + 0.02, bz), r * 0.93, r * 1.06, 0.14, r * 0.3, 14), "acc_red")
    w.make("Head", waist_band((0, hy + 0.02, bz), r * 0.95, r * 1.08, 0.06, r * 0.09, 14), "acc_white")
    knot = Vector((r * 0.62, hy + r * 0.82, bz))
    w.make("Head", lowsphere(tuple(knot), (r * 0.2, r * 0.18, r * 0.2), 6, 4), "acc_red")
    for spread, length in ((0.25, 1.0), (-0.15, 0.8)):
        tip = knot + Vector((r * (0.25 + spread), r * 0.55 * length, -r * 0.55 * length))
        w.make("Head", prism(tuple(knot), tuple(tip), r * 0.13, r * 0.07, sides=4), "acc_red")

    # -------- Bracelets éponge : épais, trois bandes (blanc, rouge, bleu)
    w.start("Sweatbands")
    for side, _ in sides():
        el, wr = J[side + "Elbow"], J[side + "Wrist"]
        axis = (wr - el).normalized()
        c = el.lerp(wr, 0.78)
        rad = cfg["forearm"] * 0.92 + 0.1
        hh = 0.16 + cfg["forearm"] * 0.45
        w.make(side + "LowerArm", prism(tuple(c - axis * hh), tuple(c + axis * hh), rad, rad * 0.97, sides=10), "acc_white")
        for off, cell in ((-0.5, "acc_red"), (0.5, "acc_blue")):
            p = c + axis * hh * off
            w.make(side + "LowerArm", prism(tuple(p - axis * hh * 0.16), tuple(p + axis * hh * 0.16),
                                            rad + 0.02, rad + 0.02, sides=10), cell)

    # -------- Lunettes haltère : deux verres en disques de fonte, moyeu chromé, barre et colliers entre les deux
    w.start("DumbbellShades")
    centers, er = eyes(g)
    lens_r = min(r * 0.31, er * 1.45 + 0.02)
    front_y = min(c.y for c in centers) - er * 0.95
    for c in centers:
        lc = Vector((c.x, front_y - 0.03, c.z))
        w.make("Head", disc(lc, (0, -1, 0), lens_r, 0.07, 8), "acc_lens")
        w.make("Head", disc(lc + Vector((0, 0.03, 0)), (0, -1, 0), lens_r + 0.05, 0.05, 8), "acc_black")
        w.make("Head", disc(lc - Vector((0, 0.045, 0)), (0, -1, 0), lens_r * 0.22, 0.04, 6), "acc_chrome")
    lx = centers[1].x
    w.make("Head", prism((lx - lens_r * 0.95, front_y - 0.02, centers[0].z + lens_r * 0.2),
                         (-lx + lens_r * 0.95, front_y - 0.02, centers[0].z + lens_r * 0.2), 0.035, 0.035, sides=6),
           "acc_chrome")
    for sx in (-1, 1):
        cx = sx * (abs(lx) - lens_r - 0.02) if abs(lx) - lens_r > 0.08 else sx * 0.06
        w.make("Head", disc((cx * 0.5, front_y - 0.02, centers[0].z + lens_r * 0.2), (1, 0, 0), 0.06, 0.05, 6), "acc_chrome")
        hinge = Vector((sx * (abs(lx) + lens_r + 0.02), front_y + 0.02, centers[0].z + lens_r * 0.25))
        ear = Vector((sx * r * 0.86, hy + r * 0.1, centers[0].z + lens_r * 0.1))
        w.make("Head", prism(tuple(hinge), tuple(ear), 0.04, 0.035, sides=4), "acc_black")

    # -------- Sac shaker : un shaker géant sur le dos (liquide rose, graduations, couvercle à bec), vraies bretelles
    w.start("ShakerBackpack")
    back_pt, back_n = onto(g, (0, 2.0, neck.z - h * 0.42), (0, -1, 0), lift)
    sr = 0.4 * k
    base_z, top_z = neck.z - h * 0.95, neck.z - h * 0.05
    sy = back_pt.y + sr * 0.8
    w.make("UpperTorso", prism((0, sy, base_z), (0, sy, base_z + (top_z - base_z) * 0.62), sr, sr * 0.97, sides=12), "acc_pink")
    w.make("UpperTorso", prism((0, sy, base_z + (top_z - base_z) * 0.62), (0, sy, top_z), sr * 0.97, sr * 0.93, sides=12),
           "acc_clear")
    for f in (0.3, 0.5, 0.75):
        zz = base_z + (top_z - base_z) * f
        w.make("UpperTorso", prism((0, sy, zz - 0.02), (0, sy, zz + 0.02), sr * 1.02, sr * 1.02, sides=12), "acc_white")
    w.make("UpperTorso", prism((0, sy, base_z - 0.06 * k), (0, sy, base_z), sr * 1.04, sr * 1.04, sides=12), "acc_black")
    w.make("UpperTorso", prism((0, sy, top_z), (0, sy, top_z + 0.18 * k), sr * 1.06, sr * 1.0, sides=12), "acc_black")
    w.make("UpperTorso", prism((0, sy - sr * 0.35, top_z + 0.18 * k), (0, sy - sr * 0.35, top_z + 0.34 * k),
                               sr * 0.24, sr * 0.16, sides=8), "acc_black")
    w.make("UpperTorso", ring_upright((0, sy + sr * 0.35, top_z + 0.3 * k), 0.14 * k, 0.05 * k, 0.06 * k, 8), "acc_black")
    # Bretelles : du dos, par-dessus l'épaule, jusque sous la poitrine. Posées vers l'axe de l'épaule (rayons qui
    # convergent vers une ligne gauche-droite) : elles collent au trapèze et au pectoral quel que soit le gabarit.
    zc = neck.z - h * 0.4
    for sx in (-1, 1):
        x = sx * g["chest_w"] * 0.21
        path = []
        for f in range(11):
            a = math.radians(-35 + 250 * f / 10)       # angle dans le plan YZ, 0 = dans le dos (+Y), 90 = au-dessus
            d = Vector((0, math.cos(a), math.sin(a)))
            path.append(onto(g, Vector((x, 0, zc)) + d * 3.0, -d, lift * 0.7))
        band(w, "UpperTorso", path, 0.17 * k, 0.05, "acc_strap")
        p0, n0 = path[-3]
        p1, _ = path[-2]
        along = (p1 - p0).normalized()
        w.make("UpperTorso", frame_box((p0 + p1) / 2 + n0 * 0.035, along, along.cross(n0), (0.2 * k, 0.24 * k, 0.05)),
               "acc_chrome")

    # -------- Chaîne en or : grosse maille gourmette qui épouse le cou et la poitrine, pendentif haltère
    w.start("GoldChain")
    pts = drape(g, neck.z, h * 0.3, ring_x, ring_y, lift * 0.5 + 0.03, 34)
    chain(w, "UpperTorso", pts, 0.11 * k, ("acc_gold", "acc_gold"))
    low = min(pts, key=lambda p: p[0].z)
    pend = below(low[0], 0.28 * k, lift + 0.06)
    w.make("UpperTorso", prism(tuple(low[0]), tuple(pend + Vector((0, 0, 0.1 * k))), 0.03 * k, 0.03 * k, 4), "acc_gold")
    bar = Vector((1, 0, 0))
    w.make("UpperTorso", prism(tuple(pend - bar * 0.3 * k), tuple(pend + bar * 0.3 * k), 0.05 * k, 0.05 * k, 6),
           "acc_gold")
    for sx in (-1, 1):
        for off, rr in ((0.2, 0.2), (0.3, 0.15)):
            c = pend + bar * sx * off * k
            w.make("UpperTorso", prism(tuple(c - bar * 0.045 * k), tuple(c + bar * 0.045 * k), rr * k, rr * k, 8),
                   "acc_gold" if off == 0.2 else "acc_gold_dark")

    # -------- Médaille de bronze : ruban en V posé sur la poitrine, grosse médaille, rebord et étoile en relief
    w.start("BronzeMedal")
    pts = drape(g, neck.z, h * 0.36, ring_x * 0.98, ring_y * 0.98, lift * 0.5 + 0.02, 26)
    band(w, "UpperTorso", pts, 0.17 * k, 0.04, "acc_blue", closed=True)
    band(w, "UpperTorso", [(p + n * 0.025, n) for p, n in pts], 0.07 * k, 0.04, "acc_red", closed=True)
    low = min(pts, key=lambda p: p[0].z)
    mc = below(low[0], 0.32 * k, lift + 0.05)
    mc.z = low[0].z - 0.32 * k                        # pend juste sous la pointe du ruban
    face = Vector((0, -1, 0))                         # devant le personnage
    up = Vector((0, 0, 1))
    w.make("UpperTorso", disc(mc, face, 0.3 * k, 0.08, 14), "acc_bronze")
    w.make("UpperTorso", ring_upright(tuple(mc + face * 0.05), 0.31 * k, 0.06 * k, 0.06, 14), "acc_bronze_dark")
    w.make("UpperTorso", star(mc + face * 0.04, face, up, 0.19 * k, 0.05), "acc_gold")
    hook = mc + up * 0.32 * k
    w.make("UpperTorso", ring_upright(tuple(hook), 0.07 * k, 0.03 * k, 0.04, 8), "acc_bronze_dark")
    w.make("UpperTorso", prism(tuple(low[0]), tuple(hook + up * 0.05 * k), 0.035 * k, 0.035 * k, 4), "acc_blue")

    # -------- Sifflet de coach : cordon tressé rouge, gros sifflet chromé avec embout et anneau
    w.start("CoachWhistle")
    pts = drape(g, neck.z, h * 0.33, ring_x, ring_y, lift * 0.5 + 0.02, 22)
    for i in range(len(pts)):
        p0, _ = pts[i]
        p1, _ = pts[(i + 1) % len(pts)]
        w.make("UpperTorso", prism(tuple(p0), tuple(p1), 0.035 * k, 0.035 * k, 5), "acc_cord")
    low = min(pts, key=lambda p: p[0].z)
    wc = below(low[0] + Vector((0.06 * k, 0, 0)), 0.2 * k, lift + 0.1 * k)
    wn = Vector((0, -1, 0))
    side = Vector((1, 0, 0))
    w.make("UpperTorso", prism(tuple(wc - side * 0.16 * k), tuple(wc + side * 0.12 * k), 0.12 * k, 0.12 * k, 10),
           "acc_chrome")
    w.make("UpperTorso", frame_box(wc + side * 0.24 * k + Vector((0, 0, 0.05 * k)), side, wn, (0.26 * k, 0.12 * k, 0.1 * k)),
           "acc_chrome")
    w.make("UpperTorso", frame_box(wc + side * 0.38 * k + Vector((0, 0, 0.05 * k)), side, wn, (0.06 * k, 0.13 * k, 0.11 * k)),
           "acc_black")
    w.make("UpperTorso", disc(wc + wn * 0.11 * k, wn, 0.05 * k, 0.03, 6), "acc_black")
    w.make("UpperTorso", ring_upright(tuple(wc + Vector((-0.1 * k, 0, 0.14 * k))), 0.06 * k, 0.025 * k, 0.03, 6), "acc_chrome")
    w.make("UpperTorso", prism(tuple(low[0]), tuple(wc + Vector((-0.1 * k, 0, 0.18 * k))), 0.03 * k, 0.03 * k, 5),
           "acc_cord")

    # -------- Chaussettes géantes : tubes remontés jusqu'aux genoux, tirebouchonnés, revers et rayures rouge/bleu
    w.start("TinySocks")
    for side, _ in sides():
        knee, ankle = J[side + "Knee"], J[side + "Ankle"]
        rad = cfg["calf"] * 1.2 + 0.1
        a, b = Vector((ankle.x, 0.0, ankle.z - 0.06)), Vector((knee.x, 0.0, knee.z - 0.08))
        mid = a.lerp(b, 0.45)
        w.make(side + "LowerLeg", limb(tuple(a), tuple(mid), rad * 1.12, rad * 1.22, rad * 1.08, sides=10), "acc_sock")
        w.make(side + "LowerLeg", limb(tuple(mid), tuple(b), rad * 1.08, rad * 1.14, rad * 1.04, sides=10), "acc_sock")
        top = b + Vector((0, 0, 0.1))
        w.make(side + "LowerLeg", prism(tuple(b - Vector((0, 0, 0.06))), tuple(top), rad * 1.16, rad * 1.18, sides=10),
               "acc_sock")
        for f, cell in ((0.76, "acc_red"), (0.9, "acc_blue")):
            p = a.lerp(b, f)
            w.make(side + "LowerLeg", prism(tuple(p - Vector((0, 0, 0.045))), tuple(p + Vector((0, 0, 0.045))),
                                            rad * 1.17, rad * 1.17, sides=10), cell)

    # -------- Ventilateur royal : cage d'or, quatre pales violettes, moyeu à rubis, petite couronne au sommet
    w.start("RoyalFan")
    back_pt, back_n = onto(g, (0, 2.0, neck.z - h * 0.2), (0, -1, 0), lift)
    hub = Vector((0, back_pt.y + 0.45 * k, neck.z + 0.25 + 0.35 * k))
    R = 0.95 * k
    w.make("UpperTorso", prism(tuple(back_pt), tuple(hub - Vector((0, 0, R * 0.3))), 0.07 * k, 0.06 * k, 6), "acc_gold_dark")
    w.make("UpperTorso", frame_box(back_pt, (1, 0, 0), (0, 0, 1), (0.36 * k, 0.28 * k, 0.08)), "acc_gold_dark")
    w.make("UpperTorso", ring_upright(tuple(hub), R, 0.07 * k, 0.09 * k, 16), "acc_gold")
    for blade in range(4):
        a = 2 * math.pi * blade / 4 + math.pi / 4
        d = Vector((math.cos(a), 0, math.sin(a)))
        perp = Vector((-math.sin(a), 0, math.cos(a)))
        tilt = Vector((0, -1, 0)).lerp(perp, 0.35).normalized()   # pales inclinées, comme un vrai ventilateur
        w.make("UpperTorso", paddle(hub + d * R * 0.14, hub + d * R * 0.9, R * 0.08, R * 0.24, tilt, 0.05), "acc_purple")
        w.make("UpperTorso", prism(tuple(hub + d * R * 0.12), tuple(hub + d * R), 0.025 * k, 0.025 * k, 4), "acc_gold")
    w.make("UpperTorso", disc(hub, (0, -1, 0), 0.17 * k, 0.12, 8), "acc_gold")
    w.make("UpperTorso", lowsphere(tuple(hub - Vector((0, 0.08, 0))), (0.09 * k, 0.06, 0.09 * k), 6, 4), "acc_gem")
    crown = hub + Vector((0, 0, R + 0.02))
    w.make("UpperTorso", prism(tuple(crown), tuple(crown + Vector((0, 0, 0.1 * k))), 0.24 * k, 0.24 * k, 8), "acc_gold")
    for i in range(5):
        x = (i - 2) * 0.11 * k
        base = crown + Vector((x, 0, 0.1 * k))
        w.make("UpperTorso", pyramid(tuple(base), tuple(base + Vector((0, 0, (0.18 if i % 2 == 0 else 0.12) * k))),
                                     0.05 * k, 0.04 * k), "acc_gold")
    w.make("UpperTorso", lowsphere(tuple(crown + Vector((0, -0.05 * k, 0.05 * k))), (0.05 * k, 0.04, 0.05 * k), 6, 4),
           "acc_gem")

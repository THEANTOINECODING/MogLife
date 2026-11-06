"""
Coupes de cheveux de MOG LIFE, refaites (D114) : chargé par build_style.py (exec) après ses formes low poly.

Avant : une calotte lisse et une ou deux boules par coupe (des « casques »). Maintenant chaque coupe a une calotte
ajustée au crâne et des MÈCHES (prismes effilés à facettes) qui cassent la silhouette : elle se reconnaît de loin, de
face comme de dos. Mêmes cases de couleur qu'avant : les cheveux prennent toujours la couleur choisie par le joueur
(teinte _Hair), et chaque coupe garde exactement ses pièces (l'installation dans Studio compte les pièces).
"""
import math
from mathutils import Vector


def head_frame(g):
    """Centre et rayons du crâne (mêmes formules que build_bodies)."""
    r = g["head_r"]
    return Vector((0, g["hy"], g["head_z"])), (r * 0.82, r * 0.95, r)


def on_head(g, theta, phi, m=1.0):
    """Point du crâne : theta = tour de tête (0 devant, + vers la gauche du personnage), phi = hauteur (0 au niveau
    des yeux, 90 au sommet), m = gonflement (1 = la peau)."""
    c, (rx, ry, rz) = head_frame(g)
    t, p = math.radians(theta), math.radians(phi)
    return c + Vector((math.sin(t) * math.cos(p) * rx * m, -math.cos(t) * math.cos(p) * ry * m, math.sin(p) * rz * m))


def normal_at(g, theta, phi):
    c, _ = head_frame(g)
    return (on_head(g, theta, phi, 1.0) - c).normalized()


def lock(root, tip, w0, w1=None, sides=4, bend=None, bend_amount=0.0):
    """Mèche : fuseau effilé de `root` à `tip` (w0 à la racine, w1 au bout), qui peut se courber vers `bend`."""
    w1 = w0 * 0.15 if w1 is None else w1
    if bend is None or bend_amount == 0:
        return prism(tuple(root), tuple(tip), w0, w1, sides)
    mid = Vector(root).lerp(Vector(tip), 0.5) + Vector(bend).normalized() * bend_amount
    return limb(tuple(root), tuple(tip), w0, (w0 + w1) * 0.6, w1, sides=sides, mid_t=0.5,
                bulge_dir=tuple(Vector(bend).normalized()), bulge=bend_amount)


_HEAD = {}


def head_tree(stage):
    """Surface du crâne seul (pièce <stade>_Head, sans yeux ni sourcils), pour que la calotte ne s'y enfonce jamais."""
    if stage not in _HEAD:
        from mathutils.bvhtree import BVHTree
        o = bpy.data.objects.get(f"{stage}_Head")
        _HEAD[stage] = (BVHTree.FromPolygons([v.co.copy() for v in o.data.vertices],
                                             [list(f.vertices) for f in o.data.polygons]) if o else None)
    return _HEAD[stage]


def cap(g, m=1.08, lift=0.0, low=-15):
    """Calotte de cheveux ajustée au crâne, descendue jusqu'à `low` degrés (sous la ligne des yeux si < 0).
    Ellipsoïde fin (rangs de 15°) ; chaque point est repoussé hors du vrai crâne (plus carré que l'ellipsoïde)."""
    c, (rx, ry, rz) = head_frame(g)
    bm = lowsphere((0, 0, 0), (1, 1, 1), 12, 12)
    cut = math.sin(math.radians(low))
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < cut - 0.01], context="VERTS")
    bmesh.ops.holes_fill(bm, edges=bm.edges, sides=0)
    tree = head_tree(g.get("stage", ""))
    gap = g["head_r"] * (m - 1)
    for v in bm.verts:
        p = c + Vector((v.co.x * rx * m, v.co.y * ry * m, v.co.z * rz * m + lift))
        face = v.co.y < -0.3 and v.co.z < 0.6                     # le visage (yeux, sourcils) reste dégagé
        if tree and not face:
            d = (c - p).normalized()
            hit = tree.ray_cast(p - d * 12, d, 30)[0]
            if hit is not None and (hit - c).length + gap > (p - c).length:
                p = c + (hit - c).normalized() * ((hit - c).length + gap)
        v.co = p
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def build_hair(w, g):
    r = g["head_r"]
    c, (rx, ry, rz) = head_frame(g)
    up = Vector((0, 0, 1))
    back = Vector((0, 1, 0))
    front = Vector((0, -1, 0))

    def crest(g, phis, lifts, sizes, mat, theta=0.0):
        """Volume de mèches qui suit le crâne : une boule allongée par étape (phi, décollement, taille), chacune posée
        sur la calotte (jamais en l'air), orientée le long de la vague."""
        for phi, lift, (sx, sy, sz) in zip(phis, lifts, sizes):
            base = on_head(g, theta, phi, 1.05)
            n = normal_at(g, theta, phi)
            w.make("Head", lowsphere(tuple(base + n * r * (sz * 0.3 + lift * 0.45)), (sx * r, sy * r, sz * r), 8, 6), mat)

    # -------- Banane : une seule grande vague jaune qui monte du sommet et retombe en avant au-dessus du front
    w.start("Banana")
    w.make("Head", cap(g, 1.07, low=5), "hair_yellow")
    crest(g, (100, 85, 70, 56, 44), (0.0, 0.12, 0.3, 0.42, 0.38),
          ((0.52, 0.5, 0.3), (0.55, 0.5, 0.42), (0.52, 0.46, 0.5), (0.46, 0.42, 0.5), (0.36, 0.36, 0.4)), "hair_yellow")
    tipb = on_head(g, 0, 40, 1.05) + normal_at(g, 0, 40) * r * 0.45
    w.make("Head", lock(tipb, tipb + front * r * 0.35 - up * r * 0.45, r * 0.3, r * 0.08, 5, front, r * 0.12), "hair_yellow")
    for k in range(4):                                                # sillons de la vague (mèches sur le dessus)
        phi = 92 - k * 13
        root = on_head(g, 0, phi, 1.05) + normal_at(g, 0, phi) * r * (0.3 + 0.05 * k)
        for sx in (-1, 1):
            off = Vector((sx * r * 0.22, 0, 0))
            w.make("Head", lock(root + off, root + off * 1.2 + front * r * 0.35 + normal_at(g, 0, phi) * r * 0.2,
                                r * 0.16, r * 0.05, 4), "hair_yellow")
    for sx in (-1, 1):                                                # côtés courts, plaqués vers l'arrière
        for k in range(3):
            root = on_head(g, sx * (60 + k * 30), 30, 1.05)
            w.make("Head", lock(root, root + back * r * 0.45 + up * r * 0.08, r * 0.2, r * 0.06, 4), "hair_yellow")

    # -------- Mulet : court et hérissé dessus, une cascade de mèches derrière jusqu'aux épaules
    w.start("Mullet")
    w.make("Head", cap(g, 1.06, low=0), "hair_brown")
    for theta in range(-60, 61, 30):                                  # petites pointes sur le dessus
        for phi in (55, 75):
            root = on_head(g, theta, phi, 1.02)
            w.make("Head", lock(root, root + normal_at(g, theta, phi) * r * 0.3 + back * r * 0.08, r * 0.16, r * 0.03, 4),
                   "hair_brown")
    for i, theta in enumerate(range(110, 251, 20)):                   # la cascade : dans le dos, de plus en plus longue
        root = on_head(g, theta, 15, 1.02)
        length = 1.2 + 0.25 * (1 - abs(theta - 180) / 70)
        tip = root + Vector((0, 0, -r * length)) + back * r * 0.35 + Vector((math.sin(math.radians(theta)) * r * 0.25, 0, 0))
        w.make("Head", lock(root, tip, r * 0.26, r * 0.12, 5, back, r * 0.15), "hair_brown")
        if i % 2 == 0:                                                # pointes retroussées au bout
            w.make("Head", lock(tip + up * r * 0.1, tip + back * r * 0.3 + up * r * 0.15, r * 0.12, r * 0.03, 4), "hair_brown")

    # -------- Crête : crâne rasé, grande crête en lames de couleur du front à la nuque
    w.start("Mohawk")
    w.make("Head", cap(g, 1.02, low=-5), "bald")
    for i in range(8):
        u = i / 7
        phi = 50 + u * 130                                            # front -> sommet -> nuque
        root = c + Vector((0, -math.cos(math.radians(phi)) * ry * 1.0, math.sin(math.radians(phi)) * rz * 1.0))
        n = (root - c).normalized()
        height = r * (0.75 + 0.55 * math.sin(math.pi * min(1, u * 1.2)))
        tip = root + n * height + back * r * 0.25
        w.make("Head", pyramid(tuple(root), tuple(tip), r * 0.06, r * 0.22), "hair_pink")

    # -------- Crâne lustré : dôme rasé (couleur de peau), reflet dans la texture
    w.start("ShinyBald")
    w.make("Head", cap(g, 1.03, low=-10), "bald")
    w.make("Head", lowsphere(tuple(on_head(g, 25, 55, 1.06)), (r * 0.22, r * 0.08, r * 0.12), 8, 5), "white")   # reflet

    # -------- Boucles (départ) : une masse de boucles serrées, toute la tête, quelques-unes sur le front
    w.start("Curly")
    w.make("Head", cap(g, 1.06, low=-5), "hair_brown")
    golden = math.pi * (3 - math.sqrt(5))
    for i in range(34):
        z = 1 - (i + 0.5) / 34 * 1.15                                 # du sommet jusque sous la ligne des oreilles
        phi = math.degrees(math.asin(max(-0.3, min(1, z))))
        theta = math.degrees(i * golden) % 360 - 180
        if abs(theta) < 40 and phi < 30:                              # pas de boucles sur le visage
            continue
        p = on_head(g, theta, phi, 1.12)
        size = r * (0.22 + 0.06 * ((i * 7) % 3))
        w.make("Head", lowsphere(tuple(p), (size, size, size * 0.9), 6, 4), "hair_brown")

    # -------- Cheveux longs (départ) : raie au milieu, rideaux qui encadrent le visage, masse jusqu'aux épaules
    w.start("LongHair")
    w.make("Head", cap(g, 1.06, low=-5), "hair_brown")
    for sx in (-1, 1):
        w.make("Head", lock(on_head(g, sx * 8, 80, 1.04), on_head(g, sx * 55, 40, 1.1), r * 0.2, r * 0.14, 5), "hair_brown")
        for k, theta in enumerate((40, 65, 95)):                      # rideaux devant les oreilles
            root = on_head(g, sx * theta, 35, 1.06)
            tip = root + Vector((sx * r * 0.12, back.y * r * 0.1 * k, -r * (1.35 + 0.1 * k)))
            w.make("Head", lock(root, tip, r * 0.24, r * 0.12, 5, Vector((sx, 0, 0)), r * 0.1), "hair_brown")
    for theta in range(120, 241, 20):                                 # la masse dans le dos
        root = on_head(g, theta, 25, 1.05)
        tip = root + Vector((math.sin(math.radians(theta)) * r * 0.15, r * 0.25, -r * 1.55))
        w.make("Head", lock(root, tip, r * 0.32, r * 0.16, 5, back, r * 0.18), "hair_brown")

    # -------- Chignon (départ) : cheveux tirés, gros chignon sur le dessus avec son élastique, deux mèches libres
    w.start("Bun")
    w.make("Head", cap(g, 1.04, low=0), "hair_brown")
    top = on_head(g, 0, 90, 1.0) + up * r * 0.32 + back * r * 0.12
    w.make("Head", lowsphere(tuple(top), (r * 0.46, r * 0.46, r * 0.38), 10, 7), "hair_brown")
    for a in range(4):                                                # tours du chignon
        t = a * math.pi / 2
        p = top + Vector((math.cos(t) * r * 0.3, math.sin(t) * r * 0.3, r * 0.12))
        w.make("Head", lowsphere(tuple(p), (r * 0.2, r * 0.2, r * 0.16), 6, 4), "hair_brown")
    w.make("Head", ring(tuple(top - up * r * 0.3), r * 0.32, 0.06, r * 0.12, 10), "red")
    for sx in (-1, 1):
        root = on_head(g, sx * 50, 30, 1.04)
        w.make("Head", lock(root, root + Vector((sx * r * 0.08, -r * 0.05, -r * 0.7)), r * 0.1, r * 0.03, 4,
                            Vector((sx, -1, 0)), r * 0.08), "hair_brown")

    # -------- Carré (départ) : casque arrondi qui s'arrête à la mâchoire, frange droite en mèches épaisses
    w.start("Bob")
    w.make("Head", cap(g, 1.1, low=0), "hair_brown")
    for theta in range(50, 311, 20):                                  # la jupe du carré, tout autour sauf le visage
        root = on_head(g, theta, 20, 1.08)
        out = normal_at(g, theta, 0)
        tip = root + Vector((0, 0, -r * 0.85)) + out * r * 0.12
        w.make("Head", lock(root, tip, r * 0.28, r * 0.22, 5), "hair_brown")
    for k in range(5):                                                # frange
        theta = -40 + k * 20
        root = on_head(g, theta, 60, 1.08)
        tip = on_head(g, theta, 28, 1.16)
        w.make("Head", lock(root, tip, r * 0.18, r * 0.15, 4), "hair_brown")

    # -------- Pompadour : gros volume gominé large et bas, trois bourrelets côte à côte d'avant en arrière, côtés
    # plaqués, une mèche rebelle qui retombe sur le front
    w.start("Pompadour")
    w.make("Head", cap(g, 1.06, low=5), "hair_black")
    for t in (-22, 0, 22):                                            # trois crêtes parallèles = sillons du peigne
        wide = 0.34 if t == 0 else 0.28
        crest(g, (95, 78, 62, 50), (0.0, 0.12, 0.22, 0.2),
              ((wide, 0.5, 0.3), (wide, 0.5, 0.38), (wide, 0.46, 0.4), (wide * 0.9, 0.4, 0.34)), "hair_black", theta=t)
    for sx in (-1, 1):
        for k in range(3):
            root = on_head(g, sx * (55 + k * 35), 40, 1.05)
            w.make("Head", lock(root, root + back * r * 0.5 + up * r * 0.1, r * 0.18, r * 0.05, 4), "hair_black")
    curl = on_head(g, 8, 50, 1.05) + normal_at(g, 8, 50) * r * 0.35
    w.make("Head", lock(curl, curl + front * r * 0.3 - up * r * 0.55 + Vector((r * 0.1, 0, 0)), r * 0.1, r * 0.03, 4,
                        front, r * 0.15), "hair_black")

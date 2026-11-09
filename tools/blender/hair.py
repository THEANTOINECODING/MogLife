"""
Coupes de cheveux de MOG LIFE, refaites une 3e fois (D126) : chargé par build_style.py (exec).

D114 : une calotte et des prismes. D126 (« 1000x plus stylé ») : chaque coupe est SCULPTÉE en grosses MÈCHES
(rubans épais, effilés, aplatis contre le crâne, qui suivent une vraie direction de coiffage et finissent en
pointe), posées en couches :
- une sous-couche plus sombre (pièce Head_HairShade : la couleur du joueur assombrie, Config/Look.luau) qui donne
  de la profondeur entre les mèches, comme une ombre ;
- les mèches principales (Head_Hair : la couleur du joueur) ;
- des mèches de détail qui cassent la silhouette (pointes relevées, mèche rebelle, frange).
Style low-poly à facettes, sans transparence (les jeux mobiles ne peuvent pas se payer des cartes de cheveux).
"""
import math
from mathutils import Vector

SHADE = "HairShade"   # pièce assombrie (D126)
UP = Vector((0, 0, 1))
BACK = Vector((0, 1, 0))
FRONT = Vector((0, -1, 0))


def head_frame(g):
    """Centre et rayons du crâne (mêmes formules que build_bodies)."""
    r = g["head_r"]
    return Vector((0, g["hy"], g["head_z"])), (r * 0.82, r * 0.95, r)


def on_head(g, theta, phi, m=1.0):
    """Point de l'ellipsoïde du crâne : theta = tour de tête (0 devant), phi = hauteur (0 aux yeux, 90 au sommet,
    > 90 vers la nuque), m = gonflement (1 = la peau)."""
    c, (rx, ry, rz) = head_frame(g)
    t, p = math.radians(theta), math.radians(phi)
    return c + Vector((math.sin(t) * math.cos(p) * rx * m, -math.cos(t) * math.cos(p) * ry * m, math.sin(p) * rz * m))


def normal_at(g, theta, phi):
    c, _ = head_frame(g)
    return (on_head(g, theta, phi, 1.0) - c).normalized()


_HEAD = {}


def head_tree(stage):
    """Surface du crâne seul (pièce <stade>_Head), pour que rien ne s'y enfonce."""
    if stage not in _HEAD:
        from mathutils.bvhtree import BVHTree
        o = bpy.data.objects.get(f"{stage}_Head")
        _HEAD[stage] = (BVHTree.FromPolygons([v.co.copy() for v in o.data.vertices],
                                             [list(f.vertices) for f in o.data.polygons]) if o else None)
    return _HEAD[stage]


def surface(g, theta, phi, lift):
    """Point du VRAI crâne (lancer de rayon), décollé de lift × rayon de tête le long de la normale."""
    c, _ = head_frame(g)
    p = on_head(g, theta, phi, 1.0)
    d = (p - c).normalized()
    tree = head_tree(g.get("stage", ""))
    base = p
    if tree:
        hit = tree.ray_cast(c + d * 12, -d, 30)[0]
        if hit is not None and (hit - c).length > (p - c).length * 0.85:
            base = hit
    return base + d * g["head_r"] * lift


def cap(g, m=1.08, lift=0.0, low=-15):
    """Calotte ajustée au crâne, descendue jusqu'à `low` degrés ; chaque point repoussé hors du vrai crâne."""
    c, (rx, ry, rz) = head_frame(g)
    bm = lowsphere((0, 0, 0), (1, 1, 1), 14, 12)
    cut = math.sin(math.radians(low))
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < cut - 0.01], context="VERTS")
    bmesh.ops.holes_fill(bm, edges=bm.edges, sides=0)
    tree = head_tree(g.get("stage", ""))
    gap = g["head_r"] * (m - 1)
    for v in bm.verts:
        p = c + Vector((v.co.x * rx * m, v.co.y * ry * m, v.co.z * rz * m + lift))
        face = v.co.y < -0.3 and v.co.z < 0.6
        if tree and not face:
            d = (c - p).normalized()
            hit = tree.ray_cast(p - d * 12, d, 30)[0]
            if hit is not None and (hit - c).length + gap > (p - c).length:
                p = c + (hit - c).normalized() * ((hit - c).length + gap)
        v.co = p
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


# ------------------------------------------------------------------ la mèche sculptée
def clump(pts, widths, flat=0.5, sides=6, center=None, axis=None, ridge=0.35):
    """Mèche : ruban épais qui suit `pts`, de largeur `widths` (pointe fine au bout), aplati le long de la normale
    du crâne (ou de `axis`), avec une arête sur le dessus (ridge) qui accroche la lumière."""
    pts = [Vector(p) for p in pts]
    n = len(pts)
    ctr = Vector(center) if center is not None else None
    bm = bmesh.new()
    loops = []
    for i, p in enumerate(pts):
        t = pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]
        t = t.normalized() if t.length > 1e-6 else Vector((0, 0, 1))
        ref = Vector(axis) if axis is not None else (p - ctr if ctr is not None else UP)
        f = ref - t * ref.dot(t)
        if f.length < 1e-5:
            f = t.orthogonal()
        f.normalize()
        s = t.cross(f).normalized()
        wd = max(widths[i], 1e-4)
        ring = []
        for k in range(sides):
            a = 2 * math.pi * k / sides
            ca, sa = math.cos(a), math.sin(a)
            h = sa * flat * (1 + ridge if sa > 0.5 else 1)
            ring.append(bm.verts.new(p + s * ca * wd + f * h * wd))
        loops.append(ring)
    for lo, hi in zip(loops, loops[1:]):
        for k in range(sides):
            j = (k + 1) % sides
            bm.faces.new((lo[k], lo[j], hi[j], hi[k]))
    t0 = (pts[1] - pts[0]).normalized()
    t1 = (pts[-1] - pts[-2]).normalized()
    a = bm.verts.new(pts[0] - t0 * widths[0] * 0.5)
    b = bm.verts.new(pts[-1] + t1 * max(widths[-1], 1e-3) * 2.5)
    for k in range(sides):
        j = (k + 1) % sides
        bm.faces.new((loops[0][j], loops[0][k], a))
        bm.faces.new((loops[-1][k], loops[-1][j], b))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def _catmull(keys, n):
    """Courbe douce passant par les clés (tuples de nombres), n points."""
    if len(keys) == 1:
        return [keys[0]] * n
    pts = [keys[0]] + list(keys) + [keys[-1]]
    segs = len(keys) - 1
    out = []
    for i in range(n):
        u = i / (n - 1) * segs
        s = min(int(u), segs - 1)
        t = u - s
        p0, p1, p2, p3 = pts[s], pts[s + 1], pts[s + 2], pts[s + 3]
        out.append(tuple(0.5 * ((2 * b) + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t * t + (-a + 3 * b - 3 * c + d) * t ** 3)
                         for a, b, c, d in zip(p0, p1, p2, p3)))
    return out


def flow(g, keys, n=8, tail=(), tail_n=3):
    """Chemin d'une mèche : collée au crâne le long des clés (theta, phi, décollement), puis libre le long de `tail`
    (décalages successifs en rayons de tête, repère monde), courbe douce."""
    r = g["head_r"]
    pts = [surface(g, th, ph, lf) for th, ph, lf in _catmull(keys, n)]
    if tail:
        cur = pts[-1]
        free = [cur]
        for off in tail:
            cur = cur + Vector(off) * r
            free.append(cur)
        smooth = _catmull([tuple(p) for p in free], len(tail) * tail_n + 1)
        pts += [Vector(p) for p in smooth[1:]]
    return pts


def widths(n, w0, wmax, peak=0.3, tip=0.02):
    """Largeur le long d'une mèche : w0 à la racine, wmax vers `peak`, presque rien au bout."""
    out = []
    for i in range(n):
        u = i / (n - 1)
        if u < peak:
            out.append(w0 + (wmax - w0) * (u / peak))
        else:
            k = (u - peak) / (1 - peak)
            out.append(wmax * (1 - k) ** 1.4 + tip * wmax * k)
    return out


def strand(w, g, keys, w0, wmax, tail=(), n=8, flat=0.5, peak=0.3, cell="hair_brown", shade=False, axis=None):
    """Pose une mèche sur la tête (Head_Hair, ou Head_HairShade si shade)."""
    c, _ = head_frame(g)
    pts = flow(g, keys, n, tail)
    bm = clump(pts, widths(len(pts), w0 * g["head_r"], wmax * g["head_r"], peak), flat, 6, c, axis)
    if shade:
        obj = w.b.make(bm, cell, None)
        w.current.setdefault("Head_" + SHADE, []).append(obj)
    else:
        w.make("Head", bm, cell)


def shade_cap(w, g, m, low, cell):
    """Calotte de la sous-couche (assombrie) : on la voit entre les mèches, comme une ombre."""
    obj = w.b.make(cap(g, m, low=low), cell, None)
    w.current.setdefault("Head_" + SHADE, []).append(obj)


def helix(g, root, normal, length, radius, turns, n=12):
    """Boucle en tire-bouchon qui part de root le long de normal."""
    nrm = Vector(normal).normalized()
    e1 = nrm.orthogonal().normalized()
    e2 = nrm.cross(e1).normalized()
    pts = []
    for i in range(n):
        u = i / (n - 1)
        a = u * turns * 2 * math.pi
        rad = radius * (0.4 + 0.6 * math.sin(min(1, u * 1.6) * math.pi / 2)) * (1 - 0.3 * u)
        pts.append(Vector(root) + nrm * length * u + (e1 * math.cos(a) + e2 * math.sin(a)) * rad)
    return pts


# ------------------------------------------------------------------ les coupes
def build_hair(w, g):
    r = g["head_r"]
    c, _ = head_frame(g)

    # -------- Banane : une immense vague dorée qui part de la couronne, monte au-dessus du front et s'enroule
    w.start("Banana")
    shade_cap(w, g, 1.05, 5, "hair_yellow")
    for k in range(-4, 5):                                            # la vague : grosses mèches serrées
        size = 1 - abs(k) * 0.06
        th = k * 9
        strand(w, g, [(th * 1.3, 130, 0.05), (th * 1.1, 100, 0.3 * size), (th, 70, 0.72 * size), (th * 0.9, 48, 1.0 * size)],
               0.3, 0.42, tail=[(0, -0.3 * size, 0.1), (0, -0.14, -0.1 * size)],
               n=10, flat=0.55, peak=0.4, cell="hair_yellow")
    for k in range(-4, 5):                                            # dessous de la vague (plus sombre) : pas de vide
        th = k * 9
        strand(w, g, [(th * 1.2, 110, 0.05), (th, 75, 0.35), (th * 0.9, 50, 0.55), (th * 0.9, 38, 0.45)],
               0.34, 0.44, n=8, flat=0.7, peak=0.5, cell="hair_yellow", shade=True)
    for k in range(-3, 4):                                            # 2e couche : arêtes sur le dessus de la vague
        th = k * 10 + 4
        strand(w, g, [(th, 110, 0.38), (th * 0.9, 80, 0.88), (th * 0.85, 56, 1.12)],
               0.1, 0.16, tail=[(0, -0.22, 0.08)], n=7, flat=0.4, cell="hair_yellow")
    for sx in (-1, 1):                                                # côtés plaqués vers l'arrière, peigne bien net
        for k in range(4):
            th = sx * (55 + k * 22)
            strand(w, g, [(th, 40 + k * 4, 0.06), (th + sx * 40, 32, 0.08), (th + sx * 70, 30, 0.06)],
                   0.16, 0.2, tail=[(0, 0.12, 0.02)], n=6, flat=0.35, cell="hair_yellow")
    for th in range(150, 211, 20):                                    # nuque courte
        strand(w, g, [(th, 80, 0.08), (th, 40, 0.08), (th, 10, 0.05)], 0.2, 0.24, n=6, flat=0.4, cell="hair_yellow")

    # -------- Mulet : dessus court en pointes ébouriffées, cascade de grosses mèches qui s'envolent sur les épaules
    w.start("Mullet")
    shade_cap(w, g, 1.05, 0, "hair_brown")
    golden = math.pi * (3 - math.sqrt(5))
    for i in range(16):                                               # pointes du dessus, vers l'arrière et le haut
        phi = 100 - i * 3.2
        th = math.degrees(i * golden) % 140 - 70
        nrm = normal_at(g, th, phi)
        strand(w, g, [(th, phi + 15, 0.05), (th, phi, 0.18)], 0.16, 0.2,
               tail=[tuple(nrm * 0.22 + BACK * 0.18)], n=4, flat=0.5, peak=0.2, cell="hair_brown")
    for k in range(-2, 3):                                            # mèches du front, relevées
        th = k * 15
        strand(w, g, [(th, 40, 0.05), (th, 58, 0.25)], 0.15, 0.2, tail=[(0, -0.05, 0.25), (0, 0.1, 0.12)], n=4,
               flat=0.5, cell="hair_brown")
    for i, th in enumerate(range(105, 256, 15)):                      # la cascade dans le dos
        sx = math.sin(math.radians(th))
        long = 1.0 + 0.35 * (1 - abs(th - 180) / 75)
        strand(w, g, [(th, 70, 0.08), (th, 30, 0.12), (th, -5, 0.14)], 0.26, 0.32,
               tail=[(sx * 0.1, 0.15, -0.5 * long), (sx * 0.15, 0.2, -0.45 * long), (sx * 0.25, 0.25, 0.05)],
               n=6, flat=0.45, cell="hair_brown")
        if i % 2:
            strand(w, g, [(th + 7, 60, 0.18), (th + 7, 20, 0.2), (th + 7, -10, 0.2)], 0.14, 0.2,
                   tail=[(sx * 0.12, 0.25, -0.55 * long), (sx * 0.25, 0.3, 0.1)], n=5, flat=0.4, cell="hair_brown")
    for sx in (-1, 1):                                                # côtés : mèches courtes vers l'arrière
        for k in range(3):
            th = sx * (60 + k * 18)
            strand(w, g, [(th, 50, 0.06), (th + sx * 25, 25, 0.08)], 0.16, 0.2, tail=[(0, 0.15, -0.05)], n=5,
                   flat=0.4, cell="hair_brown")

    # -------- Crête : crâne rasé, grandes lames tranchantes du front à la nuque, dégradé sur les côtés
    w.start("Mohawk")
    w.make("Head", cap(g, 1.02, low=-5), "bald")
    for i in range(9):
        u = i / 8
        phi = 45 + u * 125
        height = 0.7 + 0.6 * math.sin(math.pi * min(1, u * 1.1))
        nrm = normal_at(g, 0, phi)
        lean = nrm * height + BACK * 0.35 * height
        strand(w, g, [(0, phi - 6, 0.0), (0, phi, 0.05)], 0.3, 0.32, tail=[tuple(lean * 0.55), tuple(lean * 0.45)],
               n=3, flat=0.28, peak=0.15, cell="hair_pink", axis=(1, 0, 0))
    strand(w, g, [(0, 40, 0.02), (0, 95, 0.06), (0, 160, 0.04), (0, 185, 0.02)], 0.28, 0.3, n=10, flat=0.3,
           cell="hair_pink", shade=True)                              # bande de départ, plus sombre
    for sx in (-1, 1):                                                # dégradé : traits courts plaqués
        for k in range(5):
            th = sx * 22
            phi = 50 + k * 26
            strand(w, g, [(th, phi, 0.01), (th + sx * 12, phi - 6, 0.015)], 0.08, 0.1, n=4, flat=0.3,
                   cell="hair_pink", shade=True)

    # -------- Crâne lustré : dôme rasé (couleur de peau), reflet en étoile
    w.start("ShinyBald")
    w.make("Head", cap(g, 1.03, low=-10), "bald")
    shine = surface(g, 25, 58, 0.05)
    nrm = normal_at(g, 25, 58)
    side = nrm.cross(UP).normalized()
    for d in (side, nrm.cross(side).normalized()):
        w.make("Head", clump([shine - d * r * 0.24, shine, shine + d * r * 0.24], [r * 0.02, r * 0.06, r * 0.02], 0.25,
                             4, c), "white")
    w.make("Head", lowsphere(tuple(surface(g, 40, 45, 0.04)), (r * 0.05, r * 0.05, r * 0.05), 6, 4), "white")

    # -------- Boucles (départ) : une masse de vrais tire-bouchons, du sommet jusqu'à la nuque, frange bouclée
    w.start("Curly")
    shade_cap(w, g, 1.06, -5, "hair_brown")
    for i in range(46):
        z = 1 - (i + 0.5) / 46 * 1.2
        phi = math.degrees(math.asin(max(-0.35, min(1, z))))
        th = math.degrees(i * golden) % 360 - 180
        if abs(th) < 42 and phi < 35:
            continue
        root = surface(g, th, phi, 0.06)
        nrm = (root - c).normalized()
        if phi < 20:
            nrm = (nrm + Vector((0, 0, -0.9))).normalized()            # les boucles du bas retombent
        length = r * (0.32 + 0.08 * ((i * 7) % 3))
        pts = helix(g, root, nrm, length * 0.85, r * 0.07, 1.1 + 0.2 * (i % 3), 9)
        w.make("Head", clump(pts, widths(len(pts), r * 0.16, r * 0.17, 0.4, 0.45), 0.95, 6, c), "hair_brown")
    for k in range(-3, 4):                                            # boucles du front
        th = k * 12
        root = surface(g, th, 52, 0.08)
        pts = helix(g, root, (normal_at(g, th, 52) + Vector((0, -0.4, -0.7))).normalized(), r * 0.26, r * 0.06, 1.2, 9)
        w.make("Head", clump(pts, widths(len(pts), r * 0.13, r * 0.14, 0.4, 0.45), 0.95, 6, c), "hair_brown")

    # -------- Cheveux longs (départ) : raie au milieu, mèches qui coulent le long du visage jusqu'aux épaules
    w.start("LongHair")
    shade_cap(w, g, 1.05, -5, "hair_brown")
    for sx in (-1, 1):
        for k in range(6):                                            # de la raie vers les côtés, puis vers le bas
            phi0 = 62 + k * 10
            th1 = sx * (45 + k * 14)
            strand(w, g, [(sx * 4, phi0, 0.04), (sx * 30 + th1 * 0.3, phi0 - 15, 0.1), (th1, 25, 0.14), (th1, -10, 0.15)],
                   0.2, 0.28, tail=[(sx * 0.08, 0.05, -0.55), (sx * 0.12, 0.05, -0.55), (sx * 0.22, -0.02, -0.12)],
                   n=9, flat=0.45, cell="hair_brown")
        strand(w, g, [(sx * 6, 66, 0.12), (sx * 30, 45, 0.16), (sx * 42, 15, 0.16)], 0.16, 0.24,
               tail=[(sx * 0.02, -0.06, -0.55), (-sx * 0.08, -0.05, -0.45)], n=7, flat=0.45, cell="hair_brown")
    for th in range(130, 231, 14):                                    # le dos, jusqu'aux omoplates
        sx = math.sin(math.radians(th))
        strand(w, g, [(th, 92, 0.06), (th, 45, 0.12), (th, 0, 0.16)], 0.26, 0.32,
               tail=[(sx * 0.05, 0.12, -0.7), (sx * 0.08, 0.12, -0.6), (sx * 0.12, 0.2, -0.1)], n=7, flat=0.4,
               cell="hair_brown")

    # -------- Chignon (départ) : cheveux tirés en mèches nettes vers un gros chignon torsadé, deux mèches libres
    w.start("Bun")
    shade_cap(w, g, 1.04, 0, "hair_brown")
    top = surface(g, 180, 100, 0.25)
    for th in range(-150, 181, 30):                                   # mèches tirées vers le chignon
        strand(w, g, [(th, 15 if abs(th) > 40 else 45, 0.05), (th, 60, 0.08), (th, 88, 0.12)], 0.18, 0.22, n=7, flat=0.3, cell="hair_brown")
    for k in range(5):                                                # le chignon : mèches enroulées
        pts = []
        for i in range(12):
            a = k * 2 * math.pi / 5 + i / 11 * 1.6 * math.pi
            rad = r * 0.38 * (1 - 0.4 * i / 11)
            pts.append(top + Vector((math.cos(a) * rad, math.sin(a) * rad, r * (0.05 + 0.28 * i / 11))))
        w.make("Head", clump(pts, widths(12, r * 0.15, r * 0.18, 0.2, 0.2), 0.7, 6, top), "hair_brown")
    w.make("Head", ring(tuple(top - UP * r * 0.02), r * 0.36, 0.06, r * 0.1, 12), "red")
    for sx in (-1, 1):
        strand(w, g, [(sx * 35, 50, 0.08), (sx * 48, 25, 0.1)], 0.08, 0.1,
               tail=[(sx * 0.05, -0.08, -0.35), (-sx * 0.04, -0.05, -0.3)], n=5, flat=0.5, cell="hair_brown")

    # -------- Carré (départ) : volume arrondi, pointes rentrées sous la mâchoire, frange épaisse en mèches
    w.start("Bob")
    shade_cap(w, g, 1.08, 0, "hair_brown")
    for th in range(45, 316, 15):
        sx = math.sin(math.radians(th))
        cx = math.cos(math.radians(th))
        strand(w, g, [(th, 88, 0.08), (th, 45, 0.22), (th, 5, 0.28)], 0.24, 0.3,
               tail=[(sx * 0.02, -cx * 0.02, -0.45), (-sx * 0.12, cx * 0.12, -0.12)], n=7, flat=0.45, cell="hair_brown")
    for k in range(-3, 4):                                            # frange
        th = k * 11
        strand(w, g, [(th * 0.5, 95, 0.1), (th, 62, 0.2), (th, 42, 0.22)], 0.2, 0.24, tail=[(0, -0.06, -0.12)], n=6,
               flat=0.45, cell="hair_brown")

    # -------- Pompadour : un vrai rouleau gominé, haut devant, qui part en arrière ; côtés plaqués et mèche rebelle
    w.start("Pompadour")
    shade_cap(w, g, 1.05, 5, "hair_black")
    for k in range(-4, 5):                                            # le rouleau : de la racine du front vers l'arrière
        th = k * 9
        size = 1 - abs(k) * 0.08
        strand(w, g, [(th, 36, 0.06), (th, 46, 0.5 * size), (th, 62, 0.82 * size), (th * 1.1, 92, 0.72 * size),
                      (th * 1.2, 125, 0.42 * size), (th * 1.2, 158, 0.08)], 0.3, 0.4, n=13, flat=0.5, peak=0.4,
               cell="hair_black")
    for k in range(-3, 4):                                            # la vague du devant, qui roule vers l'avant
        th = k * 10
        size = 1 - abs(k) * 0.08
        strand(w, g, [(th, 42, 0.25 * size), (th, 55, 0.8 * size)], 0.22, 0.3,
               tail=[(0, -0.2 * size, 0.18), (0, 0.05, 0.2 * size), (0, 0.28, 0.02)], n=4, flat=0.5,
               cell="hair_black")
    for k in range(-3, 4):                                            # crêtes de peigne sur le dessus
        th = k * 10 + 4
        strand(w, g, [(th, 50, 0.76), (th, 80, 0.8), (th, 115, 0.45)], 0.06, 0.08, n=7, flat=0.4, cell="hair_black")
    for sx in (-1, 1):                                                # côtés : traits de peigne vers l'arrière
        for k in range(4):
            th = sx * (60 + k * 20)
            strand(w, g, [(th, 45 + k * 3, 0.06), (th + sx * 35, 38, 0.07), (th + sx * 70, 30, 0.06)], 0.12, 0.15,
                   n=6, flat=0.3, cell="hair_black")
    strand(w, g, [(8, 55, 0.58), (10, 45, 0.5)], 0.08, 0.1, tail=[(0.05, -0.18, -0.25), (0.02, -0.05, -0.3)], n=5,
           flat=0.5, cell="hair_black")                               # mèche rebelle sur le front

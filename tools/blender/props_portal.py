"""
Portail du Colisée (D105) : remplace les piliers de lumière entre le temple du Dieu du Pump et le parvis du Colisée.
Modèle choisi par Antoine : arche gothique en ogive sur deux gros piliers carrés gravés, une colonne torsadée dans
l'arche, un bouclier rond sur un pilier, des marches devant et derrière. Couleurs du Colisée (grès en
blocs alternés, marbre blanc, or) : aucune case de palette nouvelle, la texture déjà sur Roblox sert telle quelle.
Le tourbillon doré dans l'arche est joué dans le jeu (ColosseumController), pas dans le modèle.

Repère : Z vers le haut, 1 unité = 1 stud, l'ouverture regarde vers -Y (on passe dans l'arche le long de Y).
À exécuter après props_lib.py et props_colosseum.py (SANDSTONE, stone) : build_portal(P), voir export_portal.py.
"""

PORTAL = {
    "opening": 7.6,  # largeur de passage entre les piliers
    "spring": 9.0,  # hauteur où l'arche commence à se courber
    "pillar": 3.2,  # côté des piliers carrés
    "depth": 3.4,  # épaisseur de l'arche (le long de Y)
    "base_z": 1.2,  # dessus de l'estrade (deux marches)
}


def voussoir(e, r0, r1, a0, a1, y0, y1, cx):
    """Claveau : morceau d'anneau entre les rayons r0..r1 et les angles a0..a1 (radians, autour de (cx, e) dans le
    plan XZ), épais de y0 à y1."""
    bm = bmesh.new()
    pts = []
    for a in (a0, a1):
        for r in (r0, r1):
            pts.append((cx + math.cos(a) * r, e + math.sin(a) * r))
    vs = [[bm.verts.new((x, y, z)) for (x, z) in pts] for y in (y0, y1)]
    f, b = vs
    # pts : (a0,r0) (a0,r1) (a1,r0) (a1,r1)
    for quad in ((0, 1, 3, 2),):
        bm.faces.new([f[i] for i in quad])
        bm.faces.new([b[i] for i in reversed(quad)])
    for i, j in ((0, 1), (1, 3), (3, 2), (2, 0)):
        bm.faces.new((f[i], f[j], b[j], b[i]))
    return _finish(bm)


OGIVE = 1.7  # rayon des arcs = 1,7 x la demi-ouverture (plus grand : arche plus pointue)


def ogive_apex(half, spring, radius):
    """Hauteur où l'arc de rayon `radius` (même centre que l'ouverture) croise l'axe."""
    c = half * OGIVE - half
    return spring + math.sqrt(radius * radius - c * c)


def ogive_side(sx, half, spring, r0, r1, y0, y1, count, colors, offset=0):
    """Moitié d'arche en ogive (côté sx = -1 gauche, 1 droite) entre les rayons r0..r1, découpée en `count` claveaux
    aux teintes alternées. Les arcs sont centrés de l'autre côté de l'axe (à half x (OGIVE - 1)) : les deux moitiés
    se rejoignent en pointe, et tous les anneaux ont le même centre (ils s'emboîtent sans jour)."""
    c = half * OGIVE - half
    cx = -sx * c
    start = 0.0 if sx > 0 else math.pi
    out = []
    for i in range(count):
        # la pointe de chaque anneau est là où son arc extérieur croise l'axe : on coupe le dernier claveau à x = 0
        tip0 = math.acos(-cx / r0)
        a0 = start + (tip0 - start) * i / count
        a1 = start + (tip0 - start) * (i + 1) / count
        out.append((voussoir(spring, r0, r1, a0, a1, y0, y1, cx), colors[(i + offset) % len(colors)]))
    return out


def twisted_column(x, y, z0, height, size=0.7, steps=14):
    """Colonne torsadée : des blocs carrés empilés, chacun tourné un peu plus que le précédent (une vis)."""
    parts = []
    h = height / steps
    for i in range(steps):
        bm = box((0, 0, z0 + h * i + h / 2), (size, size, h * 1.02), bevel=0.06)
        rotate(bm, i * 22, "Z")
        move(bm, (x, y, 0))
        parts.append((bm, "marblew" if i % 2 == 0 else "marbleshade"))
    return parts


def carved_panel(x, y_face, z, w, h, depth=0.12):
    """Panneau gravé sur la face avant d'un pilier : cadre en creux et nœud géométrique (croix et losanges), sans
    texte."""
    parts = []
    parts.append((box((x, y_face - depth / 2, z), (w, depth, h)), "sanddark"))
    parts.append((box((x, y_face - depth - 0.04, z), (w * 0.16, 0.08, h * 0.86)), "marbleshade"))
    parts.append((box((x, y_face - depth - 0.04, z), (w * 0.8, 0.08, h * 0.12)), "marbleshade"))
    for dz in (-h * 0.28, h * 0.28):
        d = box((x, y_face - depth - 0.06, z + dz), (w * 0.34, 0.08, w * 0.34))
        rotate(d, 45, "Y", center=(x, y_face, z + dz))
        parts.append((d, "bannergold"))
    return parts


def pillar(sx, half, P_, depth, base_z, spring):
    """Gros pilier carré : socle chanfreiné, fût en blocs de grès alternés, panneaux gravés, chapiteau à corniche
    crénelée."""
    parts = []
    w = P_
    x = sx * (half + w / 2)
    # socle
    parts.append((box((x, 0, base_z + 0.5), (w + 0.7, depth + 0.7, 1.0), bevel=0.12), "marbleshade"))
    parts.append((box((x, 0, base_z + 1.25), (w + 0.35, depth + 0.35, 0.5), bevel=0.06, taper=0.9), "marblew"))
    # fût : assises de blocs (hauteur 1.25), décalées d'une assise à l'autre
    z = base_z + 1.5
    rows = int((spring - 1.5 - 1.2) // 1.25)
    for i in range(rows):
        parts.append((box((x, 0, z + 0.625), (w, depth, 1.23), bevel=0.05), stone(i, sx + 2)))
        z += 1.25
    top = z
    # panneaux gravés sur l'avant et l'arrière
    for face in (-1, 1):
        y_face = -depth / 2  # construit devant, retourné en miroir pour l'arrière
        for p in carved_panel(x, y_face, base_z + 1.5 + (top - base_z - 1.5) * 0.62, w * 0.62, 3.2):
            bm, col = p
            if face > 0:
                scale(bm, (1, -1, 1), center=(x, 0, 0))
                bmesh.ops.reverse_faces(bm, faces=bm.faces)
            parts.append((bm, col))
        for p in carved_panel(x, y_face, base_z + 2.9, w * 0.5, 1.6):
            bm, col = p
            if face > 0:
                scale(bm, (1, -1, 1), center=(x, 0, 0))
                bmesh.ops.reverse_faces(bm, faces=bm.faces)
            parts.append((bm, col))
    # chapiteau : bandeau de marbre, corniche débordante, créneaux
    parts.append((box((x, 0, top + 0.3), (w + 0.4, depth + 0.4, 0.6), bevel=0.05), "marblew"))
    parts.append((box((x, 0, top + 0.95), (w + 0.9, depth + 0.9, 0.7), bevel=0.08, taper=1.12), "marbleshade"))
    for ix in (-1, 0, 1):
        for iy in (-1, 1):
            parts.append((box((x + ix * (w + 0.5) / 3, iy * (depth + 0.5) / 2.6, top + 1.55), (0.6, 0.6, 0.5),
                              bevel=0.05), "marblew"))
    return parts, top + 1.3


def shield(x, y_face, z, r=1.05):
    """Bouclier rond doré avec umbo et rivets (sur l'avant d'un pilier)."""
    parts = []
    parts.append((cylinder((x, y_face, z), r, 0.22, 12, axis="Y"), "bronzew"))
    parts.append((torus((x, y_face - 0.24, z), r * 0.92, 0.09, 12, 4, axis="Y"), "bannergold"))
    parts.append((torus((x, y_face - 0.24, z), r * 0.5, 0.07, 10, 4, axis="Y"), "bannergold"))
    parts.append((sphere((x, y_face - 0.28, z), (0.32, 0.3, 0.32), 8, 5), "bannergold"))
    for k in range(6):
        a = math.radians(k * 60)
        parts.append((sphere((x + math.cos(a) * r * 0.72, y_face - 0.26, z + math.sin(a) * r * 0.72),
                             (0.09, 0.08, 0.09), 4, 3), "bannergold"))
    return parts


def build_portal(P):
    G = PORTAL
    half = G["opening"] / 2
    depth = G["depth"]
    base_z = G["base_z"]
    pw = G["pillar"]
    parts = []

    # Estrade : dalle irrégulière (deux niveaux), deux marches devant et derrière
    outer = half + pw + 1.4
    parts.append((box((0, 0, 0.35), (outer * 2 + 1.2, depth + 6.4, 0.7), bevel=0.1), "marbleshade"))
    parts.append((box((0, 0, 0.95), (outer * 2, depth + 3.6, 0.5), bevel=0.08), "marblew"))
    for face in (-1, 1):
        parts.append((box((0, face * (depth / 2 + 2.3), 0.85), (G["opening"] + 1.6, 1.0, 0.3), bevel=0.05),
                      "marblew"))
    # dalles du passage (alternées)
    for i in range(4):
        parts.append((box((0, -depth / 2 + depth * (i + 0.5) / 4, base_z + 0.03), (G["opening"] - 0.2,
                                                                                 depth / 4 - 0.08, 0.06)),
                      stone(i)))

    # Piliers
    tops = []
    for sx in (-1, 1):
        p, top = pillar(sx, half, pw, depth, base_z, G["spring"])
        parts += p
        tops.append(top)
    spring = max(tops) - 0.2

    # Bouclier sur le pilier de droite (face avant), colonne torsadée contre le pilier de gauche, dans l'arche
    parts += shield(half + pw / 2, -depth / 2 - 0.05, base_z + 4.2)
    parts += twisted_column(-half + 0.55, -depth / 2 + 0.55, base_z + 1.5, spring - base_z - 1.5)
    parts.append((box((-half + 0.55, -depth / 2 + 0.55, base_z + 1.3), (1.0, 1.0, 0.4), bevel=0.05), "marblew"))
    parts.append((box((-half + 0.55, -depth / 2 + 0.55, spring + 0.15), (1.0, 1.0, 0.35), bevel=0.05), "marblew"))

    # Arche en ogive : cintre intérieur de marbre (fin), claveaux de grès, clé de voûte dorée, remplissage au-dessus
    y0, y1 = -depth / 2, depth / 2
    r_in = half * OGIVE
    for sx in (-1, 1):
        parts += ogive_side(sx, half, spring, r_in, r_in + 0.45, y0 - 0.15, y1 + 0.15, 6, ("marblew",))
        parts += ogive_side(sx, half, spring, r_in + 0.45, r_in + 1.95, y0, y1, 7, SANDSTONE, offset=sx + 2)
    apex = ogive_apex(half, spring, r_in + 1.95)
    parts.append((box((0, 0, apex + 0.55), (1.3, depth + 0.5, 1.7), bevel=0.08, taper=1.25), "bannergold"))
    # tympan : mur plein entre l'ogive et le haut des piliers, à côté de la pointe (en blocs)
    for sx in (-1, 1):
        x = sx * (half + pw / 2 + 0.1)
        parts.append((box((x, 0, spring + 1.1), (pw + 0.2, depth, 2.2)), stone(sx + 3)))
        parts.append((box((sx * (half + 0.9), 0, spring + 3.1), (2.6, depth, 1.8)), stone(sx + 4)))
    # Pas de décor dans l'ouverture (le tourbillon doré du jeu la remplit), ni autour : le modèle reste centré sur
    # son ouverture (le jeu y pose le tourbillon au centre du repère)

    P.prop("Colosseum_Portal", parts)
    print("ouverture : largeur", G["opening"], "bas", base_z, "naissance", round(spring, 3), "pointe", round(ogive_apex(half, spring, half * OGIVE), 3), "repère", P.meta["Colosseum_Portal"])

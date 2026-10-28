"""
Le Colisée du Pump (D89, tranche 1) : arène gréco-romaine du dernier boss, au-delà du coin sud-ouest de la ville.
Style des images d'Antoine : grès chaud en blocs, bordures de marbre blanc, auvents rouges, étendards, piste de sable
entourée d'un haut mur, gradins et façade à deux étages d'arches. Low poly, palette commune (props_lib.py) :
les blocs de pierre sont des volumes séparés aux teintes alternées (jamais de motif étiré sur une grande surface).

Repère de conception : centre de l'arène à l'origine, z = 0 = dessus du podium = sol de la piste, l'entrée des
spectateurs vers -Y (vers la ville). Les pièces « secteur » couvrent 30 degrés, centrées sur -Y : la carte
(tools/build_map.py) les pose 12 fois en les tournant autour du centre. Toutes les cotes sont dans LAYOUT, partagé avec
la carte (positions des collisions, des points de départ) via colosseum_manifest.json.

À exécuter après props_lib.py : build_colosseum(Props(pal, "Props_Colosseum", ...)), voir export_colosseum.py.
"""

LAYOUT = {
    "sector": 30.0,  # degrés par secteur (12 secteurs)
    "pit_radius": 44.0,  # piste de sable
    "wall_outer": 46.5,  # mur de la piste (de pit_radius à wall_outer)
    "wall_height": 9.0,
    "walk_outer": 53.0,  # coursive au-dessus du mur
    "walk_top": 9.8,
    "tiers": 10,
    "tier_depth": 2.2,
    "tier_rise": 1.5,
    "stand_outer": 75.0,  # fin des gradins = mur extérieur
    "facade_outer": 78.5,
    "facade_height": 38.0,
    "plaza_outer": 96.0,  # parvis autour de l'arène
    "podium": 3.0,  # le tout est posé sur un podium de 3 studs (marches vers l'herbe)
    "aisle_width": 3.2,  # escaliers de marbre au milieu de chaque secteur
    "entrance_width": 10.0,  # grand escalier d'entrée (secteur 0)
    "gate_width": 9.0,  # portes de la piste (gladiateurs, boss)
    "gate_height": 7.0,
    "fighter_gate": 3,  # secteur de la porte des gladiateurs (90 degrés)
    "boss_gate": 9,
    "tribune": 6,  # tribune d'honneur, face à l'entrée
}

L = LAYOUT
SANDSTONE = ("sand1", "sand2", "sand3")


def colosseum_palette(pal):
    """Cases propres au colisée (ajoutées à la fin de la palette commune : les autres décors ne bougent pas)."""
    pal.color("sand1", "d8b07a", 0.025)
    pal.color("sand2", "cfa56c", 0.025)
    pal.color("sand3", "e2bd88", 0.025)
    pal.color("sanddark", "a77c4c", 0.02)
    pal.color("sandshadow", "6e4e32", 0.02)
    pal.color("arena", "e9cf9a", 0.03)
    pal.color("arenadark", "d6b77e", 0.03)
    pal.color("arenapebble", "b8996a", 0.02)
    pal.color("marblew", "f4f1ea", 0.015)
    pal.color("marbleshade", "dcd6ca", 0.015)
    pal.color("velum", "b4302a", 0.02)
    pal.color("velumdark", "8a2420", 0.02)
    pal.color("bannergold", "e8b83a", 0.02)
    pal.color("bronzew", "a86c34", 0.02)
    pal.color("bronzedark", "6e4422", 0.02)
    pal.color("tunnel", "2c2018", 0.01)
    pal.color("torchfire", "ffb43a", 0.01)
    for name, hexa in (("toga1", "f2ece0"), ("toga2", "d9483e"), ("toga3", "4f78c8"), ("toga4", "e6c04a"),
                       ("toga5", "6aa65a"), ("toga6", "a85ab4"), ("crowdskin1", "e8b48c"), ("crowdskin2", "a87250"),
                       ("crowdskin3", "c98e62"), ("crowdhair", "3a2a20")):
        pal.color(name, hexa, 0.02)


# ------------------------------------------------------------------ outils géométriques
def _rad(deg):
    return math.radians(deg)


def arc(r0, r1, a0, a1, z0, z1, segs=4):
    """Bloc courbe (portion d'anneau) entre les rayons r0..r1, les angles a0..a1 (degrés) et les hauteurs z0..z1."""
    bm = bmesh.new()
    inner_b, inner_t, outer_b, outer_t = [], [], [], []
    for i in range(segs + 1):
        a = _rad(a0 + (a1 - a0) * i / segs)
        c, s = math.cos(a), math.sin(a)
        inner_b.append(bm.verts.new((c * r0, s * r0, z0)))
        inner_t.append(bm.verts.new((c * r0, s * r0, z1)))
        outer_b.append(bm.verts.new((c * r1, s * r1, z0)))
        outer_t.append(bm.verts.new((c * r1, s * r1, z1)))
    for i in range(segs):
        j = i + 1
        bm.faces.new((inner_t[i], inner_t[j], outer_t[j], outer_t[i]))  # dessus
        bm.faces.new((inner_b[i], outer_b[i], outer_b[j], inner_b[j]))  # dessous
        bm.faces.new((inner_b[i], inner_b[j], inner_t[j], inner_t[i]))  # face intérieure
        bm.faces.new((outer_b[i], outer_t[i], outer_t[j], outer_b[j]))  # face extérieure
    bm.faces.new((inner_b[0], inner_t[0], outer_t[0], outer_b[0]))
    bm.faces.new((inner_b[-1], outer_b[-1], outer_t[-1], inner_t[-1]))
    return _finish(bm)


def polar(r, deg, z=0.0):
    a = _rad(deg)
    return (math.cos(a) * r, math.sin(a) * r, z)


def facing(bm, deg):
    """Tourne une pièce construite face à -Y pour qu'elle regarde vers l'extérieur à l'angle `deg`."""
    return rotate(bm, deg + 90, "Z")


def stone(i, j=0):
    return SANDSTONE[(i * 2 + j) % 3]


def arch_profile(width, spring, top, segs=8):
    """Profil d'un mur percé d'une arche (x, z) : piédroits jusqu'à `spring`, cintre en demi-cercle, haut à `top`."""
    half = width / 2
    pts = [(-half, top), (-half, spring)]
    for i in range(1, segs):
        a = math.pi - math.pi * i / segs
        pts.append((math.cos(a) * half, spring + math.sin(a) * half))
    pts.append((half, spring))
    pts.append((half, top))
    return pts


def arch_frame(width, spring, depth, thick=0.5, segs=8):
    """Cintre de marbre (anneau en demi-cercle) devant une arche, épaisseur `depth` le long de Y."""
    half = width / 2
    outer = [(math.cos(math.pi - math.pi * i / segs) * (half + thick),
              spring + math.sin(math.pi - math.pi * i / segs) * (half + thick)) for i in range(segs + 1)]
    inner = [(math.cos(math.pi * i / segs) * half, spring + math.sin(math.pi * i / segs) * half)
             for i in range(segs + 1)]
    return outer + inner


def bay_wall(width, height, spring, depth, arch_w, color, frame="marblew"):
    """Travée de façade : un mur plat (repère local x le long du mur, y = épaisseur vers -Y) percé d'une arche."""
    parts = []
    prof = arch_profile(arch_w, spring, height)
    half = width / 2
    side = (half - arch_w / 2)
    parts.append((box((-(arch_w / 2 + side / 2), -depth / 2, spring / 2), (side, depth, spring)), color))
    parts.append((box(((arch_w / 2 + side / 2), -depth / 2, spring / 2), (side, depth, spring)), color))
    top = extrude(prof, depth, y0=-depth)
    parts.append((top, color))
    ring = extrude(arch_frame(arch_w, spring, 0.4), 0.4, y0=-depth - 0.25)
    parts.append((ring, frame))
    return parts


def place_planar(parts, r, deg):
    """Pose des pièces construites à plat (repère : x le long du mur, -Y vers l'extérieur) au rayon r, angle deg."""
    out = []
    for bm, spec in parts:
        move(bm, (0, -r, 0))
        rotate(bm, deg + 90, "Z")
        out.append((bm, spec))
    return out


# ------------------------------------------------------------------ la piste
def colosseum_floor(P):
    """Piste de sable : disque, anneaux ratissés plus sombres, cailloux, médaillon central (soleil doré, haltère)."""
    R = L["pit_radius"]
    parts = [(cylinder((0, 0, -0.6), R + 0.2, 0.6, 48), "arena")]
    # Anneaux ratissés (à peine plus sombres, à fleur de sable)
    for k, (r0, r1) in enumerate(((14, 16), (27, 29.5), (38, 40))):
        for s in range(12):
            a0 = s * 30 + (k * 11) % 30
            parts.append((arc(r0, r1, a0, a0 + 18, -0.58, 0.02, 3), "arenadark"))
    rnd = random.Random(41)
    for _ in range(60):
        r = math.sqrt(rnd.random()) * (R - 3) + 1
        a = rnd.uniform(0, 360)
        x, y, _ = polar(r, a)
        parts.append((ico((x, y, 0.02), rnd.uniform(0.18, 0.45), 1, 0.3, rnd.randint(1, 999), 0.5), "arenapebble"))
    # Médaillon : anneau de marbre, soleil doré à 12 rayons, haltère au centre
    parts.append((cylinder((0, 0, -0.1), 9.5, 0.16, 32), "marblew"))
    parts.append((cylinder((0, 0, -0.08), 8.6, 0.16, 32), "velum"))
    parts.append((cylinder((0, 0, -0.06), 4.2, 0.16, 24), "bannergold"))
    for k in range(12):
        ray = extrude([(-0.7, 0), (0.7, 0), (0, 3.6)], 0.16, y0=-0.08)
        rotate(ray, 90, "X")  # le triangle se couche sur le sol, pointe vers -Y
        move(ray, (0, -4.0, 0.0))
        rotate(ray, k * 30, "Z")
        parts.append((ray, "bannergold"))
    parts.append((cylinder((-1.9, 0, 0.1), 0.9, 0.5, 10, axis="X"), "bronzedark"))
    parts.append((cylinder((1.4, 0, 0.1), 0.9, 0.5, 10, axis="X"), "bronzedark"))
    parts.append((cylinder((-1.4, 0, 0.35), 0.2, 2.8, 6, axis="X"), "bronzew"))
    P.prop("Colosseum_Floor", parts)


def pit_wall(P, gate=False):
    """Mur de la piste sur un secteur : 3 assises de blocs de grès aux joints décalés, socle sombre, pilastres de
    marbre, chaperon de marbre, boucliers de bronze. Variante porte : arche de 9 studs au milieu, encadrement de
    marbre, clé de voûte dorée, fond sombre (la herse est une pièce à part, animée par le jeu)."""
    r0, r1, H = L["pit_radius"], L["wall_outer"], L["wall_height"]
    half = L["sector"] / 2
    a0, a1 = -90 - half, -90 + half
    w, gh = L["gate_width"], L["gate_height"]
    gap = math.degrees((w / 2) / r0) if gate else 0.0
    parts = []
    rows = 3
    for row in range(rows):
        z0, z1 = H * row / rows, H * (row + 1) / rows
        blocks = 4
        edges = [a0] + [a0 + (a1 - a0) * (b + (0.5 if row % 2 else 0)) / blocks for b in range(blocks + 1)] + [a1]
        edges = sorted(set(min(max(e, a0), a1) for e in edges))
        for b in range(len(edges) - 1):
            s0, s1 = edges[b], edges[b + 1]
            pieces = [(s0, s1)]
            if gate:
                pieces = []
                if s0 < -90 - gap:
                    pieces.append((s0, min(s1, -90 - gap)))
                if s1 > -90 + gap:
                    pieces.append((max(s0, -90 + gap), s1))
            for q0, q1 in pieces:
                if q1 - q0 > 0.3:
                    parts.append((arc(r0 + 0.03 * (b % 2), r1, q0, q1, z0, z1 - 0.05, 2), stone(row, b)))
    if gate:
        # Au-dessus de l'ouverture : le tympan (mur plat percé de l'arche) et l'encadrement de marbre
        spring = gh - w / 2
        drum = extrude(arch_profile(w, spring, H, 10), r1 - r0, y0=-(r1 - r0))
        frame = extrude(arch_frame(w, spring, 0.9, thick=0.8, segs=10), 0.9, y0=0.0)
        posts = [(box((sx * (w / 2 + 0.45), 0.4, spring / 2), (0.9, 0.9, spring)), "marblew") for sx in (-1, 1)]
        key = box((0, 0.4, gh + 0.6), (1.2, 1.1, 1.2), bevel=0.1)
        back = box((0, -1.4, gh / 2), (w + 0.2, 0.3, gh + 0.4))
        sides = [(box((sx * (w / 2 + 0.05), -0.7, gh / 2), (0.25, 1.4, gh)), "sandshadow") for sx in (-1, 1)]
        parts += place_planar([(drum, "sand2"), (frame, "marblew"), (key, "bannergold"), (back, "tunnel")] + posts
                              + sides, r0, -90)
    # Socle sombre au pied du mur
    for q0, q1 in (((a0, -90 - gap), (-90 + gap, a1)) if gate else ((a0, a1),)):
        parts.append((arc(r0 - 0.4, r0 + 0.1, q0, q1, 0, 0.7, 3), "sanddark"))
    # Chaperon de marbre qui déborde des deux côtés
    parts.append((arc(r0 - 0.45, r1 + 0.35, a0, a1, H, H + 0.8, 4), "marblew"))
    # Pilastres aux bords du secteur (et au milieu s'il n'y a pas de porte)
    for deg in ((a0 + 0.6, a1 - 0.6) if gate else (a0 + 0.6, -90.0, a1 - 0.6)):
        pil = box((0, 0.3, H / 2), (1.6, 0.8, H), bevel=0.08)
        parts += place_planar([(pil, "marbleshade")], r0, deg)
    if not gate:
        # Deux boucliers de bronze ronds, comme sur les images
        for deg in (-90 - half / 2, -90 + half / 2):
            sh = cylinder((0, 0.25, 5.4), 1.15, 0.25, 12, axis="Y")
            knob = sphere((0, 0.55, 5.4), (0.35, 0.2, 0.35), 8, 4)
            parts += place_planar([(sh, "bronzew"), (knob, "bannergold")], r0, deg)
    P.prop("Colosseum_PitGate" if gate else "Colosseum_PitWall", parts)


def portcullis(P):
    """Herse de bronze de la porte (montée et descendue par le jeu)."""
    w, gh = L["gate_width"], L["gate_height"]
    parts = []
    for k in range(7):
        x = -w / 2 + 0.6 + k * (w - 1.2) / 6
        parts.append((box((x, 0, gh / 2), (0.25, 0.25, gh)), "bronzedark"))
        parts.append((cone((x, 0, -0.4), 0.2, 0.4, 4), "bronzew"))
    for z in (1.4, 3.4, 5.4):
        parts.append((box((0, 0, z), (w - 0.6, 0.3, 0.25)), "bronzew"))
    P.prop("Colosseum_Portcullis", parts)


# ------------------------------------------------------------------ gradins
def _tier_r(i):
    return L["walk_outer"] + L["tier_depth"] * i


def _tier_top(i):
    return L["walk_top"] + L["tier_rise"] * (i + 1)


def stands(P, variant="Normal"):
    """Un secteur de gradins : coursive pavée au-dessus du mur, balustrade de marbre, 10 rangées de grès (assises
    alternées), escalier de marbre au milieu. Variantes : « Entrance » (grand escalier d'entrée qui traverse les
    gradins depuis le parvis), « Tribune » (tribune d'honneur avec colonnes et dais rouge)."""
    half = L["sector"] / 2
    a0, a1 = -90 - half, -90 + half
    walk_r0, walk_r1, wt = L["wall_outer"], L["walk_outer"], L["walk_top"]
    parts = []
    # Coursive : dalles alternées
    for k in range(6):
        s0 = a0 + (a1 - a0) * k / 6
        s1 = a0 + (a1 - a0) * (k + 1) / 6
        parts.append((arc(walk_r0, walk_r1, s0, s1, L["wall_height"] + 0.8, wt, 2),
                      "sand3" if k % 2 else "sand1"))
    # Remplissage sous la coursive (du sol au dessus du mur), invisible de la piste mais visible depuis l'entrée
    parts.append((arc(walk_r0, walk_r1, a0, a1, 0, L["wall_height"] + 0.8, 4), "sanddark"))
    # Balustrade : main courante et petits poteaux
    parts.append((arc(walk_r0 - 0.1, walk_r0 + 0.5, a0, a1, wt + 1.0, wt + 1.3, 6), "marblew"))
    for k in range(7):
        deg = a0 + (a1 - a0) * (k + 0.5) / 7
        parts += place_planar([(box((0, 0, wt + 0.5), (0.35, 0.35, 1.0)), "marbleshade")], walk_r0 + 0.2, deg)

    # Demi-largeur angulaire d'un passage de `width` studs au rayon r
    def gap(r, width):
        return math.degrees((width / 2) / r)

    for i in range(L["tiers"]):
        r0, r1 = _tier_r(i), _tier_r(i + 1)
        top = _tier_top(i)
        # Passage au milieu : escalier (rangées normales), grand escalier (entrée), tribune (5 premières rangées)
        width = L["aisle_width"]
        if variant == "Entrance":
            width = L["entrance_width"] + 2.4
        elif variant == "Tribune" and i < 5:
            width = 14.0
        g = gap(r0, width)
        for side, (s0, s1) in enumerate(((a0, -90 - g), (-90 + g, a1))):
            # Rangée : un bloc par moitié, assises alternées ; un rebord plus clair (le siège)
            parts.append((arc(r0, r1, s0, s1, wt, top - 0.25, 3), stone(i, side)))
            parts.append((arc(r0 - 0.08, r0 + 0.9, s0, s1, top - 0.25, top, 3), "sand3" if i % 2 else "sand1"))
            parts.append((arc(r0 + 0.9, r1, s0, s1, top - 0.25, top - 0.05, 3), stone(i + 1, side)))
        if variant == "Normal" or (variant == "Tribune" and i >= 5):
            # Escalier de marbre : deux marches par rangée
            for step in range(2):
                sr0 = r0 + L["tier_depth"] * step / 2
                sr1 = sr0 + L["tier_depth"] / 2
                z = wt + L["tier_rise"] * (i + (step + 1) / 2)
                g2 = gap(sr0, L["aisle_width"])
                parts.append((arc(sr0, sr1, -90 - g2, -90 + g2, wt, z, 2), "marblew" if step == 0 else "marbleshade"))
    # Dernière rangée : un muret de grès contre la façade ; masse pleine sous les gradins (du sol à la coursive).
    # Les deux sont coupés par le grand escalier d'entrée.
    rt = _tier_r(L["tiers"])
    spans = ((a0, a1),)
    if variant == "Entrance":
        spans = None
    for r_from, r_to, z0, z1, color in ((rt, L["stand_outer"], wt, _tier_top(L["tiers"] - 1) + 1.2, "sand2"),
                                        (walk_r1, L["stand_outer"], 0, wt, "sanddark")):
        pieces = spans
        if pieces is None:
            g = gap(r_from, L["entrance_width"] + 2.4)
            pieces = ((a0, -90 - g), (-90 + g, a1))
        for q0, q1 in pieces:
            parts.append((arc(r_from, r_to, q0, q1, z0, z1, 3), color))

    if variant == "Entrance":
        parts += _entrance_stair()
    elif variant == "Tribune":
        parts += _tribune()
    P.prop(f"Colosseum_Stands{variant if variant != 'Normal' else ''}", parts)


def _entrance_stair():
    """Grand escalier de marbre blanc qui monte du parvis (dehors) à la coursive (comme l'image d'Antoine), entre deux
    murs de grès couronnés de marbre ; une grande arche de marbre l'enjambe là où il débouche sur la coursive."""
    w = L["entrance_width"]
    parts = []
    span = w + 2.4
    porta = bay_wall(span + 4.0, 15.0, 7.0, 1.6, span, "marblew", frame="bannergold")
    for bm, _spec in porta:
        move(bm, (0, 0, L["walk_top"]))
    porta.append((box((0, -0.8, L["walk_top"] + 15.4), (span + 5.0, 2.0, 0.8)), "marbleshade"))
    porta.append((box((0, -1.7, L["walk_top"] + 13.0), (2.2, 0.4, 2.2), bevel=0.15), "bannergold"))
    parts += place_planar(porta, L["walk_outer"] + 0.3, -90)
    r_out, r_in = L["facade_outer"], L["walk_outer"]
    steps = 14
    depth = (r_out - r_in) / steps
    for k in range(steps):
        r = r_out - depth * (k + 1)
        z = L["walk_top"] * (k + 1) / steps
        st = box((0, -(r + depth / 2), z / 2), (w, depth + 0.02, z))
        parts.append((st, "marblew" if k % 2 == 0 else "marbleshade"))
    top = _tier_top(L["tiers"] - 1) + 0.6
    low = L["walk_top"] * 0.35 + 2.0
    for sx in (-1, 1):
        # Mur d'échiffre : profil (rayon, hauteur) qui monte avec l'escalier puis rejoint le haut des gradins
        prof = [(-r_out, 0), (-r_in, 0), (-r_in, top), (-r_out, low)]
        wall = extrude(prof, 1.2, y0=0.0)
        rotate(wall, 90, "Z")  # le profil (x) devient le rayon (y), l'épaisseur (y) devient x
        move(wall, (sx * (w / 2 + 0.6) + 0.6, 0, 0))
        parts.append((wall, "sand2"))
        cap = extrude([(-r_out, low), (-r_in, top), (-r_in, top + 0.45), (-r_out, low + 0.45)], 1.6, y0=0.0)
        rotate(cap, 90, "Z")
        move(cap, (sx * (w / 2 + 0.6) + 0.8, 0, 0))
        parts.append((cap, "marblew"))
    return parts


def _tribune():
    """Tribune d'honneur : avancée de marbre au-dessus de la coursive, quatre colonnes, dais rouge à franges dorées."""
    parts = []
    r0 = L["walk_outer"] - 1.5
    z = L["walk_top"] + 5.0
    plat = box((0, -(r0 + 5.5), z - 0.5), (13, 11, 1.0))
    parts.append((plat, "marblew"))
    parts.append((box((0, -(r0 + 0.3), z - 1.3), (13.4, 0.6, 0.8)), "bannergold"))
    parts.append((box((0, -(r0 + 0.2), z + 0.6), (13, 0.5, 1.2)), "marbleshade"))
    for sx in (-5.5, -2, 2, 5.5):
        parts.append((cylinder((sx, -(r0 + 1.0), z), 0.55, 7.0, 10), "marblew"))
        parts.append((box((sx, -(r0 + 1.0), z + 7.2), (1.4, 1.4, 0.4)), "marbleshade"))
    canopy = box((0, -(r0 + 5.0), z + 7.8), (14, 11, 0.4))
    parts.append((canopy, "velum"))
    for k in range(7):
        parts.append((box((-6 + k * 2, -(r0 - 0.3), z + 7.2), (1.0, 0.15, 0.9), taper=0.4), "bannergold"))
    # Trône (l'annonceur s'y tiendra)
    parts.append((box((0, -(r0 + 7.5), z + 0.6), (3.0, 2.6, 1.2)), "marblew"))
    parts.append((box((0, -(r0 + 8.6), z + 2.6), (3.0, 0.6, 4.0)), "velum"))
    parts.append((box((0, -(r0 + 8.6), z + 4.8), (3.4, 0.7, 0.5)), "bannergold"))
    return parts


# ------------------------------------------------------------------ façade
def facade(P, entrance=False):
    """Façade extérieure d'un secteur : 3 travées d'arches aveugles sur deux niveaux, bandeaux de marbre, et une
    galerie d'arches ouvertes en haut (comme l'image d'Antoine). Variante entrée : une grande arche au milieu."""
    half = L["sector"] / 2
    r_in, r_out, H = L["stand_outer"], L["facade_outer"], L["facade_height"]
    rm = (r_in + r_out) / 2
    chord = 2 * rm * math.sin(math.radians(half))
    bay = chord / 3
    parts = []
    levels = ((0, 12.5, 8.5, 6.5), (12.5, 25.0, 21.0, 6.0))  # (bas, haut, naissance de l'arche, largeur)
    for lv, (z0, z1, spring, aw) in enumerate(levels):
        for b in range(3):
            if entrance and lv == 0 and b == 1:
                continue
            deg = -90 - half + L["sector"] * (b + 0.5) / 3
            wall = bay_wall(bay + 0.05, z1 - z0, spring - z0, r_out - r_in, aw, stone(b, lv))
            # Fond de l'arche aveugle (plus sombre, en retrait)
            wall.append((box((0, -0.4, (spring - z0) / 2 + 0.5), (aw, 0.2, spring - z0 + 1.0)), "sandshadow"))
            for bm, _spec in wall:
                move(bm, (0, 0, z0))
            parts += place_planar(wall, r_in, deg)
        # Colonnes engagées de marbre entre les travées (base, fût, chapiteau)
        for b in range(4):
            deg = -90 - half + L["sector"] * b / 3
            col = [
                (box((0, -0.35, z0 + 0.4), (1.9, 1.3, 0.8)), "marbleshade"),
                (cylinder((0, -0.45, z0 + 0.8), 0.7, (z1 - z0) - 2.3, 8), "marblew"),
                (box((0, -0.35, z1 - 1.25), (2.0, 1.4, 0.6), taper=1.15), "marbleshade"),
            ]
            parts += place_planar(col, r_out, deg)
        # Bandeau de marbre en haut du niveau
        parts.append((arc(r_out - 0.2, r_out + 0.7, -90 - half, -90 + half, z1 - 0.7, z1, 6), "marblew"))
    # Galerie du haut : piliers et arches ouvertes, sans mur du fond
    z0, z1 = 25.0, H
    for b in range(4):
        deg = -90 - half + L["sector"] * b / 3
        if b < 3:
            mid = -90 - half + L["sector"] * (b + 0.5) / 3
            top_arch = extrude(arch_profile(bay - 1.6, 32.0 - z0, z1 - z0), 1.2, y0=-1.2)
            move(top_arch, (0, 0, z0))
            ring = extrude(arch_frame(bay - 1.6, 32.0 - z0, 0.35), 0.3, y0=-1.45)
            move(ring, (0, 0, z0))
            parts += place_planar([(top_arch, "sand3"), (ring, "marblew")], r_in + 2.3, mid)
        pil = box((0, -0.6, (z1 - z0) / 2 + z0), (1.6, 1.2, z1 - z0))
        parts += place_planar([(pil, "sand1")], r_in + 2.3, deg)
    parts.append((arc(r_out - 1.6, r_out + 0.6, -90 - half, -90 + half, H, H + 1.0, 6), "marblew"))
    # Grande arche d'entrée (niveau bas, travée du milieu)
    if entrance:
        aw = L["entrance_width"] + 2
        gate = bay_wall(bay + 0.05, 12.5, 5.6, r_out - r_in, aw - 0.2, "sand2")
        gate.append((box((0, -(r_out - r_in) - 0.4, 12.0), (2.0, 0.8, 1.6), bevel=0.15), "bannergold"))
        parts += place_planar(gate, r_in, -90)
    P.prop("Colosseum_FacadeEntrance" if entrance else "Colosseum_Facade", parts)


def plaza(P):
    """Parvis pavé autour de l'arène sur un secteur, posé sur le podium (3 marches de grès vers l'herbe)."""
    half = L["sector"] / 2
    a0, a1 = -90 - half, -90 + half
    r0, r1 = L["facade_outer"], L["plaza_outer"]
    parts = []
    rings = 3
    for ring_i in range(rings):
        q0 = r0 + (r1 - r0) * ring_i / rings
        q1 = r0 + (r1 - r0) * (ring_i + 1) / rings
        for k in range(5):
            s0 = a0 + (a1 - a0) * (k + 0.5 * (ring_i % 2)) / 5
            s1 = min(s0 + (a1 - a0) / 5, a1)
            parts.append((arc(q0, q1, s0, s1, -0.6, -0.02, 2), "sand3" if (k + ring_i) % 2 else "sand1"))
        if ring_i % 2:
            parts.append((arc(q0, q1, a0, a0 + (a1 - a0) * 0.1, -0.6, -0.02, 1), "sand2"))
    # Podium : masse et marches
    h = L["podium"]
    parts.append((arc(r0 - 1, r1, a0, a1, -h, -0.6, 4), "sanddark"))
    for k in range(3):
        rr = r1 + 1.4 * k
        parts.append((arc(rr, rr + 1.4, a0, a1, -h, -h * (k + 1) / 4, 4), "sand2" if k % 2 else "sand1"))
    P.prop("Colosseum_Plaza", parts)


# ------------------------------------------------------------------ décors
def awning(P):
    """Velum : grande toile rouge tendue au-dessus des gradins hauts, sur deux mâts de bois, haubans."""
    parts = []
    for sx in (-7, 7):
        parts.append((segment((sx, 0, 0), (sx, 0, 12.0), 0.35, 6), "wooddark"))
        parts.append((sphere((sx, 0, 12.2), 0.45, 6, 4), "bannergold"))
    sail = box((0, 5.5, 11.0), (15.5, 11.0, 0.18))
    rotate(sail, -12, "X", (0, 0, 11.0))
    parts.append((sail, "velum"))
    hem = box((0, 0.2, 11.0), (15.5, 0.25, 0.8))
    parts.append((hem, "velumdark"))
    for k in range(8):
        parts.append((box((-7 + k * 2, 0.15, 10.4), (0.9, 0.12, 0.7), taper=0.3), "bannergold"))
    for sx in (-7, 7):
        parts.append((segment((sx, 0, 12.0), (sx * 1.2, -5.0, 0.0), 0.06, 4), "rope"))
    P.prop("Colosseum_Awning", parts)


def banner(P):
    """Étendard rouge à bordure dorée et emblème (soleil et haltère), sur une hampe à pointe dorée. Pas de texte."""
    parts = [(segment((0, 0, 0), (0, 0, 13.0), 0.18, 6), "wooddark"),
             (cone((0, 0, 13.0), 0.35, 1.0, 6), "bannergold"),
             (segment((-1.8, 0, 12.0), (1.8, 0, 12.0), 0.1, 4), "bannergold")]
    parts.append((box((0, -0.05, 8.4), (3.4, 0.12, 7.0)), "velum"))
    parts.append((box((0, -0.06, 4.9), (3.4, 0.13, 0.4)), "bannergold"))
    parts.append((box((0, -0.06, 11.8), (3.4, 0.13, 0.35)), "bannergold"))
    for sx in (-1.6, 1.6):
        parts.append((box((sx, -0.06, 8.4), (0.25, 0.13, 7.0)), "bannergold"))
    # Pointes en bas de l'étendard
    for k in range(4):
        parts.append((extrude([(-0.42, 0), (0.42, 0), (0, -0.9)], 0.12, y0=-0.11), "velum"))
        move(parts[-1][0], (-1.27 + k * 0.85, 0, 4.7))
    # Emblème : soleil doré et haltère
    parts.append((cylinder((0, -0.14, 9.0), 1.05, 0.06, 12, axis="Y"), "bannergold"))
    for s in range(8):
        ray = box((0, -0.15, 9.0 + 1.45), (0.25, 0.05, 0.6))
        rotate(ray, s * 45, "Y", (0, 0, 9.0))
        parts.append((ray, "bannergold"))
    parts.append((box((0, -0.2, 9.0), (1.2, 0.06, 0.18)), "velumdark"))
    for sx in (-0.65, 0.65):
        parts.append((box((sx, -0.2, 9.0), (0.25, 0.06, 0.8)), "velumdark"))
    P.prop("Colosseum_Banner", parts)


def brazier(P):
    """Brasero de bronze sur trépied (le jeu y allume un feu)."""
    parts = []
    for k in range(3):
        a = k * 120
        x, y, _ = polar(0.9, a)
        parts.append((segment((x * 1.3, y * 1.3, 0), (x * 0.5, y * 0.5, 3.0), 0.12, 5), "bronzedark"))
    parts.append((cylinder((0, 0, 2.8), 0.6, 0.4, 10, radius_top=1.3), "bronzew"))
    parts.append((cylinder((0, 0, 3.2), 1.3, 0.35, 10), "bronzew"))
    parts.append((torus((0, 0, 3.55), 1.3, 0.12, 12, 4), "bannergold"))
    parts.append((cylinder((0, 0, 3.4), 1.05, 0.2, 10), "sandshadow"))
    P.prop("Colosseum_Brazier", parts)


def statue(P):
    """Statue de marbre d'un dieu du muscle en double biceps, sur un haut piédestal. Pas de texte."""
    parts = []
    parts.append((box((0, 0, 1.8), (4.4, 4.4, 3.6), bevel=0.1), "marbleshade"))
    parts.append((box((0, 0, 3.75), (5.0, 5.0, 0.5), bevel=0.08), "marblew"))
    parts.append((box((0, 0, 0.25), (5.0, 5.0, 0.5), bevel=0.08), "marblew"))
    z = 4.0
    m = "marblew"
    # Jambes, hanches, buste en V, tête, bras levés (double biceps)
    for sx in (-1, 1):
        parts.append((segment((sx * 0.75, 0, z), (sx * 0.85, 0.1, z + 2.6), 0.55, 6, 0.65), m))
        parts.append((segment((sx * 0.85, 0.1, z + 2.6), (sx * 0.7, 0, z + 5.0), 0.7, 6, 0.75), m))
    parts.append((box((0, 0, z + 5.4), (2.4, 1.4, 1.2), bevel=0.2), m))
    parts.append((box((0, 0, z + 7.1), (3.0, 1.7, 2.4), bevel=0.3, taper=1.35), m))
    parts.append((sphere((0, -0.3, z + 7.6), (1.7, 0.6, 1.0), 8, 5), m))
    parts.append((segment((0, 0, z + 8.4), (0, 0, z + 9.2), 0.45, 6), m))
    parts.append((sphere((0, -0.05, z + 9.8), (0.75, 0.8, 0.9), 8, 6), m))
    parts.append((torus((0, 0, z + 10.2), 0.72, 0.12, 10, 4), "bannergold"))  # couronne de laurier dorée
    for sx in (-1, 1):
        sh = (sx * 2.1, 0, z + 8.2)
        el = (sx * 3.6, 0, z + 8.3)
        fi = (sx * 3.3, 0, z + 10.2)
        parts.append((sphere(sh, 0.85, 8, 5), m))
        parts.append((segment(sh, el, 0.6, 6, 0.55), m))
        parts.append((sphere((sx * 2.9, -0.1, z + 8.55), (0.75, 0.6, 0.6), 8, 5), m))  # biceps
        parts.append((segment(el, fi, 0.5, 6, 0.42), m))
        parts.append((sphere(fi, 0.48, 6, 4), m))
    # Pagne doré
    parts.append((box((0, 0, z + 4.7), (2.5, 1.5, 0.9), taper=0.85), "bannergold"))
    P.prop("Colosseum_Statue", parts)


def crowd(P):
    """Foule assise sur un secteur de gradins : silhouettes basses en toges de couleurs (une pièce par secteur, le jeu
    la fait sautiller pour les acclamations). Les places de l'escalier restent libres."""
    rnd = random.Random(77)
    half = L["sector"] / 2
    togas = ("toga1", "toga2", "toga3", "toga4", "toga5", "toga6", "toga1")
    skins = ("crowdskin1", "crowdskin2", "crowdskin3")
    parts = []
    for i in range(1, L["tiers"]):
        r = _tier_r(i) + 0.55
        top = _tier_top(i)
        n = int(2 * math.pi * r * (L["sector"] / 360) / 2.1)
        for k in range(n):
            if rnd.random() < 0.32:
                continue
            deg = -90 - half + L["sector"] * (k + 0.5) / n
            along = r * math.radians(deg + 90)
            if abs(along) < L["aisle_width"] / 2 + 0.8:
                continue
            toga = togas[rnd.randrange(len(togas))]
            skin = skins[rnd.randrange(len(skins))]
            h = rnd.uniform(0.85, 1.1)
            fig = [
                (box((0, 0, top + 0.55 * h), (0.95, 0.75, 1.1 * h), taper=0.8), toga),
                (box((0, 0, top + 1.38 * h), (0.6, 0.6, 0.6)), skin),
            ]
            if rnd.random() < 0.6:
                fig.append((box((0, 0.05, top + 1.72 * h), (0.64, 0.64, 0.14)), "crowdhair"))
            if rnd.random() < 0.35:
                sx = rnd.choice((-1, 1))
                fig.append((segment((sx * 0.4, 0, top + 0.95 * h), (sx * 0.55, -0.1, top + 1.9 * h), 0.13, 4), skin))
            parts += place_planar(fig, r, deg)
    P.prop("Colosseum_Crowd", parts)


def border_gate(P):
    """Porte triomphale dans la haie de bordure de la ville (coin sud-ouest) : départ de la voie vers le colisée."""
    parts = []
    w, h = 14.0, 11.0
    for sx in (-1, 1):
        parts.append((box((sx * (w / 2 + 2.5), 0, h / 2), (5.0, 4.0, h)), "sand1"))
        parts.append((box((sx * (w / 2 + 2.5), -2.1, 4.0), (5.4, 0.3, 0.5)), "marblew"))
        for dx in (-1.5, 1.5):
            parts.append((cylinder((sx * (w / 2 + 2.5) + dx, -2.4, 0), 0.5, h - 0.2, 10), "marblew"))
    top = extrude(arch_profile(w, h - w / 2 - 0.5, h + 5.0, 10), 4.0, y0=-2.0)
    parts.append((top, "sand2"))
    parts.append((extrude(arch_frame(w, h - w / 2 - 0.5, 0.4, thick=0.7, segs=10), 0.4, y0=-2.3), "marblew"))
    parts.append((box((0, 0, h + 5.4), (w + 11, 4.6, 0.8)), "marblew"))
    parts.append((box((0, 0, h + 6.6), (w + 6, 3.6, 1.6)), "sand3"))
    parts.append((box((0, -1.9, h + 6.6), (6.0, 0.2, 1.0)), "bannergold"))
    parts.append((sphere((0, -2.05, h + 6.6), (0.9, 0.2, 0.9), 8, 4), "velum"))
    P.prop("Colosseum_Gate", parts)


def build_colosseum(P):
    colosseum_floor(P)
    pit_wall(P, gate=False)
    pit_wall(P, gate=True)
    portcullis(P)
    stands(P, "Normal")
    stands(P, "Entrance")
    stands(P, "Tribune")
    facade(P, entrance=False)
    facade(P, entrance=True)
    plaza(P)
    awning(P)
    banner(P)
    brazier(P)
    statue(P)
    crowd(P)
    border_gate(P)

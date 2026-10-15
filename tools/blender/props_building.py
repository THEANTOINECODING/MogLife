"""
Bâtiments de Muscle City (étape 1) : maison de maman, garage, porte intérieure, magasins, salle de quartier.
À exécuter dans Blender après props_lib.py :  build_buildings(Props(pal, "Props_Buildings"))

Chaque bâtiment est découpé en plusieurs modèles qui se recalent ensemble dans le jeu (voir le manifeste) :
- *_Walls / *_Roof : TEINTABLES (le jeu retire la texture et applique couleur + matériau : une seule maison,
  20 couleurs). Les murs ont de vraies ouvertures (portes, fenêtres) : collision précise dans Roblox.
- *_Trim : détails texturés (soubassement, encadrements, volets, porche, gouttières, cheminée, vitrines…).
- *_Interior : papier peint, plinthes et plafond (sans collision).
Repère de conception (= repère du bâtiment dans build_map.py) : X largeur (centré), Y profondeur depuis la façade
(y = 0, l'intérieur vers +Y), Z hauteur depuis le sol. 1 unité = 1 stud.
"""

T = 0.8  # épaisseur des murs


# ------------------------------------------------------------------ outils de construction
def _split(a, b, tile):
    """Découpe [a, b] en morceaux d'au plus `tile` (pour que les motifs se répètent au lieu de s'étirer)."""
    if not tile:
        return [(a, b)]
    n = max(1, math.ceil((b - a) / tile - 1e-6))
    step = (b - a) / n
    return [(a + k * step, a + (k + 1) * step) for k in range(n)]


def wall(run, a0, a1, t0, t1, z0, z1, holes=(), tile=None):
    """Mur plein le long de X (run="x") ou de Y (run="y"), percé d'ouvertures (u0, u1, v0, v1).
    `tile` : découpe en carreaux (papier peint, carrelage)."""
    cuts = sorted({a0, a1} | {h[0] for h in holes} | {h[1] for h in holes})
    cuts = [u for u in cuts if a0 <= u <= a1]
    out = []
    for ua, ub in zip(cuts, cuts[1:]):
        if ub - ua < 1e-4:
            continue
        mid = (ua + ub) / 2
        blocked = sorted((max(z0, h[2]), min(z1, h[3])) for h in holes if h[0] < mid < h[1])
        segs, cur = [], z0
        for b0, b1 in blocked:
            if b0 > cur:
                segs.append((cur, b0))
            cur = max(cur, b1)
        if cur < z1:
            segs.append((cur, z1))
        for s0, s1 in segs:
            if s1 - s0 < 1e-4:
                continue
            for pa, pb in _split(ua, ub, tile):
                for qa, qb in _split(s0, s1, tile):
                    if run == "x":
                        out.append(box(((pa + pb) / 2, (t0 + t1) / 2, (qa + qb) / 2), (pb - pa, t1 - t0, qb - qa)))
                    else:
                        out.append(box(((t0 + t1) / 2, (pa + pb) / 2, (qa + qb) / 2), (t1 - t0, pb - pa, qb - qa)))
    return out


def gable(y0, t, w, h, rh):
    return extrude([(-w / 2, h), (w / 2, h), (0, h + rh)], t, y0=y0)


def roof_panels(w, d, h, rh, oh, th):
    """Deux pans de toit avec débord `oh` tout autour."""
    half = w / 2
    s = rh / half
    out = []
    for sx in (-1, 1):
        ex = sx * (half + oh)
        ez = h + rh - s * (half + oh)
        prof = [(0, h + rh), (ex, ez), (ex, ez + th), (0, h + rh + th)]
        out.append(extrude(prof, d + 2 * oh, y0=-oh))
    return out


def window_x(u0, u1, v0, v1, y_out, outward, shutters=None):
    """Fenêtre dans un mur le long de X : cadre, appui, vitre, croisillon (et volets)."""
    cx, w, h = (u0 + u1) / 2, u1 - u0, v1 - v0
    yo = y_out + outward * 0.12
    parts = [
        (box((cx, yo, v1 + 0.15), (w + 0.6, 0.3, 0.3)), "white"),
        (box((cx, yo - outward * 0.1, v0 - 0.12), (w + 1.0, 0.5, 0.25)), "white"),
        (box((u0 - 0.15, yo, (v0 + v1) / 2), (0.3, 0.3, h + 0.3)), "white"),
        (box((u1 + 0.15, yo, (v0 + v1) / 2), (0.3, 0.3, h + 0.3)), "white"),
        (box((cx, y_out - outward * T / 2, (v0 + v1) / 2), (w, 0.08, h)), "glass"),
        (box((cx, y_out - outward * 0.3, (v0 + v1) / 2), (0.15, 0.12, h)), "white"),
        (box((cx, y_out - outward * 0.3, (v0 + v1) / 2), (w, 0.12, 0.15)), "white"),
    ]
    if shutters:
        for sx in (-1, 1):
            x = cx + sx * (w / 2 + 0.95)
            parts.append((box((x, yo, (v0 + v1) / 2), (1.3, 0.15, h + 0.2)), shutters))
            for k in range(4):
                parts.append((box((x, yo + outward * 0.08, v0 + 0.5 + k * (h - 0.6) / 3.5), (1.0, 0.05, 0.12)), "black"))
    return parts


def window_y(u0, u1, v0, v1, x_out, outward):
    """Fenêtre dans un mur le long de Y."""
    cy, w, h = (u0 + u1) / 2, u1 - u0, v1 - v0
    xo = x_out + outward * 0.12
    return [
        (box((xo, cy, v1 + 0.15), (0.3, w + 0.6, 0.3)), "white"),
        (box((xo + outward * 0.1, cy, v0 - 0.12), (0.5, w + 1.0, 0.25)), "white"),
        (box((xo, u0 - 0.15, (v0 + v1) / 2), (0.3, 0.3, h + 0.3)), "white"),
        (box((xo, u1 + 0.15, (v0 + v1) / 2), (0.3, 0.3, h + 0.3)), "white"),
        (box((x_out - outward * T / 2, cy, (v0 + v1) / 2), (0.08, w, h)), "glass"),
        (box((x_out - outward * 0.3, cy, (v0 + v1) / 2), (0.12, 0.15, h)), "white"),
        (box((x_out - outward * 0.3, cy, (v0 + v1) / 2), (0.12, w, 0.15)), "white"),
    ]


def roof_edges(w, d, h, rh, oh, th, front=True, back=True):
    """Bordures de toit : planches de rive (pignons), bandeaux, gouttières, faîtage, descentes d'eau."""
    half = w / 2
    s = rh / half
    ez = h + rh - s * (half + oh)
    parts = []
    for y0, flag in ((-oh - 0.22, front), (d + oh, back)):
        if not flag:
            continue
        for sx in (-1, 1):
            ex = sx * (half + oh + 0.12)
            prof = [(0, h + rh + th + 0.25), (ex, ez - 0.15 + th + 0.25 - s * 0.12), (ex, ez - 0.45),
                    (0, h + rh - 0.3)]
            parts.append((extrude(prof, 0.22, y0=y0), "white"))
    for sx in (-1, 1):
        x = sx * (half + oh + 0.06)
        parts.append((box((x, d / 2, ez - 0.05), (0.2, d + 2 * oh, 0.6)), "white"))
        parts.append((box((x + sx * 0.25, d / 2, ez - 0.35), (0.35, d + 2 * oh, 0.3)), "lightgrey"))
        # Descentes d'eau plaquées contre le mur, reliées à la gouttière par un coude
        for y in (0.6, d - 0.6):
            wx = sx * (half + 0.3)
            parts.append((box((wx, y, (ez - 0.6) / 2), (0.3, 0.3, ez - 0.6)), "lightgrey"))
            parts.append((box(((wx + x + sx * 0.25) / 2, y, ez - 0.5), (abs(x + sx * 0.25 - wx) + 0.3, 0.3, 0.25)),
                          "lightgrey"))
    parts.append((box((0, d / 2, h + rh + th + 0.05), (0.9, d + 2 * oh + 0.1, 0.3)), "darkbrown"))
    return parts


def foundation(segments, height=0.7, cell="stonebase"):
    return [(box(c, s), cell) for c, s in segments]


# ------------------------------------------------------------------ maison de maman
HW, HD, HH, HRH, HOH = 26, 32, 12, 7.5, 1.2
HOUSE_FRONT_DOOR = (-3, 3, 0, 8.5)
HOUSE_FRONT_WINDOWS = ((-10.75, -5.25, 4, 8), (5.25, 10.75, 4, 8))
HOUSE_BACK_WINDOWS = ((-9, -5, 4.5, 8), (5, 9, 4.5, 8))
HOUSE_RIGHT_WINDOWS = ((7, 12, 4, 8), (19, 24, 4, 8))
HOUSE_GARAGE_DOOR = (19.5, 24.5, 0, 8.2)  # dans le mur gauche, vers le garage
LINK_X = (-15.0, -13.0)  # passage couvert entre le garage et la maison


def house(P):
    half = HW / 2
    walls = []
    walls += wall("x", -half, half, 0, T, 0, HH, (HOUSE_FRONT_DOOR,) + HOUSE_FRONT_WINDOWS)
    walls += wall("x", -half, half, HD - T, HD, 0, HH, HOUSE_BACK_WINDOWS)
    walls += wall("y", T, HD - T, -half, -half + T, 0, HH, (HOUSE_GARAGE_DOOR,))
    walls += wall("y", T, HD - T, half - T, half, 0, HH, HOUSE_RIGHT_WINDOWS)
    walls += [gable(0, T, HW, HH, HRH), gable(HD - T, T, HW, HH, HRH)]
    # Passage couvert vers le garage
    y0, y1 = HOUSE_GARAGE_DOOR[0] - 0.4, HOUSE_GARAGE_DOOR[1] + 0.4
    for ya, yb in ((y0, y0 + 0.4), (y1 - 0.4, y1)):
        walls.append(box(((LINK_X[0] + LINK_X[1]) / 2, (ya + yb) / 2, 4.3), (2.0, 0.4, 8.6)))
    walls.append(box(((LINK_X[0] + LINK_X[1]) / 2, (y0 + y1) / 2, 8.8), (2.0, y1 - y0, 0.4)))
    P.prop("House_Walls", [(b, "white") for b in walls])

    P.prop("House_Roof", [(b, "white") for b in roof_panels(HW, HD, HH, HRH, HOH, 0.45)])

    trim = []
    trim += foundation([
        ((-(half + 3) / 2 - 1.5, -0.12, 0.35), (half - 3 + 0.25, 0.25, 0.7)),
        (((half + 3) / 2 + 1.5, -0.12, 0.35), (half - 3 + 0.25, 0.25, 0.7)),
        ((0, HD + 0.12, 0.35), (HW + 0.5, 0.25, 0.7)),
        ((half + 0.12, HD / 2, 0.35), (0.25, HD, 0.7)),
        ((-half - 0.12, (HOUSE_GARAGE_DOOR[0] - 0.4) / 2, 0.35), (0.25, HOUSE_GARAGE_DOOR[0] - 0.4, 0.7)),
        ((-half - 0.12, (HD + HOUSE_GARAGE_DOOR[1] + 0.4) / 2, 0.35), (0.25, HD - HOUSE_GARAGE_DOOR[1] - 0.4, 0.7)),
    ])
    for x in (-half, half):
        for y in (0, HD):
            trim.append((box((x, y, (0.7 + HH) / 2), (0.6, 0.6, HH - 0.7)), "white"))
    for u0, u1, v0, v1 in HOUSE_FRONT_WINDOWS:
        trim += window_x(u0, u1, v0, v1, 0, -1, shutters="navy")
    for u0, u1, v0, v1 in HOUSE_BACK_WINDOWS:
        trim += window_x(u0, u1, v0, v1, HD, 1)
    for u0, u1, v0, v1 in HOUSE_RIGHT_WINDOWS:
        trim += window_y(u0, u1, v0, v1, half, 1)
    # Porte d'entrée : encadrement, porche à deux marches, auvent sur colonnes, lanterne
    d0, d1, _, dh = HOUSE_FRONT_DOOR
    trim += [
        (box((d0 - 0.2, -0.15, dh / 2), (0.4, 0.3, dh)), "white"),
        (box((d1 + 0.2, -0.15, dh / 2), (0.4, 0.3, dh)), "white"),
        (box((0, -0.15, dh + 0.25), (d1 - d0 + 0.8, 0.3, 0.5)), "white"),
        (box((0, -1.3, 0.25), (8.6, 2.6, 0.5)), "concrete"),
        (box((0, -2.95, 0.12), (8.6, 0.7, 0.25)), "concrete"),
    ]
    canopy = box((0, -1.6, 9.6), (9.4, 3.8, 0.3))
    trim.append((rotate(canopy, -8, "X", (0, 0, 9.6)), "shingles"))
    for sx in (-1, 1):
        trim.append((cylinder((sx * 4.0, -3.0, 0.5), 0.28, 8.9, 8), "white"))
        trim.append((box((sx * 4.0, -3.0, 9.35), (0.7, 0.7, 0.3)), "white"))
    trim.append((box((-4.3, -0.25, 6.4), (0.5, 0.5, 0.8)), "lampwarm"))
    trim.append((box((-4.3, -0.15, 7.0), (0.7, 0.4, 0.2)), "charcoal"))
    # Toit : rives, bandeaux, gouttières, faîtage, cheminée en brique
    trim += roof_edges(HW, HD, HH, HRH, HOH, 0.45)
    s = HRH / half
    base = HH + HRH - s * 7 - 0.4
    trim.append((box((7, 22, (base + 21.0) / 2), (2.6, 2.6, 21.0 - base)), "brick"))
    trim.append((box((7, 22, 21.15), (3.1, 3.1, 0.3)), "concrete"))
    # Encadrement de la porte intérieure vers le garage (côté maison et côté passage)
    g0, g1, _, gh = HOUSE_GARAGE_DOOR
    for x in (-half + T + 0.12, -half - 0.12):
        trim += [
            (box((x, g0 - 0.15, gh / 2), (0.25, 0.3, gh)), "white"),
            (box((x, g1 + 0.15, gh / 2), (0.25, 0.3, gh)), "white"),
            (box((x, (g0 + g1) / 2, gh + 0.15), (0.25, g1 - g0 + 0.6, 0.3)), "white"),
        ]
    P.prop("House_Trim", trim)

    # Intérieurs : 4 papiers peints (les maisons alternent)
    inner = []
    inside = half - T
    pan = 0.06
    inner_walls = [
        ("x", -inside, inside, T, T + pan, (HOUSE_FRONT_DOOR,) + HOUSE_FRONT_WINDOWS),
        ("x", -inside, inside, HD - T - pan, HD - T, HOUSE_BACK_WINDOWS),
        ("y", T, HD - T, -inside, -inside + pan, (HOUSE_GARAGE_DOOR,)),
        ("y", T, HD - T, inside - pan, inside, HOUSE_RIGHT_WINDOWS),
    ]
    for paper in ("wallpaper_cream", "wallpaper_mint", "wallpaper_rose", "wallpaper_blue"):
        parts = []
        for run, a0, a1, t0, t1, holes in inner_walls:
            parts += [(b, paper) for b in wall(run, a0, a1, t0, t1, 1.1, HH - 0.1, holes, tile=3.5)]
            # Plinthe blanche (0,5 → 1,1) qui contourne les portes
            parts += [(b, "white") for b in wall(run, a0, a1, t0 - (0.05 if t0 > 1 else 0), t1 + (0.05 if t0 < 1 else 0),
                                                  0.5, 1.1, tuple(h for h in holes if h[2] < 1.1))]
        parts.append((box((0, HD / 2, HH - 0.05), (HW - 2 * T, HD - 2 * T, 0.1)), "white"))
        P.prop(f"House_Interior_{paper.split('_')[1].capitalize()}", parts)


# ------------------------------------------------------------------ garage (assorti à la maison)
GW, GD, GH, GRH, GOH = 26, 30, 12, 3.5, 1.0
GARAGE_DOOR = (-9, 9, 0, 10)
GARAGE_HOUSE_DOOR = (23.5, 28.5, 0, 8.2)  # dans le mur droit, vers la maison
GARAGE_WINDOWS_LEFT = ((10, 15, 7, 10),)
GARAGE_WINDOWS_BACK = ((4, 9, 7, 10),)


def garage(P):
    half = GW / 2
    walls = []
    walls += wall("x", -half, half, 0, T, 0, GH, (GARAGE_DOOR,))
    walls += wall("x", -half, half, GD - T, GD, 0, GH, GARAGE_WINDOWS_BACK)
    walls += wall("y", T, GD - T, -half, -half + T, 0, GH, GARAGE_WINDOWS_LEFT)
    walls += wall("y", T, GD - T, half - T, half, 0, GH, (GARAGE_HOUSE_DOOR,))
    walls += [gable(0, T, GW, GH, GRH), gable(GD - T, T, GW, GH, GRH)]
    P.prop("Garage_Walls", [(b, "white") for b in walls])
    P.prop("Garage_Roof", [(b, "white") for b in roof_panels(GW, GD, GH, GRH, GOH, 0.4)])

    trim = []
    trim += foundation([
        ((-(half + 9) / 2 - 0.0, -0.12, 0.3), (half - 9 + 0.25, 0.25, 0.6)),
        (((half + 9) / 2, -0.12, 0.3), (half - 9 + 0.25, 0.25, 0.6)),
        ((0, GD + 0.12, 0.3), (GW + 0.5, 0.25, 0.6)),
        ((-half - 0.12, GD / 2, 0.3), (0.25, GD, 0.6)),
    ], height=0.6, cell="concrete")
    for x in (-half, half):
        for y in (0, GD):
            trim.append((box((x, y, (0.6 + GH) / 2), (0.6, 0.6, GH - 0.6)), "white"))
    d0, d1, _, dh = GARAGE_DOOR
    trim += [
        (box((d0 - 0.3, -0.18, dh / 2), (0.6, 0.36, dh)), "white"),
        (box((d1 + 0.3, -0.18, dh / 2), (0.6, 0.36, dh)), "white"),
        (box((0, -0.18, dh + 0.3), (d1 - d0 + 1.2, 0.36, 0.6)), "white"),
        # Porte de garage enroulée en haut de l'ouverture, avec son coffre
        (cylinder((d0, 1.4, dh - 0.9), 0.9, d1 - d0, 12, axis="X"), "lightgrey"),
        (box((0, 1.0, dh - 0.3), (d1 - d0 + 0.4, 1.6, 0.6)), "grey"),
        (box((0, -0.35, dh + 1.3), (1.2, 0.5, 0.6)), "lampwarm"),
        (box((0, -0.25, dh + 1.75), (1.6, 0.6, 0.25)), "charcoal"),
    ]
    for u0, u1, v0, v1 in GARAGE_WINDOWS_LEFT:
        trim += window_y(u0, u1, v0, v1, -half, -1)
    for u0, u1, v0, v1 in GARAGE_WINDOWS_BACK:
        trim += window_x(u0, u1, v0, v1, GD, 1)
    trim += roof_edges(GW, GD, GH, GRH, GOH, 0.4)
    g0, g1, _, gh = GARAGE_HOUSE_DOOR
    x = half - T - 0.12
    trim += [
        (box((x, g0 - 0.15, gh / 2), (0.25, 0.3, gh)), "white"),
        (box((x, g1 + 0.15, gh / 2), (0.25, 0.3, gh)), "white"),
        (box((x, (g0 + g1) / 2, gh + 0.15), (0.25, g1 - g0 + 0.6, 0.3)), "white"),
    ]
    P.prop("Garage_Trim", trim)

    inside = half - T
    parts = []
    for run, a0, a1, t0, t1, holes in (
        ("x", -inside, inside, T, T + 0.06, (GARAGE_DOOR,)),
        ("x", -inside, inside, GD - T - 0.06, GD - T, GARAGE_WINDOWS_BACK),
        ("y", T, GD - T, -inside, -inside + 0.06, GARAGE_WINDOWS_LEFT),
        ("y", T, GD - T, inside - 0.06, inside, (GARAGE_HOUSE_DOOR,)),
    ):
        parts += [(b, "garagewall") for b in wall(run, a0, a1, t0, t1, 0.3, GH - 0.1, holes, tile=6)]
        parts += [(b, "yellow") for b in wall(run, a0, a1, t0 - 0.02 if t0 > 1 else t0, t1 + 0.02 if t0 < 1 else t1,
                                              1.6, 1.9, tuple(h for h in holes if h[2] < 1.9))]
    parts.append((box((0, GD / 2, GH - 0.05), (GW - 2 * T, GD - 2 * T, 0.1)), "lightgrey"))
    P.prop("Garage_Interior", parts)


def doors(P):
    """Portes battantes (le jeu les fait pivoter quand un joueur approche, à l'opposé de lui).
    Convention : charnière côté -X, poignée côté +X."""
    # Entre le garage et la maison
    parts = [(box((0, 0, 4.0), (4.8, 0.3, 8.0)), "woodlight")]
    for z in (2.0, 5.6):
        parts.append((box((0, -0.17, z), (3.6, 0.05, 2.6)), "wood"))
        parts.append((box((0, 0.17, z), (3.6, 0.05, 2.6)), "wood"))
    for y in (-0.3, 0.3):
        parts.append((sphere((1.8, y, 3.8), 0.2, 6, 4), "gold"))
    P.prop("Door_Interior", parts)

    # Porte d'entrée de la maison : bois, deux panneaux, petite vitre en haut, poignée dorée
    w, h = HOUSE_FRONT_DOOR[1] - HOUSE_FRONT_DOOR[0] - 0.2, HOUSE_FRONT_DOOR[3] - 0.5
    parts = [(box((0, 0, h / 2), (w, 0.3, h)), "wood")]
    for side in (-1, 1):
        y = side * 0.17
        for x in (-w / 4, w / 4):
            parts.append((box((x, y, 1.9), (w / 2 - 0.9, 0.05, 2.4)), "woodlight"))
        parts.append((box((0, y, h - 1.6), (w - 1.4, 0.06, 1.9)), "white"))
        parts.append((sphere((w / 2 - 0.6, side * 0.32, h * 0.47), 0.22, 6, 4), "gold"))
    parts.append((box((0, 0, h - 1.6), (w - 2.0, 0.42, 1.4)), "glass"))
    P.prop("Door_House", parts)

    # Magasins : deux battants vitrés par entrée (cadre sombre, barre de poussée)
    for name, spec in SHOPS.items():
        dw, dh = spec[3]
        w, h = dw / 2 - 0.05, dh - 0.4
        parts = [
            (box((-w / 2 + 0.3, 0, h / 2), (0.6, 0.3, h)), "charcoal"),
            (box((w / 2 - 0.3, 0, h / 2), (0.6, 0.3, h)), "charcoal"),
            (box((0, 0, h - 0.35), (w, 0.3, 0.7)), "charcoal"),
            (box((0, 0, 0.6), (w, 0.3, 1.2)), "charcoal"),
            (box((0, 0, (h + 0.5) / 2), (w - 1.2, 0.1, h - 1.9)), "glass"),
        ]
        for side in (-1, 1):
            parts.append((box((w / 2 - 1.0, side * 0.32, h * 0.45), (0.2, 0.2, min(4.0, h * 0.45))), "lightgrey"))
        P.prop(f"Door_Shop_{name}", parts)


# ------------------------------------------------------------------ magasins et salle de quartier
SHOPS = {
    # nom : (largeur, profondeur, hauteur, porte (largeur, hauteur), fenêtres (x, largeur, bas, haut),
    #        couleur de l'enseigne, papier peint intérieur)
    "Clothes": (44, 38, 16, (10, 10), ((-13.5, 12, 2.5, 11), (13.5, 12, 2.5, 11)), "blue", "shopwall_white"),
    "Barber": (36, 32, 14, (8, 9), ((-10.5, 9, 3, 9.5), (10.5, 9, 3, 9.5)), "red", "wallpaper_blue"),
    "Furniture": (48, 38, 16, (12, 11), ((-15, 14, 2.5, 12), (15, 14, 2.5, 12)), "navy", "wallpaper_cream"),
    "Grocery": (36, 32, 14, (10, 9), ((-11, 10, 2.5, 9), (11, 10, 2.5, 9)), "green", "tiles"),
    "Gym": (84, 48, 20, (18, 13), ((-26, 16, 3, 12), (26, 16, 3, 12)), "darkred", "gymwall"),
}


def shop(P, name, spec):
    w, d, h, (dw, dh), windows, sign, paper = spec
    half = w / 2
    para = 1.6  # acrotère au-dessus du toit plat
    door = (-dw / 2, dw / 2, 0, dh)
    holes = (door,) + tuple((x - ww / 2, x + ww / 2, y0, y1) for x, ww, y0, y1 in windows)
    walls = []
    walls += wall("x", -half, half, 0, T, 0, h + para, holes)
    walls += wall("x", -half, half, d - T, d, 0, h + para)
    walls += wall("y", T, d - T, -half, -half + T, 0, h + para)
    walls += wall("y", T, d - T, half - T, half, 0, h + para)
    P.prop(f"Shop_{name}_Walls", [(b, "white") for b in walls])

    trim = []
    # Toit plat, couvertine de l'acrotère, corniche en façade, pilastres
    trim.append((box((0, d / 2, h + 0.3), (w - 2 * T, d - 2 * T, 0.6)), "darkgrey"))
    for c, s in (((0, 0.4, h + para + 0.12), (w + 0.4, T + 0.4, 0.25)), ((0, d - 0.4, h + para + 0.12), (w + 0.4, T + 0.4, 0.25)),
                 ((-half + 0.4, d / 2, h + para + 0.12), (T + 0.4, d, 0.25)), ((half - 0.4, d / 2, h + para + 0.12), (T + 0.4, d, 0.25))):
        trim.append((box(c, s), "lightgrey"))
    trim.append((box((0, -0.35, h - 0.6), (w + 0.6, 0.7, 0.9)), "white"))
    trim.append((box((0, -0.2, h - 1.3), (w + 0.2, 0.4, 0.3)), "white"))
    for x in (-half + 0.6, half - 0.6):
        trim.append((box((x, -0.2, (h - 1.2) / 2), (1.4, 0.45, h - 1.2)), "white"))
    # Vitrines : cadre sombre, meneaux, vitre, soubassement en pierre, petite tablette
    for x, ww, y0, y1 in windows:
        u0, u1 = x - ww / 2, x + ww / 2
        trim.append((box((x, -0.2, y1 + 0.2), (ww + 0.8, 0.4, 0.4)), "charcoal"))
        trim.append((box((x, -0.2, y0 - 0.2), (ww + 0.8, 0.5, 0.4)), "charcoal"))
        for u in (u0 - 0.2, u1 + 0.2):
            trim.append((box((u, -0.2, (y0 + y1) / 2), (0.4, 0.4, y1 - y0)), "charcoal"))
        n = max(1, int(ww // 4))
        for k in range(1, n):
            trim.append((box((u0 + k * ww / n, -0.1, (y0 + y1) / 2), (0.25, 0.25, y1 - y0)), "charcoal"))
        trim.append((box((x, T / 2, (y0 + y1) / 2), (ww, 0.1, y1 - y0)), "glass"))
        trim.append((box((x, -0.15, y0 / 2), (ww + 0.8, 0.3, y0)), "stonebase"))
    # Porte : encadrement et enseigne colorée (le jeu ne met jamais de texte)
    trim += [
        (box((-dw / 2 - 0.3, -0.2, dh / 2), (0.6, 0.4, dh)), "charcoal"),
        (box((dw / 2 + 0.3, -0.2, dh / 2), (0.6, 0.4, dh)), "charcoal"),
        (box((0, -0.2, dh + 0.3), (dw + 1.2, 0.4, 0.6)), "charcoal"),
        (box((0, -0.35, dh + 1.8), (dw + 4, 0.4, 2.2)), "white"),
        (box((0, -0.5, dh + 1.8), (dw + 3.4, 0.1, 1.7)), sign),
    ]
    for x in (-dw / 2 - 1.2, dw / 2 + 1.2):
        trim.append((box((x, -0.9, dh + 3.3), (0.5, 1.4, 0.3)), "charcoal"))
        trim.append((box((x, -1.5, dh + 3.1), (0.8, 0.4, 0.3)), "lampwarm"))
    P.prop(f"Shop_{name}_Trim", trim)

    inside = half - T
    parts = []
    for run, a0, a1, t0, t1, hl in (
        ("x", -inside, inside, T, T + 0.06, holes),
        ("x", -inside, inside, d - T - 0.06, d - T, ()),
        ("y", T, d - T, -inside, -inside + 0.06, ()),
        ("y", T, d - T, inside - 0.06, inside, ()),
    ):
        parts += [(b, paper) for b in wall(run, a0, a1, t0, t1, 1.1, h - 0.1, hl, tile=4 if paper != "gymwall" else None)]
        parts += [(b, "charcoal") for b in wall(run, a0, a1, t0 - 0.03 if t0 > 1 else t0, t1 + 0.03 if t0 < 1 else t1,
                                                0.4, 1.1, tuple(x for x in hl if x[2] < 1.1))]
    parts.append((box((0, d / 2, h - 0.05), (w - 2 * T, d - 2 * T, 0.1)), "white"))
    P.prop(f"Shop_{name}_Interior", parts)


def build_buildings(P):
    house(P)
    garage(P)
    for name, spec in SHOPS.items():
        shop(P, name, spec)
    doors(P)

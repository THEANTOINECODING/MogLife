"""
Décors de rue de Muscle City (mobilier urbain, véhicules, végétation de rue).
À exécuter dans Blender après props_lib.py (fonctions dans le même espace de noms) :
    build_street(Props(pal, "Props_Street"))
Le devant de chaque décor est vers -Y. Dimensions en studs (personnage Roblox ≈ 5 studs).
"""


def bench(P):
    parts = []
    # Pieds en fonte : profil en S de chaque côté
    leg = [(-0.9, 0), (-0.5, 0), (-0.35, 1.2), (0.6, 1.25), (0.75, 2.9), (1.0, 2.9), (0.85, 1.05), (-0.6, 1.0)]
    for x in (-2.6, 2.6):
        bm = extrude(leg, 0.35, y0=-0.175, axis="X")
        parts.append((move(bm, (x, 0, 0)), "charcoal"))
    for k, y in enumerate((-0.75, -0.25, 0.25)):
        parts.append((box((0, y, 1.32), (6.4, 0.42, 0.16), bevel=0.04), "woodlight"))
    for k, z in enumerate((2.0, 2.55)):
        b = box((0, 0.82, z), (6.4, 0.14, 0.38), bevel=0.04)
        parts.append((rotate(b, -12, "X", (0, 0.82, z)), "woodlight"))
    for x in (-3.0, 3.0):
        parts.append((box((x, -0.25, 1.5), (0.18, 1.6, 0.14), bevel=0.03), "charcoal"))
    P.prop("Bench", parts)


def street_lamp(P):
    parts = [
        (cylinder((0, 0, 0), 0.55, 0.5, 8, radius_top=0.45, bevel=0.05), "charcoal"),
        (cylinder((0, 0, 0.5), 0.32, 0.6, 8), "charcoal"),
        (cylinder((0, 0, 1.1), 0.2, 10.6, 8, radius_top=0.14), "darkgrey"),
        (torus((0, 0, 1.15), 0.28, 0.07, 8, 4), "charcoal"),
        (cylinder((0, 0, 11.7), 0.2, 0.3, 8), "charcoal"),
    ]
    # Bras courbé vers l'avant (-Y)
    pts = [(0, 0, 11.6), (0, -0.6, 12.1), (0, -1.4, 12.35), (0, -2.2, 12.3)]
    for a, b in zip(pts, pts[1:]):
        parts.append((segment(a, b, 0.11, 6), "darkgrey"))
    parts.append((box((0, -2.4, 12.15), (1.2, 1.5, 0.45), taper=0.7), "charcoal"))
    parts.append((box((0, -2.4, 11.88), (0.95, 1.2, 0.12)), "lampwarm"))
    P.prop("StreetLamp", parts)


def traffic_light(P):
    parts = [
        (cylinder((0, 0, 0), 0.5, 0.3, 8), "darkgrey"),
        (cylinder((0, 0, 0.3), 0.18, 8.2, 8), "darkgrey"),
        (box((0, -0.1, 8.9), (1.1, 0.9, 3.1), bevel=0.08), "charcoal"),
        (box((0, 0.15, 8.9), (1.4, 0.12, 3.4)), "black"),
    ]
    for k, (z, col) in enumerate(((9.85, "darkred"), (8.9, "darkgold"), (7.95, "neongreen"))):
        parts.append((sphere((0, -0.52, z), (0.34, 0.14, 0.34), 8, 4), col))
        visor = box((0, -0.72, z + 0.33), (0.85, 0.5, 0.08))
        parts.append((rotate(visor, 12, "X", (0, -0.5, z + 0.33)), "black"))
    # Bouton piétons
    parts.append((box((0, -0.25, 3.6), (0.45, 0.3, 0.6), bevel=0.04), "gold"))
    parts.append((cylinder((0, -0.4, 3.6), 0.1, 0.1, 6, axis="Y"), "black"))
    P.prop("TrafficLight", parts)


def hydrant(P):
    parts = [
        (cylinder((0, 0, 0), 0.62, 0.25, 8, bevel=0.04), "darkred"),
        (cylinder((0, 0, 0.25), 0.45, 1.5, 8, radius_top=0.42), "red"),
        (torus((0, 0, 0.35), 0.47, 0.08, 8, 4), "darkred"),
        (torus((0, 0, 1.55), 0.46, 0.08, 8, 4), "darkred"),
        (sphere((0, 0, 1.75), (0.42, 0.42, 0.35), 8, 4), "red"),
        (cylinder((0, 0, 2.02), 0.12, 0.2, 6), "darkred"),
    ]
    for ang in (0, 180):
        n = cylinder((0, 0, 1.15), 0.18, 0.75, 8, axis="X")
        parts.append((rotate(n, ang, "Z"), "red"))
        cap = cylinder((0.72, 0, 1.15), 0.22, 0.1, 6, axis="X")
        parts.append((rotate(cap, ang, "Z"), "darkred"))
    front = cylinder((0, 0, 1.0), 0.24, 0.7, 8, axis="Y")
    parts.append((rotate(front, 180, "Z"), "red"))
    parts.append((cylinder((0, -0.72, 1.0), 0.3, 0.1, 6, axis="Y"), "darkred"))
    P.prop("Hydrant", parts)


def trash_bin(P):
    parts = [
        (cylinder((0, 0, 0), 1.0, 2.6, 10, radius_top=1.1), "green"),
        (torus((0, 0, 2.62), 1.1, 0.12, 10, 4), "darkgreen"),
        (cylinder((0, 0, 2.6), 1.18, 0.25, 10), "darkgreen"),
        (sphere((0, 0, 2.85), (1.15, 1.15, 0.6), 10, 4), "darkgreen"),
        (box((0, -0.75, 3.05), (1.1, 0.5, 0.35)), "black"),
    ]
    for z in (0.6, 1.6):
        parts.append((torus((0, 0, z), 1.05, 0.07, 10, 4), "darkgreen"))
    # Sac poubelle qui dépasse (humour : même la poubelle déborde)
    parts.append((ico((0.35, -0.6, 3.25), 0.45, 1, 0.2, 3), "black"))
    P.prop("TrashBin", parts)


def mailbox(P):
    parts = [
        (box((0, 0, 1.5), (0.35, 0.35, 3.0)), "wood"),
        (box((0, 0, 3.05), (1.0, 0.8, 0.2)), "wood"),
        (box((0, 0, 3.55), (1.2, 2.0, 0.8)), "blue"),
        (cylinder((0, -1.0, 3.95), 0.6, 2.0, 10, axis="Y"), "blue"),
        (box((0, -1.01, 3.75), (1.05, 0.06, 1.1)), "navy"),
        (box((0.68, 0.3, 4.3), (0.08, 0.2, 1.4)), "red"),
        (box((0.68, 0.55, 4.85), (0.08, 0.6, 0.4)), "red"),
    ]
    P.prop("Mailbox", parts)


def bus_shelter(P):
    parts = []
    for x in (-4.3, 4.3):
        for y in (-1.2, 1.4):
            parts.append((box((x, y, 4.0), (0.25, 0.25, 8.0)), "darkgrey"))
    parts.append((box((0, 0.1, 8.15), (9.4, 3.6, 0.3), bevel=0.06), "blue"))
    parts.append((box((0, 0.1, 8.35), (9.0, 3.2, 0.12)), "white"))
    parts.append((box((0, 1.4, 4.4), (8.4, 0.08, 5.6)), "glass"))
    parts.append((box((-4.3, 0.1, 4.4), (0.08, 2.4, 5.6)), "glass"))
    parts.append((box((0, 1.4, 7.6), (8.6, 0.12, 0.6)), "blue"))
    parts.append((box((0, 0.85, 1.5), (5.5, 0.9, 0.18), bevel=0.04), "woodlight"))
    for x in (-2.4, 2.4):
        parts.append((box((x, 0.95, 0.75), (0.2, 0.6, 1.5)), "darkgrey"))
    # Panneau d'arrêt : disque jaune sur poteau (pas de texte)
    parts.append((cylinder((5.4, -1.0, 0), 0.12, 8.6, 6), "darkgrey"))
    parts.append((cylinder((5.4, -1.1, 8.7), 0.9, 0.12, 12, axis="Y"), "yellow"))
    parts.append((cylinder((5.4, -1.25, 8.7), 0.5, 0.06, 12, axis="Y"), "blue"))
    P.prop("BusShelter", parts)


def street_sign(P):
    parts = [(cylinder((0, 0, 0), 0.12, 8.5, 6), "steel")]
    arrow = [(-1.8, -0.35), (1.2, -0.35), (1.2, -0.7), (1.9, 0), (1.2, 0.7), (1.2, 0.35), (-1.8, 0.35)]
    for k, (z, rot, col) in enumerate(((7.6, 25, "green"), (6.7, -40, "blue"), (5.8, 160, "red"))):
        a = extrude(arrow, 0.1, y0=-0.05)
        a = move(a, (1.5, 0, z))
        parts.append((rotate(a, rot, "Z"), col))
    parts.append((sphere((0, 0, 8.6), 0.2, 6, 4), "gold"))
    P.prop("StreetSign", parts)


def traffic_cone(P):
    parts = [
        (box((0, 0, 0.1), (1.6, 1.6, 0.2), bevel=0.05), "black"),
        (cylinder((0, 0, 0.2), 0.62, 2.1, 10, radius_top=0.12), "orange"),
        (cylinder((0, 0, 1.0), 0.47, 0.45, 10, radius_top=0.4), "white"),
    ]
    P.prop("TrafficCone", parts)


def barrier(P):
    parts = []
    for x in (-2.6, 2.6):
        for s in (-1, 1):
            parts.append((segment((x, s * 0.7, 0), (x, 0, 2.6), 0.1, 6), "darkgrey"))
    parts.append((box((0, 0, 2.3), (6.0, 0.2, 0.7), bevel=0.04), "stripe_hazard"))
    parts.append((box((0, 0, 1.3), (6.0, 0.2, 0.5), bevel=0.04), "stripe_hazard"))
    parts.append((sphere((-2.6, 0, 2.85), 0.22, 6, 4), "orange"))
    P.prop("Barrier", parts)


def news_box(P):
    parts = [
        (box((0, 0, 0.4), (1.7, 1.5, 0.8)), "darkgrey"),
        (box((0, 0, 1.9), (1.8, 1.6, 2.2), bevel=0.06), "red"),
        (box((0, -0.81, 2.2), (1.3, 0.05, 1.0)), "glass"),
        (box((0, -0.82, 2.2), (1.0, 0.05, 0.7)), "paper"),
        (box((0.55, -0.85, 1.35), (0.3, 0.08, 0.2)), "steel"),
        (box((0, 0, 3.05), (1.9, 1.7, 0.1)), "darkred"),
    ]
    P.prop("NewsBox", parts)


def bike_rack(P):
    parts = [(box((0, 0, 0.05), (7.0, 1.2, 0.1)), "darkgrey")]
    for k in range(4):
        x = -2.6 + k * 1.75
        pts = [(x - 0.5, 0, 0), (x - 0.5, 0, 2.0), (x - 0.35, 0, 2.4), (x, 0, 2.55), (x + 0.35, 0, 2.4),
               (x + 0.5, 0, 2.0), (x + 0.5, 0, 0)]
        for a, b in zip(pts, pts[1:]):
            parts.append((segment(a, b, 0.09, 6), "chrome"))
    P.prop("BikeRack", parts)


def planter(P):
    parts = [
        (box((0, 0, 0.75), (4.0, 4.0, 1.5), bevel=0.12), "concrete"),
        (box((0, 0, 1.45), (3.5, 3.5, 0.1)), "dirt"),
        (ico((0, 0, 2.4), 1.5, 1, 0.18, 4, squash=0.8), "leaf"),
        (ico((0.9, -0.6, 2.0), 0.9, 1, 0.2, 5), "leaflight"),
    ]
    for k, (x, y, c) in enumerate(((-1.2, -1.2, "pink"), (1.3, -1.1, "yellow"), (-1.3, 1.1, "purple"),
                                   (1.2, 1.3, "red"), (0.1, -1.5, "white"))):
        parts.append((ico((x, y, 1.75), 0.35, 1, 0.1, 10 + k), c))
    P.prop("Planter", parts)


def bollard(P):
    parts = [
        (cylinder((0, 0, 0), 0.4, 2.4, 8, radius_top=0.36), "darkgrey"),
        (sphere((0, 0, 2.4), (0.38, 0.38, 0.3), 8, 4), "darkgrey"),
        (torus((0, 0, 2.0), 0.38, 0.06, 8, 4), "yellow"),
    ]
    P.prop("Bollard", parts)


def picnic_table(P):
    parts = [
        (box((0, 0, 2.6), (6.0, 2.4, 0.2), bevel=0.04), "planks"),
    ]
    for y in (-1.9, 1.9):
        parts.append((box((0, y, 1.5), (6.0, 0.9, 0.18), bevel=0.04), "planks"))
    for x in (-2.3, 2.3):
        for s in (-1, 1):
            parts.append((segment((x, s * 2.1, 0), (x, s * 0.2, 2.55), 0.13, 4), "wood"))
        parts.append((box((x, 0, 1.4), (0.25, 4.6, 0.2)), "wood"))
    P.prop("PicnicTable", parts)


def picket_fence(P):
    parts = []
    for k in range(9):
        x = -3.6 + k * 0.9
        parts.append((extrude([(-0.3, 0), (0.3, 0), (0.3, 2.6), (0, 3.0), (-0.3, 2.6)], 0.14, y0=-0.07, axis="Y"),
                      "white"))
        parts[-1] = (move(parts[-1][0], (x, 0, 0)), "white")
    for z in (0.8, 2.1):
        parts.append((box((0, 0.12, z), (8.2, 0.12, 0.3)), "offwhite"))
    P.prop("PicketFence", parts)


def hedge(P):
    parts = [(box((0, 0, 1.6), (8.0, 1.8, 3.2), bevel=0.35), "leaf")]
    for k in range(6):
        x = -3.2 + k * 1.3
        parts.append((ico((x, -0.4 if k % 2 else 0.3, 3.15), 0.7, 1, 0.25, 20 + k, squash=0.7), "leaflight"))
    P.prop("Hedge", parts)


def bush(P):
    parts = [
        (ico((0, 0, 1.3), 1.6, 1, 0.22, 31, squash=0.85), "leaf"),
        (ico((0.9, 0.4, 1.0), 1.1, 1, 0.25, 32), "darkgreen"),
        (ico((-0.8, -0.5, 1.1), 1.0, 1, 0.25, 33), "leaflight"),
    ]
    P.prop("Bush", parts)


def car(P, name, body, roof_col, pickup=False):
    parts = []
    L, W = 11.0, 5.0
    # Carrosserie : profil latéral extrudé sur la largeur (capot bas, cabine, coffre)
    if pickup:
        prof = [(-5.5, 0.9), (5.5, 0.9), (5.6, 2.2), (5.0, 2.7), (2.4, 2.8), (2.4, 2.8), (-5.4, 2.8), (-5.6, 2.2)]
    else:
        prof = [(-5.5, 0.9), (5.5, 0.9), (5.6, 2.1), (4.9, 2.7), (-4.9, 2.75), (-5.6, 2.2)]
    b = extrude(prof, W, y0=-W / 2)
    parts.append((b, body))
    if pickup:
        cab = [(-0.4, 2.8), (2.3, 2.8), (1.6, 4.5), (-0.2, 4.5)]
        parts.append((extrude(cab, W - 0.3, y0=-(W - 0.3) / 2), roof_col))
        parts.append((box((-3.1, 0, 2.95), (4.4, W - 0.8, 0.3)), "charcoal"))
        for y in (-(W / 2 - 0.15), W / 2 - 0.15):
            parts.append((box((-3.0, y, 3.2), (4.8, 0.3, 0.8)), body))
        parts.append((box((-5.45, 0, 3.2), (0.3, W, 0.8)), body))
        win = [(-0.25, 3.0), (2.05, 3.0), (1.5, 4.3), (-0.1, 4.3)]
    else:
        cab = [(-3.0, 2.75), (2.4, 2.7), (1.3, 4.4), (-2.3, 4.45)]
        parts.append((extrude(cab, W - 0.4, y0=-(W - 0.4) / 2), roof_col))
        win = [(-2.8, 2.9), (2.15, 2.85), (1.15, 4.25), (-2.15, 4.3)]
    parts.append((extrude(win, W - 0.25, y0=-(W - 0.25) / 2), "glass"))
    # Roues avec enjoliveurs, phares, feux, pare-chocs, rétroviseurs
    for x in (-3.4, 3.5):
        for y in (-W / 2 + 0.2, W / 2 - 0.2):
            parts.append((cylinder((x, y - 0.35 if y < 0 else y - 0.35, 1.0), 1.0, 0.7, 10, axis="Y"), "rubber"))
            parts.append((cylinder((x, y - 0.42 if y < 0 else y + 0.35, 1.0), 0.5, 0.08, 8, axis="Y"), "chrome"))
    for y in (-1.6, 1.6):
        parts.append((box((5.55, y, 2.05), (0.15, 0.9, 0.5)), "lampwarm"))
        parts.append((box((-5.55, y, 2.1), (0.15, 0.8, 0.45)), "red"))
    parts.append((box((5.75, 0, 1.25), (0.35, W - 0.2, 0.5), bevel=0.08), "chrome"))
    parts.append((box((-5.75, 0, 1.25), (0.35, W - 0.2, 0.5), bevel=0.08), "chrome"))
    parts.append((box((5.62, 0, 1.75), (0.1, 2.0, 0.4)), "charcoal"))
    for y in (-W / 2 - 0.25, W / 2 + 0.25):
        parts.append((box((1.9 if not pickup else 1.7, y, 3.15), (0.5, 0.35, 0.35)), body))
    # La voiture est construite le long de X ; on la tourne pour que l'avant regarde -Y
    rotated = [(rotate(bm, -90, "Z"), spec) for bm, spec in parts]
    P.prop(name, rotated)


def food_truck(P):
    """Camion à shakes protéinés (futur habitant / aide) : un shaker géant sur le toit."""
    parts = []
    L, W = 16.0, 6.4
    body = [(-8, 1.0), (8, 1.0), (8.1, 3.0), (7.2, 4.0), (5.0, 4.2), (4.6, 8.4), (-8, 8.4)]
    parts.append((extrude(body, W, y0=-W / 2), "white"))
    parts.append((box((-1.6, -W / 2 - 0.02, 3.2), (12.8, 0.08, 1.0)), "stripe_bluewhite"))
    # Fenêtre de service, comptoir, auvent rayé
    parts.append((box((-1.8, -W / 2 - 0.03, 5.6), (7.0, 0.08, 2.6)), "charcoal"))
    parts.append((box((-1.8, -W / 2 - 0.5, 4.3), (7.4, 1.0, 0.25)), "steel"))
    aw = box((-1.8, -W / 2 - 1.3, 7.3), (7.8, 2.6, 0.18))
    parts.append((rotate(aw, -18, "X", (-1.8, -W / 2, 7.4)), "stripe_redwhite"))
    parts.append((extrude([(5.0, 4.4), (7.1, 4.2), (6.4, 3.2), (5.0, 3.3)], W - 0.4, y0=-(W - 0.4) / 2), "glass"))
    for x in (-5.0, 5.0):
        for y in (-W / 2 + 0.3, W / 2 - 0.3):
            parts.append((cylinder((x, y - 0.4, 1.1), 1.1, 0.8, 10, axis="Y"), "rubber"))
            parts.append((cylinder((x, y - 0.48 if y < 0 else y + 0.4, 1.1), 0.55, 0.08, 8, axis="Y"), "chrome"))
    for y in (-1.8, 1.8):
        parts.append((box((8.1, y, 2.4), (0.15, 1.0, 0.6)), "lampwarm"))
    parts.append((box((8.25, 0, 1.4), (0.4, W, 0.6), bevel=0.08), "chrome"))
    # Shaker géant sur le toit
    parts.append((cylinder((-2.0, 0, 8.4), 1.7, 4.4, 12, radius_top=1.9), "hotpink"))
    parts.append((cylinder((-2.0, 0, 12.8), 1.95, 0.8, 12), "charcoal"))
    parts.append((cylinder((-2.0, 0, 13.6), 0.6, 1.0, 8, radius_top=0.4), "charcoal"))
    parts.append((torus((-2.0, 0, 10.6), 1.85, 0.12, 12, 4), "white"))
    rotated = [(rotate(bm, -90, "Z"), spec) for bm, spec in parts]
    P.prop("ShakeTruck", rotated)


def scooter(P):
    parts = [
        (box((0, 0.2, 0.75), (0.9, 3.2, 0.25), bevel=0.06), "red"),
        (cylinder((0, -1.6, 0.45), 0.45, 0.3, 10, axis="X"), "rubber"),
        (cylinder((0, 1.8, 0.45), 0.45, 0.3, 10, axis="X"), "rubber"),
        (segment((0, -1.6, 0.45), (0, -1.9, 3.8), 0.1, 6), "chrome"),
        (segment((-0.9, -1.9, 3.8), (0.9, -1.9, 3.8), 0.09, 6), "chrome"),
    ]
    for x in (-0.9, 0.9):
        parts.append((cylinder((x, -1.9, 3.8), 0.14, 0.4, 6, axis="X"), "black"))
    parts.append((box((0, 1.9, 1.0), (0.6, 0.5, 0.25)), "red"))
    P.prop("Scooter", parts)


def cafe_set(P):
    parts = [
        (cylinder((0, 0, 0), 0.8, 0.12, 10), "charcoal"),
        (cylinder((0, 0, 0.12), 0.12, 2.6, 6), "charcoal"),
        (cylinder((0, 0, 2.7), 1.4, 0.15, 12), "white"),
        (cylinder((0, 0, 2.85), 0.08, 3.6, 6), "white"),
        (cone((0, 0, 5.4), 3.6, 1.5, 8), "stripe_redwhite"),
        (sphere((0, 0, 6.95), 0.15, 6, 4), "white"),
    ]
    for ang in (0, 120, 240):
        chair = [
            (box((0, 2.6, 1.6), (1.6, 1.6, 0.15)), "red"),
            (box((0, 3.35, 2.6), (1.6, 0.15, 1.9)), "red"),
        ]
        for x in (-0.65, 0.65):
            for y in (2.0, 3.25):
                chair.append((segment((x, y, 0), (x, y, 1.55), 0.07, 4), "charcoal"))
        for bm, c in chair:
            parts.append((rotate(bm, ang, "Z"), c))
    P.prop("CafeSet", parts)


def build_street(P):
    for fn in (bench, street_lamp, traffic_light, hydrant, trash_bin, mailbox, bus_shelter, street_sign,
               traffic_cone, barrier, news_box, bike_rack, planter, bollard, picnic_table, picket_fence, hedge,
               bush, scooter, cafe_set):
        fn(P)
    car(P, "CarSedan", "blue", "blue")
    car(P, "CarSedanRed", "red", "red")
    car(P, "CarPickup", "orange", "orange", pickup=True)
    food_truck(P)

"""
Décors d'événements saisonniers (Halloween, Noël) et objets liés aux boss (pour leurs zones et leurs combats).
À exécuter après props_lib.py :  build_events(Props(pal, "Props_Events"))
"""


# ------------------------------------------------------------------ Halloween
def pumpkin(P, name="Pumpkin", carved=False):
    parts = []
    for k in range(6):
        a = math.radians(k * 60)
        parts.append((sphere((math.cos(a) * 0.55, math.sin(a) * 0.55, 1.1), (0.75, 0.75, 1.0), 8, 6), "orange"))
    parts.append((sphere((0, 0, 1.1), (1.1, 1.1, 1.05), 10, 6), "orange"))
    parts.append((segment((0, 0, 2.0), (0.2, 0.1, 2.6), 0.15, 5, 0.1), "darkgreen"))
    parts.append((sphere((0.5, 0.2, 2.15), (0.4, 0.2, 0.08), 6, 3), "leaf"))
    if carved:
        for s in (-1, 1):
            parts.append((extrude([(-0.25, 0), (0.25, 0), (0, 0.4)], 0.1, y0=-1.34), "flame"))
            parts[-1] = (move(parts[-1][0], (s * 0.45, 0, 1.3)), "flame")
        mouth = [(-0.7, 0), (0.7, 0), (0.5, -0.35), (0.25, -0.15), (0, -0.4), (-0.25, -0.15), (-0.5, -0.35)]
        m = extrude(mouth, 0.1, y0=-1.34)
        parts.append((move(m, (0, 0, 0.9)), "flame"))
    P.prop(name, parts)


def gravestone(P):
    prof = [(-1.0, 0), (1.0, 0), (1.0, 2.2)] + [(math.cos(math.radians(a)) * 1.0, 2.2 + math.sin(math.radians(a)) * 0.9)
                                                for a in range(20, 180, 20)] + [(-1.0, 2.2)]
    parts = [
        (extrude(prof, 0.5, y0=-0.25), "rocktex"),
        (box((0, 0, 0.15), (2.6, 1.6, 0.3)), "dirt"),
        (box((0, -0.27, 2.1), (1.0, 0.05, 0.2)), "darkrock"),
        (box((0, -0.27, 2.1), (0.2, 0.05, 1.0)), "darkrock"),
        (ico((0.9, -0.6, 0.3), 0.3, 1, 0.2, 600), "leaf"),
    ]
    P.prop("Gravestone", parts)


def dead_tree(P):
    parts = [(segment((0, 0, 0), (0.3, 0, 7.0), 0.6, 6, 0.3), "bark")]
    branches = [((0.2, 0, 4.0), (-1.8, 0.3, 6.0)), ((0.25, 0, 5.0), (2.0, -0.4, 6.8)), ((0.3, 0, 6.5), (-0.8, 0.5, 8.4)),
                ((-1.2, 0.2, 5.4), (-2.4, 0.1, 5.8)), ((1.4, -0.3, 6.2), (2.2, 0.4, 7.6))]
    for a, b in branches:
        parts.append((segment(a, b, 0.22, 5, 0.06), "bark"))
    for k in range(3):
        a = math.radians(k * 120)
        parts.append((segment((0, 0, 0.6), (math.cos(a) * 1.4, math.sin(a) * 1.4, 0), 0.3, 5, 0.1), "bark"))
    P.prop("DeadTree", parts)


def cauldron(P):
    parts = [
        (sphere((0, 0, 1.3), (1.5, 1.5, 1.2), 10, 6), "charcoal"),
        (torus((0, 0, 2.2), 1.2, 0.15, 10, 4), "charcoal"),
        (cylinder((0, 0, 2.0), 1.15, 0.15, 10), "neongreen"),
    ]
    for k in range(3):
        a = math.radians(k * 120)
        parts.append((segment((math.cos(a) * 1.0, math.sin(a) * 1.0, 0.6), (math.cos(a) * 1.3, math.sin(a) * 1.3, 0), 0.12, 4),
                      "charcoal"))
        parts.append((sphere((math.cos(a) * 0.5, math.sin(a) * 0.4, 2.4 + k * 0.2), 0.2 + k * 0.05, 6, 4), "neongreen"))
    P.prop("Cauldron", parts)


# ------------------------------------------------------------------ Noël
def xmas_tree(P):
    parts = [(cylinder((0, 0, 0), 1.2, 1.2, 8, radius_top=1.0), "red"), (cylinder((0, 0, 1.2), 0.4, 1.2, 6), "bark")]
    for k in range(4):
        t = k / 4
        parts.append((cone((0, 0, 2.0 + k * 2.0), 3.6 * (1 - t * 0.65), 3.2, 10), "darkgreen" if k % 2 == 0 else "green"))
    # Boules au bord de chaque étage, bien visibles
    for k in range(4):
        R = 3.6 * (1 - (k / 4) * 0.65)
        for j in range(5):
            a = math.radians(j * 72 + k * 30)
            parts.append((sphere((math.cos(a) * R * 0.9, math.sin(a) * R * 0.9, 2.0 + k * 2.0 + 0.35), 0.28, 6, 4),
                          ["red", "gold", "blue", "white", "hotpink"][(j + k) % 5]))
    star = [(math.cos(math.radians(90 + k * 36)) * (0.9 if k % 2 == 0 else 0.4),
             math.sin(math.radians(90 + k * 36)) * (0.9 if k % 2 == 0 else 0.4)) for k in range(10)]
    s = extrude(star, 0.3, y0=-0.15)
    parts.append((move(s, (0, 0, 11.3)), "gold"))
    P.prop("ChristmasTree", parts)


def gift(P, name, color, ribbon):
    parts = [
        (box((0, 0, 0.9), (1.8, 1.8, 1.8), bevel=0.04), color),
        (box((0, 0, 0.9), (0.35, 1.84, 1.84)), ribbon),
        (box((0, 0, 0.9), (1.84, 0.35, 1.84)), ribbon),
        (torus((-0.35, 0, 1.95), 0.35, 0.1, 8, 4, axis="X"), ribbon),
        (torus((0.35, 0, 1.95), 0.35, 0.1, 8, 4, axis="X"), ribbon),
    ]
    P.prop(name, parts)


def candy_cane(P):
    parts = [(cylinder((0, 0, 0), 0.35, 5.0, 8), "stripe_redwhite")]
    pts = [(0, 0, 5.0), (0.3, 0, 5.8), (0.9, 0, 6.1), (1.5, 0, 5.8), (1.7, 0, 5.2)]
    for a, b in zip(pts, pts[1:]):
        parts.append((segment(a, b, 0.35, 8), "stripe_redwhite"))
    P.prop("CandyCane", parts)


def snow_pile(P):
    parts = [(ico((0, 0, 0.6), 2.2, 2, 0.12, 610, squash=0.4), "snow"),
             (ico((1.4, 0.6, 0.4), 1.2, 1, 0.15, 611, squash=0.5), "snow")]
    P.prop("SnowPile", parts)


# ------------------------------------------------------------------ objets des boss
def tanning_bed(P):
    """Le solarium de Brayan le Bronzé."""
    parts = [
        (box((0, 0, 1.0), (3.4, 7.4, 2.0), bevel=0.2), "white"),
        (box((0, 0, 2.05), (2.8, 6.8, 0.1)), "neonblue"),
        (box((0, 0.6, 3.2), (3.6, 6.2, 1.2), bevel=0.25), "white"),
        (box((0, 0.6, 2.58), (3.0, 5.8, 0.06)), "neonblue"),
        (box((0, 3.9, 2.4), (3.4, 0.6, 2.4)), "lightgrey"),
        (box((1.75, -2.8, 1.4), (0.08, 0.8, 0.6)), "screentex"),
    ]
    parts[2] = (rotate(parts[2][0], 18, "X", (0, 3.7, 2.6)), "white")
    parts[3] = (rotate(parts[3][0], 18, "X", (0, 3.7, 2.6)), "neonblue")
    P.prop("TanningBed", parts)


def tactics_board(P):
    """Le tableau de Coach Turbo : des croix, des ronds et des flèches partout (pas de texte)."""
    parts = [
        (box((0, 0, 4.0), (6.0, 0.3, 3.6), bevel=0.06), "wood"),
        (box((0, -0.16, 4.0), (5.6, 0.04, 3.2)), "darkgreen"),
    ]
    for x in (-2.4, 2.4):
        parts.append((segment((x, 0.3, 0), (x, 0, 5.6), 0.1, 4), "wood"))
        parts.append((segment((x, -0.8, 0), (x, 0, 3.0), 0.08, 4), "wood"))
    for k, (x, z) in enumerate(((-1.8, 4.8), (0.4, 3.4), (1.6, 4.9))):
        parts.append((torus((x, -0.2, z), 0.3, 0.06, 8, 4, axis="Y"), "white"))
    for k, (x, z) in enumerate(((-0.6, 4.6), (1.0, 3.6), (-1.6, 3.3))):
        for ang in (45, -45):
            b = box((x, -0.2, z), (0.7, 0.04, 0.1))
            parts.append((rotate(b, ang, "Y", (x, -0.2, z)), "yellow"))
    parts.append((segment((-1.5, -0.2, 4.6), (0.2, -0.2, 3.6), 0.05, 4), "white"))
    parts.append((segment((0.5, -0.2, 3.7), (1.4, -0.2, 4.6), 0.05, 4), "white"))
    parts.append((box((0, -0.3, 2.05), (5.6, 0.4, 0.15)), "wooddark"))
    P.prop("TacticsBoard", parts)


def crown_cushion(P):
    """La couronne du Roi du Quartier, sur son coussin (récompense, décor de l'arène)."""
    parts = [
        (box((0, 0, 1.6), (2.4, 2.4, 3.2), bevel=0.1), "marble"),
        (box((0, 0, 3.45), (2.2, 2.2, 0.5), bevel=0.25), "fabricred"),
        (cylinder((0, 0, 3.7), 0.85, 0.6, 10), "gold"),
    ]
    for k in range(6):
        a = math.radians(k * 60)
        parts.append((cone((math.cos(a) * 0.75, math.sin(a) * 0.75, 4.3), 0.25, 0.7, 4), "gold"))
        parts.append((sphere((math.cos(a) * 0.86, math.sin(a) * 0.86, 4.0), 0.12, 4, 3), "red" if k % 2 else "blue"))
    for x in (-1.1, 1.1):
        for y in (-1.1, 1.1):
            parts.append((sphere((x, y, 3.45), 0.15, 4, 3), "gold"))
    P.prop("CrownCushion", parts)


def pump_altar(P):
    """L'autel du Dieu du Pump : marches, haltère sacré et flammes."""
    parts = [
        (box((0, 0, 0.5), (10.0, 6.0, 1.0)), "marble"),
        (box((0, 0.5, 1.5), (8.0, 4.6, 1.0)), "marble"),
        (box((0, 1.0, 3.0), (5.0, 3.0, 2.0), bevel=0.1), "marblegold"),
        (cylinder((-3.0, 1.0, 4.6), 0.25, 6.0, 8, axis="X"), "gold"),
    ]
    for s in (-1, 1):
        parts.append((cylinder((s * 2.4 - 0.4, 1.0, 4.6), 1.3, 0.8, 12, axis="X", bevel=0.08), "gold"))
        parts.append((cylinder((s * 4.3, -1.5, 1.0), 0.5, 2.0, 8), "marble"))
        parts.append((cylinder((s * 4.3, -1.5, 3.0), 0.8, 0.5, 8, radius_top=1.0), "gold"))
        parts.append((cone((s * 4.3, -1.5, 3.5), 0.7, 1.6, 5), "flame"))
    P.prop("PumpAltar", parts)


def nolegs_socks(P):
    """Les chaussettes géantes de M. Pas-Les-Jambes, étendues sur un fil (décor de l'arène)."""
    parts = []
    for x in (-3.0, 3.0):
        parts.append((cylinder((x, 0, 0), 0.12, 6.0, 6), "wood"))
    parts.append((segment((-3.0, 0, 5.8), (3.0, 0, 5.8), 0.04, 4), "rope"))
    for k, x in enumerate((-1.6, 1.2)):
        sock = [(-0.5, 0), (0.5, 0), (0.5, -2.8), (1.4, -3.2), (1.4, -3.9), (-0.5, -3.9)]
        s = extrude(sock, 0.3, y0=-0.15)
        parts.append((move(s, (x, 0, 5.8)), "stripe_redwhite" if k == 0 else "stripe_bluewhite"))
        parts.append((box((x, 0, 5.8), (0.3, 0.4, 0.4)), "yellow"))
    P.prop("GiantSocks", parts)


def build_events(P):
    pumpkin(P)
    pumpkin(P, "JackOLantern", carved=True)
    for fn in (gravestone, dead_tree, cauldron, xmas_tree, candy_cane, snow_pile, tanning_bed, tactics_board,
               crown_cushion, pump_altar, nolegs_socks):
        fn(P)
    gift(P, "GiftRed", "red", "gold")
    gift(P, "GiftBlue", "blue", "white")
    gift(P, "GiftGreen", "green", "red")

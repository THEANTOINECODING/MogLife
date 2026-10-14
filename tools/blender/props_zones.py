"""
Décors des futures zones (design/04_MONDE_PNJ.md) : la plage, la montagne, la Lune, l'Olympe.
Préparés à l'avance pour les mises à jour. À exécuter après props_lib.py :
    build_zones(Props(pal, "Props_Zones"))
"""


# ------------------------------------------------------------------ la plage (Muscle Beach)
def surfboard(P):
    prof = [(math.cos(math.radians(a)) * 1.0, math.sin(math.radians(a)) * 4.0) for a in range(0, 360, 30)]
    bm = extrude([(x, z) for x, z in prof], 0.3, y0=-0.15)
    move(bm, (0, 0, 4.0))
    parts = [(bm, "stripe_redwhite"), (box((0, 0.25, 0.4), (1.8, 0.8, 0.8)), "sandtex")]
    P.prop("Surfboard", parts)


def lifebuoy_post(P):
    parts = [
        (box((0, 0, 3.0), (0.4, 0.4, 6.0)), "white"),
        (torus((0, -0.45, 4.2), 1.0, 0.3, 12, 5, axis="Y"), "stripe_redwhite"),
        (box((0, 0, 6.1), (0.6, 0.6, 0.2)), "red"),
    ]
    P.prop("LifebuoyPost", parts)


def sandcastle(P):
    parts = [(box((0, 0, 0.6), (5.0, 5.0, 1.2), bevel=0.2), "sandtex")]
    for x in (-1.9, 1.9):
        for y in (-1.9, 1.9):
            parts.append((cylinder((x, y, 1.2), 0.7, 1.6, 8), "sandtex"))
            parts.append((cone((x, y, 2.8), 0.8, 1.0, 8), "sandtex"))
    parts.append((box((0, 0, 2.0), (2.4, 2.4, 1.6)), "sandtex"))
    parts.append((cylinder((0, 0, 2.8), 0.8, 1.8, 8), "sandtex"))
    parts.append((cone((0, 0, 4.6), 0.9, 1.2, 8), "sandtex"))
    parts.append((segment((0, 0, 5.6), (0, 0, 6.6), 0.05, 4), "wood"))
    parts.append((box((0.35, 0, 6.35), (0.7, 0.05, 0.45)), "red"))
    parts.append((box((0, -1.25, 1.9), (0.8, 0.06, 1.0)), "darkbrown"))
    parts.append((cylinder((3.4, -1.6, 0), 0.6, 1.0, 8, radius_top=0.75), "blue"))
    parts.append((segment((3.4, -1.6, 0.8), (4.0, -2.4, 1.6), 0.05, 4), "yellow"))
    P.prop("Sandcastle", parts)


def beach_towel(P):
    parts = [(box((0, 0, 0.05), (3.0, 6.0, 0.1)), "stripe_bluewhite"),
             (box((0, 2.4, 0.3), (1.6, 0.8, 0.4), bevel=0.15), "yellow")]
    P.prop("BeachTowel", parts)


def volleyball_net(P):
    parts = []
    for x in (-6.0, 6.0):
        parts.append((cylinder((x, 0, 0), 0.2, 8.0, 8), "white"))
        parts.append((segment((x, 0, 7.5), (x * 1.25, 0, 0), 0.04, 4), "steel"))
    parts.append((box((0, 0, 6.6), (12.0, 0.06, 2.0)), "checker"))
    parts.append((box((0, 0, 7.65), (12.0, 0.1, 0.12)), "white"))
    parts.append((sphere((2.0, -2.0, 0.55), 0.55, 8, 6), "yellow"))
    P.prop("VolleyballNet", parts)


def beach_hut(P):
    """Kiosque à smoothies protéinés de la plage."""
    parts = [
        (box((0, 0.5, 2.0), (6.0, 5.0, 4.0)), "planks"),
        (box((0, -2.2, 1.9), (6.4, 0.6, 0.3)), "woodlight"),
        (box((0, -2.04, 3.0), (5.0, 0.1, 1.8)), "charcoal"),
        (cone((0, 0.5, 4.0), 5.4, 3.2, 6), "thatch"),
        (box((0, -2.1, 1.0), (5.6, 0.2, 1.8)), "stripe_greenwhite"),
    ]
    for x in (-2.8, 2.8):
        parts.append((cylinder((x, -2.4, 0), 0.2, 4.6, 6), "palmbark"))
    for k, c in enumerate(("hotpink", "orange", "lime")):
        parts.append((cylinder((-1.5 + k * 1.5, -2.2, 2.05), 0.3, 0.8, 8, radius_top=0.35), c))
        parts.append((segment((-1.5 + k * 1.5, -2.2, 2.8), (-1.3 + k * 1.5, -2.1, 3.4), 0.04, 4), "white"))
    P.prop("BeachHut", parts)


def dip_station(P):
    """Barres parallèles de Muscle Beach (dips en plein air)."""
    parts = []
    for x in (-1.4, 1.4):
        for y in (-2.4, 2.4):
            parts.append((cylinder((x, y, 0), 0.15, 4.0, 6), "steel"))
        parts.append((cylinder((x, -2.6, 4.0), 0.14, 5.2, 8, axis="Y"), "chrome"))
        parts.append((cylinder((x, 2.4, 0), 0.4, 0.15, 6), "darkgrey"))
        parts.append((cylinder((x, -2.4, 0), 0.4, 0.15, 6), "darkgrey"))
    P.prop("DipStation", parts)


def crab(P):
    parts = [(sphere((0, 0, 0.6), (1.0, 0.7, 0.45), 8, 5), "red")]
    for s in (-1, 1):
        parts.append((segment((s * 0.4, -0.5, 0.8), (s * 0.5, -0.7, 1.4), 0.05, 4), "red"))
        parts.append((sphere((s * 0.5, -0.72, 1.45), 0.15, 6, 4), "white"))
        parts.append((segment((s * 0.8, -0.3, 0.6), (s * 1.4, -1.0, 0.8), 0.12, 5), "red"))
        parts.append((sphere((s * 1.5, -1.2, 0.9), (0.45, 0.35, 0.3), 6, 4), "red"))
        for k in range(3):
            parts.append((segment((s * 0.7, -0.1 + k * 0.3, 0.5), (s * 1.4, 0.0 + k * 0.4, 0.0), 0.05, 4), "darkred"))
    # Le crabe a des pinces énormes, évidemment
    P.prop("Crab", parts)


# ------------------------------------------------------------------ la montagne (entraînement années 80)
def log_cabin(P):
    parts = []
    for k in range(7):
        z = 0.5 + k * 0.95
        for y in (-3.5, 3.5):
            parts.append((cylinder((-5.0, y, z), 0.5, 10.0, 8, axis="X"), "bark"))
        for x in (-4.5, 4.5):
            parts.append((cylinder((x, -4.0, z + 0.45), 0.5, 8.0, 8, axis="Y"), "bark"))
    parts.append((box((0, -4.55, 2.2), (2.2, 0.2, 4.2)), "wooddark"))
    parts.append((box((2.8, -4.55, 4.0), (1.8, 0.2, 1.4)), "glass"))
    parts.append((box((2.8, -4.6, 3.2), (2.2, 0.3, 0.2)), "woodlight"))
    for side in (-1, 1):
        roof = box((0, side * 2.3, 8.6), (11.0, 5.4, 0.4))
        parts.append((rotate(roof, side * -28, "X", (0, 0, 8.6)), "roofshingle"))
    parts.append((box((3.0, 1.5, 9.5), (1.2, 1.2, 3.0)), "rocktex"))
    P.prop("LogCabin", parts)


def campfire(P):
    parts = []
    for k in range(8):
        a = math.radians(k * 45)
        parts.append((ico((math.cos(a) * 1.5, math.sin(a) * 1.5, 0.3), 0.45, 1, 0.2, 200 + k), "rock"))
    for k in range(4):
        a = math.radians(k * 90 + 20)
        parts.append((segment((math.cos(a) * 1.0, math.sin(a) * 1.0, 0.2), (0, 0, 1.2), 0.2, 5), "bark"))
    parts.append((cone((0, 0, 0.4), 0.8, 2.2, 5), "flame"))
    parts.append((cone((0.3, 0.2, 0.4), 0.5, 1.5, 5), "yellow"))
    parts.append((cone((-0.3, -0.2, 0.4), 0.5, 1.3, 5), "ember"))
    P.prop("Campfire", parts)


def tent(P):
    prof = [(-3.0, 0), (3.0, 0), (0, 4.2)]
    parts = [(extrude(prof, 6.0, y0=-3.0), "orange"),
             (extrude([(-1.0, 0), (1.0, 0), (0, 2.6)], 0.1, y0=-3.06), "darkbrown")]
    for x in (-3.4, 3.4):
        parts.append((segment((x * 0.9, -3.2, 0), (x * 1.2, -3.6, 0), 0.05, 4), "steel"))
    P.prop("Tent", parts)


def tire_on_rope(P):
    """Entraînement à l'ancienne : un pneu suspendu à une branche."""
    parts = [
        (box((0, 0, 0.3), (1.6, 1.6, 0.6)), "rocktex"),
        (cylinder((0, 0, 0.6), 0.5, 9.0, 8, radius_top=0.4), "bark"),
        (segment((0, 0, 8.6), (3.6, 0, 9.0), 0.3, 6, 0.2), "bark"),
        (segment((3.2, 0, 8.9), (3.2, 0, 4.0), 0.06, 4), "rope"),
        (torus((3.2, 0, 3.2), 1.1, 0.4, 12, 5, axis="X"), "rubber"),
    ]
    P.prop("TireOnRope", parts)


def boombox(P):
    parts = [
        (box((0, 0, 1.0), (4.0, 1.2, 2.0), bevel=0.1), "silver"),
        (cylinder((-1.2, -0.62, 1.0), 0.7, 0.1, 12, axis="Y"), "charcoal"),
        (cylinder((1.2, -0.62, 1.0), 0.7, 0.1, 12, axis="Y"), "charcoal"),
        (box((0, -0.62, 1.2), (1.1, 0.06, 0.7)), "darkgrey"),
        (segment((-1.6, 0, 2.0), (-1.2, 0, 2.6), 0.08, 4), "charcoal"),
        (segment((1.6, 0, 2.0), (1.2, 0, 2.6), 0.08, 4), "charcoal"),
        (segment((-1.2, 0, 2.6), (1.2, 0, 2.6), 0.08, 4), "charcoal"),
    ]
    for k in range(4):
        parts.append((box((-0.4 + k * 0.27, -0.64, 0.55), (0.18, 0.05, 0.18)), "neongreen" if k == 0 else "red"))
    P.prop("Boombox", parts)


def yak(P):
    """Le yack de la montagne (animal de compagnie des sportifs des années 80)."""
    parts = [
        (box((0, 0.3, 2.6), (2.4, 4.6, 2.2), bevel=0.4), "darkbrown"),
        (box((0, 0.2, 1.6), (2.6, 4.8, 1.2), bevel=0.3, taper=1.1), "brown"),
        (box((0, -2.5, 2.9), (1.4, 1.6, 1.4), bevel=0.3), "darkbrown"),
        (box((0, -3.1, 2.5), (1.0, 0.6, 0.8), bevel=0.2), "tan"),
    ]
    for s in (-1, 1):
        parts.append((segment((s * 0.6, -2.4, 3.5), (s * 1.4, -2.6, 3.8), 0.15, 5, 0.08), "offwhite"))
        parts.append((segment((s * 1.4, -2.6, 3.8), (s * 1.5, -2.9, 4.4), 0.08, 5, 0.04), "offwhite"))
        parts.append((sphere((s * 0.45, -3.2, 3.1), 0.12, 6, 4), "black"))
        for y in (-1.4, 1.8):
            parts.append((box((s * 0.75, y, 0.6), (0.6, 0.6, 1.2)), "darkbrown"))
    parts.append((segment((0, 2.6, 2.8), (0, 3.2, 1.8), 0.15, 4), "darkbrown"))
    P.prop("Yak", parts)


def snowman(P):
    parts = [
        (sphere((0, 0, 1.4), 1.5, 10, 7), "snow"),
        (sphere((0, 0, 3.6), 1.05, 10, 7), "snow"),
        (sphere((0, 0, 5.2), 0.75, 10, 7), "snow"),
        (cone((0, -0.7, 5.2), 0.15, 0.8, 6), "carrot"),
        (cylinder((0, 0, 5.8), 0.55, 0.12, 10), "black"),
        (cylinder((0, 0, 5.9), 0.38, 0.8, 10), "black"),
    ]
    parts[3] = (rotate(parts[3][0], 90, "X", (0, -0.7, 5.2)), "carrot")
    for s in (-1, 1):
        parts.append((sphere((s * 0.25, -0.65, 5.4), 0.08, 4, 3), "black"))
        parts.append((segment((s * 0.9, 0, 3.8), (s * 2.2, 0, 4.6), 0.07, 4), "bark"))
    # Il soulève un petit haltère, bien sûr
    parts.append((cylinder((2.0, -0.4, 4.6), 0.06, 0.8, 6, axis="Y"), "chrome"))
    for y in (-0.45, 0.45):
        parts.append((cylinder((2.0, y - 0.1, 4.6), 0.22, 0.2, 8, axis="Y"), "charcoal"))
    parts.append((torus((0, 0, 4.5), 0.75, 0.15, 10, 4), "red"))
    P.prop("Snowman", parts)


# ------------------------------------------------------------------ la Lune
def lunar_lander(P):
    parts = [
        (box((0, 0, 4.0), (4.0, 4.0, 2.6), bevel=0.2), "gold"),
        (cylinder((0, 0, 5.3), 1.8, 2.0, 8, radius_top=1.2), "silver"),
        (box((0, -1.4, 5.9), (0.9, 0.2, 0.9)), "charcoal"),
        (cone((0, 0, 7.3), 0.3, 1.6, 6), "silver"),
        (cylinder((0, 0, 2.0), 1.0, 0.8, 8, radius_top=0.6), "darkgrey"),
    ]
    for k in range(4):
        a = math.radians(45 + k * 90)
        d = Vector((math.cos(a), math.sin(a), 0))
        parts.append((segment(tuple(d * 1.6 + Vector((0, 0, 3.4))), tuple(d * 3.4), 0.12, 5), "silver"))
        parts.append((cylinder(tuple(d * 3.4), 0.6, 0.15, 8), "silver"))
    for k in range(4):
        parts.append((box((-1.6 + k * 1.0, -2.75, 1.6), (0.5, 0.15, 0.3)), "silver"))
    P.prop("LunarLander", parts)


def moon_rover(P):
    parts = [
        (box((0, 0, 1.8), (3.6, 5.6, 0.4)), "silver"),
        (box((0, 1.0, 2.4), (3.0, 1.6, 0.8)), "gold"),
        (box((0, -1.0, 2.6), (2.6, 1.4, 1.0)), "lightgrey"),
        (segment((1.2, 1.6, 2.6), (1.2, 1.6, 5.0), 0.06, 4), "silver"),
        (cone((1.2, 1.6, 5.0), 1.0, 0.5, 8), "white"),
    ]
    parts[4] = (rotate(parts[4][0], 180, "X", (1.2, 1.6, 5.25)), "white")
    for x in (-1.9, 1.9):
        for y in (-1.9, 1.9):
            parts.append((cylinder((x - (0.25 if x < 0 else 0), y, 0.8), 0.8, 0.5, 10, axis="X"), "steel"))
    P.prop("MoonRover", parts)


def satellite_dumbbell(P):
    """L'haltère satellite (exercice prévu pour la Lune) : panneaux solaires, antenne."""
    parts = [(cylinder((-2.0, 0, 2.5), 0.25, 4.0, 8, axis="X"), "chrome")]
    for s in (-1, 1):
        parts.append((cylinder((s * 2.2 - 0.6, 0, 2.5), 1.4, 1.2, 12, axis="X", bevel=0.1), "silver"))
        parts.append((box((s * 3.6, 0, 2.5), (1.6, 0.1, 3.2)), "screentex"))
        parts.append((segment((s * 2.8, 0, 2.5), (s * 3.0, 0, 2.5), 0.08, 4), "steel"))
    parts.append((segment((0, 0, 2.7), (0.4, 0, 4.4), 0.05, 4), "steel"))
    parts.append((cone((0.4, 0, 4.4), 0.5, 0.3, 8), "white"))
    parts.append((box((0, 0, 0.4), (1.6, 1.6, 0.8)), "darkgrey"))
    parts.append((segment((0, 0, 0.8), (0, 0, 2.3), 0.1, 4), "steel"))
    P.prop("SatelliteDumbbell", parts)


def moon_flag(P):
    parts = [
        (cylinder((0, 0, 0), 0.08, 7.0, 6), "silver"),
        (cylinder((0, 0, 6.9), 0.06, 3.4, 6, axis="X"), "silver"),
        (box((1.7, 0, 5.6), (3.4, 0.05, 2.4)), "purple"),
        (box((1.7, -0.05, 5.6), (1.8, 0.04, 0.25)), "gold"),
        (box((0.85, -0.05, 5.6), (0.3, 0.04, 1.1)), "gold"),
        (box((2.55, -0.05, 5.6), (0.3, 0.04, 1.1)), "gold"),
    ]
    P.prop("MoonFlag", parts)


def crater(P):
    parts = [(torus((0, 0, 0.2), 4.0, 1.0, 16, 5), "moon"), (cylinder((0, 0, 0), 3.6, 0.1, 16), "darkrock")]
    P.prop("Crater", parts)


# ------------------------------------------------------------------ l'Olympe
def greek_column(P, name="GreekColumn", broken=False):
    h = 6.0 if broken else 12.0
    parts = [
        (box((0, 0, 0.3), (2.8, 2.8, 0.6)), "marble"),
        (cylinder((0, 0, 0.6), 1.2, 0.4, 12), "marble"),
        (cylinder((0, 0, 1.0), 1.0, h, 12, radius_top=0.9), "marble"),
    ]
    for k in range(12):
        a = math.radians(k * 30)
        parts.append((segment((math.cos(a) * 1.0, math.sin(a) * 1.0, 1.0), (math.cos(a) * 0.9, math.sin(a) * 0.9, 1.0 + h),
                              0.12, 4), "lightgrey"))
    if broken:
        top = ico((0.2, 0, 1.0 + h), 1.0, 1, 0.3, 300, squash=0.5)
        parts.append((top, "marble"))
        parts.append((ico((2.2, 0.5, 0.5), 0.9, 1, 0.3, 301), "marble"))
    else:
        parts.append((cylinder((0, 0, 1.0 + h), 0.95, 0.4, 12, radius_top=1.3), "marble"))
        parts.append((box((0, 0, 1.7 + h), (2.8, 2.8, 0.6)), "marble"))
    P.prop(name, parts)


def brazier(P):
    parts = [
        (cylinder((0, 0, 0), 1.2, 0.4, 8), "marble"),
        (cylinder((0, 0, 0.4), 0.4, 3.0, 8, radius_top=0.3), "darkgold"),
        (cylinder((0, 0, 3.4), 0.6, 1.0, 10, radius_top=1.6), "gold"),
        (cone((0, 0, 4.2), 1.1, 2.0, 6), "flame"),
        (cone((0.3, 0.2, 4.2), 0.7, 1.4, 5), "yellow"),
    ]
    for k in range(3):
        a = math.radians(k * 120)
        parts.append((segment((0, 0, 1.4), (math.cos(a) * 1.0, math.sin(a) * 1.0, 0.1), 0.1, 4), "darkgold"))
    P.prop("Brazier", parts)


def amphora(P):
    parts = [
        (cylinder((0, 0, 0), 0.5, 0.3, 10), "rust"),
        (cylinder((0, 0, 0.3), 0.6, 1.2, 10, radius_top=1.1), "rust"),
        (cylinder((0, 0, 1.5), 1.1, 1.0, 10, radius_top=0.5), "rust"),
        (cylinder((0, 0, 2.5), 0.4, 0.8, 10, radius_top=0.55), "rust"),
        (torus((0, 0, 1.4), 1.1, 0.06, 10, 4), "black"),
    ]
    for s in (-1, 1):
        parts.append((torus((s * 0.7, 0, 2.6), 0.35, 0.08, 8, 4, axis="Y"), "rust"))
    P.prop("Amphora", parts)


def cloud(P):
    parts = []
    for k, (x, y, z, r) in enumerate(((0, 0, 1.6, 2.6), (2.6, 0.4, 1.2, 2.0), (-2.6, -0.3, 1.2, 2.1),
                                       (1.0, 0.8, 2.6, 1.8), (-1.2, -0.6, 2.4, 1.6))):
        parts.append((ico((x, y, z), r, 1, 0.12, 400 + k, squash=0.8), "snow"))
    P.prop("Cloud", parts)


def golden_gate(P):
    """Portail de l'Olympe (entrée de la zone finale)."""
    parts = []
    for x in (-5.0, 5.0):
        parts.append((box((x, 0, 6.0), (2.0, 2.0, 12.0), bevel=0.1), "marble"))
        parts.append((box((x, 0, 12.4), (2.6, 2.6, 0.8)), "gold"))
    parts.append((box((0, 0, 13.4), (13.0, 2.4, 1.4), bevel=0.1), "gold"))
    parts.append((wedge((0, 0, 14.6), (13.0, 2.4, 1.0)), "gold"))
    for k in range(9):
        x = -3.6 + k * 0.9
        parts.append((segment((x, 0, 0), (x, 0, 12.6 - abs(x) * 0.3), 0.12, 5), "gold"))
        parts.append((cone((x, 0, 12.6 - abs(x) * 0.3), 0.2, 0.6, 4), "gold"))
    parts.append((torus((0, -1.25, 13.4), 0.9, 0.18, 12, 4, axis="Y"), "lime"))
    P.prop("GoldenGate", parts)


def laurel_pedestal(P):
    parts = [
        (box((0, 0, 0.9), (2.4, 2.4, 1.8), bevel=0.1), "marble"),
        (box((0, 0, 1.9), (2.8, 2.8, 0.3)), "marble"),
        (cylinder((0, 0, 2.05), 0.9, 0.2, 10), "fabricred"),
        (torus((0, 0, 2.35), 0.7, 0.15, 12, 4), "lime"),
    ]
    for k in range(8):
        a = math.radians(k * 45)
        parts.append((sphere((math.cos(a) * 0.75, math.sin(a) * 0.75, 2.45), (0.25, 0.12, 0.08), 4, 2), "green"))
    P.prop("LaurelPedestal", parts)


def build_zones(P):
    for fn in (surfboard, lifebuoy_post, sandcastle, beach_towel, volleyball_net, beach_hut, dip_station, crab,
               log_cabin, campfire, tent, tire_on_rope, boombox, yak, snowman,
               lunar_lander, moon_rover, satellite_dumbbell, moon_flag, crater,
               brazier, amphora, cloud, golden_gate, laurel_pedestal):
        fn(P)
    greek_column(P)
    greek_column(P, "GreekColumnBroken", broken=True)

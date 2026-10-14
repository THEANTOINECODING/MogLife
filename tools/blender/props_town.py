"""
Décors du centre-ville, des boutiques, du parc et de l'arène des boss.
À exécuter dans Blender après props_lib.py :  build_town(Props(pal, "Props_Town"))
"""


def fountain(P):
    """Fontaine de la place : bassin, colonne et haltère doré qui crache de l'eau."""
    parts = [
        (cylinder((0, 0, 0), 9.0, 0.8, 16, bevel=0.15), "concrete"),
        (cylinder((0, 0, 0.8), 8.3, 0.15, 16), "water_tex"),
        (torus((0, 0, 1.0), 8.7, 0.45, 16, 4), "lightgrey"),
        (cylinder((0, 0, 0.8), 2.2, 2.4, 10, radius_top=1.4), "concrete"),
        (cylinder((0, 0, 3.2), 3.4, 0.6, 12, radius_top=3.6), "concrete"),
        (cylinder((0, 0, 3.8), 3.1, 0.12, 12), "water_tex"),
        (cylinder((0, 0, 3.8), 0.8, 4.1, 8, radius_top=0.55), "concrete"),
        (cylinder((-3.4, 0, 8.2), 0.4, 6.8, 10, axis="X"), "gold"),
    ]
    for s in (-1, 1):
        parts.append((cylinder((s * 3.0 - 0.6, 0, 8.2), 2.0, 1.2, 14, axis="X", bevel=0.1), "gold"))
        parts.append((cylinder((s * 3.0 - 0.75, 0, 8.2), 0.6, 1.5, 8, axis="X"), "darkgold"))
    # Jets d'eau (cônes bleus) qui retombent dans le bassin
    for k in range(6):
        a = math.radians(k * 60)
        parts.append((segment((math.cos(a) * 3.2, math.sin(a) * 3.2, 3.9), (math.cos(a) * 5.6, math.sin(a) * 5.6, 0.95),
                              0.25, 5, 0.12), "water"))
    parts.append((cone((0, 0, 9.0), 0.5, 2.2, 6), "water"))
    P.prop("Fountain", parts)


def upright_piano(P):
    parts = [
        (box((0, 0.3, 2.6), (5.2, 2.0, 5.2), bevel=0.1), "black"),
        (box((0, -0.9, 2.1), (4.8, 1.4, 0.3)), "black"),
        (box((0, -1.0, 2.3), (4.4, 1.0, 0.12)), "white"),
        (box((0, 0.3, 5.3), (5.4, 2.2, 0.25)), "black"),
        (box((0, -0.72, 4.0), (3.6, 0.06, 1.4)), "charcoal"),
        (box((-1.0, -0.2, 5.6), (0.8, 0.6, 0.5)), "paper"),
    ]
    for k in range(9):
        parts.append((box((-1.9 + k * 0.48, -1.15, 2.42), (0.22, 0.6, 0.12)), "black"))
    for x in (-2.1, 2.1):
        parts.append((box((x, -1.3, 1.0), (0.4, 0.4, 2.0)), "black"))
    for x in (-0.5, 0.5):
        parts.append((box((x, -0.5, 0.3), (0.3, 0.6, 0.1)), "gold"))
    # Tabouret
    parts.append((cylinder((0, -2.8, 0), 0.15, 2.0, 6), "black"))
    parts.append((cylinder((0, -2.8, 2.0), 0.8, 0.4, 10), "fabricred"))
    P.prop("UprightPiano", parts)


def lounger(P):
    parts = [
        (box((0, 0.6, 1.0), (2.2, 4.4, 0.25), bevel=0.06), "stripe_bluewhite"),
        (box((0, -2.2, 1.8), (2.2, 1.8, 0.25)), "stripe_bluewhite"),
    ]
    parts[1] = (rotate(parts[1][0], 40, "X", (0, -1.6, 1.0)), "stripe_bluewhite")
    for x in (-0.95, 0.95):
        for y in (-1.4, 2.6):
            parts.append((segment((x, y, 0), (x, y, 0.95), 0.08, 4), "white"))
        parts.append((box((x, 0.6, 0.85), (0.12, 4.4, 0.15)), "white"))
    parts.append((box((0, 2.2, 1.25), (1.6, 0.9, 0.2)), "fabricred"))
    P.prop("Lounger", parts)


def beach_umbrella(P):
    parts = [
        (cylinder((0, 0, 0), 0.9, 0.3, 8), "white"),
        (cylinder((0, 0, 0.3), 0.12, 7.2, 6), "white"),
        (cone((0, 0, 6.2), 4.2, 1.8, 10), "stripe_redwhite"),
        (sphere((0, 0, 8.0), 0.18, 6, 4), "white"),
    ]
    P.prop("BeachUmbrella", parts)


def lifeguard_chair(P):
    parts = []
    for x in (-1.2, 1.2):
        parts.append((segment((x, -1.4, 0), (x, -0.6, 6.0), 0.18, 5), "white"))
        parts.append((segment((x, 1.4, 0), (x, 0.6, 6.0), 0.18, 5), "white"))
    for k in range(5):
        z = 0.8 + k * 1.1
        parts.append((box((0, -1.25 + k * 0.15, z), (2.6, 0.5, 0.12)), "woodlight"))
    parts.append((box((0, 0, 6.1), (2.6, 2.0, 0.25)), "woodlight"))
    parts.append((box((0, 0.9, 7.2), (2.6, 0.2, 2.0)), "woodlight"))
    for x in (-1.2, 1.2):
        parts.append((box((x, 0, 6.8), (0.15, 1.8, 0.15)), "white"))
    parts.append((cylinder((0, 1.1, 8.2), 0.08, 3.0, 6), "white"))
    parts.append((cone((0, 1.1, 10.4), 2.4, 1.2, 8), "stripe_redwhite"))
    parts.append((torus((1.5, -0.2, 4.5), 0.6, 0.16, 10, 4, axis="X"), "stripe_redwhite"))
    P.prop("LifeguardChair", parts)


def tanning_lamp(P):
    parts = [
        (cylinder((0, 0, 0), 1.0, 0.3, 8), "charcoal"),
        (cylinder((0, 0, 0.3), 0.15, 5.0, 6), "darkgrey"),
        (box((0, -0.6, 5.6), (2.6, 1.4, 1.4), taper=1.2), "charcoal"),
        (box((0, -1.32, 5.6), (2.2, 0.06, 1.1)), "lampwarm"),
    ]
    parts[2] = (rotate(parts[2][0], -25, "X", (0, 0, 5.3)), "charcoal")
    parts[3] = (rotate(parts[3][0], -25, "X", (0, 0, 5.3)), "lampwarm")
    P.prop("TanningLamp", parts)


def mannequin(P):
    parts = [
        (cylinder((0, 0, 0), 1.0, 0.2, 10), "black"),
        (cylinder((0, 0, 0.2), 0.12, 2.6, 6), "chrome"),
        (box((0, 0, 3.6), (2.4, 1.2, 2.2), bevel=0.25, taper=0.85), "fabricred"),
        (box((0, 0, 2.6), (1.6, 1.0, 0.8), bevel=0.2), "fabricred"),
        (cylinder((0, 0, 4.7), 0.25, 0.5, 6), "offwhite"),
        (sphere((0, 0, 5.6), (0.55, 0.6, 0.7), 8, 6), "offwhite"),
    ]
    for s in (-1, 1):
        parts.append((sphere((s * 1.25, 0, 4.4), 0.5, 6, 4), "fabricred"))
    P.prop("Mannequin", parts)


def clothes_rack(P):
    parts = []
    for x in (-3.0, 3.0):
        parts.append((segment((x, -0.8, 0.2), (x, 0, 5.2), 0.1, 6), "chrome"))
        parts.append((segment((x, 0.8, 0.2), (x, 0, 5.2), 0.1, 6), "chrome"))
        parts.append((cylinder((x, -0.8, 0), 0.25, 0.2, 6), "black"))
        parts.append((cylinder((x, 0.8, 0), 0.25, 0.2, 6), "black"))
    parts.append((cylinder((-3.1, 0, 5.2), 0.08, 6.2, 6, axis="X"), "chrome"))
    colors = ["red", "blue", "yellow", "charcoal", "green", "pink", "orange"]
    for k in range(7):
        x = -2.4 + k * 0.8
        parts.append((segment((x, 0, 5.2), (x, 0, 4.7), 0.04, 4), "steel"))
        shirt = [(-0.9, 0), (0.9, 0), (0.9, 1.5), (1.3, 1.3), (1.6, 2.0), (0.6, 2.4), (-0.6, 2.4), (-1.6, 2.0),
                 (-1.3, 1.3), (-0.9, 1.5)]
        bm = extrude(shirt, 0.15, y0=-0.075)
        bm = rotate(bm, 90, "Z")
        parts.append((move(bm, (x, 0, 2.3)), colors[k]))
    P.prop("ClothesRack", parts)


def barber_chair(P):
    parts = [
        (cylinder((0, 0, 0), 1.3, 0.3, 10), "chrome"),
        (cylinder((0, 0, 0.3), 0.35, 1.4, 8), "chrome"),
        (box((0, 0, 2.0), (2.4, 2.4, 0.6), bevel=0.2), "red"),
        (box((0, 1.15, 3.6), (2.2, 0.5, 2.8), bevel=0.2), "red"),
        (box((0, 1.25, 5.3), (1.2, 0.5, 0.6), bevel=0.15), "red"),
        (box((0, -1.8, 1.0), (1.4, 0.6, 0.2)), "chrome"),
        (segment((0, -1.0, 1.7), (0, -1.8, 1.0), 0.08, 4), "chrome"),
    ]
    for s in (-1, 1):
        parts.append((box((s * 1.3, 0.1, 2.8), (0.3, 2.0, 0.25), bevel=0.06), "chrome"))
        parts.append((segment((s * 1.3, -0.6, 2.7), (s * 1.3, -0.6, 2.2), 0.07, 4), "chrome"))
    P.prop("BarberChair", parts)


def barber_pole(P):
    parts = [
        (box((0, 0.4, 3.0), (1.0, 0.2, 2.6)), "chrome"),
        (cylinder((0, 0, 1.6), 0.45, 0.3, 10), "chrome"),
        (cylinder((0, 0, 1.9), 0.38, 2.4, 10), "stripe_pole"),
        (cylinder((0, 0, 4.3), 0.45, 0.3, 10), "chrome"),
        (sphere((0, 0, 4.75), 0.38, 8, 5), "gold"),
    ]
    P.prop("BarberPole", parts)


def shop_counter(P):
    parts = [
        (box((0, 0, 1.8), (8.0, 2.4, 3.6), bevel=0.06), "woodlight"),
        (box((0, -0.1, 3.7), (8.4, 2.8, 0.25)), "marbleblack"),
        (box((0, -1.22, 1.8), (7.4, 0.05, 2.8)), "wood"),
        # Caisse enregistreuse
        (box((2.4, 0.2, 4.3), (1.8, 1.4, 1.0), taper=0.8), "charcoal"),
        (box((2.4, 0.4, 5.2), (1.2, 0.2, 0.8)), "screentex"),
        (box((2.4, -0.3, 3.95), (1.6, 0.5, 0.2)), "darkgrey"),
        # Pot à pourboires et clochette
        (cylinder((-2.8, 0, 3.85), 0.35, 0.8, 8), "glass"),
        (sphere((-1.6, -0.2, 3.95), (0.3, 0.3, 0.2), 6, 3), "gold"),
    ]
    P.prop("ShopCounter", parts)


def grocery_shelf(P):
    parts = [(box((0, 0.6, 3.0), (6.0, 0.2, 6.0)), "lightgrey")]
    for x in (-2.95, 2.95):
        parts.append((box((x, 0, 3.0), (0.15, 1.4, 6.0)), "lightgrey"))
    goods = ["apple", "banana", "carrot", "grape", "milk", "cheese", "tomato", "lettuce"]
    for k, z in enumerate((0.2, 1.7, 3.2, 4.7)):
        parts.append((box((0, 0, z), (5.8, 1.4, 0.15)), "steel"))
        for j in range(5):
            x = -2.3 + j * 1.15
            g = goods[(k * 3 + j) % len(goods)]
            if g in ("milk", "cheese"):
                parts.append((box((x, -0.1, z + 0.55), (0.8, 0.8, 1.0)), g))
            else:
                parts.append((ico((x, -0.1, z + 0.45), 0.45, 1, 0.15, 90 + k * 5 + j, squash=0.8), g))
    P.prop("GroceryShelf", parts)


def fruit_stand(P):
    parts = [
        (box((0, 0, 1.6), (6.0, 3.0, 0.3)), "wood"),
        (box((0, 0.4, 0.8), (5.6, 2.0, 1.6)), "crate"),
    ]
    for x in (-2.8, 2.8):
        for y in (-1.3, 1.3):
            parts.append((box((x, y, 2.8), (0.2, 0.2, 5.6 if y > 0 else 3.2)), "wood"))
    roof = box((0, 0, 5.4), (6.8, 3.6, 0.2))
    parts.append((rotate(roof, -15, "X", (0, 0, 5.4)), "stripe_greenwhite"))
    for k, (x, c) in enumerate(((-2.0, "apple"), (-0.7, "banana"), (0.6, "carrot"), (1.9, "grape"))):
        parts.append((box((x, -0.6, 1.95), (1.2, 1.5, 0.4)), "crate"))
        for j in range(3):
            parts.append((ico((x - 0.3 + j * 0.3, -0.6 + (j % 2) * 0.3, 2.35), 0.32, 1, 0.12, 120 + k * 3 + j), c))
    P.prop("FruitStand", parts)


def bicycle(P):
    parts = []
    for y in (-1.8, 1.8):
        parts.append((torus((0, y, 1.2), 1.0, 0.1, 14, 4, axis="X"), "rubber"))
        parts.append((cylinder((-0.05, y, 1.2), 0.15, 0.1, 6, axis="X"), "steel"))
    frame = [((0, -1.8, 1.2), (0, 0.2, 1.2)), ((0, 0.2, 1.2), (0, -0.8, 2.6)), ((0, -0.8, 2.6), (0, -1.8, 1.2)),
             ((0, 0.2, 1.2), (0, 0.6, 2.8)), ((0, -0.8, 2.6), (0, 1.3, 2.7)), ((0, 1.3, 2.7), (0, 1.8, 1.2)),
             ((0, 1.3, 2.7), (0, 1.1, 3.3))]
    for a, b in frame:
        parts.append((segment(a, b, 0.08, 5), "green"))
    parts.append((box((0, 0.6, 2.9), (0.4, 0.9, 0.18)), "black"))
    parts.append((segment((-0.7, 1.1, 3.3), (0.7, 1.1, 3.3), 0.07, 5), "chrome"))
    parts.append((box((0, -2.2, 2.2), (0.9, 0.7, 0.6)), "brown"))
    rotated = [(rotate(bm, 180, "Z"), c) for bm, c in parts]
    P.prop("Bicycle", rotated)


def suitcase(P):
    parts = [
        (box((0, 0, 1.6), (2.6, 1.2, 3.0), bevel=0.15), "blue"),
        (box((0, -0.62, 1.6), (2.0, 0.06, 2.4)), "navy"),
        (box((0, 0, 3.25), (1.0, 0.3, 0.3)), "black"),
        (box((0.4, -0.64, 2.2), (0.8, 0.04, 0.5)), "yellow"),
        (box((-0.5, -0.64, 1.2), (0.6, 0.04, 0.6)), "red"),
    ]
    for x in (-1.0, 1.0):
        parts.append((cylinder((x, 0, 0.0), 0.15, 0.15, 6), "black"))
    P.prop("Suitcase", parts)


def treehouse(P):
    parts = [
        (box((0, 0, 0.3), (7.0, 7.0, 0.4)), "planks"),
        (box((0, 0, 2.6), (6.4, 6.4, 4.2)), "planks"),
        (box((0, -3.21, 2.0), (2.0, 0.05, 3.0)), "wooddark"),
        (box((2.0, -3.21, 3.4), (1.4, 0.05, 1.2)), "glass"),
        (wedge((0, -1.9, 5.5), (7.6, 4.0, 1.8)), "roofshingle"),
        (wedge((0, 1.9, 5.5), (7.6, 4.0, 1.8)), "roofshingle"),
        (box((-2.4, -3.3, 4.2), (1.2, 0.08, 0.8)), "red"),
    ]
    parts[5] = (rotate(parts[5][0], 180, "Z", (0, 1.9, 5.5)), "roofshingle")
    for k in range(7):
        parts.append((box((-2.2, -3.6, -6.5 + k * 1.0), (1.6, 0.12, 0.2)), "woodlight"))
    for x in (-2.9, -1.5):
        parts.append((box((x, -3.6, -3.4), (0.15, 0.15, 7.4)), "wood"))
    # Poteaux : la cabane tient seule (ou se pose dans un grand arbre)
    for x in (-3.2, 3.2):
        for y in (-3.2, 3.2):
            parts.append((box((x, y, -3.5), (0.5, 0.5, 7.2)), "bark"))
    P.prop("Treehouse", parts)


def playground_slide(P):
    parts = [
        (box((0, 2.0, 4.0), (3.0, 3.0, 0.3)), "planks"),
    ]
    tilt = math.degrees(math.atan2(4.0, 6.0))
    slide = box((0, -2.4, 2.2), (2.0, 7.3, 0.3))
    parts.append((rotate(slide, tilt, "X", (0, -2.4, 2.2)), "yellow"))
    for x in (-1.05, 1.05):
        rail = box((x, -2.4, 2.6), (0.15, 7.3, 0.6))
        parts.append((rotate(rail, tilt, "X", (0, -2.4, 2.2)), "red"))
    for x in (-1.4, 1.4):
        for y in (0.6, 3.4):
            parts.append((box((x, y, 3.0), (0.25, 0.25, 6.0)), "red"))
    for k in range(5):
        parts.append((box((0, 3.8 + k * 0.4, 0.4 + k * 0.8), (2.4, 0.3, 0.15)), "blue"))
    parts.append((wedge((0, 2.0, 6.6), (3.4, 3.4, 1.4)), "red"))
    P.prop("PlaygroundSlide", parts)


def swing_set(P):
    parts = []
    for x in (-4.0, 4.0):
        parts.append((segment((x, -1.6, 0), (x, 0, 6.0), 0.15, 6), "blue"))
        parts.append((segment((x, 1.6, 0), (x, 0, 6.0), 0.15, 6), "blue"))
    parts.append((cylinder((-4.2, 0, 6.0), 0.15, 8.4, 6, axis="X"), "blue"))
    for x in (-2.0, 2.0):
        for s in (-0.6, 0.6):
            parts.append((segment((x + s, 0, 6.0), (x + s, 0, 1.6), 0.04, 4), "steel"))
        parts.append((box((x, 0, 1.55), (1.6, 0.6, 0.15)), "red"))
    P.prop("SwingSet", parts)


def basketball_hoop(P):
    parts = [
        (box((0, 0.5, 0.3), (2.0, 2.0, 0.6)), "darkgrey"),
        (cylinder((0, 0.5, 0.6), 0.25, 9.0, 8), "darkgrey"),
        (segment((0, 0.5, 9.4), (0, -0.6, 9.8), 0.2, 6), "darkgrey"),
        (box((0, -0.8, 10.4), (4.0, 0.2, 2.6)), "white"),
        (box((0, -0.92, 10.0), (1.6, 0.05, 1.2)), "red"),
        (torus((0, -1.6, 9.4), 0.65, 0.07, 12, 4), "orange"),
    ]
    for k in range(6):
        a = math.radians(k * 60)
        parts.append((segment((math.cos(a) * 0.6, -1.6 + math.sin(a) * 0.6, 9.4),
                              (math.cos(a) * 0.4, -1.6 + math.sin(a) * 0.4, 8.6), 0.03, 3), "white"))
    parts.append((sphere((1.8, -1.6, 0.6), 0.6, 8, 6), "orange"))
    P.prop("BasketballHoop", parts)


def flagpole(P):
    parts = [
        (box((0, 0, 0.3), (1.6, 1.6, 0.6)), "concrete"),
        (cylinder((0, 0, 0.6), 0.15, 14.0, 8, radius_top=0.1), "silver"),
        (sphere((0, 0, 14.7), 0.25, 6, 4), "gold"),
        (box((1.9, 0, 12.8), (3.6, 0.06, 2.4)), "purple"),
        (box((1.9, -0.05, 12.8), (1.9, 0.04, 0.25)), "gold"),
        (box((1.0, -0.05, 12.8), (0.3, 0.04, 1.1)), "gold"),
        (box((2.8, -0.05, 12.8), (0.3, 0.04, 1.1)), "gold"),
    ]
    P.prop("Flagpole", parts)


def vending_machine(P):
    """Distributeur de shakes protéinés (pas de texte : des icônes de couleur)."""
    parts = [
        (box((0, 0, 3.4), (3.4, 2.6, 6.8), bevel=0.1), "hotpink"),
        (box((-0.4, -1.31, 4.0), (2.2, 0.06, 4.0)), "glass"),
        (box((1.3, -1.32, 4.4), (0.5, 0.06, 2.0)), "charcoal"),
        (box((-0.4, -1.32, 1.1), (2.2, 0.06, 0.8)), "charcoal"),
        (box((0, -1.31, 6.4), (3.2, 0.06, 0.6)), "white"),
    ]
    for row, z in enumerate((5.2, 4.1, 3.0)):
        for k in range(4):
            parts.append((cylinder((-1.2 + k * 0.55, -1.2, z), 0.2, 0.7, 6),
                          ["hotpink", "blue", "yellow", "green"][(row + k) % 4]))
    for k in range(3):
        parts.append((box((1.3, -1.36, 5.0 - k * 0.5), (0.25, 0.04, 0.25)), "neongreen"))
    P.prop("ShakeVendingMachine", parts)


def billboard(P):
    """Panneau publicitaire : un énorme haltère et des étoiles, aucun texte."""
    parts = [
        (box((-3.5, 0.5, 4.0), (0.6, 0.6, 8.0)), "darkgrey"),
        (box((3.5, 0.5, 4.0), (0.6, 0.6, 8.0)), "darkgrey"),
        (box((0, 0, 11.0), (12.0, 0.6, 6.0), bevel=0.1), "white"),
        (box((0, -0.32, 11.0), (11.4, 0.05, 5.4)), "sky"),
        (cylinder((-3.0, -0.4, 11.0), 0.3, 6.0, 8, axis="X"), "gold"),
        (box((0, 0.2, 8.1), (12.0, 1.4, 0.2)), "darkgrey"),
    ]
    for s in (-1, 1):
        parts.append((cylinder((s * 3.0 - 0.4, -0.5, 11.0), 1.8, 0.8, 12, axis="X"), "gold"))
    for k, (x, z) in enumerate(((-4.8, 13.0), (4.6, 12.8), (0.0, 13.3), (-1.8, 9.0), (2.4, 9.2))):
        parts.append((sphere((x, -0.38, z), (0.35, 0.05, 0.35), 4, 2), "yellow"))
    for x in (-4, 0, 4):
        parts.append((box((x, -0.8, 8.4), (0.4, 1.0, 0.4)), "lampwarm"))
    P.prop("Billboard", parts)


def podium(P):
    """Podium 1-2-3 (classements, événements)."""
    parts = []
    for x, h, c in ((0, 3.0, "gold"), (-4.2, 2.0, "silver"), (4.2, 1.4, "bronze")):
        parts.append((box((x, 0, h / 2), (4.0, 3.6, h), bevel=0.1), "white"))
        parts.append((box((x, -1.81, h * 0.55), (1.4, 0.06, 1.0)), c))
    P.prop("Podium", parts)


def boss_stage(P):
    """Estrade de boss : marches, plateau et poteaux de ring."""
    parts = [
        (box((0, 0, 0.6), (14.0, 14.0, 1.2), bevel=0.1), "darkred"),
        (box((0, 0, 1.25), (12.6, 12.6, 0.1)), "fabricred"),
        (box((0, -7.6, 0.3), (5.0, 1.2, 0.6)), "charcoal"),
    ]
    for x in (-6.6, 6.6):
        for y in (-6.6, 6.6):
            parts.append((cylinder((x, y, 1.2), 0.3, 4.0, 8), "chrome"))
            parts.append((sphere((x, y, 5.3), 0.4, 8, 4), "gold"))
    for z in (2.6, 3.8):
        for (a, b) in (((-6.6, -6.6), (6.6, -6.6)), ((6.6, -6.6), (6.6, 6.6)), ((6.6, 6.6), (-6.6, 6.6)),
                       ((-6.6, 6.6), (-6.6, -6.6))):
            parts.append((segment((a[0], a[1], z), (b[0], b[1], z), 0.08, 4), "white"))
    P.prop("BossStage", parts)


def bleachers(P):
    """Gradins pour regarder les combats de boss (idée de l'arène)."""
    parts = []
    for k in range(4):
        h = 1.2 * (k + 1)
        parts.append((box((0, k * 2.0, h / 2), (14.0, 2.0, h)), "concrete"))
        parts.append((box((0, k * 2.0 - 0.3, h + 0.15), (13.6, 1.2, 0.3)), ["blue", "red", "yellow", "green"][k]))
    for x in (-7.1, 7.1):
        parts.append((segment((x, -1.0, 1.8), (x, 7.0, 6.6), 0.1, 5), "chrome"))
    P.prop("Bleachers", parts)


def spotlight(P):
    parts = [
        (box((0, 0, 0.2), (2.4, 2.4, 0.4)), "charcoal"),
        (segment((-0.8, 0, 0.4), (0, 0, 3.4), 0.1, 5), "darkgrey"),
        (segment((0.8, 0, 0.4), (0, 0, 3.4), 0.1, 5), "darkgrey"),
        (segment((0, 0.8, 0.4), (0, 0, 3.4), 0.1, 5), "darkgrey"),
        (cylinder((0, -0.6, 4.0), 0.9, 1.8, 10, axis="Y", radius_top=1.1), "charcoal"),
        (cylinder((0, -0.65, 4.0), 0.85, 0.06, 10, axis="Y"), "lampwarm"),
    ]
    parts[4] = (rotate(parts[4][0], -20, "X", (0, 0, 4.0)), "charcoal")
    parts[5] = (rotate(parts[5][0], -20, "X", (0, 0, 4.0)), "lampwarm")
    P.prop("Spotlight", parts)


def gong(P):
    parts = [
        (box((0, 0, 0.3), (6.0, 1.6, 0.6)), "wooddark"),
        (box((-2.6, 0, 3.8), (0.5, 0.5, 7.0)), "darkred"),
        (box((2.6, 0, 3.8), (0.5, 0.5, 7.0)), "darkred"),
        (box((0, 0, 7.5), (6.6, 0.6, 0.6), bevel=0.1), "darkred"),
        (cylinder((0, 0.1, 4.2), 2.1, 0.25, 16, axis="Y"), "gold"),
        (torus((0, 0, 4.2), 2.0, 0.12, 16, 4, axis="Y"), "darkgold"),
        (cylinder((0, -0.05, 4.2), 0.7, 0.1, 12, axis="Y"), "darkgold"),
    ]
    for x in (-1.2, 1.2):
        parts.append((segment((x, 0, 7.2), (x * 0.6, 0, 6.2), 0.04, 4), "black"))
    P.prop("Gong", parts)


def stanchion_rope(P):
    """Poteaux et corde rouge (tapis rouge du Roi du Quartier, files d'attente)."""
    parts = []
    for x in (-3.0, 3.0):
        parts.append((cylinder((x, 0, 0), 0.5, 0.2, 8), "gold"))
        parts.append((cylinder((x, 0, 0.2), 0.12, 3.0, 6), "gold"))
        parts.append((sphere((x, 0, 3.3), 0.25, 6, 4), "gold"))
    pts = [(-3.0, 0, 2.9), (-1.5, 0, 2.2), (0, 0, 2.0), (1.5, 0, 2.2), (3.0, 0, 2.9)]
    for a, b in zip(pts, pts[1:]):
        parts.append((segment(a, b, 0.1, 5), "red"))
    P.prop("StanchionRope", parts)


def build_town(P):
    for fn in (fountain, upright_piano, lounger, beach_umbrella, lifeguard_chair, tanning_lamp, mannequin, clothes_rack,
               barber_chair, barber_pole, shop_counter, grocery_shelf, fruit_stand, bicycle, suitcase, treehouse,
               playground_slide, swing_set, basketball_hoop, flagpole, vending_machine, billboard, podium, boss_stage,
               bleachers, spotlight, gong, stanchion_rope):
        fn(P)

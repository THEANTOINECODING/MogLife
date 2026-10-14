"""
Kit de façade : détails à plaquer sur les bâtiments en blocs de la carte (fenêtres, portes, climatiseurs…).
Le dos de chaque élément est à y = 0 (contre le mur), il dépasse vers -Y (vers la rue).
À exécuter après props_lib.py :  build_kit(Props(pal, "Props_Kit"))
"""


def window(P, name, w, h, frame="white", shutters=None, flowers=False):
    parts = [
        (box((0, -0.15, h / 2), (w + 0.6, 0.3, h + 0.6)), frame),
        (box((0, -0.32, h / 2), (w, 0.05, h)), "glass"),
        (box((0, -0.36, h / 2), (0.18, 0.06, h)), frame),
        (box((0, -0.36, h / 2), (w, 0.06, 0.18)), frame),
        (box((0, -0.5, -0.1), (w + 0.9, 0.7, 0.25)), frame),
    ]
    if shutters:
        for s in (-1, 1):
            parts.append((box((s * (w / 2 + 0.75), -0.2, h / 2), (0.9, 0.12, h + 0.4)), shutters))
            for k in range(4):
                parts.append((box((s * (w / 2 + 0.75), -0.28, 0.4 + k * (h / 4)), (0.7, 0.04, 0.1)), "darkgrey"))
    if flowers:
        parts.append((box((0, -0.9, -0.55), (w + 0.4, 0.8, 0.7)), "wood"))
        for k in range(5):
            x = -w / 2 + 0.2 + k * (w / 4)
            parts.append((ico((x, -0.9, 0.0), 0.35, 1, 0.15, 500 + k), ["red", "yellow", "pink", "purple", "white"][k]))
    P.prop(name, parts)


def door(P, name, color, glass=False):
    parts = [
        (box((0, -0.15, 3.9), (4.4, 0.3, 7.8)), "white"),
        (box((0, -0.32, 3.6), (3.6, 0.12, 7.2)), color),
        (box((0, -0.5, 0.15), (5.0, 1.2, 0.3)), "concrete"),
        (sphere((1.3, -0.45, 3.5), 0.18, 6, 4), "gold"),
    ]
    for z in (1.6, 4.6):
        parts.append((box((0, -0.4, z), (2.6, 0.05, 2.2)), color))
    if glass:
        parts.append((box((0, -0.4, 6.4), (2.4, 0.05, 0.9)), "glass"))
    parts.append((box((-1.0, -0.42, 5.9), (0.5, 0.04, 0.3)), "gold"))
    P.prop(name, parts)


def garage_door(P):
    parts = [(box((0, -0.15, 5.0), (18.6, 0.3, 10.0)), "lightgrey")]
    for k in range(8):
        parts.append((box((0, -0.34, 0.65 + k * 1.25), (18.0, 0.1, 1.1)), "white"))
    parts.append((box((6.5, -0.42, 1.0), (1.4, 0.06, 0.3)), "steel"))
    parts.append((box((0, -0.3, 10.2), (19.4, 0.6, 0.4)), "darkgrey"))
    P.prop("Kit_GarageDoor", parts)


def ac_unit(P):
    parts = [
        (box((0, -0.9, 1.0), (2.6, 1.8, 2.0), bevel=0.06), "lightgrey"),
        (cylinder((0, -1.81, 1.0), 0.75, 0.06, 12, axis="Y"), "darkgrey"),
        (box((0, -0.9, 0.0), (2.4, 1.6, 0.1)), "steel"),
    ]
    for k in range(4):
        parts.append((box((0, -1.86, 0.55 + k * 0.3), (1.4, 0.04, 0.06)), "charcoal"))
    parts.append((segment((1.0, -0.2, 0.2), (1.0, -0.2, -1.6), 0.06, 4), "steel"))
    P.prop("Kit_ACUnit", parts, ground=False)


def satellite_dish(P):
    parts = [
        (box((0, -0.2, 0.0), (0.6, 0.4, 0.8)), "darkgrey"),
        (segment((0, -0.4, 0.2), (0, -1.4, 0.8), 0.08, 4), "steel"),
        (cone((0, -1.6, 0.9), 1.4, 0.6, 12), "white"),
        (segment((0, -1.6, 1.0), (0, -2.6, 1.6), 0.05, 4), "steel"),
        (sphere((0, -2.6, 1.6), 0.15, 6, 4), "darkgrey"),
    ]
    parts[2] = (rotate(parts[2][0], 70, "X", (0, -1.6, 0.9)), "white")
    P.prop("Kit_SatelliteDish", parts, ground=False)


def gutter(P):
    parts = [
        (box((0, -0.3, 12.0), (0.5, 0.5, 0.5)), "white"),
        (cylinder((0, -0.3, 0.6), 0.22, 11.4, 8), "white"),
        (segment((0, -0.3, 0.6), (0, -1.0, 0.1), 0.22, 8), "white"),
    ]
    for z in (3, 6, 9):
        parts.append((box((0, -0.1, z), (0.6, 0.2, 0.15)), "steel"))
    P.prop("Kit_Gutter", parts)


def awning(P, name, pattern):
    parts = []
    a = box((0, -1.6, 0.0), (8.0, 3.4, 0.2))
    parts.append((rotate(a, -18, "X", (0, 0, 0.5)), pattern))
    # Bande qui pend au bord de l'auvent
    parts.append((box((0, -3.25, -0.65), (8.0, 0.12, 0.8)), pattern))
    for x in (-3.9, 3.9):
        parts.append((segment((x, 0, 0.5), (x, -3.2, -0.5), 0.06, 4), "darkgrey"))
    P.prop(name, parts, ground=False)


def shop_sign(P, name, color, icon_color):
    """Enseigne de boutique sans texte : un cadre coloré avec une icône simple (le jeu affiche le nom à part)."""
    parts = [
        (box((0, -0.2, 0), (10.0, 0.4, 2.4), bevel=0.1), color),
        (box((0, -0.42, 0), (9.4, 0.05, 1.9)), "white"),
        (cylinder((-3.6, -0.5, 0), 0.75, 0.1, 12, axis="Y"), icon_color),
    ]
    for x in (-4.0, 0.0, 4.0):
        parts.append((box((x, -0.7, 1.4), (0.3, 0.6, 0.3)), "lampwarm"))
    P.prop(name, parts, ground=False)


def water_tank(P):
    parts = [
        (cylinder((0, 0, 4.0), 3.0, 5.0, 12), "wood"),
        (cone((0, 0, 9.0), 3.3, 1.8, 12), "wooddark"),
    ]
    for z in (5.0, 7.0, 8.6):
        parts.append((torus((0, 0, z), 3.02, 0.08, 12, 4), "iron"))
    for k in range(4):
        a = math.radians(45 + k * 90)
        parts.append((segment((math.cos(a) * 2.6, math.sin(a) * 2.6, 0), (math.cos(a) * 2.4, math.sin(a) * 2.4, 4.0),
                              0.18, 5), "iron"))
    P.prop("Kit_WaterTank", parts)


def roof_vent(P):
    parts = [
        (box((0, 0, 0.4), (2.0, 2.0, 0.8)), "darkgrey"),
        (cylinder((0, 0, 0.8), 0.6, 1.4, 8), "steel"),
        (cone((0, 0, 2.2), 1.0, 0.8, 8), "steel"),
    ]
    P.prop("Kit_RoofVent", parts)


def chimney(P):
    parts = [
        (box((0, 0, 2.5), (2.4, 2.4, 5.0)), "brick"),
        (box((0, 0, 5.15), (2.8, 2.8, 0.3)), "concrete"),
        (cylinder((0, 0, 5.3), 0.5, 0.8, 8), "rust"),
    ]
    P.prop("Kit_Chimney", parts)


def stairs(P):
    parts = []
    for k in range(5):
        h = 0.8 * (5 - k)
        parts.append((box((0, -k * 1.0, h / 2), (6.0, 1.0, h)), "concrete"))
    for x in (-3.2, 3.2):
        parts.append((segment((x, 0.2, 4.0 + 3.0), (x, -4.6, 0.8 + 3.0), 0.1, 5), "chrome"))
        for y in (0.2, -4.6):
            z0 = 4.0 if y > 0 else 0.8
            parts.append((segment((x, y, z0), (x, y, z0 + 3.0), 0.1, 5), "chrome"))
    P.prop("Kit_Stairs", parts)


def fence_metal(P):
    parts = []
    for k in range(9):
        x = -4.0 + k
        parts.append((segment((x, 0, 0), (x, 0, 4.0), 0.07, 4), "charcoal"))
        parts.append((cone((x, 0, 4.0), 0.15, 0.4, 4), "gold"))
    for z in (0.6, 3.4):
        parts.append((box((0, 0, z), (8.4, 0.12, 0.18)), "charcoal"))
    for x in (-4.4, 4.4):
        parts.append((box((x, 0, 2.2), (0.5, 0.5, 4.4)), "brick"))
        parts.append((box((x, 0, 4.5), (0.7, 0.7, 0.2)), "concrete"))
    P.prop("Kit_MetalFence", parts)


def build_kit(P):
    window(P, "Kit_Window", 3.6, 3.6)
    window(P, "Kit_WindowShutters", 3.6, 3.6, shutters="blue")
    window(P, "Kit_WindowFlowers", 3.6, 3.6, shutters="green", flowers=True)
    window(P, "Kit_ShopWindow", 10.0, 6.0, frame="charcoal")
    door(P, "Kit_DoorRed", "red", glass=True)
    door(P, "Kit_DoorBlue", "blue")
    door(P, "Kit_DoorWood", "wood", glass=True)
    garage_door(P)
    ac_unit(P)
    satellite_dish(P)
    gutter(P)
    awning(P, "Kit_AwningRed", "stripe_redwhite")
    awning(P, "Kit_AwningBlue", "stripe_bluewhite")
    awning(P, "Kit_AwningGreen", "stripe_greenwhite")
    shop_sign(P, "Kit_SignClothes", "blue", "red")
    shop_sign(P, "Kit_SignBarber", "red", "blue")
    shop_sign(P, "Kit_SignFurniture", "orange", "blue")
    shop_sign(P, "Kit_SignGym", "darkred", "gold")
    water_tank(P)
    roof_vent(P)
    chimney(P)
    stairs(P)
    fence_metal(P)

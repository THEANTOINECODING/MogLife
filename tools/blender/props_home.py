"""
Meubles de la maison et du garage.
- Furniture_<Id> : les 21 meubles du magasin (mêmes identifiants que src/shared/Config/Furniture.luau),
  pour remplacer les blocs provisoires. Le devant vers -Y, le dos contre le mur (+Y).
- Home_* / Garage_* : meubles et objets pour plus tard (nouveaux emplacements, garages, intérieurs).
À exécuter dans Blender après props_lib.py :  build_home(Props(pal, "Props_Home"))
"""


def sofa_parts(width, seat, back, arm, depth=3.0, legs="darkbrown", cushions=2):
    parts = [
        (box((0, 0, 0.75), (width, depth, 0.9), bevel=0.15), seat),
        (box((0, depth / 2 - 0.45, 2.1), (width, 0.9, 2.2), bevel=0.2), back),
    ]
    cw = (width - 1.6) / cushions
    for k in range(cushions):
        x = -width / 2 + 0.8 + cw * (k + 0.5)
        parts.append((box((x, -0.25, 1.4), (cw - 0.1, depth - 1.0, 0.5), bevel=0.15), seat))
        parts.append((box((x, depth / 2 - 1.05, 2.2), (cw - 0.15, 0.5, 1.3), bevel=0.15), back))
    for s in (-1, 1):
        parts.append((box((s * (width / 2 - 0.4), 0, 1.4), (0.8, depth, 1.6), bevel=0.2), arm))
        for y in (-depth / 2 + 0.3, depth / 2 - 0.3):
            parts.append((cylinder((s * (width / 2 - 0.4), y, 0), 0.15, 0.3, 6), legs))
    return parts


def furniture(P):
    # --- Canapés
    parts = sofa_parts(7.0, "fabric", "fabric", "fabric")
    parts.append((box((1.6, -0.3, 1.35), (1.4, 1.2, 0.08)), "darkbrown"))  # tache / trou dans le coussin
    parts.append((box((-2.0, -0.4, 1.72), (1.6, 1.6, 0.2)), "cardboardtex"))  # boîte à pizza oubliée
    P.prop("Furniture_SaggyCouch", parts)

    parts = [
        (box((0, 0, 1.6), (7.0, 2.6, 0.7), bevel=0.15), "black"),
        (box((0, 1.0, 2.8), (7.0, 0.6, 1.8), bevel=0.15), "black"),
    ]
    for x in (-3.0, 3.0):
        parts.append((box((x, 0, 0.6), (0.4, 2.2, 1.2)), "chrome"))
    parts.append((cylinder((-4.6, 1.2, 4.2), 0.12, 9.2, 8, axis="X"), "chrome"))
    for s in (-1, 1):
        parts += [(cylinder((s * 4.3 - 0.25, 1.2, 4.2), 1.4, 0.5, 12, axis="X", bevel=0.06), "charcoal")]
        parts.append((box((s * 3.9, 1.1, 3.0), (0.3, 0.3, 2.4)), "chrome"))
    P.prop("Furniture_BenchSofa", parts)

    P.prop("Furniture_LeopardSofa", sofa_parts(7.4, "leopard", "leopard", "black", legs="gold"))

    parts = [
        (box((0, 0, 0.6), (5.2, 3.2, 1.2), bevel=0.1), "darkgold"),
        (box((0, -0.2, 1.5), (3.8, 2.6, 0.6), bevel=0.2), "fabricred"),
        (box((0, 1.25, 4.0), (5.0, 0.7, 5.6), bevel=0.15), "gold"),
        (box((0, 0.85, 3.6), (3.6, 0.2, 4.0), bevel=0.2), "fabricred"),
    ]
    for s in (-1, 1):
        parts.append((box((s * 2.3, 0, 2.2), (0.6, 3.0, 1.0), bevel=0.15), "gold"))
        parts.append((sphere((s * 2.3, -1.4, 2.7), 0.5, 8, 5), "gold"))
        parts.append((cone((s * 2.2, 1.3, 6.8), 0.4, 1.2, 6), "gold"))
    parts.append((cone((0, 1.3, 6.8), 0.55, 1.8, 6), "gold"))
    parts.append((sphere((0, 1.0, 5.6), 0.45, 8, 5), "red"))
    P.prop("Furniture_ThroneSofa", parts)

    # --- Télés
    parts = [
        (box((0, 0.2, 1.0), (4.0, 1.8, 2.0), bevel=0.06), "wood"),
        (box((0, -0.71, 1.0), (3.2, 0.06, 1.4)), "wooddark"),
        (box((0, 0.3, 3.4), (3.4, 2.6, 2.8), bevel=0.25), "darkgrey"),
        (box((-0.4, -1.0, 3.45), (2.3, 0.1, 2.0)), "screentex"),
        (cylinder((1.15, -1.05, 3.9), 0.2, 0.12, 8, axis="Y"), "steel"),
        (cylinder((1.15, -1.05, 3.2), 0.2, 0.12, 8, axis="Y"), "steel"),
        (segment((-0.6, 0.6, 4.8), (-1.2, 0.8, 6.2), 0.05, 4), "steel"),
        (segment((0.6, 0.6, 4.8), (1.3, 0.9, 6.0), 0.05, 4), "steel"),
    ]
    P.prop("Furniture_TubeTv", parts)

    parts = [
        (box((0, 0.2, 0.7), (6.4, 1.8, 1.4), bevel=0.06), "charcoal"),
        (box((0, 0.5, 4.2), (8.4, 0.35, 4.8), bevel=0.06), "black"),
        (box((0, 0.3, 4.2), (7.9, 0.06, 4.3)), "screentex"),
        (box((0, 0.5, 1.8), (1.2, 0.3, 1.0)), "black"),
    ]
    for s in (-1, 1):
        parts.append((box((s * 4.4, 0.2, 2.6), (1.0, 1.0, 2.6), bevel=0.1), "charcoal"))
        parts.append((cylinder((s * 4.4, -0.32, 3.2), 0.35, 0.1, 10, axis="Y"), "steel"))
        parts.append((cylinder((s * 4.4, -0.32, 2.2), 0.25, 0.1, 10, axis="Y"), "steel"))
    P.prop("Furniture_GiantScreen", parts)

    # --- Lits
    parts = [
        (box((0, 0.5, 0.45), (5.0, 7.0, 0.9), bevel=0.2), "offwhite"),
        (box((0, 3.2, 1.05), (3.4, 1.2, 0.45), bevel=0.2), "white"),
        (box((0.2, -0.8, 1.0), (4.6, 4.0, 0.25), bevel=0.1), "fabricblue"),
        (box((-1.8, -2.8, 0.25), (1.2, 0.8, 0.5), bevel=0.15), "pizza"),
    ]
    P.prop("Furniture_Mattress", parts)

    parts = []
    body = [(-3.8, 0.4), (4.3, 0.4), (4.3, 1.8), (3.6, 2.2), (2.6, 2.4), (-2.2, 2.4), (-2.8, 3.4), (-3.9, 3.4)]
    b = extrude(body, 5.4, y0=-2.7)
    parts.append((rotate(b, -90, "Z"), "red"))
    parts.append((box((0, 0.3, 2.45), (4.4, 6.6, 0.3)), "white"))
    parts.append((box((0, 2.9, 2.8), (3.0, 1.0, 0.5), bevel=0.15), "white"))
    parts.append((box((0, -0.6, 2.65), (4.4, 4.2, 0.2)), "stripe_bluewhite"))
    for x in (-2.75, 2.75):
        for y in (-2.6, 2.4):
            parts.append((cylinder((x - (0.3 if x < 0 else 0), y, 0.9), 0.9, 0.3, 10, axis="X"), "rubber"))
            parts.append((cylinder((x - (0.32 if x < 0 else -0.3), y, 0.9), 0.45, 0.04, 8, axis="X"), "chrome"))
    parts.append((box((0, 4.15, 3.4), (5.4, 0.3, 0.3)), "black"))  # aileron
    for x in (-2.0, 2.0):
        parts.append((box((x, 4.15, 2.8), (0.2, 0.2, 1.0)), "black"))
    for x in (-1.6, 1.6):
        parts.append((box((x, -3.65, 1.4), (0.8, 0.1, 0.4)), "lampwarm"))
    P.prop("Furniture_RaceCarBed", parts)

    # --- Tapis (très plats, sans collision dans le jeu)
    parts = [(cylinder((0, 0, 0), 3.5, 0.1, 16), "pizzatop"), (torus((0, 0, 0.08), 3.4, 0.12, 16, 4), "tan")]
    P.prop("Furniture_PizzaRug", parts)
    zebra = [(-5.0, -2.8), (-3.6, -3.4), (-1.0, -3.5), (1.5, -3.3), (4.2, -3.6), (5.2, -2.0), (4.6, 0.2), (5.3, 2.6),
             (3.4, 3.4), (0.4, 3.5), (-2.4, 3.3), (-4.6, 3.6), (-5.3, 1.2), (-4.6, -0.6)]
    bm = extrude([(x, y) for x, y in zebra], 0.1, axis="Y")
    rotate(bm, 90, "X")
    P.prop("Furniture_ZebraRug", [(bm, "zebra")])
    parts = [
        (box((0, 0, 0.05), (11.0, 8.0, 0.1)), "fabricred"),
        (box((0, 0, 0.11), (9.6, 6.6, 0.02)), "gold"),
        (box((0, 0, 0.13), (8.6, 5.6, 0.02)), "fabricred"),
        (cylinder((0, 0, 0.13), 1.4, 0.04, 8), "gold"),
    ]
    for x in (-5.4, 5.4):
        for k in range(8):
            parts.append((box((x + (0.35 if x > 0 else -0.35), -3.5 + k, 0.03), (0.7, 0.25, 0.06)), "gold"))
    P.prop("Furniture_GoldRug", parts)

    # --- Murs (posters et enseigne néon) : plaqués contre le mur derrière (+Y)
    parts = [
        (box((0, 0, 2.5), (4.0, 0.12, 5.0)), "white"),
        (box((0, -0.05, 2.5), (3.6, 0.06, 4.6)), "yellow"),
    ]
    arm = [(-1.2, 0.6), (-0.4, 0.6), (-0.3, 2.2), (0.6, 2.4), (1.0, 3.4), (0.4, 3.9), (-0.3, 3.0), (-1.1, 2.9)]
    a = extrude(arm, 0.08, y0=-0.18)
    parts.append((a, "orangeskin"))
    parts.append((sphere((-0.2, -0.16, 2.8), (0.65, 0.08, 0.55), 8, 3), "orangeskin"))
    for k, (x, z) in enumerate(((-1.4, 4.4), (1.4, 0.7), (1.3, 4.5))):
        parts.append((box((x, -0.12, z), (0.35, 0.04, 0.35)), "red"))
    P.prop("Furniture_FlexPoster", parts)
    parts = [
        (box((0, 0, 2.0), (6.0, 0.12, 4.0)), "black"),
        (box((0, -0.05, 2.0), (5.6, 0.06, 3.6)), "sunset"),
        (cylinder((0, -0.1, 2.3), 0.9, 0.04, 12, axis="Y"), "yellow"),
        (box((-1.9, -0.11, 0.9), (0.15, 0.04, 1.5)), "darkbrown"),
    ]
    for k in range(4):
        a = math.radians(30 + k * 40)
        parts.append((box((-1.9 + math.cos(a) * 0.5, -0.12, 1.65 + math.sin(a) * 0.3), (0.9, 0.04, 0.15)), "darkgreen"))
    P.prop("Furniture_SunsetPoster", parts)
    parts = [
        (box((0, 0, 1.6), (6.0, 0.15, 3.2), bevel=0.05), "charcoal"),
        (box((0, -0.12, 1.6), (4.0, 0.12, 0.35)), "neonpink"),
    ]
    for s in (-1, 1):
        parts.append((box((s * 2.1, -0.12, 1.6), (0.35, 0.12, 1.9)), "neonblue"))
        parts.append((box((s * 2.55, -0.12, 1.6), (0.35, 0.12, 1.3)), "neonblue"))
    P.prop("Furniture_NeonDumbbell", parts)

    # --- Plantes
    parts = [
        (cylinder((0, 0, 0), 0.8, 1.4, 8, radius_top=1.0), "rust"),
        (torus((0, 0, 1.4), 1.0, 0.12, 8, 4), "rust"),
        (cylinder((0, 0, 1.3), 0.85, 0.1, 8), "dirt"),
        (cylinder((0, 0, 1.3), 0.45, 3.0, 8, radius_top=0.4), "green"),
        (sphere((0, 0, 4.3), (0.42, 0.42, 0.3), 8, 4), "green"),
        (segment((0.35, 0, 2.4), (1.0, 0, 2.6), 0.28, 6), "green"),
        (segment((1.0, 0, 2.6), (1.0, 0, 3.6), 0.26, 6), "green"),
        (segment((-0.35, 0, 2.9), (-0.9, 0, 3.0), 0.24, 6), "green"),
        (segment((-0.9, 0, 3.0), (-0.9, 0, 3.8), 0.22, 6), "green"),
        (sphere((0.1, -0.35, 4.5), 0.22, 6, 4), "pink"),
    ]
    P.prop("Furniture_Cactus", parts)
    parts = [
        (cylinder((0, 0, 0), 0.9, 3.2, 10, radius_top=1.0), "hotpink"),
        (cylinder((0, 0, 3.2), 1.02, 0.6, 10), "charcoal"),
        (torus((0, 0, 1.8), 0.98, 0.06, 10, 4), "white"),
        (ico((0, 0, 5.1), 1.7, 1, 0.2, 51), "leaf"),
        (ico((0.9, -0.5, 4.4), 1.0, 1, 0.25, 52), "leaflight"),
        (ico((-0.8, 0.4, 4.6), 1.0, 1, 0.25, 53), "darkgreen"),
    ]
    P.prop("Furniture_ShakerPlant", parts)

    # --- Lampes
    parts = [
        (cylinder((0, 0, 0), 0.7, 1.0, 8, radius_top=0.45), "silver"),
        (cylinder((0, 0, 1.0), 0.45, 2.6, 8, radius_top=0.65), "neonpink"),
        (sphere((0, 0, 1.9), 0.3, 6, 4), "orange"),
        (sphere((0.1, 0, 2.9), 0.22, 6, 4), "orange"),
        (cylinder((0, 0, 3.6), 0.65, 0.8, 8, radius_top=0.2), "silver"),
    ]
    P.prop("Furniture_LavaLamp", parts)
    parts = [
        (cylinder((0, 0, 0), 1.3, 0.4, 12, bevel=0.05), "charcoal"),
        (cylinder((0, 0, 0), 0.32, 0.45, 8), "steel"),
        (cylinder((0, 0, 0.4), 0.2, 5.0, 8), "steel"),
        (cylinder((-0.6, 0, 3.0), 0.1, 1.2, 6, axis="X"), "chrome"),
        (cylinder((-0.75, 0, 3.0), 0.35, 0.18, 8, axis="X"), "charcoal"),
        (cylinder((0.57, 0, 3.0), 0.35, 0.18, 8, axis="X"), "charcoal"),
        (cylinder((0, 0, 5.4), 1.4, 1.4, 10, radius_top=0.8), "cream"),
        (cylinder((0, 0, 5.38), 1.2, 0.05, 10), "lampwarm"),
    ]
    P.prop("Furniture_DumbbellLamp", parts)

    # --- Étagère à trophées (meuble + trophée)
    def shelf():
        return [
            (box((0, 0.5, 1.3), (4.0, 1.6, 2.6), bevel=0.05), "wood"),
            (box((0, -0.31, 1.3), (3.4, 0.05, 1.9)), "wooddark"),
            (box((0, 0.5, 2.65), (4.2, 1.8, 0.12)), "woodlight"),
        ]
    parts = shelf() + [
        (cylinder((0, 0.5, 2.7), 0.6, 0.3, 8, radius_top=0.4), "bronze"),
        (cylinder((0, 0.5, 3.0), 0.15, 0.7, 6), "bronze"),
        (cylinder((0, 0.5, 3.7), 0.3, 1.2, 10, radius_top=0.85), "bronze"),
        (torus((-0.9, 0.5, 4.3), 0.3, 0.08, 8, 4, axis="Y"), "bronze"),
        (torus((0.9, 0.5, 4.3), 0.3, 0.08, 8, 4, axis="Y"), "bronze"),
        (box((1.3, 0.2, 2.9), (0.6, 0.4, 0.3)), "paper"),
    ]
    P.prop("Furniture_BronzeCup", parts)
    parts = shelf() + [(box((0, 0.5, 2.9), (2.4, 1.2, 0.4)), "marbleblack"),
                       (cylinder((-1.4, 0.5, 3.75), 0.2, 2.8, 8, axis="X"), "gold")]
    for s in (-1, 1):
        parts.append((cylinder((s * 1.3 - 0.25, 0.5, 3.75), 0.75, 0.5, 12, axis="X", bevel=0.06), "gold"))
    P.prop("Furniture_GoldenDumbbell", parts)
    # Buste en marbre d'un « mogger » : épaules énormes, trapèzes, mâchoire démesurée
    parts = [
        (box((0, 0.3, 0.7), (3.4, 2.4, 1.4), bevel=0.1), "marble"),
        (box((0, 0.3, 1.55), (2.8, 2.0, 0.3)), "marble"),
        (box((0, 0.3, 2.6), (3.6, 1.6, 1.8), bevel=0.25, taper=0.75), "marble"),
        (sphere((-0.65, -0.35, 2.55), (0.75, 0.35, 0.55), 8, 4), "marble"),
        (sphere((0.65, -0.35, 2.55), (0.75, 0.35, 0.55), 8, 4), "marble"),
        (box((0, 0.3, 3.55), (2.6, 1.2, 0.5), bevel=0.15, taper=0.5), "marble"),
        (cylinder((0, 0.3, 3.5), 0.45, 0.6, 8), "marble"),
        (sphere((0, 0.3, 4.6), (0.75, 0.8, 0.8), 8, 6), "marble"),
        (box((0, 0.1, 4.05), (1.5, 1.2, 0.8), bevel=0.2, taper=1.15), "marble"),
        (wedge((0, -0.5, 4.45), (0.25, 0.35, 0.45)), "marble"),
        (box((0, -0.42, 4.75), (1.1, 0.1, 0.18)), "marble"),
    ]
    P.prop("Furniture_BicepStatue", parts)


def home_extras(P):
    # Fauteuil, table basse, bibliothèque, armoire, bureau gamer, pouf, aquarium, horloge, frigo, machine à laver
    parts = sofa_parts(3.6, "fabricblue", "fabricblue", "fabricblue", cushions=1)
    P.prop("Home_Armchair", parts)
    parts = [(box((0, 0, 1.4), (5.0, 3.0, 0.3), bevel=0.06), "woodlight")]
    for x in (-2.1, 2.1):
        for y in (-1.1, 1.1):
            parts.append((box((x, y, 0.65), (0.3, 0.3, 1.3)), "wooddark"))
    parts.append((box((-1.0, 0, 1.62), (1.4, 1.4, 0.14)), "cardboardtex"))
    parts.append((cylinder((1.2, 0.4, 1.55), 0.3, 0.7, 8), "red"))
    P.prop("Home_CoffeeTable", parts)
    # Bibliothèque ouverte : côtés, fond, étagères, livres de couleur
    parts = [
        (box((-2.4, 0, 4.0), (0.2, 1.6, 8.0)), "wood"),
        (box((2.4, 0, 4.0), (0.2, 1.6, 8.0)), "wood"),
        (box((0, 0.7, 4.0), (4.6, 0.2, 8.0)), "wooddark"),
        (box((0, 0, 7.9), (5.0, 1.6, 0.2)), "wood"),
    ]
    for k, z in enumerate((0.1, 2.1, 4.1, 6.1)):
        parts.append((box((0, 0, z), (4.6, 1.5, 0.2)), "woodlight"))
        parts.append((box((-0.4 + (k % 2) * 0.6, 0.05, z + 0.85), (3.4, 1.0, 1.5)), "bookspines"))
    parts.append((box((1.7, 0.0, 6.6), (0.6, 0.6, 0.8)), "gold"))
    P.prop("Home_Bookshelf", parts)
    parts = [(box((0, 0, 4.0), (4.6, 2.2, 8.0), bevel=0.08), "woodlight"),
             (box((-1.12, -1.12, 4.2), (2.1, 0.06, 7.2)), "wood"),
             (box((1.12, -1.12, 4.2), (2.1, 0.06, 7.2)), "wood")]
    for x in (-0.3, 0.3):
        parts.append((box((x, -1.2, 4.3), (0.15, 0.12, 0.9)), "gold"))
    P.prop("Home_Wardrobe", parts)
    parts = [(box((0, 0.3, 2.6), (6.0, 2.6, 0.2), bevel=0.05), "charcoal")]
    for x in (-2.8, 2.8):
        parts.append((box((x, 0.3, 1.25), (0.25, 2.4, 2.5)), "charcoal"))
    parts += [
        (box((0, 1.0, 4.2), (3.2, 0.25, 2.0), bevel=0.05), "black"),
        (box((0, 0.86, 4.2), (2.9, 0.04, 1.7)), "screentex"),
        (box((0, 1.1, 2.95), (0.6, 0.4, 0.5)), "black"),
        (box((0, -0.3, 2.75), (2.4, 0.8, 0.1)), "darkgrey"),
        (box((2.2, 0.3, 3.6), (0.9, 2.0, 1.8), bevel=0.05), "black"),
        (box((2.2, -0.71, 3.6), (0.5, 0.04, 1.4)), "neonblue"),
    ]
    P.prop("Home_GamingDesk", parts)
    parts = [
        (cylinder((0, 0, 0), 1.2, 0.2, 5), "black"),
        (cylinder((0, 0, 0.2), 0.15, 1.3, 6), "chrome"),
        (box((0, 0, 1.75), (2.0, 2.0, 0.5), bevel=0.15), "red"),
        (box((0, 0.9, 3.3), (1.8, 0.5, 2.8), bevel=0.15), "red"),
        (box((0, 0.88, 3.4), (0.6, 0.55, 2.2)), "black"),
        (box((0, 0.95, 4.9), (1.2, 0.5, 0.6), bevel=0.2), "black"),
    ]
    for s in (-1, 1):
        parts.append((box((s * 1.1, 0.1, 2.5), (0.25, 1.4, 0.2)), "black"))
    P.prop("Home_GamingChair", parts)
    P.prop("Home_BeanBag", [(ico((0, 0, 1.2), 1.9, 2, 0.08, 61, squash=0.6), "orange"),
                            (ico((0, 0.6, 1.9), 1.2, 1, 0.08, 62, squash=0.7), "orange")])
    # Aquarium : meuble, eau visible, cadre noir, poissons et algues devant la vitre
    parts = [
        (box((0, 0, 1.2), (5.0, 2.2, 2.4)), "wooddark"),
        (box((0, 0, 3.55), (4.7, 1.9, 2.3)), "water_tex"),
        (box((0, 0, 2.55), (4.75, 1.95, 0.3)), "sandtex"),
        (box((0, 0, 4.85), (5.0, 2.2, 0.3)), "black"),
    ]
    for x in (-2.45, 2.45):
        for y in (-1.0, 1.0):
            parts.append((box((x, y, 3.6), (0.14, 0.14, 2.5)), "black"))
    for k, (x, z, c) in enumerate(((-1.2, 3.4, "orange"), (0.8, 3.9, "yellow"), (1.5, 3.0, "blue"))):
        parts.append((sphere((x, -0.98, z), (0.35, 0.1, 0.22), 6, 4), c))
        parts.append((wedge((x + 0.45, -0.98, z), (0.25, 0.08, 0.35)), c))
    parts.append((segment((-1.8, -0.95, 2.7), (-1.6, -0.95, 4.0), 0.1, 4), "green"))
    parts.append((segment((-1.5, -0.95, 2.7), (-1.2, -0.95, 3.7), 0.1, 4), "leaflight"))
    parts.append((ico((1.7, -0.7, 2.9), 0.35, 1, 0.2, 77), "rock"))
    P.prop("Home_Aquarium", parts)
    parts = [
        (cylinder((0, 0.1, 1.6), 1.6, 0.25, 16, axis="Y"), "white"),
        (torus((0, 0.0, 1.6), 1.6, 0.12, 16, 4, axis="Y"), "black"),
        (box((0, -0.05, 2.1), (0.12, 0.05, 1.0)), "black"),
        (box((0.35, -0.05, 1.6), (0.7, 0.05, 0.12)), "black"),
    ]
    for k in range(12):
        a = math.radians(k * 30)
        parts.append((box((math.cos(a) * 1.3, -0.04, 1.6 + math.sin(a) * 1.3), (0.15, 0.04, 0.15)), "black"))
    P.prop("Home_WallClock", parts)
    parts = [
        (cylinder((0, 0, 0), 1.1, 1.6, 8, radius_top=1.3), "white"),
        (ico((0, 0, 3.4), 2.0, 1, 0.25, 71, squash=1.2), "darkgreen"),
    ]
    for k in range(5):
        a = math.radians(k * 72)
        parts.append((segment((0, 0, 1.6), (math.cos(a) * 1.8, math.sin(a) * 1.8, 4.6), 0.1, 4), "green"))
        parts.append((sphere((math.cos(a) * 1.9, math.sin(a) * 1.9, 4.7), (0.9, 0.9, 0.25), 8, 3), "leaf"))
    P.prop("Home_TallPlant", parts)
    # Cuisine : meuble bas, plan de travail, évier, plaque, crédence, placards hauts, robinet
    parts = [
        (box((0, 0, 1.5), (6.0, 2.2, 3.0)), "woodlight"),
        (box((0, -0.05, 3.1), (6.2, 2.4, 0.25)), "marbleblack"),
        (box((1.5, -0.1, 3.2), (1.8, 1.3, 0.08)), "steel"),
        (box((-1.6, -0.1, 3.24), (1.6, 1.3, 0.04)), "charcoal"),
        (box((0, 1.0, 4.6), (6.0, 0.15, 2.6)), "tiles"),
        (box((0, 0.6, 6.9), (6.0, 1.0, 2.0)), "woodlight"),
        (segment((1.5, 0.6, 3.2), (1.5, 0.6, 4.2), 0.08, 6), "chrome"),
        (segment((1.5, 0.6, 4.2), (1.5, 0.1, 4.2), 0.08, 6), "chrome"),
        (cylinder((-1.6, 0.0, 3.3), 0.45, 0.4, 8), "charcoal"),
    ]
    for x in (-2.0, 0.0, 2.0):
        parts.append((box((x, -1.11, 2.6), (1.0, 0.06, 0.15)), "chrome"))
        parts.append((box((x, 0.08, 6.4), (0.12, 0.06, 0.6)), "chrome"))
    for x in (-1.5, 1.5):
        parts.append((box((x, -1.11, 1.4), (2.8, 0.04, 2.4)), "wood"))
    P.prop("Home_KitchenCounter", parts)
    parts = [(cylinder((0, 0, 0), 0.3, 2.6, 8), "wooddark"), (cylinder((0, 0, 2.6), 2.4, 0.2, 12), "woodlight")]
    for ang in (0, 90, 180, 270):
        ch = [(box((0, 2.6, 1.4), (1.6, 1.6, 0.18)), "woodlight"), (box((0, 3.35, 2.4), (1.6, 0.15, 2.0)), "wood")]
        for x in (-0.65, 0.65):
            for y in (2.0, 3.25):
                ch.append((box((x, y, 0.7), (0.15, 0.15, 1.4)), "wooddark"))
        for bm, c in ch:
            parts.append((rotate(bm, ang, "Z"), c))
    P.prop("Home_DiningSet", parts)
    parts = [
        (box((0, 0, 0.9), (4.6, 1.6, 1.8)), "brickwhite"),
        (box((0, 0, 2.5), (5.2, 1.8, 0.3)), "wooddark"),
        (box((0, -0.5, 1.0), (2.6, 0.8, 1.4)), "black"),
        (cone((-0.4, -0.5, 0.3), 0.6, 1.2, 5), "flame"),
        (cone((0.4, -0.5, 0.3), 0.5, 0.9, 5), "orange"),
        (box((0, 0.3, 5.0), (3.4, 1.0, 4.8)), "brickwhite"),
    ]
    P.prop("Home_Fireplace", parts)


def garage(P):
    parts = [
        (box((0, 0, 3.6), (3.0, 3.0, 7.2), bevel=0.15), "white"),
        (box((0, -1.52, 5.4), (2.8, 0.05, 0.05)), "grey"),
        (box((1.1, -1.55, 6.3), (0.15, 0.12, 1.2)), "chrome"),
        (box((1.1, -1.55, 3.4), (0.15, 0.12, 1.6)), "chrome"),
    ]
    for k, (x, z, c) in enumerate(((-0.6, 6.5, "yellow"), (0.4, 6.8, "red"), (-0.2, 4.6, "blue"), (0.6, 2.4, "green"))):
        parts.append((box((x, -1.55, z), (0.5, 0.06, 0.5)), c))
    P.prop("Garage_Fridge", parts)
    parts = [
        (box((0, 0, 1.8), (3.2, 3.0, 3.6), bevel=0.12), "white"),
        (cylinder((0, -1.5, 1.6), 1.05, 0.12, 14, axis="Y"), "lightgrey"),
        (cylinder((0, -1.56, 1.6), 0.85, 0.06, 14, axis="Y"), "glass"),
        (box((0, -1.4, 3.2), (3.0, 0.2, 0.6)), "lightgrey"),
        (cylinder((0.9, -1.55, 3.2), 0.18, 0.06, 8, axis="Y"), "darkgrey"),
    ]
    P.prop("Garage_WashingMachine", parts)
    parts = [(box((0, 0, 2.9), (7.0, 2.6, 0.3), bevel=0.04), "planks")]
    for x in (-3.2, 3.2):
        for y in (-1.0, 1.0):
            parts.append((box((x, y, 1.4), (0.3, 0.3, 2.8)), "wood"))
    parts.append((box((0, 0, 0.8), (6.6, 2.2, 0.2)), "wood"))
    parts.append((box((0, 1.2, 5.0), (7.0, 0.15, 4.0)), "cardboardtex"))
    for k, (x, z) in enumerate(((-2.4, 5.6), (-1.0, 5.2), (0.6, 5.8), (2.2, 5.0))):
        parts.append((box((x, 1.05, z), (0.3, 0.15, 1.4)), ["red", "steel", "blue", "yellow"][k]))
    parts.append((box((1.8, 0, 3.3), (1.4, 0.8, 0.5)), "red"))
    parts.append((box((-2.0, 0.2, 3.15), (0.9, 0.4, 0.2)), "steel"))
    P.prop("Garage_Workbench", parts)
    parts = []
    for k, (x, y, z, s, r) in enumerate(((0, 0, 1.2, 2.4, 5), (2.3, 0.3, 1.0, 2.0, -8), (0.3, 0.2, 3.3, 1.8, 14),
                                         (2.0, -0.2, 2.9, 1.5, 30))):
        b = box((x, y, z), (s, s, s), bevel=0.04)
        parts.append((rotate(b, r, "Z", (x, y, z)), "cardboardtex"))
        tape = box((x, y, z + s / 2), (s * 0.25, s + 0.02, 0.02))
        parts.append((rotate(tape, r, "Z", (x, y, z)), "tan"))
    P.prop("Garage_BoxStack", parts)
    parts = []
    for k in range(5):
        b = box((0, 0, 0.12 + k * 0.24), (2.6, 2.6, 0.22))
        parts.append((rotate(b, k * 9, "Z"), {"top": "pizzatop" if k == 4 else "cardboardtex",
                                               "side": "cardboardtex"}))
    P.prop("Garage_PizzaBoxes", parts)
    parts = [
        (box((0, 0, 0.15), (3.0, 3.0, 0.3)), "darkgrey"),
        (cylinder((0, 0, 0.3), 1.2, 3.4, 10), "red"),
        (sphere((0, 0, 3.7), (1.2, 1.2, 0.5), 10, 4), "red"),
        (cylinder((0, 0, 4.1), 0.3, 0.6, 6), "black"),
        (box((0, -1.25, 2.0), (1.0, 0.1, 1.2)), "paper"),
    ]
    P.prop("Garage_GasCan", parts)
    parts = [(torus((0, 0, 1.5), 1.1, 0.42, 12, 6, axis="Y"), "rubber"),
             (cylinder((0, -0.5, 1.5), 0.6, 1.0, 8, axis="Y"), "steel")]
    P.prop("Garage_Tire", parts)


def build_home(P):
    furniture(P)
    home_extras(P)
    garage(P)

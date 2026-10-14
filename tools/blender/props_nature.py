"""
Végétation et éléments naturels (ville, parc, et futures zones : plage, montagne).
À exécuter dans Blender après props_lib.py :  build_nature(Props(pal, "Props_Nature"))
"""


def trunk(base, height, r0, r1, sides=7, lean=(0, 0)):
    top = (base[0] + lean[0], base[1] + lean[1], base[2] + height)
    return segment(base, top, r0, sides, r1)


def round_tree(P, name, height, crown, seed, colors=("leaf", "leaflight", "darkgreen")):
    parts = [(trunk((0, 0, 0), height, 0.75, 0.45), "bark")]
    # Racines
    for k in range(4):
        a = math.radians(45 + k * 90)
        parts.append((segment((0, 0, 0.6), (math.cos(a) * 1.3, math.sin(a) * 1.3, 0), 0.35, 5, 0.12), "bark"))
    # Branches qui portent les touffes
    rnd = random.Random(seed)
    clumps = [((0, 0, height + crown * 0.55), crown), ((0, 0, height + crown * 1.15), crown * 0.75)]
    for k in range(6):
        a = math.radians(k * 60 + rnd.uniform(-20, 20))
        d = crown * rnd.uniform(0.55, 0.75)
        c = (math.cos(a) * d, math.sin(a) * d, height + crown * rnd.uniform(-0.1, 0.5))
        clumps.append((c, crown * rnd.uniform(0.55, 0.72)))
        parts.append((segment((0, 0, height * 0.8), (c[0] * 0.6, c[1] * 0.6, c[2] - 0.5), 0.25, 5, 0.12), "bark"))
    for k, (c, r) in enumerate(clumps):
        parts.append((ico(c, r, 1, 0.16, seed * 10 + k, squash=0.85), colors[k % len(colors)]))
    P.prop(name, parts)


def pine(P, name, height, seed, snowy=False):
    parts = [(trunk((0, 0, 0), height * 0.35, 0.55, 0.4), "bark")]
    tiers = 5
    for k in range(tiers):
        t = k / tiers
        r = 3.6 * (1 - t * 0.7)
        z = height * (0.14 + t * 0.5)
        bm = cone((0, 0, z), r, height * 0.32, 10)
        rotate(bm, k * 17, "Z")
        parts.append((bm, "darkgreen" if k % 2 == 0 else "green"))
        if snowy:
            parts.append((cone((0, 0, z + height * 0.17), r * 0.5, height * 0.15, 10), "snow"))
    P.prop(name, parts)


def palm(P, name, height, seed, lean=1.6):
    rnd = random.Random(seed)
    parts = []
    # Tronc courbé en anneaux
    segs = 7
    prev = (0, 0, 0)
    for k in range(1, segs + 1):
        t = k / segs
        cur = (lean * t * t * 2.0, 0, height * t)
        parts.append((segment(prev, cur, 0.55 - 0.2 * t, 7, 0.5 - 0.2 * t), "palmbark"))
        prev = cur
    top = prev
    # Palmes : feuilles en deux pans inclinés, retombantes
    for k in range(8):
        a = math.radians(k * (360 / 8) + rnd.uniform(-12, 12))
        L = rnd.uniform(6.0, 7.2)
        d = Vector((math.cos(a), math.sin(a), 0))
        mid = Vector(top) + d * (L * 0.5) + Vector((0, 0, 0.6))
        tip = Vector(top) + d * L + Vector((0, 0, -2.4))
        side = Vector((-d.y, d.x, 0)) * 1.2
        bm = bmesh.new()
        v = [bm.verts.new(p) for p in (Vector(top) + Vector((0, 0, 0.2)), mid + side, tip, mid - side,
                                        mid + Vector((0, 0, 0.25)))]
        bm.faces.new((v[0], v[1], v[4]))
        bm.faces.new((v[4], v[1], v[2]))
        bm.faces.new((v[0], v[4], v[3]))
        bm.faces.new((v[4], v[2], v[3]))
        # Face du dessous pour que la feuille soit visible des deux côtés
        bm.faces.new((v[0], v[3], v[2], v[1]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        parts.append((bm, "leaf" if k % 2 else "green"))
    for k in range(3):
        a = math.radians(k * 120)
        parts.append((sphere((top[0] + math.cos(a) * 0.45, top[1] + math.sin(a) * 0.45, top[2] - 0.35), 0.35, 6, 4),
                      "brown"))
    P.prop(name, parts)


def rock(P, name, size, seed, flat=0.7, tex="rocktex"):
    parts = [(ico((0, 0, size * flat * 0.7), size, 1, 0.28, seed, squash=flat), tex)]
    rnd = random.Random(seed)
    for k in range(2):
        a = rnd.uniform(0, 6.28)
        s = size * rnd.uniform(0.35, 0.5)
        parts.append((ico((math.cos(a) * size * 0.9, math.sin(a) * size * 0.9, s * 0.5), s, 1, 0.3, seed + k + 1,
                          squash=0.7), tex))
    P.prop(name, parts)


def flower_patch(P):
    parts = [(cylinder((0, 0, 0), 2.4, 0.25, 10), "dirt")]
    rnd = random.Random(5)
    colors = ["red", "yellow", "pink", "purple", "white", "orange"]
    for k in range(11):
        a = rnd.uniform(0, 6.28)
        d = rnd.uniform(0.2, 2.0)
        x, y = math.cos(a) * d, math.sin(a) * d
        h = rnd.uniform(0.8, 1.5)
        parts.append((segment((x, y, 0.2), (x, y, h), 0.06, 4), "green"))
        parts.append((ico((x, y, h + 0.15), 0.28, 1, 0.1, 40 + k, squash=0.6), colors[k % len(colors)]))
        parts.append((sphere((x, y, h + 0.22), 0.1, 6, 3), "yellow"))
    P.prop("FlowerPatch", parts)


def grass_tuft(P):
    parts = []
    rnd = random.Random(8)
    for k in range(9):
        a = rnd.uniform(0, 6.28)
        d = rnd.uniform(0, 0.6)
        x, y = math.cos(a) * d, math.sin(a) * d
        tip = (x + rnd.uniform(-0.4, 0.4), y + rnd.uniform(-0.4, 0.4), rnd.uniform(1.0, 1.8))
        parts.append((cone((x, y, 0), 0.18, 1, 3), "leaflight" if k % 2 else "leaf"))
        bm = parts[-1][0]
        for v in bm.verts:
            if v.co.z > 0.5:
                v.co = Vector(tip)
    P.prop("GrassTuft", parts)


def stump(P):
    parts = [
        (cylinder((0, 0, 0), 1.1, 1.3, 9, radius_top=0.95), "bark"),
        (cylinder((0, 0, 1.3), 0.92, 0.06, 9), "woodlight"),
    ]
    for k in range(4):
        a = math.radians(20 + k * 90)
        parts.append((segment((0, 0, 0.5), (math.cos(a) * 1.6, math.sin(a) * 1.6, 0), 0.4, 5, 0.15), "bark"))
    # Hache plantée dedans (humour : bûcheronnage = cardio)
    parts.append((segment((0.2, 0, 1.3), (0.9, 0.2, 3.2), 0.08, 5), "wood"))
    parts.append((box((0.15, 0, 1.45), (0.9, 0.12, 0.6)), "steel"))
    P.prop("Stump", parts)


def log(P):
    parts = [
        (cylinder((-3, 0, 0.8), 0.8, 6.0, 9, axis="X"), "bark"),
        (cylinder((-3.02, 0, 0.8), 0.68, 0.04, 9, axis="X"), "woodlight"),
        (cylinder((2.99, 0, 0.8), 0.68, 0.04, 9, axis="X"), "woodlight"),
    ]
    for v in parts[0][0].verts:
        v.co.z -= 0.0
    P.prop("Log", parts)


def mushroom_cluster(P):
    parts = []
    for k, (x, y, h, r) in enumerate(((0, 0, 1.4, 0.9), (0.9, 0.5, 0.9, 0.55), (-0.7, 0.6, 0.7, 0.45))):
        parts.append((cylinder((x, y, 0), 0.22, h, 7, radius_top=0.18), "offwhite"))
        parts.append((sphere((x, y, h), (r, r, r * 0.55), 8, 4), "red"))
        for j in range(3):
            a = math.radians(j * 120 + k * 30)
            parts.append((sphere((x + math.cos(a) * r * 0.5, y + math.sin(a) * r * 0.5, h + r * 0.38), 0.12, 6, 3),
                          "white"))
    P.prop("Mushrooms", parts)


def build_nature(P):
    round_tree(P, "TreeRound", 7, 3.6, 1)
    round_tree(P, "TreeRoundBig", 10, 5.0, 2)
    round_tree(P, "TreeAutumn", 8, 4.0, 3, colors=("orange", "yellow", "rust"))
    round_tree(P, "TreeBlossom", 7, 3.8, 4, colors=("pink", "pastelpink", "white"))
    pine(P, "Pine", 14, 1)
    pine(P, "PineSnowy", 14, 2, snowy=True)
    palm(P, "PalmTree", 14, 1)
    palm(P, "PalmTreeLeaning", 12, 2, lean=3.0)
    rock(P, "Rock", 2.0, 3)
    rock(P, "RockBig", 4.5, 6, flat=0.8)
    rock(P, "MoonRock", 2.5, 9, flat=0.6, tex="moon")
    flower_patch(P)
    grass_tuft(P)
    stump(P)
    log(P)
    mushroom_cluster(P)

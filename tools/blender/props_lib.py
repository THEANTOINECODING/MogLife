"""
Bibliothèque des DÉCORS low poly PS1 de MOG LIFE (à charger avec exec dans Blender).

- Une seule texture « palette » 512x512 partagée par tous les décors (cases de 32 px) :
  couleurs unies légèrement bruitées (effet PS1) + motifs (bois, brique, marbre, tissu, rayures, écran…).
  Une case unie est plaquée en un seul point (aucune bavure de couleur quand Roblox réduit la texture),
  un motif est projeté à plat sur chaque face, avec une marge.
- Formes à facettes : boîte (chanfrein optionnel), cylindre, cône, sphère basse, tore, segment (tube),
  prisme extrudé depuis un profil, coin (wedge).
- prop(nom, pièces) fusionne les pièces en un seul objet : origine au milieu de la base (z = 0).

Convention : Z vers le haut, 1 unité = 1 stud, le devant du décor vers -Y (comme les personnages).
Couleurs : chaque pièce reçoit un nom de case, ou un dict par direction de face
{"top": ..., "side": ..., "bottom": ..., "front": ..., "back": ...} (clé "side" = défaut).
"""
import bpy, bmesh, math, random
from mathutils import Vector, Matrix

SIZE, CELL, PAD = 512, 32, 5
GRID = SIZE // CELL  # 16 x 16 cases


def _clamp(v):
    return max(0.0, min(1.0, v))


def hexrgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


# ------------------------------------------------------------------ palette
class Palette:
    def __init__(self, name="MogProps"):
        self.name = name
        self.px = [0.0] * (SIZE * SIZE * 4)
        self.cells = {}      # nom -> (cx, cy)
        self.solid = set()   # cases unies (UV en un point)
        self.next = 0
        self.rng = random.Random(7)

    def _slot(self):
        i = self.next
        self.next += 1
        return i % GRID, i // GRID

    def put(self, x, y, c):
        i = (y * SIZE + x) * 4
        self.px[i:i + 4] = [_clamp(c[0]), _clamp(c[1]), _clamp(c[2]), 1.0]

    def paint(self, name, fn, solid=False):
        cx, cy = self._slot()
        self.cells[name] = (cx, cy)
        if solid:
            self.solid.add(name)
        for y in range(CELL):
            for x in range(CELL):
                self.put(cx * CELL + x, cy * CELL + y, fn(x, y))

    def color(self, name, rgb, noise=0.035):
        """Couleur unie avec un léger grain (effet PS1)."""
        rgb = hexrgb(rgb) if isinstance(rgb, str) else rgb
        r = self.rng

        def fn(x, y):
            n = r.uniform(-noise, noise)
            return (rgb[0] + n, rgb[1] + n, rgb[2] + n)
        self.paint(name, fn, solid=True)

    def pattern(self, name, fn):
        self.paint(name, fn)

    def material(self):
        img = bpy.data.images.get(f"{self.name}_Palette")
        if img and tuple(img.size) != (SIZE, SIZE):
            bpy.data.images.remove(img)
            img = None
        img = img or bpy.data.images.new(f"{self.name}_Palette", SIZE, SIZE)
        img.pixels = self.px
        img.pack()
        mat = bpy.data.materials.get(f"{self.name}_Mat") or bpy.data.materials.new(f"{self.name}_Mat")
        mat.use_nodes = True
        nt = mat.node_tree
        bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs["Roughness"].default_value = 1.0
        tex = next((n for n in nt.nodes if n.type == "TEX_IMAGE"), None) or nt.nodes.new("ShaderNodeTexImage")
        tex.image = img
        tex.interpolation = "Closest"
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        return mat


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def build_palette():
    P = Palette()
    rnd = random.Random(11)
    # --- couleurs unies (nom : hex)
    solids = {
        "white": "f0eee8", "offwhite": "e6dfd0", "cream": "f4e6c4", "lightgrey": "c8c6c0", "grey": "8e8c88",
        "darkgrey": "4a4a50", "charcoal": "2a2a2e", "black": "18181a",
        "red": "d2382e", "darkred": "8e2a26", "orange": "ee8a32", "rust": "b0602e", "yellow": "f2c63c",
        "gold": "e6be3c", "darkgold": "a8822a", "lime": "9ad24a", "green": "4e9a44", "darkgreen": "2e6a34",
        "leaf": "5aa04a", "leaflight": "7cc05a", "teal": "3aa69a", "sky": "8ec8ee", "blue": "3c6ec8",
        "navy": "283c78", "purple": "8a4ab4", "pink": "ee90b4", "hotpink": "ff4aa8", "magenta": "c83c9c",
        "brown": "825c3c", "darkbrown": "553a26", "tan": "c8a070", "skin": "e8b48c", "skindark": "a87250",
        "orangeskin": "e88a4a", "beige": "dcc8a0", "sand": "e8d49a", "water": "4aa6dc", "glass": "a6d2ec",
        "chrome": "cfd4da", "steel": "9aa2aa", "iron": "5a6066", "copper": "c47a44", "bronze": "b07840",
        "silver": "c8ccd2", "rubber": "222226", "neonpink": "ff5ad2", "neonblue": "4ae6ff", "neongreen": "5aff8a",
        "screen": "6aa8e6", "lampwarm": "fff0c0", "flame": "ff9a2a", "ember": "d23a1a", "snow": "f6f8fc",
        "rock": "8a8478", "darkrock": "5e5a52", "moon": "b8b6ae", "pastelpink": "eeb2be", "pastelmint": "a8dec6",
        "pastelyellow": "f4e4a0", "pastelblue": "aaccea", "pastelpurple": "c8bae4", "pastelpeach": "f8c8a0",
        "khaki": "a89a64", "olive": "6a7a3a", "cardboard": "b08a5a", "paper": "f2ede0", "pizza": "f0b450",
        "pepperoni": "c8382c", "cheese": "f6d860", "lettuce": "6ac04a", "tomato": "e0402c", "banana": "f6dc4a",
        "apple": "d23a2e", "grape": "7a3aa0", "carrot": "f08a2a", "milk": "f8f8f4",
    }
    for name, h in solids.items():
        P.color(name, h)

    # --- motifs
    def wood(base, dark):
        b, d = hexrgb(base), hexrgb(dark)
        seeds = [rnd.random() for _ in range(CELL)]

        def fn(x, y):
            grain = 0.5 + 0.5 * math.sin(y * 1.3 + math.sin(x * 0.35 + seeds[y] * 6) * 1.6)
            c = mix(b, d, grain * 0.45)
            if y % 8 == 0:
                c = mix(c, d, 0.8)
            n = rnd.uniform(-0.03, 0.03)
            return (c[0] + n, c[1] + n, c[2] + n)
        return fn

    P.pattern("wood", wood("a8784c", "6a4428"))
    P.pattern("woodlight", wood("d0a46c", "9a7044"))
    P.pattern("wooddark", wood("6a4428", "3a2414"))

    def planks(base, dark):
        b, d = hexrgb(base), hexrgb(dark)

        def fn(x, y):
            c = b
            if x % 8 == 0:
                c = d
            elif (y + (x // 8) * 11) % 16 == 0:
                c = mix(b, d, 0.7)
            n = rnd.uniform(-0.04, 0.04)
            return (c[0] + n, c[1] + n, c[2] + n)
        return fn

    P.pattern("planks", planks("b88a58", "6a4a2c"))
    P.pattern("floorboards", planks("d8a868", "8a6236"))

    def brick(base, mortar):
        b, m = hexrgb(base), hexrgb(mortar)

        def fn(x, y):
            row = y // 6
            off = 4 if row % 2 else 0
            if y % 6 == 0 or (x + off) % 10 == 0:
                return m
            n = rnd.uniform(-0.06, 0.06)
            return (b[0] + n, b[1] + n * 0.6, b[2] + n * 0.5)
        return fn

    P.pattern("brick", brick("a24a3a", "d6ccbc"))
    P.pattern("brickwhite", brick("e6e0d6", "a8a098"))

    def stripes(a, b, width=4, horizontal=False):
        ca, cb = hexrgb(a), hexrgb(b)

        def fn(x, y):
            v = y if horizontal else x
            return ca if (v // width) % 2 == 0 else cb
        return fn

    P.pattern("stripe_redwhite", stripes("d2382e", "f0eee8"))
    P.pattern("stripe_bluewhite", stripes("3c6ec8", "f0eee8"))
    P.pattern("stripe_greenwhite", stripes("4e9a44", "f0eee8"))
    P.pattern("stripe_yellowblack", stripes("f2c63c", "222226", horizontal=True))
    P.pattern("melonskin", stripes("2e6a34", "7cc05a", width=3))
    P.pattern("stripe_hazard", lambda x, y: hexrgb("f2c63c") if ((x + y) // 5) % 2 == 0 else hexrgb("222226"))
    P.pattern("stripe_pole", lambda x, y: [hexrgb("d2382e"), hexrgb("f0eee8"), hexrgb("3c6ec8")][((x + y) // 4) % 3])
    P.pattern("checker", lambda x, y: hexrgb("f0eee8") if ((x // 4) + (y // 4)) % 2 == 0 else hexrgb("222226"))
    P.pattern("checker_red", lambda x, y: hexrgb("f0eee8") if ((x // 4) + (y // 4)) % 2 == 0 else hexrgb("d2382e"))

    def noisy(base, amount, speck=None, speck_rate=0.0):
        b = hexrgb(base)
        s = hexrgb(speck) if speck else None

        def fn(x, y):
            if s and rnd.random() < speck_rate:
                return s
            n = rnd.uniform(-amount, amount)
            return (b[0] + n, b[1] + n, b[2] + n)
        return fn

    P.pattern("grass", lambda x, y: mix(hexrgb("5aa04a"), hexrgb("3e7a34"), rnd.random() * 0.8))
    P.pattern("asphalt", noisy("3a3a40", 0.05, "6a6a70", 0.06))
    P.pattern("concrete", noisy("a8a6a0", 0.05, "8a8882", 0.08))
    P.pattern("sandtex", noisy("e8d49a", 0.05, "c8b47a", 0.1))
    P.pattern("rocktex", noisy("8a8478", 0.08, "5e5a52", 0.12))
    P.pattern("dirt", noisy("6e5038", 0.06, "4a3424", 0.15))
    P.pattern("metal", lambda x, y: mix(hexrgb("9aa2aa"), hexrgb("c8ced4"), 0.5 + 0.5 * math.sin(y * 0.9 + x * 0.05)))
    P.pattern("rusty", noisy("8a5a3a", 0.08, "b0602e", 0.25))
    P.pattern("fabric", lambda x, y: hexrgb("7a5a44") if (x + y) % 2 == 0 else hexrgb("6a4c3a"))
    P.pattern("fabricblue", lambda x, y: hexrgb("4a68a8") if (x + y) % 2 == 0 else hexrgb("3e5a94"))
    P.pattern("fabricred", lambda x, y: hexrgb("b83a34") if (x + y) % 2 == 0 else hexrgb("a0302c"))
    P.pattern("cardboardtex", lambda x, y: hexrgb("8e6a42") if x % 6 == 0 else mix(hexrgb("b08a5a"), hexrgb("a07a4a"), rnd.random()))

    leo_spots = [(rnd.randrange(CELL), rnd.randrange(CELL), rnd.uniform(1.6, 2.8)) for _ in range(14)]

    def leopard(x, y):
        for sx, sy, r in leo_spots:
            d = math.hypot(x - sx, y - sy)
            if d < r * 0.55:
                return hexrgb("7a4a20")
            if d < r:
                return hexrgb("2a1a10")
        return hexrgb("e0a850")
    P.pattern("leopard", leopard)
    P.pattern("zebra", lambda x, y: hexrgb("f0eee8") if math.sin(x * 0.7 + math.sin(y * 0.3) * 2.2) > 0 else hexrgb("1a1a1c"))

    veins = [(rnd.uniform(0, 6.28), rnd.uniform(0.15, 0.35)) for _ in range(3)]

    def marble(base, vein):
        b, v = hexrgb(base), hexrgb(vein)

        def fn(x, y):
            t = sum(abs(math.sin(x * f + y * f * 0.6 + p)) for p, f in veins) / 3
            return mix(v, b, min(1, t * 1.6))
        return fn

    P.pattern("marble", marble("eeeae2", "a8a49c"))
    P.pattern("marblegold", marble("e6c45a", "a07a2a"))
    P.pattern("marbleblack", marble("3a3a3e", "8a8a90"))

    def screen(x, y):
        c = mix(hexrgb("9ad2ff"), hexrgb("3a78c8"), y / CELL)
        return mix(c, hexrgb("ffffff"), 0.25) if y % 3 == 0 else c
    P.pattern("screentex", screen)
    P.pattern("sunset", lambda x, y: mix(hexrgb("ffcc5a"), hexrgb("e04a7a"), y / CELL) if y < 22 else hexrgb("5a2a80"))
    P.pattern("water_tex", lambda x, y: mix(hexrgb("4aa6dc"), hexrgb("8ad2f4"), 0.5 + 0.5 * math.sin(x * 0.6 + y * 0.9)))
    P.pattern("pizzatop", lambda x, y: hexrgb("c8382c") if ((x - 10) ** 2 + (y - 10) ** 2 < 14 or (x - 22) ** 2 + (y - 18) ** 2 < 14 or (x - 12) ** 2 + (y - 24) ** 2 < 12) else hexrgb("f2c45a"))
    P.pattern("bookspines", lambda x, y: [hexrgb("d2382e"), hexrgb("3c6ec8"), hexrgb("f2c63c"), hexrgb("4e9a44"), hexrgb("8a4ab4")][(x // 4) % 5] if y % 16 not in (0, 15) else hexrgb("6a4428"))
    P.pattern("tiles", lambda x, y: hexrgb("d6dce2") if x % 8 == 0 or y % 8 == 0 else hexrgb("f2f4f6"))
    P.pattern("tilesblue", lambda x, y: hexrgb("e8eef4") if x % 8 == 0 or y % 8 == 0 else hexrgb("6aaedc"))
    P.pattern("roofshingle", lambda x, y: mix(hexrgb("9a463a"), hexrgb("6e2e26"), 0.6 if y % 6 == 0 else rnd.random() * 0.3))
    P.pattern("thatch", lambda x, y: mix(hexrgb("c8a860"), hexrgb("8e7038"), (math.sin(x * 1.7) * 0.5 + 0.5) * 0.6))
    P.pattern("bark", lambda x, y: mix(hexrgb("6e4a2e"), hexrgb("4a301c"), 0.7 if x % 5 == 0 else rnd.random() * 0.3))
    P.pattern("palmbark", lambda x, y: mix(hexrgb("9a7a4a"), hexrgb("6a5030"), 0.8 if y % 5 == 0 else rnd.random() * 0.25))
    P.pattern("rope", lambda x, y: mix(hexrgb("d8c08a"), hexrgb("9a8050"), 0.7 if (x + y) % 6 < 2 else 0.1))
    P.pattern("crate", lambda x, y: hexrgb("6a4a2c") if x < 3 or x > 28 or y < 3 or y > 28 or abs(x - y) < 2 else mix(hexrgb("b88a58"), hexrgb("a07444"), rnd.random()))
    # --- Ajouts de l'étape 1 (bâtiments). TOUJOURS ajouter à la fin : les décors déjà importés gardent leurs cases.
    P.pattern("wallpaper_cream", lambda x, y: hexrgb("efe2c4") if (x // 4) % 2 == 0 else hexrgb("e6d6b4"))
    P.pattern("wallpaper_mint", lambda x, y: hexrgb("cfe8d8") if not (x % 8 == 4 and y % 8 == 4) else hexrgb("8ec4a4"))
    P.pattern("wallpaper_rose", lambda x, y: hexrgb("f2d4d8") if (x + y) % 8 not in (0, 1) else hexrgb("e4b4bc"))
    P.pattern("wallpaper_blue", lambda x, y: hexrgb("d4e2f2") if (x // 3) % 3 else hexrgb("b4c8e2"))
    P.pattern("garagewall", noisy("b8bcc0", 0.04, "9a9ea4", 0.06))
    P.pattern("shopwall_white", noisy("f2f0ea", 0.02, "e2e0da", 0.04))
    P.pattern("gymwall", lambda x, y: hexrgb("3a3a44") if y < 12 else (hexrgb("d23a2e") if y < 15 else hexrgb("e8e6e2")))
    P.pattern("shingles", lambda x, y: mix(hexrgb("7a3a32"), hexrgb("5a2a24"), 0.7 if y % 5 == 0 else ((x + (y // 5) * 3) % 6 == 0) * 0.5))
    P.pattern("stonebase", lambda x, y: hexrgb("8a8478") if (y % 8 == 0 or (x + (y // 8) * 5) % 11 == 0) else mix(hexrgb("b8b0a0"), hexrgb("a49c8c"), rnd.random()))
    P.pattern("rubberfloor", noisy("2e2e34", 0.03, "e8c840", 0.02))
    return P


# ------------------------------------------------------------------ formes (bmesh en coordonnées monde)
def _finish(bm):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def box(center, size, bevel=0.0, taper=1.0):
    """Boîte ; bevel = chanfrein (en studs) sur les arêtes ; taper = rétrécit le dessus (x, y)."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        t = taper if v.co.z > 0 else 1.0
        v.co = Vector((v.co.x * size[0] * t, v.co.y * size[1] * t, v.co.z * size[2]))
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=1, affect="EDGES")
    for v in bm.verts:
        v.co += Vector(center)
    return _finish(bm)


def cylinder(base, radius, height, sides=8, radius_top=None, axis="Z", bevel=0.0):
    """Cylindre (ou tronc de cône) dont la base est en `base`, le long de l'axe donné."""
    bm = bmesh.new()
    rt = radius if radius_top is None else radius_top
    ring0 = [bm.verts.new((math.cos(2 * math.pi * i / sides) * radius, math.sin(2 * math.pi * i / sides) * radius, 0))
             for i in range(sides)]
    ring1 = [bm.verts.new((math.cos(2 * math.pi * i / sides) * rt, math.sin(2 * math.pi * i / sides) * rt, height))
             for i in range(sides)]
    for i in range(sides):
        j = (i + 1) % sides
        bm.faces.new((ring0[i], ring0[j], ring1[j], ring1[i]))
    bm.faces.new(list(reversed(ring0)))
    if rt > 1e-4:
        bm.faces.new(ring1)
    if bevel > 0:
        caps = [e for e in bm.edges if all(abs(v.co.z) < 1e-5 or abs(v.co.z - height) < 1e-5 for v in e.verts)
                and abs(e.verts[0].co.z - e.verts[1].co.z) < 1e-5]
        bmesh.ops.bevel(bm, geom=caps, offset=bevel, segments=1, affect="EDGES")
    rotm = {"Z": Matrix.Identity(3), "X": Matrix.Rotation(math.radians(90), 3, "Y"),
            "Y": Matrix.Rotation(math.radians(-90), 3, "X")}[axis]
    for v in bm.verts:
        v.co = rotm @ v.co + Vector(base)
    return _finish(bm)


def cone(base, radius, height, sides=8):
    bm = bmesh.new()
    ring = [bm.verts.new(Vector(base) + Vector((math.cos(2 * math.pi * i / sides) * radius,
                                                math.sin(2 * math.pi * i / sides) * radius, 0))) for i in range(sides)]
    tip = bm.verts.new(Vector(base) + Vector((0, 0, height)))
    for i in range(sides):
        bm.faces.new((ring[i], ring[(i + 1) % sides], tip))
    bm.faces.new(list(reversed(ring)))
    return _finish(bm)


def sphere(center, radii, u=8, v=6):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=1.0)
    r = radii if isinstance(radii, (tuple, list)) else (radii, radii, radii)
    for vert in bm.verts:
        vert.co = Vector((vert.co.x * r[0], vert.co.y * r[1], vert.co.z * r[2])) + Vector(center)
    return _finish(bm)


def ico(center, radius, subdiv=1, jitter=0.0, seed=1, squash=1.0):
    """Boule à facettes (rochers, feuillages) ; jitter déforme pour un aspect organique."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=radius)
    r = random.Random(seed)
    for v in bm.verts:
        k = 1 + r.uniform(-jitter, jitter)
        v.co = Vector((v.co.x * k, v.co.y * k, v.co.z * k * squash)) + Vector(center)
    return _finish(bm)


def torus(center, major, minor, seg=10, ring=6, axis="Z"):
    bm = bmesh.new()
    verts = []
    for i in range(seg):
        a = 2 * math.pi * i / seg
        row = []
        for j in range(ring):
            b = 2 * math.pi * j / ring
            p = Vector(((major + minor * math.cos(b)) * math.cos(a), (major + minor * math.cos(b)) * math.sin(a),
                        minor * math.sin(b)))
            row.append(bm.verts.new(p))
        verts.append(row)
    for i in range(seg):
        for j in range(ring):
            a, b = verts[i][j], verts[(i + 1) % seg][j]
            c, d = verts[(i + 1) % seg][(j + 1) % ring], verts[i][(j + 1) % ring]
            bm.faces.new((a, b, c, d))
    rotm = {"Z": Matrix.Identity(3), "X": Matrix.Rotation(math.radians(90), 3, "Y"),
            "Y": Matrix.Rotation(math.radians(90), 3, "X")}[axis]
    for v in bm.verts:
        v.co = rotm @ v.co + Vector(center)
    return _finish(bm)


def segment(p0, p1, radius, sides=6, radius1=None):
    """Tube entre deux points (pieds de chaise, barres, tuyaux, branches)."""
    p0, p1 = Vector(p0), Vector(p1)
    axis = (p1 - p0).normalized()
    side = axis.cross(Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((1, 0, 0))).normalized()
    up = axis.cross(side)
    r1 = radius if radius1 is None else radius1
    bm = bmesh.new()
    rings = []
    for p, r in ((p0, radius), (p1, r1)):
        rings.append([bm.verts.new(p + (side * math.cos(2 * math.pi * i / sides) + up * math.sin(2 * math.pi * i / sides)) * r)
                      for i in range(sides)])
    for i in range(sides):
        j = (i + 1) % sides
        bm.faces.new((rings[0][i], rings[0][j], rings[1][j], rings[1][i]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[1])
    return _finish(bm)


def extrude(profile, depth, y0=0.0, axis="Y"):
    """Prisme : profil 2D (liste de (x, z)) extrudé sur `depth` le long de Y (ou X)."""
    bm = bmesh.new()
    front = [bm.verts.new((x, y0, z)) for x, z in profile]
    back = [bm.verts.new((x, y0 + depth, z)) for x, z in profile]
    n = len(profile)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((front[i], front[j], back[j], back[i]))
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    if axis == "X":
        m = Matrix.Rotation(math.radians(90), 3, "Z")
        for v in bm.verts:
            v.co = m @ v.co
    return _finish(bm)


def wedge(center, size):
    """Coin : pente qui monte de -Y vers +Y."""
    x, y, z = size
    cx, cy, cz = center
    prof = [(-y / 2, -z / 2), (y / 2, -z / 2), (y / 2, z / 2)]
    bm = bmesh.new()
    a = [bm.verts.new((cx - x / 2, cy + py, cz + pz)) for py, pz in prof]
    b = [bm.verts.new((cx + x / 2, cy + py, cz + pz)) for py, pz in prof]
    for i in range(3):
        j = (i + 1) % 3
        bm.faces.new((a[i], a[j], b[j], b[i]))
    bm.faces.new(a)
    bm.faces.new(list(reversed(b)))
    return _finish(bm)


# ------------------------------------------------------------------ transformations
def rotate(bm, deg, axis="Z", center=(0, 0, 0)):
    m = Matrix.Rotation(math.radians(deg), 3, axis)
    c = Vector(center)
    for v in bm.verts:
        v.co = m @ (v.co - c) + c
    return bm


def move(bm, offset):
    for v in bm.verts:
        v.co += Vector(offset)
    return bm


def scale(bm, s, center=(0, 0, 0)):
    s = s if isinstance(s, (tuple, list)) else (s, s, s)
    c = Vector(center)
    for v in bm.verts:
        d = v.co - c
        v.co = c + Vector((d.x * s[0], d.y * s[1], d.z * s[2]))
    return bm


def copy(bm):
    return bm.copy()


# ------------------------------------------------------------------ assemblage
DIRS = {"top": Vector((0, 0, 1)), "bottom": Vector((0, 0, -1)), "front": Vector((0, -1, 0)),
        "back": Vector((0, 1, 0)), "left": Vector((-1, 0, 0)), "right": Vector((1, 0, 0))}


def _cell_for(face, spec):
    if isinstance(spec, str):
        return spec
    n = face.normal
    for key in ("top", "bottom", "front", "back", "left", "right"):
        if key in spec and n.dot(DIRS[key]) > 0.6:
            return spec[key]
    return spec.get("side", next(iter(spec.values())))


def _uv(bm, spec, pal):
    uv = bm.loops.layers.uv.verify()
    xs = [v.co.x for v in bm.verts]
    ys = [v.co.y for v in bm.verts]
    zs = [v.co.z for v in bm.verts]
    mn = Vector((min(xs), min(ys), min(zs)))
    size = Vector((max(xs), max(ys), max(zs))) - mn
    for f in bm.faces:
        name = _cell_for(f, spec)
        if name not in pal.cells:
            raise KeyError(f"case de palette inconnue : {name}")
        cx, cy = pal.cells[name]
        if name in pal.solid:
            u, v = (cx * CELL + CELL / 2) / SIZE, (cy * CELL + CELL / 2) / SIZE
            for l in f.loops:
                l[uv].uv = (u, v)
            continue
        n = f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        a, b = {0: (1, 2), 1: (0, 2), 2: (0, 1)}[ax]
        for l in f.loops:
            p = l.vert.co
            u = (p[a] - mn[a]) / (size[a] or 1)
            v = (p[b] - mn[b]) / (size[b] or 1)
            l[uv].uv = ((cx * CELL + PAD + u * (CELL - 2 * PAD)) / SIZE, (cy * CELL + PAD + v * (CELL - 2 * PAD)) / SIZE)


class Props:
    """Crée les décors dans une collection, alignés sur une grille pour les regarder."""

    def __init__(self, pal, collection="Props", spacing=14, columns=8):
        self.pal = pal
        self.mat = pal.material()
        self.col = bpy.data.collections.get(collection) or bpy.data.collections.new(collection)
        if self.col.name not in bpy.context.scene.collection.children:
            bpy.context.scene.collection.children.link(self.col)
        self.spacing, self.columns = spacing, columns
        self.count = 0
        self.report = []
        self.meta = {}

    def clear(self):
        for o in list(self.col.objects):
            me = o.data
            bpy.data.objects.remove(o, do_unlink=True)
            if me and me.users == 0:
                bpy.data.meshes.remove(me)

    def prop(self, name, parts, ground=True):
        """parts : liste de (bmesh, case ou dict). Fusionne, centre la base sur l'origine, range sur la grille."""
        total = bmesh.new()
        tmp = bpy.data.meshes.new("_tmp")
        for bm, spec in parts:
            bm.normal_update()
            _uv(bm, spec, self.pal)
            bm.to_mesh(tmp)
            total.from_mesh(tmp)
            bm.free()
        bpy.data.meshes.remove(tmp)
        xs = [v.co.x for v in total.verts]
        ys = [v.co.y for v in total.verts]
        zs = [v.co.z for v in total.verts]
        offset = Vector(((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, min(zs) if ground else 0))
        # Où était le décor dans son repère de conception : le générateur de carte en a besoin pour les pièces
        # d'un même bâtiment (murs, toit, façade) qui doivent se recaler ensemble
        self.meta[name] = {"center": [round(offset.x, 3), round(offset.y, 3)], "bottom": round(min(zs), 3),
                           "size": [round(max(xs) - min(xs), 3), round(max(ys) - min(ys), 3), round(max(zs) - min(zs), 3)]}
        for v in total.verts:
            v.co -= offset
        bmesh.ops.remove_doubles(total, verts=total.verts, dist=0.0005)
        me = bpy.data.meshes.get(name)
        if me:
            for o in list(bpy.data.objects):
                if o.data == me:
                    bpy.data.objects.remove(o, do_unlink=True)
            bpy.data.meshes.remove(me)
        me = bpy.data.meshes.new(name)
        total.to_mesh(me)
        total.free()
        for p in me.polygons:
            p.use_smooth = False
        me.materials.append(self.mat)
        obj = bpy.data.objects.new(name, me)
        self.col.objects.link(obj)
        i = self.count
        obj.location = ((i % self.columns) * self.spacing, -(i // self.columns) * self.spacing, 0)
        self.count += 1
        tris = sum(len(p.vertices) - 2 for p in me.polygons)
        dims = obj.dimensions
        self.report.append(f"{name}: {tris} tris, {dims.x:.1f} x {dims.y:.1f} x {dims.z:.1f}")
        return obj


def export_fbx(collection_names, path):
    """Exporte toutes les pièces des collections dans un FBX (un objet = un MeshPart), positions remises à 0."""
    objs = [o for n in collection_names for o in bpy.data.collections[n].objects if o.type == "MESH"]
    saved = {o: o.location.copy() for o in objs}
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    for o in objs:
        o.location = (0, 0, 0)
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(
        filepath=path, use_selection=True, object_types={"MESH"},
        axis_forward="-Z", axis_up="Y", apply_unit_scale=True, apply_scale_options="FBX_SCALE_ALL",
        mesh_smooth_type="FACE", path_mode="RELATIVE", embed_textures=False,
    )
    for o, loc in saved.items():
        o.location = loc
    return len(objs)

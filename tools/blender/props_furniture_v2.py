"""
Meubles du magasin refaits (D121), tribunes de stade de l'arène et décors des secrets.
Chargé par export_props.py APRÈS props_home.py et props_town.py : remplace furniture() et bleachers().
Mêmes identifiants (Furniture_<Id>), mêmes encombrements à peu près (les emplacements de la maison ne changent pas) :
le devant vers -Y, le dos contre le mur (+Y), le sol à z = 0.
Style (design/05_ART_SON.md) : low-poly, couleurs unies de la palette, mais des formes arrondies (chanfreins à
plusieurs segments, coussins bombés, pieds fuselés) et des détails qui racontent une blague de bro.
"""
import math
import bmesh
from mathutils import Vector


# ------------------------------------------------------------------ formes arrondies
def fv2_rbox(center, size, r=0.15, seg=2, taper=1.0, bulge=0.0):
    """Boîte aux arêtes arrondies (seg segments) ; taper rétrécit le dessus ; bulge bombe le dessus (coussins)."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    sx, sy, sz = size
    for v in bm.verts:
        t = taper if v.co.z > 0 else 1.0
        v.co = Vector((v.co.x * sx * t, v.co.y * sy * t, v.co.z * sz))
    r = min(r, min(size) * 0.48)
    if r > 0.005:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=r, segments=seg, profile=0.5, affect="EDGES",
                        clamp_overlap=True)
    if bulge:
        for v in bm.verts:
            if v.co.z > sz * 0.2:
                u = max(0.0, 1 - (2 * v.co.x / sx) ** 2) * max(0.0, 1 - (2 * v.co.y / sy) ** 2)
                v.co.z += bulge * u
    for v in bm.verts:
        v.co += Vector(center)
    return _finish(bm)


def fv2_pillow(center, size, bulge=None):
    """Coussin rebondi : boîte très arrondie, bombée dessus et dessous."""
    bm = fv2_rbox(center, size, r=min(size) * 0.45, seg=3)
    b = bulge if bulge is not None else size[2] * 0.25
    c = Vector(center)
    for v in bm.verts:
        d = v.co - c
        u = max(0.0, 1 - (2 * d.x / size[0]) ** 2) * max(0.0, 1 - (2 * d.y / size[1]) ** 2)
        v.co.z += math.copysign(b * u, d.z) if abs(d.z) > 1e-4 else 0
    return _finish(bm)


def fv2_leg(x, y, z0, height, r0, r1=None, sides=8):
    """Pied fuselé (plus fin en bas)."""
    return cylinder((x, y, z0), r1 if r1 is not None else r0 * 0.6, height, sides, radius_top=r0)


def fv2_tube(points, radius, sides=8, joints=True):
    """Tube qui suit une ligne brisée, avec une boule à chaque coude (cadres de chrome, néons)."""
    parts = []
    for a, b in zip(points, points[1:]):
        parts.append(segment(a, b, radius, sides))
    if joints:
        for p in points[1:-1]:
            parts.append(sphere(p, radius, sides, max(4, sides // 2)))
    return parts


def fv2_disc(center, radius, thick, sides=16, axis="Y"):
    """Pastille (plaque, cadran, poids d'haltère) centrée sur `center`."""
    c = Vector(center)
    off = {"X": Vector((thick / 2, 0, 0)), "Y": Vector((0, thick / 2, 0)), "Z": Vector((0, 0, thick / 2))}[axis]
    return cylinder(tuple(c - off), radius, thick, sides, axis=axis)


def fv2_plate(center, radius, thick, sides=16):
    """Disque de fonte (axe X) : bord arrondi et moyeu."""
    x, y, z = center
    return [
        (cylinder((x - thick / 2, y, z), radius, thick, sides, axis="X", bevel=thick * 0.25), "charcoal"),
        (cylinder((x - thick / 2 - 0.02, y, z), radius * 0.28, thick + 0.04, 10, axis="X"), "steel"),
    ]


def fv2_dumbbell(center, length, bar_r, plate_r, plate_t, color="gold", plates=2, bar="chrome"):
    """Haltère couché (axe X) : barre moletée, disques empilés, embouts."""
    x, y, z = center
    parts = [(cylinder((x - length / 2, y, z), bar_r, length, 10, axis="X"), bar)]
    for s in (-1, 1):
        for k in range(plates):
            px = x + s * (length / 2 - 0.25 - k * plate_t * 1.05 - plate_t / 2)
            r = plate_r * (1 - 0.18 * k)
            parts.append((cylinder((px - plate_t / 2, y, z), r, plate_t, 16, axis="X", bevel=plate_t * 0.2), color))
        parts.append((sphere((x + s * length / 2, y, z), bar_r * 1.4, 8, 5), bar))
    return parts


def fv2_frame(w, h, depth, border, z0=0.0, y=0.0, color="gold"):
    """Cadre de tableau (4 baguettes arrondies) posé contre le mur, centre en (0, y, z0 + h/2)."""
    zc = z0 + h / 2
    b = border
    return [
        (fv2_rbox((0, y, z0 + h - b / 2), (w, depth, b), r=b * 0.35), color),
        (fv2_rbox((0, y, z0 + b / 2), (w, depth, b), r=b * 0.35), color),
        (fv2_rbox((-w / 2 + b / 2, y, zc), (b, depth, h - 2 * b + 0.02), r=b * 0.35), color),
        (fv2_rbox((w / 2 - b / 2, y, zc), (b, depth, h - 2 * b + 0.02), r=b * 0.35), color),
    ]


def fv2_tuft_buttons(x0, x1, z0, z1, y, nx, nz, r=0.09, color="darkgold"):
    """Capitons : petits boutons en quinconce."""
    out = []
    for i in range(nz):
        for j in range(nx + (i % 2)):
            fx = (j + (0.5 if i % 2 == 0 else 0.0)) / nx
            if fx > 1.0:
                continue
            out.append((sphere((x0 + (x1 - x0) * fx, y, z0 + (z1 - z0) * (i + 0.5) / nz), (r, r * 0.6, r), 6, 4), color))
    return out


# ------------------------------------------------------------------ meubles du magasin
def fv2_sofa_base(width, depth, seat_h, back_h, fabric, arm_style="round", arm=None, legs="darkbrown", cushions=3,
              sag=0.0, piping=None):
    """Canapé : socle, assise en coussins bombés, dossier en coussins, accoudoirs ronds ou carrés, pieds fuselés.
    sag : creux au milieu (canapé avachi)."""
    arm = arm or fabric
    arm_w = 0.8
    inner = width - 2 * arm_w
    parts = [
        (fv2_rbox((0, 0.1, seat_h * 0.42), (width - 0.1, depth - 0.2, seat_h * 0.55), r=0.18), fabric),
        (fv2_rbox((0, depth / 2 - 0.4, seat_h + back_h * 0.42), (width - 0.1, 0.75, back_h * 0.95), r=0.3, seg=3), fabric),
    ]
    cw = inner / cushions
    for k in range(cushions):
        x = -inner / 2 + cw * (k + 0.5)
        u = 1 - abs(x) / (inner / 2 + 1e-6)
        dz = -sag * u
        parts.append((fv2_pillow((x, -0.22, seat_h * 0.82 + dz), (cw - 0.08, depth - 1.05, 0.55)), fabric))
        parts.append((fv2_pillow((x, depth / 2 - 0.95, seat_h + back_h * 0.5 + dz * 0.5), (cw - 0.12, 0.6, back_h * 0.78),
                             bulge=0.08), fabric))
    for s in (-1, 1):
        ax = s * (width / 2 - arm_w / 2)
        if arm_style == "round":
            parts.append((fv2_rbox((ax, 0.025, seat_h * 0.62), (arm_w, depth - 0.15, seat_h * 1.0), r=0.2), arm))
            parts.append((cylinder((ax, -depth / 2 + 0.05, seat_h * 1.08), 0.5, depth - 0.25, 12, axis="Y"), arm))
        else:
            parts.append((fv2_rbox((ax, 0.025, seat_h * 0.82), (arm_w, depth - 0.15, seat_h * 1.3), r=0.22, seg=3), arm))
        if piping:
            parts.append((torus((ax, -depth / 2 + 0.02, seat_h * 1.08), 0.42, 0.06, 14, 4, axis="Y"), piping))
        for y in (-depth / 2 + 0.35, depth / 2 - 0.35):
            parts.append((fv2_leg(ax, y, 0, 0.32, 0.15, 0.09), legs))
    return parts


def fv2_saggy_couch():
    # Le premier canapé : avachi, rapiécé, un ressort qui sort, la boîte à pizza oubliée et une chaussette
    parts = fv2_sofa_base(7.0, 3.0, 1.35, 1.9, "fabric", arm_style="round", legs="darkbrown", cushions=3, sag=0.35)
    parts.append((fv2_rbox((1.9, -0.3, 1.5), (0.9, 0.9, 0.06), r=0.05), "rust"))                        # pièce rapiécée
    for k in range(4):
        parts.append((segment((1.6 + 0.15 * k, -0.6, 1.53), (1.6 + 0.15 * k, 0.0, 1.53), 0.025, 4), "darkbrown"))
    coil = [(-0.6 + 0.12 * math.cos(a * 1.3), -0.4 + 0.12 * math.sin(a * 1.3), 1.45 + 0.05 * a) for a in range(9)]
    parts += [(p[0], "steel") for p in [(segment(a, b, 0.03, 4),) for a, b in zip(coil, coil[1:])]]
    pizza = fv2_rbox((-2.0, -0.4, 1.78), (1.7, 1.7, 0.18), r=0.04)
    rotate(pizza, 12, "Z", (-2.0, -0.4, 1.78))
    parts.append((pizza, "cardboardtex"))
    parts.append((fv2_rbox((-2.0, -0.4, 1.88), (0.5, 0.06, 0.03)), "pepperoni"))
    sock = segment((2.6, 0.9, 2.95), (2.9, 1.0, 3.4), 0.13, 6)
    parts.append((sock, "white"))
    parts.append((sphere((2.95, 1.0, 3.45), (0.16, 0.13, 0.12), 6, 4), "white"))
    return parts


def fv2_bench_sofa():
    # Banc de muscu devenu canapé : simili cuir noir capitonné, châssis en tubes chromés, une barre chargée en dossier
    parts = [
        (fv2_pillow((0, -0.2, 1.65), (6.6, 2.4, 0.6), bulge=0.1), "black"),
        (fv2_rbox((0, -0.2, 1.3), (6.4, 2.2, 0.18), r=0.06), "charcoal"),
        (fv2_pillow((0, 0.95, 2.85), (6.6, 0.55, 1.6), bulge=0.06), "black"),
    ]
    for x in (-2.2, 0, 2.2):
        parts.append((fv2_rbox((x, -0.2, 1.97), (0.06, 2.2, 0.04), r=0.01), "charcoal"))           # coutures
    for s in (-1, 1):
        x = s * 2.9
        parts += [(p, "chrome") for p in fv2_tube([(x, -1.2, 0.05), (x, -1.2, 1.25), (x, 1.0, 1.25), (x, 1.0, 0.05)], 0.12)]
        parts.append((fv2_rbox((x, -0.1, 0.06), (0.5, 2.6, 0.12), r=0.05), "charcoal"))
        parts.append((segment((x, 1.15, 1.2), (x, 1.15, 4.1), 0.11, 8), "chrome"))              # montants du rack
        parts.append((fv2_rbox((x, 0.95, 4.0), (0.3, 0.5, 0.12), r=0.04), "steel"))                 # crochets
    parts.append((cylinder((-3.9, 0.85, 4.25), 0.1, 7.8, 10, axis="X"), "chrome"))              # barre
    for s in (-1, 1):
        for k in range(2):
            parts += fv2_plate((s * (3.25 + k * 0.38), 0.85, 4.25), 1.3 - 0.3 * k, 0.3)
        parts.append((cylinder((s * 3.7 - 0.15, 0.85, 4.25), 0.16, 0.3, 8, axis="X"), "steel"))  # colliers
    return parts


def fv2_leopard_sofa():
    # Canapé de diva : léopard, accoudoirs roulés, passepoil noir, pieds dorés, coussin en cœur
    parts = fv2_sofa_base(7.4, 3.1, 1.45, 2.0, "leopard", arm_style="round", arm="leopard", legs="gold", cushions=3,
                      piping="black")
    parts.append((cylinder((-3.45, 1.15, 3.28), 0.13, 6.9, 10, axis="X"), "black"))                    # passepoil du dos
    heart = []
    for k in range(18):
        t = 2 * math.pi * k / 18
        heart.append((0.045 * 16 * math.sin(t) ** 3, 0.045 * (13 * math.cos(t) - 5 * math.cos(2 * t)
                                                              - 2 * math.cos(3 * t) - math.cos(4 * t)) + 2.3))
    h = extrude(heart, 0.35, y0=0.25)
    parts.append((h, "hotpink"))
    return parts


def fv2_throne_sofa():
    # Trône du roi du salon : socle à marches, dossier en ogive capitonné de velours, accoudoirs à boules, couronne
    parts = [
        (fv2_rbox((0, 0.1, 0.25), (6.0, 3.8, 0.5), r=0.12), "darkgold"),
        (fv2_rbox((0, 0.15, 0.62), (5.4, 3.4, 0.3), r=0.1), "gold"),
        (fv2_rbox((0, 0.0, 1.15), (4.8, 3.0, 0.8), r=0.18), "gold"),
        (fv2_pillow((0, -0.2, 1.75), (3.6, 2.5, 0.55)), "fabricred"),
    ]
    # Dossier en ogive : profil extrudé
    prof = [(-2.4, 1.4)]
    for k in range(13):
        a = math.pi * k / 12
        prof.append((-2.4 * math.cos(a), 5.4 + 1.5 * math.sin(a) ** 1.4))
    prof.append((2.4, 1.4))
    back = extrude(prof, 0.7, y0=0.95)
    parts.append((back, "gold"))
    inner = [(x * 0.82, 1.6 + (z - 1.4) * 0.86) for x, z in prof]
    parts.append((extrude(inner, 0.12, y0=0.86), "fabricred"))
    parts += fv2_tuft_buttons(-1.6, 1.6, 2.2, 5.6, 0.83, 4, 4, r=0.1, color="gold")
    for s in (-1, 1):
        parts.append((fv2_rbox((s * 2.25, -0.1, 2.2), (0.55, 2.8, 0.45), r=0.16), "gold"))
        parts.append((fv2_rbox((s * 2.25, -0.1, 1.75), (0.45, 2.6, 0.5), r=0.1), "darkgold"))
        parts.append((sphere((s * 2.25, -1.55, 2.3), 0.42, 10, 6), "gold"))
        parts.append((sphere((s * 2.25, -1.6, 2.3), (0.2, 0.2, 0.2), 6, 4), "red"))
        parts.append((sphere((s * 2.0, 1.3, 6.6), 0.3, 8, 5), "gold"))
    # Couronne au sommet
    parts.append((cylinder((0, 1.3, 6.7), 0.75, 0.35, 12), "gold"))
    for k in range(5):
        a = 2 * math.pi * k / 5
        parts.append((cone((0.55 * math.cos(a), 1.3 + 0.55 * math.sin(a), 7.0), 0.2, 0.55, 6), "gold"))
        parts.append((sphere((0.55 * math.cos(a), 1.3 + 0.55 * math.sin(a), 7.6), 0.09, 6, 4), "red"))
    parts.append((sphere((0, 0.6, 6.85), 0.18, 6, 4), "blue"))
    return parts


def fv2_tube_tv():
    # Vieille télé cathodique sur meuble vintage : écran bombé, molettes, antennes « oreilles de lapin », VHS
    parts = [
        (fv2_rbox((0, 0.2, 1.15), (4.2, 1.9, 0.9), r=0.12), "wood"),
        (fv2_rbox((0, -0.72, 1.15), (3.6, 0.08, 0.55), r=0.03), "wooddark"),
        (fv2_rbox((-0.9, -0.78, 1.15), (0.5, 0.06, 0.08), r=0.02), "darkgold"),
        (fv2_rbox((0.9, -0.78, 1.15), (0.5, 0.06, 0.08), r=0.02), "darkgold"),
    ]
    for x in (-1.8, 1.8):
        for y in (-0.5, 0.9):
            parts.append((segment((x, y, 0.72), (x * 1.08, y + (0.12 if y > 0 else -0.12), 0.0), 0.09, 6, 0.05),
                          "wooddark"))
    parts.append((fv2_rbox((0, 0.35, 3.05), (3.6, 2.7, 2.9), r=0.45, seg=3), "darkgrey"))
    parts.append((fv2_rbox((0, 1.45, 3.0), (2.6, 1.0, 2.2), r=0.4, seg=2, taper=0.8), "darkgrey"))
    scr = fv2_rbox((-0.45, -1.0, 3.1), (2.5, 0.3, 2.05), r=0.35, seg=3, bulge=0.0)
    for v in scr.verts:
        if v.co.y < -1.0:
            v.co.y -= 0.12 * max(0, 1 - ((v.co.x + 0.45) / 1.3) ** 2) * max(0, 1 - ((v.co.z - 3.1) / 1.05) ** 2)
    parts.append((scr, "screentex"))
    for z in (3.75, 3.15):
        parts.append((cylinder((1.35, -0.95, z), 0.22, 0.2, 10, axis="Y"), "steel"))
    for k in range(4):
        parts.append((fv2_rbox((1.35, -1.0, 2.35 + k * 0.12), (0.5, 0.05, 0.05), r=0.01), "charcoal"))
    for s in (-1, 1):
        parts.append((segment((s * 0.25, 0.7, 4.45), (s * 1.3, 1.0, 6.1), 0.04, 5), "steel"))
        parts.append((sphere((s * 1.3, 1.0, 6.1), 0.1, 6, 4), "steel"))
    parts.append((sphere((0, 0.7, 4.5), (0.35, 0.3, 0.15), 8, 4), "charcoal"))
    parts.append((fv2_rbox((-1.2, 0.4, 4.58), (1.3, 0.75, 0.22), r=0.03), "black"))                   # cassette VHS
    parts.append((fv2_rbox((-1.2, 0.02, 4.58), (1.0, 0.03, 0.12), r=0.01), "white"))
    return parts


def fv2_giant_screen():
    # Écran géant de gamer : meuble bas avec bande LED, écran ultra-large sur pied, tours d'enceintes, console
    parts = [
        (fv2_rbox((0, 0.25, 0.75), (6.8, 1.9, 1.3), r=0.15), "charcoal"),
        (fv2_rbox((0, -0.72, 0.75), (6.4, 0.06, 0.9), r=0.03), "black"),
        (fv2_rbox((0, -0.74, 0.12), (6.6, 0.04, 0.08), r=0.01), "neonblue"),
        (fv2_rbox((-1.8, -0.76, 0.75), (0.06, 0.04, 0.8)), "darkgrey"),
        (fv2_rbox((1.8, -0.76, 0.75), (0.06, 0.04, 0.8)), "darkgrey"),
        (fv2_rbox((0, 0.55, 1.65), (2.2, 0.8, 0.12), r=0.05), "darkgrey"),                            # pied
        (fv2_rbox((0, 0.65, 2.0), (0.5, 0.25, 0.7), r=0.08), "darkgrey"),
        (fv2_rbox((0, 0.55, 4.3), (6.6, 0.32, 3.9), r=0.12), "black"),
        (fv2_rbox((0, 0.37, 4.3), (6.3, 0.06, 3.6), r=0.03), "screentex"),
        (fv2_rbox((0, 0.4, 2.12), (2.8, 0.25, 0.2), r=0.08), "darkgrey"),                              # barre de son
        (fv2_rbox((2.6, 0.2, 1.55), (1.3, 1.0, 0.32), r=0.1), "white"),                                 # console
        (fv2_rbox((2.6, -0.31, 1.55), (1.0, 0.04, 0.04)), "neonblue"),
    ]
    for s in (-1, 1):
        x = s * 3.85
        parts.append((fv2_rbox((x, -0.3, 2.6), (0.8, 1.0, 5.0), r=0.15), "charcoal"))
        for z, rr in ((4.4, 0.3), (3.3, 0.24), (1.6, 0.34)):
            parts.append((cylinder((x, -0.83, z), rr, 0.08, 12, axis="Y"), "steel"))
            parts.append((sphere((x, -0.9, z), (rr * 0.35, 0.08, rr * 0.35), 6, 4), "darkgrey"))
    return parts


def fv2_mattress():
    # Le matelas par terre sur deux palettes, couette froissée, oreiller, réveil, part de pizza
    parts = []
    for k, y in enumerate((-1.75, 1.75)):
        for i in range(5):
            parts.append((fv2_rbox((-2.0 + i * 1.0, y, 0.42), (0.75, 3.3, 0.12), r=0.03), "woodlight"))
        for x in (-2.2, 0, 2.2):
            parts.append((fv2_rbox((x, y, 0.2), (0.4, 3.3, 0.32), r=0.03), "wood"))
    parts.append((fv2_rbox((0, 0, 0.95), (5.0, 6.9, 0.8), r=0.3, seg=3), "offwhite"))
    parts.append((fv2_rbox((0, 0, 0.95), (5.04, 6.94, 0.08), r=0.03), "pastelblue"))                    # passepoil
    duvet = fv2_rbox((0.15, -1.0, 1.42), (4.8, 4.4, 0.3), r=0.14, seg=2)
    bmesh.ops.subdivide_edges(duvet, edges=[e for e in duvet.edges if abs(e.verts[0].co.z - e.verts[1].co.z) < 1e-4
                                            and e.verts[0].co.z > 1.4], cuts=3, use_grid_fill=True)
    for v in duvet.verts:
        if v.co.z > 1.4:
            v.co.z += 0.12 * math.sin(v.co.x * 2.1) * math.cos(v.co.y * 1.7)
    parts.append((_finish(duvet), "fabricblue"))
    parts.append((fv2_pillow((0, 2.65, 1.55), (3.2, 1.25, 0.5)), "white"))
    parts.append((fv2_rbox((2.9, 3.0, 0.3), (0.6, 0.45, 0.6), r=0.12), "red"))                          # réveil
    parts.append((cylinder((2.9, 2.75, 0.35), 0.2, 0.04, 10, axis="Y"), "white"))
    for s in (-1, 1):
        parts.append((sphere((2.9 + s * 0.22, 3.0, 0.68), 0.12, 6, 4), "steel"))
    slice_ = extrude([(0, 0), (0.9, 0.35), (0.9, -0.35)], 0.1, y0=0)
    rotate(slice_, 90, "X")
    move(slice_, (-2.1, -2.9, 1.42))
    parts.append((slice_, "pizza"))
    parts.append((cylinder((-1.55, -2.9, 1.43), 0.11, 0.03, 8), "pepperoni"))
    return parts


def fv2_race_car_bed():
    # Lit voiture de course : carrosserie galbée, ailerons, phares, jantes, bandes, matelas à damier
    prof = [(-3.9, 0.35), (4.2, 0.35), (4.4, 1.0), (4.3, 1.75), (3.7, 2.15), (2.4, 2.35), (-1.8, 2.35), (-2.4, 3.05),
            (-3.0, 3.35), (-3.8, 3.4), (-4.0, 2.8), (-4.0, 1.0)]
    body = extrude(prof, 5.4, y0=-2.7)
    rotate(body, -90, "Z")
    parts = [(body, "red")]
    for x in (-0.9, 0.9):
        top = [(3.7, 2.15), (2.4, 2.35), (-1.8, 2.35), (-2.4, 3.05), (-3.0, 3.35), (-3.8, 3.4)]
        band = [(px, pz + 0.04) for px, pz in top] + [(px, pz - 0.06) for px, pz in reversed(top)]
        stripe = extrude(band, 0.45, y0=x - 0.225)
        rotate(stripe, -90, "Z")
        parts.append((stripe, "white"))
    parts.append((fv2_rbox((0, 0.2, 2.5), (4.3, 5.9, 0.4), r=0.15), "checker"))
    parts.append((fv2_pillow((0, 2.65, 2.85), (3.0, 1.0, 0.45)), "white"))
    for x in (-2.75, 2.75):
        for y in (-2.6, 2.4):
            parts.append((cylinder((x - (0.35 if x < 0 else 0), y, 1.0), 1.0, 0.35, 16, axis="X", bevel=0.08), "rubber"))
            parts.append((cylinder((x - (0.37 if x < 0 else -0.3), y, 1.0), 0.55, 0.06, 12, axis="X"), "chrome"))
            parts.append((cylinder((x - (0.38 if x < 0 else -0.33), y, 1.0), 0.18, 0.05, 8, axis="X"), "darkgrey"))
    parts.append((fv2_rbox((0, 4.25, 3.75), (5.4, 0.9, 0.18), r=0.06), "black"))                       # aileron
    for x in (-2.1, 2.1):
        parts.append((fv2_rbox((x, 4.15, 3.1), (0.18, 0.5, 1.2), r=0.05), "black"))
    for x in (-1.5, 1.5):
        parts.append((fv2_rbox((x, -4.33, 1.45), (0.95, 0.2, 0.45), r=0.1), "lampwarm"))
    parts.append((cylinder((0, -1.0, 2.25), 0.75, 0.03, 16), "white"))                              # rond du numéro
    parts.append((fv2_rbox((0, -4.34, 0.75), (2.6, 0.14, 0.5), r=0.05), "black"))                         # calandre
    return parts


def fv2_pizza_rug():
    # Tapis pizza : croûte dorée, fromage qui coule, pepperoni, une part déjà mangée
    parts = []
    gap0, gap1 = math.radians(-20), math.radians(25)
    pts = [(0.0, 0.0)]
    for k in range(29):
        a = gap1 + (2 * math.pi - (gap1 - gap0)) * k / 28
        pts.append((3.3 * math.cos(a), 3.3 * math.sin(a)))
    cheese = extrude(pts, 0.12, y0=0)
    rotate(cheese, 90, "X")
    parts.append((cheese, "cheese"))
    for k in range(28):
        a0 = gap1 + (2 * math.pi - (gap1 - gap0)) * k / 28
        a1 = gap1 + (2 * math.pi - (gap1 - gap0)) * (k + 1) / 28
        p0 = (3.45 * math.cos(a0), 3.45 * math.sin(a0), 0.24)
        p1 = (3.45 * math.cos(a1), 3.45 * math.sin(a1), 0.24)
        parts.append((segment(p0, p1, 0.24, 6), "pizza"))
    for r, a in ((1.4, 60), (2.3, 120), (1.0, 200), (2.4, 250), (2.0, 320), (0.4, 90), (2.6, 170), (1.6, 285)):
        x, y = r * math.cos(math.radians(a)), r * math.sin(math.radians(a))
        parts.append((cylinder((x, y, 0.1), 0.42, 0.08, 12), "pepperoni"))
    for a in (40, 150, 230):
        x, y = 3.2 * math.cos(math.radians(a)), 3.2 * math.sin(math.radians(a))
        parts.append((sphere((x * 1.08, y * 1.08, 0.05), (0.35, 0.35, 0.06), 8, 3), "cheese"))
    return parts


def fv2_zebra_rug():
    # Peau de zèbre (fausse !) : contour doux à quatre pattes, un peu d'épaisseur
    outline = []
    for k in range(40):
        t = 2 * math.pi * k / 40
        r = 1.0 + 0.22 * math.cos(4 * t) ** 3 + 0.05 * math.sin(7 * t)
        outline.append((5.0 * r * math.cos(t), 3.3 * r * math.sin(t)))
    bm = extrude(outline, 0.1, axis="Y")
    rotate(bm, 90, "X")
    return [(bm, "zebra")]


def fv2_gold_rug():
    # Tapis persan de palace : bordures emboîtées, médaillon central, losanges, franges
    parts = [
        (fv2_rbox((0, 0, 0.05), (11.0, 8.0, 0.1), r=0.04), "fabricred"),
        (fv2_rbox((0, 0, 0.11), (10.0, 7.0, 0.03), r=0.02), "gold"),
        (fv2_rbox((0, 0, 0.13), (9.4, 6.4, 0.03), r=0.02), "navy"),
        (fv2_rbox((0, 0, 0.15), (8.8, 5.8, 0.03), r=0.02), "fabricred"),
    ]
    diamond = extrude([(0, -1.6), (2.6, 0), (0, 1.6), (-2.6, 0)], 0.04, y0=0)
    rotate(diamond, 90, "X")
    move(diamond, (0, 0, 0.17))
    parts.append((diamond, "gold"))
    small = extrude([(0, -0.9), (1.5, 0), (0, 0.9), (-1.5, 0)], 0.04, y0=0)
    rotate(small, 90, "X")
    move(small, (0, 0, 0.21))
    parts.append((small, "navy"))
    parts.append((cylinder((0, 0, 0.21), 0.5, 0.06, 12), "gold"))
    for sx in (-1, 1):
        for sy in (-1, 1):
            c = extrude([(0, -0.5), (0.8, 0), (0, 0.5), (-0.8, 0)], 0.04, y0=0)
            rotate(c, 90, "X")
            move(c, (sx * 3.6, sy * 2.2, 0.17))
            parts.append((c, "gold"))
    for x in (-5.5, 5.5):
        for k in range(12):
            y = -3.6 + k * 0.65
            parts.append((segment((x, y, 0.04), (x + (0.6 if x > 0 else -0.6), y, 0.02), 0.06, 4), "cream"))
    return parts


def fv2_flex_poster():
    # Affiche de motivation : cadre, fond en rayons de soleil, gros bras qui fléchit, étoiles
    parts = fv2_frame(4.0, 5.0, 0.2, 0.25, y=0.0, color="black")
    parts.append((fv2_rbox((0, 0.02, 2.5), (3.6, 0.06, 4.6), r=0.01), "yellow"))
    for k in range(10):
        a = math.radians(k * 36)
        ray = extrude([(0, 0), (2.4 * math.cos(a - 0.15), 2.4 * math.sin(a - 0.15)),
                       (2.4 * math.cos(a + 0.15), 2.4 * math.sin(a + 0.15))], 0.02, y0=-0.04)
        move(ray, (0, 0, 2.6))
        bmv = [v for v in ray.verts]
        for v in bmv:
            v.co.x = max(-1.75, min(1.75, v.co.x))
            v.co.z = max(0.3, min(4.7, v.co.z))
        parts.append((ray, "orange"))
    arm = [(-1.3, 0.7), (-0.5, 0.7), (-0.35, 1.6), (0.15, 2.1), (0.75, 2.2), (0.95, 2.9), (1.25, 3.6), (0.85, 4.0),
           (0.45, 3.5), (0.35, 2.95), (-0.1, 3.05), (-0.6, 3.15), (-1.05, 2.8), (-1.25, 1.9)]
    parts.append((extrude(arm, 0.08, y0=-0.12), "orangeskin"))
    parts.append((sphere((-0.15, -0.14, 2.75), (0.65, 0.08, 0.5), 10, 3), "orangeskin"))         # biceps
    parts.append((sphere((1.0, -0.14, 3.85), (0.38, 0.06, 0.32), 8, 3), "orangeskin"))           # poing
    for x, z in ((-1.3, 4.3), (1.4, 0.9), (-1.35, 0.7)):
        star = []
        for k in range(10):
            a = math.pi / 2 + k * math.pi / 5
            r = 0.3 if k % 2 == 0 else 0.13
            star.append((x + r * math.cos(a), z + r * math.sin(a)))
        parts.append((extrude(star, 0.04, y0=-0.1), "white"))
    return parts


def fv2_sunset_poster():
    # Coucher de soleil rétro : soleil à bandes, montagnes, palmier, grille au sol, cadre néon
    parts = fv2_frame(6.0, 4.0, 0.2, 0.22, y=0.0, color="charcoal")
    parts.append((fv2_rbox((0, 0.02, 2.0), (5.6, 0.06, 3.6), r=0.01), "sunset"))
    sun_pts = []
    for k in range(17):
        a = math.pi * k / 16
        sun_pts.append((1.1 * math.cos(a), 2.0 + 1.1 * math.sin(a)))
    parts.append((extrude(sun_pts, 0.04, y0=-0.04), "yellow"))
    for k in range(3):
        parts.append((fv2_rbox((0, -0.07, 2.15 + k * 0.28), (2.3, 0.02, 0.08)), "orange"))
    parts.append((extrude([(-2.8, 0.2), (-1.6, 1.9), (-0.8, 1.2), (0.2, 2.1), (1.4, 1.0), (2.8, 1.6), (2.8, 0.2)],
                          0.04, y0=-0.08), "purple"))
    parts.append((fv2_rbox((0, -0.1, 0.55), (5.6, 0.02, 0.7)), "navy"))
    for k in range(7):
        x = -2.4 + k * 0.8
        parts.append((segment((x, -0.12, 0.85), (x * 1.15, -0.12, 0.25), 0.025, 4), "neonpink"))
    for z in (0.4, 0.6, 0.8):
        parts.append((fv2_rbox((0, -0.12, z), (5.4, 0.02, 0.04)), "neonpink"))
    parts.append((segment((-1.9, -0.13, 0.4), (-1.75, -0.13, 2.4), 0.07, 5), "black"))             # palmier
    for k in range(6):
        a = math.radians(-10 + k * 40)
        tip = (-1.75 + 0.95 * math.cos(a), -0.14, 2.4 + 0.35 * math.sin(a) - 0.25 * abs(math.cos(a)))
        mid = (-1.75 + 0.5 * math.cos(a), -0.14, 2.4 + 0.3 * math.sin(a) + 0.05)
        parts.append((segment((-1.75, -0.14, 2.4), mid, 0.11, 4, 0.09), "black"))
        parts.append((segment(mid, tip, 0.09, 4, 0.02), "black"))
    return parts


def fv2_neon_dumbbell():
    # Enseigne néon : panneau sombre aux coins ronds, entretoises, haltère en tubes néon et halo
    parts = [(fv2_rbox((0, 0.1, 1.6), (6.0, 0.15, 3.2), r=0.35, seg=3), "charcoal")]
    for x in (-2.6, 2.6):
        for z in (0.4, 2.8):
            parts.append((cylinder((x, -0.05, z), 0.12, 0.1, 8, axis="Y"), "chrome"))
    neon = fv2_tube([(-1.5, -0.12, 1.6), (1.5, -0.12, 1.6)], 0.11, 8)
    parts += [(p, "neonpink") for p in neon]
    for s in (-1, 1):
        for k, (dx, h) in enumerate(((1.65, 1.9), (2.15, 1.4))):
            x = s * dx
            loop = [(x - 0.18, -0.12, 1.6 - h / 2), (x - 0.18, -0.12, 1.6 + h / 2), (x + 0.18, -0.12, 1.6 + h / 2),
                    (x + 0.18, -0.12, 1.6 - h / 2), (x - 0.18, -0.12, 1.6 - h / 2)]
            parts += [(p, "neonblue") for p in fv2_tube(loop, 0.09, 8)]
    parts.append((fv2_rbox((0, -0.02, 1.6), (5.2, 0.04, 2.5), r=0.3, seg=2), "navy"))                    # halo
    for k in range(3):
        parts.append((sphere((-2.2 + k * 0.25, -0.12, 0.45), 0.07, 6, 4), "neongreen"))
    return parts


def fv2_cactus():
    # Cactus « prickly gains » : pot en terre cuite peint, bras arrondis, fleur rose, cailloux
    parts = [
        (cylinder((0, 0, 0), 0.75, 1.3, 14, radius_top=0.95, bevel=0.06), "rust"),
        (torus((0, 0, 1.32), 0.98, 0.14, 14, 6), "rust"),
        (torus((0, 0, 0.6), 0.86, 0.05, 14, 4), "cream"),
        (cylinder((0, 0, 1.25), 0.88, 0.08, 14), "dirt"),
    ]
    for k in range(4):
        a = 2 * math.pi * k / 4 + 0.4
        parts.append((sphere((0.6 * math.cos(a), 0.6 * math.sin(a), 1.36), 0.12, 6, 4), "lightgrey"))
    parts.append((cylinder((0, 0, 1.3), 0.45, 2.8, 12, radius_top=0.42), "green"))
    parts.append((sphere((0, 0, 4.1), (0.42, 0.42, 0.4), 12, 6), "green"))
    for s, (h0, out, up) in ((1, (2.2, 0.75, 0.9)), (-1, (2.8, 0.65, 0.75))):
        x0 = s * 0.4
        parts.append((segment((x0, 0, h0), (s * out, 0, h0), 0.24, 10), "green"))
        parts.append((sphere((s * out, 0, h0), 0.24, 10, 6), "green"))
        parts.append((segment((s * out, 0, h0), (s * out, 0, h0 + up), 0.24, 10, 0.22), "green"))
        parts.append((sphere((s * out, 0, h0 + up), 0.22, 10, 6), "green"))
    for k in range(5):                                                                              # côtes claires
        a = 2 * math.pi * k / 5
        parts.append((segment((0.42 * math.cos(a), 0.42 * math.sin(a), 1.45), (0.4 * math.cos(a), 0.4 * math.sin(a), 4.0),
                              0.04, 4), "leaflight"))
    for k in range(5):
        a = 2 * math.pi * k / 5
        parts.append((sphere((0.16 * math.cos(a), -0.05 + 0.16 * math.sin(a), 4.5), (0.14, 0.14, 0.07), 6, 3), "pink"))
    parts.append((sphere((0, -0.05, 4.52), 0.08, 6, 4), "yellow"))
    return parts


def fv2_shaker_plant():
    # Plante qui pousse dans un shaker de protéine géant : bouteille graduée, couvercle à bec, feuilles larges
    parts = [
        (cylinder((0, 0, 0), 0.95, 3.2, 16, radius_top=1.02, bevel=0.06), "hotpink"),
        (cylinder((0, 0, 3.2), 1.08, 0.5, 16, bevel=0.05), "charcoal"),
        (cylinder((0.45, 0.3, 3.7), 0.18, 0.3, 8), "charcoal"),
        (cylinder((0, 0, 3.7), 0.95, 0.1, 16), "dirt"),
    ]
    for k in range(5):
        parts.append((fv2_rbox((0, -0.98, 0.6 + k * 0.5), (0.5 if k % 2 else 0.8, 0.06, 0.06), r=0.02), "white"))
    parts.append((fv2_rbox((0, -0.99, 2.9), (1.0, 0.04, 0.35), r=0.05), "white"))
    for k in range(7):
        a = 2 * math.pi * k / 7
        tilt = 0.55 + 0.1 * (k % 3)
        base = Vector((0.2 * math.cos(a), 0.2 * math.sin(a), 3.8))
        tip = base + Vector((math.cos(a) * 1.6 * tilt, math.sin(a) * 1.6 * tilt, 1.6 + 0.4 * (k % 2)))
        mid = (base + tip) / 2
        leaf = sphere(tuple(mid), (0.55, 0.2, 1.05), 8, 5)
        d = (tip - base).normalized()
        rot = d.to_track_quat("Z", "Y").to_matrix()
        for v in leaf.verts:
            v.co = mid + rot @ (v.co - mid)
        parts.append((leaf, "leaf" if k % 2 else "leaflight"))
        parts.append((segment(tuple(base), tuple(mid), 0.05, 4), "darkgreen"))
    return parts


def fv2_lava_lamp():
    # Lampe à lave : base en cône chromé, verre en fuseau, bulles de lave, chapeau
    parts = [
        (cylinder((0, 0, 0), 0.8, 1.2, 14, radius_top=0.45, bevel=0.04), "silver"),
        (torus((0, 0, 1.2), 0.47, 0.05, 14, 4), "chrome"),
    ]
    glass = bmesh.new()
    rings = []
    for k in range(7):
        t = k / 6
        z = 1.2 + 2.7 * t
        r = 0.45 + 0.28 * math.sin(math.pi * t * 0.85) - 0.1 * t
        rings.append([glass.verts.new((r * math.cos(2 * math.pi * i / 14), r * math.sin(2 * math.pi * i / 14), z))
                      for i in range(14)])
    for a, b in zip(rings, rings[1:]):
        for i in range(14):
            j = (i + 1) % 14
            glass.faces.new((a[i], a[j], b[j], b[i]))
    glass.faces.new(list(reversed(rings[0])))
    glass.faces.new(rings[-1])
    parts.append((_finish(glass), "neonpink"))
    # Bulles de lave en relief sur le verre (le verre est opaque dans Roblox : on les voit de tous les côtés)
    for k, (t, a, rr) in enumerate(((0.12, -90, 0.3), (0.42, -50, 0.22), (0.68, -120, 0.18), (0.3, 60, 0.26),
                                    (0.55, 170, 0.2), (0.2, 200, 0.24), (0.8, 20, 0.15))):
        z = 1.2 + 2.7 * t
        r = 0.45 + 0.28 * math.sin(math.pi * t * 0.85) - 0.1 * t
        ang = math.radians(a)
        parts.append((sphere((r * 0.93 * math.cos(ang), r * 0.93 * math.sin(ang), z), (rr, rr, rr * 1.3), 8, 5),
                      "orange"))
    parts.append((cylinder((0, 0, 3.85), 0.42, 0.75, 14, radius_top=0.18, bevel=0.03), "silver"))
    parts.append((sphere((0, 0, 4.62), 0.12, 8, 4), "chrome"))
    return parts


def fv2_dumbbell_lamp():
    # Lampadaire : un haltère sert de lest, mât chromé, abat-jour plissé, ampoule
    parts = [(fv2_rbox((0, 0, 0.12), (2.6, 1.2, 0.24), r=0.1), "charcoal")]
    parts += fv2_dumbbell((0, 0, 0.75), 2.4, 0.14, 0.6, 0.28, color="charcoal", plates=2, bar="chrome")
    parts.append((cylinder((0, 0, 0.75), 0.14, 5.0, 10), "chrome"))
    parts.append((torus((0, 0, 3.2), 0.18, 0.05, 10, 4), "steel"))
    shade = bmesh.new()
    n = 24
    lo, hi = [], []
    for i in range(n):
        a = 2 * math.pi * i / n
        rr = 1.45 + (0.06 if i % 2 else 0)
        lo.append(shade.verts.new((rr * math.cos(a), rr * math.sin(a), 5.2)))
        r2 = 0.85 + (0.04 if i % 2 else 0)
        hi.append(shade.verts.new((r2 * math.cos(a), r2 * math.sin(a), 6.6)))
    for i in range(n):
        j = (i + 1) % n
        shade.faces.new((lo[i], lo[j], hi[j], hi[i]))
    inner_lo = [shade.verts.new((v.co.x * 0.94, v.co.y * 0.94, 5.2)) for v in lo]
    inner_hi = [shade.verts.new((v.co.x * 0.92, v.co.y * 0.92, 6.6)) for v in hi]
    for i in range(n):
        j = (i + 1) % n
        shade.faces.new((inner_hi[i], inner_hi[j], inner_lo[j], inner_lo[i]))
        shade.faces.new((lo[i], inner_lo[i], inner_lo[j], lo[j]))
        shade.faces.new((hi[j], inner_hi[j], inner_hi[i], hi[i]))
    parts.append((_finish(shade), "cream"))
    parts.append((sphere((0, 0, 5.75), 0.38, 10, 6), "lampwarm"))
    parts.append((torus((0, 0, 5.2), 1.48, 0.05, 24, 4), "darkgold"))
    return parts


def fv2_pedestal(top_color="woodlight", body="wood"):
    """Socle de musée : plinthe, fût, corniche, plaque dorée vierge."""
    return [
        (fv2_rbox((0, 0.4, 0.2), (3.0, 2.0, 0.4), r=0.1), "wooddark"),
        (fv2_rbox((0, 0.4, 1.4), (2.5, 1.6, 2.1), r=0.12), body),
        (fv2_rbox((0, 0.4, 2.55), (3.0, 2.0, 0.25), r=0.1), top_color),
        (fv2_rbox((0, -0.42, 1.6), (1.2, 0.06, 0.45), r=0.04), "gold"),
    ]


def fv2_bronze_cup():
    # Coupe de bronze sur socle de musée : pied, tige, coupe évasée, anses, ruban rouge
    parts = fv2_pedestal()
    parts += [
        (cylinder((0, 0.4, 2.67), 0.75, 0.25, 14, radius_top=0.55, bevel=0.04), "bronze"),
        (cylinder((0, 0.4, 2.92), 0.16, 0.65, 10, radius_top=0.22), "bronze"),
        (sphere((0, 0.4, 3.62), (0.32, 0.32, 0.18), 10, 5), "bronze"),
    ]
    cup = bmesh.new()
    rings = []
    for k in range(6):
        t = k / 5
        z = 3.65 + 1.25 * t
        r = 0.3 + 0.62 * math.sin(t * math.pi / 2) ** 0.8
        rings.append([cup.verts.new((r * math.cos(2 * math.pi * i / 16), 0.4 + r * math.sin(2 * math.pi * i / 16), z))
                      for i in range(16)])
    inner = [cup.verts.new((v.co.x * 0.85, 0.4 + (v.co.y - 0.4) * 0.85, v.co.z)) for v in rings[-1]]
    bottom = [cup.verts.new((v.co.x * 0.85, 0.4 + (v.co.y - 0.4) * 0.85, 4.1)) for v in rings[-1]]
    for a, b in zip(rings, rings[1:]):
        for i in range(16):
            j = (i + 1) % 16
            cup.faces.new((a[i], a[j], b[j], b[i]))
    for i in range(16):
        j = (i + 1) % 16
        cup.faces.new((rings[-1][i], rings[-1][j], inner[j], inner[i]))
        cup.faces.new((inner[i], inner[j], bottom[j], bottom[i]))
    cup.faces.new(list(reversed(rings[0])))
    cup.faces.new(list(bottom))
    parts.append((_finish(cup), "bronze"))
    for s in (-1, 1):
        parts.append((torus((s * 0.95, 0.4, 4.35), 0.32, 0.07, 10, 5, axis="Y"), "bronze"))
    parts.append((torus((0, 0.4, 3.0), 0.24, 0.06, 10, 4), "red"))
    parts.append((segment((0.15, 0.2, 3.0), (0.35, -0.1, 2.6), 0.06, 4), "red"))
    return parts


def fv2_golden_dumbbell():
    # Haltère en or massif sur coussin de velours, sur socle de marbre noir, sous un petit projecteur
    parts = [
        (fv2_rbox((0, 0.4, 0.2), (3.0, 2.0, 0.4), r=0.1), "marbleblack"),
        (fv2_rbox((0, 0.4, 1.4), (2.4, 1.5, 2.1), r=0.1), "marbleblack"),
        (fv2_rbox((0, 0.4, 2.55), (3.0, 2.0, 0.25), r=0.1), "gold"),
        (fv2_rbox((0, -0.37, 1.6), (1.2, 0.06, 0.45), r=0.04), "gold"),
        (fv2_pillow((0, 0.4, 2.9), (2.6, 1.6, 0.5)), "fabricred"),
    ]
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append((sphere((sx * 1.2, 0.4 + sy * 0.72, 2.75), 0.12, 6, 4), "gold"))
    parts += fv2_dumbbell((0, 0.4, 3.55), 2.8, 0.15, 0.62, 0.32, color="gold", plates=2, bar="gold")
    parts.append((segment((0, 1.35, 2.7), (0, 1.35, 5.4), 0.06, 6), "darkgrey"))
    parts.append((segment((0, 1.35, 5.4), (0, 0.6, 5.6), 0.06, 6), "darkgrey"))
    parts.append((cylinder((0, 0.45, 5.25), 0.3, 0.45, 10, radius_top=0.18), "darkgrey"))
    parts.append((cylinder((0, 0.45, 5.23), 0.25, 0.03, 10), "lampwarm"))
    return parts


def fv2_bicep_statue():
    # Statue de marbre d'un mogger en double biceps, sur socle : trapèzes, mâchoire carrée, bras levés
    parts = [
        (fv2_rbox((0, 0.3, 0.3), (3.4, 2.4, 0.6), r=0.1), "marbleblack"),
        (fv2_rbox((0, 0.3, 0.9), (2.8, 2.0, 0.6), r=0.08), "marble"),
        (fv2_rbox((0, -0.72, 0.9), (1.4, 0.06, 0.35), r=0.03), "gold"),
        (fv2_rbox((0, 0.3, 1.9), (2.2, 1.3, 1.5), r=0.4, seg=3, taper=1.25), "marble"),                     # torse
        (sphere((-0.5, -0.25, 2.15), (0.6, 0.3, 0.45), 10, 5), "marble"),                                 # pectoraux
        (sphere((0.5, -0.25, 2.15), (0.6, 0.3, 0.45), 10, 5), "marble"),
        (sphere((0, 0.35, 2.75), (1.15, 0.55, 0.45), 12, 6), "marble"),                                   # trapèzes
        (cylinder((0, 0.25, 2.8), 0.3, 0.4, 10), "marble"),
        (sphere((0, 0.2, 3.5), (0.5, 0.55, 0.55), 12, 8), "marble"),                                      # tête
        (fv2_rbox((0, -0.05, 3.15), (0.95, 0.75, 0.55), r=0.2, seg=2, taper=1.1), "marble"),                  # mâchoire
        (sphere((0, -0.38, 3.45), (0.1, 0.12, 0.13), 6, 4), "marble"),                                    # nez
    ]
    for k in range(3):
        for s in (-1, 1):
            parts.append((sphere((s * 0.22, -0.2, 1.75 - k * 0.32), (0.2, 0.12, 0.13), 6, 4), "marble"))   # abdos
    for s in (-1, 1):
        sh = Vector((s * 1.15, 0.3, 2.55))
        el = Vector((s * 1.95, 0.3, 2.65))
        fi = Vector((s * 1.8, 0.2, 3.6))
        parts.append((sphere(tuple(sh), (0.5, 0.5, 0.45), 10, 6), "marble"))                             # deltoïde
        parts.append((segment(tuple(sh), tuple(el), 0.33, 10, 0.28), "marble"))
        parts.append((sphere(tuple(sh.lerp(el, 0.55) + Vector((0, 0, 0.22))), (0.42, 0.33, 0.36), 10, 6), "marble"))  # biceps
        parts.append((sphere(tuple(el), 0.28, 8, 5), "marble"))
        parts.append((segment(tuple(el), tuple(fi), 0.26, 10, 0.22), "marble"))
        parts.append((sphere(tuple(fi + Vector((0, 0, 0.1))), (0.27, 0.25, 0.3), 8, 5), "marble"))      # poing
    return parts


FURNITURE_V2 = {
    "SaggyCouch": fv2_saggy_couch, "BenchSofa": fv2_bench_sofa, "LeopardSofa": fv2_leopard_sofa, "ThroneSofa": fv2_throne_sofa,
    "TubeTv": fv2_tube_tv, "GiantScreen": fv2_giant_screen, "Mattress": fv2_mattress, "RaceCarBed": fv2_race_car_bed,
    "PizzaRug": fv2_pizza_rug, "ZebraRug": fv2_zebra_rug, "GoldRug": fv2_gold_rug, "FlexPoster": fv2_flex_poster,
    "SunsetPoster": fv2_sunset_poster, "NeonDumbbell": fv2_neon_dumbbell, "Cactus": fv2_cactus, "ShakerPlant": fv2_shaker_plant,
    "LavaLamp": fv2_lava_lamp, "DumbbellLamp": fv2_dumbbell_lamp, "BronzeCup": fv2_bronze_cup, "GoldenDumbbell": fv2_golden_dumbbell,
    "BicepStatue": fv2_bicep_statue,
}


# Mise à l'échelle finale pour rester dans l'encombrement des anciens modèles (emplacements de la maison inchangés)
FURNITURE_V2_SCALE = {"RaceCarBed": (0.85, 0.76, 0.9), "ZebraRug": (0.9, 0.9, 1.0), "GoldRug": (0.9, 0.9, 1.0)}


def furniture(P):
    for name, build in FURNITURE_V2.items():
        parts = build()
        s = FURNITURE_V2_SCALE.get(name)
        if s:
            for bm, _ in parts:
                scale(bm, s)
        P.prop("Furniture_" + name, parts)


# ------------------------------------------------------------------ tribune de stade (arène des boss)
def fv2_stadium_stand(seat_color, accent):
    """Vraie tribune de stade : 4 gradins de béton aux nez arrondis, sièges baquets moulés avec dossier, allée
    centrale en escalier à nez jaunes, joues de béton biseautées, garde-corps avant rembourré, rambardes en tube et
    mâts de drapeau. Le devant (côté ring) vers -Y."""
    parts = []
    width, rows, depth, rise = 15.0, 4, 2.2, 1.0  # 16 studs avec les joues : tient dans le sol de l'arène (x >= -38)
    aisle = 1.6
    half = (width - aisle) / 2
    for k in range(rows):
        y0 = -depth * rows / 2 + k * depth
        top = rise * (k + 1)
        for side in (-1, 1):
            xc = side * (aisle / 2 + half / 2)
            parts.append((fv2_rbox((xc, y0 + depth / 2, top / 2), (half, depth + 0.02, top), r=0.08), "concrete"))
            parts.append((fv2_rbox((xc, y0 + 0.08, top - 0.03), (half, 0.2, 0.12), r=0.05), "lightgrey"))  # nez arrondi
        # Sièges baquets de part et d'autre de l'allée
        n = 6
        span = (width - aisle) / 2 - 0.6
        for side in (-1, 1):
            for i in range(n):
                x = side * (aisle / 2 + 0.3 + span * (i + 0.5) / n)
                yc = y0 + depth * 0.55
                parts.append((fv2_rbox((x, yc, top + 0.28), (0.9, 0.9, 0.16), r=0.06, seg=1), seat_color))
                back = fv2_rbox((x, yc + 0.48, top + 0.75), (0.9, 0.14, 0.85), r=0.06, seg=1)
                rotate(back, -10, "X", (x, yc + 0.48, top + 0.35))
                parts.append((back, seat_color))
                parts.append((box((x, yc + 0.1, top + 0.12), (0.18, 0.5, 0.24)), "darkgrey"))
        # Allée : deux marches par gradin, nez jaunes
        for st in range(2):
            z = rise * k + rise * (st + 1) / 2
            yy = y0 + depth * st / 2
            parts.append((fv2_rbox((0, yy + depth / 4, z / 2), (aisle, depth / 2 + 0.02, z), r=0.04), "lightgrey"))
            parts.append((fv2_rbox((0, yy + 0.06, z), (aisle - 0.06, 0.12, 0.06), r=0.02), "yellow"))
    # Joues biseautées de chaque côté
    total_d = depth * rows
    prof = [(-total_d / 2 - 0.3, 0.0), (total_d / 2 + 0.2, 0.0), (total_d / 2 + 0.2, rise * rows + 1.2),
            (total_d / 2 - 0.6, rise * rows + 1.2), (-total_d / 2 - 0.3, 1.3)]
    for s in (-1, 1):
        # profil (y, z) extrudé sur 0,5 puis tourné : y du profil -> y, épaisseur -> x, collée à l'extérieur
        cheek = extrude(prof, 0.5, y0=0)
        rotate(cheek, 90, "Z")
        for v in cheek.verts:
            v.co.x = s * (width / 2 - v.co.x)
        parts.append((cheek, "concrete"))
    # Garde-corps avant rembourré (couleur du boss) et rambarde en fv2_tube
    parts.append((fv2_rbox((0, -total_d / 2 - 0.15, 0.55), (width, 0.35, 1.1), r=0.12), "concrete"))
    parts.append((fv2_pillow((0, -total_d / 2 - 0.22, 1.25), (width - 0.2, 0.45, 0.35)), accent))
    for x in (-width / 2 + 0.3, -aisle / 2 - 0.1, aisle / 2 + 0.1, width / 2 - 0.3):
        parts.append((segment((x, -total_d / 2 - 0.15, 1.3), (x, -total_d / 2 - 0.15, 2.2), 0.06, 6), "chrome"))
    parts += [(p, "chrome") for p in fv2_tube([(-width / 2 + 0.3, -total_d / 2 - 0.15, 2.2),
                                           (width / 2 - 0.3, -total_d / 2 - 0.15, 2.2)], 0.07)]
    # Rambardes de l'allée et de l'arrière
    for s in (-1, 1):
        x = s * (aisle / 2 + 0.05)
        parts += [(p, "chrome") for p in fv2_tube([(x, -total_d / 2 + 0.2, 1.5), (x, total_d / 2 - 0.3, rise * rows + 1.4)],
                                              0.06)]
        for k in range(rows):
            y = -total_d / 2 + depth * (k + 0.5)
            parts.append((segment((x, y, rise * (k + 0.5)), (x, y, rise * (k + 0.5) + 1.25), 0.05, 6), "chrome"))
    back_y = total_d / 2 + 0.05
    parts.append((fv2_rbox((0, back_y, rise * rows + 0.5), (width, 0.3, 1.0), r=0.1), "concrete"))
    parts += [(p, "chrome") for p in fv2_tube([(-width / 2 + 0.3, back_y, rise * rows + 1.0),
                                           (-width / 2 + 0.3, back_y, rise * rows + 2.0),
                                           (width / 2 - 0.3, back_y, rise * rows + 2.0),
                                           (width / 2 - 0.3, back_y, rise * rows + 1.0)], 0.07)]
    # Mâts de drapeau aux deux coins arrière (fanions unis, sans texte)
    for s in (-1, 1):
        x = s * (width / 2 + 0.25)
        parts.append((segment((x, back_y, rise * rows + 1.2), (x, back_y, rise * rows + 5.0), 0.07, 6), "chrome"))
        parts.append((sphere((x, back_y, rise * rows + 5.05), 0.14, 8, 4), "gold"))
        flag = extrude([(0, 0), (-s * 1.6, -0.35), (0, -0.8)], 0.04, y0=-0.02, axis="Y")
        move(flag, (x, back_y, rise * rows + 4.85))
        parts.append((flag, accent))
    return parts


def bleachers(P):
    """Tribunes de l'arène (D121) : une par boss, aux couleurs de son ring."""
    P.prop("Bleachers", fv2_stadium_stand("red", "darkred"))            # Pas-Les-Jambes (ring rouge)
    P.prop("Bleachers_King", fv2_stadium_stand("purple", "gold"))       # Roi du Quartier (ring violet)


# ------------------------------------------------------------------ décors des secrets (D121)
def fv2_secret_props(P):
    # Plaque d'égout qui se soulève (le jeu l'anime) et le rat coach qui fait des pompes avec un mini haltère
    lid = [(cylinder((0, 0, 0), 1.5, 0.18, 20, bevel=0.04), "iron")]
    for k in range(5):
        lid.append((fv2_rbox((0, -1.0 + k * 0.5, 0.2), (2.4 - abs(k - 2) * 0.5, 0.12, 0.04), r=0.02), "darkgrey"))
    P.prop("Secret_ManholeLid", lid)
    # Cadre posé au sol, fond noir (le trou) juste dessous du couvercle
    ring = [(torus((0, 0, 0.16), 1.65, 0.16, 20, 6), "darkgrey"),
            (cylinder((0, 0, 0.0), 1.52, 0.04, 20), "black")]
    P.prop("Secret_ManholeRing", ring)
    rat = [
        (sphere((0, 0.1, 0.55), (0.55, 0.85, 0.42), 12, 8), "grey"),                       # corps
        (sphere((0, -0.75, 0.62), (0.36, 0.45, 0.34), 10, 6), "grey"),                     # tête
        (cone((0, -1.05, 0.6), 0.2, 0.0, 6), "grey"),
        (sphere((0, -1.2, 0.6), 0.08, 6, 4), "pink"),                                       # nez
        (sphere((-0.17, -1.0, 0.78), 0.07, 6, 4), "black"),
        (sphere((0.17, -1.0, 0.78), 0.07, 6, 4), "black"),
        (sphere((-0.3, -0.62, 0.98), (0.2, 0.06, 0.22), 8, 4), "pink"),                     # oreilles
        (sphere((0.3, -0.62, 0.98), (0.2, 0.06, 0.22), 8, 4), "pink"),
        (fv2_rbox((0, -0.95, 0.45), (0.36, 0.06, 0.08), r=0.02), "white"),                       # dents
        (fv2_rbox((0, -0.35, 0.9), (0.9, 0.12, 0.12), r=0.04), "red"),                           # bandeau
    ]
    for s in (-1, 1):
        rat.append((segment((s * 0.35, -0.5, 0.45), (s * 0.55, -0.6, 0.05), 0.12, 6), "grey"))   # bras tendus
        rat.append((sphere((s * 0.4, -0.25, 0.75), (0.22, 0.25, 0.18), 8, 5), "grey"))          # pectoraux
        rat.append((segment((s * 0.3, 0.75, 0.35), (s * 0.35, 1.0, 0.05), 0.1, 6), "grey"))
    tail = [(0, 0.9, 0.5), (0.2, 1.4, 0.45), (0.5, 1.8, 0.6), (0.4, 2.2, 0.9)]
    rat += [(p, "pink") for p in fv2_tube(tail, 0.05, 6)]
    rat += fv2_dumbbell((0.95, -0.4, 0.12), 0.7, 0.04, 0.14, 0.08, color="charcoal", plates=1, bar="chrome")
    P.prop("Secret_RatCoach", rat)
    # Haltère fantôme (le jeu le rend translucide et le fait flotter)
    ghost = fv2_dumbbell((0, 0, 0.8), 3.0, 0.16, 0.75, 0.35, color="white", plates=2, bar="white")
    for s in (-1, 1):
        ghost.append((sphere((s * 0.35, -0.17, 0.95), (0.1, 0.05, 0.14), 6, 4), "black"))         # yeux
    ghost.append((sphere((0, -0.17, 0.6), (0.12, 0.05, 0.08), 6, 4), "black"))                     # « ooo »
    P.prop("Secret_GhostDumbbell", ghost)


def build_v2_extras(P):
    """Décors nouveaux de D121 (en plus des catégories) : ceux des secrets."""
    fv2_secret_props(P)

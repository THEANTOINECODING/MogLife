"""
Meubles v3 (D133, demande d'Antoine : « refaire l'entièreté des meubles pour qu'ils soient extrêmement plus
qualitatifs »). Chargé après props_lib.py et props_furniture_v2.py (on réutilise ses formes arrondies).

Ce qui change par rapport à la v2 :
- Chaque meuble est fait de plusieurs MeshParts, une par « look » : une VRAIE matière Roblox et une couleur
  (tissu, cuir, bois, métal doré, chrome, néon qui brille, verre, marbre…). Fini le damier de la palette sur les
  tissus. Les motifs (léopard, zèbre, écran, pizza, damier) gardent la palette partagée (« tex: »).
- Ombres lissées : faces lissées avec arêtes vives au-delà de 35° (formes rondes douces, angles nets).
- Formes refaites : plus de segments sur les arrondis, coussins rebondis, plis, coutures, petites blagues de bro.
- Mêmes identifiants Furniture_<Id> et mêmes encombrements (les emplacements de la maison ne changent pas) :
  devant vers -Y, dos contre le mur (+Y), sol à z = 0.

Nom des objets exportés : Furniture_<Id>__<Matière>_<rrggbb> (ou __Tex pour la palette). tools/install_furniture.luau
les assemble dans Studio : la plus grosse pièce devient Furniture_<Id>, les autres ses enfants (attribut AccentOffset,
voir src/shared/PropAccents.luau).
"""
import math
import bmesh
import bpy
from mathutils import Vector

# ------------------------------------------------------------------ looks : (matière Roblox, couleur)
LOOKS = {
    # tissus
    "couch": ("Fabric", "8c5e3c"), "couchdark": ("Fabric", "6a4428"), "couchpatch": ("Fabric", "c0703a"),
    "throw": ("Fabric", "e88a4a"), "velvet": ("Fabric", "b02a30"), "velvetdark": ("Fabric", "7e1c22"),
    "sheet": ("Fabric", "f4f1ea"), "pillow": ("Fabric", "fbfaf6"), "duvet": ("Fabric", "3c6ec8"),
    "duvetlight": ("Fabric", "8ec8ee"), "pink": ("Fabric", "ff5aa8"), "boa": ("Fabric", "ff9ad2"),
    "black_fabric": ("Fabric", "1e1e22"), "rugred": ("Carpet", "a8262c"), "ruggold": ("Carpet", "e2b43c"),
    "rugnavy": ("Carpet", "243a78"), "rugcream": ("Carpet", "f2e2bc"), "crust": ("Fabric", "e09a48"),
    "cheese": ("Fabric", "f6d050"), "pepperoni": ("Fabric", "c8342a"), "basil": ("Fabric", "4e9a44"),
    "shade": ("Fabric", "f4e6c4"), "sweatband": ("Fabric", "e0302a"), "towel": ("Fabric", "f0eee8"),
    # cuir
    "leather": ("Leather", "232328"), "leatherseam": ("Leather", "101012"), "leatherred": ("Leather", "b0282a"),
    # bois
    "wood": ("Wood", "a8784c"), "wooddark": ("Wood", "5e3c24"), "woodlight": ("Wood", "d8b07a"),
    "pallet": ("WoodPlanks", "d0a46c"),
    # métaux
    "gold": ("Foil", "e6b83a"), "golddark": ("Foil", "b88a26"), "bronze": ("Foil", "c07a3e"),
    "chrome": ("Metal", "dfe4ea"), "steel": ("Metal", "9aa2aa"), "iron": ("Metal", "3e4248"),
    "brass": ("Foil", "d8a840"),
    # plastiques
    "red": ("SmoothPlastic", "d8302a"), "white": ("SmoothPlastic", "f2f0ea"), "black": ("SmoothPlastic", "1c1c20"),
    "charcoal": ("SmoothPlastic", "2c2c32"), "grey": ("SmoothPlastic", "8e8c88"), "beige": ("SmoothPlastic", "d6c6a0"),
    "orange": ("SmoothPlastic", "f08a2a"), "yellow": ("SmoothPlastic", "f2c63c"), "blue": ("SmoothPlastic", "3c6ec8"),
    "terracotta": ("SmoothPlastic", "c8643c"), "terracottadark": ("SmoothPlastic", "9a4a2a"),
    "soil": ("SmoothPlastic", "4a3424"), "cactus": ("SmoothPlastic", "4e9a44"), "cactusdark": ("SmoothPlastic", "3a7a36"),
    "leaf": ("SmoothPlastic", "4ea24a"), "leafdark": ("SmoothPlastic", "2e7034"), "flower": ("SmoothPlastic", "ff6aa8"),
    "rubber": ("Rubber", "202024"), "skin": ("SmoothPlastic", "e8a878"), "can_red": ("Metal", "d2302a"),
    "can_green": ("Metal", "6ad24a"), "cardboard": ("Cardboard", "b08a5a"), "paper": ("SmoothPlastic", "f6f2e6"),
    "carred": ("SmoothPlastic", "e0281e"), "carwhite": ("SmoothPlastic", "f6f6f6"), "posterbg": ("SmoothPlastic", "f6d24a"),
    "posterray": ("SmoothPlastic", "f9e48a"), "palm": ("SmoothPlastic", "241238"), "acrylic": ("Glass", "1a1a26"),
    # pierres
    "marble": ("Marble", "eeeae2"), "marbleblack": ("Marble", "36363c"), "marblewhite": ("Marble", "f6f4ee"),
    # verre et lumière
    "glass": ("Glass", "bfe2f6"), "screenglass": ("Glass", "20283a"),
    "neon_pink": ("Neon", "ff4aa8"), "neon_cyan": ("Neon", "4ae6ff"), "neon_warm": ("Neon", "ffe2a0"),
    "neon_orange": ("Neon", "ff8a2a"), "neon_red": ("Neon", "ff3a3a"), "neon_blue": ("Neon", "5a8aff"),
    "neon_purple": ("Neon", "b05aff"), "neon_white": ("Neon", "fff6e6"), "neon_sun": ("Neon", "ffb04a"),
    "screen": ("Neon", "3a6ad8"), "screencrt": ("Neon", "7ab0e0"),
}
SMOOTH_ANGLE = math.radians(35)


def v3_finish_group(name, parts, pal):
    """Fusionne des pièces (bmesh, case de palette ou look) en un bmesh, UV sur la palette ou case unie."""
    total = bmesh.new()
    tmp = bpy.data.meshes.new("_tmp_v3")
    for bm, spec in parts:
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.normal_update()
        ns_uv(bm, spec, pal)
        bm.to_mesh(tmp)
        total.from_mesh(tmp)
        bm.free()
    bpy.data.meshes.remove(tmp)
    return total


def ns_uv(bm, spec, pal):
    # Les looks sans texture prennent la case blanche de la palette (la texture est retirée dans Studio)
    cell = spec[4:] if spec.startswith("tex:") else "white"
    _uv(bm, cell, pal)


def v3_prop(P, name, parts):
    """Crée un meuble en plusieurs objets (un par look), tous dans le même repère, rangés sur la grille de P."""
    groups = {}
    for bm, spec in parts:
        key = spec if spec.startswith("tex:") else spec
        if not spec.startswith("tex:") and spec not in LOOKS:
            raise KeyError(f"look inconnu : {spec} ({name})")
        groups.setdefault(key, []).append((bm, spec))
    # Repère commun : base centrée sur l'origine, sol à z = 0
    meshes = {k: v3_finish_group(name, g, P.pal) for k, g in groups.items()}
    xs, ys, zs = [], [], []
    for bm in meshes.values():
        for v in bm.verts:
            xs.append(v.co.x)
            ys.append(v.co.y)
            zs.append(v.co.z)
    offset = Vector(((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, min(zs)))
    i = P.count
    location = ((i % P.columns) * P.spacing, -(i // P.columns) * P.spacing, 0)
    P.count += 1
    tris = 0
    objects = []
    for key, bm in meshes.items():
        for v in bm.verts:
            v.co -= offset
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
        if key.startswith("tex:"):
            suffix = "Tex"
        else:
            material, color = LOOKS[key]
            suffix = f"{material}_{color}"
        obj_name = f"{name}__{suffix}"
        old = bpy.data.objects.get(obj_name)
        if old:
            bpy.data.objects.remove(old, do_unlink=True)
        me = bpy.data.meshes.get(obj_name)
        if me:
            bpy.data.meshes.remove(me)
        me = bpy.data.meshes.new(obj_name)
        bm.to_mesh(me)
        bm.free()
        for p in me.polygons:
            p.use_smooth = True
        me.set_sharp_from_angle(angle=SMOOTH_ANGLE)
        me.materials.append(P.mat)
        obj = bpy.data.objects.new(obj_name, me)
        P.col.objects.link(obj)
        obj.location = location
        tris += sum(len(p.vertices) - 2 for p in me.polygons)
        objects.append(obj)
    size = Vector((max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs)))
    P.report.append(f"{name}: {tris} tris, {len(objects)} pièces, {size.x:.1f} x {size.y:.1f} x {size.z:.1f}")
    return objects


# ------------------------------------------------------------------ petites formes
def v3_round(center, size, r=None, seg=3, bulge=0.0, taper=1.0):
    return fv2_rbox(center, size, r=r if r is not None else min(size) * 0.3, seg=seg, bulge=bulge, taper=taper)


def v3_cyl(base, radius, height, sides=20, axis="Z", radius_top=None, bevel=0.0):
    return cylinder(base, radius, height, sides, radius_top=radius_top, axis=axis, bevel=bevel)


def v3_ball(center, r, u=16, v=10):
    return sphere(center, r, u, v)


def v3_leaf(base, length, width, yaw, pitch, thick=0.06):
    """Feuille : ellipsoïde aplati, posé à `base`, orienté (lacet, inclinaison) en degrés."""
    bm = sphere((0, length / 2, 0), (width / 2, length / 2, thick), 12, 6)
    # nervure creusée : on abaisse un peu le milieu
    for v in bm.verts:
        v.co.z -= 0.05 * width * math.exp(-(v.co.x / (width * 0.2)) ** 2)
        v.co.z += 0.12 * length * (v.co.y / length) ** 2  # la pointe remonte
    rotate(bm, pitch, "X")
    rotate(bm, yaw, "Z")
    move(bm, base)
    return bm


def v3_coil(center, radius, wire, turns, height, steps=10):
    pts = []
    n = int(turns * steps)
    for k in range(n + 1):
        a = 2 * math.pi * k / steps
        pts.append((center[0] + radius * math.cos(a), center[1] + radius * math.sin(a), center[2] + height * k / n))
    return [segment(a, b, wire, 6) for a, b in zip(pts, pts[1:])]


def v3_tube(points, radius, look, sides=12):
    return [(bm, look) for bm in fv2_tube(points, radius, sides)]


def v3_plate(center, radius, thick, look="iron", hub="chrome", axis="X"):
    x, y, z = center
    if axis == "X":
        return [
            (v3_cyl((x - thick / 2, y, z), radius, thick, 24, axis="X", bevel=thick * 0.22), look),
            (v3_cyl((x - thick / 2 - 0.03, y, z), radius * 0.26, thick + 0.06, 14, axis="X"), hub),
            (torus((x, y, z), radius * 0.72, thick * 0.12, 24, 4, axis="X"), look),
        ]
    return [
        (v3_cyl((x, y, z - thick / 2), radius, thick, 24, bevel=thick * 0.22), look),
        (v3_cyl((x, y, z - thick / 2 - 0.03), radius * 0.26, thick + 0.06, 14), hub),
    ]


def v3_dumbbell(center, length, bar_r, plate_r, plate_t, look="gold", bar="chrome", plates=2):
    x, y, z = center
    parts = [(v3_cyl((x - length / 2, y, z), bar_r, length, 14, axis="X"), bar)]
    # moletage : anneaux fins
    for k in range(-3, 4):
        parts.append((torus((x + k * length * 0.06, y, z), bar_r * 1.02, bar_r * 0.12, 14, 4, axis="X"), bar))
    for s in (-1, 1):
        for k in range(plates):
            px = x + s * (length / 2 - 0.2 - k * plate_t * 1.08 - plate_t / 2)
            r = plate_r * (1 - 0.16 * k)
            parts.append((v3_cyl((px - plate_t / 2, y, z), r, plate_t, 24, axis="X", bevel=plate_t * 0.22), look))
        parts.append((v3_ball((x + s * length / 2, y, z), bar_r * 1.5, 12, 8), bar))
    return parts


def v3_frame(w, h, depth, border, look, z0=0.0, y=0.0):
    """Cadre mouluré : baguette extérieure arrondie et filet intérieur."""
    parts = [(bm, look) for bm, _ in fv2_frame(w, h, depth, border, z0=z0, y=y, color="gold")]
    inner = [(bm, look) for bm, _ in fv2_frame(w - 2 * border + 0.1, h - 2 * border + 0.1, depth * 0.6, border * 0.3,
                                               z0=z0 + border - 0.05, y=y - depth * 0.2, color="gold")]
    return parts + inner


# ------------------------------------------------------------------ canapés
def v3_sofa_shell(width, depth, seat_h, back_h, look, arm_look=None, leg_look="wooddark", cushions=3, sag=0.0,
                  arm_r=0.55, back_tilt=0.0, piping=None):
    """Canapé rebondi : socle, coussins d'assise et de dossier très bombés, accoudoirs roulés, pieds fuselés."""
    arm_look = arm_look or look
    arm_w = 0.95
    inner = width - 2 * arm_w + 0.1
    parts = [
        (v3_round((0, 0.1, seat_h * 0.38), (width - 0.2, depth - 0.25, seat_h * 0.5), r=0.22, seg=3), look),
        (v3_round((0, depth / 2 - 0.42, seat_h + back_h * 0.36), (width - 0.25, 0.8, back_h * 1.05), r=0.36, seg=4),
         look),
    ]
    cw = inner / cushions
    for k in range(cushions):
        x = -inner / 2 + cw * (k + 0.5)
        u = 1 - (abs(x) / (inner / 2 + 1e-6)) ** 2
        dz = -sag * u
        seat = fv2_pillow((x, -0.2, seat_h * 0.8 + dz), (cw - 0.06, depth - 1.0, 0.62), bulge=0.14)
        parts.append((seat, look))
        back = fv2_pillow((0, 0, 0), (cw - 0.1, 0.7, back_h * 0.86), bulge=0.12)
        rotate(back, -10 - back_tilt * (1 if k % 2 else -0.6), "X")
        rotate(back, (k - (cushions - 1) / 2) * -2.5 * back_tilt, "Y")
        move(back, (x, depth / 2 - 0.98, seat_h + back_h * 0.52 + dz * 0.4))
        parts.append((back, look))
    for s in (-1, 1):
        ax = s * (width / 2 - arm_w / 2)
        parts.append((v3_round((ax, 0.02, seat_h * 0.62), (arm_w, depth - 0.2, seat_h * 1.05), r=0.25, seg=3), arm_look))
        roll = v3_cyl((ax, -depth / 2 + 0.06, seat_h * 1.12), arm_r, depth - 0.3, 20, axis="Y")
        parts.append((roll, arm_look))
        parts.append((v3_round((ax, -depth / 2 + 0.03, seat_h * 1.12), (arm_r * 1.7, 0.14, arm_r * 1.7),
                               r=arm_r * 0.8, seg=3), arm_look))
        if piping:
            parts.append((torus((ax, -depth / 2 - 0.03, seat_h * 1.12), arm_r * 0.86, 0.06, 20, 6, axis="Y"), piping))
        for y in (-depth / 2 + 0.38, depth / 2 - 0.38):
            parts.append((v3_cyl((ax + s * -0.05, y, 0), 0.1, 0.36, 12, radius_top=0.17), leg_look))
    return parts


def v3_saggy_couch():
    # Le canapé de la cave : avachi, rapiécé au scotch, un ressort qui sort, plaid jeté, pizza et télécommande
    parts = v3_sofa_shell(7.0, 3.0, 1.35, 1.95, "couch", arm_look="couchdark", leg_look="wooddark", cushions=3,
                          sag=0.32, back_tilt=1.0)
    # rustine en scotch gris en croix sur l'accoudoir gauche
    for a in (35, -35):
        tape = v3_round((0, 0, 0), (0.95, 0.24, 0.05), r=0.02, seg=1)
        rotate(tape, a, "Y")
        move(tape, (-3.05, -0.6, 1.95))
        parts.append((tape, "grey"))
    # pièce de tissu cousue sur le coussin de droite + points de couture
    parts.append((v3_round((1.75, -0.35, 1.47), (0.95, 0.85, 0.08), r=0.03, seg=1), "couchpatch"))
    for k in range(6):
        parts.append((v3_round((1.32 + 0.17 * k, -0.79, 1.52), (0.05, 0.12, 0.03), r=0.01, seg=1), "black"))
    # ressort qui sort du coussin du milieu
    parts += [(bm, "steel") for bm in v3_coil((-0.05, -0.5, 1.35), 0.14, 0.035, 3.0, 0.55)]
    # plaid orange plié sur l'accoudoir droit
    for k in range(3):
        fold = v3_round((3.02, -0.15, 2.08 + 0.13 * k), (1.0 - 0.06 * k, 1.5 - 0.1 * k, 0.14), r=0.06, seg=2,
                        bulge=0.03)
        parts.append((fold, "throw"))
    for k in range(5):  # franges
        parts.append((segment((3.52, -0.75 + 0.3 * k, 2.1), (3.6, -0.75 + 0.3 * k, 1.85), 0.035, 4), "throw"))
    # boîte à pizza ouverte sur le coussin de gauche, couvercle relevé contre le dossier
    box_ = v3_round((-1.95, -0.45, 1.62), (1.55, 1.55, 0.16), r=0.03, seg=1)
    parts.append((box_, "cardboard"))
    lid = v3_round((-1.95, 0.33, 1.7 + 0.775), (1.55, 0.06, 1.55), r=0.02, seg=1)
    rotate(lid, -14, "X", (-1.95, 0.33, 1.7))
    parts.append((lid, "cardboard"))
    slice_ = extrude([(0, 0), (0.55, 0.0), (0.27, 0.6)], 0.06, y0=0)
    rotate(slice_, -90, "X")
    move(slice_, (-2.3, -0.75, 1.73))
    parts.append((slice_, "cheese"))
    parts.append((v3_cyl((-2.0, -0.6, 1.73), 0.09, 0.03, 12), "pepperoni"))
    # télécommande et canette sur le coussin
    remote = v3_round((0.55, -0.9, 1.55), (0.28, 0.75, 0.12), r=0.06, seg=2)
    rotate(remote, -25, "Z", (0.55, -0.9, 1.55))
    parts.append((remote, "black"))
    parts.append((v3_round((0.55, -1.05, 1.62), (0.08, 0.08, 0.03), r=0.02, seg=1), "red"))
    parts.append((v3_cyl((2.6, 1.0, 3.35), 0.17, 0.5, 16), "can_green"))
    return parts


def v3_bench_sofa():
    # Banc de muscu devenu canapé : cuir capitonné, châssis chromé, rack à barre en dossier, disques de couleur
    parts = [
        (fv2_pillow((0, -0.15, 1.72), (6.6, 2.4, 0.66), bulge=0.12), "leather"),
        (v3_round((0, -0.15, 1.32), (6.4, 2.2, 0.2), r=0.07, seg=2), "charcoal"),
        (fv2_pillow((0, 0.98, 2.95), (6.6, 0.58, 1.7), bulge=0.08), "leather"),
    ]
    # capitons et coutures
    for i, z in enumerate((2.45, 2.95, 3.45)):
        for k in range(7 - (i % 2)):
            x = -2.7 + 0.9 * k + (0.45 if i % 2 else 0)
            parts.append((v3_ball((x, 0.66, z), (0.07, 0.05, 0.07), 8, 5), "leatherseam"))
    for x in (-2.2, 0, 2.2):
        parts.append((v3_round((x, -0.15, 2.04), (0.05, 2.25, 0.04), r=0.01, seg=1), "leatherseam"))
    for s in (-1, 1):
        x = s * 2.9
        parts += v3_tube([(x, -1.2, 0.08), (x, -1.2, 1.25), (x, 1.05, 1.25), (x, 1.05, 0.08)], 0.12, "chrome")
        parts.append((v3_round((x, -0.08, 0.08), (0.5, 2.7, 0.16), r=0.06, seg=2), "charcoal"))
        for y in (-1.3, 1.15):  # patins
            parts.append((v3_cyl((x, y, 0), 0.22, 0.08, 12), "rubber"))
        parts.append((segment((x, 1.2, 1.2), (x, 1.2, 4.3), 0.12, 12), "chrome"))
        hook = v3_round((x, 0.92, 4.05), (0.3, 0.6, 0.14), r=0.05, seg=2)
        parts.append((hook, "steel"))
        parts.append((v3_ball((x, 1.2, 4.35), 0.16, 10, 6), "chrome"))
    parts += v3_dumbbell((0, 0.85, 4.32), 8.2, 0.1, 1.05, 0.26, look="red", bar="chrome", plates=1)
    for s in (-1, 1):
        parts += v3_plate((s * 3.35, 0.85, 4.32), 0.82, 0.22, look="blue", hub="chrome")
        parts.append((v3_cyl((s * 3.62 - 0.12, 0.85, 4.32), 0.17, 0.24, 12, axis="X"), "steel"))
    # serviette pliée et gourde
    parts.append((v3_round((-2.2, -0.4, 2.12), (1.2, 0.8, 0.16), r=0.07, seg=2), "towel"))
    parts.append((v3_cyl((2.6, -0.6, 2.05), 0.22, 0.75, 16), "blue"))
    parts.append((v3_cyl((2.6, -0.6, 2.8), 0.14, 0.12, 12), "black"))
    return parts


def v3_leopard_sofa():
    # Canapé de diva : léopard, passepoil noir, pieds dorés, boa de plumes rose, coussin cœur
    parts = v3_sofa_shell(7.4, 3.1, 1.45, 2.05, "tex:leopard", leg_look="gold", cushions=3, piping="black_fabric")
    parts.append((v3_cyl((-3.4, 1.18, 3.42), 0.13, 6.8, 14, axis="X"), "black_fabric"))
    # boa de plumes posé le long du dossier
    for k in range(26):
        t = k / 25
        x = -3.2 + 6.4 * t
        z = 3.55 + 0.12 * math.sin(t * math.pi * 3)
        parts.append((ico((x, 1.05 + 0.08 * math.sin(t * 9), z), 0.24, 1, jitter=0.25, seed=k), "boa"))
    for k in range(5):
        parts.append((ico((3.45, 0.3 - 0.25 * k, 3.2 - 0.38 * k), 0.22, 1, jitter=0.25, seed=40 + k), "boa"))
    heart = []
    for k in range(28):
        t = 2 * math.pi * k / 28
        heart.append((0.05 * 16 * math.sin(t) ** 3, 0.05 * (13 * math.cos(t) - 5 * math.cos(2 * t)
                                                            - 2 * math.cos(3 * t) - math.cos(4 * t)) + 2.45))
    h = extrude([(x, z - 0.55) for x, z in heart], 0.38, y0=-0.05)
    rotate(h, -12, "X", (0, 0.15, 1.8))
    parts.append((h, "pink"))
    return parts


def v3_throne_sofa():
    # Trône du roi du salon : estrade en marbre et tapis rouge, velours capitonné, or, gemmes lumineuses, couronne
    parts = [
        (v3_round((0, 0.1, 0.25), (6.0, 3.8, 0.5), r=0.12, seg=2), "marbleblack"),
        (v3_round((0, 0.15, 0.64), (5.4, 3.4, 0.3), r=0.1, seg=2), "marblewhite"),
        (v3_round((0, -1.55, 0.53), (1.8, 0.9, 0.08), r=0.03, seg=1), "velvet"),
        (v3_round((0, 0.0, 1.18), (4.8, 3.0, 0.8), r=0.2, seg=3), "gold"),
        (fv2_pillow((0, -0.2, 1.8), (3.6, 2.5, 0.6), bulge=0.14), "velvet"),
    ]
    prof = [(-2.4, 1.4)]
    for k in range(25):
        a = math.pi * k / 24
        prof.append((-2.4 * math.cos(a), 5.4 + 1.5 * math.sin(a) ** 1.4))
    prof.append((2.4, 1.4))
    parts.append((extrude(prof, 0.7, y0=0.95), "gold"))
    inner = [(x * 0.82, 1.6 + (z - 1.4) * 0.86) for x, z in prof]
    parts.append((extrude(inner, 0.14, y0=0.83), "velvet"))
    for bm, _ in fv2_tuft_buttons(-1.6, 1.6, 2.2, 5.7, 0.8, 4, 5, r=0.1, color="gold"):
        parts.append((bm, "gold"))
    for s in (-1, 1):
        parts.append((v3_round((s * 2.25, -0.1, 2.25), (0.6, 2.8, 0.5), r=0.18, seg=3), "gold"))
        parts.append((v3_round((s * 2.25, -0.1, 1.78), (0.48, 2.6, 0.5), r=0.12, seg=2), "golddark"))
        parts.append((v3_ball((s * 2.25, -1.55, 2.35), 0.44, 16, 10), "gold"))
        parts.append((v3_ball((s * 2.25, -1.92, 2.35), 0.2, 12, 8), "neon_red"))
        parts.append((v3_ball((s * 2.0, 1.3, 6.65), 0.32, 14, 8), "gold"))
    parts.append((v3_cyl((0, 1.3, 6.68), 0.78, 0.38, 20), "gold"))
    for k in range(6):
        a = 2 * math.pi * k / 6
        parts.append((cone((0.58 * math.cos(a), 1.3 + 0.58 * math.sin(a), 7.0), 0.2, 0.6, 8), "gold"))
        parts.append((v3_ball((0.58 * math.cos(a), 1.3 + 0.58 * math.sin(a), 7.66), 0.1, 8, 5), "neon_red"))
    parts.append((v3_ball((0, 0.58, 6.88), 0.2, 12, 8), "neon_blue"))
    return parts


# ------------------------------------------------------------------ télés
def v3_tube_tv():
    # Télé cathodique sur meuble vintage : écran bombé qui luit, molettes, antennes avec papier d'alu, VHS, console
    parts = [
        (v3_round((0, 0.2, 1.0), (4.0, 1.9, 1.6), r=0.1, seg=2), "wood"),
        (v3_round((0, -0.78, 1.0), (3.6, 0.1, 1.2), r=0.04, seg=1), "wooddark"),
    ]
    for s in (-1, 1):
        parts.append((v3_cyl((s * 1.7, -0.5, 0), 0.07, 0.25, 10, radius_top=0.12), "wooddark"))
        parts.append((v3_cyl((s * 1.7, 0.85, 0), 0.07, 0.25, 10, radius_top=0.12), "wooddark"))
    # VHS empilées et console dans le meuble
    for k in range(3):
        parts.append((v3_round((-0.9, -0.62, 0.55 + 0.27 * k), (1.3, 0.55, 0.24), r=0.03, seg=1), "black"))
        parts.append((v3_round((-0.9, -0.9, 0.55 + 0.27 * k), (0.8, 0.02, 0.12), r=0.0, seg=1), "white"))
    parts.append((v3_round((0.9, -0.6, 0.62), (1.4, 0.7, 0.32), r=0.08, seg=2), "grey"))
    parts.append((v3_ball((0.6, -0.96, 0.66), 0.06, 8, 5), "neon_red"))
    # caisson de la télé
    parts.append((v3_round((0, 0.35, 3.25), (3.1, 2.3, 2.7), r=0.35, seg=4, taper=0.92), "beige"))
    parts.append((v3_round((0, 1.2, 3.25), (2.3, 1.2, 2.0), r=0.3, seg=3), "beige"))
    parts.append((v3_round((-0.35, -0.82, 3.25), (2.2, 0.08, 2.15), r=0.12, seg=2), "charcoal"))
    screen = sphere((-0.35, -0.8, 3.25), (1.0, 0.12, 0.95), 18, 10)
    parts.append((screen, "screencrt"))
    for k, z in enumerate((3.9, 3.35)):
        parts.append((v3_cyl((1.1, -0.8, z), 0.17, 0.12, 14, axis="Y"), "chrome"))
        parts.append((v3_round((1.1, -0.95, z), (0.05, 0.05, 0.22), r=0.02, seg=1), "black"))
    for k in range(4):
        parts.append((v3_round((1.1, -0.82, 2.55 + 0.12 * k), (0.4, 0.04, 0.05), r=0.01, seg=1), "charcoal"))
    # antennes « oreilles de lapin », bout enroulé de papier d'alu
    parts.append((v3_ball((0, 0.6, 4.6), (0.32, 0.32, 0.18), 14, 8), "charcoal"))
    for s in (-1, 1):
        parts.append((segment((s * 0.1, 0.6, 4.65), (s * 1.0, 0.75, 6.0), 0.04, 6), "chrome"))
        parts.append((ico((s * 1.03, 0.76, 6.05), 0.13, 1, jitter=0.3, seed=7 + s), "chrome"))
    return parts


def v3_giant_screen():
    # Home cinéma : écran géant bord à bord, meuble bas laqué, bandeau LED rose, enceintes colonnes, console et manette
    parts = [
        (v3_round((0, 0.2, 0.75), (6.4, 1.6, 1.3), r=0.1, seg=2), "black"),
        (v3_round((0, -0.62, 0.75), (6.2, 0.06, 0.9), r=0.02, seg=1), "wooddark"),
        (v3_round((0, -0.62, 0.12), (6.2, 0.06, 0.06), r=0.0, seg=1), "neon_pink"),
        (v3_round((0, 0.55, 4.05), (8.0, 0.25, 4.6), r=0.08, seg=2), "black"),
        (v3_round((0, 0.4, 4.05), (7.7, 0.06, 4.3), r=0.02, seg=1), "screen"),
        (v3_round((0, 0.6, 1.62), (0.5, 0.3, 0.5), r=0.08, seg=2), "charcoal"),
        (v3_round((0, 0.5, 1.45), (2.4, 0.8, 0.12), r=0.05, seg=2), "charcoal"),
    ]
    # reflet sur l'écran (bande plus claire en biais)
    glare = v3_round((0, 0, 0), (0.9, 0.02, 5.2), r=0.0, seg=1)
    rotate(glare, 35, "Y")
    move(glare, (-2.4, 0.36, 4.05))
    parts.append((glare, "neon_blue"))
    # console et manette
    parts.append((v3_round((1.6, 0.0, 1.5), (1.3, 0.8, 0.2), r=0.08, seg=2), "white"))
    parts.append((v3_round((1.6, -0.42, 1.52), (0.9, 0.02, 0.04), r=0.0, seg=1), "neon_blue"))
    pad = v3_round((-1.6, -0.1, 1.47), (0.8, 0.45, 0.14), r=0.1, seg=2)
    parts.append((pad, "charcoal"))
    for s in (-1, 1):
        parts.append((v3_ball((-1.6 + s * 0.4, -0.15, 1.45), (0.2, 0.2, 0.1), 10, 6), "charcoal"))
    # enceintes colonnes
    for s in (-1, 1):
        x = s * 3.9
        parts.append((v3_round((x, 0.2, 2.3), (0.9, 0.9, 4.6), r=0.12, seg=2), "black"))
        for z, r in ((3.8, 0.34), (2.6, 0.34), (1.2, 0.26)):
            parts.append((v3_cyl((x, -0.25, z), r, 0.06, 20, axis="Y"), "chrome"))
            parts.append((v3_ball((x, -0.26, z), (r * 0.65, 0.1, r * 0.65), 14, 6), "charcoal"))
        parts.append((v3_ball((x, -0.26, 4.4), 0.08, 8, 5), "neon_blue"))
    return parts


# ------------------------------------------------------------------ lits
def v3_mattress():
    # Matelas sur palettes : drap blanc, couette froissée, gros oreiller, réveil, canettes, haltère au pied du lit
    parts = []
    for row in range(2):
        y0 = -1.7 + 3.4 * row
        for k in range(5):
            parts.append((v3_round((-2.3 + 1.15 * k, y0, 0.32), (0.85, 3.3, 0.14), r=0.03, seg=1), "pallet"))
            parts.append((v3_round((-2.3 + 1.15 * k, y0, 0.08), (0.85, 3.3, 0.14), r=0.03, seg=1), "pallet"))
        for y in (y0 - 1.35, y0, y0 + 1.35):
            parts.append((v3_round((0, y, 0.2), (5.6, 0.45, 0.28), r=0.04, seg=1), "pallet"))
    parts.append((v3_round((0, 0, 0.75), (5.2, 6.6, 0.75), r=0.3, seg=3), "sheet"))
    duvet = v3_round((0, -0.9, 1.18), (5.35, 4.8, 0.32), r=0.15, seg=3, bulge=0.12)
    for v in duvet.verts:  # plis
        if v.co.z > 1.18:
            v.co.z += 0.08 * math.sin(v.co.x * 2.2 + v.co.y * 1.3)
        if v.co.y > 1.2:
            v.co.z += 0.18 * (v.co.y - 1.2)
    parts.append((duvet, "duvet"))
    turn = v3_round((0, 1.55, 1.48), (5.2, 0.5, 0.22), r=0.1, seg=2)
    rotate(turn, -14, "X", (0, 1.55, 1.48))
    parts.append((turn, "duvetlight"))
    parts.append((fv2_pillow((0, 2.65, 1.4), (3.0, 1.15, 0.55), bulge=0.18), "pillow"))
    # réveil (cloches) et canettes
    parts.append((v3_cyl((2.95, 2.5, 0), 0.38, 0.75, 20, axis="Z"), "red"))
    parts.append((v3_cyl((2.95, 2.12, 0.15), 0.3, 0.04, 20, axis="Y"), "white"))
    for s in (-1, 1):
        parts.append((v3_ball((2.95 + s * 0.24, 2.5, 0.82), 0.14, 10, 6), "chrome"))
    for k, look in enumerate(("can_red", "can_green", "can_red")):
        can = v3_cyl((-2.95 + 0.1 * k, -2.6 + 0.45 * k, 0), 0.16, 0.5, 14)
        if k == 2:
            rotate(can, 90, "X", (-2.85, -1.7, 0.16))
        parts.append((can, look))
    parts += v3_dumbbell((1.2, -3.55, 0.32), 1.5, 0.07, 0.32, 0.16, look="iron", bar="chrome", plates=1)
    return parts


def v3_race_car_bed():
    # Lit voiture de course : carrosserie rouge laquée, bandes blanches, matelas damier, aileron, jantes chromées,
    # phares allumés, pare-brise en verre en guise de tête de lit
    parts = []
    body = v3_round((0, 0.1, 1.05), (5.2, 7.2, 1.5), r=0.55, seg=4)
    for v in body.verts:  # capot plongeant vers l'avant
        if v.co.y < -2.0 and v.co.z > 1.0:
            v.co.z -= (abs(v.co.y) - 2.0) * 0.32
    parts.append((body, "carred"))
    for s in (-1, 1):
        stripe = v3_round((s * 0.55, -1.6, 1.62), (0.35, 3.8, 0.06), r=0.02, seg=1)
        for v in stripe.verts:
            if v.co.y < -2.0:
                v.co.z -= (abs(v.co.y) - 2.0) * 0.32
        parts.append((stripe, "carwhite"))
    parts.append((v3_round((0, 0.9, 1.9), (4.3, 5.0, 0.42), r=0.18, seg=3), "tex:checker"))
    parts.append((fv2_pillow((0, 2.85, 2.25), (2.6, 0.9, 0.42), bulge=0.14), "pillow"))
    # pare-brise (tête de lit)
    ws = v3_round((0, 3.65, 2.7), (4.4, 0.18, 1.3), r=0.08, seg=2, taper=0.85)
    rotate(ws, 12, "X", (0, 3.65, 2.7))
    parts.append((ws, "glass"))
    parts.append((v3_round((0, 3.7, 2.05), (4.6, 0.3, 0.2), r=0.08, seg=2), "black"))
    # aileron
    for s in (-1, 1):
        parts.append((v3_round((s * 1.9, 3.95, 3.25), (0.18, 0.4, 1.0), r=0.05, seg=2), "black"))
    parts.append((v3_round((0, 4.05, 3.85), (5.0, 0.9, 0.16), r=0.07, seg=2), "carred"))
    # roues
    for x in (-2.65, 2.65):
        for y in (-2.4, 2.6):
            s = 1 if x > 0 else -1
            parts.append((v3_cyl((x - 0.3, y, 0.82), 0.82, 0.6, 24, axis="X", bevel=0.12), "rubber"))
            rim_x = x + 0.3 if s > 0 else x - 0.36
            parts.append((v3_cyl((rim_x, y, 0.82), 0.5, 0.06, 20, axis="X"), "chrome"))
            for k in range(5):
                a = 2 * math.pi * k / 5
                parts.append((segment((x + s * 0.34, y, 0.82),
                                      (x + s * 0.34, y + 0.42 * math.cos(a), 0.82 + 0.42 * math.sin(a)), 0.05, 6),
                              "chrome"))
    # phares et calandre
    for s in (-1, 1):
        parts.append((v3_ball((s * 1.75, -3.45, 0.95), (0.45, 0.12, 0.28), 14, 8), "neon_warm"))
    parts.append((v3_round((0, -3.55, 0.65), (2.0, 0.1, 0.35), r=0.05, seg=1), "black"))
    for bm, _ in parts:  # ramené à l'encombrement de l'emplacement du lit (≈ 5,5 × 7)
        scale(bm, (0.92, 0.86, 0.92))
    return parts


# ------------------------------------------------------------------ tapis
def v3_pizza_rug():
    # Tapis pizza : croûte dorée bombée, fromage, rondelles de pepperoni, basilic, une part qui manque
    parts = []
    gap = (math.radians(-110), math.radians(-70))

    def arc_ok(a):
        return not (gap[0] < a < gap[1])

    pts = [(0, 0)]
    n = 48
    for k in range(n + 1):
        a = gap[1] + (2 * math.pi - (gap[1] - gap[0])) * k / n
        pts.append((3.2 * math.cos(a), -3.2 * math.sin(a)))  # (x, -y) : la rotation remet y à l'endroit
    cheese = extrude(pts, 0.14, y0=0)
    rotate(cheese, 90, "X")
    parts.append((cheese, "cheese"))
    for k in range(40):
        a0 = gap[1] + (2 * math.pi - (gap[1] - gap[0])) * k / 40
        a1 = gap[1] + (2 * math.pi - (gap[1] - gap[0])) * (k + 1) / 40
        parts.append((segment((3.45 * math.cos(a0), 3.45 * math.sin(a0), 0.18),
                              (3.45 * math.cos(a1), 3.45 * math.sin(a1), 0.18), 0.28, 8), "crust"))
    for x, y in ((-1.6, 0.9), (1.2, 1.6), (0.3, -0.2), (-0.8, -1.8), (2.1, -0.6), (-2.3, -0.6), (-0.2, 2.4),
                 (1.6, -1.9)):
        if arc_ok(math.atan2(y, x)):
            parts.append((v3_cyl((x, y, 0.13), 0.48, 0.07, 20, bevel=0.02), "pepperoni"))
    for k, (x, y) in enumerate(((-0.6, 1.2), (0.9, 0.4), (-1.5, -0.9), (1.8, 0.8))):
        parts.append((v3_leaf((x, y, 0.2), 0.55, 0.3, k * 70, 0), "basil"))
    return parts


def v3_zebra_rug():
    # Peau de zèbre : vraie silhouette (pattes, tête, queue), bord ourlé noir
    outline = []
    n = 96
    for k in range(n):
        t = 2 * math.pi * k / n
        r = 1.0 + 0.16 * math.cos(4 * t) + 0.05 * math.cos(8 * t)
        outline.append((4.1 * r * math.cos(t), 2.75 * r * math.sin(t)))
    # pattes et tête ajoutées en bosses
    shaped = []
    for x, y in outline:
        t = math.atan2(y / 2.75, x / 4.1)
        bump = 0.0
        for c in (math.radians(40), math.radians(140), math.radians(220), math.radians(320)):
            d = (t - c + math.pi) % (2 * math.pi) - math.pi
            bump += 0.35 * math.exp(-(d / 0.18) ** 2)
        d = (t + math.pi) % (2 * math.pi) - math.pi  # tête à droite (angle 0)
        bump += 0.25 * math.exp(-(d / 0.22) ** 2)
        k = 1 + bump
        shaped.append((x * k, y * k))
    rug = extrude([(x, -y) for x, y in shaped], 0.06, y0=0)
    rotate(rug, 90, "X")
    parts = [(rug, "rugcream")]
    # rayures noires en vraie géométrie (ondulées, plus fines vers les bords), coupées à la silhouette
    poly = shaped

    def inside(px, py):
        c = False
        j = len(poly) - 1
        for i in range(len(poly)):
            xi, yi = poly[i]
            xj, yj = poly[j]
            if (yi > py) != (yj > py) and px < (xj - xi) * (py - yi) / (yj - yi + 1e-9) + xi:
                c = not c
            j = i
        return c

    for k in range(11):
        x0 = -5.0 + 1.0 * k
        width = 0.42 - 0.12 * abs(x0) / 5.0
        pts = []
        steps = 40
        for i in range(steps + 1):
            y = -4.2 + 8.4 * i / steps
            x = x0 + 0.45 * math.sin(y * 0.9 + k * 1.3) + 0.2 * math.sin(y * 2.1)
            pts.append((x, y))
        for (xa, ya), (xb, yb) in zip(pts, pts[1:]):
            if inside(xa * 1.03, ya * 1.03) and inside(xb * 1.03, yb * 1.03):
                stripe = segment((xa, ya, 0.065), (xb, yb, 0.065), width / 2, 6)
                scale(stripe, (1, 1, 0.08), (0, 0, 0.065))  # aplatie : une bande, pas un tube
                parts.append((stripe, "black_fabric"))
    for (x0, y0), (x1, y1) in zip(shaped, shaped[1:] + shaped[:1]):
        parts.append((segment((x0, y0, 0.04), (x1, y1, 0.04), 0.06, 5), "black_fabric"))
    return parts


def v3_gold_rug():
    # Tapis persan : bordures en couches, médaillon central, motifs d'angle, franges dorées
    parts = [
        (v3_round((0, 0, 0.04), (10.4, 7.0, 0.08), r=0.03, seg=1), "rugred"),
        (v3_round((0, 0, 0.09), (9.6, 6.2, 0.04), r=0.0, seg=1), "ruggold"),
        (v3_round((0, 0, 0.11), (9.2, 5.8, 0.04), r=0.0, seg=1), "rugnavy"),
        (v3_round((0, 0, 0.13), (8.6, 5.2, 0.04), r=0.0, seg=1), "rugred"),
    ]
    med = [(2.4 * math.cos(2 * math.pi * k / 16) * (1 if k % 2 == 0 else 0.62),
            1.7 * math.sin(2 * math.pi * k / 16) * (1 if k % 2 == 0 else 0.62)) for k in range(16)]
    m = extrude(med, 0.04, y0=0)
    rotate(m, 90, "X")
    move(m, (0, 0, 0.17))
    parts.append((m, "ruggold"))
    inner = extrude([(x * 0.55, y * 0.55) for x, y in med], 0.04, y0=0)
    rotate(inner, 90, "X")
    move(inner, (0, 0, 0.19))
    parts.append((inner, "rugnavy"))
    parts.append((v3_cyl((0, 0, 0.19), 0.35, 0.04, 16), "rugcream"))
    for sx in (-1, 1):
        for sy in (-1, 1):
            corner = extrude([(0, 0), (-sx * 1.3, 0), (0, sy * 0.95)], 0.04, y0=0)
            rotate(corner, 90, "X")  # profil (x, z) -> (x, -y) : la pointe vise le centre
            move(corner, (sx * 4.25, sy * 2.55, 0.17))
            parts.append((corner, "ruggold"))
    for s in (-1, 1):
        for k in range(23):
            y = -3.3 + 0.3 * k
            parts.append((segment((s * 5.2, y, 0.03), (s * 5.55, y, 0.02), 0.045, 4), "ruggold"))
    return parts


# ------------------------------------------------------------------ décoration murale (dos contre le mur, +Y)
def v3_flex_poster():
    # Affiche « flex » : cadre bois, fond jaune à rayons, bras qui fait le biceps en relief, étoiles
    parts = v3_frame(4.0, 5.0, 0.28, 0.32, "wooddark")
    parts.append((v3_round((0, 0.05, 2.5), (3.5, 0.06, 4.5), r=0.0, seg=1), "posterbg"))
    for k in range(10):
        a = 2 * math.pi * k / 10
        ray = extrude([(0, 0), (2.6 * math.cos(a - 0.12), 2.6 * math.sin(a - 0.12)),
                       (2.6 * math.cos(a + 0.12), 2.6 * math.sin(a + 0.12))], 0.02, y0=0)
        for v in ray.verts:
            v.co.x = max(-1.7, min(1.7, v.co.x))
            v.co.z = max(-2.2, min(2.2, v.co.z))
        move(ray, (0.3, -0.0, 2.7))
        parts.append((ray, "posterray"))
    # silhouette de culturiste en double biceps, en relief (aplatie contre l'affiche)
    figure = v3_figure((0.0, 0.0, 0.0), 1.15, "skin")
    for bm, _ in figure:
        scale(bm, (1, 0.35, 1))
        move(bm, (0.15, -0.12, 0.55))
    parts += figure
    parts.append((v3_round((0.15, -0.2, 2.05), (1.0, 0.1, 0.28), r=0.08, seg=2), "sweatband"))
    for x, z in ((-1.1, 3.6), (1.3, 1.1), (-1.2, 2.5)):
        star = extrude([(0.25 * math.cos(math.pi / 2 + k * math.pi / 5) * (1 if k % 2 == 0 else 0.45),
                         0.25 * math.sin(math.pi / 2 + k * math.pi / 5) * (1 if k % 2 == 0 else 0.45))
                        for k in range(10)], 0.05, y0=-0.05)
        move(star, (x, -0.02, z))
        parts.append((star, "white"))
    return parts


def v3_sunset_poster():
    # Affiche rétro : soleil à bandes qui luit, palmier en ombre chinoise, grille néon rose, cadre noir
    parts = v3_frame(6.0, 4.0, 0.28, 0.28, "black")
    parts.append((v3_round((0, 0.05, 2.0), (5.5, 0.06, 3.5), r=0.0, seg=1), "tex:sunset"))
    for k in range(5):
        z = 2.0 + 0.2 * k
        w = 2 * math.sqrt(max(0.0, 1.1 ** 2 - (z - 2.1) ** 2))
        parts.append((v3_round((0.4, -0.02, z + 0.06), (w, 0.04, 0.12), r=0.0, seg=1), "neon_sun"))
    for k in range(6):
        parts.append((v3_round((0, -0.02, 0.45 + 0.17 * k), (5.4, 0.03, 0.03), r=0.0, seg=1), "neon_pink"))
    for k in range(9):
        x = -2.4 + 0.6 * k
        parts.append((segment((x * 0.35, -0.03, 1.4), (x, -0.03, 0.32), 0.02, 4), "neon_pink"))
    trunk = [(-1.65 + 0.05 * math.sin(k * 0.6), 0.4 + 0.25 * k) for k in range(9)]
    for (x0, z0), (x1, z1) in zip(trunk, trunk[1:]):
        parts.append((segment((x0, -0.05, z0), (x1, -0.05, z1), 0.09, 6), "palm"))
    for k in range(7):
        a = math.radians(-20 + 32 * k)
        frond = v3_leaf((0, 0, 0), 1.0, 0.32, 0, 0, thick=0.03)
        rotate(frond, 90, "X")
        rotate(frond, math.degrees(a) - 90, "Y")
        move(frond, (trunk[-1][0], -0.07, trunk[-1][1]))
        parts.append((frond, "palm"))
    return parts


def v3_neon_dumbbell():
    # Enseigne néon : plaque d'acrylique fumé, haltère en tubes néon cyan, barre rose, entretoises chromées
    parts = [(v3_round((0, 0.1, 1.6), (6.0, 0.12, 3.2), r=0.25, seg=3), "acrylic")]
    for x in (-2.7, 2.7):
        for z in (0.35, 2.85):
            parts.append((v3_cyl((x, -0.0, z), 0.09, 0.3, 12, axis="Y"), "chrome"))
    parts.append((segment((-1.9, -0.05, 1.6), (1.9, -0.05, 1.6), 0.07, 10), "neon_pink"))
    for s in (-1, 1):
        for x0, h in ((1.9, 1.0), (2.35, 0.7)):
            x = s * x0
            loop = [(x - 0.17, 1.6 - h), (x + 0.17, 1.6 - h), (x + 0.17, 1.6 + h), (x - 0.17, 1.6 + h),
                    (x - 0.17, 1.6 - h)]
            for (a, za), (b, zb) in zip(loop, loop[1:]):
                parts.append((segment((a, -0.08, za), (b, -0.08, zb), 0.07, 10), "neon_cyan"))
            for xx, zz in loop[:4]:
                parts.append((v3_ball((xx, -0.08, zz), 0.07, 10, 6), "neon_cyan"))
    # petit éclair de « puissance »
    bolt = extrude([(0, 0.5), (0.25, 0.05), (0.08, 0.05), (0.2, -0.5), (-0.15, 0.1), (0.05, 0.1)], 0.06, y0=-0.12)
    move(bolt, (0, 0, 2.55))
    parts.append((bolt, "neon_orange"))
    return parts


# ------------------------------------------------------------------ plantes
def v3_cactus():
    # Cactus de salle de sport : pot en terre cuite à rebord, cactus à bras avec bandeau de sport et fleur rose
    parts = [
        (v3_cyl((0, 0, 0), 0.72, 1.3, 24, radius_top=0.92), "terracotta"),
        (v3_cyl((0, 0, 1.2), 1.02, 0.34, 24, bevel=0.06), "terracottadark"),
        (v3_cyl((0, 0, 1.4), 0.86, 0.1, 24), "soil"),
    ]
    trunk = v3_round((0, 0, 2.75), (1.0, 1.0, 2.9), r=0.48, seg=4)
    parts.append((trunk, "cactus"))
    for s, z0, h in ((-1, 2.4, 1.1), (1, 2.9, 0.9)):
        parts.append((segment((s * 0.4, 0, z0), (s * 0.95, 0, z0), 0.24, 12), "cactus"))
        parts.append((v3_round((s * 1.05, 0, z0 + h / 2), (0.5, 0.5, h + 0.3), r=0.24, seg=3), "cactus"))
    # côtes et épines
    for k in range(8):
        a = 2 * math.pi * k / 8
        for z in (2.0, 2.6, 3.2, 3.8):
            x, y = 0.52 * math.cos(a), 0.52 * math.sin(a)
            parts.append((cone((x, y, z), 0.025, 0.14, 4), "white"))
    parts.append((v3_round((0, 0, 3.35), (1.06, 1.06, 0.26), r=0.12, seg=2), "sweatband"))
    for k in range(6):
        a = 2 * math.pi * k / 6
        petal = v3_ball((0.16 * math.cos(a), 0.16 * math.sin(a), 4.25), (0.18, 0.18, 0.08), 10, 6)
        parts.append((petal, "flower"))
    parts.append((v3_ball((0, 0, 4.3), 0.09, 8, 5), "yellow"))
    return parts


def v3_shaker_plant():
    # Plante dans un shaker géant : gobelet noir, fenêtre graduée, couvercle orange, grandes feuilles de monstera
    parts = [
        (v3_cyl((0, 0, 0), 0.95, 2.9, 24, radius_top=1.05), "black"),
        (v3_round((0, -0.98, 1.45), (0.5, 0.08, 2.2), r=0.04, seg=1), "screenglass"),
        (v3_cyl((0, 0, 2.85), 1.12, 0.45, 24, bevel=0.06), "orange"),
        (v3_cyl((0, 0, 3.25), 0.9, 0.08, 24), "soil"),
    ]
    for k in range(6):
        parts.append((v3_round((0.0, -1.01, 0.6 + 0.32 * k), (0.28 if k % 2 else 0.45, 0.03, 0.04), r=0.0, seg=1),
                      "white"))
    parts.append((v3_round((0.75, -0.4, 3.1), (0.35, 0.35, 0.3), r=0.1, seg=2), "orange"))
    for k in range(7):
        yaw = k * 51
        pitch = 25 + 12 * (k % 3)
        stem_top = (0.6 * math.cos(math.radians(yaw + 90)), 0.6 * math.sin(math.radians(yaw + 90)), 4.3 + 0.25 * (k % 3))
        parts.append((segment((0, 0, 3.2), stem_top, 0.05, 6), "leafdark"))
        leaf = v3_leaf((0, 0, 0), 1.6, 1.25, 0, pitch, thick=0.05)
        rotate(leaf, yaw, "Z")
        move(leaf, stem_top)
        parts.append((leaf, "leaf" if k % 2 else "leafdark"))
    return parts


# ------------------------------------------------------------------ lampes
def v3_lava_lamp():
    # Lampe à lave : socle chromé conique, ampoule de verre, bulles de lave lumineuses, capuchon
    parts = [
        (v3_cyl((0, 0, 0), 0.75, 1.2, 24, radius_top=0.42), "chrome"),
        (v3_cyl((0, 0, 1.15), 0.44, 0.1, 24), "iron"),
        (v3_cyl((0, 0, 1.25), 0.44, 2.6, 24, radius_top=0.3), "glass"),
        (v3_cyl((0, 0, 3.82), 0.31, 0.75, 24, radius_top=0.12), "chrome"),
    ]
    for (x, z, r) in ((0.05, 1.6, 0.28), (-0.08, 2.25, 0.2), (0.1, 2.8, 0.15), (-0.05, 3.35, 0.12)):
        parts.append((v3_ball((x, 0, z), (r, r, r * 1.3), 14, 8), "neon_pink"))
    parts.append((v3_ball((0, 0, 1.38), (0.36, 0.36, 0.12), 14, 6), "neon_orange"))
    return parts


def v3_dumbbell_lamp():
    # Lampadaire de bro : disque de fonte en socle, barre chromée en pied, abat-jour tissu, ampoule qui luit
    parts = v3_plate((0, 0, 0.22), 1.35, 0.44, look="iron", hub="chrome", axis="Z")
    parts.append((v3_cyl((0, 0, 0.4), 0.12, 5.2, 16), "chrome"))
    for z in (2.2, 2.35, 2.5, 2.65):
        parts.append((torus((0, 0, z), 0.125, 0.025, 16, 4), "steel"))
    parts.append((v3_cyl((0, 0, 0.44), 0.32, 0.25, 16, bevel=0.04), "steel"))
    parts.append((v3_ball((0, 0, 5.15), (0.32, 0.32, 0.42), 14, 8), "neon_warm"))
    shade = v3_cyl((0, 0, 4.55), 1.5, 1.6, 28, radius_top=0.95)
    parts.append((shade, "shade"))
    parts.append((torus((0, 0, 4.57), 1.5, 0.05, 28, 4), "golddark"))
    parts.append((torus((0, 0, 6.13), 0.95, 0.05, 28, 4), "golddark"))
    parts.append((segment((0.5, 0, 5.0), (0.5, 0, 4.2), 0.015, 4), "brass"))
    parts.append((v3_ball((0.5, 0, 4.15), 0.06, 8, 5), "brass"))
    return parts


# ------------------------------------------------------------------ trophées
def v3_pedestal(w, d, h, look="wood", top="wooddark", plaque="brass"):
    return [
        (v3_round((0, 0.2, h / 2), (w, d, h), r=0.1, seg=2), look),
        (v3_round((0, 0.2, h + 0.08), (w + 0.25, d + 0.25, 0.16), r=0.06, seg=2), top),
        (v3_round((0, 0.2, 0.08), (w + 0.25, d + 0.25, 0.16), r=0.06, seg=2), top),
        (v3_round((0, 0.2 - d / 2 - 0.02, h * 0.55), (w * 0.55, 0.05, h * 0.25), r=0.03, seg=1), plaque),
    ]


def v3_figure(center, s, look):
    """Petit bonhomme qui fait le double biceps (trophée)."""
    x, y, z = center
    parts = [
        (v3_ball((x, y, z + 1.3 * s), (0.42 * s, 0.3 * s, 0.5 * s), 12, 8), look),  # torse
        (v3_ball((x, y, z + 1.95 * s), 0.22 * s, 10, 6), look),  # tête
        (segment((x - 0.15 * s, y, z + 0.85 * s), (x - 0.22 * s, y, z), 0.1 * s, 8), look),
        (segment((x + 0.15 * s, y, z + 0.85 * s), (x + 0.22 * s, y, z), 0.1 * s, 8), look),
    ]
    for sx in (-1, 1):
        parts.append((segment((x + sx * 0.38 * s, y, z + 1.55 * s), (x + sx * 0.85 * s, y, z + 1.6 * s), 0.13 * s, 8),
                      look))
        parts.append((v3_ball((x + sx * 0.65 * s, y - 0.03 * s, z + 1.7 * s), (0.17 * s, 0.13 * s, 0.15 * s), 10, 6),
                      look))
        parts.append((segment((x + sx * 0.85 * s, y, z + 1.6 * s), (x + sx * 0.8 * s, y, z + 2.15 * s), 0.11 * s, 8),
                      look))
        parts.append((v3_ball((x + sx * 0.8 * s, y, z + 2.22 * s), 0.12 * s, 8, 5), look))
    return parts


def v3_bronze_cup():
    # Coupe de bronze sur socle en bois verni, plaque en laiton, petit culturiste au sommet
    parts = v3_pedestal(2.6, 1.6, 2.4)
    parts.append((v3_cyl((0, 0.2, 2.56), 0.6, 0.25, 20, bevel=0.05), "bronze"))
    parts.append((v3_cyl((0, 0.2, 2.8), 0.12, 0.6, 14, radius_top=0.18), "bronze"))
    cup = v3_cyl((0, 0.2, 3.35), 0.22, 1.0, 24, radius_top=0.72)
    parts.append((cup, "bronze"))
    parts.append((torus((0, 0.2, 4.35), 0.7, 0.06, 24, 6), "bronze"))
    for s in (-1, 1):
        parts.append((torus((s * 0.78, 0.2, 3.9), 0.28, 0.07, 16, 6, axis="Y"), "bronze"))
    parts += v3_figure((0, 0.2, 4.35), 0.42, "gold")
    return parts


def v3_golden_dumbbell():
    # Haltère en or dans une vitrine : socle en marbre noir, coussin de velours, cloche de verre, spot lumineux
    parts = v3_pedestal(2.6, 1.6, 2.4, look="marbleblack", top="gold", plaque="gold")
    parts.append((fv2_pillow((0, 0.2, 2.75), (2.2, 1.3, 0.4), bulge=0.12), "velvet"))
    parts += v3_dumbbell((0, 0.2, 3.3), 2.5, 0.09, 0.55, 0.22, look="gold", bar="gold", plates=2)
    parts.append((v3_round((0, 0.2, 3.9), (2.75, 1.75, 2.0), r=0.12, seg=2), "glass"))
    parts.append((v3_round((0, 0.2, 4.95), (2.85, 1.85, 0.14), r=0.05, seg=2), "gold"))
    parts.append((v3_ball((0, 0.2, 4.88), (0.25, 0.25, 0.06), 12, 5), "neon_warm"))
    return parts


def v3_bicep_statue():
    # Buste de marbre du « Giga Mogger » en double biceps : socle noir et or, torse en V, pectoraux, abdos,
    # trapèzes, biceps en boule, mâchoire carrée démesurée et banane de cheveux
    M = "marble"
    parts = [
        (v3_round((0, 0.3, 0.45), (3.6, 2.2, 0.9), r=0.12, seg=2), "marbleblack"),
        (v3_round((0, 0.3, 0.95), (3.8, 2.4, 0.12), r=0.05, seg=2), "gold"),
        (v3_round((0, -0.82, 0.45), (1.4, 0.05, 0.4), r=0.03, seg=1), "gold"),
        (v3_round((0, 0.38, 1.75), (1.3, 0.8, 1.55), r=0.36, seg=4, taper=1.75), M),  # torse en V
        (v3_ball((0, 0.42, 2.55), (0.95, 0.45, 0.32), 18, 10), M),  # trapèzes
        (v3_cyl((0, 0.32, 2.5), 0.3, 0.45, 18, radius_top=0.27), M),  # cou
    ]
    for sx in (-1, 1):
        parts.append((v3_ball((sx * 0.42, -0.08, 2.18), (0.54, 0.34, 0.38), 18, 10), M))  # pectoraux
        for row in range(3):
            parts.append((v3_round((sx * 0.2, 0.0, 1.72 - 0.26 * row), (0.34, 0.22, 0.22), r=0.09, seg=2), M))
        parts.append((v3_ball((sx * 1.22, 0.3, 2.42), 0.42, 18, 10), M))  # épaules
        parts.append((segment((sx * 1.2, 0.3, 2.45), (sx * 1.95, 0.3, 2.5), 0.27, 16), M))  # bras
        parts.append((v3_ball((sx * 1.6, 0.17, 2.72), (0.38, 0.3, 0.34), 18, 10), M))  # biceps
        parts.append((v3_ball((sx * 1.97, 0.3, 2.5), 0.27, 14, 8), M))  # coude
        parts.append((segment((sx * 1.97, 0.3, 2.5), (sx * 1.9, 0.3, 3.35), 0.26, 16, radius1=0.2), M))
        parts.append((v3_ball((sx * 1.88, 0.24, 3.55), (0.27, 0.25, 0.28), 14, 8), M))  # poing
    parts += [
        (v3_round((0, 0.28, 3.3), (0.74, 0.8, 0.95), r=0.3, seg=4), M),  # tête
        (v3_round((0, 0.12, 2.98), (0.92, 0.72, 0.42), r=0.14, seg=3), M),  # mâchoire carrée
        (v3_round((0, -0.08, 3.5), (0.72, 0.2, 0.12), r=0.05, seg=2), M),  # arcades
        (v3_round((0, -0.13, 3.27), (0.14, 0.18, 0.3), r=0.06, seg=2), M),  # nez
        (v3_round((0, 0.18, 3.85), (0.82, 0.95, 0.28), r=0.12, seg=3, bulge=0.06), M),  # banane
    ]
    for sx in (-1, 1):
        parts.append((v3_ball((sx * 0.4, 0.3, 3.3), (0.08, 0.14, 0.18), 10, 6), M))  # oreilles
    return parts


V3_ITEMS = [
    ("SaggyCouch", v3_saggy_couch), ("BenchSofa", v3_bench_sofa), ("LeopardSofa", v3_leopard_sofa),
    ("ThroneSofa", v3_throne_sofa), ("TubeTv", v3_tube_tv), ("GiantScreen", v3_giant_screen),
    ("Mattress", v3_mattress), ("RaceCarBed", v3_race_car_bed), ("PizzaRug", v3_pizza_rug),
    ("ZebraRug", v3_zebra_rug), ("GoldRug", v3_gold_rug), ("FlexPoster", v3_flex_poster),
    ("SunsetPoster", v3_sunset_poster), ("NeonDumbbell", v3_neon_dumbbell), ("Cactus", v3_cactus),
    ("ShakerPlant", v3_shaker_plant), ("LavaLamp", v3_lava_lamp), ("DumbbellLamp", v3_dumbbell_lamp),
    ("BronzeCup", v3_bronze_cup), ("GoldenDumbbell", v3_golden_dumbbell), ("BicepStatue", v3_bicep_statue),
]


def furniture_v3(P, only=None):
    for item_id, build in V3_ITEMS:
        if only and item_id not in only:
            continue
        v3_prop(P, f"Furniture_{item_id}", build())

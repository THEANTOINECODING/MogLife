"""Tenues Robux refaites (D125) : huit tenues « légendaires » construites sur les corps réels de chaque stade.

Chargé par outfit_looks.py (donc par build_style.py et preview_premium.py). Aucun prix ici.

Ce qui les distingue des tenues à Cash (recherche D125, design/RECHERCHE_TENUES_2026-11-09.md) :
- une silhouette lisible de loin : casque, cornes, couronne ou auréole sur la tête, épaulières, ailes, cape ;
- une armure en couches : sous-tenue sombre, plaques qui épousent les muscles (_patch), liserés ;
- des pièces lumineuses : <Partie>_Glow / _GlowB (sur la tenue) et _GlowDeco / _GlowBDeco (décorations). Dans le jeu
  elles passent en matériau Néon, à la couleur de StyleSets.Glow (BodyService, Outfit) : fissures de lave, lignes
  d'énergie, auréoles ;
- des bottes et des gants : la tenue couvre tout le corps, plus de baskets du stade.
Les pièces _Deco (et _GlowDeco) ne gonflent pas avec le pump (BodyService) ; les _Glow suivent leur vêtement.
"""

import math
from mathutils import Vector

TAU = 2 * math.pi

# id, palette (base, plaque, liseré, sombre, extra), sous-tenue haute, bas, couleur de lueur A et B (aperçu Blender ;
# celles du jeu sont dans src/shared/Config/StyleSets.luau, Glow)
PREMIUM = {
    "CosmicEmperor": dict(
        colors=((0.05, 0.04, 0.17), (0.30, 0.11, 0.62), (1.0, 0.78, 0.30), (0.025, 0.02, 0.07), (0.42, 0.16, 0.66)),
        silhouette="cape", lower="straight", glow=((0.80, 0.68, 1.0), (1.0, 0.85, 0.45))),
    "GoldenTitan": dict(
        colors=((0.07, 0.06, 0.07), (0.98, 0.70, 0.18), (1.0, 0.88, 0.50), (0.30, 0.15, 0.05), (1.0, 0.42, 0.05)),
        silhouette="armor", lower="straight", glow=((1.0, 0.42, 0.06), (1.0, 0.85, 0.40))),
    "NeonPhantom": dict(
        colors=((0.035, 0.04, 0.055), (0.12, 0.13, 0.17), (0.10, 0.95, 1.0), (0.015, 0.015, 0.025), (1.0, 0.15, 0.75)),
        silhouette="hoodie", lower="taper", glow=((0.10, 0.95, 1.0), (1.0, 0.16, 0.78))),
    "GymDragon": dict(
        colors=((0.04, 0.36, 0.17), (0.10, 0.55, 0.26), (0.98, 0.72, 0.30), (0.03, 0.10, 0.06), (0.88, 0.24, 0.07)),
        silhouette="armor", lower="straight", glow=((1.0, 0.45, 0.06), (1.0, 0.82, 0.30))),
    "EternalSun": dict(
        colors=((0.97, 0.95, 0.90), (1.0, 0.76, 0.22), (1.0, 0.45, 0.08), (0.55, 0.32, 0.10), (0.10, 0.28, 0.75)),
        silhouette="robe", lower="straight", glow=((1.0, 0.80, 0.30), (1.0, 0.97, 0.85))),
    "MechaMogger": dict(
        colors=((0.10, 0.11, 0.14), (0.92, 0.94, 0.97), (0.10, 0.85, 1.0), (0.04, 0.05, 0.07), (1.0, 0.45, 0.10)),
        silhouette="armor", lower="straight", glow=((0.10, 0.88, 1.0), (0.85, 1.0, 1.0))),
    "MarbleStatue": dict(
        colors=((0.95, 0.94, 0.91), (0.83, 0.83, 0.85), (1.0, 0.80, 0.30), (0.42, 0.42, 0.45), (0.93, 0.92, 0.88)),
        silhouette="cape", lower="straight", glow=((1.0, 0.78, 0.28), (1.0, 0.96, 0.80))),
    "InfernalDemon": dict(
        colors=((0.07, 0.045, 0.05), (0.52, 0.035, 0.045), (0.14, 0.11, 0.12), (0.025, 0.015, 0.02), (0.88, 0.82, 0.70)),
        silhouette="armor", lower="straight", glow=((1.0, 0.22, 0.04), (1.0, 0.60, 0.10))),
}
PREMIUM_ORDER = ("CosmicEmperor", "GoldenTitan", "NeonPhantom", "GymDragon",
                 "EternalSun", "MechaMogger", "MarbleStatue", "InfernalDemon")
CHANNELS = ("base", "plate", "trim", "dark", "extra")
GLOW_COLORS = {name: spec["glow"][0] for name, spec in PREMIUM.items()}
GLOW_COLORS_B = {name: spec["glow"][1] for name, spec in PREMIUM.items()}


# ------------------------------------------------------------------ texture : 5 cases par tenue (colonnes 8 à 15,
# rangées 8 à 12, libres dans l'atlas)
def _clamp(c):
    return tuple(max(0.0, min(1.0, x)) for x in c)


def _mix(a, b, t):
    return tuple(a[k] * (1 - t) + b[k] * t for k in range(3))


def _hash(u, v, seed=0):
    return ((u * 73856093) ^ (v * 19349663) ^ (seed * 83492791)) % 1000 / 1000


def paint_premium_cells(atlas):
    for index, name in enumerate(PREMIUM_ORDER):
        spec = PREMIUM[name]
        for row, channel in enumerate(CHANNELS):
            rgb = spec["colors"][row]

            def painted(u, v, rgb=rgb, name=name, channel=channel, seed=index * 7 + row):
                # Base commune : dégradé doux (lumière d'en haut) et grain très léger, jamais de motif « brique »
                k = 0.86 + 0.24 * (v / 31)
                c = tuple(x * k for x in rgb)
                grain = (_hash(u, v, seed) - 0.5) * 0.035
                c = tuple(x + grain for x in c)
                if channel in ("plate", "trim"):
                    # Métal ou laque : un reflet en diagonale
                    shine = max(0.0, 1 - abs((u - v * 0.7) - 6) / 5)
                    c = _mix(c, (1, 1, 1), shine * (0.32 if channel == "trim" else 0.18))
                if name == "CosmicEmperor" and channel in ("base", "extra"):
                    # Ciel étoilé : quelques étoiles et une nébuleuse violette
                    neb = 0.5 + 0.5 * math.sin(u * 0.35 + math.sin(v * 0.3) * 2.2)
                    c = _mix(c, (0.35, 0.12, 0.55), neb * 0.25)
                    h = _hash(u, v, 11)
                    if h > 0.988:
                        c = (1.0, 0.95, 0.85)
                    elif h > 0.978:
                        c = _mix(c, (0.75, 0.7, 1.0), 0.6)
                elif name == "GymDragon" and channel in ("base", "plate"):
                    # Écailles arrondies en quinconce : arc sombre sous chaque écaille, centre plus clair
                    sx, sy = 10, 8
                    row_i = v // sy
                    cu = (u + (row_i % 2) * sx // 2) % sx - sx / 2
                    cv = v % sy
                    d = (cu / (sx / 2)) ** 2 + ((cv - sy) / sy) ** 2
                    c = tuple(x * (0.55 if d > 0.78 else 0.8 + 0.45 * (1 - d)) for x in c)
                elif name == "MarbleStatue" and channel in ("base", "plate", "extra"):
                    c = tuple(x - grain * 0.8 for x in c)
                    vein = abs(math.sin(u * 0.21 + v * 0.13 + math.sin(v * 0.37 + u * 0.05) * 2.1))
                    if vein < 0.05:
                        c = _mix(c, (0.55, 0.55, 0.6), 0.55)
                    elif vein < 0.11:
                        c = _mix(c, (0.75, 0.75, 0.78), 0.3)
                elif name == "MechaMogger" and channel == "plate":
                    # Plaque laquée : joint fin en bas de case
                    if v in (1, 2):
                        c = tuple(x * 0.72 for x in c)
                elif name == "NeonPhantom" and channel == "base":
                    # Tissu technique : fines côtes
                    if (u + v) % 4 == 0:
                        c = tuple(x * 1.35 for x in c)
                elif name == "InfernalDemon" and channel in ("base", "plate"):
                    # Surface brûlée : taches plus sombres
                    burn = 0.5 + 0.5 * math.sin(u * 0.5 + math.sin(v * 0.45) * 2.6)
                    c = tuple(x * (0.75 + 0.25 * burn) for x in c)
                elif name == "InfernalDemon" and channel == "extra":
                    # Corne : ivoire en haut, presque noire en bas de case (pointe)
                    c = _mix((0.12, 0.08, 0.07), rgb, v / 31)
                elif name == "EternalSun" and channel == "base":
                    # Soie : larges reflets doux
                    c = _mix(c, (1, 1, 1), 0.12 * max(0.0, math.sin(u * 0.4 + v * 0.1)))
                return _clamp(c)

            atlas.cell(f"prem_{name}_{channel}", 8 + index, 8 + row, painted)


# ------------------------------------------------------------------ formes
def _bbox(body, part, exclude=()):
    """Boîte englobante d'une partie du corps (toutes ses pièces sauf `exclude`), en coordonnées Blender."""
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    found = False
    for obj in bpy.data.collections["Body_" + body].objects:
        if obj.type != "MESH" or not (obj.name == body + "_" + part or obj.name.startswith(body + "_" + part + "_")):
            continue
        if any(token in obj.name for token in exclude):
            continue
        for v in obj.data.vertices:
            for k in range(3):
                lo[k] = min(lo[k], v.co[k])
                hi[k] = max(hi[k], v.co[k])
        found = True
    return (lo, hi) if found else None


def _rbox(center, size, bevel=0.35, segments=2, taper_top=1.0):
    """Boîte aux arêtes arrondies ; bevel = part de la plus petite dimension."""
    bm = block(tuple(center), tuple(size), taper_top=taper_top)
    off = min(size) * bevel * 0.5
    bmesh.ops.bevel(bm, geom=list(bm.edges) + list(bm.verts), offset=off, segments=segments, profile=0.5,
                    affect="EDGES", clamp_overlap=True)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


class Surface:
    """Surface mesurée : rows[i][j] = rayon (depuis centers[i]) à l'angle 2πj/n, à la hauteur heights[i]."""

    def __init__(self, rows, heights, centers=None, n=24, ease=0.0):
        self.rows = rows
        self.heights = heights
        self.centers = centers or [(0.0, 0.0)] * len(heights)
        self.n = n
        self.ease = ease

    def radius(self, i, j):
        i = max(0.0, min(len(self.rows) - 1.0, i))
        i0 = int(math.floor(i))
        i1 = min(i0 + 1, len(self.rows) - 1)
        fi = i - i0
        j = j % self.n
        j0 = int(math.floor(j))
        j1 = (j0 + 1) % self.n
        fj = j - j0
        a = self.rows[i0][j0] * (1 - fj) + self.rows[i0][j1] * fj
        b = self.rows[i1][j0] * (1 - fj) + self.rows[i1][j1] * fj
        return a * (1 - fi) + b * fi + self.ease

    def center(self, i):
        i = max(0.0, min(len(self.rows) - 1.0, i))
        i0 = int(math.floor(i))
        i1 = min(i0 + 1, len(self.rows) - 1)
        fi = i - i0
        return Vector((self.centers[i0][0] * (1 - fi) + self.centers[i1][0] * fi,
                       self.centers[i0][1] * (1 - fi) + self.centers[i1][1] * fi, 0))

    def point(self, i, j, out=0.0):
        i = max(0.0, min(len(self.rows) - 1.0, i))
        i0 = int(math.floor(i))
        i1 = min(i0 + 1, len(self.rows) - 1)
        fi = i - i0
        z = self.heights[i0] * (1 - fi) + self.heights[i1] * fi
        cx = self.centers[i0][0] * (1 - fi) + self.centers[i1][0] * fi
        cy = self.centers[i0][1] * (1 - fi) + self.centers[i1][1] * fi
        a = TAU * j / self.n
        r = self.radius(i, j) + out
        return Vector((cx + math.cos(a) * r, cy + math.sin(a) * r, z))

    def patch(self, j0, j1, i0, i1, out=0.0, thick=0.05, bulge=0.0, sj=None, si=None, taper=0.0):
        """Plaque fermée qui épouse la surface : angles j0..j1 (indices, j1 > j0), tranches i0..i1.
        out : décalage vers l'extérieur ; bulge : bombé au centre ; taper : rétrécit la plaque vers i1 (0..1)."""
        sj = sj or max(2, int(math.ceil(abs(j1 - j0) * 1.5)))
        si = si or max(2, int(math.ceil(abs(i1 - i0) * 1.5)))
        bm = bmesh.new()
        outer, inner = [], []
        for a in range(si + 1):
            v = a / si
            i = i0 + (i1 - i0) * v
            half = (j1 - j0) / 2 * (1 - taper * v)
            mid = (j0 + j1) / 2
            orow, irow = [], []
            for b in range(sj + 1):
                u = b / sj
                j = mid - half + 2 * half * u
                bump = bulge * math.sin(math.pi * u) * math.sin(math.pi * v)
                orow.append(bm.verts.new(self.point(i, j, out + thick + bump)))
                irow.append(bm.verts.new(self.point(i, j, out)))
            outer.append(orow)
            inner.append(irow)
        for a in range(si):
            for b in range(sj):
                bm.faces.new((outer[a][b], outer[a][b + 1], outer[a + 1][b + 1], outer[a + 1][b]))
                bm.faces.new((inner[a + 1][b], inner[a + 1][b + 1], inner[a][b + 1], inner[a][b]))
        for b in range(sj):
            bm.faces.new((outer[0][b + 1], outer[0][b], inner[0][b], inner[0][b + 1]))
            bm.faces.new((outer[si][b], outer[si][b + 1], inner[si][b + 1], inner[si][b]))
        for a in range(si):
            for b in (0, sj):
                bm.faces.new((outer[a][b], outer[a + 1][b], inner[a + 1][b], inner[a][b]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        return bm

    def band(self, i0, i1, out=0.0, thick=0.04):
        """Anneau complet (bracelet, bague de genou) entre deux tranches."""
        return self.patch(0, self.n, i0, i1, out, thick, sj=self.n, si=max(1, int(abs(i1 - i0) * 1.5)))

    def line(self, pts, out=0.0, width=0.06, thick=0.03):
        """Liseré (ligne d'énergie, fissure) qui suit la surface : pts = [(i, j), ...]."""
        bm = bmesh.new()
        prev = None
        rings = []
        for k, (i, j) in enumerate(pts):
            p = self.point(i, j, out + thick * 0.5)
            q = pts[min(k + 1, len(pts) - 1)]
            r = pts[max(k - 1, 0)]
            t = (self.point(q[0], q[1], out) - self.point(r[0], r[1], out)).normalized()
            cc = self.center(i)
            nrm = (p - Vector((cc.x, cc.y, p.z))).normalized()
            side = t.cross(nrm).normalized()
            rings.append([bm.verts.new(p + side * width * 0.5 * sx + nrm * thick * 0.5 * sy)
                          for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))])
        for lo, hi in zip(rings, rings[1:]):
            for k in range(4):
                m = (k + 1) % 4
                bm.faces.new((lo[k], lo[m], hi[m], hi[k]))
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        return bm


def _limb_surface(body, part, top, bottom, ease, count=9):
    heights = [top.z + (bottom.z - top.z) * i / (count - 1) for i in range(count)]
    centers = [(top.x + (bottom.x - top.x) * i / (count - 1), top.y + (bottom.y - top.y) * i / (count - 1))
               for i in range(count)]
    rows = _body_radii(body, part, heights, 24, centers)
    return Surface(rows, heights, centers, 24, ease)


def _horn(base, direction, length, radius, curl=(0, 0, 0), segments=7, sides=8):
    """Corne conique et courbée : part de `base` dans `direction`, se courbe vers `curl`."""
    d = Vector(direction).normalized()
    c = Vector(curl)
    pts, radii = [], []
    p = Vector(base)
    for k in range(segments + 1):
        t = k / segments
        pts.append(tuple(p))
        radii.append(radius * (1 - t) ** 0.9 + radius * 0.04)
        d = (d + c * (1.0 / segments)).normalized()
        p = p + d * (length / segments)
    return sweep(pts, radii, sides)


def _membrane(bone_a, bone_b, depth=0.03, sag=0.0, steps=6):
    """Membrane d'aile entre deux os (listes de points de même longueur) ; le bord libre se creuse de `sag`."""
    bm = bmesh.new()
    front, back = [], []
    n = len(bone_a)
    for k in range(n):
        frow, brow = [], []
        for s in range(steps + 1):
            t = s / steps
            p = Vector(bone_a[k]).lerp(Vector(bone_b[k]), t)
            if k == n - 1:
                p += (Vector(bone_a[0]) - p).normalized() * sag * math.sin(math.pi * t)
            frow.append(bm.verts.new(p))
            brow.append(bm.verts.new(p + Vector((0, depth, 0))))
        front.append(frow)
        back.append(brow)
    for k in range(n - 1):
        for s in range(steps):
            bm.faces.new((front[k][s], front[k][s + 1], front[k + 1][s + 1], front[k + 1][s]))
            bm.faces.new((back[k + 1][s], back[k + 1][s + 1], back[k][s + 1], back[k][s]))
    for k in range(n - 1):
        for s in (0, steps):
            bm.faces.new((front[k][s], front[k + 1][s], back[k + 1][s], back[k][s]))
    for s in range(steps):
        for k in (0, n - 1):
            bm.faces.new((front[k][s + 1], front[k][s], back[k][s], back[k][s + 1]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def _bone(root, tip, bend, count=6):
    """Os d'aile : de root à tip, arqué de `bend` (vecteur) au milieu."""
    root, tip, bend = Vector(root), Vector(tip), Vector(bend)
    return [root.lerp(tip, t) + bend * math.sin(math.pi * t) for t in (k / (count - 1) for k in range(count))]


def _sphere_patch(center, radii, az0, az1, el0, el1, thick, su=10, sv=6):
    """Morceau de sphère (casque, capuche) : azimut az0..az1 (0 = devant, sens horaire vu de dessus, en radians),
    élévation el0..el1 (-π/2 bas, π/2 haut). Coque fermée d'épaisseur `thick` vers l'intérieur."""
    c = Vector(center)
    bm = bmesh.new()
    outer, inner = [], []
    for a in range(sv + 1):
        el = el0 + (el1 - el0) * a / sv
        orow, irow = [], []
        for b in range(su + 1):
            az = az0 + (az1 - az0) * b / su
            d = Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el)))
            o = c + Vector((d.x * radii[0], d.y * radii[1], d.z * radii[2]))
            orow.append(bm.verts.new(o))
            irow.append(bm.verts.new(o - d * thick))
        outer.append(orow)
        inner.append(irow)
    for a in range(sv):
        for b in range(su):
            bm.faces.new((outer[a][b], outer[a][b + 1], outer[a + 1][b + 1], outer[a + 1][b]))
            bm.faces.new((inner[a + 1][b], inner[a + 1][b + 1], inner[a][b + 1], inner[a][b]))
    for b in range(su):
        bm.faces.new((outer[0][b + 1], outer[0][b], inner[0][b], inner[0][b + 1]))
        bm.faces.new((outer[sv][b], outer[sv][b + 1], inner[sv][b + 1], inner[sv][b]))
    for a in range(sv):
        for b in (0, su):
            bm.faces.new((outer[a][b], outer[a + 1][b], inner[a + 1][b], inner[a][b]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def _star(center, normal_axis, r_out, r_in, depth, points=5, rot=0.0):
    """Étoile pleine (emblème) ; normal_axis 'y' : face vers l'avant (-Y)."""
    bm = bmesh.new()
    c = Vector(center)
    ring_f, ring_b = [], []
    for k in range(points * 2):
        a = rot + math.pi * k / points
        r = r_out if k % 2 == 0 else r_in
        off = Vector((math.cos(a) * r, 0, math.sin(a) * r))
        ring_f.append(bm.verts.new(c + off - Vector((0, depth / 2, 0))))
        ring_b.append(bm.verts.new(c + off + Vector((0, depth / 2, 0))))
    cf = bm.verts.new(c - Vector((0, depth, 0)))
    cb = bm.verts.new(c + Vector((0, depth / 2, 0)))
    m = len(ring_f)
    for k in range(m):
        q = (k + 1) % m
        bm.faces.new((cf, ring_f[k], ring_f[q]))
        bm.faces.new((cb, ring_b[q], ring_b[k]))
        bm.faces.new((ring_f[k], ring_b[k], ring_b[q], ring_f[q]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


# ------------------------------------------------------------------ contexte commun d'une tenue sur un corps
class Kit:
    def __init__(self, w, body, g, name):
        self.w, self.body, self.g, self.name = w, body, g, name
        self.J, self.cfg = g["J"], g["cfg"]
        self.chest = g["chest_w"]
        self.k = 0.55 + self.chest * 0.35          # échelle des volumes : suit la carrure du stade
        self.c = {ch: f"prem_{name}_{ch}" for ch in CHANNELS}
        self.sil = "armor"
        head = _bbox(body, "Head", exclude=("Hair", "Brow", "Mouth", "Eyes"))
        self.head_lo, self.head_hi = head
        self.head_c = (self.head_lo + self.head_hi) / 2
        self.head_r = (self.head_hi.x - self.head_lo.x) / 2
        eyes = _bbox(body, "Head_Eyes")
        self.eye_z = (eyes[0].z + eyes[1].z) / 2 if eyes else self.head_c.z + self.head_r * 0.1
        self.eye_y = eyes[0].y if eyes else self.head_lo.y
        # Crâne (sans la mâchoire, qui avance) : centre et rayons pour casques, capuches et couronnes
        self.skull_c = Vector((0, (self.eye_y + self.head_hi.y) / 2 + 0.02, self.eye_z + 0.05))
        self.skull_r = Vector((self.head_r * 1.02, (self.head_hi.y - self.eye_y) / 2 + 0.03,
                               self.head_hi.z - self.eye_z + 0.02))

    def make(self, part, bm, channel, tint=None):
        """tint : None, 'Deco', 'Glow', 'GlowB', 'GlowDeco', 'GlowBDeco' (D126 : aussi CapeDeco, TailDeco, WingADeco…)."""
        self.w.make(part + ("_" + tint if tint else ""), bm, self.c[channel])

    # ---------------- haut : sous-tenue et surface du torse
    def torso(self, silhouette):
        self.sil = silhouette
        radii, heights = _torso(self.w, self.body, self.g, self.c["base"], silhouette, self.name)
        self.T = Surface(radii, heights)
        return self.T

    def arm(self, side, lower=False):
        J, cfg = self.J, self.cfg
        sh, el, wr = J[side + "Shoulder"], J[side + "Elbow"], J[side + "Wrist"]
        ease = (0.21 if self.sil in ("puffer", "armor") else 0.115) + cfg["bicep"] * 0.06
        if lower:
            top = Vector((el.x, el.y, el.z + cfg["forearm"] * 0.7))
            return _limb_surface(self.body, side + "LowerArm", top, el.lerp(wr, 0.91), ease * 0.85 + 0.01)
        arm = bpy.data.objects.get(self.body + "_" + side + "UpperArm")
        arm_top = max(v.co.z for v in arm.data.vertices) if arm else sh.z
        top = Vector((sh.x, sh.y, max(sh.z + cfg["delt"] * 0.95, arm_top + 0.03)))
        return _limb_surface(self.body, side + "UpperArm", top, el, ease + 0.01)

    def leg(self, side, ease, lower=False):
        J = self.J
        hip, knee, ankle = J[side + "Hip"], J[side + "Knee"], J[side + "Ankle"]
        if lower:
            return _limb_surface(self.body, side + "LowerLeg", knee, Vector((ankle.x, ankle.y, ankle.z + 0.12)), ease + 0.01)
        return _limb_surface(self.body, side + "UpperLeg", Vector((hip.x, 0, hip.z + 0.05)), knee, ease + 0.01)

    def hips(self, ease):
        root = self.J["Root"]
        heights = [root.z - 0.26 + i * 0.075 for i in range(11)]
        rows = _body_radii(self.body, "LowerTorso", heights)
        return Surface(rows, heights, None, 24, ease + 0.01)

    def boots(self, channel="dark", plate="plate", glow=None, toe_spike=False, cuff=1.0):
        """Bottes : coque arrondie autour du pied (baskets du stade cachées), plaque sur le dessus."""
        for side, sx in sides():
            box = _bbox(self.body, side + "Foot")
            if not box:
                continue
            lo, hi = box
            c = (lo + hi) / 2
            size = (hi - lo)
            self.make(side + "Foot", _rbox(c + Vector((0, -0.01, 0.01)), (size.x * 1.14 + 0.05, size.y * 1.1 + 0.05, size.z * 1.12 + 0.05),
                                           0.55), channel)
            top = Vector((c.x, lo.y + size.y * 0.32, hi.z + 0.03))
            self.make(side + "Foot", _rbox(top, (size.x * 0.9, size.y * 0.55, 0.07 + size.z * 0.12), 0.6), plate)
            # Revers de botte autour de la cheville
            self.make(side + "Foot", ring((c.x, c.y + size.y * 0.12, hi.z + 0.04), max(size.x, size.y * 0.6) * 0.62 * cuff,
                                          0.06, 0.12, 12), plate)
            if glow:
                self.make(side + "Foot", _rbox(top + Vector((0, -size.y * 0.05, 0.05 + size.z * 0.06)),
                                               (size.x * 0.25, size.y * 0.4, 0.035), 0.5), "trim", glow)
            if toe_spike:
                tip = Vector((c.x, lo.y - 0.05, lo.z + size.z * 0.4))
                self.make(side + "Foot", _horn(tip + Vector((0, 0.12, 0)), (0, -1, 0.5), 0.22 * self.k, 0.07 * self.k,
                                               (0, 0, 0.6)), plate)

    def gloves(self, channel="dark", plate="plate", glow=None, claws=None):
        for side, sx in sides():
            box = _bbox(self.body, side + "Hand")
            if not box:
                continue
            lo, hi = box
            c = (lo + hi) / 2
            size = hi - lo
            self.make(side + "Hand", _rbox(c, (size.x * 1.18 + 0.04, size.y * 1.15 + 0.04, size.z * 1.06 + 0.03), 0.6), channel)
            # Plaque du dos de la main (côté extérieur)
            self.make(side + "Hand", _rbox(Vector((c.x + sx * (size.x * 0.62 + 0.02), c.y, c.z + size.z * 0.12)),
                                           (0.06, size.y * 1.0, size.z * 0.55), 0.5), plate)
            if glow:
                self.make(side + "Hand", _rbox(Vector((c.x + sx * (size.x * 0.62 + 0.06), c.y, c.z + size.z * 0.12)),
                                               (0.03, size.y * 0.45, size.z * 0.18), 0.5), "trim", glow)
            if claws:
                for n in (-1, 0, 1):
                    base = Vector((c.x + sx * size.x * 0.2, c.y + n * size.y * 0.3, lo.z + 0.03))
                    self.make(side + "Hand", _horn(base, (sx * 0.2, -0.2, -1), 0.16 * self.k, 0.035 * self.k, (sx * 0.6, -0.6, 0)),
                              claws)

    def collar(self, channel, height=0.14, out=0.04):
        neck = self.J["Neck"]
        r = max(self.cfg["neck"] * 1.3 + 0.12, self.head_r * 0.5)
        r = min(r, self.chest * 0.32)
        self.make("UpperTorso", ring((0, 0.04, neck.z + 0.02), r + out, 0.07, height, 16), channel)

    def pauldron(self, side, sx, channel, layers=3, scale=1.0, tint=None, flare=0.0, glow=None):
        """Épaulière : coque qui couvre le dessus et l'extérieur de l'épaule (ouverte côté cou : la tête reste
        dégagée), puis des lames qui descendent sur le bras."""
        A = self.arm(side)
        jo = 0 if sx > 0 else 12  # côté extérieur du bras
        r = (A.radius(1.2, jo) + A.radius(1.2, 6) + A.radius(1.2, 18)) / 3 * scale
        cx = A.centers[0][0] + sx * r * 0.2
        cy = A.centers[0][1]
        z0 = A.heights[0]
        part = side + "UpperArm"
        mid = math.pi / 2 * sx  # azimut de l'extérieur
        self.make(part, _sphere_patch((cx, cy, z0 - r * 0.42), (r * 1.2, r * 1.1, r * 0.95), mid - 2.5, mid + 2.5,
                                      -0.2, 1.5, 0.07, 18, 6), channel, tint)
        self.make(part, _sphere_patch((cx, cy, z0 - r * 0.42), (r * 1.24, r * 1.14, r * 0.99), mid - 2.5, mid + 2.5,
                                      -0.32, -0.12, 0.05, 18, 1), "trim", tint)
        for n in range(1, layers):
            z = z0 - r * (0.62 + n * 0.3)
            rr = r * (1.16 + flare * n * 0.1)
            self.make(part, _sphere_patch((cx, cy, z), (rr, rr * 0.95, r * 0.4), mid - 1.65, mid + 1.65, -0.45, 0.6, 0.05, 14, 2),
                      "trim" if n == layers - 1 else channel, tint)
        if glow:
            self.make(part, _sphere_patch((cx, cy, z0 - r * 0.42), (r * 1.26, r * 1.16, r * 1.01), mid - 1.9, mid + 1.9,
                                          0.05, 0.2, 0.03, 16, 1), "trim", glow)
        return Vector((cx, cy, z0)), r

    def bracers(self, channel, glow=None, ridge=None):
        for side, sx in sides():
            A = self.arm(side, lower=True)
            self.make(side + "LowerArm", A.band(3.2, 8, 0.0, 0.06), channel)
            self.make(side + "LowerArm", A.band(7.4, 8, 0.06, 0.035), "trim")
            if glow:
                self.make(side + "LowerArm", A.line([(3.6, 0 if sx > 0 else 12), (7.2, 0 if sx > 0 else 12)], 0.06, 0.05, 0.03),
                          "trim", glow)
            if ridge:
                for n in range(3):
                    i = 3.8 + n * 1.3
                    jj = 0 if sx > 0 else 12
                    p = A.point(i, jj, 0.08)
                    self.make(side + "LowerArm_Deco", _horn(p, (sx, 0, 0.6), 0.16 * self.k, 0.05 * self.k, (0, 0, 1.2)), ridge)

    def greaves(self, ease, channel, glow=None, knee="plate", knee_spike=None):
        for side, sx in sides():
            L = self.leg(side, ease, lower=True)
            self.make(side + "LowerLeg", L.patch(13.2, 22.8, 0.8, 7.6, 0.0, 0.06, 0.04), channel)
            self.make(side + "LowerLeg", L.band(7.2, 8, 0.0, 0.05), "trim")
            # Genouillère bombée
            p = L.point(0.4, 18, 0.0)
            r = L.radius(0.5, 18)
            self.make(side + "LowerLeg", lowsphere(tuple(p + Vector((0, -0.02, 0.02))), (r * 0.75, r * 0.38, r * 0.7), 12, 6), knee)
            if glow:
                self.make(side + "LowerLeg", L.line([(1.6, 18), (6.8, 18)], 0.06, 0.045, 0.03), "trim", glow)
            if knee_spike:
                self.make(side + "LowerLeg_Deco", _horn(p + Vector((0, -r * 0.2, 0.0)), (0, -1, 0.4), 0.25 * self.k, 0.07 * self.k,
                                                        (0, 0, 0.9)), knee_spike)

    def belt(self, H, channel, buckle, glow=None):
        self.make("LowerTorso", H.band(7.6, 9.4, 0.0, 0.06), channel)
        p = H.point(8.5, 18, 0.06)
        self.make("LowerTorso", _rbox(p, (0.22 + self.chest * 0.06, 0.07, 0.18 + self.chest * 0.02), 0.5), buckle)
        if glow:
            self.make("LowerTorso", _rbox(p + Vector((0, -0.04, 0)), (0.1 + self.chest * 0.03, 0.03, 0.08), 0.5), "trim", glow)

    def tassets(self, ease, channel, trim="trim", length=0.6):
        for side, sx in sides():
            U = self.leg(side, ease)
            j0, j1 = (18.5, 23.5) if sx > 0 else (12.5, 17.5)
            self.make(side + "UpperLeg", U.patch(j0, j1, 0, 8 * length, 0.03, 0.05, 0.03), channel)
            self.make(side + "UpperLeg", U.patch(j0, j1, 8 * length - 0.3, 8 * length + 0.2, 0.08, 0.03), trim)


# ------------------------------------------------------------------ les huit tenues
def _cosmic(K, top):
    T = K.torso("cape")
    chest, k = K.chest, K.k
    J = K.J
    # Plastron violet bordé d'or, col d'empereur, étoile pectorale lumineuse, lignes de constellation
    K.make("UpperTorso", T.patch(13.6, 22.4, 5.5, 13, 0.0, 0.05, 0.05), "plate")
    K.make("UpperTorso", T.line([(13, 13.6), (5.5, 15), (1.0, 18), (5.5, 21), (13, 22.4)], 0.05, 0.07, 0.035), "trim")
    K.make("UpperTorso", T.line([(5.5, 15), (5.5, 21)], 0.05, 0.05, 0.03), "trim")
    centre = T.point(9.2, 18, 0.11)
    K.make("UpperTorso", _star(centre, "y", chest * 0.11, chest * 0.045, 0.06), "trim", "GlowB")
    for a, b in (((11.5, 16.2), (9.8, 17.0)), ((9.8, 17.0), (8.2, 16.0)), ((11.2, 19.8), (8.6, 20.2)), ((8.6, 20.2), (7.4, 19.4))):
        K.make("UpperTorso", T.line([a, b], 0.08, 0.035, 0.02), "trim", "Glow")
    # Haut col doré dans le dos (jamais devant : la mâchoire reste libre)
    neck = J["Neck"]
    back = T.radius(13, 6)
    h = 0.32 + chest * 0.12
    K.make("UpperTorso", _sphere_patch((0, 0.06, neck.z + h * 0.15), (chest * 0.36, back * 0.95, h), 2.1, 4.2, -0.1, 1.0, 0.05, 12, 4),
           "trim")
    K.make("UpperTorso", _sphere_patch((0, 0.03, neck.z + h * 0.15), (chest * 0.34, back * 0.92, h * 0.95), 2.2, 4.1, -0.05, 0.95, 0.03, 10, 3),
           "extra")
    # Épaulières : planètes dorées à anneau incliné
    for side, sx in sides():
        c, r = K.pauldron(side, sx, "plate", layers=2, scale=1.0)
        K.make(side + "UpperArm", ring((c.x, c.y, c.z - r * 0.35), r * 1.32, 0.05, 0.06, 20), "trim")
        K.make(side + "UpperArm_GlowDeco", ring((c.x + sx * r * 0.1, c.y, c.z + r * 0.1), r * 1.55, 0.03, 0.03, 24), "trim")
    K.bracers("plate", glow="Glow")
    K.gloves("dark", "trim")
    # Cape étoilée doublée d'or
    cape_y = max(row[6] for row in T.rows)
    # D126 : pièce « Cape » à part, qui ondule et suit les mouvements dans le jeu (PremiumMotionController)
    K.make("UpperTorso_CapeDeco", _cape_mesh(chest, cape_y + 0.02, neck.z, J["Waist"].z - 0.9 * k, 1.5, 1.35), "base")
    K.make("UpperTorso_CapeDeco", _cape_mesh(chest, cape_y - 0.015, neck.z - 0.04, J["Waist"].z - 0.86 * k, 1.47, 1.32), "trim")
    # Couronne d'étoiles qui flotte au-dessus de la tête (lumineuse)
    hc = Vector((0, K.skull_c.y, K.head_hi.z + 0.28 * k))
    K.make("Head_GlowBSpinDeco", ring(tuple(hc), K.head_r * 0.82, 0.05, 0.07, 20), "trim")  # D126 : tourne
    for n in range(7):
        a = TAU * n / 7
        p = hc + Vector((math.cos(a) * K.head_r * 0.82, math.sin(a) * K.head_r * 0.82, 0.12 * k))
        K.make("Head_GlowSpinDeco", _star(p, "y", 0.11 * k, 0.045 * k, 0.04, rot=math.pi / 2), "trim")


def _cosmic_bottom(K):
    ease = _bottom(K.w, K.body, K.g, K.c["base"], "straight", K.name)
    H = K.hips(0.075)
    K.belt(H, "trim", "plate", "GlowB")
    for side, sx in sides():
        L = K.leg(side, ease, lower=True)
        j = 0 if sx > 0 else 12
        K.make(side + "LowerLeg", L.line([(0.4, j), (7.4, j)], 0.0, 0.07, 0.035), "trim")
        K.make(side + "LowerLeg", L.line([(0.8, j + (1.2 if sx > 0 else -1.2)), (7.0, j + (1.2 if sx > 0 else -1.2))], 0.03, 0.035, 0.02),
               "trim", "Glow")
    # Pans de tunique devant les cuisses
    K.tassets(ease, "plate", length=0.75)
    K.boots("dark", "trim", "GlowB")


def _titan(K, top):
    T = K.torso("armor")
    chest, k = K.chest, K.k
    # Cuirasse dorée en deux pectoraux + abdominaux, fissures de lave entre les plaques
    K.make("UpperTorso", T.patch(18.25, 22.6, 7.6, 13, 0.0, 0.07, 0.06), "plate")
    K.make("UpperTorso", T.patch(13.4, 17.75, 7.6, 13, 0.0, 0.07, 0.06), "plate")
    for n, (i0, i1) in enumerate(((5.4, 7.2), (3.4, 5.1), (1.2, 3.1))):
        for j0, j1 in ((15.6, 17.85), (18.15, 20.4)):
            K.make("UpperTorso", T.patch(j0, j1, i0, i1, 0.0, 0.065, 0.03), "plate")
    K.make("UpperTorso", T.patch(1.5, 10.5, 5, 13, 0.0, 0.06, 0.04), "plate")  # dossière
    K.make("UpperTorso", T.line([(13, 18), (0.6, 18)], 0.0, 0.07, 0.045), "extra", "Glow")
    for i in (7.4, 5.25, 3.25):
        K.make("UpperTorso", T.line([(i, 15.4), (i, 20.6)], 0.0, 0.05, 0.04), "extra", "Glow")
    K.collar("trim", 0.16)
    # D126 : cape d'obsidienne doublée d'or, qui ondule dans le jeu
    J = K.J
    cape_y = max(row[6] for row in T.rows)
    K.make("UpperTorso_CapeDeco", _cape_mesh(chest, cape_y + 0.02, J["Neck"].z, J["Waist"].z - 1.0 * k, 1.45, 1.4), "base")
    K.make("UpperTorso_CapeDeco", _cape_mesh(chest, cape_y - 0.015, J["Neck"].z - 0.04, J["Waist"].z - 0.96 * k, 1.42, 1.37), "trim")
    for side, sx in sides():
        c, r = K.pauldron(side, sx, "plate", layers=3, scale=1.12, glow="Glow")
        # Cornes de colosse sur l'épaulière
        K.make(side + "UpperArm_Deco", _horn(c + Vector((sx * r * 0.55, 0, r * 0.3)), (sx * 0.7, 0, 1), 0.55 * k, 0.11 * k,
                                             (sx * 1.0, 0.0, -0.4)), "trim")
    K.bracers("plate", glow="Glow")
    K.gloves("dark", "plate", glow="Glow")
    # Couronne-heaume : bandeau doré, trois pointes, gemme de lave
    s = K.skull_c
    band_z = K.eye_z + (K.head_hi.z - K.eye_z) * 0.55
    K.make("Head_Deco", ring((0, s.y, band_z), K.skull_r.x * 1.08, 0.06, 0.13 + 0.03 * k, 18), "plate")
    for a, h in ((0, 0.42), (-0.6, 0.3), (0.6, 0.3), (-1.2, 0.22), (1.2, 0.22)):
        p = Vector((math.sin(a) * K.skull_r.x * 1.08, s.y - math.cos(a) * K.skull_r.y * 1.05, band_z + 0.05))
        K.make("Head_Deco", pyramid(tuple(p), tuple(p + Vector((0, -0.02, h * k))), 0.08 * k, 0.05), "trim")
    p = Vector((0, s.y - K.skull_r.y * 1.12, band_z + 0.02))
    K.make("Head_GlowDeco", lowsphere(tuple(p), (0.07 * k, 0.04, 0.07 * k), 8, 6), "extra")


def _titan_bottom(K):
    ease = _bottom(K.w, K.body, K.g, K.c["base"], "straight", K.name)
    H = K.hips(0.075)
    K.belt(H, "plate", "trim", "Glow")
    K.tassets(ease, "plate", length=0.7)
    K.greaves(ease, "plate", glow="Glow", knee="trim")
    K.boots("dark", "plate", "Glow")


def _phantom(K, top):
    T = K.torso("hoodie")
    chest, k = K.chest, K.k
    # Gilet tactique graphite, sangles et lignes néon cyan / magenta
    K.make("UpperTorso", T.patch(14.2, 21.8, 3.5, 11, 0.0, 0.06, 0.03), "plate")
    for sx in (-1, 1):
        j = 18 + sx * 2.6
        K.make("UpperTorso", T.line([(13, 18 + sx * 4.2), (1.2, j)], 0.06, 0.07, 0.035), "dark")
        K.make("UpperTorso", T.line([(11.6, 18 + sx * 4.6), (6.0, 18 + sx * 3.4), (2.0, 18 + sx * 3.9)], 0.0, 0.065, 0.035),
               "trim", "Glow")
    K.make("UpperTorso", T.line([(10.6, 15.0), (10.6, 21.0)], 0.06, 0.06, 0.035), "extra", "GlowB")
    # X lumineux sur le gilet et chevrons sur les flancs
    K.make("UpperTorso", T.line([(9.5, 15.6), (7.0, 18), (4.5, 20.4)], 0.06, 0.06, 0.035), "trim", "Glow")
    K.make("UpperTorso", T.line([(9.5, 20.4), (7.0, 18), (4.5, 15.6)], 0.06, 0.06, 0.035), "trim", "Glow")
    for sx in (-1, 1):
        for n in range(3):
            i = 3 + n * 2.5
            K.make("UpperTorso", T.line([(i + 1, 18 + sx * 5.2), (i, 18 + sx * 6.4), (i + 1, 18 + sx * 7.6)], 0.0, 0.05, 0.03),
                   "extra", "GlowB")
    K.make("UpperTorso", T.patch(2.5, 9.5, 3, 12, 0.0, 0.05, 0.02), "plate")
    K.make("UpperTorso", T.line([(11, 6), (2.5, 6)], 0.05, 0.05, 0.03), "trim", "Glow")
    for side, sx in sides():
        A = K.arm(side)
        j = 0 if sx > 0 else 12
        K.make(side + "UpperArm", A.line([(0.8, j), (7.6, j)], 0.0, 0.07, 0.035), "trim", "Glow")
        K.make(side + "UpperArm", A.band(1.0, 1.4, 0.0, 0.03), "trim", "Glow")
        K.make(side + "UpperArm", A.band(4.5, 5.3, 0.0, 0.04), "dark")
        K.make(side + "UpperArm", A.line([(2.0, j + (1.6 if sx > 0 else -1.6)), (6.0, j + (1.6 if sx > 0 else -1.6))], 0.0, 0.035, 0.02),
               "extra", "GlowB")
        B = K.arm(side, lower=True)
        K.make(side + "LowerArm", B.band(5.5, 8, 0.0, 0.05), "plate")
        K.make(side + "LowerArm", B.band(6.6, 7.0, 0.05, 0.02), "trim", "Glow")
    K.gloves("dark", "plate", glow="GlowB")
    # Capuche relevée (elle laisse voir tout le visage) et visière néon
    s, R = K.skull_c, K.skull_r
    K.make("Head_Deco", _sphere_patch(tuple(s + Vector((0, 0.06, 0.02))), (R.x * 1.2, R.y * 1.18, R.z * 1.18),
                                      math.radians(68), math.radians(292), -0.95, 1.45, 0.07, 16, 7), "base")
    K.make("Head_GlowDeco", _sphere_patch(tuple(s + Vector((0, 0.06, 0.02))), (R.x * 1.22, R.y * 1.2, R.z * 1.2),
                                          math.radians(66), math.radians(70), -0.9, 1.4, 0.03, 1, 7), "trim")
    K.make("Head_GlowDeco", _sphere_patch(tuple(s + Vector((0, 0.06, 0.02))), (R.x * 1.22, R.y * 1.2, R.z * 1.2),
                                          math.radians(290), math.radians(294), -0.9, 1.4, 0.03, 1, 7), "trim")
    # Visière : bande lumineuse devant les yeux
    vy = K.eye_y
    K.make("Head_GlowDeco", _sphere_patch((0, vy + K.head_r * 0.95, K.eye_z + 0.02), (K.head_r * 1.04, K.head_r * 1.0, 0.11),
                                          math.radians(-62), math.radians(62), -0.55, 0.55, 0.04, 12, 2), "trim")
    K.make("Head_Deco", _sphere_patch((0, vy + K.head_r * 0.95, K.eye_z + 0.02), (K.head_r * 1.1, K.head_r * 1.04, 0.15),
                                      math.radians(-68), math.radians(-60), -0.6, 0.6, 0.05, 2, 2), "dark")
    K.make("Head_Deco", _sphere_patch((0, vy + K.head_r * 0.95, K.eye_z + 0.02), (K.head_r * 1.1, K.head_r * 1.04, 0.15),
                                      math.radians(60), math.radians(68), -0.6, 0.6, 0.05, 2, 2), "dark")


def _phantom_bottom(K):
    ease = _bottom(K.w, K.body, K.g, K.c["base"], "taper", K.name)
    H = K.hips(0.075)
    K.belt(H, "dark", "plate", "Glow")
    for side, sx in sides():
        U = K.leg(side, ease)
        j = 0 if sx > 0 else 12
        K.make(side + "UpperLeg", U.line([(0.5, j), (7.5, j)], 0.0, 0.07, 0.035), "trim", "Glow")
        # Poche cargo graphite et sangle
        p = U.point(3.5, j - (2.5 if sx > 0 else -2.5), 0.05)
        K.make(side + "UpperLeg", _rbox(p, (0.12, 0.28 + K.chest * 0.04, 0.3), 0.4), "plate")
        K.make(side + "UpperLeg", U.band(2.0, 2.5, 0.0, 0.035), "dark")
        L = K.leg(side, ease, lower=True)
        K.make(side + "LowerLeg", L.line([(0.5, j), (7.2, j)], 0.0, 0.07, 0.035), "extra", "GlowB")
        K.make(side + "LowerLeg", L.band(4.0, 4.4, 0.0, 0.03), "trim", "Glow")
        K.make(side + "LowerLeg", L.patch(14.5, 21.5, 0.6, 3.0, 0.0, 0.05, 0.03), "plate")
    K.boots("dark", "plate", "Glow")


def _dragon(K, top):
    T = K.torso("armor")
    chest, k = K.chest, K.k
    J = K.J
    neck, waist = J["Neck"], J["Waist"]
    # Plastron de ventre doré en bandes (comme un vrai ventre de dragon), braises entre les bandes
    for n in range(6):
        i0 = 0.6 + n * 2.05
        K.make("UpperTorso", T.patch(15.4 + n * 0.1, 20.6 - n * 0.1, i0, i0 + 1.75, 0.0, 0.05, 0.03), "trim")
        if n < 5:
            K.make("UpperTorso", T.line([(i0 + 1.9, 16.0), (i0 + 1.9, 20.0)], 0.0, 0.035, 0.03), "extra", "Glow")
    # Écailles d'épaule et pectoraux en plaques
    K.make("UpperTorso", T.patch(20.4, 23.4, 8.5, 13, 0.0, 0.05, 0.03), "plate")
    K.make("UpperTorso", T.patch(12.6, 15.6, 8.5, 13, 0.0, 0.05, 0.03), "plate")
    # Crête dorsale
    for n in range(7):
        t = n / 6
        i = 12.5 - 11 * t
        p = T.point(i, 6, 0.02)
        size = (0.24 - 0.1 * t) * k
        K.make("UpperTorso_Deco", _horn(p, (0, 1, 0.55), size * 1.6, size * 0.45, (0, 0, 1.2)), "extra")
    for side, sx in sides():
        c, r = K.pauldron(side, sx, "plate", layers=3, scale=1.08, flare=0.5)
        for n, (dy, dz, ln) in enumerate(((-0.35, 0.2, 0.5), (0.0, 0.32, 0.65), (0.35, 0.2, 0.5))):
            base = c + Vector((sx * r * 0.6, dy * r, r * dz))
            K.make(side + "UpperArm_Deco", _horn(base, (sx * 0.8, dy * 0.4, 0.7), ln * k, 0.09 * k, (sx * 0.2, 0, 0.9)), "extra")
    K.bracers("plate", glow="Glow", ridge="extra")
    K.gloves("dark", "plate", claws="trim")
    # Ailes déployées : trois doigts sombres, membranes rouge feu, griffe au coude d'aile
    back = T.radius(9, 6)
    for sx in (-1, 1):
        wing = "UpperTorso_WingADeco" if sx < 0 else "UpperTorso_WingBDeco"  # D126 : une pièce par aile (battement)
        root = Vector((sx * chest * 0.16, back + 0.06, T.heights[10]))
        elbow = root + Vector((sx * (0.55 + chest * 0.25), 0.35 * k, 0.75 * k))
        tips = [elbow + Vector((sx * (0.9 + 0.45 * n) * k, (0.25 + 0.12 * n) * k, (0.55 - 0.75 * n) * k)) for n in range(3)]
        low = root + Vector((sx * chest * 0.12, 0.2 * k, -1.0 * k))
        arm_bone = _bone(root, elbow, Vector((0, 0.05, 0.15 * k)), 4)
        K.make(wing, sweep([tuple(p) for p in arm_bone], [0.09 * k, 0.08 * k, 0.07 * k, 0.065 * k], 6), "dark")
        bones = [_bone(elbow, tip, Vector((0, 0.06 * k, 0.12 * k)), 5) for tip in tips]
        for b in bones:
            K.make(wing, sweep([tuple(p) for p in b], [0.06 * k, 0.05 * k, 0.04 * k, 0.03 * k, 0.012 * k], 6), "dark")
        edges = [_bone(root, elbow, Vector((0, 0, 0)), 5)] + bones + [_bone(elbow, low, Vector((sx * 0.25 * k, 0.1, -0.1)), 5)]
        for a, b in zip(edges[1:], edges[2:]):
            K.make(wing, _membrane(a, b, 0.025, 0.18 * k), "extra")
        K.make(wing, _membrane(_bone(root, elbow, Vector((0, 0, 0)), 5), bones[0], 0.025, 0.0), "extra")
        K.make(wing, _horn(elbow, (sx * 0.2, 0, 1), 0.2 * k, 0.05 * k, (sx * 0.8, 0, 0)), "trim")
    # Cornes de dragon sur la tête : deux grandes cornes vers l'arrière et une petite crête
    s, R = K.skull_c, K.skull_r
    for sx in (-1, 1):
        base = s + Vector((sx * R.x * 0.55, R.y * 0.1, R.z * 0.62))
        K.make("Head_Deco", _horn(base, (sx * 0.35, 0.55, 1), 0.85 * k, 0.15 * k, (0, 1.4, -0.6)), "dark")
        K.make("Head_Deco", _horn(base + Vector((sx * R.x * 0.32, 0.08, -R.z * 0.42)), (sx * 1, 0.6, 0.2), 0.32 * k, 0.07 * k,
                                  (0, 0.8, 0.3)), "trim")
    for n in range(3):
        p = s + Vector((0, -R.y * 0.15 + n * R.y * 0.45, R.z * (0.95 - n * 0.12)))
        K.make("Head_Deco", _horn(p, (0, 0.6, 1), (0.28 - n * 0.06) * k, 0.06 * k, (0, 1, 0)), "extra")


def _dragon_bottom(K):
    ease = _bottom(K.w, K.body, K.g, K.c["base"], "straight", K.name)
    J = K.J
    H = K.hips(0.075)
    K.belt(H, "dark", "trim", "Glow")
    K.tassets(ease, "plate", length=0.6)
    K.greaves(ease, "plate", glow="Glow", knee="trim", knee_spike="extra")
    K.boots("dark", "plate", toe_spike=True)
    # Queue épaisse jusqu'au sol, piquants de feu, pointe en flèche
    k = K.k
    root = J["Root"]
    by = H.radius(5, 6) + 0.05
    z0 = root.z + 0.1
    pts = [(0, by, z0), (0, by + 0.4 * k, z0 - 0.4 * k), (0.1, by + 0.95 * k, z0 - 0.75 * k), (0.25, by + 1.55 * k, z0 - 0.88 * k),
           (0.35, by + 2.15 * k, z0 - 0.78 * k), (0.3, by + 2.6 * k, z0 - 0.5 * k), (0.15, by + 2.9 * k, z0 - 0.2 * k)]
    radii = [0.26 * k, 0.22 * k, 0.17 * k, 0.13 * k, 0.09 * k, 0.06 * k, 0.03 * k]
    K.make("LowerTorso_TailDeco", sweep(pts, radii, 10), "base")
    for n in range(1, 6):
        p = Vector(pts[n])
        K.make("LowerTorso_TailDeco", _horn(p + Vector((0, 0, radii[n] * 0.8)), (0, 0.3, 1), (0.22 - n * 0.025) * k, radii[n] * 0.45,
                                        (0, 1, 0)), "extra")
    K.make("LowerTorso_GlowTailDeco", sweep(pts[1:6], [r * 0.32 for r in radii[1:6]], 6), "trim")


def _sun(K, top):
    T = K.torso("robe")
    chest, k = K.chest, K.k
    J = K.J
    neck = J["Neck"]
    # Pectoral d'or en éventail (style pharaon), lapis-lazuli, cœur solaire lumineux
    K.make("UpperTorso", T.patch(13.2, 22.8, 9.5, 13.2, 0.0, 0.06, 0.03), "plate")
    K.make("UpperTorso", T.patch(13.8, 22.2, 8.6, 9.6, 0.0, 0.05), "extra")
    K.make("UpperTorso", T.patch(14.4, 21.6, 7.8, 8.7, 0.0, 0.05), "plate")
    core = T.point(8.0, 18, 0.12)
    K.make("UpperTorso", lowsphere(tuple(core), (chest * 0.12, 0.06, chest * 0.12), 12, 8), "trim", "Glow")
    for n in range(12):
        a = TAU * n / 12
        d = Vector((math.cos(a), 0, math.sin(a)))
        p = core + d * chest * 0.14
        K.make("UpperTorso", _horn(p, d, chest * (0.12 if n % 2 else 0.18), chest * 0.025, (0, 0, 0)), "plate", "GlowB" if n % 2 == 0 else None)
    # Écharpe de soie or en travers
    K.make("UpperTorso", T.line([(12.8, 21.6), (6, 18), (0.5, 14.4)], 0.07, 0.16, 0.04), "plate")
    for side, sx in sides():
        c, r = K.pauldron(side, sx, "plate", layers=2, scale=1.0)
        for n in range(5):
            a = math.radians(-40 + n * 30)
            base = c + Vector((sx * r * 0.9 * math.cos(a), 0, r * 0.9 * math.sin(a)))
            K.make(side + "UpperArm_GlowDeco", _horn(base, (sx * math.cos(a), 0, math.sin(a)), (0.32 if n % 2 == 0 else 0.22) * k, 0.06 * k),
                   "trim")
    K.bracers("plate", glow="GlowB")
    K.gloves("base", "plate")
    # Auréole solaire derrière la tête : disque, anneau, 16 rayons (lumineux)
    s, R = K.skull_c, K.skull_r
    hc = Vector((0, K.head_hi.y + 0.25 * k, s.z + 0.05))
    big = K.head_r * 1.65 + 0.2 * k
    # D126 : l'auréole tourne lentement dans le jeu (pièces « Spin »)
    K.make("Head_GlowSpinDeco", ring_upright(tuple(hc), big, big * 0.09, 0.06, 28), "plate")
    K.make("Head_GlowBSpinDeco", ring_upright(tuple(hc + Vector((0, 0.02, 0))), big * 0.72, big * 0.05, 0.05, 24), "plate")
    for n in range(16):
        a = TAU * n / 16
        d = Vector((math.cos(a), 0, math.sin(a)))
        length = big * (0.55 if n % 2 == 0 else 0.32)
        K.make("Head_GlowSpinDeco", _horn(hc + d * big * 0.98, d, length, big * 0.06, (0, 0, 0), 3, 4), "plate")
    # Diadème solaire
    band_z = K.eye_z + (K.head_hi.z - K.eye_z) * 0.6
    K.make("Head_Deco", ring((0, s.y, band_z), R.x * 1.07, 0.05, 0.08, 18), "plate")
    p = Vector((0, s.y - R.y * 1.08, band_z + 0.1))
    K.make("Head_GlowDeco", lowsphere(tuple(p), (0.09 * k, 0.04, 0.09 * k), 10, 6), "trim")


def _sun_bottom(K):
    ease = _bottom(K.w, K.body, K.g, K.c["base"], "straight", K.name)
    H = K.hips(0.075)
    K.belt(H, "plate", "extra", "Glow")
    # Pagne / tabard plissé or et lapis devant
    p = H.point(4.5, 18, 0.06)
    for n, ch in enumerate(("plate", "extra", "plate")):
        dx = (n - 1) * (0.12 + K.chest * 0.04)
        K.make("LowerTorso", _rbox(p + Vector((dx, -0.02 * (n % 2), -0.25)), (0.11 + K.chest * 0.04, 0.04, 0.75), 0.3), ch)
    for side, sx in sides():
        L = K.leg(side, ease, lower=True)
        K.make(side + "LowerLeg", L.band(0.2, 1.1, 0.0, 0.05), "plate")
        K.make(side + "LowerLeg", L.band(6.4, 7.6, 0.0, 0.05), "plate")
        K.make(side + "LowerLeg", L.band(6.9, 7.1, 0.05, 0.02), "trim", "Glow")
    K.boots("base", "plate", "GlowB")


def _mecha(K, top):
    T = K.torso("armor")
    chest, k = K.chest, K.k
    # Plaques blanches laquées, joints sombres, lignes d'énergie et réacteur pectoral
    K.make("UpperTorso", T.patch(18.3, 22.8, 7.0, 13, 0.0, 0.07, 0.05), "plate")
    K.make("UpperTorso", T.patch(13.2, 17.7, 7.0, 13, 0.0, 0.07, 0.05), "plate")
    K.make("UpperTorso", T.patch(15.6, 20.4, 1.0, 6.4, 0.0, 0.06, 0.03), "plate")
    K.make("UpperTorso", T.patch(1.5, 10.5, 4, 13, 0.0, 0.06, 0.03), "plate")
    core = T.point(9.6, 18, 0.07)
    K.make("UpperTorso", ring_upright(tuple(core + Vector((0, -0.02, 0))), chest * 0.12, chest * 0.035, 0.06, 18), "dark")
    K.make("UpperTorso", lowsphere(tuple(core + Vector((0, -0.03, 0))), (chest * 0.085, 0.05, chest * 0.085), 12, 8), "trim", "GlowB")
    for sx in (-1, 1):
        K.make("UpperTorso", T.line([(9.6, 18 + sx * 1.2), (9.6, 18 + sx * 3.4), (12.6, 18 + sx * 4.6)], 0.07, 0.04, 0.03), "trim", "Glow")
        K.make("UpperTorso", T.line([(6.2, 18 + sx * 2.6), (1.2, 18 + sx * 2.6)], 0.06, 0.04, 0.03), "trim", "Glow")
        K.make("UpperTorso", T.line([(5.5, 18 + sx * 4.6), (2, 18 + sx * 4.6)], 0.06, 0.06, 0.03), "extra")
    # Réacteur dorsal plus compact, tuyères lumineuses
    back = T.radius(8, 6)
    zmid = T.heights[8]
    K.make("UpperTorso_Deco", _rbox((0, back + 0.18 * k, zmid), (chest * 0.46, 0.3 * k, (T.heights[12] - T.heights[4])), 0.3), "plate")
    for sx in (-1, 1):
        nz = T.heights[4] - 0.05
        K.make("UpperTorso_Deco", prism((sx * chest * 0.14, back + 0.2 * k, nz + 0.1), (sx * chest * 0.15, back + 0.22 * k, nz - 0.25 * k),
                                        0.08 * k, 0.12 * k, sides=10), "dark")
        K.make("UpperTorso_GlowDeco", lowsphere((sx * chest * 0.15, back + 0.22 * k, nz - 0.24 * k), (0.09 * k, 0.09 * k, 0.03), 10, 4),
               "trim")
        K.make("UpperTorso_Deco", _rbox((sx * chest * 0.27, back + 0.3 * k, T.heights[12] + 0.15 * k), (0.06, 0.08, 0.5 * k), 0.4), "dark")
    # Épaulières carrées mais placées plus bas et plus à l'extérieur : le visage reste visible
    for side, sx in sides():
        A = K.arm(side)
        jo = 0 if sx > 0 else 12
        r = (A.radius(1.5, jo) + A.radius(1.5, 6) + A.radius(1.5, 18)) / 3
        # Correctif : le dessus de la manche noire (anneau à 0,72 r, au ras de heights[0]) affleurait au sommet de
        # l'épaulière (scintillement) et dépassait côté cou ; l'épaulière déborde maintenant vers le cou et 12 % plus haut
        cx = A.centers[0][0] + sx * r * 0.3
        z = A.heights[0] - r * 0.33
        K.make(side + "UpperArm", _rbox((cx, A.centers[0][1], z), (r * 2.2, r * 1.95, r * 0.9), 0.3, taper_top=0.95), "plate")
        K.make(side + "UpperArm", _rbox((cx + sx * r * 0.4, A.centers[0][1] - r * 1.07, z - r * 0.1), (r * 1.1, 0.05, r * 0.16), 0.4), "trim", "Glow")
        K.make(side + "UpperArm", _rbox((cx + sx * r * 1.12, A.centers[0][1], z), (0.06, r * 1.4, r * 0.5), 0.4), "extra")
        K.make(side + "UpperArm", A.patch((jo - 5) % 24, (jo - 5) % 24 + 10, 2.5, 7.6, 0.0, 0.06, 0.03), "plate")
        K.make(side + "UpperArm", A.band(7.0, 7.6, 0.06, 0.03), "trim", "Glow")
        B = K.arm(side, lower=True)
        K.make(side + "LowerArm", B.patch(0, 24, 2.5, 8, 0.0, 0.07, sj=16), "plate")
        K.make(side + "LowerArm", B.line([(3, 0 if sx > 0 else 12), (7.5, 0 if sx > 0 else 12)], 0.07, 0.05, 0.03), "trim", "Glow")
    K.gloves("dark", "plate", glow="Glow")
    # Casque ouvert : arceau blanc, oreillettes, antennes ; visière lumineuse devant les yeux
    s, R = K.skull_c, K.skull_r
    K.make("Head_Deco", _sphere_patch(tuple(s + Vector((0, 0.04, 0.03))), (R.x * 1.12, R.y * 1.12, R.z * 1.12),
                                      math.radians(55), math.radians(305), 0.15, 1.5, 0.07, 16, 5), "plate")
    for sx in (-1, 1):
        ear = Vector((sx * R.x * 1.1, s.y + 0.02, K.eye_z))
        K.make("Head_Deco", _rbox(ear, (0.12, R.y * 0.9, R.z * 0.7), 0.5), "plate")
        K.make("Head_GlowDeco", _rbox(ear + Vector((sx * 0.07, 0, 0)), (0.03, R.y * 0.4, R.z * 0.2), 0.4), "trim")
        K.make("Head_Deco", prism(tuple(ear + Vector((0, 0.05, R.z * 0.3))), tuple(ear + Vector((sx * 0.08, 0.2, R.z * 0.3 + 0.55 * k))),
                                  0.035, 0.02, sides=6), "dark")
    K.make("Head_GlowDeco", _sphere_patch((0, K.eye_y + K.head_r * 0.95, K.eye_z + 0.02), (K.head_r * 1.05, K.head_r * 1.0, 0.09),
                                          math.radians(-58), math.radians(58), -0.5, 0.5, 0.03, 12, 2), "trim")


def _mecha_bottom(K):
    ease = _bottom(K.w, K.body, K.g, K.c["base"], "straight", K.name)
    H = K.hips(0.075)
    K.belt(H, "dark", "plate", "Glow")
    for side, sx in sides():
        U = K.leg(side, ease)
        K.make(side + "UpperLeg", U.patch(14, 24, 0.8, 6.5, 0.0, 0.07, 0.04), "plate")
        j = 0 if sx > 0 else 12
        K.make(side + "UpperLeg", U.line([(1.2, j), (6.0, j)], 0.0, 0.05, 0.03), "trim", "Glow")
    K.greaves(ease, "plate", glow="Glow", knee="plate")
    K.boots("plate", "dark", "Glow")


def _marble(K, top):
    T = K.torso("cape")
    chest, k = K.chest, K.k
    J = K.J
    neck = J["Neck"]
    # Statue divine : marbre, fissures d'or lumineuses (kintsugi), toge en travers, laurier sur la tête
    K.make("UpperTorso", T.line([(13, 21.8), (6.5, 18), (0.4, 14)], 0.06, 0.32, 0.06), "plate")
    K.make("UpperTorso", T.line([(13.2, 21.2), (6.8, 17.4), (0.6, 13.4)], 0.13, 0.06, 0.04), "trim")
    cracks = [[(12.6, 14.2), (11.5, 15.0), (10.2, 15.8), (9.4, 15.3), (7.8, 16.4), (6.4, 15.9), (4.6, 16.8), (2.4, 16.2)],
              [(9.4, 15.3), (8.6, 14.0), (7.2, 13.6)],
              [(7.0, 21.2), (5.0, 20.5), (4.0, 19.7), (3.1, 20.4), (1.6, 19.6), (0.6, 20.3)],
              [(12.6, 19.0), (11.2, 20.3), (10.1, 19.9), (8.8, 21.0)],
              [(12, 2.0), (10.4, 3.2), (8.0, 3.0), (6.6, 4.2), (5.3, 3.6), (3.6, 4.8), (1.5, 4.2)],
              [(12.4, 9.5), (10.5, 8.0), (9.0, 8.8), (7.4, 8.1), (5.5, 9.0)]]
    for c in cracks:
        K.make("UpperTorso", T.line(c, 0.0, 0.05, 0.035), "trim", "Glow")
    for side, sx in sides():
        c, r = K.pauldron(side, sx, "base", layers=1, scale=1.0)
        K.make(side + "UpperArm", ring_upright((c.x, c.y - r * 1.05, c.z - r * 0.25), r * 0.3, r * 0.08, 0.08, 12), "trim")
        A = K.arm(side)
        j = 0 if sx > 0 else 12
        K.make(side + "UpperArm", A.line([(2, j + 2), (3.5, j + 0.6), (5.5, j + 1.4), (7, j)], 0.0, 0.03, 0.025), "trim", "Glow")
        B = K.arm(side, lower=True)
        K.make(side + "LowerArm", B.band(6.6, 8, 0.0, 0.05), "trim")
    K.gloves("base", "trim")
    cape_y = max(row[6] for row in T.rows)
    K.make("UpperTorso_CapeDeco", _cape_mesh(chest, cape_y + 0.02, neck.z, J["Waist"].z - 0.6 * k, 1.35, 1.25), "base")
    K.make("UpperTorso_CapeDeco", _cape_mesh(chest, cape_y - 0.015, neck.z - 0.04, J["Waist"].z - 0.56 * k, 1.31, 1.21), "trim")
    # Couronne de laurier d'or : deux branches de feuilles qui se rejoignent devant
    s, R = K.skull_c, K.skull_r
    band_z = K.eye_z + (K.head_hi.z - K.eye_z) * 0.5
    for sx in (-1, 1):
        for n in range(9):
            a = math.radians(170 - n * 17) * sx
            p = Vector((math.sin(a) * R.x * 1.1, s.y - math.cos(a) * R.y * 1.08, band_z + 0.02 * math.sin(n)))
            d = Vector((math.cos(a) * sx, math.sin(a) * sx, 0.45)).normalized()
            for up in (-1, 1):
                leaf = d + Vector((0, 0, 0.6 * up))
                K.make("Head_Deco", _horn(p, leaf, 0.2 * k, 0.05 * k, (0, 0, 0), 3, 4), "trim")
    K.make("Head_GlowDeco", ring((0, s.y, band_z), R.x * 1.1, 0.03, 0.04, 20), "trim")


def _marble_bottom(K):
    ease = _bottom(K.w, K.body, K.g, K.c["base"], "straight", K.name)
    H = K.hips(0.075)
    K.belt(H, "trim", "trim", "Glow")
    K.tassets(ease, "plate", length=0.65)
    for side, sx in sides():
        L = K.leg(side, ease, lower=True)
        for n in range(8):
            j = 3 * n + 1.5
            K.make(side + "LowerLeg", L.line([(0.8, j), (6.8, j)], 0.0, 0.05, 0.04), "plate")
        K.make(side + "LowerLeg", L.band(0.2, 0.9, 0.0, 0.06), "trim")
        K.make(side + "LowerLeg", L.band(6.9, 7.8, 0.0, 0.06), "trim")
        K.make(side + "LowerLeg", L.line([(1.5, 19), (3, 17.8), (4.5, 18.6), (6.0, 17.6)], 0.04, 0.03, 0.025), "trim", "Glow")
    K.boots("base", "trim")


def _demon(K, top):
    T = K.torso("armor")
    chest, k = K.chest, K.k
    J = K.J
    # Armure d'obsidienne et plaques pourpres, fissures de magma, pointes ; grandes cornes, ailes déchirées
    K.make("UpperTorso", T.patch(18.3, 22.9, 7.4, 13, 0.0, 0.07, 0.06), "plate")
    K.make("UpperTorso", T.patch(13.1, 17.7, 7.4, 13, 0.0, 0.07, 0.06), "plate")
    for (i0, i1) in ((5.0, 6.9), (3.0, 4.7), (0.9, 2.7)):
        for j0, j1 in ((15.4, 17.8), (18.2, 20.6)):
            K.make("UpperTorso", T.patch(j0, j1, i0, i1, 0.0, 0.06, 0.03, taper=0.25), "dark")
    K.make("UpperTorso", T.patch(1.2, 10.8, 4.5, 13, 0.0, 0.06, 0.04), "plate")
    magma = [[(13, 18), (10.5, 18.2), (8.6, 17.6), (7.2, 18.3)],
             [(7.2, 18), (5.0, 18), (3.0, 18), (0.8, 18)],
             [(11.6, 21.2), (9.6, 20.3), (8.0, 21.0)],
             [(11.6, 14.8), (9.6, 15.7), (8.0, 15.0)],
             [(12, 4.5), (9, 5.6), (7, 4.8), (5, 6)],
             [(12, 7.5), (10, 6.6), (8, 7.4)],
             [(6.9, 15.2), (6.9, 20.8)], [(4.85, 15.2), (4.85, 20.8)], [(2.8, 15.2), (2.8, 20.8)],
             [(7.4, 13.2), (8.2, 12.2), (10, 12.6), (12.6, 11.8)], [(7.4, 22.8), (8.2, 23.8), (10, 23.4), (12.6, 24.2)]]
    for m in magma:
        K.make("UpperTorso", T.line(m, 0.0, 0.06, 0.05), "trim", "Glow")
    K.collar("trim", 0.18, 0.06)
    for side, sx in sides():
        c, r = K.pauldron(side, sx, "plate", layers=3, scale=1.15, flare=0.6, glow="GlowB")
        for n, (dy, ln) in enumerate(((-0.45, 0.45), (0.0, 0.65), (0.45, 0.45))):
            base = c + Vector((sx * r * 0.55, dy * r, r * 0.3))
            K.make(side + "UpperArm_Deco", _horn(base, (sx * 0.7, dy * 0.3, 1), ln * k, 0.1 * k, (sx * 0.9, 0, -0.1)), "extra")
    K.bracers("plate", glow="Glow", ridge="extra")
    K.gloves("dark", "plate", glow="GlowB", claws="extra")
    # Ailes de démon déchirées : os noirs, membrane pourpre sombre, échancrures
    back = T.radius(9, 6)
    for sx in (-1, 1):
        wing = "UpperTorso_WingADeco" if sx < 0 else "UpperTorso_WingBDeco"  # D126 : une pièce par aile (battement)
        root = Vector((sx * chest * 0.15, back + 0.06, T.heights[10]))
        elbow = root + Vector((sx * (0.5 + chest * 0.22), 0.4 * k, 0.95 * k))
        tips = [elbow + Vector((sx * (0.75 + 0.5 * n) * k, (0.3 + 0.1 * n) * k, (0.35 - 0.85 * n) * k)) for n in range(4)]
        arm_bone = _bone(root, elbow, Vector((0, 0.05, 0.2 * k)), 4)
        K.make(wing, sweep([tuple(p) for p in arm_bone], [0.09 * k, 0.08 * k, 0.07 * k, 0.06 * k], 6), "trim")
        bones = [_bone(elbow, tip, Vector((0, 0.05 * k, 0.1 * k)), 5) for tip in tips]
        for b in bones:
            K.make(wing, sweep([tuple(p) for p in b], [0.055 * k, 0.045 * k, 0.035 * k, 0.025 * k, 0.01 * k], 6), "trim")
        K.make(wing, _membrane(_bone(root, elbow, Vector((0, 0, 0)), 5), bones[0], 0.025, 0.0), "plate")
        for a, b in zip(bones, bones[1:]):
            K.make(wing, _membrane(a, b, 0.025, 0.3 * k), "plate")
        K.make(wing, _horn(elbow, (sx * 0.1, 0, 1), 0.28 * k, 0.06 * k, (sx * 1.0, 0, 0)), "extra")
    # Cornes : deux grandes cornes de bélier-démon (ivoire vers noir), lueur de magma à la base
    s, R = K.skull_c, K.skull_r
    for sx in (-1, 1):
        base = s + Vector((sx * R.x * 0.62, -R.y * 0.15, R.z * 0.6))
        K.make("Head_Deco", _horn(base, (sx * 0.9, 0.1, 0.85), 1.05 * k, 0.17 * k, (sx * -0.3, 0.5, 1.6), 9, 10), "extra")
        K.make("Head_GlowBDeco", ring(tuple(base + Vector((sx * 0.03, 0, 0.02))), 0.17 * k, 0.04, 0.05, 10), "trim")
    # Bandeau à pointes sur le front
    band_z = K.eye_z + (K.head_hi.z - K.eye_z) * 0.42
    K.make("Head_Deco", ring((0, s.y, band_z), R.x * 1.06, 0.05, 0.09, 18), "trim")
    for a in (-0.5, 0.0, 0.5):
        p = Vector((math.sin(a) * R.x * 1.06, s.y - math.cos(a) * R.y * 1.04, band_z + 0.03))
        K.make("Head_Deco", pyramid(tuple(p), tuple(p + Vector((0, -0.03, 0.24 * k))), 0.05 * k, 0.04), "extra")


def _demon_bottom(K):
    ease = _bottom(K.w, K.body, K.g, K.c["base"], "straight", K.name)
    J = K.J
    k = K.k
    H = K.hips(0.075)
    K.belt(H, "trim", "plate", "Glow")
    K.tassets(ease, "plate", length=0.65)
    K.greaves(ease, "plate", glow="Glow", knee="dark", knee_spike="extra")
    K.boots("dark", "plate", "GlowB", toe_spike=True)
    # Queue fine et fouettée, pointe en fer de lance
    root = J["Root"]
    by = H.radius(5, 6) + 0.05
    z0 = root.z + 0.15
    pts = [(0, by, z0), (0.05, by + 0.45 * k, z0 - 0.45 * k), (0.25, by + 0.95 * k, z0 - 0.8 * k), (0.6, by + 1.35 * k, z0 - 0.75 * k),
           (0.85, by + 1.6 * k, z0 - 0.4 * k), (0.95, by + 1.65 * k, z0 + 0.05 * k)]
    K.make("LowerTorso_TailDeco", sweep(pts, [0.12 * k, 0.1 * k, 0.08 * k, 0.065 * k, 0.05 * k, 0.04 * k], 8), "dark")
    tip = Vector(pts[-1])
    K.make("LowerTorso_TailDeco", _rbox(tip + Vector((0, 0, 0.12 * k)), (0.06, 0.3 * k, 0.32 * k), 0.2, taper_top=0.05), "plate")
    K.make("LowerTorso_GlowTailDeco", sweep(pts[:5], [0.04 * k] * 5, 5), "trim")


BUILDERS = {
    "CosmicEmperor": (_cosmic, _cosmic_bottom),
    "GoldenTitan": (_titan, _titan_bottom),
    "NeonPhantom": (_phantom, _phantom_bottom),
    "GymDragon": (_dragon, _dragon_bottom),
    "EternalSun": (_sun, _sun_bottom),
    "MechaMogger": (_mecha, _mecha_bottom),
    "MarbleStatue": (_marble, _marble_bottom),
    "InfernalDemon": (_demon, _demon_bottom),
}


def build_premium(w, body, g, name):
    top, bottom = BUILDERS[name]
    w.start(name + "Top")
    K = Kit(w, body, g, name)
    top(K, True)
    w.start(name + "Bottom")
    bottom(K)

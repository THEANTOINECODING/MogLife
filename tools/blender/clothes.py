"""
Hauts et bas de la boutique de MOG LIFE, refaits (D114) : chargé par build_style.py (exec) après accessories.py et
hair.py ; remplace build_tops et build_bottoms.

Avant : des boules gonflées (un ballon pour la poitrine, des boules pour les manches) et des barres dorées posées en
travers. Maintenant chaque vêtement est une COQUE AJUSTÉE, mesurée sur le vrai corps du stade (tranches horizontales,
comme les tenues de outfit_looks.py) : il épouse un Normie comme un GOD MOGGER. Les finitions (ourlets, poignets,
ceintures, cols, emmanchures) sont des anneaux qui suivent le tissu, et les petits détails (boutons, poche, boucle,
cordons) sont posés sur sa surface. Chaque objet garde exactement ses pièces (l'installation dans Studio les compte).
"""
import math
from mathutils import Vector

N = 16                                   # points par tranche (tous les 22,5°) ; angle 270° = devant (-Y)
FRONT = 1.5 * math.pi


class Shell:
    """Coque mesurée sur une partie du corps : `heights` (z des tranches), `centers` (axe de chaque tranche),
    `ease(t, a)` = aisance (studs) à la hauteur relative t (0 en bas, 1 en haut) et à l'angle a."""

    def __init__(self, g, part, heights, centers=None, ease=None):
        self.heights = heights
        self.centers = centers or [(0.0, 0.0)] * len(heights)
        # Mesuré 3 fois plus fin, chaque point garde le plus grand rayon de ses voisins (et la flèche de la corde) :
        # entre deux points, le tissu ne rentre jamais dans un muscle rond (pectoraux du GOD MOGGER)
        fine = _body_radii(g["stage"], part, heights, N * 3, centers)
        chord = 1 / math.cos(math.pi / N)
        base = [[max(row[(j * 3 + k) % (N * 3)] for k in (-1, 0, 1)) * chord for j in range(N)] for row in fine]
        ease = ease or (lambda t, a: 0.08)
        last = len(heights) - 1
        self.r = [[base[i][j] + ease(i / last, 2 * math.pi * j / N) for j in range(N)] for i in range(len(heights))]

    def _ring(self, i, extra):
        cx, cy = self.centers[i]
        return [(cx + math.cos(2 * math.pi * j / N) * (self.r[i][j] + extra),
                 cy + math.sin(2 * math.pi * j / N) * (self.r[i][j] + extra), self.heights[i]) for j in range(N)]

    def mesh(self, i0=0, i1=None, extra=0.0, open_ends=True):
        """Loft des tranches i0..i1 (comprises), décollé de `extra`."""
        i1 = len(self.heights) - 1 if i1 is None else i1
        bm = _loft([self._ring(i, extra) for i in range(i0, i1 + 1)])
        if open_ends:
            bmesh.ops.delete(bm, geom=[f for f in bm.faces if len(f.verts) > 4], context="FACES")
        return bm

    def bulge(self, t, a, spread=0.6):
        """De combien le tissu avance au plus autour de l'angle a (±spread) : pour poser un motif devant les muscles."""
        r0 = self.point(t, a)[0]
        return max((self.point(t, a + spread * k / 4)[0] - Vector((0, 0, r0.z))).dot(Vector((math.cos(a), math.sin(a), 0)))
                   for k in range(-4, 5)) - (r0 - Vector((0, 0, r0.z))).dot(Vector((math.cos(a), math.sin(a), 0)))

    def point(self, t, a, extra=0.0):
        """Point du tissu à la hauteur relative t et à l'angle a (radians), décollé de `extra`, et sa normale."""
        f = max(0.0, min(1.0, t)) * (len(self.heights) - 1)
        i0 = min(int(f), len(self.heights) - 2)
        u = f - i0
        s = (a % (2 * math.pi)) / (2 * math.pi) * N
        j0 = int(s) % N
        j1 = (j0 + 1) % N
        v = s - int(s)
        r = ((self.r[i0][j0] * (1 - v) + self.r[i0][j1] * v) * (1 - u)
             + (self.r[i0 + 1][j0] * (1 - v) + self.r[i0 + 1][j1] * v) * u) + extra
        cx = self.centers[i0][0] * (1 - u) + self.centers[i0 + 1][0] * u
        cy = self.centers[i0][1] * (1 - u) + self.centers[i0 + 1][1] * u
        z = self.heights[i0] * (1 - u) + self.heights[i0 + 1] * u
        n = Vector((math.cos(a), math.sin(a), 0))
        return Vector((cx, cy, z)) + n * r, n


def carve(bm, cut):
    """Retire les faces dont le centre (x, y, z) répond à `cut` : emmanchures, encolures (la peau du corps, dessous,
    apparaît dans le trou ; les MeshParts ne montrent pas leur face intérieure)."""
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if cut(f.calc_center_median())], context="FACES")
    for _ in range(3):                    # bords francs : pas de face isolée accrochée par un coin
        loose = [f for f in bm.faces if sum(e.is_boundary for e in f.edges) >= 3
                 or any(not v.is_manifold for v in f.verts)]
        if not loose:
            break
        bmesh.ops.delete(bm, geom=loose, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    return bm


def flat(center, normal, up, size):
    """Petit pavé posé à plat sur le tissu (poche, boucle, étiquette) : size = (largeur, épaisseur, hauteur)."""
    side = Vector(up).cross(Vector(normal)).normalized()
    return frame_box(center, side, Vector(up), (size[0], size[2], size[1]))


def stud(center, normal, r):
    """Bouton : pastille aplatie posée sur le tissu."""
    n = Vector(normal).normalized()
    bm = lowsphere((0, 0, 0), (r, r, r * 0.45), 6, 4)
    rot = n.to_track_quat("Z", "Y").to_matrix()
    for v in bm.verts:
        v.co = Vector(center) + rot @ v.co
    return bm


def torso_heights(g, low_frac=0.0, rows=11, top_extra=0.02):
    J = g["J"]
    waist, neck = J["Waist"], J["Neck"]
    low = waist.z - 0.06 + (neck.z - waist.z) * low_frac
    # Le haut du torse (trapèzes, cou) monte au-dessus de l'articulation du cou, beaucoup chez les gros stades :
    # le tissu monte avec lui, sinon une bande de peau apparaît sur les épaules
    skin = bpy.data.objects.get(g["stage"] + "_UpperTorso")
    rise = (max(v.co.z for v in skin.data.vertices) - neck.z) * 0.55 if skin else 0.0
    high = neck.z + max(top_extra, rise)
    return [low + (high - low) * i / (rows - 1) for i in range(rows)]


def limb_shell(g, part, top, bottom, ease, rows=7):
    heights = [top.z + (bottom.z - top.z) * i / (rows - 1) for i in range(rows)]
    centers = [(top.x + (bottom.x - top.x) * i / (rows - 1), top.y + (bottom.y - top.y) * i / (rows - 1))
               for i in range(rows)]
    return Shell(g, part, heights, centers, ease)


def sleeve(g, side, end, ease, rows=7):
    """Manche : part au-dessus du deltoïde (sinon l'épaule perce le tissu), fermée en haut ; s'arrête à `end`."""
    sh = g["J"][side + "Shoulder"]
    top = Vector((sh.x, sh.y, sh.z + g["cfg"]["delt"] * 0.95))
    shell = limb_shell(g, side + "UpperArm", top, end, ease, rows)
    bm = shell.mesh(open_ends=False)
    low = min(v.co.z for v in bm.verts)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if len(f.verts) > 4 and f.calc_center_median().z < low + 0.01],
                     context="FACES")
    return shell, bm


def side_angle(a):
    """0 devant/derrière, 1 pile sur le côté (sous le bras)."""
    return abs(math.cos(a))


class Solid:
    """Passe les formes à la garde-robe en donnant une épaisseur de tissu aux coques ouvertes (ourlets, emmanchures) :
    chaque pièce reste un volume fermé (validate_style.py le vérifie)."""

    def __init__(self, w):
        self.w = w

    def start(self, item):
        self.w.start(item)

    def make(self, part, bm, cell, front_cell=None):
        if any(e.is_boundary for e in bm.edges):
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
            bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.025)
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        self.w.make(part, bm, cell, front_cell=front_cell)


# ------------------------------------------------------------------ hauts
def build_tops(w, g):
    w = Solid(w)
    J, cfg = g["J"], g["cfg"]
    neck, waist = J["Neck"], J["Waist"]
    chest_w = g["chest_w"]
    neck_r = cfg["neck"]

    def tank_cuts(shell, scoop_front, scoop_back, strap):
        """Débardeur : encolure ronde devant et derrière, bretelles de largeur `strap` (part du torse) posées juste à
        côté du cou, emmanchures profondes au-delà. Tout est mesuré depuis le cou : chez les gros stades, le cou
        large ne mange plus les bretelles."""
        z_arm = shell.heights[0] + (shell.heights[-1] - shell.heights[0]) * 0.62
        z_top = shell.heights[-1]
        inner = neck_r * 1.05 + 0.04
        outer = inner + max(0.16, chest_w * strap * 0.35)

        def cut(c):
            if c.z < z_arm:
                return False
            u = (c.z - z_arm) / max(1e-4, z_top - z_arm)
            if abs(c.x) > outer and u > 0.15:
                return True                                               # emmanchure
            depth = scoop_front if c.y < 0 else scoop_back
            return abs(c.x) < inner and u > 1 - depth                     # encolure
        return cut

    # -------- Débardeur trop petit : blanc, s'arrête au-dessus du nombril, liseré rouge (il a rétréci au lavage)
    w.start("TightTank")
    tight = Shell(g, "UpperTorso", torso_heights(g, 0.38, 13), ease=lambda t, a: 0.075)
    w.make("UpperTorso", carve(tight.mesh(), tank_cuts(tight, 0.55, 0.3, 0.42)), "white")
    w.make("UpperTorso", tight.mesh(0, 1, 0.03), "red")                   # ourlet roulé, trop haut
    w.make("UpperTorso", tight.mesh(4, 5, 0.025), "red")                  # rayure de sport

    # -------- Débardeur MOG : noir, dos nageur, haltère doré sur la poitrine, finitions dorées
    w.start("MogTank")
    mog = Shell(g, "UpperTorso", torso_heights(g, 0.0, 15), ease=lambda t, a: 0.06 + 0.02 * t)
    cut = tank_cuts(mog, 0.45, 0.35, 0.4)
    w.make("UpperTorso", carve(mog.mesh(), cut), "black")
    # Haltère doré en relief sur la poitrine (dessiné en entier dans la texture, il se lisait comme une lettre)
    pc, nc = mog.point(0.6, FRONT, 0.03 + mog.bulge(0.6, FRONT))
    bar = chest_w * 0.17
    w.make("UpperTorso", flat(pc, nc, (0, 0, 1), (bar * 2, 0.04, 0.06)), "gold")
    for sx in (-1, 1):
        pp = Vector((sx * bar, pc.y, pc.z))
        w.make("UpperTorso", flat(pp, nc, (0, 0, 1), (0.1, 0.06, 0.26)), "gold")
        w.make("UpperTorso", flat(pp + Vector((sx * 0.08, 0, 0)), nc, (0, 0, 1), (0.07, 0.06, 0.17)), "gold")
    w.make("UpperTorso", mog.mesh(0, 1, 0.035), "gold")                   # ourlet doré

    # -------- Chemise hawaïenne : ample, manches courtes évasées, col ouvert, boutons nacrés, pans qui flottent
    w.start("Hawaiian")
    hw = Shell(g, "UpperTorso", torso_heights(g), ease=lambda t, a: 0.11 + 0.06 * (1 - t) ** 2)
    w.make("UpperTorso", carve(hw.mesh(),
                               lambda c: c.y < 0 and c.z > hw.heights[-4] and abs(c.x) < neck_r * 0.9 + (c.z - hw.heights[-4]) * 0.8),
           "hawaiian", front_cell="hawaiian_front")
    w.make("UpperTorso", hw.mesh(0, 1, 0.03), "hawaiian")                 # ourlet
    for k in range(3):                                                    # boutons
        p, n = hw.point(0.2 + k * 0.17, FRONT, 0.02)
        w.make("UpperTorso", stud(p, n, 0.05), "white")
    for sx in (-1, 1):                                                    # revers du col, rabattus sur la poitrine
        p, n = hw.point(0.86, FRONT + sx * 0.32, 0.03)
        w.make("UpperTorso", flat(p, n, (sx * 0.35, 0, 1), (chest_w * 0.16, 0.035, g["h"] * 0.16)), "hawaiian")
    for side, _ in sides():
        sh, el = J[side + "Shoulder"], J[side + "Elbow"]
        end = sh.lerp(el, 0.55)
        sl, bm = sleeve(g, side, end, lambda t, a: 0.12 + 0.07 * t * t)
        w.make(side + "UpperArm", bm, "hawaiian")
        w.make(side + "UpperArm", sl.mesh(5, 6, 0.025), "white")      # bord de manche

    # -------- Veste de survêtement : col montant, fermeture éclair chromée, bandes blanches, poignets et bas côtelés
    w.start("TrackJacket")
    hs = torso_heights(g, top_extra=0.16)
    tj = Shell(g, "UpperTorso", hs, ease=lambda t, a: 0.1 + 0.02 * math.sin(math.pi * t))
    w.make("UpperTorso", tj.mesh(), "track", front_cell="track_front")
    w.make("UpperTorso", tj.mesh(0, 1, 0.03), "white")                    # bas côtelé
    w.make("UpperTorso", tj.mesh(9, 10, 0.02), "white")                  # col montant
    p, n = tj.point(0.97, FRONT, 0.04)
    w.make("UpperTorso", flat(p - Vector((0, 0, 0.05)), n, (0, 0, 1), (0.07, 0.04, 0.12)), "chrome")   # tirette
    for side, _ in sides():
        sh, el, wr = J[side + "Shoulder"], J[side + "Elbow"], J[side + "Wrist"]
        _, bm = sleeve(g, side, el, lambda t, a: 0.11)
        w.make(side + "UpperArm", bm, "track")
        top = Vector((el.x, el.y, el.z + cfg["forearm"] * 0.7))
        lower = limb_shell(g, side + "LowerArm", top, el.lerp(wr, 0.9), lambda t, a: 0.095 + 0.03 * t)
        w.make(side + "LowerArm", lower.mesh(), "track")
        w.make(side + "LowerArm", lower.mesh(5, 6, 0.02), "white")        # poignet côtelé

    # -------- Peignoir de boxeur : satin rouge, col châle blanc, ceinture nouée, pans sur les cuisses, liserés dorés
    w.start("BoxerRobe")
    rb = Shell(g, "UpperTorso", torso_heights(g), ease=lambda t, a: 0.15 + 0.04 * (1 - t))
    w.make("UpperTorso", carve(rb.mesh(),
                               lambda c: c.y < 0 and c.z > rb.heights[5] and abs(c.x) < neck_r * 0.5 + (c.z - rb.heights[5]) * 0.45),
           "satin")
    for sx in (-1, 1):                                                    # col châle : deux bandes en V jusqu'à la ceinture
        pts = [rb.point(0.3 + k * 0.1, FRONT + sx * (0.06 + 0.055 * k), 0.035) for k in range(8)]
        band(w, "UpperTorso", pts, 0.16, 0.04, "white")
    for side, _ in sides():
        sh, el = J[side + "Shoulder"], J[side + "Elbow"]
        sl, bm = sleeve(g, side, sh.lerp(el, 0.7), lambda t, a: 0.15 + 0.08 * t)
        w.make(side + "UpperArm", bm, "satin")
        w.make(side + "UpperArm", sl.mesh(5, 6, 0.025), "gold")
    root = J["Root"]
    skirt_h = [root.z - 0.26 + i * 0.075 for i in range(11)]
    skirt = Shell(g, "LowerTorso", skirt_h, ease=lambda t, a: 0.17 + 0.08 * (1 - t))
    w.make("LowerTorso", skirt.mesh(open_ends=False), "satin")
    w.make("LowerTorso", skirt.mesh(7, 8, 0.05), "white")                 # ceinture
    p, n = skirt.point(0.75, FRONT + 0.35, 0.08)
    w.make("LowerTorso", lowsphere(tuple(p), (0.09, 0.07, 0.08), 6, 4), "white")    # noeud
    for k, sway in enumerate((0.0, 0.05)):                                # pans de la ceinture
        top = p + Vector((sway, -0.02, -0.05))
        w.make("LowerTorso", prism(tuple(top), tuple(top + Vector((sway * 2 + 0.03 * k, -0.03, -0.32))), 0.05, 0.04, 4), "white")
    for side, _ in sides():
        hip, knee = J[side + "Hip"], J[side + "Knee"]
        flap = limb_shell(g, side + "UpperLeg", Vector((hip.x, 0, hip.z + 0.05)), hip.lerp(knee, 0.78),
                          lambda t, a: 0.17 + 0.12 * t)
        w.make(side + "UpperLeg", flap.mesh(), "satin")
        w.make(side + "UpperLeg", flap.mesh(5, 6, 0.03), "gold")         # liseré doré du bas

    # -------- Haut de pyjama : rayé, col pointu, poche, boutons, poignets à liseré
    w.start("PajamaTop")
    pj = Shell(g, "UpperTorso", torso_heights(g), ease=lambda t, a: 0.12 + 0.03 * (1 - t))
    w.make("UpperTorso", carve(pj.mesh(),
                               lambda c: c.y < 0 and c.z > pj.heights[-3] and abs(c.x) < neck_r * 0.7 + (c.z - pj.heights[-3]) * 0.5),
           "pajama", front_cell="pajama_front")
    w.make("UpperTorso", pj.mesh(0, 1, 0.03), "white")                    # liseré du bas
    for k in range(4):
        p, n = pj.point(0.15 + k * 0.18, FRONT, 0.02)
        w.make("UpperTorso", stud(p, n, 0.045), "white")
    for sx in (-1, 1):                                                    # col pointu
        p, n = pj.point(0.9, FRONT + sx * 0.3, 0.03)
        w.make("UpperTorso", pyramid(tuple(p + Vector((0, 0, 0.06))), tuple(p + Vector((sx * 0.05, -0.02, -0.16))),
                                     0.09, 0.025), "white")
    p, n = pj.point(0.62, FRONT + 0.55, 0.025)                            # poche sur la gauche de la poitrine
    w.make("UpperTorso", flat(p, n, (0, 0, 1), (chest_w * 0.2, 0.03, g["h"] * 0.17)), "pajama")
    w.make("UpperTorso", flat(p + n * 0.02 + Vector((0, 0, g["h"] * 0.075)), n, (0, 0, 1),
                              (chest_w * 0.21, 0.03, 0.03)), "white")
    for side, _ in sides():
        sh, el, wr = J[side + "Shoulder"], J[side + "Elbow"], J[side + "Wrist"]
        _, bm = sleeve(g, side, el, lambda t, a: 0.12)
        w.make(side + "UpperArm", bm, "pajama")
        top = Vector((el.x, el.y, el.z + cfg["forearm"] * 0.7))
        lower = limb_shell(g, side + "LowerArm", top, el.lerp(wr, 0.88), lambda t, a: 0.11 + 0.04 * t)
        w.make(side + "LowerArm", lower.mesh(), "pajama")
        w.make(side + "LowerArm", lower.mesh(5, 6, 0.025), "white")


# ------------------------------------------------------------------ bas
def build_bottoms(w, g):
    w = Solid(w)
    J, cfg = g["J"], g["cfg"]
    root = J["Root"]
    hips_h = [root.z - 0.26 + i * 0.075 for i in range(11)]

    def legs(cell, length, ease_up, ease_low=None, upper_profile=None, lower_profile=None):
        shells = {}
        for side, _ in sides():
            hip, knee, ankle = J[side + "Hip"], J[side + "Knee"], J[side + "Ankle"]
            top = Vector((hip.x, 0, hip.z + 0.05))
            if length == "short":
                up = limb_shell(g, side + "UpperLeg", top, hip.lerp(knee, 0.58),
                                lambda t, a: ease_up + (upper_profile(t) if upper_profile else 0))
                w.make(side + "UpperLeg", up.mesh(), cell)
                shells[side] = (up, None)
            else:
                up = limb_shell(g, side + "UpperLeg", top, knee, lambda t, a: ease_up + (upper_profile(t) if upper_profile else 0))
                low = limb_shell(g, side + "LowerLeg", knee, Vector((ankle.x, ankle.y, ankle.z + 0.12)),
                                 lambda t, a: ease_low + (lower_profile(t) if lower_profile else 0))
                w.make(side + "UpperLeg", up.mesh(), cell)
                w.make(side + "LowerLeg", low.mesh(), cell)
                shells[side] = (up, low)
        return shells

    # -------- Short fluo : vert fluo, ceinture blanche, cordon noir, liserés blancs aux cuisses
    w.start("FluoShorts")
    hips = Shell(g, "LowerTorso", hips_h, ease=lambda t, a: 0.07)
    w.make("LowerTorso", hips.mesh(open_ends=False), "fluo")
    w.make("LowerTorso", hips.mesh(8, 10, 0.03), "white")                 # ceinture élastique
    p, n = hips.point(0.88, FRONT, 0.05)
    for sx in (-1, 1):                                                    # cordon noué
        w.make("LowerTorso", prism(tuple(p), tuple(p + Vector((sx * 0.06, -0.02, -0.16))), 0.025, 0.02, 4), "black")
    w.make("LowerTorso", lowsphere(tuple(p), (0.04, 0.03, 0.035), 5, 4), "black")
    shells = legs("fluo", "short", 0.09, upper_profile=lambda t: 0.06 * t * t)
    for side, sx in sides():
        up, _ = shells[side]
        w.make(side + "UpperLeg", up.mesh(5, 6, 0.025), "white")          # liseré du bas
        a = 0.0 if sx > 0 else math.pi                                    # bande blanche sur le côté
        for k in range(4):
            p0, n0 = up.point(k / 4, a, 0.02)
            p1, _ = up.point((k + 1) / 4, a, 0.02)
            w.make(side + "UpperLeg", frame_box((p0 + p1) / 2, p1 - p0, Vector((0, 1, 0)),
                                                ((p1 - p0).length * 1.1, 0.07, 0.03)), "white")

    # -------- Jogging en velours : ample aux cuisses, resserré aux chevilles (et qui bouffe au-dessus), cordons dorés
    w.start("VelvetJoggers")
    hips = Shell(g, "LowerTorso", hips_h, ease=lambda t, a: 0.09)
    w.make("LowerTorso", hips.mesh(open_ends=False), "velvet")
    w.make("LowerTorso", hips.mesh(8, 10, 0.035), "purple")              # ceinture large
    p, n = hips.point(0.85, FRONT, 0.06)
    for sx in (-1, 1):                                                    # cordons à embouts dorés
        tip = p + Vector((sx * 0.05, -0.03, -0.26))
        w.make("LowerTorso", prism(tuple(p + Vector((sx * 0.03, 0, 0))), tuple(tip), 0.022, 0.02, 4), "white")
        w.make("LowerTorso", prism(tuple(tip), tuple(tip + Vector((0, 0, -0.07))), 0.03, 0.03, 5), "gold")
    shells = legs("velvet", "long", 0.13, 0.11, upper_profile=lambda t: 0.03 * math.sin(math.pi * t),
                  lower_profile=lambda t: 0.06 * math.sin(math.pi * min(1, t * 1.15)) ** 2)
    for side, _ in sides():
        _, low = shells[side]
        w.make(side + "LowerLeg", low.mesh(5, 6, -0.03), "purple")       # poignet de cheville serré

    # -------- Pantalon de cuir : moulant et brillant, grosse boucle dorée, couture latérale, genoux renforcés
    w.start("LeatherPants")
    hips = Shell(g, "LowerTorso", hips_h, ease=lambda t, a: 0.05)
    w.make("LowerTorso", hips.mesh(open_ends=False), "leather")
    w.make("LowerTorso", hips.mesh(8, 9, 0.03), "strap")                 # ceinture
    p, n = hips.point(0.85, FRONT, 0.05)
    w.make("LowerTorso", flat(p, n, (0, 0, 1), (0.24, 0.05, 0.17)), "gold")       # boucle
    w.make("LowerTorso", flat(p + n * 0.03, n, (0, 0, 1), (0.13, 0.05, 0.08)), "strap")
    shells = legs("leather", "long", 0.045, 0.045, lower_profile=lambda t: 0.05 * t * t)
    for side, sx in sides():
        up, low = shells[side]
        a = 0.0 if sx > 0 else math.pi
        for shell, part in ((up, "UpperLeg"), (low, "LowerLeg")):        # couture surpiquée sur le côté
            for k in range(3):
                p0, _ = shell.point(k / 3, a, 0.015)
                p1, _ = shell.point((k + 1) / 3, a, 0.015)
                w.make(side + part, frame_box((p0 + p1) / 2, p1 - p0, Vector((0, 1, 0)),
                                              ((p1 - p0).length * 1.05, 0.04, 0.025)), "gold")
        pk, nk = up.point(0.9, FRONT, 0.02)                              # genouillère cousue
        w.make(side + "UpperLeg", flat(pk, nk, (0, 0, 1), (cfg["thigh"] * 1.1, 0.035, 0.22)), "strap")

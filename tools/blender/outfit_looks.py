"""Twenty original MOG LIFE outfits (plus seven Robux outfits, D121 and D122), built against each stage's actual body shell.

Loaded by build_style.py. No game prices live here. Every garment has matching
R15 part keys on all fourteen bodies so growth can interpolate continuously.
"""

from mathutils.bvhtree import BVHTree


LOOKS = (
    # id, display idea, primary, secondary, accent, upper silhouette, lower silhouette, signature
    ("CircuitAce", "neon racing", (0.035, 0.065, 0.17), (0.02, 0.86, 0.91), (0.98, 0.16, 0.42), "racer", "taper", "chevron"),
    ("BoardwalkBolt", "sunny surf", (0.98, 0.48, 0.15), (0.08, 0.68, 0.70), (1.0, 0.92, 0.58), "open", "short", "wave"),
    ("VelvetVillain", "stage lounge", (0.25, 0.075, 0.36), (0.80, 0.52, 0.89), (0.96, 0.73, 0.25), "blazer", "flare", "lapel"),
    ("MoonMechanic", "comic astronaut", (0.80, 0.87, 0.90), (0.16, 0.20, 0.28), (0.96, 0.36, 0.12), "utility", "cargo", "harness"),
    ("GoldenHour", "parade champion", (0.94, 0.78, 0.31), (0.96, 0.94, 0.75), (0.52, 0.28, 0.10), "varsity", "short", "medal"),
    ("BubblegumBlitz", "hyperpop athlete", (0.93, 0.16, 0.47), (0.38, 0.10, 0.58), (0.97, 0.76, 0.89), "hoodie", "taper", "spiral"),
    ("BrickhouseBrawler", "ring entrance", (0.76, 0.065, 0.085), (0.11, 0.10, 0.14), (0.98, 0.88, 0.64), "robe", "short", "lapel"),
    ("ThunderArcade", "arcade hero", (0.14, 0.13, 0.36), (0.46, 0.30, 0.92), (0.95, 0.95, 0.18), "hoodie", "cargo", "zigzag"),
    ("RoyalRumble", "ridiculous royalty", (0.33, 0.07, 0.24), (0.95, 0.75, 0.16), (0.97, 0.91, 0.78), "cape", "short", "crown"),
    ("MidnightExpress", "after-dark suit", (0.055, 0.075, 0.12), (0.34, 0.65, 0.69), (0.90, 0.89, 0.83), "blazer", "straight", "tie"),
    ("JungleJolt", "tropical lifter", (0.08, 0.42, 0.20), (0.91, 0.26, 0.14), (0.98, 0.79, 0.26), "open", "short", "leaf"),
    ("FrostFlex", "snow-day giant", (0.56, 0.78, 0.93), (0.11, 0.31, 0.52), (0.98, 0.98, 0.91), "puffer", "cargo", "quilt"),
    ("TurboTaxi", "comic courier", (0.96, 0.75, 0.09), (0.10, 0.10, 0.12), (0.98, 0.98, 0.84), "racer", "short", "checker"),
    ("DiscoDynamo", "retro dance", (0.36, 0.12, 0.57), (0.98, 0.52, 0.12), (0.88, 0.92, 0.96), "blazer", "flare", "star"),
    ("CometCoach", "space gym teacher", (0.12, 0.23, 0.42), (0.97, 0.33, 0.29), (0.97, 0.89, 0.69), "varsity", "taper", "orbit"),
    ("SunsetStunt", "stunt pilot", (0.83, 0.27, 0.18), (0.98, 0.66, 0.30), (0.15, 0.14, 0.17), "bomber", "taper", "wings"),
    ("GarageGremlin", "garage inventor", (0.22, 0.35, 0.37), (0.89, 0.44, 0.16), (0.96, 0.88, 0.67), "utility", "cargo", "tool"),
    ("CloudCruiser", "dreamy street", (0.80, 0.77, 0.96), (0.39, 0.56, 0.88), (0.97, 0.93, 0.98), "puffer", "baggy", "cloud"),
    ("IronMeteor", "comic armor", (0.20, 0.23, 0.29), (0.71, 0.79, 0.78), (0.92, 0.27, 0.12), "armor", "straight", "meteor"),
    ("PaperCrown", "absurd finale", (0.96, 0.91, 0.73), (0.91, 0.65, 0.15), (0.16, 0.52, 0.68), "cape", "flare", "crown"),
    # D121 : tenues Robux (Game Pass), « Drip au maximum » : plus de pièces et de volumes que toutes les autres.
    # Leurs cases d'atlas suivent les 20 premières (rangée 13 colonnes 4 à 7, puis rangée 14).
    ("CosmicEmperor", "galactic emperor", (0.23, 0.10, 0.52), (0.05, 0.07, 0.22), (1.0, 0.80, 0.28), "cape", "straight", "crown"),
    ("GoldenTitan", "molten gold colossus", (0.96, 0.72, 0.16), (0.99, 0.93, 0.70), (0.92, 0.32, 0.08), "armor", "straight", "meteor"),
    ("NeonPhantom", "neon night runner", (0.04, 0.05, 0.09), (0.12, 0.14, 0.22), (0.08, 0.95, 1.0), "hoodie", "taper", "zigzag"),
    # D122 : tenues Robux haut de gamme (choix d'Antoine) : Dragon de la Salle, Soleil Éternel, Mecha-Mogger,
    # Statue de Marbre. Leurs cases d'atlas sont à droite (colonnes 8 à 15, rangées 6 et 7), libres.
    ("GymDragon", "gym dragon", (0.05, 0.42, 0.21), (0.03, 0.11, 0.07), (1.0, 0.55, 0.08), "armor", "straight", "scales"),
    ("EternalSun", "eternal sun", (0.98, 0.74, 0.16), (1.0, 0.95, 0.80), (1.0, 0.40, 0.06), "robe", "straight", "sunburst"),
    ("MechaMogger", "mecha mogger", (0.82, 0.85, 0.90), (0.14, 0.15, 0.20), (0.10, 0.85, 1.0), "armor", "straight", "panels"),
    ("MarbleStatue", "marble statue", (0.94, 0.93, 0.90), (0.60, 0.60, 0.63), (0.95, 0.75, 0.25), "cape", "straight", "marble"),
    # D125 : tenue Robux « Démon des Enfers » (les huit tenues Robux sont construites par premium_looks.py)
    ("InfernalDemon", "infernal demon", (0.07, 0.045, 0.05), (0.52, 0.035, 0.045), (1.0, 0.22, 0.04), "armor", "straight", "panels"),
)
PREMIUM_LOOKS = ("CosmicEmperor", "GoldenTitan", "NeonPhantom", "GymDragon", "EternalSun", "MechaMogger", "MarbleStatue",
                 "InfernalDemon")  # D125 : refaites dans premium_looks.py
SIGNATURE_LOOKS = ("GymDragon", "EternalSun", "MechaMogger", "MarbleStatue")  # D122
FIRST_SIGNATURE = 23  # index de GymDragon dans LOOKS


def paint_outfit_cells(atlas):
    """Eight 32px cells per row; new colors occupy rows 6-14 (D122 : columns 8-15 of rows 6-7)."""
    for i, (name, _, primary, secondary, accent, _, _, signature) in enumerate(LOOKS):
        if name in PREMIUM_LOOKS:
            continue  # D125 : leurs cases sont peintes par paint_premium_cells
        for channel, color in enumerate((primary, secondary, accent)):
            if i >= FIRST_SIGNATURE:
                cell = (i - FIRST_SIGNATURE) * 3 + channel
                x, y = 8 + cell % 8, 6 + cell // 8
            else:
                cell = i * 3 + channel
                x, y = cell % 8, 6 + cell // 8
            def painted(u, v, rgb=color, number=i, layer=channel, mark=signature, vein=secondary):
                base = lit(noise(rgb, 0.012), v, 0.13)
                if layer:
                    return base
                # D122 : motifs des tenues haut de gamme
                if mark == "scales":  # écailles en quinconce, bord sombre
                    edge = (u + (v // 5 % 2) * 4) % 8 in (0, 7) or v % 5 == 0
                    shade = 0.62 if edge else 1.0 + 0.12 * ((v % 5) / 4)
                    return tuple(min(1, c * shade) for c in base)
                if mark == "sunburst":  # rayons partant du centre
                    if math.sin(math.atan2(v - 16, u - 16) * 8) > 0.55:
                        return tuple(base[k] * 0.55 + vein[k] * 0.45 for k in range(3))
                    return base
                if mark == "panels":  # plaques et rivets
                    if u % 16 == 0 or v % 16 == 0:
                        return tuple(c * 0.55 for c in base)
                    if u % 16 in (3, 13) and v % 16 in (3, 13):
                        return tuple(min(1, c * 1.25) for c in base)
                    return base
                if mark == "marble":  # veines grises
                    if abs(math.sin(u * 0.32 + v * 0.17 + math.sin(v * 0.45) * 1.6)) < 0.09:
                        return tuple(base[k] * 0.35 + vein[k] * 0.65 for k in range(3))
                    return base
                # Woven and printed motifs. They repeat on fabric panels, never spell words.
                hit = False
                if mark in ("checker", "tool"):
                    hit = (u // 6 + v // 6) % 2 == 0
                elif mark in ("chevron", "zigzag", "wings", "wave"):
                    hit = abs(((u + (v // 5) * (2 if mark == "zigzag" else -2)) % 18) - 9) < 2
                elif mark in ("star", "meteor", "crown", "medal"):
                    hit = (abs(u - 16) + abs(v - 17) < 8) and ((u + v) % 3 == 0)
                elif mark in ("quilt", "cloud"):
                    hit = (u % 10 == 0 or v % 10 == 0)
                elif mark in ("leaf", "spiral", "orbit"):
                    hit = ((u - 16) ** 2 + (v - 16) ** 2) % 97 < 10
                else:
                    hit = u % (5 + number % 3) == 0
                if hit:
                    other = accent if number % 2 else secondary
                    return tuple(base[k] * 0.65 + other[k] * 0.35 for k in range(3))
                return base
            atlas.cell(f"look_{name}_{channel}", x, y, painted)
    paint_premium_cells(atlas)


def _loft(rings):
    """Close a ring loft. Rings are same-length lists of xyz points."""
    bm = bmesh.new()
    verts = [[bm.verts.new(Vector(p)) for p in ring] for ring in rings]
    n = len(verts[0])
    for lo, hi in zip(verts, verts[1:]):
        for j in range(n):
            k = (j + 1) % n
            bm.faces.new((lo[j], lo[k], hi[k], hi[j]))
    bm.faces.new(list(reversed(verts[0])))
    bm.faces.new(verts[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def _cape_mesh(chest, y_back, neck_z, waist_z, width_scale=1.0, length_scale=1.0):
    """A tapered cloth panel with shallow folds, closed at the edges."""
    bm = bmesh.new()
    front, rear = [], []
    for i in range(7):
        t = i / 6
        width = chest * (0.34 + 0.17 * t) * width_scale
        z = neck_z - 0.10 - (neck_z - waist_z + 0.22) * t * length_scale
        frow, rrow = [], []
        for j in range(7):
            s = (j - 3) / 3
            x = s * width
            fold = 0.065 * (1 - t * 0.45) * math.cos(s * math.pi * 2)
            y = y_back + 0.07 + fold + t * 0.10
            frow.append(bm.verts.new((x, y, z)))
            rrow.append(bm.verts.new((x, y + 0.035, z)))
        front.append(frow)
        rear.append(rrow)
    for i in range(6):
        for j in range(6):
            bm.faces.new((front[i][j], front[i][j + 1], front[i + 1][j + 1], front[i + 1][j]))
            bm.faces.new((rear[i + 1][j], rear[i + 1][j + 1], rear[i][j + 1], rear[i][j]))
    for j in range(6):
        bm.faces.new((front[0][j + 1], front[0][j], rear[0][j], rear[0][j + 1]))
        bm.faces.new((front[-1][j], front[-1][j + 1], rear[-1][j + 1], rear[-1][j]))
    for i in range(6):
        for j in (0, 6):
            bm.faces.new((front[i][j], front[i + 1][j], rear[i + 1][j], rear[i][j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


_BODY_TREES = {}


def _body_radii(body, part, z_values, n=24, centers=None):
    """Measure the actual body envelope in horizontal slices around a moving axis."""
    key = (body, part)
    if key not in _BODY_TREES:
        objects = [o for o in bpy.data.collections["Body_" + body].objects
                   if o.type == "MESH" and (o.name == body + "_" + part or o.name.startswith(body + "_" + part + "_"))]
        trees = []
        for obj in objects:
            bm = bmesh.new()
            bm.from_mesh(obj.data)
            trees.append(BVHTree.FromBMesh(bm))
            bm.free()
        _BODY_TREES[key] = trees
    trees = _BODY_TREES[key]
    rows = []
    for i, z in enumerate(z_values):
        cx, cy = centers[i] if centers else (0, 0)
        row = []
        for j in range(n):
            angle = 2 * math.pi * j / n
            dx, dy = math.cos(angle), math.sin(angle)
            origin = Vector((cx + dx * 8, cy + dy * 8, z))
            direction = Vector((-dx, -dy, 0))
            distances = [hit[3] for tree in trees if (hit := tree.ray_cast(origin, direction, 8))[0] is not None]
            row.append(8 - min(distances) if distances else None)
        rows.append(row)
    # Fill tiny gaps between the body's disconnected low-poly components.
    for j in range(n):
        known = [i for i, row in enumerate(rows) if row[j] is not None]
        if not known:
            # An eccentric limb can lie entirely to one side of the axis.
            # Use the widest measured direction rather than leave a skin gap.
            for row in rows:
                row[j] = max((value for value in row if value is not None), default=0.1)
            continue
        for i, row in enumerate(rows):
            if row[j] is None:
                nearest = min(known, key=lambda k: abs(k - i))
                row[j] = rows[nearest][j]
    return rows


def _fitted_limb(w, body, part, top, bottom, cell, ease, profile=None, n=16, dome=0.0):
    """A separate R15 garment shell that clears the skin, including deltoid bulges."""
    count = 19 if part.endswith("LowerArm") else 13
    if part.endswith("LowerArm"):
        n = 24
    heights = [top.z + (bottom.z - top.z) * i / (count - 1) for i in range(count)]
    centers = [(top.x + (bottom.x - top.x) * i / (count - 1),
                top.y + (bottom.y - top.y) * i / (count - 1)) for i in range(count)]
    radii = _body_radii(body, part, heights, n, centers)
    rings = []
    for i, z in enumerate(heights):
        t = i / (count - 1)
        extra = ease + (profile(t) if profile else 0)
        round_envelope = max(radii[i]) if part.endswith("LowerArm") else 0
        # D119 : haut de manche arrondi au-dessus du deltoïde (sinon une épaulette plate et carrée)
        # (seul l'anneau du dessus, au-dessus de la peau, rentre : le deltoïde reste large presque jusqu'en haut)
        k = 0.72 if dome > 0 and i == 0 else 1.0
        # Skin and cloth use the same R15 part, so their clearance scales together.
        rings.append([(centers[i][0] + math.cos(2 * math.pi * j / n) * (max(r, round_envelope) + extra) * k,
                       centers[i][1] + math.sin(2 * math.pi * j / n) * (max(r, round_envelope) + extra) * k, z)
                      for j, r in enumerate(radii[i])])
    w.make(part, _loft(rings), cell)
    return radii, heights, centers


def _torso(w, body, g, cell, silhouette, name):
    J, cfg = g["J"], g["cfg"]
    waist, neck = J["Waist"], J["Neck"]
    # Overlap the waistband; otherwise the animation reveals a strip of empty torso.
    low, high = waist.z - 0.06, neck.z + 0.02
    heights = [low + (high - low) * i / 13 for i in range(14)]
    radii = _body_radii(body, "UpperTorso", heights)
    ease = {"open": 0.135, "racer": 0.075, "blazer": 0.105, "utility": 0.105,
            "varsity": 0.10, "hoodie": 0.13, "robe": 0.11, "cape": 0.205,
            "puffer": 0.18, "bomber": 0.13, "armor": 0.15}[silhouette]
    rings = []
    outer_radii = []
    for i, z in enumerate(heights):
        ring = []
        outer_row = []
        for j, base in enumerate(radii[i]):
            a = 2 * math.pi * j / 24
            front = max(0, -math.sin(a))
            # Give cloth ease without erasing the hourglass silhouette.
            t = i / 13
            extra = (0.1 if cfg.get("fem") else 0.085) + ease * (0.75 + 0.25 * math.sin(math.pi * t))
            if silhouette in ("racer", "varsity"):
                extra += 0.08 * t * t
            elif silhouette in ("blazer", "robe"):
                extra += 0.045 * (1 - t) ** 2
            elif silhouette == "bomber":
                extra += 0.09 * math.sin(math.pi * t) ** 2
            elif silhouette == "puffer":
                extra += 0.11 * math.sin(math.pi * t) ** 2
            elif silhouette == "armor":
                extra += 0.05 * t
            radius = base + extra + (0.035 * front if silhouette in ("blazer", "puffer", "cape") else 0)
            ring.append((math.cos(a) * radius, math.sin(a) * radius, z))
            outer_row.append(radius)
        rings.append(ring)
        outer_radii.append(outer_row)
    w.make("UpperTorso", _loft(rings), cell)
    # D119 : col qui monte avec les trapèzes (nappe au-dessus du cou chez les gros stades), comme clothes.py ;
    # une pièce à part pour garder les 14 tranches dont dépendent les détails des ensembles
    skin = bpy.data.objects.get(body + "_UpperTorso")
    rise = (max(v.co.z for v in skin.data.vertices) - neck.z) * 0.55 if skin else 0.0
    if rise > 0.04:
        top_h = [neck.z - 0.1 + (rise + 0.1) * i / 5 for i in range(6)]
        top_r = _body_radii(body, "UpperTorso", top_h)
        collar = [[(math.cos(2 * math.pi * j / 24) * (r + 0.085 + ease * 0.75),
                    math.sin(2 * math.pi * j / 24) * (r + 0.085 + ease * 0.75), z)
                   for j, r in enumerate(row)] for z, row in zip(top_h, top_r)]
        w.make("UpperTorso", _loft(collar), cell)
    # Sleeve sections follow their own animated R15 limbs.
    if silhouette != "open":
        for side, _ in sides():
            sh, el, wr = (J[side + key] for key in ("Shoulder", "Elbow", "Wrist"))
            sleeve = "long" if silhouette in ("blazer", "utility", "hoodie", "robe", "cape", "puffer", "bomber", "armor") else "short"
            if (name == "DiscoDynamo" and side == "Right") or (name == "GarageGremlin" and side == "Left"):
                sleeve = "short"
            end = el if sleeve == "long" else sh.lerp(el, 0.59)
            ease_arm = (0.115 if silhouette not in ("puffer", "armor") else 0.21) + cfg["bicep"] * 0.06  # D116: room for huge biceps
            profile = (lambda t: 0.045 * math.sin(math.pi * t) ** 2) if silhouette in ("bomber", "hoodie") else None
            # D119 : la manche part au-dessus du deltoïde (il montait plus haut que l'épaule et perçait le tissu)
            arm = bpy.data.objects.get(body + "_" + side + "UpperArm")
            arm_top = max(v.co.z for v in arm.data.vertices) if arm else sh.z
            top = Vector((sh.x, sh.y, max(sh.z + cfg["delt"] * 0.95, arm_top + 0.03)))
            dome = (top.z - sh.z) / max(0.01, top.z - end.z)
            _fitted_limb(w, body, side + "UpperArm", top, end, cell, ease_arm, profile, dome=dome)
            if sleeve == "long":
                cuff_top = Vector((el.x, el.y, el.z + cfg["forearm"] * 0.7))
                _fitted_limb(w, body, side + "LowerArm", cuff_top, el.lerp(wr, 0.91),
                             cell, ease_arm * 0.85)
            elif name in ("DiscoDynamo", "GarageGremlin"):
                # An exposed forearm with a fitted wrist band keeps the growth key stable.
                _fitted_limb(w, body, side + "LowerArm", el.lerp(wr, 0.72),
                             el.lerp(wr, 0.89), cell, ease_arm * 0.85)
    return outer_radii, heights


def _bottom(w, body, g, cell, silhouette, name):
    J, cfg = g["J"], g["cfg"]
    root = J["Root"]
    height = [root.z - 0.26 + i * 0.075 for i in range(11)]
    radii = _body_radii(body, "LowerTorso", height)
    # Smoothed bodies (D115): very wide feminine hips need a little more ease to stay covered while growing.
    ease = 0.075 + (0.02 * g["hip_w"] if cfg.get("fem") else 0)
    rings = []
    for i, z in enumerate(height):
        rings.append([(math.cos(2 * math.pi * j / 24) * (radii[i][j] + ease),
                       math.sin(2 * math.pi * j / 24) * (radii[i][j] + ease), z) for j in range(24)])
    w.make("LowerTorso", _loft(rings), cell)
    length = "short" if silhouette == "short" else "long"
    t = {"short": 0.10, "taper": 0.115, "straight": 0.15, "cargo": 0.18,
         "flare": 0.14, "baggy": 0.22}[silhouette]
    for side, _ in sides():
        hip, knee, ankle = (J[side + key] for key in ("Hip", "Knee", "Ankle"))
        if length == "short":
            short_length = {"BoardwalkBolt": 0.46, "GoldenHour": 0.54,
                            "BrickhouseBrawler": 0.73, "RoyalRumble": 0.63,
                            "JungleJolt": 0.67, "TurboTaxi": 0.58}.get(name, 0.60)
            _fitted_limb(w, body, side + "UpperLeg", Vector((hip.x, 0, hip.z + 0.05)),
                         hip.lerp(knee, short_length), cell,
                         t + (0.10 if name == "TurboTaxi" else 0.03),
                         lambda f: 0.04 * f * f)
        else:
            _fitted_limb(w, body, side + "UpperLeg", Vector((hip.x, 0, hip.z + 0.05)),
                         knee, cell, t)
            _fitted_limb(w, body, side + "LowerLeg", knee,
                         Vector((ankle.x, ankle.y, ankle.z + 0.12)), cell, t,
                         (lambda f: (0.34 if name == "DiscoDynamo" else 0.23) * f * f)
                         if silhouette == "flare" else None)
    return t


def build_looks(w, body, g):
    """Build all two-piece outfits (20 Cash sets, 3 Robux sets) for one body stage."""
    J, cfg = g["J"], g["cfg"]
    neck, waist, root = J["Neck"], J["Waist"], J["Root"]
    chest = g["chest_w"]
    only = globals().get("ONLY_LOOKS")
    for name, _, _, _, _, silhouette, lower, signature in LOOKS:
        if only and name not in only:
            continue  # aperçu rapide (preview_premium.py)
        if name in PREMIUM_LOOKS:
            build_premium(w, body, g, name)  # D125
            continue
        primary, secondary, accent = (f"look_{name}_{i}" for i in range(3))
        w.start(name + "Top")
        radii, heights = _torso(w, body, g, primary, silhouette, name)
        # At each x, place the trim against the actual outer fabric, not the torso centerline.
        def front(z_index, x=0):
            j = min(range(12, 24), key=lambda k: abs(math.cos(2 * math.pi * k / 24) * radii[z_index][k] - x))
            return math.sin(2 * math.pi * j / 24) * radii[z_index][j] - 0.025
        zmid = heights[7]
        if silhouette in ("blazer", "robe", "cape", "open"):
            for sx in (-1, 1):
                w.make("UpperTorso", prism((sx * chest * 0.10, front(12, sx * chest * 0.10), neck.z - 0.06),
                                            (sx * chest * 0.24, front(5, sx * chest * 0.24), zmid - 0.13),
                                            0.085, 0.10, sides=4), secondary)
            if silhouette in ("blazer", "robe"):
                w.make("UpperTorso", prism((0, front(10) - 0.045, heights[10]),
                                            (0, front(2) - 0.045, heights[2]),
                                            0.032, 0.032, sides=4), accent)
        if silhouette in ("racer", "varsity", "bomber", "utility", "armor"):
            for sx in (-1, 1):
                w.make("UpperTorso", prism((sx * chest * 0.28, front(10, sx * chest * 0.28), heights[10]),
                                            (sx * chest * 0.20, front(3, sx * chest * 0.20), heights[3]),
                                            0.085, 0.07, sides=4), secondary)
            if silhouette == "armor":
                for sx in (-1, 1):
                    w.make("UpperTorso", block((sx * chest * 0.19, front(9, sx * chest * 0.19) - 0.045, heights[9]),
                                                (chest * 0.23, 0.075, 0.20)), secondary)
        if silhouette in ("hoodie", "puffer"):
            w.make("UpperTorso", ring((0, 0.10, neck.z + 0.03), cfg["neck"] * 1.38,
                                      0.075, 0.15, 12), secondary)
        if silhouette == "cape":
            # Back panel is welded to the torso. It clears arms but moves with the torso.
            cape_y = max(row[6] for row in radii)
            size = {"PaperCrown": 1.25, "CosmicEmperor": 1.4, "MarbleStatue": 1.3}.get(name, 1.0)
            length = 1.12 if name in ("CosmicEmperor", "MarbleStatue") else 1.0
            # La statue porte un drapé de marbre blanc (les autres capes : couleur secondaire)
            w.make("UpperTorso", _cape_mesh(chest, cape_y, neck.z, waist.z, size, length),
                   primary if name == "MarbleStatue" else secondary)
        if silhouette == "puffer":
            for k in (4, 7, 10):
                w.make("UpperTorso", prism((-chest * 0.40, front(k, -chest * 0.40), heights[k]),
                                            (chest * 0.40, front(k, chest * 0.40), heights[k]), 0.052, 0.052, sides=4), accent)
        if silhouette == "bomber":
            hem = [[(math.cos(2 * math.pi * j / 24) * (radii[k][j] + 0.02),
                     math.sin(2 * math.pi * j / 24) * (radii[k][j] + 0.02), heights[k])
                    for j in range(24)] for k in (0, 1)]
            w.make("UpperTorso", _loft(hem), secondary)
        if signature in ("chevron", "zigzag", "wings", "wave", "orbit"):
            for sx in (-1, 1):
                w.make("UpperTorso", prism((0, front(8) - 0.015, heights[8]),
                                            (sx * chest * 0.27, front(6, sx * chest * 0.27) - 0.015, heights[6]),
                                            0.085, 0.085, sides=4), accent)
        elif signature in ("medal", "star", "meteor", "crown", "checker"):
            w.make("UpperTorso", pyramid((0, front(7) - 0.025, zmid),
                                          (0, front(7) - 0.07, zmid + 0.22),
                                          chest * 0.17, 0.10), accent)
        elif signature == "harness":
            for sx in (-1, 1):
                w.make("UpperTorso", prism((sx * chest * 0.28, front(10, sx * chest * 0.28), heights[10]),
                                            (-sx * chest * 0.06, front(4), heights[4]),
                                            0.058, 0.058, sides=4), accent)
        elif signature == "spiral":
            w.make("UpperTorso", ring_upright((0, front(7) - 0.035, zmid), chest * 0.13,
                                               0.035, 0.04, 12), accent)
        elif signature == "leaf":
            for sx in (-1, 1):
                w.make("UpperTorso", pyramid((sx * chest * 0.06, front(7) - 0.025, zmid - 0.04),
                                              (sx * chest * 0.20, front(7, sx * chest * 0.20) - 0.04, zmid + 0.16),
                                              chest * 0.08, 0.05), accent)
        elif signature == "tool":
            for sx in (-1, 1):
                w.make("UpperTorso", prism((sx * chest * 0.12, front(8) - 0.025, heights[8]),
                                            (-sx * chest * 0.12, front(6) - 0.025, heights[6]),
                                            0.035, 0.035, sides=4), accent)
        elif signature == "cloud":
            for x, z in ((-0.12, 0.0), (0.0, 0.09), (0.12, 0.0)):
                w.make("UpperTorso", lowsphere((x * chest, front(7, x * chest) - 0.012, zmid + z),
                                                (chest * 0.09, 0.045, 0.10), 8, 6), accent)
        elif signature == "tie":
            w.make("UpperTorso", pyramid((0, front(10) - 0.02, heights[10]),
                                          (0, front(5) - 0.04, heights[5]), chest * 0.06, 0.06), accent)
        elif signature == "lapel":
            for k in (4, 6, 8):
                w.make("UpperTorso", lowsphere((0, front(k) - 0.025, heights[k]),
                                                (0.05, 0.035, 0.05), 6, 4), accent)
        elif signature in ("scales", "sunburst", "panels", "marble"):
            pass  # D122 : leurs emblèmes sont dans _signature_top
        elif signature != "quilt":
            raise ValueError(f"Unknown outfit signature: {signature}")
        # Large readable tailoring cues distinguish the silhouettes from a distance.
        def seam(ax, az, bx, bz, width, color):
            w.make("UpperTorso", prism((ax * chest, front(az, ax * chest) - 0.065, heights[az]),
                                        (bx * chest, front(bz, bx * chest) - 0.065, heights[bz]),
                                        width, 0.045, sides=4), color)

        if name == "CircuitAce":
            for sx in (-1, 1):
                seam(sx * 0.34, 11, sx * 0.34, 3, 0.06, secondary)
                seam(sx * 0.34, 11, sx * 0.10, 9, 0.06, accent)
        elif name == "BoardwalkBolt":
            for sx in (-1, 1):
                seam(sx * 0.09, 12, sx * 0.34, 7, 0.075, secondary)
                seam(sx * 0.34, 7, sx * 0.34, 2, 0.04, accent)
        elif name == "VelvetVillain":
            for sx in (-1, 1):
                seam(sx * 0.08, 12, sx * 0.42, 7, 0.105, secondary)
                seam(sx * 0.42, 7, sx * 0.16, 3, 0.065, accent)
        elif name == "MoonMechanic":
            for sx in (-1, 1):
                seam(sx * 0.39, 11, -sx * 0.13, 3, 0.095, secondary)
                w.make("UpperTorso", block((sx * chest * 0.33, front(3, sx * chest * 0.33) - 0.09,
                                            heights[3]), (chest * 0.18, 0.10, 0.18)), accent)
        elif name == "GoldenHour":
            seam(-0.45, 11, 0.45, 11, 0.11, secondary)
            seam(-0.45, 2, 0.45, 2, 0.08, accent)
        elif name == "BubblegumBlitz":
            for sx in (-1, 1):
                seam(sx * 0.40, 9, sx * 0.18, 2, 0.07, secondary)
            seam(-0.26, 3, 0.26, 3, 0.10, accent)
        elif name == "BrickhouseBrawler":
            for sx in (-1, 1):
                seam(sx * 0.06, 12, sx * 0.35, 5, 0.12, secondary)
            seam(-0.46, 2, 0.46, 2, 0.12, accent)
        elif name == "ThunderArcade":
            for sx in (-1, 1):
                seam(sx * 0.42, 11, sx * 0.10, 7, 0.075, accent)
                seam(sx * 0.10, 7, sx * 0.40, 3, 0.075, secondary)
        elif name == "RoyalRumble":
            seam(-0.42, 10, 0.42, 10, 0.13, secondary)
            seam(-0.22, 3, 0.22, 3, 0.10, accent)
        elif name == "MidnightExpress":
            for sx in (-1, 1):
                seam(sx * 0.08, 12, sx * 0.31, 7, 0.095, secondary)
                seam(sx * 0.31, 7, sx * 0.09, 3, 0.055, accent)
            seam(-0.14, 2, 0.14, 2, 0.06, secondary)
        elif name == "JungleJolt":
            for sx in (-1, 1):
                seam(sx * 0.12, 11, sx * 0.32, 6, 0.075, secondary)
                seam(sx * 0.32, 6, sx * 0.18, 2, 0.055, accent)
        elif name == "FrostFlex":
            for k in (2, 5, 8, 11):
                seam(-0.43, k, 0.43, k, 0.065, secondary)
        elif name == "TurboTaxi":
            seam(-0.46, 11, 0.46, 11, 0.13, secondary)
            for sx in (-1, 1):
                seam(sx * 0.39, 10, sx * 0.39, 3, 0.06, accent)
        elif name == "DiscoDynamo":
            seam(-0.40, 10, 0.28, 5, 0.105, secondary)
            seam(0.32, 10, -0.24, 4, 0.06, accent)
        elif name == "CometCoach":
            for sx in (-1, 1):
                seam(0, 10, sx * 0.44, 12, 0.11, secondary)
                seam(sx * 0.40, 3, sx * 0.15, 1, 0.06, accent)
        elif name == "SunsetStunt":
            seam(-0.43, 11, 0.27, 3, 0.09, secondary)
            seam(0.43, 11, -0.27, 3, 0.07, accent)
        elif name == "GarageGremlin":
            seam(-0.40, 11, 0.16, 4, 0.09, secondary)
            for sx in (-1, 1):
                w.make("UpperTorso", block((sx * chest * 0.32, front(3, sx * chest * 0.32) - 0.10,
                                            heights[3]), (chest * 0.20, 0.12, 0.20)), accent)
        elif name == "CloudCruiser":
            for sx in (-1, 1):
                w.make("UpperTorso", lowsphere((sx * chest * 0.36, front(9, sx * chest * 0.36) - 0.035,
                                                heights[9]), (chest * 0.20, 0.09, 0.16), 8, 6), secondary)
            seam(-0.30, 2, 0.30, 2, 0.09, accent)
        elif name == "IronMeteor":
            for sx in (-1, 1):
                w.make("UpperTorso", block((sx * chest * 0.26, front(9, sx * chest * 0.26) - 0.105,
                                            heights[9]), (chest * 0.30, 0.11, 0.24)), secondary)
                seam(sx * 0.36, 6, sx * 0.18, 3, 0.07, accent)
        elif name == "PaperCrown":
            for sx in (-1, 1):
                seam(0, 11, sx * 0.42, 8, 0.12, secondary)
                seam(sx * 0.42, 8, sx * 0.19, 2, 0.06, accent)
        if name in SIGNATURE_LOOKS:
            _signature_top(w, body, g, name, radii, heights, front, seam, (primary, secondary, accent))
        elif name in PREMIUM_LOOKS:
            _premium_top(w, body, g, name, radii, heights, front, seam, (primary, secondary, accent))
        w.start(name + "Bottom")
        leg_ease = _bottom(w, body, g, primary, lower, name)
        for side, sx in sides():
            hip, knee = J[side + "Hip"], J[side + "Knee"]
            leg_z = hip.z - (hip.z - knee.z) * (0.38 if lower == "short" else 0.55)
            edge = cfg["thigh"] + leg_ease + 0.07
            w.make(side + "UpperLeg", prism((hip.x + sx * edge, 0, leg_z + 0.13),
                                            (hip.x + sx * edge, 0, leg_z - 0.13),
                                            0.045, 0.045, sides=4), accent)
            if lower in ("cargo", "baggy"):
                w.make(side + "UpperLeg", block((hip.x + sx * (cfg["thigh"] + leg_ease + 0.05),
                                                 -cfg["thigh"] * 0.35, leg_z),
                                                (0.16 + cfg["thigh"] * 0.30, 0.08, 0.22)), secondary)
        if name in SIGNATURE_LOOKS:
            _signature_bottom(w, body, g, name, leg_ease, (primary, secondary, accent))
        elif name in PREMIUM_LOOKS:
            _premium_bottom(w, body, g, name, leg_ease, (primary, secondary, accent))


# ------------------------------------------------------------------ D121 : détails des tenues Robux
def _sleeve_top(body, g, side):
    """Haut de la manche longue (comme _torso) et son rayon mesuré : là où se posent épaulettes et spalières."""
    J, cfg = g["J"], g["cfg"]
    sh, el = J[side + "Shoulder"], J[side + "Elbow"]
    arm = bpy.data.objects.get(body + "_" + side + "UpperArm")
    arm_top = max(v.co.z for v in arm.data.vertices) if arm else sh.z
    top_z = max(sh.z + cfg["delt"] * 0.95, arm_top + 0.03)
    z = top_z - (top_z - el.z) * 0.18
    ring_r = _body_radii(body, side + "UpperArm", [z], 24, [(sh.x, sh.y)])[0]
    ease = 0.115 + cfg["bicep"] * 0.06
    return Vector((sh.x, sh.y, top_z)), max(ring_r) + ease, el


def _leg_radius(body, part, z, center):
    row = _body_radii(body, part, [z], 24, [center])[0]
    return max(row), row[18]  # rayon le plus large, rayon vers l'avant (-Y)


def _premium_top(w, body, g, name, radii, heights, front, seam, cells):
    J = g["J"]
    neck = J["Neck"]
    chest = g["chest_w"]
    primary, secondary, accent = cells
    back = max(row[6] for row in radii[9:])
    for side, sx in sides():
        top, r, el = _sleeve_top(body, g, side)
        if name == "CosmicEmperor":
            # Épaulettes d'apparat dorées, frangées
            w.make(side + "UpperArm", lowsphere((top.x + sx * r * 0.08, top.y, top.z - r * 0.18),
                                                (r * 1.18, r * 1.12, r * 0.34), 12, 6), accent)
            for k in range(5):
                a = math.pi * (0.15 + 0.7 * k / 4)
                x = top.x + sx * r * 1.05 * math.sin(a)
                y = top.y - r * 1.0 * math.cos(a)
                w.make(side + "UpperArm", prism((x, y, top.z - r * 0.25), (x, y, top.z - r * 0.85),
                                                r * 0.075, r * 0.06, sides=4), accent)
        elif name == "GoldenTitan":
            # Spalières de colosse : dôme ivoire, liseré en fusion, pointe
            cx = top.x + sx * r * 0.3  # décalé vers l'extérieur : la tête reste dégagée
            w.make(side + "UpperArm", lowsphere((cx, top.y, top.z - r * 0.2),
                                                (r * 1.2, r * 1.12, r * 0.55), 12, 7), secondary)
            w.make(side + "UpperArm", ring((cx, top.y, top.z - r * 0.5), r * 1.2,
                                           r * 0.12, r * 0.14, 14), accent)
            w.make(side + "UpperArm", pyramid((cx + sx * r * 0.35, top.y, top.z + r * 0.2),
                                              (cx + sx * r * 0.7, top.y, top.z + r * 0.62), r * 0.12, r * 0.12), accent)
        elif name == "NeonPhantom":
            # Couture néon le long du bras, de l'épaule au coude
            outer = top.x + sx * r * 1.02
            w.make(side + "UpperArm", prism((outer, top.y, top.z - r * 0.4), (el.x + sx * r * 0.92, el.y, el.z + r * 0.2),
                                            r * 0.09, r * 0.09, sides=4), accent)
    if name == "CosmicEmperor":
        # Haut col d'empereur dans le dos (jamais devant : le menton reste libre, D120) et broches de la cape
        h = chest * 0.13 + 0.12
        w.make("UpperTorso", block((0, back * 0.92, neck.z + h * 0.32), (chest * 0.46, 0.05 + chest * 0.025, h),
                                   1.35, chest * 0.05), secondary)
        w.make("UpperTorso", block((0, back * 0.92 - 0.02 - chest * 0.012, neck.z + h * 0.32),
                                   (chest * 0.48, 0.02 + chest * 0.008, h * 1.04), 1.36, chest * 0.05), accent)
        for sx in (-1, 1):
            w.make("UpperTorso", lowsphere((sx * chest * 0.30, front(11, sx * chest * 0.30) - 0.06, heights[11]),
                                            (chest * 0.07, 0.05, chest * 0.07), 10, 6), accent)
        seam(-0.30, 11, 0.30, 11, 0.05, accent)  # chaîne de cape
        seam(-0.08, 10, -0.08, 1, 0.05, accent)  # boutonnières dorées
        seam(0.08, 10, 0.08, 1, 0.05, accent)
    elif name == "GoldenTitan":
        # Plastron rayonnant et gorgerin
        w.make("UpperTorso", ring_upright((0, front(8) - 0.10, heights[8]), chest * 0.15, chest * 0.04, 0.06, 14), accent)
        for k in range(8):
            a = 2 * math.pi * k / 8
            ox, oz = math.cos(a) * chest * 0.21, math.sin(a) * chest * 0.21
            w.make("UpperTorso", pyramid((ox * 0.7, front(8, ox) - 0.10, heights[8] + oz * 0.7),
                                          (ox * 1.25, front(8, ox) - 0.12, heights[8] + oz * 1.25), chest * 0.03, chest * 0.03), accent)
        seam(-0.40, 12, 0.40, 12, 0.10, secondary)
        seam(-0.44, 2, 0.44, 2, 0.08, accent)
    elif name == "NeonPhantom":
        # Capuche rabattue dans le dos et lignes néon sur les flancs
        w.make("UpperTorso", lowsphere((0, back + chest * 0.06, neck.z - chest * 0.02),
                                        (chest * 0.24, chest * 0.11, chest * 0.13), 12, 6), secondary)
        for sx in (-1, 1):
            seam(sx * 0.44, 12, sx * 0.44, 1, 0.045, accent)
            seam(sx * 0.12, 11, sx * 0.30, 5, 0.04, accent)
        seam(-0.30, 1, 0.30, 1, 0.045, accent)


def _premium_bottom(w, body, g, name, leg_ease, cells):
    J, cfg = g["J"], g["cfg"]
    primary, secondary, accent = cells
    root = J["Root"]
    # Ceinture (les trois) : anneau sur la taille du pantalon, boucle devant
    z = root.z + 0.40
    belt = _body_radii(body, "LowerTorso", [z])[0]
    rings = [[(math.cos(2 * math.pi * j / 24) * (belt[j] + 0.11), math.sin(2 * math.pi * j / 24) * (belt[j] + 0.11), z + dz)
              for j in range(24)] for dz in (-0.07, 0.07)]
    w.make("LowerTorso", _loft(rings), accent if name == "NeonPhantom" else secondary)
    w.make("LowerTorso", block((0, -(belt[18] + 0.13), z), (0.16 + cfg["chest_w"] * 0.05, 0.05, 0.14 + cfg["chest_w"] * 0.02)), accent)
    for side, sx in sides():
        knee, ankle = J[side + "Knee"], J[side + "Ankle"]
        kz = knee.z - (knee.z - ankle.z) * 0.10
        wide, fwd = _leg_radius(body, side + "LowerLeg", kz, (knee.x, knee.y))
        if name == "GoldenTitan":
            # Genouillères ivoire
            w.make(side + "LowerLeg", lowsphere((knee.x, knee.y - fwd - leg_ease - wide * 0.05, kz),
                                                (wide * 0.72, wide * 0.32, wide * 0.8), 10, 6), secondary)
        else:
            # Bande latérale du genou à la cheville (or pour l'empereur, néon pour le fantôme)
            low = ankle.z + 0.25
            wide_low, _ = _leg_radius(body, side + "LowerLeg", low, (ankle.x, ankle.y))
            w.make(side + "LowerLeg", prism((knee.x + sx * (wide + leg_ease + 0.02), knee.y, kz),
                                            (ankle.x + sx * (wide_low + leg_ease + 0.02), ankle.y, low),
                                            0.045 + wide * 0.04, 0.045 + wide * 0.04, sides=4), accent)


# ------------------------------------------------------------------ D122 : tenues Robux haut de gamme
# Les grandes décorations (ailes, auréole, réacteur, queue...) sont des pièces à part, <Partie>_Deco : le jeu gonfle
# chaque pièce autour de son propre centre (pump), une aile collée au haut l'aurait fait glisser sur le corps.
# BodyService ne gonfle pas les pièces _Deco ; elles suivent la croissance comme les autres.
def _spike(base, tip, radius):
    """Pointe conique (corne, rayon, feuille) dans n'importe quelle direction, jamais plate."""
    return prism(tuple(base), tuple(tip), radius, radius * 0.08, sides=5)


def _slab(points, depth):
    """Plaque fine (membrane d'aile) : un polygone convexe épaissi de `depth` vers l'arrière (+Y)."""
    bm = bmesh.new()
    front = [bm.verts.new(Vector(p)) for p in points]
    back = [bm.verts.new(Vector(p) + Vector((0, depth, 0))) for p in points]
    n = len(points)
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((front[j], front[i], back[i], back[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def _signature_top(w, body, g, name, radii, heights, front, seam, cells):
    J = g["J"]
    neck, waist = J["Neck"], J["Waist"]
    chest = g["chest_w"]
    primary, secondary, accent = cells
    back = max(row[6] for row in radii[9:])
    back_mid = max(row[6] for row in radii[4:9])
    k = 0.55 + chest * 0.35  # échelle des volumes : suit la carrure du stade
    for side, sx in sides():
        top, r, el = _sleeve_top(body, g, side)
        cx = top.x + sx * r * 0.3  # décalé vers l'extérieur : la tête reste dégagée
        if name == "GymDragon":
            # Épaulière en écailles sombres et trois cornes de feu vers l'extérieur
            w.make(side + "UpperArm", lowsphere((cx, top.y, top.z - r * 0.22), (r * 1.15, r * 1.08, r * 0.5), 12, 7), secondary)
            for n, (dx, dz) in enumerate(((0.2, 0.55), (0.55, 0.42), (0.85, 0.15))):
                base = Vector((cx + sx * r * dx * 0.8, top.y + r * (0.25 - n * 0.25), top.z - r * 0.05))
                tip = base + Vector((sx * r * (0.35 + dx * 0.6), r * 0.15, r * (0.45 + dz)))
                w.make(side + "UpperArm_Deco", _spike(base, tip, r * 0.15), accent)
        elif name == "EternalSun":
            # Épaule en soleil : disque doré et éventail de rayons
            w.make(side + "UpperArm", lowsphere((cx, top.y, top.z - r * 0.18), (r * 1.1, r * 1.05, r * 0.42), 12, 6), primary)
            for n in range(5):
                a = math.radians(-20 + n * 30)
                base = Vector((cx + sx * r * 0.85 * math.cos(a), top.y, top.z - r * 0.1 + r * 0.85 * math.sin(a)))
                tip = base + Vector((sx * math.cos(a), 0, math.sin(a))) * r * (0.75 if n % 2 == 0 else 0.5)
                w.make(side + "UpperArm_Deco", _spike(base, tip, r * 0.15),
                       accent if n % 2 == 0 else secondary)
        elif name == "MechaMogger":
            # Module d'épaule carré : coque, bande lumineuse, trois tubes de lanceur
            w.make(side + "UpperArm_Deco", block((cx, top.y, top.z - r * 0.1), (r * 2.3, r * 2.15, r * 1.0), 0.86), primary)
            w.make(side + "UpperArm_Deco", block((cx, top.y - r * 1.08, top.z - r * 0.1), (r * 1.6, r * 0.08, r * 0.22)), accent)
            for n in (-1, 0, 1):
                y = top.y + n * r * 0.45
                w.make(side + "UpperArm_Deco", prism((cx + sx * r * 1.1, y, top.z + r * 0.05),
                                                (cx + sx * r * 1.45, y, top.z + r * 0.05), r * 0.16, r * 0.16, sides=6), secondary)
        elif name == "MarbleStatue":
            # Drapé de marbre sur l'épaule et fibule dorée en laurier
            w.make(side + "UpperArm", lowsphere((cx, top.y, top.z - r * 0.25), (r * 1.18, r * 1.12, r * 0.55), 12, 7), primary)
            w.make(side + "UpperArm", ring_upright((cx, top.y - r * 1.05, top.z - r * 0.25), r * 0.32, r * 0.1, r * 0.1, 10), accent)
            for n in range(4):
                a = math.radians(90 + n * 40)
                base = Vector((cx + math.cos(a) * r * 0.34, top.y - r * 1.1, top.z - r * 0.25 + math.sin(a) * r * 0.34))
                tip = base + Vector((math.cos(a + 1.2), 0, math.sin(a + 1.2))) * r * 0.32
                w.make(side + "UpperArm", _spike(base, tip, r * 0.09), accent)

    if name == "GymDragon":
        # Crête dorsale : piquants de feu du cou à la taille
        for n in range(6):
            t = n / 5
            z = neck.z - 0.05 - (neck.z - waist.z) * 0.85 * t
            y = back * (1 - t) + back_mid * t
            size = (0.17 - 0.07 * t) * k
            w.make("UpperTorso_Deco", pyramid((0, y - 0.04, z), (0, y + size * 1.6, z + size * 0.9), size * 0.45, size * 0.7), accent)
        # Ailes repliées : membrane verte et trois baleines sombres de chaque côté
        for sx in (-1, 1):
            root = Vector((sx * chest * 0.14, back - 0.02, heights[10]))
            tips = [Vector((sx * chest * (0.55 + 0.25 * n), back + (0.32 + 0.1 * n) * k, neck.z + (0.55 - 0.42 * n) * k))
                    for n in range(3)]
            low = Vector((sx * chest * 0.32, back + 0.18 * k, heights[3]))
            outline = [root, tips[0], tips[1], tips[2], low]
            if sx < 0:
                outline.reverse()
            w.make("UpperTorso_Deco", _slab([tuple(p) for p in outline], 0.035), primary)
            for tip in tips:
                w.make("UpperTorso_Deco", prism(tuple(root), tuple(tip), 0.05 * k, 0.018 * k, sides=4), secondary)
                w.make("UpperTorso_Deco", _spike(tip, tip + Vector((sx * 0.05, 0.04, 0.12)) * k, 0.04 * k), accent)
        # Plaques de ventre et col en écailles
        for kk in (2, 4, 6):
            seam(-0.22, kk, 0.22, kk, 0.075, accent)
        seam(-0.36, 12, 0.36, 12, 0.10, secondary)
        for sx in (-1, 1):
            seam(sx * 0.10, 11, sx * 0.36, 8, 0.06, secondary)
    elif name == "EternalSun":
        # Auréole solaire dans le dos : grand anneau doré, anneau intérieur et douze rayons alternés
        hc = Vector((0, back + 0.22 * k, neck.z + chest * 0.06))
        R = chest * 0.62 + 0.15
        w.make("UpperTorso_Deco", ring_upright(tuple(hc), R, R * 0.12, 0.08 * k, 20), primary)
        w.make("UpperTorso_Deco", ring_upright(tuple(hc + Vector((0, -0.02, 0))), R * 0.72, R * 0.06, 0.06 * k, 16), accent)
        for n in range(12):
            a = 2 * math.pi * n / 12
            d = Vector((math.cos(a), 0, math.sin(a)))
            length = R * (0.42 if n % 2 == 0 else 0.26)
            w.make("UpperTorso_Deco", _spike(hc + d * R * 0.98, hc + d * (R + length), R * 0.08),
                   accent if n % 2 == 0 else primary)
        # Soleil sur la poitrine : disque crème et rayons de feu
        cz = heights[8]
        w.make("UpperTorso", lowsphere((0, front(8) - 0.07, cz), (chest * 0.13, 0.05, chest * 0.13), 12, 6), secondary)
        for n in range(10):
            a = 2 * math.pi * n / 10 + 0.3
            ox, oz = math.cos(a) * chest * 0.15, math.sin(a) * chest * 0.15
            w.make("UpperTorso", _spike((ox, front(8, ox) - 0.08, cz + oz), (ox * 1.7, front(8, ox) - 0.09, cz + oz * 1.7), chest * 0.03), accent)
        seam(-0.42, 12, 0.42, 12, 0.10, accent)
        seam(-0.40, 1, 0.40, 1, 0.09, accent)
    elif name == "MechaMogger":
        # Réacteur sur la poitrine : plaque sombre, anneau lumineux, cœur
        cz = heights[8]
        w.make("UpperTorso", block((0, front(8) - 0.05, cz), (chest * 0.42, 0.06, chest * 0.36), 0.8), secondary)
        w.make("UpperTorso", ring_upright((0, front(8) - 0.10, cz), chest * 0.11, chest * 0.035, 0.05, 14), accent)
        w.make("UpperTorso", lowsphere((0, front(8) - 0.09, cz), (chest * 0.07, 0.04, chest * 0.07), 10, 6), accent)
        # Réacteur dorsal : caisson, deux tuyères vers le bas, ailerons d'antenne
        pack_z = (heights[11] + heights[4]) / 2
        depth = 0.22 * k
        w.make("UpperTorso_Deco", block((0, back + depth * 0.5, pack_z), (chest * 0.5, depth, (heights[11] - heights[4]) * 0.95), 0.9),
               secondary)
        for sx in (-1, 1):
            nz = heights[4] - 0.05
            w.make("UpperTorso_Deco", prism((sx * chest * 0.15, back + depth * 0.55, nz + 0.12),
                                       (sx * chest * 0.17, back + depth * 0.6, nz - 0.22 * k), 0.08 * k, 0.12 * k, sides=8), primary)
            w.make("UpperTorso_Deco", ring((sx * chest * 0.17, back + depth * 0.6, nz - 0.22 * k), 0.11 * k, 0.03 * k, 0.04, 8), accent)
            w.make("UpperTorso_Deco", pyramid((sx * chest * 0.16, back + depth * 0.5, heights[11] + 0.02),
                                          (sx * chest * 0.22, back + depth * 0.9, neck.z + 0.35 * k), 0.03 * k, 0.07 * k), primary)
            seam(sx * 0.40, 12, sx * 0.40, 2, 0.06, secondary)
            seam(sx * 0.30, 3, sx * 0.12, 1, 0.05, accent)
    elif name == "MarbleStatue":
        # Toge : écharpe de marbre en travers du buste, plis gris et laurier doré le long de l'écharpe
        seam(0.40, 12, -0.36, 1, 0.16, primary)
        seam(0.30, 12, -0.42, 3, 0.07, secondary)
        seam(0.44, 10, -0.24, 0, 0.06, secondary)
        for n in range(7):
            t = n / 6
            x = 0.38 - 0.72 * t
            kk = round(11 - 9 * t)
            for leaf in (-1, 1):
                base = (x * chest, front(kk, x * chest) - 0.10, heights[kk])
                tip = (x * chest + leaf * chest * 0.06, front(kk, x * chest) - 0.12, heights[kk] + chest * 0.05)
                w.make("UpperTorso", _spike(base, tip, chest * 0.03), accent)
        seam(-0.42, 12, 0.42, 12, 0.07, accent)  # bordure dorée du col


def _signature_bottom(w, body, g, name, leg_ease, cells):
    J, cfg = g["J"], g["cfg"]
    primary, secondary, accent = cells
    root = J["Root"]
    chest = cfg["chest_w"]
    k = 0.55 + chest * 0.35
    z = root.z + 0.40
    belt = _body_radii(body, "LowerTorso", [z])[0]
    rings = [[(math.cos(2 * math.pi * j / 24) * (belt[j] + 0.11), math.sin(2 * math.pi * j / 24) * (belt[j] + 0.11), z + dz)
              for j in range(24)] for dz in (-0.07, 0.07)]
    w.make("LowerTorso", _loft(rings), accent if name in ("EternalSun", "MarbleStatue") else secondary)
    fy = -(belt[18] + 0.13)
    by = belt[6] + 0.11
    if name == "GymDragon":
        # Queue : du bas du dos jusqu'au sol, piquants de feu sur le dessus
        z0 = root.z + 0.15
        pts = [(0, by, z0), (0, by + 0.35 * k, z0 - 0.35 * k), (0, by + 0.8 * k, z0 - 0.62 * k),
               (0, by + 1.3 * k, z0 - 0.72 * k), (0, by + 1.8 * k, z0 - 0.62 * k), (0, by + 2.15 * k, z0 - 0.45 * k)]
        w.make("LowerTorso_Deco", sweep(pts, [0.2 * k, 0.17 * k, 0.13 * k, 0.09 * k, 0.06 * k, 0.03 * k], 8), primary)
        for n in range(1, 5):
            p = Vector(pts[n])
            r = (0.17, 0.13, 0.09, 0.06)[n - 1] * k
            w.make("LowerTorso_Deco", _spike(p + Vector((0, 0, r * 0.7)), p + Vector((0, 0.05, r * 0.7 + 0.14 * k)), r * 0.35), accent)
        w.make("LowerTorso_Deco", pyramid(pts[-1], (0, by + 2.45 * k, z0 - 0.3 * k), 0.06 * k, 0.09 * k), accent)
        w.make("LowerTorso", block((0, fy, z), (0.2 + chest * 0.05, 0.05, 0.16)), accent)
    elif name == "EternalSun":
        # Boucle soleil et tabard crème bordé d'or devant les cuisses
        w.make("LowerTorso", ring_upright((0, fy - 0.02, z), 0.12 + chest * 0.03, 0.04, 0.05, 12), primary)
        w.make("LowerTorso", block((0, fy + 0.02, z - 0.32), (0.22 + chest * 0.08, 0.035, 0.5)), secondary)
        w.make("LowerTorso", block((0, fy, z - 0.56), (0.24 + chest * 0.08, 0.04, 0.05)), accent)
    elif name == "MechaMogger":
        w.make("LowerTorso", block((0, fy, z), (0.2 + chest * 0.05, 0.06, 0.14)), accent)
        for sx in (-1, 1):
            w.make("LowerTorso", block((sx * belt[0] * 0.75, fy * 0.6, z - 0.12), (0.26, 0.2, 0.14)), primary)
    elif name == "MarbleStatue":
        w.make("LowerTorso", ring_upright((0, fy - 0.02, z), 0.1 + chest * 0.02, 0.035, 0.05, 10), accent)
    for side, _ in sides():
        knee, ankle = J[side + "Knee"], J[side + "Ankle"]
        kz = knee.z - (knee.z - ankle.z) * 0.10
        wide, fwd = _leg_radius(body, side + "LowerLeg", kz, (knee.x, knee.y))
        low = ankle.z + 0.25
        wide_low, _ = _leg_radius(body, side + "LowerLeg", low, (ankle.x, ankle.y))
        out = wide + leg_ease
        if name == "GymDragon":
            # Genouillère en griffe : plaque sombre et trois griffes de feu vers l'avant
            w.make(side + "LowerLeg", lowsphere((knee.x, knee.y - fwd - leg_ease - wide * 0.05, kz),
                                                (wide * 0.7, wide * 0.32, wide * 0.78), 10, 6), secondary)
            for n in (-1, 0, 1):
                base = (knee.x + n * wide * 0.35, knee.y - fwd - leg_ease - wide * 0.3, kz - wide * 0.2)
                tip = (knee.x + n * wide * 0.45, knee.y - fwd - leg_ease - wide * 0.75, kz - wide * 0.75)
                w.make(side + "LowerLeg_Deco", pyramid(base, tip, wide * 0.08, wide * 0.08), accent)
        elif name == "EternalSun":
            w.make(side + "LowerLeg", ring((knee.x, knee.y, kz), out + 0.04, 0.05, 0.08, 14), accent)
            w.make(side + "LowerLeg", ring((ankle.x, ankle.y, low), wide_low + leg_ease + 0.04, 0.05, 0.08, 14), accent)
        elif name == "MechaMogger":
            # Genouillère blindée, voyant lumineux et plaque de tibia
            w.make(side + "LowerLeg", block((knee.x, knee.y - fwd - leg_ease - 0.02, kz), (wide * 1.3, wide * 0.5, wide * 1.2), 0.8),
                   primary)
            w.make(side + "LowerLeg", lowsphere((knee.x, knee.y - fwd - leg_ease - wide * 0.3, kz), (wide * 0.18, 0.04, wide * 0.18), 8, 4),
                   accent)
            w.make(side + "LowerLeg", block(((knee.x + ankle.x) / 2, (knee.y + ankle.y) / 2 - (fwd + wide_low) / 2 - leg_ease,
                                             (kz + low) / 2), (wide * 1.0, 0.06, (kz - low) * 0.7), 0.85), secondary)
        elif name == "MarbleStatue":
            # Jambières en colonne : cannelures verticales, bagues dorées au genou et à la cheville
            for n in range(8):
                a = 2 * math.pi * (n + 0.5) / 8
                ca, sa = math.cos(a), math.sin(a)
                w.make(side + "LowerLeg", prism((knee.x + ca * (out + 0.02), knee.y + sa * (out + 0.02), kz - 0.05),
                                                (ankle.x + ca * (wide_low + leg_ease + 0.02), ankle.y + sa * (wide_low + leg_ease + 0.02),
                                                 low + 0.05), 0.035 + wide * 0.03, 0.035 + wide * 0.03, sides=4), secondary)
            w.make(side + "LowerLeg", ring((knee.x, knee.y, kz), out + 0.07, 0.06, 0.09, 14), accent)
            w.make(side + "LowerLeg", ring((ankle.x, ankle.y, low), wide_low + leg_ease + 0.07, 0.06, 0.09, 14), accent)


# D125 : les huit tenues Robux refaites
_premium_path = os.path.join(D, "premium_looks.py")
exec(compile(open(_premium_path, encoding="utf-8").read(), _premium_path, "exec"), globals())

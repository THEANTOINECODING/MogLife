"""Twenty original MOG LIFE outfits, built against each stage's actual body shell.

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
)


def paint_outfit_cells(atlas):
    """Eight 32px cells per row; new colors occupy rows 6-13."""
    for i, (name, _, primary, secondary, accent, _, _, signature) in enumerate(LOOKS):
        for channel, color in enumerate((primary, secondary, accent)):
            cell = i * 3 + channel
            x, y = cell % 8, 6 + cell // 8
            def painted(u, v, rgb=color, number=i, layer=channel, mark=signature):
                base = lit(noise(rgb, 0.012), v, 0.13)
                if layer:
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


def _fitted_limb(w, body, part, top, bottom, cell, ease, profile=None, n=16):
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
        # Skin and cloth use the same R15 part, so their clearance scales together.
        rings.append([(centers[i][0] + math.cos(2 * math.pi * j / n) * (max(r, round_envelope) + extra),
                       centers[i][1] + math.sin(2 * math.pi * j / n) * (max(r, round_envelope) + extra), z)
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
    # Sleeve sections follow their own animated R15 limbs.
    if silhouette != "open":
        for side, _ in sides():
            sh, el, wr = (J[side + key] for key in ("Shoulder", "Elbow", "Wrist"))
            sleeve = "long" if silhouette in ("blazer", "utility", "hoodie", "robe", "cape", "puffer", "bomber", "armor") else "short"
            if (name == "DiscoDynamo" and side == "Right") or (name == "GarageGremlin" and side == "Left"):
                sleeve = "short"
            end = el if sleeve == "long" else sh.lerp(el, 0.59)
            ease_arm = 0.115 if silhouette not in ("puffer", "armor") else 0.21
            profile = (lambda t: 0.045 * math.sin(math.pi * t) ** 2) if silhouette in ("bomber", "hoodie") else None
            _fitted_limb(w, body, side + "UpperArm", sh, end, cell, ease_arm, profile)
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
    """Build all 20 two-piece outfits for one body stage."""
    J, cfg = g["J"], g["cfg"]
    neck, waist, root = J["Neck"], J["Waist"], J["Root"]
    chest = g["chest_w"]
    for name, _, _, _, _, silhouette, lower, signature in LOOKS:
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
            size = 1.25 if name == "PaperCrown" else 1.0
            w.make("UpperTorso", _cape_mesh(chest, cape_y, neck.z, waist.z, size, 1.0), secondary)
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

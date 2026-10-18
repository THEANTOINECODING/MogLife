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


def _cape_mesh(chest, y_back, neck_z, waist_z):
    """A tapered cloth panel with shallow folds, closed at the edges."""
    bm = bmesh.new()
    front, rear = [], []
    for i in range(7):
        t = i / 6
        width = chest * (0.34 + 0.17 * t)
        z = neck_z - 0.10 - (neck_z - waist_z + 0.22) * t
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


def _body_radii(body, part, z_values, n=24):
    """Measure the outer surface, including default top/shorts, by radial casts."""
    objects = [o for o in bpy.data.collections["Body_" + body].objects
               if o.type == "MESH" and (o.name == body + "_" + part or o.name.startswith(body + "_" + part + "_"))]
    trees = []
    for obj in objects:
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        trees.append(BVHTree.FromBMesh(bm))
        bm.free()
    rows = []
    for z in z_values:
        row = []
        for j in range(n):
            angle = 2 * math.pi * j / n
            dx, dy = math.cos(angle), math.sin(angle)
            origin = Vector((dx * 8, dy * 8, z))
            direction = Vector((-dx, -dy, 0))
            distances = [hit[3] for tree in trees if (hit := tree.ray_cast(origin, direction, 8))[0] is not None]
            row.append(8 - min(distances) if distances else None)
        rows.append(row)
    # Fill tiny gaps between the body's disconnected low-poly components.
    for j in range(n):
        known = [i for i, row in enumerate(rows) if row[j] is not None]
        if not known:
            raise ValueError(f"No body surface for {body}/{part}, angle {j}")
        for i, row in enumerate(rows):
            if row[j] is None:
                nearest = min(known, key=lambda k: abs(k - i))
                row[j] = rows[nearest][j]
    return rows


def _torso(w, body, g, cell, silhouette):
    J, cfg = g["J"], g["cfg"]
    waist, neck = J["Waist"], J["Neck"]
    # Overlap the waistband; otherwise the animation reveals a strip of empty torso.
    low, high = waist.z - 0.06, neck.z + 0.02
    heights = [low + (high - low) * i / 13 for i in range(14)]
    radii = _body_radii(body, "UpperTorso", heights)
    ease = {"open": 0.055, "racer": 0.065, "blazer": 0.10, "utility": 0.085,
            "varsity": 0.09, "hoodie": 0.13, "robe": 0.09, "cape": 0.095,
            "puffer": 0.18, "bomber": 0.12, "armor": 0.13}[silhouette]
    rings = []
    for i, z in enumerate(heights):
        ring = []
        for j, base in enumerate(radii[i]):
            a = 2 * math.pi * j / 24
            front = max(0, -math.sin(a))
            # Give cloth ease without erasing the hourglass silhouette.
            extra = ease * (0.75 + 0.25 * math.sin(math.pi * i / 13))
            radius = base + extra + (0.035 * front if silhouette in ("blazer", "puffer", "cape") else 0)
            ring.append((math.cos(a) * radius, math.sin(a) * radius, z))
        rings.append(ring)
    w.make("UpperTorso", _loft(rings), cell)
    # Sleeve sections follow their own animated R15 limbs.
    if silhouette != "open":
        for side, _ in sides():
            sh, el, wr = (J[side + key] for key in ("Shoulder", "Elbow", "Wrist"))
            sleeve = "long" if silhouette in ("blazer", "utility", "hoodie", "robe", "cape", "puffer", "bomber", "armor") else "short"
            end = el if sleeve == "long" else sh.lerp(el, 0.56)
            ease_arm = 0.055 if silhouette not in ("puffer", "armor") else 0.13
            w.make(side + "UpperArm", limb(tuple(sh), tuple(end), cfg["delt"] + ease_arm,
                                            cfg["bicep"] + ease_arm, cfg["bicep"] * 0.92 + ease_arm), cell)
            if sleeve == "long":
                w.make(side + "LowerArm", limb(tuple(el), tuple(el.lerp(wr, 0.9)), cfg["forearm"] + ease_arm,
                                                cfg["forearm"] + ease_arm, cfg["forearm"] * 0.72 + ease_arm), cell)
    return radii, heights


def _bottom(w, body, g, cell, silhouette):
    J, cfg = g["J"], g["cfg"]
    root = J["Root"]
    height = [root.z - 0.26 + i * 0.075 for i in range(11)]
    radii = _body_radii(body, "LowerTorso", height)
    rings = []
    for i, z in enumerate(height):
        rings.append([(math.cos(2 * math.pi * j / 24) * (radii[i][j] + 0.052),
                       math.sin(2 * math.pi * j / 24) * (radii[i][j] + 0.052), z) for j in range(24)])
    w.make("LowerTorso", _loft(rings), cell)
    length = "short" if silhouette == "short" else "long"
    t = {"short": 0.04, "taper": 0.065, "straight": 0.10, "cargo": 0.13,
         "flare": 0.10, "baggy": 0.18}[silhouette]
    for side, _ in sides():
        hip, knee, ankle = (J[side + key] for key in ("Hip", "Knee", "Ankle"))
        x = hip.x
        if length == "short":
            short_r = max(cfg["thigh"] * 1.14, 0.24) if cfg.get("baggy") else cfg["thigh"] * 1.14
            w.make(side + "UpperLeg", limb((x, 0, hip.z + 0.05),
                                            (x, 0, hip.z - (hip.z - knee.z) * 0.55),
                                            short_r + t, short_r * 1.03 + t, short_r * 1.08 + t), cell)
        else:
            thigh_r, calf_r = cfg["thigh"], cfg["calf"]
            w.make(side + "UpperLeg", limb((x, 0, knee.z), (x, 0, hip.z + 0.05),
                                            calf_r * 0.82 + t, thigh_r + t, thigh_r * 1.08 + t,
                                            bulge_dir=(0, -1, 0), bulge=thigh_r * 0.15), cell)
            ankle_ease = t * (1.8 if silhouette == "flare" else 1.0)
            w.make(side + "LowerLeg", limb((x, 0, ankle.z + 0.12), (x, 0, knee.z),
                                            calf_r * 0.6 + ankle_ease, calf_r + t,
                                            calf_r * 0.82 + t, mid_t=0.62,
                                            bulge_dir=(0, 1, 0), bulge=calf_r * 0.25), cell)


def build_looks(w, body, g):
    """Build all 20 two-piece outfits for one body stage."""
    J, cfg = g["J"], g["cfg"]
    neck, waist, root = J["Neck"], J["Waist"], J["Root"]
    chest = g["chest_w"]
    for name, _, _, _, _, silhouette, lower, signature in LOOKS:
        primary, secondary, accent = (f"look_{name}_{i}" for i in range(3))
        w.start(name + "Top")
        radii, heights = _torso(w, body, g, primary, silhouette)
        # Details are attached to sampled fabric radii, never placed in front by a fixed offset.
        front = lambda z_index: -radii[z_index][18] - 0.015
        zmid = heights[7]
        if silhouette in ("blazer", "robe", "cape", "open"):
            for sx in (-1, 1):
                w.make("UpperTorso", prism((sx * chest * 0.10, front(12), neck.z - 0.06),
                                            (sx * chest * 0.24, front(5), zmid - 0.13),
                                            0.085, 0.10, sides=4), secondary)
            if silhouette in ("blazer", "robe"):
                w.make("UpperTorso", prism((0, front(10) - 0.045, heights[10]),
                                            (0, front(2) - 0.045, heights[2]),
                                            0.032, 0.032, sides=4), accent)
        if silhouette in ("racer", "varsity", "bomber", "utility", "armor"):
            for sx in (-1, 1):
                w.make("UpperTorso", prism((sx * chest * 0.28, front(10), heights[10]),
                                            (sx * chest * 0.20, front(3), heights[3]),
                                            0.085, 0.07, sides=4), secondary)
            if silhouette == "armor":
                for sx in (-1, 1):
                    w.make("UpperTorso", block((sx * chest * 0.19, front(9) - 0.045, heights[9]),
                                                (chest * 0.23, 0.075, 0.20)), secondary)
        if silhouette in ("hoodie", "puffer"):
            w.make("UpperTorso", ring((0, 0.10, neck.z + 0.03), cfg["neck"] * 1.38,
                                      0.075, 0.15, 12), secondary)
        if silhouette == "cape":
            # Back panel is welded to the torso. It clears arms but moves with the torso.
            cape_y = max(row[6] for row in radii)
            w.make("UpperTorso", _cape_mesh(chest, cape_y, neck.z, waist.z), secondary)
        if silhouette == "puffer":
            for k in (4, 7, 10):
                w.make("UpperTorso", prism((-chest * 0.40, front(k), heights[k]),
                                            (chest * 0.40, front(k), heights[k]), 0.052, 0.052, sides=4), accent)
        if silhouette == "bomber":
            w.make("UpperTorso", waist_band((0, 0, waist.z + 0.03),
                                            g["waist_w"] * 0.5 + 0.1, g["depth"] * 0.48 + 0.10,
                                            0.055, 0.13), secondary)
        if signature in ("chevron", "zigzag", "wings", "wave", "orbit"):
            for sx in (-1, 1):
                w.make("UpperTorso", prism((0, front(8) - 0.015, heights[8]),
                                            (sx * chest * 0.27, front(6) - 0.015, heights[6]),
                                            0.085, 0.085, sides=4), accent)
        elif signature in ("medal", "star", "meteor", "crown", "checker"):
            w.make("UpperTorso", pyramid((0, front(7) - 0.025, zmid),
                                          (0, front(7) - 0.07, zmid + 0.22),
                                          chest * 0.17, 0.10), accent)
        else:
            w.make("UpperTorso", block((0, front(7) - 0.035, zmid),
                                        (chest * 0.36, 0.06, 0.20)), accent)
        w.start(name + "Bottom")
        _bottom(w, body, g, primary, lower)
        for side, sx in sides():
            hip, knee = J[side + "Hip"], J[side + "Knee"]
            leg_z = hip.z - (hip.z - knee.z) * (0.38 if lower == "short" else 0.55)
            w.make(side + "UpperLeg", prism((hip.x + sx * (cfg["thigh"] + 0.07), 0, leg_z + 0.13),
                                            (hip.x + sx * (cfg["thigh"] + 0.07), 0, leg_z - 0.13),
                                            0.026, 0.026, sides=4), accent)
            if lower in ("cargo", "baggy"):
                w.make(side + "UpperLeg", block((hip.x + sx * (cfg["thigh"] + 0.04),
                                                 -cfg["thigh"] * 0.35, leg_z),
                                                (0.16 + cfg["thigh"] * 0.30, 0.08, 0.22)), secondary)

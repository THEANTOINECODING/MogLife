"""
Construit les boss 2 à 6 de MOG LIFE (style low poly PS1, anatomie plus réaliste), de plus en plus
grands, musclés (bras ET jambes) et orange :
Brayan -> Coach Turbo -> M. Pas-Les-Jambes -> Le Roi du Quartier -> Le Dieu du Pump (aberration).
À exécuter dans Blender. Chaque boss va dans sa propre collection (même nom que son id dans Stages.luau).
Variable optionnelle ONLY = ["Brayan", ...] pour ne reconstruire que certains boss.
"""
import bpy, math, random
from mathutils import Vector

LIB = r"C:\Users\antoi\Documents\MogLife\tools\blender\lowpoly_lib.py"
exec(compile(open(LIB, encoding="utf-8").read(), LIB, "exec"), globals())

ATLAS = r"C:\Users\antoi\Documents\MogLife\tools\blender\bro_atlas.py"
exec(compile(open(ATLAS, encoding="utf-8").read(), ATLAS, "exec"), globals())


# ------------------------------------------------------------------ corps d'un « bro »
def build_bro(name, cfg):
    atlas = paint_bro_atlas(name, cfg)
    b = Builder(name, atlas, cfg.get("scale", 1.0))
    sx = (-1, 1)
    top_kind = cfg.get("top")
    clothed = top_kind in ("tank", "jacket", "shirt")  # shirt : manches longues, tissu uni (habitants)
    body = "top" if clothed else "skin"

    # --- jambes (elles grossissent avec le reste : paramètre `leg`)
    foot_h = 0.25
    leg = cfg["leg"]
    leg_len, hip_w = cfg["leg_len"], cfg["hip_w"]
    hip_z = foot_h + leg_len
    knee_z = foot_h + leg_len * 0.47
    leg_x = hip_w * 0.28
    thigh_r = 0.17 + leg * 0.38
    calf_r = 0.12 + leg * 0.22
    for s in sx:
        x = leg_x * s
        b.make(block((x, -0.18, foot_h / 2), (0.3 + leg * 0.25, 0.6 + leg * 0.3, foot_h), taper_top=0.85), "shoe")
        b.make(limb((x, 0, foot_h), (x, 0, knee_z), calf_r * 0.55, calf_r, calf_r * 0.72, mid_t=0.6,
                    bulge_dir=(0, 1, 0), bulge=calf_r * 0.25), "skin")                               # mollet
        b.make(lowsphere((x, -0.03, knee_z), (calf_r * 0.75, calf_r * 0.75, calf_r * 0.7), 6, 4), "skin")  # genou
        b.make(limb((x, 0, knee_z), (x * 1.05, 0, hip_z), calf_r * 0.78, thigh_r, thigh_r * 0.9,
                    bulge_dir=(0, -1, 0), bulge=thigh_r * 0.15), "skin")                             # cuisse
        b.make(limb((x * 1.05, 0, hip_z + 0.05), (x, 0, hip_z - leg_len * 0.2), thigh_r * 1.05, thigh_r * 1.12,
                    thigh_r * 1.1), "shorts")                                                        # jambe de short
    b.make(lowsphere((0, 0.02, hip_z + 0.15), (hip_w * 0.5 + thigh_r * 0.4, cfg["torso_d"] * 0.48, 0.38)), "shorts")

    # --- torse : abdos, cage thoracique, grands dorsaux (le V), pectoraux, trapèzes
    torso_d, torso_h = cfg["torso_d"], cfg["torso_h"]
    waist_w, chest_w, shoulder_w = cfg["waist_w"], cfg["chest_w"], cfg["shoulder_w"]
    torso_bottom = hip_z + 0.3
    top = torso_bottom + torso_h
    b.make(lowsphere((0, -0.02, torso_bottom + torso_h * 0.25), (waist_w / 2, torso_d * 0.45, torso_h * 0.3)),
           body, front_cell="top_front" if clothed else "abs")
    b.make(lowsphere((0, 0.02, top - torso_h * 0.32), (chest_w / 2, torso_d * 0.55, torso_h * 0.38), 10, 8),
           body, front_cell="top_front" if clothed else "chest")
    for s in sx:
        b.make(lowsphere((chest_w * 0.4 * s, 0.1, top - torso_h * 0.42), (cfg["lat"], torso_d * 0.38, torso_h * 0.3)), body)
        if not clothed:
            pec = cfg["pec"]
            b.make(lowsphere((chest_w * 0.19 * s, -torso_d * 0.48, top - torso_h * 0.22), (pec, pec * 0.42, pec * 0.62)), "chest")
    trap, neck_r, delt = cfg["trap"], cfg["neck_r"], cfg["delt"]
    for s in sx:
        b.make(limb((neck_r * 0.5 * s, 0.08, top + 0.12 + trap * 0.15), (shoulder_w * 0.42 * s, 0.05, top - 0.05),
                    neck_r * 0.6 + trap * 0.1, 0.12 + trap * 0.32, delt * 0.7), "skin")
    if trap > 0.6:
        b.make(lowsphere((0, 0.25, top + 0.05), (neck_r + trap * 0.3, 0.2 + trap * 0.2, 0.15 + trap * 0.25)), "skin")

    # --- tête (plus le personnage est musclé, plus elle est enfoncée ; elle sort toujours en avant)
    head_r = cfg["head_r"]
    hy = -0.05 - cfg.get("head_fwd", 0.05 + trap * 0.35)
    head_z = top + 0.3 + head_r * 0.9 - trap * 0.12
    b.make(limb((0, 0.02, top - 0.1), (0, hy + 0.05, head_z - head_r * 0.7), neck_r, neck_r * 1.05, neck_r * 0.9), "skin")
    b.make(lowsphere((0, hy, head_z), (head_r * 0.82, head_r * 0.95, head_r), 10, 8), "skin", front_cell="face")
    jaw_w, jaw_h, jaw_fwd = cfg["jaw_w"], cfg["jaw_h"], cfg["jaw_fwd"]
    jaw_depth = head_r * 1.15 + jaw_fwd
    jaw_y = hy - head_r * 0.15 - jaw_fwd * 0.5
    jaw_z = head_z - head_r * 0.6 - jaw_h * 0.25
    jaw_front = jaw_y - jaw_depth / 2
    jaw_top = jaw_z + jaw_h / 2
    b.make(block((0, jaw_y, jaw_z), (jaw_w, jaw_depth, jaw_h), taper_top=0.85), "skin", front_cell="face")   # mâchoire carrée
    b.make(block((0, hy - head_r * 0.86, head_z + head_r * 0.3), (head_r * 1.35, 0.14, 0.12)), "brow")      # arcade + sourcils
    nose_y = min(hy - head_r * 0.88, jaw_front)
    b.make(pyramid((0, nose_y, head_z - head_r * 0.05), (0, nose_y - head_r * 0.32, head_z - head_r * 0.22),
                   head_r * 0.16, head_r * 0.22), "skin")                                                  # nez
    for s in sx:
        b.make(block((head_r * 0.82 * s, hy + 0.02, head_z), (0.09, head_r * 0.35, head_r * 0.45)), "skin")   # oreilles

    # Bouche : lèvres + dents selon l'expression
    mouth = cfg.get("mouth", "grin")
    lips_h = jaw_h * (0.32 if mouth == "shout" else 0.2)
    b.make(block((0, jaw_front - 0.03, jaw_z + jaw_h * 0.1), (jaw_w * 0.5, 0.07, lips_h)), "lips")
    if mouth in ("grin", "shout"):
        b.make(block((0, jaw_front - 0.07, jaw_z + jaw_h * (0.18 if mouth == "shout" else 0.1)),
                     (jaw_w * 0.42, 0.04, jaw_h * 0.1)), "teeth")
    elif mouth == "smug":
        b.make(block((jaw_w * 0.1, jaw_front - 0.07, jaw_z + jaw_h * 0.12), (jaw_w * 0.22, 0.04, jaw_h * 0.06)), "teeth")

    # Yeux : gros et exorbités, mais humains (iris coloré, paupières lourdes)
    eyes = cfg.get("eyes", [cfg.get("eye_r", 0.16)] * 2)
    eye_pos = {}
    for s, r in zip(sx, eyes):
        ey = Vector((head_r * 0.36 * s, min(hy - head_r * 0.78, jaw_front + r * 0.8), max(head_z + head_r * 0.12, jaw_top + r * 0.7)))
        eye_pos[s] = ey
        b.make(lowsphere(tuple(ey), (r, r * 0.85, r)), "white")
        b.make(lowsphere((ey.x, ey.y - r * 0.78, ey.z - r * 0.05), (r * 0.5, r * 0.14, r * 0.5), 8, 4), "iris")
        b.make(lowsphere((ey.x, ey.y - r * 0.88, ey.z - r * 0.05), (r * 0.22, r * 0.08, r * 0.22), 6, 4), "black")
        b.make(half_sphere((ey.x, ey.y, ey.z + r * 0.18), (r * 1.06, r * 0.95, r * 0.95)), "skin")     # paupière lourde

    # --- bras : en A, ou double biceps (« flex »)
    flex = cfg.get("pose") == "flex"
    ua, fa = cfg["ua_len"], cfg["fa_len"]
    sleeve = "top" if top_kind in ("jacket", "shirt") else ("veiny" if cfg.get("veins") else "skin")
    forearm_cell = "top" if top_kind in ("jacket", "shirt") else ("veiny" if cfg.get("veins") else "skin")
    bicep, forearm, fist = cfg["bicep"], cfg["forearm"], cfg["fist"]
    arms = {}
    for s in sx:
        sh = Vector((shoulder_w / 2 * s, 0, top - 0.12))
        b.make(lowsphere(tuple(sh), (delt, delt * 0.95, delt * 0.9)), "top" if top_kind in ("jacket", "shirt") else "skin")   # deltoïde
        if flex:
            el = sh + Vector((ua * s, 0, 0.15))
            wr = el + Vector((0.08 * s, -0.05, fa))
        else:
            el = sh + Vector((math.sin(math.radians(30)) * ua * s, -0.05, -math.cos(math.radians(30)) * ua))
            wr = el + Vector((math.sin(math.radians(12)) * fa * s, -0.12, -math.cos(math.radians(12)) * fa))
        b.make(limb(tuple(sh), tuple(el), delt * 0.6, bicep, bicep * 0.6,
                    bulge_dir=(0, -0.4, 1) if flex else (0, -1, 0), bulge=bicep * 0.25), sleeve)          # biceps / triceps
        b.make(limb(tuple(el), tuple(wr), forearm * 0.8, forearm, forearm * 0.55, mid_t=0.3), forearm_cell)   # avant-bras
        d = (wr - el).normalized()
        front = Vector((0, -1, 0))
        b.make(prism(tuple(wr), tuple(wr + d * fist), fist * 0.48, fist * 0.42, sides=4), "skin")             # main
        b.make(prism(tuple(wr + d * fist * 0.2 + front * fist * 0.35), tuple(wr + d * fist * 0.65 + front * fist * 0.45),
                     fist * 0.15, fist * 0.12, sides=4), "skin")                                             # pouce
        arms[s] = (sh, el, wr)

    geo = dict(top=top, head_z=head_z, head_r=head_r, hy=hy, hip_z=hip_z, foot_h=foot_h, knee_z=knee_z,
               leg_x=leg_x, calf_r=calf_r, arms=arms, eyes=eye_pos, jaw_front=jaw_front, jaw_z=jaw_z, jaw_h=jaw_h,
               torso_d=torso_d, shoulder_w=shoulder_w, chest_w=chest_w, hip_w=hip_w, neck_r=neck_r)
    if cfg.get("extras"):
        cfg["extras"](b, geo)
    return b


# ------------------------------------------------------------------ accessoires
def hair_slick(b, g, quiff=0.3):
    r, z, hy = g["head_r"], g["head_z"], g["hy"]
    b.make(half_sphere((0, hy + 0.03, z + r * 0.15), (r * 0.86, r * 1.0, r * 0.9)), "hair")
    b.make(block((0, hy - r * 0.5, z + r * 0.85), (r * 1.1, r * 0.8, quiff), lean_top=-0.1), "hair")       # banane gominée


def brayan_extras(b, g):
    hair_slick(b, g, 0.35)
    r, z, hy = g["head_r"], g["head_z"], g["hy"]
    b.make(block((0, hy - r * 0.8, z + r * 0.62), (r * 1.55, 0.1, 0.14)), "black")                         # lunettes sur le front
    b.make(ring((0, -0.02, g["top"] + 0.05), g["neck_r"] * 1.7, 0.06, 0.1, 8), "gold")                     # chaîne en or
    b.make(block((0, -g["torso_d"] * 0.62, g["top"] - 0.5), (0.14, 0.06, 0.18)), "gold")                   # médaillon


def coach_extras(b, g):
    r, z, hy = g["head_r"], g["head_z"], g["hy"]
    b.make(half_sphere((0, hy, z + r * 0.25), (r * 0.9, r * 1.02, r * 0.78)), "accent")                    # casquette
    b.make(block((0, hy - r * 1.0, z + r * 0.3), (r * 1.4, r * 0.85, 0.07)), "accent")                    # visière
    b.make(block((0, g["jaw_front"] - 0.05, g["jaw_z"] + g["jaw_h"] * 0.42), (0.55, 0.1, 0.12)), "hair")  # moustache
    sh, el, wr = g["arms"][1]
    d = Vector((0.15, -1, 0.1)).normalized()
    b.make(prism(tuple(wr + d * 0.1), tuple(wr + d * 1.3), 0.13, 0.5, sides=8), "accent2")                 # mégaphone
    b.make(ring((0, -0.02, g["top"] - 0.02), g["neck_r"] * 1.6, 0.03, 0.04, 8), "black")                  # cordon
    b.make(block((0.05, -g["torso_d"] * 0.62, g["top"] - 0.6), (0.13, 0.09, 0.09)), "gold")               # sifflet


def nolegs_extras(b, g):
    hair_slick(b, g, 0.22)
    r, z, hy = g["head_r"], g["head_z"], g["hy"]
    b.make(ring((0, hy, z + r * 0.4), r * 0.9, 0.05, 0.15, 8), "accent")                                  # bandeau
    for s in (-1, 1):                                                                                     # chaussettes géantes
        x = g["leg_x"] * s
        b.make(prism((x, 0, g["foot_h"]), (x, 0, g["knee_z"] + 0.1), g["calf_r"] * 1.35, g["calf_r"] * 1.45, 8), "accent2")


def king_extras(b, g):
    r, z, hy = g["head_r"], g["head_z"], g["hy"]
    hair_slick(b, g, 0.18)
    crown_z = z + r * 1.0
    b.make(ring((0, hy, crown_z), r * 0.78, 0.06, 0.28, 8), "gold")                                       # couronne
    for i in range(6):
        a = 2 * math.pi * i / 6
        base = (math.cos(a) * r * 0.76, hy + math.sin(a) * r * 0.76, crown_z + 0.14)
        b.make(pyramid(base, (base[0], base[1], crown_z + 0.5), 0.08, 0.05), "gold")
    e = g["eyes"]
    gy = min(e[-1].y, e[1].y) - 0.12
    b.make(block((0, gy, e[1].z), (abs(e[1].x - e[-1].x) + 0.45, 0.08, 0.24)), "black")                   # lunettes noires
    w = g["chest_w"]
    b.make(block((0, g["torso_d"] * 0.7, (g["top"] + g["hip_z"]) / 2 - 0.3),
                 (w * 1.1, 0.12, g["top"] - g["hip_z"] + 1.3), taper_top=0.7), "accent")                   # cape violette


def god_extras(b, g):
    r, z, hy = g["head_r"], g["head_z"], g["hy"]
    hair_slick(b, g, 0.25)
    b.make(ring((0, hy, z + r * 0.5), r * 0.92, 0.07, 0.12, 10), "laurel")                                # couronne de laurier
    for i in range(10):
        a = 2 * math.pi * i / 10
        base = (math.cos(a) * r * 0.92, hy + math.sin(a) * r * 0.92, z + r * 0.55)
        b.make(pyramid(base, (base[0] * 1.25, hy + (base[1] - hy) * 1.25, z + r * 0.8), 0.07, 0.03), "laurel")
    b.make(ring((0, 0.02, g["hip_z"] + 0.35), g["hip_w"] * 0.75, 0.1, 0.4, 10), "gold")                   # ceinture de champion
    b.make(block((0, -g["torso_d"] * 0.5, g["hip_z"] + 0.35), (0.9, 0.12, 0.6)), "gold")
    # ABERRATION : des muscles qui poussent sur les muscles (épaules, trapèzes, bras, dos)
    random.seed(42)
    w, top = g["shoulder_w"], g["top"]
    for _ in range(20):
        side = random.choice((-1, 1))
        kind = random.random()
        if kind < 0.4:
            c = (side * random.uniform(0.2, 0.5) * w, random.uniform(-0.1, 0.5), top + random.uniform(-0.3, 0.5))
        elif kind < 0.8:
            sh, el, wr = g["arms"][side]
            t = random.uniform(0.2, 0.8)
            p = sh.lerp(el, t) if random.random() < 0.65 else el.lerp(wr, t * 0.6)
            c = tuple(p + Vector((0, random.uniform(-0.25, 0.25), random.uniform(0.1, 0.45))))
        else:
            c = (side * random.uniform(0.15, 0.45) * w, random.uniform(0.35, 0.7), top - random.uniform(0.4, 1.4))
        rr = random.uniform(0.28, 0.55)
        b.make(lowsphere(c, (rr, rr * random.uniform(0.75, 1.0), rr * random.uniform(0.8, 1.1)), 7, 5), "veiny")


# ------------------------------------------------------------------ les boss (de plus en plus grands, musclés et orange)
BOSSES = {
    "Brayan": dict(scale=1.15, skin=(0.9, 0.62, 0.45), iris=(0.25, 0.45, 0.75), top="tank", top_color=(0.2, 0.62, 0.66),
                   shorts=(0.15, 0.15, 0.2), shoe=(0.92, 0.92, 0.92), mouth="grin",
                   leg=0.25, leg_len=2.3, hip_w=0.85, waist_w=0.75, chest_w=1.25, shoulder_w=1.7, torso_d=0.62,
                   torso_h=1.75, pec=0.3, lat=0.25, trap=0.35, delt=0.28, bicep=0.24, forearm=0.15, fist=0.26,
                   ua_len=1.0, fa_len=0.95, neck_r=0.17, head_r=0.4, jaw_w=0.62, jaw_h=0.42, jaw_fwd=0.08, eye_r=0.15,
                   extras=brayan_extras),
    "CoachTurbo": dict(scale=1.3, skin=(0.92, 0.56, 0.38), top="jacket", top_color=(0.75, 0.13, 0.13),
                       shorts=(0.7, 0.12, 0.12), accent=(0.78, 0.14, 0.14), accent2=(0.92, 0.92, 0.92),
                       shoe=(0.92, 0.92, 0.92), stubble=True, mouth="shout",
                       leg=0.45, leg_len=2.15, hip_w=0.95, waist_w=0.95, chest_w=1.5, shoulder_w=2.0, torso_d=0.78,
                       torso_h=1.8, pec=0.36, lat=0.32, trap=0.55, delt=0.36, bicep=0.32, forearm=0.2, fist=0.3,
                       ua_len=1.0, fa_len=0.95, neck_r=0.24, head_r=0.42, jaw_w=0.78, jaw_h=0.5, jaw_fwd=0.12, eye_r=0.16,
                       extras=coach_extras),
    "NoLegs": dict(scale=1.5, skin=(0.95, 0.52, 0.3), top="none", shorts=(0.1, 0.1, 0.12), accent=(0.8, 0.15, 0.15),
                   accent2=(0.95, 0.95, 0.95), shoe=(0.92, 0.92, 0.92), stubble=True, cleft=True, mouth="smug",
                   leg=0.0, leg_len=1.0, hip_w=0.85, waist_w=1.15, chest_w=2.1, shoulder_w=2.9, torso_d=1.1,
                   torso_h=2.0, pec=0.55, lat=0.5, trap=0.95, delt=0.55, bicep=0.48, forearm=0.3, fist=0.38,
                   ua_len=1.05, fa_len=1.0, neck_r=0.34, head_r=0.4, jaw_w=0.95, jaw_h=0.55, jaw_fwd=0.2, eye_r=0.16,
                   extras=nolegs_extras),
    "BlockKing": dict(scale=1.8, skin=(0.97, 0.47, 0.22), top="none", shorts=(0.42, 0.1, 0.5), accent=(0.42, 0.1, 0.55),
                      shoe=(0.85, 0.68, 0.18), stubble=True, cleft=True, veins=True, mouth="smug", pose="flex",
                      leg=0.7, leg_len=1.7, hip_w=1.05, waist_w=1.25, chest_w=2.5, shoulder_w=3.3, torso_d=1.3,
                      torso_h=2.1, pec=0.68, lat=0.65, trap=1.2, delt=0.65, bicep=0.62, forearm=0.38, fist=0.44,
                      ua_len=1.2, fa_len=1.0, neck_r=0.42, head_r=0.4, jaw_w=1.15, jaw_h=0.65, jaw_fwd=0.3, eye_r=0.16,
                      extras=king_extras),
    "PumpGod": dict(scale=2.5, skin=(1.0, 0.42, 0.12), iris=(0.75, 0.6, 0.1), top="none", shorts=(0.95, 0.95, 0.93),
                    shoe=(0.85, 0.68, 0.18), stubble=True, cleft=True, veins=True, mouth="smug", pose="flex",
                    leg=1.1, leg_len=1.4, hip_w=1.2, waist_w=1.6, chest_w=3.4, shoulder_w=4.4, torso_d=1.7,
                    torso_h=2.4, pec=1.0, lat=0.95, trap=1.9, delt=0.95, bicep=0.95, forearm=0.55, fist=0.6,
                    ua_len=1.5, fa_len=1.2, neck_r=0.55, head_r=0.36, jaw_w=1.6, jaw_h=0.9, jaw_fwd=0.6, eyes=[0.3, 0.11],
                    extras=god_extras),
}

# Exécuté avec BOSSES_LIBRARY = True (ex. par build_townsfolk.py) : on ne fait que charger les définitions
if not globals().get("BOSSES_LIBRARY"):
    ONLY = globals().get("ONLY") or list(BOSSES)
    offset = 0.0
    for name in ONLY:
        b = build_bro(name, BOSSES[name])
        # Aperçu côte à côte (la position d'objet est ignorée à l'export : seuls les sommets comptent)
        for o in b.col.objects:
            o.location.x = offset
        offset += 6 + BOSSES[name]["scale"] * 3
        print(f"{name}: {len(b.col.objects)} pièces, {b.tris()} triangles")

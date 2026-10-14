"""
Construit les boss 2 à 6 de MOG LIFE (style low poly PS1), de plus en plus grands, musclés et orange :
Brayan -> Coach Turbo -> M. Pas-Les-Jambes -> Le Roi du Quartier -> Le Dieu du Pump (aberration).
À exécuter dans Blender. Chaque boss va dans sa propre collection (même nom que son id dans Stages.luau).
Variable optionnelle ONLY = ["Brayan", ...] pour ne reconstruire que certains boss.
"""
import bpy, math, random, os
from mathutils import Vector

LIB = r"C:\Users\antoi\Documents\MogLife\tools\blender\lowpoly_lib.py"
exec(compile(open(LIB, encoding="utf-8").read(), LIB, "exec"), globals())


# ------------------------------------------------------------------ texture d'un « bro »
def paint_bro_atlas(name, cfg):
    random.seed(sum(ord(c) for c in name))  # graine stable (hash() change à chaque lancement de Blender)
    a = Atlas(name)
    skin = cfg["skin"]
    shade = darker(skin, 0.78)

    a.cell("skin", 0, 0, lambda x, y: noise(skin, 0.03))

    def face(x, y):
        c = noise(skin, 0.03)
        if cfg.get("stubble") and y < 12 and random.random() < 0.22:
            c = darker(skin, 0.55)
        if cfg.get("cleft") and 14 <= x <= 17 and y < 7:
            c = shade
        return c
    a.cell("face", 1, 0, face)

    def chest(x, y):                       # torse nu : pectoraux, abdos, veines
        c = noise(skin, 0.03)
        if 6 < y < 24 and (x == 15 or x == 16):
            c = shade                                             # ligne centrale
        if y == 22 and 4 < x < 28:
            c = shade                                             # bas des pectoraux
        if y < 20 and y % 5 == 0 and 9 < x < 23:
            c = shade                                             # abdos
        if cfg.get("veins") and (x * 7 + y * 3) % 23 == 0:
            c = (0.55, 0.15, 0.25)
        return c
    a.cell("chest", 2, 0, chest)

    def veiny(x, y):                       # peau veineuse (bras de l'aberration)
        c = noise(skin, 0.03)
        if cfg.get("veins") and (abs((x + y // 2) % 11 - 5) == 0 or abs((x * 2 - y) % 13) == 0):
            c = (0.6, 0.12, 0.22)
        return c
    a.cell("veiny", 3, 0, veiny)

    top = cfg.get("top_color", (0.2, 0.2, 0.2))
    a.cell("top", 0, 1, lambda x, y: noise(top, 0.03))

    def top_front(x, y):
        kind = cfg.get("top")
        if kind == "tank" and (x - 16) ** 2 + (y - 32) ** 2 < 30:
            return noise(skin, 0.03)                              # simple encolure ronde
        if kind == "jacket":
            if x in (15, 16):
                return (0.9, 0.9, 0.9)                            # fermeture éclair
            if x in (3, 4, 27, 28):
                return (0.95, 0.95, 0.95)                         # bandes de survêtement
        return noise(top, 0.03)
    a.cell("top_front", 1, 1, top_front)

    a.cell("shorts", 2, 1, lambda x, y: noise(cfg.get("shorts", (0.15, 0.15, 0.2)), 0.03))
    a.cell("hair", 3, 1, lambda x, y: noise(cfg.get("hair", (0.1, 0.07, 0.05)), 0.05))
    a.cell("white", 0, 2, lambda x, y: noise((0.97, 0.96, 0.92), 0.02))
    a.cell("black", 1, 2, lambda x, y: (0.03, 0.03, 0.03))

    def mouth(x, y):
        kind = cfg.get("mouth", "grin")
        if kind == "shout":                                      # bouche grande ouverte qui hurle
            if y > 24 and 6 < x < 26:
                return (0.97, 0.96, 0.9)
            return (0.35, 0.05, 0.05)
        if kind == "smug":                                       # rictus en coin
            if 12 < y < 20 and 4 < x < 28 and (y - 12) < (x - 4) * 0.4:
                return (0.97, 0.96, 0.9)
            return darker(skin, 0.5)
        if 8 < y < 24 and 2 < x < 30:                            # grand sourire de facettes blanches
            return (0.06, 0.04, 0.04) if (x % 5 == 0 or y == 16) else (0.98, 0.98, 0.95)
        return darker(skin, 0.45)
    a.cell("mouth", 2, 2, mouth)

    a.cell("gold", 3, 2, lambda x, y: noise((0.95, 0.75, 0.15), 0.06))
    a.cell("accent", 0, 3, lambda x, y: noise(cfg.get("accent", (0.5, 0.1, 0.6)), 0.03))
    a.cell("accent2", 1, 3, lambda x, y: noise(cfg.get("accent2", (0.9, 0.9, 0.9)), 0.03))
    a.cell("shoe", 2, 3, lambda x, y: noise(cfg.get("shoe", (0.9, 0.9, 0.9)), 0.04))
    a.cell("laurel", 3, 3, lambda x, y: noise((0.35, 0.6, 0.15), 0.06) if (x + y) % 4 else (0.95, 0.8, 0.2))
    return a


# ------------------------------------------------------------------ corps d'un « bro »
def build_bro(name, cfg):
    atlas = paint_bro_atlas(name, cfg)
    b = Builder(name, atlas, cfg.get("scale", 1.0))
    sx = (-1, 1)

    foot_h = 0.22
    hip_z = foot_h + cfg["leg_len"]
    hip_w, waist_w, shoulder_w = cfg["hip_w"], cfg["waist_w"], cfg["shoulder_w"]
    torso_d, torso_h = cfg["torso_d"], cfg["torso_h"]
    torso_bottom = hip_z + 0.3
    top = torso_bottom + torso_h
    clothed = cfg.get("top") in ("tank", "jacket")

    # Pieds, jambes, short
    for s in sx:
        b.make(block((hip_w * 0.28 * s, -0.12, foot_h / 2), (cfg["foot"][0], cfg["foot"][1], foot_h)), "shoe")
        b.make(prism((hip_w * 0.28 * s, 0, foot_h), (hip_w * 0.3 * s, 0, hip_z + 0.1), cfg["leg_r"], cfg["leg_r"] * 1.15), "skin")
    b.make(block((0, 0.0, hip_z + 0.15), (hip_w, torso_d * 0.95, 0.6)), "shorts")

    # Torse en V (ou en montagne)
    b.make(block((0, 0, torso_bottom + torso_h / 2), (waist_w, torso_d, torso_h), taper_top=shoulder_w / waist_w,
                 taper_depth=1.15), "top" if clothed else "skin", front_cell="top_front" if clothed else "chest")
    pec = cfg["pec"]
    if clothed:
        # Habillé : un seul bloc de poitrine bombée sous le tissu (deux sphères ressembleraient à un haut de bikini)
        b.make(block((0, -torso_d * 0.5 - pec * 0.1, top - 0.3 - pec * 0.35), (shoulder_w * 0.72, pec * 0.7, pec * 1.2),
                     taper_top=1.05), "top", front_cell="top_front")
    else:
        for s in sx:
            b.make(lowsphere((shoulder_w * 0.2 * s, -torso_d * 0.55 - pec * 0.1, top - 0.3 - pec * 0.35),
                             (pec, pec * 0.55, pec * 0.7)), "chest")
    trap = cfg["trap"]
    b.make(lowsphere((0, torso_d * 0.1 + trap * 0.15, top + trap * 0.1), (0.35 + trap * 0.5, 0.3 + trap * 0.3, 0.18 + trap * 0.4)), "skin")

    # Cou et tête : plus le personnage est musclé, plus la tête est enfoncée… mais elle sort toujours
    # EN AVANT des trapèzes, pour que le visage (et la mâchoire) restent visibles
    head_r = cfg["head_r"]
    head_fwd = cfg.get("head_fwd", trap * 0.45)
    hy = -0.05 - head_fwd
    head_z = top + 0.35 + head_r * 0.85 - trap * 0.18
    b.make(prism((0, 0, top - 0.1), (0, hy, head_z - head_r * 0.6), cfg["neck_r"], cfg["neck_r"] * 0.9), "skin")
    b.make(lowsphere((0, hy, head_z), (head_r * 0.85, head_r * 0.95, head_r)), "skin", front_cell="face")
    jaw_w, jaw_h, jaw_fwd = cfg["jaw_w"], cfg["jaw_h"], cfg["jaw_fwd"]
    jaw_depth = head_r * 1.2 + jaw_fwd
    jaw_y = hy - head_r * 0.2 - jaw_fwd * 0.5
    jaw_z = head_z - head_r * 0.55 - jaw_h * 0.3
    b.make(block((0, jaw_y, jaw_z), (jaw_w, jaw_depth, jaw_h), taper_top=0.9), "skin", front_cell="face")
    b.make(block((0, jaw_y - jaw_depth / 2 - 0.02, jaw_z + jaw_h * 0.05), (jaw_w * 0.6, 0.06, jaw_h * 0.38)), "mouth")
    for s in sx:
        b.make(block((head_r * 0.85 * s, hy, head_z), (0.08, head_r * 0.4, head_r * 0.5)), "skin")       # oreilles
    # Gros yeux exorbités (tailles réglables : l'aberration a des yeux dépareillés)
    eyes = cfg.get("eyes", [cfg.get("eye_r", 0.2)] * 2)
    jaw_front = jaw_y - jaw_depth / 2
    jaw_top = jaw_z + jaw_h / 2
    for s, r in zip(sx, eyes):
        # Les yeux restent visibles même au-dessus d'une mâchoire démesurée : ils se posent dessus si besoin
        ey = (head_r * 0.4 * s, min(hy - head_r * 0.8, jaw_front + r * 0.9),
              max(head_z + head_r * 0.2, jaw_top + r * 0.75))
        b.make(lowsphere(ey, (r, r * 0.9, r)), "white")
        b.make(lowsphere((ey[0] + 0.03 * s, ey[1] - r * 0.85, ey[2] - r * 0.15), (r * 0.32, r * 0.2, r * 0.32), 6, 4), "black")
        b.make(block((ey[0], ey[1] - 0.02, ey[2] + r + 0.06), (r * 1.7, 0.08, 0.08)), "hair")              # sourcils

    # Bras : pose en A, ou double biceps (« flex »)
    flex = cfg.get("pose") == "flex"
    ua, fa = cfg["ua_len"], cfg["fa_len"]
    sleeve = "top" if cfg.get("top") == "jacket" else ("veiny" if cfg.get("veins") else "skin")
    arm_parts = {}
    for s in sx:
        sh = Vector((shoulder_w / 2 * s, 0, top - 0.2))
        b.make(lowsphere(tuple(sh), (cfg["delt"], cfg["delt"] * 0.9, cfg["delt"])), sleeve)            # épaule
        if flex:
            el = sh + Vector((ua * s, 0, 0.15))
            wr = el + Vector((0.1 * s, -0.05, fa))
        else:
            el = sh + Vector((math.sin(math.radians(35)) * ua * s, -0.05, -math.cos(math.radians(35)) * ua))
            wr = el + Vector((math.sin(math.radians(15)) * fa * s, -0.1, -math.cos(math.radians(15)) * fa))
        bi = cfg["bicep"]
        b.make(prism(tuple(sh), tuple(el), bi * 0.55, bi * 0.5), sleeve)
        mid = (sh + el) / 2 + (Vector((0, -0.05, bi * 0.35)) if flex else Vector((0, -bi * 0.25, 0)))
        b.make(lowsphere(tuple(mid), (bi, bi * 0.85, bi * 1.05)), sleeve)                             # biceps
        b.make(prism(tuple(el), tuple(wr), cfg["forearm_r"], cfg["forearm_r"] * 0.75), "veiny" if cfg.get("veins") else "skin")
        f = cfg["fist"]
        b.make(block(tuple(wr + (wr - el).normalized() * f * 0.4), (f, f * 0.85, f)), "skin")         # poing en moufle
        arm_parts[s] = (sh, el, wr)

    geo = dict(top=top, head_z=head_z, head_r=head_r, hy=hy, hip_z=hip_z, foot_h=foot_h, arms=arm_parts,
               jaw=(jaw_y, jaw_z, jaw_depth), torso_d=torso_d, shoulder_w=shoulder_w, hip_w=hip_w)
    if cfg.get("extras"):
        cfg["extras"](b, geo)
    return b


# ------------------------------------------------------------------ accessoires
def hair_slick(b, g, quiff=0.35):
    r, z = g["head_r"], g["head_z"]
    b.make(half_sphere((0, g["hy"] + 0.03, z + r * 0.25), (r * 0.9, r, r * 0.8)), "hair")
    b.make(block((0, g["hy"] - r * 0.5, z + r * 0.9), (r * 1.1, r * 0.8, quiff), lean_top=-0.12), "hair")     # banane gominée


def brayan_extras(b, g):
    hair_slick(b, g, 0.4)
    r, z = g["head_r"], g["head_z"]
    b.make(block((0, g["hy"] - r * 0.75, z + r * 0.75), (r * 1.6, 0.1, 0.16)), "black")                         # lunettes sur le front
    b.make(ring((0, -0.05, g["top"] + 0.05), 0.42, 0.08, 0.12, 8), "gold")                            # chaîne en or
    b.make(block((0, -0.62, g["top"] - 0.45), (0.16, 0.06, 0.2)), "gold")                             # médaillon


def coach_extras(b, g):
    r, z = g["head_r"], g["head_z"]
    b.make(half_sphere((0, g["hy"], z + r * 0.3), (r * 0.95, r * 1.02, r * 0.75)), "accent")                # casquette
    b.make(block((0, g["hy"] - r * 1.0, z + r * 0.35), (r * 1.5, r * 0.9, 0.07)), "accent")                   # visière
    b.make(block((0, g["jaw"][0] - g["jaw"][2] / 2 - 0.05, g["jaw"][1] + 0.28), (0.6, 0.12, 0.12)), "hair")  # moustache
    sh, el, wr = g["arms"][1]
    tip = wr + Vector((0.2, -1.4, 0.15))
    b.make(prism(tuple(wr + Vector((0, -0.2, 0))), tuple(tip), 0.14, 0.55, sides=8), "accent2")       # mégaphone géant
    b.make(ring((0, -0.05, g["top"] - 0.05), 0.4, 0.04, 0.05, 8), "black")                            # cordon du sifflet
    b.make(block((0.05, -0.6, g["top"] - 0.6), (0.14, 0.1, 0.1)), "gold")                             # sifflet


def nolegs_extras(b, g):
    hair_slick(b, g, 0.25)
    r, z = g["head_r"], g["head_z"]
    b.make(ring((0, g["hy"], z + r * 0.45), r * 0.92, 0.05, 0.16, 8), "accent")                          # bandeau
    for s in (-1, 1):                                                                                  # chaussettes géantes
        b.make(prism((g["hip_w"] * 0.28 * s, 0, g["foot_h"]), (g["hip_w"] * 0.29 * s, 0, g["hip_z"] - 0.1), 0.22, 0.24, 8), "accent2")


def king_extras(b, g):
    r, z = g["head_r"], g["head_z"]
    hair_slick(b, g, 0.2)
    crown_z = z + r * 1.05
    b.make(ring((0, g["hy"], crown_z), r * 0.8, 0.06, 0.3, 8), "gold")                                  # couronne
    for i in range(6):
        a = 2 * math.pi * i / 6
        base = (math.cos(a) * r * 0.78, g["hy"] + math.sin(a) * r * 0.78, crown_z + 0.15)
        b.make(pyramid(base, (base[0], base[1], crown_z + 0.55), 0.09, 0.05), "gold")
    b.make(block((0, g["hy"] - r * 0.9, z + r * 0.2), (r * 1.9, 0.1, 0.22)), "black")                          # lunettes noires
    w = g["shoulder_w"]
    b.make(block((0, g["torso_d"] * 0.75, (g["top"] + g["hip_z"]) / 2 - 0.4),
                 (w * 1.05, 0.12, g["top"] - g["hip_z"] + 1.2), taper_top=0.75), "accent")            # cape violette


def god_extras(b, g):
    r, z = g["head_r"], g["head_z"]
    hair_slick(b, g, 0.3)
    b.make(ring((0, g["hy"], z + r * 0.55), r * 0.95, 0.08, 0.12, 10), "laurel")                        # couronne de laurier
    for i in range(10):
        a = 2 * math.pi * i / 10
        base = (math.cos(a) * r * 0.95, g["hy"] + math.sin(a) * r * 0.95, z + r * 0.6)
        b.make(pyramid(base, (base[0] * 1.25, g["hy"] + (base[1] - g["hy"]) * 1.25, z + r * 0.85), 0.08, 0.03), "laurel")
    b.make(ring((0, 0, g["hip_z"] + 0.35), g["hip_w"] * 0.62, 0.1, 0.4, 10), "gold")                  # ceinture de champion
    b.make(block((0, -g["hip_w"] * 0.62, g["hip_z"] + 0.35), (0.9, 0.12, 0.6)), "gold")
    # ABERRATION : des muscles qui poussent sur les muscles, partout
    random.seed(42)
    w, top = g["shoulder_w"], g["top"]
    for _ in range(26):
        side = random.choice((-1, 1))
        kind = random.random()
        if kind < 0.45:                                    # grappes sur les épaules et les trapèzes
            c = (side * random.uniform(0.15, 0.55) * w, random.uniform(-0.3, 0.4), top + random.uniform(-0.6, 0.6))
        elif kind < 0.8:                                   # bosses sur les bras
            sh, el, wr = g["arms"][side]
            t = random.random()
            p = sh.lerp(el, t) if random.random() < 0.6 else el.lerp(wr, t)
            c = tuple(p + Vector((0, random.uniform(-0.4, 0.1), random.uniform(0, 0.4))))
        else:                                              # dos et flancs
            c = (side * random.uniform(0.2, 0.5) * w, random.uniform(0.2, 0.6), top - random.uniform(0.6, 1.6))
        rr = random.uniform(0.25, 0.6)
        b.make(lowsphere(c, (rr, rr * random.uniform(0.7, 1.1), rr * random.uniform(0.7, 1.2)), 7, 5), "veiny")


# ------------------------------------------------------------------ les boss (de plus en plus grands, musclés et orange)
BOSSES = {
    "Brayan": dict(scale=1.15, skin=(0.95, 0.62, 0.38), top="tank", top_color=(0.15, 0.7, 0.75), shorts=(0.15, 0.15, 0.2),
                   shoe=(0.95, 0.95, 0.95), stubble=False, mouth="grin",
                   leg_len=2.3, leg_r=0.15, foot=(0.35, 0.6), hip_w=0.85, torso_h=1.7, waist_w=0.8, shoulder_w=1.6,
                   torso_d=0.6, pec=0.32, trap=0.5, delt=0.3, bicep=0.3, forearm_r=0.13, fist=0.24, ua_len=0.95, fa_len=0.9,
                   neck_r=0.18, head_r=0.38, jaw_w=0.7, jaw_h=0.42, jaw_fwd=0.1, eye_r=0.19, extras=brayan_extras),
    "CoachTurbo": dict(scale=1.3, skin=(0.97, 0.55, 0.28), top="jacket", top_color=(0.8, 0.12, 0.12), shorts=(0.75, 0.1, 0.1),
                       accent=(0.85, 0.12, 0.12), accent2=(0.95, 0.95, 0.95), shoe=(0.95, 0.95, 0.95), stubble=True, mouth="shout",
                       leg_len=2.1, leg_r=0.17, foot=(0.36, 0.62), hip_w=0.95, torso_h=1.8, waist_w=1.0, shoulder_w=2.0,
                       torso_d=0.75, pec=0.4, trap=0.75, delt=0.4, bicep=0.4, forearm_r=0.17, fist=0.3, ua_len=1.0, fa_len=0.95,
                       neck_r=0.24, head_r=0.4, jaw_w=0.85, jaw_h=0.5, jaw_fwd=0.15, eye_r=0.21, extras=coach_extras),
    "NoLegs": dict(scale=1.5, skin=(1.0, 0.47, 0.17), top="none", shorts=(0.1, 0.1, 0.12),
                   accent=(0.9, 0.15, 0.15), accent2=(0.97, 0.97, 0.97), shoe=(0.95, 0.95, 0.95), stubble=True, cleft=True,
                   mouth="smug", leg_len=1.0, leg_r=0.08, foot=(0.3, 0.5), hip_w=0.9, torso_h=2.0, waist_w=1.2,
                   shoulder_w=2.8, torso_d=1.0, pec=0.55, trap=1.05, delt=0.55, bicep=0.55, forearm_r=0.24, fist=0.36,
                   ua_len=1.05, fa_len=1.0, neck_r=0.32, head_r=0.38, jaw_w=1.0, jaw_h=0.55, jaw_fwd=0.22, eye_r=0.2,
                   extras=nolegs_extras),
    "BlockKing": dict(scale=1.8, skin=(1.0, 0.4, 0.08), top="none", shorts=(0.45, 0.1, 0.55), accent=(0.45, 0.1, 0.6),
                      shoe=(0.95, 0.75, 0.15), stubble=True, cleft=True, veins=True, mouth="smug", pose="flex",
                      leg_len=1.5, leg_r=0.13, foot=(0.32, 0.55), hip_w=1.0, torso_h=2.1, waist_w=1.3, shoulder_w=3.3,
                      torso_d=1.2, pec=0.7, trap=1.35, delt=0.65, bicep=0.75, forearm_r=0.3, fist=0.42, ua_len=1.2,
                      fa_len=1.0, neck_r=0.38, head_r=0.38, jaw_w=1.2, jaw_h=0.65, jaw_fwd=0.35, eye_r=0.21,
                      extras=king_extras),
    "PumpGod": dict(scale=2.5, skin=(1.0, 0.33, 0.0), top="none", shorts=(0.97, 0.97, 0.95), shoe=(0.95, 0.75, 0.15),
                    stubble=True, cleft=True, veins=True, mouth="smug", pose="flex",
                    leg_len=1.1, leg_r=0.09, foot=(0.25, 0.42), hip_w=1.0, torso_h=2.4, waist_w=1.6, shoulder_w=4.4,
                    torso_d=1.6, pec=1.0, trap=2.0, delt=0.95, bicep=1.1, forearm_r=0.42, fist=0.55, ua_len=1.5,
                    fa_len=1.2, neck_r=0.5, head_r=0.34, jaw_w=1.6, jaw_h=0.9, jaw_fwd=0.65, eyes=[0.34, 0.12],
                    extras=god_extras),
}

ONLY = globals().get("ONLY") or list(BOSSES)
offset = 0.0
for name in ONLY:
    b = build_bro(name, BOSSES[name])
    # Aperçu côte à côte (la position d'objet est ignorée à l'export : seuls les sommets comptent)
    for o in b.col.objects:
        o.location.x = offset
    offset += 6 + BOSSES[name]["scale"] * 3
    print(f"{name}: {len(b.col.objects)} pièces, {b.tris()} triangles")

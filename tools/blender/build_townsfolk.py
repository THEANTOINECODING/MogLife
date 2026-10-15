"""
Habitants de Muscle City (étape 4) : les 8 habitants des aides, les vendeurs des magasins (D38) et le mentor
mystérieux (D29), dans le style des boss (low poly PS1, anatomie réaliste, texture à éclairage cuit).
L'humour est dans les costumes, les accessoires et les expressions, jamais dans le corps des gens (00_VISION).

Écrit assets/export/npcs/MogLife_Townsfolk.fbx (un mesh par personnage, nommé comme son id dans Npcs.luau)
+ une texture par personnage à côté. Import : Accueil -> Importer 3D, puis tools/install_townsfolk.luau.
Dans Blender : exec(open(r"...\\tools\\blender\\build_townsfolk.py", encoding="utf-8").read())
"""
import bpy, bmesh, math, os
from mathutils import Vector

D = r"C:\Users\antoi\Documents\MogLife\tools\blender"
OUT = r"C:\Users\antoi\Documents\MogLife\assets\export\npcs"
os.makedirs(OUT, exist_ok=True)

BOSSES_LIBRARY = True
path = os.path.join(D, "build_bosses.py")
exec(compile(open(path, encoding="utf-8").read(), path, "exec"), globals())

# Silhouette d'un habitant (pas un bro : ni pectoraux en vitrine ni trapèzes géants)
CIVIL = dict(scale=1.0, skin=(0.93, 0.72, 0.56), iris=(0.35, 0.22, 0.12), top="shirt", top_color=(0.5, 0.5, 0.55),
             shorts=(0.25, 0.25, 0.3), shoe=(0.9, 0.9, 0.9), hair=(0.25, 0.16, 0.09), mouth="grin",
             leg=0.12, leg_len=2.2, hip_w=0.8, waist_w=0.8, chest_w=1.05, shoulder_w=1.4, torso_d=0.62, torso_h=1.6,
             pec=0.1, lat=0.08, trap=0.1, delt=0.22, bicep=0.17, forearm=0.13, fist=0.22, ua_len=0.95, fa_len=0.9,
             neck_r=0.15, head_r=0.42, jaw_w=0.55, jaw_h=0.38, jaw_fwd=0.03, eye_r=0.15)


def cfg(**kw):
    c = dict(CIVIL)
    c.update(kw)
    return c


# ------------------------------------------------------------------ pièces de costume
def skirt(b, g, cell, to_ankle=False, flare=1.0):
    """Robe ou peignoir sous la taille."""
    bottom = g["foot_h"] + 0.35 if to_ankle else g["knee_z"] - 0.1
    r_top = g["hip_w"] * 0.55
    b.make(prism((0, 0.02, g["hip_z"] + 0.35), (0, 0.02, bottom), r_top, r_top * (1.3 + 0.25 * flare), sides=10), cell)


def long_pants(b, g, cell):
    """Pantalon : recouvre tibia et cuisse (un peu plus large que les muscles de build_bro)."""
    thigh = 0.17 + CIVIL["leg"] * 0.38
    for s in (-1, 1):
        x = g["leg_x"] * s
        b.make(limb((x, 0, g["foot_h"] + 0.12), (x, 0, g["knee_z"]), g["calf_r"] * 1.05, g["calf_r"] * 1.3,
                    g["calf_r"] * 1.2), cell)
        b.make(limb((x, 0, g["knee_z"] - 0.05), (x * 1.05, 0, g["hip_z"] + 0.1), g["calf_r"] * 1.25, thigh * 1.2,
                    thigh * 1.3), cell)


def socks(b, g, cell):
    for s in (-1, 1):
        x = g["leg_x"] * s
        b.make(prism((x, 0, g["foot_h"]), (x, 0, g["foot_h"] + 0.55), g["calf_r"] * 0.9, g["calf_r"] * 0.95, 8), cell)


def cap(b, g, cell, backwards=False):
    r, z, hy = g["head_r"], g["head_z"], g["hy"]
    b.make(half_sphere((0, hy, z + r * 0.3), (r * 0.9, r * 1.0, r * 0.7)), cell)
    side = 1 if backwards else -1
    b.make(block((0, hy + side * r * 1.0, z + r * 0.33), (r * 1.2, r * 0.8, 0.06)), cell)


def shades(b, g, on_head=False):
    e = g["eyes"]
    z = (e[1].z + g["head_r"] * 0.75) if on_head else e[1].z
    y = (g["hy"] - g["head_r"] * 0.5) if on_head else min(e[-1].y, e[1].y) - 0.1
    b.make(block((0, y, z), (abs(e[1].x - e[-1].x) + 0.42, 0.08, 0.2)), "black")


def mustache(b, g, cell="hair", big=1.0):
    b.make(block((0, g["jaw_front"] - 0.05, g["jaw_z"] + g["jaw_h"] * 0.42), (0.5 * big, 0.1, 0.12 * big)), cell)


def beard(b, g, cell="hair"):
    # Sous la bouche (pas devant) : sinon on dirait un masque
    b.make(block((0, g["jaw_front"] + 0.08, g["jaw_z"] - g["jaw_h"] * 0.42), (g["head_r"] * 1.4, 0.3, g["jaw_h"] * 0.62),
                 taper_top=1.15), cell)
    b.make(pyramid((0, g["jaw_front"] + 0.02, g["jaw_z"] - g["jaw_h"] * 0.7),
                   (0, g["jaw_front"] - 0.02, g["jaw_z"] - g["jaw_h"] * 1.3), g["head_r"] * 0.45, 0.12), cell)
    mustache(b, g, cell, 1.1)


def in_hand(g, side=1, forward=0.0, down=0.0):
    sh, el, wr = g["arms"][side]
    d = (wr - el).normalized()
    return wr + d * (0.25 + down) + Vector((0, -forward, 0))


def hair_bun(b, g, cell="hair", big=1.0):
    r, z, hy = g["head_r"], g["head_z"], g["hy"]
    b.make(half_sphere((0, hy + 0.03, z + r * 0.15), (r * 0.88, r * 1.02, r * 0.92)), cell)
    b.make(lowsphere((0, hy + r * 0.2, z + r * (1.05 + 0.2 * big)), (r * 0.6 * big, r * 0.6 * big, r * 0.55 * big)), cell)


def short_hair(b, g, cell="hair"):
    r, z, hy = g["head_r"], g["head_z"], g["hy"]
    b.make(half_sphere((0, hy + 0.03, z + r * 0.15), (r * 0.88, r * 1.02, r * 0.92)), cell)


# ------------------------------------------------------------------ les personnages
def mom_extras(b, g):
    skirt(b, g, "top")                                                     # peignoir rose
    b.make(ring((0, -0.02, g["hip_z"] + 0.5), g["hip_w"] * 0.52, 0.06, 0.12, 10), "accent")   # ceinture du peignoir
    short_hair(b, g)
    r, z, hy = g["head_r"], g["head_z"], g["hy"]
    for k in range(5):                                                    # bigoudis
        a = -0.9 + k * 0.45
        c = (math.sin(a) * r * 0.75, hy + math.cos(a) * 0.1 - 0.05, z + r * 0.75 + math.cos(a) * 0.12)
        b.make(prism((c[0] - 0.12, c[1], c[2]), (c[0] + 0.12, c[1], c[2]), 0.09, 0.09, sides=6), "accent2")
    jar = in_hand(g, 1, forward=0.15)                                       # le bocal de cornichons
    b.make(prism(tuple(jar + Vector((0, 0, -0.25))), tuple(jar + Vector((0, 0, 0.2))), 0.22, 0.22, sides=8), "accent")
    b.make(prism(tuple(jar + Vector((0, 0, 0.2))), tuple(jar + Vector((0, 0, 0.3))), 0.24, 0.24, sides=8), "gold")


def courier_extras(b, g):
    cap(b, g, "accent")
    t = g["top"]
    b.make(block((0, g["torso_d"] * 0.95, t - 0.6), (1.1, 0.9, 1.0)), "accent2")             # colis géant sur le dos
    b.make(block((0, g["torso_d"] * 0.95, t - 0.6), (1.12, 0.92, 0.12)), "accent")            # scotch
    box = in_hand(g, -1, forward=0.25)                                      # un colis de plus sous le bras
    b.make(block(tuple(box), (0.55, 0.45, 0.4)), "accent2")


def kid_extras(b, g):
    cap(b, g, "accent", backwards=True)
    hammer = in_hand(g, 1, forward=0.1)                                     # marteau plus grand que lui
    b.make(prism(tuple(hammer + Vector((0, 0, -0.1))), tuple(hammer + Vector((0, -0.05, 0.75))), 0.05, 0.05, sides=6),
           "accent2")
    b.make(block(tuple(hammer + Vector((0, -0.05, 0.8))), (0.4, 0.18, 0.18)), "black")
    for s in (-1, 1):                                                       # bretelles de salopette
        b.make(block((s * 0.22, -g["torso_d"] * 0.5, g["top"] - 0.45), (0.1, 0.06, 0.9)), "shorts")


def neighbor_extras(b, g):
    short_hair(b, g)
    shades(b, g, on_head=True)                                              # lunettes relevées sur la tête
    mustache(b, g, big=1.2)
    socks(b, g, "white")                                                    # chaussettes dans les sandales
    keys = in_hand(g, 1, forward=0.1)
    b.make(ring(tuple(keys), 0.1, 0.03, 0.03, 8), "gold")


def doremi_extras(b, g):
    skirt(b, g, "top", to_ankle=True, flare=1.6)                             # robe de cantatrice
    hair_bun(b, g, big=1.3)
    neck = Vector((0, -0.02, g["top"] + 0.05))
    for k in range(10):                                                     # collier de perles
        a = math.pi * (0.15 + 0.7 * k / 9)
        b.make(lowsphere((math.cos(a) * g["neck_r"] * 1.9, neck.y - math.sin(a) * g["neck_r"] * 1.6, neck.z - math.sin(a) * 0.12),
                         (0.06, 0.06, 0.06), 6, 4), "white")
    fan = in_hand(g, -1, forward=0.15)                                       # éventail
    for k in range(5):
        a = -0.6 + k * 0.3
        b.make(pyramid(tuple(fan), tuple(fan + Vector((math.sin(a) * 0.5, -0.02, math.cos(a) * 0.5))), 0.12, 0.02), "accent")


def lifeguard_extras(b, g):
    short_hair(b, g, "hair")
    shades(b, g)
    nose_y = g["jaw_front"] - 0.02
    b.make(block((0, nose_y - 0.12, g["head_z"] - g["head_r"] * 0.1), (0.18, 0.08, 0.18)), "white")   # crème sur le nez
    b.make(ring((0, -0.02, g["top"] + 0.02), g["neck_r"] * 1.6, 0.03, 0.04, 8), "black")
    b.make(prism((0.1, -g["torso_d"] * 0.6, g["top"] - 0.55), (0.32, -g["torso_d"] * 0.6, g["top"] - 0.55), 0.08, 0.07, 8), "gold")
    buoy = in_hand(g, 1, forward=0.3)                                        # bouée rouge et blanche
    b.make(ring(tuple(buoy + Vector((0, 0, 0.1))), 0.42, 0.14, 0.16, 12), "accent")


def grocer_extras(b, g):
    b.make(block((0, -g["torso_d"] * 0.62, g["hip_z"] + 0.3), (g["hip_w"] * 1.1, 0.06, 1.6)), "accent2")   # tablier
    mustache(b, g, big=1.5)
    r, z, hy = g["head_r"], g["head_z"], g["hy"]
    b.make(ring((0, hy, z + r * 0.15), r * 0.9, 0.08, 0.2, 10), "hair")     # couronne de cheveux autour du crâne
    crate = (in_hand(g, 1) + in_hand(g, -1)) / 2 + Vector((0, -0.45, 0.25))  # cagette de fruits
    b.make(block(tuple(crate), (1.1, 0.6, 0.35)), "accent2")
    for k in range(4):
        b.make(lowsphere(tuple(crate + Vector((-0.36 + k * 0.24, 0, 0.25))), (0.13, 0.13, 0.13), 6, 4),
               "accent" if k % 2 else "gold")


def tourist_extras(b, g):
    r, z, hy = g["head_r"], g["head_z"], g["hy"]
    b.make(prism((0, hy, z + r * 0.45), (0, hy, z + r * 1.05), r * 0.92, r * 0.8, sides=10), "accent2")   # bob
    b.make(prism((0, hy, z + r * 0.45), (0, hy, z + r * 0.5), r * 1.35, r * 1.35, sides=10), "accent2")
    socks(b, g, "white")
    cam = Vector((0, -g["torso_d"] * 0.62, g["top"] - 0.7))                  # appareil photo autour du cou
    b.make(block(tuple(cam), (0.45, 0.25, 0.3)), "black")
    b.make(prism(tuple(cam + Vector((0, -0.1, 0))), tuple(cam + Vector((0, -0.28, 0))), 0.1, 0.1, 8), "white")
    m = (in_hand(g, 1) + in_hand(g, -1)) / 2 + Vector((0, -0.55, 0.45))      # carte dépliée, à l'envers
    b.make(block(tuple(m), (1.5, 0.04, 1.0)), "accent")


def vendor_clothes_extras(b, g):
    long_pants(b, g, "top")                                                 # tout en noir, très chic
    r, z, hy = g["head_r"], g["head_z"], g["hy"]
    short_hair(b, g)
    b.make(half_sphere((r * 0.15, hy, z + r * 0.6), (r * 0.95, r * 0.95, r * 0.35)), "accent")   # béret
    b.make(ring((0, -0.03, g["top"] - 0.05), g["neck_r"] * 2.2, 0.04, 0.12, 10), "gold")          # mètre ruban
    for s in (-1, 1):
        b.make(block((s * 0.42, -g["torso_d"] * 0.55, g["top"] - 0.6), (0.12, 0.04, 0.9)), "gold")
    e = g["eyes"]
    for s in (-1, 1):                                                       # lunettes rondes
        b.make(ring((e[s].x, e[s].y - 0.1, e[s].z), 0.16, 0.03, 0.05, 10), "black")


def vendor_barber_extras(b, g):
    r, z, hy = g["head_r"], g["head_z"], g["hy"]
    b.make(half_sphere((0, hy + 0.03, z + r * 0.15), (r * 0.88, r * 1.02, r * 0.92)), "hair")
    b.make(lowsphere((0, hy - r * 0.35, z + r * 1.1), (r * 0.6, r * 0.75, r * 0.6), 8, 6), "hair")   # banane parfaite
    mustache(b, g, big=1.3)
    for s, (cell, length) in zip((1, -1), (("gold", 0.5), ("black", 0.45))):        # ciseaux et peigne
        tool = in_hand(g, s, forward=0.1)
        b.make(prism(tuple(tool), tuple(tool + Vector((0, -0.1, length))), 0.05, 0.03, sides=4), cell)


def vendor_furniture_extras(b, g):
    long_pants(b, g, "shorts")
    r, z, hy = g["head_r"], g["head_z"], g["hy"]
    short_hair(b, g, "white")                                               # cheveux gris
    b.make(block((0, -g["torso_d"] * 0.62, g["top"] - 0.05), (0.35, 0.06, 0.16)), "accent")      # nœud papillon
    e = g["eyes"]
    b.make(block((0, min(e[-1].y, e[1].y) - 0.1, e[1].z), (abs(e[1].x - e[-1].x) + 0.4, 0.04, 0.05)), "black")
    lamp = in_hand(g, 1, forward=0.15)                                       # une lampe sous le bras
    b.make(prism(tuple(lamp + Vector((0, 0, -0.3))), tuple(lamp + Vector((0, 0, 0.6))), 0.04, 0.04, sides=6), "gold")
    b.make(prism(tuple(lamp + Vector((0, 0, 0.55))), tuple(lamp + Vector((0, 0, 0.95))), 0.38, 0.2, sides=8), "accent2")


def mentor_extras(b, g):
    r, z, hy = g["head_r"], g["head_z"], g["hy"]
    b.make(half_sphere((0, hy + 0.12, z + r * 0.05), (r * 1.1, r * 1.2, r * 1.15)), "top")      # capuche
    b.make(ring((0, hy, z + r * 0.4), r * 0.98, 0.08, 0.16, 10), "gold")                         # bandeau doré
    shades(b, g)
    beard(b, g, "white")                                                    # barbe blanche de vieux sage
    b.make(ring((0, -0.02, g["top"] + 0.02), g["neck_r"] * 1.6, 0.03, 0.04, 8), "black")
    b.make(prism((0.1, -g["torso_d"] * 0.62, g["top"] - 0.6), (0.34, -g["torso_d"] * 0.62, g["top"] - 0.6), 0.09, 0.08, 8),
           "gold")                                                          # sifflet en or
    long_pants(b, g, "top")


TOWNSFOLK = {
    "Mom": cfg(scale=0.95, top_color=(0.96, 0.62, 0.78), shoe=(0.98, 0.78, 0.86), hair=(0.45, 0.28, 0.15),
               accent=(0.35, 0.62, 0.22), accent2=(0.55, 0.78, 0.95), extras=mom_extras),
    "Courier": cfg(top_color=(0.55, 0.38, 0.2), shorts=(0.45, 0.3, 0.16), accent=(0.95, 0.75, 0.15),
                   accent2=(0.78, 0.6, 0.38), mouth="shout", extras=courier_extras),
    "Kid": cfg(scale=0.66, top="tank", top_color=(0.25, 0.42, 0.78), shorts=(0.25, 0.42, 0.78), accent=(0.88, 0.18, 0.18),
               accent2=(0.6, 0.42, 0.22), head_r=0.5, eye_r=0.18, extras=kid_extras),
    "Neighbor": cfg(top_color=(0.55, 0.75, 0.92), shorts=(0.78, 0.7, 0.5), shoe=(0.5, 0.33, 0.18), hair=(0.3, 0.22, 0.15),
                    mouth="smug", extras=neighbor_extras),
    "MrsDoRe": cfg(top_color=(0.55, 0.18, 0.62), shoe=(0.55, 0.18, 0.62), hair=(0.78, 0.2, 0.12), accent=(0.95, 0.85, 0.3),
                   mouth="shout", extras=doremi_extras),
    "Lifeguard": cfg(top="none", shorts=(0.88, 0.12, 0.12), skin=(0.9, 0.62, 0.42), pec=0.25, lat=0.15, delt=0.28,
                     bicep=0.22, chest_w=1.3, shoulder_w=1.6, accent=(0.9, 0.15, 0.15), mouth="shout",
                     hair=(0.95, 0.8, 0.4), extras=lifeguard_extras),
    "Grocer": cfg(top_color=(0.3, 0.55, 0.32), shorts=(0.3, 0.3, 0.35), hair=(0.3, 0.22, 0.15), accent=(0.85, 0.15, 0.12),
                  accent2=(0.95, 0.95, 0.93), extras=grocer_extras),
    "Tourist": cfg(skin=(1.0, 0.6, 0.52), top_color=(0.3, 0.75, 0.82), shorts=(0.82, 0.74, 0.55), shoe=(0.5, 0.33, 0.18),
                   accent=(0.95, 0.93, 0.85), accent2=(0.82, 0.74, 0.55), mouth="shout", extras=tourist_extras),
    "VendorClothes": cfg(top_color=(0.1, 0.1, 0.12), shorts=(0.1, 0.1, 0.12), shoe=(0.1, 0.1, 0.12), accent=(0.8, 0.15, 0.2),
                         mouth="smug", extras=vendor_clothes_extras),
    "VendorBarber": cfg(top_color=(0.95, 0.95, 0.93), shorts=(0.2, 0.2, 0.25), hair=(0.08, 0.07, 0.07), mouth="grin",
                        extras=vendor_barber_extras),
    "VendorFurniture": cfg(top_color=(0.82, 0.66, 0.3), shorts=(0.35, 0.3, 0.25), shoe=(0.4, 0.26, 0.14),
                           accent=(0.75, 0.12, 0.15), accent2=(0.96, 0.9, 0.75), extras=vendor_furniture_extras),
    "Mentor": cfg(scale=1.12, top="jacket", top_color=(0.24, 0.12, 0.38), shoe=(0.1, 0.1, 0.12), hair=(0.92, 0.92, 0.9), chest_w=1.5,
                  shoulder_w=1.9, delt=0.32, bicep=0.27, forearm=0.19, torso_d=0.75, mouth="smug", extras=mentor_extras),
}


# ------------------------------------------------------------------ fusion et export
def merge_character(name, builder):
    """Toutes les formes d'un personnage en un seul mesh, retourné en X (l'import de Roblox inverse gauche et droite)."""
    bm = bmesh.new()
    for o in list(builder.col.objects):
        bm.from_mesh(o.data)
    for v in bm.verts:
        v.co.x = -v.co.x
    bmesh.ops.reverse_faces(bm, faces=bm.faces)
    for o in list(builder.col.objects):
        m = o.data
        bpy.data.objects.remove(o, do_unlink=True)
        if m.users == 0:
            bpy.data.meshes.remove(m)
    me = bpy.data.meshes.get(name)
    if me:
        bpy.data.meshes.remove(me)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(builder.mat)
    for p in me.polygons:
        p.use_smooth = False
    obj = bpy.data.objects.new(name, me)
    builder.col.objects.link(obj)
    return obj


objs = []
for i, (name, c) in enumerate(TOWNSFOLK.items()):
    b = build_bro(name, c)
    obj = merge_character(name, b)
    obj.location.x = i * 3.5
    objs.append(obj)
    img = bpy.data.images.get(f"{name}_Atlas")
    img.filepath_raw = os.path.join(OUT, f"Npc_{name}.png")
    img.file_format = "PNG"
    img.save()
    print(f"{name}: {sum(len(p.vertices) - 2 for p in obj.data.polygons)} triangles")

for lc in bpy.context.view_layer.layer_collection.children:
    lc.hide_viewport = False
    lc.exclude = False
saved = {o: o.location.copy() for o in objs}
for o in bpy.context.view_layer.objects:
    o.select_set(False)
for o in objs:
    o.location = (0, 0, 0)
    o.hide_set(False)
    o.select_set(True)
bpy.context.view_layer.objects.active = objs[0]
fbx = os.path.join(OUT, "MogLife_Townsfolk.fbx")
bpy.ops.export_scene.fbx(
    filepath=fbx, use_selection=True, object_types={"MESH"},
    axis_forward="-Z", axis_up="Y", apply_unit_scale=True, apply_scale_options="FBX_SCALE_ALL",
    mesh_smooth_type="FACE", path_mode="RELATIVE", embed_textures=False,
)
for o, loc in saved.items():
    o.location = loc
print(f"{len(objs)} personnages exportés dans {fbx} ({os.path.getsize(fbx) // 1024} Ko)")

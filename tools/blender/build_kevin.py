"""
Construit Kevin (premier boss) dans Blender, style low poly PS1 (voir design/PROMPTS_PERSONNAGES.md, V4).
À exécuter dans Blender (via le MCP Blender, ou Script > Ouvrir > Exécuter).
Crée la collection « Kevin » (pièces éditables) et l'atlas de texture 128x128 « Kevin_Atlas ».
L'export se fait ensuite avec tools/blender/export_character.py.
"""
import bpy, bmesh, math, random
from mathutils import Vector

random.seed(7)

# ---------------------------------------------------------------- collection
col = bpy.data.collections.get("Kevin") or bpy.data.collections.new("Kevin")
if col.name not in bpy.context.scene.collection.children:
    bpy.context.scene.collection.children.link(col)
for o in list(col.objects):
    bpy.data.objects.remove(o, do_unlink=True)

# ---------------------------------------------------------------- atlas 128x128 (cases de 32 px)
S, C, PAD = 128, 32, 2
img = bpy.data.images.get("Kevin_Atlas") or bpy.data.images.new("Kevin_Atlas", S, S)
px = [0.0] * (S * S * 4)

def put(x, y, rgb):
    if 0 <= x < S and 0 <= y < S:
        i = (y * S + x) * 4
        px[i:i + 4] = [rgb[0], rgb[1], rgb[2], 1.0]

def noise(rgb, amt=0.04):
    n = random.uniform(-amt, amt)
    return tuple(max(0, min(1, c + n)) for c in rgb)

def fill_cell(cx, cy, fn):
    for y in range(C):
        for x in range(C):
            put(cx * C + x, cy * C + y, fn(x, y))

PALE = (0.8, 0.72, 0.62)
PJ = (0.55, 0.7, 0.85)
STRIPE = (0.35, 0.5, 0.72)
HAIR = (0.12, 0.09, 0.07)

fill_cell(0, 0, lambda x, y: noise(PALE))                       # peau

def face(x, y):                                                 # visage : barbe éparse, cernes
    c = noise(PALE)
    if y < 9 and random.random() < 0.18:
        c = (0.25, 0.2, 0.15)
    if 17 <= y <= 18 and (6 <= x <= 12 or 19 <= x <= 25):
        c = (0.55, 0.45, 0.45)
    return c
fill_cell(1, 0, face)
for (x, y) in [(5, 25), (26, 27), (14, 29), (22, 12), (8, 10), (27, 6), (16, 4)]:   # boutons
    for dx, dy in [(0, 0), (1, 0), (0, 1), (1, 1)]:
        put(C + x + dx, y + dy, (0.85, 0.2, 0.18))
    put(C + x, y + 1, (1, 0.9, 0.8))

fill_cell(2, 0, lambda x, y: noise(STRIPE if x % 6 < 2 else PJ, 0.03))   # pyjama rayé

def shirt_front(x, y):                                          # chemise ouverte, côtes, tache de sauce
    if abs(x - 16) < (y - 10) * 0.45 and y > 10:
        if y > 12 and y % 4 == 0 and abs(x - 16) > 1:
            return (0.62, 0.5, 0.42)
        return noise(PALE)
    if (x - 9) ** 2 + (y - 14) ** 2 < 9 or (x - 7) ** 2 + (y - 11) ** 2 < 4:
        return (0.7, 0.15, 0.1)
    return noise(STRIPE if x % 6 < 2 else PJ, 0.03)
fill_cell(3, 0, shirt_front)

fill_cell(0, 1, lambda x, y: noise(HAIR, 0.05))                 # cheveux gras
fill_cell(1, 1, lambda x, y: noise((0.55, 0.53, 0.5), 0.06))    # pantoufles
fill_cell(2, 1, lambda x, y: noise((0.08, 0.08, 0.09), 0.02))   # manette
fill_cell(3, 1, lambda x, y: noise((0.97, 0.96, 0.92), 0.02))   # blanc des yeux
fill_cell(0, 2, lambda x, y: (0.02, 0.02, 0.02))                # pupilles
fill_cell(1, 2, lambda x, y: (0.95, 0.93, 0.85) if (y > 20 and 8 < x < 23 and x != 16) else (0.3, 0.06, 0.06))  # bouche
fill_cell(2, 2, lambda x, y: noise(PALE) if not (14 <= x <= 16 and 14 <= y <= 16) else (0.55, 0.42, 0.36))  # ventre
fill_cell(3, 2, lambda x, y: [(0.9, 0.2, 0.2), (0.2, 0.8, 0.3), (0.2, 0.4, 0.9), (0.95, 0.85, 0.2)][(x // 8 + y // 8) % 4])
fill_cell(0, 3, lambda x, y: noise((0.4, 0.3, 0.18), 0.04))   # iris marron terne

img.pixels = px
img.pack()

mat = bpy.data.materials.get("Kevin_Mat") or bpy.data.materials.new("Kevin_Mat")
mat.use_nodes = True
nt = mat.node_tree
bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
bsdf.inputs["Roughness"].default_value = 1.0
tex = next((n for n in nt.nodes if n.type == "TEX_IMAGE"), None) or nt.nodes.new("ShaderNodeTexImage")
tex.image = img
tex.interpolation = "Closest"
nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])

# ---------------------------------------------------------------- géométrie
CELLS = {"skin": (0, 0), "face": (1, 0), "pj": (2, 0), "shirt": (3, 0), "hair": (0, 1), "slipper": (1, 1),
         "pad": (2, 1), "white": (3, 1), "black": (0, 2), "mouth": (1, 2), "belly": (2, 2), "buttons": (3, 2), "iris": (0, 3)}

def uv_project(bm, cell, front_cell=None):
    uv = bm.loops.layers.uv.verify()
    xs = [v.co.x for v in bm.verts]; ys = [v.co.y for v in bm.verts]; zs = [v.co.z for v in bm.verts]
    mn = Vector((min(xs), min(ys), min(zs)))
    size = Vector((max(xs), max(ys), max(zs))) - mn
    for f in bm.faces:
        n = f.normal
        cx, cy = CELLS[front_cell if (front_cell and n.y < -0.5) else cell]
        ax = max(range(3), key=lambda i: abs(n[i]))
        a, b = {0: (1, 2), 1: (0, 2), 2: (0, 1)}[ax]
        for l in f.loops:
            p = l.vert.co
            u = (p[a] - mn[a]) / (size[a] or 1)
            v = (p[b] - mn[b]) / (size[b] or 1)
            l[uv].uv = ((cx * C + PAD + u * (C - 2 * PAD)) / S, (cy * C + PAD + v * (C - 2 * PAD)) / S)

def make(name, bm, cell, front_cell=None):
    bm.normal_update()
    uv_project(bm, cell, front_cell)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    for p in me.polygons:
        p.use_smooth = False
    o = bpy.data.objects.new(name, me); col.objects.link(o)
    o.data.materials.append(mat)
    return o

def prism(p0, p1, r0, r1, sides=6):
    bm = bmesh.new()
    p0, p1 = Vector(p0), Vector(p1)
    axis = (p1 - p0).normalized()
    side = axis.cross(Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((1, 0, 0))).normalized()
    up = axis.cross(side)
    rings = []
    for p, r in ((p0, r0), (p1, r1)):
        rings.append([bm.verts.new(p + (side * math.cos(2 * math.pi * i / sides) + up * math.sin(2 * math.pi * i / sides)) * r)
                      for i in range(sides)])
    for i in range(sides):
        j = (i + 1) % sides
        bm.faces.new((rings[0][i], rings[0][j], rings[1][j], rings[1][i]))
    bm.faces.new(list(reversed(rings[0]))); bm.faces.new(rings[1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm

def lowsphere(center, radii, u=8, v=6):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=1.0)
    for vert in bm.verts:
        vert.co = Vector((vert.co.x * radii[0], vert.co.y * radii[1], vert.co.z * radii[2])) + Vector(center)
    return bm

def half_sphere(center, radii, u=8, v=6):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=1.0)
    bmesh.ops.delete(bm, geom=[vert for vert in bm.verts if vert.co.z < -0.01], context="VERTS")
    bmesh.ops.holes_fill(bm, edges=bm.edges, sides=0)
    for vert in bm.verts:
        vert.co = Vector((vert.co.x * radii[0], vert.co.y * radii[1], vert.co.z * radii[2])) + Vector(center)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm

def block(center, size, taper_top=1.0, lean_top=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for vert in bm.verts:
        top = vert.co.z > 0
        vert.co = Vector((vert.co.x * size[0] * (taper_top if top else 1),
                          vert.co.y * size[1] + (lean_top if top else 0),
                          vert.co.z * size[2])) + Vector(center)
    return bm

def pyramid(base_center, tip, half_w, half_h):
    bm = bmesh.new()
    c = Vector(base_center)
    vs = [bm.verts.new(c + Vector(d)) for d in ((-half_w, 0, -half_h), (half_w, 0, -half_h), (half_w, 0, half_h), (-half_w, 0, half_h))]
    t = bm.verts.new(Vector(tip))
    bm.faces.new(vs)
    for i in range(4):
        bm.faces.new((vs[i], vs[(i + 1) % 4], t))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm

for side, s in (("L", -1), ("R", 1)):
    make(f"Slipper{side}", block((0.33 * s, -0.15, 0.17), (0.55, 1.0, 0.34), taper_top=0.85), "slipper")
    make(f"Leg{side}", prism((0.3 * s, 0.0, 0.3), (0.27 * s, 0.05, 3.2), 0.21, 0.16), "pj")
    sh, el, wr = (0.42 * s, -0.22, 4.85), (0.66 * s, -0.28, 3.95), (0.84 * s, -0.34, 3.08)
    make(f"Sleeve{side}", prism(sh, el, 0.17, 0.15), "pj")
    make(f"Elbow{side}", lowsphere(el, (0.1, 0.1, 0.1), 6, 4), "skin")
    make(f"Forearm{side}", prism(el, wr, 0.075, 0.065, sides=5), "skin")
    make(f"Hand{side}", block((0.88 * s, -0.36, 2.88), (0.18, 0.13, 0.34)), "skin")
    make(f"Ear{side}", block((0.4 * s, -0.66, 6.05), (0.07, 0.2, 0.28)), "skin")
    # Gros yeux exorbités mais humains (iris coloré, paupières lourdes), comme les autres boss
    make(f"Eye{side}", lowsphere((0.17 * s, -1.0, 6.2), (0.18, 0.16, 0.19)), "white")
    make(f"Lid{side}", half_sphere((0.17 * s, -1.0, 6.25), (0.195, 0.175, 0.2)), "skin")

make("IrisL", lowsphere((-0.19, -1.14, 6.15), (0.085, 0.03, 0.085), 8, 4), "iris")
make("IrisR", lowsphere((0.2, -1.14, 6.12), (0.085, 0.03, 0.085), 8, 4), "iris")
make("PupilL", lowsphere((-0.19, -1.165, 6.15), (0.04, 0.02, 0.04), 6, 4), "black")
make("PupilR", lowsphere((0.2, -1.165, 6.12), (0.04, 0.02, 0.04), 6, 4), "black")
make("Hips", block((0, 0.05, 3.3), (0.85, 0.5, 0.45)), "pj")
make("Torso", block((0, 0.0, 4.2), (0.82, 0.42, 1.55), taper_top=0.82, lean_top=-0.3), "pj", front_cell="shirt")
make("Belly", lowsphere((0, -0.22, 3.62), (0.3, 0.22, 0.28)), "belly")
make("Neck", prism((0, -0.22, 4.92), (0, -0.58, 5.55), 0.11, 0.1), "skin")
make("Head", lowsphere((0, -0.66, 6.05), (0.36, 0.38, 0.62)), "skin", front_cell="face")
make("Nose", pyramid((0, -0.96, 6.02), (0, -1.55, 5.88), 0.14, 0.17), "skin")
make("Mouth", block((0, -1.0, 5.72), (0.24, 0.06, 0.13)), "mouth")
make("HairCap", lowsphere((0, -0.6, 6.42), (0.39, 0.41, 0.3), 8, 4), "hair")
strands = [
    ((-0.22, -0.82, 6.62), (-0.3, -1.02, 6.32)), ((-0.07, -0.88, 6.66), (-0.1, -1.08, 6.36)),
    ((0.08, -0.88, 6.66), (0.14, -1.07, 6.4)), ((0.22, -0.8, 6.62), (0.32, -1.0, 6.36)),
    ((-0.36, -0.6, 6.5), (-0.44, -0.62, 6.05)), ((0.36, -0.6, 6.5), (0.44, -0.6, 6.08)),
    ((0.0, -0.3, 6.55), (0.0, -0.12, 6.1)),
]
for i, (base, tip) in enumerate(strands):
    make(f"HairStrand{i}", pyramid(base, tip, 0.1, 0.05), "hair")
make("Controller", block((0.95, -0.48, 2.9), (0.46, 0.17, 0.22)), "pad")
make("ControllerButtons", block((1.05, -0.58, 2.95), (0.12, 0.04, 0.09)), "buttons")

print("Kevin:", len(col.objects), "pièces,", sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in col.objects), "triangles")

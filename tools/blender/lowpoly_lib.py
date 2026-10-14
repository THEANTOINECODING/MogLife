"""
Bibliothèque commune des personnages low poly PS1 de MOG LIFE (à charger avec exec dans Blender).
- Atlas de texture 128x128 en cases de 32 px, filtrage « Closest » (pixels nets).
- Formes low poly à facettes (prismes, sphères basses, blocs, pyramides) avec projection UV par case.
Convention : Z vers le haut, l'avant du personnage vers -Y, 1 unité = 1 stud, pieds à z = 0.
Les sommets sont en coordonnées monde (transformation identité) : export_character.py fusionne les meshes.
"""
import bpy, bmesh, math, random
from mathutils import Vector

S, C, PAD = 128, 32, 2


# ------------------------------------------------------------------ atlas
class Atlas:
    def __init__(self, name):
        self.name = name
        self.px = [0.0] * (S * S * 4)
        self.cells = {}

    def put(self, x, y, rgb):
        if 0 <= x < S and 0 <= y < S:
            i = (y * S + x) * 4
            self.px[i:i + 4] = [rgb[0], rgb[1], rgb[2], 1.0]

    def cell(self, key, cx, cy, fn):
        """Peint la case (cx, cy) avec fn(x, y) -> rgb, et l'enregistre sous `key`."""
        self.cells[key] = (cx, cy)
        for y in range(C):
            for x in range(C):
                self.put(cx * C + x, cy * C + y, fn(x, y))

    def material(self):
        img = bpy.data.images.get(f"{self.name}_Atlas") or bpy.data.images.new(f"{self.name}_Atlas", S, S)
        img.pixels = self.px
        img.pack()
        mat = bpy.data.materials.get(f"{self.name}_Mat") or bpy.data.materials.new(f"{self.name}_Mat")
        mat.use_nodes = True
        nt = mat.node_tree
        bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs["Roughness"].default_value = 1.0
        tex = next((n for n in nt.nodes if n.type == "TEX_IMAGE"), None) or nt.nodes.new("ShaderNodeTexImage")
        tex.image = img
        tex.interpolation = "Closest"
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        return mat


def noise(rgb, amt=0.04):
    n = random.uniform(-amt, amt)
    return tuple(max(0.0, min(1.0, c + n)) for c in rgb)


def darker(rgb, k=0.75):
    return tuple(c * k for c in rgb)


# ------------------------------------------------------------------ construction
class Builder:
    """Construit les pièces d'un personnage dans une collection, avec une échelle globale `scale`."""

    def __init__(self, name, atlas, scale=1.0):
        self.col = bpy.data.collections.get(name) or bpy.data.collections.new(name)
        if self.col.name not in bpy.context.scene.collection.children:
            bpy.context.scene.collection.children.link(self.col)
        for o in list(self.col.objects):
            bpy.data.objects.remove(o, do_unlink=True)
        self.atlas = atlas
        self.mat = atlas.material()
        self.scale = scale
        self.count = 0

    def _uv(self, bm, cell, front_cell=None):
        uv = bm.loops.layers.uv.verify()
        xs = [v.co.x for v in bm.verts]; ys = [v.co.y for v in bm.verts]; zs = [v.co.z for v in bm.verts]
        mn = Vector((min(xs), min(ys), min(zs)))
        size = Vector((max(xs), max(ys), max(zs))) - mn
        for f in bm.faces:
            n = f.normal
            key = front_cell if (front_cell and n.y < -0.5) else cell
            cx, cy = self.atlas.cells[key]
            ax = max(range(3), key=lambda i: abs(n[i]))
            a, b = {0: (1, 2), 1: (0, 2), 2: (0, 1)}[ax]
            for l in f.loops:
                p = l.vert.co
                u = (p[a] - mn[a]) / (size[a] or 1)
                v = (p[b] - mn[b]) / (size[b] or 1)
                l[uv].uv = ((cx * C + PAD + u * (C - 2 * PAD)) / S, (cy * C + PAD + v * (C - 2 * PAD)) / S)

    def make(self, bm, cell, front_cell=None):
        for v in bm.verts:
            v.co *= self.scale
        bm.normal_update()
        self._uv(bm, cell, front_cell)
        self.count += 1
        me = bpy.data.meshes.new(f"{self.col.name}_{self.count}")
        bm.to_mesh(me); bm.free()
        for p in me.polygons:
            p.use_smooth = False
        o = bpy.data.objects.new(me.name, me)
        self.col.objects.link(o)
        o.data.materials.append(self.mat)
        return o

    def tris(self):
        return sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in self.col.objects)


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


def block(center, size, taper_top=1.0, lean_top=0.0, taper_depth=1.0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for vert in bm.verts:
        top = vert.co.z > 0
        vert.co = Vector((vert.co.x * size[0] * (taper_top if top else 1),
                          vert.co.y * size[1] * (taper_depth if top else 1) + (lean_top if top else 0),
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


def ring(center, radius, thickness, height, sides=8):
    """Anneau horizontal (chaîne, couronne, ceinture) : prisme creux à facettes."""
    bm = bmesh.new()
    c = Vector(center)
    loops = []
    for r, z in ((radius, -height / 2), (radius, height / 2), (radius - thickness, height / 2), (radius - thickness, -height / 2)):
        loops.append([bm.verts.new(c + Vector((math.cos(2 * math.pi * i / sides) * r, math.sin(2 * math.pi * i / sides) * r, z)))
                      for i in range(sides)])
    for k in range(4):
        a, b = loops[k], loops[(k + 1) % 4]
        for i in range(sides):
            j = (i + 1) % sides
            bm.faces.new((a[i], a[j], b[j], b[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm

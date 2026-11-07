"""
Faces superposées dans les modèles (D121) : deux surfaces au même endroit, dans le même sens, que Roblox dessine tour à
tour quand la caméra bouge (« double texture » : enseignes des magasins, sol des gradins du Colisée...).

- coplanar_pairs(obj) : paires d'îlots (morceaux de maillage non reliés) d'un même objet dont deux faces sont dans le
  même plan, dans le même sens, et se recouvrent vraiment.
- separate_coplanar(objs) : pour chaque paire, le plus petit îlot grossit très légèrement autour de son centre, juste
  assez pour que sa face passe 0,03 stud devant l'autre (même règle que tools/build_map.py pour les blocs).
  Les faces tournées vers le bas au ras du sol (z ≈ 0, jamais vues) sont ignorées.
Exécuté par les scripts d'export (export_colosseum.py, export_buildings.py, export_props.py) avant d'écrire le FBX.
"""
import bmesh
from mathutils import Vector

GAP = 0.03          # écart voulu entre les deux faces (studs)
TOL = 0.003         # deux plans à moins de TOL sont « le même plan »
MIN_AREA = 0.01


def _islands(bm):
    island = {}
    k = 0
    for f in bm.faces:
        if f.index in island:
            continue
        stack = [f]
        island[f.index] = k
        while stack:
            g = stack.pop()
            for e in g.edges:
                for h in e.link_faces:
                    if h.index not in island:
                        island[h.index] = k
                        stack.append(h)
        k += 1
    return island, k


def _inside(p, poly, n):
    ax = max(range(3), key=lambda i: abs(n[i]))
    i, j = [a for a in range(3) if a != ax]
    x, y = p[i], p[j]
    inside = False
    m = len(poly)
    for a in range(m):
        x1, y1 = poly[a][i], poly[a][j]
        x2, y2 = poly[(a + 1) % m][i], poly[(a + 1) % m][j]
        if (y1 > y) != (y2 > y):
            if x1 + (y - y1) * (x2 - x1) / (y2 - y1) > x:
                inside = not inside
    return inside


def coplanar_pairs(bm, floor=0.0):
    """[(îlot de la face recouverte, îlot qui la recouvre, normale, point du plan)] dans un bmesh."""
    bm.faces.ensure_lookup_table()
    island, _ = _islands(bm)
    groups = {}
    faces = []
    for f in bm.faces:
        if f.calc_area() < MIN_AREA:
            continue
        n = f.normal.copy()
        vs = [v.co.copy() for v in f.verts]
        c = f.calc_center_median()
        if n.z < -0.9 and c.z < floor + 0.05:
            continue
        rec = (island[f.index], n, vs, c)
        faces.append(rec)
        key = (round(n.x, 2), round(n.y, 2), round(n.z, 2), round(n.dot(vs[0]) / TOL))
        groups.setdefault(key, []).append(rec)
    pairs = []
    for key, recs in groups.items():
        cand = recs + groups.get((key[0], key[1], key[2], key[3] + 1), [])
        for a in recs:
            pts = [a[3]] + [a[3].lerp(v, 0.7) for v in a[2]]
            for b in cand:
                if b[0] == a[0] or a[1].dot(b[1]) < 0.999 or abs(a[1].dot(a[2][0]) - b[1].dot(b[2][0])) > TOL:
                    continue
                if sum(_inside(p, b[2], b[1]) for p in pts) >= 2:
                    pairs.append((a[0], b[0], a[1], a[3]))
                    break
    return pairs


def separate_coplanar(objs, floor=0.0, passes=8):
    """Sépare les faces superposées de chaque objet ; renvoie le nombre de corrections."""
    fixed = 0
    for obj in objs:
        # La boîte englobante de l'objet ne bouge pas (le jeu pose chaque modèle d'après elle) : un îlot qui grossit
        # reste dedans
        xs = [v.co for v in obj.data.vertices]
        if not xs:
            continue
        box_lo = Vector((min(c.x for c in xs), min(c.y for c in xs), min(c.z for c in xs)))
        box_hi = Vector((max(c.x for c in xs), max(c.y for c in xs), max(c.z for c in xs)))
        for _ in range(passes):
            bm = bmesh.new()
            bm.from_mesh(obj.data)
            bm.faces.ensure_lookup_table()
            pairs = coplanar_pairs(bm, floor)
            if not pairs:
                bm.free()
                break
            island, count = _islands(bm)
            members = [[] for _ in range(count)]
            for f in bm.faces:
                members[island[f.index]].append(f)
            boxes = []
            for fs in members:
                vs = {v for f in fs for v in f.verts}
                lo = Vector((min(v.co.x for v in vs), min(v.co.y for v in vs), min(v.co.z for v in vs)))
                hi = Vector((max(v.co.x for v in vs), max(v.co.y for v in vs), max(v.co.z for v in vs)))
                boxes.append((lo, hi, vs))
            grow = {}
            for a, b, n, point in pairs:
                size_a = (boxes[a][1] - boxes[a][0]).length
                size_b = (boxes[b][1] - boxes[b][0]).length
                small = a if size_a <= size_b else b
                center = (boxes[small][0] + boxes[small][1]) / 2
                h = max(abs((point - center).dot(n)), 0.05)
                grow[small] = max(grow.get(small, 1.0), min(1.0 + GAP / h, 1.25))
            for isl, s in grow.items():
                lo, hi, vs = boxes[isl]
                center = (lo + hi) / 2
                for v in vs:
                    c = center + (v.co - center) * s
                    v.co = Vector(tuple(min(max(c[i], box_lo[i]), box_hi[i]) for i in range(3)))
            fixed += len(grow)
            bm.to_mesh(obj.data)
            bm.free()
    return fixed

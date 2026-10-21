"""Vérifie dans Blender le lot de garde-robe exporté par build_style.py.

Usage : blender -b assets/blender/wardrobe.blend --python tools/blender/validate_style.py
"""

import bpy
import bmesh
import os
import math
from collections import Counter
from mathutils import Vector
from mathutils.bvhtree import BVHTree


STAGES = ("Normie", "GymRat", "Bro", "Alpha", "Chad", "Gigachad", "GodMogger")
BODY_KEYS = tuple(key for stage in STAGES for key in (stage, stage + "F"))
TOPS = ("TightTank", "MogTank", "Hawaiian", "TrackJacket", "BoxerRobe", "PajamaTop")
ROOT = r"C:\Users\antoi\Documents\MogLife"
namespace = {}
exec(compile(open(os.path.join(ROOT, "tools", "blender", "outfit_looks.py"), encoding="utf-8").read(),
             "outfit_looks.py", "exec"), namespace)
LOOKS = namespace["LOOKS"]
TOPS += tuple(name + "Top" for name, *_ in LOOKS)


def bounds(obj):
    return tuple((min(v.co[i] for v in obj.data.vertices), max(v.co[i] for v in obj.data.vertices)) for i in range(3))


def tree(obj, extra=0):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    if extra:
        box = bounds(obj)
        center = Vector(tuple((lo + hi) * 0.5 for lo, hi in box))
        pump = Vector((1 + extra, 1 + extra, 1 + extra * 0.25))
        for vertex in bm.verts:
            vertex.co = center + (vertex.co - center) * pump
    result = BVHTree.FromBMesh(bm)
    bm.free()
    return result


def common_dimensions(obj, scale, extra):
    box = bounds(obj)
    center = Vector(tuple((lo + hi) * 0.5 for lo, hi in box))
    size = Vector(tuple(hi - lo for lo, hi in box))
    pump = Vector((1 + extra, 1 + extra, 1 + extra * 0.25))
    return center * scale, size * scale * pump


def common_tree(obj, scale, extra):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    box = bounds(obj)
    center = Vector(tuple((lo + hi) * 0.5 for lo, hi in box))
    pump = Vector((1 + extra, 1 + extra, 1 + extra * 0.25))
    for vertex in bm.verts:
        vertex.co = center * scale + (vertex.co - center) * scale * pump
    result = BVHTree.FromBMesh(bm)
    bm.free()
    return result


def surface(trees, center, z, angle):
    dx, dy = math.cos(angle), math.sin(angle)
    origin = Vector((center[0] + 8 * dx, center[1] + 8 * dy, z))
    direction = Vector((-dx, -dy, 0))
    hits = [hit[3] for item in trees if (hit := item.ray_cast(origin, direction, 12))[0] is not None]
    return 8 - min(hits) if hits else None


expected_items = None
expected_parts = None
total = 0
coverage_failures = []
for body in BODY_KEYS:
    stage = body[:-1] if body.endswith("F") else body
    next_body = (STAGES[STAGES.index(stage) + 1] + ("F" if body.endswith("F") else "")) if stage != STAGES[-1] else None
    col = bpy.data.collections["Style_" + body]
    pieces = list(col.objects)
    items = {obj.name.split("__")[1] for obj in pieces}
    if expected_items is None:
        expected_items = items
        expected_parts = {item: {obj.name.split("__")[2] for obj in pieces
                                 if obj.name.split("__")[1] == item} for item in items}
    assert items == expected_items, f"Articles manquants sur {body}: {expected_items - items}"
    assert {item: {obj.name.split("__")[2] for obj in pieces
                   if obj.name.split("__")[1] == item} for item in items} == expected_parts, (
        f"{body}: parties de vêtement incompatibles avec la croissance vers le stade suivant"
    )
    assert len(items) == 74, f"{body}: {len(items)} articles au lieu de 74"
    assert len(pieces) == 237, f"{body}: {len(pieces)} pièces au lieu de 237"
    for name, *_ in LOOKS:
        assert name + "Top" in items and name + "Bottom" in items, f"{body}: ensemble {name} incomplet"
    tris_by_item = {item: 0 for item in items}
    for obj in pieces:
        mesh = obj.data
        assert obj.type == "MESH" and mesh.uv_layers and mesh.materials, obj.name
        assert all(hi - lo > 0.005 for lo, hi in bounds(obj)), obj.name
        tris_by_item[obj.name.split("__")[1]] += sum(len(poly.vertices) - 2 for poly in mesh.polygons)
        bm = bmesh.new()
        bm.from_mesh(mesh)
        bad_edges = sum(not edge.is_manifold for edge in bm.edges)
        bm.free()
        assert bad_edges == 0, f"{obj.name}: {bad_edges} arêtes ouvertes"
    assert max(tris_by_item.values()) < 10000, f"{body}: article trop détaillé"
    body_col = bpy.data.collections["Body_" + body]
    body_trees = {}
    coverage_samples = 0
    for name, *_ in LOOKS:
        for item in (name + "Top", name + "Bottom"):
            for obj in (piece for piece in pieces if piece.name.split("__")[1] == item):
                part = obj.name.split("__")[2]
                sources = [source for source in body_col.objects
                           if source.type == "MESH" and
                           (source.name == body + "_" + part or source.name.startswith(body + "_" + part + "_"))]
                box = bounds(obj)
                reference = next((source for source in sources if source.name == body + "_" + part), sources[0])
                reference_box = bounds(reference)
                center = ((reference_box[0][0] + reference_box[0][1]) * 0.5,
                          (reference_box[1][0] + reference_box[1][1]) * 0.5)
                kind = part.removeprefix("Left").removeprefix("Right")
                weight = {"UpperTorso": 1, "LowerTorso": 0.4, "UpperArm": 1,
                          "LowerArm": 0.8, "UpperLeg": 0.7, "LowerLeg": 0.6}.get(kind, 0)
                for extra in (0, 0.42 * weight):
                    key = (part, extra)
                    if key not in body_trees:
                        body_trees[key] = [tree(source, extra) for source in sources]
                    fabric = tree(obj, extra)
                    middle_z = (box[2][0] + box[2][1]) * 0.5
                    for fraction in (0.22, 0.5, 0.78):
                        z = middle_z + (box[2][0] + (box[2][1] - box[2][0]) * fraction - middle_z) * (1 + extra * 0.25)
                        for direction in range(16):
                            angle = 2 * math.pi * (direction + 0.37) / 16
                            skin = surface(body_trees[key], center, z, angle)
                            if skin is None:
                                continue
                            cloth = surface((fabric,), center, z, angle)
                            if cloth is None or cloth < skin - 0.04:
                                coverage_failures.append((obj.name, part, round(z, 2), direction,
                                                          round(skin, 3), round(cloth, 3) if cloth else None, extra))
                                continue
                            coverage_samples += 1
                if next_body:
                    next_garment = bpy.data.objects.get(next_body + obj.name[len(body):])
                    skin_source = bpy.data.objects.get(body + "_" + part)
                    next_skin = bpy.data.objects.get(next_body + "_" + part)
                    assert next_garment, f"Missing growth twin for {obj.name}"
                    if not skin_source or not next_skin:
                        continue
                    skin_box = bounds(skin_source)
                    next_box = bounds(next_skin)
                    for progress in (0.25, 0.5, 0.75):
                        extra = 0.2 * weight
                        ratio = Vector(tuple((next_box[i][1] - next_box[i][0]) /
                                             (skin_box[i][1] - skin_box[i][0]) for i in range(3)))
                        scale = Vector((1, 1, 1)).lerp(ratio, progress)
                        cloth_center, cloth_size = common_dimensions(obj, scale, extra)
                        skin_center, skin_size = common_dimensions(skin_source, scale, extra)
                        z_low = max(cloth_center.z - cloth_size.z * 0.5,
                                    skin_center.z - skin_size.z * 0.5)
                        z_high = min(cloth_center.z + cloth_size.z * 0.5,
                                     skin_center.z + skin_size.z * 0.5)
                        if z_high <= z_low:
                            continue
                        grown_skin = common_tree(skin_source, scale, extra)
                        grown_cloth = common_tree(obj, scale, extra)
                        for fraction in (0.3, 0.7):
                            z = z_low + (z_high - z_low) * fraction
                            for direction in range(16):
                                angle = 2 * math.pi * (direction + 0.37) / 16
                                skin = surface((grown_skin,), skin_center, z, angle)
                                if skin is None:
                                    continue
                                cloth = surface((grown_cloth,), skin_center, z, angle)
                                if cloth is None or cloth < skin - 0.04:
                                    coverage_failures.append((obj.name, part, round(z, 2), direction,
                                                              round(skin, 3), round(cloth, 3) if cloth else None,
                                                              (progress, extra)))
                                    continue
                                coverage_samples += 1
    print(f"{body}: {coverage_samples} clothing coverage samples checked")
    if body.endswith("F"):
        base = bpy.data.objects[body + "_UpperTorso_Top"]
        base_front = bounds(base)[1][0]
        for top in TOPS:
            garment = bpy.data.objects[f"{body}__{top}__UpperTorso"]
            garment_front = bounds(garment)[1][0]
            assert garment_front < base_front - 0.01, (
                f"{body}/{top}: poitrine de base devant le tissu ({base_front:.3f} / {garment_front:.3f})"
            )
    total += len(pieces)
    print(f"{body}: {len(items)} articles, {len(pieces)} pièces, {max(tris_by_item.values())} triangles max/article")

atlas = bpy.data.images["Style_Atlas"]
assert tuple(atlas.size) == (512, 512) and atlas.channels == 4
assert total == 3318
print(f"Clothing coverage failures: {len(coverage_failures)}")
if coverage_failures:
    print("Failure groups:", Counter((failure[0].split("__")[0], failure[1]) for failure in coverage_failures))
    for group in sorted({(failure[0].split("__")[0], failure[1]) for failure in coverage_failures}):
        subset = [failure for failure in coverage_failures if (failure[0].split("__")[0], failure[1]) == group]
        finite = [failure[4] - failure[5] for failure in subset if failure[5] is not None]
        print("Failure extent:", group, "count", len(subset), "missing", len(subset) - len(finite),
              "max penetration", round(max(finite), 3) if finite else None)
    for failure in sorted(coverage_failures, key=lambda value: value[4] - (value[5] or -10), reverse=True)[:30]:
        print(failure)
assert not coverage_failures, "Clothing does not fully cover the body in the samples above"
print(f"Garde-robe validée : {len(BODY_KEYS)} corps, {len(expected_items)} articles, {total} pièces, atlas RGBA 512²")

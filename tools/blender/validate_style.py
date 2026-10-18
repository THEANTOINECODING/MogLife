"""Vérifie dans Blender le lot de garde-robe exporté par build_style.py.

Usage : blender -b assets/blender/wardrobe.blend --python tools/blender/validate_style.py
"""

import bpy
import bmesh
import os


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


expected_items = None
expected_parts = None
total = 0
for body in BODY_KEYS:
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
print(f"Garde-robe validée : {len(BODY_KEYS)} corps, {len(expected_items)} articles, {total} pièces, atlas RGBA 512²")

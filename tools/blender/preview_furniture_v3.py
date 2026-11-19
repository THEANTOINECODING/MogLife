"""
Aperçu des meubles v3 dans Blender (sans export) : construit les 21 meubles dans la collection « FurnV3 » et donne à
chaque pièce une matière d'aperçu de la couleur de son look (néon émissif, verre transparent, métaux brillants).
Dans Blender : exec(open(r"...\tools\blender\preview_furniture_v3.py", encoding="utf-8").read())
"""
import bpy, os

D = r"C:\Users\antoi\Documents\MogLife\tools\blender"
ns = {}
exec(open(os.path.join(D, "props_lib.py"), encoding="utf-8").read(), ns)
for m in ["props_home.py", "props_furniture_v2.py", "props_furniture_v3.py"]:
    exec(open(os.path.join(D, m), encoding="utf-8").read(), ns)
pal = ns["build_palette"]()
P = ns["Props"](pal, "FurnV3", spacing=10, columns=7)
P.clear()
ns["furniture_v3"](P)


def _lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def look_material(material, hexc):
    name = f"V3_{material}_{hexc}"
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    col = tuple(_lin(int(hexc[i:i + 2], 16) / 255) for i in (0, 2, 4)) + (1.0,)
    b.inputs["Base Color"].default_value = col
    b.inputs["Roughness"].default_value = {"Fabric": 0.9, "Carpet": 0.95, "Leather": 0.45, "Wood": 0.6,
                                           "WoodPlanks": 0.7, "Foil": 0.25, "Metal": 0.3, "Marble": 0.2,
                                           "Glass": 0.05, "Cardboard": 0.9, "Rubber": 0.8}.get(material, 0.4)
    if material in ("Foil", "Metal"):
        b.inputs["Metallic"].default_value = 1.0
    if material == "Neon":
        b.inputs["Emission Color"].default_value = col
        b.inputs["Emission Strength"].default_value = 4.0
    if material == "Glass":
        b.inputs["Alpha"].default_value = 0.4
        m.surface_render_method = "BLENDED"
    m.diffuse_color = col
    return m


for o in P.col.objects:
    suffix = o.name.split("__")[-1]
    if suffix != "Tex":
        material, hexc = suffix.split("_")
        o.data.materials.clear()
        o.data.materials.append(look_material(material, hexc))
for line in P.report:
    print(line)

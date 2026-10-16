"""
Aperçu des teintes dans Blender (D55) : les zones teintables des textures sont semi-transparentes et ne prennent
leur couleur que dans Roblox (MeshPart.Color). Pour juger le rendu dans Blender, preview_tints(objets, couleurs)
donne à chaque pièce un matériau d'aperçu qui pose la texture sur la couleur de son groupe (comme Roblox).
restore_tints(objets) remet le matériau d'origine AVANT l'export (l'export FBX ne doit voir que la texture) ;
les scripts de construction recréent de toute façon les pièces à chaque lancement.
À charger avec exec ; aucun effet sur les fichiers exportés.
"""
import bpy

PREVIEW = {
    "Skin": (0.93, 0.72, 0.56),
    "Hair": (0.3, 0.18, 0.08),
    "Eyes": (0.25, 0.45, 0.75),
    "Top": (0.86, 0.22, 0.22),
    "Shorts": (0.15, 0.25, 0.6),
}


def tint_of(name):
    """Groupe de teinte d'une pièce d'après son nom (mêmes règles que src/shared/Look.luau)."""
    name = name.split(".")[0]                         # copies d'aperçu : « Nom.001 »
    if "__" in name:                                  # objet de style : <Corps>__<Objet>__<Partie>[_<Teinte>]
        key = name.split("__")[2]
        group = key.split("_")[1] if "_" in key else ""
        return group if group in PREVIEW else None
    key = name.split("_", 1)[1]                       # pièce de corps : <Corps>_<Partie>[_<Groupe>]
    group = key.split("_")[1] if "_" in key else ""
    if group == "":
        return "Skin"
    if group.startswith("Mouth"):
        return "Skin"
    if group.startswith("Brow") or group == "Hair":
        return "Hair"
    return group if group in PREVIEW else None


def _preview_material(base, tint, rgb):
    name = f"{base.name}__Preview{tint}"
    mat = bpy.data.materials.get(name)
    if mat:
        return mat
    mat = base.copy()
    mat.name = name
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tex = next(n for n in nt.nodes if n.type == "TEX_IMAGE")
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.inputs[6].default_value = (*rgb, 1.0)        # A : couleur de la pièce
    nt.links.new(tex.outputs["Alpha"], mix.inputs[0])
    nt.links.new(tex.outputs["Color"], mix.inputs[7])  # B : texture, selon son alpha
    nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
    return mat


def preview_tints(objs, colors=None):
    """Le matériau d'aperçu est posé sur l'OBJET (lien « OBJECT »), jamais sur le maillage : les copies
    d'aperçu partagent leur maillage avec les vraies pièces, qui doivent garder leur matériau pour l'export."""
    colors = dict(PREVIEW, **(colors or {}))
    for o in objs:
        if o.type != "MESH" or not o.data.materials or o.data.materials[0] is None:
            continue
        base = o.data.materials[0]
        tint = tint_of(o.name)
        slot = o.material_slots[0]
        slot.link = "OBJECT"
        slot.material = _preview_material(base, tint, colors[tint]) if tint else base


def restore_tints(objs):
    for o in objs:
        if o.type == "MESH" and o.material_slots:
            o.material_slots[0].link = "DATA"

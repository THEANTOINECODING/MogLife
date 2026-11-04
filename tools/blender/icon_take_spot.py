"""
Icône du produit développeur « Take the Spot » (D110) : un bro musclé, hilare, a pris le banc ; le bro spaghetti
qui l'occupait s'envole en tournoyant, des étoiles autour de la tête. Aucun texte dans l'image (règle du projet).
Réutilise les personnages ronds du prototype Bro v2 (proto_body_v2.py).

blender -b --factory-startup --python tools/blender/icon_take_spot.py
  MOG_OUT=fichier png (par défaut assets/concepts/icon_take_spot.png), MOG_SIZE=1024
"""
import bpy, math, os
from mathutils import Vector, Euler

HERE = os.path.dirname(os.path.abspath(__file__))
proto = {"__name__": "proto_body_v2", "__file__": os.path.join(HERE, "proto_body_v2.py")}
exec(open(proto["__file__"], encoding="utf-8").read(), proto)
build, material, COLORS = proto["build"], proto["material"], proto["COLORS"]

for o in list(bpy.data.objects):
    bpy.data.objects.remove(o)
scene = bpy.context.scene

COLORS.update({
    "Pad": (0.85, 0.12, 0.15),
    "Steel": (0.35, 0.36, 0.42),
    "Gold": (1.0, 0.72, 0.12),
    "Puff": (0.97, 0.97, 1.0),
    "Star": (1.0, 0.86, 0.2),
    "Floor": (0.36, 0.3, 0.55),
    "Shorts2": (0.95, 0.45, 0.1),
})


def box(name, size, loc, mat, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    bev = o.modifiers.new("Bevel", "BEVEL")
    bev.width = min(size) * 0.18
    bev.segments = 3
    o.data.materials.append(material(mat))
    return o


def cyl(name, r, depth, loc, mat, rot=(0, 0, 0), verts=20):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=depth, location=loc, rotation=rot, vertices=verts)
    o = bpy.context.object
    o.name = name
    o.data.materials.append(material(mat))
    bpy.ops.object.shade_smooth()
    return o


def star(name, loc, r, mat="Star", rot=(0, 0, 0)):
    """Étoile à 5 branches, épaisse (low-poly)."""
    verts, faces = [], []
    for k in range(10):
        a = math.pi / 2 + k * math.pi / 5
        rr = r if k % 2 == 0 else r * 0.45
        for z in (-r * 0.18, r * 0.18):
            verts.append((math.cos(a) * rr, z, math.sin(a) * rr))
    verts += [(0, -r * 0.3, 0), (0, r * 0.3, 0)]
    c0, c1 = 20, 21
    for k in range(10):
        a0, a1 = 2 * k, 2 * ((k + 1) % 10)
        faces.append((c0, a0, a1))
        faces.append((c1, a1 + 1, a0 + 1))
        faces.append((a0, a0 + 1, a1 + 1, a1))
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.materials.append(material(mat))
    o = bpy.data.objects.new(name, me)
    o.location = loc
    o.rotation_euler = rot
    scene.collection.objects.link(o)
    return o


def ball(name, loc, r, mat):
    bpy.ops.mesh.primitive_ico_sphere_add(radius=r, subdivisions=2, location=loc)
    o = bpy.context.object
    o.name = name
    o.data.materials.append(material(mat))
    bpy.ops.object.shade_smooth()
    return o


def group(name, objs, loc, rot):
    e = bpy.data.objects.new(name, None)
    scene.collection.objects.link(e)
    for o in objs:
        o.parent = e
    e.location = loc
    e.rotation_euler = rot
    return e


# --- sol : estrade ronde de salle de sport
floor = cyl("Floor", 4.2, 0.3, (0, 0.6, -0.15), "Floor", verts=48)

# --- banc de musculation (à droite), barre dorée sur ses montants
bench = []
bench.append(box("Pad", (0.75, 2.3, 0.22), (0, 0, 0.78), "Pad"))
for y in (-0.85, 0.85):
    bench.append(box("Leg", (0.6, 0.14, 0.7), (0, y, 0.35), "Steel"))
for x in (-0.85, 0.85):
    bench.append(box("Upright", (0.12, 0.12, 1.5), (x, -0.95, 0.75), "Steel"))
bench.append(cyl("Bar", 0.06, 3.0, (0, -0.95, 1.5), "Gold", rot=(0, math.pi / 2, 0)))
for x in (-1.25, 1.25):
    bench.append(cyl("Plate", 0.42, 0.14, (x, -0.95, 1.5), "Gold", rot=(0, math.pi / 2, 0), verts=24))
group("Bench", bench, (1.0, 0.6, 0), (0, 0, math.radians(-20)))

# --- le gros bro (Chad), debout devant le banc, tourné vers le joueur, fier
chad, chad_h = build("Chad", 0.62, 0.0)
FIT = 2.5 / chad_h  # personnages ramenés à l'échelle du banc (Chad : 2,5 de haut)
print("hauteurs :", chad_h)
ch = group("ChadRig", chad, (0.55, -0.4, 0), (0, 0, math.radians(-22)))
ch.scale = (FIT, FIT, FIT)

# --- le bro spaghetti éjecté : en l'air, en haut à gauche, qui tournoie
normie, normie_h = build("Normie", 0.0, 0.0)
normie_h *= FIT
for o in normie:
    if o.name.endswith("_Shorts"):
        o.data.materials.clear()
        o.data.materials.append(material("Shorts2"))
fly = group("NormieRig", normie, (0.05, 0.4, 2.35), (math.radians(15), math.radians(-55), math.radians(30)))
fly.scale = (FIT, FIT, FIT)
bpy.context.view_layer.update()

# Traînée de petits nuages derrière le gros bro (il vient du banc), puis étoiles autour de sa tête
for k, (x, z, r) in enumerate([(-0.75, 1.15, 0.2), (-0.95, 1.5, 0.15), (-1.1, 1.8, 0.11)]):
    ball(f"Puff{k}", (x, -0.5, z), r, "Puff")
head = fly.matrix_world @ Vector((0, 0, normie_h * 0.92))
for k in range(3):
    a = k * 2 * math.pi / 3
    star(f"Star{k}", head + Vector((math.cos(a) * 0.62, -0.25, math.sin(a) * 0.35 + 0.15)), 0.2,
         rot=(0, math.radians(15 * k), 0))
# Éclat doré sur le banc : la place est prise
for k, (x, z, r) in enumerate([(2.0, 2.3, 0.3), (2.3, 1.45, 0.2), (1.55, 2.75, 0.16)]):
    star(f"Gold{k}", (x, -0.2, z), r, mat="Gold", rot=(0, math.radians(20 * k), 0))

# --- rendu
for eng in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
    try:
        scene.render.engine = eng
        break
    except TypeError:
        pass
world = bpy.data.worlds.new("W")
scene.world = world
world.use_nodes = True
nodes, links = world.node_tree.nodes, world.node_tree.links
bg = next(n for n in nodes if n.type == "BACKGROUND")
# Fond : dégradé violet (haut) -> rose orangé (bas), vu par la caméra ; éclairage doux
coord = nodes.new("ShaderNodeTexCoord")
split = nodes.new("ShaderNodeSeparateXYZ")
ramp = nodes.new("ShaderNodeValToRGB")
ramp.color_ramp.elements[0].position = 0.35
ramp.color_ramp.elements[0].color = (0.95, 0.42, 0.32, 1)
ramp.color_ramp.elements[1].color = (0.2, 0.08, 0.42, 1)
links.new(coord.outputs["Window"], split.inputs["Vector"])
links.new(split.outputs["Y"], ramp.inputs["Fac"])
light_path = nodes.new("ShaderNodeLightPath")
mix = nodes.new("ShaderNodeMixShader")
bg2 = nodes.new("ShaderNodeBackground")
bg2.inputs[0].default_value = (0.75, 0.72, 0.85, 1)
bg2.inputs[1].default_value = 0.8
links.new(ramp.outputs["Color"], bg.inputs["Color"])
out = next(n for n in nodes if n.type == "OUTPUT_WORLD")
links.new(bg2.outputs[0], mix.inputs[1])
links.new(bg.outputs[0], mix.inputs[2])
links.new(light_path.outputs["Is Camera Ray"], mix.inputs["Fac"])
links.new(mix.outputs[0], out.inputs["Surface"])

sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.data.energy = 3.5
sun.rotation_euler = (math.radians(50), 0, math.radians(-30))
scene.collection.objects.link(sun)
rim = bpy.data.objects.new("Rim", bpy.data.lights.new("Rim", "SUN"))
rim.data.energy = 2.0
rim.data.color = (1.0, 0.85, 0.6)
rim.rotation_euler = (math.radians(60), 0, math.radians(150))
scene.collection.objects.link(rim)

cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
scene.collection.objects.link(cam)
aim = Vector((0.2, 0.2, 1.75))
cam.location = aim + Vector((1.2, -8.2, 0.8))
cam.rotation_euler = (aim - cam.location).to_track_quat("-Z", "Y").to_euler()
cam.data.lens = 50
scene.camera = cam
scene.view_settings.view_transform = "Standard"
size = int(os.environ.get("MOG_SIZE", "1024"))
scene.render.resolution_x = size
scene.render.resolution_y = size
path = os.environ.get("MOG_OUT", os.path.join(HERE, "..", "..", "assets", "concepts", "icon_take_spot.png"))
scene.render.filepath = os.path.abspath(path)
bpy.ops.render.render(write_still=True)
print("image :", scene.render.filepath)

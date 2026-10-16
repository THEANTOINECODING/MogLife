"""
Générateur de la carte de MUSCLE CITY (structure en blocs Roblox, versionnée dans Git via Rojo).

Plan carré et compact : tout se passe au CENTRE (place à fontaine et statues, parc, arène des boss) ; les boutiques
et la salle de quartier donnent sur la route en anneau, juste en face des 20 maisons de maman (une par joueur,
serveur de 20 joueurs max), 5 par côté, tournées vers le centre. 5 arrêts de bus (tag BusStop).

Écrit world/Map/ :
- Plots/PlotNN : maison + garage (curl, pompes), maman devant la porte, 8 emplacements de meubles.
- Town/*      : route en anneau (marquages, feux, voitures garées), centre-ville, parc, arène, bordure.
Tous les emplacements de jeu (stations, boss, habitants, miroirs, comptoir de meubles) sont générés ici.
Visuels des stations : tools/map_templates/*.model.json.

Usage :  py -3 tools/build_map.py   (puis Rojo synchronise tout seul)
Convention : Y vers le haut ; yaw 0 = regarde vers -Z, 180 = vers +Z, 90 = vers -X, -90 = vers +X.
Repère local d'un bâtiment : origine au milieu de la façade, au sol ; l'intérieur est vers +Z local,
la façade regarde vers -Z local.
"""
import json, math, os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
WORLD = os.path.join(ROOT, "world")
TEMPLATES = os.path.join(os.path.dirname(os.path.abspath(__file__)), "map_templates")
GROUND = 0.1  # dessus du sol herbeux (la Baseplate, à y = 0, est cachée dessous)


# ------------------------------------------------------------------ maths
def rot(yaw=0.0, roll=0.0):
    """Matrice de rotation (lignes) : Ry(yaw) * Rz(roll), angles en degrés."""
    y, r = math.radians(yaw), math.radians(roll)
    cy, sy, cr, sr = math.cos(y), math.sin(y), math.cos(r), math.sin(r)
    ry = [[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]]
    rz = [[cr, -sr, 0], [sr, cr, 0], [0, 0, 1]]
    return [[round(sum(ry[i][k] * rz[k][j] for k in range(3)), 6) for j in range(3)] for i in range(3)]


def mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def transpose(m):
    return [[m[j][i] for j in range(3)] for i in range(3)]


def apply(m, v):
    return [sum(m[i][k] * v[k] for k in range(3)) for i in range(3)]


class Frame:
    """Repère local (origine + rotation autour de Y)."""

    def __init__(self, origin, yaw=0.0):
        self.o, self.yaw, self.R = list(origin), yaw, rot(yaw)

    def p(self, local):
        d = apply(self.R, local)
        return [self.o[i] + d[i] for i in range(3)]

    def child(self, local, yaw=0.0):
        return Frame(self.p(local), self.yaw + yaw)


# ------------------------------------------------------------------ instances
def rgb(c):
    return {"Color3uint8": list(c)}


def part(name, pos, size, color, material="SmoothPlastic", yaw=0, roll=0, cls="Part", shape=None, collide=True,
         transparency=0, children=None, extra=None, tags=None, attributes=None):
    props = {
        "Anchored": True,
        "Size": [round(s, 3) for s in size],
        "CFrame": {"CFrame": {"position": [round(p, 3) for p in pos], "orientation": rot(yaw, roll)}},
        "Color": rgb(color),
        "Material": material,
        "CanCollide": collide,
    }
    if transparency:
        props["Transparency"] = transparency
    if shape:
        props["Shape"] = shape
    if tags:
        props["Tags"] = {"Tags": tags}
    if extra:
        props.update(extra)
    node = {"name": name, "className": cls, "properties": props}
    if attributes:
        node["attributes"] = attributes
    if children:
        node["children"] = children
    return node


def P(F, name, local, size, color, material="SmoothPlastic", yaw=0, **kw):
    return part(name, F.p(local), size, color, material, yaw=F.yaw + yaw, **kw)


def W(F, name, local, size, color, material="SmoothPlastic", yaw=0):
    return P(F, name, local, size, color, material, yaw=yaw, cls="WedgePart")


def light(color=(255, 230, 190), brightness=1.4, range_=26):
    return {"name": "Light", "className": "PointLight",
            "properties": {"Brightness": brightness, "Range": range_,
                           "Color": {"Color3": [round(v / 255, 4) for v in color]}}}


def folder(name, children):
    return {"name": name, "className": "Folder", "children": children}


def model(name, children, tags=None, attributes=None):
    node = {"name": name, "className": "Model", "children": children}
    if tags:
        node["properties"] = {"Tags": {"Tags": tags}}
    if attributes:
        node["attributes"] = attributes
    return node


def write(path, node):
    """Écrit un fichier d'un coup (fichier temporaire puis remplacement) pour que Rojo ne lise jamais un fichier
    à moitié écrit ; un fichier inchangé n'est pas réécrit."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    node = dict(node)
    node.pop("name", None)
    text = json.dumps(node, indent=1, ensure_ascii=False) + "\n"
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            if f.read() == text:
                return
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    os.replace(tmp, path)


# ------------------------------------------------------------------ palette (design/05_ART_SON.md)
CONCRETE = (150, 148, 142)
CONCRETE_LIGHT = (200, 198, 192)
PAVING = (214, 200, 184)
TIN = (150, 170, 182)
TIN_DARK = (96, 108, 118)
WOOD = (130, 92, 60)
WOOD_LIGHT = (176, 132, 88)
CARDBOARD = (176, 136, 90)
ASPHALT = (56, 56, 62)
GRASS = (104, 156, 80)
LAWN = (118, 172, 88)
PARK_GRASS = (126, 182, 92)
HEDGE = (64, 122, 60)
BRICK = (150, 72, 60)
GLASS = (150, 195, 225)
WHITE = (240, 238, 232)
TRIM = (245, 245, 240)
LAMP_GREY = (60, 60, 66)
ROOFS = [(150, 70, 60), (90, 96, 120), (120, 82, 60), (160, 100, 70), (80, 110, 100)]
PASTELS = [(238, 178, 190), (168, 222, 198), (244, 228, 160), (200, 186, 228), (248, 200, 160), (170, 204, 234),
           (240, 210, 230), (210, 232, 170)]
SPOT_BOSS = (140, 40, 40)
SPOT_HELP = (90, 150, 100)

# Plan (distances depuis le centre de la ville, en studs). Compact : les boutiques et la salle donnent directement
# sur la route en anneau, juste en face des maisons ; le parc, l'arène et la place sont à l'intérieur.
CENTER = 104         # le centre-ville va de -104 à 104 sur X et Z
PLAZA = 36           # la place centrale pavée va de -36 à 36
AVENUE = 8           # demi-largeur des 4 allées qui relient la place à la route
WALK_IN = (104, 112)   # trottoir intérieur
ROAD = (112, 132)      # route en anneau
WALK_OUT = (132, 140)  # trottoir extérieur (les maisons commencent à 140)
PLOT_W, PLOT_D = 56, 70
PLOT_OFFSETS = (0, -56, 56, -112, 112)  # 5 maisons par côté, celles du milieu d'abord
BORDER = 214
WALK_TOP = 0.6       # hauteur des trottoirs au-dessus du sol


# Les 4 côtés : repère dont l'axe local X longe le côté et l'axe local Z s'éloigne du centre
def side_frame(side):
    return Frame((0, GROUND, 0), {"N": 0, "E": 90, "S": 180, "W": -90}[side])


SIDES = ("N", "E", "S", "W")
# Arrêt de bus de chaque côté (au bout de l'allée), nommé d'après ce qu'il y a autour
BUS_STOPS = {"N": "Shops", "E": "Gym", "S": "Arena", "W": "Park"}


# ------------------------------------------------------------------ briques réutilisables
def building(F, w, d, h, color, material, door_w, door_h, windows=(), floor=None, roof="flat", roof_color=(90, 90, 96),
             roof_material="Slate", wall_t=1.0, prefix=""):
    """Bâtiment creux : 4 murs, une porte dans la façade, fenêtres (vitres dedans et dehors), sol et toit."""
    hw = w / 2
    c = []
    if floor:
        fcol, fmat, ft = floor
        c.append(P(F, prefix + "Floor", (0, ft / 2, d / 2), (w, ft, d), fcol, fmat))
    c.append(P(F, prefix + "WallBack", (0, h / 2, d - wall_t / 2), (w, h, wall_t), color, material))
    c.append(P(F, prefix + "WallLeft", (-hw + wall_t / 2, h / 2, d / 2), (wall_t, h, d), color, material))
    c.append(P(F, prefix + "WallRight", (hw - wall_t / 2, h / 2, d / 2), (wall_t, h, d), color, material))
    side = (w - door_w) / 2
    c.append(P(F, prefix + "WallFrontL", (-hw + side / 2, h / 2, wall_t / 2), (side, h, wall_t), color, material))
    c.append(P(F, prefix + "WallFrontR", (hw - side / 2, h / 2, wall_t / 2), (side, h, wall_t), color, material))
    c.append(P(F, prefix + "Lintel", (0, door_h + (h - door_h) / 2, wall_t / 2), (door_w, h - door_h, wall_t), color,
               material))
    for i, (lx, ww, y0, y1) in enumerate(windows):
        for j, lz in enumerate((-0.06, wall_t + 0.06)):
            c.append(P(F, f"{prefix}Window{i}_{j}", (lx, (y0 + y1) / 2, lz), (ww, y1 - y0, 0.1), GLASS, "Glass",
                       collide=False, extra={"Reflectance": 0.15}))
        c.append(P(F, f"{prefix}Sill{i}", (lx, y0 - 0.15, -0.2), (ww + 0.6, 0.3, 0.6), TRIM))
    if roof == "flat":
        c.append(P(F, prefix + "Roof", (0, h + 0.4, d / 2), (w + 1.5, 0.8, d + 1.5), roof_color, roof_material))
        c.append(P(F, prefix + "RoofTrim", (0, h - 0.2, -0.5), (w + 1.5, 0.6, 0.4), TRIM))
    elif roof == "gable":
        rh = min(8.0, w * 0.3)
        for k, (sx, yaw) in enumerate(((-1, 90), (1, -90))):
            c.append(W(F, f"{prefix}Roof{k}", (sx * (w / 4 + 0.25), h + rh / 2, d / 2), (d + 2, rh, w / 2 + 0.5),
                       roof_color, roof_material, yaw=yaw))
        c.append(P(F, prefix + "Eave", (0, h - 0.15, d / 2), (w + 1, 0.3, d + 1), TRIM))
    return c


def tree(F, name, local, height=9.0, radius=4.5, color=(80, 140, 60), trunk=(110, 78, 50), prop=None):
    x, y, z = local
    blocks = [
        P(F, name + "Trunk", (x, y + height / 2, z), (height, 1.3, 1.3), trunk, "Wood", roll=90, shape="Cylinder"),
        P(F, name + "Leaves", (x, y + height + radius * 0.5, z), (radius * 2,) * 3, color, "Grass", shape="Ball"),
        P(F, name + "Leaves2", (x + radius * 0.5, y + height - radius * 0.1, z - radius * 0.3), (radius * 1.4,) * 3,
          tuple(min(255, int(v * 1.12)) for v in color), "Grass", shape="Ball"),
    ]
    prop = prop or ("TreeRoundBig" if radius >= 5.5 else "TreeRound")
    yaw = (sum(ord(ch) for ch in name) * 37) % 360  # chaque arbre tourné différemment
    return [prop_slot(F, name, local, prop, blocks, yaw=yaw, height=height + radius * 1.5)]


def bench(F, name, local, yaw=0):
    G = F.child(local, yaw)
    blocks = [
        P(G, name + "Seat", (0, 1.4, 0), (6, 0.4, 1.8), WOOD_LIGHT, "WoodPlanks"),
        P(G, name + "Back", (0, 2.6, 0.8), (6, 1.6, 0.3), WOOD_LIGHT, "WoodPlanks"),
        P(G, name + "LegL", (-2.6, 0.6, 0), (0.4, 1.2, 1.6), (50, 50, 56), "Metal"),
        P(G, name + "LegR", (2.6, 0.6, 0), (0.4, 1.2, 1.6), (50, 50, 56), "Metal"),
    ]
    return [prop_slot(G, name, (0, 0, 0), "Bench", blocks)]


def lamp_post(F, name, local, arm_dir=-1):
    """Lampadaire ; arm_dir = sens du bras sur l'axe Z local (vers la route). La lumière reste une pièce à part
    (tag StreetLight, allumée la nuit) pour fonctionner aussi avec le modèle 3D."""
    x, y, z = local
    blocks = [
        P(F, name, (x, y + 6, z), (0.5, 12, 0.5), LAMP_GREY, "Metal"),
        P(F, name + "Arm", (x, y + 11.8, z + arm_dir * 1.2), (0.4, 0.4, 2.4), LAMP_GREY, "Metal"),
        P(F, name + "Head", (x, y + 11.5, z + arm_dir * 2.2), (1.4, 0.5, 1.4), (255, 236, 190), "Neon",
          tags=["StreetLight"]),
    ]
    lamp = P(F, name + "Light", (x, y + 11.2, z + arm_dir * 2.3), (0.4, 0.4, 0.4), WHITE, transparency=1,
             collide=False, tags=["StreetLight"], extra={"CanQuery": False, "CanTouch": False},
             children=[light((255, 220, 170), 1.1, 28)])
    return [prop_slot(F, name + "Slot", local, "StreetLamp", blocks, yaw=180 if arm_dir > 0 else 0), lamp]


def flowerbed(F, name, local, size=(10, 10)):
    x, y, z = local
    c = [P(F, name, (x, y + 0.4, z), (size[0], 0.8, size[1]), (110, 80, 60), "Ground")]
    colors = [(240, 90, 120), (250, 210, 70), (180, 120, 230), (250, 150, 60)]
    for k in range(4):
        dx = (k % 2 - 0.5) * size[0] * 0.5
        dz = (k // 2 - 0.5) * size[1] * 0.5
        ball = P(F, f"{name}Flowers{k}", (x + dx, y + 1.2, z + dz), (2.4, 1.2, 2.4), colors[k], "Grass", shape="Ball")
        c.append(prop_slot(F, f"{name}FlowerSlot{k}", (x + dx, y + 0.8, z + dz), "FlowerPatch", [ball],
                           yaw=k * 90, height=1.3, collide=False))
    return c


def spot(F, name, local, size, color, tag, attributes, yaw=0, material="SmoothPlastic"):
    return P(F, name, local, size, color, material, yaw=yaw, tags=[tag], attributes=attributes)


def helper(F, name, local, help_id, yaw=0):
    return spot(F, name, local, (6, 1, 6), SPOT_HELP, "HelperSpot", {"HelpId": help_id}, yaw=yaw)


def station(F, name, local, exercise_id, yaw=0):
    """Station d'exercice copiée depuis tools/map_templates (dalle + accessoires), replacée et tournée."""
    with open(os.path.join(TEMPLATES, f"{exercise_id}Station.model.json"), encoding="utf-8") as f:
        tpl = json.load(f)
    cf = tpl["properties"]["CFrame"]["CFrame"]
    pos0, R0 = cf["position"], cf.get("orientation", rot())
    Rt = transpose(R0)
    world = F.p(local)
    R = rot(F.yaw + yaw)
    tpl["name"] = name
    tpl["properties"]["CFrame"]["CFrame"] = {"position": [round(v, 3) for v in world], "orientation": R}
    tpl["properties"]["Tags"]["Tags"] = tpl["properties"]["Tags"]["Tags"] + ["PropSlot"]
    tpl["attributes"]["Prop"] = STATION_PROPS[exercise_id]
    tpl["attributes"]["PropCollide"] = False
    if not FALLBACK_BLOCKS:
        tpl["children"] = []
    for child in tpl.get("children", []):
        ccf = child["properties"]["CFrame"]["CFrame"]
        rel = apply(Rt, [ccf["position"][i] - pos0[i] for i in range(3)])
        d = apply(R, rel)
        ccf["position"] = [round(world[i] + d[i], 3) for i in range(3)]
        rel_o = mul(Rt, ccf.get("orientation", rot()))
        ccf["orientation"] = [[round(v, 6) for v in row] for row in mul(R, rel_o)]
    # Barre posée sur les crochets (décor à part : le client la fait bouger pendant la série)
    if exercise_id in STATION_BARS:
        bar_height, bar_z = STATION_BARS[exercise_id]
        G = F.child(local, yaw)
        tpl.setdefault("children", []).append(
            prop_slot(G, "StationBar", (0, 0.5 + bar_height - BARBELL_RADIUS, bar_z), "Barbell", collide=False))
    return tpl


def style_display(F, name, local, stage, items, kind="Mannequin", yaw=0):
    """Présentoir de la boutique (tag StyleDisplay) : DisplayService y monte un mannequin (ou une tête) blanc
    au corps du stade `stage`, qui porte les vrais objets `items`."""
    return P(F, name, (local[0], local[1] + 0.1, local[2]), (1, 0.2, 1), WHITE, yaw=yaw, transparency=1, collide=False,
             tags=["StyleDisplay"], attributes={"Stage": stage, "Items": ",".join(items), "Kind": kind},
             extra={"CanQuery": False, "CanTouch": False})


def vendor(F, name, local, npc, store, tag, categories=None, yaw=0):
    """Vendeur d'un magasin (tag VendorSpot, décision D38) : VendorService y fait apparaître le PNJ `npc`.
    Il porte le tag `tag` du point de vente (Mirror ou FurnitureShop) : lui parler ouvre la même boutique."""
    attributes = {"Npc": npc, "Store": store, "Tag": tag}
    if categories:
        attributes["Categories"] = categories
    return P(F, name, (local[0], local[1] + 0.1, local[2]), (1.6, 0.2, 1.6), WHITE, yaw=yaw, transparency=1,
             collide=False, tags=["VendorSpot"], attributes=attributes, extra={"CanQuery": False, "CanTouch": False})


def mirror(F, name, local, attributes, yaw=0):
    """Miroir de boutique (tag Mirror) : ses attributs disent quelles catégories de style il vend."""
    G = F.child(local, yaw)
    return P(G, name, (0, 0, 0), (8, 10, 0.4), (205, 230, 250), "Glass", tags=["Mirror"], attributes=attributes,
             extra={"Reflectance": 0.5},
             children=[P(G, "Frame", (0, 0, 0.3), (9, 11, 0.3), (230, 180, 40), collide=False)])


# ------------------------------------------------------------------ emplacements de décor 3D (Blender)
# Un emplacement (tag PropSlot) = un repère invisible (PropAnchor, au sol, orienté) + les blocs actuels (Fallback).
# Si le modèle 3D du même nom est importé dans ServerStorage.Props, PropService le pose et retire les blocs ;
# sinon les blocs restent. Le devant d'un modèle 3D est vers -Z du repère.
# Les modèles 3D sont importés (ServerStorage.Props) : les blocs de secours ne sont plus écrits dans la carte.
# Remettre True pour retrouver la ville en blocs (par exemple sur une place où les modèles n'ont pas été importés).
FALLBACK_BLOCKS = False

STATION_PROPS = {"Curl": "WatermelonDumbbell", "PushUp": "PushUpMat", "BenchPress": "BenchPress",
                 "Squat": "SquatRack", "PullUp": "PullUpBar", "JumpRope": "JumpRope"}
# Hauteur de la barre au-dessus de la dalle et position avant/arrière (props_gym.py : bench_press, squat_rack)
STATION_BARS = {"BenchPress": (4.0, -2.5), "Squat": (4.75, -1.95)}
BARBELL_RADIUS = 1.4  # rayon des disques du modèle Barbell (son repère est sous les disques)


def prop_slot(F, name, local, prop, fallback=(), yaw=0, height=None, collide=True, align=None):
    anchor = P(F, "PropAnchor", local, (1, 0.2, 1), WHITE, yaw=yaw, transparency=1, collide=False,
               extra={"CanQuery": False, "CanTouch": False})
    attributes = {"Prop": prop}
    if height:
        attributes["PropHeight"] = round(height, 2)
    if not collide:
        attributes["PropCollide"] = False
    if align:
        attributes["PropAlign"] = align  # "Back" : le dos du modèle touche le repère (fenêtres, enseignes)
    children = [anchor]
    if fallback and FALLBACK_BLOCKS:
        children.append({"name": "Fallback", "className": "Model", "children": list(fallback)})
    return {"name": name, "className": "Model", "properties": {"Tags": {"Tags": ["PropSlot"]}},
            "attributes": attributes, "children": children}


# Positions des pièces de bâtiment dans leur repère de conception (écrit par tools/blender/props_building.py)
with open(os.path.join(ROOT, "assets", "export", "props", "buildings_manifest.json"), encoding="utf-8") as _f:
    BUILDING_MANIFEST = json.load(_f)


def piece(F, name, prop, tint=None, material=None, collide=True, attributes=None):
    """Pièce d'un bâtiment (murs, toit, façade, intérieur) recalée dans le repère F du bâtiment.
    tint / material : le jeu retire la texture et applique cette couleur et ce matériau Roblox."""
    m = BUILDING_MANIFEST[prop]
    cx, cy = m["center"]
    slot = prop_slot(F, name, (cx, m["bottom"], cy), prop, collide=collide)
    if tint:
        slot["attributes"]["PropColor"] = {"Color3": [round(v / 255, 4) for v in tint]}
    if material:
        slot["attributes"]["PropMaterial"] = material
    if attributes:
        slot["attributes"].update(attributes)
    return slot


SHOP_DIMS = {"Clothes": (44, 38), "Barber": (36, 32), "Furniture": (48, 38), "Grocery": (36, 32), "Gym": (84, 48)}
SHOP_DOOR_WIDTH = {"Clothes": 10, "Barber": 8, "Furniture": 12, "Grocery": 10, "Gym": 18}  # = props_building.SHOPS


def auto_door(F, name, local, prop, yaw=0, swing=None):
    """Porte battante modélisée dans Blender (charnière côté -X du modèle, poignée côté +X).
    DoorService la fait pivoter à l'opposé du joueur qui approche ; on la traverse toujours (pas de collision)."""
    slot = prop_slot(F, name, local, prop, yaw=yaw, collide=False)
    slot["attributes"].update({"AutoDoor": True, "DoorHinge": -1})
    if swing:
        slot["attributes"]["DoorSwing"] = swing  # 1 : s'ouvre toujours vers le +Z du repère de la porte
    return slot


def shop_shell(F, name, color, material, floor):
    """Magasin modélisé dans Blender : sol en bloc + murs teintés, façade (vitrines, enseigne) et intérieur."""
    w, d = SHOP_DIMS[name]
    fcol, fmat, ft = floor
    return [
        P(F, name + "Floor", (0, ft / 2, d / 2), (w, ft, d), fcol, fmat),
        piece(F, name + "Walls", f"Shop_{name}_Walls", tint=color, material=material),
        piece(F, name + "Trim", f"Shop_{name}_Trim", collide=False),
        piece(F, name + "Interior", f"Shop_{name}_Interior", collide=False),
        # Deux battants vitrés, poignées au milieu (le battant de droite est retourné)
        auto_door(F, name + "DoorLeft", (-SHOP_DOOR_WIDTH[name] / 4, ft, 0.4), f"Door_Shop_{name}"),
        auto_door(F, name + "DoorRight", (SHOP_DOOR_WIDTH[name] / 4, ft, 0.4), f"Door_Shop_{name}", yaw=180),
    ]


def wrap(c, n0, F, name, local, prop, yaw=0, height=None, collide=True, align=None):
    """Range les blocs ajoutés à `c` depuis l'index n0 dans un emplacement de décor."""
    blocks = c[n0:]
    del c[n0:]
    c.append(prop_slot(F, name, local, prop, blocks, yaw=yaw, height=height, collide=collide, align=align))


def decor(F, name, local, prop, yaw=0, height=None, collide=True, align=None):
    """Décor 3D sans version en blocs : invisible tant que le modèle n'est pas importé."""
    return prop_slot(F, name, local, prop, (), yaw=yaw, height=height, collide=collide, align=align)


# ------------------------------------------------------------------ 1. maison de maman (une par joueur)
SLOTS = {
    # emplacement : (x, y, z, yaw) dans le repère de la maison ; yaw = direction où regarde le meuble
    "Rug": (0, 0.5, 14, 0),
    "Sofa": (-10.5, 0.5, 15, -90),
    "Tv": (11, 0.5, 15, 90),
    "Bed": (6.5, 0.5, 26, 0),
    "Trophy": (-7, 0.5, 29.6, 0),
    "Poster": (-11.9, 6, 15, -90),
    "Plant": (-9.5, 0.5, 3.5, 0),
    "Lamp": (9.5, 0.5, 3.5, 0),
}


CAR_PROPS = {(200, 60, 50): "CarSedanRed", (240, 200, 60): "CarPickup", (150, 60, 150): "CarSedanRed"}


def car(F, name, local, color, yaw=0):
    C = F.child(local, yaw)
    dark = tuple(int(v * 0.88) for v in color)
    blocks = [
        P(C, name + "Body", (0, 1.8, 0), (11, 2.2, 5), color),
        P(C, name + "Cabin", (-0.5, 3.8, 0), (6, 1.8, 4.6), dark),
        P(C, name + "Windows", (-0.5, 3.8, 0), (6.1, 1.4, 4.7), GLASS, "Glass", transparency=0.3, collide=False),
        P(C, name + "LightL", (5.55, 2, -1.6), (0.1, 0.6, 1), (255, 240, 200), "Neon", collide=False),
        P(C, name + "LightR", (5.55, 2, 1.6), (0.1, 0.6, 1), (255, 240, 200), "Neon", collide=False),
    ]
    for k, (dx, dz) in enumerate(((-3.6, -2.4), (3.6, -2.4), (-3.6, 2.4), (3.6, 2.4))):
        blocks.append(P(C, f"{name}Wheel{k}", (dx, 1, dz), (1, 2, 2), (25, 25, 28), yaw=90, shape="Cylinder"))
    # La voiture en blocs est construite le long de X (avant vers +X) : le modèle 3D regarde donc vers +X
    return [prop_slot(C, name, (0, 0, 0), CAR_PROPS.get(tuple(color), "CarSedan"), blocks, yaw=-90)]


def bus_stop(F, name, local, stop_id, yaw=0):
    """Abri de bus : le panneau jaune au sol (tag BusStop) téléporte vers les autres arrêts."""
    G = F.child(local, yaw)
    pad = P(G, name, (0, 0.05, 0), (8, 0.1, 3), (250, 200, 40), "SmoothPlastic", tags=["BusStop"],
            attributes={"Stop": stop_id})
    blocks = [
        P(G, name + "Roof", (0, 8.2, 1.4), (9, 0.4, 3.6), (60, 110, 200), "Metal"),
        P(G, name + "Back", (0, 4.5, 3), (9, 7, 0.2), GLASS, "Glass", transparency=0.4),
        P(G, name + "PostL", (-4.3, 4, 3), (0.3, 8, 0.3), LAMP_GREY, "Metal"),
        P(G, name + "PostR", (4.3, 4, 3), (0.3, 8, 0.3), LAMP_GREY, "Metal"),
        P(G, name + "Bench", (0, 1.4, 2.3), (6, 0.4, 1.2), WOOD_LIGHT, "WoodPlanks"),
        P(G, name + "SignPole", (-5.2, 4, 0), (0.3, 8, 0.3), LAMP_GREY, "Metal"),
        P(G, name + "SignDisc", (-5.2, 8.4, 0), (0.3, 2.4, 2.4), (250, 200, 40), "SmoothPlastic", yaw=90,
          shape="Cylinder"),
    ]
    return [pad, prop_slot(G, name + "Shelter", (0.5, 0, 1.2), "BusShelter", blocks)]


def landmark(F, name, local, icon):
    """Point invisible au-dessus d'un bâtiment : le client y affiche une grande icône visible de loin."""
    return P(F, name, local, (1, 1, 1), WHITE, transparency=1, collide=False, tags=["Landmark"],
             attributes={"Icon": icon}, extra={"CanQuery": False, "CanTouch": False})


def plot(index, side, offset):
    S = side_frame(side)
    F = S.child((offset, 0, WALK_OUT[1]))  # façade de la parcelle sur le trottoir, l'intérieur s'éloigne du centre
    wall = PASTELS[index % len(PASTELS)]
    roof = ROOFS[index % len(ROOFS)]
    hw = PLOT_W / 2
    c = []
    # Terrain : pelouse, haies, allée de garage, chemin jusqu'à la porte, bateau sur le trottoir
    c.append(P(F, "Lawn", (0, 0.05, PLOT_D / 2), (PLOT_W, 0.1, PLOT_D), LAWN, "Grass"))
    for k, lx in enumerate((-hw + 0.4, hw - 0.4)):
        c.append(P(F, f"HedgeSide{k}", (lx, 1.5, PLOT_D / 2 + 3), (0.8, 3, PLOT_D - 6), HEDGE, "Grass"))
    c.append(P(F, "HedgeBack", (0, 1.5, PLOT_D - 0.6), (PLOT_W, 3, 1.2), HEDGE, "Grass"))
    for k, (x0, x1) in enumerate(((-hw, -23), (-5, 11.5), (16.5, hw))):
        c.append(P(F, f"HedgeFront{k}", ((x0 + x1) / 2, 0.8, 0.8), (x1 - x0, 1.6, 1.2), HEDGE, "Grass"))
    c.append(P(F, "Driveway", (-14, 0.08, 4.5), (18, 0.16, 9), CONCRETE, "Concrete"))
    c.append(P(F, "Apron", (-14, WALK_TOP + 0.02, -4), (18, 0.04, 7.6), CONCRETE, "Concrete", collide=False))
    c.append(P(F, "Path", (14, 0.08, 6), (4, 0.16, 12), CONCRETE_LIGHT, "Concrete"))

    # Panneau du propriétaire (le serveur y écrit le nom) et boîte aux lettres
    c.append(P(F, "SignPost", (3.5, 1.2, 2.8), (0.4, 2.4, 0.4), WOOD, "WoodPlanks"))
    c.append(P(F, "OwnerSign", (3.5, 3.4, 2.8), (7, 2.4, 0.3), WHITE, "WoodPlanks"))
    n0 = len(c)
    c.append(P(F, "MailboxPost", (-2.5, 1.5, 2.8), (0.4, 3, 0.4), WOOD, "WoodPlanks"))
    c.append(P(F, "Mailbox", (-2.5, 3.4, 2.8), (1.2, 1.2, 2), (40, 90, 160), "Metal"))
    wrap(c, n0, F, "MailboxSlot", (-2.5, 0.1, 2.8), "Mailbox")
    c.append(P(F, "Spawn", (5, 3, 7), (2, 1, 2), WHITE, transparency=1, collide=False,
               extra={"CanQuery": False, "CanTouch": False}))

    # Le garage : curl, pompes, et Kevin sur le canapé défoncé (assez grand pour recevoir des visiteurs)
    G = F.child((-14, 0, 8))
    # Garage modélisé dans Blender, de la couleur de la maison (murs en plâtre, toit en ardoise)
    c.append(P(G, "GarageFloor", (0, 0.15, 15), (26, 0.3, 30), CONCRETE, "Concrete"))
    c.append(piece(G, "GarageWalls", "Garage_Walls", tint=wall, material="Plaster"))
    c.append(piece(G, "GarageRoof", "Garage_Roof", tint=roof, material="Slate"))
    c.append(piece(G, "GarageTrim", "Garage_Trim", collide=False))
    c.append(piece(G, "GarageInterior", "Garage_Interior", collide=False))
    for k, lz in enumerate((8, 20)):
        c.append(P(G, f"GarageLamp{k}", (0, 11.5, lz), (8, 0.4, 1), (255, 244, 214), "Neon",
                   children=[light(brightness=0.8, range_=20)]))
    c.append(station(G, "CurlStation", (-7, 0.8, 6.5), "Curl"))
    c.append(station(G, "PushUpStation", (7, 0.8, 6.5), "PushUp"))
    # Vieux tapis de course qui sert d'étendoir à linge (Kevin, lui, traîne en ville)
    n0 = len(c)
    c.append(P(G, "TreadmillBase", (0, 0.8, 17), (3.4, 1, 7), (60, 60, 66), "Metal"))
    c.append(P(G, "TreadmillBelt", (0, 1.32, 17.4), (2.8, 0.05, 6), (30, 30, 34), "Rubber", collide=False))
    c.append(P(G, "TreadmillHandle", (0, 3.6, 14), (3.4, 0.4, 0.4), (60, 60, 66), "Metal"))
    for k, lx in enumerate((-1.5, 1.5)):
        c.append(P(G, f"TreadmillPost{k}", (lx, 2.3, 14), (0.3, 3, 0.3), (60, 60, 66), "Metal"))
    for k, (lx, colr) in enumerate(((-0.9, (240, 90, 90)), (0.6, (90, 140, 220)))):
        c.append(P(G, f"Laundry{k}", (lx, 2.7, 14), (1.2, 1.6, 0.1), colr, "Fabric", collide=False))
    wrap(c, n0, G, "TreadmillSlot", (0, 0.3, 17), "Treadmill")
    n0 = len(c)
    c.append(P(G, "CouchSeat", (0, 1.5, 24.5), (11, 2.4, 4), (122, 82, 62), "Fabric"))
    c.append(P(G, "CouchBack", (0, 3.6, 26.3), (11, 2.6, 1), (112, 74, 56), "Fabric"))
    for k, lx in enumerate((-6, 6)):
        c.append(P(G, f"CouchArm{k}", (lx, 2.6, 24.5), (1, 2.2, 4), (112, 74, 56), "Fabric"))
    c.append(P(G, "PizzaBox", (-3, 2.85, 24), (2.6, 0.3, 2.6), CARDBOARD, "Cardboard", yaw=20))
    wrap(c, n0, G, "CouchSlot", (0, 0.3, 25), "Furniture_SaggyCouch")
    n0 = len(c)
    c.append(P(G, "Workbench", (-10.6, 2.1, 17), (2.4, 3.6, 7), WOOD, "WoodPlanks"))
    c.append(P(G, "Toolboard", (-12.3, 7, 17), (0.3, 3.4, 7), WOOD_LIGHT, "WoodPlanks"))
    wrap(c, n0, G, "WorkbenchSlot", (-10.6, 0.3, 17), "Garage_Workbench", yaw=-90)
    n0 = len(c)
    # Côté droit dégagé au fond : la porte vers la maison s'y trouve (z 23,5 → 28,5)
    n0 = len(c)
    c.append(P(G, "Fridge", (10.5, 3.9, 12), (3, 7.2, 3), (232, 230, 220)))
    wrap(c, n0, G, "FridgeSlot", (10.6, 0.3, 12), "Garage_Fridge", yaw=90)
    n0 = len(c)
    c.append(P(G, "WashingMachine", (10.5, 1.9, 16.5), (3.2, 3.2, 3.2), (220, 220, 226)))
    wrap(c, n0, G, "WasherSlot", (10.6, 0.3, 16.5), "Garage_WashingMachine", yaw=90)
    n0 = len(c)
    for k, (lx, ly, lz, s) in enumerate(((9.5, 1.5, 20.5, 2.4), (10, 3.6, 20.6, 1.8))):
        c.append(P(G, f"Box{k}", (lx, ly, lz), (s, s, s), CARDBOARD, "Cardboard", yaw=k * 23))
    wrap(c, n0, G, "BoxesSlot", (10.0, 0.3, 20.5), "Garage_BoxStack", yaw=90)
    n0 = len(c)
    c.append(P(G, "Box2", (-9.5, 1.3, 26.5), (2.2, 2.2, 2.2), CARDBOARD, "Cardboard", yaw=46))
    wrap(c, n0, G, "PizzaBoxesSlot", (-9.5, 0.3, 26.5), "Garage_PizzaBoxes", yaw=30)
    c.append(decor(G, "TireSlot", (-11.6, 0.3, 23.0), "Garage_Tire", yaw=-90))
    c.append(decor(G, "GasCanSlot", (-11.0, 0.3, 11.0), "Garage_GasCan", yaw=-90, height=2.2))

    # La maison : 8 emplacements de meubles que le joueur décore
    H = F.child((14, 0, 12))
    # Maison modélisée dans Blender : murs en plâtre de couleur pastel, toit en ardoise, façade et porche,
    # papier peint intérieur (4 motifs en alternance)
    c.append(P(H, "HouseFloor", (0, 0.25, 16), (26, 0.5, 32), WOOD_LIGHT, "WoodPlanks"))
    c.append(piece(H, "HouseWalls", "House_Walls", tint=wall, material="Plaster"))
    c.append(piece(H, "HouseRoof", "House_Roof", tint=roof, material="Slate"))
    c.append(piece(H, "HouseTrim", "House_Trim", collide=False))
    c.append(piece(H, "HouseInterior", "House_Interior_" + ("Cream", "Mint", "Rose", "Blue")[index % 4],
                   collide=False))
    # Passage couvert vers le garage, et porte qui s'ouvre toute seule quand un joueur approche (DoorService)
    c.append(P(H, "LinkFloor", (-14, 0.2, 22), (2.4, 0.4, 5.6), CONCRETE_LIGHT, "Concrete"))
    # (dans le mur gauche de la maison : sa largeur est le long de Z)
    # (le passage côté garage est étroit : elle s'ouvre toujours vers le salon)
    c.append(auto_door(H, "InteriorDoor", (-12.6, 0.2, 22), "Door_Interior", yaw=90, swing=1))
    # Porte d'entrée, sur le seuil du porche
    c.append(auto_door(H, "FrontDoor", (0, 0.5, 0.4), "Door_House"))
    for k, lz in enumerate((9, 22)):
        c.append(P(H, f"HouseLamp{k}", (0, 11.6, lz), (4, 0.4, 4), (255, 244, 214), "Neon",
                   children=[light(brightness=0.8, range_=20)]))
    for slot, (lx, ly, lz, yaw) in SLOTS.items():
        c.append(P(H, f"Slot{slot}", (lx, ly, lz), (1, 1, 1), WHITE, yaw=yaw, transparency=1, collide=False,
                   tags=["FurnitureSlot"], attributes={"Slot": slot}, extra={"CanTouch": False}))

    # Maman attend devant la porte avec son bocal
    c.append(helper(F, "MomSpot", (21.5, 0.6, 6), "OpenJar"))

    # Jardin de derrière et bouche d'incendie sur le trottoir
    c += tree(F, "TreeA", (-14, 0, 56))
    c += tree(F, "TreeB", (14, 0, 60), height=7, radius=3.6, color=(96, 150, 70))
    n0 = len(c)
    c.append(P(F, "Hydrant", (-25, WALK_TOP + 0.9, -2.5), (1.8, 0.9, 0.9), (200, 40, 40), "Metal",
               shape="Cylinder", roll=90))
    wrap(c, n0, F, "HydrantSlot", (-25, WALK_TOP, -2.5), "Hydrant", yaw=180)
    return model(f"Plot{index:02d}", c, tags=["Plot"], attributes={"PlotIndex": index})


def plot_list():
    """Ordre d'attribution : les maisons du milieu de chaque côté d'abord, puis vers les coins."""
    return [(side, off) for off in PLOT_OFFSETS for side in SIDES]


# ------------------------------------------------------------------ 2. route en anneau et bordure
# Objets posés sur le trottoir intérieur : pas de lampadaire ni d'arbre devant eux (position le long du côté)
KEEP_CLEAR = {"N": (-52, -47, 20, 46, 52, 70), "E": (20, 54), "S": (20,), "W": (20, -32, -40)}
CAR_COLORS = [(60, 110, 200), (240, 200, 60), (90, 170, 90), (230, 230, 235), (150, 60, 150)]


def ring():
    c = [part("Ground", (0, GROUND - 0.5, 0), (2000, 1, 2000), GRASS, "Grass")]
    for n, side in enumerate(SIDES):
        S = side_frame(side)
        long_side = side in ("N", "S")  # les côtés N et S couvrent les coins
        road_len = 2 * ROAD[1] if long_side else 2 * ROAD[0]
        in_len = 2 * WALK_IN[1] if long_side else 2 * WALK_IN[0]
        out_len = 2 * WALK_OUT[1] if long_side else 2 * WALK_OUT[0]
        mid_road = sum(ROAD) / 2
        c.append(P(S, f"Road{side}", (0, 0.075, mid_road), (road_len, 0.15, ROAD[1] - ROAD[0]), ASPHALT, "Asphalt"))
        c.append(P(S, f"WalkIn{side}", (0, WALK_TOP / 2, sum(WALK_IN) / 2), (in_len, WALK_TOP, 8), CONCRETE_LIGHT,
                   "Concrete"))
        c.append(P(S, f"WalkOut{side}", (0, WALK_TOP / 2, sum(WALK_OUT) / 2), (out_len, WALK_TOP, 8),
                   CONCRETE_LIGHT, "Concrete"))
        c.append(P(S, f"CurbIn{side}", (0, 0.32, WALK_IN[1] - 0.2), (in_len, 0.64, 0.4), (170, 168, 160),
                   "Concrete"))
        c.append(P(S, f"CurbOut{side}", (0, 0.32, WALK_OUT[0] + 0.2), (out_len, 0.64, 0.4), (170, 168, 160),
                   "Concrete"))
        # Marquages : lignes de rive, ligne centrale, passage piéton et lignes d'arrêt en face de l'allée
        edge_len = 2 * ROAD[0] - 4
        for k, d in enumerate((ROAD[0] + 0.8, ROAD[1] - 0.8)):
            c.append(P(S, f"EdgeLine{side}{k}", (0, 0.16, d), (edge_len if k == 0 else 2 * ROAD[1] - 4, 0.02, 0.4),
                       WHITE, collide=False))
        for i, s in enumerate(range(-108, 109, 12)):
            if abs(s) > 12:
                c.append(P(S, f"Dash{side}{i}", (s, 0.16, mid_road), (6, 0.02, 0.6), (240, 200, 60), collide=False))
        for j, dz in enumerate((-7.5, -4.5, -1.5, 1.5, 4.5, 7.5)):
            c.append(P(S, f"Crosswalk{side}{j}", (0, 0.16, mid_road + dz), (10, 0.02, 1.6), WHITE, collide=False))
        for k, s in enumerate((-8, 8)):
            c.append(P(S, f"StopLine{side}{k}", (s, 0.16, mid_road), (0.8, 0.02, ROAD[1] - ROAD[0] - 2), WHITE,
                       collide=False))
        # Feux tricolores de chaque côté du passage piéton
        for k, (s, d) in enumerate(((-7, WALK_IN[1] - 1), (7, WALK_OUT[0] + 1))):
            n0 = len(c)
            c.append(P(S, f"TrafficPole{side}{k}", (s, WALK_TOP + 4, d), (0.4, 8, 0.4), LAMP_GREY, "Metal"))
            c.append(P(S, f"TrafficBox{side}{k}", (s, WALK_TOP + 8.6, d), (1, 3, 1), (30, 30, 34)))
            for j, (colr, lit) in enumerate((((220, 40, 40), False), ((240, 190, 40), False), ((60, 220, 90), True))):
                c.append(P(S, f"TrafficLamp{side}{k}{j}", (s, WALK_TOP + 9.6 - j * 0.95, d), (0.7, 0.7, 1.05),
                           colr if lit else tuple(v // 3 for v in colr), "Neon" if lit else "SmoothPlastic",
                           shape="Ball", collide=False))
            wrap(c, n0, S, f"TrafficLightSlot{side}{k}", (s, WALK_TOP, d), "TrafficLight", yaw=180 if k == 0 else 0)
        c.append(decor(S, f"TrashSlot{side}", (-12, WALK_TOP, WALK_IN[0] + 1.6), "TrashBin"))
        c.append(decor(S, f"NewsSlot{side}", (11, WALK_TOP, WALK_IN[0] + 1.3), "NewsBox", yaw=180))
        c.append(decor(S, f"HydrantSlotIn{side}", (-40, WALK_TOP, WALK_IN[1] - 1.4), "Hydrant", yaw=180))
        # Plaques d'égout et voitures garées le long du trottoir extérieur
        for k, s in enumerate((-60, 60)):
            c.append(P(S, f"Manhole{side}{k}", (s, 0.16, mid_road - 5), (0.02, 2.4, 2.4), (40, 40, 44), "Metal",
                       roll=90, shape="Cylinder", collide=False))
        for k, s in enumerate((-42, 70)):
            c += car(S, f"Parked{side}{k}", (s, 0.15, ROAD[1] - 3.6), CAR_COLORS[(n * 2 + k) % len(CAR_COLORS)])
        # Lampadaires et arbres d'alignement, en alternance, sur les deux trottoirs
        for i, s in enumerate(range(-100, 101, 25)):
            if abs(s) < 14 or any(abs(s - k) < 7 for k in KEEP_CLEAR[side]):
                continue
            if i % 2 == 0:
                c += lamp_post(S, f"LampIn{side}{i}", (s, WALK_TOP, WALK_IN[1] - 1.2), arm_dir=1)
                c += lamp_post(S, f"LampOut{side}{i}", (s, WALK_TOP, WALK_OUT[0] + 1.2), arm_dir=-1)
            else:
                c += tree(S, f"TreeIn{side}{i}", (s, WALK_TOP, WALK_IN[1] - 1.8), height=7, radius=3.2)
                c += tree(S, f"TreeOut{side}{i}", (s, WALK_TOP, WALK_OUT[0] + 1.8), height=7, radius=3.2)
        # Arrêt de bus au bout de l'allée
        c += bus_stop(S, f"BusStop{side}", (20, WALK_TOP, WALK_IN[0] + 4), BUS_STOPS[side], yaw=180)
        # Bordure de la ville : grande haie et rangée d'arbres derrière les maisons
        c.append(P(S, f"BorderHedge{side}", (0, 3, BORDER), (2 * BORDER + 2, 6, 2), HEDGE, "Grass"))
        for i, s in enumerate(range(-200, 201, 40)):
            c += tree(S, f"BorderTree{side}{i}", (s, 0, BORDER + 10), height=10 + (i % 3) * 2, radius=6,
                      color=(70, 130, 56), prop="Pine" if i % 2 else "TreeRoundBig")
        # Coin de rue : petit square fleuri entre deux côtés de maisons
        c += flowerbed(S, f"CornerBed{side}", (-176, 0, 176), (16, 16))
        c += tree(S, f"CornerTree{side}", (-162, 0, 192), height=11, radius=6)
        c += bench(S, f"CornerBench{side}", (-176, 0, 160), yaw=180)
    return folder("Ring", c)


# ------------------------------------------------------------------ 3. le centre-ville
def plaza():
    F = Frame((0, GROUND, 0))
    c = [P(F, "Plaza", (0, 0.06, 0), (2 * PLAZA, 0.12, 2 * PLAZA), PAVING, "Pavement")]
    length = CENTER - PLAZA
    for side in SIDES:  # les 4 allées qui relient la place à la route
        S = side_frame(side)
        c.append(P(S, f"Avenue{side}", (0, 0.06, PLAZA + length / 2), (2 * AVENUE, 0.12, length), PAVING, "Pavement"))
        for k, sx in enumerate((-1, 1)):
            c += lamp_post(S, f"AvenueLamp{side}{k}", (sx * (AVENUE + 1.5), 0, PLAZA + length / 2), arm_dir=0)
    # Grande fontaine : un haltère doré
    n0 = len(c)
    c.append(P(F, "FountainBasin", (0, 0.9, 0), (1.8, 18, 18), (200, 200, 205), "Concrete", roll=90,
               shape="Cylinder"))
    c.append(P(F, "FountainWater", (0, 1.6, 0), (0.2, 16, 16), (90, 170, 230), "Glass", roll=90, shape="Cylinder",
               transparency=0.2, collide=False))
    c.append(P(F, "FountainColumn", (0, 4, 0), (6, 2.4, 2.4), (200, 200, 205), "Concrete", roll=90,
               shape="Cylinder"))
    c.append(P(F, "FountainBar", (0, 8, 0), (8, 0.9, 0.9), (230, 190, 60), "Metal", shape="Cylinder"))
    for k, dx in enumerate((-3.8, 3.8)):
        c.append(P(F, f"FountainPlate{k}", (dx, 8, 0), (0.9, 4.4, 4.4), (230, 190, 60), "Metal", shape="Cylinder"))
    wrap(c, n0, F, "FountainSlot", (0, 0.12, 0), "Fountain")
    for k, (x, z, yaw) in enumerate(((0, -14, 0), (14, 0, 90), (-14, 0, -90))):
        c += bench(F, f"FountainBench{k}", (x, 0, z), yaw=yaw)
    # Podium des 3 plus gros moggers du serveur (statues mises à jour par le serveur, tag MogStatue)
    for rank, (x, h, color) in enumerate(((0, 3, (230, 190, 60)), (-11, 2.2, (200, 200, 210)),
                                          (11, 1.6, (200, 130, 70))), start=1):
        c.append(P(F, f"StatuePedestal{rank}", (x, 0.12 + h / 2, 25), (7, h, 7), color, "Marble",
                   tags=["MogStatue"], attributes={"Rank": rank}))
    for k, (x, z) in enumerate(((28, 28), (-28, 28), (28, -28), (-28, -28))):
        c += flowerbed(F, f"PlazaBed{k}", (x, 0.12, z), (8, 8))
        c += tree(F, f"PlazaTree{k}", (x, 0.92, z), height=7, radius=3.4, prop="TreeBlossom")
    # Le mentor mystérieux (D29) attend près du podium, tourné vers la fontaine
    c.append(P(F, "MentorSpot", (19, 0.22, 18), (1.6, 0.2, 1.6), WHITE, yaw=45, transparency=1, collide=False,
               tags=["MentorSpot"], extra={"CanQuery": False, "CanTouch": False}))
    # Le touriste perdu, et l'arrêt de bus de la place
    c.append(helper(F, "TouristSpot", (-12, 0.62, -20), "Directions", yaw=180))
    n0 = len(c)
    c.append(P(F, "Suitcase", (-7.5, 1.4, -21), (2.6, 2.6, 1.2), (60, 120, 170)))
    wrap(c, n0, F, "SuitcaseSlot", (-7.5, 0.12, -21), "Suitcase", yaw=200)
    c += bus_stop(F, "BusStopPlaza", (18, 0.12, -26), "Plaza", yaw=0)
    return c


def shop_frame(cx):
    """Boutique du côté nord du centre : façade sur le trottoir intérieur, tournée vers la route et les maisons."""
    return Frame((cx, GROUND, CENTER), 180)


def clothing_store():
    F = shop_frame(-78)
    c = shop_shell(F, "Clothes", (120, 170, 210), "Plaster", ((236, 230, 220), "Marble", 0.4))
    for k in range(7):  # auvent rayé
        c.append(P(F, f"ClothesAwning{k}", (-18 + k * 6, 13.6, -1.6), (6, 0.4, 3.2),
                   (60, 110, 200) if k % 2 == 0 else WHITE, "Fabric"))
    c.append(P(F, "SignShirt", (0, 20.5, 1), (7, 8, 1), (240, 90, 90)))
    for k, sx in enumerate((-1, 1)):
        c.append(P(F, f"SignSleeve{k}", (sx * 4.8, 22.7, 1), (3.4, 3.4, 1), (240, 90, 90)))
    for k, lz in enumerate((11, 27)):
        c.append(P(F, f"ClothesLamp{k}", (0, 15.4, lz), (12, 0.4, 2), (255, 244, 214), "Neon",
                   children=[light(brightness=0.9, range_=34)]))
    tops = [(240, 90, 90), (60, 110, 200), (250, 200, 60), (40, 40, 44), (120, 200, 120)]
    for r, lx in enumerate((-16, 16)):
        n0 = len(c)
        c.append(P(F, f"RackBar{r}", (lx, 6, 19), (0.4, 0.4, 16), (180, 180, 186), "Metal"))
        for k in range(6):
            c.append(P(F, f"Shirt{r}_{k}", (lx, 4.4, 13 + k * 2.4), (3, 3, 0.4), tops[(k + r) % 5], "Fabric",
                       yaw=90))
        wrap(c, n0, F, f"RackSlot{r}A", (lx, 0.4, 15), "ClothesRack", yaw=-90 if lx < 0 else 90)
        c.append(decor(F, f"RackSlot{r}B", (lx, 0.4, 23), "ClothesRack", yaw=-90 if lx < 0 else 90))
    # Vitrine : quatre mannequins de gabarits croissants portent les vrais articles (DisplayService)
    for k, (lx, stage, items) in enumerate(((-12.5, "GymRat", ("Hawaiian", "FluoShorts", "DumbbellShades")),
                                            (-4.5, "Bro", ("TrackJacket", "VelvetJoggers", "Sweatbands")),
                                            (4.5, "Alpha", ("BoxerRobe", "Headband")),
                                            (12.5, "Chad", ("MogTank", "LeatherPants", "GoldChain")))):
        c.append(style_display(F, f"ClothesDisplay{k}", (lx, 0.4, 7.5), stage, items))
    n0 = len(c)
    c.append(P(F, "ClothesCounter", (11, 1.9, 31), (12, 3.4, 2.4), WOOD_LIGHT, "WoodPlanks"))
    wrap(c, n0, F, "CounterSlot", (11, 0.4, 31), "ShopCounter")
    c.append(vendor(F, "ClothesVendor", (11, 0.4, 33.6), "VendorClothes", "Clothes", "Mirror", "Top,Bottom,Accessory"))
    for k, lx in enumerate((-12, 0)):
        c.append(mirror(F, f"ClothesMirror{k}", (lx, 5.5, 36.6), {"Categories": "Top,Bottom,Accessory", "Store": "Clothes"}))
    c.append(landmark(F, "ClothesIcon", (0, 30, 19), "Clothes"))
    return c


def barber():
    F = shop_frame(-30)
    c = shop_shell(F, "Barber", (250, 236, 220), "Plaster", ((40, 40, 44), "Marble", 0.4))
    n0 = len(c)
    for k in range(8):
        c.append(P(F, f"Pole{k}", (5.2, 2 + k * 0.9, -1.2), (0.9, 1, 1), [(220, 40, 40), WHITE, (40, 80, 200)][k % 3],
                   roll=90, shape="Cylinder"))
    c.append(P(F, "PoleTop", (5.2, 9.4, -1.2), (1.3, 1.3, 1.3), (230, 200, 60), "Metal", shape="Ball"))
    wrap(c, n0, F, "BarberPoleSlot", (5.2, 3.0, -0.4), "BarberPole", align="Back")
    for k, angle in enumerate((25, -25)):
        c.append(P(F, f"ScissorBlade{k}", (0, 18, 1), (1, 7, 0.6), (200, 205, 210), "Metal", roll=angle))
        c.append(P(F, f"ScissorRing{k}", (1.6 if k == 0 else -1.6, 14.4, 1), (0.6, 2, 2), (40, 40, 44),
                   shape="Cylinder", yaw=90))
    for k, lz in enumerate((10, 22)):
        c.append(P(F, f"BarberLamp{k}", (0, 13.4, lz), (10, 0.4, 2), (255, 244, 214), "Neon",
                   children=[light(brightness=0.85, range_=30)]))
    for k, lx in enumerate((-10, 0, 10)):  # fauteuils de barbier face au mur du fond
        n0 = len(c)
        c.append(P(F, f"ChairSeat{k}", (lx, 2, 25), (3, 0.8, 3), (180, 40, 40), "Fabric"))
        c.append(P(F, f"ChairBack{k}", (lx, 3.8, 23.6), (3, 3, 0.6), (180, 40, 40), "Fabric"))
        c.append(P(F, f"ChairFoot{k}", (lx, 0.9, 25), (1.4, 1, 1), (180, 180, 186), "Metal", shape="Cylinder",
                   roll=90))
        wrap(c, n0, F, f"BarberChairSlot{k}", (lx, 0.4, 25), "BarberChair", yaw=180)
        c.append(mirror(F, f"BarberMirror{k}", (lx, 6, 30.6), {"Categories": "Hair,Beard,Face", "Store": "Barber"}))
    c.append(P(F, "Sink", (-15.5, 2, 13), (2, 3.4, 4), WHITE))
    # Table des coupes : cinq têtes coiffées (et barbues) exposent les vrais articles (DisplayService)
    # (contre le mur de gauche, hors du passage entre la porte et les fauteuils)
    c.append(P(F, "BustTable", (-9.2, 1.7, 5), (12.6, 0.4, 2.6), WOOD_LIGHT, "WoodPlanks"))
    for k, lx in enumerate((-15, -3.4)):
        c.append(P(F, f"BustTableLeg{k}", (lx, 0.95, 5), (0.4, 1.1, 2), (60, 60, 66), "Metal"))
    for k, (lx, stage, items) in enumerate(((-14.4, "Bro", ("Banana", "Goatee")),
                                            (-11.8, "Alpha", ("Pompadour", "ChinStrap", "FrownBrows")),
                                            (-9.2, "Chad", ("Mohawk", "Handlebar")),
                                            (-6.6, "GymRat", ("Mullet", "LumberBeard")),
                                            (-4.0, "Gigachad", ("ShinyBald", "MegaJaw", "SparkleSmile")))):
        c.append(style_display(F, f"BarberBust{k}", (lx, 1.9, 5), stage, items, kind="Bust"))
    n0 = len(c)
    c.append(P(F, "WaitingSofa", (12, 1.4, 7), (8, 2, 3), (90, 60, 140), "Fabric"))
    wrap(c, n0, F, "WaitingSofaSlot", (12, 0.4, 7.5), "Furniture_BenchSofa", yaw=180)
    c.append(decor(F, "BarberPlantSlot", (-15.5, 0.4, 3.5), "Home_TallPlant"))
    c.append(vendor(F, "BarberVendor", (14.5, 0.4, 17), "VendorBarber", "Barber", "Mirror", "Hair,Beard,Face", yaw=-20))
    c.append(landmark(F, "BarberIcon", (0, 27, 16), "Barber"))
    return c


def furniture_store():
    F = shop_frame(36)
    c = shop_shell(F, "Furniture", (230, 200, 140), "Plaster", ((190, 150, 110), "WoodPlanks", 0.4))
    c.append(P(F, "SignSeat", (0, 18, 2), (9, 2, 5), (90, 140, 200), "Fabric"))
    c.append(P(F, "SignBack", (0, 21, 4), (9, 5, 1.4), (90, 140, 200), "Fabric"))
    for k, sx in enumerate((-1, 1)):
        c.append(P(F, f"SignArm{k}", (sx * 4.9, 19.5, 2.2), (1.2, 3, 5), (70, 120, 180), "Fabric"))
    for k, lz in enumerate((11, 27)):
        c.append(P(F, f"FurnitureLamp{k}", (0, 15.4, lz), (12, 0.4, 2), (255, 244, 214), "Neon",
                   children=[light(brightness=0.9, range_=36)]))
    n0 = len(c)
    c.append(P(F, "ShowSofa", (-14, 1.6, 15), (8, 2.4, 3.5), (200, 90, 60), "Fabric"))
    c.append(P(F, "ShowSofaBack", (-14, 3.4, 16.6), (8, 2.4, 0.8), (190, 80, 52), "Fabric"))
    wrap(c, n0, F, "ShowSofaSlot", (-14, 0.4, 15.5), "Furniture_LeopardSofa")
    n0 = len(c)
    c.append(P(F, "ShowRug", (-14, 0.45, 10), (9, 0.1, 6), (240, 200, 90), "Fabric"))
    wrap(c, n0, F, "ShowRugSlot", (-14, 0.4, 9), "Furniture_GoldRug", collide=False)
    n0 = len(c)
    c.append(P(F, "ShowBed", (14, 1.4, 15), (6, 2, 8), (240, 240, 245), "Fabric"))
    c.append(P(F, "ShowPillow", (14, 2.7, 18), (4, 0.8, 1.4), (120, 170, 230), "Fabric"))
    wrap(c, n0, F, "ShowBedSlot", (14, 0.4, 15), "Furniture_RaceCarBed")
    n0 = len(c)
    c.append(P(F, "ShowLampPole", (-6, 3.4, 24), (0.4, 6, 0.4), LAMP_GREY, "Metal"))
    c.append(P(F, "ShowLampShade", (-6, 6.8, 24), (2.4, 1.6, 2.4), (250, 220, 120), "Neon"))
    wrap(c, n0, F, "ShowLampSlot", (-6, 0.4, 24), "Furniture_DumbbellLamp")
    n0 = len(c)
    c.append(P(F, "ShowPlantPot", (6, 1.4, 24), (2, 2, 2), (190, 100, 60), "Concrete"))
    c.append(P(F, "ShowPlant", (6, 4, 24), (3, 3.6, 3), (80, 150, 70), "Grass", shape="Ball"))
    wrap(c, n0, F, "ShowPlantSlot", (6, 0.4, 24), "Furniture_ShakerPlant")
    c.append(decor(F, "ShowShelfSlot", (-22.1, 0.4, 28), "Home_Bookshelf", yaw=-90))
    c.append(decor(F, "ShowAquariumSlot", (21.8, 0.4, 24), "Home_Aquarium", yaw=90))
    c.append(decor(F, "ShowThroneSlot", (-16, 0.4, 30), "Furniture_ThroneSofa"))
    c.append(decor(F, "ShowScreenSlot", (16, 0.4, 35.9), "Furniture_GiantScreen"))
    c.append(decor(F, "ShowTvSlot", (21.6, 0.4, 10), "Furniture_TubeTv", yaw=90))
    c.append(decor(F, "ShowPosterSlot", (-22.9, 6.0, 12), "Furniture_NeonDumbbell", yaw=-90, collide=False,
                   align="Back"))
    c.append(P(F, "FurnitureCounter", (0, 2.1, 32), (14, 3.6, 2.6), WOOD, "WoodPlanks", tags=["FurnitureShop"]))
    c.append(P(F, "CounterTop", (0, 4, 32), (14.4, 0.3, 3), (60, 50, 44), "Marble"))
    c.append(vendor(F, "FurnitureVendor", (0, 0.4, 34.4), "VendorFurniture", "Furniture", "FurnitureShop"))
    c.append(landmark(F, "FurnitureIcon", (0, 32, 19), "Furniture"))
    return c


def grocery():
    F = shop_frame(82)
    c = shop_shell(F, "Grocery", (250, 240, 210), "Plaster", (WHITE, "SmoothPlastic", 0.3))
    for k in range(7):
        c.append(P(F, f"GroceryAwning{k}", (-15 + k * 5, 12.5, -1.6), (5, 0.4, 3.2),
                   (210, 50, 50) if k % 2 == 0 else WHITE, "Fabric"))
    for k, colr in enumerate(((220, 60, 50), (250, 200, 60), (120, 180, 60), (250, 140, 40))):
        lx = -14 + k * 3.4 if k < 2 else 8 + (k - 2) * 3.4
        c.append(P(F, f"Crate{k}", (lx, 1, 2.5), (3, 2, 2.4), WOOD, "WoodPlanks"))
        c.append(P(F, f"Fruit{k}", (lx, 2.3, 2.5), (2.6, 0.8, 2), colr))
    for k, lx in enumerate((-10, 0, 10)):
        n0 = len(c)
        c.append(P(F, f"Shelf{k}", (lx, 3, 19), (2.4, 6, 12), (200, 200, 205), "Metal"))
        wrap(c, n0, F, f"ShelfSlot{k}A", (lx - 0.72, 0.3, 16), "GroceryShelf", yaw=90)
        for j, (dx, lz, yaw) in enumerate(((-0.72, 22, 90), (0.72, 16, -90), (0.72, 22, -90))):
            c.append(decor(F, f"ShelfSlot{k}" + "BCD"[j], (lx + dx, 0.3, lz), "GroceryShelf", yaw=yaw))
    for k, lz in enumerate((10, 22)):
        c.append(P(F, f"GroceryLamp{k}", (0, 13.4, lz), (10, 0.4, 2), (255, 244, 214), "Neon",
                   children=[light(brightness=0.85, range_=30)]))
    c.append(P(F, "SignApple", (0, 17.5, 2), (5, 5, 5), (220, 40, 40), shape="Ball"))
    c.append(P(F, "SignStem", (0, 20.5, 2), (0.5, 1.6, 0.5), WOOD))
    c.append(P(F, "SignLeaf", (0.9, 20.5, 2), (1.6, 0.3, 0.9), (90, 170, 70)))
    c.append(landmark(F, "GroceryIcon", (0, 27, 16), "Grocery"))
    return c


GYM_STATIONS = {"BenchPress": (-34, 26), "Squat": (-34, 38), "PullUp": (14, 26), "JumpRope": (14, 38)}


def gym():
    """Salle de quartier (côté est) : façade sur la route, 3 exemplaires de chaque station pour 20 joueurs."""
    F = Frame((CENTER, GROUND, -54), -90)
    c = shop_shell(F, "Gym", BRICK, "Brick", ((58, 58, 64), "Rubber", 0.3))
    for i, lx in enumerate((-24, 0, 24)):
        for j, lz in enumerate((14, 34)):
            c.append(P(F, f"GymLamp{i}{j}", (lx, 19.4, lz), (10, 0.4, 1.4), (255, 244, 214), "Neon",
                       children=[light(brightness=0.6, range_=40)]))
    c.append(P(F, "SignBar", (0, 25, 6), (26, 1.2, 1.2), (180, 180, 186), "Metal", shape="Cylinder"))
    for k, dx in enumerate((-13, 13)):
        c.append(P(F, f"SignPlate{k}", (dx, 25, 6), (2, 9, 9), (40, 40, 44), "Metal", shape="Cylinder"))
    c.append(P(F, "GymAwning", (0, 16.8, -1.5), (22, 0.5, 3), (200, 40, 40), "Fabric"))
    for ex, (x0, lz) in GYM_STATIONS.items():
        for k in range(3):
            c.append(station(F, f"{ex}Station{k + 1}", (x0 + k * 10, 0.8, lz), ex))
    n0 = len(c)
    c.append(P(F, "CoachStage", (0, 0.8, 16), (16, 1, 12), (170, 40, 40), "Fabric"))
    wrap(c, n0, F, "CoachStageSlot", (0, 0.3, 16), "BossStage")
    c.append(spot(F, "CoachTurboSpot", (0, 1.8, 16), (8, 1, 8), SPOT_BOSS, "BossSpot", {"BossId": "CoachTurbo"}))
    c.append(P(F, "GymMirror", (0, 8, 46.8), (76, 10, 0.2), (200, 225, 240), "Glass", collide=False,
               extra={"Reflectance": 0.4}))
    for k in range(7):
        n0 = len(c)
        c.append(P(F, f"Rack{k}", (-36 + k * 12, 1.7, 45), (7, 2.8, 1.6), (70, 70, 76), "Metal"))
        wrap(c, n0, F, f"RackSlot{k}", (-36 + k * 12, 0.3, 45.4), "DumbbellRack")
    for k, lx in enumerate((-41.4, 41.4)):
        c.append(P(F, f"Banner{k}", (lx, 12, 24), (0.3, 9, 6), (250, 200, 40) if k else (60, 110, 200), "Fabric"))
    n0 = len(c)
    c.append(P(F, "PunchBag", (-30, 6, 10), (5, 2.4, 2.4), (150, 40, 40), "Fabric", shape="Cylinder", roll=90))
    c.append(P(F, "PunchBagChain", (-30, 13.5, 10), (0.3, 10, 0.3), (120, 120, 126), "Metal"))
    wrap(c, n0, F, "PunchBagSlot", (-30, 0.3, 10), "PunchingBag")
    # Équipement en plus (apparaît avec les modèles 3D) : tapis de course, vestiaires, fontaine à eau, toit
    for k, lx in enumerate((20, 26, 32)):
        c.append(decor(F, f"TreadmillSlot{k}", (lx, 0.3, 6.5), "Treadmill"))
    c.append(decor(F, "LockersSlot", (39.4, 0.3, 16), "Lockers", yaw=90))
    c.append(decor(F, "CoolerSlot", (-39.6, 0.3, 4), "WaterCooler", yaw=-90))
    c.append(decor(F, "TubSlot", (-39.4, 0.3, 18), "ProteinTub", yaw=-90))
    c.append(decor(F, "BallSlot", (-20, 0.3, 4), "MedicineBall"))
    c.append(decor(F, "KettlebellSlot", (-17.5, 0.3, 4.5), "Kettlebell"))
    c.append(decor(F, "PlatesSlot", (-39, 0.3, 32), "PlateStack"))
    c.append(decor(F, "TrophySlot", (39.4, 0.3, 30), "GoldTrophy", yaw=90))
    c.append(decor(F, "TankSlot", (28, 20.8, 34), "Kit_WaterTank"))
    for k, (lx, lz) in enumerate(((-24, 30), (0, 40))):
        c.append(decor(F, f"VentSlot{k}", (lx, 20.8, lz), "Kit_RoofVent"))
    c.append(landmark(F, "GymIcon", (0, 36, 24), "Gym"))
    return c


def park():
    """Parc (quart nord-ouest) : terrasse de bronzage de Brayan, piscine, cabane dans l'arbre."""
    F = Frame((0, GROUND, 0))
    c = [P(F, "ParkLawn", (-70, 0.05, 37), (64, 0.1, 50), PARK_GRASS, "Grass")]
    c.append(P(F, "ParkPath", (-70, 0.11, 37), (64, 0.12, 4), (214, 196, 160), "Ground"))
    c.append(P(F, "TanDeck", (-52, 0.4, 24), (16, 0.8, 14), WOOD_LIGHT, "WoodPlanks"))
    c.append(spot(F, "BrayanSpot", (-50, 1.3, 24), (8, 1, 8), SPOT_BOSS, "BossSpot", {"BossId": "Brayan"}, yaw=-90))
    n0 = len(c)
    c.append(P(F, "Lounger", (-57, 1.3, 21), (3, 1, 7), WHITE, "Fabric", yaw=70))
    wrap(c, n0, F, "LoungerSlot", (-57, 0.8, 21), "Lounger", yaw=70)
    n0 = len(c)
    c.append(P(F, "UmbrellaPole", (-57, 4, 28), (0.3, 8, 0.3), WHITE, "Metal"))
    c.append(P(F, "Umbrella", (-57, 8, 28), (0.6, 8, 8), (250, 170, 60), "Fabric", roll=90, shape="Cylinder"))
    wrap(c, n0, F, "UmbrellaSlot", (-57, 0.8, 28), "BeachUmbrella")
    for k, lz in enumerate((18, 30)):
        n0 = len(c)
        c.append(P(F, f"TanLamp{k}", (-43, 3, lz), (1, 6, 1), LAMP_GREY, "Metal"))
        c.append(P(F, f"TanLampHead{k}", (-43.8, 6.5, lz), (1.6, 1.6, 2.6), (255, 220, 120), "Neon",
                   children=[light((255, 200, 120), 2, 20)]))
        wrap(c, n0, F, f"TanLampSlot{k}", (-43, 0, lz), "TanningLamp", yaw=90)
    c.append(P(F, "PoolRim", (-84, 0.4, 50), (26, 0.8, 12), WHITE, "Concrete"))
    c.append(P(F, "PoolWater", (-84, 0.85, 50), (24, 0.2, 10), (70, 170, 230), "Glass", transparency=0.25,
               collide=False))
    n0 = len(c)
    c.append(P(F, "LifeguardChair", (-84, 4, 58.5), (2.4, 8, 2.4), WHITE, "WoodPlanks"))
    wrap(c, n0, F, "LifeguardChairSlot", (-84, 0.1, 58.8), "LifeguardChair")
    for k in range(4):
        c.append(P(F, f"ChairStack{k}", (-62, 0.6 + k * 0.7, 54), (3, 0.5, 5), (250, 120 + k * 25, 80), "Fabric",
                   yaw=k * 9))
    c.append(helper(F, "LifeguardSpot", (-64, 0.6, 46), "BeachChairs", yaw=-90))
    c += tree(F, "BigTree", (-94, 0, 22), height=12, radius=7)
    c.append(P(F, "Treehouse", (-94, 10, 22), (7, 5, 7), WOOD, "WoodPlanks"))
    c.append(W(F, "TreehouseRoof", (-94, 13.75, 22), (7.6, 2.5, 7.6), (160, 60, 50), "WoodPlanks"))
    c.append(P(F, "Ladder", (-89.8, 4.5, 22), (0.4, 9, 2), WOOD_LIGHT, "WoodPlanks"))
    c.append(helper(F, "KidSpot", (-82, 0.6, 22), "Nails", yaw=-90))
    for k, (x, z) in enumerate(((-100, 40), (-44, 58), (-72, 14))):
        c += tree(F, f"ParkTree{k}", (x, 0, z), height=8 + (k % 3), radius=4 + (k % 2))
    c.append(decor(F, "PicnicSlot", (-60, 0.1, 60), "PicnicTable"))
    c.append(decor(F, "FlowersSlot", (-70, 0.1, 30), "FlowerPatch", collide=False))
    c.append(decor(F, "TanningBedSlot", (-46, 0.1, 50), "TanningBed", yaw=180))
    c.append(decor(F, "ParkBinSlot", (-50, 0.1, 40), "TrashBin"))
    c.append(landmark(F, "ParkIcon", (-70, 26, 37), "Park"))
    return c


def boss_arena():
    """Arène des boss (quart sud-ouest) : Pas-Les-Jambes, le Roi du Quartier, temple du Dieu du Pump au fond."""
    F = Frame((0, GROUND, 0))
    c = [P(F, "ArenaFloor", (-70, 0.06, -70), (64, 0.12, 64), (196, 180, 170), "Pavement")]
    c.append(P(F, "ArenaCarpet", (-54, 0.14, -54), (6, 0.1, 34), (190, 30, 40), "Fabric", collide=False, yaw=45))
    n0 = len(c)
    c.append(P(F, "NoLegsStage", (-92, 0.6, -46), (12, 1, 12), (170, 40, 40), "Fabric"))
    wrap(c, n0, F, "NoLegsStageSlot", (-92, 0.1, -46), "BossStage", yaw=-90)
    c.append(spot(F, "NoLegsSpot", (-92, 1.6, -46), (8, 1, 8), SPOT_BOSS, "BossSpot", {"BossId": "NoLegs"},
                  yaw=-90))
    n0 = len(c)
    c.append(P(F, "KingStage", (-46, 0.6, -92), (16, 1, 16), (110, 40, 130), "Fabric"))
    wrap(c, n0, F, "KingStageSlot", (-46, 0.1, -92), "BossStage", yaw=180)
    c.append(spot(F, "BlockKingSpot", (-46, 1.6, -92), (8, 1, 8), SPOT_BOSS, "BossSpot", {"BossId": "BlockKing"},
                  yaw=180))
    T = Frame((-80, GROUND, -80), -135)
    c.append(P(T, "TempleStep", (0, 0.5, 0), (30, 1, 30), (225, 222, 212), "Marble"))
    c.append(P(T, "TempleBase", (0, 1.5, 0), (26, 1, 26), (235, 232, 222), "Marble"))
    for i, (dx, dz) in enumerate(((-11, -11), (11, -11), (-11, 11), (11, 11), (0, 11))):
        n0 = len(c)
        c.append(P(T, f"Column{i}", (dx, 11, dz), (18, 3, 3), (240, 238, 230), "Marble", roll=90, shape="Cylinder"))
        wrap(c, n0, T, f"ColumnSlot{i}", (dx, 2.0, dz), "GreekColumn", height=18.5)
    c.append(P(T, "TempleTop", (0, 20.75, 0), (28, 1.5, 28), (225, 200, 120), "Marble"))
    c.append(W(T, "Pediment", (0, 23, -12), (28, 3, 4), (225, 200, 120), "Marble"))
    c.append(spot(T, "PumpGodSpot", (0, 2.5, 0), (14, 1, 14), (230, 180, 40), "BossSpot", {"BossId": "PumpGod"},
                  material="Marble"))
    c.append(landmark(T, "ArenaIcon", (0, 32, 0), "Arena"))
    # Ambiance de match (apparaît avec les modèles 3D) : projecteurs, gong, cordons, trophées des boss
    c.append(decor(F, "SpotlightSlot0", (-100, 0.12, -40), "Spotlight", yaw=-45))
    c.append(decor(F, "SpotlightSlot1", (-40, 0.12, -100), "Spotlight", yaw=135))
    c.append(decor(F, "GongSlot", (-102, 0.12, -64), "Gong", yaw=-90))
    for k, (along, side) in enumerate(((-8, 1), (8, 1), (-8, -1), (8, -1))):
        x = -54 + along * 0.707 + side * 3.0
        z = -54 + along * 0.707 - side * 3.0
        c.append(decor(F, f"RopeSlot{k}", (x, 0.12, z), "StanchionRope", yaw=-45))
    c.append(decor(F, "CrownSlot", (-60, 0.12, -98), "CrownCushion", yaw=135))
    c.append(decor(F, "SocksSlot", (-92, 0.1, -36), "GiantSocks"))
    return c


def downtown():
    c = plaza() + clothing_store() + barber() + furniture_store() + grocery() + gym() + park() + boss_arena()
    F = Frame((0, GROUND, 0))
    walk = sum(WALK_IN) / 2
    # Habitants devant les boutiques, sur le trottoir intérieur (face à la route)
    c.append(helper(F, "CourierSpot", (-52, WALK_TOP + 0.5, walk), "PumpTire", yaw=180))
    n0 = len(c)
    c.append(P(F, "BikeFrame", (-47, 1.8 + WALK_TOP, walk), (0.4, 1.4, 4), (40, 160, 90), "Metal"))
    for k, dz in enumerate((-1.6, 1.6)):
        c.append(P(F, f"BikeWheel{k}", (-47, 1.4 + WALK_TOP, walk + dz), (0.3, 2.4, 2.4), (30, 30, 34),
                   shape="Cylinder"))
    wrap(c, n0, F, "BikeSlot", (-47, WALK_TOP, walk), "Bicycle")
    c.append(helper(F, "PianoSpot", (52, WALK_TOP + 0.5, walk), "Piano", yaw=180))
    n0 = len(c)
    c.append(P(F, "Piano", (46, 2.3 + WALK_TOP, walk), (5, 4.4, 2.4), (20, 20, 22)))
    c.append(P(F, "PianoKeys", (46, 3.1 + WALK_TOP, walk + 1.4), (4.6, 0.3, 0.6), (240, 240, 235)))
    wrap(c, n0, F, "PianoSlot", (46, WALK_TOP, walk - 0.6), "UprightPiano", yaw=180)
    c.append(helper(F, "GrocerSpot", (70, WALK_TOP + 0.5, walk), "Groceries", yaw=180))
    # Petits squares à l'intérieur (nord-est et sud-est)
    for k, (x, z) in enumerate(((40, 40), (80, 30), (60, 52), (8, -52), (40, -80), (20, -94))):
        c += tree(F, f"SquareTree{k}", (x, 0, z), height=8 + (k % 3), radius=4 + (k % 2))
    c += flowerbed(F, "SquareBedNE", (70, 0, 44), (10, 10))
    # Salle de sport en plein air : 8 machines de plus, pour que les joueurs ne se marchent pas dessus
    c.append(P(F, "OutdoorGymMat", (33, 0.06, -56), (40, 0.12, 30), (46, 46, 52), "Rubber"))
    for k, (ex, x, z) in enumerate((("Curl", 18, -49), ("PushUp", 28, -49), ("BenchPress", 38, -49),
                                    ("Squat", 48, -49), ("PullUp", 18, -63), ("JumpRope", 28, -63),
                                    ("Curl", 38, -63), ("PushUp", 48, -63))):
        c.append(station(F, f"Outdoor{ex}Station{k}", (x, 0.62, z), ex, yaw=180))
    c += bench(F, "SquareBenchNE", (56, 0, 30), yaw=0)
    # Kevin « je commence demain » : un seul pour toute la ville, affalé sur son canapé juste à côté de la salle
    K = Frame((73, GROUND, 22), 90)  # regarde vers la place
    c.append(P(K, "KevinRug", (0, 0.05, -1), (12, 0.1, 12), (150, 120, 90), "Fabric", collide=False))
    c.append(spot(K, "KevinSpot", (0, 0.6, -4), (8, 1, 8), SPOT_BOSS, "BossSpot", {"BossId": "Kevin"}))
    n0 = len(c)
    c.append(P(K, "KevinCouchSeat", (0, 1.2, 2.5), (11, 2.4, 4), (122, 82, 62), "Fabric"))
    c.append(P(K, "KevinCouchBack", (0, 3.3, 4.3), (11, 2.6, 1), (112, 74, 56), "Fabric"))
    for k, lx in enumerate((-6, 6)):
        c.append(P(K, f"KevinCouchArm{k}", (lx, 2.3, 2.5), (1, 2.2, 4), (112, 74, 56), "Fabric"))
    wrap(c, n0, K, "KevinCouchSlot", (0, 0.1, 3), "Furniture_SaggyCouch")
    for k, (lx, ly, yaw) in enumerate(((-3, 2.55, 20), (7.5, 0.25, -10), (7.6, 0.55, 15), (7.4, 0.85, 40))):
        c.append(P(K, f"KevinPizza{k}", (lx, ly, 2 if k == 0 else 0), (2.6, 0.3, 2.6), CARDBOARD, "Cardboard",
                   yaw=yaw))
    # Sa vieille télé, sur le côté, tournée vers le canapé
    n0 = len(c)
    c.append(P(K, "KevinTvStand", (-9, 1, -3), (1.6, 2, 5), WOOD, "WoodPlanks"))
    c.append(P(K, "KevinTv", (-9, 3.4, -3), (2, 2.8, 4), (60, 60, 64)))
    c.append(P(K, "KevinTvScreen", (-7.95, 3.4, -3), (0.1, 2.2, 3.4), (110, 160, 210), "Neon", collide=False))
    wrap(c, n0, K, "KevinTvSlot", (-9, 0.1, -3), "Furniture_TubeTv", yaw=-90)
    # Aire de jeux et terrain de basket (nord-est), camion à shakes et terrasse (sud-est) : modèles 3D seulement
    c.append(decor(F, "SwingSlot", (45, 0, 54), "SwingSet"))
    c.append(decor(F, "SlideSlot", (30, 0, 58), "PlaygroundSlide", yaw=90))
    c.append(decor(F, "HoopSlot", (92, 0, 60), "BasketballHoop"))
    c.append(decor(F, "ShakeTruckSlot", (46, 0, -88), "ShakeTruck", yaw=90))
    c.append(decor(F, "CafeSlot", (44, 0, -30), "CafeSet"))
    c.append(decor(F, "VendingSlot", (106.2, WALK_TOP, -66), "ShakeVendingMachine", yaw=-90))
    # Boosts (D47) : on les achète au camion à shakes et au distributeur (tag BoostShop, BoostService)
    for k, pos in enumerate(((40, 3, -88), (103.4, WALK_TOP + 3, -66))):
        c.append(P(F, f"BoostShop{k}", pos, (2, 6, 4), WHITE, transparency=1, collide=False, tags=["BoostShop"],
                   extra={"CanTouch": False}))
    # La voiture du voisin, en panne sur la route ouest ; le voisin attend sur le trottoir
    c += car(F, "NeighborCar", (-ROAD[0] - 5, 0.15, -40), (200, 60, 50), yaw=90)
    c.append(helper(F, "NeighborSpot", (-walk, WALK_TOP + 0.5, -32), "PushCar", yaw=90))
    return folder("Downtown", c)

# ------------------------------------------------------------------ écriture
if __name__ == "__main__":
    out = os.path.join(WORLD, "Map")
    written = set()
    for i, (side, offset) in enumerate(plot_list(), start=1):
        path = os.path.join(out, "Plots", f"Plot{i:02d}.model.json")
        write(path, plot(i, side, offset))
        written.add(os.path.normpath(path))
    for node in (ring(), downtown()):
        path = os.path.join(out, "Town", f"{node['name']}.model.json")
        write(path, node)
        written.add(os.path.normpath(path))
    # Supprime seulement les anciens fichiers qui ne sont plus générés (jamais le dossier entier)
    for dirpath, _, files in os.walk(out):
        for name in files:
            path = os.path.normpath(os.path.join(dirpath, name))
            if path not in written:
                os.remove(path)
    print("Muscle City générée :", len(plot_list()), "maisons")

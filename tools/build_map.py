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
import json, math, os, random

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
WORLD = os.path.join(ROOT, "world")
TEMPLATES = os.path.join(os.path.dirname(os.path.abspath(__file__)), "map_templates")
GROUND = 0.1  # dessus du sol herbeux (la Baseplate, à y = 0, est cachée dessous)


# ------------------------------------------------------------------ maths
def rot(yaw=0.0, roll=0.0, pitch=0.0):
    """Matrice de rotation (lignes) : Ry(yaw) * Rz(roll) * Rx(pitch), angles en degrés.
    pitch > 0 relève le bout -Z (l'avant) de la pièce."""
    y, r = math.radians(yaw), math.radians(roll)
    cy, sy, cr, sr = math.cos(y), math.sin(y), math.cos(r), math.sin(r)
    ry = [[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]]
    rz = [[cr, -sr, 0], [sr, cr, 0], [0, 0, 1]]
    m = [[sum(ry[i][k] * rz[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
    if pitch:
        a = math.radians(pitch)
        m = mul(m, [[1, 0, 0], [0, math.cos(a), -math.sin(a)], [0, math.sin(a), math.cos(a)]])
    return [[round(m[i][j], 6) for j in range(3)] for i in range(3)]


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
         transparency=0, children=None, extra=None, tags=None, attributes=None, pitch=0):
    props = {
        "Anchored": True,
        "Size": [round(s, 3) for s in size],
        "CFrame": {"CFrame": {"position": [round(p, 3) for p in pos], "orientation": rot(yaw, roll, pitch)}},
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


def vendor(F, name, local, npc, store, tag, categories=None, yaw=0, title=None):
    """Vendeur d'un magasin (tag VendorSpot, décision D38) : VendorService y fait apparaître le PNJ `npc`.
    Il porte le tag `tag` du point de vente (Mirror, FurnitureShop ou BoostShop) : lui parler ouvre la même boutique.
    `title` : clé de Texts affichée sur le bouton du point de vente (à la place du nom par défaut)."""
    attributes = {"Npc": npc, "Store": store, "Tag": tag}
    if categories:
        attributes["Categories"] = categories
    if title:
        attributes["TitleKey"] = title
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
SHOP_BACK_DOOR_WIDTH = {"Gym": 10}  # = props_building.BACK_DOORS (porte au milieu du mur du fond, D69)
# = props_building.SHOPS : hauteur du toit, hauteur de la porte, vitrines (x, largeur, bas, haut)
SHOP_HEIGHT = {"Clothes": 16, "Barber": 14, "Furniture": 16, "Grocery": 14, "Gym": 20}
SHOP_DOOR_HEIGHT = {"Clothes": 10, "Barber": 9, "Furniture": 11, "Grocery": 9, "Gym": 13}
SHOP_WINDOWS = {
    "Clothes": ((-13.5, 12, 2.5, 11), (13.5, 12, 2.5, 11)),
    "Barber": ((-10.5, 9, 3, 9.5), (10.5, 9, 3, 9.5)),
    "Furniture": ((-15, 14, 2.5, 12), (15, 14, 2.5, 12)),
    "Grocery": ((-11, 10, 2.5, 9), (11, 10, 2.5, 9)),
    "Gym": ((-26, 16, 3, 12), (26, 16, 3, 12)),
}
# Rayures des auvents au-dessus des vitrines (couleur de l'enseigne et blanc)
SHOP_AWNINGS = {"Clothes": ((60, 110, 200), WHITE), "Barber": ((200, 45, 45), WHITE),
                "Furniture": ((40, 60, 110), (240, 226, 196)), "Grocery": ((60, 150, 70), WHITE),
                "Gym": ((170, 30, 30), (40, 40, 44))}


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
    ] + back_doors(F, name, d, ft) + shop_dressing(F, name)


def awning(F, name, x, width, top, colors, depth=3.6, slope=24):
    """Auvent rayé incliné au-dessus d'une vitrine : bandes de toile en pente vers la rue et lambrequin."""
    out = []
    n = max(3, round(width / 1.6))
    stripe = width / n
    a = math.radians(slope)
    cz, cy = -depth / 2 * math.cos(a), top - depth / 2 * math.sin(a)
    for k in range(n):
        lx = x - width / 2 + stripe * (k + 0.5)
        colr = colors[k % 2]
        out.append(P(F, f"{name}{k}", (lx, cy, cz), (stripe + 0.02, 0.2, depth), colr, "Fabric", pitch=-slope,
                     collide=False))
        out.append(P(F, f"{name}Flap{k}", (lx, top - depth * math.sin(a) - 0.4, -depth * math.cos(a)),
                     (stripe + 0.02, 0.8, 0.12), colr, "Fabric", collide=False))
    for k, sx in enumerate((-1, 1)):  # deux tiges de fer qui le tiennent
        out.append(P(F, f"{name}Rod{k}", (x + sx * (width / 2 - 0.4), cy - 0.5, cz), (0.15, 0.15, depth),
                     LAMP_GREY, "Metal", pitch=-slope - 14, collide=False))
    return out


def planter(F, name, local, color=(150, 96, 70), flowers=((240, 90, 120), (250, 210, 70), (250, 250, 250))):
    """Jardinière en bois : buis taillé en boule et quelques fleurs."""
    x, y, z = local
    out = [
        P(F, name, (x, y + 0.8, z), (2.6, 1.6, 1.6), color, "WoodPlanks"),
        P(F, name + "Soil", (x, y + 1.62, z), (2.3, 0.1, 1.3), (80, 56, 40), "Ground", collide=False),
        P(F, name + "Bush", (x, y + 2.4, z), (1.9, 1.9, 1.9), HEDGE, "Grass", shape="Ball", collide=False),
    ]
    for k, colr in enumerate(flowers):
        out.append(P(F, f"{name}Flower{k}", (x - 1.0 + k * 1.0, y + 1.9, z - 0.55), (0.5, 0.5, 0.5), colr,
                     shape="Ball", collide=False))
    return out


def ac_unit(F, name, local, yaw=0):
    """Climatiseur de toit : caisson, ventilateur, grilles et socle."""
    G = F.child(local, yaw)
    out = [
        P(G, name + "Base", (0, 0.15, 0), (4.4, 0.3, 3.4), TIN_DARK, "Metal"),
        P(G, name, (0, 1.5, 0), (4, 2.4, 3), TIN, "Metal"),
        P(G, name + "Fan", (0.6, 2.75, 0), (0.12, 2.2, 2.2), TIN_DARK, "Metal", roll=90, shape="Cylinder"),
        P(G, name + "Hub", (0.6, 2.8, 0), (0.15, 0.6, 0.6), LAMP_GREY, "Metal", roll=90, shape="Cylinder"),
    ]
    for k in range(4):
        out.append(P(G, f"{name}Grille{k}", (-1.4 + k * 0.35, 1.5, -1.55), (0.12, 1.8, 0.1), TIN_DARK, "Metal"))
    return out


def roof_vent(F, name, local, height=1.8):
    x, y, z = local
    return [
        P(F, name, (x, y + height / 2, z), (height, 0.8, 0.8), (190, 192, 196), "Metal", roll=90, shape="Cylinder"),
        P(F, name + "Cap", (x, y + height + 0.15, z), (0.3, 1.3, 1.3), (160, 162, 168), "Metal", roll=90,
          shape="Cylinder"),
    ]


def skylight(F, name, local, size=(6, 4)):
    x, y, z = local
    w, d = size
    return [
        P(F, name, (x, y + 0.35, z), (w, 0.7, d), (58, 58, 64), "Metal"),
        P(F, name + "Glass", (x, y + 0.75, z), (w - 0.6, 0.12, d - 0.6), GLASS, "Glass",
          extra={"Reflectance": 0.3}),
    ]


def shop_dressing(F, name):
    """Habillage d'un magasin (D97) : auvents rayés sur les vitrines, jardinières de part et d'autre de la porte,
    appliques allumées la nuit, fausses fenêtres sur les côtés et toit équipé (climatiseurs, aérations, verrière)."""
    w, d = SHOP_DIMS[name]
    h, dh, dw = SHOP_HEIGHT[name], SHOP_DOOR_HEIGHT[name], SHOP_DOOR_WIDTH[name]
    c = []
    for k, (x, ww, y0, y1) in enumerate(SHOP_WINDOWS[name]):
        c += awning(F, f"{name}Awning{k}_", x, ww + 1.2, y1 + 1.5, SHOP_AWNINGS[name])
    for k, sx in enumerate((-1, 1)):
        c += planter(F, f"{name}Planter{k}", (sx * (dw / 2 + 3.2), 0, -1.4))
        # Les appliques de la façade (modèle 3D) éclairent le trottoir la nuit
        c.append(P(F, f"{name}Sconce{k}", (sx * (dw / 2 + 1.2), dh + 2.7, -1.7), (0.3, 0.3, 0.3), WHITE,
                   transparency=1, collide=False, tags=["StreetLight"], extra={"CanQuery": False, "CanTouch": False},
                   children=[light((255, 214, 160), 1.2, 16)]))
        # Fausses fenêtres sur les murs de côté (cadre sombre, vitre, appui)
        for j, fz in enumerate((d * 0.3, d * 0.7)):
            G = F.child((sx * (w / 2 + 0.12), 0, fz), -90 * sx)
            wy = h * 0.55
            c += [
                P(G, f"{name}SideFrame{k}{j}", (0, wy, 0), (5.6, 5.6, 0.2), (58, 58, 64), "Metal", collide=False),
                P(G, f"{name}SideGlass{k}{j}", (0, wy, -0.08), (4.8, 4.8, 0.08), GLASS, "Glass", collide=False,
                  extra={"Reflectance": 0.2}),
                P(G, f"{name}SideBar{k}{j}", (0, wy, -0.14), (0.25, 4.8, 0.08), (58, 58, 64), "Metal",
                  collide=False),
                P(G, f"{name}SideSill{k}{j}", (0, wy - 3.0, -0.25), (6.2, 0.3, 0.6), TRIM, collide=False),
            ]
    # Toit plat (dessus à h + 0,6) : rien au milieu (l'icône de la boutique flotte au-dessus)
    top = h + 0.6
    c.append(P(F, f"{name}RoofDeck", (0, top + 0.03, d / 2), (w - 2, 0.06, d - 2), (128, 128, 132), "Slate"))
    c += ac_unit(F, f"{name}AcA", (w * 0.28, top, d * 0.62), yaw=15)
    c += roof_vent(F, f"{name}VentA", (-w * 0.12, top, d * 0.78))
    c += roof_vent(F, f"{name}VentB", (w * 0.36, top, d * 0.25), height=1.3)
    if w >= 40:
        c += ac_unit(F, f"{name}AcB", (-w * 0.3, top, d * 0.35), yaw=-10)
        c += skylight(F, f"{name}Skylight", (-w * 0.26, top, d * 0.72))
    else:
        c.append(P(F, f"{name}Hatch", (-w * 0.28, top + 0.3, d * 0.6), (3, 0.6, 3), TIN_DARK, "Metal"))
    return c


def back_doors(F, name, d, ft):
    """Deux battants dans l'ouverture du mur du fond, s'il y en a une (props_building.BACK_DOORS)."""
    bw = SHOP_BACK_DOOR_WIDTH.get(name)
    if not bw:
        return []
    return [
        auto_door(F, name + "BackDoorLeft", (-bw / 4, ft, d - 0.4), f"Door_Shop_{name}Back"),
        auto_door(F, name + "BackDoorRight", (bw / 4, ft, d - 0.4), f"Door_Shop_{name}Back", yaw=180),
    ]


def wrap(c, n0, F, name, local, prop, yaw=0, height=None, collide=True, align=None):
    """Range les blocs ajoutés à `c` depuis l'index n0 dans un emplacement de décor."""
    blocks = c[n0:]
    del c[n0:]
    c.append(prop_slot(F, name, local, prop, blocks, yaw=yaw, height=height, collide=collide, align=align))


def decor(F, name, local, prop, yaw=0, height=None, collide=True, align=None):
    """Décor 3D sans version en blocs : invisible tant que le modèle n'est pas importé."""
    return prop_slot(F, name, local, prop, (), yaw=yaw, height=height, collide=collide, align=align)


# Portail du Colisée (D105, tools/blender/props_portal.py) : l'arche est posée à PORTAL_HEIGHT studs de haut ;
# l'ouverture fait alors PORTAL_OPENING (largeur, hauteur utile) et commence à PORTAL_SILL du sol. Le repère invisible
# (tag ColosseumPortal) a exactement la taille de l'ouverture : le jeu y met son invite et y dessine le tourbillon.
PORTAL_HEIGHT = 11
PORTAL_OPENING = (4.1, 8.2)
PORTAL_SILL = 0.73


def colosseum_portal(F, name, local, yaw, target):
    x, y, z = local
    w, h = PORTAL_OPENING
    return [
        decor(F, name + "Arch", local, "Colosseum_Portal", yaw=yaw, height=PORTAL_HEIGHT),
        P(F, name, (x, y + PORTAL_SILL + h / 2, z), (w, h, 1), WHITE, yaw=yaw, transparency=1, collide=False,
          tags=["ColosseumPortal"], attributes={"Target": target}, extra={"CanTouch": False}),
    ]


# ------------------------------------------------------------------ détails de finition (D101)
GOLD_TRIM = (206, 156, 44)


def vec3(v):
    return {"Vector3": [round(x, 3) for x in v]}


def bed(F, name, local, width, depth=1.6, k=0):
    """Massif fleuri bordé de briques : terre, trois buis et des fleurs de couleurs variées entre eux."""
    x, y, z = local
    out = [
        P(F, name, (x, y + 0.25, z), (width, 0.5, depth), (150, 72, 60), "Brick", collide=False),
        P(F, name + "Soil", (x, y + 0.52, z), (width - 0.4, 0.1, depth - 0.4), (80, 56, 40), "Ground", collide=False),
    ]
    colors = ((240, 90, 120), (250, 210, 70), (250, 250, 250), (200, 120, 230), (250, 150, 60))
    for j, dx in enumerate((-width / 3, 0, width / 3)):
        out.append(P(F, f"{name}Shrub{j}", (x + dx, y + 1.15, z), (1.4, 1.4, 1.4), HEDGE, "Grass", shape="Ball",
                     collide=False))
    for j, dx in enumerate((-width / 2 + 0.7, -width / 6, width / 6, width / 2 - 0.7)):
        out.append(P(F, f"{name}Flower{j}", (x + dx, y + 0.85, z - 0.2), (0.6, 0.6, 0.6), colors[(j + k) % 5],
                     shape="Ball", collide=False))
    return out


def gnome(F, name, local, yaw=0, hat=(220, 40, 40), coat=(60, 110, 200)):
    """Nain de jardin qui soulève un haltère au-dessus de sa tête (l'humour gym bro jusque dans les jardins)."""
    G = F.child(local, yaw)
    skin, dark = (240, 200, 170), (70, 50, 40)
    out = [
        P(G, name + "Boots", (0, 0.2, 0), (0.9, 0.3, 0.6), dark, collide=False),
        P(G, name + "Body", (0, 0.9, 0), (1.1, 0.95, 0.95), coat, roll=90, shape="Cylinder", collide=False),
        P(G, name + "Belt", (0, 0.75, 0), (0.15, 1.0, 1.0), (40, 40, 40), roll=90, shape="Cylinder", collide=False),
        P(G, name + "Head", (0, 1.8, 0), (0.8, 0.8, 0.8), skin, shape="Ball", collide=False),
        P(G, name + "Nose", (0, 1.78, -0.4), (0.28, 0.28, 0.28), (240, 150, 140), shape="Ball", collide=False),
        P(G, name + "Beard", (0, 1.5, -0.2), (0.75, 0.75, 0.75), WHITE, shape="Ball", collide=False),
        P(G, name + "Hat", (0, 2.3, 0), (0.5, 0.82, 0.82), hat, roll=90, shape="Cylinder", collide=False),
        P(G, name + "HatTip", (0, 2.7, 0), (0.45, 0.5, 0.5), hat, roll=90, shape="Cylinder", collide=False),
        P(G, name + "HatBall", (0, 3.0, 0), (0.3, 0.3, 0.3), hat, shape="Ball", collide=False),
        P(G, name + "Bar", (0, 3.45, 0), (2.0, 0.14, 0.14), LAMP_GREY, "Metal", shape="Cylinder", collide=False),
    ]
    for sx in (-1, 1):
        out += [
            P(G, f"{name}Arm{sx}", (sx * 0.5, 2.6, 0), (0.26, 1.3, 0.26), coat, collide=False),
            P(G, f"{name}Plate{sx}", (sx * 0.85, 3.45, 0), (0.25, 0.75, 0.75), (40, 40, 44), "Metal",
              shape="Cylinder", collide=False),
        ]
    return out


def clothesline(F, name, local, colors):
    """Corde à linge du jardin : deux poteaux, une corde et des débardeurs de sport qui sèchent."""
    x, y, z = local
    out = []
    for sx in (-1, 1):
        out.append(P(F, f"{name}Post{sx}", (x + sx * 6, y + 3, z), (0.3, 6, 0.3), WOOD, "Wood"))
    out.append(P(F, name + "Rope", (x, y + 5.8, z), (12, 0.08, 0.08), WHITE, collide=False))
    for j, colr in enumerate(colors):
        lx = x - 3.6 + j * 3.6
        out.append(P(F, f"{name}Tank{j}", (lx, y + 4.9, z), (1.5, 1.8, 0.1), colr, "Fabric", collide=False))
        out.append(P(F, f"{name}Strap{j}", (lx, y + 5.65, z), (0.9, 0.3, 0.12), colr, "Fabric", collide=False))
    return out


def torch(F, name, local, height=5.0):
    """Torche sur pied : poteau, coupe en métal et feu (tag ColosseumFire : flammes et lumière côté client)."""
    x, y, z = local
    return [
        P(F, name + "Foot", (x, y + 0.2, z), (1.3, 0.4, 1.3), (50, 46, 44), "Metal"),
        P(F, name, (x, y + height / 2, z), (height, 0.45, 0.45), (60, 54, 50), "Metal", roll=90, shape="Cylinder"),
        P(F, name + "Cup", (x, y + height + 0.25, z), (0.6, 1.8, 1.8), (70, 62, 56), "Metal", roll=90,
          shape="Cylinder"),
        P(F, name + "Fire", (x, y + height + 0.9, z), (1, 1, 1), WHITE, transparency=1, collide=False,
          tags=["ColosseumFire"], extra=INVISIBLE),
    ]


def ceiling_fan(F, name, local, speed=3.0):
    """Ventilateur de plafond : tige, moyeu et 4 pales ; les pièces tagguées Spinner tournent côté client
    (AmbienceController) autour de leur attribut SpinCenter."""
    x, y, z = local
    center = vec3(F.p(local))
    spin = {"SpinCenter": center, "SpinSpeed": speed}
    out = [
        P(F, name + "Rod", (x, y + 0.6, z), (0.2, 1.2, 0.2), LAMP_GREY, "Metal", collide=False),
        P(F, name + "Hub", (x, y, z), (0.5, 1.1, 1.1), (200, 200, 205), "Metal", roll=90, shape="Cylinder",
          collide=False),
    ]
    for i in range(4):
        G = F.child(local, i * 90)
        out.append(P(G, f"{name}Blade{i}", (1.9, 0, 0), (2.8, 0.1, 0.8), WOOD_LIGHT, "WoodPlanks", collide=False,
                     tags=["Spinner"], attributes=spin))
    return out


def water_basin(F, name, local, size, height=1.0, rim=0.7, rim_color=(240, 236, 226), lilies=0, water=None):
    """Bassin rempli de vraie eau (Terrain, tag WaterVolume) : fond, margelle de pierre, nénuphars.
    L'eau Terrain se pose par cubes de 4 studs alignés sur le monde : bassin non tourné seulement, et `water`
    (largeur, profondeur du volume d'eau) choisi pour que les cubes du bord soient pleins sous la margelle."""
    x, y, z = local
    w, d = size
    ww, wd = water or (w + rim * 0.6, d + rim * 0.6)
    out = [
        P(F, name + "Floor", (x, y + 0.05, z), (w, 0.1, d), (46, 110, 120), "Slate"),
        P(F, name + "Water", (x, y + height / 2 + 0.05, z), (ww, height - 0.25, wd),
          (90, 170, 230), transparency=1, collide=False, tags=["WaterVolume"], extra=INVISIBLE),
    ]
    for sx in (-1, 1):
        out.append(P(F, f"{name}RimX{sx}", (x + sx * (w + rim) / 2, y + height / 2, z), (rim, height, d + 2 * rim),
                     rim_color, "Limestone"))
        out.append(P(F, f"{name}RimZ{sx}", (x, y + height / 2, z + sx * (d + rim) / 2), (w, height, rim), rim_color,
                     "Limestone"))
    for j in range(lilies):
        lx = x + (j - (lilies - 1) / 2) * w / max(lilies, 1) * 0.8
        lz = z + (0.25 if j % 2 else -0.25) * d
        out.append(P(F, f"{name}Lily{j}", (lx, y + height - 0.18, lz), (0.08, 1.4, 1.4), (70, 150, 70), "Grass",
                     roll=90, shape="Cylinder", collide=False))
        if j % 2 == 0:
            out.append(P(F, f"{name}LilyFlower{j}", (lx + 0.2, y + height - 0.05, lz), (0.45, 0.45, 0.45),
                         (250, 180, 210), shape="Ball", collide=False))
    return out


def citrus_pot(F, name, local, k=0):
    """Citronnier dans une grande jarre de terre cuite (jardin romain)."""
    x, y, z = local
    clay = (196, 110, 70)
    out = [
        P(F, name + "Pot", (x, y + 1.0, z), (2.0, 2.4, 2.4), clay, "Brick", roll=90, shape="Cylinder"),
        P(F, name + "PotRim", (x, y + 2.05, z), (0.3, 2.7, 2.7), (176, 96, 60), "Brick", roll=90, shape="Cylinder"),
        P(F, name + "Soil", (x, y + 2.1, z), (0.1, 2.2, 2.2), (80, 56, 40), "Ground", roll=90, shape="Cylinder",
          collide=False),
        P(F, name + "Trunk", (x, y + 3.3, z), (2.6, 0.4, 0.4), (110, 78, 50), "Wood", roll=90, shape="Cylinder",
          collide=False),
        P(F, name + "Leaves", (x, y + 5.2, z), (3.6, 3.6, 3.6), (52, 110, 56), "Grass", shape="Ball", collide=False),
    ]
    for j in range(5):
        a = math.radians(j * 72 + k * 23)
        out.append(P(F, f"{name}Lemon{j}", (x + math.sin(a) * 1.55, y + 5.0 + (j % 2) * 0.8, z + math.cos(a) * 1.55),
                     (0.5, 0.5, 0.5), (250, 220, 60), shape="Ball", collide=False))
    return out


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
    # Jardinières fleuries sous les deux fenêtres de la façade (D97)
    for k, wx in enumerate((-8, 8)):
        c.append(P(H, f"WindowBox{k}", (wx, 3.3, -0.75), (5.6, 0.9, 1.0), (150, 96, 70), "WoodPlanks",
                   collide=False))
        c.append(P(H, f"WindowBoxLeaves{k}", (wx, 3.85, -0.75), (5.2, 0.4, 0.8), HEDGE, "Grass", collide=False))
        for j in range(5):
            colr = ((240, 90, 120), (250, 210, 70), (250, 250, 250), (200, 120, 230))[(j + k + index) % 4]
            c.append(P(H, f"WindowFlower{k}{j}", (wx - 2.2 + j * 1.1, 4.15, -0.85), (0.5, 0.5, 0.5), colr,
                       shape="Ball", collide=False))
    # Massifs fleuris le long de la façade, de part et d'autre du porche, et lumière du porche la nuit (D101)
    for k, sx in enumerate((-1, 1)):
        c += bed(H, f"FrontBed{k}", (sx * 8.7, 0.1, -1.1), 7.4, k=index + k)
    c.append(P(H, "PorchLight", (0, 8.0, -2.2), (0.3, 0.3, 0.3), WHITE, transparency=1, collide=False,
               tags=["StreetLight"], extra=INVISIBLE, children=[light((255, 210, 150), 1.1, 16)]))
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

    # Nain de jardin bodybuildé près du chemin, corde à linge (débardeurs de sport) dans le jardin de derrière (D101)
    hats = ((220, 40, 40), (40, 120, 220), (240, 180, 30), (60, 160, 80))
    c += gnome(F, "Gnome", (9.4, 0.1, 6.5), yaw=-20, hat=hats[index % 4], coat=hats[(index + 1) % 4])
    tanks = ((240, 90, 90), (60, 110, 200), (250, 200, 60), (40, 40, 44), (120, 200, 120))
    c += clothesline(F, "Clothesline", (0, 0.1, 51), [tanks[(index + j) % 5] for j in range(3)])
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
        # (coin sud-ouest : ouverture pour la porte triomphale du Colisée du Pump, D89)
        gap_end = {"S": 1, "W": -1}.get(side, 0)
        length = 2 * BORDER + 2 - (GATE_GAP if gap_end else 0)
        c.append(P(S, f"BorderHedge{side}", (-gap_end * GATE_GAP / 2, 3, BORDER), (length, 6, 2), HEDGE, "Grass"))
        for i, s in enumerate(range(-200, 201, 40)):
            if gap_end and s * gap_end > 160:
                continue
            c += tree(S, f"BorderTree{side}{i}", (s, 0, BORDER + 10), height=10 + (i % 3) * 2, radius=6,
                      color=(70, 130, 56), prop="Pine" if i % 2 else "TreeRoundBig")
        # Coin de rue : petit square fleuri entre deux côtés de maisons
        c += flowerbed(S, f"CornerBed{side}", (-176, 0, 176), (16, 16))
        c += tree(S, f"CornerTree{side}", (-162, 0, 192), height=11, radius=6)
        c += bench(S, f"CornerBench{side}", (-176, 0, 160), yaw=180)
    return folder("Ring", c)


# ------------------------------------------------------------------ 3. le centre-ville
MARBLE = (238, 226, 204)
MARBLE_WARM = (222, 204, 176)
GOLD = (206, 156, 44)
POOL_TILE = (46, 128, 150)


def jet(F, name, local, kind, direction=(0, 1, 0)):
    """Point d'où sort un jet d'eau (tag FountainJet) : AmbienceController y accroche les particules du type
    `kind` (Config/Ambience.luau), dirigées vers `direction` (repère du monde)."""
    return P(F, name, local, (0.2, 0.2, 0.2), WHITE, transparency=1, collide=False, tags=["FountainJet"],
             extra=INVISIBLE, attributes={"Jet": kind, "JetDir": {"Vector3": [round(v, 3) for v in direction]}})


def stone_ring(F, name, r0, r1, y0, y1, count, color, material="Limestone"):
    """Anneau de pierre visible (margelle) : `count` blocs entre les rayons r0..r1 et les hauteurs y0..y1."""
    out = []
    step = 360.0 / count
    width = 2 * r1 * math.sin(math.radians(step / 2)) + 0.05
    for i in range(count):
        G = F.child((0, 0, 0), step * i)
        out.append(P(G, f"{name}{i}", (0, (y0 + y1) / 2, -(r0 + r1) / 2), (width, y1 - y0, r1 - r0), color, material))
    return out


def fountain(F):
    """Grande fontaine de la place (D97) : bassin de marbre rempli de vraie eau (Terrain, tag WaterVolume, remplie
    par SceneryService), vasque haute, haltère doré au sommet, jets d'eau en arc depuis la margelle, gerbe au-dessus
    de l'haltère, rideau qui déborde de la vasque, éclaboussures et lumière dans l'eau la nuit."""
    c = [
        P(F, "FountainStep", (0, 0.2, 0), (0.4, 21.4, 21.4), CONCRETE_LIGHT, "Concrete", roll=90, shape="Cylinder"),
        P(F, "FountainPool", (0, 0.45, 0), (0.3, 17.2, 17.2), POOL_TILE, "Slate", roll=90, shape="Cylinder"),
        # Volume d'eau : bord caché dans la margelle (l'eau Terrain se pose par cubes de 4 studs)
        P(F, "FountainWater", (0, 1.25, 0), (1.3, 17.6, 17.6), (90, 170, 230), roll=90, shape="Cylinder",
          transparency=1, collide=False, tags=["WaterVolume"], extra=INVISIBLE),
    ]
    c += stone_ring(F, "FountainRim", 8.4, 9.8, 0.4, 2.1, 28, MARBLE)
    c += stone_ring(F, "FountainRimCap", 8.2, 10.1, 2.1, 2.5, 28, MARBLE_WARM)
    # Pied, colonne (bague dorée), vasque et son eau, tige et haltère doré
    c += [
        P(F, "FountainPedestal", (0, 1.4, 0), (2.0, 5.0, 5.0), MARBLE, "Marble", roll=90, shape="Cylinder"),
        P(F, "FountainPedestalCap", (0, 2.5, 0), (0.3, 5.4, 5.4), MARBLE_WARM, "Marble", roll=90, shape="Cylinder"),
        P(F, "FountainColumn", (0, 3.85, 0), (2.8, 2.2, 2.2), MARBLE, "Marble", roll=90, shape="Cylinder"),
        P(F, "FountainColumnBand", (0, 3.9, 0), (0.35, 2.5, 2.5), GOLD, "Metal", roll=90, shape="Cylinder"),
        P(F, "FountainBowl", (0, 5.45, 0), (0.5, 8.4, 8.4), MARBLE, "Marble", roll=90, shape="Cylinder"),
        P(F, "FountainBowlFoot", (0, 5.05, 0), (0.4, 4.0, 4.0), MARBLE_WARM, "Marble", roll=90, shape="Cylinder"),
        P(F, "FountainBowlWater", (0, 5.95, 0), (0.1, 7.4, 7.4), (70, 165, 205), "Glass", roll=90, shape="Cylinder",
          transparency=0.25, collide=False, extra={"Reflectance": 0.25}),
    ]
    c += stone_ring(F, "FountainBowlRim", 3.7, 4.3, 5.7, 6.2, 18, MARBLE_WARM)
    c += [
        P(F, "FountainStem", (0, 6.9, 0), (1.6, 1.0, 1.0), GOLD, "Metal", roll=90, shape="Cylinder"),
        P(F, "FountainBar", (0, 8, 0), (8.6, 0.9, 0.9), GOLD, "Metal", shape="Cylinder"),
    ]
    for k, sx in enumerate((-1, 1)):
        c += [
            P(F, f"FountainPlate{k}", (sx * 3.3, 8, 0), (0.9, 4.6, 4.6), GOLD, "Metal", shape="Cylinder"),
            P(F, f"FountainPlateSmall{k}", (sx * 2.5, 8, 0), (0.7, 3.4, 3.4), GOLD, "Metal", shape="Cylinder"),
            P(F, f"FountainCollar{k}", (sx * 4.0, 8, 0), (0.5, 1.5, 1.5), GOLD, "Metal", shape="Cylinder"),
        ]
    # Jets : 8 becs dorés sur la margelle tirent en arc vers le pied
    for i in range(8):
        a = math.radians(22.5 + 45 * i)
        dx, dz = math.sin(a), math.cos(a)  # du centre vers le bec
        c.append(P(F, f"FountainNozzle{i}", (dx * 9.0, 2.65, dz * 9.0), (0.3, 0.6, 0.6), GOLD, "Metal", roll=90,
                   shape="Cylinder"))
        c.append(jet(F, f"FountainArc{i}", (dx * 8.9, 2.85, dz * 8.9), "Arc", (-dx * 0.57, 0.82, -dz * 0.57)))
        # Éclaboussures là où retombent les arcs et le rideau de la vasque
        c.append(jet(F, f"FountainSplash{i}", (dx * 3.6, 1.75, dz * 3.6), "Splash"))
        # Rideau qui déborde de la vasque
        b = math.radians(45 * i)
        c.append(jet(F, f"FountainCurtain{i}", (math.sin(b) * 4.3, 6.15, math.cos(b) * 4.3), "Curtain",
                     (math.sin(b), 0, math.cos(b))))
    # Gerbe au-dessus de l'haltère et deux jets au sommet des disques
    c.append(jet(F, "FountainGeyser", (0, 8.5, 0), "Geyser"))
    for k, sx in enumerate((-1, 1)):
        c.append(jet(F, f"FountainPlateJet{k}", (sx * 3.3, 10.35, 0), "PlateJet", (sx * 0.25, 1, 0)))
    c.append(jet(F, "FountainSparkle", (0, 9, 0), "Sparkle"))
    # La nuit : lumière bleutée dans l'eau (allumée avec les lampadaires)
    c.append(P(F, "FountainLight", (0, 1.4, 0), (0.4, 0.4, 0.4), WHITE, transparency=1, collide=False,
               tags=["StreetLight"], extra=INVISIBLE, children=[light((120, 210, 255), 2.2, 20)]))
    return c


def plaza():
    F = Frame((0, GROUND, 0))
    c = [P(F, "Plaza", (0, 0.06, 0), (2 * PLAZA, 0.12, 2 * PLAZA), PAVING, "Pavement")]
    length = CENTER - PLAZA
    for side in SIDES:  # les 4 allées qui relient la place à la route
        S = side_frame(side)
        c.append(P(S, f"Avenue{side}", (0, 0.06, PLAZA + length / 2), (2 * AVENUE, 0.12, length), PAVING, "Pavement"))
        for k, sx in enumerate((-1, 1)):
            c += lamp_post(S, f"AvenueLamp{side}{k}", (sx * (AVENUE + 1.5), 0, PLAZA + length / 2), arm_dir=0)
    c += fountain(F)
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
    c += grocery_checkout(F)
    c.append(landmark(F, "GroceryIcon", (0, 27, 16), "Grocery"))
    return c


SHAKE_COLORS = ((240, 200, 230), (120, 230, 90), (200, 90, 70), (255, 210, 60))  # = couleurs de Config/Boosts.luau


def grocery_checkout(F):
    """Caisse de l'épicerie (D98) : comptoir avec tapis, caisse enregistreuse et présentoir de friandises ; derrière,
    le caissier (VendorGrocery, tag BoostShop) vend les mêmes boosts que le camion à shakes. Contre le mur, un frigo
    vitré rempli de shakes aux couleurs des 4 boosts et une ardoise de menu (pictogrammes, sans texte)."""
    G = F.child((12.8, 0.3, 8.6), 90)  # repère de la caisse : -Z = côté client (l'allée), +Z = le mur
    green, dark = (60, 150, 70), (44, 46, 52)
    c = [
        P(G, "CheckoutBody", (0, 1.6, 0), (7, 3.2, 2.4), (246, 242, 232), "Plaster"),
        P(G, "CheckoutStripe", (0, 2.3, -1.22), (7, 0.7, 0.06), green, collide=False),
        P(G, "CheckoutKick", (0, 0.2, -1.1), (7, 0.4, 0.3), dark, "Metal", collide=False),
        P(G, "CheckoutTop", (0, 3.3, 0), (7.4, 0.2, 2.8), (58, 60, 66), "Granite"),
        P(G, "CheckoutBelt", (-1.3, 3.46, 0), (4.2, 0.12, 1.7), (28, 28, 32), "Rubber", collide=False),
        P(G, "CheckoutDivider", (0.9, 3.55, 0), (0.15, 0.3, 1.5), (230, 60, 50), collide=False),
    ]
    for k in range(2):  # bords chromés du tapis
        c.append(P(G, f"CheckoutRail{k}", (-1.3, 3.5, (k * 2 - 1) * 0.92), (4.2, 0.16, 0.1), (200, 204, 210), "Metal",
                   collide=False))
    # Ce qui défile sur le tapis : un shake, un jus vert, un steak géant et une boîte d'œufs dorés
    c += [
        P(G, "BeltShake", (-3.0, 4.0, -0.2), (1.0, 0.7, 0.7), SHAKE_COLORS[0], roll=90, shape="Cylinder",
          collide=False),
        P(G, "BeltShakeLid", (-3.0, 4.55, -0.2), (0.12, 0.8, 0.8), WHITE, roll=90, shape="Cylinder", collide=False),
        P(G, "BeltJuice", (-2.2, 4.1, 0.3), (1.2, 0.55, 0.55), SHAKE_COLORS[1], "Glass", roll=90, shape="Cylinder",
          collide=False, transparency=0.15),
        P(G, "BeltSteak", (-1.0, 3.72, -0.1), (1.6, 0.4, 1.1), SHAKE_COLORS[2], "Fabric", yaw=15, collide=False),
        P(G, "BeltSteakFat", (-1.0, 3.93, -0.1), (1.2, 0.05, 0.7), (236, 210, 196), yaw=15, collide=False),
        P(G, "BeltSteakBone", (-0.2, 3.75, 0.1), (0.6, 0.3, 0.3), (245, 240, 225), roll=90, shape="Cylinder",
          collide=False),
        P(G, "BeltEggBox", (0.7, 3.66, 0.45), (1.2, 0.3, 0.7), (200, 180, 150), "Cardboard", collide=False),
    ]
    for k in range(3):
        c.append(P(G, f"BeltEgg{k}", (-0.2 + k * 0.4, 3.9, 0.45), (0.35, 0.4, 0.35), SHAKE_COLORS[3], "Metal",
                   shape="Ball", collide=False))
    # Caisse enregistreuse, écran incliné vers le client et terminal de paiement
    c += [
        P(G, "RegisterBase", (2.3, 3.75, 0.3), (2.0, 0.7, 1.5), (70, 72, 80), "Metal", collide=False),
        P(G, "RegisterDrawer", (2.3, 3.6, -0.47), (1.7, 0.35, 0.06), (52, 54, 60), "Metal", collide=False),
        P(G, "RegisterNeck", (2.3, 4.35, 0.6), (0.25, 0.6, 0.25), (52, 54, 60), "Metal", collide=False),
        P(G, "RegisterScreen", (2.3, 4.9, 0.55), (1.5, 0.95, 0.12), (40, 42, 48), pitch=-20, collide=False),
        P(G, "RegisterGlow", (2.3, 4.9, 0.48), (1.3, 0.75, 0.04), (110, 230, 140), "Neon", pitch=-20,
          collide=False),
        P(G, "CardTerminal", (3.3, 3.55, -0.85), (0.5, 0.3, 0.8), (36, 36, 40), pitch=25, collide=False),
        P(G, "CardTerminalLight", (3.3, 3.73, -0.85), (0.35, 0.04, 0.3), (90, 200, 255), "Neon", pitch=25,
          collide=False),
        P(G, "Scanner", (1.15, 3.43, 0), (0.9, 0.06, 0.9), (180, 40, 40), "Glass", transparency=0.2,
          collide=False),
    ]
    # Présentoir de friandises côté client (barres protéinées de toutes les couleurs)
    H = G.child((-4.1, 0, -0.3))
    c += [
        P(H, "CandyRack", (0, 2.1, 0), (0.8, 4.2, 1.8), (60, 62, 70), "Metal"),
        P(H, "CandyRackTop", (0, 4.3, 0), (1.0, 0.2, 2.0), green),
    ]
    bars = ((240, 90, 90), (250, 200, 60), (90, 160, 240), (160, 90, 220), (120, 210, 120), (250, 140, 40))
    for row in range(3):
        for k in range(3):
            c.append(P(H, f"CandyBar{row}{k}", (-0.45, 1.2 + row * 1.0, -0.55 + k * 0.55), (0.12, 0.7, 0.4),
                       bars[(row * 3 + k) % len(bars)], collide=False))
    # Lampe de caisse : poteau et feu vert « caisse ouverte »
    c += [
        P(G, "LanePole", (3.55, 5.2, 0.9), (0.2, 3.6, 0.2), (200, 204, 210), "Metal", collide=False),
        P(G, "LaneLamp", (3.55, 7.1, 0.9), (0.7, 0.7, 0.7), (110, 230, 120), "Neon", shape="Ball", collide=False,
          children=[light((140, 255, 160), 0.8, 10)]),
    ]
    # Frigo vitré contre le mur, rempli de shakes (4 étagères, une couleur de boost chacune)
    K = G.child((0, 0, 4.15))
    c += [
        P(K, "ShakeFridge", (0, 3.4, 0.25), (6.4, 6.8, 0.9), (235, 238, 242), "Metal"),
        P(K, "ShakeFridgeInside", (0, 3.6, -0.2), (5.8, 6.0, 0.1), (220, 245, 255), "Neon", collide=False,
          transparency=0.35),
        P(K, "ShakeFridgeGlass", (0, 3.6, -0.6), (5.8, 6.0, 0.08), (200, 230, 250), "Glass", transparency=0.65,
          collide=False, extra={"Reflectance": 0.3}),
        P(K, "ShakeFridgeTop", (0, 7.0, -0.1), (6.6, 0.5, 1.3), green, collide=False),
        P(K, "ShakeFridgeHandle", (2.6, 3.6, -0.72), (0.15, 2.4, 0.15), (200, 204, 210), "Metal", collide=False),
    ]
    for row, colr in enumerate(SHAKE_COLORS):
        y = 1.3 + row * 1.45
        c.append(P(K, f"FridgeShelf{row}", (0, y - 0.05, -0.3), (5.8, 0.08, 0.7), (200, 210, 220), "Glass",
                   collide=False, transparency=0.3))
        for k in range(6):
            c.append(P(K, f"FridgeShake{row}_{k}", (-2.4 + k * 0.96, y + 0.45, -0.35), (0.85, 0.42, 0.42), colr,
                       roll=90, shape="Cylinder", collide=False))
    c.append(P(K, "FridgeLight", (0, 6.2, -0.4), (0.3, 0.3, 0.3), WHITE, transparency=1, collide=False,
               extra=INVISIBLE, children=[light((210, 240, 255), 0.7, 9)]))
    # Ardoise de menu au-dessus du frigo : les 4 boosts en pastilles (pictogrammes, aucun texte)
    c.append(P(K, "MenuBoard", (0, 9.3, 0.55), (6.6, 3.0, 0.2), (36, 40, 38), "Slate", collide=False))
    c.append(P(K, "MenuFrame", (0, 9.3, 0.62), (7.0, 3.4, 0.12), WOOD, "WoodPlanks", collide=False))
    for k, colr in enumerate(SHAKE_COLORS):
        c.append(P(K, f"MenuDot{k}", (-2.4 + k * 1.6, 9.5, 0.42), (0.1, 1.1, 1.1), colr, "Neon", yaw=90,
                   shape="Cylinder", collide=False))
        c.append(P(K, f"MenuLine{k}", (-2.4 + k * 1.6, 8.5, 0.43), (0.9, 0.12, 0.05), (210, 210, 200), collide=False))
    # Le caissier, derrière le comptoir, tourné vers l'allée
    c.append(vendor(F, "GroceryVendor", (15.0, 0.3, 8.6), "VendorGrocery", "Grocery", "BoostShop", yaw=90,
                    title="Boost.Checkout"))
    return c


GYM_STATIONS = {"BenchPress": (-34, 26), "Squat": (-34, 38), "PullUp": (14, 26), "JumpRope": (14, 38)}


def gym():
    """Salle de quartier (côté est) : façade sur la route, 3 exemplaires de chaque station pour 20 joueurs."""
    F = Frame((CENTER, GROUND, -54), -90)
    c = shop_shell(F, "Gym", BRICK, "Brick", ((58, 58, 64), "Rubber", 0.3))
    for i, lx in enumerate((-24, 0, 24)):
        for j, lz in enumerate((14, 34)):
            c.append(P(F, f"GymLamp{i}{j}", (lx, 19.4, lz), (10, 0.4, 1.4), (255, 244, 214), "Neon",
                       children=[light(brightness=1.3, range_=40)]))
    c.append(P(F, "SignBar", (0, 25, 6), (26, 1.2, 1.2), (180, 180, 186), "Metal", shape="Cylinder"))
    for k, dx in enumerate((-13, 13)):
        c.append(P(F, f"SignPlate{k}", (dx, 25, 6), (2, 9, 9), (40, 40, 44), "Metal", shape="Cylinder"))
    # Bandes de couleur sur les murs de côté, écrans, ventilateurs qui tournent, range-vélos devant (D101)
    for k, sx in enumerate((-1, 1)):
        c.append(P(F, f"GymStripe{k}", (sx * 41.1, 2.7, 24), (0.1, 0.9, 45), (200, 40, 40), collide=False))
        c.append(P(F, f"GymStripeGold{k}", (sx * 41.1, 3.4, 24), (0.1, 0.25, 45), (250, 200, 40), collide=False))
        for j, lz in enumerate((10, 38)):
            c.append(P(F, f"GymTv{k}{j}", (sx * 40.95, 13, lz), (0.3, 4.6, 7.6), (24, 24, 28), "Metal",
                       collide=False))
            c.append(P(F, f"GymTvScreen{k}{j}", (sx * 40.78, 13, lz), (0.06, 4.0, 7.0),
                       ((70, 150, 255), (255, 120, 60))[(k + j) % 2], "Neon", collide=False))
    for k, lx in enumerate((-12, 12)):
        c += ceiling_fan(F, f"GymFan{k}", (lx, 18.4, 24), speed=3.5 if k else -3.5)
    c.append(decor(F, "BikeRackSlot", (-21, WALK_TOP, -2.4), "BikeRack"))
    for ex, (x0, lz) in GYM_STATIONS.items():
        for k in range(3):
            c.append(station(F, f"{ex}Station{k + 1}", (x0 + k * 10, 0.8, lz), ex))
    n0 = len(c)
    c.append(P(F, "CoachStage", (0, 0.8, 16), (16, 1, 12), (170, 40, 40), "Fabric"))
    wrap(c, n0, F, "CoachStageSlot", (0, 0.3, 16), "BossStage")
    c.append(spot(F, "CoachTurboSpot", (0, 1.8, 16), (8, 1, 8), SPOT_BOSS, "BossSpot", {"BossId": "CoachTurbo"}))
    # Miroir du fond en deux parties, de chaque côté de la porte arrière
    for k, lx in enumerate((-22.5, 22.5)):
        c.append(P(F, f"GymMirror{k}", (lx, 8, 46.8), (31, 10, 0.2), (200, 225, 240), "Glass", collide=False,
                   extra={"Reflectance": 0.4}))
    for k in range(7):
        if k == 3:
            continue  # place de la porte arrière
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
    # Piscine à vraie eau (D101) : fond carrelé, margelle, échelle, plongeoir, bouée, ballon, lumière la nuit
    c += water_basin(F, "Pool", (-84, 0.1, 50), (22.8, 8.8), height=1.6, rim=1.6, rim_color=WHITE, water=(23.76, 12))
    for k, lx in enumerate((-78.6, -77.4)):
        c.append(P(F, f"PoolLadderRail{k}", (lx, 1.4, 46.0), (0.22, 2.4, 0.22), (205, 208, 214), "Metal",
                   collide=False))
        c.append(P(F, f"PoolLadderTop{k}", (lx, 2.55, 45.4), (0.22, 0.22, 1.4), (205, 208, 214), "Metal",
                   collide=False))
    c.append(P(F, "PoolLadderStep", (-78, 1.0, 46.0), (1.2, 0.12, 0.4), (205, 208, 214), "Metal", collide=False))
    c.append(P(F, "DivingBase", (-98.6, 1.0, 50), (2.0, 2.0, 2.4), WHITE, "Concrete"))
    c.append(P(F, "DivingBoard", (-95.6, 2.1, 50), (5.6, 0.25, 1.6), (60, 130, 200)))
    for i in range(10):
        G = F.child((-80, 0.1, 51.5), i * 36)
        # bandes blanches un peu plus fines que les rouges : aucune face commune (pas de scintillement)
        c.append(P(G, f"PoolFloat{i}", (0, 1.55, -0.95), (0.8, 0.4, 0.6) if i % 2 == 0 else (0.8, 0.34, 0.54),
                   ((235, 60, 60), WHITE)[i % 2], collide=False))
    c.append(P(F, "PoolBall", (-89, 1.9, 48), (1.4, 1.4, 1.4), (250, 200, 50), shape="Ball", collide=False))
    c.append(P(F, "PoolLight", (-84, 1.0, 50), (0.4, 0.4, 0.4), WHITE, transparency=1, collide=False,
               tags=["StreetLight"], extra=INVISIBLE, children=[light((120, 210, 255), 2, 18)]))
    for k, lx in enumerate((-93, -75)):
        c.append(decor(F, f"PoolLoungerSlot{k}", (lx, 0.1, 59.6), "Lounger", yaw=90))
    for k, lx in enumerate((-92, -74, -56)):
        c += lamp_post(F, f"ParkLamp{k}", (lx, 0.1, 34.4), arm_dir=1)
    for k, lx in enumerate((-83, -65)):
        c += bench(F, f"ParkBench{k}", (lx, 0.1, 40.6))
    c += flowerbed(F, "ParkFlowerbed", (-92, 0.1, 30.5), (7, 5))
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
    # (le 3e reculé en D102 : son feuillage avalait le lampadaire de l'avenue)
    for k, (x, z) in enumerate(((-100, 40), (-44, 58), (-75, 17))):
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
    # Braseros allumés devant le temple (D101)
    for sx in (-1, 1):
        c.append(decor(T, f"TempleBrazier{sx}", (sx * 17, 0, -17), "Colosseum_Brazier", collide=False))
        c.append(P(T, f"TempleFire{sx}", (sx * 17, 4.0, -17), (1, 1, 1), WHITE, transparency=1, collide=False,
                   tags=["ColosseumFire"], extra=INVISIBLE))
    # Portail vers le Colisée du Pump (D89, arche gothique en D105) : en tête du tapis rouge, entre les deux torches
    c += colosseum_portal(T, "ColosseumPortalTemple", (0, 0.12, -17.6), 0, "Colosseum")
    # Ambiance de match (apparaît avec les modèles 3D) : projecteurs, gong, cordons, trophées des boss
    c.append(decor(F, "SpotlightSlot0", (-100, 0.12, -40), "Spotlight", yaw=-45))
    c.append(decor(F, "SpotlightSlot1", (-40, 0.12, -100), "Spotlight", yaw=135))
    c.append(decor(F, "GongSlot", (-102, 0.12, -64), "Gong", yaw=-90))
    for k, (along, side) in enumerate(((-8, 1), (8, 1), (-8, -1), (8, -1))):
        x = -54 + along * 0.707 + side * 3.0
        z = -54 + along * 0.707 - side * 3.0
        c.append(decor(F, f"RopeSlot{k}", (x, 0.12, z), "StanchionRope", yaw=-45))
    c.append(decor(F, "CrownSlot", (-60, 0.12, -98), "CrownCushion", yaw=135))
    # Torches enflammées le long du tapis rouge, cercles dorés autour des scènes, gradins (D101)
    for k, along in enumerate((-15, 0, 15)):
        for side in (-1, 1):
            x = -54 + along * 0.707 + side * 5.2 * 0.707
            z = -54 + along * 0.707 - side * 5.2 * 0.707
            c += torch(F, f"ArenaTorch{k}{side}", (x, 0.12, z))
    for name, (x, z), r in (("NoLegsRing", (-92, -46), 9.0), ("KingRing", (-46, -92), 11.8)):
        c += stone_ring(F.child((x, 0, z)), name, r, r + 0.8, 0.1, 0.2, 32, GOLD_TRIM, material="Metal")
    c.append(decor(F, "BleachersSlot0", (-46, 0.12, -74), "Bleachers"))
    c.append(decor(F, "BleachersSlot1", (-74, 0.12, -46), "Bleachers", yaw=90))
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


# ------------------------------------------------------------------ 5. le Colisée du Pump (D89)
# Arène du dernier boss, au-delà du coin sud-ouest de la ville : on y entre par une porte triomphale ouverte dans la
# haie de bordure, puis une voie bordée de colonnes. Modèles 3D : tools/blender/props_colosseum.py (12 secteurs de
# 30 degrés posés autour du centre) ; cotes et positions des pièces : assets/export/props/colosseum_manifest.json.
# Les collisions sont des blocs invisibles simples (gradins, marches, murs) : on marche sur des marches régulières, et
# une barrière invisible haute sépare la piste des gradins (les spectateurs ne descendent pas, le combattant ne sort pas).
with open(os.path.join(ROOT, "assets", "export", "props", "colosseum_manifest.json"), encoding="utf-8") as _f:
    _COLO = json.load(_f)
COLO_PIECES, COLO = _COLO["pieces"], _COLO["layout"]
COLO_CENTER = (-330.0, -330.0)
COLO_YAW = -135.0  # l'entrée (secteur 0) regarde vers la ville (nord-est)
COLO_TOP = GROUND + COLO["podium"]  # dessus du podium = sol de la piste
GATE_GAP = 20  # longueur de haie retirée de chaque côté du coin sud-ouest pour la porte
INVISIBLE = {"CanQuery": False, "CanTouch": False}


def colo_piece(F, name, prop, collide=False, attributes=None):
    """Pièce du colisée recalée dans le repère F (centre de l'arène, tourné vers le secteur voulu)."""
    m = COLO_PIECES[prop]
    cx, cy = m["center"]
    slot = prop_slot(F, name, (cx, m["bottom"], cy), prop, collide=collide)
    if attributes:
        slot["attributes"].update(attributes)
    return slot


def colo_frame(k):
    return Frame((COLO_CENTER[0], COLO_TOP, COLO_CENTER[1]), COLO_YAW + COLO["sector"] * k)


def ring_boxes(F, name, r0, r1, z0, z1, count, offset=0.0, skip=None, **kw):
    """Anneau de blocs invisibles (collisions) entre les rayons r0..r1 et les hauteurs z0..z1, dans le repère F."""
    out = []
    step = 360.0 / count
    for i in range(count):
        a = offset + step * i
        if skip and skip(a):
            continue
        rm = (r0 + r1) / 2
        width = 2 * r1 * math.sin(math.radians(step / 2)) + 0.3
        G = F.child((0, 0, 0), a)
        out.append(P(G, f"{name}{i}", (0, (z0 + z1) / 2, -rm), (width, z1 - z0, r1 - r0), WHITE, transparency=1,
                     extra=INVISIBLE, **kw))
    return out


def colosseum():
    c = []
    L = COLO
    F0 = colo_frame(0)
    top = 0.0  # repère : z = 0 au dessus du podium
    fg, bg, tribune = L["fighter_gate"], L["boss_gate"], L["tribune"]

    # --- pièces 3D, secteur par secteur
    c.append(colo_piece(F0, "ColosseumFloor", "Colosseum_Floor"))
    for k in range(12):
        F = colo_frame(k)
        gate = k in (fg, bg)
        c.append(colo_piece(F, f"ColosseumPitWall{k}", "Colosseum_PitGate" if gate else "Colosseum_PitWall"))
        stands = "Colosseum_StandsEntrance" if k == 0 else ("Colosseum_StandsTribune" if k == tribune
                                                            else "Colosseum_Stands")
        c.append(colo_piece(F, f"ColosseumStands{k}", stands))
        c.append(colo_piece(F, f"ColosseumFacade{k}", "Colosseum_FacadeEntrance" if k == 0 else "Colosseum_Facade"))
        c.append(colo_piece(F, f"ColosseumPlaza{k}", "Colosseum_Plaza"))
        if k not in (0, tribune):
            c.append(colo_piece(F, f"ColosseumCrowd{k}", "Colosseum_Crowd",
                                attributes={"ColosseumCrowd": True, "Phase": k}))
        if gate:
            # Herse de la porte (le jeu la lève pour faire entrer le combattant ou le boss)
            slot = prop_slot(F, f"ColosseumPortcullis{k}", (0, 0, -(L["pit_radius"] + 0.6)), "Colosseum_Portcullis",
                             collide=True)
            slot["attributes"]["ColosseumGate"] = "Fighter" if k == fg else "Boss"
            c.append(slot)
            for sx in (-1, 1):
                c.append(decor(F, f"ColosseumGateBanner{k}{sx}", (sx * 7.5, L["walk_top"], -(L["wall_outer"] + 1.5)),
                               "Colosseum_Banner", collide=False))
        # Velums rouges en haut, un secteur sur deux (pas au-dessus de l'entrée ni de la tribune)
        if k % 2 == 1 and k != tribune:
            c.append(decor(F, f"ColosseumAwning{k}", (0, L["walk_top"] + L["tier_rise"] * L["tiers"] + 1.2,
                                                      -(L["stand_outer"] - 1.5)), "Colosseum_Awning", collide=False))
        # Braseros sur la coursive, au bord des secteurs
        G = F.child((0, 0, 0), L["sector"] / 2)
        c.append(decor(G, f"ColosseumBrazier{k}", (0, L["walk_top"], -(L["walk_outer"] - 1.6)), "Colosseum_Brazier",
                       collide=False))
        c.append(P(G, f"ColosseumFire{k}", (0, L["walk_top"] + 4.0, -(L["walk_outer"] - 1.6)), (1, 1, 1), WHITE,
                   transparency=1, collide=False, tags=["ColosseumFire"], extra=INVISIBLE))
    # Tribune d'honneur : deux étendards ; statues de marbre autour de l'arène, sur le parvis
    Ft = colo_frame(tribune)
    for sx in (-1, 1):
        c.append(decor(Ft, f"ColosseumTribuneBanner{sx}", (sx * 9.0, L["walk_top"], -(L["walk_outer"] - 1.0)),
                       "Colosseum_Banner", collide=False))
    for k in (2, 4, 6, 8, 10):
        c.append(decor(colo_frame(k), f"ColosseumPlazaStatue{k}", (0, 0, -(L["facade_outer"] + 8.0)),
                       "Colosseum_Statue"))
    # Panthéon des champions (D93) : entre les statues de marbre, un socle par vainqueur du Dieu du Pump présent sur
    # le serveur (statue dorée mise par StatueService, tag ChampionStatue)
    for rank, k in enumerate((5, 7, 3, 9), start=1):
        c.append(P(colo_frame(k), f"ColosseumChampion{rank}", (0, 1.5, -(L["facade_outer"] + 8.0)), (6, 3, 6),
                   (236, 230, 218), "Marble", tags=["ChampionStatue"], attributes={"Rank": rank}))
        c.append(P(colo_frame(k), f"ColosseumChampionTrim{rank}", (0, 3.1, -(L["facade_outer"] + 8.0)),
                   (6.6, 0.4, 6.6), (255, 200, 70), "SmoothPlastic", collide=False))
    # Entrée : statues, étendards et braseros de part et d'autre du grand escalier, sur le parvis
    for sx in (-1, 1):
        c.append(decor(F0, f"ColosseumEntryStatue{sx}", (sx * 13.0, 0, -(L["facade_outer"] + 6.0)), "Colosseum_Statue"))
        c.append(decor(F0, f"ColosseumEntryBanner{sx}", (sx * 7.6, 0, -(L["facade_outer"] + 1.5)), "Colosseum_Banner",
                       collide=False))
        c.append(decor(F0, f"ColosseumEntryBrazier{sx}", (sx * 7.6, 0, -(L["facade_outer"] + 9.0)),
                       "Colosseum_Brazier", collide=False))
        c.append(P(F0, f"ColosseumEntryFire{sx}", (sx * 7.6, 4.0, -(L["facade_outer"] + 9.0)), (1, 1, 1), WHITE,
                   transparency=1, collide=False, tags=["ColosseumFire"], extra=INVISIBLE))

    # --- collisions (invisibles)
    R = L["plaza_outer"]
    h = L["podium"]
    # Podium et piste : un grand disque, puis les 3 marches vers l'herbe
    c.append(P(F0, "ColosseumPodium", (0, -h / 2, 0), (h, 2 * R, 2 * R), WHITE, transparency=1, roll=90,
               shape="Cylinder", extra=INVISIBLE))
    for k in range(3):
        rr = R + 1.4 * (k + 1)
        topk = -h * (k + 1) / 4
        c.append(P(F0, f"ColosseumStep{k}", (0, (topk - h) / 2, 0), (topk + h, 2 * rr, 2 * rr), WHITE,
                   transparency=1, roll=90, shape="Cylinder", extra=INVISIBLE))
    # Mur de la piste, et barrière haute au-dessus (personne ne passe entre la piste et les gradins)
    c += ring_boxes(F0, "ColosseumPitWallCol", L["pit_radius"], L["wall_outer"], 0, L["walk_top"], 36)
    c += ring_boxes(F0, "ColosseumBarrier", L["pit_radius"] + 0.2, L["pit_radius"] + 1.2, L["walk_top"], 60, 36)
    # Coursive (sol) et masse sous les gradins (l'entrée laisse un passage de 13 studs)
    half_entry = math.degrees((L["entrance_width"] / 2 + 1.0) / L["stand_outer"])

    def in_entry(a):
        d = (a + 180) % 360 - 180
        return abs(d) < half_entry + 360 / 72 / 2

    c += ring_boxes(F0, "ColosseumWalk", L["wall_outer"], L["walk_outer"], 0, L["walk_top"], 36)
    # Rangées : deux blocs par secteur (de part et d'autre du passage du milieu), cordes de l'arc
    half_sector = L["sector"] / 2
    for k in range(12):
        F = colo_frame(k)
        for i in range(L["tiers"]):
            r0 = L["walk_outer"] + L["tier_depth"] * i
            r1 = r0 + L["tier_depth"]
            z1 = L["walk_top"] + L["tier_rise"] * (i + 1)
            lateral = L["aisle_width"] / 2
            if k == 0:
                lateral = L["entrance_width"] / 2 + 1.2
            elif k == tribune and i < 5:
                lateral = 7.0
            rm = (r0 + r1) / 2
            a_gap = math.degrees(math.asin(min(lateral / rm, 0.99)))
            span = half_sector - a_gap
            # Deux cordes par demi-secteur : elles collent à l'arc à moins de 0,1 stud près
            for sx in (-1, 1):
                for part_i in range(2):
                    mid = sx * (a_gap + span * (part_i + 0.5) / 2)
                    G = F.child((0, 0, 0), mid)
                    width = 2 * r1 * math.sin(math.radians(span / 4)) + 0.3
                    c.append(P(G, f"ColosseumTier{k}_{i}_{sx}_{part_i}", (0, z1 / 2, -rm),
                               (width, z1, r1 - r0 + 0.04), WHITE, transparency=1, extra=INVISIBLE))
    # Tribune d'honneur : sous elle, les 5 premières rangées laissent un renfoncement au niveau de la coursive (il
    # n'avait pas de sol : on tombait sous le stade) ; la tribune elle-même, ses colonnes et le trône sont solides
    Ft = colo_frame(tribune)
    r_back = L["walk_outer"] + L["tier_depth"] * 5
    c.append(P(Ft, "ColosseumTribuneFloor", (0, L["walk_top"] / 2, -(L["walk_outer"] + r_back) / 2),
               (14.6, L["walk_top"], r_back - L["walk_outer"] + 0.1), WHITE, transparency=1, extra=INVISIBLE))
    r0t = L["walk_outer"] - 1.5
    zt = L["walk_top"] + 5.0
    c.append(P(Ft, "ColosseumTribunePlatform", (0, zt - 0.5, -(r0t + 5.5)), (13, 1.0, 11), WHITE, transparency=1,
               extra=INVISIBLE))
    c.append(P(Ft, "ColosseumTribuneThrone", (0, zt + 1.5, -(r0t + 7.9)), (3.0, 3.0, 3.4), WHITE, transparency=1,
               extra=INVISIBLE))
    for k_col, sx in enumerate((-5.5, -2, 2, 5.5)):
        c.append(P(Ft, f"ColosseumTribuneColumn{k_col}", (sx, zt + 3.5, -(r0t + 1.0)), (1.1, 7.0, 1.1), WHITE,
                   transparency=1, extra=INVISIBLE))
    # Escaliers de marbre (2 marches par rangée) au milieu de chaque secteur, sauf entrée et bas de la tribune
    for k in range(1, 12):
        F = colo_frame(k)
        for i in range(L["tiers"]):
            if k == tribune and i < 5:
                continue
            for step in range(2):
                r0 = L["walk_outer"] + L["tier_depth"] * (i + step / 2)
                z = L["walk_top"] + L["tier_rise"] * (i + (step + 1) / 2)
                c.append(P(F, f"ColosseumAisle{k}_{i}_{step}", (0, z / 2, -(r0 + L["tier_depth"] / 4)),
                           (L["aisle_width"], z, L["tier_depth"] / 2), WHITE, transparency=1, extra=INVISIBLE))
    # Grand escalier d'entrée : 14 marches du parvis à la coursive, entre deux murs
    steps = 14
    r_out, r_in = L["facade_outer"], L["walk_outer"]
    depth = (r_out - r_in) / steps
    for k in range(steps):
        r = r_out - depth * (k + 1)
        z = L["walk_top"] * (k + 1) / steps
        c.append(P(F0, f"ColosseumEntryStep{k}", (0, z / 2, -(r + depth / 2)), (L["entrance_width"], z, depth + 0.05),
                   WHITE, transparency=1, extra=INVISIBLE))
    for sx in (-1, 1):
        # Mur d'échiffre : du bord des marches (aucune fente) jusqu'au début des gradins
        c.append(P(F0, f"ColosseumEntryWall{sx}", (sx * (L["entrance_width"] / 2 + 0.95), 15, -(r_in + r_out) / 2),
                   (1.9, 30, r_out - r_in), WHITE, transparency=1, extra=INVISIBLE))
    # Façade : un mur plein tout autour (l'arche d'entrée reste ouverte jusqu'à 11 studs de haut)
    c += ring_boxes(F0, "ColosseumFacadeCol", L["stand_outer"], L["facade_outer"], 0, L["facade_height"] + 1, 48,
                    offset=3.75, skip=in_entry)
    for sx in (-1, 1):
        G = F0.child((0, 0, 0), sx * (half_entry + 3.75))
        c.append(P(G, f"ColosseumFacadeEntrySide{sx}", (0, (L["facade_height"] + 1) / 2,
                                                         -(L["stand_outer"] + L["facade_outer"]) / 2),
                   (8.0, L["facade_height"] + 1, L["facade_outer"] - L["stand_outer"]), WHITE, transparency=1,
                   extra=INVISIBLE))
    c.append(P(F0, "ColosseumFacadeEntryTop", (0, (11 + L["facade_height"] + 1) / 2,
                                               -(L["stand_outer"] + L["facade_outer"]) / 2),
               (L["entrance_width"] + 2.5, L["facade_height"] + 1 - 11, L["facade_outer"] - L["stand_outer"]), WHITE,
               transparency=1, extra=INVISIBLE))

    # --- points de jeu (invisibles)
    def point(F, name, local, tag, attributes=None):
        return P(F, name, local, (4, 1, 4), WHITE, transparency=1, collide=False, tags=[tag], attributes=attributes,
                 extra=INVISIBLE)

    c.append(point(colo_frame(fg), "ColosseumFighterSpot", (0, 0.5, -(L["pit_radius"] - 10)), "ColosseumSpot",
                   {"Role": "Fighter"}))
    c.append(point(colo_frame(bg), "ColosseumBossSpot", (0, 0.5, -(L["pit_radius"] - 12)), "ColosseumSpot",
                   {"Role": "Boss"}))
    c.append(point(F0, "ColosseumCenter", (0, 0.5, 0), "ColosseumSpot", {"Role": "Center"}))
    c.append(point(F0, "ColosseumArrival", (0, 0.5, -(L["plaza_outer"] - 5)), "ColosseumSpot", {"Role": "Arrival"}))
    c.append(point(F0, "ColosseumStandsSpot", (0, L["walk_top"] + 0.5, -(L["walk_outer"] - 2)), "ColosseumSpot",
                   {"Role": "Stands"}))
    # Portail de retour vers la ville (D105), sur le parvis, à droite de la statue, ouverture tournée vers l'arrivée
    c += colosseum_portal(F0, "ColosseumPortalBack", (22, 0, -(L["plaza_outer"] - 8)), 90, "Temple")
    # Arrêt de bus du colisée (réseau de bus de la ville)
    # à gauche de la statue d'entrée (D102 : l'abribus était dedans)
    c += bus_stop(F0.child((-27, 0, -(L["plaza_outer"] - 9)), 0), "BusStopColosseum", (0, 0, 0), "Colosseum")
    c.append(landmark(F0, "ColosseumIcon", (0, L["facade_height"] + 12, 0), "Colosseum"))

    # --- porte triomphale dans la haie (coin sud-ouest) et voie bordée de colonnes
    gate_at = (-(BORDER - GATE_GAP / 2) + 0.5, -(BORDER - GATE_GAP / 2) + 0.5)
    Fg = Frame((gate_at[0], GROUND, gate_at[1]), COLO_YAW)
    c.append(decor(Fg, "ColosseumTownGate", (0, 0, 0), "Colosseum_Gate"))
    for sx in (-1, 1):
        c.append(P(Fg, f"ColosseumTownGatePier{sx}", (sx * 10.5, 9, 0), (5, 18, 4), WHITE, transparency=1,
                   extra=INVISIBLE))
    start = math.hypot(COLO_CENTER[0] - gate_at[0], COLO_CENTER[1] - gate_at[1])
    via = start - (R + 4.2)
    Fv = Frame((gate_at[0], GROUND, gate_at[1]), COLO_YAW + 180)  # la voie part de la porte vers l'arène (+Z local -> -Z)
    for k in range(int(via // 6)):
        z = 3 + k * 6
        c.append(P(Fv, f"ColosseumVia{k}", (0, 0.1, -z), (12, 0.2, 6.02), (214, 186, 140) if k % 2 else (226, 200, 154),
                   "Sandstone"))
        for sx in (-1, 1):
            c.append(P(Fv, f"ColosseumViaEdge{k}{sx}", (sx * 6.4, 0.18, -z), (0.8, 0.36, 6.02), (240, 236, 226),
                       "Marble"))
    for k in range(1, int(via // 14) + 1):
        z = k * 14
        for sx in (-1, 1):
            n0 = len(c)
            c.append(P(Fv, f"ColosseumViaColumn{k}{sx}", (sx * 8.5, 7, -z), (14, 1.6, 1.6), (240, 238, 230), "Marble",
                       roll=90, shape="Cylinder"))
            wrap(c, n0, Fv, f"ColosseumViaColumnSlot{k}{sx}", (sx * 8.5, 0, -z), "GreekColumn", height=12)
            if k % 2 == 0:
                c.append(decor(Fv, f"ColosseumViaBrazier{k}{sx}", (sx * 8.5, 0, -z - 7), "Colosseum_Brazier",
                               collide=False))
                c.append(P(Fv, f"ColosseumViaFire{k}{sx}", (sx * 8.5, 4.0, -z - 7), (1, 1, 1), WHITE,
                           transparency=1, collide=False, tags=["ColosseumFire"], extra=INVISIBLE))
    # Citronniers en pots de terre cuite derrière chaque colonne de la voie (D101)
    for k in range(1, int(via // 14) + 1):
        for sx in (-1, 1):
            c += citrus_pot(Fv, f"ColosseumLemon{k}{sx}", (sx * 13.5, 0, -k * 14), k + sx)
    # --- paysage autour : cyprès, rochers, buissons ; la vue depuis la voie reste dégagée
    rnd = random.Random(89)
    for i in range(30):
        a = i * 12 + rnd.uniform(-3, 3)
        d = (a + 180) % 360 - 180
        if abs(d) < 26:
            continue
        G = F0.child((0, 0, 0), a)
        r = rnd.uniform(108, 126)
        c.append(decor(G, f"ColosseumCypress{i}", (rnd.uniform(-3, 3), -h, -r), "Pine",
                       yaw=rnd.uniform(0, 360), height=rnd.uniform(17, 25)))
    for i in range(22):
        a = rnd.uniform(0, 360)
        d = (a + 180) % 360 - 180
        if abs(d) < 20:
            continue
        G = F0.child((0, 0, 0), a)
        big = i % 3 == 0
        c.append(decor(G, f"ColosseumRock{i}", (0, -h, -rnd.uniform(104, 140)), "RockBig" if big else "Rock",
                       yaw=rnd.uniform(0, 360), height=rnd.uniform(3, 6) if big else rnd.uniform(1.5, 3)))
    for i in range(36):
        a = i * 10 + 5
        d = (a + 180) % 360 - 180
        if abs(d) < 12:
            continue
        G = F0.child((0, 0, 0), a)
        c.append(decor(G, f"ColosseumBush{i}", (0, -h, -(R + 6.5)), "Bush", yaw=a * 7, height=2.6, collide=False))
    # Amphores de part et d'autre de l'entrée
    for k, (x, z) in enumerate(((-11, 2), (-12.5, 4), (11, 2), (12.5, 4))):
        c.append(decor(F0, f"ColosseumAmphora{k}", (x, 0, -(L["facade_outer"] + z)), "Amphora", yaw=k * 50,
                       height=2.4))
    # Buissons et touffes d'herbe le long de la voie
    for k in range(1, int(via // 14) + 1):
        for sx in (-1, 1):
            c.append(decor(Fv, f"ColosseumViaBush{k}{sx}", (sx * 10.5, 0, -k * 14 + 7), "Bush", yaw=k * 40,
                           height=2.2, collide=False))
    return model("Colosseum", c)

# ------------------------------------------------------------------ 6. le Mur des Colosses (D107)
# Le monde est fermé par un mur continu de statues géantes en marbre (dieux « gym bro » qui portent la corniche),
# autour de la ville (un carré) et du Colisée (un cercle) : leur contour commun. Modèles : tools/blender/
# props_statue_wall.py ; tailles, positions et points d'effet : assets/export/props/statue_wall_manifest.json.
# Un module (socle + mur + entablement + un colosse) fait au plus MODULE["width"] ; sur chaque côté, les modules sont
# un peu resserrés pour tomber juste, et un pilier à brasero cache chaque jonction. Collisions : un bloc invisible
# haut par module (on ne grimpe pas sur les statues, on ne sort pas du monde).
with open(os.path.join(ROOT, "assets", "export", "props", "statue_wall_manifest.json"), encoding="utf-8") as _f:
    WALL = json.load(_f)
TOWN_WALL = 244  # demi-côté du carré de la ville, sur l'axe des modules (les arbres de bordure s'arrêtent à 230)
COLO_WALL = 170  # rayon autour du Colisée (cyprès et rochers jusqu'à ~146)
WALL_POSES = ("Atlas", "Torch", "Scepter", "Atlas", "Flex", "Torch")
WALL_GLOW = {"Atlas": 2, "Torch": 3, "Scepter": 1, "Flex": 1}  # lueurs (yeux, veines) sur une statue sur N
PIER_FIRE_EVERY = 2  # un brasero allumé sur N piliers
WALL_FIRE_RANGE = 360  # studs : les flammes du mur se voient de loin (au-delà de la portée des braseros du Colisée)


def wall_outline():
    """Points du contour (sens horaire vu du ciel), chaque côté découpé en modules : liste de (a, b, dedans)
    où dedans est le point vers lequel les colosses regardent."""
    R, c = COLO_WALL, COLO_CENTER
    t = TOWN_WALL
    j = c[1] + math.sqrt(R * R - (t + c[0]) ** 2)  # croisement du carré et du cercle (x = -t ou z = -t)
    town = (0.0, 0.0)
    runs = [((-t, j), (-t, t)), ((-t, t), (t, t)), ((t, t), (t, -t)), ((t, -t), (j, -t))]
    out = []
    for a, b in runs:
        length = math.dist(a, b)
        n = math.ceil(length / WALL["module"]["width"])
        for k in range(n):
            p0 = [a[i] + (b[i] - a[i]) * k / n for i in range(2)]
            p1 = [a[i] + (b[i] - a[i]) * (k + 1) / n for i in range(2)]
            out.append((p0, p1, town))
    # arc autour du Colisée, du croisement sud au croisement ouest, par l'extérieur
    a0 = math.atan2(-t - c[1], j - c[0])
    a1 = math.atan2(j - c[1], -t - c[0]) - 2 * math.pi
    step = 2 * math.asin(WALL["module"]["width"] / 2 / R)
    n = math.ceil(abs(a1 - a0) / step)
    for k in range(n):
        u0, u1 = a0 + (a1 - a0) * k / n, a0 + (a1 - a0) * (k + 1) / n
        p0 = [c[0] + R * math.cos(u0), c[1] + R * math.sin(u0)]
        p1 = [c[0] + R * math.cos(u1), c[1] + R * math.sin(u1)]
        out.append((p0, p1, c))
    return out


def wall_piece(F, name, prop, collide=False):
    m = WALL["pieces"][prop]
    cx, cy = m["center"]
    return prop_slot(F, name, (cx, m["bottom"], cy), prop, collide=collide)


def statue_wall():
    c = []
    M = WALL["module"]
    for i, (p0, p1, inside) in enumerate(wall_outline()):
        mid = [(p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2]
        length = math.dist(p0, p1)
        # le module regarde vers l'intérieur (son -Z local), perpendiculaire au côté
        ex, ez = (p1[0] - p0[0]) / length, (p1[1] - p0[1]) / length
        nx, nz = -ez, ex
        if (inside[0] - mid[0]) * nx + (inside[1] - mid[1]) * nz < 0:
            nx, nz = -nx, -nz
        yaw = math.degrees(math.atan2(-nx, -nz))
        F = Frame((mid[0], GROUND, mid[1]), yaw)
        pose = WALL_POSES[i % len(WALL_POSES)]
        statue = f"Colossus_{pose}"
        glow = i % WALL_GLOW[pose] == 0
        c.append(wall_piece(F, f"Wall{i}Module", "StatueWall_Module"))
        c.append(wall_piece(F, f"Wall{i}Statue", statue))
        c.append(wall_piece(F, f"Wall{i}Gold", statue + "_Gold"))
        if glow:
            c.append(wall_piece(F, f"Wall{i}Glow", statue + "_Glow"))
        # collision : tout le module, très haut
        c.append(P(F, f"Wall{i}Block", (0, 80, 0), (length + 0.5, 160, M["depth"]), WHITE, transparency=1,
                   extra=INVISIBLE))
        # effets (manifest en repère Blender : x, y vers l'arrière, z vers le haut -> repère local x, y, z)
        fx = WALL["statues"][pose]
        if "Flame" in fx:
            x, y, z = fx["Flame"]
            c.append(P(F, f"Wall{i}Flame", (x, z, y), (1, 1, 1), WHITE, transparency=1, collide=False,
                       tags=["ColosseumFire"], attributes={"FireSize": 6, "FireRange": WALL_FIRE_RANGE},
                       extra=INVISIBLE))
        if glow:
            gx, gy, gz = fx["Gaze"]
            gaze = apply(rot(yaw), [gx, gz, gy])
            for k, (x, y, z) in enumerate(fx["Eyes"]):
                c.append(P(F, f"Wall{i}Eye{k}", (x, z, y), (0.5, 0.5, 0.5), WHITE, transparency=1, collide=False,
                           tags=["ColossusGlow"], attributes={"Kind": "Eye", "Gaze": {"Vector3": [round(v, 3) for v in gaze]}},
                           extra=INVISIBLE))
            if "Scepter" in fx:
                x, y, z = fx["Scepter"]
                c.append(P(F, f"Wall{i}Scepter", (x, z, y), (1, 1, 1), WHITE, transparency=1, collide=False,
                           tags=["ColossusGlow"], attributes={"Kind": "Scepter"}, extra=INVISIBLE))
        # pilier sur la jonction de départ (le contour est fermé : chaque jonction est le départ d'un module)
        for j, (px, pz) in enumerate((p0,)):
            G = Frame((px, GROUND, pz), yaw)
            c.append(decor(G, f"Wall{i}Pier{j}", (0, 0, -3.2), "StatueWall_Pier"))
            c.append(P(G, f"Wall{i}PierBlock{j}", (0, 80, -3.2), (WALL["pier"]["size"] + 2.6, 160,
                                                                 WALL["pier"]["size"] + 2.6), WHITE, transparency=1,
                       extra=INVISIBLE))
            if (i + j) % PIER_FIRE_EVERY == 0:
                fx_, fy_, fz_ = WALL["pier"]["fire"]
                c.append(P(G, f"Wall{i}PierFire{j}", (fx_, fz_, -3.2 + fy_), (1, 1, 1), WHITE, transparency=1,
                           collide=False, tags=["ColosseumFire"],
                           attributes={"FireSize": 9, "FireRange": WALL_FIRE_RANGE}, extra=INVISIBLE))
    return model("StatueWall", c)


# ------------------------------------------------------------------ écriture
# ------------------------------------------------------------------ faces superposées (D102)
ZFIGHT_EPS = 0.03  # studs : la plus petite pièce dépasse d'autant (invisible, mais plus de scintillement)


def _blocks(node, out):
    props = node.get("properties", {})
    if node.get("className") == "Part" and props.get("Shape", "Block") == "Block"             and props.get("Transparency", 0) < 0.95 and "Size" in props:
        out.append(node)
    for child in node.get("children", []):
        _blocks(child, out)
    return out


def _faces(node):
    props = node["properties"]
    pos = props["CFrame"]["CFrame"]["position"]
    m = props["CFrame"]["CFrame"]["orientation"]
    size = props["Size"]
    axes = [[m[0][j], m[1][j], m[2][j]] for j in range(3)]
    out = []
    for i in range(3):
        for sgn in (1, -1):
            n = [a * sgn for a in axes[i]]
            c = [pos[k] + n[k] * size[i] / 2 for k in range(3)]
            others = [(axes[j], size[j] / 2) for j in range(3) if j != i]
            out.append((i, sgn, n, c, others))
    return out


def _dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def _overlap(fa, fb):
    area = 1.0
    for axis, half in fa[4]:
        ca = _dot(fa[3], axis)
        cb = _dot(fb[3], axis)
        eb = sum(abs(_dot(ax, axis)) * h for ax, h in fb[4])
        o = min(ca + half, cb + eb) - max(ca - half, cb - eb)
        if o <= 0.02:
            return 0.0
        area *= o
    return area


def separate_coplanar(root):
    """Deux faces au même endroit, dans le même sens, de couleurs ou matières différentes : Roblox les fait
    scintiller (elles « changent de couleur » quand la caméra bouge). La plus petite pièce dépasse un peu.
    Renvoie le nombre de pièces décalées."""
    parts = _blocks(root, [])
    moved = 0
    for _ in range(8):  # une face par paire et par passage : une paire peut en partager plusieurs
        grid = {}
        boxes = []
        for idx, node in enumerate(parts):
            props = node["properties"]
            pos, size = props["CFrame"]["CFrame"]["position"], props["Size"]
            r = math.sqrt(sum(v * v for v in size)) / 2 + 0.05
            lo = [int(math.floor((pos[k] - r) / 16)) for k in range(3)]
            hi = [int(math.floor((pos[k] + r) / 16)) for k in range(3)]
            boxes.append((pos, r))
            for gx in range(lo[0], hi[0] + 1):
                for gy in range(lo[1], hi[1] + 1):
                    for gz in range(lo[2], hi[2] + 1):
                        grid.setdefault((gx, gy, gz), []).append(idx)
        pairs = set()
        for cell in grid.values():
            for a in range(len(cell)):
                for b in range(a + 1, len(cell)):
                    i, j = cell[a], cell[b]
                    (pa, ra), (pb, rb) = boxes[i], boxes[j]
                    if sum((pa[k] - pb[k]) ** 2 for k in range(3)) <= (ra + rb) ** 2:
                        pairs.add((min(i, j), max(i, j)))
        changed = 0
        for i, j in sorted(pairs):
            A, B = parts[i]["properties"], parts[j]["properties"]
            if A["Color"] == B["Color"] and A["Material"] == B["Material"]:
                continue
            for fa in _faces(parts[i]):
                hit = None
                for fb in _faces(parts[j]):
                    if _dot(fa[2], fb[2]) > 0.999 and abs(_dot([fb[3][k] - fa[3][k] for k in range(3)], fa[2])) < 0.01                             and _overlap(fa, fb) > 0.05:
                        hit = fb
                        break
                if not hit:
                    continue
                vol = lambda P: P["Size"][0] * P["Size"][1] * P["Size"][2]
                small, face = (parts[i], fa) if vol(A) <= vol(B) else (parts[j], hit)
                props = small["properties"]
                axis, n = face[0], face[2]
                props["Size"][axis] = round(props["Size"][axis] + ZFIGHT_EPS, 3)
                pos = props["CFrame"]["CFrame"]["position"]
                props["CFrame"]["CFrame"]["position"] = [round(pos[k] + n[k] * ZFIGHT_EPS / 2, 3) for k in range(3)]
                changed += 1
                break
        moved += changed
        if not changed:
            break
    return moved


if __name__ == "__main__":
    out = os.path.join(WORLD, "Map")
    written = set()
    plots = [plot(i, side, offset) for i, (side, offset) in enumerate(plot_list(), start=1)]
    town = [ring(), downtown(), colosseum(), statue_wall()]
    # Toute la carte d'un coup : les faces superposées entre deux fichiers (allée d'une maison et trottoir) comptent
    print(separate_coplanar({"children": plots + town}), "faces superposées séparées")
    for i, node in enumerate(plots, start=1):
        path = os.path.join(out, "Plots", f"Plot{i:02d}.model.json")
        write(path, node)
        written.add(os.path.normpath(path))
    for node in town:
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
